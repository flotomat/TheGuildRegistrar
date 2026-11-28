-- The Guild Registrar - companion of Blizzard's guild window (prepared notes)
--
-- While the member list ("Roster") of Blizzard's guild window is open, a small movable panel shows
-- the prepared notes of the selected member; a click opens the edit dialog. When the officer opens
-- a guild note in Blizzard's window, a copy box with the prepared text (selected) appears below
-- Blizzard's dialog: Ctrl+C -> click into Blizzard's field -> Ctrl+A -> Ctrl+V -> Enter.
--
-- Blizzard's frames are only READ, never changed: writing into Blizzard's note field from an addon
-- makes saving fail ("only available to the Blizzard UI"). Safe and tested in game:
--   hooksecurefunc(CommunitiesFrame.GuildMemberDetailFrame, "DisplayMember", ...) and reading
--   StaticPopupN.which / .data (the note dialog is called "SET_GUILD_COMMUNITIY_NOTE", sic).

local _, ns = ...

local Companion = {}
ns.Companion = Companion

local L = ns.L
local W = ns.W

local NOTE_POPUP = "SET_GUILD_COMMUNITIY_NOTE"
local panel, copyBox, driver
local selected -- { guid, name } of the member selected in Blizzard's window
local hiddenByUser = false
local hooked = false

local function settings()
    local g = ns.DB.Guild()
    return g and g.settings
end

-- Character (and its row of the last comparison) by GUID or name.
local function findChar(guid, name)
    local short = name and name:match("^([^%-]+)") or nil
    local function matches(c)
        if guid and c.guid == guid then
            return true
        end
        if name and (c.fullName == name or (not name:find("-", 1, true) and c.name == short)) then
            return true
        end
        return false
    end
    local res = ns.state.results
    for _, row in ipairs(res and res.rows or {}) do
        for _, c in ipairs(ns.Advice.rowChars(row)) do
            if matches(c) then
                return c, row
            end
        end
    end
    for _, c in ipairs(ns.Roster.Read() or {}) do
        if matches(c) then
            return c, nil
        end
    end
    return nil
end

-- Is the member list of Blizzard's guild window visible?
local function rosterVisible()
    local cf = _G.CommunitiesFrame
    if not cf or not cf:IsVisible() then
        return false
    end
    local modes = _G.COMMUNITIES_FRAME_DISPLAY_MODES
    if cf.GetDisplayMode and modes and modes.ROSTER then
        local ok, mode = pcall(cf.GetDisplayMode, cf)
        if ok then
            return mode == modes.ROSTER
        end
    end
    return cf.MemberList ~= nil and cf.MemberList:IsVisible()
end

-- Panel ---------------------------------------------------------------------------------------

local function noteLine(parent, kind)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(18)
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetSize(14, 14)
    icon:SetPoint("LEFT", 0, 0)
    icon:SetTexture(W.NOTE_TEXTURES[kind])
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.text:SetPoint("LEFT", icon, "RIGHT", 4, 0)
    b.text:SetPoint("RIGHT", 0, 0)
    b.text:SetJustifyH("LEFT")
    b.text:SetWordWrap(false)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.08)
    b.kind = kind
    b:SetScript("OnClick", function(self)
        if self.char then
            ns.Dialogs.ShowPrepareNote(self.row, self.char, kind)
        end
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText((kind == "officer") and L.NOTE_OFFICER or L.NOTE_PUBLIC, 1, 1, 1)
        GameTooltip:AddLine(L.COMPANION_CLICK, 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    return b
end

local function createPanel()
    panel = CreateFrame("Frame", "TheGuildRegistrarCompanion", UIParent, "BackdropTemplate")
    panel:SetSize(300, 190)
    panel:SetFrameStrata("HIGH")
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    panel:SetMovable(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        if ns.db then
            ns.db.ui.companionPos = { point, relPoint, x, y }
        end
    end)
    W.Backdrop(panel, 0.94)
    panel.title = W.Label(panel, L.COMPANION_TITLE, "GameFontNormal")
    panel.title:SetPoint("TOPLEFT", 10, -9)
    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 0, 0)
    close:SetScript("OnClick", function()
        hiddenByUser = true
        panel:Hide()
    end)
    panel.char = W.Label(panel, "", "GameFontHighlight")
    panel.char:SetPoint("TOPLEFT", 10, -30)
    panel.char:SetPoint("RIGHT", -10, 0)
    panel.lines = {}
    for i, kind in ipairs({ "public", "officer" }) do
        local b = noteLine(panel, kind)
        b:SetPoint("TOPLEFT", 10, -50 - (i - 1) * 20)
        b:SetPoint("RIGHT", -10, 0)
        panel.lines[kind] = b
    end
    panel.hint = W.Label(panel, L.COMPANION_HINT, "GameFontDisableSmall")
    panel.hint:SetPoint("TOPLEFT", 10, -96)
    panel.hint:SetPoint("RIGHT", -10, 0)
    panel.hint:SetJustifyV("TOP")
    panel.more = W.Label(panel, "", "GameFontHighlightSmall")
    panel.more:SetPoint("TOPLEFT", panel.hint, "BOTTOMLEFT", 0, -8)
    panel.more:SetPoint("RIGHT", -10, 0)
    panel.more:SetJustifyV("TOP")
    panel:Hide()
end

local function placePanel()
    panel:ClearAllPoints()
    local pos = ns.db and ns.db.ui.companionPos
    if pos then
        panel:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    elseif _G.CommunitiesFrame then
        panel:SetPoint("TOPLEFT", _G.CommunitiesFrame, "TOPRIGHT", 4, 0)
    else
        panel:SetPoint("CENTER")
    end
end

function Companion.Update()
    if not panel or not panel:IsShown() then
        return
    end
    local c, row
    if selected then
        c, row = findChar(selected.guid, selected.name)
    end
    if c then
        panel.char:SetText(W.Colorize(c.name, W.ClassColor(c.classFile)))
    else
        panel.char:SetText("|cff999999" .. (selected and L.COMPANION_NOT_FOUND or L.COMPANION_SELECT) .. "|r")
    end
    for kind, b in pairs(panel.lines) do
        b.char, b.row = c, row
        local pending = c and ns.PendingNotes.Get(c.fullName, kind)
        if pending then
            b.text:SetText("|cffffd100" .. pending .. "|r")
        elseif c then
            b.text:SetText("|cff777777" .. L.COMPANION_NONE .. "|r")
        else
            b.text:SetText("")
        end
        b:SetShown(c ~= nil)
    end
    -- the other characters with prepared notes
    local names, seen = {}, {}
    for _, e in ipairs(ns.PendingNotes.List()) do
        if not seen[e.fullName] and (not c or e.fullName ~= c.fullName) then
            seen[e.fullName] = true
            names[#names + 1] = e.fullName:match("^([^%-]+)") or e.fullName
        end
    end
    if #names > 0 then
        local shown = {}
        for i = 1, math.min(#names, 8) do
            shown[i] = names[i]
        end
        local text = string.format(L.COMPANION_MORE, #names) .. "\n|cffffffff" .. table.concat(shown, ", ")
        if #names > 8 then
            text = text .. ", ..."
        end
        panel.more:SetText(text .. "|r")
    else
        panel.more:SetText("")
    end
    panel:SetHeight(110 + (panel.hint:GetStringHeight() or 24) + (panel.more:GetStringHeight() or 0))
end

-- Copy box below Blizzard's note dialog --------------------------------------------------------

local function createCopyBox()
    copyBox = CreateFrame("Frame", "TheGuildRegistrarCopyBox", UIParent, "BackdropTemplate")
    copyBox:SetSize(380, 74)
    copyBox:SetFrameStrata("DIALOG")
    W.Backdrop(copyBox, 0.95)
    copyBox.title = W.Label(copyBox, "", "GameFontNormalSmall")
    copyBox.title:SetPoint("TOPLEFT", 10, -8)
    copyBox.title:SetPoint("RIGHT", -10, 0)
    local eb = W.EditBox(copyBox, 356, 20)
    eb:SetPoint("TOPLEFT", 14, -24)
    eb:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            self:SetText(copyBox.text or "")
            self:HighlightText()
        end
    end)
    eb:SetScript("OnEditFocusGained", function(self)
        self:HighlightText()
    end)
    eb:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    copyBox.edit = eb
    copyBox.hint = W.Label(copyBox, L.COPYBOX_HINT, "GameFontDisableSmall")
    copyBox.hint:SetPoint("TOPLEFT", 10, -50)
    copyBox.hint:SetPoint("RIGHT", -10, 0)
    copyBox:Hide()
end

-- The note dialog of Blizzard that is open (or nil).
local function notePopup()
    for i = 1, (_G.STATICPOPUP_NUMDIALOGS or 4) do
        local p = _G["StaticPopup" .. i]
        if p and p:IsShown() and p.which == NOTE_POPUP then
            return p
        end
    end
    return nil
end

-- Character and note kind of Blizzard's note dialog (data = { currentNote, isPublic, guid }).
local function popupTarget(p)
    local data = p.data
    local isPublic, guid
    if type(data) == "table" then
        isPublic = data.isPublic
        if isPublic == nil then
            isPublic = data[2]
        end
        guid = data.guid or data[3]
    end
    local c, row
    if guid then
        c, row = findChar(guid, nil)
    end
    if not c and selected then
        c, row = findChar(selected.guid, selected.name)
    end
    local kind
    if isPublic ~= nil then
        kind = isPublic and "public" or "officer"
    elseif c then
        -- unknown note type: only clear if exactly one note is prepared
        local pub, off = ns.PendingNotes.Get(c.fullName, "public"), ns.PendingNotes.Get(c.fullName, "officer")
        kind = (pub and not off) and "public" or ((off and not pub) and "officer" or nil)
    end
    return c, row, kind
end

local currentPopup
local function checkPopup()
    local s = settings()
    local p = (s and s.notesCopyBox ~= false) and notePopup() or nil
    if not p then
        if currentPopup then
            currentPopup = nil
            if copyBox then
                copyBox:Hide()
            end
            -- the roster update after saving ticks the note off
            if C_Timer and C_Timer.After then
                C_Timer.After(1, ns.Roster.Request)
            end
        end
        return
    end
    if p == currentPopup then
        return
    end
    currentPopup = p
    local c, _, kind = popupTarget(p)
    local text = c and kind and ns.PendingNotes.Get(c.fullName, kind)
    if not text then
        return
    end
    if not copyBox then
        createCopyBox()
    end
    copyBox.text = text
    copyBox.title:SetText(string.format(L.COPYBOX_TITLE, (kind == "officer") and L.NOTE_OFFICER or L.NOTE_PUBLIC, c.name))
    copyBox:ClearAllPoints()
    copyBox:SetPoint("TOP", p, "BOTTOM", 0, -6)
    copyBox:Show()
    copyBox.edit:SetText(text)
    copyBox.edit:SetFocus()
    copyBox.edit:HighlightText()
end

-- Driver: polls Blizzard's frames (read only) a few times per second ----------------------------

local elapsedSum = 0
local function onUpdate(_, elapsed)
    elapsedSum = elapsedSum + (elapsed or 0)
    if elapsedSum < 0.2 then
        return
    end
    elapsedSum = 0
    local s = settings()
    local want = s and s.notesCompanion ~= false and not hiddenByUser and rosterVisible()
        and ns.PendingNotes.Count() > 0
    if want then
        if not panel then
            createPanel()
        end
        if not panel:IsShown() then
            placePanel()
            panel:Show()
            Companion.Update()
        end
    elseif panel and panel:IsShown() then
        panel:Hide()
    end
    if not (_G.CommunitiesFrame and _G.CommunitiesFrame:IsVisible()) then
        hiddenByUser = false -- show again next time the guild window opens
    end
    checkPopup()
end

-- Hook Blizzard's member details (called when Blizzard_Communities is loaded).
function Companion.Hook()
    if hooked then
        return
    end
    local cf = _G.CommunitiesFrame
    local detail = cf and cf.GuildMemberDetailFrame
    if not detail or not detail.DisplayMember then
        return
    end
    hooked = true
    hooksecurefunc(detail, "DisplayMember", function(_, _, memberInfo)
        if type(memberInfo) == "table" then
            selected = { guid = memberInfo.guid, name = memberInfo.name }
            Companion.Update()
        end
    end)
end

function Companion.Init()
    if not driver then
        driver = CreateFrame("Frame")
        driver:SetScript("OnUpdate", onUpdate)
    end
    Companion.Hook()
end

-- (tests)
Companion._findChar = findChar
Companion._checkPopup = checkPopup
function Companion._select(guid, name)
    selected = { guid = guid, name = name }
end
function Companion._panel()
    return panel, copyBox
end
Companion._onUpdate = onUpdate
