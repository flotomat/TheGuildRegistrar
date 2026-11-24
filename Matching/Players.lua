-- The Guild Registrar - group guild characters into players (main + twinks) (pure Lua 5.1)
--
-- Input character (from Data/Roster.lua or demo data):
--   { name, fullName, realm, rank (1 = guild master), rankName, level, classFile, className,
--     note, officerNote, online, guid }
-- A character is a twink if
--   - its rank name is one of the configured twink ranks (settings.twinkByRank), or
--   - one of its notes matches a twink pattern (settings.twinkByNote).
-- Patterns are simple templates such as "twink von {main}" or plain keywords such as "twink".

local _, ns = ...

local Players = {}
ns.Players = Players

local Text = ns.Text

local MAGIC = "([%^%$%(%)%%%.%[%]%*%+%-%?])"
local CAPTURE = "([^%s,;/|%(%)%[%]:]+)"

-- Compile the configured templates once.
function Players.compilePatterns(templates)
    local compiled = { withMain = {}, keywords = {} }
    for _, tpl in ipairs(templates or {}) do
        local t = Text.lower(ns.Util.trim(tpl))
        if t ~= "" then
            if t:find("{main}", 1, true) then
                local pat = t:gsub(MAGIC, "%%%1")
                pat = pat:gsub("{main}", "\001")
                pat = pat:gsub("%s+", "%%s*")
                pat = pat:gsub("\001", CAPTURE)
                if t:sub(1, 1):match("[%w]") then
                    pat = "%f[%w]" .. pat
                end
                compiled.withMain[#compiled.withMain + 1] = pat
            else
                local f = Text.forms(t)
                compiled.keywords[#compiled.keywords + 1] = f
            end
        end
    end
    return compiled
end

local function noteTexts(c, settings)
    local list = {}
    if settings.useNote and c.note and c.note ~= "" then
        list[#list + 1] = { text = c.note, source = "note" }
    end
    if settings.useOfficerNote and c.officerNote and c.officerNote ~= "" then
        list[#list + 1] = { text = c.officerNote, source = "officer" }
    end
    return list
end

-- Detect twink status and main references for a character.
local function inspectTwink(c, settings, patterns, twinkRankSet, stopset)
    local isTwink, refs = false, {}
    if settings.twinkByRank and c.rankName and twinkRankSet[Text.key(c.rankName)] then
        isTwink = true
        c.twinkReason = "rank"
    end
    if settings.twinkByNote then
        for _, nt in ipairs(noteTexts(c, settings)) do
            local low = Text.lower(nt.text)
            for _, pat in ipairs(patterns.withMain) do
                for cap in low:gmatch(pat) do
                    local f = Text.forms(cap)
                    if #f.a >= 2 and not (stopset[f.a] or stopset[f.g]) then
                        refs[#refs + 1] = cap
                        isTwink = true
                        c.twinkReason = c.twinkReason or "note"
                    end
                end
            end
            if #patterns.keywords > 0 then
                for _, tok in ipairs(Text.tokenize(nt.text, nil)) do
                    for _, kw in ipairs(patterns.keywords) do
                        if tok.forms.a == kw.a or tok.forms.g == kw.g then
                            isTwink = true
                            c.twinkReason = c.twinkReason or "note"
                        end
                    end
                end
            end
        end
    end
    return isTwink, refs
end

-- Find a character by a (possibly abbreviated) name. Exact folded match first, then a unique prefix (min. 4 letters).
local function findCharByName(name, byKey, chars, exclude)
    local f = Text.forms(name)
    local c = byKey[f.a] or byKey[f.g]
    if c and c ~= exclude then
        return c
    end
    if #f.a >= 4 then
        local found
        for _, other in ipairs(chars) do
            if other ~= exclude and (other.forms.a:sub(1, #f.a) == f.a or other.forms.g:sub(1, #f.g) == f.g) then
                if found then
                    return nil -- ambiguous
                end
                found = other
            end
        end
        return found
    end
    return nil
end

-- Build players from roster characters.
-- Returns list of players: { id, main = char, chars = {...}, twinks = {...}, orphan = bool }
function Players.build(chars, settings)
    local stopset = Text.wordSet(settings.stopwords)
    local twinkRankSet = Text.wordSet(settings.twinkRankNames)
    local patterns = Players.compilePatterns(settings.twinkPatterns)

    local byKey = {}
    for _, c in ipairs(chars) do
        c.forms = Text.forms(c.name)
        c.isTwink, c.twinkRefs, c.mainChar, c.twinkReason = false, nil, nil, nil
        byKey[c.forms.a] = byKey[c.forms.a] or c
        byKey[c.forms.g] = byKey[c.forms.g] or c
        -- note tokens for matching
        c.noteTokens = {}
        for _, nt in ipairs(noteTexts(c, settings)) do
            for _, tok in ipairs(Text.tokenize(nt.text, stopset)) do
                tok.source = nt.source
                c.noteTokens[#c.noteTokens + 1] = tok
            end
        end
    end

    for _, c in ipairs(chars) do
        local isTwink, refs = inspectTwink(c, settings, patterns, twinkRankSet, stopset)
        c.isTwink = isTwink
        c.twinkRefs = refs
    end

    -- resolve main characters
    for _, c in ipairs(chars) do
        if c.isTwink then
            for _, ref in ipairs(c.twinkRefs) do
                local m = findCharByName(ref, byKey, chars, c)
                if m then
                    c.mainChar = m
                    break
                end
            end
            if not c.mainChar then
                -- e.g. twink rank with a note that just names the main
                for _, tok in ipairs(c.noteTokens) do
                    local m = byKey[tok.forms.a] or byKey[tok.forms.g]
                    if m and m ~= c and not m.isTwink then
                        c.mainChar = m
                        break
                    end
                end
            end
        end
    end

    local function root(c)
        local cur, steps = c, 0
        while cur.isTwink and cur.mainChar and steps < 6 do
            cur = cur.mainChar
            steps = steps + 1
        end
        return cur
    end

    local players, byRoot = {}, {}
    local function playerFor(rootChar)
        local p = byRoot[rootChar]
        if not p then
            p = { id = rootChar.fullName or rootChar.name, main = rootChar, chars = { rootChar }, twinks = {}, orphan = rootChar.isTwink }
            byRoot[rootChar] = p
            players[#players + 1] = p
            rootChar.player = p
        end
        return p
    end

    for _, c in ipairs(chars) do
        if not c.isTwink then
            playerFor(c)
        end
    end
    for _, c in ipairs(chars) do
        if c.isTwink then
            local r = root(c)
            if r == c then
                playerFor(c)
            else
                local p = playerFor(r)
                p.chars[#p.chars + 1] = c
                p.twinks[#p.twinks + 1] = c
                c.player = p
            end
        end
    end
    return players
end
