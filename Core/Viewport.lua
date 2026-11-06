local _, Addon = ...

local Viewport = {}
Addon.Viewport = Viewport
Viewport.originalPoints = nil
Viewport.originalUserPlaced = nil
Viewport.applied = false

local function capturePoints(frame)
    local points = {}
    local count = frame:GetNumPoints() or 0
    for index = 1, count do
        local point, relativeTo, relativePoint, x, y = frame:GetPoint(index)
        points[#points + 1] = { point, relativeTo, relativePoint, x, y }
    end
    return points
end

local function finiteNumber(value)
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge
end

function Viewport:Capture()
    if self.originalPoints then return end
    if not WorldFrame or not WorldFrame.GetNumPoints then
        error("WorldFrame is unavailable")
    end
    self.originalPoints = capturePoints(WorldFrame)
    if WorldFrame.IsUserPlaced then
        self.originalUserPlaced = WorldFrame:IsUserPlaced() == true
    end
end

function Viewport:Apply(layout)
    if not layout then error("Cannot apply viewport without geometry") end
    local canvasWidth = layout.canvasWidth or (UIParent and UIParent.GetWidth and UIParent:GetWidth())
    local canvasHeight = layout.canvasHeight or (UIParent and UIParent.GetHeight and UIParent:GetHeight())
    local mainMonitor = layout.mainMonitor
    if type(mainMonitor) ~= "table" then return false, "Invalid MainMonitor geometry" end
    local left, right = mainMonitor.left, mainMonitor.right
    local bottom = mainMonitor.bottom
    if bottom == nil then bottom = 0 end
    local top = mainMonitor.top
    if top == nil then top = canvasHeight end
    if not finiteNumber(canvasWidth) or not finiteNumber(canvasHeight)
        or canvasWidth <= 0 or canvasHeight <= 0
        or not finiteNumber(left) or not finiteNumber(right)
        or not finiteNumber(bottom) or not finiteNumber(top)
        or left < 0 or bottom < 0 or right > canvasWidth or top > canvasHeight
        or right <= left or top <= bottom then
        return false, "Invalid MainMonitor geometry"
    end
    if InCombatLockdown and InCombatLockdown() then
        Addon:RunWhenSafe(function() Addon:RefreshLayoutState() end, "layout-state")
        return false
    end
    if not UIParent then return false, "UIParent is unavailable" end
    local parentScale = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    local frameScale = WorldFrame and WorldFrame.GetEffectiveScale and WorldFrame:GetEffectiveScale() or parentScale
    if not finiteNumber(parentScale) or not finiteNumber(frameScale) or parentScale <= 0 or frameScale <= 0 then
        return false, "Invalid viewport effective scale"
    end
    local pointScale = parentScale / frameScale
    self:Capture()
    -- Keep an independent snapshot of the current anchors for transactional rollback.
    local beforePoints = capturePoints(WorldFrame)
    local wasApplied = self.applied
    local beforeUserPlaced = WorldFrame.IsUserPlaced and WorldFrame:IsUserPlaced() == true
    local ok, err = pcall(function()
        -- The crop must never become a persisted default WoW viewport.
        if WorldFrame.SetUserPlaced then WorldFrame:SetUserPlaced(false) end
        WorldFrame:ClearAllPoints()
        WorldFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left * pointScale, bottom * pointScale)
        WorldFrame:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", right * pointScale, top * pointScale)
    end)
    if not ok then
        local restored, restoreError = pcall(function()
            WorldFrame:ClearAllPoints()
            -- An empty anchor list is a valid original state: do not invent an anchor.
            for _, point in ipairs(beforePoints) do
                WorldFrame:SetPoint(point[1], point[2], point[3], point[4], point[5])
            end
            if WorldFrame.SetUserPlaced then WorldFrame:SetUserPlaced(beforeUserPlaced) end
        end)
        self.applied = restored and wasApplied or false
        if not restored then
            return false, "Apply failed: " .. tostring(err) .. "; rollback failed: " .. tostring(restoreError)
        end
        return false, "Apply failed and previous anchors restored: " .. tostring(err)
    end
    self.applied = true
    return true
end

function Viewport:Restore()
    if not self.originalPoints or not WorldFrame then
        self.applied = false
        return true
    end
    if InCombatLockdown and InCombatLockdown() then
        Addon:RunWhenSafe(function() Addon:RefreshLayoutState() end, "layout-state")
        return false
    end

    local beforePoints = capturePoints(WorldFrame)
    local beforeUserPlaced = WorldFrame.IsUserPlaced and WorldFrame:IsUserPlaced() == true
    local ok, err = pcall(function()
        WorldFrame:ClearAllPoints()
        -- Preserve the exact pre-addon anchor state, including zero anchors.
        for _, anchor in ipairs(self.originalPoints) do
            WorldFrame:SetPoint(anchor[1], anchor[2], anchor[3], anchor[4], anchor[5])
        end
        if WorldFrame.SetUserPlaced then
            WorldFrame:SetUserPlaced(self.originalUserPlaced == true)
        end
    end)
    if not ok then
        local reverted, revertError = pcall(function()
            WorldFrame:ClearAllPoints()
            for _, anchor in ipairs(beforePoints) do
                WorldFrame:SetPoint(anchor[1], anchor[2], anchor[3], anchor[4], anchor[5])
            end
            if WorldFrame.SetUserPlaced then WorldFrame:SetUserPlaced(beforeUserPlaced) end
        end)
        -- Keep the original snapshot available for a later restoration attempt.
        return false, "Viewport restoration failed: " .. tostring(err)
            .. (reverted and "; current layout retained" or "; rollback also failed: " .. tostring(revertError))
    end
    self.originalPoints = nil
    self.originalUserPlaced = nil
    self.applied = false
    return true
end
