-- The Guild Registrar - localization bootstrap
-- Every language file calls ns.RegisterLocale(code, table).
-- Locales/Apply.lua then builds ns.L: English as base, the client language on top.
-- Missing keys fall back to English, then to the key itself.

local _, ns = ...

ns.Locales = {}

ns.L = setmetatable({}, {
    __index = function(_, key)
        return tostring(key)
    end,
})

function ns.RegisterLocale(code, strings)
    ns.Locales[code] = strings
end
