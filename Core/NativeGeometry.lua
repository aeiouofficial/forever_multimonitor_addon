local _, Addon = ...
-- Windows geometry is advisory: no Win32 or arbitrary-code execution occurs in Lua.
Addon.nativeGeometry = nil
Addon.nativeGeometryStatus = "manual"

local function integer(value, lower, upper)
    return type(value) == "number" and value == math.floor(value)
        and value >= lower and value <= upper
end

local function validString(value, limit)
    return type(value) == "string" and #value > 0 and #value <= limit
        and not value:find("[%c]")
end

function Addon:LoadNativeGeometry()
    self.nativeGeometry = nil
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

    local bounds = input.bounds
    if type(bounds) ~= "table"
        or not integer(bounds.left, -200000, 200000)
        or not integer(bounds.top, -200000, 200000)
        or not integer(bounds.right, -200000, 200000)
        or not integer(bounds.bottom, -200000, 200000)
        or bounds.right <= bounds.left or bounds.bottom <= bounds.top
    then return reject("invalid combined display bounds") end

    if type(input.displays) ~= "table" or #input.displays < 2 or #input.displays > 8 then
        return reject("expected two to eight selected displays")
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

    if input.mainhandDeviceId ~= nil and
        (not validString(input.mainhandDeviceId, 512) or not seen[input.mainhandDeviceId:lower()]) then
        return reject("mainhand display not found in selection")
    end

    self.nativeGeometry = {
        schemaVersion = 1, processId = input.processId, generatedAtUtc = input.generatedAtUtc,
        bounds = { left = bounds.left, top = bounds.top, right = bounds.right, bottom = bounds.bottom },
        displays = displays, displayCount = #displays, mainhandDeviceId = input.mainhandDeviceId,
    }
    self.nativeGeometryStatus = "loaded"
    return true
end

-- Safe calibration is supported only for two edge-adjacent, vertically aligned
-- displays. Other topologies require the normal manual controls.
function Addon:UseNativeGeometry()
    if not self.nativeGeometry then return false, "No validated native geometry; use manual settings." end
    local geometry = self.nativeGeometry
    if geometry.displayCount ~= 2 then return false, "Automatic calibration requires exactly two displays." end
    local a, b = geometry.displays[1], geometry.displays[2]
    if a.top ~= b.top or a.bottom ~= b.bottom then
        return false, "Displays must share the same vertical edges; use manual calibration."
    end
    local left, right
    if a.right == b.left then left, right = a, b
    elseif b.right == a.left then left, right = b, a
    else return false, "Displays are not horizontally adjacent; use manual calibration." end

    local selected = nil
    for _, item in ipairs(geometry.displays) do
        if item.deviceId == geometry.mainhandDeviceId then selected = item end
    end
    if not selected then
        selected = a.primary and a or (b.primary and b or left)
    end
    local width = geometry.bounds.right - geometry.bounds.left
    local percent = (selected.right - selected.left) * 100 / width
    -- Profile limits preclude highly asymmetric ratios; refuse instead of clamping silently.
    if percent < 25 or percent > 90 then
        return false, "Display width ratio is outside the supported 25-90% range."
    end
    self:SetProfileValue("mainhandSide", selected == left and "left" or "right")
    self:SetProfileValue("mainhandWidthPercent", percent)
    if self.db and self.db.enabled and self.Apply then self:Apply() end
    return true, string.format("Calibrated Mainhand %s (%.1f%%) from native display bounds.",
        selected == left and "left" or "right", percent)
end
