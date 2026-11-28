-- The Guild Registrar - Settings page "Dungeon roles": sources and their priority, keywords,
-- overview of the roles each class can take

local _, ns = ...

local L = ns.L
local W = ns.W

local function settings()
    local g = ns.DB.Guild()
    return g and g.settings
end

local function rerun()
    ns.Engine.Run()
end

local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
local KEYWORD_LISTS = { "tank", "heal", "melee", "ranged", "dd" }

local function className(classFile)
    local names = LOCALIZED_CLASS_NAMES_MALE
    return (names and names[classFile]) or (classFile:sub(1, 1) .. classFile:sub(2):lower())
end

-- Small arrow button (scroll button templates exist in every client; plain button otherwise).
local function arrowButton(parent, up, onClick)
    local ok, b = pcall(CreateFrame, "Button", nil, parent,
        up and "UIPanelScrollUpButtonTemplate" or "UIPanelScrollDownButtonTemplate")
    if not ok or not b then
        b = W.Button(parent, up and "^" or "v", 22, 20)
    end
    b:SetSize(18, 16)
    b:SetScript("OnClick", onClick)
    return b
end

-- Keyword list text -> list (one per line or separated by commas/semicolons; spaces stay).
local function parseList(text)
    local list = {}
    for _, line in ipairs(ns.Util.linesToList(text or "")) do
        for part in line:gmatch("[^,;]+") do
            local w = ns.Util.trim(part)
            if w ~= "" then
                list[#list + 1] = w
            end
        end
    end
    return list
end

local function create(parent)
    local f = CreateFrame("Frame", nil, parent)
    local x1, x2 = 8, 520

    local intro = W.Label(f, L.DROLE_PAGE_INTRO, "GameFontHighlight")
    intro:SetPoint("TOPLEFT", x1, -6)
    intro:SetWidth(490)
    intro:SetJustifyV("TOP")

    -- sources ----------------------------------------------------------------------------
    local srcTitle = W.Label(f, L.DROLE_SOURCES, "GameFontNormalLarge")
    srcTitle:SetPoint("TOPLEFT", x1, -76)
    f.sourceRows = {}
    for i = 1, #ns.DungeonRoles.SOURCES do
        local row = CreateFrame("Frame", nil, f)
        row:SetSize(480, 26)
        row:SetPoint("TOPLEFT", x1, -98 - (i - 1) * 26)
        row.num = W.Label(row, i .. ".", "GameFontNormal")
        row.num:SetPoint("LEFT", 2, 0)
        row.check = W.Check(row, "", function(_, checked)
            local s = settings()
            if s and s.dungeonRoleSources[i] then
                s.dungeonRoleSources[i].on = checked
                rerun()
            end
        end)
        row.check:SetPoint("LEFT", 18, 0)
        local function move(delta)
            local s = settings()
            local list = s and s.dungeonRoleSources
            local j = i + delta
            if list and list[j] then
                list[i], list[j] = list[j], list[i]
                f.Load()
                rerun()
            end
        end
        row.up = arrowButton(row, true, function()
            move(-1)
        end)
        row.up:SetPoint("LEFT", 400, 0)
        W.Tooltip(row.up, L.DROLE_MOVE_UP)
        row.down = arrowButton(row, false, function()
            move(1)
        end)
        row.down:SetPoint("LEFT", row.up, "RIGHT", 4, 0)
        W.Tooltip(row.down, L.DROLE_MOVE_DOWN)
        f.sourceRows[i] = row
    end

    -- classes ------------------------------------------------------------------------------
    local cy = -98 - #ns.DungeonRoles.SOURCES * 26 - 18
    local clsTitle = W.Label(f, L.DROLE_CLASSES, "GameFontNormalLarge")
    clsTitle:SetPoint("TOPLEFT", x1, cy)
    local colX = { 150, 210, 270, 330 }
    for k, r in ipairs(ns.DungeonRoles.ROLES) do
        local head = W.Label(f, W.RoleIcon(r, 16), "GameFontNormal")
        head:SetPoint("TOPLEFT", x1 + colX[k], cy - 24)
    end
    for i, cls in ipairs(CLASSES) do
        local y = cy - 44 - (i - 1) * 17
        local name = W.Label(f, W.Colorize(className(cls), W.ClassColor(cls)), "GameFontHighlightSmall")
        name:SetPoint("TOPLEFT", x1 + 4, y)
        for k, r in ipairs(ns.DungeonRoles.ROLES) do
            local mark = ns.DungeonRoles.ClassAllows(cls, r) and W.RoleIcon(r, 13) or "|cff555555-|r"
            local m = W.Label(f, mark, "GameFontHighlightSmall")
            m:SetPoint("TOPLEFT", x1 + colX[k] + 1, y)
        end
    end
    local legend = {}
    for _, r in ipairs(ns.DungeonRoles.ROLES) do
        legend[#legend + 1] = W.RoleIcon(r, 12) .. " " .. L["DROLE_" .. r:upper()]
    end
    local legendLabel = W.Label(f, table.concat(legend, "   "), "GameFontHighlightSmall")
    legendLabel:SetPoint("TOPLEFT", x1 + 4, cy - 44 - #CLASSES * 17 - 6)
    local clsHint = W.Label(f, L.DROLE_CLASSES_HINT, "GameFontDisableSmall")
    clsHint:SetPoint("TOPLEFT", legendLabel, "BOTTOMLEFT", 0, -6)
    clsHint:SetWidth(480)
    clsHint:SetJustifyV("TOP")

    -- keywords -----------------------------------------------------------------------------
    local kwTitle = W.Label(f, L.DROLE_KEYWORDS, "GameFontNormalLarge")
    kwTitle:SetPoint("TOPLEFT", x2, -6)
    local kwHint = W.Label(f, L.DROLE_KEYWORDS_HINT, "GameFontDisableSmall")
    kwHint:SetPoint("TOPLEFT", x2, -28)
    kwHint:SetWidth(480)
    kwHint:SetJustifyV("TOP")
    f.keywordBoxes = {}
    for i, key in ipairs(KEYWORD_LISTS) do
        local col, rowN = (i - 1) % 2, math.floor((i - 1) / 2)
        local x, y = x2 + col * 245, -62 - rowN * 128
        local title = key == "dd" and L.DROLE_KEYWORDS_DD or (W.RoleIcon(key, 14) .. " " .. L["DROLE_" .. key:upper()])
        local lbl = W.Label(f, title, "GameFontNormal")
        lbl:SetPoint("TOPLEFT", x, y)
        local box, eb = W.MultiLine(f, 235, 100)
        box:SetPoint("TOPLEFT", x, y - 18)
        f.keywordBoxes[key] = eb
    end
    local apply = W.Button(f, L.DROLE_KEYWORDS_APPLY, 230, 24, function()
        local s = settings()
        if not s then
            return
        end
        for key, eb in pairs(f.keywordBoxes) do
            s.dungeonRoleKeywords[key] = parseList(eb:GetText())
            eb:ClearFocus()
        end
        f.Load()
        rerun()
    end)
    apply:SetPoint("TOPLEFT", x2 + 245, -62 - 2 * 128 - 18)

    function f.Load()
        local s = settings()
        if not s then
            return
        end
        for i, row in ipairs(f.sourceRows) do
            local src = s.dungeonRoleSources[i]
            if src then
                row.check.label:SetText(L["DROLE_SOURCE_" .. src.key:upper() .. "_LONG"])
                row.check:SetChecked(src.on ~= false)
                row.up:SetEnabled(i > 1)
                row.down:SetEnabled(i < #s.dungeonRoleSources)
                row:Show()
            else
                row:Hide()
            end
        end
        for key, eb in pairs(f.keywordBoxes) do
            eb:SetText(table.concat(s.dungeonRoleKeywords[key] or {}, "\n"))
        end
    end
    return f
end

local function refresh(f)
    for _, eb in pairs(f.keywordBoxes) do
        if eb:HasFocus() then
            return
        end
    end
    f.Load()
end

ns.UI.RegisterSettingsPage({ key = "dungeonRoles", order = 3, title = L.SETTINGS_PAGE_DUNGEON_ROLES, create = create, refresh = refresh })
