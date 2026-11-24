-- The Guild Registrar - apply the active locale (must be loaded after all language files)

local _, ns = ...

local function apply(code)
    local L = ns.L
    for k in pairs(L) do
        L[k] = nil
    end
    local base = ns.Locales.enUS or {}
    for k, v in pairs(base) do
        L[k] = v
    end
    local loc = ns.Locales[code]
    if loc and loc ~= base then
        for k, v in pairs(loc) do
            L[k] = v
        end
    end
    ns.activeLocale = loc and code or "enUS"
end

ns.ApplyLocale = apply

local clientLocale = (GetLocale and GetLocale()) or "enUS"
apply(clientLocale)
