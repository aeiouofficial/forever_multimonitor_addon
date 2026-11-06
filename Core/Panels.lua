local _, Addon = ...

local Panels = {}
Addon.Panels = Panels
Panels.originalPoints = setmetatable({}, { __mode = "k" })
Panels.originalScales = setmetatable({}, { __mode = "k" })
Panels.hooked = setmetatable({}, { __mode = "k" })
Panels.assignments = setmetatable({}, { __mode = "k" })
Panels.excluded = setmetatable({}, { __mode = "k" })
Panels.discoveryHooksInstalled = false
Panels.discoveryCount = 0

local function capture(frame)
    local points = {}
    local count = frame.GetNumPoints and frame:GetNumPoints() or 0
    for index = 1, count do
        local point, relativeTo, relativePoint, x, y = frame:GetPoint(index)
        points[#points + 1] = { point, relativeTo, relativePoint, x, y }
    end
    return points
end

local function frameName(frame)
    return frame and frame.GetName and frame:GetName() or "unnamed frame"
end

local function finiteNumber(value)
    return type(value) == "number" and value == value and value < math.huge and value > -math.huge
end

function Panels:GetSavedPosition(frame)
    local name = frameName(frame)
    if name == "unnamed frame" or not Addon.charDB then return nil end
    if (tonumber(Addon.charDB.panelPositionSchema) or 0) > 1 then return nil end
    local positions = Addon.charDB.panelPositions
    local saved = type(positions) == "table" and positions[name] or nil
    if type(saved) ~= "table" or saved.schema ~= 1 then return nil end
    if not finiteNumber(saved.x) or not finiteNumber(saved.y) then return nil end
    if math.abs(saved.x) > 2 or math.abs(saved.y) > 2 then return nil end
    return saved
end

function Panels:SavePosition(frame)
    if not frame or not frame.GetCenter or not UIParent or not UIParent.GetWidth or not UIParent.GetHeight then
        return false
    end
    if InCombatLockdown and InCombatLockdown() then
        Addon:RunWhenSafe(function() Panels:SavePosition(frame) end, "save-position:" .. tostring(frame))
        return false
    end

    local name = frameName(frame)
    if name == "unnamed frame" or not Addon.charDB then return false end
    if (tonumber(Addon.charDB.panelPositionSchema) or 0) > 1 then return false end
    if type(Addon.charDB.panelPositions) ~= "table" then Addon.charDB.panelPositions = {} end

    local centerX, centerY = frame:GetCenter()
    local width, height = UIParent:GetWidth(), UIParent:GetHeight()
    local originX, originY
    if UIParent.GetCenter then originX, originY = UIParent:GetCenter() end
    originX = originX or (width and width / 2)
    originY = originY or (height and height / 2)
    if not finiteNumber(centerX) or not finiteNumber(centerY) or not finiteNumber(width) or not finiteNumber(height) or width <= 0 or height <= 0 or not finiteNumber(originX) or not finiteNumber(originY) then
        return false
    end

    local normalizedX = (centerX - originX) / width
    local normalizedY = (centerY - originY) / height
    if not finiteNumber(normalizedX) or not finiteNumber(normalizedY) or math.abs(normalizedX) > 2 or math.abs(normalizedY) > 2 then
        return false
    end

    Addon.charDB.panelPositions[name] = { schema = 1, x = normalizedX, y = normalizedY }
    Addon.charDB.panelPositionSchema = 1
    return true
end

function Panels:Remember(frame)
    if not frame or self.originalPoints[frame] then return end
    self.originalPoints[frame] = capture(frame)
    self.originalScales[frame] = frame.GetScale and frame:GetScale() or 1
end

function Panels:Place(frame, layout)
    if not frame or not frame.IsShown or not frame:IsShown() then return false end
    if InCombatLockdown and InCombatLockdown() then
        Addon:RunWhenSafe(function() Panels:Place(frame, layout) end, "panel:" .. tostring(frame))
        return false
    end

    self:Remember(frame)
    local profile = Addon:GetProfile()
    local originalScale = self.originalScales[frame] or 1
    local requestedScale = originalScale * (profile.panelScale or 1)
    local frameWidth = frame.GetWidth and frame:GetWidth() or 0
    local frameHeight = frame.GetHeight and frame:GetHeight() or 0
    local widthFit = frameWidth > 0 and layout.workspace.width / frameWidth or requestedScale
    local heightFit = frameHeight > 0 and layout.canvasHeight / frameHeight or requestedScale
    local scale = math.min(requestedScale, widthFit, heightFit)
    if not finiteNumber(scale) or scale <= 0 then
        Addon:ReportError("Panel has no valid fit scale for " .. frameName(frame), scale)
        return false
    end
    local savedPosition = self:GetSavedPosition(frame)
    local centerX = savedPosition and savedPosition.x * layout.canvasWidth or layout.workspace.centerX
    local centerY = savedPosition and savedPosition.y * layout.canvasHeight or layout.workspace.centerY

    frame:ClearAllPoints()
    frame:SetScale(scale)
    frame:SetPoint("CENTER", UIParent, "CENTER", centerX, centerY)
    return true
end

function Panels:Restore(frame)
    local points = self.originalPoints[frame]
    if not points then return true end
    if InCombatLockdown and InCombatLockdown() then
        Addon:RunWhenSafe(function() Panels:Restore(frame) end, "restore:" .. tostring(frame))
        return false
    end

    frame:ClearAllPoints()
    if #points > 0 then
        for _, anchor in ipairs(points) do
            frame:SetPoint(anchor[1], anchor[2], anchor[3], anchor[4], anchor[5])
        end
    end
    frame:SetScale(self.originalScales[frame] or 1)
    self.originalPoints[frame] = nil
    self.originalScales[frame] = nil
    return true
end

function Panels:RouteFrame(frame, layout)
    local definition = self.assignments[frame] or Addon.PanelRegistry:Classify(frame)
    if not definition or definition.route == false then return false end
    local controller = Addon.PanelControllers:Get(definition.controller)
    if not controller then
        Addon:ReportError("No position controller registered for " .. frameName(frame), definition.controller)
        return false
    end
    local ok, result = pcall(controller.Apply, controller, frame, layout)
    if not ok then
        Addon:ReportError("Panel routing failed for " .. frameName(frame), result)
        return false
    end
    return result ~= false
end

function Panels:ReconcileFrame(frame)
    if not frame then return false end
    return Addon:RunWhenSafe(function()
        if Addon.db and Addon.db.enabled and frame.IsShown and frame:IsShown() then
            local layout, err = Addon.Geometry:Calculate(Addon:GetProfile())
            if not layout then
                Addon:ReportError("Panel geometry unavailable for " .. frameName(frame), err)
                return
            end
            self:RouteFrame(frame, layout)
        else
            self:Restore(frame)
        end
    end, "panel-state:" .. tostring(frame))
end

function Panels:RouteIfEnabled(frame)
    if not frame then return end
    self:Hook(frame)
    return self:ReconcileFrame(frame)
end

function Panels:Hook(frame)
    if not frame or self.hooked[frame] or not frame.HookScript then return false end
    self.hooked[frame] = true
    self.discoveryCount = self.discoveryCount + 1
    frame:HookScript("OnShow", function(shownFrame) Panels:RouteIfEnabled(shownFrame) end)
    frame:HookScript("OnHide", function(hiddenFrame) Panels:ReconcileFrame(hiddenFrame) end)
    frame:HookScript("OnDragStop", function(draggedFrame) Panels:SavePosition(draggedFrame) end)
    return true
end

function Panels:DiscoverFrame(frame, routeExisting)
    if not frame or not frame.HookScript or not frame.IsShown then return false end
    local definition = Addon.PanelRegistry:Classify(frame)
    if not definition then return false end
    if definition.route == false then
        self.excluded[frame] = definition
        return false
    end
    self.assignments[frame] = definition
    self:Hook(frame)
    if routeExisting ~= false and Addon.db and Addon.db.enabled and frame:IsShown() then
        self:RouteIfEnabled(frame)
    end
    return true
end

function Panels:DiscoverAndPlace()
    for _, globalName in ipairs(Addon.PanelRegistry:GetKnownNames()) do
        self:DiscoverFrame(_G[globalName], false)
    end
end

function Panels:InstallDiscoveryHooks()
    if self.discoveryHooksInstalled or not hooksecurefunc then return end
    self.discoveryHooksInstalled = true
    if type(_G.ShowUIPanel) == "function" then
        hooksecurefunc("ShowUIPanel", function(frame) Panels:DiscoverFrame(frame) end)
    end
    if type(_G.CreateFrame) == "function" then
        hooksecurefunc("CreateFrame", function(_, globalName)
            if type(globalName) == "string" and globalName ~= "" then Panels:DiscoverFrame(_G[globalName]) end
        end)
    end
    if type(_G.ToggleFrame) == "function" then
        hooksecurefunc("ToggleFrame", function(frameOrName)
            local frame = type(frameOrName) == "string" and _G[frameOrName] or frameOrName
            Panels:DiscoverFrame(frame)
        end)
    end
    for _, functionName in ipairs({ "ToggleBackpack", "ToggleAllBags", "OpenAllBags", "ToggleBag" }) do
        if type(_G[functionName]) == "function" then
            hooksecurefunc(functionName, function() Panels:DiscoverAndPlace() end)
        end
    end
end

function Panels:Initialize()
    for _, globalName in ipairs(Addon.PanelRegistry:GetKnownNames()) do
        self:DiscoverFrame(_G[globalName])
    end
    self:InstallDiscoveryHooks()
end

function Panels:Apply(layout)
    if not layout then return end
    self:DiscoverAndPlace()
    for frame in pairs(self.hooked) do
        if frame.IsShown and frame:IsShown() then self:RouteFrame(frame, layout) end
    end
end

function Panels:RestoreAll()
    local frames = {}
    for frame in pairs(self.originalPoints) do frames[#frames + 1] = frame end
    for _, frame in ipairs(frames) do
        local definition = self.assignments[frame]
        local controller = definition and Addon.PanelControllers:Get(definition.controller)
        local ok, err = pcall(controller and controller.Restore or self.Restore, controller or self, frame)
        if not ok then Addon:ReportError("Panel restore failed for " .. frameName(frame), err) end
    end
end