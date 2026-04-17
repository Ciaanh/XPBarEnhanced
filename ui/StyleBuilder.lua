-- XP Bar Enhanced - Style Builder ()
-- Composition utility for creating style mixins via CreateFromMixins

-------------------------------------------------------------------
-- GLOBAL STYLE BUILDER
-------------------------------------------------------------------

---@class XPBarStyleBuilder
XPBarStyleBuilder = {}

local StyleBuilder = XPBarStyleBuilder
local Addon = XPBarEnhanced
Addon.StyleBuilder = StyleBuilder

-------------------------------------------------------------------
-- REGISTRY of created style mixins
-------------------------------------------------------------------
---
local StyleRegistry = Addon.Styles or {}
Addon.Styles = StyleRegistry

function XPBarStyleBuilder:RegisterStyle(key, mixin)
	mixin.__xpbar_key = key
	StyleRegistry[key] = mixin
end

function XPBarStyleBuilder:GetStyleMixin(key)
	return StyleRegistry[key]
end

-------------------------------------------------------------------
-- CAPABILITY CONSTANTS
-- Declare what features a style supports. Replaces scattered
-- "if self.X then" guards with explicit declarations.
-------------------------------------------------------------------

XPBarStyleBuilder.Capabilities = {
	statusBar      = "statusBar",       -- has visible StatusBar widget
	overlays       = "overlays",        -- has rested/quest overlay textures
	exhaustionTick = "exhaustionTick",  -- has ExhaustionTick marker
	textOnBar      = "textOnBar",       -- has LevelText/XPText/PercentText
	textBelowBar   = "textBelowBar",    -- has RateText/SessionText/QuestSummaryText
	barColors      = "barColors",       -- responds to user color changes
}

-- Default capabilities for standard horizontal bars
local DEFAULT_CAPABILITIES = {
	statusBar      = true,
	overlays       = true,
	exhaustionTick = false,
	textOnBar      = true,
	textBelowBar   = true,
	barColors      = true,
}

-------------------------------------------------------------------
-- BUILDER API
-------------------------------------------------------------------

--- Create a composed style mixin using CreateFromMixins
--- Composition order: Base → Behaviors → StyleTemplate (style wins on method collision)
---@param baseMixin table Base mixin (XPBarMixinBase)
---@param styleTemplate table Style-specific visual methods
---@param config table Configuration for behaviors and style
---@return table composedMixin Composed mixin ready for global registration
function StyleBuilder:Create(baseMixin, styleTemplate, config)
	-- Validate inputs
	if not baseMixin then
		error("StyleBuilder:Create - baseMixin is required")
	end
	if not styleTemplate then
		error("StyleBuilder:Create - styleTemplate is required")
	end
	config = config or {}

	-- Build behavior mixin list based on config
	local behaviorMixins = self:BuildBehaviorList(config)

	-- Compose: Base → Behaviors → Style (style methods override)
	local mixins = {baseMixin}
	for _, behavior in ipairs(behaviorMixins) do
		table.insert(mixins, behavior)
	end
	table.insert(mixins, styleTemplate)

	-- Use CreateFromMixins to compose all mixins
	local composedMixin = CreateFromMixins(unpack(mixins))

	-- Store config on composed mixin for runtime access
	composedMixin.__xpbar_config = config

	-- Merge capabilities (style declares overrides, rest defaults to true)
	local caps = {}
	for k, v in pairs(DEFAULT_CAPABILITIES) do
		caps[k] = v
	end
	if config.capabilities then
		for k, v in pairs(config.capabilities) do
			caps[k] = v
		end
	end
	composedMixin.__xpbar_capabilities = caps

	return composedMixin
end

--- Build list of behavior mixins based on config flags
---@param config table Configuration object
---@return table behaviorMixins Array of behavior mixin tables
function StyleBuilder:BuildBehaviorList(config)
	local behaviors = {}
	local Mixins = Addon.UI.Mixins

	-- Layout mixin (always first - pure calculations, no dependencies)
	if Mixins.Layout then
		table.insert(behaviors, Mixins.Layout)
	end

	-- Paint mixin (colors/textures, no layout dependencies)
	if Mixins.Paint then
		table.insert(behaviors, Mixins.Paint)
	end

	-- Display mixin (aggregator coordinating Layout + Paint)
	if Mixins.Display then
		table.insert(behaviors, Mixins.Display)
	end

	-- Text mixin (text content and visibility)
	if Mixins.Text then
		table.insert(behaviors, Mixins.Text)
	end

	-- Animation mixin (animation system)
	if Mixins.Animation then
		table.insert(behaviors, Mixins.Animation)
	end

	-- Interaction mixin (optional, default enabled)
	if config.interaction ~= false then
		if Mixins.Interaction then
			table.insert(behaviors, Mixins.Interaction)
		end
	end

	-- Tooltip mixin (optional, default enabled)
	if config.tooltip ~= false then
		if Mixins.Tooltip then
			table.insert(behaviors, Mixins.Tooltip)
		end
	end

	-- Position mixin (always included, mode determined by config)
	if Mixins.Position then
		table.insert(behaviors, Mixins.Position)
	end

	return behaviors
end

--- Validate configuration object
--- Provides helpful warnings for common config errors
---@param config table Configuration to validate
---@return boolean valid True if config is valid
function StyleBuilder:ValidateConfig(config)
	if not config then
		return true -- nil config is valid (uses defaults)
	end

	if type(config) ~= "table" then
		error("StyleBuilder:ValidateConfig - config must be a table")
	end

	-- Validate position config
	if config.position then
		if config.position.mode and config.position.mode ~= "STATIC" and config.position.mode ~= "DRAGGABLE" then
			error("Invalid position.mode '" .. tostring(config.position.mode) .. "' - expected 'STATIC' or 'DRAGGABLE'")
		end

		if config.position.mode == "DRAGGABLE" and not config.position.positionKey then
			error("position.mode is DRAGGABLE but position.positionKey not specified - position will not be saved")
		end
	end

	return true
end

-------------------------------------------------------------------
-- FRAME FACTORY
-------------------------------------------------------------------

--- Create a frame for the given style key, applying the registered mixin.
--- The XML template provides the visual structure; this applies behavior via mixin.
---@param styleKey string Style registry key (e.g., "flat", "circular")
---@param config table|nil Optional config overrides
---@param templateName string|nil XML virtual template name (default: "FlatBarTemplate")
---@return table|nil frame Created frame or nil on error
function StyleBuilder:CreateFrameForStyle(styleKey, config, templateName)
	-- Get registered style mixin
	local mixin = self:GetStyleMixin(styleKey)
	if not mixin then
		error("CreateFrameForStyle: style not registered: " .. tostring(styleKey))
	end

	if not templateName then
		error("CreateFrameForStyle: templateName is required")
	end

	-- Create frame from XML virtual template
	local frame = CreateFrame("Frame", nil, UIParent, templateName)
	if not frame then
		error("CreateFrameForStyle: failed to create frame from template: " .. tostring(templateName))
	end

	-- Apply mixin if XML template didn't already do so
	-- (XML template should reference the mixin via mixin="FlatBarXPBarMixin")
	-- This is a safety fallback for programmatic creation
	if not frame.OnLoad then
		Mixin(frame, mixin)
	end

	-- Store config
	frame.__xpbar_config = config or mixin.__xpbar_config or {}

	return frame
end

return StyleBuilder
