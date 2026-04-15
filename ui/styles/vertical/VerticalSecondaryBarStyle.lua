-- XP Bar Enhanced - Vertical Secondary Bar Style
-- Slim 20x300 vertical reputation bar displayed alongside the vertical primary column.
-- Tooltip-only: no on-bar label (too narrow), all info surfaced on hover.

local Addon = XPBarEnhanced

---@class XPBarVerticalReputationMixin
XPBarVerticalReputationMixin = {}
local StyleMixin = {}

local FACTION_COLORS = {
    standard   = {r = 0.70, g = 0.30, b = 0.85},
    friendship = {r = 0.20, g = 0.85, b = 0.30},
    major      = {r = 0.20, g = 0.60, b = 1.00},
    paragon    = {r = 0.95, g = 0.75, b = 0.10},
    companion  = {r = 0.20, g = 0.80, b = 0.80},
}

local function GetFactionColor(factionType)
    return FACTION_COLORS[factionType] or FACTION_COLORS.standard
end

local function GetBarColor(context)
    if context and context.isCompanion then
        return FACTION_COLORS.companion
    end
    return GetFactionColor(context and context.factionType)
end


function StyleMixin:GetPositionConfigKey()
    return "secondaryBarPositions"
end

function StyleMixin:GetFallbackPosition()
    local db = Addon and Addon.db
    local configuredStyle = db and db.barStyle
    if configuredStyle and configuredStyle ~= "none" then
        local barDefPos = Addon.defaults
            and Addon.defaults.barPositions
            and Addon.defaults.barPositions[configuredStyle]
        if barDefPos then
            return {
                point         = barDefPos.point or "CENTER",
                relativeTo    = barDefPos.relativeTo or "UIParent",
                relativePoint = barDefPos.relativePoint or "CENTER",
                -- Primary is 60px wide; secondary is 20px wide; 4px gap.
                -- Offset right by half-primary (30) + gap (4) + half-secondary (10) = 44.
                x             = (barDefPos.x or 0) + 44,
                y             = barDefPos.y or 0,
            }
        end
    end
    -- Vertical primary has no barPositions default: place 44px right of screen center.
    return {
        point         = "CENTER",
        relativeTo    = "UIParent",
        relativePoint = "CENTER",
        x             = 44,
        y             = 0,
    }
end

function StyleMixin:GetAttachedAnchor()
    -- Attach to the RIGHT of the vertical primary column (2px gap).
    -- All horizontal styles use the default BOTTOM→TOP stacking from SecondaryBarManager.
    return "LEFT", "RIGHT", 2, 0
end

function StyleMixin:GetBroadcastEventName()
    return Addon.EventNames.REPUTATION_BROADCAST_UPDATE
end

function StyleMixin:GetInitialContext()
    if Addon.ReputationSession and Addon.ReputationSession.GetCurrentContext then
        return Addon.ReputationSession:GetCurrentContext()
    end
    return nil
end


function StyleMixin:Render(context)
    if not context then
        return
    end

    local wasAvailable = self._lastContext and self._lastContext.isAvailable
    local isAvailable = context.isAvailable

    self._lastContext = context

    if wasAvailable and not isAvailable then
        self:FadeToAlpha(0)
        return
    end

    if not isAvailable then
        self:SetAlpha(0)
        return
    end

    if not wasAvailable then
        self:FadeToAlpha(1)
    else
        self:SetAlpha(1)
    end

    local color = GetBarColor(context)
    self.Bar:SetMinMaxValues(context.min, context.max)
    self.Bar:SetValue(context.current)
    self.Bar:SetStatusBarColor(color.r, color.g, color.b)
end

function StyleMixin:OnEnter()
    if not GameTooltip or not self._lastContext then
        return
    end

    local context = self._lastContext
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(context.name, 1, 1, 1)

    if context.isCompanion and context.currentLevel and context.currentLevel > 0 then
        GameTooltip:AddLine(string.format("Level: %d", context.currentLevel), 0.7, 0.7, 0.7)
    elseif context.standingLabel and context.standingLabel ~= "" then
        GameTooltip:AddLine(context.standingLabel, 0.7, 0.7, 0.7)
    end

    if context.isMaxed then
        GameTooltip:AddLine("Progress: MAX", 0.7, 1, 0.7)
    else
        local TextFormatter = Addon.TextFormatter
        local progressText = TextFormatter:FormatPercent(context.current, context.max)
        GameTooltip:AddLine(string.format("Progress: %s", progressText), 0.7, 1, 0.7)
    end

    if context.sessionGained and context.sessionGained > 0 then
        local TextFormatter = Addon.TextFormatter
        local gained = TextFormatter:FormatNumber(context.sessionGained, false)
        GameTooltip:AddLine(string.format("Gained: +%s", gained), 0.5, 1, 0.5)
    end

    if context.repPerHour and context.repPerHour > 0 then
        local TextFormatter = Addon.TextFormatter
        local rate = TextFormatter:FormatNumber(context.repPerHour, false)
        GameTooltip:AddLine(string.format("Rate: %s/hr", rate), 0.5, 0.8, 1)
    end

    if context.timeToNextLevel and context.timeToNextLevel > 0 then
        local TextFormatter = Addon.TextFormatter
        local timeStr = TextFormatter:FormatTime(context.timeToNextLevel, true)
        GameTooltip:AddLine(string.format("Next: %s", timeStr), 0.8, 0.8, 0.5)
    end

    GameTooltip:AddLine("Right-click: open Reputation", 0.4, 0.4, 0.4)
    local primaryFrame = Addon.BarManager and Addon.BarManager:GetCurrentFrame()
    local isAttachedToPrimary = Addon.db and Addon.db.secondaryBarsAttached and primaryFrame ~= nil
    if not isAttachedToPrimary then
        GameTooltip:AddLine("Shift+Drag to move", 0.4, 0.4, 0.4)
    end
    GameTooltip:Show()
end

function StyleMixin:OnLeave()
    if GameTooltip then
        GameTooltip:Hide()
    end
end

function StyleMixin:OnMouseUp(button)
    if self.__isDragging then
        self:StopMovingOrSizing()
        self.__isDragging = nil
        if self.SavePosition then
            self:SavePosition()
        end
        return
    end

    if button == "RightButton" then
        self:OnRightClick()
    end
end

function StyleMixin:OnRightClick()
    if ToggleCharacter then
        ToggleCharacter("ReputationFrame")
    end
end

function StyleMixin:OnDragStart()
    if not IsShiftKeyDown() then
        return
    end

    local AddonGlobal = XPBarEnhanced
    if not AddonGlobal.db or AddonGlobal.db.barLocked then
        return
    end

    if AddonGlobal.db.secondaryBarsAttached then
        local primaryFrame = Addon.BarManager and Addon.BarManager:GetCurrentFrame()
        if primaryFrame then
            return
        end
    end

    if InCombatLockdown and InCombatLockdown() then
        return
    end

    self:StartMoving()
    self.__isDragging = true
end

function StyleMixin:OnDragStop()
    self.__isDragging = nil
    local db = Addon and Addon.db
    if db and db.secondaryBarsAttached then
        local primaryFrame = Addon.BarManager and Addon.BarManager:GetCurrentFrame()
        if primaryFrame then
            self:StopMovingOrSizing()
            return
        end
    end

    self:StopMovingOrSizing()
    self:SetUserPlaced(true)
    self:SavePosition()
end

function StyleMixin:OnSecondaryLoad()
    self:ConfigureDragSupport()
end

XPBarVerticalReputationMixin = CreateFromMixins(XPBarSecondaryBaseMixin, StyleMixin)
