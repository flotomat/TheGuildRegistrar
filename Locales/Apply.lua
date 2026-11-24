-- The Guild Registrar - apply the active locale (must be loaded after all language files)
--
-- Strings may contain the placeholders {Alt}, {Alts}, {alt} and {alts}. They are replaced by the
-- term chosen in the options ("Twink" or "Alt", see ns.SetAltTerm).

local _, ns = ...

local raw = {}

local PLACEHOLDERS = {
    Alt = "ONE", Alts = "MANY", alt = "ONE_LOWER", alts = "MANY_LOWER",
}

local function substitute()
    local L = ns.L
    local term = (ns.altTerm == "alt") and "ALT" or "TWINK"
    local words = {}
    for ph, suffix in pairs(PLACEHOLDERS) do
        words[ph] = raw["TERM_" .. term .. "_" .. suffix] or ph
    end
    for k, v in pairs(raw) do
        if type(v) == "string" and v:find("{", 1, true) then
            L[k] = (v:gsub("{(%a+)}", words))
        else
            L[k] = v
        end
    end
end

local function apply(code)
    local L = ns.L
    for k in pairs(L) do
        L[k] = nil
    end
    for k in pairs(raw) do
        raw[k] = nil
    end
    local base = ns.Locales.enUS or {}
    for k, v in pairs(base) do
        raw[k] = v
    end
    local loc = ns.Locales[code]
    if loc and loc ~= base then
        for k, v in pairs(loc) do
            raw[k] = v
        end
    end
    ns.activeLocale = loc and code or "enUS"
    substitute()
end

ns.ApplyLocale = apply

-- Switch the term for alternative characters ("twink" | "alt") and update registered UI texts.
function ns.SetAltTerm(term)
    term = (term == "alt") and "alt" or "twink"
    if ns.altTerm == term then
        return false
    end
    ns.altTerm = term
    substitute()
    if ns.W and ns.W.RefreshLocalized then
        ns.W.RefreshLocalized()
    end
    return true
end

ns.altTerm = (GetLocale and GetLocale() == "deDE") and "twink" or "alt"
local clientLocale = (GetLocale and GetLocale()) or "enUS"
apply(clientLocale)
