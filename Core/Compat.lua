local _, Addon = ...

local Compat = {}
Addon.Compat = Compat

function Compat:Inspect()
    local version, build, buildDate, interface = GetBuildInfo()
    local projectID = WOW_PROJECT_ID
    local foreverProjectID = WOW_PROJECT_CAMELOT

    return {
        version = tostring(version or "unknown"),
        build = tostring(build or "unknown"),
        buildDate = tostring(buildDate or "unknown"),
        interface = tonumber(interface) or 0,
        projectID = projectID,
        foreverProjectID = foreverProjectID,
        isForever = foreverProjectID ~= nil and projectID == foreverProjectID,
        hasWorldFrame = WorldFrame ~= nil,
        hasEditMode = C_EditMode ~= nil or EditModeManagerFrame ~= nil,
        hasSettingsAPI = Settings ~= nil and type(Settings.RegisterCanvasLayoutCategory) == "function",
        hasContainerAPI = C_Container ~= nil,
        hasTimerAPI = C_Timer ~= nil and type(C_Timer.After) == "function",
    }
end

function Compat:Initialize()
    Addon.runtime = self:Inspect()
    local runtime = Addon.runtime

    Addon:Print(string.format(
        "Client %s build %s | interface %d | project %s",
        runtime.version,
        runtime.build,
        runtime.interface,
        tostring(runtime.projectID)
    ))

    if runtime.interface ~= 16001 then
        Addon:Print("WARNING: this build targets interface 16001; current interface differs.")
    end
    if runtime.foreverProjectID and not runtime.isForever then
        Addon:Print("WARNING: current client project is not Camelot / Forever.")
    end
    if not runtime.hasWorldFrame then
        Addon:Print("WARNING: WorldFrame is unavailable; viewport control cannot run.")
    end

    return runtime
end
