local _, Addon = ...
-- Windows geometry is advisory: no Win32 or arbitrary-code execution occurs in Lua.
Addon.nativeGeometry = nil
Addon.nativeGeometryStatus = "manual"
Addon.activeNativeGeometry = nil

local function integer(value, lower, upper)
    return type(value) == "number" and value == math.floor(value)
        and value >= lower and value <= upper
end

local function validString(value, limit)
    return type(value) == "string" and #value > 0 and #value <= limit
        and not value:find("[%c]")
end

local function matchesPhysicalSize(value, expected)
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge
        and math.abs(value - expected) <= 2
end

function Addon:ValidateNativeGeometryScreenSize(geometry)
    if not geometry or not geometry.bounds then
        return false, "Native display bounds are unavailable."
    end
    if not (self.runtime and self.runtime.isForever and type(GetPhysicalScreenSize) == "function") then
        return true
    end

    local sizeOK, screenWidth, screenHeight = pcall(GetPhysicalScreenSize)
    local bounds = geometry.bounds
    if not sizeOK
        or not matchesPhysicalSize(screenWidth, bounds.right - bounds.left)
        or not matchesPhysicalSize(screenHeight, bounds.bottom - bounds.top) then
        return false, "Native display bounds do not match the current Forever screen size."
    end
    return true
end

function Addon:ValidateActiveNativeGeometry()
    if not self.activeNativeGeometry then return true end
    local current, reason = self:ValidateNativeGeometryScreenSize(self.activeNativeGeometry)
    if not current then
        self.activeNativeGeometry = nil
        self.nativeGeometryStatus = "stale: " .. tostring(reason)
        return false, reason
    end
    return true
end

function Addon:LoadNativeGeometry()
    self.nativeGeometry = nil
    self.activeNativeGeometry = nil
    self.nativeGeometryStatus = "manual"
    local input = ForeverMultiMonitorNativeGeometry
    if input == nil then return false, "No native handoff; manual layout active." end

    local function reject(reason)
        self.nativeGeometryStatus = "invalid: " .. reason
        return false, reason
    end

    if type(input) ~= "table" or input.schemaVersion ~= 1
        or input.source ~= "ForeverMultiMonitor.WindowsHelper"
        or not integer(input.processId, 1, 2147483647)
        or not validString(input.generatedAtUtc, 40)
    then return reject("unsupported native handoff header") end

    local mode = input.mode or "dual-display"
    if mode ~= "dual-display" and mode ~= "single-ultrawide" then
        return reject("unsupported native topology mode")
    end

    local bounds = input.bounds
    if type(bounds) ~= "table"
        or not integer(bounds.left, -200000, 200000)
        or not integer(bounds.top, -200000, 200000)
        or not integer(bounds.right, -200000, 200000)
        or not integer(bounds.bottom, -200000, 200000)
        or bounds.right <= bounds.left or bounds.bottom <= bounds.top
    then return reject("invalid combined display bounds") end

    local expectedDisplayCount = mode == "single-ultrawide" and 1 or 2
    if type(input.displays) ~= "table" or #input.displays ~= expectedDisplayCount then
        return reject(mode == "single-ultrawide"
            and "single-ultrawide mode requires exactly one selected display"
            or "normal spanning requires exactly two selected displays")
    end

    local displays, seen, minimumLeft, minimumTop, maximumRight, maximumBottom = {}, {}, nil, nil, nil, nil
    local primaryCount = 0
    for i = 1, #input.displays do
        local d = input.displays[i]
        if type(d) ~= "table"
            or not validString(d.device, 128) or not validString(d.deviceId, 512)
            or not validString(d.name, 256) or type(d.primary) ~= "boolean"
            or not integer(d.left, -200000, 200000)
            or not integer(d.top, -200000, 200000)
            or not integer(d.right, -200000, 200000)
            or not integer(d.bottom, -200000, 200000)
            or d.right <= d.left or d.bottom <= d.top
            or not integer(d.dpiX, 48, 768) or not integer(d.dpiY, 48, 768)
        then return reject("invalid monitor data at index " .. i) end
        local key = d.deviceId:lower()
        if seen[key] then return reject("duplicate device identity") end
        seen[key] = true
        if d.primary then primaryCount = primaryCount + 1 end
        minimumLeft = math.min(minimumLeft or d.left, d.left)
        minimumTop = math.min(minimumTop or d.top, d.top)
        maximumRight = math.max(maximumRight or d.right, d.right)
        maximumBottom = math.max(maximumBottom or d.bottom, d.bottom)
        displays[i] = {
            device = d.device, deviceId = d.deviceId, name = d.name, primary = d.primary,
            left = d.left, top = d.top, right = d.right, bottom = d.bottom,
            dpiX = d.dpiX, dpiY = d.dpiY,
        }
    end
    if primaryCount > 1 or minimumLeft ~= bounds.left or minimumTop ~= bounds.top
        or maximumRight ~= bounds.right or maximumBottom ~= bounds.bottom then
        return reject("display union mismatch")
    end

    if #displays == 2 then
        local first, second = displays[1], displays[2]
        local overlapWidth = math.min(first.right, second.right) - math.max(first.left, second.left)
        local overlapHeight = math.min(first.bottom, second.bottom) - math.max(first.top, second.top)
        if overlapWidth > 0 and overlapHeight > 0 then
            return reject("selected display rectangles overlap")
        end
    end

    local mainMonitorDeviceId = input.mainMonitorDeviceId
    if mainMonitorDeviceId == nil then
        -- Read older helper handoffs once; the current format uses the branded field.
        mainMonitorDeviceId = input.mainhandDeviceId
    end
    if mainMonitorDeviceId ~= nil and
        (not validString(mainMonitorDeviceId, 512) or not seen[mainMonitorDeviceId:lower()]) then
        return reject("MainMonitor display not found in selection")
    end

    self.nativeGeometry = {
        schemaVersion = 1, mode = mode, processId = input.processId, generatedAtUtc = input.generatedAtUtc,
        bounds = { left = bounds.left, top = bounds.top, right = bounds.right, bottom = bounds.bottom },
        displays = displays, displayCount = #displays, mainMonitorDeviceId = mainMonitorDeviceId,
    }
    self.nativeGeometryStatus = "loaded"
    return true
end

-- Activation is explicit: merely loading a helper handoff never changes the
-- manual layout. Dual-display rectangles remain exact; the separately marked
-- single-ultrawide mode is split equally when Geometry calculates the layout.
function Addon:UseNativeGeometry()
    if not self.nativeGeometry then return false, "No validated native geometry; use manual settings." end
    local geometry = self.nativeGeometry
    local expectedDisplayCount = geometry.mode == "single-ultrawide" and 1 or 2
    if geometry.displayCount ~= expectedDisplayCount then
        return false, geometry.mode == "single-ultrawide"
            and "Single-ultrawide mode requires exactly one selected display."
            or "Normal spanning requires exactly two selected displays."
    end

    local selected
    if geometry.mode == "single-ultrawide" then selected = geometry.displays[1] end
    if geometry.mainMonitorDeviceId then
        local selectedId = geometry.mainMonitorDeviceId:lower()
        for _, item in ipairs(geometry.displays) do
            if item.deviceId:lower() == selectedId then selected = item; break end
        end
    end
    if not selected then
        for _, item in ipairs(geometry.displays) do
            if item.primary then selected = item; break end
        end
    end
    if not selected then
        return false, "No selected MainMonitor display; choose one in the Windows helper."
    end

    local screenMatches, screenSizeError = self:ValidateNativeGeometryScreenSize(geometry)
    if not screenMatches then return false, screenSizeError end

    local function copyDisplay(item)
        return {
            device = item.device, deviceId = item.deviceId, name = item.name, primary = item.primary,
            left = item.left, top = item.top, right = item.right, bottom = item.bottom,
            dpiX = item.dpiX, dpiY = item.dpiY,
        }
    end
    local previousActive = self.activeNativeGeometry
    local activeGeometry = {
        bounds = {
            left = geometry.bounds.left, top = geometry.bounds.top,
            right = geometry.bounds.right, bottom = geometry.bounds.bottom,
        },
        mode = geometry.mode,
    }
    if geometry.mode == "single-ultrawide" then
        activeGeometry.display = copyDisplay(selected)
    else
        local secondMonitor1 = geometry.displays[1] == selected and geometry.displays[2] or geometry.displays[1]
        activeGeometry.mainMonitor = copyDisplay(selected)
        activeGeometry.secondMonitor1 = copyDisplay(secondMonitor1)
    end
    self.activeNativeGeometry = activeGeometry

    -- Retain the old manual profile calibration when the selected displays
    -- are a directly adjacent, vertically aligned pair and fit its controls.
    local legacySide, legacyPercent
    if geometry.mode == "dual-display" then
        local a, b = geometry.displays[1], geometry.displays[2]
        local left
        if a.right == b.left then left = a
        elseif b.right == a.left then left = b end
        if left and a.top == b.top and a.bottom == b.bottom then
            local width = geometry.bounds.right - geometry.bounds.left
            local percent = (selected.right - selected.left) * 100 / width
            if percent >= 25 and percent <= 90 then
                legacySide = selected == left and "left" or "right"
                legacyPercent = percent
            end
        end
    end

    local applyQueued = false
    if self.db and self.db.enabled and self.Apply then
        local callOK, applied, applyError = pcall(self.Apply, self)
        if not callOK then
            self.activeNativeGeometry = previousActive
            return false, "Could not apply exact native geometry: " .. tostring(applied)
        elseif applied ~= true then
            if (InCombatLockdown and InCombatLockdown()) and self.db.enabled then
                applyQueued = true
            else
                self.activeNativeGeometry = previousActive
                return false, "Could not apply exact native geometry: " .. tostring(applyError or "layout apply failed")
            end
        end
    end

    if legacySide then
        self:SetProfileValue("mainMonitorSide", legacySide)
        self:SetProfileValue("mainMonitorWidthPercent", legacyPercent)
    end
    local message
    if geometry.mode == "single-ultrawide" then
        message = string.format("Activated the explicit equal MainMonitor/SecondMonitor1 split on %s.", selected.name)
    else
        message = string.format("Activated exact MainMonitor %s and SecondMonitor1 rectangles from native display bounds.",
            selected.name)
    end
    self.nativeGeometryStatus = "active"
    if applyQueued then message = message .. " Layout application is queued until combat ends." end
    return true, message
end
