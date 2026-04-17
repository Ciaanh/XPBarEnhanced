-- XP Bar Enhanced - FlatBar Style
-- Minimal style file: XML owns visual creation via contract.
-- Adds optional milestone ticks (10/25/50/75/100%) overlaid on the bar.

-------------------------------------------------------------------
-- DEPENDENCIES
-------------------------------------------------------------------

if not XPBarStyleBuilder or not XPBarMixinBase then
	error("FlatBarStyle:  core (StyleBuilder/BaseMixin) not loaded. Ensure ui/xpbars core files are earlier in the .toc.")
end

local Addon = XPBarEnhanced
local Colors = Addon.Colors
local SharedStyleHelpers = Addon.UI.SharedStyleHelpers

-------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------

local MILESTONES    = {0.25, 0.50, 0.75}
local TICK_WIDTH    = 2
local BAR_HEIGHT    = 30
local FRAME_WIDTH   = 565

-------------------------------------------------------------------
-- STYLE TEMPLATE
-------------------------------------------------------------------

local FlatBarStyleTemplate = {}

-------------------------------------------------------------------
-- MILESTONE TICK HELPERS
-------------------------------------------------------------------

--- Create tick textures and percent labels over the bar.
--- Called once from BuildVisuals after the base initialises element aliases.
function FlatBarStyleTemplate:CreateMilestoneTicks()
	local container = self.OverlayFrameTextContainer
	if not container then return end

	self._milestoneTicks = {}
	local W = self:GetWidth() > 0 and self:GetWidth() or FRAME_WIDTH

	for _, pct in ipairs(MILESTONES) do
		local x = pct * W

		-- Thin full-height vertical line
		local tick = container:CreateTexture(nil, "OVERLAY", nil, 6)
		tick:SetSize(TICK_WIDTH, BAR_HEIGHT)
		tick:SetPoint("BOTTOM", container, "BOTTOMLEFT", x, 0)
		tick:Hide()

		-- Small percent label inside the bar near the bottom
		local label = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		label:SetText(string.format("%d%%", math.floor(pct * 100)))
		label:SetPoint("BOTTOM", container, "BOTTOMLEFT", x, 2)
		label:Hide()

		table.insert(self._milestoneTicks, {tick = tick, label = label, ratio = pct})
	end
end

--- Show/hide and recolor ticks based on current ratio and db settings.
--- Ticks at or before the cursor take the active bar color; the rest are dimmed.
function FlatBarStyleTemplate:UpdateMilestoneTicks(currentRatio, context)
	if not self._milestoneTicks then return end

	local db = Addon.db or {}

	if not db.showMilestoneTicks then
		for _, t in ipairs(self._milestoneTicks) do
			t.tick:Hide()
			t.label:Hide()
		end
		return
	end

	local activeColor = SharedStyleHelpers.GetXPBarColor(context)

	for _, t in ipairs(self._milestoneTicks) do
		if t.ratio <= currentRatio then
			t.tick:SetColorTexture(activeColor.r, activeColor.g, activeColor.b, 0.85)
			t.label:SetTextColor(activeColor.r * 0.9, activeColor.g * 0.9, activeColor.b * 0.9, 1)
		else
			t.tick:SetColorTexture(0.6, 0.6, 0.6, 0.35)
			t.label:SetTextColor(0.5, 0.5, 0.5, 0.8)
		end
		t.tick:Show()
		t.label:Show()
	end
end

-------------------------------------------------------------------
-- LIFECYCLE OVERRIDES
-------------------------------------------------------------------

--- Override BuildVisuals to create tick elements after the base aliases run.
function FlatBarStyleTemplate:BuildVisuals()
	if XPBarPaintMixin and XPBarPaintMixin.BuildVisuals then
		XPBarPaintMixin.BuildVisuals(self)
	end
	self:CreateMilestoneTicks()
end

--- Override UpdateGainedBar to keep ticks in sync with every render/animation tick.
function FlatBarStyleTemplate:UpdateGainedBar(currentRatio, context)
	-- Base: set StatusBar value and apply bar color
	if XPBarDisplayMixin and XPBarDisplayMixin.UpdateGainedBar then
		XPBarDisplayMixin.UpdateGainedBar(self, currentRatio, context)
	end
	self:UpdateMilestoneTicks(currentRatio, context)
end

-------------------------------------------------------------------
-- DEFAULT CONFIG
-------------------------------------------------------------------

local DefaultConfig = {
	interaction = {enabled = true},
	tooltip = {enabled = true},
	animation = {
		enableAnimations = true,
		flashOnGain = true
	},
	position = {mode = "DRAGGABLE", positionKey = "FlatBar"},
	style = {}
}

-------------------------------------------------------------------
-- STYLE CREATION
-------------------------------------------------------------------

-- Create composed mixin (Base + Behaviors + Style)
FlatBarXPBarMixin = XPBarStyleBuilder:Create(XPBarMixinBase, FlatBarStyleTemplate, DefaultConfig)
XPBarStyleBuilder:RegisterStyle("flat", FlatBarXPBarMixin)
