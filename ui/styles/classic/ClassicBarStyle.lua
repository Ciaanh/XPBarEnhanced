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

local Addon = XPBarEnhanced

-- ClassicChrome.lua is listed ahead of this file in ClassicBarTemplate.xml.
local function GetChrome()
    return Addon.UI and Addon.UI.ClassicChrome
end

-------------------------------------------------------------------
-- TEMPLATE GEOMETRY
-------------------------------------------------------------------

-- Authored dimensions from ClassicBarTemplate.xml. The on-bar text fields are
-- scaled against BASE_WIDTH so a wider bar gets proportionally more room for
-- level/XP/percent rather than three clusters marooned at the default insets.
local BASE_WIDTH = 566
local FRAME_HEIGHT = 12
local STATUS_BAR_HEIGHT = 10
local BELOW_BAR_HEIGHT = 30
local OVERLAY_TEXT_HEIGHT = 11

local BASE_LEVEL_TEXT_WIDTH = 120
local BASE_XP_TEXT_WIDTH = 280
local BASE_PERCENT_TEXT_WIDTH = 120

-------------------------------------------------------------------
-- ATLAS CONFIGURATION
-------------------------------------------------------------------

-- Blizzard atlas names for the XP bar fill with TGA file fallbacks.
-- Atlas textures are resolution-independent and scale better than custom TGAs.
local ATLAS_CONFIG = {
    barFill = {
        -- Probed in order. Blizzard's own experience bar uses
        -- "-Fill-Experience"; "-Fill-XP" does not appear anywhere in the
        -- current Blizzard UI source, so on any client matching it this bar was
        -- falling through to the TGA instead of the atlas. The old name is kept
        -- as a second candidate in case an older client still ships it.
        atlas = {"UI-HUD-ExperienceBar-Fill-Experience", "UI-HUD-ExperienceBar-Fill-XP"},
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
    local Chrome = GetChrome()
    local cfg = ATLAS_CONFIG.barFill
    local atlas = Chrome and Chrome.ResolveAtlas(cfg.atlas) or nil
    self:ApplyBarAtlasOrTexture(atlas, cfg.fallback)

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
-- SIZING
-------------------------------------------------------------------

local function ScaleTextWidth(fontString, baseWidth, width)
    if fontString and fontString.SetWidth then
        fontString:SetWidth(math.floor(baseWidth / BASE_WIDTH * width))
    end
end

--- Resize the whole bar to the configured Classic width and re-space the
--- segment dividers. Safe to call repeatedly; the overlay/quest/rested geometry
--- is derived from the live StatusBar width on the next render, so nothing else
--- needs to be told about the new size.
function ClassicBarStyleTemplate:ResizeToConfiguredWidth()
    local Chrome = GetChrome()
    if not Chrome then
        return
    end

    local width = Chrome.GetWidth()
    self:SetSize(width, FRAME_HEIGHT)

    if self.StatusBar and self.StatusBar.SetSize then
        self.StatusBar:SetSize(width, STATUS_BAR_HEIGHT)
    end

    local overlay = self.OverlayFrameTextContainer
    if overlay and overlay.SetSize then
        overlay:SetSize(width + Chrome.OVERLAY_TEXT_INSET, OVERLAY_TEXT_HEIGHT)
        ScaleTextWidth(overlay.LevelText, BASE_LEVEL_TEXT_WIDTH, width)
        ScaleTextWidth(overlay.XPText, BASE_XP_TEXT_WIDTH, width)
        ScaleTextWidth(overlay.PercentText, BASE_PERCENT_TEXT_WIDTH, width)
    end

    local below = self.BelowBarTextContainer
    if below and below.SetSize then
        below:SetSize(width + Chrome.BELOW_TEXT_INSET, BELOW_BAR_HEIGHT)
    end

    Chrome.LayoutDividers(self)
end

-------------------------------------------------------------------
-- LIFECYCLE OVERRIDES
-------------------------------------------------------------------

--- Override BuildVisuals to slice the chrome and apply the configured width
--- once the base has aliased the XML elements.
function ClassicBarStyleTemplate:BuildVisuals()
    if XPBarPaintMixin and XPBarPaintMixin.BuildVisuals then
        XPBarPaintMixin.BuildVisuals(self)
    end

    local Chrome = GetChrome()
    if Chrome then
        Chrome.BuildSlicedChrome(self)
    end

    self:ResizeToConfiguredWidth()
end

-------------------------------------------------------------------
-- TRIGGER IMPLEMENTATION
-------------------------------------------------------------------

-------------------------------------------------------------------
-- DEFAULT CONFIG
-------------------------------------------------------------------

local function GetClassicBarConfig()
    local Addon = XPBarEnhanced
    local isDraggable = Addon.Config and Addon.Config.GetOptionValue and Addon.Config:GetOptionValue("classicBarDraggable")
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
            positionKey = Addon.StyleKeys.classic
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
