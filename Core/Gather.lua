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

local function isMovable(frame)
    if type(frame.IsMovable) ~= "function" then return false end
    local ok, value = pcall(frame.IsMovable, frame)
    return ok and value == true
end

local function frameName(frame, fallback)
    if frame and type(frame.GetName) == "function" then
        local ok, name = pcall(frame.GetName, frame)
        if ok and type(name) == "string" and name ~= "" then return name end
    end
    return fallback
end

local function isExplicitlyExcluded(frame, name)
    if frame == UIParent or name == "UIParent" or name == "WorldFrame" then return true end
    local lowerName = type(name) == "string" and name:lower() or ""
    if lowerName:find("tooltip", 1, true) or lowerName:find("canvas", 1, true) then return true end
    if type(frame.IsObjectType) == "function" then
        local ok, isTooltip = pcall(frame.IsObjectType, frame, "GameTooltip")
        if ok and isTooltip then return true end
    end
    return false
end

local function isTitleReachable(frame, layout, parentScale)
    local frameScale = readNumber(frame, "GetEffectiveScale")
    if not frameScale or frameScale <= 0 then return nil end
    local scaleRatio = frameScale / parentScale
    local left = readNumber(frame, "GetLeft")
    local top = readNumber(frame, "GetTop")
    local width = readNumber(frame, "GetWidth")
    if not left or not top or not width or width <= 0 then return nil end

    left = left * scaleRatio
    top = top * scaleRatio
    width = width * scaleRatio
    local right = left + width
    if not finiteNumber(left) or not finiteNumber(top) or not finiteNumber(right) then return nil end
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

local function collectCandidates()
    local candidates = {}
    local function add(frame, name, allowUnregistered)
        if not frame then return end
        local candidate = candidates[frame]
        if not candidate then
            candidate = { name = name, allowUnregistered = false }
            candidates[frame] = candidate
        elseif not candidate.name and name then
            candidate.name = name
        end
        if allowUnregistered then candidate.allowUnregistered = true end
    end

    for _, name in ipairs(Addon.PanelRegistry:GetKnownNames()) do
        add(_G[name], name, false)
    end
    for name in pairs(type(UIPanelWindows) == "table" and UIPanelWindows or {}) do
        if type(name) == "string" then add(_G[name], name, true) end
    end
    if UIParent and type(UIParent.GetChildren) == "function" then
        local childrenOK, children = pcall(function() return { UIParent:GetChildren() } end)
        if childrenOK then
            for _, child in ipairs(children) do
                if isMovable(child) then add(child, frameName(child), true) end
            end
        end
    end
    return candidates
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

    local moved, skipped = 0, 0
    for frame, candidate in pairs(collectCandidates()) do
        local classified, classification = false, nil
        if type(Addon.PanelRegistry.Classify) == "function" then
            classified, classification = pcall(Addon.PanelRegistry.Classify, Addon.PanelRegistry, frame)
        end
        local registered = classified and type(classification) == "table" and classification.route == true
        local explicitlyDenied = classified and type(classification) == "table" and classification.route == false
        local name = (type(classification) == "table" and classification.name)
            or candidate.name or frameName(frame)
        if not explicitlyDenied and (registered or candidate.allowUnregistered)
            and not isExplicitlyExcluded(frame, name)
            and not isTrue(frame, "IsForbidden")
            and not isTrue(frame, "IsProtected")
            and type(frame.IsShown) == "function" then
            local shownOK, shown = pcall(frame.IsShown, frame)
            local reachable = shownOK and shown and isTitleReachable(frame, layout, parentScale)
            if shownOK and shown and reachable == false then
                local placeOK, placed = pcall(Addon.Panels.Place, Addon.Panels, frame, mainMonitorLayout)
                if placeOK and placed then
                    moved = moved + 1
                else
                    skipped = skipped + 1
                    if not placeOK then
                        Addon:ReportError("Panel gather failed for " .. tostring(name or "unnamed frame"), placed)
                    end
                end
            end
        end
    end
    return moved, skipped
end
