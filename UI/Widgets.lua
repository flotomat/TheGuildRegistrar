-- The Guild Registrar - small UI building blocks (only long-standing templates are used)

local _, ns = ...

local W = {}
ns.W = W

W.STATUS_COLORS = {
    confirmed = { 0.30, 0.85, 1.00 },
    sure = { 0.25, 0.90, 0.25 },
    likely = { 1.00, 0.85, 0.20 },
    unlikely = { 1.00, 0.55, 0.15 },
    unassigned = { 1.00, 0.30, 0.30 },
    guest = { 0.65, 0.65, 0.65 },
    ignored = { 0.45, 0.45, 0.45 },
}

-- Inline icons (texture escapes; forward slashes work in texture paths)
W.ICON_ONLINE = "|TInterface/FriendsFrame/StatusIcon-Online:10|t"
W.ICON_OK = "|TInterface/RaidFrame/ReadyCheck-Ready:12|t"
W.ICON_BAD = "|TInterface/RaidFrame/ReadyCheck-NotReady:12|t"
W.ICON_UNKNOWN = "|TInterface/RaidFrame/ReadyCheck-Waiting:12|t"

function W.Hex(rgb)
    return string.format("ff%02x%02x%02x", rgb[1] * 255, rgb[2] * 255, rgb[3] * 255)
end

function W.Colorize(text, rgb)
    return "|c" .. W.Hex(rgb) .. tostring(text) .. "|r"
end

function W.ClassColor(classFile)
    local c = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if c then
        return { c.r, c.g, c.b }
    end
    return { 1, 1, 1 }
end

function W.Label(parent, text, font)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    fs:SetText(text or "")
    fs:SetJustifyH("LEFT")
    return fs
end

-- Texts that depend on the chosen term for alternative characters ({Alt}/{alt} in the locale)
-- are registered here and updated by ns.SetAltTerm.
local localized = {}

-- Register a font string (or button) to show the locale string `key`; returns the object.
function W.Localized(obj, key)
    localized[#localized + 1] = { obj = obj, key = key }
    obj:SetText(ns.L[key])
    return obj
end

function W.RefreshLocalized()
    for _, e in ipairs(localized) do
        e.obj:SetText(ns.L[e.key])
    end
end

-- Returns a function that reads the locale string `key` when called (for tooltips).
function W.LocText(key)
    return function()
        return ns.L[key]
    end
end

function W.Button(parent, text, width, height, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width or 120, height or 22)
    b:SetText(text or "")
    if onClick then
        b:SetScript("OnClick", onClick)
    end
    return b
end

function W.Check(parent, text, onClick, tooltip)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    local label = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    label:SetText(text or "")
    cb.label = label
    -- the template may bring its own text region; keep it empty
    if cb.Text then
        cb.Text:SetText("")
    end
    cb:SetHitRectInsets(0, -math.max(40, label:GetStringWidth() + 6), 0, 0)
    if onClick then
        cb:SetScript("OnClick", function(self)
            onClick(self, self:GetChecked() and true or false)
        end)
    end
    if tooltip then
        W.Tooltip(cb, function()
            return label:GetText()
        end, tooltip)
    end
    return cb
end

-- title and text may be strings or functions returning strings (evaluated on hover).
function W.Tooltip(frame, title, text)
    frame:HookScript("OnEnter", function(self)
        local t = type(title) == "function" and title() or title
        local body = type(text) == "function" and text() or text
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(t or "", 1, 1, 1)
        if body then
            GameTooltip:AddLine(body, nil, nil, nil, true)
        end
        GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

function W.EditBox(parent, width, height)
    local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    eb:SetSize(width or 150, height or 20)
    eb:SetAutoFocus(false)
    eb:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    eb:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)
    return eb
end

-- Search field: Blizzard's SearchBoxTemplate (magnifier, grey placeholder, clear button) if the
-- client has it, otherwise a plain field with an "x" button. Use HookScript for OnTextChanged.
function W.SearchBox(parent, width, height, placeholder)
    local hasTemplate = C_XMLUtil and C_XMLUtil.GetTemplateInfo and C_XMLUtil.GetTemplateInfo("SearchBoxTemplate")
    if hasTemplate then
        local eb = CreateFrame("EditBox", nil, parent, "SearchBoxTemplate")
        eb:SetSize(width or 150, height or 20)
        eb:SetAutoFocus(false)
        if placeholder and eb.Instructions then
            eb.Instructions:SetText(placeholder)
        end
        return eb
    end
    local eb = W.EditBox(parent, (width or 150) - 24, height)
    local clear = W.Button(parent, "x", 22, height or 20, function()
        eb:SetText("")
        eb:ClearFocus()
    end)
    clear:SetPoint("LEFT", eb, "RIGHT", 2, 0)
    eb.clearButton = clear
    return eb
end

-- Read-only field to copy a text (links etc.). Selects everything on focus.
function W.CopyBox(parent, width, text)
    local eb = W.EditBox(parent, width, 20)
    eb:SetText(text or "")
    eb:SetCursorPosition(0)
    eb:SetScript("OnEditFocusGained", function(self)
        self:HighlightText()
    end)
    eb:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            self:SetText(text or "")
            self:HighlightText()
        end
    end)
    eb.SetCopyText = function(self, t)
        text = t
        self:SetText(t or "")
        self:SetCursorPosition(0)
    end
    return eb
end

local function backdrop(frame, alpha)
    if not frame.SetBackdrop then
        Mixin(frame, BackdropTemplateMixin)
    end
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0.05, 0.05, 0.08, alpha or 0.9)
    frame:SetBackdropBorderColor(0.5, 0.5, 0.55, 1)
end
W.Backdrop = backdrop

-- Multi-line text field with scroll bar. Returns container, editBox.
function W.MultiLine(parent, width, height)
    local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    box:SetSize(width, height)
    backdrop(box, 0.6)

    local ok, sf = pcall(CreateFrame, "ScrollFrame", nil, box, "UIPanelScrollFrameTemplate")
    if not ok then
        sf = CreateFrame("ScrollFrame", nil, box)
    end
    sf:SetPoint("TOPLEFT", 6, -6)
    sf:SetPoint("BOTTOMRIGHT", ok and -28 or -6, 6)

    local eb = CreateFrame("EditBox", nil, sf)
    eb:SetMultiLine(true)
    eb:SetAutoFocus(false)
    eb:SetFontObject(ChatFontNormal)
    eb:SetWidth(width - 40)
    eb:SetMaxLetters(0)
    eb:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    eb:SetScript("OnCursorChanged", function(self, _, y, _, h)
        local top = -y
        local scroll = sf:GetVerticalScroll()
        local visible = sf:GetHeight()
        if top < scroll then
            sf:SetVerticalScroll(top)
        elseif top + h > scroll + visible then
            sf:SetVerticalScroll(math.max(0, top + h - visible))
        end
    end)
    sf:SetScrollChild(eb)
    if not ok then
        sf:EnableMouseWheel(true)
        sf:SetScript("OnMouseWheel", function(self, delta)
            local maxScroll = math.max(0, eb:GetHeight() - self:GetHeight())
            self:SetVerticalScroll(math.min(maxScroll, math.max(0, self:GetVerticalScroll() - delta * 30)))
        end)
    end
    box:EnableMouse(true)
    box:SetScript("OnMouseDown", function()
        eb:SetFocus()
    end)
    box.editBox = eb
    box.scrollFrame = sf
    return box, eb
end

-- Simple vertical scroll bar without templates.
function W.ScrollBar(parent, onChange)
    local sb = CreateFrame("Slider", nil, parent)
    sb:SetOrientation("VERTICAL")
    sb:SetWidth(12)
    local bg = sb:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.35)
    local thumb = sb:CreateTexture(nil, "OVERLAY")
    thumb:SetColorTexture(0.55, 0.55, 0.6, 0.9)
    thumb:SetSize(10, 32)
    sb:SetThumbTexture(thumb)
    sb:SetMinMaxValues(0, 0)
    sb:SetValueStep(1)
    if sb.SetObeyStepOnDrag then
        sb:SetObeyStepOnDrag(true)
    end
    sb:SetValue(0)
    sb:SetScript("OnValueChanged", function(self, value)
        onChange(math.floor(value + 0.5))
    end)
    return sb
end

--[[ Virtual list: only `visibleRows` row frames exist, data is scrolled through them.
  opts = { rowHeight, createRow(parent, i) -> row, updateRow(row, item, index) }
]]
function W.List(parent, opts)
    local list = CreateFrame("Frame", nil, parent)
    list.items = {}
    list.offset = 0
    list.rows = {}
    list.rowHeight = opts.rowHeight or 20

    list.scrollBar = W.ScrollBar(list, function(v)
        list.offset = v
        list:Refresh()
    end)
    list.scrollBar:SetPoint("TOPRIGHT", 0, 0)
    list.scrollBar:SetPoint("BOTTOMRIGHT", 0, 0)

    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(self, delta)
        local _, maxV = self.scrollBar:GetMinMaxValues()
        local v = math.max(0, math.min(maxV, self.offset - delta * 3))
        self.scrollBar:SetValue(v)
    end)

    function list:Layout()
        local h = self:GetHeight()
        local count = math.max(1, math.floor(h / self.rowHeight))
        for i = 1, count do
            if not self.rows[i] then
                local row = opts.createRow(self, i)
                row:SetHeight(self.rowHeight)
                row:SetPoint("TOPLEFT", 0, -(i - 1) * self.rowHeight)
                row:SetPoint("RIGHT", self.scrollBar, "LEFT", -2, 0)
                self.rows[i] = row
            end
        end
        self.visibleRows = count
        for i = count + 1, #self.rows do
            self.rows[i]:Hide()
        end
    end

    function list:SetItems(items)
        if not self.visibleRows then
            self:Layout()
        end
        self.items = items or {}
        local maxOffset = math.max(0, #self.items - (self.visibleRows or 0))
        self.scrollBar:SetMinMaxValues(0, maxOffset)
        if self.offset > maxOffset then
            self.offset = maxOffset
        end
        self.scrollBar:SetValue(self.offset)
        if maxOffset == 0 then
            self.scrollBar:Hide()
        else
            self.scrollBar:Show()
        end
        self:Refresh()
    end

    function list:Refresh()
        for i = 1, self.visibleRows or 0 do
            local row = self.rows[i]
            local item = self.items[self.offset + i]
            if item then
                opts.updateRow(row, item, self.offset + i)
                row:Show()
            else
                row:Hide()
            end
        end
    end

    list:SetScript("OnSizeChanged", function(self)
        self:Layout()
        self:SetItems(self.items)
    end)
    return list
end

-- Cycle button: shows the current option, click goes to the next one.
-- options = { { value = ..., text = ... }, ... }
function W.Cycle(parent, width, options, getValue, setValue)
    local b = W.Button(parent, "", width, 22)
    local function refresh()
        local v = getValue()
        for _, o in ipairs(options) do
            if o.value == v then
                b:SetText(o.text)
                return
            end
        end
        b:SetText(options[1].text)
    end
    b:SetScript("OnClick", function()
        local v = getValue()
        local idx = 1
        for i, o in ipairs(options) do
            if o.value == v then
                idx = i
            end
        end
        local nextOpt = options[idx % #options + 1]
        setValue(nextOpt.value)
        refresh()
    end)
    b.Refresh = refresh
    refresh()
    return b
end
