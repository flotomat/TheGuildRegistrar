-- The Guild Registrar - matching engine (pure Lua 5.1)
--
-- Scores every Discord member against every player (main + twinks), assigns them greedily
-- and classifies each assignment:
--   confirmed  - manually confirmed by an officer
--   sure       - score >= thresholds.sure and no close competitor (margin >= thresholds.margin)
--   likely     - score >= thresholds.likely (or a sure score with a close competitor)
--   unlikely   - score >= thresholds.unlikely
--   unassigned - nothing good enough
--   guest      - Discord member with a guest role and no assignment
--   ignored    - put on the ignore list by an officer
--
-- To keep it fast, fuzzy comparisons only happen between words that start with the same letter.

local _, ns = ...

local Matcher = {}
ns.Matcher = Matcher

local Text, Sim, Util = ns.Text, ns.Similarity, ns.Util

Matcher.STATUS_ORDER = { confirmed = 1, sure = 2, likely = 3, unlikely = 4, unassigned = 5, guest = 6, ignored = 7 }
Matcher.STATUS_LEVEL = { confirmed = 4, sure = 3, likely = 2, unlikely = 1, unassigned = 0, guest = 0, ignored = 0 }

local CANDIDATE_MIN = 0.20

function Matcher.pairKey(memberKey, charFullName)
    return memberKey .. "\001" .. charFullName
end

local function classify(score, margin, th)
    if score >= th.sure and margin >= th.margin then
        return "sure"
    elseif score >= th.likely then
        return "likely"
    elseif score >= th.unlikely then
        return "unlikely"
    end
    return "unassigned"
end
Matcher.classify = classify

local function weight(tok, entry)
    local w
    if entry.source == "name" then
        if tok.isConcat then
            w = 1.00
        elseif tok.secondary then
            w = 0.80
        elseif tok.part == "main" then
            w = 1.00
        elseif tok.part == "nick" then
            w = 0.90
        else
            w = 0.95
        end
    else
        if tok.secondary or entry.secondary then
            w = 0.75
        else
            w = 0.90
        end
    end
    if entry.char.isTwink then
        w = w * 0.95
    end
    return w
end

local function bucketKeys(forms)
    local k1 = forms.a:sub(1, 1)
    local k2 = forms.g:sub(1, 1)
    if k2 ~= k1 and k2 ~= "" then
        return k1, k2
    end
    return k1
end

-- Build an index of all comparable words on the guild side, bucketed by first letter.
local function buildIndex(players)
    local index = {}
    local function put(entry)
        local k1, k2 = bucketKeys(entry.forms)
        for _, k in ipairs({ k1, k2 }) do
            if k and k ~= "" then
                local b = index[k]
                if not b then
                    b = {}
                    index[k] = b
                end
                b[#b + 1] = entry
            end
        end
    end
    for _, p in ipairs(players) do
        for _, c in ipairs(p.chars) do
            put({ forms = c.forms, source = "name", char = c, player = p, raw = c.name })
            for _, tok in ipairs(c.noteTokens or {}) do
                put({ forms = tok.forms, source = tok.source, secondary = tok.secondary, char = c, player = p, raw = tok.raw })
            end
        end
    end
    return index
end

-- Words of the Discord name that are compared (tokens + the whole name glued together).
local function memberWords(analysis)
    local words = {}
    for _, t in ipairs(analysis.tokens) do
        words[#words + 1] = t
    end
    if analysis.primaryCount > 1 and #analysis.concat.a >= 2 then
        words[#words + 1] = { raw = analysis.display, forms = analysis.concat, isConcat = true }
    end
    return words
end

local function bestNameMatch(rawText, player)
    -- best similarity of any word in rawText against the character names of a player
    local best = 0
    for _, tok in ipairs(Text.tokenize(rawText or "", nil)) do
        for _, c in ipairs(player.chars) do
            local v = Sim.compareForms(tok.forms, c.forms)
            if v > best then
                best = v
            end
        end
    end
    return best
end

--[[
ctx = {
  members   = { { key, display, roles } },
  players   = list from Players.build,
  settings  = settings table (nameRule, thresholds, stopwords, guestRoleNames),
  decisions = { confirmed = { [memberKey] = charFullName }, rejected = { [pairKey] = true },
                ignoredDiscord = { [memberKey] = true }, ignoredChars = { [charFullName] = true } },
  yield     = optional function, called regularly (coroutine.yield inside the game)
}
returns { rows = {...}, summary = {...} }
]]
function Matcher.run(ctx)
    local settings = ctx.settings
    local th = settings.thresholds
    local decisions = ctx.decisions or {}
    local confirmed = decisions.confirmed or {}
    local rejected = decisions.rejected or {}
    local ignoredDiscord = decisions.ignoredDiscord or {}
    local ignoredChars = decisions.ignoredChars or {}
    local yield = ctx.yield or function() end
    local stopset = Text.wordSet(settings.stopwords)
    local guestSet = Text.wordSet(settings.guestRoleNames)

    local ops = 0
    local function tick(n)
        ops = ops + n
        if ops >= 300 then
            ops = 0
            yield()
        end
    end

    -- players that take part
    local active, charByFull = {}, {}
    for _, p in ipairs(ctx.players) do
        p.ignored = ignoredChars[p.main.fullName] and true or false
        p.candidates, p.assigned, p.attachedTo = {}, nil, nil
        for _, c in ipairs(p.chars) do
            charByFull[c.fullName] = c
        end
        if not p.ignored then
            active[#active + 1] = p
        end
    end
    local index = buildIndex(active)

    -- analyze and score Discord members
    local members = {}
    for _, src in ipairs(ctx.members) do
        local m = {
            key = src.key, display = src.display, roles = src.roles or {},
            ignored = ignoredDiscord[src.key] and true or false,
        }
        m.isGuest = false
        for _, r in ipairs(m.roles) do
            local f = Text.forms(r)
            if guestSet[f.a] or guestSet[f.g] then
                m.isGuest = true
            end
        end
        m.analysis = Text.analyzeDiscordName(src.display, settings.nameRule, stopset)
        m.candidates = {}
        members[#members + 1] = m

        if not m.ignored then
            local byPlayer = {}
            for _, tok in ipairs(memberWords(m.analysis)) do
                local k1, k2 = bucketKeys(tok.forms)
                local visited = {}
                for _, k in ipairs({ k1, k2 }) do
                    local bucket = k and index[k]
                    if bucket then
                        tick(#bucket)
                        for _, e in ipairs(bucket) do
                            if not visited[e] then
                                visited[e] = true
                                local v, kind = Sim.compareForms(tok.forms, e.forms)
                                if v > 0 then
                                    local val = v * weight(tok, e)
                                    local cand = byPlayer[e.player]
                                    if not cand then
                                        cand = { player = e.player, name = 0, note = 0 }
                                        byPlayer[e.player] = cand
                                    end
                                    local cat = (e.source == "name") and "name" or "note"
                                    if val > cand[cat] then
                                        cand[cat] = val
                                        cand[cat .. "Reason"] = {
                                            source = e.source, kind = kind, word = tok.isConcat and m.display or tok.raw,
                                            target = e.raw, char = e.char.name, value = val,
                                        }
                                    end
                                end
                            end
                        end
                    end
                end
            end
            for p, cand in pairs(byPlayer) do
                cand.score = Sim.combine(cand.name, cand.note)
                if cand.score >= CANDIDATE_MIN and not rejected[Matcher.pairKey(m.key, p.main.fullName)] then
                    m.candidates[#m.candidates + 1] = cand
                    p.candidates[#p.candidates + 1] = { member = m, score = cand.score }
                end
            end
            Util.stableSort(m.candidates, function(a, b) return a.score > b.score end)
        end
    end
    for _, p in ipairs(active) do
        Util.stableSort(p.candidates, function(a, b) return a.score > b.score end)
    end
    yield()

    -- manual confirmations first
    for _, m in ipairs(members) do
        m.assigned, m.extras, m.status = nil, {}, nil
        local target = confirmed[m.key]
        if target and not m.ignored then
            local c = charByFull[target]
            if c and c.player and not c.player.ignored then
                m.assigned = c.player
                m.status = "confirmed"
                m.score = 1
                c.player.assigned = c.player.assigned or m
            else
                m.confirmedMissing = target
            end
        end
    end

    -- greedy assignment by descending score
    local pairs_ = {}
    for _, m in ipairs(members) do
        if not m.ignored and not m.assigned then
            for _, cand in ipairs(m.candidates) do
                if cand.score >= th.unlikely then
                    pairs_[#pairs_ + 1] = { member = m, cand = cand }
                end
            end
        end
    end
    Util.stableSort(pairs_, function(a, b) return a.cand.score > b.cand.score end)
    for _, pr in ipairs(pairs_) do
        local m, p = pr.member, pr.cand.player
        if not p.assigned and not p.attachedTo then
            if not m.assigned and m.status ~= "confirmed" then
                m.assigned = p
                m.cand = pr.cand
                m.score = pr.cand.score
                p.assigned = m
            elseif p.orphan and m.assigned ~= p then
                -- twink without detected main: attach to the member that already has a player
                p.attachedTo = m
                m.extras[#m.extras + 1] = { player = p, cand = pr.cand }
            end
        end
    end
    yield()

    -- classification
    local function competitorForMember(m, p)
        for _, cand in ipairs(m.candidates) do
            if cand.player ~= p and not cand.player.orphan then
                return cand.score
            end
        end
        return 0
    end
    local function competitorForPlayer(p, m)
        for _, pc in ipairs(p.candidates) do
            if pc.member ~= m then
                return pc.score
            end
        end
        return 0
    end

    local rows = {}
    local summary = { total = 0, members = #members, players = #ctx.players,
        confirmed = 0, sure = 0, likely = 0, unlikely = 0, unassigned = 0, guest = 0, ignored = 0,
        discordOnly = 0, wowOnly = 0, ruleIssues = 0 }

    for _, m in ipairs(members) do
        local row = { kind = "member", member = m, player = m.assigned, extras = m.extras, flags = {}, alternatives = {} }
        if m.ignored then
            row.status = "ignored"
        elseif m.status == "confirmed" then
            row.status = "confirmed"
            row.score = 1
            row.margin = 1
        elseif m.assigned then
            local comp = math.max(competitorForMember(m, m.assigned), competitorForPlayer(m.assigned, m))
            row.score = m.score
            row.margin = m.score - comp
            row.status = classify(m.score, row.margin, th)
            row.reasons = { m.cand.nameReason, m.cand.noteReason }
        else
            row.status = m.isGuest and "guest" or "unassigned"
        end
        for _, ex in ipairs(m.extras) do
            ex.status = classify(ex.cand.score, 1, th)
        end
        -- alternatives: other candidates
        for _, cand in ipairs(m.candidates) do
            if cand.player ~= m.assigned and #row.alternatives < 5 then
                row.alternatives[#row.alternatives + 1] = { player = cand.player, score = cand.score }
            end
        end
        -- flags
        local a = m.analysis
        if a.rule.applies and not a.rule.ok then
            row.flags.ruleFormat = true
        end
        if a.rule.applies and a.rule.ok and not a.rule.anyOrder and m.assigned then
            local mainSim = bestNameMatch(a.rule.mainRaw, m.assigned)
            local nickSim = bestNameMatch(a.rule.nickRaw, m.assigned)
            if mainSim < 0.9 and nickSim >= 0.9 then
                row.flags.ruleReversed = true
            end
        end
        if m.isGuest and m.assigned then
            row.flags.guestInGuild = true
        end
        if m.assigned and m.assigned.orphan then
            row.flags.orphanTwink = true
        end
        if m.confirmedMissing then
            row.flags.confirmedMissing = m.confirmedMissing
        end
        row.side = m.assigned and "both" or "discordOnly"
        rows[#rows + 1] = row
    end

    for _, p in ipairs(ctx.players) do
        if not p.assigned and not p.attachedTo then
            local row = { kind = "player", player = p, flags = {}, alternatives = {}, side = "wowOnly" }
            row.status = p.ignored and "ignored" or "unassigned"
            for _, pc in ipairs(p.candidates or {}) do
                if #row.alternatives < 5 then
                    row.alternatives[#row.alternatives + 1] = { member = pc.member, score = pc.score }
                end
            end
            if p.orphan then
                row.flags.orphanTwink = true
            end
            rows[#rows + 1] = row
        end
    end

    for _, row in ipairs(rows) do
        summary.total = summary.total + 1
        summary[row.status] = (summary[row.status] or 0) + 1
        if row.status ~= "ignored" and row.status ~= "guest" then
            if row.side == "discordOnly" then
                summary.discordOnly = summary.discordOnly + 1
            elseif row.side == "wowOnly" then
                summary.wowOnly = summary.wowOnly + 1
            end
        end
        if row.flags.ruleFormat or row.flags.ruleReversed then
            summary.ruleIssues = summary.ruleIssues + 1
        end
    end

    return { rows = rows, summary = summary, members = members }
end
