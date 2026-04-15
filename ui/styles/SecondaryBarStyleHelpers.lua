-- XP Bar Enhanced - Secondary Bar Style Helpers
-- Shared helpers for secondary reputation bar styles.

local Addon = XPBarEnhanced
Addon.UI = Addon.UI or {}
Addon.UI.StyleHelpers = Addon.UI.StyleHelpers or {}
local StyleHelpers = Addon.UI.StyleHelpers

local FACTION_COLORS = {
    standard = {r = 0.70, g = 0.30, b = 0.85},
    friendship = {r = 0.20, g = 0.85, b = 0.30},
    major = {r = 0.20, g = 0.60, b = 1.00},
    paragon = {r = 0.95, g = 0.75, b = 0.10},
    companion = {r = 0.20, g = 0.80, b = 0.80},
}

local function Clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

function StyleHelpers.GetFactionColor(context)
    if context and context.isCompanion then
        return FACTION_COLORS.companion
    end

    local factionType = context and context.factionType or "standard"
    return FACTION_COLORS[factionType] or FACTION_COLORS.standard
end

function StyleHelpers.BuildTooltipProgressText(context)
    if context and context.isMaxed then
        return "MAX"
    end

    local formatter = Addon.TextFormatter
    if formatter and formatter.FormatPercent then
        return formatter:FormatPercent(context and context.current, context and context.max)
    end

    return string.format("%d / %d (%d%%)", context and context.current or 0, context and context.max or 1, context and context.percent or 0)
end
