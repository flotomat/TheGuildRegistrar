-- The Guild Registrar - change the guild rank of a character (only on explicit request + confirmation)
--
-- WoW: Forever reserves rank changes for the Blizzard UI (C_GuildInfo.Promote/Demote are protected,
-- C_GuildInfo.SetGuildRankOrder carries the same restriction as C_GuildInfo.SetNote, which Forever
-- refuses for addons). The menu entry is therefore shown greyed out while ns.FEATURES.changeRank is
-- false. The code is kept for clients that allow it.

local _, ns = ...

local RankChange = {}
ns.RankChange = RankChange

function RankChange.IsAvailable()
    return ns.FEATURES.changeRank and true or false
end

-- Whether the player may give `rank` (1 = guild master) to the character.
function RankChange.CanSet(char, rank)
    if not RankChange.IsAvailable() then
        return false
    end
    if ns.demoActive then
        return rank ~= 1
    end
    if not char or not char.guid or rank == char.rank then
        return false
    end
    if C_GuildInfo and C_GuildInfo.IsGuildRankAssignmentAllowed then
        return C_GuildInfo.IsGuildRankAssignmentAllowed(char.guid, rank) and true or false
    end
    if rank < (char.rank or 0) then
        return CanGuildPromote and CanGuildPromote() and true or false
    end
    return CanGuildDemote and CanGuildDemote() and true or false
end

-- Set the rank. Returns ok, errorKey.
function RankChange.Set(char, rank)
    if not RankChange.CanSet(char, rank) then
        return false, "RANK_ERR_PERMISSION"
    end
    if ns.demoActive then
        local entry = ns.Demo.ROSTER[char.index]
        if entry then
            entry.rank = rank
            return true
        end
        return false, "NOTE_ERR_NOT_FOUND"
    end
    if C_GuildInfo and C_GuildInfo.SetGuildRankOrder then
        C_GuildInfo.SetGuildRankOrder(char.guid, rank)
        return true
    end
    return false, "RANK_ERR_API"
end
