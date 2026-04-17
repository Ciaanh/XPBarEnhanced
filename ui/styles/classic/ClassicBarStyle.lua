-- XP Bar Enhanced - Classic Bar Style
-- Blizzard-style XP bar with border frame and atlas textures
-- Static positioning (anchored to Blizzard's MainStatusTrackingBarContainer)

-------------------------------------------------------------------
-- DEPENDENCIES
-------------------------------------------------------------------

if not XPBarStyleBuilder or not XPBarMixinBase then
    error(
        "ClassicBarStyle:  core (StyleBuilder/BaseMixin) not loaded. Ensure ui/xpbars core files are earlier in the .toc."
    )
end

-------------------------------------------------------------------
-- ATLAS CONFIGURATION
-------------------------------------------------------------------

-- Blizzard atlas names for the XP bar fill with TGA file fallbacks.
-- Atlas textures are resolution-independent and scale better than custom TGAs.
local ATLAS_CONFIG = {
    barFill = {
        atlas = "UI-HUD-ExperienceBar-Fill-XP",
        fallback = "Interface\\AddOns\\XPBarEnhanced\\assets\\xp-bar"
    },
    restedOverlay = {
        -- Keep this on a neutral texture so the configured rested color is not
        -- multiplied by Blizzard's baked rested tint/shading.
        atlas = nil,
        fallback = "Interface\\AddOns\\XPBarEnhanced\\assets\\xp-bar"
    },
    questComplete = {
        atlas = nil, -- No Blizzard atlas for quest overlays; use file texture
        fallback = "Interface\\AddOns\\XPBarEnhanced\\assets\\xp-bar"
    },
    questIncomplete = {
        atlas = nil,
        fallback = "Interface\\AddOns\\XPBarEnhanced\\assets\\xp-bar"
    }
}

-------------------------------------------------------------------
-- STYLE TEMPLATE
-------------------------------------------------------------------

-- Classic Bar style template: follows  composition pattern
local ClassicBarStyleTemplate = {}

--- Apply atlas textures after BuildVisuals aliases all XML elements.
--- Called from OnLoad chain via mixin composition.
function ClassicBarStyleTemplate:ApplyAtlasTextures()
    if not self.ApplyBarAtlasOrTexture then
        return -- PaintMixin not available
    end

    -- Main bar fill: prefer atlas over custom TGA
    local cfg = ATLAS_CONFIG.barFill
    self:ApplyBarAtlasOrTexture(cfg.atlas, cfg.fallback)

    -- Rested overlay
    if self.RestedOverlay then
        cfg = ATLAS_CONFIG.restedOverlay
        if self.ApplyAtlasOrTexture then
            self:ApplyAtlasOrTexture(self.RestedOverlay, cfg.atlas, cfg.fallback)
        end
    end

    -- Quest overlays (no atlas available, keep file textures)
    -- These are already set in XML, no action needed
end

--- Override ApplyStyle to also apply atlas textures after base style setup
function ClassicBarStyleTemplate:ApplyStyle(styleConfig)
    -- Call parent ApplyStyle (from PaintMixin)
    if XPBarPaintMixin and XPBarPaintMixin.ApplyStyle then
        XPBarPaintMixin.ApplyStyle(self, styleConfig)
    end
    -- Apply atlas textures (with fallback to TGA if unavailable)
    self:ApplyAtlasTextures()
end

-------------------------------------------------------------------
-- TRIGGER IMPLEMENTATION
-------------------------------------------------------------------

-------------------------------------------------------------------
-- DEFAULT CONFIG
-------------------------------------------------------------------

local function GetClassicBarConfig()
    local Addon = XPBarEnhanced
    local isDraggable = Addon.db and Addon.db.classicBarDraggable
    if isDraggable == nil then
        isDraggable = true -- Default to draggable
    end

    return {
        interaction = {enabled = true},
        tooltip = {enabled = true},
        animation = {
            enableAnimations = true,
            flashOnGain = true
        },
        position = {
            mode = isDraggable and "DRAGGABLE" or "STATIC",
            positionKey = "ClassicBar"
        },
        style = {},
        capabilities = {
            exhaustionTick = true,
        }
    }
end

local DefaultConfig = GetClassicBarConfig()

-------------------------------------------------------------------
-- STYLE CREATION
-------------------------------------------------------------------

-- Create composed mixin (Base + Behaviors + Style)
ClassicBarXPBarMixin = XPBarStyleBuilder:Create(XPBarMixinBase, ClassicBarStyleTemplate, DefaultConfig)
XPBarStyleBuilder:RegisterStyle("classic", ClassicBarXPBarMixin)
