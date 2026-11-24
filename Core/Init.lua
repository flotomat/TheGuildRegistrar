-- The Guild Registrar - events and slash commands

local ADDON_NAME, ns = ...

local L = ns.L

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("GUILD_ROSTER_UPDATE")
events:RegisterEvent("PLAYER_GUILD_UPDATE")

events:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        ns.DB.Init()
    elseif event == "PLAYER_LOGIN" then
        -- nothing to do until the window is opened; keep login light
    elseif event == "GUILD_ROSTER_UPDATE" then
        ns.Engine.OnRosterUpdate()
    elseif event == "PLAYER_GUILD_UPDATE" then
        ns.state.results = nil
        if ns.UI.IsShown() then
            ns.Engine.Refresh()
        end
    end
end)

local function help()
    ns.Engine.Print(L.HELP_HEADER)
    print("  /tgr - " .. L.HELP_TOGGLE)
    print("  /tgr import - " .. L.HELP_IMPORT)
    print("  /tgr demo - " .. L.HELP_DEMO)
    print("  /tgr demo off - " .. L.HELP_DEMO_OFF)
    print("  /tgr refresh - " .. L.HELP_REFRESH)
    print("  /tgr wipe - " .. L.HELP_WIPE)
end

SLASH_THEGUILDREGISTRAR1 = "/tgr"
SLASH_THEGUILDREGISTRAR2 = "/registrar"
SlashCmdList.THEGUILDREGISTRAR = function(msg)
    msg = ns.Util.trim(msg or ""):lower()
    if msg == "" then
        ns.UI.Toggle()
    elseif msg == "import" then
        ns.UI.Show("import")
    elseif msg == "demo" or msg == "demo on" then
        ns.Engine.SetDemo(true)
        ns.UI.Show("results")
        ns.Engine.Print(L.DEMO_STARTED)
    elseif msg == "demo off" then
        ns.Engine.SetDemo(false)
        ns.Engine.Print(L.DEMO_STOPPED)
        if ns.UI.IsShown() then
            ns.UI.Show()
        end
    elseif msg == "refresh" then
        ns.Engine.Refresh()
    elseif msg == "wipe" then
        ns.UI.ConfirmDeleteAllData()
    else
        help()
    end
end
