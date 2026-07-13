-- XP Bar Enhanced - Shared Style Helpers
-- Cross-style helpers used by both primary and secondary style implementations.

local Addon = XPBarEnhanced
local Utils = Addon.Utils
Addon.UI = Addon.UI or {}
Addon.UI.SharedStyleHelpers = Addon.UI.SharedStyleHelpers or {}

local Shared = Addon.UI.SharedStyleHelpers

local BAR_SIZE_SCALES = {
    small   = 0.7,
    default = 1.0,
    large   = 1.5,
    huge    = 2.0,
}

-- Standard availability/visibility transition for secondary bars.
-- Returns true when the style should continue with paint operations.
function Shared.BeginSecondaryRender(frame, context)
    if not frame or not context then
        return false
    end

    local wasAvailable = frame._lastContext and frame._lastContext.isAvailable
    local isAvailable = context.isAvailable
    frame._lastContext = context

    if wasAvailable and not isAvailable then
        frame:FadeToAlpha(0)
        return false
    end

    if not isAvailable then
        frame:SetAlpha(0)
        return false
    end

    if not wasAvailable then
        frame:FadeToAlpha(1)
    else
        frame:SetAlpha(1)
    end

    return true
end

-- Apply standard status bar progress values and color from a context payload.
function Shared.ApplyStatusBarProgress(bar, context, color)
    if not bar or not context then
        return
    end

    bar:SetMinMaxValues(context.min, context.max)
    bar:SetValue(context.current)

    if color then
        bar:SetStatusBarColor(color.r, color.g, color.b, color.a or 1)
    end
end

function Shared.GetXPBarColor(context)
    local Colors = Addon and Addon.Colors
    if not Colors then
        return {r = 1, g = 1, b = 1, a = 1}
    end

    local hasRestedXP = context and (context.hasRestedXP or ((context.restedXP or 0) > 0))
    local colorKey = hasRestedXP and Colors.Key.XpBarRested or Colors.Key.XpBar
    return Colors:Get(colorKey)
end

function Shared.GetBarScale(configKey)
    if not configKey or not Addon.Config or not Addon.Config.GetOptionValue then
        return BAR_SIZE_SCALES.default
    end

    local sizeKey = Addon.Config:GetOptionValue(configKey)
    if type(sizeKey) ~= "string" then
        return BAR_SIZE_SCALES.default
    end

    return BAR_SIZE_SCALES[sizeKey] or BAR_SIZE_SCALES.default
end

function Shared.ApplySegmentTypeColor(segment, segmentType, colors, emptyColor, overlayAlpha)
    if not segment then
        return
    end

    local SEGMENT_TYPE = {
        HIDDEN = -1,
        EMPTY = 0,
        CURRENT_XP = 1,
        RESTED = 2,
        QUEST_COMPLETE = 3,
        QUEST_INCOMPLETE = 4,
    }

    overlayAlpha = overlayAlpha or 1.0
    emptyColor = emptyColor or {r = 0.1, g = 0.1, b = 0.1, a = 0.3}

    if segmentType == SEGMENT_TYPE.CURRENT_XP then
        local color = colors and colors.currentXP
        if color and color.r then
            segment:SetVertexColor(color.r, color.g, color.b, (color.a or 1) * overlayAlpha)
        else
            segment:SetVertexColor(emptyColor.r, emptyColor.g, emptyColor.b, emptyColor.a)
        end
    elseif segmentType == SEGMENT_TYPE.QUEST_COMPLETE then
        local color = colors and colors.questComplete
        if color and color.r then
            segment:SetVertexColor(color.r, color.g, color.b, (color.a or 1) * overlayAlpha)
        else
            segment:SetVertexColor(emptyColor.r, emptyColor.g, emptyColor.b, emptyColor.a)
        end
    elseif segmentType == SEGMENT_TYPE.QUEST_INCOMPLETE then
        local color = colors and colors.questIncomplete
        if color and color.r then
            segment:SetVertexColor(color.r, color.g, color.b, (color.a or 1) * overlayAlpha)
        else
            segment:SetVertexColor(emptyColor.r, emptyColor.g, emptyColor.b, emptyColor.a)
        end
    elseif segmentType == SEGMENT_TYPE.RESTED then
        local color = colors and colors.rested
        if color and color.r then
            segment:SetVertexColor(color.r, color.g, color.b, color.a or 1)
        else
            segment:SetVertexColor(emptyColor.r, emptyColor.g, emptyColor.b, emptyColor.a)
        end
    else
        segment:SetVertexColor(emptyColor.r, emptyColor.g, emptyColor.b, emptyColor.a)
    end
end

function Shared.HideTooltip()
    if GameTooltip then
        GameTooltip:Hide()
    end
end

function Shared.ShowSecondaryTooltip(frame, context, anchor)
    if not GameTooltip or not frame or not context then
        return
    end

    if context.isAvailable == false then
        return
    end

    local TextFormatter = Addon.TextFormatter
    local StyleHelpers = Addon.UI and Addon.UI.StyleHelpers
    local tooltipAnchor = anchor or "ANCHOR_TOP"

    GameTooltip:SetOwner(frame, tooltipAnchor)
    GameTooltip:AddLine(context.name or "", 1, 1, 1)

    if context.isCompanion and context.currentLevel and context.currentLevel > 0 then
        GameTooltip:AddLine(string.format("Level: %d", context.currentLevel), 0.7, 0.7, 0.7)
    elseif context.standingLabel and context.standingLabel ~= "" then
        GameTooltip:AddLine(context.standingLabel, 0.7, 0.7, 0.7)
    end

    if context.isMaxed then
        GameTooltip:AddLine("Progress: MAX", 0.7, 1, 0.7)
    else
        local progressText = nil
        local displayCurrent = context.current or 0
        local displayMax = context.max or 1
        local displayRemaining = math.max(0, displayMax - displayCurrent)

        if StyleHelpers and StyleHelpers.GetDisplayProgressValues then
            displayCurrent, displayMax, displayRemaining = StyleHelpers.GetDisplayProgressValues(context)
        end

        if StyleHelpers and StyleHelpers.BuildTooltipProgressText then
            progressText = StyleHelpers.BuildTooltipProgressText(context)
        elseif TextFormatter and TextFormatter.FormatPercent then
            progressText = TextFormatter:FormatPercent(displayCurrent, displayMax)
        end
        if progressText then
            GameTooltip:AddLine(string.format("Progress: %s", progressText), 0.7, 1, 0.7)
        end

        if TextFormatter and TextFormatter.FormatNumber then
            local currentText = TextFormatter:FormatNumber(displayCurrent, false)
            local maxText = TextFormatter:FormatNumber(displayMax, false)
            GameTooltip:AddDoubleLine("Current:", currentText .. " / " .. maxText, 0.7, 0.7, 0.7, 0.7, 0.9, 1)
        end
    end

    if context.sessionGained and context.sessionGained > 0 and TextFormatter and TextFormatter.FormatNumber then
        local gained = TextFormatter:FormatNumber(context.sessionGained, false)
        GameTooltip:AddLine(string.format("Gained: +%s", gained), 0.5, 1, 0.5)
    end

    if context.repPerHour and context.repPerHour > 0 and TextFormatter and TextFormatter.FormatNumber then
        local rate = TextFormatter:FormatNumber(context.repPerHour, false)
        GameTooltip:AddLine(string.format("Rate: %s/hr", rate), 0.5, 0.8, 1)
    end

    if context.timeToNextLevel and context.timeToNextLevel > 0 and TextFormatter and TextFormatter.FormatTime then
        local timeStr = TextFormatter:FormatTime(context.timeToNextLevel, true)
        GameTooltip:AddLine(string.format("Next: %s", timeStr), 0.8, 0.8, 0.5)
    end
end

function Shared.AddSecondaryTooltipMoveHint(context)
    local primaryFrame = Addon.BarManager and Addon.BarManager:GetCurrentFrame()
    local isAttachedToPrimary = (Utils and Utils.GetOptionValue or function() return true end)("secondaryBarsAttached", true) and primaryFrame ~= nil
    if not isAttachedToPrimary then
        GameTooltip:AddLine("Shift+Drag to move", 0.4, 0.4, 0.4)
    end
end

function Shared.FinishSecondaryTooltip()
    if GameTooltip then
        GameTooltip:Show()
    end
end

function Shared.BeginSecondaryShiftDrag(frame)
    if not frame or not IsShiftKeyDown() then
        return false
    end

    if (Utils and Utils.GetOptionValue or function() return false end)("barLocked", false) then
        return false
    end

    if (Utils and Utils.GetOptionValue or function() return true end)("secondaryBarsAttached", true) then
        local primaryFrame = Addon.BarManager and Addon.BarManager:GetCurrentFrame()
        if primaryFrame then
            return false
        end
    end

    if InCombatLockdown and InCombatLockdown() then
        return false
    end

    frame:StartMoving()
    frame.__isDragging = true
    return true
end

function Shared.EndSecondaryDrag(frame)
    if not frame then
        return
    end

    frame.__isDragging = nil

    if (Utils and Utils.GetOptionValue or function() return true end)("secondaryBarsAttached", true) then
        local primaryFrame = Addon.BarManager and Addon.BarManager:GetCurrentFrame()
        if primaryFrame then
            frame:StopMovingOrSizing()
            return
        end
    end

    frame:StopMovingOrSizing()
    frame:SetUserPlaced(true)
    if frame.SavePosition then
        frame:SavePosition()
    end
end

function Shared.BuildSecondaryLabel(context)
    local label = (context and context.name) or ""
    if context and context.isCompanion then
        if context.currentLevel and context.currentLevel > 0 then
            label = label .. string.format(" Lv.%d", context.currentLevel)
        end
    elseif context and context.standingLabel and context.standingLabel ~= "" then
        label = label .. " - " .. context.standingLabel
    end

    if context and context.isMaxed then
        return label .. " (MAX)"
    end

    if context and context.factionType == "housing" then
        local formatter = Addon.TextFormatter
        local StyleHelpers = Addon.UI and Addon.UI.StyleHelpers
        local displayCurrent = context.current or 0
        local displayMax = context.max or 1

        if StyleHelpers and StyleHelpers.GetDisplayProgressValues then
            displayCurrent, displayMax = StyleHelpers.GetDisplayProgressValues(context)
        end

        if formatter and formatter.FormatNumber then
            return label .. string.format(
                " (%s / %s)",
                formatter:FormatNumber(displayCurrent, false),
                formatter:FormatNumber(displayMax, false)
            )
        end
    end

    return label .. string.format(" (%d%%)", (context and context.percent) or 0)
end

function Shared.OpenReputationPanel()
    if Shared.GetActiveSecondarySource and Shared.GetActiveSecondarySource() == "housing" then
        if HousingFramesUtil and HousingFramesUtil.ToggleHousingDashboard then
            HousingFramesUtil.ToggleHousingDashboard()
            return
        end

        if C_AddOns and C_AddOns.LoadAddOn then
            C_AddOns.LoadAddOn("Blizzard_HousingEventHandler")
            if HousingFramesUtil and HousingFramesUtil.ToggleHousingDashboard then
                HousingFramesUtil.ToggleHousingDashboard()
                return
            end

            C_AddOns.LoadAddOn("Blizzard_HousingDashboard")
            if HousingDashboardFrame and ToggleFrame then
                ToggleFrame(HousingDashboardFrame)
                return
            end
        end
    end

    if ToggleCharacter then
        ToggleCharacter("ReputationFrame")
    end
end

function Shared.HandleStandardSecondaryMouseUp(frame, button, onRightClick)
    if not frame then
        return
    end

    if frame.__isDragging then
        frame:StopMovingOrSizing()
        frame.__isDragging = nil
        if frame.SavePosition then
            frame:SavePosition()
        end
        return
    end

    if button == "RightButton" then
        if onRightClick then
            onRightClick(frame)
        else
            Shared.OpenReputationPanel()
        end
    end
end

function Shared.BuildConfiguredStyleOffsetFallback(defaultPoint, defaultX, defaultY, yOffset)
    local configuredStyle = (Utils and Utils.GetOptionValue or function() end)("barStyle")
    if configuredStyle and configuredStyle ~= "none" then
        local barDefPos = Addon.defaults
            and Addon.defaults.barPositions
            and Addon.defaults.barPositions[configuredStyle]
        if barDefPos then
            return {
                point         = barDefPos.point or defaultPoint,
                relativeTo    = barDefPos.relativeTo or "UIParent",
                relativePoint = barDefPos.relativePoint or defaultPoint,
                x             = barDefPos.x or defaultX,
                y             = (barDefPos.y or 0) + (yOffset or 0),
            }
        end
    end

    return {
        point         = defaultPoint,
        relativeTo    = "UIParent",
        relativePoint = defaultPoint,
        x             = defaultX,
        y             = defaultY,
    }
end

function Shared.BuildConfiguredStyleCenterFallback(defaultX, defaultY, xOffset, yOffset)
    local configuredStyle = (Utils and Utils.GetOptionValue or function() end)("barStyle")
    if configuredStyle and configuredStyle ~= "none" then
        local barDefPos = Addon.defaults
            and Addon.defaults.barPositions
            and Addon.defaults.barPositions[configuredStyle]
        if barDefPos then
            return {
                point         = barDefPos.point or "CENTER",
                relativeTo    = barDefPos.relativeTo or "UIParent",
                relativePoint = barDefPos.relativePoint or "CENTER",
                x             = (barDefPos.x or 0) + (xOffset or 0),
                y             = (barDefPos.y or 0) + (yOffset or 0),
            }
        end
    end

    return {
        point         = "CENTER",
        relativeTo    = "UIParent",
        relativePoint = "CENTER",
        x             = defaultX or 0,
        y             = defaultY or 0,
    }
end

function Shared.GetSecondaryPositionConfigKey()
    return "secondaryBarPositions"
end

local function ResolveConfiguredSecondarySource()
    local source = nil
    if Addon.Config and Addon.Config.GetOptionValue then
        source = Addon.Config:GetOptionValue("secondaryBarSource")
    end
    if source == nil and Addon.db then
        source = Addon.db.secondaryBarSource
    end
    if source == "housing" or source == "reputation"
        or source == "honor" or source == "profession" then
        return source
    end
    return "reputation"
end

local function GetHousingContext()
    if Addon.HousingSession and Addon.HousingSession.GetCurrentContext then
        return Addon.HousingSession:GetCurrentContext()
    end
    return nil
end

local function GetReputationContext()
    if Addon.ReputationSession and Addon.ReputationSession.GetCurrentContext then
        return Addon.ReputationSession:GetCurrentContext()
    end
    return nil
end

local function GetHonorContext()
    if Addon.HonorSession and Addon.HonorSession.GetCurrentContext then
        return Addon.HonorSession:GetCurrentContext()
    end
    return nil
end

local function GetProfessionContext()
    if Addon.ProfessionSession and Addon.ProfessionSession.GetCurrentContext then
        return Addon.ProfessionSession:GetCurrentContext()
    end
    return nil
end

function Shared.GetActiveSecondarySource()
    return ResolveConfiguredSecondarySource()
end

function Shared.GetSecondaryBroadcastEventName()
    if not Addon.EventNames then
        return {
            "REPUTATION:BROADCAST_UPDATE",
            "HOUSING:BROADCAST_UPDATE",
        }
    end

    return {
        Addon.EventNames.REPUTATION_BROADCAST_UPDATE or "REPUTATION:BROADCAST_UPDATE",
        Addon.EventNames.HOUSING_BROADCAST_UPDATE or "HOUSING:BROADCAST_UPDATE",
        Addon.EventNames.HONOR_BROADCAST_UPDATE or "HONOR:BROADCAST_UPDATE",
        Addon.EventNames.PROFESSION_BROADCAST_UPDATE or "PROFESSION:BROADCAST_UPDATE",
    }
end

function Shared.GetSecondaryInitialContext()
    local source = Shared.GetActiveSecondarySource()
    if source == "housing" then
        return GetHousingContext()
    elseif source == "honor" then
        return GetHonorContext()
    elseif source == "profession" then
        return GetProfessionContext()
    end

    return GetReputationContext()
end

return Shared
