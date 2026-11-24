-- The Guild Registrar - "Import" tab: paste the export of the companion app

local _, ns = ...

local L = ns.L
local W = ns.W

local function describe(parsed)
    local lines = {}
    if parsed.ok then
        lines[#lines + 1] = "|cff44ff44" .. string.format(L.IMPORT_OK, #parsed.members, #parsed.roles) .. "|r"
        if parsed.server and parsed.server ~= "" then
            lines[#lines + 1] = string.format(L.IMPORT_SERVER, parsed.server, parsed.timestamp or "-")
        end
    end
    for _, e in ipairs(parsed.errors) do
        lines[#lines + 1] = string.format("|cffff4444%s|r %s %s", L.IMPORT_LINE:format(e.line), L[e.msg], e.detail or "")
    end
    local shown = 0
    for _, w in ipairs(parsed.warnings) do
        shown = shown + 1
        if shown > 12 then
            lines[#lines + 1] = string.format(L.IMPORT_MORE_WARNINGS, #parsed.warnings - 12)
            break
        end
        lines[#lines + 1] = string.format("|cffffaa00%s|r %s %s", L.IMPORT_LINE:format(w.line), L[w.msg], w.detail or "")
    end
    return table.concat(lines, "\n")
end

local function create(parent)
    local f = CreateFrame("Frame", nil, parent)

    local intro = W.Label(f, L.IMPORT_INTRO, "GameFontHighlight")
    intro:SetPoint("TOPLEFT", 8, -8)
    intro:SetPoint("RIGHT", -8, 0)
    intro:SetJustifyV("TOP")

    local box, eb = W.MultiLine(f, 640, 420)
    box:SetPoint("TOPLEFT", 8, -50)
    f.editBox = eb

    local importBtn = W.Button(f, L.IMPORT_BUTTON, 160, 24, function()
        local text = eb:GetText()
        local parsed = ns.Engine.Import(text)
        f.result:SetText(describe(parsed))
        if parsed.ok then
            eb:SetText("")
            eb:ClearFocus()
        end
    end)
    importBtn:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -8)

    local clearBtn = W.Button(f, L.IMPORT_CLEAR, 120, 24, function()
        eb:SetText("")
        f.result:SetText("")
    end)
    clearBtn:SetPoint("LEFT", importBtn, "RIGHT", 8, 0)

    local toResults = W.Button(f, L.IMPORT_TO_RESULTS, 160, 24, function()
        ns.UI.SelectTab("results")
    end)
    toResults:SetPoint("LEFT", clearBtn, "RIGHT", 8, 0)

    local side = CreateFrame("Frame", nil, f)
    side:SetPoint("TOPLEFT", box, "TOPRIGHT", 16, 0)
    side:SetPoint("BOTTOMRIGHT", -8, 8)

    local current = W.Label(side, "", "GameFontHighlight")
    current:SetPoint("TOPLEFT", 0, 0)
    current:SetPoint("RIGHT", 0, 0)
    current:SetJustifyV("TOP")
    f.current = current

    local result = W.Label(side, "", "GameFontHighlightSmall")
    result:SetPoint("TOPLEFT", current, "BOTTOMLEFT", 0, -16)
    result:SetPoint("RIGHT", 0, 0)
    result:SetJustifyV("TOP")
    f.result = result

    local help = W.Label(side, L.IMPORT_HELP, "GameFontDisableSmall")
    help:SetPoint("BOTTOMLEFT", 0, 0)
    help:SetPoint("RIGHT", 0, 0)
    help:SetJustifyV("BOTTOM")
    return f
end

local function refresh(f)
    local g = ns.DB.Guild()
    if not g then
        f.current:SetText("|cffff6666" .. L.STATE_NO_GUILD .. "|r")
        return
    end
    if g.import then
        f.current:SetText(string.format(L.IMPORT_CURRENT, #g.import.members, #(g.import.roles or {}),
            g.import.server or "-", g.import.timestamp or "-",
            g.import.importedAt and date("%Y-%m-%d %H:%M", g.import.importedAt) or "-"))
    else
        f.current:SetText(L.IMPORT_NONE)
    end
end

ns.UI.RegisterTab({ key = "import", order = 2, title = L.TAB_IMPORT, create = create, refresh = refresh })
