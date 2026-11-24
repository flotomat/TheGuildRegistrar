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

    local settings = ns.Util.copy(g.settings)
    if not state.canViewOfficer then
        settings.useOfficerNote = false
    end

    runAsync(function()
        local players = ns.Players.build(roster, settings)
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

-- Officer decisions --------------------------------------------------------

local function decisions()
    local g = ns.DB.Guild()
    return g and g.decisions
end

function Engine.Confirm(memberKey, charFullName)
    local d = decisions()
    if not d then
        return
    end
    d.confirmed[memberKey] = charFullName
    d.rejected[ns.Matcher.pairKey(memberKey, charFullName)] = nil
    Engine.Run()
end

function Engine.Reject(memberKey, charFullName)
    local d = decisions()
    if not d then
        return
    end
    d.rejected[ns.Matcher.pairKey(memberKey, charFullName)] = true
    if d.confirmed[memberKey] == charFullName then
        d.confirmed[memberKey] = nil
    end
    Engine.Run()
end

-- Remove all manual decisions for a Discord member.
function Engine.ResetMember(memberKey)
    local d = decisions()
    if not d then
        return
    end
    d.confirmed[memberKey] = nil
    local prefix = memberKey .. "\001"
    for k in pairs(d.rejected) do
        if k:sub(1, #prefix) == prefix then
            d.rejected[k] = nil
        end
    end
    Engine.Run()
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

function Engine.HasDecision(memberKey)
    local d = decisions()
    if not d then
        return false
    end
    if d.confirmed[memberKey] then
        return true
    end
    local prefix = memberKey .. "\001"
    for k in pairs(d.rejected) do
        if k:sub(1, #prefix) == prefix then
            return true
        end
    end
    return false
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
