-- XP Bar Enhanced - Secondary Bar Style Helpers
-- Shared helpers for secondary reputation bar styles.

local Addon = XPBarEnhanced
Addon.UI = Addon.UI or {}
Addon.UI.StyleHelpers = Addon.UI.StyleHelpers or {}
local StyleHelpers = Addon.UI.StyleHelpers

local function GetOptionValue(key, fallback)
    if Addon.Config and Addon.Config.GetOptionValue then
        local value = Addon.Config:GetOptionValue(key)
        if value ~= nil then
            return value
        end
    end
    return fallback
end

local FALLBACK_FACTION_COLORS = {
    standard = {r = 0.70, g = 0.30, b = 0.85, a = 1},
    friendship = {r = 0.20, g = 0.85, b = 0.30, a = 1},
    major = {r = 0.20, g = 0.60, b = 1.00, a = 1},
    paragon = {r = 0.95, g = 0.75, b = 0.10, a = 1},
    companion = {r = 0.20, g = 0.80, b = 0.80, a = 1},
    housing = {r = 0.85, g = 0.55, b = 0.20, a = 1},
}

local COLOR_KEY_BY_TYPE = {
    standard = "SecondaryReputation",
    friendship = "SecondaryReputation",
    major = "SecondaryReputation",
    paragon = "SecondaryReputation",
    companion = "SecondaryReputation",
    housing = "SecondaryHousing",
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
    local colorType = "standard"
    if context and context.isCompanion then
        colorType = "companion"
    elseif context and context.factionType then
        colorType = context.factionType
    end

    local Colors = Addon.Colors
    local keyName = COLOR_KEY_BY_TYPE[colorType] or COLOR_KEY_BY_TYPE.standard
    local colorKey = Colors and Colors.Key and Colors.Key[keyName]
    if colorKey and Colors.Get then
        local color = Colors:Get(colorKey)
        if color then
            return color
        end
    end

    return FALLBACK_FACTION_COLORS[colorType] or FALLBACK_FACTION_COLORS.standard
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

function StyleHelpers.GetMinimapRingSegmentHeight()
    local rawHeight = GetOptionValue("minimapRingSegmentHeight", 25)
    return math.max(5, math.min(25, math.floor(tonumber(rawHeight) or 25)))
end

function StyleHelpers.GetMinimapRingRadius(frame)
    if not Minimap then
        return 112
    end

    local minimapEffScale = Minimap:GetEffectiveScale() or 1
    local frameEffScale = frame and frame.GetEffectiveScale and frame:GetEffectiveScale() or 1
    local minimapRadius = ((Minimap:GetWidth() / 2) - 2) * (minimapEffScale / frameEffScale)

    local padding = GetOptionValue("minimapRingPadding", 14)
    padding = math.max(0, math.min(32, math.floor(tonumber(padding) or 14)))
    return minimapRadius + padding
end
