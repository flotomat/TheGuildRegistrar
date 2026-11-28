-- The Guild Registrar - what the officer should (probably) change (pure Lua 5.1)
--
-- Runs after Matcher.run and Ranks.evaluate. Adds
--   row.advice = { entries about the assignment / the Discord side }
--   c.advice   = { entries about a character in the guild (rank, notes, alt status) }
-- An entry is { code = "...", a = ..., b = ..., method = ... }. Texts are built by the UI
-- (locale keys ADV_<code> and ADV_SHORT_<code>), so this module stays free of game and UI code.

local _, ns = ...

local Advice = {}
ns.Advice = Advice

local Text, Util = ns.Text, ns.Util

Advice.NOTE_MAX_BYTES = 31

-- All characters shown with a row: the player's characters plus attached alt groups.
function Advice.rowChars(row)
    local list = {}
    if row.player then
        for _, c in ipairs(row.player.chars) do
            list[#list + 1] = c
        end
    end
    for _, ex in ipairs(row.extras or {}) do
        for _, c in ipairs(ex.player.chars) do
            list[#list + 1] = c
        end
    end
    return list
end

-- The main character a character belongs to in this row (for attached groups: the row's main).
local function mainOf(row, c)
    if row.player then
        return row.player.main
    end
    return c
end

-- Abbreviations of a list of keys ("mDD/rDD", "BB/Schmied"); empty abbreviations are left out.
local function abbreviate(keys, abbr)
    local parts = {}
    for _, k in ipairs(keys or {}) do
        local a = abbr and abbr[k]
        if a and Util.trim(a) ~= "" then
            parts[#parts + 1] = Util.trim(a)
        end
    end
    return parts
end

-- Values for the note templates. `settings` gives the abbreviations for {roles} and {professions}.
function Advice.templateValues(row, c, settings)
    local m = row.member
    local main = mainOf(row, c)
    local abbr = settings and settings.abbreviations or {}
    local roles = abbreviate(c.dungeonRoles, abbr.roles)
    local profs = abbreviate(c.professions, abbr.professions)
    return {
        discord = m and m.display or "",
        nick = m and Text.nickname(m.analysis) or "",
        main = main and main.name or c.name,
        char = c.name,
        roles = table.concat(roles, "/"),
        professions = table.concat(profs, "/"),
    }, { roles = c.dungeonRoles or {}, professions = c.professions or {} }
end

local function isAlt(row, c)
    return c ~= mainOf(row, c)
end
Advice.isAlt = isAlt

-- Template of a character for a note ("public" | "officer"), nil if empty or that note is switched off.
function Advice.template(row, c, settings, kind)
    local on = (kind == "officer") and settings.noteCheckOfficer or (kind == "public" and settings.noteCheckPublic)
    if not on then
        return nil
    end
    local key = (isAlt(row, c) and "twink" or "main") .. ((kind == "officer") and "Officer" or "Public")
    local template = settings.noteTemplates and settings.noteTemplates[key]
    if not template or Util.trim(template) == "" then
        return nil
    end
    return template
end

-- Fill a template: placeholders replaced, double spaces removed, cut to the note limit.
function Advice.render(template, values)
    local text = Util.trim((Util.format(template, values):gsub("%s+", " ")))
    -- separators next to an empty placeholder: at the start, at the end, or doubled
    local before
    repeat
        before = text
        text = text:gsub("^[|/,;%-]%s*", ""):gsub("%s*[|/,;%-]$", ""):gsub("([|/,;])%s*[|/,;]", "%1")
        text = Util.trim(text)
    until text == before
    return Util.utf8truncate(text, Advice.NOTE_MAX_BYTES)
end

-- Suggested note text for a character, shortened to the note limit. Without `kind` the officer note
-- is used if its template is on, otherwise the public note. Returns text, kind (nil if no template
-- or the text would be empty).
function Advice.suggestedNote(row, c, settings, kind)
    for _, k in ipairs(kind and { kind } or { "officer", "public" }) do
        local template = Advice.template(row, c, settings, k)
        if template then
            local text = Advice.render(template, (Advice.templateValues(row, c, settings)))
            if text ~= "" then
                return text, k
            end
        end
    end
    return nil
end

local function contains(hay, needle)
    local h, n = Text.key(hay or ""), Text.key(needle or "")
    return n ~= "" and h:find(n, 1, true) ~= nil
end

-- True if a note (`kind` of character `c`) fits its template: every filled placeholder value must
-- appear in the note. The Discord name may also appear as its nickname part; dungeon roles and
-- professions count if the note names them in any known spelling (not only the abbreviation).
-- Templates without placeholders must appear as a whole.
function Advice.noteFits(c, kind, template, values, lists, member)
    local note = (kind == "officer") and c.officerNote or c.note
    local anyPlaceholder = false
    for key in template:gmatch("{(%w+)}") do
        anyPlaceholder = true
        if key == "roles" or key == "professions" then
            local found = (key == "roles" and c.noteRoles or c.noteProfessions) or {}
            found = found[kind] or {}
            for _, item in ipairs(lists[key] or {}) do
                if not found[item] then
                    return false
                end
            end
        elseif key == "discord" or key == "nick" then
            local v = values[key]
            if v and v ~= "" and not (contains(note, v) or contains(note, values.discord)
                or (member and contains(note, Text.nickname(member.analysis)))) then
                return false
            end
        else
            local v = values[key]
            if v and v ~= "" and not contains(note, v) then
                return false
            end
        end
    end
    if not anyPlaceholder then
        return contains(note, Advice.render(template, values))
    end
    return true
end

-- Players this (unassigned) player might be an alt of: the Discord member that matches it best
-- already has another player. Returns { { player, member, score } }, best first.
function Advice.altSuggestions(p, minScore)
    local list, seen = {}, {}
    for _, pc in ipairs(p.candidates or {}) do
        local other = pc.member.assigned
        if pc.score >= (minScore or 0) and other and other ~= p and not seen[other] and not pc.member.ignored then
            seen[other] = true
            list[#list + 1] = { player = other, member = pc.member, score = pc.score }
        end
    end
    return list
end

local function add(list, entry)
    list[#list + 1] = entry
end

-- Notes that name another Discord member than the one assigned.
local function checkNotesNameOthers(members)
    for _, m2 in ipairs(members or {}) do
        if not m2.ignored then
            for _, cand in ipairs(m2.candidates or {}) do
                local r = cand.noteReason
                local p = cand.player
                local owner = p.assigned or p.attachedTo
                if r and r.kind == "exact" and (r.value or 0) >= 0.8 and owner and owner ~= m2 then
                    -- skip if the note also names the assigned member
                    local ownerNamed = false
                    for _, oc in ipairs(owner.candidates or {}) do
                        if oc.player == p and oc.noteReason and oc.noteReason.kind == "exact" then
                            ownerNamed = true
                        end
                    end
                    if not ownerNamed then
                        for _, c in ipairs(p.chars) do
                            if c.name == r.char and c.advice then
                                add(c.advice, { code = "NOTE_OTHER", a = m2.display })
                            end
                        end
                    end
                end
            end
        end
    end
end

--[[
ctx = {
  settings  = guild settings,
  rankNames = { [rankNumber] = name },
  members   = res.members (from Matcher.run),
}
Returns the number of top-level rows that have at least one entry.
]]
function Advice.evaluate(rows, ctx)
    local s = ctx.settings
    local th = s.thresholds
    local rankNames = ctx.rankNames or {}
    local twinkRankSet = Text.wordSet(s.twinkRankNames)
    local hasTwinkRank = false
    for _, name in pairs(rankNames) do
        if twinkRankSet[Text.key(name)] then
            hasTwinkRank = true
        end
    end
    local level = ns.Matcher.STATUS_LEVEL

    -- start with the hints of the dungeon roles (DungeonRoles.Evaluate runs before)
    for _, row in ipairs(rows) do
        row.advice = {}
        for _, e in ipairs(row.dungeonAdvice or {}) do
            add(row.advice, e)
        end
        for _, c in ipairs(Advice.rowChars(row)) do
            c.advice = {}
            for _, e in ipairs(c.dungeonAdvice or {}) do
                add(c.advice, e)
            end
        end
    end

    for _, row in ipairs(rows) do
        local m, p, fl = row.member, row.player, row.flags
        local ra = row.advice

        -- Discord side and assignment
        if fl.ruleFormat then
            add(ra, { code = "RULE_FORMAT" })
        end
        if fl.ruleReversed then
            add(ra, { code = "RULE_REVERSED" })
        end
        if fl.guestInGuild then
            add(ra, { code = "GUEST_IN_GUILD" })
        end
        if fl.confirmedMissing then
            add(ra, { code = "CONFIRMED_MISSING", a = fl.confirmedMissing })
        end
        if fl.linkMissing then
            add(ra, { code = "LINK_MISSING", a = fl.linkMissing })
        end
        if m and p and (row.status == "likely" or row.status == "unlikely") then
            add(ra, { code = "CONFIRM", a = p.main.name })
        end
        if row.side == "discordOnly" and row.status == "unassigned" then
            add(ra, { code = "NOT_IN_GUILD" })
        end
        if row.side == "wowOnly" and row.status == "unassigned" then
            local alts = Advice.altSuggestions(p, th.unlikely)
            local best
            for _, pc in ipairs(p.candidates or {}) do
                if not pc.member.assigned and not pc.member.ignored then
                    best = pc
                    break
                end
            end
            if alts[1] then
                add(ra, { code = "ALT_SUGGEST", a = alts[1].player.main.name, b = alts[1].member.display })
            elseif best then
                add(ra, { code = "ASSIGN_SUGGEST", a = best.member.display })
            elseif not p.orphan then
                add(ra, { code = "NOT_IN_DISCORD" })
            end
        end

        -- characters in the guild
        if p and row.status ~= "ignored" then
            -- rank
            if row.rank and row.rank.state == "mismatch" then
                for _, issue in ipairs(row.rank.issues) do
                    add(issue.char.advice, { code = "RANK", a = issue.actualName or "?",
                        b = rankNames[row.rank.expected] or ("#" .. tostring(row.rank.expected)) })
                end
            end
            for _, c in ipairs(Advice.rowChars(row)) do
                local main = mainOf(row, c)
                -- character of an attached group: only the Discord name connects it to the main
                local attachedMain = c.player ~= p and c.player and c == c.player.main
                -- alt (or its main) only known to the addon: mark it in the game
                if (c.manualTwink or attachedMain) and main ~= c and (not c.detectedTwink or not c.noteMainChar) then
                    -- the note that names the main (officer note first)
                    local note
                    for _, kind in ipairs({ "officer", "public" }) do
                        local t = Advice.template(row, c, s, kind)
                        if not note and t and t:find("{main}", 1, true) then
                            note = Advice.suggestedNote(row, c, s, kind)
                        end
                    end
                    local byNote = s.twinkByNote and note ~= nil
                    local byRank = not c.detectedTwink and s.twinkByRank and hasTwinkRank
                    if byNote or byRank then
                        add(c.advice, { code = "ALT_MARK", a = main.name,
                            method = (byNote and byRank) and "both" or (byNote and "note" or "rank"),
                            note = note })
                    end
                end
                -- note names another main
                if c.manualTwink and c.noteMainChar and c.noteMainChar ~= c.mainChar then
                    add(c.advice, { code = "ALT_NOTE_WRONG", a = c.noteMainChar.name, b = c.mainChar and c.mainChar.name or "?" })
                end
                -- marked as main, but rank/note say alt
                if c.manualMain and c.detectedTwink then
                    add(c.advice, { code = "MAIN_MARK", method = c.detectedReason or "note" })
                end
                -- alt without a known main (attached alts get the ALT_MARK hint instead)
                if c.isTwink and not c.mainChar and c.player and c.player.orphan and c == c.player.main and c == main then
                    add(c.advice, { code = "ORPHAN", a = c.twinkRefs and c.twinkRefs[1] })
                end
                -- expected note texts (the officer note only if this rank may read it)
                if m and (level[row.status] or 0) >= 2 then
                    for _, kind in ipairs({ "officer", "public" }) do
                        local template = Advice.template(row, c, s, kind)
                        if template and (kind == "public" or ctx.canViewOfficer ~= false) then
                            local values, lists = Advice.templateValues(row, c, s)
                            local expected = Advice.render(template, values)
                            if expected ~= "" and not Advice.noteFits(c, kind, template, values, lists, m) then
                                add(c.advice, { code = "NOTE_EXPECTED", a = expected, method = kind })
                            end
                        end
                    end
                end
            end
        end
    end

    checkNotesNameOthers(ctx.members)

    local count = 0
    for _, row in ipairs(rows) do
        local any = #row.advice > 0
        for _, c in ipairs(Advice.rowChars(row)) do
            if #c.advice > 0 then
                any = true
            end
        end
        row.hasAdvice = any
        if any then
            count = count + 1
        end
    end
    return count
end
