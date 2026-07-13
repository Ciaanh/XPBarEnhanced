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
        self._fillMask = fillMask

        local fillTexture = self.StatusBar.GetStatusBarTexture and self.StatusBar:GetStatusBarTexture()
        if fillTexture and fillTexture.AddMaskTexture then
            fillTexture:AddMaskTexture(fillMask)
        end
        if self.GainFlash and self.GainFlash.AddMaskTexture then
            self.GainFlash:AddMaskTexture(fillMask)
        end
        -- Quest overlays live on the StatusBar and must be clipped too
        for _, key in ipairs({"QuestOverlayComplete", "QuestOverlayIncomplete"}) do
            local overlay = self.StatusBar[key]
            if overlay and overlay.AddMaskTexture then
                overlay:AddMaskTexture(fillMask)
            end
        end
    end

    -- The rested extent lives on the root frame (under the fill); clip it
    -- with the root circle mask.
    if self.RestedOverlay and self.CircleMask and self.RestedOverlay.AddMaskTexture then
        self.RestedOverlay:AddMaskTexture(self.CircleMask)
    end

    if XPBarMixinBase and XPBarMixinBase.OnLoad then
        XPBarMixinBase.OnLoad(self)
    end
end

--- Clip runtime-created effect textures (celebration glow) to the orb circle
function OrbBarStyleTemplate:GetCelebrationMask()
    return self._fillMask
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
    -- No unconditional Show(): visibility is owned by UpdateTextVisibility
    -- (which honors the Blizzard status-text CVar).
end

-------------------------------------------------------------------
-- OVERLAY LAYOUTS (vertical bands clipped to the orb circle)
-- Same math as the Vertical style: positions are proportional to the
-- frame height, anchored from the bottom of the sphere.
-------------------------------------------------------------------

function OrbBarStyleTemplate:UpdateQuestCompleteBarLayout(context, overlayName)
    overlayName = overlayName or "QuestOverlayComplete"
    local overlay = self.StatusBar and self.StatusBar[overlayName]
    if not overlay then
        return
    end

    local completeXP = context.completeQuestXP or 0
    local showQuestXP = context.showQuestXP
    local showComplete = context.showCompleteQuestOverlay

    local visible = false
    if showQuestXP and showComplete and completeXP > 0 then
        local currentXP = context.currentXP or 0
        local maxXP = context.xpMax or 1
        local remainingXP = math.max(0, maxXP - currentXP)
        local questXPClamped = math.min(completeXP, remainingXP)
        local ratio = questXPClamped / maxXP

        if ratio >= 0.01 then
            local barHeight = self:GetHeight()
            local yOffset = barHeight * (currentXP / maxXP)

            overlay:ClearAllPoints()
            overlay:SetPoint("BOTTOMLEFT", self.StatusBar, "BOTTOMLEFT", 0, yOffset)
            overlay:SetPoint("BOTTOMRIGHT", self.StatusBar, "BOTTOMRIGHT", 0, yOffset)
            overlay:SetHeight(math.max(1, barHeight * ratio))
            visible = true
        end
    end

    overlay:SetShown(visible)
end

function OrbBarStyleTemplate:UpdateQuestIncompleteBarLayout(context, overlayName)
    overlayName = overlayName or "QuestOverlayIncomplete"
    local overlay = self.StatusBar and self.StatusBar[overlayName]
    if not overlay then
        return
    end

    local completeQuestXP = context.completeQuestXP or 0
    local incompleteQuestXP = context.incompleteQuestXP or 0
    local showQuestXP = context.showQuestXP
    local showComplete = context.showCompleteQuestOverlay
    local showIncomplete = context.showIncompleteQuestOverlay

    local visible = false
    if showQuestXP and showIncomplete and incompleteQuestXP > 0 then
        local currentXP = context.currentXP or 0
        local maxXP = context.xpMax or 1
        local remainingXP = math.max(0, maxXP - currentXP)

        if showComplete and completeQuestXP > 0 then
            remainingXP = math.max(0, remainingXP - completeQuestXP)
        end

        local questXPClamped = math.min(incompleteQuestXP, remainingXP)
        local ratio = questXPClamped / maxXP

        if ratio >= 0.01 then
            local barHeight = self:GetHeight()
            local startXP = currentXP
            if showComplete and completeQuestXP > 0 then
                startXP = startXP + completeQuestXP
            end
            local yOffset = barHeight * (startXP / maxXP)

            overlay:ClearAllPoints()
            overlay:SetPoint("BOTTOMLEFT", self.StatusBar, "BOTTOMLEFT", 0, yOffset)
            overlay:SetPoint("BOTTOMRIGHT", self.StatusBar, "BOTTOMRIGHT", 0, yOffset)
            overlay:SetHeight(math.max(1, barHeight * ratio))
            visible = true
        end
    end

    overlay:SetShown(visible)
end

function OrbBarStyleTemplate:UpdateRestedBarLayout(context)
    if not self.RestedOverlay then
        return
    end

    local restedXP = context.restedXP or 0
    local showRested = Addon.ConfigHelper.GetShowRestedOverlay(context)
    local showQuestXP = context.showQuestXP
    local showComplete = context.showCompleteQuestOverlay
    local showIncomplete = context.showIncompleteQuestOverlay

    local visible = false
    if showRested and restedXP > 0 then
        local currentXP = context.currentXP or 0
        local maxXP = context.xpMax or 1
        local remainingXP = math.max(0, maxXP - currentXP)
        local restedXPClamped = math.min(restedXP, remainingXP)

        -- Quest overlays sit between the fill and the rested extent
        local questOffset = 0
        local completeQuestXP = context.completeQuestXP or 0
        local incompleteQuestXP = context.incompleteQuestXP or 0
        if showQuestXP and showComplete and completeQuestXP > 0 then
            questOffset = questOffset + math.min(completeQuestXP, remainingXP)
        end
        if showQuestXP and showIncomplete and incompleteQuestXP > 0 then
            local remainingAfterComplete = math.max(0, remainingXP - questOffset)
            questOffset = questOffset + math.min(incompleteQuestXP, remainingAfterComplete)
        end

        local totalXP = currentXP + questOffset + restedXPClamped
        local totalRatio = math.min(totalXP / maxXP, 1.0)

        if totalRatio >= 0.01 then
            local barHeight = self:GetHeight()
            self.RestedOverlay:ClearAllPoints()
            self.RestedOverlay:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 0, 0)
            self.RestedOverlay:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, 0)
            self.RestedOverlay:SetHeight(math.max(1, barHeight * totalRatio))
            visible = true
        end
    end

    self.RestedOverlay:SetShown(visible)
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
        exhaustionTick = false,
        textBelowBar = false,
    }
}

-------------------------------------------------------------------
-- STYLE CREATION
-------------------------------------------------------------------

OrbBarXPBarMixin = XPBarStyleBuilder:Create(XPBarMixinBase, OrbBarStyleTemplate, DefaultConfig)
XPBarStyleBuilder:RegisterStyle("orb", OrbBarXPBarMixin)
