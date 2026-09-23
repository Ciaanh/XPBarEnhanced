-- XP Bar Enhanced - Classic Bar Style
-- Blizzard-style XP bar: a chamfered frame over a tinted neutral fill, drawn
-- entirely from the addon's own textures (see ClassicChrome.lua).

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

-- Frame and fill heights come from ClassicChrome so the secondary bar matches.
-- The on-bar text fields are scaled against BASE_WIDTH so a wider bar gets
-- proportionally more room for level/XP/percent rather than three clusters
-- marooned at the default insets.
local BASE_WIDTH = 566
local BELOW_BAR_HEIGHT = 30
local OVERLAY_TEXT_HEIGHT = 11

local BASE_LEVEL_TEXT_WIDTH = 120
local BASE_XP_TEXT_WIDTH = 280
local BASE_PERCENT_TEXT_WIDTH = 120

-------------------------------------------------------------------
-- STYLE TEMPLATE
-------------------------------------------------------------------

-- The fill and the rested/quest overlays all use classic-bar-fill.tga, set in
-- ClassicBarTemplate.xml. It is a neutral grey, so the configured colors come
-- through as chosen instead of being multiplied into a baked hue.
local ClassicBarStyleTemplate = {}

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

    local width = Chrome.LayoutBar(self, self.StatusBar)

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
end

-------------------------------------------------------------------
-- LIFECYCLE OVERRIDES
-------------------------------------------------------------------

--- Override BuildVisuals to texture the chrome and apply the configured width
--- once the base has aliased the XML elements.
function ClassicBarStyleTemplate:BuildVisuals()
    if XPBarPaintMixin and XPBarPaintMixin.BuildVisuals then
        XPBarPaintMixin.BuildVisuals(self)
    end

    local Chrome = GetChrome()
    if Chrome then
        Chrome.BuildChrome(self, self.StatusBar)
        Chrome.StylePip(self.ExhaustionTick)
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
    return {
        interaction = {enabled = true},
        tooltip = {enabled = true},
        animation = {
            enableAnimations = true,
            flashOnGain = true
        },
        position = {
            -- Read by PositionMixin when the frame is built, once saved
            -- settings exist; this table is built at file load.
            modeOption = "classicBarDraggable",
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
