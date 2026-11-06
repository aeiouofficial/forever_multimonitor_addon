local _, Addon = ...

local function printHelp()
    Addon:Print("Commands: /fmm status | apply | enable | disable | side left|right | width 25-90 | seam 0-100 | scale 0.5-1.5 | rawmouse on|off | profile list|create|use|delete | config | reset")
end

local function printStatus()
    local profile = Addon:GetProfile()
    local layout, err = Addon.Geometry:Calculate(profile)
    local runtime = Addon.runtime or {}

    Addon:Print("Enabled: " .. tostring(Addon.db.enabled))
    Addon:Print("Mainhand: " .. profile.mainhandSide .. " / " .. tostring(profile.mainhandWidthPercent) .. "%")
    Addon:Print("Seam offset: " .. tostring(profile.seamUiUnits) .. " UI units | panel scale: " .. tostring(profile.panelScale) .. " | raw mouse: " .. tostring(profile.rawMouseEnabled))
    Addon:Print("Client: " .. tostring(runtime.version or "unknown") .. " build " .. tostring(runtime.build or "unknown") .. " / interface " .. tostring(runtime.interface or "unknown"))
    if layout then
        Addon:Print(string.format("Canvas: %.0f x %.0f; Offhand workspace: %.0f logical UI units", layout.canvasWidth, layout.canvasHeight, layout.workspace.width))
    else
        Addon:Print("Geometry unavailable: " .. tostring(err))
    end
    if Addon.lastError then Addon:Print("Last error: " .. Addon.lastError) end
end

function Addon:HandleCommand(message)
    local command, value = message:match("^(%S+)%s*(.-)$")
    command = (command or "help"):lower()

    if command == "help" or command == "" then
        printHelp()
    elseif command == "profile" then
        local action, name = value:match("^(%S+)%s*(.-)$")
        action = (action or "list"):lower()
        if action == "list" then
            Addon:Print("Profiles: " .. table.concat(self:GetProfileNames(), ", ") .. " | active: " .. self:GetActiveProfileName())
        elseif action == "create" then
            local ok, err = self:CreateProfile(name)
            Addon:Print(ok and ("Created and activated profile " .. name) or err)
        elseif action == "use" then
            local ok, err = self:SetActiveProfile(name)
            Addon:Print(ok and ("Active profile: " .. name) or err)
        elseif action == "delete" then
            local ok = self:DeleteProfile(name)
            Addon:Print(ok and ("Deleted profile " .. name) or "Cannot delete Default, the active profile, or a missing profile.")
        else
            Addon:Print("Usage: /fmm profile list|create <name>|use <name>|delete <name>")
        end
    elseif command == "config" then
        self.Options:Toggle()
    elseif command == "status" then
        printStatus()
    elseif command == "enable" then
        if self.Options then self.Options:CancelPreview(false) end
        self:SetEnabled(true)
        if self.Options then self.Options:Refresh() end
        self:Print("Dual-monitor layout enabled.")
    elseif command == "disable" then
        if self.Options then self.Options:CancelPreview(false) end
        self:SetEnabled(false)
        if self.Options then self.Options:Refresh() end
        self:Print("Dual-monitor layout disabled.")
    elseif command == "apply" then
        if not self.db.enabled then
            self:Print("Layout is disabled. Use /fmm enable first.")
        elseif self.Options and self.Options.previewActive then
            self.Options:KeepPreview()
            self:Print("Layout preview confirmed.")
        else
            self:Apply()
            self:Print("Layout apply requested.")
        end
    elseif command == "reset" then
        if self.Options then self.Options:CancelPreview(false) end
        self:SetEnabled(false)
        if self.Options then self.Options:Refresh() end
        self:Print("Layout disabled; viewport and supported panels restored.")
    elseif command == "side" then
        value = value:lower()
        if value ~= "left" and value ~= "right" then
            self:Print("Usage: /fmm side left|right")
            return
        end
        self:SetProfileValue("mainhandSide", value)
        if self.db.enabled then self:Apply() end
    elseif command == "width" then
        local width = tonumber(value)
        if not width then
            self:Print("Usage: /fmm width 25-90")
            return
        end
        self:SetProfileValue("mainhandWidthPercent", width)
        if self.db.enabled then self:Apply() end
    elseif command == "seam" then
        local seam = tonumber(value)
        if not seam then
            self:Print("Usage: /fmm seam 0-100")
            return
        end
        self:SetProfileValue("seamUiUnits", seam)
        if self.db.enabled then self:Apply() end
    elseif command == "scale" then
        local scale = tonumber(value)
        if not scale then
            self:Print("Usage: /fmm scale 0.5-1.5")
            return
        end
        self:SetProfileValue("panelScale", scale)
        if self.db.enabled then self:Apply() end
    elseif command == "rawmouse" then
        value = value:lower()
        if value ~= "on" and value ~= "off" then
            self:Print("Usage: /fmm rawmouse on|off")
            return
        end
        self:SetProfileValue("rawMouseEnabled", value == "on")
        if self.RawMouse then
            local ok, err = pcall(self.RawMouse.Sync, self.RawMouse)
            if not ok then self:ReportError("Raw mouse setting failed", err) end
        end
    else
        printHelp()
    end
end

SLASH_FOREVERMULTIMONITOR1 = "/fmm"
SlashCmdList = SlashCmdList or {}
SlashCmdList.FOREVERMULTIMONITOR = function(message)
    Addon:HandleCommand(message or "")
end