-- The Guild Registrar - "Options" tab (settings are stored per guild)

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

local function create(parent)
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

    -- note templates --------------------------------------------------------------
    y = y - 120
    section(f, "OPT_SECTION_WRITE", x1, y)
    local t1 = W.Label(f, L.OPT_NOTE_TEMPLATE, "GameFontHighlight")
    t1:SetPoint("TOPLEFT", x1 + 4, y - 28)
    controls.noteTemplate = W.EditBox(f, 200, 20)
    controls.noteTemplate:SetPoint("TOPLEFT", x1 + 180, y - 24)
    controls.noteTemplate:SetScript("OnEditFocusLost", function(self)
        settings().noteTemplate = self:GetText()
    end)
    local t2 = W.Localized(W.Label(f, "", "GameFontHighlight"), "OPT_TWINK_NOTE_TEMPLATE")
    t2:SetPoint("TOPLEFT", x1 + 4, y - 54)
    controls.twinkNoteTemplate = W.EditBox(f, 200, 20)
    controls.twinkNoteTemplate:SetPoint("TOPLEFT", x1 + 180, y - 50)
    controls.twinkNoteTemplate:SetScript("OnEditFocusLost", function(self)
        settings().twinkNoteTemplate = self:GetText()
    end)
    controls.noteTemplate:HookScript("OnEditFocusLost", rerun)
    controls.twinkNoteTemplate:HookScript("OnEditFocusLost", rerun)

    -- default write mode: only useful while writing notes is allowed (see ns.FEATURES)
    local t3 = W.Label(f, L.OPT_NOTE_MODE, "GameFontHighlight")
    t3:SetPoint("TOPLEFT", x1 + 4, y - 80)
    controls.noteMode = W.Cycle(f, 160, {
        { value = "append", text = L.NOTE_MODE_APPEND },
        { value = "replace", text = L.NOTE_MODE_REPLACE },
    }, function()
        local s = settings()
        return s and s.noteWriteMode or "append"
    end, function(v)
        settings().noteWriteMode = v
    end)
    controls.noteMode:SetPoint("TOPLEFT", x1 + 180, y - 76)

    -- note check (in place of the write mode while writing is blocked)
    local t4 = W.Label(f, L.OPT_NOTE_CHECK, "GameFontHighlight")
    t4:SetPoint("TOPLEFT", x1 + 4, y - 80)
    controls.noteCheck = W.Cycle(f, 160, {
        { value = "officer", text = L.OPT_NOTE_CHECK_OFFICER },
        { value = "public", text = L.OPT_NOTE_CHECK_PUBLIC },
        { value = "off", text = L.OPT_NOTE_CHECK_OFF },
    }, function()
        local s = settings()
        return s and s.noteCheck or "officer"
    end, function(v)
        settings().noteCheck = v
        rerun()
    end)
    controls.noteCheck:SetPoint("TOPLEFT", x1 + 180, y - 76)
    W.Tooltip(controls.noteCheck, L.OPT_NOTE_CHECK, W.LocText("OPT_NOTE_CHECK_TOOLTIP"))
    if ns.Notes.IsAvailable() then
        t4:Hide()
        controls.noteCheck:Hide()
    else
        t3:Hide()
        controls.noteMode:Hide()
    end
    local phHint = W.Localized(W.Label(f, "", "GameFontDisableSmall"), "OPT_PLACEHOLDERS")
    phHint:SetPoint("TOPLEFT", x1 + 4, y - 104)
    phHint:SetWidth(480)
    phHint:SetJustifyV("TOP")

    -- right column: lists ----------------------------------------------------------------
    local ry = -6
    section(f, "OPT_TWINK_PATTERNS", x2, ry)
    local pHint = W.Localized(W.Label(f, "", "GameFontDisableSmall"), "OPT_TWINK_PATTERNS_HINT")
    pHint:SetPoint("TOPLEFT", x2, ry - 22)
    pHint:SetWidth(480)
    pHint:SetJustifyV("TOP")
    local pBox, pEdit = W.MultiLine(f, 480, 150)
    pBox:SetPoint("TOPLEFT", x2, ry - 52)
    controls.patterns = pEdit

    ry = ry - 216
    section(f, "OPT_STOPWORDS", x2, ry)
    local sHint = W.Label(f, L.OPT_STOPWORDS_HINT, "GameFontDisableSmall")
    sHint:SetPoint("TOPLEFT", x2, ry - 22)
    sHint:SetWidth(480)
    sHint:SetJustifyV("TOP")
    local sBox, sEdit = W.MultiLine(f, 480, 150)
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
        ns.Dialogs.ShowConfirm(L.OPT_RESET_SETTINGS, L.OPT_RESET_SETTINGS_CONFIRM, function()
            ns.DB.ResetSettings()
            f.Load()
            rerun()
        end)
    end)
    resetSettings:SetPoint("BOTTOMLEFT", 4, 4)
    local clearDecisions = W.Button(f, L.OPT_CLEAR_DECISIONS, 240, 24, function()
        ns.Dialogs.ShowConfirm(L.OPT_CLEAR_DECISIONS, L.OPT_CLEAR_DECISIONS_CONFIRM, function()
            ns.DB.ClearDecisions("decisions")
            rerun()
        end)
    end)
    clearDecisions:SetPoint("LEFT", resetSettings, "RIGHT", 8, 0)
    local clearIgnored = W.Button(f, L.OPT_CLEAR_IGNORED, 210, 24, function()
        ns.Dialogs.ShowConfirm(L.OPT_CLEAR_IGNORED, L.OPT_CLEAR_IGNORED_CONFIRM, function()
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
        controls.noteTemplate:SetText(s.noteTemplate or "")
        controls.twinkNoteTemplate:SetText(s.twinkNoteTemplate or "")
        controls.noteMode.Refresh()
        controls.noteCheck.Refresh()
        controls.altTerm.Refresh()
        controls.patterns:SetText(ns.Util.listToLines(s.twinkPatterns))
        controls.stopwords:SetText(table.concat(s.stopwords or {}, ", "))
    end
    return f
end

local function refresh(f)
    -- do not overwrite fields the user is currently editing
    local c = f.controls
    local boxes = { c.patterns, c.stopwords, c.separator, c.noteTemplate, c.twinkNoteTemplate }
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

ns.UI.RegisterTab({ key = "options", order = 5, title = L.TAB_OPTIONS, create = create, refresh = refresh })
