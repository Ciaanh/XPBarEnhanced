-- XP Bar Enhanced - Sigil Secondary Bar Style
-- Companion ring for the secondary source. Always the procedural halo, never
-- tier art: tier art means XP, and this bar is never tracking XP. Follows
-- OrbSecondaryBarStyle's contract.

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

---@class XPBarSigilReputationMixin
XPBarSigilReputationMixin = {}
local StyleMixin = {}

local CIRCLE_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local TEX_RING = "Interface\\AddOns\\XPBarEnhanced\\assets\\border"

local SIGIL_SECONDARY_SIZE = 70

function StyleMixin:GetPositionConfigKey()
    return SharedStyleHelpers.GetSecondaryPositionConfigKey()
end

function StyleMixin:GetFallbackPosition()
    return SharedStyleHelpers.BuildConfiguredStyleOffsetFallback("BOTTOM", 0, 34, 20)
end

--- Sit to the RIGHT of the primary ring, bottom-aligned, the same companion
--- arrangement the orb uses rather than stacked above it.
function StyleMixin:GetAttachedAnchor()
    return "BOTTOMLEFT", "BOTTOMRIGHT", 6, 0
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

-- Compact label suited to the ring footprint: percent only (or MAX). The full
-- name and standing live in the tooltip.
local function BuildSigilLabel(context)
    if context and context.isMaxed then
        return (Addon.L and Addon.L["LABEL_MAX"]) or "MAX"
    end
    return string.format("%d%%", (context and context.percent) or 0)
end

function StyleMixin:Render(context)
    if not SharedStyleHelpers.BeginSecondaryRender(self, context) then
        return
    end

    local color = StyleHelpers.GetFactionColor and StyleHelpers.GetFactionColor(context)
        or {r = 0.7, g = 0.3, b = 0.85, a = 1}
    SharedStyleHelpers.ApplyStatusBarProgress(self.Bar, context, color)

    -- The halo tracks the source colour, so the companion ring reads as
    -- belonging to whatever it is showing.
    if self.RingOverlay and self.RingOverlay.Halo then
        self.RingOverlay.Halo:SetVertexColor(color.r, color.g, color.b, 0.95)
    end

    if self.LabelContainer and self.LabelContainer.Label then
        self.LabelContainer.Label:SetText(BuildSigilLabel(context))
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
        self.LabelContainer.Label:SetText(BuildSigilLabel(context))
    end
end

function StyleMixin:OnDragStart()
    SharedStyleHelpers.BeginSecondaryShiftDrag(self)
end

function StyleMixin:OnDragStop()
    SharedStyleHelpers.EndSecondaryDrag(self)
end

function StyleMixin:OnSecondaryLoad()
    -- Clip the fill (it only exists at runtime) to the ring circle
    if self.Bar then
        local fillMask = self.Bar:CreateMaskTexture()
        fillMask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        fillMask:SetAllPoints(self)

        local fillTexture = self.Bar.GetStatusBarTexture and self.Bar:GetStatusBarTexture()
        if fillTexture and fillTexture.AddMaskTexture then
            fillTexture:AddMaskTexture(fillMask)
        end
    end

    if self.RingOverlay and self.RingOverlay.Halo then
        self.RingOverlay.Halo:SetTexture(TEX_RING)
    end

    -- Sibling frames share a frame level; force the ring dressing above the fill
    -- StatusBar and the label above both.
    if self.RingOverlay and self.Bar then
        self.RingOverlay:SetFrameLevel(self.Bar:GetFrameLevel() + 1)
        if self.LabelContainer then
            self.LabelContainer:SetFrameLevel(self.Bar:GetFrameLevel() + 2)
        end
    end

    self:ConfigureDragSupport()
end

XPBarSigilReputationMixin = CreateFromMixins(XPBarSecondaryBaseMixin, StyleMixin)

-- Referenced by the XML template's Size; kept here so the two cannot drift.
XPBarSigilReputationMixin.SIGIL_SECONDARY_SIZE = SIGIL_SECONDARY_SIZE
