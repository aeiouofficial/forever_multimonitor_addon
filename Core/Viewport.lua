local _, Addon = ...

local Viewport = {}
Addon.Viewport = Viewport
Viewport.originalPoints = nil
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

function Viewport:Capture()
    if self.originalPoints then
        return
    end
    if not WorldFrame or not WorldFrame.GetNumPoints then
        error("WorldFrame is unavailable")
    end
    self.originalPoints = capturePoints(WorldFrame)
end

function Viewport:Apply(layout)
    if not layout then
        error("Cannot apply viewport without geometry")
    end
    if InCombatLockdown and InCombatLockdown() then
        Addon.pendingWork = true
        Addon.pendingCallback = function()
            Addon:Apply()
        end
        return false
    end

    self:Capture()
    WorldFrame:ClearAllPoints()
    WorldFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", layout.mainhand.left, 0)
    WorldFrame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", layout.mainhand.right, 0)

    self.applied = true
    return true
end

function Viewport:Restore()
    if not self.originalPoints or not WorldFrame then
        self.applied = false
        return true
    end
    if InCombatLockdown and InCombatLockdown() then
        Addon.pendingWork = true
        Addon.pendingCallback = function()
            Addon:Reset()
        end
        return false
    end

    WorldFrame:ClearAllPoints()
    if #self.originalPoints == 0 then
        WorldFrame:SetAllPoints(UIParent)
    else
        for _, anchor in ipairs(self.originalPoints) do
            WorldFrame:SetPoint(anchor[1], anchor[2], anchor[3], anchor[4], anchor[5])
        end
    end

    self.applied = false
    return true
end
