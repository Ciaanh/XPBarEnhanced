-- XP Bar Enhanced - Orb Secondary Bar Style
-- Companion orb for the secondary source: a smaller vertical-fill orb with
-- the source label underneath. Mirrors FlatSecondaryBarStyle's contract.

local Addon = XPBarEnhanced

local function ResolveSharedStyleHelpers()
    return Addon and Addon.UI and Addon.UI.SharedStyleHelpers
end

local function ResolveStyleHelpers()
    return Addon and Addon.UI and Addon.UI.StyleHelpers
end

local SharedStyleHelpers = setmetatable({}, {
    __index = function(_, key)
        local helpers = ResolveSharedStyleHelpers()
        return helpers and helpers[key]
    end,
})

local StyleHelpers = setmetatable({}, {
    __index = function(_, key)
        local helpers = ResolveStyleHelpers()
        return helpers and helpers[key]
    end,
})

---@class XPBarOrbReputationMixin
XPBarOrbReputationMixin = {}
local StyleMixin = {}

local ORB_SIZE = 70
local CIRCLE_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

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

    local color = StyleHelpers.GetFactionColor and StyleHelpers.GetFactionColor(context)
        or {r = 0.7, g = 0.3, b = 0.85, a = 1}
    SharedStyleHelpers.ApplyStatusBarProgress(self.Bar, context, color)
    if self.LabelContainer and self.LabelContainer.Label then
        self.LabelContainer.Label:SetText(SharedStyleHelpers.BuildSecondaryLabel(context))
    end
end

function StyleMixin:OnEnter()
    if not self._lastContext then
        return
    end
    SharedStyleHelpers.ShowSecondaryTooltip(self, self._lastContext, "ANCHOR_TOP")
    SharedStyleHelpers.AddSecondaryTooltipMoveHint(self._lastContext)
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
    if self.LabelContainer and self.LabelContainer.Label then
        self.LabelContainer.Label:SetText(SharedStyleHelpers.BuildSecondaryLabel(context))
    end
end

function StyleMixin:OnDragStart()
    SharedStyleHelpers.BeginSecondaryShiftDrag(self)
end

function StyleMixin:OnDragStop()
    SharedStyleHelpers.EndSecondaryDrag(self)
end

function StyleMixin:OnSecondaryLoad()
    -- Clip the fill (only exists at runtime) to the orb circle
    if self.Bar then
        local fillMask = self.Bar:CreateMaskTexture()
        fillMask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        fillMask:SetAllPoints(self.Orb or self.Bar)

        local fillTexture = self.Bar.GetStatusBarTexture and self.Bar:GetStatusBarTexture()
        if fillTexture and fillTexture.AddMaskTexture then
            fillTexture:AddMaskTexture(fillMask)
        end
    end

    self:ConfigureDragSupport()
end

XPBarOrbReputationMixin = CreateFromMixins(XPBarSecondaryBaseMixin, StyleMixin)
