-- The Guild Registrar - saved variables (per account, data separated per guild)

local _, ns = ...

local DB = {}
ns.DB = DB

DB.VERSION = 2

local Util = ns.Util

-- Migrations from older saved variable versions go here: [fromVersion] = function(db) ... end
local MIGRATIONS = {
    -- 1 -> 2: a Discord account can own several characters. Confirmations were stored per Discord
    -- member (confirmed[memberKey] = charFullName); now every character has its own fixed
    -- assignment (links[charFullName] = memberKey).
    [1] = function(db)
        for _, g in pairs(db.guilds or {}) do
            local d = g.decisions
            if d and d.confirmed then
                d.links = d.links or {}
                for memberKey, charFullName in pairs(d.confirmed) do
                    d.links[charFullName] = d.links[charFullName] or memberKey
                end
                d.confirmed = nil
            end
        end
    end,
}

function DB.Init()
    TheGuildRegistrarDB = TheGuildRegistrarDB or {}
    local db = TheGuildRegistrarDB
    db.version = db.version or DB.VERSION
    while db.version < DB.VERSION do
        local step = MIGRATIONS[db.version]
        if step then
            step(db)
        end
        db.version = db.version + 1
    end
    db.guilds = db.guilds or {}
    db.ui = db.ui or {}
    db.ui.filters = Util.fillDefaults(db.ui.filters or {}, ns.DEFAULT_FILTERS)
    Util.fillDefaults(db.ui.filters.status, ns.DEFAULT_FILTERS.status)
    ns.db = db
end

-- Key of the current guild ("Guild-Realm"), the demo key in demo mode, or nil.
function DB.GuildKey()
    if ns.demoActive then
        return ns.Demo.GUILD_KEY
    end
    if not IsInGuild or not IsInGuild() then
        return nil
    end
    local name, _, _, realm = GetGuildInfo("player")
    if not name then
        return nil
    end
    realm = realm or (GetNormalizedRealmName and GetNormalizedRealmName()) or (GetRealmName and GetRealmName()) or ""
    return name .. "-" .. realm
end

function DB.GuildName()
    if ns.demoActive then
        return "Demo"
    end
    local name = IsInGuild and IsInGuild() and GetGuildInfo("player")
    return name
end

local function ensureDecisions(g)
    g.decisions = g.decisions or {}
    local d = g.decisions
    d.links = d.links or {}           -- [charFullName] = memberKey (fixed by an officer)
    d.rejected = d.rejected or {}     -- [memberKey .. "\001" .. charFullName] = true (separated)
    d.ignoredDiscord = d.ignoredDiscord or {}
    d.ignoredChars = d.ignoredChars or {}
    d.twinkOf = d.twinkOf or {}       -- [charFullName] = mainFullName (alt assigned by an officer)
    d.markedMain = d.markedMain or {} -- [charFullName] = true (never an alt)
end

-- Data of the current guild (created on first use).
function DB.Guild()
    local key = DB.GuildKey()
    if not key or not ns.db then
        return nil
    end
    local g = ns.db.guilds[key]
    if not g then
        g = {}
        ns.db.guilds[key] = g
        if key == ns.Demo.GUILD_KEY then
            g.settings = Util.copy(ns.DEFAULT_SETTINGS)
            for k, v in pairs(ns.Demo.SETTINGS) do
                g.settings[k] = Util.copy(v)
            end
            local parsed = ns.Import.parse(ns.Demo.IMPORT)
            g.import = { members = parsed.members, roles = parsed.roles, server = parsed.server,
                timestamp = parsed.timestamp, importedAt = time() }
        end
    end
    g.settings = Util.fillDefaults(g.settings or {}, ns.DEFAULT_SETTINGS)
    ensureDecisions(g)
    ns.SetAltTerm(g.settings.altTerm)
    return g, key
end

function DB.ResetSettings()
    local g = DB.Guild()
    if g then
        g.settings = Util.copy(ns.DEFAULT_SETTINGS)
    end
end

function DB.ClearDecisions(which)
    local g = DB.Guild()
    if not g then
        return
    end
    if which == "ignored" then
        g.decisions.ignoredDiscord, g.decisions.ignoredChars = {}, {}
    else
        g.decisions.links, g.decisions.rejected = {}, {}
        g.decisions.twinkOf, g.decisions.markedMain = {}, {}
    end
end

-- True if a guild entry holds Discord data (imported list or any decision - they contain Discord names).
function DB.HasDiscordData(g)
    if not g then
        return false
    end
    if g.import then
        return true
    end
    local d = g.decisions
    if not d then
        return false
    end
    for _, list in pairs(d) do
        if type(list) == "table" and next(list) then
            return true
        end
    end
    return false
end

-- Keys ("Guild-Realm") of all real guilds (not the demo) that hold Discord data, sorted.
function DB.GuildsWithData()
    local keys = {}
    if ns.db and ns.db.guilds then
        for key, g in pairs(ns.db.guilds) do
            if key ~= ns.Demo.GUILD_KEY and DB.HasDiscordData(g) then
                keys[#keys + 1] = key
            end
        end
    end
    table.sort(keys)
    return keys
end

local function clearDiscordData(g)
    g.import = nil
    g.decisions = nil
    ensureDecisions(g)
end

-- Delete all Discord data of the current guild: the imported list and every decision
-- (they contain Discord names). Settings such as the rank mapping are kept.
function DB.DeleteImportedData()
    local g = DB.Guild()
    if not g then
        return false
    end
    clearDiscordData(g)
    return true
end

-- Delete the Discord data of every guild on this account (not the demo). Settings are kept.
-- Returns the number of guilds whose data was deleted.
function DB.DeleteAllImportedData()
    local keys = DB.GuildsWithData()
    for _, key in ipairs(keys) do
        clearDiscordData(ns.db.guilds[key])
    end
    return #keys
end

function DB.ResetDemo()
    if ns.db then
        ns.db.guilds[ns.Demo.GUILD_KEY] = nil
    end
end
