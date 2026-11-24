-- The Guild Registrar - small helpers (pure Lua 5.1, no WoW API)

local _, ns = ...

local Util = {}
ns.Util = Util

function Util.trim(s)
    return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

function Util.copy(t)
    if type(t) ~= "table" then
        return t
    end
    local r = {}
    for k, v in pairs(t) do
        r[k] = Util.copy(v)
    end
    return r
end

-- Fill missing keys of `target` from `defaults` (recursively). Lists are copied as a whole.
function Util.fillDefaults(target, defaults)
    for k, v in pairs(defaults) do
        if target[k] == nil then
            target[k] = Util.copy(v)
        elseif type(v) == "table" and type(target[k]) == "table" and not Util.isList(v) then
            Util.fillDefaults(target[k], v)
        end
    end
    return target
end

function Util.isList(t)
    if type(t) ~= "table" then
        return false
    end
    local n = 0
    for _ in pairs(t) do
        n = n + 1
    end
    return n > 0 and n == #t
end

function Util.splitLines(text)
    local lines = {}
    text = tostring(text or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
    for line in (text .. "\n"):gmatch("(.-)\n") do
        lines[#lines + 1] = line
    end
    return lines
end

-- Turn a multi-line text into a list of trimmed, non-empty lines.
function Util.linesToList(text)
    local list = {}
    for _, line in ipairs(Util.splitLines(text)) do
        line = Util.trim(line)
        if line ~= "" then
            list[#list + 1] = line
        end
    end
    return list
end

function Util.listToLines(list)
    return table.concat(list or {}, "\n")
end

function Util.round(x, digits)
    local m = 10 ^ (digits or 0)
    return math.floor(x * m + 0.5) / m
end

-- Replace {placeholders} in a template.
function Util.format(template, values)
    return (tostring(template or ""):gsub("{(%w+)}", function(key)
        local v = values[key]
        if v == nil then
            return "{" .. key .. "}"
        end
        return tostring(v)
    end))
end

-- Number of UTF-8 characters in a string.
function Util.utf8len(s)
    local _, count = tostring(s or ""):gsub("[^\128-\191]", "")
    return count
end

-- Cut a string to at most maxBytes bytes without breaking a UTF-8 character.
function Util.utf8truncate(s, maxBytes)
    s = tostring(s or "")
    if #s <= maxBytes then
        return s
    end
    local cut = maxBytes
    while cut > 0 do
        local b = s:byte(cut + 1)
        if not b or b < 128 or b >= 192 then
            break
        end
        cut = cut - 1
    end
    return s:sub(1, cut)
end

-- Stable insertion-safe sort (table.sort is not stable).
function Util.stableSort(list, less)
    for i, v in ipairs(list) do
        v.__order = i
    end
    table.sort(list, function(a, b)
        if less(a, b) then
            return true
        elseif less(b, a) then
            return false
        end
        return a.__order < b.__order
    end)
    for _, v in ipairs(list) do
        v.__order = nil
    end
end
