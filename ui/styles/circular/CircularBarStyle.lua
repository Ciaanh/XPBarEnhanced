-- XP Bar Enhanced - CircularBar Style
-- Circular progress ring with optimized 100-segment system
-- Integrates with AnimationManager for standard effects

-------------------------------------------------------------------
-- DEPENDENCIES
-------------------------------------------------------------------

if not XPBarStyleBuilder or not XPBarMixinBase then
    error(
        "CircularBarStyle:  core (StyleBuilder/BaseMixin) not loaded. Ensure ui/xpbars core files are earlier in the .toc."
    )
end

local Addon = XPBarEnhanced
local Config = Addon.Config

local function GetSharedStyleHelpers()
    return Addon and Addon.UI and Addon.UI.SharedStyleHelpers
end

-------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------

local MAX_SEGMENTS = 100 -- Always create this many (pool size)
local DEFAULT_SEGMENTS = 50 -- Default visible segments
local CIRCLE_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

local SEGMENT_TYPE = {
    HIDDEN = -1, -- Not displayed (beyond configured count)
    EMPTY = 0, -- Background/transparent segment
    CURRENT_XP = 1, -- Current XP (main bar color)
    RESTED = 2, -- Rested XP overlay
    QUEST_COMPLETE = 3, -- Complete quest XP
    QUEST_INCOMPLETE = 4 -- Incomplete quest XP
}

-- Background color for empty segments (slight transparency to show ring structure)
local EMPTY_SEGMENT_COLOR = {r = 0.1, g = 0.1, b = 0.1, a = 0.3}

local CIRCULAR_BAR_STYLE = {
    RING_RADIUS_PX = 97, -- Distance from center to segment center (placement radius)
    SEGMENT_WIDTH_PX = 5, -- Base width of each segment at 100 segments
    SEGMENT_HEIGHT_PX = 15, -- Height of each segment in pixels
    SEGMENT_TEXTURE_PATH_SOLID = "Interface\\Buttons\\WHITE8X8", -- Solid texture for segments
    SEGMENT_TEXTURE_PATH = "Interface\\AddOns\\XPBarEnhanced\\assets\\xp-bar" -- Texture for each segment
}

-- Reference segment count for base width (segments are wider with fewer count)
local REFERENCE_SEGMENT_COUNT = 100

-- Predefined size presets mapping to scale factors
local CIRCULAR_SIZE_SCALES = {
    small = 0.75,
    medium = 1.0,
    large = 1.5,
    huge = 2.0
}

-- Base frame size at 1.0 scale (matches XML template)
local BASE_FRAME_SIZE = 256

-------------------------------------------------------------------
-- STYLE TEMPLATE
-------------------------------------------------------------------

local CircularBarStyleTemplate = {}

-------------------------------------------------------------------
-- INITIALIZATION
-------------------------------------------------------------------

function CircularBarStyleTemplate:OnLoad()
    -- Circular bar specific setup
    self.segments = {} -- Single set of segments
    self.segmentTypes = {} -- Track type of each segment
    self.lastProgress = 0
    self.targetProgress = 0
    self.isAnimating = false

    -- Create ring segments (initialized with background color)
    self:CreateRingSegments()

    -- Call base OnLoad (initializes animation system and calls Refresh)
    if XPBarMixinBase and XPBarMixinBase.OnLoad then
        XPBarMixinBase.OnLoad(self)
    end
end

-------------------------------------------------------------------
-- SEGMENT CREATION AND POSITIONING
-------------------------------------------------------------------

--- Get the configured size scale factor (from saved settings)
-- @return number: Scale factor for ring size (0.75 to 2.0)
function CircularBarStyleTemplate:GetCircularScale()
    local size = "medium"
    local saved = Config and Config.GetOptionValue and Config:GetOptionValue("circularSize")
    if type(saved) == "string" and CIRCULAR_SIZE_SCALES[saved] then
        size = saved
    end
    return CIRCULAR_SIZE_SCALES[size] or 1.0
end

--- Get the configured number of segments to display (from saved settings)
-- @return number: Number of segments to display (clamped to 25-100)
function CircularBarStyleTemplate:GetDisplaySegmentCount()
    local count = DEFAULT_SEGMENTS
    local saved = Config and Config.GetOptionValue and Config:GetOptionValue("circularSegments")
    if type(saved) == "number" then
        count = saved
    else
        -- Migrate any boolean/invalid saved values to default on the active storage target.
        if saved ~= nil and Config and Config.SetOptionKey then
            Config:SetOptionKey("circularSegments", DEFAULT_SEGMENTS)
        end
    end
    -- Clamp to valid range
    -- normalize to integer and clamp
    count = math.floor(tonumber(count) or DEFAULT_SEGMENTS)
    return math.max(25, math.min(100, count))
end

--- Calculate segment width based on display count
-- Wider segments for fewer count to maintain visual ring coverage
-- @param displayCount number: Number of segments being displayed
-- @return number: Width in pixels for each segment
function CircularBarStyleTemplate:GetSegmentWidth(displayCount)
    -- Scale width inversely with segment count
    -- At 100 segments: base width (5px)
    -- At 25 segments (the floor GetDisplaySegmentCount clamps to): 4x wider (20px)
    local baseWidth = CIRCULAR_BAR_STYLE.SEGMENT_WIDTH_PX
    local scaleFactor = REFERENCE_SEGMENT_COUNT / displayCount
    return baseWidth * scaleFactor
end

--- Get whether to use textured or solid segments (from saved settings)
-- @return boolean: true for textured, false for solid color
function CircularBarStyleTemplate:GetUseTexture()
    if Config and Config.GetOptionValue then
        local useTexture = Config:GetOptionValue("circularUseTexture")
        if useTexture ~= nil then
            return useTexture
        end
    end
    return true -- Default to textured
end

--- Get the appropriate texture path based on settings
-- @return string: Texture path to use for segments
function CircularBarStyleTemplate:GetSegmentTexturePath()
    if self:GetUseTexture() then
        return CIRCULAR_BAR_STYLE.SEGMENT_TEXTURE_PATH
    else
        return CIRCULAR_BAR_STYLE.SEGMENT_TEXTURE_PATH_SOLID
    end
end

function CircularBarStyleTemplate:CreateRingSegments()
    -- Create full pool of segments (all hidden initially)
    local color = EMPTY_SEGMENT_COLOR
    local texturePath = self:GetSegmentTexturePath()
    for i = 1, MAX_SEGMENTS do
        local segment = self:CreateTexture(nil, "ARTWORK")
        segment:SetTexture(texturePath)
        segment:SetSize(CIRCULAR_BAR_STYLE.SEGMENT_WIDTH_PX, CIRCULAR_BAR_STYLE.SEGMENT_HEIGHT_PX)
        segment:SetVertexColor(color.r, color.g, color.b, color.a)
        segment:Hide() -- Start hidden
        self.segments[i] = segment
        self.segmentTypes[i] = SEGMENT_TYPE.HIDDEN
    end

    -- Position and show only the configured number
    self:RepositionSegments()
end

--- Reposition segments based on current config (called on config change)
function CircularBarStyleTemplate:RepositionSegments()
    -- Reset the paint diff here rather than at the call sites: this is the one
    -- place segment geometry, texture and visibility change, and resetting inside
    -- it means all five existing callers (OnLoad, the four option handlers, the
    -- profile-change path) and any future one force a full repaint for free.
    self._prevSegmentTypes = nil
    self._prevOverlayAlpha = nil
    self._prevSegmentCount = nil

    local displayCount = self:GetDisplaySegmentCount()
    local clockwise = -1
    local scale = self:GetCircularScale()
    local placementRadius = CIRCULAR_BAR_STYLE.RING_RADIUS_PX * scale

    -- Resize frame to match scale (BorderRing and GainFlash auto-resize via setAllPoints;
    -- CenterBG is re-pinned to fixed size by FixStaticElements called below)
    local frameSize = BASE_FRAME_SIZE * scale
    self:SetSize(frameSize, frameSize)

    -- Calculate segment width based on count (wider for fewer segments), then apply scale
    local segmentWidth = self:GetSegmentWidth(displayCount) * scale
    local segmentHeight = CIRCULAR_BAR_STYLE.SEGMENT_HEIGHT_PX * scale

    -- Update texture for all segments based on current setting
    local texturePath = self:GetSegmentTexturePath()
    for i = 1, MAX_SEGMENTS do
        local segment = self.segments[i]
        if segment then
            segment:SetTexture(texturePath)
        end
    end

    -- Localize heavy math functions for the inner loop
    local math_cos = math.cos
    local math_sin = math.sin
    local math_pi = math.pi

    -- Start at 6 o'clock (bottom) and increase angle -> clockwise in WoW (y positive = down)
    local startAngle = math_pi / 2
    local fullCircle = 2 * math_pi

    -- Position visible segments
    for i = 1, displayCount do
        local angle = startAngle + ((i - 1) / displayCount) * fullCircle

        -- Offsets relative to frame center (use CENTER anchor)
        local xOff = math_cos(angle) * placementRadius
        local yOff = math_sin(angle) * placementRadius * clockwise
        local rotation = (clockwise * angle) + startAngle

        -- Position and size segment
        local segment = self.segments[i]
        segment:SetSize(segmentWidth, segmentHeight)
        segment:ClearAllPoints()
        segment:SetPoint("CENTER", self, "CENTER", xOff, yOff)
        if segment.SetRotation then
            segment:SetRotation(rotation)
        end
        segment:Show()
        self.segmentTypes[i] = SEGMENT_TYPE.EMPTY
    end

    -- Hide excess segments beyond displayCount
    for i = displayCount + 1, MAX_SEGMENTS do
        local segment = self.segments[i]
        if segment then
            segment:Hide()
            self.segmentTypes[i] = SEGMENT_TYPE.HIDDEN
        end
    end

    -- Re-pin CenterBG and update center text scale
    self:FixStaticElements()
    self:UpdateCenterTextScale()

    -- Re-apply current progress colors after repositioning
    if self.Refresh then
        self:Refresh()
    end
end

--- Keep CenterBG at its original 256x256 size centered on the frame,
--- or scale it proportionally when center text scaling is enabled.
-- Called after every frame resize.
function CircularBarStyleTemplate:FixStaticElements()
    if self.CenterBG then
        self.CenterBG:ClearAllPoints()
        if Config and Config.GetOptionValue and Config:GetOptionValue("circularScaleCenterText") then
            self.CenterBG:SetAllPoints(self)
        else
            self.CenterBG:SetSize(BASE_FRAME_SIZE, BASE_FRAME_SIZE)
            self.CenterBG:SetPoint("CENTER", self, "CENTER", 0, 0)
        end
    end
end

-------------------------------------------------------------------
--  ANIMATION IMPLEMENTATION (AnimationManager integration)
-------------------------------------------------------------------

--- Update bar position - smooth fill animation
-- @param iterationData table: Per-frame iteration data with currentRatio
-- @param eventContext table: Immutable event context
function CircularBarStyleTemplate:AnimateBarPosition(iterationData, eventContext)
    -- During level-up Phase 1 (animating to 100%), hide overlays to avoid visual artifacts
    -- The context contains new level data, but we're animating the old level's progress
    local contextToUse = eventContext
    if iterationData.isLevelUpPhase1 then
        -- Create a modified context that hides overlays during Phase 1
        contextToUse = {
            -- Copy essential fields from eventContext
            hasRestedXP = eventContext.hasRestedXP,
            xpMax = eventContext.preLevelXPMax or eventContext.xpMax or 1,
            currentXP = math.floor((iterationData.currentRatio or 0) * (eventContext.preLevelXPMax or eventContext.xpMax or 1)),
            -- Hide all overlays during Phase 1
            showQuestXP = false,
            showCompleteQuestOverlay = false,
            showIncompleteQuestOverlay = false,
            showRestedOverlay = false,
            completeQuestXP = 0,
            incompleteQuestXP = 0,
            restedXP = 0
        }
    end
    
    -- Update the arc progress with current ratio
    -- Pass hasRestedXP from eventContext to ensure correct coloring
    -- Pass complete event context into SetArcProgress to ensure the style
    -- uses fresh flags (showQuestXP, showCompleteQuestOverlay, etc.) during animation.
    self:SetArcProgress(iterationData.currentRatio, contextToUse, iterationData.questOverlayAlpha)
end

--- Update visual effects - glow overlay animation
-- @param iterationData table: Per-frame iteration data with flashData
-- @param eventContext table: Immutable event context
function CircularBarStyleTemplate:AnimateBarEffect(iterationData, eventContext)
    -- Access GainFlash with fallback pattern (StatusBar.GainFlash or main frame GainFlash)
    local gainFlash = (self.StatusBar and self.StatusBar.GainFlash) or self.GainFlash
    if not gainFlash then
        return
    end

    local flashData = iterationData.flashData
    local flashActive = flashData and flashData.active and flashData.currentAlpha > 0
    if flashActive then
        -- Show glow with animated alpha
        gainFlash:SetAlpha(flashData.currentAlpha)
        gainFlash:Show()
    else
        -- Force hide and reset alpha when flash is inactive or nil
        gainFlash:SetAlpha(0)
        gainFlash:Hide()
    end
end

--- Clip runtime-created effect textures (celebration glow) to the ring circle.
--- This style has no StatusBar, so the glow anchors to the bar frame and would
--- otherwise pulse as a square over a round bar.
function CircularBarStyleTemplate:GetCelebrationMask()
    if not self._celebrationMask then
        local mask = self:CreateMaskTexture()
        mask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(self)
        self._celebrationMask = mask
    end
    return self._celebrationMask
end

-------------------------------------------------------------------
-- OPTIMIZED SEGMENT MANAGEMENT
-------------------------------------------------------------------

function CircularBarStyleTemplate:CountSegmentsToDisplay(progress, totalSegments)
    local segments = math.floor(progress * totalSegments)
    segments = math.max(0, math.min(segments, totalSegments))
    return segments
end

--- Set arc progress and calculate all segment types in one pass
-- @param progress number: Progress ratio (0-1)
-- @param context table: Immutable context with all state and flags
-- @param overlayAlpha number: Optional alpha for overlay segments
function CircularBarStyleTemplate:SetArcProgress(progress, context, overlayAlpha)
    -- Defensive: if context is nil, return silently rather than raising errors.
    if not context then
        return
    end

    local totalSegments = self:GetDisplaySegmentCount()

    local overlaySegments = self:ComputeOverlaySegments(progress, context, totalSegments)

    -- Reset segment types to empty
    for i = 1, totalSegments do
        self.segmentTypes[i] = SEGMENT_TYPE.EMPTY
    end

    -- Fill current XP
    for i = 1, overlaySegments.currentXPSegments do
        self.segmentTypes[i] = SEGMENT_TYPE.CURRENT_XP
    end

    -- Fill quest complete overlay if present
    if overlaySegments.completeCount and overlaySegments.completeCount > 0 then
        local start = overlaySegments.completeStart
        local last = math.min(start + overlaySegments.completeCount - 1, totalSegments)
        for i = start, last do
            self.segmentTypes[i] = SEGMENT_TYPE.QUEST_COMPLETE
        end
    end

    -- Fill quest incomplete overlay if present
    if overlaySegments.incompleteCount and overlaySegments.incompleteCount > 0 then
        local start = overlaySegments.incompleteStart
        local last = math.min(start + overlaySegments.incompleteCount - 1, totalSegments)
        for i = start, last do
            self.segmentTypes[i] = SEGMENT_TYPE.QUEST_INCOMPLETE
        end
    end

    -- Fill rested overlay if present (use only empty segments)
    if overlaySegments.restedCount and overlaySegments.restedCount > 0 then
        local start = overlaySegments.restedStart
        local last = math.min(start + overlaySegments.restedCount - 1, totalSegments)
        for i = start, last do
            if self.segmentTypes[i] == SEGMENT_TYPE.EMPTY then
                self.segmentTypes[i] = SEGMENT_TYPE.RESTED
            end
        end
    end

    -- Apply colors (totalSegments is resolved once here and passed down --
    -- GetDisplaySegmentCount is a full profile-chain read and can even write on a
    -- migration path, so it must not be called twice per frame)
    local hasRestedXP = context.hasRestedXP == true
    self:UpdateSegmentColors(hasRestedXP, overlayAlpha, totalSegments)
end

--- Build (or reuse) the segment colour table for the current render.
--- The four Colors:Get / GetXPBarColor lookups and the table allocation used to
--- be paid on every animation frame. The table is invalidated at RenderBar entry
--- and keyed on hasRestedXP, so a rested flip mid-animation still recolours.
-- @param hasRestedXP boolean: Whether player has rested XP available
-- @return table: Colour table consumed by ApplySegmentTypeColor
function CircularBarStyleTemplate:GetRenderColors(hasRestedXP)
    if self._renderColors and self._renderColorsRested == hasRestedXP then
        return self._renderColors
    end

    local Colors = XPBarEnhanced.Colors
    local shared = GetSharedStyleHelpers()
    local currentXPColor = nil
    if shared and shared.GetXPBarColor then
        currentXPColor = shared.GetXPBarColor({hasRestedXP = hasRestedXP})
    end
    if not currentXPColor or not currentXPColor.r then
        local key = hasRestedXP and Colors.Key.XpBarRested or Colors.Key.XpBar
        currentXPColor = Colors:Get(key)
    end

    self._renderColors = {
        currentXP = currentXPColor,
        rested = Colors:Get(Colors.Key.Rested),
        questComplete = Colors:Get(Colors.Key.QuestComplete),
        questIncomplete = Colors:Get(Colors.Key.QuestIncomplete),
    }
    self._renderColorsRested = hasRestedXP

    -- Fresh colours invalidate the paint diff: every visible segment needs
    -- rewriting even where its type is unchanged.
    self._prevSegmentTypes = nil

    return self._renderColors
end

--- Apply colors to segments, touching only those whose paint actually changed.
--- At 100 segments the old unconditional loop cost 100 SetVertexColor + 100 Show
--- per animation frame; a typical frame changes 1-3 segments.
-- @param hasRestedXP boolean: Whether player has rested XP available
-- @param overlayAlpha number|nil: Alpha multiplier for overlay segments
-- @param totalSegments number|nil: Visible segment count, resolved by the caller
function CircularBarStyleTemplate:UpdateSegmentColors(hasRestedXP, overlayAlpha, totalSegments)
    local shared = GetSharedStyleHelpers()
    local colors = self:GetRenderColors(hasRestedXP)

    overlayAlpha = overlayAlpha or 1.0
    totalSegments = totalSegments or self:GetDisplaySegmentCount()

    -- Full-repaint conditions. overlayAlpha multiplies into every segment's
    -- colour, so an animating alpha invalidates the diff wholesale; a changed
    -- count means the previous snapshot describes a different ring.
    local prev = self._prevSegmentTypes
    if prev and (self._prevOverlayAlpha ~= overlayAlpha or self._prevSegmentCount ~= totalSegments) then
        prev = nil
    end

    local types = self.segmentTypes
    for i = 1, totalSegments do
        local segType = types[i]
        if not prev or prev[i] ~= segType then
            local segment = self.segments[i]
            if segment then
                if shared and shared.ApplySegmentTypeColor then
                    shared.ApplySegmentTypeColor(segment, segType, colors, EMPTY_SEGMENT_COLOR, overlayAlpha)
                else
                    local fallback = colors.currentXP or EMPTY_SEGMENT_COLOR
                    segment:SetVertexColor(fallback.r, fallback.g, fallback.b, (fallback.a or 1) * overlayAlpha)
                end
            end
        end
    end

    -- No Show() here. Visibility belongs to RepositionSegments, which runs from
    -- OnLoad, the four option handlers and the profile-change path -- never
    -- mid-animation -- and which resets this snapshot so the next frame repaints
    -- in full.
    local snapshot = prev
    if not snapshot then
        snapshot = self._prevSegmentTypes or {}
        self._prevSegmentTypes = snapshot
    end
    for i = 1, totalSegments do
        snapshot[i] = types[i]
    end
    self._prevOverlayAlpha = overlayAlpha
    self._prevSegmentCount = totalSegments
end

-------------------------------------------------------------------
--  UNIFIED RENDER PATTERN
-------------------------------------------------------------------

-- OVERRIDES
--- Single render method for circular bar ( unified pattern)
--- Pure rendering method - orchestration handled by BaseMixin:TriggerBarRefresh
---@param context table Immutable context with all state and flags
function CircularBarStyleTemplate:RenderBar(context)
    if not context then
        error("RenderBar requires an explicit immutable context")
    end

    self._lastLevel = context.level

    -- Invalidate the per-render colour cache. Bars do not subscribe to
    -- COLORS_UPDATED -- every colour-change path (options swatch, profile switch,
    -- Colors:NotifyColorsChanged) reaches the bar as a domain broadcast that ends
    -- here, so rebuilding at RenderBar entry makes all of them correct by
    -- construction, and the animation frames that follow reuse the one table.
    self._renderColors = nil

    -- Calculate target ratio (use currentXP as canonical field)
    local targetRatio = self:CalculateTargetRatio(context)

    -- Initialize current ratio if not set (first update after creation)
    if not self._currentRatio then
        if self.SetCurrentRatio then
            self:SetCurrentRatio(targetRatio)
        end
    end

    -- Update overlays FIRST (always update, matches Classic/Vertical pattern)
    -- These populate the cached overlay data that SetArcProgress uses.
    -- Doing this before the UpdateGainedBar / SetArcProgress call ensures the
    -- Circular style uses the latest context values (e.g., when toggling
    -- quest XP or on level-up) and avoids showing stale overlay colors.
    if self.UpdateRestedBar then
        self:UpdateRestedBar(context)
    end
    if self.UpdateQuestCompleteBar then
        self:UpdateQuestCompleteBar(context)
    end
    if self.UpdateQuestIncompleteBar then
        self:UpdateQuestIncompleteBar(context)
    end
    if self.UpdateExhaustionTick then
        self:UpdateExhaustionTick(context)
    end

    -- Render at final position (no animation decision - BaseMixin handles that)
    self:UpdateGainedBar(targetRatio, context)

    -- Update text (always update, matches Classic/Vertical pattern)
    if self.UpdateTexts then
        self:UpdateTexts(context)
    end
end

-- OVERRIDES
--- Render all bar elements for a single animation frame
--- Called by AnimationManager on each tick, or once for instant updates
---@param currentRatio number Current animation progress (0-1), or final ratio for instant
---@param context table Immutable context with all state and flags
function CircularBarStyleTemplate:UpdateGainedBar(currentRatio, context)
    -- Pass full context so SetArcProgress can prefer context values and avoid stale cached data
    self:SetArcProgress(currentRatio, context)

    -- Update current ratio tracking
    if self.SetCurrentRatio then
        self:SetCurrentRatio(currentRatio)
    end

    if self.UpdateTexts then
        self:UpdateTexts(context)
    end

    -- Note: Overlays are handled inside SetArcProgress for circular bar
    -- SetArcProgress calculates segment types for: current XP, rested, quest complete, quest incomplete
end

-------------------------------------------------------------------
-- OVERRIDES for circular layout
-------------------------------------------------------------------

-- These are no-ops: SetArcProgress is called once with the correct ratio in
-- UpdateGainedBar, which is the canonical render entry point for circular bar.
-- Calling it in each overlay method caused 4x renders per frame with stale ratios.
function CircularBarStyleTemplate:UpdateRestedBar(context) end

function CircularBarStyleTemplate:UpdateQuestCompleteBar(context) end

function CircularBarStyleTemplate:UpdateQuestIncompleteBar(context) end

--- Override UpdateVisuals to trigger text updates
function CircularBarStyleTemplate:UpdateVisuals(context)
    if not context then
        return
    end

    -- Update text content with context
    if self.UpdateTexts then
        self:UpdateTexts(context)
    else
    end
end

--- Override text visibility: center text is the primary display for circular
--- bars and must NOT be gated by Blizzard's xpBarText CVar.
function CircularBarStyleTemplate:UpdateTextVisibility(context)
    if self.LevelText then
        local show = Addon.ConfigHelper.GetShowLevelText(context)
        self.LevelText:SetShown(show)
    end
    if self.PercentText then
        local show = Addon.ConfigHelper.GetShowPercentage(context)
        self.PercentText:SetShown(show)
    end
    if self.RateText then
        local showTimeToLevel = Addon.ConfigHelper.GetShowTimeToLevelText(context)
        self.RateText:SetShown(showTimeToLevel)
    end
end

--- Scale center text elements proportionally with the ring size.
--- Called from RepositionSegments when layout changes.
function CircularBarStyleTemplate:UpdateCenterTextScale()
    local shouldScale = Config and Config.GetOptionValue and Config:GetOptionValue("circularScaleCenterText")
    local scale = shouldScale and self:GetCircularScale() or 1.0

    local elements = {
        {elem = self.LevelText,   baseY = 15},
        {elem = self.PercentText, baseY = -5},
        {elem = self.RateText,    baseY = -25},
    }

    for _, info in ipairs(elements) do
        local element = info.elem
        if element then
            if not element._baseFontFile then
                local fontFile, fontSize, fontFlags = element:GetFont()
                element._baseFontFile = fontFile
                element._baseFontSize = fontSize
                element._baseFontFlags = fontFlags or ""
            end
            element:SetFont(element._baseFontFile, element._baseFontSize * scale, element._baseFontFlags)
            element:ClearAllPoints()
            element:SetPoint("CENTER", self, "CENTER", 0, info.baseY * scale)
        end
    end
end

--- Override text update methods to match v1 circular format (simple values, not full formatted text)
function CircularBarStyleTemplate:UpdateLevelText(context)
    if not self.LevelText then
        return
    end

    -- v1 shows just the level number, not "Level XX"
    local level = (context and context.level) or UnitLevel("player")
    self.LevelText:SetText(tostring(level))
end

function CircularBarStyleTemplate:UpdatePercentText(context)
    if not self.PercentText or not context or not Addon.TextFormatter then
        return
    end

    -- shows simple percentage like "45.2%" without quest XP additions
    local maxv = context.xpMax or 1
    local current = context.currentXP or 0
    if Addon.TextFormatter then
        -- Context first (already profile-resolved), then profile-aware Config fallback
        local decimals = (context and context.percentDecimals) or
            (Addon and Addon.Config and Addon.Config.GetOptionValue and Addon.Config:GetOptionValue("percentDecimals")) or 1

        -- Use simple percent formatting (no quest additions).
        -- string.format + SetText ran every animation frame while the rounded
        -- value only changes a handful of times across a fill; cache and compare.
        -- Safe because this override is the only writer of circular's PercentText.
        local percent = (maxv > 0) and (current / maxv * 100) or 0
        local text = string.format("%." .. decimals .. "f%%", percent)
        if text ~= self._lastPercentText then
            self._lastPercentText = text
            self.PercentText:SetText(text)
        end
    end
end

function CircularBarStyleTemplate:UpdateRateText(context)
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

--- Override bar color update (handled in UpdateSegmentColors)
function CircularBarStyleTemplate:UpdateBarColors(context, barName)
    -- Colors are now applied in UpdateSegmentColors during SetArcProgress
    -- This is kept for compatibility but does nothing
end

-------------------------------------------------------------------
-- CIRCULAR REPUTATION INTEGRATION
-- Mouse events belong to the XP bar frame; the circular reputation overlay
-- is mouse-passthrough (enableMouse=false). The XP bar surfaces reputation
-- data in its own tooltip and handles reputation click actions.
-------------------------------------------------------------------

local function GetReputationContext()
    if Addon.ReputationSession and Addon.ReputationSession.GetCurrentContext then
        local ctx = Addon.ReputationSession:GetCurrentContext()
        if ctx and ctx.isAvailable then
            return ctx
        end
    end
    return nil
end

local function IsReputationSecondaryActive()
    if not Addon.SecondaryBarManager or Addon.SecondaryBarManager._currentStyle ~= "circular" then
        return false
    end

    local secondaryFrame = Addon.SecondaryBarManager:GetCurrentFrame()
    if not secondaryFrame then
        return false
    end

    if secondaryFrame.IsDetachedInteractionEnabled and secondaryFrame:IsDetachedInteractionEnabled() then
        return false
    end

    return true
end

local function OpenReputationPanel()
    if ToggleCharacter then
        ToggleCharacter("ReputationFrame")
    end
end

--- Append reputation section to the in-progress GameTooltip.
--- Called after the XP tooltip has already been opened and populated.
function CircularBarStyleTemplate:AppendReputationToTooltip()
    local repCtx = GetReputationContext()
    if not repCtx then
        return
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(repCtx.name or "", 1, 0.82, 0)

    if repCtx.isCompanion and repCtx.currentLevel and repCtx.currentLevel > 0 then
        GameTooltip:AddLine(string.format("Level: %d", repCtx.currentLevel), 0.7, 0.7, 0.7)
    elseif repCtx.standingLabel and repCtx.standingLabel ~= "" then
        GameTooltip:AddLine(repCtx.standingLabel, 0.7, 0.7, 0.7)
    end

    local StyleHelpers = Addon.UI.StyleHelpers
    GameTooltip:AddLine(
        string.format("Rep: %s", StyleHelpers.BuildTooltipProgressText(repCtx)),
        0.7, 1, 0.7
    )

    local fmt = Addon.TextFormatter
    if not repCtx.isMaxed and fmt then
        local cur = fmt:FormatNumber(repCtx.current or 0, false)
        local max = fmt:FormatNumber(repCtx.max or 0, false)
        GameTooltip:AddDoubleLine("Current:", cur .. " / " .. max, 0.7, 0.7, 0.7, 0.7, 0.9, 1)
    end
    if repCtx.sessionGained and repCtx.sessionGained > 0 and fmt then
        GameTooltip:AddDoubleLine("Gained:", "+" .. fmt:FormatNumber(repCtx.sessionGained, false), 0.7, 0.7, 0.7, 0.5, 1, 0.5)
    end
    if repCtx.repPerHour and repCtx.repPerHour > 0 and fmt then
        GameTooltip:AddDoubleLine("Rate:", fmt:FormatNumber(repCtx.repPerHour, false) .. "/hr", 0.7, 0.7, 0.7, 0.5, 0.8, 1)
    end
    if repCtx.timeToNextLevel and repCtx.timeToNextLevel > 0 and fmt then
        GameTooltip:AddDoubleLine("Next:", fmt:FormatTime(repCtx.timeToNextLevel, true), 0.7, 0.7, 0.7, 0.8, 0.8, 0.5)
    end
end

--- Override OnEnter: show XP tooltip then append reputation section.
function CircularBarStyleTemplate:OnEnter()
    -- Base tooltip (XP data, session, hints)
    XPBarTooltipMixin.OnEnter(self)

    -- Append reputation section if the circular secondary bar is active
    if not IsReputationSecondaryActive() then
        return
    end

    self:AppendReputationToTooltip()
    GameTooltip:Show()
end

--- Override OnRightClick: open Reputation panel when secondary bar is active.
function CircularBarStyleTemplate:OnRightClick()
    if IsReputationSecondaryActive() then
        OpenReputationPanel()
    end
end

--- Override GetHintText: add reputation hints when the secondary bar is active.
function CircularBarStyleTemplate:GetHintText()
    local L = XPBarEnhanced and XPBarEnhanced.L or {}

    local isDraggable = false
    if self.GetPositionMode then
        isDraggable = self:GetPositionMode() == "DRAGGABLE"
    end

    local hints = {}
    if isDraggable then
        table.insert(hints, L["TT_HINT_DRAG"])
    end
    table.insert(hints, L["TT_HINT_ALT_OPTIONS"])
    table.insert(hints, L["TT_HINT_CTRL_STATS"])

    -- Reputation hint: right-click opens the Reputation panel
    if IsReputationSecondaryActive() then
        table.insert(hints, "Right-click: open Reputation")
    end

    return table.concat(hints, "\n")
end

--- Override OnHide to clean up animations
function CircularBarStyleTemplate:OnHide()
    -- Cancel any running per-frame arc animation
    if type(self.GetScript) == "function" and self:GetScript("OnUpdate") then
        self:SetScript("OnUpdate", nil)
    end
    self.isAnimating = false

    -- Call base cleanup
    if XPBarMixinBase and XPBarMixinBase.OnHide then
        XPBarMixinBase.OnHide(self)
    end
end

-------------------------------------------------------------------
-- OVERLAY HELPERS (must be defined before style registration)
-------------------------------------------------------------------

--- Compute overlay segment ranges purely from provided context (no DB fallback, no persistent cache)
-- @param context table: Immutable context with xp/current/rested/quest values and show flags
-- @param totalSegments number: Number of ring segments (RING_SEGMENTS)
-- @param currentXPSegments number: Number of segments filled by current XP
-- @return table { completeCount, completeStart, incompleteCount, incompleteStart, restedCount, restedStart }
function CircularBarStyleTemplate:ComputeOverlaySegments(progress, context, totalSegments)
    totalSegments = totalSegments or self:GetDisplaySegmentCount()

    local currentProgress = math.max(0, math.min(progress or 0, 1))

    local currentXPSegments = self:CountSegmentsToDisplay(currentProgress, totalSegments)
    currentXPSegments = math.max(0, math.min(currentXPSegments, totalSegments))

    local result = {
        currentXPSegments = currentXPSegments,
        completeCount = 0,
        completeStart = currentXPSegments + 1,
        incompleteCount = 0,
        incompleteStart = currentXPSegments + 1,
        restedCount = 0,
        restedStart = currentXPSegments + 1
    }

    if not context then
        error("ComputeOverlaySegments requires an explicit immutable context")
    end

    local xpMax = context.xpMax or 0
    if xpMax <= 0 then
        return result
    end

    local currentXP = context.currentXP or 0
    local remainingXP = math.max(0, xpMax - currentXP)

    -- Quest complete overlay
    local completeXPUsed = 0
    if
        context.showQuestXP and context.showCompleteQuestOverlay and (context.completeQuestXP or 0) > 0 and
            remainingXP > 0
     then
        completeXPUsed = math.min(context.completeQuestXP, remainingXP)
        remainingXP = math.max(0, remainingXP - completeXPUsed)
    end

    local incompleteXPUsed = 0
    if
        context.showQuestXP and context.showIncompleteQuestOverlay and (context.incompleteQuestXP or 0) > 0 and
            remainingXP > 0
     then
        incompleteXPUsed = math.min(context.incompleteQuestXP, remainingXP)
        remainingXP = math.max(0, remainingXP - incompleteXPUsed)
    end

    local restedXPUsed = 0
    if context.showRestedOverlay and (context.restedXP or 0) > 0 and remainingXP > 0 then
        restedXPUsed = math.min(context.restedXP, remainingXP)
        remainingXP = math.max(0, remainingXP - restedXPUsed)
    end

    -- Compute target total filled segments based on combined XP
    local combinedXP = currentXP + completeXPUsed + incompleteXPUsed + restedXPUsed
    local totalFillSegments = self:CountSegmentsToDisplay((combinedXP / xpMax), totalSegments)

    -- Compute initial floor-based counts for overlays (clamped by available slots)
    local slotsRemaining = totalSegments - currentXPSegments

    local completeCount = 0
    if completeXPUsed > 0 and slotsRemaining > 0 then
        completeCount = self:CountSegmentsToDisplay((completeXPUsed / xpMax), totalSegments)
        completeCount = math.max(0, math.min(completeCount, slotsRemaining))
        slotsRemaining = slotsRemaining - completeCount
    end

    local incompleteCount = 0
    if incompleteXPUsed > 0 and slotsRemaining > 0 then
        incompleteCount = self:CountSegmentsToDisplay((incompleteXPUsed / xpMax), totalSegments)
        incompleteCount = math.max(0, math.min(incompleteCount, slotsRemaining))
        slotsRemaining = slotsRemaining - incompleteCount
    end

    local restedCount = 0
    if restedXPUsed > 0 and slotsRemaining > 0 then
        restedCount = self:CountSegmentsToDisplay((restedXPUsed / xpMax), totalSegments)
        restedCount = math.max(0, math.min(restedCount, slotsRemaining))
        slotsRemaining = slotsRemaining - restedCount
    end

    -- If rounding leaves a deficit compared to combined total, distribute deficit deterministically
    local filled = currentXPSegments + completeCount + incompleteCount + restedCount
    if filled < totalFillSegments then
        local deficit = totalFillSegments - filled
        while deficit > 0 and (completeCount + incompleteCount + restedCount + currentXPSegments) < totalSegments do
            -- Allocate to complete first, then incomplete, then rested
            if
                completeXPUsed > 0 and
                    (completeCount < (totalSegments - currentXPSegments - incompleteCount - restedCount))
             then
                completeCount = completeCount + 1
            elseif
                incompleteXPUsed > 0 and
                    (incompleteCount < (totalSegments - currentXPSegments - completeCount - restedCount))
             then
                incompleteCount = incompleteCount + 1
            elseif
                restedXPUsed > 0 and
                    (restedCount < (totalSegments - currentXPSegments - completeCount - incompleteCount))
             then
                restedCount = restedCount + 1
            else
                -- No place to allocate more; break out
                break
            end
            deficit = deficit - 1
        end
    end

    -- Assign results + starts
    result.completeCount = completeCount
    result.completeStart = currentXPSegments + 1

    result.incompleteCount = incompleteCount
    result.incompleteStart = currentXPSegments + 1 + completeCount

    result.restedCount = restedCount
    result.restedStart = currentXPSegments + 1 + completeCount + incompleteCount

    return result
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
    position = {mode = "DRAGGABLE", positionKey = "CircularBar"},
    style = {},
    capabilities = {
        statusBar      = false,
        overlays       = false,
        exhaustionTick = false,
        textBelowBar   = false,
        -- No below-bar row, but UpdateRateText is overridden to show time-to-level
        -- as the third centre row. Without this the ETA only moved when an XP event
        -- arrived, so it froze precisely while the player was standing still.
        timeReadout    = true,
    }
}

-------------------------------------------------------------------
-- STYLE CREATION
-------------------------------------------------------------------

-- Create composed mixin (Base + Behaviors + Style)
CircularBarXPBarMixin = XPBarStyleBuilder:Create(XPBarMixinBase, CircularBarStyleTemplate, DefaultConfig)
XPBarStyleBuilder:RegisterStyle("circular", CircularBarXPBarMixin)
