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

    -- An alpha-0 frame still takes clicks: the hidden bar would swallow them
    -- (and open the reputation panel) over the strip it covers. Only what
    -- this turned off is turned back on; a style that keeps its mouse off
    -- (Circular attached) stays as it set it.
    if not isAvailable then
        if frame.IsMouseEnabled and frame:IsMouseEnabled() then
            frame._xpbeMouseOffWhileHidden = true
            frame:EnableMouse(false)
        end
    elseif frame._xpbeMouseOffWhileHidden then
        frame._xpbeMouseOffWhileHidden = nil
        frame:EnableMouse(true)
    end

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
    -- Max-level "primary shows secondary source" mode supplies the source's
    -- color so the repurposed primary bar matches the selected source.
    if context and context._secondaryColor then
        return context._secondaryColor
    end

    local Colors = Addon and Addon.Colors
    if not Colors then
        return {r = 1, g = 1, b = 1, a = 1}
    end

    local hasRestedXP = context and (context.hasRestedXP or ((context.restedXP or 0) > 0))
    local colorKey = hasRestedXP and Colors.Key.XpBarRested or Colors.Key.XpBar
    return Colors:Get(colorKey)
end

-------------------------------------------------------------------
-- FILL GRADIENT (styles declaring the fillGradient capability)
-------------------------------------------------------------------

-- The gradient spans the whole bar, from a darker shade of the colour at the
-- empty end to a lighter one at the full end. A texture covering [from, to] of
-- the bar takes the colours the bar has at those two points, so the colours
-- stay where they are as the bar fills, and the overlays continue the fill.
local GRADIENT_DARK = 0.6   -- the empty end: the colour times this
local GRADIENT_LIGHT = 0.35 -- the full end: this far from the colour towards white

-- Set when SetGradient raised: flat colours for the rest of the session.
local gradientFailed = false

local function GradientColorAt(color, t)
    t = math.min(1, math.max(0, t or 0))
    local function channel(c)
        local dark = c * GRADIENT_DARK
        local light = c + (1 - c) * GRADIENT_LIGHT
        return dark + (light - dark) * t
    end
    return channel(color.r or 1), channel(color.g or 1), channel(color.b or 1)
end
Shared.GradientColorAt = GradientColorAt

---Whether this bar paints its fill and overlays as a gradient: the style
---declares the fillGradient capability and the option is on.
function Shared.UsesFillGradient(frame)
    if gradientFailed or type(CreateColor) ~= "function" then
        return false
    end
    local caps = frame and frame.__xpbar_capabilities
    if not (caps and caps.fillGradient == true) then
        return false
    end
    return Addon.Config and Addon.Config.GetOptionValue
        and Addon.Config:GetOptionValue("fillGradient") == true or false
end

-- Whether a vertex colour and a gradient replace each other or multiply is
-- the engine's business; painting never depends on it. Before its first
-- gradient, a texture's vertex colour goes to white (neutral when they
-- multiply), and from then on its flat colour is a two-stop gradient of one
-- colour rather than a vertex colour, so a gradient left behind never tints it.
-- Every colour write on the fill and the overlays goes through here.

-- Reused for every call, the fill being repainted on every animation frame;
-- SetGradient copies the values.
local fromColor, toColor

local function SetTextureGradient(frame, texture, r1, g1, b1, r2, g2, b2, a)
    if not fromColor then
        fromColor, toColor = CreateColor(0, 0, 0, 1), CreateColor(0, 0, 0, 1)
    end
    fromColor:SetRGBA(r1, g1, b1, a)
    toColor:SetRGBA(r2, g2, b2, a)
    local ok = pcall(texture.SetGradient, texture, frame.gradientOrientation or "HORIZONTAL", fromColor, toColor)
    if not ok then
        gradientFailed = true
    end
    return ok
end

-- Paint texture as the stretch [from, to] of the bar's gradient. False when it
-- could not (no gradient for this bar, no span, or SetGradient refused).
-- bar: the StatusBar whose fill texture is, so its colour is the one reset.
local function ApplySpanGradient(frame, texture, color, from, to, bar)
    if not (from and to and texture and texture.SetGradient) or not Shared.UsesFillGradient(frame) then
        return false
    end
    if not texture._xpbeGradient then
        if bar then
            bar:SetStatusBarColor(1, 1, 1, 1)
        else
            texture:SetVertexColor(1, 1, 1, 1)
        end
        texture._xpbeGradient = true
    end
    local r1, g1, b1 = GradientColorAt(color, from)
    local r2, g2, b2 = GradientColorAt(color, to)
    return SetTextureGradient(frame, texture, r1, g1, b1, r2, g2, b2, color.a or 1)
end

-- Paint texture one flat colour. A texture that took a gradient keeps taking
-- them, even after another refused one: its gradient must be replaced.
local function PaintFlat(frame, texture, color, bar)
    local a = color.a or 1
    if texture and texture._xpbeGradient
        and SetTextureGradient(frame, texture, color.r, color.g, color.b, color.r, color.g, color.b, a) then
        return
    end
    if bar then
        bar:SetStatusBarColor(color.r, color.g, color.b, a)
    elseif texture then
        texture:SetVertexColor(color.r, color.g, color.b, a)
    end
end

---Colour an overlay texture: its stretch of the bar's gradient when the bar
---has one, else the flat colour.
---@param frame table The bar
---@param texture table The overlay
---@param color table {r, g, b, a}
---@param from number|nil Where the overlay starts on the bar (0..1); nil paints flat
---@param to number|nil Where it ends
function Shared.PaintSpan(frame, texture, color, from, to)
    if not texture then
        return
    end
    if not ApplySpanGradient(frame, texture, color, from, to) then
        PaintFlat(frame, texture, color)
    end
end

---Colour a StatusBar's fill: [0, its value] of the bar's gradient, else the
---flat colour. Call it after the value is set.
function Shared.PaintStatusBarFill(frame, bar, color)
    if not bar then
        return
    end
    local texture = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
    if texture and Shared.UsesFillGradient(frame) then
        local low, high = bar:GetMinMaxValues()
        local value = bar:GetValue() or 0
        local to = (low and high and high > low) and ((value - low) / (high - low)) or 0
        if ApplySpanGradient(frame, texture, color, 0, to, bar) then
            return
        end
    end
    PaintFlat(frame, texture, color, bar)
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

    GameTooltip:SetOwner(frame, anchor or "ANCHOR_TOP")
    Shared.AddSecondaryTooltipLines(context)
end

--- Add a secondary source's lines (name, standing, progress, session gain,
--- rate, time to next level) to the tooltip being built, so a style that shows
--- the source inside another tooltip uses the same text.
---@param context table|nil Secondary source context
function Shared.AddSecondaryTooltipLines(context)
    if not GameTooltip or not context or context.isAvailable == false then
        return
    end

    local TextFormatter = Addon.TextFormatter
    local StyleHelpers = Addon.UI and Addon.UI.StyleHelpers

    GameTooltip:AddLine(context.name or "", 1, 1, 1)

    if context.isCompanion and context.currentLevel and context.currentLevel > 0 then
        GameTooltip:AddLine(string.format("%s: %d", Addon.L["TT_LEVEL"], context.currentLevel), 0.7, 0.7, 0.7)
    elseif context.standingLabel and context.standingLabel ~= "" then
        GameTooltip:AddLine(context.standingLabel, 0.7, 0.7, 0.7)
    end

    if context.isMaxed then
        GameTooltip:AddLine(string.format("%s: MAX", Addon.L["TT_PROGRESS"]), 0.7, 1, 0.7)
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
            GameTooltip:AddLine(string.format("%s: %s", Addon.L["TT_PROGRESS"], progressText), 0.7, 1, 0.7)
        end

        if TextFormatter and TextFormatter.FormatNumber then
            local currentText = TextFormatter:FormatNumber(displayCurrent, false)
            local maxText = TextFormatter:FormatNumber(displayMax, false)
            GameTooltip:AddDoubleLine(Addon.L["TT_CURRENT"] .. ":", currentText .. " / " .. maxText, 0.7, 0.7, 0.7, 0.7, 0.9, 1)
        end
    end

    if context.sessionGained and context.sessionGained > 0 and TextFormatter and TextFormatter.FormatNumber then
        local gained = TextFormatter:FormatNumber(context.sessionGained, false)
        GameTooltip:AddLine(string.format("%s: +%s", Addon.L["TT_GAINED"], gained), 0.5, 1, 0.5)
    end

    if context.repPerHour and context.repPerHour > 0 and TextFormatter and TextFormatter.FormatNumber then
        local rate = TextFormatter:FormatNumber(context.repPerHour, false)
        GameTooltip:AddLine(string.format("%s: %s/hr", Addon.L["TT_RATE"], rate), 0.5, 0.8, 1)
    end

    if context.timeToNextLevel and context.timeToNextLevel > 0 and TextFormatter and TextFormatter.FormatTime then
        local timeStr = TextFormatter:FormatTime(context.timeToNextLevel, true)
        GameTooltip:AddLine(string.format("%s: %s", Addon.L["TT_NEXT"], timeStr), 0.8, 0.8, 0.5)
    end
end

-- Right-click opens the panel for the active source (see OpenReputationPanel).
local OPEN_PANEL_HINTS = {
    reputation = "TT_OPEN_REPUTATION",
    honor = "TT_OPEN_HONOR",
    housing = "TT_OPEN_HOUSING",
    profession = "TT_OPEN_PROFESSIONS",
}

--- The right-click hint for the active secondary source.
---@return string
function Shared.GetOpenPanelHint()
    local source = Shared.GetActiveSecondarySource and Shared.GetActiveSecondarySource()
    return Addon.L[OPEN_PANEL_HINTS[source] or "TT_OPEN_REPUTATION"]
end

--- Text for a style's level readout. In the max-level "shows secondary
--- source" mode the context carries the source's standing in
--- levelTextOverride ("Renown 3", "Honor Level 29", a profession name);
--- a `compact` readout with no room for that shows the bare level when the
--- source has one.
---@param context table|nil
---@param compact boolean|nil
---@return string
function Shared.GetLevelText(context, compact)
    local override = context and context.levelTextOverride
    if override and override ~= "" then
        local numeric = tonumber(context.level)
        if compact and numeric and numeric > 0 then
            return tostring(numeric)
        end
        return override
    end
    return tostring((context and context.level) or UnitLevel("player"))
end

function Shared.AddSecondaryTooltipMoveHint(context)
    local primaryFrame = Addon.BarManager and Addon.BarManager:GetCurrentFrame()
    local isAttachedToPrimary = (Utils and Utils.GetOptionValue or function() return true end)("secondaryBarsAttached", true) and primaryFrame ~= nil
    if not isAttachedToPrimary then
        GameTooltip:AddLine(Addon.L["TT_SHIFT_DRAG_MOVE"], 0.4, 0.4, 0.4)
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
    local source = Shared.GetActiveSecondarySource and Shared.GetActiveSecondarySource()

    -- Honor: open the PvP UI; Profession: open the professions book.
    if source == "honor" and TogglePVPUI then
        TogglePVPUI()
        return
    elseif source == "profession" then
        if ToggleProfessionsBook then
            ToggleProfessionsBook()
            return
        elseif ToggleSpellBook then
            ToggleSpellBook("professions")
            return
        end
    end

    if source == "housing" then
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
    if Addon:IsFeatureEnabled("housing", "GetCurrentContext") then
        return Addon.HousingSession:GetCurrentContext()
    end
    return nil
end

local function GetReputationContext()
    if Addon:IsFeatureEnabled("reputation", "GetCurrentContext") then
        return Addon.ReputationSession:GetCurrentContext()
    end
    return nil
end

local function GetHonorContext()
    if Addon:IsFeatureEnabled("honor", "GetCurrentContext") then
        return Addon.HonorSession:GetCurrentContext()
    end
    return nil
end

local function GetProfessionContext()
    if Addon:IsFeatureEnabled("profession", "GetCurrentContext") then
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
