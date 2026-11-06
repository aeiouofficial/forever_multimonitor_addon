local addonName, Addon = ...

Addon.frame = CreateFrame("Frame")
Addon.frame:RegisterEvent("ADDON_LOADED")
Addon.frame:RegisterEvent("PLAYER_LOGIN")
Addon.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
Addon.frame:RegisterEvent("PLAYER_REGEN_ENABLED")
Addon.frame:RegisterEvent("UI_SCALE_CHANGED")
Addon.frame:RegisterEvent("DISPLAY_SIZE_CHANGED")
Addon.frame:RegisterEvent("PLAYER_LOGOUT")

function Addon:RefreshLayoutState()
    if self.db and self.db.enabled then self:Apply() else self:Reset() end
end

function Addon:Apply()
    if not self.db then self:InitializeConfig() end
    if not self.db.enabled then return false end
    if InCombatLockdown and InCombatLockdown() then
        self:RunWhenSafe(function() self:RefreshLayoutState() end, "layout-state")
        return false
    end

    local layout, err = self.Geometry:Calculate(self:GetProfile())
    if not layout then
        self:Print("Cannot apply layout: " .. tostring(err))
        return false
    end

    return self:RunWhenSafe(function()
        if not (self.db and self.db.enabled) then
            self:RefreshLayoutState()
            return
        end
        local currentLayout, currentError = self.Geometry:Calculate(self:GetProfile())
        if not currentLayout then
            self:Print("Cannot apply layout: " .. tostring(currentError))
            return
        end
        local viewportOK, viewportError = pcall(self.Viewport.Apply, self.Viewport, currentLayout)
        if not viewportOK then self:ReportError("Viewport apply failed", viewportError) end
        self.Panels:Apply(currentLayout)

        if viewportOK then
            self:RecordAppliedLayout(currentLayout)
            if self.RawMouse then
                local rawOK, rawError = pcall(self.RawMouse.Sync, self.RawMouse)
                if not rawOK then self:ReportError("Raw mouse sync failed", rawError) end
            end
        elseif self.RawMouse then
            pcall(self.RawMouse.Restore, self.RawMouse)
        end
    end, "layout-state")
end

function Addon:Reset()
    if InCombatLockdown and InCombatLockdown() then
        self:RunWhenSafe(function() self:RefreshLayoutState() end, "layout-state")
        return false
    end

    return self:RunWhenSafe(function()
        if self.db and self.db.enabled then
            self:RefreshLayoutState()
            return
        end
        local viewportOK, viewportError = pcall(self.Viewport.Restore, self.Viewport)
        if not viewportOK then self:ReportError("Viewport restore failed", viewportError) end
        self.Panels:RestoreAll()
        if self.RawMouse then
            local rawOK, rawError = pcall(self.RawMouse.Restore, self.RawMouse)
            if not rawOK then self:ReportError("Raw mouse restore failed", rawError) end
        end
    end, "layout-state")
end

Addon.frame:SetScript("OnEvent", function(_, event, loadedName)
    if event == "ADDON_LOADED" then
        if loadedName == addonName then
            Addon:InitializeConfig()
            Addon.Compat:Initialize()
            Addon:Print("Loaded version " .. Addon.version .. " for Forever.")
        end
        if Addon.db then Addon.Panels:Initialize() end
    elseif event == "PLAYER_LOGIN" then
        if not Addon.db then
            Addon:InitializeConfig()
            Addon.Compat:Initialize()
        end
        Addon.Panels:Initialize()
        if Addon.db.enabled then
            Addon:ScheduleRecovery("PLAYER_LOGIN")
        elseif Addon.RawMouse then
            pcall(Addon.RawMouse.Restore, Addon.RawMouse)
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        Addon:ScheduleRecovery("PLAYER_ENTERING_WORLD")
    elseif event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" then
        Addon:ScheduleRecovery(event)
    elseif event == "PLAYER_LOGOUT" then
        if Addon.RawMouse then pcall(Addon.RawMouse.Restore, Addon.RawMouse) end
    elseif event == "PLAYER_REGEN_ENABLED" then
        Addon:FlushPendingWork()
    end
end)