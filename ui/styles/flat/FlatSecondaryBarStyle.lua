-- XP Bar Enhanced - Flat Secondary Bar Style
-- Displays the watched faction's reputation progress as a simple flat status bar.

local Addon = XPBarEnhanced
local SharedStyleHelpers = Addon.UI.SharedStyleHelpers
local StyleHelpers = Addon.UI.StyleHelpers

---@class XPBarFlatReputationMixin
XPBarFlatReputationMixin = {}
local StyleMixin = {}

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
    self:ConfigureDragSupport()
end

XPBarFlatReputationMixin = CreateFromMixins(XPBarSecondaryBaseMixin, StyleMixin)