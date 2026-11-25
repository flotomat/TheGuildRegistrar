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

-- Values for the note templates.
function Advice.templateValues(row, c)
    local m = row.member
    local main = mainOf(row, c)
    return {
        discord = m and m.display or "",
        nick = m and Text.nickname(m.analysis) or "",
        main = main and main.name or c.name,
        char = c.name,
    }
end

local function isAlt(row, c)
    return c ~= mainOf(row, c)
end

-- Suggested note text for a character (template for mains or alts), shortened to the note limit.
function Advice.suggestedNote(row, c, settings)
    local template = isAlt(row, c) and settings.twinkNoteTemplate or settings.noteTemplate
    if not template or Util.trim(template) == "" then
        return nil
    end
    return Util.utf8truncate(Util.format(template, Advice.templateValues(row, c)), Advice.NOTE_MAX_BYTES)
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

local function contains(hay, needle)
    local h, n = Text.key(hay or ""), Text.key(needle or "")
    return n ~= "" and h:find(n, 1, true) ~= nil
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

    for _, row in ipairs(rows) do
        row.advice = {}
        for _, c in ipairs(Advice.rowChars(row)) do
            c.advice = {}
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
                    local note = Advice.suggestedNote(row, c, s)
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
                -- expected note text
                -- (the officer note is only checked if it can be read: Engine turns useOfficerNote off otherwise)
                local checkNote = s.noteCheck == "public" or (s.noteCheck == "officer" and s.useOfficerNote)
                if checkNote and m and (level[row.status] or 0) >= 2 then
                    local note = (s.noteCheck == "officer") and c.officerNote or c.note
                    local expected = Advice.suggestedNote(row, c, s)
                    if expected then
                        local ok
                        if isAlt(row, c) then
                            ok = contains(note, main.name)
                        else
                            ok = contains(note, expected) or contains(note, m.display)
                                or contains(note, Text.nickname(m.analysis))
                        end
                        if not ok then
                            add(c.advice, { code = "NOTE_EXPECTED", a = expected, method = s.noteCheck })
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
