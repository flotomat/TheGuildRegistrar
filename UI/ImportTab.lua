-- The Guild Registrar - "Import" tab: paste the export of Peasant (helper app)

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

-- Result of parsing an assignment code (errors and warnings like the Discord import).
local function describeShare(parsed)
    local lines = {}
    for _, e in ipairs(parsed.errors) do
        lines[#lines + 1] = string.format("|cffff4444%s|r %s %s", L.IMPORT_LINE:format(e.line), L[e.msg], e.detail or "")
    end
    for i, w in ipairs(parsed.warnings) do
        if i > 12 then
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
        -- a code with shared assignments of another officer
        if ns.Share.IsCode(text) then
            local parsed = ns.Share.Parse(text)
            f.result:SetText(describeShare(parsed))
            if parsed.ok then
                local c = parsed.counts
                local msg = string.format(L.SHARE_IMPORT_CONFIRM, parsed.created ~= "" and parsed.created or "-",
                    c.L or 0, c.R or 0, (c.T or 0) + (c.M or 0), (c.ID or 0) + (c.IC or 0))
                local guild = ns.DB.GuildName() or ""
                if parsed.guild and parsed.guild ~= "" and parsed.guild ~= guild then
                    msg = msg .. "\n\n" .. string.format(L.SHARE_GUILD_OTHER, parsed.guild, guild)
                end
                -- own decisions the code would overwrite or remove -> delete warning
                local g = ns.DB.Guild()
                local lost = ns.Protect.Share(g and g.decisions, parsed)
                ns.Dialogs.ShowDeleteWarning(L.SHARE_IMPORT_TITLE, msg, lost, function()
                    local n = ns.Engine.ImportDecisions(parsed)
                    local done = string.format(L.SHARE_IMPORTED, n)
                    f.result:SetText("|cff44ff44" .. done .. "|r")
                    ns.Engine.Print(done)
                    eb:SetText("")
                    eb:ClearFocus()
                end, L.PROTECT_OVERWRITE)
            end
            return
        end
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

    -- delete Discord data (import + decisions): current guild / all guilds, always with confirmation
    local deleteBtn = W.Button(side, L.IMPORT_DELETE, 260, 24, function()
        ns.Dialogs.ShowDeleteWarning(L.IMPORT_DELETE, L.IMPORT_DELETE_CONFIRM, ns.Protect.GuildData(ns.DB.Guild()), function()
            if ns.Engine.DeleteImportedData() then
                f.result:SetText("|cff44ff44" .. L.IMPORT_DELETED .. "|r")
                ns.Engine.Print(L.IMPORT_DELETED)
            end
        end)
    end)
    W.Tooltip(deleteBtn, L.IMPORT_DELETE, W.LocText("IMPORT_DELETE_TOOLTIP"))
    f.deleteBtn = deleteBtn

    local deleteAllBtn = W.Button(side, L.IMPORT_DELETE_ALL, 260, 24, function()
        ns.UI.ConfirmDeleteAllData(function(n)
            f.result:SetText("|cff44ff44" .. string.format(L.IMPORT_DELETED_ALL, n) .. "|r")
        end)
    end)
    W.Tooltip(deleteAllBtn, L.IMPORT_DELETE_ALL, W.LocText("IMPORT_DELETE_ALL_TOOLTIP"))
    f.deleteAllBtn = deleteAllBtn

    local stored = W.Label(side, "", "GameFontHighlightSmall")
    stored:SetPoint("RIGHT", 0, 0)
    stored:SetJustifyV("BOTTOM")
    f.stored = stored

    local help = W.Label(side, L.IMPORT_HELP, "GameFontDisableSmall")
    help:SetPoint("BOTTOMLEFT", 0, 0)
    help:SetPoint("RIGHT", 0, 0)
    help:SetJustifyV("BOTTOM")
    deleteAllBtn:SetPoint("BOTTOMLEFT", help, "TOPLEFT", 0, 12)
    deleteBtn:SetPoint("BOTTOMLEFT", deleteAllBtn, "TOPLEFT", 0, 6)
    stored:SetPoint("BOTTOMLEFT", deleteBtn, "TOPLEFT", 0, 8)
    return f
end

-- "Guild A, Guild B, ... and 3 more" (at most `max` names)
local function guildList(keys, max)
    local names = {}
    for i = 1, math.min(#keys, max) do
        names[#names + 1] = keys[i]
    end
    local text = table.concat(names, ", ")
    if #keys > max then
        text = text .. " " .. string.format(L.IMPORT_AND_MORE, #keys - max)
    end
    return text
end

-- Confirm and delete the Discord data of all guilds (also used by /tgr wipe).
function ns.UI.ConfirmDeleteAllData(onDone)
    local keys = ns.DB.GuildsWithData()
    if #keys == 0 then
        ns.Engine.Print(L.IMPORT_STORED_NONE)
        return
    end
    local text = string.format(L.IMPORT_DELETE_ALL_CONFIRM, #keys, guildList(keys, 15))
    local lost = {}
    for _, key in ipairs(keys) do
        ns.Protect.Merge(lost, ns.Protect.GuildData(ns.db.guilds[key]))
    end
    ns.Dialogs.ShowDeleteWarning(L.IMPORT_DELETE_ALL, text, lost, function()
        local n = ns.Engine.DeleteAllImportedData()
        ns.Engine.Print(string.format(L.IMPORT_DELETED_ALL, n))
        if onDone then
            onDone(n)
        end
    end)
end

local function refresh(f)
    -- data stored on this account (all real guilds, not the demo)
    local keys = ns.DB.GuildsWithData()
    if #keys > 0 then
        f.stored:SetText(string.format(L.IMPORT_STORED, #keys, guildList(keys, 6)))
    else
        f.stored:SetText(L.IMPORT_STORED_NONE)
    end
    f.deleteAllBtn:SetShown(#keys > 0)

    local g = ns.DB.Guild()
    if not g then
        f.current:SetText("|cffff6666" .. L.STATE_NO_GUILD .. "|r")
        f.deleteBtn:Hide()
        return
    end
    -- only shown when the current (non-demo) guild has data to delete
    f.deleteBtn:SetShown(not ns.demoActive and ns.DB.HasDiscordData(g))
    if g.import then
        f.current:SetText(string.format(L.IMPORT_CURRENT, #g.import.members, #(g.import.roles or {}),
            g.import.server or "-", g.import.timestamp or "-",
            g.import.importedAt and date("%Y-%m-%d %H:%M", g.import.importedAt) or "-"))
    else
        f.current:SetText(L.IMPORT_NONE)
    end
end

ns.UI.RegisterTab({ key = "import", order = 2, title = L.TAB_IMPORT, create = create, refresh = refresh })
