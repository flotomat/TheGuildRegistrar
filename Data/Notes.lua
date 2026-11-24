-- The Guild Registrar - write guild notes (only ever on explicit request + confirmation)

local _, ns = ...

local Notes = {}
ns.Notes = Notes

Notes.MAX_BYTES = 31

local function call(tbl, fname, ...)
    if tbl and tbl[fname] then
        return true, tbl[fname](...)
    end
    return false
end

function Notes.CanEdit(kind)
    if ns.demoActive then
        return true
    end
    local found, result
    if kind == "officer" then
        found, result = call(C_GuildInfo, "CanEditOfficerNote")
        if not found then
            found, result = call(_G, "CanEditOfficerNote")
        end
    else
        found, result = call(C_GuildInfo, "CanEditPublicNote")
        if not found then
            found, result = call(_G, "CanEditPublicNote")
        end
    end
    if not found then
        return true -- unknown API: let the server decide
    end
    return result and true or false
end

-- Combine the current note with the new text.
function Notes.Compose(current, addition, mode)
    current = ns.Util.trim(current)
    addition = ns.Util.trim(addition)
    local text
    if mode == "replace" or current == "" then
        text = addition
    elseif current:lower():find(addition:lower(), 1, true) then
        text = current
    else
        text = current .. " " .. addition
    end
    return text
end

function Notes.Fits(text)
    return #text <= Notes.MAX_BYTES
end

-- Write a note. kind = "public" | "officer". Returns ok, errorKey.
function Notes.Write(char, kind, text)
    text = ns.Util.utf8truncate(text, Notes.MAX_BYTES)
    if not Notes.CanEdit(kind) then
        return false, "NOTE_ERR_PERMISSION"
    end
    if ns.demoActive then
        local entry = ns.Demo.ROSTER[char.index]
        if entry then
            if kind == "officer" then
                entry.officerNote = text
            else
                entry.note = text
            end
            return true
        end
        return false, "NOTE_ERR_NOT_FOUND"
    end
    if C_GuildInfo and C_GuildInfo.SetNote and char.guid then
        C_GuildInfo.SetNote(char.guid, text, kind ~= "officer")
        return true
    end
    local index = ns.Roster.FindIndex(char.fullName)
    if not index then
        return false, "NOTE_ERR_NOT_FOUND"
    end
    if kind == "officer" and GuildRosterSetOfficerNote then
        GuildRosterSetOfficerNote(index, text)
        return true
    elseif kind ~= "officer" and GuildRosterSetPublicNote then
        GuildRosterSetPublicNote(index, text)
        return true
    end
    return false, "NOTE_ERR_API"
end
