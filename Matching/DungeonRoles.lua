-- The Guild Registrar - dungeon roles (Tank, Healer, Melee DD, Ranged DD) per character (pure Lua 5.1)
--
-- One set of roles for raids and dungeons, up to two per character. Sources, in a configurable
-- order (each can be switched off): manual (set by an officer), Discord (roles of the Discord
-- member - only if the member has exactly one character), officer note, public note.
-- The first source that names a role wins; the other sources are only checked for contradictions.
--
-- What a class can do (no specializations are evaluated):
--   Warrior T/M, Rogue M, Paladin T/H/M, Priest H/R, Mage R, Warlock R, Hunter M/R,
--   Druid T/H/M/R, Shaman H/M/R
-- A generic "DD"/"DPS" is resolved by the class if it has only one kind of DD, otherwise it is a hint.
--
-- Results: c.dungeonRoles = { "tank", ... } (may be empty), c.dungeonRoleSource = source key or nil,
-- c.dungeonAdvice / row.dungeonAdvice = advice entries (see Advice.lua) with codes DROLE_*.

local _, ns = ...

local DR = {}
ns.DungeonRoles = DR

local Text = ns.Text

DR.ROLES = { "tank", "heal", "melee", "ranged" }
DR.SOURCES = { "manual", "discord", "officer", "public" }
DR.MAX = 2

DR.CLASS_ROLES = {
    WARRIOR = { tank = true, melee = true },
    ROGUE = { melee = true },
    PALADIN = { tank = true, heal = true, melee = true },
    PRIEST = { heal = true, ranged = true },
    MAGE = { ranged = true },
    WARLOCK = { ranged = true },
    HUNTER = { melee = true, ranged = true },
    DRUID = { tank = true, heal = true, melee = true, ranged = true },
    SHAMAN = { heal = true, melee = true, ranged = true },
}

local ROLE_INDEX = {}
for i, r in ipairs(DR.ROLES) do
    ROLE_INDEX[r] = i
end

function DR.IsRole(r)
    return ROLE_INDEX[r] ~= nil
end

-- Roles the class can take (all roles for an unknown class).
function DR.ClassAllows(classFile, role)
    local allowed = DR.CLASS_ROLES[classFile or ""]
    return not allowed or allowed[role] == true
end

function DR.ClassRoles(classFile)
    local list = {}
    for _, r in ipairs(DR.ROLES) do
        if DR.ClassAllows(classFile, r) then
            list[#list + 1] = r
        end
    end
    return list
end

-- Roles sorted in the fixed display order, without duplicates.
function DR.Sort(roles)
    local seen, out = {}, {}
    for _, r in ipairs(roles or {}) do
        if ROLE_INDEX[r] and not seen[r] then
            seen[r] = true
            out[#out + 1] = r
        end
    end
    table.sort(out, function(a, b)
        return ROLE_INDEX[a] < ROLE_INDEX[b]
    end)
    return out
end

function DR.Equal(a, b)
    a, b = DR.Sort(a), DR.Sort(b)
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

-- Keywords ------------------------------------------------------------------------------

-- Folded word -> role ("dd" for a generic damage dealer). Built from the settings lists.
function DR.BuildKeywords(lists)
    return Text.keywordMap(lists, { "tank", "heal", "melee", "ranged", "dd" })
end

-- Roles named in a text: { roles = { role = true }, order = { role, ... }, generic = bool }.
-- Every word is checked on its own and together with the next word ("Nahkampf DD", "Melee-DD").
function DR.Detect(text, keywords)
    local found = { roles = {}, order = {}, generic = false }
    for _, role in ipairs(Text.findKeywords(text, keywords)) do
        if role == "dd" then
            found.generic = true
        else
            found.roles[role] = true
            found.order[#found.order + 1] = role
        end
    end
    return found
end

-- Turn detected roles into the roles of a character of `classFile`.
-- Returns roles (list), issues (list of { code, a, b }).
function DR.Resolve(found, classFile)
    local roles, issues = {}, {}
    local seen = {}
    local function take(r)
        if not seen[r] then
            seen[r] = true
            roles[#roles + 1] = r
        end
    end
    for _, r in ipairs(found.order) do
        if DR.ClassAllows(classFile, r) then
            take(r)
        else
            issues[#issues + 1] = { code = "CLASS", role = r }
        end
    end
    if found.generic and not (seen.melee or seen.ranged) then
        local dds = {}
        for _, r in ipairs({ "melee", "ranged" }) do
            if DR.ClassAllows(classFile, r) then
                dds[#dds + 1] = r
            end
        end
        if #dds == 1 then
            take(dds[1])
        elseif #dds > 1 then
            issues[#issues + 1] = { code = "GENERIC" }
        end
    end
    if #roles > DR.MAX then
        issues[#issues + 1] = { code = "TOO_MANY", count = #roles }
        local keep = {}
        for i = 1, DR.MAX do
            keep[i] = roles[i]
        end
        roles = keep
    end
    return DR.Sort(roles), issues
end

-- Evaluation ------------------------------------------------------------------------------

local function sourceList(settings)
    local list = {}
    for _, s in ipairs(settings.dungeonRoleSources or {}) do
        if s.on ~= false and (s.key == "manual" or s.key == "discord" or s.key == "officer" or s.key == "public") then
            list[#list + 1] = s.key
        end
    end
    return list
end

local function rowChars(row)
    return ns.Advice.rowChars(row)
end

--[[
ctx = {
  settings     = guild settings (dungeonRoleSources, dungeonRoleKeywords),
  manual       = { [charFullName] = { roles } },
  canViewOfficer = bool (false: officer notes are not read),
}
]]
function DR.Evaluate(rows, ctx)
    local s = ctx.settings
    local manual = ctx.manual or {}
    local lists = {}
    for key, words in pairs(s.dungeonRoleKeywords or {}) do
        lists[key] = { unpack(words) }
    end
    for role, abbr in pairs(s.abbreviations and s.abbreviations.roles or {}) do
        if lists[role] and ns.Util.trim(abbr) ~= "" then
            table.insert(lists[role], 1, abbr)
        end
    end
    local keywords = DR.BuildKeywords(lists)
    local sources = sourceList(s)
    local enabled = {}
    for _, k in ipairs(sources) do
        enabled[k] = true
    end
    local counts = { tank = 0, heal = 0, melee = 0, ranged = 0, none = 0 }

    for _, row in ipairs(rows) do
        row.dungeonAdvice = {}
        local chars = rowChars(row)
        local hints = row.status ~= "ignored"

        -- Discord roles: only usable for a Discord member with exactly one character
        local discordFound
        if enabled.discord and row.member and #(row.member.roles or {}) > 0 then
            discordFound = DR.Detect(table.concat(row.member.roles, ", "), keywords)
            if not (next(discordFound.roles) or discordFound.generic) then
                discordFound = nil
            elseif #chars ~= 1 then
                if hints and #chars > 1 then
                    row.dungeonAdvice[#row.dungeonAdvice + 1] = { code = "DROLE_DISCORD_MULTI", a = #chars }
                end
                discordFound = nil
            end
        end

        for _, c in ipairs(chars) do
            c.dungeonAdvice = {}
            c.dungeonRoles, c.dungeonRoleSource = {}, nil
            local results = {} -- [source] = roles
            local srcIssues = {}
            -- roles found in each note (also for disabled sources: the note check needs them)
            local noteFound = {
                public = DR.Detect(c.note, keywords),
                officer = (ctx.canViewOfficer ~= false) and DR.Detect(c.officerNote, keywords) or nil,
            }
            c.noteRoles = {}
            for kind, found in pairs(noteFound) do
                local set = {}
                for _, r in ipairs((DR.Resolve(found, c.classFile))) do
                    set[r] = true
                end
                c.noteRoles[kind] = set
            end
            for _, src in ipairs(sources) do
                local roles, issues
                if src == "manual" then
                    local m = manual[c.fullName]
                    if m then
                        roles, issues = DR.Sort(m), {}
                    end
                else
                    local found
                    if src == "discord" then
                        found = discordFound
                    elseif src == "officer" or src == "public" then
                        found = noteFound[src]
                    end
                    if found and (next(found.roles) or found.generic) then
                        roles, issues = DR.Resolve(found, c.classFile)
                    end
                end
                if roles then
                    results[src] = roles
                    srcIssues[src] = issues
                    if not c.dungeonRoleSource and (#roles > 0 or src == "manual") then
                        c.dungeonRoles, c.dungeonRoleSource = roles, src
                    end
                end
            end
            -- hints: problems of the sources, contradictions between sources
            if hints then
                for _, src in ipairs(sources) do
                    for _, issue in ipairs(srcIssues[src] or {}) do
                        -- a generic DD only matters if no source before it decided the roles
                        local relevant = issue.code ~= "GENERIC" or c.dungeonRoleSource == nil
                            or c.dungeonRoleSource == src
                        if relevant then
                            c.dungeonAdvice[#c.dungeonAdvice + 1] = { code = "DROLE_" .. issue.code, method = src,
                                a = issue.role, b = c.className or c.classFile }
                        end
                    end
                end
                local used = c.dungeonRoleSource and results[c.dungeonRoleSource]
                if used then
                    for _, src in ipairs(sources) do
                        local other = results[src]
                        if src ~= c.dungeonRoleSource and other and #other > 0 and not DR.Equal(other, used) then
                            c.dungeonAdvice[#c.dungeonAdvice + 1] = { code = "DROLE_CONFLICT",
                                method = c.dungeonRoleSource, other = src, roles = used, otherRoles = other }
                        end
                    end
                end
            end
            if #c.dungeonRoles == 0 then
                counts.none = counts.none + 1
            end
            for _, r in ipairs(c.dungeonRoles) do
                counts[r] = counts[r] + 1
            end
        end
    end
    return counts
end
