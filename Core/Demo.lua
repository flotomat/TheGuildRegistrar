-- The Guild Registrar - demo data (pure Lua 5.1)
-- "/tgr demo" loads a fictional guild and Discord export so the addon can be tried without a guild.

local _, ns = ...

local Demo = {}
ns.Demo = Demo

Demo.GUILD_KEY = "__demo__"

Demo.RANKS = { "Gildenmeister", "Offizier", "Raider", "Mitglied", "Twink", "Neuling" }

Demo.IMPORT = table.concat({
    "#TGR1;2026-11-24T20:00:00Z;Demo-Server",
    "@roles;Gildenleitung,Offizier,Raider,Mitglied,Austauschschüler,Gast,Tank,Heiler,DD",
    "Jens | Wurstinator;Raider,Tank",
    "Fluffy | Rolf;Offizier,Heiler",
    "Anna | Gamblergirl;Raider",
    "MatroseHirnlos | Rüdiger;Mitglied",
    "BauchHaengeSchwein | Jan-Lars;Mitglied",
    "MotzHard Nils;Raider,DD",
    "KörperKlaus;Mitglied,DD",
    "Tina | Sonnenblume;Gildenleitung,Raider,Heiler",
    "Rolfine | Kerstin;Mitglied",
    "Besucher Bob;Gast",
    "Austausch Ali;Austauschschüler",
    "Neu Hier;Mitglied",
}, "\n")

local function char(name, rank, classFile, level, note, officerNote, online)
    return {
        name = name, rank = rank, classFile = classFile, level = level,
        note = note or "", officerNote = officerNote or "", online = online or false,
    }
end

Demo.ROSTER = {
    char("Wurstinator", 3, "WARRIOR", 60, "Wursti", "Tank", true),
    char("Wurstbrot", 5, "MAGE", 34, "Twink von Wurstinator", ""),
    char("Heilkraut", 4, "PRIEST", 40, "Heiler", "DC: Jens"),
    char("Rolf", 2, "PALADIN", 60, "Fluffy, Tank", "DC: Fluffy", true),
    char("Gamblergirl", 4, "PRIEST", 60, "Anna, Heiler", ""),
    char("Annaheal", 5, "DRUID", 42, "Anna Twink", ""),
    char("Rüdiger", 4, "WARLOCK", 58, "Schweini, BB/Schmied", ""),
    char("Motzhard", 3, "ROGUE", 60, "", "Nils", true),
    char("Körperklaus", 4, "HUNTER", 51, "", ""),
    char("Sonnenblume", 1, "DRUID", 60, "Tina", "Gildenleitung", true),
    char("Rolfine", 4, "SHAMAN", 27, "Kerstin, Tank", ""),
    char("Jeanlars", 4, "WARRIOR", 19, "Jan-Lars, DD", ""),
    char("Ohnediscord", 4, "HUNTER", 60, "Ingi, Fernkampf", ""),
    char("Mysteriös", 5, "ROGUE", 12, "Twink", ""),
}

-- Settings that differ from the defaults in the demo.
Demo.SETTINGS = {
    nameRule = { enabled = true, separator = "|", order = "nick_main" },
    guestRoleNames = { "Gast", "Gäste", "Guest", "Guests", "Besucher", "Visitor", "Austauschschüler" },
    roleMapping = { ["Gildenleitung"] = 1, ["Offizier"] = 2, ["Raider"] = 3, ["Mitglied"] = 4 },
}

-- Build roster entries in the same shape as Data/Roster.lua produces.
function Demo.buildRoster()
    local list = {}
    for i, c in ipairs(Demo.ROSTER) do
        list[#list + 1] = {
            index = i,
            name = c.name,
            fullName = c.name .. "-Demo",
            realm = "Demo",
            rank = c.rank,
            rankName = Demo.RANKS[c.rank],
            level = c.level,
            classFile = c.classFile,
            className = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[c.classFile]) or c.classFile,
            note = c.note,
            officerNote = c.officerNote,
            online = c.online,
            guid = "demo-" .. i,
        }
    end
    return list
end
