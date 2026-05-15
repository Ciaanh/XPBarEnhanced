-- XP Bar Enhanced - Flat Secondary Bar Style
-- Displays the watched faction's reputation progress as a simple flat status bar.

local Addon = XPBarEnhanced
local FALLBACK_SHARED_STYLE_HELPERS = {
    GetSecondaryPositionConfigKey = function()
        return "secondaryBarPositions"
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
        if Addon.ReputationSession and Addon.ReputationSession.GetCurrentContext then
            return Addon.ReputationSession:GetCurrentContext()
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

local FALLBACK_STYLE_HELPERS = {
    GetFactionColor = function()
        return {r = 0.7, g = 0.3, b = 0.85, a = 1}
    end,
}

local function ResolveSharedStyleHelpers()
    local shared = Addon and Addon.UI and Addon.UI.SharedStyleHelpers
    return shared or FALLBACK_SHARED_STYLE_HELPERS
end

local function ResolveStyleHelpers()
    local style = Addon and Addon.UI and Addon.UI.StyleHelpers
    return style or FALLBACK_STYLE_HELPERS
end

local SharedStyleHelpers = setmetatable({}, {
    __index = function(_, key)
        return ResolveSharedStyleHelpers()[key]
    end,
})

local StyleHelpers = setmetatable({}, {
    __index = function(_, key)
        return ResolveStyleHelpers()[key]
    end,
})

---@class XPBarFlatReputationMixin
XPBarFlatReputationMixin = {}
local StyleMixin = {}

local BASE_WIDTH = 565
local BASE_HEIGHT = 18

local function GetBarColor(context)
    return StyleHelpers.GetFactionColor(context)
end

function StyleMixin:GetPositionConfigKey()
    return SharedStyleHelpers.GetSecondaryPositionConfigKey()
end

function StyleMixin:GetFallbackPosition()
    return SharedStyleHelpers.BuildConfiguredStyleOffsetFallback("BOTTOM", 0, 34, 20)
end

function StyleMixin:GetBroadcastEventName()
    return SharedStyleHelpers.GetSecondaryBroadcastEventName()
end

function StyleMixin:GetInitialContext()
    return SharedStyleHelpers.GetSecondaryInitialContext()
end

function StyleMixin:GetTextTickerInterval()
    return 1.0
end

function StyleMixin:GetTextTickerContext()
    return self._lastContext or self:GetInitialContext()
end

function StyleMixin:ResizeToScale()
    local scale = (SharedStyleHelpers.GetBarScale and SharedStyleHelpers.GetBarScale("flatSize")) or 1.0
    local width = BASE_WIDTH * scale
    local height = BASE_HEIGHT * scale

    self:SetSize(width, height)

    -- Keep child geometry synchronized with frame scale.
    if self.Bar and self.Bar.SetSize then
        self.Bar:SetSize(width, height)
    end
    if self.LabelContainer and self.LabelContainer.Label and self.LabelContainer.Label.SetSize then
        self.LabelContainer.Label:SetSize(width, height)
    end
end

function StyleMixin:Render(context)
    if not SharedStyleHelpers.BeginSecondaryRender(self, context) then
        return
    end

    local color = GetBarColor(context)
    SharedStyleHelpers.ApplyStatusBarProgress(self.Bar, context, color)
    self.LabelContainer.Label:SetText(SharedStyleHelpers.BuildSecondaryLabel(context))
end

function StyleMixin:OnEnter()
    if not self._lastContext then
        return
    end
    local context = self._lastContext
    SharedStyleHelpers.ShowSecondaryTooltip(self, context, "ANCHOR_TOP")
    GameTooltip:AddLine("Right-click: open Reputation", 0.4, 0.4, 0.4)
    SharedStyleHelpers.AddSecondaryTooltipMoveHint(context)
    SharedStyleHelpers.FinishSecondaryTooltip()
end

function StyleMixin:OnLeave()
    SharedStyleHelpers.HideTooltip()
end

function StyleMixin:OnMouseUp(button)
    SharedStyleHelpers.HandleStandardSecondaryMouseUp(self, button, self.OnRightClick)
end

function StyleMixin:OnRightClick()
    SharedStyleHelpers.OpenReputationPanel()
end

function StyleMixin:OnTextTick(context)
    if not context or not context.isAvailable then
        return
    end

    self.LabelContainer.Label:SetText(SharedStyleHelpers.BuildSecondaryLabel(context))
end

function StyleMixin:OnDragStart()
    SharedStyleHelpers.BeginSecondaryShiftDrag(self)
end

function StyleMixin:OnDragStop()
    SharedStyleHelpers.EndSecondaryDrag(self)
end

function StyleMixin:OnSecondaryLoad()
    self:ResizeToScale()
    self:ConfigureDragSupport()
end

XPBarFlatReputationMixin = CreateFromMixins(XPBarSecondaryBaseMixin, StyleMixin)