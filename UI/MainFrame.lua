-- The Guild Registrar - main window with tabs

local _, ns = ...

local UI = {}
ns.UI = UI

local L = ns.L
local W = ns.W

UI.tabs = {}       -- registered by the tab files: { key, order, title, create(parent), refresh(frame) }
UI.tabFrames = {}

local main

function UI.RegisterTab(def)
    UI.tabs[#UI.tabs + 1] = def
    table.sort(UI.tabs, function(a, b)
        return a.order < b.order
    end)
end

local function savePosition()
    if not ns.db then
        return
    end
    local point, _, relPoint, x, y = main:GetPoint()
    ns.db.ui.position = { point, relPoint, x, y }
end

local function create()
    main = CreateFrame("Frame", "TheGuildRegistrarFrame", UIParent, "BackdropTemplate")
    main:SetSize(1040, 620)
    main:SetFrameStrata("HIGH")
    main:SetToplevel(true)
    main:SetClampedToScreen(true)
    main:EnableMouse(true)
    main:SetMovable(true)
    main:RegisterForDrag("LeftButton")
    main:SetScript("OnDragStart", main.StartMoving)
    main:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        savePosition()
    end)
    W.Backdrop(main, 0.96)
    local pos = ns.db and ns.db.ui.position
    if pos then
        main:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    else
        main:SetPoint("CENTER")
    end
    tinsert(UISpecialFrames, "TheGuildRegistrarFrame")

    main.title = W.Label(main, "The Guild Registrar", "GameFontNormalLarge")
    main.title:SetPoint("TOPLEFT", 16, -12)

    local close = CreateFrame("Button", nil, main, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)

    -- tab buttons
    main.tabButtons = {}
    local prev
    for i, def in ipairs(UI.tabs) do
        local b = W.Button(main, def.title, 130, 24, function()
            UI.SelectTab(def.key)
        end)
        if prev then
            b:SetPoint("LEFT", prev, "RIGHT", 4, 0)
        else
            b:SetPoint("TOPLEFT", 14, -36)
        end
        b.key = def.key
        main.tabButtons[i] = b
        prev = b
    end

    main.content = CreateFrame("Frame", nil, main)
    main.content:SetPoint("TOPLEFT", 12, -66)
    main.content:SetPoint("BOTTOMRIGHT", -12, 30)

    -- status line
    main.status = W.Label(main, "", "GameFontHighlightSmall")
    main.status:SetPoint("BOTTOMLEFT", 16, 10)
    main.status:SetPoint("RIGHT", -16, 0)

    main:SetScript("OnShow", function()
        UI.UpdateStatus()
        if not ns.state.results and not ns.state.running then
            ns.Engine.Refresh()
        end
    end)
    main:Hide()
end

function UI.SelectTab(key)
    if not main then
        create()
    end
    for _, def in ipairs(UI.tabs) do
        local f = UI.tabFrames[def.key]
        if def.key == key then
            if not f then
                f = def.create(main.content)
                f:SetAllPoints(main.content)
                UI.tabFrames[def.key] = f
            end
            f:Show()
            if def.refresh then
                def.refresh(f)
            end
        elseif f then
            f:Hide()
        end
    end
    for _, b in ipairs(main.tabButtons) do
        if b.key == key then
            b:LockHighlight()
            b:GetFontString():SetTextColor(1, 1, 1)
        else
            b:UnlockHighlight()
            b:GetFontString():SetTextColor(1, 0.82, 0)
        end
    end
    UI.currentTab = key
    if ns.db then
        ns.db.ui.lastTab = key
    end
end

function UI.IsShown()
    return main and main:IsShown() or false
end

function UI.Show(tab)
    if not main then
        create()
    end
    main:Show()
    local g = ns.DB.Guild()
    local default = (g and g.import) and "results" or "setup"
    UI.SelectTab(tab or UI.currentTab or (ns.db and ns.db.ui.lastTab) or default)
end

function UI.Toggle()
    if UI.IsShown() then
        main:Hide()
    else
        UI.Show()
    end
end

local function formatTime(t)
    if not t then
        return "-"
    end
    return date("%Y-%m-%d %H:%M", t)
end

function UI.UpdateStatus()
    if not main then
        return
    end
    local state = ns.state
    local g = ns.DB.Guild()
    local parts = {}
    local guildName = ns.DB.GuildName()
    parts[#parts + 1] = string.format("%s: |cffffffff%s|r", L.STATUS_GUILD, guildName or L.NONE)
    if ns.demoActive then
        parts[#parts + 1] = "|cffff8800" .. L.DEMO_ACTIVE .. "|r"
    end
    if g and g.import then
        parts[#parts + 1] = string.format("%s: |cffffffff%s|r (%d)", L.STATUS_LAST_IMPORT,
            formatTime(g.import.importedAt), #g.import.members)
    end
    if state.running then
        parts[#parts + 1] = "|cff66bbff" .. L.STATUS_RUNNING .. "|r"
    elseif state.error then
        parts[#parts + 1] = "|cffff6666" .. L[state.error] .. "|r"
    elseif state.lastRun then
        parts[#parts + 1] = string.format("%s: |cffffffff%s|r", L.STATUS_LAST_RUN, formatTime(state.lastRun))
    end
    if state.canViewOfficer == false then
        parts[#parts + 1] = "|cffffaa00" .. L.STATUS_NO_OFFICER_NOTES .. "|r"
    end
    main.status:SetText(table.concat(parts, "   |cff666666·|r   "))
    main.title:SetText("The Guild Registrar" .. (ns.demoActive and ("  |cffff8800[" .. L.DEMO .. "]|r") or ""))
end

-- Called by the engine whenever results or state change.
function UI.OnStateChanged()
    if not main then
        return
    end
    UI.UpdateStatus()
    for _, def in ipairs(UI.tabs) do
        local f = UI.tabFrames[def.key]
        if f and f:IsShown() and def.refresh then
            def.refresh(f)
        end
    end
end

-- Addon compartment (minimap addon menu)
function TheGuildRegistrar_OnAddonCompartmentClick()
    UI.Toggle()
end

function TheGuildRegistrar_OnAddonCompartmentEnter(_, menuButtonFrame)
    GameTooltip:SetOwner(menuButtonFrame or UIParent, "ANCHOR_LEFT")
    GameTooltip:SetText("The Guild Registrar", 1, 1, 1)
    GameTooltip:AddLine(L.COMPARTMENT_HINT, nil, nil, nil, true)
    GameTooltip:Show()
end

function TheGuildRegistrar_OnAddonCompartmentLeave()
    GameTooltip:Hide()
end
