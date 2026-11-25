-- The Guild Registrar - entry in the game's Options -> AddOns list
-- Only a small launcher page: the real settings stay in the addon window (tabs Ranks / Options).

local ADDON_NAME, ns = ...

local W = ns.W
local TITLE = "The Guild Registrar"

local function addonVersion()
    local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local v = get and get(ADDON_NAME, "Version")
    if not v or v == "" or v:find("@", 1, true) then
        return nil
    end
    return v
end

-- Close the game's options window (and the game menu behind it) so the addon window is visible.
local function closeGameOptions()
    for _, name in ipairs({ "SettingsPanel", "InterfaceOptionsFrame", "GameMenuFrame" }) do
        local f = _G[name]
        if f and f.IsShown and f:IsShown() then
            HideUIPanel(f)
        end
    end
end

local function open(tab)
    closeGameOptions()
    ns.UI.Show(tab)
end

local function build()
    local panel = CreateFrame("Frame")
    panel.name = TITLE

    local title = W.Label(panel, TITLE, "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)

    local version = addonVersion()
    if version then
        local v = W.Label(panel, version, "GameFontDisableSmall")
        v:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 8, 1)
    end

    local intro = W.Localized(W.Label(panel, nil, "GameFontHighlight"), "SETTINGS_INTRO")
    intro:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
    intro:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    intro:SetJustifyV("TOP")

    local openBtn = W.Localized(W.Button(panel, nil, 220, 26, function()
        open()
    end), "SETTINGS_OPEN")
    openBtn:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 0, -16)

    local optionsBtn = W.Localized(W.Button(panel, nil, 220, 26, function()
        open("options")
    end), "SETTINGS_OPEN_OPTIONS")
    optionsBtn:SetPoint("TOPLEFT", openBtn, "BOTTOMLEFT", 0, -8)

    local slash = W.Localized(W.Label(panel, nil, "GameFontDisable"), "SETTINGS_SLASH")
    slash:SetPoint("TOPLEFT", optionsBtn, "BOTTOMLEFT", 0, -16)
    slash:SetPoint("RIGHT", panel, "RIGHT", -16, 0)

    return panel
end

local function register()
    local panel = build()
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, TITLE)
        Settings.RegisterAddOnCategory(category)
        ns.settingsCategory = category
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end

-- Never let a changed options API break the rest of the addon.
local ok, err = pcall(register)
if not ok and ns.Engine and ns.Engine.Print then
    ns.Engine.Print("Options entry not available: " .. tostring(err))
end
