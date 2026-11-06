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

local function makeSlider(parent, labelText, minValue, maxValue, step, formatValue, onChange)
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
    slider:SetScript("OnMouseUp", function() if Addon.db and Addon.db.enabled then Addon:Apply() end; if Addon.Options then Addon.Options:Refresh() end end)
    container.slider = slider
    container.valueText = valueText
    container.formatValue = formatValue
    return container
end

function Options:Refresh()
    if not self.frame or not Addon.db then return end
    local profile = Addon:GetProfile()
    self.enabledButton.label:SetText(Addon.db.enabled and "Disable layout" or "Enable layout")
    self.sideLeft.label:SetText(profile.mainhandSide == "left" and "[ Mainhand left ]" or "Mainhand left")
    self.sideRight.label:SetText(profile.mainhandSide == "right" and "[ Mainhand right ]" or "Mainhand right")
    self.rawMouseButton.label:SetText("Raw mouse: " .. (profile.rawMouseEnabled and "ON" or "OFF"))
    self.profileLabel:SetText("Profile: " .. Addon:GetActiveProfileName() .. " (" .. tostring(#Addon:GetProfileNames()) .. ")")
    self.widthSlider.slider:SetValue(profile.mainhandWidthPercent)
    self.seamSlider.slider:SetValue(profile.seamUiUnits)
    self.scaleSlider.slider:SetValue(profile.panelScale)
    local layout, err = Addon.Geometry:Calculate(profile)
    if layout then
        self.status:SetText(string.format("%s | Canvas %.0f x %.0f | Offhand %.0f UI units", Addon.db.enabled and "ACTIVE" or "DISABLED", layout.canvasWidth, layout.canvasHeight, layout.workspace.width))
    else
        self.status:SetText("Layout unavailable: " .. tostring(err))
    end
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
    if not C_Timer or type(C_Timer.After) ~= "function" then
        Addon:Print("Preview unavailable: client timer API is missing.")
        return false
    end
    self.previewGeneration = (self.previewGeneration or 0) + 1
    local generation = self.previewGeneration
    self.previewWasEnabled = Addon.db and Addon.db.enabled == true or false
    self.previewActive = true
    if not Addon.db.enabled then Addon:SetEnabled(true) else Addon:Apply() end
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
    self.previewGeneration = (self.previewGeneration or 0) + 1
    self.previewActive = false
    self.previewWasEnabled = nil
    if self.previewButton then self.previewButton:Show() end
    if self.keepPreviewButton then self.keepPreviewButton:Hide() end
    if Addon.db and not Addon.db.enabled then Addon:SetEnabled(true) else Addon:Apply() end
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
        title = "Setup 2 / 3 - Mainhand",
        body = [=[Choose which side contains the Mainhand view and set its share of the combined logical canvas. The remaining area becomes the Offhand workspace. You can change these values later in the dashboard.]=],
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
        self.wizard.sideLeft.label:SetText(profile.mainhandSide == "left" and "[ Mainhand left ]" or "Mainhand left")
        self.wizard.sideRight.label:SetText(profile.mainhandSide == "right" and "[ Mainhand right ]" or "Mainhand right")
        self.wizard.widthSlider.slider:SetValue(profile.mainhandWidthPercent)
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
        wizard.sideLeft = makeButton(wizard.config, "Mainhand left", 150, 28, function()
            Addon:SetProfileValue("mainhandSide", "left")
            self:RefreshWizard()
        end)
        wizard.sideLeft:SetPoint("TOPLEFT", 0, 0)
        wizard.sideRight = makeButton(wizard.config, "Mainhand right", 150, 28, function()
            Addon:SetProfileValue("mainhandSide", "right")
            self:RefreshWizard()
        end)
        wizard.sideRight:SetPoint("TOPLEFT", 170, 0)
        wizard.widthSlider = makeSlider(wizard.config, "Mainhand width", 25, 90, 1, function(v) return string.format("%.0f%%", v) end, function(v)
            Addon:SetProfileValue("mainhandWidthPercent", v)
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

function Options:Create()
    if self.frame then return self.frame end
    local frame = CreateFrame("Frame", "ForeverMultiMonitorOptionsFrame", UIParent)
    frame:SetSize(500, 500)
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
    end
    local title = makeText(frame, "Forever MultiMonitor", 18)
    title:SetPoint("TOPLEFT", 20, -18)
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
    self.sideLeft = makeButton(frame, "Mainhand left", 140, 28, function() Addon:SetProfileValue("mainhandSide", "left"); if Addon.db.enabled then Addon:Apply() end; self:Refresh() end)
    self.sideLeft:SetPoint("TOPLEFT", 190, -78)
    self.sideRight = makeButton(frame, "Mainhand right", 140, 28, function() Addon:SetProfileValue("mainhandSide", "right"); if Addon.db.enabled then Addon:Apply() end; self:Refresh() end)
    self.sideRight:SetPoint("TOPLEFT", 340, -78)

    self.settings = CreateFrame("Frame", nil, frame)
    self.profileLabel = makeText(frame, "Profile: Default", 12)
    self.profileLabel:SetPoint("TOPLEFT", 22, -114)
    self.profileNameInput = CreateFrame("EditBox", nil, frame)
    self.profileNameInput:SetSize(122, 24)
    local profileNameLabel = makeText(frame, "Name", 10)
    profileNameLabel:SetPoint("TOPLEFT", 140, -94)
    self.profileNameInput:SetPoint("TOPLEFT", 138, -108)
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
    self.profileNewButton:SetPoint("TOPLEFT", 266, -108)
    self.profileLoadButton = makeButton(frame, "Load", 58, 24, function()
        local ok, err = Addon:SetActiveProfile(self.profileNameInput:GetText())
        if not ok then Addon:Print(err) end
        self:Refresh()
    end)
    self.profileLoadButton:SetPoint("TOPLEFT", 328, -108)
    self.profileDeleteButton = makeButton(frame, "Delete", 66, 24, function()
        if not Addon:DeleteProfile(self.profileNameInput:GetText()) then Addon:Print("Cannot delete Default, the active profile, or a missing profile.") end
        self:Refresh()
    end)
    self.profileDeleteButton:SetPoint("TOPLEFT", 390, -108)
    self.settings:SetPoint("TOPLEFT", 22, -146)
    self.settings:SetSize(450, 250)
    self.widthSlider = makeSlider(self.settings, "Mainhand width", 25, 90, 1, function(v) return string.format("%.0f%%", v) end, function(v) Addon:SetProfileValue("mainhandWidthPercent", v) end)
    self.widthSlider:SetPoint("TOPLEFT", 0, 0)
    self.seamSlider = makeSlider(self.settings, "Seam offset (logical UI units)", 0, 100, 1, function(v) return string.format("%.0f", v) end, function(v) Addon:SetProfileValue("seamUiUnits", v) end)
    self.seamSlider:SetPoint("TOPLEFT", 0, -64)
    self.scaleSlider = makeSlider(self.settings, "Panel scale", 0.5, 1.5, 0.05, function(v) return string.format("%.2f", v) end, function(v) Addon:SetProfileValue("panelScale", v) end)
    self.scaleSlider:SetPoint("TOPLEFT", 0, -128)
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
    local footer = makeText(frame, "/fmm commands remain available. Native monitor control requires WindowsHelper.", 10)
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