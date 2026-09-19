-- XP Bar Enhanced - Vertical Secondary Bar Style
-- Slim 20x300 vertical reputation bar displayed alongside the vertical primary column.
-- Tooltip-only: no on-bar label (too narrow), all info surfaced on hover.

local Addon = XPBarEnhanced
local FALLBACK_SHARED_STYLE_HELPERS = Addon and Addon.UI and Addon.UI.StyleHelpers and Addon.UI.StyleHelpers.GetDefaultSecondarySharedHelpers and Addon.UI.StyleHelpers:GetDefaultSecondarySharedHelpers() or {}

local FALLBACK_STYLE_HELPERS = Addon and Addon.UI and Addon.UI.StyleHelpers and Addon.UI.StyleHelpers.GetDefaultSecondaryStyleHelpers and Addon.UI.StyleHelpers:GetDefaultSecondaryStyleHelpers() or {
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

---@class XPBarVerticalReputationMixin
XPBarVerticalReputationMixin = {}
local StyleMixin = {}

local BASE_WIDTH = 20
local BASE_HEIGHT = 300

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

function StyleMixin:ResizeToScale()
    local scale = (SharedStyleHelpers.GetBarScale and SharedStyleHelpers.GetBarScale("verticalSize")) or 1.0
    local width = BASE_WIDTH * scale
    local height = BASE_HEIGHT * scale

    self:SetSize(width, height)

    -- Keep the reputation fill bar dimensions in lockstep with the frame.
    if self.Bar and self.Bar.SetSize then
        self.Bar:SetSize(width, height)
    end
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
    self:ResizeToScale()
    self:ConfigureDragSupport()
end

XPBarVerticalReputationMixin = CreateFromMixins(XPBarSecondaryBaseMixin, StyleMixin)
