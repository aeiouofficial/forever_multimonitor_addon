local _, Addon = ...

local Geometry = {}
Addon.Geometry = Geometry

local function getCanvasSize()
    local width = UIParent and UIParent.GetWidth and UIParent:GetWidth()
    local height = UIParent and UIParent.GetHeight and UIParent:GetHeight()

    if not width or width <= 0 then
        width = GetScreenWidth and GetScreenWidth() or 0
    end
    if not height or height <= 0 then
        height = GetScreenHeight and GetScreenHeight() or 0
    end

    return width, height
end

local function finiteNumber(value)
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge
end

local function mapPhysicalRect(bounds, display, canvasWidth, canvasHeight)
    if type(display) ~= "table"
        or not finiteNumber(display.left) or not finiteNumber(display.top)
        or not finiteNumber(display.right) or not finiteNumber(display.bottom)
        or display.right <= display.left or display.bottom <= display.top
        or display.left < bounds.left or display.top < bounds.top
        or display.right > bounds.right or display.bottom > bounds.bottom then
        return nil
    end

    local physicalWidth = bounds.right - bounds.left
    local physicalHeight = bounds.bottom - bounds.top
    local scaleX, scaleY = canvasWidth / physicalWidth, canvasHeight / physicalHeight
    local left = display.left == bounds.left and 0 or (display.left - bounds.left) * scaleX
    local right = display.right == bounds.right and canvasWidth or (display.right - bounds.left) * scaleX
    local bottom = display.bottom == bounds.bottom and 0 or (bounds.bottom - display.bottom) * scaleY
    local top = display.top == bounds.top and canvasHeight or (bounds.bottom - display.top) * scaleY
    if not finiteNumber(left) or not finiteNumber(right)
        or not finiteNumber(bottom) or not finiteNumber(top)
        or left < 0 or bottom < 0 or right > canvasWidth or top > canvasHeight
        or right <= left or top <= bottom then
        return nil
    end

    local width, height = right - left, top - bottom
    return {
        left = left, right = right, bottom = bottom, top = top,
        width = width, height = height,
        centerX = (left + right) / 2 - canvasWidth / 2,
        centerY = (bottom + top) / 2 - canvasHeight / 2,
    }
end

function Geometry:Calculate(profile)
    local width, height = getCanvasSize()
    if not finiteNumber(width) or not finiteNumber(height) or width <= 0 or height <= 0 then
        return nil, "UI canvas dimensions are unavailable"
    end

    local native = Addon.activeNativeGeometry
    if native then
        local sizeMatches, sizeError = Addon:ValidateActiveNativeGeometry()
        if not sizeMatches then
            return nil, sizeError or "Active native display topology is stale"
        end
        native = Addon.activeNativeGeometry
        if not native then
            return nil, "Active native display topology is no longer valid; restore the selected displays and reapply it."
        end
        local bounds = native.bounds
        if type(bounds) ~= "table"
            or not finiteNumber(bounds.left) or not finiteNumber(bounds.top)
            or not finiteNumber(bounds.right) or not finiteNumber(bounds.bottom)
            or bounds.right <= bounds.left or bounds.bottom <= bounds.top then
            return nil, "Active native display bounds are invalid"
        end
        local mainMonitorRect, secondMonitor1Rect
        if native.mode == "single-ultrawide" then
            local display = native.display
            if type(display) ~= "table" or not finiteNumber(display.left) or not finiteNumber(display.right)
                or not finiteNumber(display.top) or not finiteNumber(display.bottom)
                or display.right <= display.left or display.bottom <= display.top then
                return nil, "Active single-ultrawide display rectangle is invalid"
            end
            local splitX = (display.left + display.right) / 2
            local leftHalf = {
                left = display.left, right = splitX, top = display.top, bottom = display.bottom,
            }
            local rightHalf = {
                left = splitX, right = display.right, top = display.top, bottom = display.bottom,
            }
            if profile.mainMonitorSide == "right" then
                mainMonitorRect, secondMonitor1Rect = rightHalf, leftHalf
            else
                mainMonitorRect, secondMonitor1Rect = leftHalf, rightHalf
            end
        else
            mainMonitorRect, secondMonitor1Rect = native.mainMonitor, native.secondMonitor1
        end
        local mainMonitor = mapPhysicalRect(bounds, mainMonitorRect, width, height)
        local secondMonitor1 = mapPhysicalRect(bounds, secondMonitor1Rect, width, height)
        if not mainMonitor or not secondMonitor1 then
            return nil, "Active native MainMonitor or SecondMonitor1 rectangle is invalid"
        end
        return {
            canvasWidth = width, canvasHeight = height,
            mainMonitor = mainMonitor,
            secondMonitor1 = secondMonitor1,
            seam = 0,
            nativeGeometry = true,
        }
    end

    local share = math.max(25, math.min(90, tonumber(profile.mainMonitorWidthPercent) or 50)) / 100
    local seam = math.max(0, tonumber(profile.seamUiUnits) or 0)
    if seam >= width * 0.25 then
        return nil, "Seam offset exceeds 25% of the canvas"
    end

    local mainMonitorWidth = (width - seam) * share
    local secondMonitor1Width = width - seam - mainMonitorWidth

    if secondMonitor1Width < 1 then
        return nil, "SecondMonitor1 is too narrow"
    end

    local mainMonitorLeft
    local secondMonitor1Left
    if profile.mainMonitorSide == "right" then
        secondMonitor1Left = 0
        mainMonitorLeft = secondMonitor1Width + seam
    else
        mainMonitorLeft = 0
        secondMonitor1Left = mainMonitorWidth + seam
    end

    return {
        canvasWidth = width,
        canvasHeight = height,
        mainMonitor = {
            left = mainMonitorLeft,
            right = mainMonitorLeft + mainMonitorWidth,
            bottom = 0,
            top = height,
            width = mainMonitorWidth,
            height = height,
            centerX = mainMonitorLeft + mainMonitorWidth / 2 - width / 2,
            centerY = 0,
        },
        secondMonitor1 = {
            left = secondMonitor1Left,
            right = secondMonitor1Left + secondMonitor1Width,
            bottom = 0,
            top = height,
            width = secondMonitor1Width,
            height = height,
            centerX = secondMonitor1Left + secondMonitor1Width / 2 - width / 2,
            centerY = 0,
        },
        seam = seam,
    }
end
