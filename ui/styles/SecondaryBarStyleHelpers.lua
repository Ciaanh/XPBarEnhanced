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
    honor = {r = 0.80, g = 0.20, b = 0.20, a = 1},
    profession = {r = 0.30, g = 0.65, b = 0.75, a = 1},
}

local COLOR_KEY_BY_TYPE = {
    standard = "SecondaryReputation",
    friendship = "SecondaryReputation",
    major = "SecondaryReputation",
    paragon = "SecondaryReputation",
    companion = "SecondaryReputation",
    housing = "SecondaryHousing",
    honor = "SecondaryHonor",
    profession = "SecondaryProfession",
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

local function GetDisplayProgressValues(context)
    if not context then
        return 0, 1, 0
    end

    local current = context.current or 0
    local maxValue = context.max or 1
    local remaining = math.max(0, maxValue - current)

    if context.factionType == "housing" then
        current = context.progressCurrent or current
        maxValue = context.progressGoal or maxValue
        remaining = context.progressRemaining
        if remaining == nil then
            remaining = math.max(0, maxValue - current)
        end
    end

    return current, math.max(1, maxValue), math.max(0, remaining)
end

function StyleHelpers.GetDisplayProgressValues(context)
    return GetDisplayProgressValues(context)
end

function StyleHelpers.GetDefaultSecondarySharedHelpers()
    return {
        GetSecondaryPositionConfigKey = function()
            return "secondaryBarPositions"
        end,
        BuildConfiguredStyleCenterFallback = function(defaultX, defaultY, xOffset, yOffset)
            local configuredStyle = (Addon.Config and Addon.Config.GetOptionValue or function() end)("barStyle")
            if configuredStyle and configuredStyle ~= "none" then
                local barDefPos = Addon.defaults
                    and Addon.defaults.barPositions
                    and Addon.defaults.barPositions[configuredStyle]
                if barDefPos then
                    return {
                        point = barDefPos.point or "CENTER",
                        relativeTo = barDefPos.relativeTo or "UIParent",
                        relativePoint = barDefPos.relativePoint or "CENTER",
                        x = (barDefPos.x or 0) + (xOffset or 0),
                        y = (barDefPos.y or 0) + (yOffset or 0),
                    }
                end
            end

            return {
                point = "CENTER",
                relativeTo = "UIParent",
                relativePoint = "CENTER",
                x = defaultX or 0,
                y = defaultY or 0,
            }
        end,
        BuildConfiguredStyleOffsetFallback = function(point, x, y)
            return {
                point = point or "BOTTOM",
                relativeTo = "UIParent",
                relativePoint = point or "BOTTOM",
                x = x or 0,
                y = y or 34,
            }
        end,
        GetSecondaryBroadcastEventName = function()
            return (Addon.EventNames and Addon.EventNames.REPUTATION_BROADCAST_UPDATE) or "REPUTATION:BROADCAST_UPDATE"
        end,
        GetSecondaryInitialContext = function()
            if Addon and Addon.IsFeatureEnabled and Addon:IsFeatureEnabled("reputation", "GetCurrentContext") then
                return Addon.ReputationSession and Addon.ReputationSession:GetCurrentContext()
            end
            return nil
        end,
        BeginSecondaryRender = function(frame, context)
            frame._lastContext = context
            if not context or not context.isAvailable then
                frame:SetAlpha(0)
                return false
            end
            frame:SetAlpha(1)
            return true
        end,
        ApplyStatusBarProgress = function(bar, context, color)
            if not bar or not context then
                return
            end
            bar:SetMinMaxValues(context.min or 0, context.max or 1)
            bar:SetValue(context.current or 0)
            if color then
                bar:SetStatusBarColor(color.r or 1, color.g or 1, color.b or 1, color.a or 1)
            end
        end,
        BuildSecondaryLabel = function(context)
            local name = (context and context.name) or ""
            local percent = (context and context.percent) or 0
            return string.format("%s (%d%%)", name, percent)
        end,
        ShowSecondaryTooltip = function(frame, context, anchor)
            if not GameTooltip then
                return
            end
            GameTooltip:SetOwner(frame, anchor or "ANCHOR_TOP")
            GameTooltip:AddLine((context and context.name) or "", 1, 1, 1)
        end,
        AddSecondaryTooltipMoveHint = function()
        end,
        FinishSecondaryTooltip = function()
            if GameTooltip then
                GameTooltip:Show()
            end
        end,
        HideTooltip = function()
            if GameTooltip then
                GameTooltip:Hide()
            end
        end,
        HandleStandardSecondaryMouseUp = function(frame, button, onRightClick)
            if button == "RightButton" and onRightClick then
                onRightClick(frame)
            end
        end,
        OpenReputationPanel = function()
            if ToggleCharacter then
                ToggleCharacter("ReputationFrame")
            end
        end,
        BeginSecondaryShiftDrag = function()
            return false
        end,
        EndSecondaryDrag = function(frame)
            if frame and frame.StopMovingOrSizing then
                frame:StopMovingOrSizing()
            end
        end,
    }
end

function StyleHelpers.GetDefaultSecondaryStyleHelpers()
    return {
        GetFactionColor = function(context)
            if context and context.factionType == "housing" then
                return {r = 0.85, g = 0.55, b = 0.20, a = 1}
            end
            if context and context.factionType == "honor" then
                return {r = 0.80, g = 0.20, b = 0.20, a = 1}
            end
            if context and context.factionType == "profession" then
                return {r = 0.30, g = 0.65, b = 0.75, a = 1}
            end
            return {r = 0.7, g = 0.3, b = 0.85, a = 1}
        end,
        GetMinimapRingRadius = function()
            return 112
        end,
        GetMinimapRingSegmentHeight = function()
            return 10
        end,
    }
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

    local current, maxValue = GetDisplayProgressValues(context)

    local formatter = Addon.TextFormatter
    if formatter and formatter.FormatPercent then
        return formatter:FormatPercent(current, maxValue)
    end

    return string.format("%d / %d (%d%%)", current, maxValue, context and context.percent or 0)
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
