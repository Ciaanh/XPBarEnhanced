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
local Colors = Addon.Colors

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

    -- Use the parent frame's declared width; container:GetWidth() returns 0
    -- during OnLoad because anchor-based sizing hasn't resolved yet.
    local totalWidth = self:GetWidth()
    if totalWidth == 0 then
        totalWidth = 565
    end
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

--- Called by the animation system each frame with the interpolated ratio.
--- Rebuilds a lightweight context so RenderBar can colour segments correctly.
function SegmentedBarStyleTemplate:UpdateGainedBar(currentRatio, eventContext)
    if not self.segments or #self.segments == 0 then
        return
    end

    -- Build a minimal context for RenderBar using the interpolated ratio.
    local ctx = eventContext or {}
    local renderCtx = {
        ratio        = currentRatio,
        currentXP    = ctx.currentXP,
        xpMax        = ctx.xpMax,
        restedXP     = ctx.restedXP,
        hasRestedXP  = ctx.hasRestedXP,
        completeQuestXP    = ctx.completeQuestXP,
        incompleteQuestXP  = ctx.incompleteQuestXP,
    }
    self:RenderBar(renderCtx)
end

--- Override RenderBar to fill segments based on XP ratio and overlays.
function SegmentedBarStyleTemplate:RenderBar(context)
    if not self.segments or #self.segments == 0 then
        return
    end

    if not context then
        return
    end

    -- Derive ratio from currentXP/xpMax when the caller hasn't pre-computed it.
    -- ContextBuilder never sets a "ratio" field; it always provides currentXP + xpMax.
    local ratio = context.ratio
    if not ratio then
        local currentXP = context.currentXP or 0
        local xpMax = context.xpMax or 1
        ratio = xpMax > 0 and (currentXP / xpMax) or 0
    end
    local filledCount = ratio * NUM_SEGMENTS

    -- Determine bar fill color (rested vs normal)
    local hasRestedXP = context.hasRestedXP or (context.restedXP and context.restedXP > 0)
    local fillColor
    local colorKey = hasRestedXP and Colors.Key.XpBarRested or Colors.Key.XpBar
    fillColor = Colors:Get(colorKey)

    -- Calculate rested XP segment coverage
    local restedRatio = 0
    if context.restedXP and context.xpMax and context.xpMax > 0 and context.currentXP then
        restedRatio = (context.currentXP + context.restedXP) / context.xpMax
    end
    local restedSegments = restedRatio * NUM_SEGMENTS

    -- Get rested overlay color
    local restedColor = Colors:Get(Colors.Key.Rested)

    -- Calculate quest XP segment coverage
    local questCompleteRatio = 0
    local questIncompleteRatio = 0
    local db = Addon.db or {}

    if db.showQuestXP and context.xpMax and context.xpMax > 0 and context.currentXP then
        if db.showCompleteQuestOverlay and context.completeQuestXP and context.completeQuestXP > 0 then
            questCompleteRatio = (context.currentXP + context.completeQuestXP) / context.xpMax
        end
        if db.showIncompleteQuestOverlay and context.incompleteQuestXP and context.incompleteQuestXP > 0 then
            local questBase = context.currentXP + (context.completeQuestXP or 0)
            questIncompleteRatio = (questBase + context.incompleteQuestXP) / context.xpMax
        end
    end

    local questCompleteSegments = questCompleteRatio * NUM_SEGMENTS
    local questIncompleteSegments = questIncompleteRatio * NUM_SEGMENTS

    -- Get quest overlay colors
    local questCompleteColor = Colors:Get(Colors.Key.QuestComplete)
    local questIncompleteColor = Colors:Get(Colors.Key.QuestIncomplete)

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
    if self.UpdateTexts then
        self:UpdateTexts(context)
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
