-- The Guild Registrar - text normalization and tokenization (pure Lua 5.1)
--
-- Every comparable piece of text is turned into "forms":
--   forms.a = lower case, accents folded the simple way   (ä -> a, ß -> ss)
--   forms.g = lower case, accents folded the German way   (ä -> ae, ö -> oe, ü -> ue)
-- Comparisons always compare a<->a and g<->g, so "Hänge" matches "Haenge" and "Hange".

local _, ns = ...

local Text = {}
ns.Text = Text

local byte, char, gsub, lower = string.byte, string.char, string.gsub, string.lower

-- Lower case incl. Latin-1 supplement (U+00C0..U+00DE -> U+00E0..U+00FE, except ×).
local function lowerUtf8(s)
    s = lower(s)
    s = gsub(s, "\195([\128-\158])", function(c)
        local b = byte(c)
        if b == 151 then
            return nil
        end
        return "\195" .. char(b + 32)
    end)
    return s
end
Text.lower = lowerUtf8

-- Second byte of the lower case Latin-1 letters (after \195) -> ASCII replacement.
local FOLD_SIMPLE = {
    [159] = "ss",
    [160] = "a", [161] = "a", [162] = "a", [163] = "a", [164] = "a", [165] = "a", [166] = "ae", [167] = "c",
    [168] = "e", [169] = "e", [170] = "e", [171] = "e", [172] = "i", [173] = "i", [174] = "i", [175] = "i",
    [176] = "d", [177] = "n", [178] = "o", [179] = "o", [180] = "o", [181] = "o", [182] = "o", [184] = "o",
    [185] = "u", [186] = "u", [187] = "u", [188] = "u", [189] = "y", [190] = "th", [191] = "y",
}
local FOLD_GERMAN = {}
for k, v in pairs(FOLD_SIMPLE) do
    FOLD_GERMAN[k] = v
end
FOLD_GERMAN[164] = "ae"
FOLD_GERMAN[182] = "oe"
FOLD_GERMAN[188] = "ue"

local function fold(s, map)
    return (gsub(s, "\195([\128-\191])", function(c)
        return map[byte(c)]
    end))
end

-- Remove emojis, symbols, punctuation blocks and invisible characters (they become spaces).
local function stripSymbols(s)
    s = gsub(s, "[\240-\244][\128-\191][\128-\191][\128-\191]", " ") -- 4-byte: emojis etc.
    s = gsub(s, "\239\184[\128-\143]", "")                          -- variation selectors
    s = gsub(s, "\239\187\191", "")                                 -- BOM / zero width no-break space
    s = gsub(s, "[\226][\128-\191][\128-\191]", " ")                -- U+2000..U+2FFF: punctuation, symbols, dingbats
    s = gsub(s, "\227\128[\128-\191]", " ")                         -- CJK punctuation
    s = gsub(s, "\194[\128-\191]", " ")                             -- U+0080..U+00BF: nbsp, «», ·, ©, ...
    s = gsub(s, "\195[\151\183]", " ")                              -- × ÷
    return s
end
Text.stripSymbols = stripSymbols

-- Only keep letters/digits (ASCII + any remaining multi-byte letters).
local function compact(s)
    return (gsub(s, "[^%w\128-\255]", ""))
end

-- Build comparable forms of a raw word.
function Text.forms(raw)
    local l = lowerUtf8(raw or "")
    return {
        a = compact(fold(l, FOLD_SIMPLE)),
        g = compact(fold(l, FOLD_GERMAN)),
    }
end

-- Fold an arbitrary text to a single lower case ASCII-ish string (used for lookups by name).
function Text.key(raw)
    return Text.forms(raw).a
end

-- Build a set (folded keys) from a list of words.
function Text.wordSet(list)
    local set = {}
    for _, w in ipairs(list or {}) do
        local f = Text.forms(w)
        if f.a ~= "" then
            set[f.a] = true
        end
        if f.g ~= "" then
            set[f.g] = true
        end
    end
    return set
end

local function isStop(forms, stopset)
    return stopset and (stopset[forms.a] or stopset[forms.g]) or false
end

-- Split CamelCase words: "BauchHaengeSchwein" -> {"Bauch", "Haenge", "Schwein"}
local function camelParts(word)
    local spaced = gsub(word, "(%l)(%u)", "%1 %2")
    spaced = gsub(spaced, "(\195[\160-\191])(%u)", "%1 %2")
    spaced = gsub(spaced, "(%l)(\195[\128-\158])", "%1 %2")
    local parts = {}
    for p in spaced:gmatch("%S+") do
        parts[#parts + 1] = p
    end
    return parts
end

-- Tokenize a free text into word tokens.
-- Returns a list of { raw = "Word", forms = {a=,g=}, secondary = bool }.
-- Secondary tokens are parts of CamelCase or hyphenated words and count a little less.
function Text.tokenize(text, stopset)
    local tokens = {}
    local seen = {}
    local function add(raw, secondary)
        local f = Text.forms(raw)
        if #f.a < 2 or isStop(f, stopset) then
            return
        end
        local key = f.a .. (secondary and "#2" or "#1")
        if seen[f.a .. "#1"] or seen[key] then
            return
        end
        seen[key] = true
        tokens[#tokens + 1] = { raw = raw, forms = f, secondary = secondary or false }
    end

    local cleaned = stripSymbols(tostring(text or ""))
    for word in cleaned:gmatch("[%w\128-\255%-]+") do
        word = gsub(gsub(word, "^%-+", ""), "%-+$", "")
        if word ~= "" then
            add(word, false)
            if word:find("-", 1, true) then
                for part in word:gmatch("[^%-]+") do
                    add(part, true)
                end
            end
            local parts = camelParts(word)
            if #parts > 1 then
                for _, part in ipairs(parts) do
                    if #part >= 3 then
                        add(part, true)
                    end
                end
            end
        end
    end
    return tokens
end

-- Analyze a Discord display name.
-- rule = { enabled = bool, separator = "|", order = "nick_main" | "main_nick" | "any" }
-- Returns {
--   display, tokens (each token may carry part = "nick" | "main"),
--   concat = forms of all primary tokens glued together,
--   rule = { applies = bool, ok = bool, mainRaw = "...", nickRaw = "..." }
-- }
function Text.analyzeDiscordName(display, rule, stopset)
    local result = { display = display, tokens = {}, rule = { applies = false } }

    local parts
    if rule and rule.enabled and rule.separator and rule.separator ~= "" then
        result.rule.applies = true
        parts = {}
        local s = display
        local sep = rule.separator
        local pos = 1
        while true do
            local i = s:find(sep, pos, true)
            if not i then
                parts[#parts + 1] = s:sub(pos)
                break
            end
            parts[#parts + 1] = s:sub(pos, i - 1)
            pos = i + #sep
        end
        for i = #parts, 1, -1 do
            if ns.Util.trim(stripSymbols(parts[i])) == "" then
                table.remove(parts, i)
            end
        end
        result.rule.ok = (#parts == 2)
        if result.rule.ok then
            local first, second = ns.Util.trim(parts[1]), ns.Util.trim(parts[2])
            if rule.order == "main_nick" then
                result.rule.mainRaw, result.rule.nickRaw = first, second
            elseif rule.order == "nick_main" then
                result.rule.nickRaw, result.rule.mainRaw = first, second
            else
                result.rule.nickRaw, result.rule.mainRaw = first, second
                result.rule.anyOrder = true
            end
        end
    end

    if result.rule.applies and result.rule.ok then
        local mainTokens = Text.tokenize(result.rule.mainRaw, stopset)
        local nickTokens = Text.tokenize(result.rule.nickRaw, stopset)
        for _, t in ipairs(mainTokens) do
            t.part = "main"
            result.tokens[#result.tokens + 1] = t
        end
        for _, t in ipairs(nickTokens) do
            t.part = "nick"
            result.tokens[#result.tokens + 1] = t
        end
    else
        result.tokens = Text.tokenize(display, stopset)
    end

    local ca, cg = {}, {}
    for _, t in ipairs(result.tokens) do
        if not t.secondary then
            ca[#ca + 1] = t.forms.a
            cg[#cg + 1] = t.forms.g
        end
    end
    result.concat = { a = table.concat(ca), g = table.concat(cg) }
    result.primaryCount = #ca
    return result
end

-- Search forms -------------------------------------------------------------------------
-- The search is more forgiving than the matching: accent marks and apostrophes vanish
-- ("Ka'thar" -> "kathar", "Dårk" -> "dark"), Latin Extended-A letters are folded as well
-- ("Łukasz" -> "lukasz"), everything else that is not a letter or digit separates words.

-- Latin Extended-A (U+0100..U+017F) -> ASCII, by code point
local EXT_A = {}
local function extRange(from, to, rep)
    for cp = from, to do
        EXT_A[cp] = rep
    end
end
extRange(0x100, 0x105, "a")
extRange(0x106, 0x10D, "c")
extRange(0x10E, 0x111, "d")
extRange(0x112, 0x11B, "e")
extRange(0x11C, 0x123, "g")
extRange(0x124, 0x127, "h")
extRange(0x128, 0x131, "i")
extRange(0x132, 0x133, "ij")
extRange(0x134, 0x135, "j")
extRange(0x136, 0x138, "k")
extRange(0x139, 0x142, "l")
extRange(0x143, 0x14B, "n")
extRange(0x14C, 0x151, "o")
extRange(0x152, 0x153, "oe")
extRange(0x154, 0x159, "r")
extRange(0x15A, 0x161, "s")
extRange(0x162, 0x167, "t")
extRange(0x168, 0x173, "u")
extRange(0x174, 0x175, "w")
extRange(0x176, 0x178, "y")
extRange(0x179, 0x17E, "z")
extRange(0x17F, 0x17F, "s")

local function foldExtA(b1, b2)
    return EXT_A[(byte(b1) - 192) * 64 + (byte(b2) - 128)]
end

-- Remove accent marks and apostrophes (they must not split a word).
local function stripMarks(s)
    s = gsub(s, "\204[\128-\191]", "")                  -- combining marks U+0300..U+033F
    s = gsub(s, "\205[\128-\175]", "")                  -- combining marks U+0340..U+036F
    s = gsub(s, "\194[\168\180\184]", "")               -- ¨ ´ ¸
    s = gsub(s, "\202[\185-\191]", "")                  -- modifier letters incl. ʼ (U+02B9..U+02BF)
    s = gsub(s, "\203[\128-\159]", "")                  -- ˆ ˇ ˘ ˙ ˚ ˛ ˜ ˝ (U+02C0..U+02DF)
    s = gsub(s, "\226\128[\152-\155\178-\180]", "")     -- ‘ ’ ‚ ‛ ′ ″ ‴
    s = gsub(s, "['`%^]", "")
    return s
end

local function searchFold(s, map)
    s = fold(s, map)
    s = gsub(s, "([\196\197])([\128-\191])", foldExtA)
    s = stripSymbols(s)
    s = gsub(s, "[^%w\128-\255]+", " ")
    return (gsub(gsub(s, "^ +", ""), " +$", ""))
end

-- Text prepared for the search. Returns {
--   a  = words folded the simple way (ä -> a), separated by single spaces,
--   g  = words folded the German way (ä -> ae),
--   ca, cg = the same without spaces (finds "Wurst Inator" when searching "wurstinator"),
-- }. Both variants always have the same number of words.
function Text.searchForms(raw)
    local l = stripMarks(lowerUtf8(tostring(raw or "")))
    local a = searchFold(l, FOLD_SIMPLE)
    local g = searchFold(l, FOLD_GERMAN)
    return { a = a, g = g, ca = gsub(a, " ", ""), cg = gsub(g, " ", "") }
end

-- Keyword detection (dungeon roles, professions) ------------------------------------------

-- Folded word -> value, from { [value] = { words } }. `keys` gives the order (first one wins on
-- duplicates). Words may contain spaces ("Erste Hilfe"); they are matched as word pairs.
function Text.keywordMap(lists, keys)
    local map = {}
    for _, value in ipairs(keys) do
        for _, word in ipairs(lists and lists[value] or {}) do
            local f = Text.searchForms(word)
            for _, form in ipairs({ f.a, f.g, f.ca, f.cg }) do
                if form ~= "" and not map[form] then
                    map[form] = value
                end
            end
        end
    end
    return map
end

-- Values of the keywords in a text, in order of appearance, without duplicates. Every word is
-- checked together with the next word first ("Nahkampf DD", "Erste Hilfe"), then on its own;
-- parts of words never match ("Tankwart" is no "Tank").
function Text.findKeywords(text, map)
    local out, seen = {}, {}
    if not text or text == "" then
        return out
    end
    local forms = Text.searchForms(text)
    for _, spaced in ipairs({ forms.a, forms.g }) do
        local words = {}
        for w in spaced:gmatch("%S+") do
            words[#words + 1] = w
        end
        local i = 1
        while i <= #words do
            local pair = words[i + 1] and map[words[i] .. words[i + 1]]
            local value = pair or map[words[i]]
            if value and not seen[value] then
                seen[value] = true
                out[#out + 1] = value
            end
            i = i + (pair and 2 or 1)
        end
    end
    return out
end

-- The "nickname" part of a Discord name for note templates.
function Text.nickname(analysis)
    if analysis.rule and analysis.rule.ok and analysis.rule.nickRaw then
        return analysis.rule.nickRaw
    end
    for _, t in ipairs(analysis.tokens) do
        if not t.secondary then
            return t.raw
        end
    end
    return analysis.display
end
