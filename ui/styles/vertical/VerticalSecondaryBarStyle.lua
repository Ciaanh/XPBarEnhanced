-- XP Bar Enhanced - Vertical Secondary Bar Style
-- Slim 20x300 vertical reputation bar displayed alongside the vertical primary column.
-- Tooltip-only: no on-bar label (too narrow), all info surfaced on hover.

local Addon = XPBarEnhanced
local SharedStyleHelpers = Addon.UI.SharedStyleHelpers
local StyleHelpers = Addon.UI.StyleHelpers

---@class XPBarVerticalReputationMixin
XPBarVerticalReputationMixin = {}
local StyleMixin = {}

local function GetBarColor(context)
    return StyleHelpers.GetFactionColor(context)
end


function StyleMixin:GetPositionConfigKey()
    return SharedStyleHelpers.GetSecondaryPositionConfigKey()
end

function StyleMixin:GetFallbackPosition()
    return SharedStyleHelpers.BuildConfiguredStyleCenterFallback(44, 0, 44, 0)
end

function StyleMixin:GetAttachedAnchor()
    -- Attach to the RIGHT of the vertical primary column (2px gap).
    -- All horizontal styles use the default BOTTOM→TOP stacking from SecondaryBarManager.
    return "LEFT", "RIGHT", 2, 0
end

function StyleMixin:GetBroadcastEventName()
    return SharedStyleHelpers.GetSecondaryBroadcastEventName()
end

function StyleMixin:GetInitialContext()
    return SharedStyleHelpers.GetSecondaryInitialContext()
end


function StyleMixin:Render(context)
    if not SharedStyleHelpers.BeginSecondaryRender(self, context) then
        return
    end

    local color = GetBarColor(context)
    SharedStyleHelpers.ApplyStatusBarProgress(self.Bar, context, color)
end

function StyleMixin:OnEnter()
    if not self._lastContext then
        return
    end
    local context = self._lastContext
    SharedStyleHelpers.ShowSecondaryTooltip(self, context, "ANCHOR_RIGHT")
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

function StyleMixin:OnDragStart()
    SharedStyleHelpers.BeginSecondaryShiftDrag(self)
end

function StyleMixin:OnDragStop()
    SharedStyleHelpers.EndSecondaryDrag(self)
end

function StyleMixin:OnSecondaryLoad()
    self:ConfigureDragSupport()
end

XPBarVerticalReputationMixin = CreateFromMixins(XPBarSecondaryBaseMixin, StyleMixin)
