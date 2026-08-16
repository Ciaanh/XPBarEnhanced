-- XP Bar Enhanced - Sigil Secondary Bar Style
-- Companion ring for the secondary source. Always the procedural halo, never
-- tier art: tier art means XP, and this bar is never tracking XP. Follows
-- OrbSecondaryBarStyle's contract.
--
-- Progress is a clockwise arc (Amendment A), like the primary: one paused
-- Cooldown sweeping the annulus channel. A thin swept ring is MORE halo-like
-- than the masked liquid fill it replaces, so the companion converges on its
-- design intent. The Bar StatusBar stays as an alpha-0 data carrier.

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

local TEX_RING = "Interface\\AddOns\\XPBarEnhanced\\assets\\border"
local TEX_ARC_FILL = "Interface\\AddOns\\XPBarEnhanced\\assets\\sigil-fill"
local TEX_ARC_TRACK = "Interface\\AddOns\\XPBarEnhanced\\assets\\sigil-track"
-- Sweep origin at 6 o'clock, matching the primary ring, even though the
-- companion has no crest: the two arcs should start at the same place.
local ARC_ROTATION = math.pi
local ARC_DURATION = 100

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
    -- The Bar is the alpha-0 data carrier; the shared helper keeps computing
    -- the ratio and writing it, and the arc reads it back for the visual.
    SharedStyleHelpers.ApplyStatusBarProgress(self.Bar, context, color)

    if self.ArcFill then
        self.ArcFill:SetSwipeColor(color.r, color.g, color.b, color.a or 1)
        local fraction = (self.Bar and self.Bar.GetValue and self.Bar:GetValue()) or 0
        if fraction <= 0.0001 then
            self.ArcFill:Clear()
            self.ArcFill:Hide()
        else
            self.ArcFill:Show()
            self.ArcFill:SetCooldown(GetTime() - math.min(fraction, 1) * ARC_DURATION, ARC_DURATION)
            self.ArcFill:Pause()
        end
    end

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
    -- The Bar is a data carrier only: the arc renders the progress. Hide it at
    -- FRAME level (the terminal trick) -- texture-level alpha does not survive,
    -- because ApplyStatusBarProgress recolours the bar every render and
    -- SetStatusBarColor writes the fill texture's vertex alpha back to 1.
    if self.Bar then
        self.Bar:SetAlpha(0)
    end

    -- The groove the arc runs in, then the arc itself.
    if self.Cavity and not self.ArcTrack then
        local track = self.Cavity:CreateTexture(nil, "BORDER")
        track:SetTexture(TEX_ARC_TRACK)
        track:SetAllPoints(self.Cavity)
        self.ArcTrack = track
    end

    if not self.ArcFill then
        local arc = CreateFrame("Cooldown", nil, self, "CooldownFrameTemplate")
        arc:SetAllPoints(self.Cavity or self)
        arc:EnableMouse(false)
        arc:SetReverse(true)
        arc:SetSwipeTexture(TEX_ARC_FILL)
        arc:SetDrawEdge(false)
        arc:SetDrawBling(false)
        arc:SetHideCountdownNumbers(true)
        if arc.SetRotation then
            arc:SetRotation(ARC_ROTATION)
        end
        if self.Bar then
            arc:SetFrameLevel(self.Bar:GetFrameLevel() + 1)
        end
        self.ArcFill = arc
    end

    if self.RingOverlay and self.RingOverlay.Halo then
        self.RingOverlay.Halo:SetTexture(TEX_RING)
    end

    -- Sibling frames share a frame level; the stack bottom-up is carrier Bar,
    -- fill arc (+1, set above), ring dressing, label.
    if self.RingOverlay and self.Bar then
        self.RingOverlay:SetFrameLevel(self.Bar:GetFrameLevel() + 2)
        if self.LabelContainer then
            self.LabelContainer:SetFrameLevel(self.Bar:GetFrameLevel() + 3)
        end
    end

    self:ConfigureDragSupport()
end

XPBarSigilReputationMixin = CreateFromMixins(XPBarSecondaryBaseMixin, StyleMixin)

-- Referenced by the XML template's Size; kept here so the two cannot drift.
XPBarSigilReputationMixin.SIGIL_SECONDARY_SIZE = SIGIL_SECONDARY_SIZE
