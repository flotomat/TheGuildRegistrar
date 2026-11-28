-- The Guild Registrar - orchestration: import, roster, matching run, officer decisions

local _, ns = ...

local Engine = {}
ns.Engine = Engine

ns.state = {
    running = false,
    results = nil,
    rankNames = {},
    error = nil, -- localization key
    lastRun = nil,
}

local state = ns.state

-- Run a function as coroutine, spread over frames (max. ~8 ms per frame).
local asyncFrame
local function runAsync(fn, onDone, onError)
    local co = coroutine.create(fn)
    asyncFrame = asyncFrame or CreateFrame("Frame")
    asyncFrame:SetScript("OnUpdate", function(self)
        local start = debugprofilestop()
        repeat
            local ok, res = coroutine.resume(co)
            if not ok then
                self:SetScript("OnUpdate", nil)
                onError(res)
                return
            end
            if coroutine.status(co) == "dead" then
                self:SetScript("OnUpdate", nil)
                onDone(res)
                return
            end
        until debugprofilestop() - start > 8
    end)
end

local function notifyUI()
    if ns.UI and ns.UI.OnStateChanged then
        ns.UI.OnStateChanged()
    end
end

function Engine.Print(msg)
    print("|cff66bbffThe Guild Registrar:|r " .. tostring(msg))
end

-- Start a matching run (reads the roster, builds players, matches, checks ranks).
function Engine.Run()
    if state.running then
        state.rerun = true
        return
    end
    local g = ns.DB.Guild()
    if not g then
        state.error = "STATE_NO_GUILD"
        state.results = nil
        notifyUI()
        return
    end
    if not g.import or not g.import.members or #g.import.members == 0 then
        state.error = "STATE_NO_IMPORT"
        state.results = nil
        notifyUI()
        return
    end
    local roster = ns.Roster.Read()
    if not roster or #roster == 0 then
        state.error = "STATE_NO_ROSTER"
        state.awaitingRoster = true
        ns.Roster.Request()
        notifyUI()
        return
    end
    state.error = nil
    state.running = true
    state.rankNames = ns.Roster.RankNames()
    state.canViewOfficer = ns.Roster.CanViewOfficerNote()
    notifyUI()

    ns.SetAltTerm(g.settings.altTerm)
    local settings = ns.Util.copy(g.settings)
    if not state.canViewOfficer then
        settings.useOfficerNote = false
    end

    runAsync(function()
        local players = ns.Players.build(roster, settings, g.decisions)
        coroutine.yield()
        local res = ns.Matcher.run({
            members = g.import.members,
            players = players,
            settings = settings,
            decisions = g.decisions,
            yield = coroutine.yield,
        })
        res.rankStats = ns.Ranks.evaluate(res.rows, {
            roleOrder = g.import.roles,
            roleMapping = g.settings.roleMapping,
            twinkRankNames = g.settings.twinkRankNames,
            acceptTwinkRanks = g.settings.acceptTwinkRanks,
            minStatus = g.settings.rankCheckMinStatus,
        })
        ns.Professions.Evaluate(res.rows, { settings = settings, canViewOfficer = state.canViewOfficer,
            manual = g.professions and g.professions.manual })
        res.dungeonRoleCounts = ns.DungeonRoles.Evaluate(res.rows, {
            settings = settings,
            manual = g.dungeonRoles and g.dungeonRoles.manual,
            canViewOfficer = state.canViewOfficer,
        })
        res.summary.withAdvice = ns.Advice.evaluate(res.rows, {
            settings = settings,
            canViewOfficer = state.canViewOfficer,
            rankNames = state.rankNames,
            members = res.members,
        })
        res.rosterCount = #roster
        return res
    end, function(res)
        state.running = false
        state.results = res
        state.lastRun = time()
        notifyUI()
        if state.rerun then
            state.rerun = false
            Engine.Run()
        end
    end, function(err)
        state.running = false
        state.rerun = false
        state.error = "STATE_ERROR"
        notifyUI()
        geterrorhandler()(err)
    end)
end

-- Refresh roster from the server, then run.
function Engine.Refresh()
    local g = ns.DB.Guild()
    if ns.demoActive or not g or not g.import then
        -- nothing to wait for: run directly (shows demo results or the right hint)
        state.awaitingRoster = false
        Engine.Run()
        return
    end
    state.awaitingRoster = true
    ns.Roster.Request()
    -- show results from the cached roster right away; the roster update triggers another run
    local n = GetNumGuildMembers and GetNumGuildMembers() or 0
    if n > 0 then
        Engine.Run()
    end
end

-- Called on GUILD_ROSTER_UPDATE.
local pendingTimer
function Engine.OnRosterUpdate()
    if state.awaitingRoster then
        state.awaitingRoster = false
        Engine.Run()
        return
    end
    -- roster changes while the window is open: re-run, debounced
    if ns.UI and ns.UI.IsShown and ns.UI.IsShown() and not pendingTimer then
        pendingTimer = true
        C_Timer.After(3, function()
            pendingTimer = nil
            if ns.UI.IsShown() then
                Engine.Run()
            end
        end)
    end
end

-- Import Discord data. Returns the parse result.
function Engine.Import(text)
    local parsed = ns.Import.parse(text)
    if parsed.ok then
        local g = ns.DB.Guild()
        if not g then
            parsed.ok = false
            parsed.errors[#parsed.errors + 1] = { line = 0, msg = "STATE_NO_GUILD" }
            return parsed
        end
        g.import = {
            members = parsed.members,
            roles = parsed.roles,
            server = parsed.server,
            timestamp = parsed.timestamp,
            importedAt = time(),
        }
        Engine.Refresh()
    end
    return parsed
end

-- Code with the manual decisions of the current guild for other officers. Returns text, count.
function Engine.ExportDecisions()
    local g = ns.DB.Guild()
    if not g then
        return nil, 0
    end
    return ns.Share.Export(g.decisions, ns.DB.GuildName() or "", date("!%Y-%m-%dT%H:%M:%SZ"), g.dungeonRoles.manual,
        g.professions.manual)
end

-- Merge a parsed decisions code (ns.Share.Parse) into the current guild. Returns the number of changes.
function Engine.ImportDecisions(parsed)
    local g = ns.DB.Guild()
    if not g or not parsed or not parsed.ok then
        return 0
    end
    local n = ns.Share.Merge(g.decisions, parsed, g.dungeonRoles.manual, g.professions.manual)
    Engine.Run()
    return n
end

-- Delete the imported Discord list and all decisions of the current guild (manual dungeon roles
-- only with `withRoles`).
function Engine.DeleteImportedData(withRoles)
    if ns.demoActive then
        return false
    end
    if not ns.DB.DeleteImportedData(withRoles) then
        return false
    end
    Engine.Run()
    return true
end

-- Delete the Discord data of all guilds on this account. Returns the number of guilds.
function Engine.DeleteAllImportedData(withRoles)
    local n = ns.DB.DeleteAllImportedData(withRoles)
    if ns.DB.Guild() then
        Engine.Run()
    elseif ns.UI and ns.UI.OnStateChanged then
        ns.UI.OnStateChanged()
    end
    return n
end

-- Officer decisions --------------------------------------------------------

local function decisions()
    local g = ns.DB.Guild()
    return g and g.decisions
end

-- A Discord account can own several characters: every character has its own fixed assignment
-- (links) and every Discord member / character pair can be separated (rejected).

-- Fix characters to a Discord member ("confirm"). `chars` is a full name or a list of full names.
function Engine.Confirm(memberKey, chars)
    local d = decisions()
    if not d then
        return
    end
    for _, charFullName in ipairs(type(chars) == "table" and chars or { chars }) do
        d.links[charFullName] = memberKey
        d.rejected[ns.Matcher.pairKey(memberKey, charFullName)] = nil
    end
    Engine.Run()
end

-- Remove fixed assignments to this member (back to automatic assignment, nothing is separated).
function Engine.Unconfirm(memberKey, chars)
    local d = decisions()
    if not d then
        return
    end
    for _, charFullName in ipairs(type(chars) == "table" and chars or { chars }) do
        if d.links[charFullName] == memberKey then
            d.links[charFullName] = nil
        end
    end
    Engine.Run()
end

-- Separate a character (with its group) from a Discord member: it is no longer assigned to it
-- automatically. Undo with Engine.ResetMember.
function Engine.Unlink(memberKey, charFullName)
    local d = decisions()
    if not d then
        return
    end
    d.rejected[ns.Matcher.pairKey(memberKey, charFullName)] = true
    if d.links[charFullName] == memberKey then
        d.links[charFullName] = nil
    end
    Engine.Run()
end
Engine.Reject = Engine.Unlink

-- True if one of the characters is fixed to this member.
function Engine.IsConfirmed(memberKey, chars)
    local d = decisions()
    if not d then
        return false
    end
    for _, charFullName in ipairs(type(chars) == "table" and chars or { chars }) do
        if d.links[charFullName] == memberKey then
            return true
        end
    end
    return false
end

-- Remove all manual decisions for a Discord member (fixed assignments and separations).
function Engine.ResetMember(memberKey)
    local d = decisions()
    if not d then
        return
    end
    for charFullName, key in pairs(d.links) do
        if key == memberKey then
            d.links[charFullName] = nil
        end
    end
    local prefix = memberKey .. "\001"
    for k in pairs(d.rejected) do
        if k:sub(1, #prefix) == prefix then
            d.rejected[k] = nil
        end
    end
    Engine.Run()
end

-- Find a Discord member of the last run by display name (exact, then unique beginning).
function Engine.FindMember(name)
    local res = state.results
    local key = ns.Text.key(name or "")
    if key == "" or not res then
        return nil
    end
    local found
    for _, m in ipairs(res.members or {}) do
        local k = ns.Text.key(m.display)
        if k == key then
            return m
        end
        if k:sub(1, #key) == key then
            if found then
                found = false -- ambiguous
            elseif found == nil then
                found = m
            end
        end
    end
    return found or nil
end

function Engine.SetIgnoredMember(memberKey, ignored)
    local d = decisions()
    if d then
        d.ignoredDiscord[memberKey] = ignored or nil
        Engine.Run()
    end
end

function Engine.SetIgnoredChar(charFullName, ignored)
    local d = decisions()
    if d then
        d.ignoredChars[charFullName] = ignored or nil
        Engine.Run()
    end
end

-- Alts -----------------------------------------------------------------------

-- Find a character of the last run by full name.
function Engine.FindChar(fullName)
    local res = state.results
    for _, row in ipairs(res and res.rows or {}) do
        for _, c in ipairs(ns.Advice.rowChars(row)) do
            if c.fullName == fullName then
                return c
            end
        end
    end
    return nil
end

-- Make `charFullName` an alt of the player that `mainFullName` belongs to.
-- Returns false, errorKey if that would put a player under itself.
function Engine.SetAltOf(charFullName, mainFullName)
    local d = decisions()
    if not d then
        return false
    end
    local c, target = Engine.FindChar(charFullName), Engine.FindChar(mainFullName)
    if not c or not target then
        return false, "ALT_ERR_NOT_FOUND"
    end
    -- always point to the main of the target's player
    local main = (target.player and target.player.main) or target
    if main == c then
        return false, "ALT_ERR_SELF"
    end
    d.twinkOf[charFullName] = main.fullName
    d.markedMain[charFullName] = nil
    -- it now follows its main (and the main's Discord account)
    d.links[charFullName] = nil
    Engine.Run()
    return true
end

-- Mark a character as main: removes a manual alt assignment and overrides alt detection.
function Engine.MarkMain(charFullName)
    local d = decisions()
    if not d then
        return
    end
    d.twinkOf[charFullName] = nil
    d.markedMain[charFullName] = true
    Engine.Run()
end

-- Remove manual alt/main decisions of a character (back to automatic detection).
function Engine.ResetAltDecision(charFullName)
    local d = decisions()
    if not d then
        return
    end
    d.twinkOf[charFullName] = nil
    d.markedMain[charFullName] = nil
    Engine.Run()
end

function Engine.HasAltDecision(charFullName)
    local d = decisions()
    return d and (d.twinkOf[charFullName] or d.markedMain[charFullName]) and true or false
end

function Engine.HasDecision(memberKey)
    local d = decisions()
    if not d then
        return false
    end
    for _, key in pairs(d.links) do
        if key == memberKey then
            return true
        end
    end
    local prefix = memberKey .. "\001"
    for k in pairs(d.rejected) do
        if k:sub(1, #prefix) == prefix then
            return true
        end
    end
    return false
end

-- Dungeon roles ------------------------------------------------------------------

-- Manual dungeon roles of a character: a list (may be empty = explicitly none), or nil = automatic.
function Engine.GetManualDungeonRoles(charFullName)
    local g = ns.DB.Guild()
    return g and g.dungeonRoles.manual[charFullName]
end

-- Set manual dungeon roles (list, at most DungeonRoles.MAX, only roles the class allows),
-- or nil to go back to the automatic detection.
function Engine.SetDungeonRoles(charFullName, roles)
    local g = ns.DB.Guild()
    if not g then
        return
    end
    g.dungeonRoles.manual[charFullName] = roles and ns.DungeonRoles.Sort(roles) or nil
    Engine.Run()
end

-- Manual professions of a character: a list (may be empty = explicitly none), or nil = from the notes.
function Engine.GetManualProfessions(charFullName)
    local g = ns.DB.Guild()
    return g and g.professions.manual[charFullName]
end

-- Set manual professions (list) or nil to read them from the notes again.
function Engine.SetProfessions(charFullName, list)
    local g = ns.DB.Guild()
    if not g then
        return
    end
    g.professions.manual[charFullName] = list and ns.Professions.Sort(list) or nil
    Engine.Run()
end

-- Demo mode -------------------------------------------------------------------

function Engine.SetDemo(on)
    ns.demoActive = on and true or false
    if on then
        -- start every demo session from scratch (settings, decisions and notes)
        ns.DB.ResetDemo()
        if ns.Demo.ORIGINAL then
            ns.Demo.ROSTER = ns.Util.copy(ns.Demo.ORIGINAL)
        else
            ns.Demo.ORIGINAL = ns.Util.copy(ns.Demo.ROSTER)
        end
    end
    state.results = nil
    Engine.Run()
end
