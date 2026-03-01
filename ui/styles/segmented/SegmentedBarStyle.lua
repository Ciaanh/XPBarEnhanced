-- XP Bar Enhanced - Segmented Bar Style
-- Displays XP progress as discrete segments instead of a continuous fill.
-- 20 segments with color-coding for XP, rested XP, and quest XP.

-------------------------------------------------------------------
-- DEPENDENCIES
-------------------------------------------------------------------

if not XPBarStyleBuilder or not XPBarMixinBase then
    error(
        "SegmentedBarStyle: core (StyleBuilder/BaseMixin) not loaded. Ensure ui/xpbars core files are earlier in the .toc."
    )
end

local Addon = XPBarEnhanced
local XPBarColors = _G.XPBarColors

-------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------

local NUM_SEGMENTS = 20
local SEGMENT_GAP = 2
local SEGMENT_HEIGHT = 24
local EMPTY_COLOR = {r = 0.12, g = 0.12, b = 0.12, a = 0.8}

-------------------------------------------------------------------
-- STYLE TEMPLATE
-------------------------------------------------------------------

local SegmentedBarStyleTemplate = {}

--- Create segment textures inside the SegmentContainer frame.
--- Called after BuildVisuals has aliased all XML elements.
function SegmentedBarStyleTemplate:CreateSegments()
    local container = self.SegmentContainer
    if not container then
        return
    end

    self.segments = {}

    local totalWidth = container:GetWidth()
    local totalGaps = (NUM_SEGMENTS - 1) * SEGMENT_GAP
    local segmentWidth = math.floor((totalWidth - totalGaps) / NUM_SEGMENTS)

    for i = 1, NUM_SEGMENTS do
        local segment = container:CreateTexture(nil, "ARTWORK")
        segment:SetSize(segmentWidth, SEGMENT_HEIGHT)

        if i == 1 then
            segment:SetPoint("LEFT", container, "LEFT", 0, 0)
        else
            segment:SetPoint("LEFT", self.segments[i - 1], "RIGHT", SEGMENT_GAP, 0)
        end

        -- Start empty
        segment:SetColorTexture(EMPTY_COLOR.r, EMPTY_COLOR.g, EMPTY_COLOR.b, EMPTY_COLOR.a)
        segment:Show()

        self.segments[i] = segment
    end
end

--- Override RenderBar to fill segments based on XP ratio and overlays.
function SegmentedBarStyleTemplate:RenderBar(context)
    if not self.segments or #self.segments == 0 then
        return
    end

    if not context then
        return
    end

    local ratio = context.ratio or 0
    local filledCount = ratio * NUM_SEGMENTS

    -- Determine bar fill color (rested vs normal)
    local hasRestedXP = context.hasRestedXP or (context.restedXP and context.restedXP > 0)
    local fillColor
    if XPBarColors then
        local colorKey = hasRestedXP and Color.XpBarRested or Color.XpBar
        fillColor = XPBarColors:GetUserColor(colorKey)
    else
        fillColor = {r = 0.58, g = 0.0, b = 0.55, a = 1.0}
    end

    -- Calculate rested XP segment coverage
    local restedRatio = 0
    if context.restedXP and context.maxXP and context.maxXP > 0 and context.currentXP then
        restedRatio = (context.currentXP + context.restedXP) / context.maxXP
    end
    local restedSegments = restedRatio * NUM_SEGMENTS

    -- Get rested overlay color
    local restedColor
    if XPBarColors then
        restedColor = XPBarColors:GetUserColor(Color.Rested)
    else
        restedColor = {r = 0.07, g = 0.58, b = 0.95, a = 0.5}
    end

    -- Calculate quest XP segment coverage
    local questCompleteRatio = 0
    local questIncompleteRatio = 0
    local db = Addon.db or {}

    if db.showQuestXP and context.maxXP and context.maxXP > 0 and context.currentXP then
        if db.showCompleteQuestOverlay and context.completedQuestXP and context.completedQuestXP > 0 then
            questCompleteRatio = (context.currentXP + context.completedQuestXP) / context.maxXP
        end
        if db.showIncompleteQuestOverlay and context.incompleteQuestXP and context.incompleteQuestXP > 0 then
            local questBase = context.currentXP + (context.completedQuestXP or 0)
            questIncompleteRatio = (questBase + context.incompleteQuestXP) / context.maxXP
        end
    end

    local questCompleteSegments = questCompleteRatio * NUM_SEGMENTS
    local questIncompleteSegments = questIncompleteRatio * NUM_SEGMENTS

    -- Get quest overlay colors
    local questCompleteColor, questIncompleteColor
    if XPBarColors then
        questCompleteColor = XPBarColors:GetUserColor(Color.QuestComplete)
        questIncompleteColor = XPBarColors:GetUserColor(Color.QuestIncomplete)
    else
        questCompleteColor = {r = 1.0, g = 0.65, b = 0.0, a = 0.85}
        questIncompleteColor = {r = 0.5, g = 1.0, b = 0.2, a = 0.85}
    end

    -- Render each segment
    for i = 1, NUM_SEGMENTS do
        local segment = self.segments[i]
        local segIndex = i -- 1-based

        if segIndex <= filledCount then
            -- Fully filled with XP
            segment:SetColorTexture(fillColor.r, fillColor.g, fillColor.b, fillColor.a or 1)
        elseif segIndex <= restedSegments and hasRestedXP and db.showRestedOverlay then
            -- Rested XP range (beyond current XP)
            segment:SetColorTexture(restedColor.r, restedColor.g, restedColor.b, restedColor.a or 0.5)
        elseif segIndex <= questCompleteSegments and db.showCompleteQuestOverlay then
            -- Complete quest XP range
            segment:SetColorTexture(questCompleteColor.r, questCompleteColor.g, questCompleteColor.b, questCompleteColor.a or 0.85)
        elseif segIndex <= questIncompleteSegments and db.showIncompleteQuestOverlay then
            -- Incomplete quest XP range
            segment:SetColorTexture(questIncompleteColor.r, questIncompleteColor.g, questIncompleteColor.b, questIncompleteColor.a or 0.85)
        else
            -- Empty segment
            segment:SetColorTexture(EMPTY_COLOR.r, EMPTY_COLOR.g, EMPTY_COLOR.b, EMPTY_COLOR.a)
        end
    end

    -- Update the hidden StatusBar value for mixin compatibility
    if self.StatusBar then
        self.StatusBar:SetMinMaxValues(0, 1)
        self.StatusBar:SetValue(ratio)
    end
end

--- Override FullUpdate to use our custom RenderBar
function SegmentedBarStyleTemplate:FullUpdate(context)
    if not context then
        context = XPBarContextBuilder and XPBarContextBuilder.BuildContext("MANUAL_REFRESH") or {}
    end

    self:RenderBar(context)

    -- Update text elements (delegate to text mixin)
    if self.UpdateAllText then
        self:UpdateAllText(context)
    end
end

--- Override BuildVisuals to create segments after XML elements are aliased
function SegmentedBarStyleTemplate:BuildVisuals()
    -- Call parent BuildVisuals for text/overlay aliasing
    if XPBarPaintMixin and XPBarPaintMixin.BuildVisuals then
        XPBarPaintMixin.BuildVisuals(self)
    end

    -- Create the segment textures
    self:CreateSegments()

    -- Hide the StatusBar visually (we render segments instead)
    if self.StatusBar then
        self.StatusBar:SetAlpha(0)
    end
end

--- Override visual overlay methods (segments handle colors internally)
function SegmentedBarStyleTemplate:UpdateBarColors()
    -- No-op: segment colors are set in RenderBar
end

function SegmentedBarStyleTemplate:UpdateRestedBarColor()
    -- No-op: handled in RenderBar
end

function SegmentedBarStyleTemplate:UpdateQuestCompleteBarColor()
    -- No-op: handled in RenderBar
end

function SegmentedBarStyleTemplate:UpdateQuestIncompleteBarColor()
    -- No-op: handled in RenderBar
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
    position = {mode = "DRAGGABLE", positionKey = "SegmentedBar"},
    style = {}
}

-------------------------------------------------------------------
-- STYLE CREATION
-------------------------------------------------------------------

-- Create composed mixin (Base + Behaviors + Style)
SegmentedBarXPBarMixin = XPBarStyleBuilder:Create(XPBarMixinBase, SegmentedBarStyleTemplate, DefaultConfig)
XPBarStyleBuilder:RegisterStyle("segmented", SegmentedBarXPBarMixin)
