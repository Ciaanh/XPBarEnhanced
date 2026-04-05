-- XP Bar Enhanced - Flat Companion Bar Style
-- Displays the Delve companion (Brann) XP progress as a simple flat status bar.

local Addon = XPBarEnhanced

---@class FlatCompanionBarMixin
FlatCompanionBarMixin = {}
local StyleMixin = {}

local BAR_COLOR = {r = 0.20, g = 0.80, b = 0.80}

function StyleMixin:OnSecondaryLoad()
    self.Bar:SetStatusBarColor(BAR_COLOR.r, BAR_COLOR.g, BAR_COLOR.b)
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

-------------------------------------------------------------------
-- RENDER
-------------------------------------------------------------------

function StyleMixin:Render(context)
    if not context then
        return
    end

    if not context.isAvailable then
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

FlatCompanionBarMixin = CreateFromMixins(XPBarSecondaryBaseMixin, StyleMixin)
