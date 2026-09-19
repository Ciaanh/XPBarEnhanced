-- XP Bar Enhanced - Flat Secondary Bar Style
-- Displays the watched faction's reputation progress as a simple flat status bar.

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