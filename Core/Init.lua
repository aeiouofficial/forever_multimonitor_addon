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
    local ok
    if self.db and self.db.enabled then ok = self:Apply() else ok = self:Reset() end
    if self.MapEscape then self.MapEscape:Sync() end
    return ok
end

function Addon:RollbackFailedApply(reason)
    if self.db then self.db.enabled = false end
    local rollbackFailures = {}

    local panelsCallOK, panelsRestored = pcall(self.Panels.RestoreAll, self.Panels)
    if not panelsCallOK or panelsRestored ~= true then
        rollbackFailures[#rollbackFailures + 1] = panelsCallOK and "panel restoration incomplete" or tostring(panelsRestored)
    end

    local viewportCallOK, viewportRestored, viewportError = pcall(self.Viewport.Restore, self.Viewport)
    if not viewportCallOK or viewportRestored ~= true then
        rollbackFailures[#rollbackFailures + 1] = viewportCallOK and ("viewport restoration failed: " .. tostring(viewportError or "restore returned false"))
            or ("viewport restoration raised: " .. tostring(viewportRestored))
    end

    if self.RawMouse then
        local rawCallOK, rawRestored = pcall(self.RawMouse.Restore, self.RawMouse)
        if not rawCallOK or rawRestored ~= true then
            rollbackFailures[#rollbackFailures + 1] = rawCallOK and "raw mouse restoration failed" or tostring(rawRestored)
        end
    end

    if self.MapEscape then
        local mapCallOK, mapRestored = pcall(self.MapEscape.Sync, self.MapEscape)
        if not mapCallOK or mapRestored ~= true then
            rollbackFailures[#rollbackFailures + 1] = mapCallOK and "map Escape state could not be restored" or tostring(mapRestored)
        end
    end

    if #rollbackFailures > 0 then
        reason = tostring(reason) .. "; rollback incomplete: " .. table.concat(rollbackFailures, "; ")
    end
    self:ReportError("Layout apply failed; layout disabled", reason)
    return false, reason
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
        return self:RollbackFailedApply("Cannot calculate layout: " .. tostring(err))
    end

    local successfullyApplied = false
    local dispatched = self:RunWhenSafe(function()
        if not (self.db and self.db.enabled) then
            return self:RefreshLayoutState()
        end
        local currentLayout, currentError = self.Geometry:Calculate(self:GetProfile())
        if not currentLayout then
            return self:RollbackFailedApply("Cannot calculate layout: " .. tostring(currentError))
        end
        local callOK, applied, viewportError = pcall(self.Viewport.Apply, self.Viewport, currentLayout)
        local viewportOK = callOK and applied == true
        if not viewportOK then
            return self:RollbackFailedApply("Viewport apply failed: "
                .. tostring(callOK and (viewportError or "apply returned false") or applied))
        end
        local panelsCallOK, panelsApplied = pcall(self.Panels.Apply, self.Panels, currentLayout)
        if not panelsCallOK or panelsApplied ~= true then
            return self:RollbackFailedApply("Panel routing failed: "
                .. tostring(panelsCallOK and "one or more panels could not be placed" or panelsApplied))
        end

        self:RecordAppliedLayout(currentLayout)
        if self.RawMouse then
            local rawOK, rawError = pcall(self.RawMouse.Sync, self.RawMouse)
            if not rawOK then self:ReportError("Raw mouse sync failed", rawError) end
        end
        successfullyApplied = true
        return true
    end, "layout-state")
    return dispatched and successfullyApplied
end

function Addon:Reset()
    if InCombatLockdown and InCombatLockdown() then
        self:RunWhenSafe(function() self:RefreshLayoutState() end, "layout-state")
        return false
    end

    return self:RunWhenSafe(function()
        if self.db and self.db.enabled then
            return self:RefreshLayoutState()
        end
        local callOK, restored, viewportError = pcall(self.Viewport.Restore, self.Viewport)
        if not callOK or restored ~= true then
            self:ReportError("Viewport restore failed", callOK and (viewportError or "restore returned false") or restored)
        end
        local panelsCallOK, panelsRestored = pcall(self.Panels.RestoreAll, self.Panels)
        if not panelsCallOK or panelsRestored ~= true then
            self:ReportError("Panel restore failed", panelsCallOK and "one or more panels could not be restored" or panelsRestored)
        end
        local rawRestored = true
        if self.RawMouse then
            local rawOK, rawResult = pcall(self.RawMouse.Restore, self.RawMouse)
            if not rawOK or rawResult ~= true then
                self:ReportError("Raw mouse restore failed", rawResult)
                rawRestored = false
            end
        end
        return callOK and restored == true and panelsCallOK and panelsRestored == true and rawRestored
    end, "layout-state")
end

Addon.frame:SetScript("OnEvent", function(_, event, loadedName)
    if event == "ADDON_LOADED" then
        if loadedName == addonName then
            Addon:InitializeConfig()
            Addon.Compat:Initialize()
            Addon:LoadNativeGeometry()
            if Addon.Options and Addon.Options.RegisterCategory then
                local registerCallOK, registered, registrationError = pcall(Addon.Options.RegisterCategory, Addon.Options)
                if not registerCallOK then
                    Addon:ReportError("Could not register AddOns settings entry", registered)
                elseif not registered then
                    Addon:Print("AddOns settings entry unavailable: " .. tostring(registrationError) .. ". Use /forevermultimonitor config to open settings.")
                end
            end
            Addon:Print("Loaded version " .. Addon.version .. " for Forever.")
        end
        if Addon.db then Addon.Panels:Initialize() end
    elseif event == "PLAYER_LOGIN" then
        if not Addon.db then
            Addon:InitializeConfig()
            Addon.Compat:Initialize()
            Addon:LoadNativeGeometry()
        end
        Addon.Panels:Initialize()
        if Addon.MapEscape then Addon.MapEscape:Sync() end
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
        -- Avoid persisting a cropped viewport in the game layout cache.
        if Addon.Viewport then
            local callOK, restored, err = pcall(Addon.Viewport.Restore, Addon.Viewport)
            if not callOK or restored ~= true then
                Addon:ReportError("Viewport logout restoration failed", callOK and (err or "restore returned false") or restored)
            end
        end
        if Addon.MapEscape then Addon.MapEscape:Restore() end
        if Addon.RawMouse then pcall(Addon.RawMouse.Restore, Addon.RawMouse) end
    elseif event == "PLAYER_REGEN_ENABLED" then
        Addon:FlushPendingWork()
    end
end)
