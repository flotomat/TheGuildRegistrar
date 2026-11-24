-- The Guild Registrar - rank check Discord role -> guild rank (pure Lua 5.1)
--
-- The highest mapped Discord role of a member defines the expected guild rank.
-- "Highest" follows the Discord role order from the export (@roles line).
-- Main and twinks are checked the same way; optionally twinks may also hold a twink rank.

local _, ns = ...

local Ranks = {}
ns.Ranks = Ranks

local Text = ns.Text

-- Determine the expected rank for a list of Discord roles.
-- Returns rankNumber, roleName (or nil if no role is mapped).
function Ranks.expected(roles, roleOrder, roleMapping)
    local pos = {}
    for i, r in ipairs(roleOrder or {}) do
        pos[r] = i
    end
    local bestPos, bestRank, bestRole
    for i, r in ipairs(roles or {}) do
        local rank = roleMapping[r]
        if rank then
            local p = pos[r] or (1000 + i)
            if not bestPos or p < bestPos then
                bestPos, bestRank, bestRole = p, rank, r
            end
        end
    end
    return bestRank, bestRole
end

--[[
ctx = {
  roleOrder        = { role names, highest first },
  roleMapping      = { [roleName] = rankNumber },     (rank 1 = guild master)
  twinkRankNames   = { ... },
  acceptTwinkRanks = bool,
  minStatus        = "sure" | "likely" | "unlikely",
}
Sets row.rank = { state = "ok" | "mismatch" | "unmapped" | "skipped", expected, role, issues = { {char, actual, actualName, dir} } }
]]
function Ranks.evaluate(rows, ctx)
    local twinkSet = Text.wordSet(ctx.twinkRankNames)
    local minLevel = ns.Matcher.STATUS_LEVEL[ctx.minStatus or "likely"] or 2
    local stats = { ok = 0, mismatch = 0, unmapped = 0 }

    for _, row in ipairs(rows) do
        row.rank = nil
        local m, p = row.member, row.player
        if m and p then
            local level = ns.Matcher.STATUS_LEVEL[row.status] or 0
            if level < minLevel then
                row.rank = { state = "skipped" }
            else
                local expected, role = Ranks.expected(m.roles, ctx.roleOrder, ctx.roleMapping)
                if not expected then
                    row.rank = { state = "unmapped" }
                    stats.unmapped = stats.unmapped + 1
                else
                    local info = { state = "ok", expected = expected, role = role, issues = {} }
                    local chars = {}
                    for _, c in ipairs(p.chars) do
                        chars[#chars + 1] = c
                    end
                    for _, ex in ipairs(row.extras or {}) do
                        for _, c in ipairs(ex.player.chars) do
                            chars[#chars + 1] = c
                        end
                    end
                    for _, c in ipairs(chars) do
                        local okRank = (c.rank == expected)
                        if not okRank and c.isTwink and ctx.acceptTwinkRanks and c.rankName and twinkSet[Text.key(c.rankName)] then
                            okRank = true
                        end
                        if not okRank then
                            info.issues[#info.issues + 1] = {
                                char = c, actual = c.rank, actualName = c.rankName,
                                dir = (c.rank or 99) < expected and "high" or "low",
                            }
                        end
                    end
                    if #info.issues > 0 then
                        info.state = "mismatch"
                        stats.mismatch = stats.mismatch + 1
                    else
                        stats.ok = stats.ok + 1
                    end
                    row.rank = info
                end
            end
        end
    end
    return stats
end
