local _, Addon = ...

local Gather = {}
Addon.Gather = Gather

local function finiteNumber(value)
    return type(value) == "number" and value == value and value < math.huge and value > -math.huge
end

local function readNumber(frame, method)
    if not frame or type(frame[method]) ~= "function" then return nil end
    local ok, value = pcall(frame[method], frame)
    if not ok or not finiteNumber(value) then return nil end
    return value
end

local function isTrue(frame, method)
    if type(frame[method]) ~= "function" then return false end
    local ok, value = pcall(frame[method], frame)
    return not ok or value == true
end

local function isExplicitlyExcluded(frame, name)
    if type(name) ~= "string" then return true end
    if frame == UIParent or name == "UIParent" or name == "WorldFrame" then return true end
    local lowerName = name:lower()
    if lowerName:find("tooltip", 1, true) or lowerName:find("canvas", 1, true) then return true end
    return false
end

local function isTitleReachable(frame, layout, parentScale)
    local frameScale = readNumber(frame, "GetEffectiveScale")
    if not frameScale or frameScale <= 0 then return false end
    local scaleRatio = frameScale / parentScale
    local left = readNumber(frame, "GetLeft")
    local top = readNumber(frame, "GetTop")
    local width = readNumber(frame, "GetWidth")
    if not left or not top or not width or width <= 0 then return false end

    left = left * scaleRatio
    top = top * scaleRatio
    width = width * scaleRatio
    local right = left + width
    local titleMargin = 16 / parentScale
    local requiredOverlapPixels = math.min(48, width * parentScale)
    local areas = { layout.mainMonitor, layout.secondMonitor1 }

    for _, area in ipairs(areas) do
        if type(area) == "table"
            and finiteNumber(area.left) and finiteNumber(area.right)
            and finiteNumber(area.bottom) and finiteNumber(area.top)
            and area.right > area.left and area.top > area.bottom
            and top >= area.bottom + titleMargin and top <= area.top - titleMargin then
            local overlap = math.max(0, math.min(right, area.right) - math.max(left, area.left))
            if overlap * parentScale >= requiredOverlapPixels then return true end
        end
    end
    return false
end

function Gather:Run()
    if InCombatLockdown and InCombatLockdown() then return false, 0 end
    if not Addon.PanelRegistry or not Addon.PanelRegistry.GetKnownNames
        or not Addon.Geometry or not Addon.Panels or not Addon.Panels.Place then
        return nil, "panel recovery services are unavailable"
    end

    local layout, layoutError = Addon.Geometry:Calculate(Addon:GetProfile())
    if not layout or type(layout.mainMonitor) ~= "table" or type(layout.secondMonitor1) ~= "table" then
        return nil, layoutError or "MainMonitor/SecondMonitor1 geometry is unavailable"
    end
    local parentScale = readNumber(UIParent, "GetEffectiveScale")
    if not parentScale or parentScale <= 0 then return nil, "UIParent effective scale is unavailable" end

    local mainMonitorLayout = {}
    for key, value in pairs(layout) do mainMonitorLayout[key] = value end
    mainMonitorLayout.secondMonitor1 = layout.mainMonitor

    local moved, skipped, seen = 0, 0, {}
    for _, name in ipairs(Addon.PanelRegistry:GetKnownNames()) do
        local frame = _G[name]
        if frame and not seen[frame] then
            seen[frame] = true
            local classified, classification = pcall(Addon.PanelRegistry.Classify, Addon.PanelRegistry, frame)
            local frameName = classified and type(classification) == "table"
                and (classification.name or name) or name
            if classified and classification and classification.route == true
                and not isExplicitlyExcluded(frame, frameName)
                and not isTrue(frame, "IsForbidden")
                and not isTrue(frame, "IsProtected")
                and type(frame.IsShown) == "function" then
                local shownOk, shown = pcall(frame.IsShown, frame)
                if shownOk and shown and not isTitleReachable(frame, layout, parentScale) then
                    local placeOk, placed = pcall(Addon.Panels.Place, Addon.Panels, frame, mainMonitorLayout)
                    if placeOk and placed then
                        moved = moved + 1
                    else
                        skipped = skipped + 1
                        if not placeOk then
                            Addon:ReportError("Panel gather failed for " .. name, placed)
                        end
                    end
                end
            end
        end
    end
    return moved, skipped
end
