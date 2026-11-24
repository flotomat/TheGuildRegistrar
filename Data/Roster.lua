-- The Guild Registrar - read the guild roster from the game

local _, ns = ...

local Roster = {}
ns.Roster = Roster

local restoreShowOffline = false

-- Ask the server for fresh roster data (answer arrives as GUILD_ROSTER_UPDATE).
function Roster.Request()
    if ns.demoActive then
        return
    end
    -- Older client APIs only list offline members when "show offline" is enabled.
    if GetGuildRosterShowOffline and SetGuildRosterShowOffline and not GetGuildRosterShowOffline() then
        SetGuildRosterShowOffline(true)
        restoreShowOffline = true
    end
    if C_GuildInfo and C_GuildInfo.GuildRoster then
        C_GuildInfo.GuildRoster()
    elseif GuildRoster then
        GuildRoster()
    end
end

local function currentRealm()
    return (GetNormalizedRealmName and GetNormalizedRealmName()) or (GetRealmName and GetRealmName():gsub("%s", "")) or ""
end

function Roster.CanViewOfficerNote()
    if ns.demoActive then
        return true
    end
    if C_GuildInfo and C_GuildInfo.CanViewOfficerNote then
        return C_GuildInfo.CanViewOfficerNote() and true or false
    end
    if CanViewOfficerNote then
        return CanViewOfficerNote() and true or false
    end
    return false
end

-- Guild rank names, index 1 = guild master.
function Roster.RankNames()
    if ns.demoActive then
        return ns.Util.copy(ns.Demo.RANKS)
    end
    local ranks = {}
    local n = GuildControlGetNumRanks and GuildControlGetNumRanks() or 0
    for i = 1, n do
        ranks[i] = GuildControlGetRankName(i)
    end
    return ranks
end

-- Returns the list of characters (see Matching/Players.lua for the shape) or nil if not available.
function Roster.Read()
    if ns.demoActive then
        return ns.Demo.buildRoster()
    end
    if not IsInGuild or not IsInGuild() then
        return nil
    end
    local realmNow = currentRealm()
    local list = {}
    local n = GetNumGuildMembers() or 0
    for i = 1, n do
        local name, rankName, rankIndex, level, className, _, note, officerNote, online, _, classFile,
            _, _, _, _, _, guid = GetGuildRosterInfo(i)
        if name then
            local short, realm = name:match("^([^%-]+)%-(.+)$")
            short = short or name
            realm = realm or realmNow
            list[#list + 1] = {
                index = i,
                name = short,
                fullName = short .. "-" .. realm,
                realm = realm,
                rank = (rankIndex or 0) + 1,
                rankName = rankName,
                level = level,
                className = className,
                classFile = classFile,
                note = note or "",
                officerNote = officerNote or "",
                online = online and true or false,
                guid = guid,
            }
        end
    end
    if restoreShowOffline and SetGuildRosterShowOffline then
        restoreShowOffline = false
        SetGuildRosterShowOffline(false)
    end
    return list
end

-- Find the current roster index of a character (indexes change when the roster updates).
function Roster.FindIndex(fullName)
    local n = GetNumGuildMembers and GetNumGuildMembers() or 0
    local realmNow = currentRealm()
    for i = 1, n do
        local name = GetGuildRosterInfo(i)
        if name then
            local full = name:find("-", 1, true) and name or (name .. "-" .. realmNow)
            if full == fullName then
                return i
            end
        end
    end
    return nil
end
