-- XP Bar Enhanced - VerticalBar Style
-- Vertical XP bar with StatusBar widget using vertical orientation
-- Integrates with  AnimationManager for standard effects

-------------------------------------------------------------------
-- DEPENDENCIES
-------------------------------------------------------------------

if not XPBarStyleBuilder or not XPBarMixinBase then
    error(
        "VerticalBarStyle:  core (StyleBuilder/BaseMixin) not loaded. Ensure ui/xpbars core files are earlier in the .toc."
    )
end

local Addon = XPBarEnhanced

local function GetSharedStyleHelpers()
    return Addon and Addon.UI and Addon.UI.SharedStyleHelpers
end

local BASE_WIDTH = 60
local BASE_HEIGHT = 300

-------------------------------------------------------------------
-- STYLE TEMPLATE
-------------------------------------------------------------------

local VerticalBarStyleTemplate = {}

-------------------------------------------------------------------
-- INITIALIZATION
-------------------------------------------------------------------

function VerticalBarStyleTemplate:OnLoad()
    -- Vertical bar specific setup
    self.RateText = self.OverlayFrameTextContainer and self.OverlayFrameTextContainer.RateText

    if XPBarMixinBase and XPBarMixinBase.OnLoad then
        XPBarMixinBase.OnLoad(self)
    end

    self:ResizeToScale()
end

function VerticalBarStyleTemplate:ResizeToScale()
    local shared = GetSharedStyleHelpers()
    local scale = (shared and shared.GetBarScale and shared.GetBarScale("verticalSize")) or 1.0
    local width = BASE_WIDTH * scale
    local height = BASE_HEIGHT * scale

    self:SetSize(width, height)

    -- Keep the inner StatusBar synced to frame scale so fill width/height
    -- matches the resized background and text container.
    if self.StatusBar and self.StatusBar.SetSize then
        self.StatusBar:SetSize(width, height)
    end
end

-------------------------------------------------------------------
-- OVERRIDES for the vertical layout
-------------------------------------------------------------------

--- Override text update methods to match v1 circular format (simple values, not full formatted text)
function VerticalBarStyleTemplate:UpdateLevelText(context)
    if not self.LevelText then
        return
    end

    -- shows just the level number, not "Level XX"
    local level = (context and context.level) or UnitLevel("player")
    self.LevelText:SetText(tostring(level))
end

function VerticalBarStyleTemplate:UpdateRateText(context)
    if not self.RateText or not Addon.TextFormatter then
        return
    end

    -- only shows time to level (not XP/hour)
    local showTimeToLevel = Addon.ConfigHelper.GetShowTimeToLevelText(context)

    if not showTimeToLevel then
        self.RateText:SetText("")
        return
    end

    -- Get time to level from context or Session service
    local timeToLevel =
        (context and context.timeToLevel) or
        (Addon.Session and Addon.Session.GetTimeToLevel and Addon.Session:GetTimeToLevel()) or
        0

    if timeToLevel > 0 then
        self.RateText:SetText(Addon.TextFormatter:GetTimeToLevelText(timeToLevel))
    else
        self.RateText:SetText("")
    end
end

--- Override main bar color for vertical orientation (uses StatusBar SetStatusBarColor)
function VerticalBarStyleTemplate:UpdateBarColors(context, barName)
    if not self.StatusBar then
        return
    end

    local shared = GetSharedStyleHelpers()
    local color = shared and shared.GetXPBarColor and shared.GetXPBarColor(context)
    if not color or not color.r then
        local Colors = Addon and Addon.Colors
        if Colors and Colors.Get and Colors.Key then
            color = Colors:Get(Colors.Key.XpBar)
        end
    end
    color = color or {r = 1, g = 1, b = 1, a = 1}

    -- Use SetStatusBarColor for StatusBar widget
    self.StatusBar:SetStatusBarColor(color.r, color.g, color.b, color.a or 1)
end

--- Override quest complete overlay layout for vertical orientation
function VerticalBarStyleTemplate:UpdateQuestCompleteBarLayout(context, overlayName)
    overlayName = overlayName or "QuestOverlayComplete"
    local overlay = self.StatusBar and self.StatusBar[overlayName]

    if not overlay then
        return
    end

    local completeXP = context.completeQuestXP or 0

    -- Get visibility flags from context (single source of truth)
    local showQuestXP = context.showQuestXP
    local showComplete = context.showCompleteQuestOverlay

    local visible = false
    if showQuestXP and showComplete and (completeXP and completeXP > 0) then
        local currentXP = context.currentXP or 0
        local maxXP = context.xpMax or 1
        local remainingXP = math.max(0, maxXP - currentXP)
        local questXPClamped = math.min(completeXP, remainingXP)
        local ratio = questXPClamped / maxXP

        if ratio >= 0.01 then
            local barHeight = self:GetHeight()

            -- Vertical: calculate Y offset and height
            local currentRatio = currentXP / maxXP
            local yOffset = barHeight * currentRatio -- Start at top of current XP
            local height = barHeight * ratio

            overlay:ClearAllPoints()
            overlay:SetPoint("BOTTOMLEFT", self.StatusBar, "BOTTOMLEFT", 0, yOffset)
            overlay:SetPoint("BOTTOMRIGHT", self.StatusBar, "BOTTOMRIGHT", 0, yOffset)
            overlay:SetHeight(math.max(1, height))
            visible = true
        end
    end

    overlay:SetShown(visible)
end

--- Override quest incomplete overlay layout for vertical orientation
function VerticalBarStyleTemplate:UpdateQuestIncompleteBarLayout(context, overlayName)
    overlayName = overlayName or "QuestOverlayIncomplete"
    local overlay = self.StatusBar and self.StatusBar[overlayName]

    if not overlay then
        return
    end

    local completeQuestXP = context.completeQuestXP or 0
    local incompleteQuestXP = context.incompleteQuestXP or 0

    -- Get visibility flags from context (single source of truth)
    local showQuestXP = context.showQuestXP
    local showComplete = context.showCompleteQuestOverlay
    local showIncomplete = context.showIncompleteQuestOverlay

    local visible = false
    if showQuestXP and showIncomplete and incompleteQuestXP > 0 then
        local currentXP = context.currentXP or 0
        local maxXP = context.xpMax or 1
        local remainingXP = math.max(0, maxXP - currentXP)

        -- Only subtract complete quest XP if that overlay is actually showing
        if showQuestXP and showComplete and completeQuestXP > 0 then
            remainingXP = math.max(0, remainingXP - completeQuestXP)
        end

        local questXPClamped = math.min(incompleteQuestXP, remainingXP)
        local ratio = questXPClamped / maxXP

        if ratio >= 0.01 then
            local barHeight = self:GetHeight()

            -- Vertical: calculate start Y position (current XP + complete quest XP if showing)
            local startXP = currentXP
            if showQuestXP and showComplete and completeQuestXP > 0 then
                startXP = startXP + completeQuestXP
            end

            local startRatio = startXP / maxXP
            local yOffset = barHeight * startRatio
            local height = barHeight * ratio

            overlay:ClearAllPoints()
            overlay:SetPoint("BOTTOMLEFT", self.StatusBar, "BOTTOMLEFT", 0, yOffset)
            overlay:SetPoint("BOTTOMRIGHT", self.StatusBar, "BOTTOMRIGHT", 0, yOffset)
            overlay:SetHeight(math.max(1, height))
            visible = true
        end
    end

    overlay:SetShown(visible)
end

--- Override rested overlay layout for vertical orientation
function VerticalBarStyleTemplate:UpdateRestedBarLayout(context)
    if not self.RestedOverlay then
        return
    end

    local restedXP = context.restedXP or 0
    local showRested = Addon.ConfigHelper.GetShowRestedOverlay(context)

    -- Get quest overlay visibility from context (single source of truth)
    local showQuestXP = context.showQuestXP
    local showComplete = context.showCompleteQuestOverlay
    local showIncomplete = context.showIncompleteQuestOverlay

    local visible = false
    if showRested and restedXP > 0 then
        local currentXP = context.currentXP or 0
        local maxXP = context.xpMax or 1
        local remainingXP = math.max(0, maxXP - currentXP)
        local restedXPClamped = math.min(restedXP, remainingXP)

        -- Calculate quest offset (how much space quest overlays take)
        local questOffset = 0
        local completeQuestXP = context.completeQuestXP or 0
        local incompleteQuestXP = context.incompleteQuestXP or 0

        -- Add complete quest XP if showing
        if showQuestXP and showComplete and completeQuestXP > 0 then
            local completeQuestClamped = math.min(completeQuestXP, remainingXP)
            questOffset = questOffset + completeQuestClamped
        end

        -- Add incomplete quest XP if showing
        if showQuestXP and showIncomplete and incompleteQuestXP > 0 then
            local remainingAfterComplete = math.max(0, remainingXP - questOffset)
            local incompleteQuestClamped = math.min(incompleteQuestXP, remainingAfterComplete)
            questOffset = questOffset + incompleteQuestClamped
        end

        -- Vertical: total height from bottom (current XP + quest overlays + rested XP)
        -- The rested overlay is behind everything, so it extends from 0 to (current + quests + rested)
        local totalXP = currentXP + questOffset + restedXPClamped
        local totalRatio = math.min(totalXP / maxXP, 1.0)

        if totalRatio >= 0.01 then
            local barHeight = self:GetHeight()
            local height = barHeight * totalRatio

            self.RestedOverlay:ClearAllPoints()
            self.RestedOverlay:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 0, 0)
            self.RestedOverlay:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, 0)
            self.RestedOverlay:SetHeight(math.max(1, height))
            visible = true
        end
    end

    self.RestedOverlay:SetShown(visible)
end

--- Override percent text to match circular center text behavior
--- (simple current percent only; no quest-percent augmentation)
function VerticalBarStyleTemplate:UpdatePercentText(context)
    if not self.PercentText then
        return
    end

    -- Respect explicit visibility flags first (context wins); fallback to ConfigHelper if present
    local showPercent = nil
    if context then
        showPercent = context.showPercent or context.showPercentage
    end
    if Addon.ConfigHelper and Addon.ConfigHelper.GetShowPercentage then
        showPercent = Addon.ConfigHelper.GetShowPercentage(context)
    end
    if showPercent == false then
        self.PercentText:Hide()
        return
    end

    local currentXP = (context and context.currentXP) or 0
    local maxXP = (context and context.xpMax) or 1

    -- Keep decimals source consistent with circular style (DB-backed)
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

-- Default configuration for vertical bar
local DefaultConfig = {
    interaction = {enabled = true},
    tooltip = {enabled = true},
    animation = {
        enableAnimations = true,
        flashOnGain = true
    },
    position = {mode = "DRAGGABLE", positionKey = "VerticalBar"},
    style = {},
    capabilities = {
        textBelowBar = false,
    }
}

-------------------------------------------------------------------
-- STYLE CREATION
-------------------------------------------------------------------

-- Create composed mixin (Base + Behaviors + Style)
VerticalBarXPBarMixin = XPBarStyleBuilder:Create(XPBarMixinBase, VerticalBarStyleTemplate, DefaultConfig)
XPBarStyleBuilder:RegisterStyle("vertical", VerticalBarXPBarMixin)
