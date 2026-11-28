-- The Guild Registrar - "Settings" tab with sub pages (settings are stored per guild)
--   General (this file), Ranks (RanksTab.lua), Dungeon roles (DungeonRolesTab.lua), Notes (this file)

local _, ns = ...

local L = ns.L
local W = ns.W

local function settings()
    local g = ns.DB.Guild()
    return g and g.settings
end

local function rerun()
    ns.Engine.Run()
end

-- Section title; `key` is a locale key (kept up to date when the alt term changes).
local function section(f, key, x, y)
    local fs = W.Localized(W.Label(f, "", "GameFontNormalLarge"), key)
    fs:SetPoint("TOPLEFT", x, y)
    return fs
end

local function createGeneral(parent)
    local f = CreateFrame("Frame", nil, parent)
    local controls = {}
    f.controls = controls

    local x1, x2 = 8, 520
    local y = -6

    -- notes ---------------------------------------------------------------------------
    section(f, "OPT_SECTION_NOTES", x1, y)
    local notesLabel = W.Label(f, L.OPT_NOTES_USED, "GameFontHighlight")
    notesLabel:SetPoint("TOPLEFT", x1 + 4, y - 28)
    controls.notes = W.Cycle(f, 230, {
        { value = "both", text = L.NOTES_SOURCE_BOTH },
        { value = "public", text = L.NOTES_SOURCE_PUBLIC },
        { value = "officer", text = L.NOTES_SOURCE_OFFICER },
        { value = "none", text = L.NOTES_SOURCE_NONE },
    }, function()
        local s = settings()
        if not s then
            return "both"
        elseif s.useNote and s.useOfficerNote then
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
        rerun()
    end)
    controls.notes:SetPoint("TOPLEFT", x1 + 150, y - 24)
    W.Tooltip(controls.notes, L.OPT_NOTES_USED, function()
        return L.NOTES_SOURCE_TOOLTIP .. "\n\n" .. L.OPT_USE_OFFICER_NOTE_TOOLTIP
    end)
    local notesHint = W.Localized(W.Label(f, "", "GameFontDisableSmall"), "OPT_NOTES_HINT")
    notesHint:SetPoint("TOPLEFT", x1 + 4, y - 50)
    notesHint:SetWidth(480)
    notesHint:SetJustifyV("TOP")

    -- naming rule ------------------------------------------------------------------------
    y = y - 76
    section(f, "OPT_SECTION_RULE", x1, y)
    controls.ruleEnabled = W.Check(f, L.OPT_RULE_ENABLED, function(_, v)
        settings().nameRule.enabled = v
        rerun()
    end, L.OPT_RULE_TOOLTIP)
    controls.ruleEnabled:SetPoint("TOPLEFT", x1, y - 22)

    local sepLabel = W.Label(f, L.OPT_RULE_SEPARATOR, "GameFontHighlight")
    sepLabel:SetPoint("TOPLEFT", x1 + 4, y - 56)
    controls.separator = W.EditBox(f, 50, 20)
    controls.separator:SetPoint("LEFT", sepLabel, "RIGHT", 10, 0)
    controls.separator:SetScript("OnEditFocusLost", function(self)
        local v = ns.Util.trim(self:GetText())
        if v == "" then
            v = "|"
        end
        settings().nameRule.separator = v
        self:SetText(v)
        rerun()
    end)

    local orderLabel = W.Label(f, L.OPT_RULE_ORDER, "GameFontHighlight")
    orderLabel:SetPoint("LEFT", controls.separator, "RIGHT", 24, 0)
    controls.order = W.Cycle(f, 210, {
        { value = "nick_main", text = L.OPT_RULE_NICK_MAIN },
        { value = "main_nick", text = L.OPT_RULE_MAIN_NICK },
        { value = "any", text = L.OPT_RULE_ANY },
    }, function()
        local s = settings()
        return s and s.nameRule.order or "nick_main"
    end, function(v)
        settings().nameRule.order = v
        rerun()
    end)
    controls.order:SetPoint("LEFT", orderLabel, "RIGHT", 10, 0)

    -- twinks ---------------------------------------------------------------------------
    y = y - 96
    section(f, "OPT_SECTION_TWINKS", x1, y)
    controls.twinkByRank = W.Check(f, L.OPT_TWINK_BY_RANK, function(_, v)
        settings().twinkByRank = v
        rerun()
    end, W.LocText("OPT_TWINK_BY_RANK_TOOLTIP"))
    controls.twinkByRank:SetPoint("TOPLEFT", x1, y - 22)
    controls.twinkByNote = W.Check(f, L.OPT_TWINK_BY_NOTE, function(_, v)
        settings().twinkByNote = v
        rerun()
    end, W.LocText("OPT_TWINK_BY_NOTE_TOOLTIP"))
    controls.twinkByNote:SetPoint("TOPLEFT", x1 + 230, y - 22)

    -- what alts are called in the addon
    local termLabel = W.Label(f, L.OPT_ALT_TERM, "GameFontHighlight")
    termLabel:SetPoint("TOPLEFT", x1 + 230, y - 2)
    controls.altTerm = W.Cycle(f, 100, {
        { value = "twink", text = L.OPT_ALT_TERM_TWINK },
        { value = "alt", text = L.OPT_ALT_TERM_ALT },
    }, function()
        local s = settings()
        return s and s.altTerm or ns.DEFAULT_SETTINGS.altTerm
    end, function(v)
        settings().altTerm = v
        ns.SetAltTerm(v)
        rerun()
    end)
    controls.altTerm:SetPoint("LEFT", termLabel, "RIGHT", 8, 0)

    -- thresholds ---------------------------------------------------------------------
    y = y - 60
    section(f, "OPT_SECTION_THRESHOLDS", x1, y)
    local thFields = {
        { key = "sure", label = L.STATUS_SURE },
        { key = "likely", label = L.STATUS_LIKELY },
        { key = "unlikely", label = L.STATUS_UNLIKELY },
        { key = "margin", label = L.OPT_MARGIN },
    }
    controls.thresholds = {}
    for i, fdef in ipairs(thFields) do
        local lbl = W.Label(f, fdef.label, "GameFontHighlight")
        lbl:SetPoint("TOPLEFT", x1 + 4 + (i - 1) * 120, y - 26)
        local eb = W.EditBox(f, 44, 20)
        eb:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", 4, -4)
        eb:SetNumeric(false)
        eb:SetScript("OnEditFocusLost", function(self)
            local v = tonumber((self:GetText():gsub(",", ".")))
            local s = settings()
            if v then
                if v > 1 then
                    v = v / 100
                end
                s.thresholds[fdef.key] = math.max(0, math.min(1, v))
                rerun()
            end
            self:SetText(tostring(math.floor(s.thresholds[fdef.key] * 100 + 0.5)))
        end)
        local pct = W.Label(f, "%", "GameFontHighlight")
        pct:SetPoint("LEFT", eb, "RIGHT", 4, 0)
        controls.thresholds[fdef.key] = eb
    end
    local thHint = W.Label(f, L.OPT_THRESHOLDS_HINT, "GameFontDisableSmall")
    thHint:SetPoint("TOPLEFT", x1 + 4, y - 76)
    thHint:SetWidth(480)
    thHint:SetJustifyV("TOP")

    -- right column: lists ----------------------------------------------------------------
    local ry = -6
    section(f, "OPT_TWINK_PATTERNS", x2, ry)
    local pHint = W.Localized(W.Label(f, "", "GameFontDisableSmall"), "OPT_TWINK_PATTERNS_HINT")
    pHint:SetPoint("TOPLEFT", x2, ry - 22)
    pHint:SetWidth(480)
    pHint:SetJustifyV("TOP")
    local pBox, pEdit = W.MultiLine(f, 480, 130)
    pBox:SetPoint("TOPLEFT", x2, ry - 52)
    controls.patterns = pEdit

    ry = ry - 196
    section(f, "OPT_STOPWORDS", x2, ry)
    local sHint = W.Label(f, L.OPT_STOPWORDS_HINT, "GameFontDisableSmall")
    sHint:SetPoint("TOPLEFT", x2, ry - 22)
    sHint:SetWidth(480)
    sHint:SetJustifyV("TOP")
    local sBox, sEdit = W.MultiLine(f, 480, 130)
    sBox:SetPoint("TOPLEFT", x2, ry - 52)
    controls.stopwords = sEdit

    local apply = W.Button(f, L.OPT_APPLY_LISTS, 200, 24, function()
        local s = settings()
        s.twinkPatterns = ns.Util.linesToList(pEdit:GetText())
        local words = {}
        for _, line in ipairs(ns.Util.linesToList(sEdit:GetText())) do
            for w in line:gmatch("[^,;%s]+") do
                words[#words + 1] = w
            end
        end
        s.stopwords = words
        pEdit:ClearFocus()
        sEdit:ClearFocus()
        f.Load()
        rerun()
    end)
    apply:SetPoint("TOPLEFT", sBox, "BOTTOMLEFT", 0, -8)

    -- search in the Comparison tab
    controls.searchTypos = W.Check(f, L.OPT_SEARCH_TYPOS, function(_, v)
        settings().searchTypos = v
    end, L.OPT_SEARCH_TYPOS_TOOLTIP)
    controls.searchTypos:SetPoint("TOPLEFT", apply, "BOTTOMLEFT", 0, -12)

    -- bottom buttons --------------------------------------------------------------------
    local resetSettings = W.Button(f, L.OPT_RESET_SETTINGS, 210, 24, function()
        ns.Dialogs.ShowDeleteWarning(L.OPT_RESET_SETTINGS, L.OPT_RESET_SETTINGS_CONFIRM, ns.Protect.Settings(settings()), function()
            ns.DB.ResetSettings()
            f.Load()
            rerun()
        end, L.PROTECT_RESET)
    end)
    resetSettings:SetPoint("BOTTOMLEFT", 4, 4)
    local function decisions()
        local g = ns.DB.Guild()
        return g and g.decisions
    end
    local clearDecisions = W.Button(f, L.OPT_CLEAR_DECISIONS, 240, 24, function()
        ns.Dialogs.ShowDeleteWarning(L.OPT_CLEAR_DECISIONS, L.OPT_CLEAR_DECISIONS_CONFIRM,
            ns.Protect.Decisions(decisions(), "decisions"), function()
                ns.DB.ClearDecisions("decisions")
                rerun()
            end)
    end)
    clearDecisions:SetPoint("LEFT", resetSettings, "RIGHT", 8, 0)
    local clearIgnored = W.Button(f, L.OPT_CLEAR_IGNORED, 210, 24, function()
        ns.Dialogs.ShowDeleteWarning(L.OPT_CLEAR_IGNORED, L.OPT_CLEAR_IGNORED_CONFIRM,
            ns.Protect.Decisions(decisions(), "ignored"), function()
                ns.DB.ClearDecisions("ignored")
                rerun()
            end)
    end)
    clearIgnored:SetPoint("LEFT", clearDecisions, "RIGHT", 8, 0)

    function f.Load()
        local s = settings()
        if not s then
            return
        end
        controls.notes.Refresh()
        controls.ruleEnabled:SetChecked(s.nameRule.enabled)
        controls.separator:SetText(s.nameRule.separator or "|")
        controls.order.Refresh()
        controls.twinkByRank:SetChecked(s.twinkByRank)
        controls.twinkByNote:SetChecked(s.twinkByNote)
        controls.searchTypos:SetChecked(s.searchTypos ~= false)
        for key, eb in pairs(controls.thresholds) do
            eb:SetText(tostring(math.floor((s.thresholds[key] or 0) * 100 + 0.5)))
        end
        controls.altTerm.Refresh()
        controls.patterns:SetText(ns.Util.listToLines(s.twinkPatterns))
        controls.stopwords:SetText(table.concat(s.stopwords or {}, ", "))
    end
    return f
end

local function refreshGeneral(f)
    -- do not overwrite fields the user is currently editing
    local c = f.controls
    local boxes = { c.patterns, c.stopwords, c.separator }
    for _, eb in pairs(c.thresholds) do
        boxes[#boxes + 1] = eb
    end
    for _, eb in ipairs(boxes) do
        if eb:HasFocus() then
            return
        end
    end
    f.Load()
end

-- Notes page: four templates (main / alt x public / officer note), one check box per note,
-- abbreviations for dungeon roles and professions ---------------------------------------------

local TEMPLATE_ROWS = { { key = "main", label = "NOTES_ROW_MAIN" }, { key = "twink", label = "NOTES_ROW_TWINK" } }
local TEMPLATE_COLS = {
    { kind = "public", suffix = "Public", title = "NOTE_PUBLIC", check = "noteCheckPublic", checkLabel = "NOTES_CHECK_PUBLIC" },
    { kind = "officer", suffix = "Officer", title = "NOTE_OFFICER", check = "noteCheckOfficer", checkLabel = "NOTES_CHECK_OFFICER" },
}
local PROFESSIONS = { "alchemy", "blacksmithing", "enchanting", "engineering", "herbalism", "leatherworking",
    "mining", "skinning", "tailoring", "cooking", "fishing", "firstaid" }

-- Grey out an edit box (and show it as not editable).
local function setBoxEnabled(eb, on)
    eb:SetEnabled(on)
    if on then
        eb:SetTextColor(1, 1, 1)
    else
        eb:SetTextColor(0.45, 0.45, 0.45)
        eb:ClearFocus()
    end
end

local function createNotes(parent)
    local f = CreateFrame("Frame", nil, parent)
    local controls = { templates = {}, checks = {}, roleAbbr = {}, profAbbr = {} }
    f.controls = controls
    local x1 = 8
    local colX = { 120, 570 }
    local boxW = 420

    -- templates ---------------------------------------------------------------------------
    section(f, "OPT_SECTION_WRITE", x1, -6)
    for ci, col in ipairs(TEMPLATE_COLS) do
        local head = W.Label(f, L[col.title], "GameFontNormal")
        head:SetPoint("TOPLEFT", colX[ci] + 4, -34)
    end
    for ri, rowDef in ipairs(TEMPLATE_ROWS) do
        local y = -54 - (ri - 1) * 28
        local lbl = W.Localized(W.Label(f, "", "GameFontHighlight"), rowDef.label)
        lbl:SetPoint("TOPLEFT", x1 + 4, y - 4)
        for ci, col in ipairs(TEMPLATE_COLS) do
            local key = rowDef.key .. col.suffix
            local eb = W.EditBox(f, boxW, 20)
            eb:SetPoint("TOPLEFT", colX[ci] + 6, y)
            eb:SetScript("OnEditFocusLost", function(self)
                local s = settings()
                if s then
                    s.noteTemplates[key] = self:GetText()
                    rerun()
                end
            end)
            controls.templates[key] = eb
        end
    end
    -- one check box below each column: switches the note check and its templates on/off
    for ci, col in ipairs(TEMPLATE_COLS) do
        local cb = W.Check(f, L[col.checkLabel], function(_, checked)
            local s = settings()
            if s then
                s[col.check] = checked
                f.Load()
                rerun()
            end
        end, W.LocText("NOTES_CHECK_TOOLTIP"))
        cb:SetPoint("TOPLEFT", colX[ci], -54 - #TEMPLATE_ROWS * 28 - 2)
        controls.checks[col.check] = cb
    end
    local phHint = W.Localized(W.Label(f, "", "GameFontDisableSmall"), "OPT_PLACEHOLDERS")
    phHint:SetPoint("TOPLEFT", x1 + 4, -54 - #TEMPLATE_ROWS * 28 - 34)
    phHint:SetWidth(990)
    phHint:SetJustifyV("TOP")

    -- abbreviations -------------------------------------------------------------------------
    local ay = -210
    section(f, "NOTES_ABBR", x1, ay)
    local abbrHint = W.Label(f, L.NOTES_ABBR_HINT, "GameFontDisableSmall")
    abbrHint:SetPoint("TOPLEFT", x1 + 4, ay - 22)
    abbrHint:SetWidth(990)
    abbrHint:SetJustifyV("TOP")

    local function abbrBox(x, y, label, width, onSave)
        local lbl = W.Label(f, label, "GameFontHighlight")
        lbl:SetPoint("TOPLEFT", x, y - 4)
        lbl:SetWidth(150)
        lbl:SetWordWrap(false)
        local eb = W.EditBox(f, width or 80, 20)
        eb:SetPoint("TOPLEFT", x + 156, y)
        eb:SetScript("OnEditFocusLost", function(self)
            onSave(ns.Util.trim(self:GetText()))
            rerun()
        end)
        return eb
    end

    local sub1 = W.Label(f, L.COL_DUNGEON_ROLES_LONG, "GameFontNormal")
    sub1:SetPoint("TOPLEFT", x1 + 4, ay - 52)
    for i, r in ipairs(ns.DungeonRoles.ROLES) do
        controls.roleAbbr[r] = abbrBox(x1 + 4 + (i - 1) * 250, ay - 72,
            W.RoleIcon(r, 14) .. " " .. L["DROLE_" .. r:upper()], 70, function(v)
                local s = settings()
                if s then
                    s.abbreviations.roles[r] = v
                end
            end)
    end

    local sub2 = W.Label(f, L.NOTES_ABBR_PROFESSIONS, "GameFontNormal")
    sub2:SetPoint("TOPLEFT", x1 + 4, ay - 108)
    for i, p in ipairs(PROFESSIONS) do
        local col, row = (i - 1) % 4, math.floor((i - 1) / 4)
        controls.profAbbr[p] = abbrBox(x1 + 4 + col * 250, ay - 128 - row * 26, L["PROF_" .. p:upper()], 70, function(v)
            local s = settings()
            if s then
                s.abbreviations.professions[p] = v
            end
        end)
    end

    -- preparing notes ----------------------------------------------------------------------
    local py = -420
    section(f, "NOTES_PREPARE", x1, py)
    controls.prepare = {}
    for i, opt in ipairs({ "notesCompanion", "notesCopyBox", "notesTickFeedback" }) do
        local key = "NOTES_OPT_" .. opt:sub(6):upper()
        local cb = W.Check(f, L[key], function(_, checked)
            local s = settings()
            if s then
                s[opt] = checked
            end
        end, W.LocText(key .. "_TOOLTIP"))
        cb:SetPoint("TOPLEFT", x1 + (i - 1) * 330, py - 24)
        controls.prepare[opt] = cb
    end

    function f.Load()
        local s = settings()
        if not s then
            return
        end
        for opt, cb in pairs(controls.prepare) do
            cb:SetChecked(s[opt] ~= false)
        end
        for ci, col in ipairs(TEMPLATE_COLS) do
            local on = s[col.check] and true or false
            controls.checks[col.check]:SetChecked(on)
            for _, rowDef in ipairs(TEMPLATE_ROWS) do
                local eb = controls.templates[rowDef.key .. col.suffix]
                eb:SetText(s.noteTemplates[rowDef.key .. col.suffix] or "")
                setBoxEnabled(eb, on)
            end
        end
        for r, eb in pairs(controls.roleAbbr) do
            eb:SetText(s.abbreviations.roles[r] or "")
        end
        for p, eb in pairs(controls.profAbbr) do
            eb:SetText(s.abbreviations.professions[p] or "")
        end
    end
    return f
end

local function refreshNotes(f)
    local c = f.controls
    for _, group in ipairs({ c.templates, c.roleAbbr, c.profAbbr }) do
        for _, eb in pairs(group) do
            if eb:HasFocus() then
                return
            end
        end
    end
    f.Load()
end

-- Container: sub tabs above the pages --------------------------------------------------------
local function createContainer(parent)
    local f = CreateFrame("Frame", nil, parent)
    f.pages, f.buttons = {}, {}
    local host = CreateFrame("Frame", nil, f)
    host:SetPoint("TOPLEFT", 0, -32)
    host:SetPoint("BOTTOMRIGHT", 0, 0)
    local line = f:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 0.82, 0, 0.35)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", 0, -28)
    line:SetPoint("RIGHT", 0, 0)

    local prev
    for _, def in ipairs(ns.UI.settingsPages) do
        local b = W.Button(f, def.title, 160, 22, function()
            f.Select(def.key)
        end)
        if prev then
            b:SetPoint("LEFT", prev, "RIGHT", 4, 0)
        else
            b:SetPoint("TOPLEFT", 4, -2)
        end
        b.key = def.key
        f.buttons[#f.buttons + 1] = b
        prev = b
    end

    function f.Select(key)
        local found
        for _, def in ipairs(ns.UI.settingsPages) do
            if def.key == key then
                found = def
            end
        end
        found = found or ns.UI.settingsPages[1]
        for _, def in ipairs(ns.UI.settingsPages) do
            local page = f.pages[def.key]
            if def == found then
                if not page then
                    page = def.create(host)
                    page:SetAllPoints(host)
                    f.pages[def.key] = page
                end
                page:Show()
                if def.refresh then
                    def.refresh(page)
                end
            elseif page then
                page:Hide()
            end
        end
        for _, b in ipairs(f.buttons) do
            local fs = b:GetFontString()
            if b.key == found.key then
                b:LockHighlight()
                if fs then
                    fs:SetTextColor(1, 1, 1)
                end
            else
                b:UnlockHighlight()
                if fs then
                    fs:SetTextColor(1, 0.82, 0)
                end
            end
        end
        f.current = found.key
        if ns.db then
            ns.db.ui.settingsPage = found.key
        end
    end
    return f
end

local function refreshContainer(f)
    local want = ns.UI.settingsPageRequest
    ns.UI.settingsPageRequest = nil
    f.Select(want or f.current or (ns.db and ns.db.ui.settingsPage) or "general")
end

ns.UI.RegisterSettingsPage({ key = "general", order = 1, title = L.SETTINGS_PAGE_GENERAL, create = createGeneral, refresh = refreshGeneral })
ns.UI.RegisterSettingsPage({ key = "notes", order = 4, title = L.SETTINGS_PAGE_NOTES, create = createNotes, refresh = refreshNotes })
ns.UI.RegisterTab({ key = "options", order = 4, title = L.TAB_OPTIONS, create = createContainer, refresh = refreshContainer })

