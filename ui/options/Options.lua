---@diagnostic disable: undefined-global
-- XP Bar Enhanced Options Panel
local Addon = XPBarEnhanced

Addon.Options = {}
local Options = Addon.Options
local Config = Addon.Config
local EventNames = Addon.EventNames

-- Helper function to resolve locale keys from Config
local function ResolveLocale(key)
    return Addon.L and Addon.L[key] or key
end

-- Expose via multiple namespaces for compatibility
Addon.UI = Addon.UI or {}
Addon.App = Addon.App or {}

local _G = _G
local Settings = rawget(_G, "Settings")
local InterfaceOptions_AddCategory = rawget(_G, "InterfaceOptions_AddCategory")
local InterfaceOptionsFrame_OpenToCategory = rawget(_G, "InterfaceOptionsFrame_OpenToCategory")
local ColorPickerFrame = rawget(_G, "ColorPickerFrame")
local OpacitySliderFrame = rawget(_G, "OpacitySliderFrame")
local StaticPopup_Show = rawget(_G, "StaticPopup_Show")
local StaticPopupDialogs = rawget(_G, "StaticPopupDialogs")
local CreateFrame = rawget(_G, "CreateFrame")
local MenuTemplates = rawget(_G, "MenuTemplates")
local MenuVariants = rawget(_G, "MenuVariants")

local PANEL_NAME = ResolveLocale("ADDON_NAME")
local PROFILE_CREATE_POPUP = "XPBE_CREATE_PROFILE"
local PROFILE_RENAME_POPUP = "XPBE_RENAME_PROFILE"
local PROFILE_DELETE_POPUP = "XPBE_DELETE_PROFILE"

local XPBarEnhancedOptionsMixin = {}

-- Rows the active style cannot render, keyed by config key then style name, with
-- the locale key of the muted reason to show. A style absent from a row's table
-- can use that row. Such rows are disabled with the reason rather than hidden:
-- a control that vanishes teaches nothing about which style owns the feature.
local UNAVAILABLE_BY_STYLE = {
    flashOnGain        = {none = "OPT_UNAVAIL_NO_BAR"},
    twoPhaseOnLevelUp  = {none = "OPT_UNAVAIL_NO_BAR"},
    levelUpCelebration = {none = "OPT_UNAVAIL_NO_BAR"},
    barLocked          = {none = "OPT_UNAVAIL_NO_BAR"},
}

-- Rows that configure exactly one bar style. Under any other style the row is
-- disabled and labelled "<Style> only" rather than hidden, so the row count and
-- scroll height stay constant across all eight styles and the player learns that
-- e.g. Segment count belongs to Circular instead of finding it simply absent.
local ROW_OWNER_STYLE = {
    flatSize                    = "flat",
    showMilestoneTicks          = "flat",
    verticalSize                = "vertical",
    classicBarDraggable         = "classic",
    circularSize                = "circular",
    circularSegments            = "circular",
    circularUseTexture          = "circular",
    circularScaleCenterText     = "circular",
    circularSecondaryFullCircle = "circular",
    minimapRingPadding          = "minimap_ring",
    minimapRingSegments         = "minimap_ring",
    minimapRingCollectButtons   = "minimap_ring",
    minimapRingSegmentWidth     = "minimap_ring",
    minimapRingSegmentHeight    = "minimap_ring",
    minimapArcStartExpanded     = "minimap_ring",
    terminalUseCustomColors     = "terminal",
    sigilSkin                   = "sigil",
    sigilSize                   = "sigil",
    sigilTierMode               = "sigil",
    sigilPinnedTier             = "sigil",
    sigilUseClassColor          = "sigil",
}

-- Rows suppressed entirely rather than disabled, because there is nothing to
-- choose. sigilSkin offers exactly one value while halo is the only other skin
-- and halo is internal, so the dropdown would be a control with a single item.
-- Once a second selectable skin exists this returns false and the row appears
-- with no other change.
local function IsRowSuppressed(key)
    if key ~= "sigilSkin" then
        return false
    end
    local skins = Addon.SigilSkins
    local selectable = skins and skins.GetSelectable and skins:GetSelectable()
    return not selectable or #selectable < 2
end

-- The Colors tab carries one swatch per secondary-bar source, but only one source
-- is ever on screen. The active source's swatch stays out in the open; the other
-- three fold into a disclosure and read as inactive.
local SECONDARY_COLOR_GROUP = "othersources"
local SECONDARY_SOURCE_COLOR = {
    reputation = "secondaryReputation",
    housing = "secondaryHousing",
    honor = "secondaryHonor",
    profession = "secondaryProfession",
}

-- layoutIndex slots for those four rows. The active source's swatch takes the
-- slot ahead of the OtherSourcesDisclosure header (50.15) so it never reads as
-- part of the folded group; the other three keep their relative order behind it.
local SECONDARY_COLOR_ACTIVE_SLOT = 50.1
local SECONDARY_COLOR_FOLDED_SLOTS = {50.2, 50.3, 50.4}

-- Initial expanded state per disclosure group; anything unlisted starts collapsed.
local DISCLOSURE_DEFAULT_OPEN = {
    -- A player already on a custom readout came for the individual toggles, so
    -- folding them away would hide what they opened the panel to change.
    advanced = function()
        local presets = Addon.ReadoutPresets
        return (presets and presets:Detect() == presets.CUSTOM) and true or false
    end,
}

--- Short display name of a bar style, from the barStyle option list.
--- Short, not long: "— Circular only" reads better than
--- "— Circular (Progress ring) only", and it also fits the gallery's status line.
---@param styleValue string
---@return string
local function GetStyleLabel(styleValue)
    local detail = Config.optionDetails and Config.optionDetails.barStyle
    for _, option in ipairs((detail and detail.options) or {}) do
        if option.value == styleValue then
            return option.shortLabel or option.label
        end
    end
    return styleValue
end

local function clamp01(value)
    if not value then
        return 0
    end
    if value < 0 then
        return 0
    end
    if value > 1 then
        return 1
    end
    return value
end

local function rgbToHex(r, g, b, a)
    local function comp(v)
        return math.floor(clamp01(v) * 255 + 0.5)
    end

    return string.format("%02X%02X%02X%02X", comp(r), comp(g), comp(b), comp(a ~= nil and a or 1))
end

---Collects immediate children of a container indexed by their `configKey` field
local function CollectChildrenByConfigKey(container)
    if not container then
        return {}
    end

    local framesByKey = {}
    local children = {container:GetChildren()}
    for _, child in ipairs(children) do
        local key = child and child.configKey
        if key then
            framesByKey[key] = child
        end
    end

    return framesByKey
end

local function GetProfileDisplayName(profileName)
    return profileName or ResolveLocale("OPT_PROFILE_GLOBAL")
end

local function GetPopupEditBox(popup)
    if not popup then
        return nil
    end

    return popup.editBox or _G[popup:GetName() .. "EditBox"]
end

local function EnsureProfilePopups()
    if not StaticPopupDialogs then
        return
    end

    if not StaticPopupDialogs[PROFILE_CREATE_POPUP] then
        StaticPopupDialogs[PROFILE_CREATE_POPUP] = {
            text = ResolveLocale("OPT_PROFILE_CREATE_DIALOG"),
            button1 = ACCEPT,
            button2 = CANCEL,
            hasEditBox = 1,
            maxLetters = 32,
            timeout = 0,
            whileDead = 1,
            hideOnEscape = 1,
            preferredIndex = 3,
            OnShow = function(popup, data)
                local editBox = GetPopupEditBox(popup)
                if editBox then
                    editBox:SetText((data and data.initialText) or "")
                    editBox:HighlightText()
                    editBox:SetFocus()
                end
            end,
            EditBoxOnEnterPressed = function(editBox)
                local popup = editBox:GetParent()
                if popup and popup.button1 and popup.button1:IsEnabled() then
                    popup.button1:Click()
                end
            end,
            OnAccept = function(popup)
                local editBox = GetPopupEditBox(popup)
                local value = editBox and editBox:GetText() or nil
                if Addon.Options and Addon.Options.AcceptCreateProfileDialog then
                    Addon.Options:AcceptCreateProfileDialog(value)
                end
            end,
        }
    end

    if not StaticPopupDialogs[PROFILE_RENAME_POPUP] then
        StaticPopupDialogs[PROFILE_RENAME_POPUP] = {
            text = ResolveLocale("OPT_PROFILE_RENAME_DIALOG"),
            button1 = ACCEPT,
            button2 = CANCEL,
            hasEditBox = 1,
            maxLetters = 32,
            timeout = 0,
            whileDead = 1,
            hideOnEscape = 1,
            preferredIndex = 3,
            OnShow = function(popup, data)
                local editBox = GetPopupEditBox(popup)
                if editBox then
                    editBox:SetText((data and data.initialText) or "")
                    editBox:HighlightText()
                    editBox:SetFocus()
                end
            end,
            EditBoxOnEnterPressed = function(editBox)
                local popup = editBox:GetParent()
                if popup and popup.button1 and popup.button1:IsEnabled() then
                    popup.button1:Click()
                end
            end,
            OnAccept = function(popup, data)
                local editBox = GetPopupEditBox(popup)
                local value = editBox and editBox:GetText() or nil
                if Addon.Options and Addon.Options.AcceptRenameProfileDialog then
                    Addon.Options:AcceptRenameProfileDialog(data and data.oldName, value)
                end
            end,
        }
    end

    if not StaticPopupDialogs[PROFILE_DELETE_POPUP] then
        StaticPopupDialogs[PROFILE_DELETE_POPUP] = {
            text = "%s",
            button1 = DELETE,
            button2 = CANCEL,
            timeout = 0,
            whileDead = 1,
            hideOnEscape = 1,
            preferredIndex = 3,
            OnAccept = function(_popup, data)
                if Addon.Options and Addon.Options.AcceptDeleteProfileDialog then
                    Addon.Options:AcceptDeleteProfileDialog(data and data.profileName)
                end
            end,
        }
    end
end

-- ControlHelpers is used for centralized option control setup
local ControlHelpers = Addon.UI.ControlHelpers

-- Tab definitions in display order
local TABS = {
    {id = "visual",    label = ResolveLocale("OPT_TAB_VISUAL")},
    {id = "text",      label = ResolveLocale("OPT_TAB_TEXT")},
    {id = "behavior",  label = ResolveLocale("OPT_TAB_BEHAVIOR")},
    {id = "secondary", label = ResolveLocale("OPT_TAB_SECONDARY")},
    {id = "colors",    label = ResolveLocale("OPT_TAB_COLORS")},
}

function XPBarEnhancedOptionsMixin:SelectTab(tabId)
    self._activeTab = tabId

    -- Update tab button states and explicitly fix frame level ordering so the
    -- selected tab is always drawn on top of its neighbours regardless of XML order.
    if self.TabContainer then
        local baseLevel = self.TabContainer:GetFrameLevel()
        for _, tab in ipairs(TABS) do
            local btn = self.TabContainer["Tab_" .. tab.id]
            if btn then
                if tab.id == tabId then
                    PanelTemplates_SelectTab(btn)
                    btn:SetFrameLevel(baseLevel + 3)
                else
                    PanelTemplates_DeselectTab(btn)
                    btn:SetFrameLevel(baseLevel + 1)
                end
            end
        end
    end

    -- Re-tag the secondary swatches before showing them: which one is active can
    -- have changed on another tab, and the newly active row is one that was
    -- folded away still labelled inactive.
    if tabId == "colors" then
        self:RefreshSecondaryColorRows()
    end

    -- Show/hide container children by their optionTab attribute
    local container = self.ContentFrame and self.ContentFrame.OptionsContainer
    if not container then return end

    local children = {container:GetChildren()}
    for _, child in ipairs(children) do
        local childTab = child and child.optionTab
        if childTab then
            -- A row is visible only if: correct tab AND its disclosure group
            -- (if any) is expanded. Bar style never hides a row — see
            -- RefreshRowAvailability, which enables or disables instead.
            local tabMatch = (childTab == tabId)
            local disclosureOk = self:IsDisclosureExpanded(self:GetEffectiveDisclosureGroup(child))
            child:SetShown(tabMatch and disclosureOk)
        end
    end

    -- Re-run vertical layout so hidden rows collapse
    if container.Layout then
        container:Layout()
    end

    -- Recalculate scroll height
    self:RefreshScrollLayout()
end

function XPBarEnhancedOptionsMixin:SetupTabs()
    if not self.TabContainer then return end
    local tabId = 1
    for _, tab in ipairs(TABS) do
        local btn = self.TabContainer["Tab_" .. tab.id]
        if btn then
            btn:SetText(tab.label)
            btn:SetScript("OnClick", function()
                self:SelectTab(tab.id)
            end)
            PanelTemplates_DeselectTab(btn)
            btn.id = tabId
            tabId = tabId + 1
        end
    end
    -- Set numTabs directly; PanelTemplates_SetNumTabs is not used because it calls
    -- PanelTemplates_AnchorTabs which expects frame["Tab1"]/["Tab2"]/... keys,
    -- but our tabs are children of TabContainer with string IDs. XML already anchors them.
    self.numTabs = #TABS
end

function XPBarEnhancedOptionsMixin:BuildProfileDropdownMenu(rootDescription)
    -- Global Settings (nil profile) as a radio entry
    local globalIsSelected = function() return Config:GetActiveProfileName() == nil end
    local globalOnSelect = function()
        if Addon.Config and Addon.Config.SelectProfile then
            Addon.Config:SelectProfile(nil)
        end
    end
    rootDescription:CreateRadio(GetProfileDisplayName(nil), globalIsSelected, globalOnSelect)

    -- Named profiles — each gets inline gear (rename) + cancel (delete) on hover
    local names = Config:GetProfileNames() or {}
    for _, profileName in ipairs(names) do
        local name = profileName  -- capture for closures

        local isSelected = function() return Config:GetActiveProfileName() == name end
        local onSelect = function()
            if Addon.Config and Addon.Config.SelectProfile then
                Addon.Config:SelectProfile(name)
            end
        end

        local radio = rootDescription:CreateRadio(name, isSelected, onSelect)

        if MenuTemplates and MenuVariants then
            radio:AddInitializer(function(button, description, menu)
                local gearButton = MenuTemplates.AttachAutoHideGearButton(button)
                MenuTemplates.SetUtilityButtonTooltipText(gearButton, ResolveLocale("OPT_PROFILE_RENAME"))
                MenuTemplates.SetUtilityButtonAnchor(gearButton, MenuVariants.GearButtonAnchor, button)
                MenuTemplates.SetUtilityButtonClickHandler(gearButton, function()
                    self:ShowRenameProfilePrompt(name)
                    menu:Close()
                end)

                local cancelButton = MenuTemplates.AttachAutoHideCancelButton(button)
                MenuTemplates.SetUtilityButtonTooltipText(cancelButton, ResolveLocale("OPT_PROFILE_DELETE"))
                MenuTemplates.SetUtilityButtonAnchor(cancelButton, MenuVariants.CancelButtonAnchor, gearButton)
                MenuTemplates.SetUtilityButtonClickHandler(cancelButton, function()
                    self:ShowDeleteProfilePrompt(name)
                    menu:Close()
                end)
            end)
        end
    end

    -- Divider then bottom-row actions
    rootDescription:CreateDivider()
    rootDescription:CreateButton(ResolveLocale("OPT_PROFILE_NEW"), function()
        self:ShowCreateProfilePrompt()
    end)
end

function XPBarEnhancedOptionsMixin:EnsureProfileControls()
    if self._profileControlsBuilt then
        return
    end

    if not self then
        return
    end

    EnsureProfilePopups()

    local selectorRow = self.ProfileSelectorRow
    if not selectorRow then
        return
    end

    if selectorRow.Label and selectorRow.Label.SetText then
        selectorRow.Label:Show()
        selectorRow.Label:SetText(ResolveLocale("OPT_PROFILE_SELECTOR"))
    end

    if selectorRow.Dropdown then
        selectorRow.Dropdown:SetupMenu(function(_dropdown, rootDescription)
            self:BuildProfileDropdownMenu(rootDescription)
        end)
    end

    self.profileControls = {
        selectorRow = selectorRow,
        dropdown = selectorRow.Dropdown,
    }
    self._profileControlsBuilt = true
end

function XPBarEnhancedOptionsMixin:RefreshProfileControls()
    local controls = self.profileControls
    if not controls then
        return
    end

    local activeProfile = Config:GetActiveProfileName()
    if controls.dropdown and controls.dropdown.SetDefaultText then
        controls.dropdown:SetDefaultText(GetProfileDisplayName(activeProfile))
    end
end

function XPBarEnhancedOptionsMixin:ShowCreateProfilePrompt()
    if StaticPopup_Show then
        StaticPopup_Show(PROFILE_CREATE_POPUP, nil, nil, { initialText = "" })
    end
end

function XPBarEnhancedOptionsMixin:ShowRenameProfilePrompt(profileName)
    local name = profileName or Config:GetActiveProfileName()
    if not name then
        return
    end

    if StaticPopup_Show then
        StaticPopup_Show(PROFILE_RENAME_POPUP, nil, nil, { oldName = name, initialText = name })
    end
end

function XPBarEnhancedOptionsMixin:ShowDeleteProfilePrompt(profileName)
    local name = profileName or Config:GetActiveProfileName()
    if not name then
        return
    end

    if StaticPopup_Show then
        StaticPopup_Show(
            PROFILE_DELETE_POPUP,
            string.format(ResolveLocale("OPT_PROFILE_DELETE_DIALOG"), name),
            nil,
            { profileName = name }
        )
    end
end

function XPBarEnhancedOptionsMixin:OnLoad()
    Options.frame = self
    self.controls = {}
    self.colorControls = {}
    self.radioGroups = {}

    -- ContentFrame is now a child of ScrollBox in XML
    -- Access it through ScrollBox
    self.ContentFrame = self.ScrollBox.ContentFrame
    local scrollChild = self.ContentFrame

    -- DYNAMIC SCROLLBOX SETUP:
    -- Calculate content height dynamically based on actual content
    local optionsPanel = self
    local function CalculateContentHeight()
        local contentTop = scrollChild:GetTop()
        if not contentTop then
            -- Not laid out yet (OnLoad); use a provisional extent, the
            -- deferred refresh below re-queries once rects are valid
            return 800
        end

        -- Find the bottom-most shown element to determine actual content height
        local bottomY = 0
        local function consider(element)
            if element and element.IsShown and element:IsShown() and element.GetBottom then
                local bottom = element:GetBottom()
                if bottom then
                    local extent = contentTop - bottom
                    if extent > bottomY then
                        bottomY = extent
                    end
                end
            end
        end

        for _, child in ipairs({scrollChild:GetChildren()}) do
            consider(child)
        end
        if scrollChild.GetRegions then
            for _, region in ipairs({scrollChild:GetRegions()}) do
                consider(region)
            end
        end

        -- At least fill the viewport, plus 40px bottom padding for the content
        local minHeight = (optionsPanel.ScrollBox and optionsPanel.ScrollBox:GetHeight()) or 0
        if minHeight <= 0 then
            minHeight = 400
        end
        return math.max(bottomY + 40, minHeight)
    end

    -- Use the modern ScrollBox API with ContentFrame as the scroll target
    local view = CreateScrollBoxListLinearView()
    view:SetPanExtent(100) -- Mousewheel scroll amount

    -- Store reference for dynamic updates
    self.scrollView = view
    self.calculateContentHeight = CalculateContentHeight

    view:SetElementExtentCalculator(
        function(dataIndex, elementData)
            -- Recalculate each time for dynamic sizing
            return CalculateContentHeight()
        end
    )

    -- Simple factory that references our existing ContentFrame
    view:SetElementFactory(
        function(factory, elementData)
            factory(
                "Frame",
                function(frame, elementData)
                    if not frame.initialized then
                        -- Just set the frame to match ContentFrame's size
                        frame:SetSize(scrollChild:GetWidth(), CalculateContentHeight())
                        -- Make ContentFrame visible within this frame
                        scrollChild:ClearAllPoints()
                        scrollChild:SetAllPoints(frame)
                        frame.initialized = true
                    end
                end
            )
        end
    )

    -- Create data provider with one element
    local dataProvider = CreateDataProvider()
    dataProvider:Insert({id = "content"})

    -- Initialize ScrollBox and ScrollBar
    ScrollUtil.InitScrollBoxListWithScrollBar(self.ScrollBox, self.ScrollBar, view)
    self.ScrollBox:SetDataProvider(dataProvider)
    self.ScrollBox:SetScrollPercentage(0, ScrollBoxConstants.NoScrollInterpolation)

    -- Schedule a layout update after the frame is fully loaded
    C_Timer.After(0.1, function()
        if self.ScrollBox and self.ScrollBox:GetDataProvider() then
            self.ScrollBox:GetDataProvider():Flush()
            self.ScrollBox:SetDataProvider(dataProvider)
        end
    end)

    if scrollChild.TitleText then
        scrollChild.TitleText:SetText(PANEL_NAME)
        if scrollChild.TitleText.SetJustifyH then
            scrollChild.TitleText:SetJustifyH("LEFT")
        end
    end

    if scrollChild.SubtitleText then
        scrollChild.SubtitleText:SetText(ResolveLocale("OPT_SUBTITLE"))
        if scrollChild.SubtitleText.SetJustifyH then
            scrollChild.SubtitleText:SetJustifyH("LEFT")
        end
        if scrollChild.SubtitleText.SetWordWrap then
            scrollChild.SubtitleText:SetWordWrap(true)
        end
        if scrollChild.SubtitleText.SetNonSpaceWrap then
            scrollChild.SubtitleText:SetNonSpaceWrap(true)
        end
    end

    -- Apply VerticalLayoutMixin so hidden rows collapse automatically — no manual
    -- anchor chains needed. fixedWidth locks the container's width so Layout()
    -- only auto-sizes the height.
    local container = scrollChild.OptionsContainer
    if container then
        Mixin(container, LayoutMixin, VerticalLayoutMixin)
        container.fixedWidth = 520

        -- Set subsection header text (localized)
        if container.TextOnBarHeader and container.TextOnBarHeader.Title then
            container.TextOnBarHeader.Title:SetText(ResolveLocale("OPT_TEXT_ON_BAR"))
        end

        if container.TextBelowBarHeader and container.TextBelowBarHeader.Title then
            container.TextBelowBarHeader.Title:SetText(ResolveLocale("OPT_TEXT_BELOW_BAR"))
        end
        if container.TextLeftLabelHeader and container.TextLeftLabelHeader.Text then
            container.TextLeftLabelHeader.Text:SetText(ResolveLocale("OPT_TEXT_LEFT"))
        end
        if container.TextMiddleLabelHeader and container.TextMiddleLabelHeader.Text then
            container.TextMiddleLabelHeader.Text:SetText(ResolveLocale("OPT_TEXT_MIDDLE"))
        end
        if container.TextRightLabelHeader and container.TextRightLabelHeader.Text then
            container.TextRightLabelHeader.Text:SetText(ResolveLocale("OPT_TEXT_RIGHT"))
        end
    end

    if self.ResetSettingsButton and self.ResetSettingsButton.SetText then
        self.ResetSettingsButton:SetText(ResolveLocale("OPT_RESET_SETTINGS"))
    end

    if self.ResetSettingsButton then
        self.ResetSettingsButton:SetScript(
            "OnClick",
            function()
                self:OnResetSettingsClicked()
            end
        )
    end

    if self.ResetBarPositionButton then
        self.ResetBarPositionButton:SetText(ResolveLocale("OPT_RESET_BAR_POSITION"))
        self.ResetBarPositionButton:SetScript(
            "OnClick",
            function()
                self:OnResetBarPositionClicked()
            end
        )
    end

    -- Set section header titles
    if scrollChild.OptionsContainer then
        local container = scrollChild.OptionsContainer

        -- Bar Settings section
        if container.BarSettingsHeader and container.BarSettingsHeader.Title then
            container.BarSettingsHeader.Title:SetText(ResolveLocale("OPT_HEADER_BAR_SETTINGS"))
        end

        -- Quest Features section
        if container.OverlayFeaturesHeader and container.OverlayFeaturesHeader.Title then
            container.OverlayFeaturesHeader.Title:SetText(ResolveLocale("OPT_HEADER_DISPLAY_FEATURES"))
        end

        -- Quest Features section
        if container.QuestFeaturesHeader and container.QuestFeaturesHeader.Title then
            container.QuestFeaturesHeader.Title:SetText(ResolveLocale("OPT_HEADER_QUEST_FEATURES"))
        end

        -- Text Display section
        if container.TextDisplayHeader and container.TextDisplayHeader.Title then
            container.TextDisplayHeader.Title:SetText(ResolveLocale("OPT_HEADER_TEXT_DISPLAY"))
        end

        -- Animation section
        if container.AnimationHeader and container.AnimationHeader.Title then
            container.AnimationHeader.Title:SetText(ResolveLocale("OPT_HEADER_ANIMATION"))
        end

        -- Colors section
        if container.ColorsHeader and container.ColorsHeader.Title then
            container.ColorsHeader.Title:SetText(ResolveLocale("OPT_HEADER_COLORS"))
        end

        -- Secondary Bars section
        if container.SecondaryBarsHeader and container.SecondaryBarsHeader.Title then
            container.SecondaryBarsHeader.Title:SetText(ResolveLocale("OPT_HEADER_SECONDARY_BARS"))
        end
    end

    self:EnsureProfileControls()

    self:BuildOptionCheckboxes()
    self:BuildColorControls()
    self:SetupStyleGallery()
    self:SetupPresetRow()
    self:SetupDisclosures()
    self:SetupTabs()
    self:SelectTab("visual")
    self:Refresh()
    self:RegisterCategory()

    local observerId = self:GetName() or ("_bar_" .. tostring(self))
    local colorHandler = function(payload)
        if self and self.UpdateColorControls then
            self:UpdateColorControls()
        end
    end
    Addon.EventBus:Register(EventNames.COLORS_UPDATED, observerId, colorHandler)
    Addon.EventBus:Register(EventNames.PROFILE_CHANGED, observerId .. "_profile_changed", function()
        if self and self.Refresh then
            self:Refresh()
        end
    end)
    Addon.EventBus:Register(EventNames.PROFILES_UPDATED, observerId .. "_profiles_updated", function()
        if self and self.Refresh then
            self:Refresh()
        end
    end)
end

function XPBarEnhancedOptionsMixin:OnPanelShow()
    self:Refresh()
    -- Resize tab buttons now that the frame is visible and FontStrings have valid widths.
    -- PanelTemplates_TabResize uses GetStringWidth() which returns 0 at OnLoad time.
    if self.TabContainer then
        for _, tab in ipairs(TABS) do
            local btn = self.TabContainer["Tab_" .. tab.id]
            if btn then
                PanelTemplates_TabResize(btn, 0)
            end
        end
    end
    -- Recalculate scroll height when panel is shown
    self:RefreshScrollLayout()
end

function XPBarEnhancedOptionsMixin:RefreshScrollLayout()
    -- Force recalculation of scroll content height while preserving scroll position.
    if self.ScrollBox and self.ScrollBox:GetDataProvider() then
        local previousPercent = nil
        if self.ScrollBox.GetScrollPercentage then
            previousPercent = self.ScrollBox:GetScrollPercentage()
        elseif self.ScrollBar and self.ScrollBar.GetValue and self.ScrollBar.GetMinMaxValues then
            local minValue, maxValue = self.ScrollBar:GetMinMaxValues()
            local currentValue = self.ScrollBar:GetValue()
            if minValue and maxValue and currentValue and maxValue > minValue then
                previousPercent = (currentValue - minValue) / (maxValue - minValue)
            else
                previousPercent = 0
            end
        end

        local dataProvider = CreateDataProvider()
        dataProvider:Insert({id = "content"})
        self.ScrollBox:SetDataProvider(dataProvider)

        if previousPercent ~= nil and self.ScrollBox.SetScrollPercentage then
            self.ScrollBox:SetScrollPercentage(previousPercent, ScrollBoxConstants.NoScrollInterpolation)
        elseif previousPercent ~= nil and self.ScrollBar and self.ScrollBar.SetValue and self.ScrollBar.GetMinMaxValues then
            local minValue, maxValue = self.ScrollBar:GetMinMaxValues()
            if minValue and maxValue and maxValue > minValue then
                self.ScrollBar:SetValue(minValue + ((maxValue - minValue) * previousPercent))
            end
        end
    end
end

function XPBarEnhancedOptionsMixin:BuildOptionCheckboxes()
    if not self.ContentFrame or not self.ContentFrame.OptionsContainer then
        return
    end

    if next(self.controls) then
        return
    end

    local container = self.ContentFrame.OptionsContainer
    local childFrames = CollectChildrenByConfigKey(container)

    for _, key in ipairs(Config.optionOrder or {}) do
        local detail = Config.optionDetails and Config.optionDetails[key]
        local frame = childFrames[key]

        if detail and frame then
            -- Route based on template type (detect two-column templates)
            -- Check for Slider and Dropdown FIRST (before Checkbox) to avoid misdetection
            if frame.Grid then
                -- Swatch gallery row (ConfigStyleGalleryTemplate) — built by
                -- SetupStyleGallery, which needs the click handler this loop has
                -- no way to express.
                frame.Label:SetText(detail.label)
            elseif frame.Slider then
                -- Two-column slider template (ConfigSliderTemplate)
                ControlHelpers.SetupProperSlider(self, frame, key, detail)
            elseif frame.Dropdown then
                -- Two-column dropdown template (ConfigDropdownTemplate)
                ControlHelpers.SetupProperDropdown(self, frame, key, detail)
            elseif frame.Checkbox and frame.Label then
                -- Two-column checkbox template (ConfigCheckboxTemplate)
                ControlHelpers.SetupTwoColumnCheckbox(self, frame, key, detail)
            elseif detail.type == "slider" then
                -- Old-style slider (dynamically created)
                ControlHelpers.SetupSlider(self, frame, key, detail)
            elseif detail.type == "dropdown" and detail.options and #detail.options > 2 then
                -- Old-style cycling button dropdown
                ControlHelpers.SetupDropdown(self, frame, key, detail)
            elseif detail.type == "dropdown" then
                -- Old-style radio group
                ControlHelpers.SetupRadioGroup(self, frame, key, detail)
            else
                -- Default to checkbox
                ControlHelpers.SetupCheckbox(self, frame, key, detail)
            end
        end
    end
end

function XPBarEnhancedOptionsMixin:BuildColorControls()
    if not self.ContentFrame or not self.ContentFrame.OptionsContainer then
        return
    end

    if next(self.colorControls) then
        return -- Already built
    end

    local container = self.ContentFrame.OptionsContainer

    -- Collect all color picker rows from OptionsContainer (they're now direct children like other settings)
    local rowsByKey = CollectChildrenByConfigKey(container)

    if not Config.colorOptionsList then
        return
    end

    -- Setup each color row
    for _, info in ipairs(Config.colorOptionsList) do
        local row = rowsByKey[info.key]
        if row then
            local controls = ControlHelpers.SetupColorRow(self, row, info)
            if controls then
                self.colorControls[info.key] = controls
            end
        end
    end

    self:UpdateColorControls()
end

function XPBarEnhancedOptionsMixin:UpdateContentHeight(bottomAnchor)
    local contentFrame = self.ContentFrame
    if not contentFrame then
        return
    end

    local top = contentFrame:GetTop()
    local bottom = bottomAnchor and bottomAnchor.valueText and bottomAnchor.valueText:GetBottom()

    local resetBtn = self.ResetSettingsButton
    if not bottom and resetBtn and resetBtn.GetBottom then
        bottom = resetBtn:GetBottom()
    end

    if top and bottom then
        local height = (top - bottom) + 80
        if height > contentFrame:GetHeight() then
            contentFrame:SetHeight(height)
        end
    end
end

function XPBarEnhancedOptionsMixin:RegisterCategory()
    if self._registeredCategory then
        return
    end

    self.name = PANEL_NAME

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local settingsCategory = Settings.RegisterCanvasLayoutCategory(self, PANEL_NAME)
        Settings.RegisterAddOnCategory(settingsCategory)
        self._registeredCategory = settingsCategory
        Options.category = settingsCategory
        Addon.OptionsCategory = settingsCategory
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(self)
        self._registeredCategory = self
        Options.category = self
        Addon.OptionsCategory = self
    end
end

function XPBarEnhancedOptionsMixin:OnResetSettingsClicked()
    Config:Reset()
    self:Refresh()
end

function XPBarEnhancedOptionsMixin:OnResetBarPositionClicked()
    -- Prefer BarManager wrapper or direct view call for reset position; fallback to old shim
    if Addon.BarManager and Addon.BarManager.ResetBarPosition then
        Addon.BarManager:ResetBarPosition()
    end
    -- Clear persisted secondary bar positions so bars return to default anchors
    -- Use profile-aware API instead of direct Addon.db access
    if Addon.Config and Addon.Config.GetSettingsStorage then
        local storage = Addon.Config:GetSettingsStorage()
        if storage then
            storage.secondaryBarPositions = nil
        end
    elseif Addon.db then
        Addon.db.secondaryBarPositions = nil
    end
    if Addon.SecondaryBarManager and Addon.SecondaryBarManager.ResetBarPositions then
        Addon.SecondaryBarManager:ResetBarPositions()
    end
end

function XPBarEnhancedOptionsMixin:UpdateColorControls()
    -- The style swatches paint their fills with the configured xpBar colour, so a
    -- colour change has to reach them too — not only the Colors tab's own rows.
    self:RefreshStyleGallery(Config and Config:GetOptionValue("barStyle"))

    if not Config or not Config.colorOptionsList then
        return
    end

    for _, info in ipairs(Config.colorOptionsList) do
        local controls = self.colorControls[info.key]
        if controls then
            local color = Config:GetColor(info.key) or Config:GetDefaultColor(info.key) or {}
            local r = clamp01(color.r or color[1] or 1)
            local g = clamp01(color.g or color[2] or 1)
            local b = clamp01(color.b or color[3] or 1)
            local a = clamp01(color.a or color[4] or 1)

            if controls.swatchTexture then
                controls.swatchTexture:SetColorTexture(r, g, b, 1)
            end

            if controls.previewType == "statusbar" and controls.preview and controls.preview.SetStatusBarColor then
                controls.preview:SetStatusBarColor(r, g, b, a)
                if controls.previewBackground and controls.previewBackground.SetColorTexture then
                    controls.previewBackground:SetColorTexture(r, g, b, clamp01(a * 0.25) + 0.05)
                end
            elseif controls.previewType == "texture" and controls.preview and controls.preview.SetColorTexture then
                controls.preview:SetColorTexture(r, g, b, a)
            end

            if controls.valueText then
                local hex = Config:GetColorHex(info.key) or "FFFFFFFF"
                local alphaPercent = math.floor(a * 100 + 0.5)
                controls.valueText:SetText(
                    string.format(ResolveLocale("OPT_COLOR_CURRENT_FMT"), string.sub(hex, 1, 6), alphaPercent)
                )
            end

            if controls.swatch then
                if ColorPickerFrame or rawget(_G, "OpenColorPicker") then
                    controls.swatch:Enable()
                    controls.swatch:SetAlpha(1)
                else
                    controls.swatch:Disable()
                    controls.swatch:SetAlpha(0.5)
                end
            end
        end
    end
end

function XPBarEnhancedOptionsMixin:OpenColorPicker(colorKey)
    -- Check for modern ColorPicker API first
    local hasColorPicker = ColorPickerFrame or rawget(_G, "OpenColorPicker")

    if not hasColorPicker then
        print("|cFFFF5555" .. ResolveLocale("ADDON_NAME") .. ":|r " .. ResolveLocale("MSG_COLOR_PICKER_UNAVAILABLE"))
        return
    end

    local info = Config:GetColorOptionByKey(colorKey)
    if not info then
        return
    end

    local color = Config:GetColor(colorKey) or Config:GetDefaultColor(colorKey) or {}
    local r = clamp01(color.r or color[1] or 1)
    local g = clamp01(color.g or color[2] or 1)
    local b = clamp01(color.b or color[3] or 1)
    local a = clamp01(color.a or color[4] or 1)
    local previousHex = Config:GetColorHex(colorKey)

    -- Called continuously as the user changes color/opacity
    local function applyColor(restore, ...)
        local pr, pg, pb, opacity

        if type(restore) == "table" then
            pr = clamp01(restore.r or restore[1] or r)
            pg = clamp01(restore.g or restore[2] or g)
            pb = clamp01(restore.b or restore[3] or b)
            local restoreAlpha = restore.a or restore[4]
            if restoreAlpha ~= nil then
                opacity = clamp01(restoreAlpha)
            end
        end

        if not pr then
            pr, pg, pb = ColorPickerFrame:GetColorRGB()
        end

        if opacity == nil then
            -- Use GetColorAlpha() to get the current alpha value from the slider
            if ColorPickerFrame.GetColorAlpha then
                opacity = ColorPickerFrame:GetColorAlpha()
            elseif
                ColorPickerFrame.Content and ColorPickerFrame.Content.ColorPicker and
                    ColorPickerFrame.Content.ColorPicker.GetColorAlpha
             then
                opacity = ColorPickerFrame.Content.ColorPicker:GetColorAlpha()
            end

            -- Fallback to the static opacity field if GetColorAlpha doesn't exist
            if opacity == nil then
                opacity = ColorPickerFrame.opacity
            end

            -- Final fallback to OpacitySliderFrame for older versions
            if (opacity == nil) and OpacitySliderFrame and OpacitySliderFrame:IsShown() then
                opacity = OpacitySliderFrame:GetValue()
            end
        end

        opacity = clamp01(opacity or 1)
        local hex = rgbToHex(pr, pg, pb, opacity)

        -- Save the new color
        Config:SetColor(colorKey, hex, true)
        if Config.ApplyPendingOptionChanges then
            Config:ApplyPendingOptionChanges()
        end

        -- Update UI
        local controller = Options
        if controller and controller.OnColorChanged then
            controller:OnColorChanged(colorKey, hex)
        else
            self:UpdateColorControls()
        end
    end

    -- Called when user clicks Cancel - restore original color
    local function cancelColor(restore)
        -- Restore to the original color
        Config:SetColor(colorKey, previousHex, true)
        if Config.ApplyPendingOptionChanges then
            Config:ApplyPendingOptionChanges()
        end

        -- Update UI
        local controller = Options
        if controller and controller.OnColorCancel then
            controller:OnColorCancel(colorKey, previousHex)
        else
            self:UpdateColorControls()
        end
    end

    if ColorPickerFrame and ColorPickerFrame.SetColorRGB then
        ColorPickerFrame.func = applyColor
        ColorPickerFrame.opacityFunc = applyColor
        ColorPickerFrame.cancelFunc = cancelColor

        ColorPickerFrame.hasOpacity = true
        ColorPickerFrame.opacity = a
        ColorPickerFrame.previousValues = {r = r, g = g, b = b, a = a}
        ColorPickerFrame:SetColorRGB(r, g, b)
        ColorPickerFrame:Hide()
        ColorPickerFrame:Show()
    elseif ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow(
            {
                swatchFunc = applyColor,
                opacityFunc = applyColor,
                cancelFunc = cancelColor,
                hasOpacity = true,
                opacity = a,
                r = r,
                g = g,
                b = b,
                previousValues = {r = r, g = g, b = b, a = a}
            }
        )
    else
        local OpenColorPicker = rawget(_G, "OpenColorPicker")
        if OpenColorPicker then
            OpenColorPicker(
                {
                    swatchFunc = applyColor,
                    opacityFunc = applyColor,
                    cancelFunc = cancelColor,
                    hasOpacity = true,
                    opacity = a,
                    r = r,
                    g = g,
                    b = b,
                    previousValues = {r = r, g = g, b = b, a = a}
                }
            )
        end
    end
end

--- The disclosure group a row is in right now, which is usually the static one
--- declared in XML. The exception is the secondary-source colour swatches: the
--- one matching the active source is pulled out of the group so it is always
--- visible, since it is the only one of the four that paints anything on screen.
---@param child table A container child
---@return string|nil
function XPBarEnhancedOptionsMixin:GetEffectiveDisclosureGroup(child)
    local group = child and child.disclosureGroup
    if group ~= SECONDARY_COLOR_GROUP then
        return group
    end

    local source = Config:GetOptionValue("secondaryBarSource")
    if child.configKey == SECONDARY_SOURCE_COLOR[source] then
        return nil
    end
    return group
end

--- True when rows in `group` should be shown. Rows with no group always show.
---@param group string|nil
---@return boolean
function XPBarEnhancedOptionsMixin:IsDisclosureExpanded(group)
    if not group then
        return true
    end
    return (self._disclosureExpanded and self._disclosureExpanded[group]) and true or false
end

--- Update a disclosure header's own text to match its expanded state
function XPBarEnhancedOptionsMixin:RefreshDisclosureHeaders()
    local container = self.ContentFrame and self.ContentFrame.OptionsContainer
    if not container then
        return
    end

    for _, child in ipairs({container:GetChildren()}) do
        local group = child and child.disclosureToggle
        if group and child.Title then
            local marker = self:IsDisclosureExpanded(group) and "-" or "+"
            child.Title:SetText(marker .. " " .. ResolveLocale("OPT_SECTION_" .. string.upper(group)))
        end
    end
end

--- Expand or collapse a disclosure group and relayout the active tab
---@param group string
---@param expanded boolean
function XPBarEnhancedOptionsMixin:SetDisclosureExpanded(group, expanded)
    self._disclosureExpanded = self._disclosureExpanded or {}
    self._disclosureExpanded[group] = expanded and true or false
    self:RefreshDisclosureHeaders()
    -- Re-run the tab filter so the group's rows appear/disappear and the
    -- container reflows around them.
    if self._activeTab then
        self:SelectTab(self._activeTab)
    end
end

--- Wire the disclosure headers. Each group's starting state comes from
--- DISCLOSURE_DEFAULT_OPEN, so a group can open itself when its contents are what
--- the player came for.
function XPBarEnhancedOptionsMixin:SetupDisclosures()
    local container = self.ContentFrame and self.ContentFrame.OptionsContainer
    if not container then
        return
    end

    self._disclosureExpanded = self._disclosureExpanded or {}
    for _, child in ipairs({container:GetChildren()}) do
        local group = child and child.disclosureToggle
        if group then
            if self._disclosureExpanded[group] == nil then
                local defaultOpen = DISCLOSURE_DEFAULT_OPEN[group]
                self._disclosureExpanded[group] = defaultOpen and defaultOpen() or false
            end
            if child.Toggle then
                child.Toggle:SetScript("OnClick", function()
                    self:SetDisclosureExpanded(group, not self:IsDisclosureExpanded(group))
                end)
            end
        end
    end

    self:RefreshDisclosureHeaders()
end

--- Tag the secondary-source colour swatch that is actually painting something and
--- mark the other three inactive. Only one secondary source is on screen at a
--- time, so three of the four swatches are always guesswork otherwise.
function XPBarEnhancedOptionsMixin:RefreshSecondaryColorRows()
    local container = self.ContentFrame and self.ContentFrame.OptionsContainer
    local detail = Config.optionDetails and Config.optionDetails.secondaryBarSource
    if not container or not detail or not detail.options then
        return
    end

    local activeKey = SECONDARY_SOURCE_COLOR[Config:GetOptionValue("secondaryBarSource")]
    local foldedIndex = 0

    -- Ordered by the source dropdown rather than a second list here, so a fifth
    -- secondary source needs only its own colour key and layout slot.
    for _, option in ipairs(detail.options) do
        local colorKey = SECONDARY_SOURCE_COLOR[option.value]
        local row = colorKey and container["ColorRow_" .. colorKey]
        if row then
            local isActive = (colorKey == activeKey)
            -- Tagged, folded away, but still editable: unlike a style-scoped row,
            -- an inactive source's colour is a setting that works — it just is not
            -- on screen yet. Disabling it would remove the ability to set a colour
            -- before switching to that source.
            self:SetRowAvailability(
                colorKey,
                true,
                isActive and ResolveLocale("OPT_COLOR_ACTIVE") or ResolveLocale("OPT_UNAVAIL_NOT_ACTIVE")
            )

            if isActive then
                row.layoutIndex = SECONDARY_COLOR_ACTIVE_SLOT
            else
                foldedIndex = foldedIndex + 1
                row.layoutIndex = SECONDARY_COLOR_FOLDED_SLOTS[foldedIndex] or row.layoutIndex
            end
        end
    end
end

--- Build the bar-style swatch gallery that replaced the barStyle dropdown.
--- Selection writes the same barStyle values the dropdown wrote, so slash
--- commands and saved variables are unaffected.
function XPBarEnhancedOptionsMixin:SetupStyleGallery()
    local container = self.ContentFrame and self.ContentFrame.OptionsContainer
    local row = container and container.Row_barStyle
    local gallery = Addon.StyleGallery
    if not row or not gallery then
        return
    end

    gallery:Build(row, function(styleValue)
        -- Deferred write plus one apply: ApplyPendingOptionChanges is what runs
        -- BarManager:SetStyle and emits the single CONFIG_UPDATED.
        Config:SetOptionKey("barStyle", styleValue, true)
        Config:ApplyPendingOptionChanges()
        -- Style scoping is availability, not visibility (see RefreshRowAvailability),
        -- so a new style re-labels rows without changing the panel's shape.
        self:Refresh()
    end)
end

--- Ring the active style's swatch and re-apply the configured bar colour.
function XPBarEnhancedOptionsMixin:RefreshStyleGallery(barStyle)
    local container = self.ContentFrame and self.ContentFrame.OptionsContainer
    local row = container and container.Row_barStyle
    local gallery = Addon.StyleGallery
    if not row or not gallery then
        return
    end

    gallery:Refresh(row, barStyle)
    if row.StatusText then
        row.StatusText:SetText(GetStyleLabel(barStyle))
    end
end

--- Wire the three readout-preset buttons and the reset shortcut.
--- Presets are the new player's path from "I want a minimal bar" to the boolean
--- toggles that produce one; the individual toggles stay one click away.
function XPBarEnhancedOptionsMixin:SetupPresetRow()
    local container = self.ContentFrame and self.ContentFrame.OptionsContainer
    local row = container and container.Row_readoutPreset
    local presets = Addon.ReadoutPresets
    if not row or not presets then
        return
    end

    if row.Label then
        row.Label:SetText(ResolveLocale("OPT_READOUT_PRESET"))
    end

    for index, name in ipairs(presets.ORDER) do
        local button = row["PresetButton" .. index]
        if button then
            local upper = string.upper(name)
            button:SetText(ResolveLocale("OPT_READOUT_PRESET_" .. upper))
            button.tooltipText = ResolveLocale("OPT_READOUT_PRESET_" .. upper)
            button.tooltipRequirement = ResolveLocale("OPT_READOUT_PRESET_" .. upper .. "_DESC")
            button:SetScript("OnClick", function()
                presets:Apply(name)
                -- Choosing a preset means the details are handled; fold them away.
                self:SetDisclosureExpanded("advanced", false)
                self:Refresh()
            end)
        end
    end

    if row.ResetButton then
        row.ResetButton:SetText(ResolveLocale("OPT_READOUT_PRESET_RESET"))
        row.ResetButton:SetScript("OnClick", function()
            presets:Apply("standard")
            self:SetDisclosureExpanded("advanced", false)
            self:Refresh()
        end)
    end
end

--- Reflect the preset currently in effect: highlight nothing when Custom, and
--- offer the reset shortcut only then.
function XPBarEnhancedOptionsMixin:RefreshPresetRow()
    local container = self.ContentFrame and self.ContentFrame.OptionsContainer
    local row = container and container.Row_readoutPreset
    local presets = Addon.ReadoutPresets
    if not row or not presets then
        return
    end

    local active = presets:Detect()

    for index, name in ipairs(presets.ORDER) do
        local button = row["PresetButton" .. index]
        if button then
            -- The active preset's own button is redundant, not broken: disabling it
            -- states "you are already here" without removing the row.
            button:SetEnabled(active ~= name)
        end
    end

    if row.StatusText then
        row.StatusText:SetText(ResolveLocale("OPT_READOUT_PRESET_" .. string.upper(active)))
    end
    if row.ResetButton then
        row.ResetButton:SetShown(active == presets.CUSTOM)
    end
end

--- Enable or disable one option row, keeping it visible either way.
--- Rows the active style cannot use are disabled and their label is muted with a
--- trailing note rather than hidden, so the panel's shape stays constant across
--- styles and the player learns which style owns the feature.
--- The note is appended to the row's own Label so this works for every row
--- template, including the color rows that do not inherit ConfigRowBase.
---@param key string Config key; the row is Row_<key> or ColorRow_<key>
---@param available boolean
---@param note string|nil Trailing note; shown whether or not the row is available
function XPBarEnhancedOptionsMixin:SetRowAvailability(key, available, note)
    local container = self.ContentFrame and self.ContentFrame.OptionsContainer
    local row = container and (container["Row_" .. key] or container["ColorRow_" .. key])

    local label = row and row.Label
    if label and label.SetText then
        local detail = (Config.optionDetails and Config.optionDetails[key])
            or (Config.colorOptionByKey and Config.colorOptionByKey[key])
        local base = (detail and detail.label) or label.__xpbeBaseText or label:GetText() or ""
        -- Remember the untagged text: GetText() would return the tagged version
        -- on the next call and the note would accumulate.
        label.__xpbeBaseText = base
        label:SetText(note and (base .. "   " .. note) or base)
        if label.SetFontObject then
            label:SetFontObject(available and "GameFontHighlight" or "GameFontDisable")
        end
    end

    -- Resolve the interactive widget from the row itself: only checkboxes and
    -- sliders land in self.controls, so dropdown and color rows would otherwise
    -- stay clickable while reading as disabled.
    local control = self.controls and self.controls[key]
    local widget = (row and (row.Slider or row.Dropdown or row.Checkbox or row.Swatch))
        or (control and (control.Slider or control.Dropdown or control))
    if widget and widget.SetEnabled then
        widget:SetEnabled(available)
    end

    -- Fade everything the row draws to the right of its label, not just the
    -- control: a full-brightness colour preview beside a greyed label reads as
    -- the row still being in effect.
    -- Built by assignment rather than as a literal: a nil in the middle of a
    -- table constructor truncates ipairs.
    local parts = {}
    parts[#parts + 1] = widget
    for _, name in ipairs({"Description", "ValueText", "StatusPreview", "TexturePreview"}) do
        parts[#parts + 1] = row and row[name]
    end

    local alpha = available and 1 or 0.5
    for _, part in ipairs(parts) do
        if part.SetAlpha then
            part:SetAlpha(alpha)
        end
    end
end

--- Apply UNAVAILABLE_BY_STYLE and ROW_OWNER_STYLE for the active style.
---@param barStyle string
function XPBarEnhancedOptionsMixin:RefreshRowAvailability(barStyle)
    for key, byStyle in pairs(UNAVAILABLE_BY_STYLE) do
        local localeKey = byStyle[barStyle]
        self:SetRowAvailability(key, localeKey == nil, localeKey and ResolveLocale(localeKey))
    end

    for key, ownerStyle in pairs(ROW_OWNER_STYLE) do
        local available = (ownerStyle == barStyle)
        self:SetRowAvailability(
            key,
            available,
            not available and string.format(ResolveLocale("OPT_UNAVAIL_STYLE_ONLY"), GetStyleLabel(ownerStyle)) or nil
        )
    end

    -- sigilPinnedTier only means anything while the tier mode is pinned. This is
    -- a dependency on another option rather than on the style, so it applies on
    -- top of the ROW_OWNER_STYLE pass above and must run after it.
    if barStyle == "sigil" and Config:GetOptionValue("sigilTierMode") ~= "pinned" then
        self:SetRowAvailability("sigilPinnedTier", false, ResolveLocale("OPT_UNAVAIL_TIER_AUTO"))
    end

    -- A one-item dropdown is a control with nothing to choose, so this row is
    -- hidden outright rather than disabled -- the only row in the panel that is.
    local container = self.ContentFrame and self.ContentFrame.OptionsContainer
    local skinRow = container and container.Row_sigilSkin
    if skinRow and skinRow.SetShown then
        skinRow:SetShown(not IsRowSuppressed("sigilSkin"))
    end
end

function XPBarEnhancedOptionsMixin:Refresh()
    if not self.controls then
        return
    end

    -- Current barStyle drives row availability, not row visibility.
    local barStyle = Config:GetOptionValue("barStyle")

    -- Refresh checkboxes
    for key, checkbox in pairs(self.controls) do
        if checkbox and checkbox.SetChecked then
            local value = Config:GetOptionValue(key)
            checkbox:SetChecked(value and true or false)
            -- Style scoping is applied uniformly in RefreshRowAvailability below:
            -- rows stay visible and are enabled or disabled instead of hidden.
        elseif checkbox and checkbox.Slider then
            -- It's a slider control
            local value = Config:GetOptionValue(key)

            -- Validate that value is a number
            if type(value) ~= "number" then
                -- Fall back to default value from metadata
                local detail = Config.optionDetails and Config.optionDetails[key]
                if detail then
                    value = detail.min or 0
                else
                    value = 1.0 -- Fallback default
                end
            end

            if checkbox.Slider.SetValue then
                checkbox.Slider:SetValue(value)
                if checkbox.ValueText then
                    local slider = self.sliders and self.sliders[key]
                    local formatStr = (slider and slider.format) or "%.1f"
                    checkbox.ValueText:SetText(string.format(formatStr, value))
                end
            end
        end
    end

    -- Disable rows the active style cannot render (kept visible, with a reason)
    self:RefreshRowAvailability(barStyle)

    self:RefreshStyleGallery(barStyle)
    self:RefreshSecondaryColorRows()
    self:RefreshPresetRow()

    -- Refresh dropdowns
    if self.dropdowns then
        for key, dropdown in pairs(self.dropdowns) do
            local value = Config:GetOptionValue(key)
            local detail = Config.optionDetails and Config.optionDetails[key]

            if detail and detail.options then
                -- Find the label for current value
                local labelText = nil
                for _, opt in ipairs(detail.options) do
                    if opt.value == value then
                        labelText = opt.label
                        break
                    end
                end

                if labelText then
                    -- WowStyle1DropdownTemplate: Use SetDefaultText to update displayed text
                    if dropdown.SetDefaultText then
                        dropdown:SetDefaultText(labelText)
                    elseif dropdown.Button then
                        -- Old-style cycling button dropdown (classic)
                        dropdown.Button:SetText(labelText)
                    end
                end
            end
        end
    end

    -- Refresh proper sliders (MinimalSliderWithSteppersTemplate)
    if self.sliders then
        for key, slider in pairs(self.sliders) do
            local value = Config:GetOptionValue(key)

            -- Validate that value is a number
            if type(value) ~= "number" then
                local detail = Config.optionDetails and Config.optionDetails[key]
                if detail then
                    value = detail.min or 0
                else
                    value = 1.0
                end
            end

            if slider and slider.SetValue then
                -- Prevent callback from firing when we programmatically set value
                slider.settingValue = true
                slider:SetValue(value)
                slider.settingValue = false
            end
        end
    end

    -- Re-apply the tab filter so the container reflows. Style scoping no longer
    -- shows or hides anything, so row count and scroll height are the same for
    -- every bar style — only which rows are enabled changes.
    local container = self.ContentFrame and self.ContentFrame.OptionsContainer
    if container then
        if self._activeTab then
            self:SelectTab(self._activeTab)
        else
            container:Layout()
            self:RefreshScrollLayout()
        end
    end

    -- Refresh radio groups
    if self.radioGroups then
        for key, radioGroup in pairs(self.radioGroups) do
            if radioGroup and radioGroup.buttons then
                local value = Config:GetOptionValue(key)

                -- Update radio button checked states
                for _, button in ipairs(radioGroup.buttons) do
                    button:SetChecked(button.value == value)
                end
            end
        end
    end

    self:RefreshProfileControls()
    self:UpdateColorControls()
end

function Options:AcceptCreateProfileDialog(name)
    local success, err = Config:CreateProfile(name, true)
    if success then
        print(string.format("|cFF00FF00" .. ResolveLocale("ADDON_NAME") .. ":|r " .. ResolveLocale("MSG_PROFILE_CREATED"), tostring(name)))
        self:Refresh()
    else
        print("|cFFFF0000" .. ResolveLocale("ADDON_NAME") .. ":|r " .. tostring(err))
    end
end

function Options:AcceptRenameProfileDialog(oldName, newName)
    local success, err = Config:RenameProfile(oldName, newName)
    if success then
        print(string.format("|cFF00FF00" .. ResolveLocale("ADDON_NAME") .. ":|r " .. ResolveLocale("MSG_PROFILE_RENAMED"), tostring(newName)))
        self:Refresh()
    else
        print("|cFFFF0000" .. ResolveLocale("ADDON_NAME") .. ":|r " .. tostring(err))
    end
end

function Options:AcceptDeleteProfileDialog(name)
    local success, err = Config:DeleteProfile(name)
    if success then
        print(string.format("|cFF00FF00" .. ResolveLocale("ADDON_NAME") .. ":|r " .. ResolveLocale("MSG_PROFILE_DELETED"), tostring(name)))
        self:Refresh()
    else
        print("|cFFFF0000" .. ResolveLocale("ADDON_NAME") .. ":|r " .. tostring(err))
    end
end

function Options:Initialize(controller)
    if controller then
        self.controller = controller
    end

    if not self.frame then
        local panel = rawget(_G, "XPBarEnhancedOptionsPanel")
        if panel then
            self.frame = panel
        end
    end

    local panel = self.frame
    if panel and not panel.controls then
        if panel.OnLoad then
            panel:OnLoad()
        end
    end

    return panel
end

function Options:Refresh()
    local panel = self:Initialize(self.controller)
    if panel and panel.Refresh then
        panel:Refresh()
    end
end

function Options:UpdateColorControls()
    local panel = self:Initialize(self.controller)
    if panel and panel.UpdateColorControls then
        panel:UpdateColorControls()
    end
end

function Options:OpenColorPicker(colorKey)
    local panel = self:Initialize(self.controller)
    if panel and panel.OpenColorPicker then
        panel:OpenColorPicker(colorKey)
    end
end

function Options:Open()
    local panel = self:Initialize(self.controller)
    if not panel then
        return
    end

    self:Refresh()

    local category = self.category
    if Settings and Settings.OpenToCategory and category then
        local id = category.GetID and category:GetID() or category.ID or category
        -- Defer via C_Timer to break addon taint from the click call stack;
        -- OpenSettingsPanel() is protected and cannot be called from tainted code.
        C_Timer.After(0, function() Settings.OpenToCategory(id) end)
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(panel)
        InterfaceOptionsFrame_OpenToCategory(panel)
    end
end

-- Controller Methods

function Options:OnOptionChanged(key)
    -- Handle specific option changes
    if key == "barStyle" then
        local value = (Addon.Config and Addon.Config.GetOptionValue and Addon.Config:GetOptionValue("barStyle")) or "classic"
        if Addon.BarManager and Addon.BarManager.SetStyle then
            Addon.BarManager:SetStyle(value)
        end
    elseif key == "barLocked" then
    elseif key == "classicBarDraggable" then
    elseif key == "showMinimapButton" then
        local value = Config:GetOptionValue("showMinimapButton")
        if Addon.MinimapButton and Addon.MinimapButton.SetEnabled then
            Addon.MinimapButton:SetEnabled(value and true or false)
        end
        -- Handled by Config side effects - just refresh UI
    elseif
        key == "enableAnimations" or key == "flashOnGain" or key == "twoPhaseOnLevelUp"
     then
        if Addon.BarManager and Addon.BarManager.UpdateAnimationSettings then
            Addon.BarManager:UpdateAnimationSettings()
        end
    elseif key == "circularSegments" then
        -- Immediately reposition segments on the circular bar
        if Addon.BarManager and Addon.BarManager.GetCurrentFrame then
            local bar = Addon.BarManager:GetCurrentFrame()
            if bar and bar.RepositionSegments then
                bar:RepositionSegments()
            end
        end
    elseif key == "circularUseTexture" then
        -- Update texture on segments and reposition
        if Addon.BarManager and Addon.BarManager.GetCurrentFrame then
            local bar = Addon.BarManager:GetCurrentFrame()
            if bar and bar.RepositionSegments then
                bar:RepositionSegments()
            end
        end
    elseif key == "flatSize" or key == "verticalSize" then
        if Addon.BarManager and Addon.BarManager.GetCurrentFrame then
            local bar = Addon.BarManager:GetCurrentFrame()
            if bar and bar.ResizeToScale then
                bar:ResizeToScale()
            end
        end
        if Addon.SecondaryBarManager and Addon.SecondaryBarManager.GetCurrentFrame then
            local secondaryBar = Addon.SecondaryBarManager:GetCurrentFrame()
            if secondaryBar and secondaryBar.ResizeToScale then
                secondaryBar:ResizeToScale()
            end
        end
    elseif key == "circularSize" then
        -- Resize ring and reposition segments
        if Addon.BarManager and Addon.BarManager.GetCurrentFrame then
            local bar = Addon.BarManager:GetCurrentFrame()
            if bar and bar.RepositionSegments then
                bar:RepositionSegments()
            end
        end
        if Addon.SecondaryBarManager and Addon.SecondaryBarManager.GetCurrentFrame then
            local secondaryBar = Addon.SecondaryBarManager:GetCurrentFrame()
            if secondaryBar and secondaryBar.QueueReposition then
                secondaryBar:QueueReposition()
            end
        end
    elseif key == "circularScaleCenterText" then
        -- Re-layout center text and CenterBG with new scale setting
        if Addon.BarManager and Addon.BarManager.GetCurrentFrame then
            local bar = Addon.BarManager:GetCurrentFrame()
            if bar and bar.RepositionSegments then
                bar:RepositionSegments()
            end
        end
        if Addon.SecondaryBarManager and Addon.SecondaryBarManager.GetCurrentFrame then
            local secondaryBar = Addon.SecondaryBarManager:GetCurrentFrame()
            if secondaryBar and secondaryBar.QueueReposition then
                secondaryBar:QueueReposition()
            end
        end
    elseif key == "sigilSize" then
        -- Resize the ring, re-anchor every element that tracks it, and re-place
        -- the halo pool. ApplySizePreset also clears the skin cache token, so the
        -- Refresh that follows repaints at the new geometry.
        if Addon.BarManager and Addon.BarManager.GetCurrentFrame then
            local bar = Addon.BarManager:GetCurrentFrame()
            if bar and bar.ApplySizePreset then
                bar:ApplySizePreset()
                if bar.ApplySkin then
                    bar:ApplySkin()
                end
            end
        end
        if Addon.SecondaryBarManager and Addon.SecondaryBarManager.GetCurrentFrame then
            local secondaryBar = Addon.SecondaryBarManager:GetCurrentFrame()
            if secondaryBar and secondaryBar.QueueReposition then
                secondaryBar:QueueReposition()
            end
        end
    elseif key == "sigilSkin" or key == "sigilTierMode" or key == "sigilPinnedTier"
        or key == "sigilUseClassColor" then
        -- Repaint only: geometry is unchanged, so no resize and no reposition.
        -- ApplySkin() is called bare here, with no context, which is correct at
        -- this moment because no render is in flight.
        if Addon.BarManager and Addon.BarManager.GetCurrentFrame then
            local bar = Addon.BarManager:GetCurrentFrame()
            if bar and bar.ApplySkin then
                bar:ApplySkin()
            end
        end
    elseif key == "terminalUseCustomColors" then
        -- Terminal colors changed, refresh the bar rendering
        -- (no specific bar method needed — Refresh will re-render with new colors)
    elseif key == "minimapRingCollectButtons" then
        -- Immediately collect or release buttons without waiting for an XP event
        if Addon.BarManager and Addon.BarManager.GetCurrentFrame then
            local bar = Addon.BarManager:GetCurrentFrame()
            if bar and bar.UpdateButtonCollection then
                bar:UpdateButtonCollection(true)
            end
        end
    elseif
        key == "minimapRingPadding" or key == "minimapRingSegments" or
        key == "minimapRingSegmentWidth" or key == "minimapRingSegmentHeight"
    then
        -- Reposition ring/arc immediately so the visual updates without waiting for an XP event
        if Addon.BarManager and Addon.BarManager.GetCurrentFrame then
            local bar = Addon.BarManager:GetCurrentFrame()
            if bar and bar.QueueReposition then
                bar:QueueReposition()
            end
        end
        if Addon.SecondaryBarManager and Addon.SecondaryBarManager.GetCurrentFrame then
            local secondaryBar = Addon.SecondaryBarManager:GetCurrentFrame()
            if secondaryBar and secondaryBar.QueueReposition then
                secondaryBar:QueueReposition()
            end
        end
    elseif
        key == "showQuestXP" or key == "showQuestPercent" or
            key == "showCompleteQuestOverlay" or
            key == "showIncompleteQuestOverlay"
     then
    elseif key == "showMilestoneTicks" then
        if Addon.BarManager and Addon.BarManager.GetCurrentFrame then
            local bar = Addon.BarManager:GetCurrentFrame()
            if bar and bar.UpdateMilestoneTicks then
                local context = nil
                if XPBarContextBuilder and XPBarContextBuilder.BuildContext then
                    context = XPBarContextBuilder.BuildContext("CONFIG_UPDATED")
                end
                local ratio = 0
                if context and context.xpMax and context.xpMax > 0 then
                    ratio = (context.currentXP or 0) / context.xpMax
                end
                bar:UpdateMilestoneTicks(ratio, context)
            end
        end
    end

    -- General refresh
    self:Refresh()
end

function Options:OnColorReset()
    self:UpdateColorControls()
    -- Refresh bars to apply new colors (all domains, single helper)
    if Addon.Colors and Addon.Colors.NotifyColorsChanged then
        Addon.Colors:NotifyColorsChanged()
    end
end

function Options:OnColorChanged(colorKey, hex)
    self:UpdateColorControls()
    -- Refresh bars to apply new colors (all domains, single helper)
    if Addon.Colors and Addon.Colors.NotifyColorsChanged then
        Addon.Colors:NotifyColorsChanged()
    end
end

function Options:OnColorCancel(colorKey, previousHex)
    self:UpdateColorControls()
    -- Refresh bars to apply new colors (all domains, single helper)
    if Addon.Colors and Addon.Colors.NotifyColorsChanged then
        Addon.Colors:NotifyColorsChanged()
    end
end

-- Register as a feature for compatibility
-- Export the mixin into a namespaced table for internal use and also
-- expose the global name required by XML mixin attributes.
Addon.UI = Addon.UI or {}
Addon.UI.Mixins = Addon.UI.Mixins or {}
Addon.UI.Mixins.XPBarEnhancedOptionsMixin = XPBarEnhancedOptionsMixin
_G.XPBarEnhancedOptionsMixin = XPBarEnhancedOptionsMixin

return Options
