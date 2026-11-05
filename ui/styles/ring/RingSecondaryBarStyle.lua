-- XP Bar Enhanced - Ring Secondary Bar Style
-- The secondary bar (reputation, housing, honor, profession) under Ring: one
-- band on the primary's arc, concentric with it, in its hole or around it
-- (RingGeometry.SecondaryBand). Its own frame, so SecondaryBarManager attaches
-- and detaches it as for the other styles: attached, it is centred on the
-- primary; detached, it is a standalone draggable ring.

local Addon = XPBarEnhanced
local Config = Addon.Config
local Geometry = Addon.UI and Addon.UI.RingGeometry
local RingBand = Addon.UI and Addon.UI.RingBand
if not Geometry or not RingBand or not XPBarSecondaryBaseMixin then
    error("RingSecondaryBarStyle: RingGeometry, RingBarStyle or the secondary base mixin not loaded. Check the .toc order.")
end

local SharedStyleHelpers = Addon.UI.SharedStyleHelpers
local StyleHelpers = Addon.UI.StyleHelpers

---@class XPBarRingReputationMixin
XPBarRingReputationMixin = {}
local StyleMixin = {}

local TRACK_COLOR = RingBand.TRACK_COLOR

local function ReadOption(key)
    return Config and Config.GetOptionValue and Config:GetOptionValue(key)
end

-------------------------------------------------------------------
-- POSITION
-------------------------------------------------------------------

function StyleMixin:GetPositionConfigKey()
    return SharedStyleHelpers.GetSecondaryPositionConfigKey()
end

--- Detached with no saved position: where the primary ring sits by default,
--- so the two stay concentric until one is moved.
function StyleMixin:GetFallbackPosition()
    local position = Addon.defaults and Addon.defaults.barPositions and Addon.defaults.barPositions.ring or {}
    return {
        point = position.point or "CENTER",
        relativeTo = position.relativeTo or "UIParent",
        relativePoint = position.relativePoint or "CENTER",
        x = position.x or 0,
        y = position.y or 0,
    }
end

function StyleMixin:GetAttachedAnchor()
    return "CENTER", "CENTER", 0, 0
end

function StyleMixin:GetBroadcastEventName()
    return SharedStyleHelpers.GetSecondaryBroadcastEventName()
end

function StyleMixin:GetInitialContext()
    return SharedStyleHelpers.GetSecondaryInitialContext()
end

-------------------------------------------------------------------
-- INTERACTION
-------------------------------------------------------------------

-- The primary's centre text has less room while this ring sits in its hole:
-- tell it whenever that may have changed (shown, hidden, attached, detached).
local function RelayoutPrimary()
    local primary = Addon.BarManager and Addon.BarManager.GetCurrentFrame and Addon.BarManager:GetCurrentFrame()
    if primary and primary.HasSecondaryInside and primary.RelayoutRing then
        primary:RelayoutRing()
    end
end

-- Attached, the mouse belongs to the primary ring underneath.
function StyleMixin:SetDetachedInteractionEnabled(enabled)
    local detached = enabled and true or false
    local changed = self._detachedInteractionEnabled ~= detached
    self._detachedInteractionEnabled = detached
    if self.EnableMouse then
        self:EnableMouse(detached)
    end
    if changed then
        RelayoutPrimary()
    end
end

function StyleMixin:OnSecondaryShow()
    RelayoutPrimary()
end

function StyleMixin:OnSecondaryHide()
    RelayoutPrimary()
end

function StyleMixin:OnEnter()
    if not self._detachedInteractionEnabled then
        return
    end

    local context = self._lastContext
    if not context or not context.isAvailable then
        return
    end

    SharedStyleHelpers.ShowSecondaryTooltip(self, context, "ANCHOR_TOP")
    GameTooltip:AddLine(SharedStyleHelpers.GetOpenPanelHint(), 0.4, 0.4, 0.4)
    SharedStyleHelpers.AddSecondaryTooltipMoveHint(context)
    SharedStyleHelpers.FinishSecondaryTooltip()
end

function StyleMixin:OnLeave()
    SharedStyleHelpers.HideTooltip()
end

function StyleMixin:OnMouseUp(button)
    if not self._detachedInteractionEnabled then
        return
    end
    SharedStyleHelpers.HandleStandardSecondaryMouseUp(self, button, SharedStyleHelpers.OpenReputationPanel)
end

function StyleMixin:OnDragStart()
    if self._detachedInteractionEnabled then
        SharedStyleHelpers.BeginSecondaryShiftDrag(self)
    end
end

function StyleMixin:OnDragStop()
    if self._detachedInteractionEnabled then
        SharedStyleHelpers.EndSecondaryDrag(self)
    end
end

-------------------------------------------------------------------
-- BAND
-------------------------------------------------------------------

function StyleMixin:OnSecondaryLoad()
    RingBand.CreateHole(self)

    self.Track = RingBand.CreateTexture(self, "BACKGROUND", 0)
    self.Track:SetVertexColor(TRACK_COLOR.r, TRACK_COLOR.g, TRACK_COLOR.b)

    self.Fill = RingBand.CreateTexture(self, "ARTWORK", 1)
    self.Fill:Hide()

    RingBand.CreateExtras(self)

    self:RelayoutRing()
    self:ConfigureDragSupport()
    self:SetDetachedInteractionEnabled(false)
end

--- Follow the primary's shape and the secondary options. Called on load and
--- by every Ring option (Config's RelayoutRing reaches both rings).
function StyleMixin:RelayoutRing()
    local settings = Geometry.Normalize(ReadOption)
    local arc = Geometry.Arc(settings)
    local band = Geometry.SecondaryBand(settings)
    self.ringSettings = settings
    self.ringArc = arc
    self.ringBand = band

    RingBand.Layout(self, band, arc, settings.trackAlpha)
    RingBand.LayoutExtras(self, settings, band, arc)

    if self._lastContext then
        self:Render(self._lastContext)
    end
end

-- Config's reposition handlers queue a rebuild on every secondary style.
function StyleMixin:QueueReposition()
    self:RelayoutRing()
end

function StyleMixin:Render(context)
    if not SharedStyleHelpers.BeginSecondaryRender(self, context) then
        return
    end
    if not self.ringArc then
        return
    end

    local ratio = math.max(0, math.min(1, (tonumber(context.percent) or 0) / 100))
    local feather = ratio < 1 and self.ringSettings.feather or 0
    RingBand.ApplySpan(self.Fill, self.ringArc, 0, ratio, feather)

    local color = StyleHelpers.GetFactionColor(context)
    if color then
        self.Fill:SetVertexColor(color.r, color.g, color.b, color.a or 1)
    end

    -- Spark, ticks and caps follow the primary's settings; one layer here. No
    -- paint key: a render is an update, not an animation frame, so repaint.
    RingBand.UpdateSpark(self, self.ringSettings.spark, ratio, color)
    RingBand.PaintCaps(self, ratio > 0 and color or nil, ratio >= 1 and color or nil, 1)
end

XPBarRingReputationMixin = CreateFromMixins(XPBarSecondaryBaseMixin, StyleMixin)
