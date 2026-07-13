-- XP Bar Enhanced - Orb Style
-- Circular orb that fills vertically (Diablo-style): a VERTICAL StatusBar
-- clipped by a circular mask. Reuses the standard StatusBar render path.

-------------------------------------------------------------------
-- DEPENDENCIES
-------------------------------------------------------------------

if not XPBarStyleBuilder or not XPBarMixinBase then
    error(
        "OrbBarStyle: core (StyleBuilder/BaseMixin) not loaded. Ensure ui/xpbars core files are earlier in the .toc."
    )
end

local Addon = XPBarEnhanced

local ORB_SIZE = 110
local CIRCLE_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

-------------------------------------------------------------------
-- STYLE TEMPLATE
-------------------------------------------------------------------

local OrbBarStyleTemplate = {}

function OrbBarStyleTemplate:OnLoad()
    self:SetSize(ORB_SIZE, ORB_SIZE)

    -- Text FontStrings live on the overlay container; alias them onto the
    -- bar frame where TextMixin expects them.
    local container = self.OverlayFrameTextContainer
    if container then
        self.LevelText = self.LevelText or container.LevelText
        self.PercentText = self.PercentText or container.PercentText
    end

    -- Clip the StatusBar fill (and gain flash) to the orb circle. The
    -- background disc is masked in XML; the fill texture only exists at
    -- runtime, so its mask is attached here.
    if self.StatusBar then
        self.StatusBar:SetSize(ORB_SIZE, ORB_SIZE)
        local fillMask = self.StatusBar:CreateMaskTexture()
        fillMask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        fillMask:SetAllPoints(self)

        local fillTexture = self.StatusBar.GetStatusBarTexture and self.StatusBar:GetStatusBarTexture()
        if fillTexture and fillTexture.AddMaskTexture then
            fillTexture:AddMaskTexture(fillMask)
        end
        if self.GainFlash and self.GainFlash.AddMaskTexture then
            self.GainFlash:AddMaskTexture(fillMask)
        end
    end

    if XPBarMixinBase and XPBarMixinBase.OnLoad then
        XPBarMixinBase.OnLoad(self)
    end
end

-------------------------------------------------------------------
-- TEXT OVERRIDES (centered inside the orb)
-------------------------------------------------------------------

function OrbBarStyleTemplate:UpdateLevelText(context)
    if not self.LevelText then
        return
    end
    if context and context.showLevelText == false then
        self.LevelText:Hide()
        return
    end

    -- Max-level repurpose mode: the orb is too small for the full standing
    -- label ("Honor Level 29"), so show the bare numeric level when the
    -- source has one — the tooltip carries the full context. Sources with
    -- no numeric level (renown standing, profession name) keep their label.
    if context and context.levelTextOverride and context.levelTextOverride ~= "" then
        local numericLevel = tonumber(context.level)
        if numericLevel and numericLevel > 0 then
            self.LevelText:SetText(tostring(numericLevel))
        else
            self.LevelText:SetText(context.levelTextOverride)
        end
        return
    end

    local level = (context and context.level) or UnitLevel("player")
    self.LevelText:SetText(tostring(level))
end

function OrbBarStyleTemplate:UpdatePercentText(context)
    if not self.PercentText then
        return
    end
    if context and context.showPercentage == false then
        self.PercentText:Hide()
        return
    end

    local currentXP = (context and context.currentXP) or 0
    local maxXP = (context and context.xpMax) or 1

    local decimals = 1
    if Addon and Addon.Database then
        local db = Addon.Database:GetDB()
        if db then
            decimals = db.percentDecimals or 1
        end
    elseif context then
        decimals = context.percentDecimals or 1
    end

    local percent = (maxXP > 0) and (currentXP / maxXP * 100) or 0
    self.PercentText:SetText(string.format("%." .. decimals .. "f%%", percent))
    self.PercentText:Show()
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
    position = {mode = "DRAGGABLE", positionKey = "OrbBar"},
    style = {},
    capabilities = {
        overlays = false,
        exhaustionTick = false,
        textBelowBar = false,
    }
}

-------------------------------------------------------------------
-- STYLE CREATION
-------------------------------------------------------------------

OrbBarXPBarMixin = XPBarStyleBuilder:Create(XPBarMixinBase, OrbBarStyleTemplate, DefaultConfig)
XPBarStyleBuilder:RegisterStyle("orb", OrbBarXPBarMixin)
