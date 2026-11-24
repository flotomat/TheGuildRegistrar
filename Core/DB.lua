-- The Guild Registrar - saved variables (per account, data separated per guild)

local _, ns = ...

local DB = {}
ns.DB = DB

DB.VERSION = 1

local Util = ns.Util

-- Migrations from older saved variable versions go here: [fromVersion] = function(db) ... end
local MIGRATIONS = {}

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
    d.confirmed = d.confirmed or {}
    d.rejected = d.rejected or {}
    d.ignoredDiscord = d.ignoredDiscord or {}
    d.ignoredChars = d.ignoredChars or {}
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
        g.decisions.confirmed, g.decisions.rejected = {}, {}
    end
end

function DB.ResetDemo()
    if ns.db then
        ns.db.guilds[ns.Demo.GUILD_KEY] = nil
    end
end
