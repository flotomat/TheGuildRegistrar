-- The Guild Registrar - "Results" tab: filterable list of all assignments
--
-- Each Discord member / guild player is one row. Players with alts get a [+] button at the left;
-- it unfolds the alts as indented child rows below the main.

local _, ns = ...

local L = ns.L
local W = ns.W
local Matcher = ns.Matcher

local COLUMNS = {
    { key = "expand", title = "", width = 22 },
    { key = "status", title = "COL_STATUS", width = 100 },
    { key = "discord", title = "COL_DISCORD", width = 160 },
    { key = "char", title = "COL_CHARACTER", width = 160 },
    { key = "roles", title = "COL_DUNGEON_ROLES", width = 46 },
    { key = "profs", title = "COL_PROFESSIONS", width = 76 },
    { key = "notes", title = "COL_NOTES", width = 162 },
    { key = "rank", title = "COL_RANK", width = 124 },
    { key = "hints", title = "COL_HINTS", width = 140 },
}

local ROW_HEIGHT = 20
local NOTE_BUTTONS = { "public", "officer", "auto" } -- icon buttons at the right end of the notes column
local NOTE_BUTTON_SIZE = 14
local COL_INDEX = {}
for i, col in ipairs(COLUMNS) do
    COL_INDEX[col.key] = i
end
local INDENT = 18

-- folded players (by player id). Everything is unfolded whenever the window opens; the officer
-- folds the players already checked.
local collapsed = {}

local function filters()
    return ns.db.ui.filters
end

local function settings()
    local g = ns.DB.Guild()
    return g and g.settings or ns.DEFAULT_SETTINGS
end

-- Characters ------------------------------------------------------------------------

-- Alts shown below a row: all characters of the row except the main.
local function altChars(row)
    local list = {}
    if not row.player then
        return list
    end
    for _, c in ipairs(ns.Advice.rowChars(row)) do
        if c ~= row.player.main then
            list[#list + 1] = c
        end
    end
    return list
end

local function rowKey(row)
    return row.player and row.player.id or nil
end

local function isOpen(row)
    local key = rowKey(row)
    return not (key and collapsed[key])
end

-- Advice texts ------------------------------------------------------------------------

local function adviceText(e)
    local code = e.code
    local key = "ADV_" .. code
    if code == "ALT_MARK" then
        key = "ADV_ALT_MARK_" .. (e.method or "note"):upper()
        return string.format(L[key], e.a or "?", e.note or "")
    elseif code == "MAIN_MARK" then
        key = (e.method == "rank") and "ADV_MAIN_MARK_RANK" or "ADV_MAIN_MARK_NOTE"
    elseif code == "ORPHAN" and e.a then
        key = "ADV_ORPHAN_REF"
    elseif code == "NOTE_EXPECTED" then
        key = (e.method == "officer") and "ADV_NOTE_EXPECTED_OFFICER" or "ADV_NOTE_EXPECTED_PUBLIC"
    elseif code == "DROLE_CLASS" then
        return string.format(L.ADV_DROLE_CLASS, W.RoleNames({ e.a }),
            L["DROLE_SOURCE_" .. (e.method or "public"):upper()], tostring(e.b or "?"))
    elseif code == "DROLE_GENERIC" or code == "DROLE_TOO_MANY" then
        return string.format(L["ADV_" .. code], L["DROLE_SOURCE_" .. (e.method or "public"):upper()])
    elseif code == "DROLE_CONFLICT" then
        return string.format(L.ADV_DROLE_CONFLICT,
            L["DROLE_SOURCE_" .. (e.method or "manual"):upper()], W.RoleNames(e.roles),
            L["DROLE_SOURCE_" .. (e.other or "public"):upper()], W.RoleNames(e.otherRoles))
    end
    return string.format(L[key], tostring(e.a or "?"), tostring(e.b or "?"))
end

local function adviceShort(e)
    return L["ADV_SHORT_" .. e.code]
end

-- All advice entries of a row: { { entry, char or nil } }
local function rowAdvice(row)
    local list = {}
    for _, e in ipairs(row.advice or {}) do
        list[#list + 1] = { e = e }
    end
    for _, c in ipairs(ns.Advice.rowChars(row)) do
        for _, e in ipairs(c.advice or {}) do
            list[#list + 1] = { e = e, char = c }
        end
    end
    return list
end

local function shortList(entries)
    local seen, out = {}, {}
    for _, item in ipairs(entries) do
        local s = adviceShort(item.e or item)
        if not seen[s] then
            seen[s] = true
            out[#out + 1] = s
        end
    end
    return table.concat(out, ", ")
end

-- Full hint texts of a row (used by export); alts are prefixed with their name.
local function hintList(row)
    local list = {}
    for _, item in ipairs(rowAdvice(row)) do
        local t = adviceText(item.e)
        if item.char and row.player and item.char ~= row.player.main then
            t = item.char.name .. ": " .. t
        end
        list[#list + 1] = t
    end
    return list
end

-- Text helpers -------------------------------------------------------------------

local function statusText(status)
    return W.Colorize(L["STATUS_" .. status:upper()], W.STATUS_COLORS[status] or { 1, 1, 1 })
end

local function charText(c)
    local name = W.Colorize(c.name, W.ClassColor(c.classFile))
    if c.online then
        name = name .. " " .. W.ICON_ONLINE
    end
    return name
end

local function playerText(row)
    local p = row.player
    if not p then
        return "|cff777777-|r"
    end
    local s = charText(p.main) .. string.format(" |cff888888%s|r", p.main.level or "")
    local n = #altChars(row)
    if n > 0 then
        s = s .. string.format(" |cff33dd33(+%d)|r", n)
    end
    return s
end

-- Which notes take part in the assignment (the officer note only if the rank may read it).
local function notesUsed()
    local s = settings()
    return s.useNote and true or false, (s.useOfficerNote and ns.state.canViewOfficer ~= false) and true or false
end

-- Notes of a character; notes that are not used for the assignment are shown in grey. A prepared
-- (pending) note is shown in gold instead of the current one.
local function notesText(c)
    if not c then
        return ""
    end
    local usePublic, useOfficer = notesUsed()
    local parts = {}
    local pubPending, offPending = ns.PendingNotes.Get(c.fullName, "public"), ns.PendingNotes.Get(c.fullName, "officer")
    if pubPending or offPending then
        if pubPending then
            parts[#parts + 1] = "|cffffd100" .. pubPending .. "|r"
        elseif c.note and c.note ~= "" then
            parts[#parts + 1] = usePublic and c.note or ("|cff666666" .. c.note .. "|r")
        end
        if offPending then
            parts[#parts + 1] = "|cffffd100" .. offPending .. "|r"
        elseif c.officerNote and c.officerNote ~= "" then
            parts[#parts + 1] = (useOfficer and "|cff88aaff" or "|cff556070") .. c.officerNote .. "|r"
        end
        return table.concat(parts, " · ")
    end
    if c.note and c.note ~= "" then
        parts[#parts + 1] = usePublic and c.note or ("|cff666666" .. c.note .. "|r")
    end
    if c.officerNote and c.officerNote ~= "" then
        parts[#parts + 1] = (useOfficer and "|cff88aaff" or "|cff556070") .. c.officerNote .. "|r"
    end
    return table.concat(parts, " · ")
end

-- The attached group a character belongs to (nil for the main group of the row).
local function extraOf(row, c)
    for _, ex in ipairs(row.extras or {}) do
        if ex.player == c.player then
            return ex
        end
    end
    return nil
end

local function rankIssue(row, c)
    if row.rank and row.rank.state == "mismatch" then
        for _, issue in ipairs(row.rank.issues) do
            if issue.char == c then
                return issue
            end
        end
    end
    return nil
end

-- Rank column for one character of a row.
local function charRankText(row, c)
    local r = row.rank
    local name = c.rankName or ""
    if not r or r.state == "skipped" then
        return "|cff999999" .. name .. "|r"
    end
    if rankIssue(row, c) then
        local expectedName = ns.state.rankNames[r.expected] or ("#" .. r.expected)
        return W.ICON_BAD .. " " .. name .. " -> " .. expectedName
    elseif r.state == "unmapped" then
        return W.ICON_UNKNOWN .. " " .. name
    end
    return W.ICON_OK .. " " .. name
end

local function rankText(row)
    if not row.player then
        return ""
    end
    local s = charRankText(row, row.player.main)
    -- the main is fine, but alts are not
    if row.rank and row.rank.state == "mismatch" and not rankIssue(row, row.player.main) then
        s = s .. string.format(" |cffff6666(%d %s)|r", #row.rank.issues, L.TOOLTIP_TWINK)
    end
    return s
end

local function sideText(row)
    if row.side == "discordOnly" then
        return L.SIDE_DISCORD_ONLY
    elseif row.side == "wowOnly" then
        return L.SIDE_WOW_ONLY
    end
    return nil
end

local function altReasonText(c, row)
    if row and row.player and c.player ~= row.player then
        return L.TOOLTIP_ALT_REASON_DISCORD
    elseif c.manualTwink then
        return L.TOOLTIP_ALT_REASON_MANUAL
    elseif c.twinkReason == "rank" then
        return L.TOOLTIP_ALT_REASON_RANK
    elseif c.twinkReason == "note" then
        return L.TOOLTIP_ALT_REASON_NOTE
    end
    return nil
end

-- Filtering and sorting --------------------------------------------------------------

-- Search (fuzzy, over all columns; see Matching/Search.lua) ----------------------------

-- Searchable fields per row, built on first use. Rows are new tables after every comparison
-- run, so the cache never holds outdated texts.
local searchIndex = setmetatable({}, { __mode = "k" })
-- current query: words, typo tolerance and a generation counter for the per-row result cache
local search = { query = nil, words = {}, typos = true, gen = 0 }
-- show search hits even if other filters hide them (switched by the hint next to the notes row)
local showAllHits = false

local FIELD_LABELS = {
    status = "COL_STATUS", discord = "SEARCH_FIELD_DISCORD", roles = "SEARCH_FIELD_ROLES",
    char = "COL_CHARACTER", realm = "SEARCH_FIELD_REALM", note = "SEARCH_FIELD_NOTE",
    officerNote = "SEARCH_FIELD_OFFICER_NOTE", rank = "COL_RANK", class = "SEARCH_FIELD_CLASS",
    level = "SEARCH_FIELD_LEVEL", hints = "COL_HINTS", dungeonRoles = "COL_DUNGEON_ROLES",
    professions = "TOOLTIP_PROFESSIONS",
}

local function rowFields(row)
    local idx = searchIndex[row]
    if idx then
        return idx
    end
    local fields = {}
    local function add(key, text, owner)
        local fld = ns.Search.field(key, text, owner)
        if fld then
            fields[#fields + 1] = fld
        end
    end
    add("status", L["STATUS_" .. row.status:upper()])
    add("status", sideText(row))
    if row.member then
        add("discord", row.member.display)
        add("roles", table.concat(row.member.roles, " "))
    end
    local main = row.player and row.player.main
    for _, c in ipairs(ns.Advice.rowChars(row)) do
        local owner = (c ~= main) and c or nil
        add("char", c.name, owner)
        add("realm", c.realm, owner)
        add("note", c.note, owner)
        add("officerNote", c.officerNote, owner)
        add("rank", c.rankName, owner)
        add("class", c.className, owner)
        add("level", c.level and tostring(c.level), owner)
        add("dungeonRoles", W.RoleNames(c.dungeonRoles), owner)
        add("professions", W.ProfessionNames(c.professions), owner)
    end
    for _, item in ipairs(rowAdvice(row)) do
        local owner = (item.char and item.char ~= main) and item.char or nil
        add("hints", tostring(adviceShort(item.e) or "") .. " " .. adviceText(item.e), owner)
    end
    idx = { fields = fields }
    searchIndex[row] = idx
    return idx
end

local function setQuery(text)
    local q = ns.Util.trim(text or "")
    local typos = settings().searchTypos ~= false
    if q ~= search.query or typos ~= search.typos then
        search.query, search.typos = q, typos
        search.words = (q ~= "") and ns.Search.parse(q) or {}
        search.gen = search.gen + 1
    end
    return #search.words > 0
end

local function isSearching()
    return #search.words > 0
end

local function matchesSearch(row)
    if not isSearching() then
        return true
    end
    local idx = rowFields(row)
    if idx.gen ~= search.gen then
        idx.gen = search.gen
        idx.ok = ns.Search.match(idx.fields, search.words, search.typos) and true or false
    end
    return idx.ok
end

-- Fields of a row that contain one of the search words.
local function searchHits(row)
    if not isSearching() then
        return {}
    end
    local _, hits = ns.Search.match(rowFields(row).fields, search.words, search.typos, true)
    return hits or {}
end

-- "Found in" text for the tooltip; `char` limits it to the fields of one alt.
local function foundInText(row, char)
    local seen, parts = {}, {}
    for _, fld in ipairs(searchHits(row)) do
        if char == nil or fld.owner == char then
            local label = L[FIELD_LABELS[fld.key] or "COL_STATUS"]
            if fld.owner and char == nil then
                label = label .. " (" .. fld.owner.name .. ")"
            end
            if not seen[label] then
                seen[label] = true
                parts[#parts + 1] = label
            end
        end
    end
    return table.concat(parts, ", ")
end

local function isOnline(row)
    for _, c in ipairs(ns.Advice.rowChars(row)) do
        if c.online then
            return true
        end
    end
    return false
end

local ROLE_ORDER = { tank = 1, heal = 2, melee = 3, ranged = 4 }

local function sortValue(row, key)
    if key == "status" then
        return Matcher.STATUS_ORDER[row.status] or 9
    elseif key == "discord" then
        return row.member and ns.Text.key(row.member.display) or "~"
    elseif key == "char" then
        return row.player and ns.Text.key(row.player.main.name) or "~"
    elseif key == "notes" then
        return row.player and ns.Text.key(row.player.main.note or "") or "~"
    elseif key == "rank" then
        local r = row.rank
        local order = { mismatch = 1, unmapped = 2, ok = 3, skipped = 4 }
        return r and order[r.state] or 5
    elseif key == "hints" then
        return -#rowAdvice(row)
    elseif key == "profs" then
        local list = row.player and row.player.main.professions
        return (list and list[1]) and ns.Text.key(table.concat(list, " ")) or "~"
    elseif key == "roles" then
        local r = row.player and row.player.main.dungeonRoles
        return (r and r[1]) and (ROLE_ORDER[r[1]] * 10 + (r[2] and ROLE_ORDER[r[2]] or 0)) or 99
    end
    return 0
end

-- Profession filter: a row matches if one of its characters has the profession ("none": the main has none).
local function matchesProfession(row, prof)
    if prof == "all" or not prof then
        return true
    end
    if not row.player then
        return false
    end
    if prof == "none" then
        return #(row.player.main.professions or {}) == 0
    end
    for _, c in ipairs(ns.Advice.rowChars(row)) do
        for _, p in ipairs(c.professions or {}) do
            if p == prof then
                return true
            end
        end
    end
    return false
end

-- Dungeon role filter: a row matches if one of its characters has the role ("none": the main has none).
local function matchesRole(row, role)
    if role == "all" or not role then
        return true
    end
    if not row.player then
        return false
    end
    if role == "none" then
        return #(row.player.main.dungeonRoles or {}) == 0
    end
    for _, c in ipairs(ns.Advice.rowChars(row)) do
        for _, r in ipairs(c.dungeonRoles or {}) do
            if r == role then
                return true
            end
        end
    end
    return false
end

local function filteredRows()
    local res = ns.state.results
    if not res then
        return {}
    end
    local f = filters()
    local searching = setQuery(f.search)
    if not searching then
        showAllHits = false
    end
    local out = {}
    local hidden = 0 -- search hits hidden by the other filters
    for _, row in ipairs(res.rows) do
        local hit = matchesSearch(row)
        local ok = hit and f.status[row.status]
        if ok and f.side ~= "all" and row.side ~= f.side then
            ok = false
        end
        if ok and f.rankMismatch and not (row.rank and row.rank.state == "mismatch") then
            ok = false
        end
        if ok and f.ruleIssues and not row.hasAdvice then
            ok = false
        end
        if ok and f.onlineOnly and not isOnline(row) then
            ok = false
        end
        if ok and not matchesRole(row, f.dungeonRole) then
            ok = false
        end
        if ok and not matchesProfession(row, f.profession) then
            ok = false
        end
        if searching and hit and not ok then
            if showAllHits then
                ok = true
            else
                hidden = hidden + 1
            end
        end
        if ok then
            out[#out + 1] = row
        end
    end
    local key, asc = f.sortKey or "status", f.sortAsc ~= false
    if key == "expand" then
        key = "status"
    end
    ns.Util.stableSort(out, function(a, b)
        local va, vb = sortValue(a, key), sortValue(b, key)
        if va == vb then
            local sa, sb = sortValue(a, "discord"), sortValue(b, "discord")
            if sa == sb then
                return sortValue(a, "char") < sortValue(b, "char")
            end
            return sa < sb
        end
        if asc then
            return va < vb
        end
        return va > vb
    end)

    -- insert unfolded alts below their main (a search that hits an alt unfolds it, too)
    local items = {}
    for _, row in ipairs(out) do
        items[#items + 1] = row
        local alts = altChars(row)
        if #alts > 0 then
            local open = isOpen(row)
            if not open and searching then
                for _, fld in ipairs(searchHits(row)) do
                    if fld.owner then
                        open = true
                        break
                    end
                end
            end
            if open then
                for _, c in ipairs(alts) do
                    items[#items + 1] = { kind = "child", row = row, char = c }
                end
            end
        end
    end
    return items, out, hidden
end

-- Tooltip ----------------------------------------------------------------------------

local function reasonText(r)
    if not r then
        return nil
    end
    local src = L["SOURCE_" .. (r.source or "name"):upper()]
    local kind = L["KIND_" .. (r.kind or "exact"):upper()]
    return string.format(L.REASON_FORMAT, r.word or "?", src, r.target or "?", kind, r.value * 100)
end

local function addCharLines(c, label)
    GameTooltip:AddDoubleLine(label .. ": " .. charText(c) .. string.format(" |cffaaaaaa(%s)|r", c.level or "?"),
        c.rankName or "", 1, 1, 1, 0.8, 0.8, 0.8)
    local usePublic, useOfficer = notesUsed()
    local unused = " |cff888888(" .. L.TOOLTIP_NOTE_UNUSED .. ")|r"
    if c.note and c.note ~= "" then
        GameTooltip:AddLine("   " .. L.NOTE_PUBLIC .. ": " .. c.note .. (usePublic and "" or unused), 0.9, 0.9, 0.9, true)
    end
    if c.officerNote and c.officerNote ~= "" then
        GameTooltip:AddLine("   " .. L.NOTE_OFFICER .. ": " .. c.officerNote .. (useOfficer and "" or unused), 0.55, 0.7, 1, true)
    end
    if c.professionSource then
        local names = #(c.professions or {}) > 0 and W.ProfessionNames(c.professions) or L.PROF_NONE
        GameTooltip:AddLine(string.format("   %s: %s |cff888888(%s)|r", L.TOOLTIP_PROFESSIONS, names,
            L["PROF_SOURCE_" .. c.professionSource:upper()]), 0.9, 0.9, 0.9, true)
    end
    for _, kind in ipairs({ "public", "officer" }) do
        local pending = ns.PendingNotes.Get(c.fullName, kind)
        if pending then
            GameTooltip:AddLine(string.format("   %s %s: %s", W.NoteIcon(kind, 12),
                (kind == "officer") and L.PENDING_TOOLTIP_OFFICER or L.PENDING_TOOLTIP_PUBLIC, pending), 1, 0.82, 0, true)
        end
    end
    if c.dungeonRoleSource then
        local names = #(c.dungeonRoles or {}) > 0 and W.RoleNames(c.dungeonRoles, true) or L.DROLE_NONE
        GameTooltip:AddLine(string.format("   %s: %s |cff888888(%s)|r", L.COL_DUNGEON_ROLES_LONG, names,
            L["DROLE_SOURCE_" .. c.dungeonRoleSource:upper()]), 0.9, 0.9, 0.9, true)
    end
end

local function addAdviceLines(entries, row)
    if #entries == 0 then
        return
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L.TOOLTIP_ADVICE, 1, 0.82, 0)
    for _, item in ipairs(entries) do
        local t = adviceText(item.e)
        if item.char and row and row.player and item.char ~= row.player.main then
            t = item.char.name .. ": " .. t
        end
        GameTooltip:AddLine("- " .. t, 1, 0.7, 0.3, true)
    end
end

-- The tooltip sits a little to the right of the cursor so the hand pointer does not cover it.
local TOOLTIP_OFFSET_X, TOOLTIP_OFFSET_Y = 24, 0

local function showRowTooltip(owner, row)
    GameTooltip:SetOwner(owner, "ANCHOR_CURSOR_RIGHT", TOOLTIP_OFFSET_X, TOOLTIP_OFFSET_Y)
    GameTooltip:AddLine(statusText(row.status) .. (row.score and row.status ~= "confirmed"
        and string.format("  |cffaaaaaa%d%%|r", row.score * 100) or ""))
    if row.status == "confirmed" then
        GameTooltip:AddLine(L.TOOLTIP_FIXED, 0.3, 0.85, 1)
    end
    local side = sideText(row)
    if side then
        GameTooltip:AddLine(side, 1, 0.6, 0.6)
    end
    local found = isSearching() and foundInText(row) or ""
    if found ~= "" then
        GameTooltip:AddLine(L.TOOLTIP_FOUND_IN .. " " .. found, 0.4, 1, 0.4, true)
    end
    if row.member then
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine(L.COL_DISCORD, row.member.display, 0.6, 0.8, 1, 1, 1, 1)
        if #row.member.roles > 0 then
            GameTooltip:AddLine(L.TOOLTIP_ROLES .. ": " .. table.concat(row.member.roles, ", "), 0.8, 0.8, 0.8, true)
        end
    end
    if row.player then
        GameTooltip:AddLine(" ")
        for _, c in ipairs(ns.Advice.rowChars(row)) do
            addCharLines(c, (c == row.player.main) and L.TOOLTIP_MAIN or L.TOOLTIP_TWINK)
        end
    end
    if row.reasons then
        local any = false
        for _, r in pairs(row.reasons) do
            local t = reasonText(r)
            if t then
                if not any then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine(L.TOOLTIP_REASONS, 1, 0.82, 0)
                    any = true
                end
                GameTooltip:AddLine("  " .. t, 0.9, 0.9, 0.9, true)
            end
        end
    end
    if row.rank and row.rank.state == "mismatch" then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(string.format(L.TOOLTIP_RANK_EXPECTED, row.rank.role,
            ns.state.rankNames[row.rank.expected] or row.rank.expected), 1, 0.4, 0.4, true)
        for _, issue in ipairs(row.rank.issues) do
            GameTooltip:AddLine(string.format("  %s: %s (%s)", issue.char.name, issue.actualName or "?",
                issue.dir == "high" and L.RANK_TOO_HIGH or L.RANK_TOO_LOW), 1, 0.6, 0.6)
        end
    elseif row.rank and row.rank.state == "unmapped" then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L.TOOLTIP_RANK_UNMAPPED, 0.7, 0.7, 0.7, true)
    end
    -- only the hints of this line: the main character (or the Discord member); alts have their own lines
    local own, altCount = {}, 0
    for _, e in ipairs(row.advice or {}) do
        own[#own + 1] = { e = e }
    end
    local main = row.player and row.player.main
    for _, c in ipairs(ns.Advice.rowChars(row)) do
        if c == main then
            for _, e in ipairs(c.advice or {}) do
                own[#own + 1] = { e = e }
            end
        elseif #(c.advice or {}) > 0 then
            altCount = altCount + 1
        end
    end
    addAdviceLines(own, row)
    if altCount > 0 then
        if #own == 0 then
            GameTooltip:AddLine(" ")
        end
        GameTooltip:AddLine(string.format(L.TOOLTIP_ADVICE_ALTS, altCount), 1, 0.6, 0.3, true)
    end
    if #row.alternatives > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L.TOOLTIP_ALTERNATIVES, 1, 0.82, 0)
        for _, alt in ipairs(row.alternatives) do
            local name = alt.player and alt.player.main.name or (alt.member and alt.member.display) or "?"
            GameTooltip:AddDoubleLine("  " .. name, string.format("%d%%", alt.score * 100), 0.9, 0.9, 0.9, 0.7, 0.7, 0.7)
        end
    end
    GameTooltip:AddLine(" ")
    if #altChars(row) > 0 then
        GameTooltip:AddLine(L.TOOLTIP_EXPAND, 0.5, 0.5, 0.5, true)
    end
    GameTooltip:AddLine(L.TOOLTIP_RIGHTCLICK, 0.5, 0.5, 0.5)
    GameTooltip:Show()
end

local function showChildTooltip(owner, item)
    local row, c = item.row, item.char
    GameTooltip:SetOwner(owner, "ANCHOR_CURSOR_RIGHT", TOOLTIP_OFFSET_X, TOOLTIP_OFFSET_Y)
    addCharLines(c, L.TOOLTIP_TWINK)
    local found = isSearching() and foundInText(row, c) or ""
    if found ~= "" then
        GameTooltip:AddLine(L.TOOLTIP_FOUND_IN .. " " .. found, 0.4, 1, 0.4, true)
    end
    local ex = extraOf(row, c)
    if ex then
        GameTooltip:AddLine(statusText(ex.status) .. (ex.status ~= "confirmed" and ex.score
            and string.format("  |cffaaaaaa%d%%|r", ex.score * 100) or ""))
    end
    local main = row.player and row.player.main
    if main then
        local reason = altReasonText(c, row)
        GameTooltip:AddLine(string.format(L.TOOLTIP_ALT_OF, main.name) .. (reason and (" (" .. reason .. ")") or ""),
            0.8, 0.8, 0.8, true)
    end
    if row.member then
        GameTooltip:AddDoubleLine(L.COL_DISCORD, row.member.display, 0.6, 0.8, 1, 1, 1, 1)
    end
    local entries = {}
    for _, e in ipairs(c.advice or {}) do
        entries[#entries + 1] = { e = e }
    end
    addAdviceLines(entries)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L.TOOLTIP_RIGHTCLICK, 0.5, 0.5, 0.5)
    GameTooltip:Show()
end

-- Context menu ------------------------------------------------------------------------

local function whisper(name)
    local fn = (ChatFrameUtil and ChatFrameUtil.SendTell) or ChatFrame_SendTell
    if fn then
        fn(name)
    else
        ns.Engine.Print(L.WHISPER_UNAVAILABLE)
    end
end

local function assignAlt(c, mainFullName)
    local ok, err = ns.Engine.SetAltOf(c.fullName, mainFullName)
    if ok then
        local target = ns.Engine.FindChar(mainFullName)
        ns.Engine.Print(string.format(L.ALT_ASSIGNED, c.name, target and target.name or mainFullName))
    elseif err then
        ns.Engine.Print(L[err])
    end
end

-- Find a character of the current results by (short or full) name.
local function findCharByName(name)
    local res = ns.state.results
    local key = ns.Text.key(name)
    for _, r in ipairs(res and res.rows or {}) do
        for _, c in ipairs(ns.Advice.rowChars(r)) do
            if ns.Text.key(c.name) == key or ns.Text.key(c.fullName) == key then
                return c
            end
        end
    end
    return nil
end

-- The context menu always lists every action. Actions that are not possible for an entry are greyed
-- out; their tooltip says why.

-- Menu entry: enabled with `func`, or greyed out with the reason `na`.
local function entry(text, func, na)
    if na then
        return { text = text, disabled = true, tooltip = na, tooltipTitle = text }
    end
    return { text = text, func = func }
end

local function section(text)
    return { text = "|cffffd100" .. text .. "|r", isTitle = true }
end

-- Mains of all groups shown with a row (the main group and attached groups).
local function rowMains(row)
    local list = {}
    if row.player then
        list[#list + 1] = row.player.main.fullName
    end
    for _, ex in ipairs(row.extras or {}) do
        list[#list + 1] = ex.player.main.fullName
    end
    return list
end

-- True if character `c` is held in this row by a fixed assignment (its own or that of its group main).
local function currentDecisions()
    local g = ns.DB.Guild()
    return g and g.decisions
end

local function isFixed(row, c)
    local m = row.member
    if not m or not c then
        return false
    end
    if ns.Engine.IsConfirmed(m.key, c.fullName) then
        return true
    end
    if c.player == row.player then
        return row.status == "confirmed"
    end
    local ex = extraOf(row, c)
    return ex and ex.linked and true or false
end

-- Separate character `c` (with its group, if it is a group main) from the row's Discord member.
-- Fixed assignments need a confirmation first.
local function unlink(row, c)
    local m = row.member
    local function doIt()
        ns.Engine.Unlink(m.key, c.fullName)
        ns.Engine.Print(string.format(L.UNLINKED, c.name, m.display))
    end
    if isFixed(row, c) then
        -- the fixed assignment may also come from the group main: it is lost either way
        local counts = ns.Protect.Links(currentDecisions(), m.key, c.fullName)
        if not counts.links then
            counts.links = 1
        end
        ns.Dialogs.ShowDeleteWarning(L.UNLINK_TITLE, string.format(L.UNLINK_CONFIRM, c.name, m.display, m.display),
            counts, doIt, L.PROTECT_UNLINK)
    else
        doIt()
    end
end

-- Display name of a Discord member of the last run.
local function memberDisplay(memberKey)
    for _, m in ipairs(ns.state.results and ns.state.results.members or {}) do
        if m.key == memberKey then
            return m.display
        end
    end
    return memberKey
end

-- Fix characters to a Discord member; asks first if one of them is fixed to another member.
local function confirmTo(memberKey, chars)
    local list = type(chars) == "table" and chars or { chars }
    local d = currentDecisions()
    local counts = ns.Protect.OtherLinks(d, memberKey, list)
    if not counts.links then
        ns.Engine.Confirm(memberKey, list)
        return
    end
    local names = {}
    for _, name in ipairs(list) do
        if d.links[name] and d.links[name] ~= memberKey then
            local ch = ns.Engine.FindChar(name)
            names[#names + 1] = string.format("%s (%s)", ch and ch.name or name, memberDisplay(d.links[name]))
        end
    end
    ns.Dialogs.ShowDeleteWarning(L.OVERWRITE_LINK_TITLE,
        string.format(L.OVERWRITE_LINK_CONFIRM, table.concat(names, ", "), memberDisplay(memberKey)), counts,
        function()
            ns.Engine.Confirm(memberKey, list)
        end, L.PROTECT_OVERWRITE)
end

-- Assignment section. `c` is the character the menu was opened for (main of the row or an alt).
local function addAssignActions(items, row, c, isChild)
    local E = ns.Engine
    local m, p = row.member, row.player
    local ignored = row.status == "ignored"
    items[#items + 1] = section(L.MENU_SECTION_ASSIGN)

    -- the characters this menu works on: the whole row, or the one alt
    local targets = isChild and { c.fullName } or rowMains(row)
    local naPair = (not m and L.NA_NO_DISCORD) or (not c and L.NA_NO_CHAR) or (ignored and L.NA_IGNORED) or nil
    local allFixed, anyFixed = true, false
    if m then
        for _, name in ipairs(targets) do
            if E.IsConfirmed(m.key, name) then
                anyFixed = true
            else
                allFixed = false
            end
        end
    end
    if isChild then
        allFixed = isFixed(row, c)
    end

    items[#items + 1] = entry(L.MENU_CONFIRM, function()
        confirmTo(m.key, targets)
    end, naPair or (allFixed and L.NA_CONFIRMED) or nil)

    items[#items + 1] = entry(L.MENU_UNCONFIRM, function()
        local names = {}
        for _, name in ipairs(targets) do
            if E.IsConfirmed(m.key, name) then
                local ch = E.FindChar(name)
                names[#names + 1] = ch and ch.name or name
            end
        end
        ns.Dialogs.ShowDeleteWarning(L.UNCONFIRM_TITLE, string.format(L.UNCONFIRM_CONFIRM, table.concat(names, ", "), m.display),
            ns.Protect.Links(currentDecisions(), m.key, targets), function()
                E.Unconfirm(m.key, targets)
            end, L.PROTECT_UNCONFIRM)
    end, naPair or ((not anyFixed) and L.NA_NOT_CONFIRMED) or nil)

    items[#items + 1] = entry(L.MENU_UNLINK, function()
        unlink(row, c)
    end, naPair)

    -- other candidates: for the row, or for an alt that heads its own (attached) group
    local sub = { { text = L.MENU_ASSIGN_OTHER, isTitle = true } }
    if not ignored and c then
        if not isChild then
            for _, alt in ipairs(row.alternatives) do
                if m and alt.player then
                    sub[#sub + 1] = { text = string.format("%s (%d%%)", alt.player.main.name, alt.score * 100), func = function()
                        confirmTo(m.key, alt.player.main.fullName)
                    end }
                elseif p and alt.member then
                    sub[#sub + 1] = { text = string.format("%s (%d%%)", alt.member.display, alt.score * 100), func = function()
                        confirmTo(alt.member.key, p.main.fullName)
                    end }
                end
            end
        elseif c.player and c == c.player.main then
            for _, pc in ipairs(c.player.candidates or {}) do
                if pc.member ~= m and #sub < 7 then
                    sub[#sub + 1] = { text = string.format("%s (%d%%)", pc.member.display, pc.score * 100), func = function()
                        confirmTo(pc.member.key, c.fullName)
                    end }
                end
            end
        end
    end
    items[#items + 1] = { text = L.MENU_ASSIGN_OTHER, submenu = sub, disabled = #sub == 1,
        tooltip = #sub == 1 and ((ignored and L.NA_IGNORED) or (not c and L.NA_NO_CHAR) or L.NA_NO_CANDIDATES) or nil }

    items[#items + 1] = entry(L.MENU_ASSIGN_BY_NAME, function()
        ns.Dialogs.ShowInput(L.MENU_ASSIGN_BY_NAME, string.format(L.ASSIGN_BY_NAME_LABEL, m.display), "", function(name)
            local ch = findCharByName(name)
            if ch then
                confirmTo(m.key, ch.fullName)
            else
                E.Print(string.format(L.ASSIGN_NOT_FOUND, name))
            end
        end)
    end, (not m and L.NA_NO_DISCORD) or (ignored and L.NA_IGNORED) or nil)

    items[#items + 1] = entry(L.MENU_ASSIGN_MEMBER, function()
        ns.Dialogs.ShowInput(L.MENU_ASSIGN_MEMBER, string.format(L.ASSIGN_MEMBER_LABEL, c.name), "", function(name)
            local member = E.FindMember(name)
            if member then
                confirmTo(member.key, c.fullName)
            else
                E.Print(string.format(L.MEMBER_NOT_FOUND, name))
            end
        end)
    end, (not c and L.NA_NO_CHAR) or (ignored and L.NA_IGNORED) or nil)

    items[#items + 1] = entry(L.MENU_RESET, function()
        ns.Dialogs.ShowDeleteWarning(L.RESET_MEMBER_TITLE, string.format(L.RESET_MEMBER_CONFIRM, m.display),
            ns.Protect.Member(currentDecisions(), m.key), function()
                E.ResetMember(m.key)
            end, L.PROTECT_RESET)
    end, (not m and L.NA_NO_DISCORD) or ((not E.HasDecision(m.key)) and L.NA_NO_DECISIONS) or nil)
end

-- Character section: alt / main ------------------------------------------------------------
local function addAltActions(items, row, c)
    local E = ns.Engine
    local naChar = (not c and L.NA_NO_CHAR) or nil
    local na = naChar or (row.status == "ignored" and L.NA_IGNORED) or nil

    -- assign as alt of another player
    local sub = { { text = L.MENU_SET_ALT, isTitle = true } }
    if not na then
        if c.player then
            for _, sug in ipairs(ns.Advice.altSuggestions(c.player, 0)) do
                if #sub < 7 then
                    sub[#sub + 1] = { text = string.format(L.MENU_ALT_SUGGESTION, sug.player.main.name, sug.member.display),
                        func = function()
                            assignAlt(c, sug.player.main.fullName)
                        end }
                end
            end
        end
        sub[#sub + 1] = { text = L.MENU_SET_ALT_BY_NAME, func = function()
            ns.Dialogs.ShowInput(L.MENU_SET_ALT_BY_NAME, string.format(L.ALT_BY_NAME_LABEL, c.name), "", function(name)
                local target = findCharByName(name)
                if target then
                    assignAlt(c, target.fullName)
                else
                    E.Print(string.format(L.ASSIGN_NOT_FOUND, name))
                end
            end)
        end }
    end
    items[#items + 1] = { text = L.MENU_SET_ALT, submenu = sub, disabled = na ~= nil, tooltip = na }

    -- main: the character is shown as alt in this row or detected as alt
    local isRowMain = c and row.player and c == row.player.main
    items[#items + 1] = entry(L.MENU_MARK_MAIN, function()
        E.MarkMain(c.fullName)
    end, na or ((isRowMain and not c.isTwink) and L.NA_ALREADY_MAIN) or nil)

    items[#items + 1] = entry(L.MENU_RESET_ALT, function()
        ns.Dialogs.ShowDeleteWarning(L.RESET_ALT_TITLE, string.format(L.RESET_ALT_CONFIRM, c.name),
            ns.Protect.AltDecision(currentDecisions(), c.fullName), function()
                E.ResetAltDecision(c.fullName)
            end, L.PROTECT_RESET)
    end, na or ((not E.HasAltDecision(c.fullName)) and L.NA_NO_ALT_DECISION) or nil)
end

-- Dungeon roles of a character (manual; only the roles the class can take). Returns menu entries.
local function roleEntries(c)
    local E = ns.Engine
    local list = {}
    if not c then
        list[1] = entry(L.MENU_DUNGEON_ROLES, nil, L.NA_NO_CHAR)
        return list
    end
    local manual = E.GetManualDungeonRoles(c.fullName)
    local current = manual or c.dungeonRoles or {}
    local has = {}
    for _, r in ipairs(current) do
        has[r] = true
    end
    for _, r in ipairs(ns.DungeonRoles.ClassRoles(c.classFile)) do
        local text = (has[r] and W.ICON_CHECK or W.ICON_NOCHECK) .. " " .. W.RoleIcon(r, 14) .. " " .. L["DROLE_" .. r:upper()]
        local full = not has[r] and #current >= ns.DungeonRoles.MAX
        list[#list + 1] = { text = text, disabled = full, tooltip = full and L.NA_DROLE_MAX or nil, tooltipTitle = text,
            func = function()
                local roles = {}
                for _, x in ipairs(current) do
                    if x ~= r then
                        roles[#roles + 1] = x
                    end
                end
                if not has[r] then
                    roles[#roles + 1] = r
                end
                E.SetDungeonRoles(c.fullName, roles)
            end }
    end
    local noneSet = manual and #manual == 0
    list[#list + 1] = { text = (noneSet and W.ICON_CHECK or W.ICON_NOCHECK) .. " " .. L.DROLE_NONE,
        disabled = noneSet or nil, func = function()
            E.SetDungeonRoles(c.fullName, {})
        end }
    list[#list + 1] = { text = L.MENU_DUNGEON_ROLES_AUTO, disabled = not manual or nil,
        tooltip = (not manual) and L.NA_NO_MANUAL_DROLE or nil, tooltipTitle = L.MENU_DUNGEON_ROLES_AUTO,
        func = function()
            ns.Dialogs.ShowDeleteWarning(L.MENU_DUNGEON_ROLES_AUTO, string.format(L.DROLE_AUTO_CONFIRM, c.name),
                { dungeonRoles = 1 }, function()
                    E.SetDungeonRoles(c.fullName, nil)
                end, L.PROTECT_RESET)
        end }
    return list
end

-- Professions of a character (manual; at most two main professions). Returns menu entries.
local function professionEntries(c)
    local E = ns.Engine
    local P = ns.Professions
    local list = {}
    if not c then
        list[1] = entry(L.MENU_PROFESSIONS, nil, L.NA_NO_CHAR)
        return list
    end
    local manual = E.GetManualProfessions(c.fullName)
    local current = manual or c.professions or {}
    local has, primaries = {}, 0
    for _, p in ipairs(current) do
        has[p] = true
        if P.IsPrimary(p) then
            primaries = primaries + 1
        end
    end
    for _, p in ipairs(P.LIST) do
        local text = (has[p] and W.ICON_CHECK or W.ICON_NOCHECK) .. " " .. W.ProfIcon(p, 14) .. " " .. L["PROF_" .. p:upper()]
        local full = not has[p] and P.IsPrimary(p) and primaries >= P.MAX_PRIMARY
        list[#list + 1] = { text = text, disabled = full, tooltip = full and L.NA_PROF_MAX or nil, tooltipTitle = text,
            func = function()
                local out = {}
                for _, x in ipairs(current) do
                    if x ~= p then
                        out[#out + 1] = x
                    end
                end
                if not has[p] then
                    out[#out + 1] = p
                end
                E.SetProfessions(c.fullName, out)
            end }
    end
    local noneSet = manual and #manual == 0
    list[#list + 1] = { text = (noneSet and W.ICON_CHECK or W.ICON_NOCHECK) .. " " .. L.PROF_NONE,
        disabled = noneSet or nil, func = function()
            E.SetProfessions(c.fullName, {})
        end }
    list[#list + 1] = { text = L.MENU_PROFESSIONS_AUTO, disabled = not manual or nil,
        tooltip = (not manual) and L.NA_NO_MANUAL_PROF or nil, tooltipTitle = L.MENU_PROFESSIONS_AUTO,
        func = function()
            ns.Dialogs.ShowDeleteWarning(L.MENU_PROFESSIONS_AUTO, string.format(L.PROF_AUTO_CONFIRM, c.name),
                { professions = 1 }, function()
                    E.SetProfessions(c.fullName, nil)
                end, L.PROTECT_RESET)
        end }
    return list
end

-- Prepare notes automatically for one character (asks first if prepared texts would be replaced).
local function autoPrepare(row, c)
    local s = settings()
    local replaced = ns.PendingNotes.AutoWouldReplace(row, c, s)
    local function doIt()
        local n = ns.PendingNotes.Auto(row, c, s)
        ns.Engine.Print(n > 0 and string.format(L.PENDING_AUTO_DONE, n, c.name) or string.format(L.PENDING_AUTO_NONE, c.name))
    end
    if replaced > 0 then
        ns.Dialogs.ShowDeleteWarning(L.PENDING_AUTO, string.format(L.PENDING_AUTO_REPLACE, c.name),
            { pendingNotes = replaced }, doIt, L.PROTECT_OVERWRITE)
    else
        doIt()
    end
end

-- Note actions of a character: prepare (by hand / from the templates), remove, copy a suggestion.
local function noteEntries(row, c)
    local list = {}
    if not c then
        list[1] = entry(L.MENU_PREPARE_NOTE, nil, L.NA_NO_CHAR)
        return list
    end
    local s = settings()
    for _, kind in ipairs({ "public", "officer" }) do
        local label = (kind == "officer") and L.MENU_PREPARE_OFFICER or L.MENU_PREPARE_PUBLIC
        local pending = ns.PendingNotes.Get(c.fullName, kind)
        local na = (kind == "officer" and ns.state.canViewOfficer == false) and L.NA_OFFICER_UNREADABLE or nil
        list[#list + 1] = entry(W.NoteIcon(kind, 14) .. " " .. label
            .. (pending and ("  |cffffd100" .. pending .. "|r") or ""), function()
            ns.Dialogs.ShowPrepareNote(row, c, kind)
        end, na)
    end
    local kinds = ns.PendingNotes.AutoKinds(s)
    list[#list + 1] = entry(W.NoteIcon("auto", 14) .. " " .. L.PENDING_AUTO, function()
        autoPrepare(row, c)
    end, (#kinds == 0) and L.NA_NO_TEMPLATE or nil)
    local count = (ns.PendingNotes.Get(c.fullName, "public") and 1 or 0) + (ns.PendingNotes.Get(c.fullName, "officer") and 1 or 0)
    list[#list + 1] = entry(L.PENDING_REMOVE_ALL, function()
        ns.Dialogs.ShowDeleteWarning(L.PENDING_REMOVE_ALL, string.format(L.PENDING_REMOVE_CONFIRM, c.name),
            { pendingNotes = count }, function()
                ns.PendingNotes.Clear(c.fullName)
            end)
    end, (count == 0) and L.NA_NO_PENDING or nil)
    -- suggestions from the templates, to copy into the guild window by hand
    for _, kind in ipairs({ "public", "officer" }) do
        local label = (kind == "officer") and L.NOTE_OFFICER or L.NOTE_PUBLIC
        local text = ns.Advice.suggestedNote(row, c, s, kind)
        list[#list + 1] = entry(L.MENU_COPY_NOTE .. " (" .. label .. ")" .. (text and (": |cffffffff" .. text .. "|r") or ""),
            function()
                ns.Dialogs.ShowCopy(L.MENU_COPY_NOTE .. " - " .. label, text, L.COPY_NOTE_HINT)
            end, (not text) and L.NA_NO_TEMPLATE or nil)
    end
    return list
end

local function submenu(title, list)
    local sub = { { text = title, isTitle = true } }
    for _, it in ipairs(list) do
        sub[#sub + 1] = it
    end
    return { text = title, submenu = sub }
end

-- Character section of the full menu: alt / main, dungeon roles, professions, rank, notes, whisper.
local function addCharActions(items, row, c)
    local E = ns.Engine
    items[#items + 1] = section(string.format(L.MENU_SECTION_CHAR, c and c.name or "-"))
    local naChar = (not c and L.NA_NO_CHAR) or nil
    addAltActions(items, row, c)

    local roles = submenu(L.MENU_DUNGEON_ROLES, roleEntries(c))
    local profs = submenu(L.MENU_PROFESSIONS, professionEntries(c))
    local notes = submenu(L.MENU_PREPARE_NOTE, noteEntries(row, c))
    for _, it in ipairs({ roles, profs, notes }) do
        if naChar then
            it.disabled, it.tooltip = true, naChar
        end
        items[#items + 1] = it
    end

    -- guild rank (blocked by Blizzard in WoW: Forever -> greyed out)
    if ns.RankChange.IsAvailable() and not naChar then
        local rsub = { { text = L.MENU_SET_RANK, isTitle = true } }
        for rank, rankName in ipairs(ns.state.rankNames or {}) do
            local allowed = ns.RankChange.CanSet(c, rank)
            rsub[#rsub + 1] = { text = string.format("%d. %s", rank, rankName), disabled = not allowed, func = function()
                ns.Dialogs.ShowConfirm(L.MENU_SET_RANK, string.format(L.RANK_CONFIRM, c.name, c.rankName or "?", rankName), function()
                    local ok, err = ns.RankChange.Set(c, rank)
                    E.Print(ok and string.format(L.RANK_CHANGED, c.name) or L[err])
                    if ok then
                        E.Refresh()
                    end
                end)
            end }
        end
        items[#items + 1] = { text = L.MENU_SET_RANK, submenu = rsub }
    else
        items[#items + 1] = entry(L.MENU_SET_RANK, nil, naChar or L.BLOCKED_BY_BLIZZARD)
    end

    items[#items + 1] = entry(L.MENU_WHISPER .. ((c and c.online) and (" " .. W.ICON_ONLINE) or ""), function()
        whisper(c.fullName)
    end, naChar)
end

-- List section: ignore, copy names.
local function addListActions(items, row, c, isChild)
    local E = ns.Engine
    local m, p = row.member, row.player
    items[#items + 1] = section(L.MENU_SECTION_LIST)
    local memberIgnored = m and m.ignored
    items[#items + 1] = entry(memberIgnored and L.MENU_UNIGNORE_DISCORD or L.MENU_IGNORE_DISCORD, function()
        E.SetIgnoredMember(m.key, not memberIgnored)
    end, (not m and L.NA_NO_DISCORD) or nil)

    -- ignoring works on the main of a character group
    local groupMain = c and c.player and c.player.main
    local charIgnored = groupMain and p and p.ignored and groupMain == p.main
    items[#items + 1] = entry(charIgnored and L.MENU_UNIGNORE_CHAR or L.MENU_IGNORE_CHAR, function()
        E.SetIgnoredChar(groupMain.fullName, not charIgnored)
    end, (not c and L.NA_NO_CHAR) or ((isChild and c ~= groupMain) and L.NA_ONLY_GROUP_MAIN) or nil)

    items[#items + 1] = { text = L.MENU_COPY_NAMES, func = function()
        local lines = {}
        if m then
            lines[#lines + 1] = m.display
        end
        if isChild then
            lines[#lines + 1] = c.name
        else
            for _, ch in ipairs(ns.Advice.rowChars(row)) do
                lines[#lines + 1] = ch.name
            end
        end
        ns.Dialogs.ShowCopy(L.MENU_COPY_NAMES, table.concat(lines, "\n"))
    end }
end

-- The context menu depends on the column that was right-clicked:
--   status / Discord / character: assignments (Discord member and alt / main)
--   dungeon roles, professions, notes: only those
--   rank / hints ("To change"): everything
local ASSIGN_COLUMNS = { expand = true, status = true, discord = true, char = true }

local function openMenu(row, c, isChild, colKey)
    local m = row.member
    local title = isChild and c.name or (m and m.display) or (c and c.name) or "?"
    if isChild and m then
        title = title .. "  |cff888888(" .. m.display .. ")|r"
    end
    local items = { { text = title, isTitle = true } }
    local function addAll(list)
        for _, it in ipairs(list) do
            items[#items + 1] = it
        end
    end
    if ASSIGN_COLUMNS[colKey] then
        addAssignActions(items, row, c, isChild)
        items[#items + 1] = section(string.format(L.MENU_SECTION_CHAR, c and c.name or "-"))
        addAltActions(items, row, c)
    elseif colKey == "roles" then
        items[#items + 1] = section(L.MENU_DUNGEON_ROLES)
        addAll(roleEntries(c))
    elseif colKey == "profs" then
        items[#items + 1] = section(L.MENU_PROFESSIONS)
        addAll(professionEntries(c))
    elseif colKey == "notes" then
        items[#items + 1] = section(L.MENU_PREPARE_NOTE)
        addAll(noteEntries(row, c))
    else
        addAssignActions(items, row, c, isChild)
        addCharActions(items, row, c)
        addListActions(items, row, c, isChild)
    end
    items[#items + 1] = { text = CLOSE or "Close" }
    ns.Menu.Open(items)
end
ns.UI.OpenResultMenu = openMenu -- (tests)
ns.UI._filteredRows = filteredRows -- (tests)

local function rowMenu(row, colKey)
    openMenu(row, row.player and row.player.main, false, colKey)
end

local function childMenu(item, colKey)
    openMenu(item.row, item.char, true, colKey)
end

-- Column under the mouse pointer in a list row.
local function columnAt(rowFrame)
    if not GetCursorPosition then
        return nil
    end
    local x = GetCursorPosition()
    local scale = rowFrame:GetEffectiveScale() or 1
    if type(x) ~= "number" or type(scale) ~= "number" or scale == 0 then
        return nil
    end
    local rx = x / scale - (rowFrame:GetLeft() or 0)
    for i, col in ipairs(COLUMNS) do
        local left = rowFrame.colX[i] - 4
        if rx >= left and rx < left + col.width then
            return col.key
        end
    end
    return nil
end

-- Export ---------------------------------------------------------------------------

local function exportText(rows, namesOnly)
    local lines = {}
    for _, row in ipairs(rows) do
        if namesOnly then
            lines[#lines + 1] = row.member and row.member.display or (row.player and row.player.main.name) or ""
        else
            local parts = {
                L["STATUS_" .. row.status:upper()],
                row.member and row.member.display or "-",
                row.player and row.player.main.name or "-",
            }
            local alts = altChars(row)
            if #alts > 0 then
                local tw = {}
                for _, c in ipairs(alts) do
                    tw[#tw + 1] = c.name
                end
                parts[3] = parts[3] .. " (+" .. table.concat(tw, ", ") .. ")"
            end
            if row.player and #(row.player.main.dungeonRoles or {}) > 0 then
                parts[#parts + 1] = L.COL_DUNGEON_ROLES_LONG .. ": " .. W.RoleNames(row.player.main.dungeonRoles)
            end
            if row.rank and row.rank.state == "mismatch" then
                parts[#parts + 1] = string.format("%s: %s -> %s", L.COL_RANK, row.player.main.rankName or "?",
                    ns.state.rankNames[row.rank.expected] or row.rank.expected)
            end
            local hints = hintList(row)
            if #hints > 0 then
                parts[#parts + 1] = table.concat(hints, "; ")
            end
            lines[#lines + 1] = table.concat(parts, " | ")
        end
    end
    return table.concat(lines, "\n")
end

-- Layout ---------------------------------------------------------------------------------

local onToggle -- set in create()

local function createRow(list, i)
    local row = CreateFrame("Button", nil, list)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.04 or 0)
    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(0.3, 0.5, 0.9, 0.25)

    -- [+] / [-] button to unfold the alts
    local toggle = CreateFrame("Button", nil, row)
    toggle:SetSize(18, 18)
    toggle:SetPoint("LEFT", 2, 0)
    toggle.text = toggle:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    toggle.text:SetPoint("CENTER")
    local thl = toggle:CreateTexture(nil, "HIGHLIGHT")
    thl:SetAllPoints()
    thl:SetColorTexture(1, 1, 1, 0.15)
    toggle:SetScript("OnClick", function()
        local data = row.data
        if data and data.kind ~= "child" then
            local key = rowKey(data)
            collapsed[key] = not collapsed[key] or nil
            onToggle()
        end
    end)
    W.Tooltip(toggle, W.LocText("TOOLTIP_EXPAND"))
    row.toggle = toggle

    row.cols = {}
    local x = 4
    row.colX = {}
    for c, col in ipairs(COLUMNS) do
        local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("LEFT", x, 0)
        fs:SetWidth(col.width - 8)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(false)
        row.cols[c] = fs
        row.colX[c] = x
        x = x + col.width
    end
    row:SetScript("OnEnter", function(self)
        local data = self.data
        if data then
            if data.kind == "child" then
                showChildTooltip(self, data)
            else
                showRowTooltip(self, data)
            end
        end
    end)
    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    row:SetScript("OnClick", function(self, button)
        local data = self.data
        if data and button == "RightButton" then
            GameTooltip:Hide()
            local colKey = columnAt(self)
            if data.kind == "child" then
                childMenu(data, colKey)
            else
                rowMenu(data, colKey)
            end
        end
    end)

    -- note buttons: prepare public note, officer note, both from the templates
    row.noteButtons = {}
    local notesIdx = COL_INDEX.notes
    for i, kind in ipairs(NOTE_BUTTONS) do
        local b = CreateFrame("Button", nil, row)
        b:SetSize(NOTE_BUTTON_SIZE, NOTE_BUTTON_SIZE)
        b:SetPoint("LEFT", row.colX[notesIdx] + COLUMNS[notesIdx].width - 4 - (#NOTE_BUTTONS - i + 1) * (NOTE_BUTTON_SIZE + 1), 0)
        local tex = b:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints()
        tex:SetTexture(W.NOTE_TEXTURES[kind])
        b.tex = tex
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.25)
        b.kind = kind
        b:SetScript("OnClick", function()
            local r, c = row.noteRow, row.noteChar
            if not r or not c then
                return
            end
            if kind == "auto" then
                autoPrepare(r, c)
            else
                ns.Dialogs.ShowPrepareNote(r, c, kind)
            end
        end)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L["PENDING_BUTTON_" .. kind:upper()], 1, 1, 1)
            local c = row.noteChar
            local pending = c and kind ~= "auto" and ns.PendingNotes.Get(c.fullName, kind)
            if pending then
                GameTooltip:AddLine(L.PENDING_TOOLTIP .. " " .. pending, 1, 0.82, 0, true)
            end
            GameTooltip:AddLine(L["PENDING_BUTTON_" .. kind:upper() .. "_TOOLTIP"], 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        row.noteButtons[i] = b
    end
    return row
end

-- Show the note buttons of a row for character `c` (prepared notes: full opacity).
local function updateNoteButtons(row, dataRow, c)
    row.noteRow, row.noteChar = dataRow, c
    for _, b in ipairs(row.noteButtons) do
        if c then
            local active = b.kind ~= "auto" and ns.PendingNotes.Get(c.fullName, b.kind) ~= nil
            b:SetAlpha(active and 1 or 0.55)
            b:Show()
        else
            b:Hide()
        end
    end
end

-- Alt rows are indented in the front columns (status, Discord, character); the other columns stay
-- aligned. The notes column leaves room for the note buttons.
local function setIndent(row, indent)
    for c, fs in ipairs(row.cols) do
        local shift = (c <= COL_INDEX.char) and indent or 0
        fs:ClearAllPoints()
        fs:SetPoint("LEFT", row.colX[c] + shift, 0)
        local w = COLUMNS[c].width - 8 - shift
        if c == COL_INDEX.notes then
            w = w - #NOTE_BUTTONS * (NOTE_BUTTON_SIZE + 1)
        end
        fs:SetWidth(w)
    end
end

local function updateRow(row, data)
    row.data = data
    if data.kind == "child" then
        local parent, c = data.row, data.char
        setIndent(row, INDENT)
        row.toggle:Hide()
        row.cols[1]:SetText("")
        -- alts of an attached group (assigned via the Discord name) show their own status
        local ex = extraOf(parent, c)
        local status = ""
        if ex and c == ex.player.main then
            status = " " .. statusText(ex.status)
        end
        row.cols[2]:SetText("|cff999999" .. L.TOOLTIP_TWINK .. "|r" .. status)
        row.cols[3]:SetText("")
        row.cols[4]:SetText(charText(c) .. string.format(" |cff888888%s|r", c.level or ""))
        row.cols[5]:SetText(W.RoleIcons(c.dungeonRoles))
        row.cols[6]:SetText(W.ProfIcons(c.professions))
        row.cols[7]:SetText(notesText(c))
        row.cols[8]:SetText(charRankText(parent, c))
        row.cols[9]:SetText(#(c.advice or {}) > 0 and ("|cffffaa44" .. shortList(c.advice) .. "|r") or "")
        updateNoteButtons(row, parent, c)
        return
    end
    setIndent(row, 0)
    if #altChars(data) > 0 then
        row.toggle.text:SetText(isOpen(data) and "-" or "+")
        row.toggle:Show()
    else
        row.toggle:Hide()
    end
    row.cols[1]:SetText("")
    row.cols[2]:SetText(statusText(data.status) .. (data.score and data.status ~= "confirmed"
        and string.format(" |cff888888%d%%|r", data.score * 100) or ""))
    row.cols[3]:SetText(data.member and data.member.display or ("|cff777777" .. L.SIDE_NO_DISCORD .. "|r"))
    row.cols[4]:SetText(data.player and playerText(data) or ("|cff777777" .. L.SIDE_NO_CHAR .. "|r"))
    row.cols[5]:SetText(data.player and W.RoleIcons(data.player.main.dungeonRoles) or "")
    row.cols[6]:SetText(data.player and W.ProfIcons(data.player.main.professions) or "")
    row.cols[7]:SetText(notesText(data.player and data.player.main))
    row.cols[8]:SetText(rankText(data))
    updateNoteButtons(row, data, data.player and data.player.main)
    local adv = rowAdvice(data)
    row.cols[9]:SetText(#adv > 0 and ("|cffffaa44" .. shortList(adv) .. "|r") or "")
end

local function create(parent)
    local f = CreateFrame("Frame", nil, parent)
    local fl = filters()

    -- filter bar 1: status
    local x = 4
    f.statusChecks = {}
    for _, status in ipairs({ "confirmed", "sure", "likely", "unlikely", "unassigned", "guest", "ignored" }) do
        local cb = W.Check(f, W.Colorize(L["STATUS_" .. status:upper()], W.STATUS_COLORS[status]), function(_, checked)
            fl.status[status] = checked
            f.Update()
        end)
        cb:SetPoint("TOPLEFT", x, -2)
        cb:SetChecked(fl.status[status])
        f.statusChecks[status] = cb
        x = x + 30 + math.max(70, cb.label:GetStringWidth() + 12)
    end

    -- dungeon role and profession filter at the right end of bar 1 (one button, menu with both lists)
    local roleCycle = W.Button(f, "", 180, 22)
    local function roleProfText()
        local role, prof = fl.dungeonRole or "all", fl.profession or "all"
        local parts = {}
        if role == "none" then
            parts[#parts + 1] = L.FILTER_DROLE_NONE
        elseif role ~= "all" then
            parts[#parts + 1] = W.RoleIcon(role, 14) .. " " .. L["DROLE_" .. role:upper()]
        end
        if prof == "none" then
            parts[#parts + 1] = L.FILTER_PROF_NONE
        elseif prof ~= "all" then
            parts[#parts + 1] = W.ProfIcon(prof, 14) .. " "
                .. ((role ~= "all") and L["ABBR_PROF_" .. prof:upper()] or L["PROF_" .. prof:upper()])
        end
        return #parts > 0 and table.concat(parts, ", ") or L.FILTER_ROLEPROF_ALL
    end
    function roleCycle.Refresh()
        roleCycle:SetText(roleProfText())
    end
    local function filterItem(text, active, set)
        return { text = (active and W.ICON_CHECK or W.ICON_NOCHECK) .. " " .. text, func = function()
            set()
            roleCycle.Refresh()
            f.Update()
        end }
    end
    roleCycle:SetScript("OnClick", function()
        local role, prof = fl.dungeonRole or "all", fl.profession or "all"
        local items = { section(L.COL_DUNGEON_ROLES_LONG) }
        local function addRole(value, text)
            items[#items + 1] = filterItem(text, role == value, function() fl.dungeonRole = value end)
        end
        local function addProf(value, text)
            items[#items + 1] = filterItem(text, prof == value, function() fl.profession = value end)
        end
        addRole("all", L.FILTER_DROLE_ALL)
        for _, r in ipairs(ns.DungeonRoles.ROLES) do
            addRole(r, W.RoleIcon(r, 14) .. " " .. L["DROLE_" .. r:upper()])
        end
        addRole("none", L.FILTER_DROLE_NONE)
        items[#items + 1] = section(L.COL_PROFESSIONS)
        addProf("all", L.FILTER_PROF_ALL)
        for _, p in ipairs(ns.Professions.LIST) do
            addProf(p, W.ProfIcon(p, 14) .. " " .. L["PROF_" .. p:upper()])
        end
        addProf("none", L.FILTER_PROF_NONE)
        local scale = UIParent:GetEffectiveScale()
        local s = roleCycle:GetEffectiveScale() / scale
        ns.Menu.Open(items, { (roleCycle:GetLeft() or 0) * s, (roleCycle:GetBottom() or 0) * s })
    end)
    roleCycle.Refresh()
    roleCycle:SetPoint("TOPRIGHT", -4, -2)
    W.Tooltip(roleCycle, L.FILTER_ROLEPROF_TITLE, W.LocText("FILTER_ROLEPROF_TOOLTIP"))

    -- filter bar 2: side, rank, hints, online, search
    local sideCycle = W.Cycle(f, 190, {
        { value = "all", text = L.SIDE_ALL },
        { value = "both", text = L.SIDE_BOTH },
        { value = "discordOnly", text = L.SIDE_DISCORD_ONLY },
        { value = "wowOnly", text = L.SIDE_WOW_ONLY },
    }, function()
        return fl.side
    end, function(v)
        fl.side = v
        f.Update()
    end)
    sideCycle:SetPoint("TOPLEFT", 4, -30)

    local rankCb = W.Check(f, L.FILTER_RANK_MISMATCH, function(_, checked)
        fl.rankMismatch = checked
        f.Update()
    end)
    rankCb:SetPoint("LEFT", sideCycle, "RIGHT", 12, 0)
    rankCb:SetChecked(fl.rankMismatch)

    local hintCb = W.Check(f, L.FILTER_HINTS, function(_, checked)
        fl.ruleIssues = checked
        f.Update()
    end)
    hintCb:SetPoint("LEFT", rankCb.label, "RIGHT", 16, 0)
    hintCb:SetChecked(fl.ruleIssues)

    local onlineCb = W.Check(f, L.FILTER_ONLINE, function(_, checked)
        fl.onlineOnly = checked
        f.Update()
    end)
    onlineCb:SetPoint("LEFT", hintCb.label, "RIGHT", 16, 0)
    onlineCb:SetChecked(fl.onlineOnly)

    local searchLabel = W.Label(f, L.FILTER_SEARCH, "GameFontNormal")
    searchLabel:SetPoint("LEFT", onlineCb.label, "RIGHT", 24, 0)
    local searchBox = W.SearchBox(f, 200, 20, L.SEARCH_PLACEHOLDER)
    searchBox:SetPoint("LEFT", searchLabel, "RIGHT", 10, 0)
    searchBox:SetText(fl.search or "")
    W.Tooltip(searchBox, L.FILTER_SEARCH, W.LocText("SEARCH_TOOLTIP"))
    -- update the list shortly after the last key press (the search runs over all columns)
    local searchToken = 0
    searchBox:HookScript("OnTextChanged", function(self)
        local text = self:GetText()
        if text == fl.search then
            return
        end
        fl.search = text
        searchToken = searchToken + 1
        local token = searchToken
        if C_Timer and C_Timer.After then
            C_Timer.After(0.25, function()
                if token == searchToken and f:IsShown() then
                    f.Update()
                end
            end)
        else
            f.Update()
        end
    end)

    -- which notes are used for the assignment (same setting as in the Options tab)
    local notesLabel = W.Label(f, L.NOTES_SOURCE_LABEL, "GameFontNormal")
    notesLabel:SetPoint("TOPLEFT", 8, -64)
    local noteSources = {
        { value = "both", text = L.NOTES_SOURCE_BOTH },
        { value = "public", text = L.NOTES_SOURCE_PUBLIC },
        { value = "officer", text = L.NOTES_SOURCE_OFFICER },
        { value = "none", text = L.NOTES_SOURCE_NONE },
    }
    local notesCycle = W.Cycle(f, 210, noteSources, function()
        local s = settings()
        if s.useNote and s.useOfficerNote then
            return "both"
        elseif s.useNote then
            return "public"
        elseif s.useOfficerNote then
            return "officer"
        end
        return "none"
    end, function(v)
        local s = settings()
        s.useNote = (v == "both" or v == "public")
        s.useOfficerNote = (v == "both" or v == "officer")
        ns.Engine.Run()
    end)
    notesCycle:SetPoint("LEFT", notesLabel, "RIGHT", 10, 0)
    W.Tooltip(notesCycle, L.NOTES_SOURCE_LABEL, W.LocText("NOTES_SOURCE_TOOLTIP"))
    -- search hits hidden by other filters: click shows them anyway (and back)
    local hiddenBtn = CreateFrame("Button", nil, f)
    hiddenBtn:SetHeight(18)
    hiddenBtn:SetPoint("TOPRIGHT", -8, -66)
    local hiddenText = hiddenBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hiddenText:SetPoint("RIGHT", 0, 0)
    hiddenText:SetJustifyH("RIGHT")
    local hiddenHl = hiddenBtn:CreateTexture(nil, "HIGHLIGHT")
    hiddenHl:SetAllPoints()
    hiddenHl:SetColorTexture(1, 1, 1, 0.08)
    hiddenBtn:SetScript("OnClick", function()
        showAllHits = not showAllHits
        f.Update()
    end)
    hiddenBtn:Hide()

    local notesWarn = W.Label(f, "", "GameFontHighlightSmall")
    notesWarn:SetPoint("LEFT", notesCycle, "RIGHT", 12, 0)
    notesWarn:SetPoint("RIGHT", hiddenBtn, "LEFT", -12, 0)

    -- header
    local header = CreateFrame("Frame", nil, f)
    header:SetPoint("TOPLEFT", 0, -86)
    header:SetPoint("RIGHT", 0, 0)
    header:SetHeight(22)
    local hbg = header:CreateTexture(nil, "BACKGROUND")
    hbg:SetAllPoints()
    hbg:SetColorTexture(1, 1, 1, 0.08)
    f.headerButtons = {}
    local hx = 0
    for _, col in ipairs(COLUMNS) do
        local b = CreateFrame("Button", nil, header)
        b:SetPoint("LEFT", hx, 0)
        b:SetSize(col.width, 22)
        local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("LEFT", 4, 0)
        fs:SetJustifyH("LEFT")
        b.text = fs
        b.col = col
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.08)
        if col.key == "expand" then
            -- unfold / fold all
            b:SetScript("OnClick", function()
                local anyClosed = false
                for _, row in ipairs(f.parentRows or {}) do
                    if #altChars(row) > 0 and not isOpen(row) then
                        anyClosed = true
                    end
                end
                for _, row in ipairs(f.parentRows or {}) do
                    if #altChars(row) > 0 then
                        collapsed[rowKey(row)] = (not anyClosed) or nil
                    end
                end
                f.Update()
            end)
            W.Tooltip(b, W.LocText("TOOLTIP_EXPAND_ALL"))
        else
            b:SetScript("OnClick", function()
                if fl.sortKey == col.key then
                    fl.sortAsc = not fl.sortAsc
                else
                    fl.sortKey, fl.sortAsc = col.key, true
                end
                f.Update()
            end)
        end
        f.headerButtons[#f.headerButtons + 1] = b
        hx = hx + col.width
    end

    -- list
    local list = W.List(f, { rowHeight = ROW_HEIGHT, createRow = createRow, updateRow = updateRow })
    list:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
    list:SetPoint("BOTTOMRIGHT", 0, 64)
    f.list = list

    -- empty / state message
    f.empty = W.Label(f, "", "GameFontDisableLarge")
    f.empty:SetPoint("CENTER", list, "CENTER", 0, 0)
    f.empty:SetJustifyH("CENTER")

    -- summary + buttons
    f.summary = W.Label(f, "", "GameFontHighlight")
    f.summary:SetPoint("BOTTOMLEFT", 4, 38)
    f.summary:SetPoint("RIGHT", -4, 0)

    local refresh = W.Button(f, L.BTN_REFRESH, 120, 24, function()
        ns.Engine.Refresh()
    end)
    refresh:SetPoint("BOTTOMLEFT", 2, 4)

    local export = W.Button(f, L.BTN_EXPORT, 140, 24, function()
        ns.Dialogs.ShowCopy(L.BTN_EXPORT, exportText(f.parentRows or {}, false))
    end)
    export:SetPoint("LEFT", refresh, "RIGHT", 8, 0)

    local exportNames = W.Button(f, L.BTN_EXPORT_NAMES, 140, 24, function()
        ns.Dialogs.ShowCopy(L.BTN_EXPORT_NAMES, exportText(f.parentRows or {}, true))
    end)
    exportNames:SetPoint("LEFT", export, "RIGHT", 8, 0)

    -- manual decisions as a code for other officers (pasted in their Import tab)
    local share = W.Button(f, L.BTN_SHARE, 160, 24, function()
        local text, n = ns.Engine.ExportDecisions()
        if not text or n == 0 then
            ns.Engine.Print(L.SHARE_EMPTY)
            return
        end
        ns.Dialogs.ShowCopy(L.SHARE_TITLE, text, L.SHARE_HINT)
    end)
    share:SetPoint("LEFT", exportNames, "RIGHT", 8, 0)
    W.Tooltip(share, L.BTN_SHARE, L.SHARE_HINT)

    -- prepare notes for many characters at once (from the templates)
    local mass = W.Button(f, L.BTN_PREPARE_NOTES, 170, 24, function()
        local res = ns.state.results
        if res then
            ns.Dialogs.ShowMassPrepare(res.rows)
        end
    end)
    mass:SetPoint("LEFT", share, "RIGHT", 8, 0)
    W.Tooltip(mass, L.BTN_PREPARE_NOTES, W.LocText("BTN_PREPARE_NOTES_TOOLTIP"))

    local reset = W.Button(f, L.BTN_RESET_FILTERS, 140, 24, function()
        local defaults = ns.Util.copy(ns.DEFAULT_FILTERS)
        for k, v in pairs(defaults) do
            fl[k] = v
        end
        for status, cb in pairs(f.statusChecks) do
            cb:SetChecked(fl.status[status])
        end
        sideCycle.Refresh()
        roleCycle.Refresh()
        rankCb:SetChecked(false)
        hintCb:SetChecked(false)
        onlineCb:SetChecked(false)
        showAllHits = false
        searchBox:SetText("")
        searchBox:ClearFocus()
        f.Update()
    end)
    reset:SetPoint("BOTTOMRIGHT", -2, 4)

    function f.Update()
        local state = ns.state
        for _, b in ipairs(f.headerButtons) do
            if b.col.key == "expand" then
                b.text:SetText("+")
            else
                local arrow = ""
                if fl.sortKey == b.col.key then
                    arrow = fl.sortAsc and " (+)" or " (-)"
                end
                b.text:SetText(L[b.col.title] .. arrow)
            end
        end
        hintCb.label:SetText(L.FILTER_HINTS)
        notesCycle.Refresh()
        local s0 = settings()
        if s0.useOfficerNote and state.canViewOfficer == false then
            notesWarn:SetText("|cffffaa00" .. L.NOTES_OFFICER_UNREADABLE .. "|r")
        else
            notesWarn:SetText("")
        end
        local items, rows, hidden = filteredRows()
        f.rows = items
        f.parentRows = rows or {}
        list:SetItems(items)

        -- search: mark the field as an active filter, offer hits hidden by other filters
        if isSearching() then
            searchLabel:SetTextColor(0.3, 1, 0.3)
        else
            searchLabel:SetTextColor(1, 0.82, 0)
        end
        local hint
        if isSearching() and showAllHits then
            hint = "|cff66ccff" .. L.SEARCH_SHOW_FILTERED .. "|r"
        elseif isSearching() and (hidden or 0) > 0 then
            hint = "|cffffaa00" .. string.format(L.SEARCH_HIDDEN, hidden) .. "|r"
        end
        if hint then
            hiddenText:SetText(hint)
            hiddenBtn:SetWidth(hiddenText:GetStringWidth() + 4)
            hiddenBtn:Show()
        else
            hiddenBtn:Hide()
        end
        if state.running then
            f.empty:SetText(L.STATUS_RUNNING)
        elseif state.error then
            f.empty:SetText(L[state.error])
        elseif state.results and #items == 0 then
            f.empty:SetText(L.RESULTS_EMPTY_FILTER)
        else
            f.empty:SetText("")
        end
        local res = state.results
        if res then
            local s = res.summary
            local parts = {
                W.Colorize(s.confirmed .. " " .. L.STATUS_CONFIRMED, W.STATUS_COLORS.confirmed),
                W.Colorize(s.sure .. " " .. L.STATUS_SURE, W.STATUS_COLORS.sure),
                W.Colorize(s.likely .. " " .. L.STATUS_LIKELY, W.STATUS_COLORS.likely),
                W.Colorize(s.unlikely .. " " .. L.STATUS_UNLIKELY, W.STATUS_COLORS.unlikely),
                W.Colorize(s.unassigned .. " " .. L.STATUS_UNASSIGNED, W.STATUS_COLORS.unassigned)
                    .. string.format(" (%d %s, %d %s)", s.discordOnly, L.SUMMARY_DISCORD_ONLY, s.wowOnly, L.SUMMARY_WOW_ONLY),
                W.Colorize(s.guest .. " " .. L.STATUS_GUEST, W.STATUS_COLORS.guest),
                string.format("|cffff6666%d %s|r", res.rankStats and res.rankStats.mismatch or 0, L.SUMMARY_RANK_MISMATCH),
                string.format("|cffffaa44%d %s|r", s.withAdvice or 0, L.SUMMARY_RULE_ISSUES),
            }
            local pending = ns.PendingNotes.Count()
            if pending > 0 then
                parts[#parts + 1] = string.format("|cffffd100%d %s|r", pending, L.SUMMARY_PENDING)
            end
            f.summary:SetText(table.concat(parts, "   ") .. string.format("   |cff888888(%s: %d)|r", L.SUMMARY_SHOWN, #(rows or {})))
        else
            f.summary:SetText("")
        end
    end
    onToggle = f.Update

    -- unfold everything whenever the main window is opened
    local main = _G.TheGuildRegistrarFrame
    if main then
        main:HookScript("OnShow", function()
            for k in pairs(collapsed) do
                collapsed[k] = nil
            end
            if f:IsShown() then
                f.Update()
            end
        end)
    end
    return f
end

local function refresh(f)
    f.Update()
end

ns.UI.RegisterTab({ key = "results", order = 3, title = L.TAB_RESULTS, create = create, refresh = refresh })
