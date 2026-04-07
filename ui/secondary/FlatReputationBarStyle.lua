-- XP Bar Enhanced - Flat Reputation Bar Style
-- Displays the watched faction's reputation progress as a simple flat status bar.

local Addon = XPBarEnhanced

---@class FlatReputationBarMixin
FlatReputationBarMixin = {}
local StyleMixin = {}

local FACTION_COLORS = {
    standard   = {r = 0.70, g = 0.30, b = 0.85},
    friendship = {r = 0.20, g = 0.85, b = 0.30},
    major      = {r = 0.20, g = 0.60, b = 1.00},
    paragon    = {r = 0.95, g = 0.75, b = 0.10},
}

local function GetFactionColor(factionType)
    return FACTION_COLORS[factionType] or FACTION_COLORS.standard
end

local function SafeCallErrorHandler(err)
    if CallErrorHandler then
        CallErrorHandler(err)
    else
        print(tostring(err))
    end
end

local function DebugSecondary(message, ...)
    local db = Addon and Addon.db
    if db and db.debugSecondaryBars == false then
        return
    end

    local text = tostring(message or "")
    if select("#", ...) > 0 then
        text = string.format(text, ...)
    end
    print("|cff66ccffXPBE Secondary|r " .. text)
end

function StyleMixin:GetPositionConfigKey()
    return "reputationBarPosition"
end

function StyleMixin:GetFallbackPosition()
    return {
        point = "CENTER",
        relativeTo = "SecondaryStatusTrackingBarContainer",
        relativePoint = "CENTER",
        x = 0,
        y = 0,
    }
end

function StyleMixin:GetBroadcastEventName()
    return Addon.EventNames.REPUTATION_BROADCAST_UPDATE
end

function StyleMixin:GetInitialContext()
    if XPBarContextBuilder and XPBarContextBuilder.BuildReputationContext then
        return XPBarContextBuilder.BuildReputationContext()
    end
    return nil
end

function StyleMixin:GetTextTickerInterval()
    return 1.0  -- Update text every 1 second
end

function StyleMixin:GetTextTickerContext()
    return self._lastContext or self:GetInitialContext()
end

-------------------------------------------------------------------
-- RENDER
-------------------------------------------------------------------

function StyleMixin:Render(context)
    if not context then
        return
    end

    -- Track availability state changes for fade transitions
    local wasAvailable = self._lastContext and self._lastContext.isAvailable
    local isAvailable = context.isAvailable
    
    self._lastContext = context

    -- Fade out if faction became unavailable (untracked)
    if wasAvailable and not isAvailable then
        self:FadeToAlpha(0)
        return
    end

    -- Fade in if faction became available (tracked)
    if not wasAvailable and isAvailable then
        self:FadeToAlpha(1)
    end

    if not isAvailable then
        self:SetAlpha(0)
        return
    end

    self:SetAlpha(1)

    local color = GetFactionColor(context.factionType)
    self.Bar:SetMinMaxValues(context.min, context.max)
    self.Bar:SetValue(context.current)
    self.Bar:SetStatusBarColor(color.r, color.g, color.b)

    -- Build label: "FactionName - Standing (percent%)"
    local label = context.name
    if context.standingLabel and context.standingLabel ~= "" then
        label = label .. " - " .. context.standingLabel
    end
    if context.isMaxed then
        label = label .. " (MAX)"
    else
        label = label .. string.format(" (%d%%)", context.percent)
    end
    self.LabelContainer.Label:SetText(label)
end

-------------------------------------------------------------------
-- TOOLTIP SUPPORT (Feature 3)
-------------------------------------------------------------------

function StyleMixin:OnEnter()
    if not GameTooltip or not self._lastContext then
        return
    end

    local context = self._lastContext
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(context.name, 1, 1, 1)

    if context.standingLabel and context.standingLabel ~= "" then
        GameTooltip:AddLine(context.standingLabel, 0.7, 0.7, 0.7)
    end

    -- Progress line
    if context.isMaxed then
        GameTooltip:AddLine("Progress: MAX", 0.7, 1, 0.7)
    else
        local TextFormatter = Addon.TextFormatter
        local progressText = TextFormatter:FormatPercent(context.current, context.max)
        GameTooltip:AddLine(string.format("Progress: %s", progressText), 0.7, 1, 0.7)
    end

    -- Session gained
    if context.sessionGained and context.sessionGained > 0 then
        local TextFormatter = Addon.TextFormatter
        local gained = TextFormatter:FormatNumber(context.sessionGained, false)
        GameTooltip:AddLine(string.format("Gained: +%s", gained), 0.5, 1, 0.5)
    end

    -- Rep per hour
    if context.repPerHour and context.repPerHour > 0 then
        local TextFormatter = Addon.TextFormatter
        local rate = TextFormatter:FormatNumber(context.repPerHour, false)
        GameTooltip:AddLine(string.format("Rate: %s/hr", rate), 0.5, 0.8, 1)
    end

    -- Time to next standing
    if context.timeToNextLevel and context.timeToNextLevel > 0 then
        local TextFormatter = Addon.TextFormatter
        local timeStr = TextFormatter:FormatTime(context.timeToNextLevel, true)
        GameTooltip:AddLine(string.format("Next: %s", timeStr), 0.8, 0.8, 0.5)
    end

    GameTooltip:Show()
end

function StyleMixin:OnLeave()
    if GameTooltip then
        GameTooltip:Hide()
    end
end

-------------------------------------------------------------------
-- LIVE TEXT REFRESH SUPPORT (Feature 4)
-------------------------------------------------------------------

function StyleMixin:OnTextTick(context)
    if not context or not context.isAvailable then
        return
    end

    -- Rebuild label with fresh calculations
    local label = context.name
    if context.standingLabel and context.standingLabel ~= "" then
        label = label .. " - " .. context.standingLabel
    end
    if context.isMaxed then
        label = label .. " (MAX)"
    else
        label = label .. string.format(" (%d%%)", context.percent)
    end
    
    self.LabelContainer.Label:SetText(label)
end

-------------------------------------------------------------------
-- DRAG-TO-MOVE SUPPORT (Feature 2)
-------------------------------------------------------------------

function StyleMixin:OnDragStart()
    -- Match XP bar behavior: Shift + Left drag while unlocked.
    if not IsShiftKeyDown() then
        return
    end

    -- Only allow dragging if bar is unlocked
    local Addon = XPBarEnhanced
    if not Addon.db or Addon.db.barLocked then
        return
    end

    if Addon.db.secondaryBarsAttached then
        DebugSecondary("Reputation drag blocked: attached mode enabled")
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        return
    end

    self:StartMoving()
end

function StyleMixin:OnDragStop()
    local db = Addon and Addon.db
    if db and db.secondaryBarsAttached then
        self:StopMovingOrSizing()
        return
    end

    self:StopMovingOrSizing()
    self:SetUserPlaced(true)
    self:SavePosition()
    DebugSecondary("Reputation drag stop: saved position")
end

function StyleMixin:OnSecondaryLoad()
    self:ConfigureDragSupport()
end

FlatReputationBarMixin = CreateFromMixins(XPBarSecondaryBaseMixin, StyleMixin)
