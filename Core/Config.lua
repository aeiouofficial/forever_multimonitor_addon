local _, Addon = ...

local DEFAULTS = {
    enabled = false,
    profile = {
        mainhandSide = "left",
        mainhandWidthPercent = 50,
        seamUiUnits = 0,
        panelScale = 1.0,
    },
}

local function applyDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            applyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

local function validateProfile(profile)
    if profile.mainhandSide ~= "left" and profile.mainhandSide ~= "right" then
        profile.mainhandSide = DEFAULTS.profile.mainhandSide
    end

    local width = tonumber(profile.mainhandWidthPercent) or 50
    profile.mainhandWidthPercent = math.max(25, math.min(90, width))

    local seam = tonumber(profile.seamUiUnits) or 0
    profile.seamUiUnits = math.max(0, math.min(100, seam))

    local scale = tonumber(profile.panelScale) or 1
    profile.panelScale = math.max(0.5, math.min(1.5, scale))
end

function Addon:InitializeConfig()
    if type(ForeverMultiMonitorDB) ~= "table" then
        ForeverMultiMonitorDB = {}
    end
    if type(ForeverMultiMonitorCharDB) ~= "table" then
        ForeverMultiMonitorCharDB = {}
    end

    applyDefaults(ForeverMultiMonitorDB, DEFAULTS)
    validateProfile(ForeverMultiMonitorDB.profile)

    self.db = ForeverMultiMonitorDB
    self.charDB = ForeverMultiMonitorCharDB
end

function Addon:GetProfile()
    if not self.db then
        self:InitializeConfig()
    end
    return self.db.profile
end

function Addon:SetEnabled(enabled)
    self.db.enabled = not not enabled
    if self.db.enabled then
        self:Apply()
    else
        self:Reset()
    end
end

function Addon:SetProfileValue(key, value)
    local profile = self:GetProfile()
    if profile[key] == nil then
        return false
    end
    profile[key] = value
    validateProfile(profile)
    return true
end
