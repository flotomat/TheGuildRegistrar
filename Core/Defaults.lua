-- The Guild Registrar - default settings (pure Lua 5.1)
-- Settings are stored per guild. Lists can be edited in the options tab.

local _, ns = ...

ns.DEFAULT_SETTINGS = {
    -- which guild notes are read
    useNote = true,
    useOfficerNote = true,

    -- optional naming rule for Discord display names, e.g. "Nickname | Main character"
    nameRule = {
        enabled = false,
        separator = "|",
        order = "nick_main", -- "nick_main" | "main_nick" | "any"
    },

    -- twink detection
    twinkByRank = true,
    twinkByNote = true,
    twinkRankNames = { "Twink", "Twinks", "Twinkie", "Alt", "Alts" },
    twinkPatterns = {
        "twink von {main}",
        "twink vom {main}",
        "twink: {main}",
        "twink {main}",
        "{main}s twink",
        "{main}'s twink",
        "{main} twink",
        "alt von {main}",
        "alt of {main}",
        "alt: {main}",
        "alt {main}",
        "{main}'s alt",
        "{main}s alt",
        "main: {main}",
        "main {main}",
        "twink",
        "alt",
    },

    -- Discord roles that mark guests (not expected to be in the guild)
    guestRoleNames = { "Gast", "Gäste", "Guest", "Guests", "Besucher", "Visitor" },

    -- words that are ignored when comparing names and notes (roles, classes, professions, ...)
    stopwords = {
        -- general
        "twink", "twinks", "twinkie", "alt", "alts", "main", "mains", "aka", "dc", "discord", "von", "vom", "of",
        "the", "der", "die", "das", "und", "and", "char", "charakter", "character", "name", "nick", "officer", "offi",
        -- roles
        "heiler", "heal", "heals", "healer", "tank", "tanks", "dd", "dps", "damage", "melee", "nahkampf",
        "range", "ranged", "fernkampf", "caster", "support", "raid", "raider", "pvp", "pve",
        -- classes
        "krieger", "warrior", "magier", "mage", "priester", "priest", "schurke", "rogue", "druide", "druid",
        "jäger", "hunter", "hexenmeister", "hexer", "warlock", "paladin", "pala", "schamane", "schami", "shaman",
        -- specs
        "holy", "heilig", "schatten", "shadow", "feral", "wildheit", "resto", "wiederherstellung", "frost", "feuer",
        "fire", "arkan", "arcane", "schutz", "protection", "prot", "waffen", "arms", "furor", "fury",
        "vergeltung", "ret", "gleichgewicht", "balance", "eule", "moonkin",
        -- professions
        "schmied", "schmiedekunst", "bs", "blacksmith", "blacksmithing", "bb", "bergbau", "mining", "miner",
        "kräuter", "kräuterkunde", "kraut", "herb", "herbalism", "alchemie", "alchi", "alchemist", "alchemy",
        "vz", "verzauberer", "verzauberkunst", "enchanter", "enchanting", "ingi", "ingenieur", "ingenieurskunst",
        "engineer", "engineering", "schneider", "schneiderei", "tailor", "tailoring", "lederer",
        "lederverarbeitung", "lw", "leatherworking", "kürschner", "kürschnerei", "skinning", "skinner",
        "kochen", "koch", "cooking", "angeln", "fishing", "ehs", "firstaid",
    },

    -- classification thresholds
    thresholds = { sure = 0.90, likely = 0.70, unlikely = 0.45, margin = 0.15 },

    -- rank check: Discord role name -> guild rank number (1 = guild master)
    roleMapping = {},
    rankCheckMinStatus = "likely", -- "sure" | "likely" | "unlikely"
    acceptTwinkRanks = true,

    -- writing notes (always only on request + confirmation)
    noteTemplate = "DC: {discord}",
    twinkNoteTemplate = "Twink {main}",
    noteWriteMode = "append", -- "append" | "replace"
}

ns.DEFAULT_FILTERS = {
    status = { confirmed = true, sure = true, likely = true, unlikely = true, unassigned = true, guest = false, ignored = false },
    side = "all", -- "all" | "both" | "discordOnly" | "wowOnly"
    rankMismatch = false,
    ruleIssues = false,
    onlineOnly = false,
    search = "",
    sortKey = "status",
    sortAsc = true,
}
