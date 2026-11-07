local _, Addon = ...

local Options = {}
Addon.Options = Options

local function makeText(parent, text, size, layer)
    local font = parent:CreateFontString(nil, layer or "OVERLAY", "GameFontNormal")
    font:SetText(text or "")
    if font.SetFont then font:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size or 12, "") end
    return font
end

local function makeButton(parent, text, width, height, callback)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width or 110, height or 26)
    button:SetNormalTexture("Interface\\Buttons\\UI-Panel-Button-Up")
    button:SetPushedTexture("Interface\\Buttons\\UI-Panel-Button-Down")
    button:SetHighlightTexture("Interface\\Buttons\\UI-Panel-Button-Highlight")
    local label = makeText(button, text, 12)
    label:SetPoint("CENTER")
    button.label = label
    button:SetScript("OnClick", callback)
    return button
end

local function makeSlider(parent, labelText, minValue, maxValue, step, formatValue, onChange, applyOnRelease)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(440, 52)
    local label = makeText(container, labelText, 12)
    label:SetPoint("TOPLEFT", 0, 0)
    local valueText = makeText(container, "", 12)
    valueText:SetPoint("TOPRIGHT", 0, 0)
    local slider = CreateFrame("Slider", nil, container)
    slider:SetPoint("TOPLEFT", 0, -22)
    slider:SetSize(420, 18)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(step)
    if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
    slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    slider:SetScript("OnValueChanged", function(_, value)
        valueText:SetText(formatValue(value))
        onChange(value)
    end)
    slider:SetScript("OnMouseUp", function()
        if applyOnRelease ~= false and Addon.db and Addon.db.enabled then Addon:Apply() end
        if Addon.Options then Addon.Options:Refresh() end
    end)
    container.slider = slider
    container.valueText = valueText
    container.formatValue = formatValue
    return container
end

local THEMES = {
    midnight = { label = "Midnight", background = { 0.025, 0.035, 0.065 }, border = { 0.18, 0.25, 0.50 }, accent = { 0.58, 0.70, 1.00 } },
    indigo = { label = "Indigo", background = { 0.045, 0.035, 0.095 }, border = { 0.32, 0.24, 0.62 }, accent = { 0.75, 0.64, 1.00 } },
    classic = { label = "Classic", background = { 0.075, 0.055, 0.035 }, border = { 0.55, 0.40, 0.20 }, accent = { 1.00, 0.82, 0.56 } },
}
local THEME_ORDER = { "midnight", "indigo", "classic" }

function Options:ApplyTheme()
    if not self.frame or not Addon.db then return end
    local profile = Addon:GetProfile()
    local theme = THEMES[profile.themePreset] or THEMES.midnight
    local opacity = profile.backgroundOpacity or 0.92
    if self.frame.SetBackdropColor then
        self.frame:SetBackdropColor(theme.background[1], theme.background[2], theme.background[3], opacity)
    elseif self.frame.backgroundTexture and self.frame.backgroundTexture.SetColorTexture then
        self.frame.backgroundTexture:SetColorTexture(theme.background[1], theme.background[2], theme.background[3], opacity)
    end
    if self.frame.SetBackdropBorderColor then
        self.frame:SetBackdropBorderColor(theme.border[1], theme.border[2], theme.border[3], 1)
    end
    if self.title and self.title.SetTextColor then
        self.title:SetTextColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
    end
    if self.wizard then
        if self.wizard.SetBackdropColor then
            self.wizard:SetBackdropColor(theme.background[1], theme.background[2], theme.background[3], opacity)
        end
        if self.wizard.SetBackdropBorderColor then
            self.wizard:SetBackdropBorderColor(theme.border[1], theme.border[2], theme.border[3], 1)
        end
    end
end

function Options:CycleTheme()
    local current = Addon:GetProfile().themePreset
    local nextTheme = THEME_ORDER[1]
    for index, themeName in ipairs(THEME_ORDER) do
        if themeName == current then
            nextTheme = THEME_ORDER[index % #THEME_ORDER + 1]
            break
        end
    end
    Addon:SetProfileValue("themePreset", nextTheme)
    self:Refresh()
end

function Options:Refresh()
    if not self.frame or not Addon.db then return end
    local profile = Addon:GetProfile()
    self.enabledButton.label:SetText(Addon.db.enabled and "Disable layout" or "Enable layout")
    self.sideLeft.label:SetText(profile.mainMonitorSide == "left" and "[ MainMonitor left ]" or "MainMonitor left")
    self.sideRight.label:SetText(profile.mainMonitorSide == "right" and "[ MainMonitor right ]" or "MainMonitor right")
    self.rawMouseButton.label:SetText("Raw mouse: " .. (profile.rawMouseEnabled and "ON" or "OFF"))
    if self.mapEscapeButton then self.mapEscapeButton.label:SetText("Map ESC: " .. (profile.mapStaysOpenOnEscape and "Keep open" or "Normal")) end
    if self.nativeButton then self.nativeButton.label:SetText(Addon.nativeGeometry and "Calibrate from displays" or "Native: manual only") end
    if self.themeButton then self.themeButton.label:SetText("Theme: " .. (THEMES[profile.themePreset] or THEMES.midnight).label) end
    if self.backgroundOpacitySlider then self.backgroundOpacitySlider.slider:SetValue(profile.backgroundOpacity or 0.92) end
    self.profileLabel:SetText("Profile: " .. Addon:GetActiveProfileName() .. " (" .. tostring(#Addon:GetProfileNames()) .. ")")
    self.widthSlider.slider:SetValue(profile.mainMonitorWidthPercent)
    self.seamSlider.slider:SetValue(profile.seamUiUnits)
    self.scaleSlider.slider:SetValue(profile.panelScale)
    local layout, err = Addon.Geometry:Calculate(profile)
    if layout then
        self.status:SetText(string.format("%s | Canvas %.0f x %.0f | SecondMonitor1 %.0f UI units", Addon.db.enabled and "ACTIVE" or "DISABLED", layout.canvasWidth, layout.canvasHeight, layout.secondMonitor1.width))
    else
        self.status:SetText("Layout unavailable: " .. tostring(err))
    end
    self:ApplyTheme()
    if self.previewButton and self.keepPreviewButton then
        if self.previewActive then
            self.previewButton:Hide()
            self.keepPreviewButton:Show()
        else
            self.previewButton:Show()
            self.keepPreviewButton:Hide()
        end
    end
end

function Options:CancelPreview(restorePrevious)
    if not self.previewActive then return false end
    local wasEnabled = self.previewWasEnabled
    self.previewGeneration = (self.previewGeneration or 0) + 1
    self.previewActive = false
    self.previewWasEnabled = nil
    if self.previewButton then self.previewButton:Show() end
    if self.keepPreviewButton then self.keepPreviewButton:Hide() end
    if restorePrevious and not wasEnabled and Addon.db and Addon.db.enabled then
        Addon:SetEnabled(false)
    end
    if self.frame then self:Refresh() end
    return true
end

function Options:StartPreview()
    if self.previewActive then return false end
    if InCombatLockdown and InCombatLockdown() then
        Addon:Print("Preview unavailable during combat.")
        return false
    end
    if not C_Timer or type(C_Timer.After) ~= "function" then
        Addon:Print("Preview unavailable: client timer API is missing.")
        return false
    end
    self.previewGeneration = (self.previewGeneration or 0) + 1
    local generation = self.previewGeneration
    self.previewWasEnabled = Addon.db and Addon.db.enabled == true or false
    local applied
    if not Addon.db.enabled then applied = Addon:SetEnabled(true) else applied = Addon:Apply() end
    if applied ~= true then
        self.previewWasEnabled = nil
        self:Refresh()
        Addon:Print("Preview could not start; layout apply failed.")
        return false
    end
    self.previewActive = true
    self:Refresh()
    self.status:SetText("PREVIEW ACTIVE - confirm within 15 seconds or it will revert.")
    C_Timer.After(15, function()
        if not self.previewActive or self.previewGeneration ~= generation then return end
        local restoreDisabled = not self.previewWasEnabled
        self:CancelPreview(false)
        if restoreDisabled then Addon:SetEnabled(false) end
        self:Refresh()
        Addon:Print("Preview expired; previous layout state restored.")
    end)
    return true
end

function Options:KeepPreview()
    if not self.previewActive then return false end
    local applied
    if Addon.db and not Addon.db.enabled then applied = Addon:SetEnabled(true) else applied = Addon:Apply() end
    if applied ~= true then
        self:CancelPreview(true)
        Addon:Print("Preview confirmation failed; layout restored.")
        return false
    end
    self.previewGeneration = (self.previewGeneration or 0) + 1
    self.previewActive = false
    self.previewWasEnabled = nil
    if self.previewButton then self.previewButton:Show() end
    if self.keepPreviewButton then self.keepPreviewButton:Hide() end
    self:Refresh()
    Addon:Print("Layout preview confirmed.")
    return true
end

local WIZARD_STEPS = {
    {
        title = "Setup 1 / 3 - Window",
        body = [=[Prepare the Windows game window first.

1. Set WoW to Windowed mode.
2. Run WindowsHelper list and identify the displays.
3. Use WindowsHelper place with the selected display names.

The helper saves the original window state. Run restore when you want to return to the original window placement.]=],
    },
    {
        title = "Setup 2 / 3 - MainMonitor",
        body = [=[Choose which side contains MainMonitor and set its share of the combined logical canvas. The remaining area becomes SecondMonitor1. You can change these values later in the dashboard.]=],
    },
    {
        title = "Setup 3 / 3 - Apply",
        body = [=[Enable the layout to apply the viewport and route supported panels. Verify the 3D view and at least one supported panel in-game. Use Reset if the result is not correct.]=],
    },
}

function Options:RefreshWizard()
    if not self.wizard then return end
    local step = math.max(1, math.min(#WIZARD_STEPS, tonumber(self.wizardStep) or 1))
    self.wizardStep = step
    local page = WIZARD_STEPS[step]
    self.wizard.title:SetText(page.title)
    self.wizard.body:SetText(page.body)
    self.wizard.back.label:SetText(step == 1 and "Cancel" or "Back")
    self.wizard.next.label:SetText(step == #WIZARD_STEPS and "Finish" or "Next")
    if step == 2 then
        local profile = Addon:GetProfile()
        self.wizard.sideLeft.label:SetText(profile.mainMonitorSide == "left" and "[ MainMonitor left ]" or "MainMonitor left")
        self.wizard.sideRight.label:SetText(profile.mainMonitorSide == "right" and "[ MainMonitor right ]" or "MainMonitor right")
        self.wizard.widthSlider.slider:SetValue(profile.mainMonitorWidthPercent)
        self.wizard.config:Show()
    else
        self.wizard.config:Hide()
    end
    if step == 3 then
        self.wizard.enableButton:Show()
        self.wizard.enableButton.label:SetText(Addon.db.enabled and "Layout enabled" or "Enable layout")
    else
        self.wizard.enableButton:Hide()
    end
    local currentStep = step
    self.wizard.back:SetScript("OnClick", function()
        if currentStep == 1 then
            self.wizard:Hide()
            self.settings:Show()
        else
            self.wizardStep = currentStep - 1
            self:RefreshWizard()
        end
    end)
    self.wizard.next:SetScript("OnClick", function()
        if currentStep == #WIZARD_STEPS then
            self.wizard:Hide()
            self.settings:Show()
            return
        end
        self.wizardStep = currentStep + 1
        self:RefreshWizard()
    end)
    self:ApplyTheme()
end

function Options:ShowWizard()
    self:CancelPreview(true)
    if not self.wizard then
        local wizard = CreateFrame("Frame", nil, self.frame)
        wizard:SetPoint("TOPLEFT", 18, -52)
        wizard:SetPoint("BOTTOMRIGHT", -18, 54)
        if wizard.SetBackdrop then
            wizard:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 24, insets = { left = 8, right = 8, top = 8, bottom = 8 } })
        end
        wizard.title = makeText(wizard, "Setup 1 / 3 - Window", 18)
        wizard.title:SetPoint("TOPLEFT", 16, -16)
        wizard.body = makeText(wizard, "", 13)
        wizard.body:SetPoint("TOPLEFT", 16, -52)
        wizard.body:SetPoint("RIGHT", -16, 0)
        wizard.body:SetJustifyH("LEFT")
        wizard.body:SetJustifyV("TOP")

        wizard.config = CreateFrame("Frame", nil, wizard)
        wizard.config:SetPoint("TOPLEFT", 16, -190)
        wizard.config:SetSize(440, 120)
        wizard.sideLeft = makeButton(wizard.config, "MainMonitor left", 150, 28, function()
            Addon:SetProfileValue("mainMonitorSide", "left")
            self:RefreshWizard()
        end)
        wizard.sideLeft:SetPoint("TOPLEFT", 0, 0)
        wizard.sideRight = makeButton(wizard.config, "MainMonitor right", 150, 28, function()
            Addon:SetProfileValue("mainMonitorSide", "right")
            self:RefreshWizard()
        end)
        wizard.sideRight:SetPoint("TOPLEFT", 170, 0)
        wizard.widthSlider = makeSlider(wizard.config, "MainMonitor width", 25, 90, 1, function(v) return string.format("%.0f%%", v) end, function(v)
            Addon:SetProfileValue("mainMonitorWidthPercent", v)
        end)
        wizard.widthSlider:SetPoint("TOPLEFT", 0, -42)

        wizard.enableButton = makeButton(wizard, "Enable layout", 150, 30, function()
            Addon:SetEnabled(true)
            self:RefreshWizard()
        end)
        wizard.enableButton:SetPoint("BOTTOM", 0, 54)
        wizard.back = makeButton(wizard, "Cancel", 110, 28, function() end)
        wizard.back:SetPoint("BOTTOMLEFT", 12, 12)
        wizard.next = makeButton(wizard, "Next", 110, 28, function() end)
        wizard.next:SetPoint("BOTTOMRIGHT", -12, 12)
        wizard.config:Hide()
        wizard.enableButton:Hide()
        wizard:Hide()
        self.wizard = wizard
    end
    self.wizardStep = 1
    self:RefreshWizard()
    self.settings:Hide()
    self.wizard:Show()
end

function Options:RegisterCategory()
    if self.categoryRegistered then return true end
    local frame = self:Create()
    frame.name = "Forever MultiMonitor"

    if type(Settings) == "table"
        and type(Settings.RegisterCanvasLayoutCategory) == "function"
        and type(Settings.RegisterAddOnCategory) == "function" then
        local categoryCallOK, category = pcall(Settings.RegisterCanvasLayoutCategory, frame, frame.name)
        if categoryCallOK and category then
            local registered = pcall(Settings.RegisterAddOnCategory, category)
            if registered then
                self.settingsCategory = category
                self.categoryRegistered = true
                return true
            end
        end
    end

    if type(InterfaceOptions_AddCategory) == "function" then
        local registered, err = pcall(InterfaceOptions_AddCategory, frame)
        if registered then
            self.legacyCategory = frame
            self.categoryRegistered = true
            return true
        end
        self.categoryRegistrationError = tostring(err)
    end
    return false, self.categoryRegistrationError or "No supported AddOns settings category API is available."
end

function Options:OpenSettings()
    local frame = self:Create()
    if not self.categoryRegistered then self:RegisterCategory() end

    local category = self.settingsCategory
    local categoryId = category and (category.ID or category.id)
    if categoryId and type(Settings) == "table" and type(Settings.OpenToCategory) == "function" then
        local opened = pcall(Settings.OpenToCategory, categoryId)
        if opened then
            frame:Show()
            self:Refresh()
            return true
        end
    end

    if self.legacyCategory and type(InterfaceOptionsFrame_OpenToCategory) == "function" then
        local opened = pcall(InterfaceOptionsFrame_OpenToCategory, self.legacyCategory)
        if opened then
            frame:Show()
            self:Refresh()
            return true
        end
    end

    frame:Show()
    self:Refresh()
    return false
end

function Options:Create()
    if self.frame then return self.frame end
    local frame = CreateFrame("Frame", "ForeverMultiMonitorOptionsFrame", UIParent)
    frame.name = "Forever MultiMonitor"
    frame:SetSize(500, 610)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    if frame.SetClampedToScreen then frame:SetClampedToScreen(true) end
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    if frame.SetBackdrop then
        frame:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 24, insets = { left = 8, right = 8, top = 8, bottom = 8 } })
    else
        local bg = frame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.035, 0.045, 0.075, 0.98)
        frame.backgroundTexture = bg
    end
    local title = makeText(frame, "Forever MultiMonitor", 18)
    title:SetPoint("TOPLEFT", 20, -18)
    self.title = title
    local close = makeButton(frame, "X", 28, 24, function() frame:Hide() end)
    close:SetPoint("TOPRIGHT", -18, -14)
    self.status = makeText(frame, "", 11)
    self.status:SetPoint("TOPLEFT", 22, -48)
    self.enabledButton = makeButton(frame, "Enable layout", 150, 30, function()
        self:CancelPreview(false)
        Addon:SetEnabled(not Addon.db.enabled)
        self:Refresh()
    end)
    self.enabledButton:SetPoint("TOPLEFT", 22, -78)
    self.sideLeft = makeButton(frame, "MainMonitor left", 140, 28, function() Addon:SetProfileValue("mainMonitorSide", "left"); if Addon.db.enabled then Addon:Apply() end; self:Refresh() end)
    self.sideLeft:SetPoint("TOPLEFT", 190, -78)
    self.sideRight = makeButton(frame, "MainMonitor right", 140, 28, function() Addon:SetProfileValue("mainMonitorSide", "right"); if Addon.db.enabled then Addon:Apply() end; self:Refresh() end)
    self.sideRight:SetPoint("TOPLEFT", 340, -78)

    self.settings = CreateFrame("Frame", nil, frame)
    self.profileLabel = makeText(frame, "Profile: Default", 12)
    self.profileLabel:SetPoint("TOPLEFT", 22, -114)
    self.profileNameInput = CreateFrame("EditBox", nil, frame)
    self.profileNameInput:SetSize(122, 24)
    local profileNameLabel = makeText(frame, "Name", 10)
    profileNameLabel:SetPoint("TOPLEFT", 138, -114)
    self.profileNameInput:SetPoint("TOPLEFT", 138, -136)
    if self.profileNameInput.SetBackdrop then
        self.profileNameInput:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 8, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    else
        local inputBackground = self.profileNameInput:CreateTexture(nil, "BACKGROUND")
        inputBackground:SetAllPoints()
        inputBackground:SetColorTexture(0.08, 0.09, 0.13, 0.95)
    end
    self.profileNameInput:SetAutoFocus(false)
    if self.profileNameInput.SetFontObject then self.profileNameInput:SetFontObject(GameFontNormal) end
    if self.profileNameInput.SetTextInsets then self.profileNameInput:SetTextInsets(5, 5, 2, 2) end
    self.profileNameInput:SetText("")
    self.profileNameInput:SetScript("OnEnterPressed", function(input) input:ClearFocus() end)
    self.profileNewButton = makeButton(frame, "New", 58, 24, function()
        local ok, err = Addon:CreateProfile(self.profileNameInput:GetText())
        if not ok then Addon:Print(err) end
        self:Refresh()
    end)
    self.profileNewButton:SetPoint("TOPLEFT", 266, -136)
    self.profileLoadButton = makeButton(frame, "Load", 58, 24, function()
        local ok, err = Addon:SetActiveProfile(self.profileNameInput:GetText())
        if not ok then Addon:Print(err) end
        self:Refresh()
    end)
    self.profileLoadButton:SetPoint("TOPLEFT", 328, -136)
    self.profileDeleteButton = makeButton(frame, "Delete", 66, 24, function()
        if not Addon:DeleteProfile(self.profileNameInput:GetText()) then Addon:Print("Cannot delete Default, the active profile, or a missing profile.") end
        self:Refresh()
    end)
    self.profileDeleteButton:SetPoint("TOPLEFT", 390, -136)
    self.settings:SetPoint("TOPLEFT", 22, -170)
    self.settings:SetSize(450, 276)
    self.widthSlider = makeSlider(self.settings, "MainMonitor width", 25, 90, 1, function(v) return string.format("%.0f%%", v) end, function(v) Addon:SetProfileValue("mainMonitorWidthPercent", v) end)
    self.widthSlider:SetPoint("TOPLEFT", 0, 0)
    self.seamSlider = makeSlider(self.settings, "Seam offset (logical UI units)", 0, 100, 1, function(v) return string.format("%.0f", v) end, function(v) Addon:SetProfileValue("seamUiUnits", v) end)
    self.seamSlider:SetPoint("TOPLEFT", 0, -64)
    self.scaleSlider = makeSlider(self.settings, "Panel scale", 0.5, 1.5, 0.05, function(v) return string.format("%.2f", v) end, function(v) Addon:SetProfileValue("panelScale", v) end)
    self.scaleSlider:SetPoint("TOPLEFT", 0, -128)
    self.themeButton = makeButton(self.settings, "Theme: Midnight", 160, 28, function() self:CycleTheme() end)
    self.themeButton:SetPoint("TOPLEFT", 0, -190)
    self.backgroundOpacitySlider = makeSlider(self.settings, "Dashboard background opacity", 0.5, 1, 0.05, function(v) return string.format("%.0f%%", v * 100) end, function(v)
        Addon:SetProfileValue("backgroundOpacity", v)
        self:ApplyTheme()
    end, false)
    self.backgroundOpacitySlider:SetPoint("TOPLEFT", 0, -224)
    self.mapEscapeButton = makeButton(frame, "Map ESC: Keep open", 150, 28, function()
        Addon:SetProfileValue("mapStaysOpenOnEscape", not Addon:GetProfile().mapStaysOpenOnEscape)
        if Addon.MapEscape then Addon.MapEscape:Sync() end
        self:Refresh()
    end)
    self.mapEscapeButton:SetPoint("BOTTOMLEFT", 22, 134)
    self.nativeButton = makeButton(frame, "Calibrate from displays", 180, 28, function()
        local ok, message = Addon:UseNativeGeometry()
        Addon:Print(ok and message or ("Native calibration unavailable: " .. tostring(message)))
        self:Refresh()
    end)
    self.nativeButton:SetPoint("BOTTOMLEFT", 184, 134)
    self.rawMouseButton = makeButton(frame, "Raw mouse: ON", 150, 28, function()
        Addon:SetProfileValue("rawMouseEnabled", not Addon:GetProfile().rawMouseEnabled)
        if Addon.RawMouse then Addon.RawMouse:Sync() end
        self:Refresh()
    end)
    self.rawMouseButton:SetPoint("BOTTOMLEFT", 22, 58)
    self.wizardButton = makeButton(frame, "Setup wizard", 120, 28, function() self:ShowWizard() end)
    self.wizardButton:SetPoint("BOTTOMLEFT", 184, 58)
    self.applyButton = makeButton(frame, "Apply / Keep", 90, 28, function()
        if self.previewActive then self:KeepPreview() else Addon:Apply(); self:Refresh() end
    end)
    self.applyButton:SetPoint("BOTTOMRIGHT", -122, 58)
    self.resetButton = makeButton(frame, "Reset", 90, 28, function()
        self:CancelPreview(false)
        Addon:SetEnabled(false)
        self:Refresh()
    end)
    self.resetButton:SetPoint("BOTTOMRIGHT", -22, 58)
    self.previewButton = makeButton(frame, "Preview 15s", 100, 28, function() self:StartPreview() end)
    self.previewButton:SetPoint("BOTTOMLEFT", 22, 94)
    self.keepPreviewButton = makeButton(frame, "Keep layout", 110, 28, function() self:KeepPreview() end)
    self.keepPreviewButton:SetPoint("BOTTOMLEFT", 132, 94)
    self.keepPreviewButton:Hide()
    self.gatherButton = makeButton(frame, "Gather off-screen UI", 190, 28, function()
        if Addon.HandleCommand then Addon:HandleCommand("gather") end
    end)
    self.gatherButton:SetPoint("BOTTOMLEFT", 250, 94)
    local footer = makeText(frame, "/forevermultimonitor commands remain available. Native monitor control requires WindowsHelper.", 10)
    footer:SetPoint("BOTTOMLEFT", 22, 28)
    self.frame = frame
    UISpecialFrames = UISpecialFrames or {}
    table.insert(UISpecialFrames, "ForeverMultiMonitorOptionsFrame")
    self:Refresh()
    frame:Hide()
    return frame
end

function Options:Toggle()
    if not self.frame then self:Create() end
    if self.frame:IsShown() then self.frame:Hide() else self.frame:Show(); self:Refresh() end
end
