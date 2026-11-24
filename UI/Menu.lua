-- The Guild Registrar - lightweight popup menu (independent of Blizzard's dropdown APIs)
-- items = { { text, func, disabled, isTitle, submenu = { items } } }

local _, ns = ...

local Menu = {}
ns.Menu = Menu

local MAX_ITEMS = 24
local ITEM_HEIGHT = 18

local blocker, frame

local function create()
    blocker = CreateFrame("Button", nil, UIParent)
    blocker:SetAllPoints(UIParent)
    blocker:SetFrameStrata("FULLSCREEN_DIALOG")
    blocker:RegisterForClicks("AnyUp")
    blocker:SetScript("OnClick", function()
        Menu.Close()
    end)
    blocker:Hide()

    frame = CreateFrame("Frame", nil, blocker, "BackdropTemplate")
    ns.W.Backdrop(frame, 0.95)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(blocker:GetFrameLevel() + 5)
    frame:EnableMouse(true)
    frame.buttons = {}
    for i = 1, MAX_ITEMS do
        local b = CreateFrame("Button", nil, frame)
        b:SetHeight(ITEM_HEIGHT)
        b:SetPoint("TOPLEFT", 6, -6 - (i - 1) * ITEM_HEIGHT)
        b:SetPoint("RIGHT", -6, 0)
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(0.3, 0.5, 0.9, 0.35)
        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        b.text:SetPoint("LEFT", 4, 0)
        b.text:SetPoint("RIGHT", -4, 0)
        b.text:SetJustifyH("LEFT")
        b:SetScript("OnClick", function(self)
            local item = self.item
            if not item or item.disabled or item.isTitle then
                return
            end
            if item.submenu then
                Menu.Open(item.submenu, frame.anchor)
                return
            end
            Menu.Close()
            if item.func then
                item.func()
            end
        end)
        frame.buttons[i] = b
    end
end

function Menu.Close()
    if blocker then
        blocker:Hide()
    end
end

-- Open the menu at the cursor (or at `anchor` = {x, y}).
function Menu.Open(items, anchor)
    if not blocker then
        create()
    end
    local scale = UIParent:GetEffectiveScale()
    if not anchor then
        local x, y = GetCursorPosition()
        anchor = { x / scale, y / scale }
    end
    frame.anchor = anchor

    local width = 160
    local n = math.min(#items, MAX_ITEMS)
    for i, b in ipairs(frame.buttons) do
        local item = items[i]
        if i <= n and item then
            b.item = item
            local text = item.text or ""
            if item.submenu then
                text = text .. "  >"
            end
            b.text:SetText(text)
            if item.isTitle then
                b.text:SetTextColor(1, 0.82, 0)
            elseif item.disabled then
                b.text:SetTextColor(0.5, 0.5, 0.5)
            else
                b.text:SetTextColor(1, 1, 1)
            end
            b:EnableMouse(not item.isTitle)
            width = math.max(width, b.text:GetStringWidth() + 24)
            b:Show()
        else
            b.item = nil
            b:Hide()
        end
    end
    frame:SetSize(width, n * ITEM_HEIGHT + 12)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", anchor[1], anchor[2])
    -- keep on screen
    local right = anchor[1] + width
    local screenW = UIParent:GetWidth()
    if right > screenW then
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", screenW - width - 4, anchor[2])
    end
    if anchor[2] - frame:GetHeight() < 0 then
        frame:ClearAllPoints()
        frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", math.min(anchor[1], screenW - width - 4), 4)
    end
    blocker:Show()
end
