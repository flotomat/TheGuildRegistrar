-- The Guild Registrar - delete protection: count the manual work an action would remove
--
-- Before an action deletes or overwrites manual decisions of an officer, the UI shows a warning
-- (Dialogs.ShowDeleteWarning) with the counts computed here. All functions return a counts table
-- { [category] = n }; categories without entries are left out. Pure Lua apart from ns.* lookups.

local _, ns = ...

local Protect = {}
ns.Protect = Protect

local SEP = "\001" -- separator of Matcher.pairKey ("memberKey\001charFullName")

-- Display order and localization key of every category.
Protect.CATEGORIES = {
    { key = "links", label = "PROTECT_LINKS" },
    { key = "rejected", label = "PROTECT_REJECTED" },
    { key = "twinkOf", label = "PROTECT_TWINKS" },
    { key = "markedMain", label = "PROTECT_MAINS" },
    { key = "ignoredDiscord", label = "PROTECT_IGNORED_DISCORD" },
    { key = "ignoredChars", label = "PROTECT_IGNORED_CHARS" },
    { key = "dungeonRoles", label = "PROTECT_DUNGEON_ROLES" },
    { key = "professions", label = "PROTECT_PROFESSIONS" },
    { key = "pendingNotes", label = "PROTECT_PENDING_NOTES" },
    { key = "roleMapping", label = "PROTECT_ROLE_MAPPING" },
    { key = "settings", label = "PROTECT_SETTINGS" },
}

local DECISION_LISTS = { "links", "rejected", "twinkOf", "markedMain", "ignoredDiscord", "ignoredChars" }

local function add(counts, key, n)
    if n and n > 0 then
        counts[key] = (counts[key] or 0) + n
    end
    return counts
end

local function size(t)
    local n = 0
    for _ in pairs(t or {}) do
        n = n + 1
    end
    return n
end

-- Sum of all counts.
function Protect.Total(counts)
    local n = 0
    for _, v in pairs(counts or {}) do
        n = n + v
    end
    return n
end

-- Add the counts of `b` to `a` (returns a).
function Protect.Merge(a, b)
    for k, v in pairs(b or {}) do
        add(a, k, v)
    end
    return a
end

-- Decisions of a guild. `which` = nil (all), "decisions" (assignments + alt/main) or "ignored".
function Protect.Decisions(d, which)
    local counts = {}
    if not d then
        return counts
    end
    for _, list in ipairs(DECISION_LISTS) do
        local isIgnore = list == "ignoredDiscord" or list == "ignoredChars"
        if which == nil or (which == "ignored") == isIgnore then
            add(counts, list, size(d[list]))
        end
    end
    return counts
end

-- Manual data of a guild entry that "delete imported data" removes: all decisions plus the
-- stored data of later features (pending notes; manual dungeon roles only with `withRoles`).
function Protect.GuildData(g, withRoles)
    local counts = Protect.Decisions(g and g.decisions)
    if g then
        add(counts, "pendingNotes", Protect.PendingNotes(g))
        if withRoles then
            add(counts, "dungeonRoles", Protect.DungeonRoles(g))
            add(counts, "professions", size(g.professions and g.professions.manual))
        end
    end
    return counts
end

-- Number of prepared guild notes (each public or officer note counts once).
function Protect.PendingNotes(g)
    local n = 0
    for _, p in pairs(g and g.pendingNotes or {}) do
        if type(p) == "table" then
            n = n + (p.public and 1 or 0) + (p.officer and 1 or 0)
        end
    end
    return n
end

-- Number of characters with manually set dungeon roles.
function Protect.DungeonRoles(g)
    return size(g and g.dungeonRoles and g.dungeonRoles.manual)
end

-- Fixed assignments and separations of one Discord member (Engine.ResetMember).
function Protect.Member(d, memberKey)
    local counts = {}
    if not d or not memberKey then
        return counts
    end
    for _, key in pairs(d.links or {}) do
        if key == memberKey then
            add(counts, "links", 1)
        end
    end
    local prefix = memberKey .. SEP
    for k in pairs(d.rejected or {}) do
        if k:sub(1, #prefix) == prefix then
            add(counts, "rejected", 1)
        end
    end
    return counts
end

-- Fixed assignments of `chars` to this member (Engine.Unconfirm, Engine.Unlink).
function Protect.Links(d, memberKey, chars)
    local counts = {}
    for _, c in ipairs(type(chars) == "table" and chars or { chars }) do
        if d and d.links[c] == memberKey then
            add(counts, "links", 1)
        end
    end
    return counts
end

-- Fixed assignments of `chars` to a *different* Discord member (Engine.Confirm overwrites them).
function Protect.OtherLinks(d, memberKey, chars)
    local counts = {}
    for _, c in ipairs(type(chars) == "table" and chars or { chars }) do
        if d and d.links[c] and d.links[c] ~= memberKey then
            add(counts, "links", 1)
        end
    end
    return counts
end

-- Manual alt/main decision of a character (Engine.ResetAltDecision).
function Protect.AltDecision(d, charFullName)
    local counts = {}
    if d then
        add(counts, "twinkOf", d.twinkOf[charFullName] and 1 or 0)
        add(counts, "markedMain", d.markedMain[charFullName] and 1 or 0)
    end
    return counts
end

-- Own decisions that a shared code (Share.Parse result) would overwrite or remove (see Share.Merge).
function Protect.Share(d, parsed, roles, profs)
    local counts = {}
    if not d or not parsed then
        return counts
    end
    for _, e in ipairs(parsed.entries or {}) do
        if e.kind == "L" then
            add(counts, "links", (d.links[e.a] and d.links[e.a] ~= e.b) and 1 or 0)
            add(counts, "rejected", d.rejected[e.b .. SEP .. e.a] and 1 or 0)
        elseif e.kind == "R" then
            add(counts, "links", d.links[e.b] == e.a and 1 or 0)
        elseif e.kind == "T" then
            add(counts, "twinkOf", (d.twinkOf[e.a] and d.twinkOf[e.a] ~= e.b) and 1 or 0)
            add(counts, "markedMain", d.markedMain[e.a] and 1 or 0)
        elseif e.kind == "M" then
            add(counts, "twinkOf", d.twinkOf[e.a] and 1 or 0)
        elseif e.kind == "DR" and roles and roles[e.a] then
            add(counts, "dungeonRoles", ns.DungeonRoles.Equal(roles[e.a], e.roles) and 0 or 1)
        elseif e.kind == "PR" and profs and profs[e.a] then
            add(counts, "professions", ns.Professions.Equal(profs[e.a], e.profs) and 0 or 1)
        end
    end
    return counts
end

local function deepEqual(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then
        return a == b
    end
    for k, v in pairs(a) do
        if not deepEqual(v, b[k]) then
            return false
        end
    end
    for k in pairs(b) do
        if a[k] == nil then
            return false
        end
    end
    return true
end

-- Settings that differ from the defaults (DB.ResetSettings). Every Discord role mapped to a guild
-- rank counts on its own; any other changed setting (a list counts as one) counts once.
function Protect.Settings(settings, defaults)
    local counts = {}
    if not settings then
        return counts
    end
    defaults = defaults or ns.DEFAULT_SETTINGS
    for k, v in pairs(settings) do
        if k == "roleMapping" then
            add(counts, "roleMapping", size(v))
        elseif defaults[k] ~= nil and not deepEqual(v, defaults[k]) then
            add(counts, "settings", 1)
        end
    end
    return counts
end

-- Localized lines "label: n" in display order.
function Protect.Lines(counts)
    local L = ns.L
    local lines = {}
    for _, cat in ipairs(Protect.CATEGORIES) do
        local n = counts and counts[cat.key]
        if n and n > 0 then
            lines[#lines + 1] = string.format("%s: %d", L[cat.label] or cat.key, n)
        end
    end
    return lines
end
