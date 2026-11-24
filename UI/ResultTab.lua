-- The Guild Registrar - "Results" tab: filterable list of all assignments

local _, ns = ...

local L = ns.L
local W = ns.W
local Matcher = ns.Matcher

local COLUMNS = {
    { key = "status", title = "COL_STATUS", width = 120 },
    { key = "discord", title = "COL_DISCORD", width = 210 },
    { key = "char", title = "COL_CHARACTER", width = 200 },
    { key = "notes", title = "COL_NOTES", width = 200 },
    { key = "rank", title = "COL_RANK", width = 140 },
    { key = "hints", title = "COL_HINTS", width = 110 },
}

local ROW_HEIGHT = 20

local function filters()
    return ns.db.ui.filters
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

local function playerText(p, extras)
    if not p then
        return "|cff777777-|r"
    end
    local s = charText(p.main)
    local twinkCount = #p.twinks
    for _, ex in ipairs(extras or {}) do
        twinkCount = twinkCount + #ex.player.chars
    end
    if twinkCount > 0 then
        s = s .. string.format(" |cff999999(+%d)|r", twinkCount)
    end
    return s
end

local function notesText(p)
    if not p then
        return ""
    end
    local c = p.main
    local parts = {}
    if c.note and c.note ~= "" then
        parts[#parts + 1] = c.note
    end
    if c.officerNote and c.officerNote ~= "" then
        parts[#parts + 1] = "|cff88aaff" .. c.officerNote .. "|r"
    end
    return table.concat(parts, " · ")
end

local function rankText(row)
    local r = row.rank
    if not r then
        if row.player then
            return "|cff999999" .. (row.player.main.rankName or "") .. "|r"
        end
        return ""
    end
    if r.state == "ok" then
        return W.ICON_OK .. " " .. (row.player.main.rankName or "")
    elseif r.state == "mismatch" then
        local expectedName = ns.state.rankNames[r.expected] or ("#" .. r.expected)
        return W.ICON_BAD .. " " .. (row.player.main.rankName or "?") .. " -> " .. expectedName
    elseif r.state == "unmapped" then
        return W.ICON_UNKNOWN .. " " .. (row.player.main.rankName or "")
    end
    return "|cff999999" .. (row.player.main.rankName or "") .. "|r"
end

local function hintList(row)
    local list = {}
    local fl = row.flags
    if fl.ruleFormat then
        list[#list + 1] = L.HINT_RULE_FORMAT
    end
    if fl.ruleReversed then
        list[#list + 1] = L.HINT_RULE_REVERSED
    end
    if fl.guestInGuild then
        list[#list + 1] = L.HINT_GUEST_IN_GUILD
    end
    if fl.orphanTwink then
        list[#list + 1] = L.HINT_ORPHAN_TWINK
    end
    if fl.confirmedMissing then
        list[#list + 1] = string.format(L.HINT_CONFIRMED_MISSING, fl.confirmedMissing)
    end
    return list
end

local function sideText(row)
    if row.side == "discordOnly" then
        return L.SIDE_DISCORD_ONLY
    elseif row.side == "wowOnly" then
        return L.SIDE_WOW_ONLY
    end
    return nil
end

-- Filtering and sorting --------------------------------------------------------------

local function matchesSearch(row, needle)
    if needle == "" then
        return true
    end
    local hay = {}
    if row.member then
        hay[#hay + 1] = row.member.display
        hay[#hay + 1] = table.concat(row.member.roles, " ")
    end
    if row.player then
        for _, c in ipairs(row.player.chars) do
            hay[#hay + 1] = c.name
            hay[#hay + 1] = c.note or ""
            hay[#hay + 1] = c.officerNote or ""
        end
    end
    local text = ns.Text.lower(table.concat(hay, " "))
    return text:find(needle, 1, true) ~= nil
end

local function isOnline(row)
    if not row.player then
        return false
    end
    for _, c in ipairs(row.player.chars) do
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
        return -#hintList(row)
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
        if ok and f.ruleIssues and #hintList(row) == 0 then
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
    return out
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

local function showTooltip(owner, row)
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
        local chars = {}
        for _, c in ipairs(row.player.chars) do
            chars[#chars + 1] = c
        end
        for _, ex in ipairs(row.extras or {}) do
            for _, c in ipairs(ex.player.chars) do
                chars[#chars + 1] = c
            end
        end
        for _, c in ipairs(chars) do
            local label = (c == row.player.main) and L.TOOLTIP_MAIN or L.TOOLTIP_TWINK
            GameTooltip:AddDoubleLine(label .. ": " .. charText(c) .. string.format(" |cffaaaaaa(%s)|r", c.level or "?"),
                c.rankName or "", 1, 1, 1, 0.8, 0.8, 0.8)
            if c.note and c.note ~= "" then
                GameTooltip:AddLine("   " .. L.NOTE_PUBLIC .. ": " .. c.note, 0.9, 0.9, 0.9, true)
            end
            if c.officerNote and c.officerNote ~= "" then
                GameTooltip:AddLine("   " .. L.NOTE_OFFICER .. ": " .. c.officerNote, 0.55, 0.7, 1, true)
            end
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
    local hints = hintList(row)
    if #hints > 0 then
        GameTooltip:AddLine(" ")
        for _, h in ipairs(hints) do
            GameTooltip:AddLine("- " .. h, 1, 0.7, 0.3, true)
        end
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

local function contextMenu(row)
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
                local res = ns.state.results
                local key = ns.Text.key(name)
                for _, r in ipairs(res and res.rows or {}) do
                    if r.player then
                        for _, c in ipairs(r.player.chars) do
                            if ns.Text.key(c.name) == key or ns.Text.key(c.fullName) == key then
                                E.Confirm(m.key, c.fullName)
                                return
                            end
                        end
                    end
                end
                ns.Engine.Print(string.format(L.ASSIGN_NOT_FOUND, name))
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

    -- notes, whisper, copy
    if p then
        local chars = {}
        for _, c in ipairs(p.chars) do
            chars[#chars + 1] = c
        end
        for _, ex in ipairs(row.extras or {}) do
            for _, c in ipairs(ex.player.chars) do
                chars[#chars + 1] = c
            end
        end
        local noteSub = { { text = L.MENU_WRITE_NOTE, isTitle = true } }
        local whisperSub = { { text = L.MENU_WHISPER, isTitle = true } }
        for _, c in ipairs(chars) do
            noteSub[#noteSub + 1] = { text = c.name, func = function()
                ns.Dialogs.ShowWriteNote(row, c)
            end }
            whisperSub[#whisperSub + 1] = { text = c.name .. (c.online and (" " .. W.ICON_ONLINE) or ""), func = function()
                whisper(c.fullName)
            end }
        end
        if #chars == 1 then
            items[#items + 1] = { text = L.MENU_WRITE_NOTE, func = noteSub[2].func }
            items[#items + 1] = { text = L.MENU_WHISPER, func = whisperSub[2].func }
        else
            items[#items + 1] = { text = L.MENU_WRITE_NOTE, submenu = noteSub }
            items[#items + 1] = { text = L.MENU_WHISPER, submenu = whisperSub }
        end
    end
    items[#items + 1] = { text = L.MENU_COPY_NAMES, func = function()
        local lines = {}
        if m then
            lines[#lines + 1] = m.display
        end
        if p then
            for _, c in ipairs(p.chars) do
                lines[#lines + 1] = c.name
            end
        end
        ns.Dialogs.ShowCopy(L.MENU_COPY_NAMES, table.concat(lines, "\n"))
    end }
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
            if row.player and #row.player.twinks > 0 then
                local tw = {}
                for _, c in ipairs(row.player.twinks) do
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
                parts[#parts + 1] = table.concat(hints, ", ")
            end
            lines[#lines + 1] = table.concat(parts, " | ")
        end
    end
    return table.concat(lines, "\n")
end

-- Layout ---------------------------------------------------------------------------------

local function createRow(list, i)
    local row = CreateFrame("Button", nil, list)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.04 or 0)
    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(0.3, 0.5, 0.9, 0.25)
    row.cols = {}
    local x = 4
    for c, col in ipairs(COLUMNS) do
        local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("LEFT", x, 0)
        fs:SetWidth(col.width - 8)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(false)
        row.cols[c] = fs
        x = x + col.width
    end
    row:SetScript("OnEnter", function(self)
        if self.data then
            showTooltip(self, self.data)
        end
    end)
    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    row:SetScript("OnClick", function(self, button)
        if self.data and button == "RightButton" then
            GameTooltip:Hide()
            contextMenu(self.data)
        end
    end)
    return row
end

local function updateRow(row, data)
    row.data = data
    row.cols[1]:SetText(statusText(data.status) .. (data.score and data.status ~= "confirmed"
        and string.format(" |cff888888%d%%|r", data.score * 100) or ""))
    row.cols[2]:SetText(data.member and data.member.display or ("|cff777777" .. L.SIDE_NO_DISCORD .. "|r"))
    row.cols[3]:SetText(data.player and playerText(data.player, data.extras) or ("|cff777777" .. L.SIDE_NO_CHAR .. "|r"))
    row.cols[4]:SetText(notesText(data.player))
    row.cols[5]:SetText(rankText(data))
    local hints = hintList(data)
    row.cols[6]:SetText(#hints > 0 and ("|cffffaa44" .. table.concat(hints, ", ") .. "|r") or "")
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
        b:SetScript("OnClick", function()
            if fl.sortKey == col.key then
                fl.sortAsc = not fl.sortAsc
            else
                fl.sortKey, fl.sortAsc = col.key, true
            end
            f.Update()
        end)
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
        ns.Dialogs.ShowCopy(L.BTN_EXPORT, exportText(f.rows or {}, false))
    end)
    export:SetPoint("LEFT", refresh, "RIGHT", 8, 0)

    local exportNames = W.Button(f, L.BTN_EXPORT_NAMES, 170, 24, function()
        ns.Dialogs.ShowCopy(L.BTN_EXPORT_NAMES, exportText(f.rows or {}, true))
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
            local arrow = ""
            if fl.sortKey == b.col.key then
                arrow = fl.sortAsc and " (+)" or " (-)"
            end
            b.text:SetText(L[b.col.title] .. arrow)
        end
        local rows = filteredRows()
        f.rows = rows
        list:SetItems(rows)
        if state.running then
            f.empty:SetText(L.STATUS_RUNNING)
        elseif state.error then
            f.empty:SetText(L[state.error])
        elseif state.results and #rows == 0 then
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
                string.format("|cffffaa44%d %s|r", s.ruleIssues, L.SUMMARY_RULE_ISSUES),
            }
            f.summary:SetText(table.concat(parts, "   ") .. string.format("   |cff888888(%s: %d)|r", L.SUMMARY_SHOWN, #rows))
        else
            f.summary:SetText("")
        end
    end
    return f
end

local function refresh(f)
    f.Update()
end

ns.UI.RegisterTab({ key = "results", order = 3, title = L.TAB_RESULTS, create = create, refresh = refresh })
