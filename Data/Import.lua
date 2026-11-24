-- The Guild Registrar - parser for the Discord export format (pure Lua 5.1)
--
-- Format (see docs/import-format.md):
--   #TGR1;<export time UTC>;<server name>
--   @roles;<role 1>,<role 2>,...          (highest role first)
--   <display name>;<role>,<role>,...
-- Backslash escapes the next character (\; \, \\).
-- Lines without header are accepted as well (manual lists: one name per line, roles optional).

local _, ns = ...

local Import = {}
ns.Import = Import

Import.SUPPORTED_VERSIONS = { TGR1 = true }

-- Split by a single-character separator, honoring backslash escapes.
-- keepEscapes = true leaves escape sequences in the fields (for fields that are split again).
local function splitEscaped(s, sep, keepEscapes)
    local fields, buf = {}, {}
    local i, n = 1, #s
    while i <= n do
        local c = s:sub(i, i)
        if c == "\\" and i < n then
            if keepEscapes then
                buf[#buf + 1] = s:sub(i, i + 1)
            else
                buf[#buf + 1] = s:sub(i + 1, i + 1)
            end
            i = i + 2
        else
            if c == sep then
                fields[#fields + 1] = table.concat(buf)
                buf = {}
            else
                buf[#buf + 1] = c
            end
            i = i + 1
        end
    end
    fields[#fields + 1] = table.concat(buf)
    return fields
end
Import.splitEscaped = splitEscaped

local function unescape(s)
    return (s:gsub("\\(.)", "%1"))
end

local function splitRoles(field)
    local roles = {}
    if not field then
        return roles
    end
    for _, r in ipairs(splitEscaped(field, ",")) do
        r = ns.Util.trim(r)
        if r ~= "" then
            roles[#roles + 1] = r
        end
    end
    return roles
end

-- Parse import text.
-- Returns {
--   ok = bool, version, timestamp, server,
--   roles = { ordered role names },        (from @roles, or collected from members)
--   members = { { key, display, roles = {...} } },
--   errors = { { line = n, msg = key, detail = string } },
--   warnings = { { line = n, msg = key, detail = string } },
-- }
-- `msg` values are localization keys.
function Import.parse(text)
    local result = { ok = false, members = {}, roles = {}, errors = {}, warnings = {} }
    local lines = ns.Util.splitLines(text)
    local headerSeen = false
    local seenKeys = {}
    local roleSeen = {}

    for lineNo, rawLine in ipairs(lines) do
        local line = ns.Util.trim(rawLine)
        if line == "" or line:sub(1, 2) == "--" then
            -- skip
        elseif line:sub(1, 1) == "#" then
            if headerSeen then
                result.warnings[#result.warnings + 1] = { line = lineNo, msg = "IMPORT_WARN_SECOND_HEADER" }
            else
                headerSeen = true
                local f = splitEscaped(line:sub(2), ";")
                local version = ns.Util.trim(f[1] or "")
                if not Import.SUPPORTED_VERSIONS[version] then
                    result.errors[#result.errors + 1] = { line = lineNo, msg = "IMPORT_ERR_VERSION", detail = version }
                    return result
                end
                result.version = version
                result.timestamp = ns.Util.trim(f[2] or "")
                result.server = ns.Util.trim(f[3] or "")
            end
        elseif line:sub(1, 1) == "@" then
            local f = splitEscaped(line:sub(2), ";", true)
            local kind = ns.Util.trim(f[1] or ""):lower()
            if kind == "roles" then
                for _, r in ipairs(splitRoles(f[2])) do
                    if not roleSeen[r] then
                        roleSeen[r] = true
                        result.roles[#result.roles + 1] = r
                    end
                end
            else
                result.warnings[#result.warnings + 1] = { line = lineNo, msg = "IMPORT_WARN_UNKNOWN_DIRECTIVE", detail = kind }
            end
        else
            local f = splitEscaped(line, ";", true)
            local display = ns.Util.trim(unescape(f[1] or ""))
            if display == "" then
                result.warnings[#result.warnings + 1] = { line = lineNo, msg = "IMPORT_WARN_EMPTY_NAME" }
            else
                if #f > 2 then
                    result.warnings[#result.warnings + 1] = { line = lineNo, msg = "IMPORT_WARN_EXTRA_FIELDS", detail = display }
                end
                local key = display
                local n = 1
                while seenKeys[key] do
                    n = n + 1
                    key = display .. " #" .. n
                end
                if n > 1 then
                    result.warnings[#result.warnings + 1] = { line = lineNo, msg = "IMPORT_WARN_DUPLICATE", detail = display }
                end
                seenKeys[key] = true
                local roles = splitRoles(f[2])
                result.members[#result.members + 1] = { key = key, display = display, roles = roles }
                for _, r in ipairs(roles) do
                    if not roleSeen[r] then
                        roleSeen[r] = true
                        result.roles[#result.roles + 1] = r
                    end
                end
            end
        end
    end

    if not headerSeen and #result.members > 0 then
        result.warnings[#result.warnings + 1] = { line = 1, msg = "IMPORT_WARN_NO_HEADER" }
    end
    if #result.members == 0 then
        result.errors[#result.errors + 1] = { line = 0, msg = "IMPORT_ERR_EMPTY" }
        return result
    end
    result.ok = true
    return result
end
