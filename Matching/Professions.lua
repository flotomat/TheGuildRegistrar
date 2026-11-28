-- The Guild Registrar - professions of a character, read from its guild notes (pure Lua 5.1)
--
-- The guild roster of WoW: Forever does not tell an addon the professions of a member, so they are
-- read from the notes ("BB/Schmied", "Alchemist", "Herb + Mining", ...). German and English names
-- and the usual abbreviations are known; the abbreviations from the settings (used for the note
-- templates, placeholder {professions}) are recognized as well.
-- Result: c.professions = { "mining", "blacksmithing" } in the fixed order of Professions.LIST,
-- c.noteProfessions = { public = { [key] = true }, officer = { ... } } per note (for the note check).

local _, ns = ...

local Prof = {}
ns.Professions = Prof

local Text = ns.Text

Prof.LIST = { "alchemy", "blacksmithing", "enchanting", "engineering", "herbalism", "leatherworking",
    "mining", "skinning", "tailoring", "cooking", "fishing", "firstaid" }

-- Built-in words (German and English, full names and common abbreviations).
Prof.KEYWORDS = {
    alchemy = { "Alchemie", "Alchemist", "Alchemistin", "Alchimist", "Alchi", "Alchy", "Alch", "Alchemy" },
    blacksmithing = { "Schmied", "Schmiedin", "Schmiedekunst", "Waffenschmied", "Rüstungsschmied", "BS",
        "Blacksmith", "Blacksmithing", "Smith", "Weaponsmith", "Armorsmith" },
    enchanting = { "VZ", "Verzauberer", "Verzauberin", "Verzauberkunst", "Verzaubern", "Enchanter", "Enchanting",
        "Enchant", "Ench" },
    engineering = { "Ingi", "Ingenieur", "Ingenieurin", "Ingenieurskunst", "Engineer", "Engineering", "Engi", "Eng" },
    herbalism = { "Kräuter", "Kräuterkunde", "Kräutersammler", "Kraut", "Herb", "Herbs", "Herbalism", "Herbalist" },
    leatherworking = { "LW", "LWer", "Leder", "Lederer", "Lederverarbeitung", "Lederverarbeiter", "Leatherworker",
        "Leatherworking" },
    mining = { "BB", "Bergbau", "Bergbauer", "Miner", "Mining" },
    skinning = { "Kürschner", "Kürschnerin", "Kürschnerei", "Kürsch", "Skinner", "Skinning", "Skin" },
    tailoring = { "Schneider", "Schneiderin", "Schneiderei", "Tailor", "Tailoring", "Tail" },
    cooking = { "Koch", "Köchin", "Kochen", "Kochkunst", "Cook", "Cooking" },
    fishing = { "Angeln", "Angler", "Anglerin", "Fishing", "Fisher", "Fish" },
    firstaid = { "EH", "Erste Hilfe", "First Aid", "Firstaid", "FA" },
}

local INDEX = {}
for i, p in ipairs(Prof.LIST) do
    INDEX[p] = i
end

-- Main professions (at most two per character); cooking, fishing and first aid are secondary.
Prof.SECONDARY = { cooking = true, fishing = true, firstaid = true }
Prof.MAX_PRIMARY = 2

function Prof.IsProfession(p)
    return INDEX[p] ~= nil
end

function Prof.IsPrimary(p)
    return INDEX[p] ~= nil and not Prof.SECONDARY[p]
end

-- Known professions in the fixed order, without duplicates.
function Prof.Sort(list)
    local seen, out = {}, {}
    for _, p in ipairs(list or {}) do
        if INDEX[p] and not seen[p] then
            seen[p] = true
            out[#out + 1] = p
        end
    end
    table.sort(out, function(a, b)
        return INDEX[a] < INDEX[b]
    end)
    return out
end

function Prof.Equal(a, b)
    a, b = Prof.Sort(a), Prof.Sort(b)
    if #a ~= #b then
        return false
    end
    for i = 1, #a do
        if a[i] ~= b[i] then
            return false
        end
    end
    return true
end

-- Keyword map from the built-in words plus the abbreviations of the settings.
function Prof.BuildKeywords(abbreviations)
    local lists = {}
    for _, p in ipairs(Prof.LIST) do
        local words = {}
        local own = abbreviations and abbreviations[p]
        if own and ns.Util.trim(own) ~= "" then
            words[1] = own
        end
        for _, w in ipairs(Prof.KEYWORDS[p]) do
            words[#words + 1] = w
        end
        lists[p] = words
    end
    return Text.keywordMap(lists, Prof.LIST)
end

-- Professions named in a text, in the fixed order.
function Prof.Detect(text, keywords)
    local list = Text.findKeywords(text, keywords)
    table.sort(list, function(a, b)
        return INDEX[a] < INDEX[b]
    end)
    return list
end

--[[
ctx = { settings = guild settings (abbreviations), canViewOfficer = bool,
        manual = { [charFullName] = { professions } } (set by an officer, wins over the notes) }
Sets c.professions and c.professionSource ("manual" | "notes" | nil) for every character.
]]
function Prof.Evaluate(rows, ctx)
    local abbr = ctx.settings.abbreviations
    local keywords = Prof.BuildKeywords(abbr and abbr.professions)
    for _, row in ipairs(rows) do
        for _, c in ipairs(ns.Advice.rowChars(row)) do
            local all = {}
            c.noteProfessions = {}
            for kind, text in pairs({ public = c.note, officer = (ctx.canViewOfficer ~= false) and c.officerNote or nil }) do
                local set = {}
                for _, p in ipairs(Prof.Detect(text, keywords)) do
                    set[p] = true
                    all[p] = true
                end
                c.noteProfessions[kind] = set
            end
            local list = {}
            for _, p in ipairs(Prof.LIST) do
                if all[p] then
                    list[#list + 1] = p
                end
            end
            local manual = ctx.manual and ctx.manual[c.fullName]
            if manual then
                c.professions, c.professionSource = Prof.Sort(manual), "manual"
            else
                c.professions, c.professionSource = list, (#list > 0) and "notes" or nil
            end
        end
    end
end
