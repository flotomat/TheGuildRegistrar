-- The Guild Registrar - share manual decisions between officers (pure Lua 5.1)
--
-- Every officer keeps their own decisions in their saved variables. To share them, the Comparison
-- tab creates a text code that another officer pastes into the Import tab; the decisions are then
-- merged into theirs (shared entries win). Nothing is sent by the addon itself.
--
-- Format (one entry per line, backslash escapes \ ; and , like the Discord export):
--   #TGRD1;<created>;<guild>
--   L;<character>;<Discord name>     character fixed to a Discord member
--   R;<Discord name>;<character>     character separated from a Discord member
--   T;<character>;<main>             character is an alt of a main
--   M;<character>                    character is a main (never an alt)
--   ID;<Discord name>                Discord member ignored
--   IC;<character>                   character ignored
--   DR;<character>[;<role>[;<role>]]  manual dungeon roles (tank, heal, melee, ranged; none = no role)
--   PR;<character>[;<profession>...]  manual professions (alchemy, mining, ...; none = no profession)
-- Characters are full names ("Name-Realm"), Discord names the display names of the import.

local _, ns = ...

local Share = {}
ns.Share = Share

Share.VERSION = "TGRD1"
Share.KINDS = { L = 2, R = 2, T = 2, M = 1, ID = 1, IC = 1, DR = 1, PR = 1 }

local SEP = "\001" -- separator of Matcher.pairKey

local function esc(s)
    return (tostring(s or ""):gsub("[\\;,]", "\\%0"))
end

local function sortedKeys(t)
    local keys = {}
    for k in pairs(t or {}) do
        keys[#keys + 1] = k
    end
    table.sort(keys)
    return keys
end

-- True if the text looks like a decisions code (and not like a Discord export).
function Share.IsCode(text)
    return (text or ""):match("^%s*#%s*TGRD") ~= nil
end

-- Number of decisions in a decisions table (plus manual dungeon roles, if given).
function Share.Count(d, roles, profs)
    local n = 0
    for _ in pairs(roles or {}) do
        n = n + 1
    end
    for _ in pairs(profs or {}) do
        n = n + 1
    end
    for _, list in pairs({ d.links, d.rejected, d.twinkOf, d.markedMain, d.ignoredDiscord, d.ignoredChars }) do
        for _ in pairs(list or {}) do
            n = n + 1
        end
    end
    return n
end

-- Create the code. Returns text, number of entries.
function Share.Export(d, guildName, created, roles, profs)
    local lines = { "#" .. Share.VERSION .. ";" .. esc(created) .. ";" .. esc(guildName) }
    for _, c in ipairs(sortedKeys(d.links)) do
        lines[#lines + 1] = "L;" .. esc(c) .. ";" .. esc(d.links[c])
    end
    for _, k in ipairs(sortedKeys(d.rejected)) do
        local m, c = k:match("^(.-)" .. SEP .. "(.*)$")
        if m then
            lines[#lines + 1] = "R;" .. esc(m) .. ";" .. esc(c)
        end
    end
    for _, c in ipairs(sortedKeys(d.twinkOf)) do
        lines[#lines + 1] = "T;" .. esc(c) .. ";" .. esc(d.twinkOf[c])
    end
    for _, c in ipairs(sortedKeys(d.markedMain)) do
        lines[#lines + 1] = "M;" .. esc(c)
    end
    for _, m in ipairs(sortedKeys(d.ignoredDiscord)) do
        lines[#lines + 1] = "ID;" .. esc(m)
    end
    for _, c in ipairs(sortedKeys(d.ignoredChars)) do
        lines[#lines + 1] = "IC;" .. esc(c)
    end
    for _, c in ipairs(sortedKeys(roles)) do
        local line = "DR;" .. esc(c)
        for _, r in ipairs(roles[c]) do
            line = line .. ";" .. r
        end
        lines[#lines + 1] = line
    end
    for _, c in ipairs(sortedKeys(profs)) do
        local line = "PR;" .. esc(c)
        for _, p in ipairs(profs[c]) do
            line = line .. ";" .. p
        end
        lines[#lines + 1] = line
    end
    return table.concat(lines, "\n"), #lines - 1
end

-- Parse a code. Returns { ok, created, guild, entries = { { kind, a, b } }, counts = { [kind] = n },
-- errors, warnings } with localization keys as messages (like Import.parse).
function Share.Parse(text)
    local r = { ok = false, entries = {}, counts = {}, errors = {}, warnings = {} }
    local split = ns.Import.splitEscaped
    local headerSeen = false
    for lineNo, raw in ipairs(ns.Util.splitLines(text or "")) do
        local line = ns.Util.trim(raw)
        if line == "" or line:sub(1, 2) == "--" then
            -- skip
        elseif line:sub(1, 1) == "#" then
            local f = split(line:sub(2), ";")
            local version = ns.Util.trim(f[1] or "")
            if version ~= Share.VERSION then
                r.errors[#r.errors + 1] = { line = lineNo, msg = "IMPORT_ERR_VERSION", detail = version }
                return r
            end
            headerSeen = true
            r.created = ns.Util.trim(f[2] or "")
            r.guild = ns.Util.trim(f[3] or "")
        else
            local f = split(line, ";")
            local kind = ns.Util.trim(f[1] or ""):upper()
            local need = Share.KINDS[kind]
            local a, b = ns.Util.trim(f[2] or ""), ns.Util.trim(f[3] or "")
            if not need then
                r.warnings[#r.warnings + 1] = { line = lineNo, msg = "IMPORT_WARN_UNKNOWN_DIRECTIVE", detail = kind }
            elseif a == "" or (need == 2 and b == "") then
                r.warnings[#r.warnings + 1] = { line = lineNo, msg = "SHARE_WARN_INCOMPLETE", detail = line }
            elseif kind == "DR" then
                -- dungeon roles: known role keys only, at most two
                local roles, bad = {}, nil
                for i = 3, #f do
                    local role = ns.Util.trim(f[i]):lower()
                    if ns.DungeonRoles.IsRole(role) then
                        if #roles < ns.DungeonRoles.MAX then
                            roles[#roles + 1] = role
                        end
                    elseif role ~= "" then
                        bad = role
                    end
                end
                if bad then
                    r.warnings[#r.warnings + 1] = { line = lineNo, msg = "SHARE_WARN_ROLE", detail = bad }
                end
                r.entries[#r.entries + 1] = { kind = kind, a = a, roles = roles }
                r.counts[kind] = (r.counts[kind] or 0) + 1
            elseif kind == "PR" then
                local list, bad = {}, nil
                for i = 3, #f do
                    local p = ns.Util.trim(f[i]):lower()
                    if ns.Professions.IsProfession(p) then
                        list[#list + 1] = p
                    elseif p ~= "" then
                        bad = p
                    end
                end
                if bad then
                    r.warnings[#r.warnings + 1] = { line = lineNo, msg = "SHARE_WARN_PROFESSION", detail = bad }
                end
                r.entries[#r.entries + 1] = { kind = kind, a = a, profs = list }
                r.counts[kind] = (r.counts[kind] or 0) + 1
            else
                r.entries[#r.entries + 1] = { kind = kind, a = a, b = need == 2 and b or nil }
                r.counts[kind] = (r.counts[kind] or 0) + 1
            end
        end
    end
    if not headerSeen then
        r.errors[#r.errors + 1] = { line = 1, msg = "SHARE_ERR_NO_HEADER" }
        return r
    end
    if #r.entries == 0 then
        r.errors[#r.errors + 1] = { line = 0, msg = "SHARE_ERR_EMPTY" }
        return r
    end
    r.ok = true
    return r
end

-- Merge parsed entries into a decisions table; shared entries win over own ones.
-- Returns the number of entries that changed something.
function Share.Merge(d, parsed, roles, profs)
    local changed = 0
    local function set(list, key, value)
        if list[key] ~= value then
            list[key] = value
            changed = changed + 1
        end
    end
    for _, e in ipairs(parsed.entries) do
        if e.kind == "L" then
            set(d.links, e.a, e.b)
            d.rejected[e.b .. SEP .. e.a] = nil
        elseif e.kind == "R" then
            set(d.rejected, e.a .. SEP .. e.b, true)
            if d.links[e.b] == e.a then
                d.links[e.b] = nil
            end
        elseif e.kind == "T" then
            set(d.twinkOf, e.a, e.b)
            d.markedMain[e.a] = nil
        elseif e.kind == "M" then
            set(d.markedMain, e.a, true)
            d.twinkOf[e.a] = nil
        elseif e.kind == "ID" then
            set(d.ignoredDiscord, e.a, true)
        elseif e.kind == "IC" then
            set(d.ignoredChars, e.a, true)
        elseif e.kind == "DR" and roles then
            local own = roles[e.a]
            if not own or not ns.DungeonRoles.Equal(own, e.roles) then
                roles[e.a] = ns.DungeonRoles.Sort(e.roles)
                changed = changed + 1
            end
        elseif e.kind == "PR" and profs then
            local own = profs[e.a]
            if not own or not ns.Professions.Equal(own, e.profs) then
                profs[e.a] = ns.Professions.Sort(e.profs)
                changed = changed + 1
            end
        end
    end
    return changed
end
