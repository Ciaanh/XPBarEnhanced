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

function StyleMixin:GetPositionConfigKey()
    return "reputationBarPosition"
end

function StyleMixin:GetFallbackPosition()
    return {
        point = "BOTTOM",
        relativeTo = "UIParent",
        relativePoint = "BOTTOM",
        x = 0,
        y = 34,
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

FlatReputationBarMixin = CreateFromMixins(XPBarSecondaryBaseMixin, StyleMixin)
