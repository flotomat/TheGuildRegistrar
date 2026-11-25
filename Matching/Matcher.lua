-- The Guild Registrar - matching engine (pure Lua 5.1)
--
-- A Discord account can own several characters (1:n). The characters are grouped into players
-- (main + twinks, see Players.lua); a Discord member gets one player as its main group and may get
-- further groups attached (shown as twinks of the main). Order of assignment:
--   1. fixed assignments of the officers (decisions.links[charFullName] = memberKey)
--   2. one player per member, greedily by descending score
--   3. remaining players are attached to the member that matches them best
--      (twinks without known main from "unlikely" on, other characters from "likely" on)
-- Ties are always broken by a fixed order, so repeated runs give the same result.
-- Every assignment is classified:
--   confirmed  - fixed by an officer
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
  decisions = { links = { [charFullName] = memberKey }, rejected = { [pairKey] = true },
                ignoredDiscord = { [memberKey] = true }, ignoredChars = { [charFullName] = true } },
  yield     = optional function, called regularly (coroutine.yield inside the game)
}
returns { rows = {...}, summary = {...}, members = {...} }
]]
function Matcher.run(ctx)
    local settings = ctx.settings
    local th = settings.thresholds
    local decisions = ctx.decisions or {}
    local links = decisions.links or {}
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
    for i, p in ipairs(ctx.players) do
        p.index = i
        p.ignored = ignoredChars[p.main.fullName] and true or false
        p.candidates, p.assigned, p.attachedTo, p.taken, p.linkMissing = {}, nil, nil, nil, nil
        for _, c in ipairs(p.chars) do
            charByFull[c.fullName] = c
        end
        if not p.ignored then
            active[#active + 1] = p
        end
    end
    local index = buildIndex(active)

    -- analyze and score Discord members
    local members, memberByKey = {}, {}
    for i, src in ipairs(ctx.members) do
        local m = {
            key = src.key, display = src.display, roles = src.roles or {}, index = i,
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
        memberByKey[m.key] = m

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
                    p.candidates[#p.candidates + 1] = { member = m, score = cand.score, cand = cand }
                end
            end
            -- ties are broken by the player order (sorted by name), never by chance
            table.sort(m.candidates, function(a, b)
                if a.score ~= b.score then
                    return a.score > b.score
                end
                return a.player.index < b.player.index
            end)
        end
    end
    for _, p in ipairs(active) do
        table.sort(p.candidates, function(a, b)
            if a.score ~= b.score then
                return a.score > b.score
            end
            return a.member.index < b.member.index
        end)
    end
    yield()

    local function candidateOf(m, p)
        for _, cand in ipairs(m.candidates) do
            if cand.player == p then
                return cand
            end
        end
        return nil
    end

    for _, m in ipairs(members) do
        m.groups, m.assigned, m.extras, m.status, m.cand, m.score = {}, nil, {}, nil, nil, nil
    end
    local function addGroup(m, p, linked, cand, score)
        m.groups[#m.groups + 1] = { player = p, linked = linked, cand = cand, score = score }
        p.taken = m
    end
    local function hasMain(m)
        for _, gr in ipairs(m.groups) do
            if not gr.player.orphan then
                return true
            end
        end
        return false
    end

    -- 1. fixed assignments
    for _, p in ipairs(active) do
        local key = links[p.main.fullName]
        if key then
            local m = memberByKey[key]
            if m and not m.ignored then
                addGroup(m, p, true, candidateOf(m, p), 1)
            elseif not m then
                p.linkMissing = key
            end
        end
    end
    -- fixed characters that are no longer in the guild
    for charName, key in pairs(links) do
        local m = memberByKey[key]
        if m and not charByFull[charName] and (not m.confirmedMissing or charName < m.confirmedMissing) then
            m.confirmedMissing = charName
        end
    end

    -- 2. one player per member, by descending score
    local pairs_ = {}
    for _, m in ipairs(members) do
        if not m.ignored then
            for _, cand in ipairs(m.candidates) do
                if cand.score >= th.unlikely and not cand.player.taken and not cand.player.orphan then
                    pairs_[#pairs_ + 1] = { member = m, cand = cand }
                end
            end
        end
    end
    table.sort(pairs_, function(a, b)
        if a.cand.score ~= b.cand.score then
            return a.cand.score > b.cand.score
        end
        if a.member.index ~= b.member.index then
            return a.member.index < b.member.index
        end
        return a.cand.player.index < b.cand.player.index
    end)
    for _, pr in ipairs(pairs_) do
        local m, p = pr.member, pr.cand.player
        if not p.taken and not hasMain(m) then
            -- a clearly better match with an account that already has its main: attach there (step 3)
            local best = p.candidates[1]
            local defer = best and best.member ~= m and best.score >= th.likely
                and best.score - pr.cand.score > th.margin and hasMain(best.member)
            if not defer then
                addGroup(m, p, false, pr.cand, pr.cand.score)
            end
        end
    end
    yield()

    -- 3. attach the remaining players to the Discord member that matches them best
    for _, p in ipairs(active) do
        local best = not p.taken and p.candidates[1]
        if best and not best.member.ignored then
            local m = best.member
            if p.orphan then
                if best.score >= th.unlikely then
                    addGroup(m, p, false, best.cand, best.score)
                end
            elseif #m.groups > 0 and best.score >= th.likely then
                addGroup(m, p, false, best.cand, best.score)
            end
        end
    end

    -- main group of each member: a character marked as main first, then a real main before a twink
    -- without main, fixed before automatic, then the best match
    local function better(a, b)
        local am, bm = a.player.main.manualMain and 1 or 0, b.player.main.manualMain and 1 or 0
        if am ~= bm then
            return am > bm
        end
        local ao, bo = a.player.orphan and 1 or 0, b.player.orphan and 1 or 0
        if ao ~= bo then
            return ao < bo
        end
        local al, bl = a.linked and 1 or 0, b.linked and 1 or 0
        if al ~= bl then
            return al > bl
        end
        local as, bs = a.cand and a.cand.score or 0, b.cand and b.cand.score or 0
        if as ~= bs then
            return as > bs
        end
        return a.player.index < b.player.index
    end
    for _, m in ipairs(members) do
        if #m.groups > 0 then
            table.sort(m.groups, better)
            local primary = m.groups[1]
            m.assigned = primary.player
            m.cand = primary.cand
            m.score = primary.score
            m.status = primary.linked and "confirmed" or nil
            primary.player.assigned = m
            for i = 2, #m.groups do
                local gr = m.groups[i]
                gr.player.attachedTo = m
                m.extras[#m.extras + 1] = {
                    player = gr.player, cand = gr.cand, score = gr.score, linked = gr.linked,
                    status = gr.linked and "confirmed" or classify(gr.score, 1, th),
                }
            end
        end
    end

    -- twinks that an officer separated from this Discord account: split them off their group
    local splitOff = {}
    local function split(m, p)
        local keep = { p.main }
        for _, c in ipairs(p.chars) do
            if c ~= p.main then
                if rejected[Matcher.pairKey(m.key, c.fullName)] then
                    local np = { id = c.fullName, main = c, chars = { c }, twinks = {}, orphan = c.isTwink and true or false,
                        candidates = {}, index = #ctx.players + #splitOff + 1, splitFrom = m }
                    c.player = np
                    splitOff[#splitOff + 1] = np
                else
                    keep[#keep + 1] = c
                end
            end
        end
        if #keep < #p.chars then
            p.chars = keep
            local twinks = {}
            for i = 2, #keep do
                twinks[#twinks + 1] = keep[i]
            end
            p.twinks = twinks
        end
    end
    for _, m in ipairs(members) do
        if m.assigned then
            split(m, m.assigned)
            for _, ex in ipairs(m.extras) do
                split(m, ex.player)
            end
        end
    end
    yield()

    -- classification
    local function competitorForMember(m, p)
        for _, cand in ipairs(m.candidates) do
            if cand.player ~= p and not cand.player.orphan and cand.player.taken ~= m then
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
            row.reasons = m.cand and { m.cand.nameReason, m.cand.noteReason } or nil
        else
            row.status = m.isGuest and "guest" or "unassigned"
        end
        -- alternatives: other candidates
        for _, cand in ipairs(m.candidates) do
            if cand.player.taken ~= m and #row.alternatives < 5 then
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

    local loose = {}
    for _, p in ipairs(ctx.players) do
        if not p.assigned and not p.attachedTo then
            loose[#loose + 1] = p
        end
    end
    for _, p in ipairs(splitOff) do
        loose[#loose + 1] = p
    end
    for _, p in ipairs(loose) do
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
        if p.linkMissing then
            row.flags.linkMissing = p.linkMissing
        end
        rows[#rows + 1] = row
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
