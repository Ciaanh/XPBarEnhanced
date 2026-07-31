-- XP Bar Enhanced - Secondary Bar Manager
-- Manages the unified tracked-reputation secondary progress bar.

local Addon = XPBarEnhanced
Addon.SecondaryBarManager = Addon.SecondaryBarManager or {}
local Manager = Addon.SecondaryBarManager
local Utils = Addon.Utils

local function GetOptionValue(key, fallback)
    if Addon.Config and Addon.Config.GetOptionValue then
        local value = Addon.Config:GetOptionValue(key)
        if value ~= nil then
            return value
        end
    end
    return fallback
end

local function GetSettingsTable(key, createIfMissing)
    if Addon.Config and Addon.Config.GetSettingsTable then
        return Addon.Config:GetSettingsTable(key, createIfMissing)
    end

    Addon.db = Addon.db or {}
    if Addon.db[key] == nil and createIfMissing then
        Addon.db[key] = {}
    end
    return Addon.db[key]
end

-- Maps each primary bar style key to its secondary bar template name.
-- Add entries here as new secondary styles are implemented.
local TEMPLATE_MAP = {
    flat     = "FlatReputationBarTemplate",
    classic  = "ClassicReputationBarTemplate",
    circular = "CircularReputationBarTemplate",
    minimap_ring = "MinimapArcReputationBarTemplate",
    vertical = "VerticalReputationBarTemplate",
    terminal = "TerminalReputationBarTemplate",
    orb      = "OrbReputationBarTemplate",
    sigil    = "SigilReputationBarTemplate",
}

local function DeriveSecondaryStyle()
    if not GetOptionValue("showSecondaryBar", false) then
        return "none"
    end
    -- When the primary bar is repurposed to show this same source at max level,
    -- hide the standalone secondary bar so the source isn't rendered twice.
    if Addon.BarManager and Addon.BarManager.ShouldRepurposePrimaryAtMaxLevel
        and Addon.BarManager:ShouldRepurposePrimaryAtMaxLevel() then
        return "none"
    end
    -- The secondary bar style is determined solely by the selected primary bar
    -- style. Use db.barStyle (user preference) rather than the runtime style so
    -- the secondary bar remains visible at max level even when the primary hides.
    local primaryStyle = GetOptionValue("barStyle", "none")
    if TEMPLATE_MAP[primaryStyle] then
        return primaryStyle
    end
    return "none"
end

local function IsCustomStyle(style)
    return style and TEMPLATE_MAP[style] ~= nil
end

local function SetDetachedInteractionState(frame, detached)
    if frame and frame.SetDetachedInteractionEnabled then
        frame:SetDetachedInteractionEnabled(detached)
    end
end

-- Returns true when our secondary bar is active at max level and Blizzard
-- would otherwise promote the reputation bar into the main status bar container.
local function ShouldSuppressMainContainer()
    local barManagerStyle = Addon.BarManager and Addon.BarManager.currentStyle
    local barManagerIdle = not barManagerStyle or barManagerStyle == "none"
    return IsCustomStyle(Manager._currentStyle) and barManagerIdle
end

function Manager:ShouldSuppressMainContainer()
    return ShouldSuppressMainContainer()
end

-- Predicates re-checked when a combat-deferred hide fires, so disabling the
-- secondary bar mid-combat cannot hide Blizzard's bars once combat ends.
local function ShouldHideSecondaryContainer()
    return IsCustomStyle(Manager._currentStyle)
end

-- Any reason the main container must stay hidden (either manager). Deferred
-- hides for a container are keyed per container, so both managers must agree
-- on one main-container predicate.
local function ShouldHideMainContainer()
    local barManager = Addon.BarManager
    if barManager and barManager.IsCustomStyle and barManager:IsCustomStyle(barManager.currentStyle) then
        return true
    end
    return ShouldSuppressMainContainer()
end

-- Safely hide a Blizzard container, deferring to after combat if in lockdown.
local function SafeHideContainer(container)
    local predicate = ShouldHideMainContainer
    if container == _G.SecondaryStatusTrackingBarContainer then
        predicate = ShouldHideSecondaryContainer
    end
    Addon.Utils.SafeHideContainer(container, predicate)
end

-------------------------------------------------------------------
-- INTERNAL
-------------------------------------------------------------------

function Manager:_GetOrCreateFrame(style)
    self._frames = self._frames or {}

    local frame = self._frames[style]
    if not frame then
        local templateName = TEMPLATE_MAP[style]
        if not templateName then
            return nil
        end

        frame = CreateFrame("Frame", nil, UIParent, templateName)
        if not frame then
            error("SecondaryBarManager: failed to create frame from template: " .. templateName)
        end
        self._frames[style] = frame
    end
    return frame
end

function Manager:_SetStyle(style)
    self._frames = self._frames or {}

    if self._currentStyle == style then
        return
    end

    for _, frame in pairs(self._frames) do
        if frame and frame.SetShown then
            frame:SetShown(false)
        end
    end

    self._currentStyle = style

    if style == "none" then
        return
    end

    local frame = self:_GetOrCreateFrame(style)
    if frame and frame.SetShown then
        frame:SetShown(true)
    end
end

-------------------------------------------------------------------
-- PUBLIC API
-------------------------------------------------------------------

function Manager:Initialize()
    self:InstallBlizzardBarHooks()

    self:RefreshForPrimaryStyleChange()

    Addon.EventBus:Register(
        Addon.EventNames.CONFIG_UPDATED,
        "SecondaryBarManager_ConfigUpdated",
        function(_ctx)
            self:RefreshForPrimaryStyleChange()
        end
    )
end

-- Re-evaluate style/visibility/position using the currently configured primary
-- style (db.barStyle), not runtime primary frame visibility.
function Manager:RefreshForPrimaryStyleChange()
    self:SetSecondaryStyle(DeriveSecondaryStyle())
    self:ApplyDefaultReputationBarVisibility()
    self:ReapplyAttachedPositions()

    local frame = self:GetCurrentFrame()
    if frame and frame.QueueReposition then
        frame:QueueReposition()
    elseif frame and frame.Refresh then
        frame:Refresh()
    end
end

-- Stack active secondary bars above the primary XP bar when attached mode is on.
-- When attached mode is off, or when at max level (primary bar hidden), restores
-- each bar to its saved/fallback position.
function Manager:ReapplyAttachedPositions()
    local frame = self:GetCurrentFrame()
    if not frame then
        return
    end

    -- At max level BarManager:GetCurrentFrame() returns nil (runtime style = "none").
    -- In that case no functional attachment target exists, so act as detached.
    local primaryFrame = Addon.BarManager and Addon.BarManager:GetCurrentFrame()
    local canAttachToPrimary = true
    if frame.ShouldAttachToPrimary then
        canAttachToPrimary = frame:ShouldAttachToPrimary() ~= false
    end

    local isAttachedAndPrimaryVisible = GetOptionValue("secondaryBarsAttached", true) and primaryFrame ~= nil and canAttachToPrimary

    SetDetachedInteractionState(frame, not isAttachedAndPrimaryVisible)

    if not isAttachedAndPrimaryVisible then
        if frame.ApplyInitialPosition then
            frame:ApplyInitialPosition()
        end
        -- Enable dragging when the bar is detached (e.g., at max level when primary bar is hidden)
        if frame.ConfigureDragSupport then
            frame:ConfigureDragSupport()
        end
        return
    end

    frame:ClearAllPoints()
    if frame.GetAttachedAnchor then
        local pt, relPt, x, y = frame:GetAttachedAnchor()
        frame:SetPoint(pt, primaryFrame, relPt, x, y)
    else
        frame:SetPoint("BOTTOM", primaryFrame, "TOP", 0, 2)
    end
end

function Manager:GetCurrentFrame()
    local style = self._currentStyle
    if not style or style == "none" then
        return nil
    end

    return self._frames and self._frames[style] or nil
end

function Manager:ApplyDefaultReputationBarVisibility()
    local hasCustomReputationStyle = IsCustomStyle(self._currentStyle)

    if hasCustomReputationStyle then
        SafeHideContainer(_G.SecondaryStatusTrackingBarContainer)
        -- At max level Blizzard promotes the reputation bar to the main container.
        -- Suppress it there too so only our secondary bar is visible.
        if ShouldSuppressMainContainer() then
            SafeHideContainer(_G.MainStatusTrackingBarContainer)
        end
    else
        if _G.SecondaryStatusTrackingBarContainer then
            _G.SecondaryStatusTrackingBarContainer:Show()
        end
    end
end

function Manager:InstallBlizzardBarHooks()
    if self._blizzardHooksInstalled then
        return
    end

    local secondaryContainer = _G.SecondaryStatusTrackingBarContainer
    if secondaryContainer and secondaryContainer.Show then
        hooksecurefunc(secondaryContainer, "Show", function()
            if IsCustomStyle(self._currentStyle) then
                SafeHideContainer(secondaryContainer)
            end
        end)
    end
    if secondaryContainer and secondaryContainer.SetShown then
        hooksecurefunc(secondaryContainer, "SetShown", function(_, shown)
            if shown and IsCustomStyle(self._currentStyle) then
                SafeHideContainer(secondaryContainer)
            end
        end)
    end

    -- At max level Blizzard promotes the watched reputation bar into the main
    -- status bar container. Hook it so we can suppress it when our own bar is active.
    local mainContainer = _G.MainStatusTrackingBarContainer
    if mainContainer and mainContainer.Show then
        hooksecurefunc(mainContainer, "Show", function()
            if ShouldSuppressMainContainer() then
                SafeHideContainer(mainContainer)
            end
        end)
    end
    if mainContainer and mainContainer.SetShown then
        hooksecurefunc(mainContainer, "SetShown", function(_, shown)
            if shown and ShouldSuppressMainContainer() then
                SafeHideContainer(mainContainer)
            end
        end)
    end

    self._blizzardHooksInstalled = true
end

function Manager:SetSecondaryStyle(style)
    self:_SetStyle(style)
    self:ApplyDefaultReputationBarVisibility()
end

function Manager:ResetBarPositions()
    local configKey = "secondaryBarPositions"
    local style = GetOptionValue("barStyle")
    local positions = GetSettingsTable(configKey)

    if positions and style then
        positions[style] = nil
    end

    local frame = self:GetCurrentFrame()
    if frame and frame.ResetPosition then
        frame:ResetPosition()
    end

    self:ReapplyAttachedPositions()
end

return Manager
