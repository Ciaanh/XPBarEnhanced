-- ControlHelpers.lua
-- Centralized helpers for checkbox and slider control setup in Options UI

local Addon = XPBarEnhanced
Addon.UI = Addon.UI or {}
Addon.UI.ControlHelpers = Addon.UI.ControlHelpers or {}

local ControlHelpers = {}
local Config = Addon.Config

-- Helper function to resolve locale keys (matches Options.lua)
local function ResolveLocale(key)
    return Addon.L and rawget(Addon.L, key) or key
end

-- Play sound helper from Options.lua
local PlaySound = rawget(_G, "PlaySound")
local SOUNDKIT = rawget(_G, "SOUNDKIT")
local function PlayCheckboxSound(checked)
    if PlaySound then
        local kit = SOUNDKIT and (checked and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        if kit then
            PlaySound(kit)
        end
    end
end

-- Shared checkbox click handler
local function CheckboxOnClick(selfFrame, checkbox, key)
    PlayCheckboxSound(checkbox:GetChecked())
    Config:SetOptionKey(key, checkbox:GetChecked(), true)
    -- A toggle that diverges from the active preset makes it Custom. Written
    -- silently so it batches into the ApplyPendingOptionChanges below and the
    -- whole change still emits exactly one CONFIG_UPDATED.
    local presets = Addon.ReadoutPresets
    if presets and presets:Owns(key) then
        presets:Resync()
    end
    if Config.ApplyPendingOptionChanges then
        Config:ApplyPendingOptionChanges()
    end
    -- Get fresh reference to Options module (avoids stale upvalue issue)
    local controller = Addon.Options
    if controller and controller.OnOptionChanged then
        controller:OnOptionChanged(key)
    else
        -- Fallback: attempt to call Refresh on the container where checkbox lives
        if selfFrame and selfFrame.Refresh then
            selfFrame:Refresh()
        end
    end
end

-- Shared slider value change handler
local function SliderOnValueChanged(selfFrame, slider, key, value)
    if slider.settingValue then
        return
    end
    Config:SetOptionKey(key, value, true)
    if Config.ApplyPendingOptionChanges then
        Config:ApplyPendingOptionChanges()
    end
    -- Get fresh reference to Options module (avoids stale upvalue issue)
    local controller = Addon.Options
    if controller and controller.OnOptionChanged then
        controller:OnOptionChanged(key)
    else
        if selfFrame and selfFrame.Refresh then
            selfFrame:Refresh()
        end
    end
end

--- Show `title` and `description` as a tooltip over each of `frames`. The
--- option templates have no OnEnter of their own, so without this no option
--- description (the *_DESC strings) was ever shown.
---@param frames table Frames to hover
---@param title string|nil
---@param description string|nil
function ControlHelpers.AttachTooltip(frames, title, description)
    if not description or description == "" then
        return
    end
    local function show(owner)
        GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
        GameTooltip:SetText(title or "", 1, 1, 1)
        GameTooltip:AddLine(description, nil, nil, nil, true)
        GameTooltip:Show()
    end
    local function hide(owner)
        if GameTooltip:GetOwner() == owner then
            GameTooltip:Hide()
        end
    end
    for _, frame in ipairs(frames) do
        if frame and frame.HookScript then
            frame:HookScript("OnEnter", show)
            frame:HookScript("OnLeave", hide)
        end
    end
end

-- Initialize a checkbox contained inside a row container (two-column layout)
function ControlHelpers.SetupTwoColumnCheckbox(selfFrame, row, key, detail)
    if not row or not row.Checkbox or not detail then
        return
    end
    local checkbox = row.Checkbox
    local label = row.Label

    -- Set label on the LEFT column
    if label and detail.label then
        label:SetText(detail.label)
    end

    -- Hide the checkbox's own built-in text to avoid duplication
    if checkbox.Text then
        checkbox.Text:SetText("")
        checkbox.Text:Hide()
    end

    ControlHelpers.AttachTooltip({row, checkbox}, detail.label, detail.description)

    -- Register click
    checkbox:SetScript("OnClick", function(btn) CheckboxOnClick(selfFrame, btn, key) end)
    if row.EnableMouse and row.SetScript then
        row:EnableMouse(true)
        row:SetScript("OnMouseUp", function(_, button)
            if button == "LeftButton" and checkbox:IsEnabled() and not checkbox:IsMouseOver() then
                checkbox:Click()
            end
        end)
    end

    -- Alias for refresh
    selfFrame.controls = selfFrame.controls or {}
    selfFrame.controls[key] = checkbox
end

-- Initialize a standalone checkbox where the checkbox provides its own text
function ControlHelpers.SetupCheckbox(selfFrame, checkbox, key, detail)
    if not checkbox or not detail then
        return
    end

    -- Ensure Text element
    if not checkbox.Text then
        checkbox.Text = checkbox:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        checkbox.Text:SetPoint("LEFT", checkbox, "RIGHT", 0, 0)
    end
    if checkbox.Text and checkbox.Text.SetText then
        checkbox.Text:SetText(detail.label)
    end

    ControlHelpers.AttachTooltip({checkbox}, detail.label, detail.description)

    checkbox:SetScript("OnClick", function(btn) CheckboxOnClick(selfFrame, btn, key) end)

    selfFrame.controls = selfFrame.controls or {}
    selfFrame.controls[key] = checkbox
end

-- Initialize a two-column slider (ConfigSliderTemplate)
function ControlHelpers.SetupProperSlider(selfFrame, row, key, detail)
    if not row or not row.Slider or not detail then
        return
    end

    local slider = row.Slider
    local label = row.Label

    -- Set label text
    if label and detail.label then
        label:SetText(detail.label)
    end

    if not row._xpbeTooltip then
        row._xpbeTooltip = true
        row:EnableMouse(true)
        ControlHelpers.AttachTooltip({row}, detail.label, detail.description)
    end

    -- Set current value now (useful as initial value for Init)
    local currentValue = Config:GetOptionValue(key)
    if type(currentValue) ~= "number" then
        currentValue = detail.min or 0
    end

    -- Setup slider only once (Init API may exist on custom slider mixin)
    if not slider.initialized then
        local minValue = detail.min or 0
        local maxValue = detail.max or 100
        local stepSize = detail.step or 1
        -- steps is the number of intervals: (max-min)/stepSize
        -- Blizzard calculates: actualStep = (max-min)/steps
        -- So for 20 to 100 with stepSize=5: steps = 80/5 = 16
        local steps = math.floor((maxValue - minValue) / stepSize)
        local formatStr = detail.format or "%.1f"
        -- MinimalSliderWithSteppersMixin.Init signature: Init(value, minValue, maxValue, steps, formatters)
        if slider.Init then
            slider:Init(currentValue, minValue, maxValue, steps, {
                [MinimalSliderWithSteppersMixin.Label.Right] = function(value)
                    return string.format(formatStr, value)
                end
            })

            slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
                SliderOnValueChanged(selfFrame, slider, key, value)
            end)
        else
            -- Fallback to simple Slider API
            slider:SetMinMaxValues(minValue, maxValue)
            slider:SetValueStep(stepSize)
            slider:SetScript("OnValueChanged", function(_, value)
                SliderOnValueChanged(selfFrame, slider, key, value)
            end)
        end

        slider.initialized = true
        slider.format = formatStr
    end

    -- Set current value while preserving programmatic flag
    -- currentValue was already computed above
    slider.settingValue = true
    if slider.SetValue then
        slider:SetValue(currentValue)
    end
    slider.settingValue = false

    selfFrame.sliders = selfFrame.sliders or {}
    selfFrame.sliders[key] = slider
end

-- Two-column dropdown setup (WowStyle1DropdownTemplate)
-- Uses radio buttons to show current selection with visual indicator
function ControlHelpers.SetupProperDropdown(selfFrame, row, key, detail)
    if not row or not row.Dropdown or not detail then
        return
    end

    local dropdown = row.Dropdown
    local label = row.Label

    -- Set label text
    if label and detail.label then
        label:SetText(detail.label)
    end

    if not row._xpbeTooltip then
        row._xpbeTooltip = true
        row:EnableMouse(true)
        ControlHelpers.AttachTooltip({row}, detail.label, detail.description)
    end

    -- Get current value for initial text
    local currentValue = Config:GetOptionValue(key)
    local initialText = nil
    if currentValue and detail.options then
        for _, option in ipairs(detail.options) do
            if option.value == currentValue then
                initialText = option.label
                break
            end
        end
    end

    -- Always rebuild menu on refresh to show correct selection
    if initialText and dropdown.SetDefaultText then
        dropdown:SetDefaultText(initialText)
    end

    dropdown:SetupMenu(
        function(dropdown, rootDescription)
            if not detail.options then
                return
            end
            
            for _, option in ipairs(detail.options) do
                -- Use CreateRadio to show radio button with selection indicator
                -- isSelected is a function that returns true if this option is current
                local isSelectedFunc = function()
                    local current = Config:GetOptionValue(key)
                    return current == option.value
                end
                
                -- Callback when option is selected
                local onSelectFunc = function()
                    Config:SetOptionKey(key, option.value, true)
                    if Config.ApplyPendingOptionChanges then
                        Config:ApplyPendingOptionChanges()
                    end
                    local controller = Addon.Options
                    if controller and controller.OnOptionChanged then
                        controller:OnOptionChanged(key)
                    end
                end
                
                -- Create radio button option (shows filled/unfilled radio based on selection)
                rootDescription:CreateRadio(option.label, isSelectedFunc, onSelectFunc)
            end
        end
    )

    selfFrame.dropdowns = selfFrame.dropdowns or {}
    selfFrame.dropdowns[key] = dropdown
end

-- Visual helper for color swatches
function ControlHelpers.SetupSwatchVisuals(swatch)
    if not swatch then
        return
    end
    if swatch.Background then
        swatch.Background:ClearAllPoints()
        swatch.Background:SetAllPoints()
        swatch.Background:SetColorTexture(0, 0, 0, 1)
    end
    if swatch.Texture then
        swatch.Texture:ClearAllPoints()
        swatch.Texture:SetPoint("TOPLEFT", swatch, "TOPLEFT", 2, -2)
        swatch.Texture:SetPoint("BOTTOMRIGHT", swatch, "BOTTOMRIGHT", -2, 2)
        swatch.Texture:SetColorTexture(1, 1, 1, 1)
    end
    if swatch.Highlight then
        swatch.Highlight:ClearAllPoints()
        swatch.Highlight:SetAllPoints()
        swatch.Highlight:SetColorTexture(1, 1, 1, 0.2)
    end
end

-- Preview setup (statusbar vs texture previews)
function ControlHelpers.SetupPreviewFrames(row, previewType)
    local statusPreview = row.StatusPreview
    local textureFrame = row.TexturePreview
    local texturePreview = textureFrame and textureFrame.Texture
    if statusPreview then
        statusPreview:Hide()
        statusPreview:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        statusPreview:SetMinMaxValues(0, 1)
        statusPreview:SetValue(1)
        if statusPreview.BackgroundTexture then
            statusPreview.BackgroundTexture:ClearAllPoints()
            statusPreview.BackgroundTexture:SetAllPoints()
        end
    end
    if textureFrame and texturePreview then
        textureFrame:Hide()
        texturePreview:ClearAllPoints()
        texturePreview:SetAllPoints()
        texturePreview:SetColorTexture(1, 1, 1, 1)
    end
    if previewType == "statusbar" and statusPreview then
        statusPreview:Show()
        return statusPreview, statusPreview.BackgroundTexture, "statusbar"
    elseif previewType == "texture" and textureFrame and texturePreview then
        textureFrame:Show()
        return texturePreview, nil, "texture"
    end
    if textureFrame and texturePreview then
        textureFrame:Show()
        return texturePreview, nil, "texture"
    end
    return nil, nil, previewType
end

-- Color row setup (color picker + swatch + preview)
function ControlHelpers.SetupColorRow(selfFrame, row, info)
    if not row or not info then
        return nil
    end
    if row.Label then
        row.Label:SetText(info.label)
        if row.Label.SetJustifyH then
            row.Label:SetJustifyH("LEFT")
        end
    end
    if row.Description then
        row.Description:SetText(info.description or "")
        if row.Description.SetJustifyH then
            row.Description:SetJustifyH("LEFT")
        end
        if row.Description.SetWordWrap then
            row.Description:SetWordWrap(true)
        end
        if row.Description.SetNonSpaceWrap then
            row.Description:SetNonSpaceWrap(true)
        end
    end
    if row.ValueText then
        if row.ValueText.SetJustifyH then
            row.ValueText:SetJustifyH("LEFT")
        end
        if row.ValueText.SetWordWrap then
            row.ValueText:SetWordWrap(false)
        end
    end

    local swatch = row.Swatch
    ControlHelpers.SetupSwatchVisuals(swatch)
    local preview, previewBackground, effectivePreviewType = ControlHelpers.SetupPreviewFrames(row, info.preview or "texture")
    local controls = {
        info = info,
        row = row,
        swatch = swatch,
        swatchTexture = swatch and swatch.Texture or nil,
        previewType = effectivePreviewType or info.preview or "texture",
        preview = preview,
        previewBackground = previewBackground,
        valueText = row.ValueText
    }
    if swatch then
        swatch:SetScript("OnClick", function()
            if IsShiftKeyDown and IsShiftKeyDown() then
                Config:ResetColor(info.key, true)
                if Config.ApplyPendingOptionChanges then
                    Config:ApplyPendingOptionChanges()
                end
                local controller = Addon.Options
                if controller and controller.OnColorReset then
                    controller:OnColorReset(info.key)
                else
                    selfFrame:UpdateColorControls()
                end
                return
            end
            selfFrame:OpenColorPicker(info.key)
        end)

        swatch:SetScript("OnEnter", function(widget)
            GameTooltip:SetOwner(widget, "ANCHOR_RIGHT")
            GameTooltip:AddLine(string.format(ResolveLocale("OPT_COLOR_SWATCH_TITLE_FMT"), info.label), 1, 1, 1)
            if info.description and info.description ~= "" then
                GameTooltip:AddLine(info.description, 0.8, 0.8, 0.8, true)
            end
            GameTooltip:AddLine(ResolveLocale("OPT_COLOR_SWATCH_RESET_HINT"), 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
        swatch:SetScript("OnLeave", function() GameTooltip:Hide() end)

        local hasColorPicker = ColorPickerFrame or rawget(_G, "OpenColorPicker")
        if not hasColorPicker then
            swatch:Disable()
            swatch:SetAlpha(0.5)
        else
            swatch:Enable()
            swatch:SetAlpha(1)
        end
    end
    return controls
end

Addon.UI.ControlHelpers = ControlHelpers
return ControlHelpers
