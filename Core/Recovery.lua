local _, Addon = ...

Addon.recoveryGeneration = 0

function Addon:RecordAppliedLayout(layout)
    if not self.db then return end
    self.db.lastAppliedLayout = {
        canvasWidth = layout.canvasWidth,
        canvasHeight = layout.canvasHeight,
        mainhandSide = self:GetProfile().mainhandSide,
        mainhandWidthPercent = self:GetProfile().mainhandWidthPercent,
        seamUiUnits = self:GetProfile().seamUiUnits,
    }
    self.db.lastAppliedBuild = self.runtime and self.runtime.build or "unknown"
end

function Addon:ScheduleRecovery(reason)
    if not (self.db and self.db.enabled) then return end
    self.recoveryGeneration = self.recoveryGeneration + 1
    local generation = self.recoveryGeneration
    self.recoveryReason = reason or "unspecified"

    local function recover()
        if generation ~= self.recoveryGeneration then return end
        self:RunWhenSafe(function()
            if generation == self.recoveryGeneration then
                self:RefreshLayoutState()
            end
        end, "layout-state")
    end

    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(0.5, recover)
    else
        recover()
    end
end
