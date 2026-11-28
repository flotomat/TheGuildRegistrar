-- The Guild Registrar - fuzzy full text search for the Comparison tab (pure Lua 5.1)
--
-- A query is split into words; a row matches if EVERY word is found in one of its fields.
-- A word is found
--   1. anywhere inside a field, also in the middle of a word (umlauts, accents and apostrophes
--      do not matter, see Text.searchForms),
--   2. in the field without spaces ("wurstinator" finds "Wurst Inator"),
--   3. with one typo (one letter wrong, missing, added or two letters swapped), starting at the
--      beginning of a word - words of 4 or more letters only, and only if typo tolerance is on.

local _, ns = ...

local Search = {}
ns.Search = Search

local find, sub, byte = string.find, string.sub, string.byte

Search.MIN_TYPO_LENGTH = 4

-- Words of a query: { { a = "...", g = "..." }, ... } (duplicates removed).
function Search.parse(query)
    local forms = ns.Text.searchForms(query)
    local words, seen = {}, {}
    local ga = {}
    for w in forms.g:gmatch("%S+") do
        ga[#ga + 1] = w
    end
    local i = 0
    for w in forms.a:gmatch("%S+") do
        i = i + 1
        local key = w .. "\001" .. (ga[i] or w)
        if not seen[key] then
            seen[key] = true
            words[#words + 1] = { a = w, g = ga[i] or w }
        end
    end
    return words
end

-- One searchable field. `key` names the column (for "found in"), `owner` is an optional
-- character the field belongs to. Returns nil for empty texts.
function Search.field(key, text, owner)
    if text == nil then
        return nil
    end
    local f = ns.Text.searchForms(text)
    if f.ca == "" then
        return nil
    end
    f.key, f.owner = key, owner
    return f
end

local function exactIn(field, w)
    if #w.a < 3 then
        -- very short words: only inside the spaced text (no matches across word borders)
        return find(field.a, w.a, 1, true) or find(field.g, w.g, 1, true)
    end
    return find(field.ca, w.a, 1, true) or find(field.cg, w.g, 1, true)
end

-- True if `needle` occurs in `hay` with at most one edit: substitution, insertion, deletion or
-- the swap of two neighbouring letters (approximate substring search, Sellers). `hay` is the
-- spaced text; a typo hit must start at the beginning of a word, otherwise short words would
-- match almost anything ("jens" -> "ens" in "namens").
local BIG = 99
local function nearIn(hay, needle)
    local m, n = #needle, #hay
    if m == 0 or n < m - 1 then
        return false
    end
    -- quick filter: at most one letter of the word may be missing from the field
    local missing = 0
    for i = 1, m do
        if not find(hay, sub(needle, i, i), 1, true) then
            missing = missing + 1
            if missing > 1 then
                return false
            end
        end
    end
    local prev2, prev, cur = nil, {}, {}
    prev[0] = 0
    for j = 1, n do
        prev[j] = (byte(hay, j) == 32) and 0 or BIG -- a match may only start after a space
    end
    for i = 1, m do
        local ni = byte(needle, i)
        local nim1 = i > 1 and byte(needle, i - 1) or nil
        cur[0] = i
        for j = 1, n do
            local hj = byte(hay, j)
            local v = prev[j - 1] + ((ni == hj) and 0 or 1)
            local d = prev[j] + 1
            if d < v then
                v = d
            end
            d = cur[j - 1] + 1
            if d < v then
                v = d
            end
            if prev2 and j > 1 and ni == byte(hay, j - 1) and nim1 == hj then
                d = prev2[j - 2] + 1
                if d < v then
                    v = d
                end
            end
            cur[j] = v
        end
        prev2, prev, cur = prev, cur, prev2 or {}
    end
    for j = 0, n do
        if prev[j] <= 1 then
            return true
        end
    end
    return false
end
Search.nearIn = nearIn

local function nearField(field, w)
    if #w.a < Search.MIN_TYPO_LENGTH then
        return false
    end
    return nearIn(field.a, w.a) or (field.g ~= field.a or w.g ~= w.a) and nearIn(field.g, w.g)
end

-- Does a list of fields match all words?
--   typos  = allow one typo per word
--   detail = also return the fields that contain a word (exact hits; typo hits for words
--            without an exact hit)
-- Returns ok, hits (list of fields, only with detail).
function Search.match(fields, words, typos, detail)
    local hits = detail and {} or nil
    for _, w in ipairs(words) do
        local found = false
        for _, f in ipairs(fields) do
            if exactIn(f, w) then
                found = true
                if not detail then
                    break
                end
                hits[#hits + 1] = f
            end
        end
        if not found and typos then
            for _, f in ipairs(fields) do
                if nearField(f, w) then
                    found = true
                    if not detail then
                        break
                    end
                    hits[#hits + 1] = f
                end
            end
        end
        if not found then
            return false, hits
        end
    end
    return true, hits
end

-- For tests: one text against a query.
function Search.matchText(text, query, typos)
    local f = Search.field("text", text)
    return Search.match(f and { f } or {}, Search.parse(query), typos ~= false) and true or false
end

return Search
