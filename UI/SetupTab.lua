-- The Guild Registrar - "Setup" tab: step-by-step guide with copyable links

local _, ns = ...

local L = ns.L
local W = ns.W

ns.LINKS = {
    releases = "https://github.com/Flotomat/TheGuildRegistrar/releases/latest",
    guide = (ns.activeLocale == "deDE")
        and "https://github.com/Flotomat/TheGuildRegistrar/blob/main/docs/setup-guide.de.md"
        or "https://github.com/Flotomat/TheGuildRegistrar/blob/main/docs/setup-guide.md",
    portal = "https://discord.com/developers/applications",
}

local function create(parent)
    local f = CreateFrame("Frame", nil, parent)

    local intro = W.Label(f, L.SETUP_INTRO, "GameFontHighlight")
    intro:SetPoint("TOPLEFT", 8, -8)
    intro:SetWidth(990)
    intro:SetJustifyV("TOP")

    local y = -56
    local steps = {
        { title = L.SETUP_STEP1_TITLE, text = L.SETUP_STEP1_TEXT, link = ns.LINKS.releases },
        { title = L.SETUP_STEP2_TITLE, text = L.SETUP_STEP2_TEXT, link = ns.LINKS.portal },
        { title = L.SETUP_STEP3_TITLE, text = L.SETUP_STEP3_TEXT },
        { title = L.SETUP_STEP4_TITLE, text = L.SETUP_STEP4_TEXT },
        { title = L.SETUP_STEP5_TITLE, text = L.SETUP_STEP5_TEXT },
    }
    for i, s in ipairs(steps) do
        local num = W.Label(f, tostring(i), "GameFontNormalHuge")
        num:SetPoint("TOPLEFT", 12, y)
        local title = W.Label(f, s.title, "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 48, y)
        local text = W.Label(f, s.text, "GameFontHighlight")
        text:SetPoint("TOPLEFT", 48, y - 22)
        text:SetWidth(940)
        text:SetJustifyV("TOP")
        local h = 22 + math.max(16, text:GetStringHeight())
        if s.link then
            local box = W.CopyBox(f, 520, s.link)
            box:SetPoint("TOPLEFT", 54, y - h - 4)
            h = h + 30
        end
        y = y - h - 16
    end

    local guideLabel = W.Label(f, L.SETUP_GUIDE_LINK, "GameFontNormal")
    guideLabel:SetPoint("TOPLEFT", 12, y)
    local guide = W.CopyBox(f, 520, ns.LINKS.guide)
    guide:SetPoint("LEFT", guideLabel, "RIGHT", 14, 0)

    local hint = W.Label(f, L.SETUP_COPY_HINT, "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", 12, y - 26)

    local demo = W.Button(f, L.DEMO_BUTTON, 200, 24, function()
        ns.Engine.SetDemo(not ns.demoActive)
        ns.UI.SelectTab("results")
    end)
    demo:SetPoint("BOTTOMRIGHT", -8, 8)
    f.demoButton = demo
    W.Tooltip(demo, L.DEMO_BUTTON, L.DEMO_TOOLTIP)

    local importBtn = W.Button(f, L.SETUP_GO_IMPORT, 200, 24, function()
        ns.UI.SelectTab("import")
    end)
    importBtn:SetPoint("RIGHT", demo, "LEFT", -8, 0)
    return f
end

local function refresh(f)
    f.demoButton:SetText(ns.demoActive and L.DEMO_OFF_BUTTON or L.DEMO_BUTTON)
end

ns.UI.RegisterTab({ key = "setup", order = 1, title = L.TAB_SETUP, create = create, refresh = refresh })
