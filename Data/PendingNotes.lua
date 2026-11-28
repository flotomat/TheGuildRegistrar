-- The Guild Registrar - prepared ("pending") guild notes
--
-- WoW: Forever does not let addons write guild notes. The officer prepares the final text here
-- (by hand or from the note templates) and copies it into Blizzard's note field; the addon only
-- reads Blizzard's frames (see UI/GuildCompanion.lua). As soon as the roster shows the prepared text,
-- the entry is ticked off automatically.
--
-- Storage: g.pendingNotes[charFullName] = { public = "text", officer = "text" } (full final texts).
-- They may contain Discord names and are deleted together with the Discord data.

local _, ns = ...

local Pending = {}
ns.PendingNotes = Pending

Pending.KINDS = { "public", "officer" }

local function guild()
    local g = ns.DB.Guild()
    if g then
        g.pendingNotes = g.pendingNotes or {}
    end
    return g
end

local function trim(s)
    return ns.Util.trim(s or "")
end

-- Pending text of a character for a note kind (or nil).
function Pending.Get(fullName, kind)
    local g = guild()
    local e = g and g.pendingNotes[fullName]
    return e and e[kind] or nil
end

function Pending.Has(fullName)
    local g = guild()
    return g and g.pendingNotes[fullName] ~= nil or false
end

-- Number of pending notes (each public/officer note counts once).
function Pending.Count()
    local g = guild()
    return g and ns.Protect.PendingNotes(g) or 0
end

-- All pending notes: { { fullName, kind, text } }, sorted by name.
function Pending.List()
    local g = guild()
    local list = {}
    for fullName, e in pairs(g and g.pendingNotes or {}) do
        for _, kind in ipairs(Pending.KINDS) do
            if e[kind] then
                list[#list + 1] = { fullName = fullName, kind = kind, text = e[kind] }
            end
        end
    end
    table.sort(list, function(a, b)
        if a.fullName == b.fullName then
            return a.kind < b.kind
        end
        return a.fullName < b.fullName
    end)
    return list
end

local function changed()
    if ns.UI and ns.UI.OnStateChanged then
        ns.UI.OnStateChanged()
    end
    if ns.Companion and ns.Companion.Update then
        ns.Companion.Update()
    end
end

-- Set (text) or remove (nil / empty) a pending note. Texts equal to the current note are not kept.
function Pending.Set(fullName, kind, text, currentNote, silent)
    local g = guild()
    if not g then
        return
    end
    text = trim(text)
    local e = g.pendingNotes[fullName] or {}
    if text == "" or (currentNote ~= nil and text == trim(currentNote)) then
        e[kind] = nil
    else
        e[kind] = text
    end
    g.pendingNotes[fullName] = (e.public or e.officer) and e or nil
    if not silent then
        changed()
    end
end

function Pending.Clear(fullName)
    local g = guild()
    if g then
        g.pendingNotes[fullName] = nil
        changed()
    end
end

-- Note kinds the automatic preparation creates: the notes whose template is switched on (the
-- officer note only if this rank may read it).
function Pending.AutoKinds(settings)
    local kinds = {}
    if settings.noteCheckPublic then
        kinds[#kinds + 1] = "public"
    end
    if settings.noteCheckOfficer and ns.state.canViewOfficer ~= false then
        kinds[#kinds + 1] = "officer"
    end
    return kinds
end

local function currentNote(c, kind)
    return (kind == "officer") and c.officerNote or c.note
end

-- Texts the templates suggest for a character: { [kind] = text } for every kind whose suggestion
-- differs from the current note. `onlyIfUnfit`: only where the note does not fit the template.
function Pending.Suggestions(row, c, settings, onlyIfUnfit)
    local out = {}
    for _, kind in ipairs(Pending.AutoKinds(settings)) do
        local template = ns.Advice.template(row, c, settings, kind)
        if template then
            local values, lists = ns.Advice.templateValues(row, c, settings)
            local text = ns.Advice.render(template, values)
            if text ~= "" and text ~= trim(currentNote(c, kind)) then
                if not onlyIfUnfit or not ns.Advice.noteFits(c, kind, template, values, lists, row.member) then
                    out[kind] = text
                end
            end
        end
    end
    return out
end

-- Prepare the template texts for one character. Returns the number of prepared notes.
function Pending.Auto(row, c, settings)
    local n = 0
    for kind, text in pairs(Pending.Suggestions(row, c, settings, false)) do
        Pending.Set(c.fullName, kind, text, currentNote(c, kind), true)
        n = n + 1
    end
    changed()
    return n
end

-- Pending notes an automatic preparation of `c` would replace (manual work), as counts for Protect.
function Pending.AutoWouldReplace(row, c, settings)
    local n = 0
    for kind, text in pairs(Pending.Suggestions(row, c, settings, false)) do
        local old = Pending.Get(c.fullName, kind)
        if old and old ~= text then
            n = n + 1
        end
    end
    return n
end

-- Mass preparation: every character of rows with at least `minStatus` whose note does not fit the
-- template. Existing pending notes are kept. Returns the number of prepared notes (or would-be
-- prepared notes with `dryRun`).
function Pending.Mass(rows, settings, minStatus, dryRun)
    local level = ns.Matcher.STATUS_LEVEL
    local min = level[minStatus or "sure"] or 3
    local n = 0
    for _, row in ipairs(rows or {}) do
        if row.member and (level[row.status] or 0) >= min then
            for _, c in ipairs(ns.Advice.rowChars(row)) do
                for kind, text in pairs(Pending.Suggestions(row, c, settings, true)) do
                    if not Pending.Get(c.fullName, kind) then
                        n = n + 1
                        if not dryRun then
                            Pending.Set(c.fullName, kind, text, currentNote(c, kind), true)
                        end
                    end
                end
            end
        end
    end
    if not dryRun then
        changed()
    end
    return n
end

-- Compare the pending notes with the roster: notes that now show the prepared text are ticked
-- off. Returns a list of { name, kind } that were ticked off.
function Pending.CheckRoster(roster)
    local g = guild()
    if not g or not next(g.pendingNotes) or not roster then
        return {}
    end
    local byName = {}
    for _, c in ipairs(roster) do
        byName[c.fullName] = c
    end
    local done = {}
    for fullName, e in pairs(g.pendingNotes) do
        local c = byName[fullName]
        if c then
            for _, kind in ipairs(Pending.KINDS) do
                if e[kind] and trim(currentNote(c, kind)) == e[kind] then
                    e[kind] = nil
                    done[#done + 1] = { name = c.name, kind = kind }
                end
            end
            if not (e.public or e.officer) then
                g.pendingNotes[fullName] = nil
            end
        end
    end
    if #done > 0 then
        changed()
    end
    return done
end

-- Called on GUILD_ROSTER_UPDATE: tick off and tell the officer (sound + message, no window).
function Pending.OnRosterUpdate()
    local g = guild()
    if not g or not next(g.pendingNotes) then
        return
    end
    local done = Pending.CheckRoster(ns.Roster.Read())
    if #done == 0 then
        return
    end
    local L = ns.L
    if g.settings.notesTickFeedback ~= false then
        for _, d in ipairs(done) do
            local msg = string.format(L.PENDING_DONE, d.name,
                (d.kind == "officer") and L.NOTE_OFFICER or L.NOTE_PUBLIC)
            if UIErrorsFrame and UIErrorsFrame.AddMessage then
                UIErrorsFrame:AddMessage(msg, 0.3, 1, 0.3)
            end
        end
        if PlaySound then
            pcall(PlaySound, (SOUNDKIT and SOUNDKIT.IG_QUEST_LIST_COMPLETE) or 872)
        end
    end
end
