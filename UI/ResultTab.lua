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
    { key = "status", title = "COL_STATUS", width = 110 },
    { key = "discord", title = "COL_DISCORD", width = 190 },
    { key = "char", title = "COL_CHARACTER", width = 190 },
    { key = "notes", title = "COL_NOTES", width = 170 },
    { key = "rank", title = "COL_RANK", width = 145 },
    { key = "hints", title = "COL_HINTS", width = 163 },
}

local ROW_HEIGHT = 20
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
    local s = charText(p.main)
    local n = #altChars(row)
    if n > 0 then
        s = s .. string.format(" |cff999999(+%d)|r", n)
    end
    return s
end

local function notesText(c)
    if not c then
        return ""
    end
    local parts = {}
    if c.note and c.note ~= "" then
        parts[#parts + 1] = c.note
    end
    if c.officerNote and c.officerNote ~= "" then
        parts[#parts + 1] = "|cff88aaff" .. c.officerNote .. "|r"
    end
    return table.concat(parts, " · ")
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

local function altReasonText(c)
    if c.manualTwink then
        return L.TOOLTIP_ALT_REASON_MANUAL
    elseif c.twinkReason == "rank" then
        return L.TOOLTIP_ALT_REASON_RANK
    elseif c.twinkReason == "note" then
        return L.TOOLTIP_ALT_REASON_NOTE
    end
    return nil
end

-- Filtering and sorting --------------------------------------------------------------

local function charMatches(c, needle)
    local text = ns.Text.lower(table.concat({ c.name, c.note or "", c.officerNote or "" }, " "))
    return text:find(needle, 1, true) ~= nil
end

local function matchesSearch(row, needle)
    if needle == "" then
        return true
    end
    if row.member then
        local text = ns.Text.lower(row.member.display .. " " .. table.concat(row.member.roles, " "))
        if text:find(needle, 1, true) then
            return true
        end
    end
    for _, c in ipairs(ns.Advice.rowChars(row)) do
        if charMatches(c, needle) then
            return true
        end
    end
    return false
end

local function isOnline(row)
    for _, c in ipairs(ns.Advice.rowChars(row)) do
        if c.online then
            return true
        end
    end
    return false
end

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
    end
    return 0
end

local function filteredRows()
    local res = ns.state.results
    if not res then
        return {}
    end
    local f = filters()
    local needle = ns.Text.lower(ns.Util.trim(f.search or ""))
    local out = {}
    for _, row in ipairs(res.rows) do
        local ok = f.status[row.status]
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
        if ok and not matchesSearch(row, needle) then
            ok = false
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
            if not open and needle ~= "" then
                for _, c in ipairs(alts) do
                    if charMatches(c, needle) then
                        open = true
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
    return items, out
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
    if c.note and c.note ~= "" then
        GameTooltip:AddLine("   " .. L.NOTE_PUBLIC .. ": " .. c.note, 0.9, 0.9, 0.9, true)
    end
    if c.officerNote and c.officerNote ~= "" then
        GameTooltip:AddLine("   " .. L.NOTE_OFFICER .. ": " .. c.officerNote, 0.55, 0.7, 1, true)
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

local function showRowTooltip(owner, row)
    GameTooltip:SetOwner(owner, "ANCHOR_CURSOR_RIGHT")
    GameTooltip:AddLine(statusText(row.status) .. (row.score and string.format("  |cffaaaaaa%d%%|r", row.score * 100) or ""))
    local side = sideText(row)
    if side then
        GameTooltip:AddLine(side, 1, 0.6, 0.6)
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
    addAdviceLines(rowAdvice(row), row)
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
    GameTooltip:SetOwner(owner, "ANCHOR_CURSOR_RIGHT")
    addCharLines(c, L.TOOLTIP_TWINK)
    local main = row.player and row.player.main
    if main then
        local reason = altReasonText(c)
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

-- Actions for one guild character (main or alt).
local function addCharActions(items, row, c)
    local E = ns.Engine

    if row.status ~= "ignored" then
        -- assign as alt of another player
        local sub = { { text = L.MENU_SET_ALT, isTitle = true } }
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
        items[#items + 1] = { text = L.MENU_SET_ALT, submenu = sub }

        if c.isTwink then
            items[#items + 1] = { text = L.MENU_MARK_MAIN, func = function()
                E.MarkMain(c.fullName)
            end }
        end
        if E.HasAltDecision(c.fullName) then
            items[#items + 1] = { text = L.MENU_RESET_ALT, func = function()
                E.ResetAltDecision(c.fullName)
            end }
        end
    end

    -- guild rank (blocked by Blizzard in WoW: Forever -> greyed out)
    if ns.RankChange.IsAvailable() then
        local sub = { { text = L.MENU_SET_RANK, isTitle = true } }
        for rank, rankName in ipairs(ns.state.rankNames or {}) do
            local allowed = ns.RankChange.CanSet(c, rank)
            sub[#sub + 1] = { text = string.format("%d. %s", rank, rankName), disabled = not allowed, func = function()
                ns.Dialogs.ShowConfirm(L.MENU_SET_RANK, string.format(L.RANK_CONFIRM, c.name, c.rankName or "?", rankName), function()
                    local ok, err = ns.RankChange.Set(c, rank)
                    E.Print(ok and string.format(L.RANK_CHANGED, c.name) or L[err])
                    if ok then
                        E.Refresh()
                    end
                end)
            end }
        end
        items[#items + 1] = { text = L.MENU_SET_RANK, submenu = sub }
    else
        items[#items + 1] = { text = L.MENU_SET_RANK, disabled = true, tooltip = L.BLOCKED_BY_BLIZZARD }
    end

    -- guild note (blocked by Blizzard in WoW: Forever -> greyed out; a suggestion can be copied)
    if ns.Notes.IsAvailable() then
        items[#items + 1] = { text = L.MENU_WRITE_NOTE, func = function()
            ns.Dialogs.ShowWriteNote(row, c)
        end }
    else
        items[#items + 1] = { text = L.MENU_WRITE_NOTE, disabled = true, tooltip = L.BLOCKED_BY_BLIZZARD }
    end
    local suggestion = ns.Advice.suggestedNote(row, c, settings())
    if suggestion and suggestion ~= "" then
        items[#items + 1] = { text = L.MENU_COPY_NOTE, func = function()
            ns.Dialogs.ShowCopy(L.MENU_COPY_NOTE, suggestion, L.COPY_NOTE_HINT)
        end }
    end

    items[#items + 1] = { text = L.MENU_WHISPER .. (c.online and (" " .. W.ICON_ONLINE) or ""), func = function()
        whisper(c.fullName)
    end }
end

local function rowMenu(row)
    local E = ns.Engine
    local items = {}
    local m, p = row.member, row.player
    local title = m and m.display or (p and p.main.name) or "?"
    items[#items + 1] = { text = title, isTitle = true }

    if m and p and row.status ~= "ignored" then
        if row.status ~= "confirmed" then
            items[#items + 1] = { text = L.MENU_CONFIRM, func = function()
                E.Confirm(m.key, p.main.fullName)
            end }
        end
        items[#items + 1] = { text = L.MENU_REJECT, func = function()
            E.Reject(m.key, p.main.fullName)
        end }
    end

    -- assign another candidate
    if row.status ~= "ignored" and #row.alternatives > 0 then
        local sub = { { text = L.MENU_ASSIGN_OTHER, isTitle = true } }
        for _, alt in ipairs(row.alternatives) do
            if m and alt.player then
                sub[#sub + 1] = { text = string.format("%s (%d%%)", alt.player.main.name, alt.score * 100), func = function()
                    E.Confirm(m.key, alt.player.main.fullName)
                end }
            elseif p and alt.member then
                sub[#sub + 1] = { text = string.format("%s (%d%%)", alt.member.display, alt.score * 100), func = function()
                    E.Confirm(alt.member.key, p.main.fullName)
                end }
            end
        end
        items[#items + 1] = { text = L.MENU_ASSIGN_OTHER, submenu = sub }
    end
    if m and row.status ~= "ignored" then
        items[#items + 1] = { text = L.MENU_ASSIGN_BY_NAME, func = function()
            ns.Dialogs.ShowInput(L.MENU_ASSIGN_BY_NAME, string.format(L.ASSIGN_BY_NAME_LABEL, m.display), "", function(name)
                local c = findCharByName(name)
                if c then
                    E.Confirm(m.key, c.fullName)
                else
                    E.Print(string.format(L.ASSIGN_NOT_FOUND, name))
                end
            end)
        end }
    end
    if m and E.HasDecision(m.key) then
        items[#items + 1] = { text = L.MENU_RESET, func = function()
            E.ResetMember(m.key)
        end }
    end

    -- ignore
    if m then
        local ignored = row.status == "ignored"
        items[#items + 1] = { text = ignored and L.MENU_UNIGNORE_DISCORD or L.MENU_IGNORE_DISCORD, func = function()
            E.SetIgnoredMember(m.key, not ignored)
        end }
    elseif p then
        local ignored = row.status == "ignored"
        items[#items + 1] = { text = ignored and L.MENU_UNIGNORE_CHAR or L.MENU_IGNORE_CHAR, func = function()
            E.SetIgnoredChar(p.main.fullName, not ignored)
        end }
    end

    -- the main character (alts have their own menu in their rows)
    if p then
        addCharActions(items, row, p.main)
    end
    items[#items + 1] = { text = L.MENU_COPY_NAMES, func = function()
        local lines = {}
        if m then
            lines[#lines + 1] = m.display
        end
        for _, c in ipairs(ns.Advice.rowChars(row)) do
            lines[#lines + 1] = c.name
        end
        ns.Dialogs.ShowCopy(L.MENU_COPY_NAMES, table.concat(lines, "\n"))
    end }
    items[#items + 1] = { text = CLOSE or "Close" }
    ns.Menu.Open(items)
end

local function childMenu(item)
    local items = { { text = item.char.name, isTitle = true } }
    addCharActions(items, item.row, item.char)
    items[#items + 1] = { text = CLOSE or "Close" }
    ns.Menu.Open(items)
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
            if data.kind == "child" then
                childMenu(data)
            else
                rowMenu(data)
            end
        end
    end)
    return row
end

local function setIndent(row, indent)
    for c, fs in ipairs(row.cols) do
        fs:ClearAllPoints()
        fs:SetPoint("LEFT", row.colX[c] + indent, 0)
        local w = COLUMNS[c].width - 8
        if c == #row.cols then
            w = w - indent
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
        row.cols[2]:SetText("|cff999999" .. L.TOOLTIP_TWINK .. "|r")
        row.cols[3]:SetText("")
        row.cols[4]:SetText(charText(c) .. string.format(" |cff888888%s|r", c.level or ""))
        row.cols[5]:SetText(notesText(c))
        row.cols[6]:SetText(charRankText(parent, c))
        row.cols[7]:SetText(#(c.advice or {}) > 0 and ("|cffffaa44" .. shortList(c.advice) .. "|r") or "")
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
    row.cols[5]:SetText(notesText(data.player and data.player.main))
    row.cols[6]:SetText(rankText(data))
    local adv = rowAdvice(data)
    row.cols[7]:SetText(#adv > 0 and ("|cffffaa44" .. shortList(adv) .. "|r") or "")
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
    local search = W.EditBox(f, 170, 20)
    search:SetPoint("LEFT", searchLabel, "RIGHT", 10, 0)
    search:SetText(fl.search or "")
    search:SetScript("OnTextChanged", function(self)
        fl.search = self:GetText()
        f.Update()
    end)

    -- header
    local header = CreateFrame("Frame", nil, f)
    header:SetPoint("TOPLEFT", 0, -60)
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

    local refresh = W.Button(f, L.BTN_REFRESH, 150, 24, function()
        ns.Engine.Refresh()
    end)
    refresh:SetPoint("BOTTOMLEFT", 2, 4)

    local export = W.Button(f, L.BTN_EXPORT, 170, 24, function()
        ns.Dialogs.ShowCopy(L.BTN_EXPORT, exportText(f.parentRows or {}, false))
    end)
    export:SetPoint("LEFT", refresh, "RIGHT", 8, 0)

    local exportNames = W.Button(f, L.BTN_EXPORT_NAMES, 170, 24, function()
        ns.Dialogs.ShowCopy(L.BTN_EXPORT_NAMES, exportText(f.parentRows or {}, true))
    end)
    exportNames:SetPoint("LEFT", export, "RIGHT", 8, 0)

    local reset = W.Button(f, L.BTN_RESET_FILTERS, 170, 24, function()
        local defaults = ns.Util.copy(ns.DEFAULT_FILTERS)
        for k, v in pairs(defaults) do
            fl[k] = v
        end
        for status, cb in pairs(f.statusChecks) do
            cb:SetChecked(fl.status[status])
        end
        sideCycle.Refresh()
        rankCb:SetChecked(false)
        hintCb:SetChecked(false)
        onlineCb:SetChecked(false)
        search:SetText("")
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
        local items, rows = filteredRows()
        f.rows = items
        f.parentRows = rows or {}
        list:SetItems(items)
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
