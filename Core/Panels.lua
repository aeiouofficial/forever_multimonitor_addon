local _, Addon = ...

local Panels = {}
Addon.Panels = Panels
Panels.originalPoints = setmetatable({}, { __mode = "k" })
Panels.originalScales = setmetatable({}, { __mode = "k" })
Panels.hooked = setmetatable({}, { __mode = "k" })
Panels.discoveryHooksInstalled = false

local PANEL_NAMES = {
    "WorldMapFrame",
    "CharacterFrame",
    "SpellBookFrame",
    "QuestLogFrame",
    "ProfessionsFrame",
    "AuctionHouseFrame",
    "FriendsFrame",
    "PVEFrame",
    "CollectionsJournal",
    "EncounterJournal",
    "AchievementFrame",
    "ContainerFrame1",
    "ContainerFrame2",
    "ContainerFrame3",
    "ContainerFrame4",
    "ContainerFrame5",
    "ContainerFrame6",
    "ContainerFrame7",
    "ContainerFrame8",
    "ContainerFrame9",
    "ContainerFrame10",
    "ContainerFrameCombinedBags",
    "BankFrame",
    "ReagentBankFrame",
    "GuildBankFrame",
}

local function capture(frame)
    local points = {}
    for index = 1, (frame:GetNumPoints() or 0) do
        local point, relativeTo, relativePoint, x, y = frame:GetPoint(index)
        points[#points + 1] = { point, relativeTo, relativePoint, x, y }
    end
    if #points == 0 and frame.GetCenter then
        local x, y = frame:GetCenter()
        if x and y then
            points.center = { x, y }
        end
    end
    return points
end

function Panels:Remember(frame)
    if not self.originalPoints[frame] then
        self.originalPoints[frame] = capture(frame)
        self.originalScales[frame] = frame:GetScale() or 1
    end
end

function Panels:Place(frame, layout)
    if not frame or not frame.IsShown or not frame:IsShown() then
        return
    end
    if InCombatLockdown and InCombatLockdown() then
        Addon.pendingWork = true
        Addon.pendingCallback = function()
            Addon:Apply()
        end
        return
    end

    self:Remember(frame)
    local profile = Addon:GetProfile()
    local originalScale = self.originalScales[frame] or 1
    local requestedScale = originalScale * (profile.panelScale or 1)
    local frameWidth = frame:GetWidth() or 0
    local frameHeight = frame:GetHeight() or 0
    local widthFit = frameWidth > 0 and (layout.workspace.width / frameWidth) or requestedScale
    local heightFit = frameHeight > 0 and (layout.canvasHeight / frameHeight) or requestedScale
    local scale = math.max(originalScale * 0.5, math.min(requestedScale, widthFit, heightFit))

    frame:ClearAllPoints()
    frame:SetScale(scale)
    frame:SetPoint("CENTER", UIParent, "CENTER", layout.workspace.centerX, layout.workspace.centerY)
end

function Panels:Restore(frame)
    local points = self.originalPoints[frame]
    if not points or (InCombatLockdown and InCombatLockdown()) then
        return
    end
    frame:ClearAllPoints()
    if #points == 0 then
        if points.center then
            frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", points.center[1], points.center[2])
        else
            frame:SetAllPoints(UIParent)
        end
    else
        for _, anchor in ipairs(points) do
            frame:SetPoint(anchor[1], anchor[2], anchor[3], anchor[4], anchor[5])
        end
    end
    frame:SetScale(self.originalScales[frame] or 1)
end

function Panels:Hook(frame)
    if not frame or self.hooked[frame] or not frame.HookScript then
        return
    end

    self.hooked[frame] = true
    frame:HookScript("OnShow", function(shownFrame)
        if Addon.db and Addon.db.enabled then
            Addon:RunWhenSafe(function()
                local layout = Addon.Geometry:Calculate(Addon:GetProfile())
                if layout then
                    Panels:Place(shownFrame, layout)
                end
            end)
        end
    end)
end

function Panels:DiscoverAndPlace()
    self:Initialize()
    if not (Addon.db and Addon.db.enabled) then
        return
    end
    Addon:RunWhenSafe(function()
        local layout = Addon.Geometry:Calculate(Addon:GetProfile())
        if layout then
            self:Apply(layout)
        end
    end)
end

function Panels:InstallDiscoveryHooks()
    if self.discoveryHooksInstalled or not hooksecurefunc then
        return
    end
    self.discoveryHooksInstalled = true

    for _, functionName in ipairs({ "ToggleBackpack", "ToggleAllBags", "OpenAllBags", "ToggleBag" }) do
        if type(_G[functionName]) == "function" then
            hooksecurefunc(functionName, function()
                Panels:DiscoverAndPlace()
            end)
        end
    end
end

function Panels:Initialize()
    for _, globalName in ipairs(PANEL_NAMES) do
        local frame = _G[globalName]
        if frame then
            self:Hook(frame)
            if Addon.db and Addon.db.enabled and frame.IsShown and frame:IsShown() then
                local layout = Addon.Geometry:Calculate(Addon:GetProfile())
                if layout then
                    Addon:RunWhenSafe(function()
                        self:Place(frame, layout)
                    end)
                end
            end
        end
    end
    self:InstallDiscoveryHooks()
end

function Panels:Apply(layout)
    if not layout then
        return
    end
    for frame in pairs(self.hooked) do
        if frame.IsShown and frame:IsShown() then
            local ok, err = pcall(self.Place, self, frame, layout)
            if not ok then
                Addon:ReportError("Panel routing failed for " .. tostring(frame.GetName and frame:GetName() or "unnamed frame"), err)
            end
        end
    end
end

function Panels:RestoreAll()
    for frame in pairs(self.originalPoints) do
        local ok, err = pcall(self.Restore, self, frame)
        if not ok then
            Addon:ReportError("Panel restore failed for " .. tostring(frame.GetName and frame:GetName() or "unnamed frame"), err)
        end
    end
end
