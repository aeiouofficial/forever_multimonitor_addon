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

local function isForbidden(frame)
    if not frame or type(frame.IsForbidden) ~= "function" then return false end
    local ok, forbidden = pcall(frame.IsForbidden, frame)
    return not ok or forbidden == true
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

function Panels:Place(frame, layout, preferred)
    if not frame or not frame.IsShown or not frame:IsShown() then return false end
    if isForbidden(frame) then return false end
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
    local secondMonitor1 = type(layout) == "table" and layout.secondMonitor1
    if type(secondMonitor1) ~= "table" then
        Addon:ReportError("Panel has invalid SecondMonitor1 bounds for " .. frameName(frame), "SecondMonitor1 geometry is unavailable")
        return false
    end
    local secondMonitor1Width = secondMonitor1.width
    local secondMonitor1Bottom = finiteNumber(secondMonitor1.bottom) and secondMonitor1.bottom or 0
    local secondMonitor1Top = finiteNumber(secondMonitor1.top) and secondMonitor1.top
        or (secondMonitor1Bottom + (finiteNumber(secondMonitor1.height) and secondMonitor1.height or layout.canvasHeight))
    local secondMonitor1Height = finiteNumber(secondMonitor1.height) and secondMonitor1.height or (secondMonitor1Top - secondMonitor1Bottom)
    if not finiteNumber(secondMonitor1Width) or secondMonitor1Width <= 0
        or not finiteNumber(secondMonitor1Height) or secondMonitor1Height <= 0 then
        Addon:ReportError("Panel has invalid SecondMonitor1 bounds for " .. frameName(frame), tostring(secondMonitor1Width) .. "x" .. tostring(secondMonitor1Height))
        return false
    end

    local parentScale = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    local currentScale = frame.GetScale and frame:GetScale() or 1
    local currentEffectiveScale = frame.GetEffectiveScale and frame:GetEffectiveScale() or parentScale * currentScale
    if not finiteNumber(parentScale) or parentScale <= 0
        or not finiteNumber(currentScale) or currentScale <= 0
        or not finiteNumber(currentEffectiveScale) or currentEffectiveScale <= 0 then
        Addon:ReportError("Panel has invalid effective scale for " .. frameName(frame), currentEffectiveScale)
        return false
    end
    local inheritedScale = currentEffectiveScale / parentScale / currentScale
    if not finiteNumber(inheritedScale) or inheritedScale <= 0 then
        Addon:ReportError("Panel has invalid relative scale for " .. frameName(frame), inheritedScale)
        return false
    end

    local widthFit = frameWidth > 0 and secondMonitor1Width / (frameWidth * inheritedScale) or requestedScale
    local heightFit = frameHeight > 0 and secondMonitor1Height / (frameHeight * inheritedScale) or requestedScale
    local scale = math.min(requestedScale, widthFit, heightFit)
    if preferred and finiteNumber(preferred.scale) and preferred.scale > 0 then
        scale = math.min(scale, preferred.scale)
    end
    if not finiteNumber(scale) or scale <= 0 then
        Addon:ReportError("Panel has no valid fit scale for " .. frameName(frame), scale)
        return false
    end
    local savedPosition = self:GetSavedPosition(frame)
    local centerX = savedPosition and savedPosition.x * layout.canvasWidth
        or (preferred and preferred.x) or layout.secondMonitor1.centerX
    local centerY = savedPosition and savedPosition.y * layout.canvasHeight
        or (preferred and preferred.y) or layout.secondMonitor1.centerY

    -- Clamp persisted drag coordinates to the currently available SecondMonitor1,
    -- so a removed/rearranged monitor cannot strand a window outside the canvas.
    local halfWidth = frameWidth * inheritedScale * scale / 2
    local halfHeight = frameHeight * inheritedScale * scale / 2
    local secondMonitor1Left = layout.secondMonitor1.left
    if not finiteNumber(secondMonitor1Left) then
        secondMonitor1Left = layout.canvasWidth / 2 + layout.secondMonitor1.centerX - layout.secondMonitor1.width / 2
    end
    local secondMonitor1Right = layout.secondMonitor1.right or (secondMonitor1Left + layout.secondMonitor1.width)
    local minX = secondMonitor1Left - layout.canvasWidth / 2 + halfWidth
    local maxX = secondMonitor1Right - layout.canvasWidth / 2 - halfWidth
    local minY = secondMonitor1Bottom - layout.canvasHeight / 2 + halfHeight
    local maxY = secondMonitor1Top - layout.canvasHeight / 2 - halfHeight
    if minX > maxX then centerX = layout.secondMonitor1.centerX
    else centerX = math.max(minX, math.min(maxX, centerX)) end
    local secondMonitor1CenterY = finiteNumber(secondMonitor1.centerY) and secondMonitor1.centerY
        or ((secondMonitor1Bottom + secondMonitor1Top) / 2 - layout.canvasHeight / 2)
    if minY > maxY then centerY = secondMonitor1CenterY
    else centerY = math.max(minY, math.min(maxY, centerY)) end

    local beforePoints = capture(frame)
    local beforeScale = frame.GetScale and frame:GetScale() or 1
    local ok, err = pcall(function()
        frame:ClearAllPoints()
        frame:SetScale(scale)
        local pointScale = inheritedScale * scale
        frame:SetPoint("CENTER", UIParent, "CENTER", centerX / pointScale, centerY / pointScale)
    end)
    if not ok then
        local restored, restoreError = pcall(function()
            frame:ClearAllPoints()
            for _, point in ipairs(beforePoints) do
                frame:SetPoint(point[1], point[2], point[3], point[4], point[5])
            end
            frame:SetScale(beforeScale)
        end)
        Addon:ReportError("Panel placement failed for " .. frameName(frame),
            tostring(err) .. (restored and "; rolled back" or "; rollback failed: " .. tostring(restoreError)))
        return false
    end
    return true
end

function Panels:Restore(frame)
    local points = self.originalPoints[frame]
    if not points then return true end
    if isForbidden(frame) then
        Addon:ReportError("Panel restore skipped for forbidden frame " .. frameName(frame), "Blizzard retains ownership")
        return false
    end
    if InCombatLockdown and InCombatLockdown() then
        Addon:RunWhenSafe(function() Panels:Restore(frame) end, "restore:" .. tostring(frame))
        return false
    end

    local beforePoints = capture(frame)
    local beforeScale = frame.GetScale and frame:GetScale() or 1
    local ok, err = pcall(function()
        frame:ClearAllPoints()
        for _, anchor in ipairs(points) do
            frame:SetPoint(anchor[1], anchor[2], anchor[3], anchor[4], anchor[5])
        end
        frame:SetScale(self.originalScales[frame] or 1)
    end)
    if not ok then
        local reverted, revertError = pcall(function()
            frame:ClearAllPoints()
            for _, anchor in ipairs(beforePoints) do
                frame:SetPoint(anchor[1], anchor[2], anchor[3], anchor[4], anchor[5])
            end
            frame:SetScale(beforeScale)
        end)
        Addon:ReportError("Panel restore failed for " .. frameName(frame),
            tostring(err) .. (reverted and "; current layout retained" or "; rollback failed: " .. tostring(revertError)))
        return false
    end
    self.originalPoints[frame] = nil
    self.originalScales[frame] = nil
    return true
end

function Panels:RouteFrame(frame, layout)
    if isForbidden(frame) then
        self.excluded[frame] = {
            name = frameName(frame), controller = nil, route = false, reason = "forbidden",
        }
        return true
    end
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

function Panels:ReconcileBags(layout)
    for index = 1, 10 do
        local bag = _G["ContainerFrame" .. index]
        if bag and self.assignments[bag] then
            if bag.IsShown and bag:IsShown() then
                self:RouteFrame(bag, layout)
            else
                self:Restore(bag)
            end
        end
    end
end

function Panels:IsEditModeOpen()
    local manager = _G.EditModeManagerFrame
    return manager and manager.IsShown and manager:IsShown() or false
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
            if self:IsEditModeOpen() then return end
            local definition = self.assignments[frame]
            if definition and definition.controller == "bags" and frameName(frame):match("^ContainerFrame%d+$") then
                self:ReconcileBags(layout)
            else
                self:RouteFrame(frame, layout)
            end
        else
            self:Restore(frame)
            local definition = self.assignments[frame]
            if Addon.db and Addon.db.enabled and definition and definition.controller == "bags"
                and frameName(frame):match("^ContainerFrame%d+$") then
                local layout = Addon.Geometry:Calculate(Addon:GetProfile())
                if layout then self:ReconcileBags(layout) end
            end
        end
    end, "panel-state:" .. tostring(frame))
end

function Panels:RouteIfEnabled(frame)
    if not frame then return end
    self:Hook(frame)
    return self:ReconcileFrame(frame)
end

function Panels:Hook(frame)
    if not frame or isForbidden(frame) or self.hooked[frame] or not frame.HookScript then return false end
    self.hooked[frame] = true
    self.discoveryCount = self.discoveryCount + 1
    frame:HookScript("OnShow", function(shownFrame) Panels:RouteIfEnabled(shownFrame) end)
    frame:HookScript("OnHide", function(hiddenFrame) Panels:ReconcileFrame(hiddenFrame) end)
    frame:HookScript("OnDragStop", function(draggedFrame) Panels:SavePosition(draggedFrame) end)
    return true
end

function Panels:InstallEditModeHook(frame)
    if not frame or not frame.HookScript or self.editModeFrame == frame then return end
    self.editModeFrame = frame
    frame:HookScript("OnShow", function()
        Addon:Print("Edit Mode is active: panel routing is paused. Do not save the Blizzard HUD layout while the window spans multiple displays.")
    end)
    frame:HookScript("OnHide", function()
        if Addon.db and Addon.db.enabled then Addon:ScheduleRecovery("EDIT_MODE_EXIT") end
    end)
end

function Panels:DiscoverFrame(frame, routeExisting)
    if not frame or not frame.HookScript or not frame.IsShown then return false end
    if isForbidden(frame) then
        self.excluded[frame] = {
            name = frameName(frame), controller = nil, route = false, reason = "forbidden",
        }
        return false
    end
    if frame.GetName and frame:GetName() == "EditModeManagerFrame" then
        self:InstallEditModeHook(frame)
        return false
    end
    local definition = Addon.PanelRegistry:Classify(frame)
    if not definition then return false end
    if definition.route == false then
        self.excluded[frame] = definition
        return false
    end
    self.assignments[frame] = definition
    self:Hook(frame)
    if definition.controller == "world-map" and Addon.MapEscape then Addon.MapEscape:Sync() end
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
    self:InstallEditModeHook(_G.EditModeManagerFrame)
    for _, globalName in ipairs(Addon.PanelRegistry:GetKnownNames()) do
        self:DiscoverFrame(_G[globalName])
    end
    self:InstallDiscoveryHooks()
end

function Panels:Apply(layout)
    if not layout then return false end
    self:InstallEditModeHook(_G.EditModeManagerFrame)
    if self:IsEditModeOpen() then
        if not self.editModeWarningShown then
            Addon:Print("Edit Mode open: supported panels will not be repositioned until you close it.")
            self.editModeWarningShown = true
        end
        return true
    end
    self.editModeWarningShown = false
    self:DiscoverAndPlace()
    local succeeded = true
    for frame in pairs(self.assignments) do
        if frame.IsShown and frame:IsShown() and not self:RouteFrame(frame, layout) then
            succeeded = false
        end
    end
    return succeeded
end

function Panels:RestoreAll()
    local frames = {}
    for frame in pairs(self.originalPoints) do frames[#frames + 1] = frame end
    local succeeded = true
    for _, frame in ipairs(frames) do
        local definition = self.assignments[frame]
        local controller = definition and Addon.PanelControllers:Get(definition.controller)
        local ok, restored = pcall(controller and controller.Restore or self.Restore, controller or self, frame)
        if not ok then
            Addon:ReportError("Panel restore failed for " .. frameName(frame), restored)
            succeeded = false
        elseif restored ~= true then
            succeeded = false
        end
    end
    return succeeded
end
