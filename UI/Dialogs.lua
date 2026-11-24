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
    confirmDialog.onAccept = onAccept
    confirmDialog:Show()
end

-- Write note dialog -----------------------------------------------------------------
-- Lets the officer choose public/officer note, append/replace and edit the text before writing.

local noteDialog
local function noteValues(row, char)
    local m = row.member
    local isTwink = char.isTwink and char.player and char.player.main ~= char
    local mainName = (row.player and row.player.main and row.player.main.name) or char.name
    local nick = m and ns.Text.nickname(m.analysis) or ""
    return {
        discord = m and m.display or "",
        nick = nick,
        main = mainName,
        char = char.name,
    }, isTwink
end

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
    local values, isTwink = noteValues(row, char)
    local template = isTwink and g.settings.twinkNoteTemplate or g.settings.noteTemplate
    d.title:SetText(L.NOTE_DIALOG_TITLE)
    d.target:SetText(string.format(L.NOTE_TARGET, W.Colorize(char.name, W.ClassColor(char.classFile)),
        row.member and row.member.display or "-"))
    d.edit:SetText(ns.Util.format(template, values))

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
