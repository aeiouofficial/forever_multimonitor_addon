local _, Addon = ...

local DEFAULT_PROFILE = {
    mainMonitorSide = "left",
    mainMonitorWidthPercent = 50,
    seamUiUnits = 0,
    panelScale = 1.0,
    rawMouseEnabled = true,
    mapStaysOpenOnEscape = true,
    themePreset = "midnight",
    backgroundOpacity = 0.92,
}

local DEFAULTS = {
    enabled = false,
    activeProfile = "Default",
    profiles = {},
    profile = DEFAULT_PROFILE,
}

local function copyTable(source)
    local result = {}
    for key, value in pairs(source or {}) do
        result[key] = type(value) == "table" and copyTable(value) or value
    end
    return result
end

local function applyDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then target[key] = {} end
            applyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

local function migrateSavedProfileKeys(profile)
    if type(profile) ~= "table" then return end
    if profile.mainMonitorSide == nil then profile.mainMonitorSide = profile.mainhandSide end
    if profile.mainMonitorWidthPercent == nil then profile.mainMonitorWidthPercent = profile.mainhandWidthPercent end
    profile.mainhandSide = nil
    profile.mainhandWidthPercent = nil
end

local function validateProfile(profile)
    if profile.mainMonitorSide ~= "left" and profile.mainMonitorSide ~= "right" then
        profile.mainMonitorSide = DEFAULT_PROFILE.mainMonitorSide
    end
    local width = tonumber(profile.mainMonitorWidthPercent) or DEFAULT_PROFILE.mainMonitorWidthPercent
    profile.mainMonitorWidthPercent = math.max(25, math.min(90, width))
    local seam = tonumber(profile.seamUiUnits) or DEFAULT_PROFILE.seamUiUnits
    profile.seamUiUnits = math.max(0, math.min(100, seam))
    local scale = tonumber(profile.panelScale) or DEFAULT_PROFILE.panelScale
    profile.panelScale = math.max(0.5, math.min(1.5, scale))
    profile.rawMouseEnabled = profile.rawMouseEnabled ~= false
    profile.mapStaysOpenOnEscape = profile.mapStaysOpenOnEscape ~= false
    if profile.themePreset ~= "midnight" and profile.themePreset ~= "indigo" and profile.themePreset ~= "classic" then
        profile.themePreset = DEFAULT_PROFILE.themePreset
    end
    local opacity = tonumber(profile.backgroundOpacity) or DEFAULT_PROFILE.backgroundOpacity
    if opacity ~= opacity or opacity == math.huge or opacity == -math.huge then opacity = DEFAULT_PROFILE.backgroundOpacity end
    profile.backgroundOpacity = math.max(0.5, math.min(1, opacity))
end

local function validProfileName(name)
    if type(name) ~= "string" then return nil end
    name = name:match("^%s*(.-)%s*$")
    if #name < 1 or #name > 24 or not name:match("^[%w _%-]+$") then return nil end
    return name
end

function Addon:InitializeConfig()
    if type(ForeverMultiMonitorDB) ~= "table" then ForeverMultiMonitorDB = {} end
    if type(ForeverMultiMonitorCharDB) ~= "table" then ForeverMultiMonitorCharDB = {} end

    migrateSavedProfileKeys(ForeverMultiMonitorDB.profile)
    migrateSavedProfileKeys(ForeverMultiMonitorDB.lastAppliedLayout)
    if type(ForeverMultiMonitorDB.profiles) == "table" then
        for _, profile in pairs(ForeverMultiMonitorDB.profiles) do
            migrateSavedProfileKeys(profile)
        end
    end
    applyDefaults(ForeverMultiMonitorDB, DEFAULTS)
    validateProfile(ForeverMultiMonitorDB.profile)

    self.db = ForeverMultiMonitorDB
    self.charDB = ForeverMultiMonitorCharDB

    if type(self.db.profiles) ~= "table" then self.db.profiles = {} end
    if type(self.db.profiles.Default) ~= "table" then
        self.db.profiles.Default = copyTable(self.db.profile)
    end
    local activeName = validProfileName(self.db.activeProfile) or "Default"
    if type(self.db.profiles[activeName]) ~= "table" then activeName = "Default" end
    self.db.activeProfile = activeName
    applyDefaults(self.db.profiles[activeName], DEFAULT_PROFILE)
    validateProfile(self.db.profiles[activeName])
    self.db.profile = copyTable(self.db.profiles[activeName])

    local positionSchema = tonumber(self.charDB.panelPositionSchema) or 0
    if positionSchema <= 1 then
        if type(self.charDB.panelPositions) ~= "table" then self.charDB.panelPositions = {} end
        self.charDB.panelPositionSchema = 1
    else
        self:Print("WARNING: panel position data uses a newer schema; saved positions are read-only.")
    end
end

function Addon:GetProfile()
    if not self.db then self:InitializeConfig() end
    return self.db.profile
end

function Addon:GetActiveProfileName()
    if not self.db then self:InitializeConfig() end
    return self.db.activeProfile or "Default"
end

function Addon:GetProfileNames()
    if not self.db then self:InitializeConfig() end
    if type(self.db.profiles) ~= "table" then self.db.profiles = {} end
    local names = {}
    for name in pairs(self.db.profiles) do names[#names + 1] = name end
    table.sort(names, function(a, b) return a:lower() < b:lower() end)
    return names
end

function Addon:CreateProfile(name)
    if not self.db then self:InitializeConfig() end
    name = validProfileName(name)
    if not name then return false, "Profile names must be 1-24 letters, numbers, spaces, underscores or hyphens." end
    if type(self.db.profiles) ~= "table" then self.db.profiles = {} end
    for existing in pairs(self.db.profiles) do
        if existing:lower() == name:lower() then return false, "A profile with that name already exists." end
    end
    self.db.profiles[name] = copyTable(self:GetProfile())
    self:SetActiveProfile(name)
    return true
end

function Addon:SetActiveProfile(name)
    if not self.db then self:InitializeConfig() end
    if type(self.db.profiles) ~= "table" then self.db.profiles = {} end
    name = validProfileName(name)
    if not name or type(self.db.profiles[name]) ~= "table" then return false, "Profile not found." end
    self.db.activeProfile = name
    self.db.profile = copyTable(self.db.profiles[name])
    validateProfile(self.db.profile)
    self.db.profiles[name] = copyTable(self.db.profile)
    if self.db.enabled and self.Apply then self:Apply() end
    if self.MapEscape then self.MapEscape:Sync() end
    return true
end

function Addon:DeleteProfile(name)
    if not self.db then self:InitializeConfig() end
    if type(self.db.profiles) ~= "table" then return false end
    name = validProfileName(name)
    if not name or name == "Default" or name == self:GetActiveProfileName() then return false end
    if not self.db.profiles[name] then return false end
    self.db.profiles[name] = nil
    return true
end

function Addon:SetEnabled(enabled)
    if not self.db then self:InitializeConfig() end
    self.db.enabled = not not enabled
    local applied
    if self.db.enabled then applied = self:Apply() else applied = self:Reset() end
    if enabled and applied == false and self.db.enabled and not (InCombatLockdown and InCombatLockdown()) then
        -- An unsuccessful enable must not persist as active across reload.
        self.db.enabled = false
        self:Reset()
    end
    if self.MapEscape then self.MapEscape:Sync() end
    return applied
end

function Addon:SetProfileValue(key, value)
    local profile = self:GetProfile()
    if profile[key] == nil then return false end
    profile[key] = value
    validateProfile(profile)
    if type(self.db.profiles) ~= "table" then self.db.profiles = {} end
    self.db.profiles[self:GetActiveProfileName()] = copyTable(profile)
    return true
end
