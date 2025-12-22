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
-- STYLE TEMPLATE
-------------------------------------------------------------------

-- Classic Bar style template: follows  composition pattern
local ClassicBarStyleTemplate = {}

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
        style = {}
    }
end

local DefaultConfig = GetClassicBarConfig()

-------------------------------------------------------------------
-- STYLE CREATION
-------------------------------------------------------------------

-- Create composed mixin (Base + Behaviors + Style)
ClassicBarXPBarMixin = XPBarStyleBuilder:Create(XPBarMixinBase, ClassicBarStyleTemplate, DefaultConfig)
XPBarStyleBuilder:RegisterStyle("classic", ClassicBarXPBarMixin)
