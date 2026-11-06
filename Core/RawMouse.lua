local _, Addon = ...

local RawMouse = {}
Addon.RawMouse = RawMouse

local CVAR_NAME = "rawMouseEnable"

function RawMouse:Enable()
    if not Addon.db or not GetCVar or not SetCVar then return false end
    if Addon.db.rawMouseOwned then
        if Addon.db.rawMousePrevious == nil then
            Addon:ReportError("Raw mouse ownership state is incomplete", "original CVar value is missing; refusing to overwrite it")
            return false
        end
    else
        local previous = GetCVar(CVAR_NAME)
        if previous == nil then return false end
        Addon.db.rawMousePrevious = tostring(previous)
        Addon.db.rawMouseOwned = true
    end

    if tostring(GetCVar(CVAR_NAME)) ~= "1" then
        local ok, err = pcall(SetCVar, CVAR_NAME, "1")
        if not ok then
            Addon:ReportError("Could not enable raw mouse input", err)
            return false
        end
    end
    return true
end

function RawMouse:Restore()
    if not Addon.db or not Addon.db.rawMouseOwned then return true end
    if not SetCVar then return false end
    local previous = Addon.db.rawMousePrevious
    if previous == nil then
        Addon:ReportError("Could not restore raw mouse input", "original CVar value is missing")
        return false
    end

    local ok, err = pcall(SetCVar, CVAR_NAME, tostring(previous))
    if not ok then
        Addon:ReportError("Could not restore raw mouse input", err)
        return false
    end
    Addon.db.rawMousePrevious = nil
    Addon.db.rawMouseOwned = nil
    return true
end

function RawMouse:Sync()
    local profile = Addon:GetProfile()
    if Addon.db.enabled and profile.rawMouseEnabled ~= false then
        return self:Enable()
    end
    return self:Restore()
end