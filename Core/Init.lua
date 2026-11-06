local addonName, Addon = ...

Addon.frame = CreateFrame("Frame")
Addon.frame:RegisterEvent("ADDON_LOADED")
Addon.frame:RegisterEvent("PLAYER_LOGIN")
Addon.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
Addon.frame:RegisterEvent("PLAYER_REGEN_ENABLED")
Addon.frame:RegisterEvent("UI_SCALE_CHANGED")
Addon.frame:RegisterEvent("DISPLAY_SIZE_CHANGED")

function Addon:Apply()
    if not self.db then
        self:InitializeConfig()
    end
    if not self.db.enabled then
        return false
    end

    local layout, err = self.Geometry:Calculate(self:GetProfile())
    if not layout then
        self:Print("Cannot apply layout: " .. tostring(err))
        return false
    end

    return self:RunWhenSafe(function()
        local viewportOK, viewportError = pcall(self.Viewport.Apply, self.Viewport, layout)
        if not viewportOK then
            self:ReportError("Viewport apply failed", viewportError)
        end
        self.Panels:Apply(layout)
        if viewportOK then
            self:RecordAppliedLayout(layout)
        end
    end)
end

function Addon:Reset()
    self:RunWhenSafe(function()
        local viewportOK, viewportError = pcall(self.Viewport.Restore, self.Viewport)
        if not viewportOK then
            self:ReportError("Viewport restore failed", viewportError)
        end
        self.Panels:RestoreAll()
    end)
end

Addon.frame:SetScript("OnEvent", function(_, event, loadedName)
    if event == "ADDON_LOADED" then
        if loadedName == addonName then
            Addon:InitializeConfig()
            Addon.Compat:Initialize()
            Addon:Print("Loaded version " .. Addon.version .. " for Forever.")
        end
        if Addon.db then
            Addon.Panels:Initialize()
        end
    elseif event == "PLAYER_LOGIN" then
        if not Addon.db then
            Addon:InitializeConfig()
            Addon.Compat:Initialize()
        end
        Addon.Panels:Initialize()
        Addon:ScheduleRecovery("PLAYER_LOGIN")
    elseif event == "PLAYER_ENTERING_WORLD" then
        Addon:ScheduleRecovery("PLAYER_ENTERING_WORLD")
    elseif event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" then
        Addon:ScheduleRecovery(event)
    elseif event == "PLAYER_REGEN_ENABLED" then
        Addon:FlushPendingWork()
    end
end)
