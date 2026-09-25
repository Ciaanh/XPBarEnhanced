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

local GetSettingsTable = Addon.Utils.GetSettingsTable

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
    -- Resolved the way the primary bar resolves it, so a stored style this
    -- build cannot render still gets the secondary bar of the style shown.
    if Addon.BarManager and Addon.BarManager.ResolveStyleKey then
        primaryStyle = Addon.BarManager:ResolveStyleKey(primaryStyle)
    end
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

--- True while one of the addon's secondary bars is showing.
function Manager:IsActive()
    return IsCustomStyle(self._currentStyle) and true or false
end

-- See BlizzardBars: it hides Blizzard's container for whatever bar this one
-- stands in for, and hands it back when this bar goes away.
function Manager:ApplyDefaultReputationBarVisibility()
    if Addon.BlizzardBars then
        Addon.BlizzardBars:Refresh()
    end
end

function Manager:SetSecondaryStyle(style)
    self:_SetStyle(style)
    self:ApplyDefaultReputationBarVisibility()
end

function Manager:ResetBarPositions()
    local configKey = "secondaryBarPositions"
    local style = GetOptionValue("barStyle")
    -- The write target: a plain read falls back to Global's table on a profile.
    local positions = GetSettingsTable(configKey, true)

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
