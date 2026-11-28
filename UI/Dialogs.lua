-- The Guild Registrar - dialogs: copy text, text input, confirmation, write note

local _, ns = ...

local Dialogs = {}
ns.Dialogs = Dialogs

local L = ns.L
local W = ns.W

local function baseDialog(width, height)
    local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    f:SetSize(width, height)
    f:SetPoint("CENTER", 0, 80)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    W.Backdrop(f, 0.97)
    f.title = W.Label(f, "", "GameFontNormalLarge")
    f.title:SetPoint("TOPLEFT", 14, -12)
    f.title:SetPoint("RIGHT", -34, 0)
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)
    f:Hide()
    return f
end

-- ESC closes a dialog: frames in UISpecialFrames are referenced by global name.
local dialogCount = 0
local function named(f)
    dialogCount = dialogCount + 1
    local name = "TheGuildRegistrarDialog" .. dialogCount
    _G[name] = f
    tinsert(UISpecialFrames, name)
    return f
end

-- Copy dialog --------------------------------------------------------------------

local copyDialog
function Dialogs.ShowCopy(title, text, hint)
    if not copyDialog then
        copyDialog = named(baseDialog(620, 420))
        copyDialog.hint = W.Label(copyDialog, "", "GameFontHighlightSmall")
        copyDialog.hint:SetPoint("TOPLEFT", 14, -36)
        copyDialog.hint:SetPoint("RIGHT", -14, 0)
        local box, eb = W.MultiLine(copyDialog, 592, 330)
        box:SetPoint("TOPLEFT", 14, -54)
        copyDialog.editBox = eb
        eb:SetScript("OnTextChanged", function(self, userInput)
            if userInput then
                self:SetText(copyDialog.text or "")
                self:HighlightText()
            end
        end)
    end
    copyDialog.title:SetText(title or "")
    copyDialog.hint:SetText(hint or L.COPY_HINT)
    copyDialog.text = text or ""
    copyDialog.editBox:SetText(copyDialog.text)
    copyDialog:Show()
    copyDialog.editBox:SetFocus()
    copyDialog.editBox:HighlightText()
end

-- Input dialog ---------------------------------------------------------------------

local inputDialog
function Dialogs.ShowInput(title, label, default, onAccept)
    if not inputDialog then
        inputDialog = named(baseDialog(420, 140))
        inputDialog.label = W.Label(inputDialog, "", "GameFontHighlight")
        inputDialog.label:SetPoint("TOPLEFT", 14, -40)
        inputDialog.label:SetPoint("RIGHT", -14, 0)
        inputDialog.edit = W.EditBox(inputDialog, 380, 22)
        inputDialog.edit:SetPoint("TOPLEFT", 20, -62)
        inputDialog.ok = W.Button(inputDialog, OKAY or "OK", 110, 22)
        inputDialog.ok:SetPoint("BOTTOMRIGHT", -130, 12)
        inputDialog.cancel = W.Button(inputDialog, CANCEL or "Cancel", 110, 22, function()
            inputDialog:Hide()
        end)
        inputDialog.cancel:SetPoint("BOTTOMRIGHT", -14, 12)
        local function accept()
            local v = ns.Util.trim(inputDialog.edit:GetText())
            inputDialog:Hide()
            if inputDialog.onAccept and v ~= "" then
                inputDialog.onAccept(v)
            end
        end
        inputDialog.ok:SetScript("OnClick", accept)
        inputDialog.edit:SetScript("OnEnterPressed", accept)
    end
    inputDialog.title:SetText(title or "")
    inputDialog.label:SetText(label or "")
    inputDialog.edit:SetText(default or "")
    inputDialog.onAccept = onAccept
    inputDialog:Show()
    inputDialog.edit:SetFocus()
    inputDialog.edit:HighlightText()
end

-- Confirmation dialog ------------------------------------------------------------

local confirmDialog
function Dialogs.ShowConfirm(title, text, onAccept)
    if not confirmDialog then
        confirmDialog = named(baseDialog(420, 150))
        confirmDialog.text = W.Label(confirmDialog, "", "GameFontHighlight")
        confirmDialog.text:SetPoint("TOPLEFT", 14, -40)
        confirmDialog.text:SetPoint("RIGHT", -14, 0)
        confirmDialog.text:SetJustifyV("TOP")
        confirmDialog.ok = W.Button(confirmDialog, YES or "Yes", 110, 22, function()
            confirmDialog:Hide()
            if confirmDialog.onAccept then
                confirmDialog.onAccept()
            end
        end)
        confirmDialog.ok:SetPoint("BOTTOMRIGHT", -130, 12)
        local no = W.Button(confirmDialog, NO or "No", 110, 22, function()
            confirmDialog:Hide()
        end)
        no:SetPoint("BOTTOMRIGHT", -14, 12)
    end
    confirmDialog.title:SetText(title or "")
    confirmDialog.text:SetText(text or "")
    -- grow with the text (e.g. a list of guilds): title + text + buttons
    confirmDialog:SetHeight(math.max(150, 40 + confirmDialog.text:GetStringHeight() + 50))
    confirmDialog.onAccept = onAccept
    confirmDialog:Show()
end

-- Delete warning (delete protection) ------------------------------------------------
-- Shown before an action removes manual work of the officer. Lists what would be lost (counts from
-- ns.Protect) and has only two buttons: cancel and the action (e.g. "Delete"). ESC cancels.
-- Without anything manual to lose, the plain confirmation is shown instead.

local warnDialog
function Dialogs.ShowDeleteWarning(title, text, counts, onAccept, acceptLabel)
    local lines = ns.Protect.Lines(counts)
    if #lines == 0 then
        Dialogs.ShowConfirm(title, text, onAccept)
        return
    end
    if not warnDialog then
        local d = named(baseDialog(460, 200))
        warnDialog = d
        local icon = d:CreateTexture(nil, "ARTWORK")
        icon:SetTexture("Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew")
        icon:SetSize(36, 36)
        icon:SetPoint("TOPLEFT", 14, -38)
        d.text = W.Label(d, "", "GameFontHighlight")
        d.text:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, 0)
        d.text:SetPoint("RIGHT", -14, 0)
        d.text:SetJustifyV("TOP")
        d.lost = W.Label(d, "", "GameFontNormal")
        d.lost:SetPoint("TOPLEFT", d.text, "BOTTOMLEFT", 0, -12)
        d.lost:SetPoint("RIGHT", -14, 0)
        d.lost:SetJustifyV("TOP")
        d.ok = W.Button(d, "", 130, 22, function()
            d:Hide()
            if d.onAccept then
                d.onAccept()
            end
        end)
        d.ok:SetPoint("BOTTOMRIGHT", -144, 12)
        local cancel = W.Button(d, CANCEL or "Cancel", 120, 22, function()
            d:Hide()
        end)
        cancel:SetPoint("BOTTOMRIGHT", -14, 12)
        d.icon = icon
    end
    local d = warnDialog
    d.title:SetText(title or "")
    d.text:SetText(text or "")
    local list = {}
    for i, line in ipairs(lines) do
        list[i] = "|cffffffff  - " .. line .. "|r"
    end
    d.lost:SetText("|cffff8040" .. L.PROTECT_INTRO .. "|r\n" .. table.concat(list, "\n"))
    d.ok:SetText("|cffff6060" .. (acceptLabel or L.PROTECT_DELETE) .. "|r")
    d.onAccept = onAccept
    d:SetHeight(math.max(170, 40 + d.text:GetStringHeight() + 12 + d.lost:GetStringHeight() + 50))
    d:Show()
    d:Raise()
end

-- Prepare note dialog ------------------------------------------------------------------
-- Edit the prepared text of one note (public or officer) with a byte counter (guild notes hold at
-- most 31 bytes). `row` may be nil (opened from the guild window companion): then no template
-- suggestion is offered.

local prepDialog

local function prepUpdate()
    local d = prepDialog
    local text = ns.Util.trim(d.edit:GetText())
    local bytes = #text
    local max = ns.Notes.MAX_BYTES
    if bytes > max then
        d.counter:SetText(string.format("|cffff4444%d/%d %s - %s|r", bytes, max, L.PENDING_BYTES, L.NOTE_TOO_LONG))
    else
        d.counter:SetText(string.format("|cff999999%d/%d %s|r", bytes, max, L.PENDING_BYTES))
    end
    d.ok:SetEnabled(bytes <= max)
end

function Dialogs.ShowPrepareNote(row, c, kind)
    local g = ns.DB.Guild()
    if not g or not c then
        return
    end
    if not prepDialog then
        local d = named(baseDialog(540, 214))
        prepDialog = d
        d.target = W.Label(d, "", "GameFontHighlight")
        d.target:SetPoint("TOPLEFT", 14, -38)
        d.target:SetPoint("RIGHT", -14, 0)
        d.current = W.Label(d, "", "GameFontHighlightSmall")
        d.current:SetPoint("TOPLEFT", 14, -60)
        d.current:SetPoint("RIGHT", -14, 0)
        d.edit = W.EditBox(d, 500, 22)
        d.edit:SetPoint("TOPLEFT", 20, -84)
        d.edit:SetScript("OnTextChanged", prepUpdate)
        d.counter = W.Label(d, "", "GameFontHighlightSmall")
        d.counter:SetPoint("TOPLEFT", d.edit, "BOTTOMLEFT", -2, -6)
        d.hint = W.Label(d, L.PENDING_DIALOG_HINT, "GameFontDisableSmall")
        d.hint:SetPoint("TOPLEFT", d.counter, "BOTTOMLEFT", 0, -8)
        d.hint:SetPoint("RIGHT", -14, 0)
        d.hint:SetJustifyV("TOP")

        local function accept()
            if not d.ok:IsEnabled() then
                return
            end
            ns.PendingNotes.Set(d.char.fullName, d.kind, d.edit:GetText(), d.currentText)
            d:Hide()
        end
        d.ok = W.Button(d, L.PENDING_OK, 120, 22, accept)
        d.ok:SetPoint("BOTTOMRIGHT", -140, 12)
        d.edit:SetScript("OnEnterPressed", accept)
        local cancel = W.Button(d, CANCEL or "Cancel", 120, 22, function()
            d:Hide()
        end)
        cancel:SetPoint("BOTTOMRIGHT", -14, 12)
        d.suggest = W.Button(d, L.PENDING_SUGGEST, 120, 22, function()
            if d.suggestion then
                d.edit:SetText(d.suggestion)
                d.edit:SetFocus()
            end
        end)
        d.suggest:SetPoint("BOTTOMLEFT", 14, 12)
        d.remove = W.Button(d, L.PENDING_REMOVE, 150, 22, function()
            local char, kind_ = d.char, d.kind
            d:Hide()
            ns.Dialogs.ShowDeleteWarning(L.PENDING_REMOVE, string.format(L.PENDING_REMOVE_CONFIRM, char.name),
                { pendingNotes = 1 }, function()
                    ns.PendingNotes.Set(char.fullName, kind_, nil)
                end)
        end)
        d.remove:SetPoint("LEFT", d.suggest, "RIGHT", 8, 0)
    end
    local d = prepDialog
    d.char, d.kind = c, kind
    local label = (kind == "officer") and L.NOTE_OFFICER or L.NOTE_PUBLIC
    d.title:SetText(L.PENDING_DIALOG_TITLE .. " - " .. label)
    d.target:SetText(W.Colorize(c.name, W.ClassColor(c.classFile))
        .. ((row and row.member) and ("  |cff888888(" .. row.member.display .. ")|r") or ""))
    d.currentText = (kind == "officer") and c.officerNote or c.note
    d.current:SetText(L.PENDING_CURRENT .. " |cffffffff" .. ((d.currentText and d.currentText ~= "") and d.currentText
        or ("|cff777777" .. L.PENDING_EMPTY .. "|r")) .. "|r")
    d.suggestion = row and ns.Advice.suggestedNote(row, c, g.settings, kind) or nil
    d.suggest:SetEnabled(d.suggestion ~= nil)
    local pending = ns.PendingNotes.Get(c.fullName, kind)
    d.remove:SetEnabled(pending ~= nil)
    d.edit:SetText(pending or d.suggestion or d.currentText or "")
    prepUpdate()
    d:Show()
    d:Raise()
    d.edit:SetFocus()
    d.edit:HighlightText()
end

-- Mass preparation dialog ---------------------------------------------------------------

local massDialog
local MASS_STATUS = { "confirmed", "sure", "likely", "unlikely" }

function Dialogs.ShowMassPrepare(rows)
    local g = ns.DB.Guild()
    if not g then
        return
    end
    if not massDialog then
        local d = named(baseDialog(520, 230))
        massDialog = d
        d.text = W.Label(d, "", "GameFontHighlight")
        d.text:SetPoint("TOPLEFT", 14, -38)
        d.text:SetPoint("RIGHT", -14, 0)
        d.text:SetJustifyV("TOP")
        local lbl = W.Label(d, L.PENDING_MASS_MIN, "GameFontNormal")
        lbl:SetPoint("TOPLEFT", 14, -118)
        local options = {}
        for _, st in ipairs(MASS_STATUS) do
            options[#options + 1] = { value = st, text = L["PENDING_MASS_" .. st:upper()] }
        end
        d.cycle = W.Cycle(d, 230, options, function()
            local s = ns.DB.Guild()
            return s and s.settings.notesMinStatus or "sure"
        end, function(v)
            local s = ns.DB.Guild()
            if s then
                s.settings.notesMinStatus = v
            end
            d.Preview()
        end)
        d.cycle:SetPoint("LEFT", lbl, "RIGHT", 10, 0)
        d.preview = W.Label(d, "", "GameFontHighlight")
        d.preview:SetPoint("TOPLEFT", 14, -150)
        d.preview:SetPoint("RIGHT", -14, 0)
        d.ok = W.Button(d, L.PENDING_OK, 120, 22, function()
            local s = ns.DB.Guild()
            local n = ns.PendingNotes.Mass(d.rows, s.settings, s.settings.notesMinStatus)
            d:Hide()
            ns.Engine.Print(string.format(L.PENDING_MASS_DONE, n))
        end)
        d.ok:SetPoint("BOTTOMRIGHT", -140, 12)
        local cancel = W.Button(d, CANCEL or "Cancel", 120, 22, function()
            d:Hide()
        end)
        cancel:SetPoint("BOTTOMRIGHT", -14, 12)
        function d.Preview()
            local s = ns.DB.Guild()
            local n = ns.PendingNotes.Mass(d.rows, s.settings, s.settings.notesMinStatus, true)
            d.preview:SetText(string.format(L.PENDING_MASS_PREVIEW, n))
            d.ok:SetEnabled(n > 0)
        end
    end
    local d = massDialog
    d.rows = rows
    local kinds = {}
    for _, k in ipairs(ns.PendingNotes.AutoKinds(g.settings)) do
        kinds[#kinds + 1] = (k == "officer") and L.NOTE_OFFICER or L.NOTE_PUBLIC
    end
    d.title:SetText(L.PENDING_MASS_TITLE)
    d.text:SetText(string.format(L.PENDING_MASS_TEXT, #kinds > 0 and table.concat(kinds, ", ") or L.NONE))
    d.cycle.Refresh()
    d.Preview()
    d:Show()
    d:Raise()
end

-- Write note dialog -----------------------------------------------------------------
-- Lets the officer choose public/officer note, append/replace and edit the text before writing.

local noteDialog
local function updateNotePreview()
    local d = noteDialog
    local addition = d.edit:GetText()
    local lines = {}
    local tooLong = false
    for _, kind in ipairs({ "public", "officer" }) do
        local cb = d.checks[kind]
        if cb:GetChecked() and cb:IsEnabled() then
            local current = (kind == "officer") and d.char.officerNote or d.char.note
            local text = ns.Notes.Compose(current, addition, d.mode)
            local fits = ns.Notes.Fits(text)
            tooLong = tooLong or not fits
            local label = (kind == "officer") and L.NOTE_OFFICER or L.NOTE_PUBLIC
            lines[#lines + 1] = string.format("%s: |cffffffff%s|r  %s", label, text,
                fits and string.format("|cff888888(%d/%d)|r", #text, ns.Notes.MAX_BYTES)
                or string.format("|cffff4444(%d/%d - %s)|r", #text, ns.Notes.MAX_BYTES, L.NOTE_TOO_LONG))
        end
    end
    if #lines == 0 then
        lines[1] = "|cffff8888" .. L.NOTE_CHOOSE_KIND .. "|r"
    end
    d.preview:SetText(table.concat(lines, "\n"))
    d.ok:SetEnabled(#lines > 0 and d.edit:GetText() ~= "" and (d.checks.public:GetChecked() or d.checks.officer:GetChecked()))
    d.tooLong = tooLong
end

function Dialogs.ShowWriteNote(row, char)
    local g = ns.DB.Guild()
    if not g then
        return
    end
    if not noteDialog then
        local d = named(baseDialog(520, 300))
        noteDialog = d
        d.target = W.Label(d, "", "GameFontHighlight")
        d.target:SetPoint("TOPLEFT", 14, -38)
        d.target:SetPoint("RIGHT", -14, 0)

        local lbl = W.Label(d, L.NOTE_TEXT, "GameFontNormal")
        lbl:SetPoint("TOPLEFT", 14, -66)
        d.edit = W.EditBox(d, 300, 22)
        d.edit:SetPoint("LEFT", lbl, "RIGHT", 12, 0)
        d.edit:SetScript("OnTextChanged", updateNotePreview)

        d.checks = {}
        d.checks.public = W.Check(d, L.NOTE_PUBLIC, updateNotePreview)
        d.checks.public:SetPoint("TOPLEFT", 14, -96)
        d.checks.officer = W.Check(d, L.NOTE_OFFICER, updateNotePreview)
        d.checks.officer:SetPoint("TOPLEFT", 200, -96)

        d.modeButton = W.Cycle(d, 160, {
            { value = "append", text = L.NOTE_MODE_APPEND },
            { value = "replace", text = L.NOTE_MODE_REPLACE },
        }, function()
            return d.mode
        end, function(v)
            d.mode = v
            updateNotePreview()
        end)
        d.modeButton:SetPoint("TOPLEFT", 14, -128)

        local pl = W.Label(d, L.NOTE_PREVIEW, "GameFontNormal")
        pl:SetPoint("TOPLEFT", 14, -164)
        d.preview = W.Label(d, "", "GameFontHighlightSmall")
        d.preview:SetPoint("TOPLEFT", 14, -182)
        d.preview:SetPoint("RIGHT", -14, 0)
        d.preview:SetJustifyV("TOP")

        d.ok = W.Button(d, L.NOTE_WRITE, 130, 22)
        d.ok:SetPoint("BOTTOMRIGHT", -150, 12)
        local cancel = W.Button(d, CANCEL or "Cancel", 120, 22, function()
            d:Hide()
        end)
        cancel:SetPoint("BOTTOMRIGHT", -14, 12)

        d.ok:SetScript("OnClick", function()
            local addition = ns.Util.trim(d.edit:GetText())
            local written, failed = 0, nil
            for _, kind in ipairs({ "public", "officer" }) do
                local cb = d.checks[kind]
                if cb:GetChecked() and cb:IsEnabled() then
                    local current = (kind == "officer") and d.char.officerNote or d.char.note
                    local text = ns.Notes.Compose(current, addition, d.mode)
                    local ok, err = ns.Notes.Write(d.char, kind, text)
                    if ok then
                        written = written + 1
                    else
                        failed = err
                    end
                end
            end
            d:Hide()
            if failed then
                ns.Engine.Print(L[failed])
            end
            if written > 0 then
                ns.Engine.Print(string.format(L.NOTE_WRITTEN, d.char.name))
                ns.Engine.Refresh()
            end
        end)
    end

    local d = noteDialog
    d.row, d.char = row, char
    d.mode = g.settings.noteWriteMode or "append"
    d.modeButton.Refresh()
    local values = ns.Advice.templateValues(row, char, g.settings)
    local template = ns.Advice.template(row, char, g.settings, ns.Notes.CanEdit("officer") and "officer" or "public")
        or ns.Advice.template(row, char, g.settings, "public") or ""
    d.title:SetText(L.NOTE_DIALOG_TITLE)
    d.target:SetText(string.format(L.NOTE_TARGET, W.Colorize(char.name, W.ClassColor(char.classFile)),
        row.member and row.member.display or "-"))
    d.edit:SetText(template ~= "" and ns.Advice.render(template, values) or "")

    local canPublic, canOfficer = ns.Notes.CanEdit("public"), ns.Notes.CanEdit("officer")
    d.checks.public:SetEnabled(canPublic)
    d.checks.officer:SetEnabled(canOfficer)
    d.checks.public:SetChecked(false)
    d.checks.officer:SetChecked(canOfficer)
    if not canOfficer then
        d.checks.public:SetChecked(canPublic)
    end
    d.checks.public.label:SetTextColor(canPublic and 1 or 0.5, canPublic and 1 or 0.5, canPublic and 1 or 0.5)
    d.checks.officer.label:SetTextColor(canOfficer and 1 or 0.5, canOfficer and 1 or 0.5, canOfficer and 1 or 0.5)
    updateNotePreview()
    d:Show()
end
