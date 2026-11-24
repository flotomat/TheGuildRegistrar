-- The Guild Registrar - string similarity (pure Lua 5.1)

local _, ns = ...

local Sim = {}
ns.Similarity = Sim

local byte, sub, max, min, floor = string.byte, string.sub, math.max, math.min, math.floor

-- Jaro-Winkler similarity on bytes (inputs are already folded to ASCII-ish forms).
function Sim.jaroWinkler(a, b)
    if a == b then
        return 1
    end
    local la, lb = #a, #b
    if la == 0 or lb == 0 then
        return 0
    end
    local range = max(floor(max(la, lb) / 2) - 1, 0)
    local aMatch, bMatch = {}, {}
    local matches = 0
    for i = 1, la do
        local lo, hi = max(1, i - range), min(lb, i + range)
        local ca = byte(a, i)
        for j = lo, hi do
            if not bMatch[j] and byte(b, j) == ca then
                aMatch[i], bMatch[j] = true, true
                matches = matches + 1
                break
            end
        end
    end
    if matches == 0 then
        return 0
    end
    local t, k = 0, 1
    for i = 1, la do
        if aMatch[i] then
            while not bMatch[k] do
                k = k + 1
            end
            if byte(a, i) ~= byte(b, k) then
                t = t + 1
            end
            k = k + 1
        end
    end
    local m = matches
    local jaro = (m / la + m / lb + (m - t / 2) / m) / 3
    local prefix = 0
    for i = 1, min(4, la, lb) do
        if byte(a, i) == byte(b, i) then
            prefix = prefix + 1
        else
            break
        end
    end
    return jaro + prefix * 0.1 * (1 - jaro)
end

-- Score two folded strings. Returns value (0..1) and kind ("exact" | "prefix" | "similar").
--   exact   : 1.0
--   prefix  : one is the beginning of the other (min. 4 characters), 0.55..0.90
--   similar : Jaro-Winkler >= 0.75 (>= 0.90 for short words), mapped to 0..0.85
function Sim.score(a, b)
    if a == b then
        if #a >= 2 then
            return 1, "exact"
        end
        return 0
    end
    local la, lb = #a, #b
    if la < 3 or lb < 3 then
        return 0
    end
    local short, long = a, b
    if la > lb then
        short, long = b, a
    end
    local ls, ll = #short, #long
    local best, kind = 0, nil
    if ls >= 4 and sub(long, 1, ls) == short then
        best, kind = 0.55 + 0.35 * ls / ll, "prefix"
    end
    local jw = Sim.jaroWinkler(a, b)
    local minJw = (ls < 5) and 0.90 or 0.75
    if jw >= minJw then
        local v = (jw - 0.75) / 0.25 * 0.85
        if v > best then
            best, kind = v, "similar"
        end
    end
    return best, kind
end

-- Compare two forms tables ({a=, g=}); returns the better of both variants.
function Sim.compareForms(f1, f2)
    local v1, k1 = Sim.score(f1.a, f2.a)
    if v1 >= 1 then
        return v1, k1
    end
    if f1.g ~= f1.a or f2.g ~= f2.a then
        local v2, k2 = Sim.score(f1.g, f2.g)
        if v2 > v1 then
            return v2, k2
        end
    end
    return v1, k1
end

-- Combine two independent signals: the stronger one plus half of the remaining gap scaled by the weaker one.
function Sim.combine(hi, lo)
    if lo > hi then
        hi, lo = lo, hi
    end
    return min(1, hi + (1 - hi) * lo * 0.5)
end
