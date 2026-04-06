-- XP Bar Enhanced - Flat Companion Bar Style
-- Displays the Delve companion (Brann) XP progress as a simple flat status bar.

local Addon = XPBarEnhanced

---@class FlatCompanionBarMixin
FlatCompanionBarMixin = {}
local StyleMixin = {}

local BAR_COLOR = {r = 0.20, g = 0.80, b = 0.80}

local function SafeCallErrorHandler(err)
    if CallErrorHandler then
        CallErrorHandler(err)
    else
        print(tostring(err))
    end
end

function StyleMixin:OnSecondaryLoad()
    self.Bar:SetStatusBarColor(BAR_COLOR.r, BAR_COLOR.g, BAR_COLOR.b)
    
    -- Enable dragging for this frame
    self:SetMovable(true)
    self:SetClampedToScreen(true)
    self:RegisterForDrag("LeftButton")
end

function StyleMixin:GetPositionConfigKey()
    return "companionBarPosition"
end

function StyleMixin:GetFallbackPosition()
    return {
        point = "BOTTOM",
        relativeTo = "UIParent",
        relativePoint = "BOTTOM",
        x = 0,
        y = 54,
    }
end

function StyleMixin:GetBroadcastEventName()
    return Addon.EventNames.COMPANION_BROADCAST_UPDATE
end

function StyleMixin:GetInitialContext()
    if XPBarContextBuilder and XPBarContextBuilder.BuildCompanionContext then
        return XPBarContextBuilder.BuildCompanionContext()
    end
    return nil
end

function StyleMixin:GetTextTickerInterval()
    return 1.0  -- Update text every 1 second
end

function StyleMixin:GetTextTickerContext()
    return self:GetInitialContext()
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

    -- Fade out if companion became unavailable
    if wasAvailable and not isAvailable then
        self:FadeToAlpha(0)
        return
    end

    -- Fade in if companion became available
    if not wasAvailable and isAvailable then
        self:FadeToAlpha(1)
    end

    if not isAvailable then
        self:SetAlpha(0)
        return
    end

    self:SetAlpha(1)

    self.Bar:SetMinMaxValues(context.min, context.max)
    self.Bar:SetValue(context.current)

    -- Build label: "CompanionName Lv.X (percent%)"
    local label = context.name
    if context.currentLevel and context.currentLevel > 0 then
        label = label .. string.format(" Lv.%d", context.currentLevel)
    end
    if context.isMaxLevel then
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
    if not self._lastContext then
        return
    end

    local context = self._lastContext
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(context.name, 1, 1, 1)

    if context.currentLevel and context.currentLevel > 0 then
        GameTooltip:AddLine(string.format("Level: %d", context.currentLevel), 0.7, 0.7, 0.7)
    end

    -- Progress line
    if context.isMaxLevel then
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

    -- XP per hour
    if context.xpPerHour and context.xpPerHour > 0 then
        local TextFormatter = Addon.TextFormatter
        local rate = TextFormatter:FormatNumber(context.xpPerHour, false)
        GameTooltip:AddLine(string.format("Rate: %s/hr", rate), 0.5, 0.8, 1)
    end

    -- Time to next level
    if context.timeToNextLevel and context.timeToNextLevel > 0 then
        local TextFormatter = Addon.TextFormatter
        local timeStr = TextFormatter:FormatTime(context.timeToNextLevel, true)
        GameTooltip:AddLine(string.format("Next: %s", timeStr), 0.8, 0.8, 0.5)
    end

    GameTooltip:Show()
end

function StyleMixin:OnLeave()
    GameTooltip:Hide()
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
    if context.currentLevel and context.currentLevel > 0 then
        label = label .. string.format(" Lv.%d", context.currentLevel)
    end
    if context.isMaxLevel then
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

    self:StartMoving()
    self:SetUserPlaced(false)
end

function StyleMixin:OnDragStop()
    self:StopMovingOrSizing()
    self:SetUserPlaced(false)
    self:SavePosition()
end

FlatCompanionBarMixin = CreateFromMixins(XPBarSecondaryBaseMixin, StyleMixin)
