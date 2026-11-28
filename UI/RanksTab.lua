-- The Guild Registrar - Settings page "Ranks": Discord role -> guild rank, guest roles, twink ranks

local _, ns = ...

local L = ns.L
local W = ns.W

local function settings()
    local g = ns.DB.Guild()
    return g and g.settings, g
end

local function inList(list, name)
    local key = ns.Text.key(name)
    for i, v in ipairs(list) do
        if ns.Text.key(v) == key then
            return i
        end
    end
    return nil
end

local function setInList(list, name, on)
    local i = inList(list, name)
    if on and not i then
        list[#list + 1] = name
    elseif not on and i then
        table.remove(list, i)
    end
end

local function rerun()
    ns.Engine.Run()
end

local function create(parent)
    local f = CreateFrame("Frame", nil, parent)

    local intro = W.Localized(W.Label(f, "", "GameFontHighlight"), "RANKS_INTRO")
    intro:SetPoint("TOPLEFT", 8, -8)
    intro:SetWidth(990)
    intro:SetJustifyV("TOP")

    -- left: Discord roles ------------------------------------------------------------
    local leftTitle = W.Label(f, L.RANKS_DISCORD_ROLES, "GameFontNormalLarge")
    leftTitle:SetPoint("TOPLEFT", 8, -56)

    local headRole = W.Label(f, L.RANKS_COL_ROLE, "GameFontNormalSmall")
    headRole:SetPoint("TOPLEFT", 12, -82)
    local headRank = W.Label(f, L.RANKS_COL_RANK, "GameFontNormalSmall")
    headRank:SetPoint("TOPLEFT", 252, -82)
    local headGuest = W.Label(f, L.RANKS_COL_GUEST, "GameFontNormalSmall")
    headGuest:SetPoint("TOPLEFT", 452, -82)

    local list = W.List(f, {
        rowHeight = 26,
        createRow = function(parent_, i)
            local row = CreateFrame("Frame", nil, parent_)
            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.04 or 0)
            row.name = W.Label(row, "", "GameFontHighlight")
            row.name:SetPoint("LEFT", 4, 0)
            row.name:SetWidth(230)
            row.name:SetWordWrap(false)
            row.rankButton = W.Button(row, "", 180, 22)
            row.rankButton:SetPoint("LEFT", 240, 0)
            row.guest = W.Check(row, "")
            row.guest:SetPoint("LEFT", 450, 0)
            row.rankButton:SetScript("OnClick", function()
                local s = settings()
                if not s then
                    return
                end
                local role = row.role
                local items = { { text = role, isTitle = true }, { text = L.RANKS_NONE, func = function()
                    s.roleMapping[role] = nil
                    f.Update()
                    rerun()
                end } }
                for idx, rankName in ipairs(ns.state.rankNames or {}) do
                    items[#items + 1] = { text = string.format("%d. %s", idx, rankName), func = function()
                        s.roleMapping[role] = idx
                        f.Update()
                        rerun()
                    end }
                end
                ns.Menu.Open(items)
            end)
            row.guest:SetScript("OnClick", function(self)
                local s = settings()
                if s then
                    setInList(s.guestRoleNames, row.role, self:GetChecked())
                    rerun()
                end
            end)
            return row
        end,
        updateRow = function(row, role)
            local s = settings()
            row.role = role
            row.name:SetText(role)
            local idx = s and s.roleMapping[role]
            if idx then
                row.rankButton:SetText(string.format("%d. %s", idx, ns.state.rankNames[idx] or "?"))
            else
                row.rankButton:SetText("|cff999999" .. L.RANKS_NONE .. "|r")
            end
            row.guest:SetChecked(s and inList(s.guestRoleNames, role) and true or false)
        end,
    })
    list:SetPoint("TOPLEFT", 8, -100)
    list:SetSize(520, 350)
    f.list = list

    f.noRoles = W.Label(f, L.RANKS_NO_IMPORT, "GameFontDisable")
    f.noRoles:SetPoint("TOPLEFT", 12, -108)

    local orderHint = W.Label(f, L.RANKS_ORDER_HINT, "GameFontDisableSmall")
    orderHint:SetPoint("TOPLEFT", list, "BOTTOMLEFT", 4, -8)
    orderHint:SetWidth(520)
    orderHint:SetJustifyV("TOP")

    -- right: guild ranks ---------------------------------------------------------------
    local rx = 580
    local rightTitle = W.Label(f, L.RANKS_GUILD_RANKS, "GameFontNormalLarge")
    rightTitle:SetPoint("TOPLEFT", rx, -56)
    local headTwink = W.Localized(W.Label(f, "", "GameFontNormalSmall"), "RANKS_COL_TWINK")
    headTwink:SetPoint("TOPLEFT", rx + 4, -82)

    f.rankChecks = {}
    for i = 1, 10 do
        local cb = W.Check(f, "", function(self, checked)
            local s = settings()
            local name = ns.state.rankNames[i]
            if s and name then
                setInList(s.twinkRankNames, name, checked)
                rerun()
            end
        end)
        cb:SetPoint("TOPLEFT", rx, -100 - (i - 1) * 26)
        f.rankChecks[i] = cb
    end

    -- rank check options
    local optY = -100 - 10 * 26 - 16
    local minLabel = W.Label(f, L.RANKS_MIN_STATUS, "GameFontNormal")
    minLabel:SetPoint("TOPLEFT", rx, optY)
    f.minCycle = W.Cycle(f, 200, {
        { value = "sure", text = L.STATUS_SURE },
        { value = "likely", text = L.STATUS_LIKELY },
        { value = "unlikely", text = L.STATUS_UNLIKELY },
    }, function()
        local s = settings()
        return s and s.rankCheckMinStatus or "likely"
    end, function(v)
        local s = settings()
        if s then
            s.rankCheckMinStatus = v
            rerun()
        end
    end)
    f.minCycle:SetPoint("TOPLEFT", minLabel, "BOTTOMLEFT", 0, -6)

    f.acceptTwink = W.Check(f, L.RANKS_ACCEPT_TWINK, function(_, checked)
        local s = settings()
        if s then
            s.acceptTwinkRanks = checked
            rerun()
        end
    end, W.LocText("RANKS_ACCEPT_TWINK_TOOLTIP"))
    W.Localized(f.acceptTwink.label, "RANKS_ACCEPT_TWINK")
    f.acceptTwink:SetPoint("TOPLEFT", f.minCycle, "BOTTOMLEFT", 0, -10)

    function f.Update()
        local s, g = settings()
        local roles = (g and g.import and g.import.roles) or {}
        list:SetItems(roles)
        f.noRoles:SetShown(#roles == 0)
        local ranks = ns.state.rankNames or {}
        if #ranks == 0 then
            ranks = ns.Roster.RankNames()
            ns.state.rankNames = ranks
        end
        for i, cb in ipairs(f.rankChecks) do
            local name = ranks[i]
            if name then
                cb.label:SetText(string.format("%d. %s", i, name))
                cb:SetChecked(s and inList(s.twinkRankNames, name) and true or false)
                cb:Show()
            else
                cb:Hide()
            end
        end
        f.minCycle.Refresh()
        f.acceptTwink:SetChecked(s and s.acceptTwinkRanks or false)
    end
    return f
end

local function refresh(f)
    f.Update()
end

ns.UI.RegisterSettingsPage({ key = "ranks", order = 2, title = L.SETTINGS_PAGE_RANKS, create = create, refresh = refresh })
