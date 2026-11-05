-- XP Bar Enhanced - Ring Style
-- A complete ring or an arc drawn with the client's native radial fill
-- (Retail 12.1+, Forever): one texture per layer, each cut to its own stretch of
-- the arc, all shaped into a band by one shared hole mask. Integrates with
-- AnimationManager through SetArcProgress, like Circular.

-------------------------------------------------------------------
-- DEPENDENCIES
-------------------------------------------------------------------

if not XPBarStyleBuilder or not XPBarMixinBase or not CircularBarXPBarMixin then
    error(
        "RingBarStyle: core (StyleBuilder/BaseMixin) or the Circular style not loaded. Ensure they are earlier in the .toc."
    )
end

local Addon = XPBarEnhanced
local Config = Addon.Config
local Geometry = Addon.UI and Addon.UI.RingGeometry
if not Geometry then
    error("RingBarStyle: RingGeometry not loaded. Ensure ui\\styles\\ring\\RingGeometry.lua is earlier in the .toc.")
end

-------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------

local DISC_TEXTURE = Geometry.DISC_TEXTURE
local HOLE_TEXTURE = Geometry.HOLE_TEXTURE

local TRACK_COLOR = {r = 0.1, g = 0.1, b = 0.1}

-- Fill layers, bottom to top, and the render colour each takes. Each one draws
-- only its own stretch of the arc, so none shows through another.
local FILL_LAYERS = {
    {key = "Rested", subLevel = 1, color = "rested"},
    {key = "QuestIncomplete", subLevel = 2, color = "questIncomplete"},
    {key = "QuestComplete", subLevel = 3, color = "questComplete"},
    {key = "Fill", subLevel = 4, color = "currentXP"},
}

-- The render colour of each layer in arc order (Geometry.CapLayers' indices).
local ARC_COLOR_KEYS = {"currentXP", "questComplete", "questIncomplete", "rested"}

-- Centre text rows: their offset from the centre at the reference size.
local CENTER_TEXT_ROWS = {
    {key = "LevelText", baseY = 15},
    {key = "PercentText", baseY = -5},
    {key = "RateText", baseY = -25},
}

-------------------------------------------------------------------
-- BANDS (shared with RingSecondaryBarStyle.lua)
-------------------------------------------------------------------

-- A band is a frame's hole mask and its radial textures, all cut from the same
-- disc and all centred on the frame. The primary and the secondary ring are
-- each one band.
Addon.UI.RingBand = Addon.UI.RingBand or {}
local RingBand = Addon.UI.RingBand

RingBand.TRACK_COLOR = TRACK_COLOR

--- The track's colour: the Colors tab's Ring track swatch (TRACK_COLOR when
--- unset). Its alpha multiplies the Track opacity option.
function RingBand.TrackColor()
    local Colors = Addon.Colors
    local color = Colors and Colors.Key and Colors.Key.RingTrack and Colors:Get(Colors.Key.RingTrack)
    return (color and color.r) and color or TRACK_COLOR
end

--- Paint the track, and note its colour for the caps and ticks over it. A
--- colour edited in place (Config:SetColor) is the same table with new
--- values, so the values are compared, not the table.
function RingBand.PaintTrack(frame, color)
    local r, g, b, a = color.r, color.g, color.b, color.a or 1
    local painted = frame.trackPainted
    if painted and painted[1] == r and painted[2] == g and painted[3] == b and painted[4] == a then
        return
    end
    frame.trackPainted = {r, g, b, a}
    frame.trackColor = {r = r, g = g, b = b, a = a}
    frame.Track:SetVertexColor(r, g, b, a)
    -- The caps and the ticks over the track take this colour: repaint them.
    frame.capPaintKey = nil
    for _, tick in ipairs(frame.ticks or {}) do
        tick.onFill = nil
    end
end

--- The hole mask every texture of `frame`'s band is cut by.
function RingBand.CreateHole(frame)
    local hole = frame:CreateMaskTexture()
    hole:SetTexture(HOLE_TEXTURE, "CLAMPTOWHITE", "CLAMPTOWHITE")
    hole:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame.Hole = hole
    frame.ringTextures = {}
    return hole
end

--- A texture of the band: the disc source, radial, cut by the hole.
function RingBand.CreateTexture(frame, drawLayer, subLevel)
    local texture = frame:CreateTexture(nil, drawLayer, nil, subLevel)
    texture:SetTexture(DISC_TEXTURE)
    texture:SetPoint("CENTER", frame, "CENTER", 0, 0)
    texture:AddMaskTexture(frame.Hole)
    texture:SetRadialProgressBarPercent(1)
    frame.ringTextures[#frame.ringTextures + 1] = texture
    return texture
end

--- Size the frame, its hole and its textures to `band` on `arc`, and cut the
--- track to the whole arc.
---@param band table {innerRadius, width}
---@return number startOffset, number endOffset The whole arc's offsets
function RingBand.Layout(frame, band, arc, trackAlpha)
    local outer, discSize, holeSize = Geometry.Sizes(band)
    frame:SetSize(2 * outer, 2 * outer)
    frame.Hole:SetSize(holeSize, holeSize)

    for _, texture in ipairs(frame.ringTextures) do
        texture:SetSize(discSize, discSize)
        texture:SetRadialProgressBarReverse(arc.reverse)
        -- The arc changed under every stretch: force the next ApplySpan to re-cut.
        texture.spanFrom = nil
    end

    local startOffset, endOffset = Geometry.SpanOffsets(arc, 0, 1)
    frame.Track:SetRadialProgressBarStartOffset(startOffset)
    frame.Track:SetRadialProgressBarEndOffset(endOffset)
    frame.Track:SetAlpha(trackAlpha)
    return startOffset, endOffset
end

--- Cut a texture to its stretch of the arc, skipping the calls when the
--- stretch has not moved (most animation frames move one layer at most).
function RingBand.ApplySpan(texture, arc, from, to, feather)
    if texture.spanFrom == from and texture.spanTo == to and texture.spanFeather == feather then
        return
    end
    texture.spanFrom, texture.spanTo, texture.spanFeather = from, to, feather

    local startOffset, endOffset = Geometry.SpanOffsets(arc, from, to)
    if not startOffset then
        texture:Hide()
        return
    end
    texture:SetRadialProgressBarStartOffset(startOffset)
    texture:SetRadialProgressBarEndOffset(endOffset)
    texture:SetRadialProgressBarFeather(feather)
    texture:Show()
end

local ApplySpan = RingBand.ApplySpan

-- The spark: Blizzard's cast bar glow, in every client the Ring runs on. Its
-- streak is a narrow column of a square texture, drawn at 2.5 times the bar's
-- height on the cast bar; the same here, across the band.
local SPARK_TEXTURE = "Interface\\CastingBar\\UI-CastingBar-Spark"
local SPARK_SIZE_RATIO = 2.5
local TICK_TEXTURE = "Interface\\Buttons\\WHITE8X8"
local TICK_COLOR = {r = 0, g = 0, b = 0, a = 0.6}
local TICK_THICKNESS = 2

--- A tick over the track: black would vanish on the dark default track, so it
--- contrasts with the track's colour instead, and fades with the track's
--- opacity without disappearing at 0.
---@return number r, number g, number b, number a
function RingBand.TrackTickColor(trackColor, trackAlpha)
    local color = trackColor or TRACK_COLOR
    local luminance = 0.299 * color.r + 0.587 * color.g + 0.114 * color.b
    local a = 0.4 * (0.5 + 0.5 * (trackAlpha or 1))
    if luminance < 0.5 then
        return 1, 1, 1, a
    end
    return 0, 0, 0, TICK_COLOR.a
end

--- Colour each tick for what lies under it: the fill up to fraction
--- `filledTo`, the track beyond. Runs every animation frame: a tick is only
--- repainted when the fill's end crosses it.
function RingBand.PaintTicks(frame, filledTo)
    local count = frame.tickCount or 0
    if count == 0 then
        return
    end
    local fractions = frame.tickFractions
    for index = 1, count do
        local tick = frame.ticks[index]
        local onFill = fractions[index] < filledTo
        if tick.onFill ~= onFill then
            tick.onFill = onFill
            if onFill then
                tick:SetVertexColor(TICK_COLOR.r, TICK_COLOR.g, TICK_COLOR.b, TICK_COLOR.a)
            else
                local trackAlpha = frame.ringSettings and frame.ringSettings.trackAlpha
                tick:SetVertexColor(RingBand.TrackTickColor(frame.trackColor, trackAlpha))
            end
        end
    end
end

local function CreateCap(frame)
    local cap = frame:CreateTexture(nil, "ARTWORK", nil, 5)
    cap:SetTexture(Geometry.CAP_TEXTURE)
    cap:Hide()
    return cap
end

--- The spark at the fill's tip, the tick pool and the two round caps.
function RingBand.CreateExtras(frame)
    local spark = frame:CreateTexture(nil, "OVERLAY", nil, 2)
    spark:SetTexture(SPARK_TEXTURE)
    spark:SetBlendMode("ADD")
    spark:Hide()
    frame.Spark = spark

    -- Created on first use, up to Geometry.MAX_TICKS, and kept.
    frame.ticks = {}
    frame.tickFractions = {}

    frame.StartCap = CreateCap(frame)
    frame.EndCap = CreateCap(frame)
end

--- Place the ticks and caps for `band` on `arc`, and size the spark. Only on a
--- layout change: nothing here moves with the fill.
function RingBand.LayoutExtras(frame, settings, band, arc)
    local mid = Geometry.MidRadius(band)
    frame.ringMid = mid
    frame.sparkAt = nil

    local sparkSize = band.width * SPARK_SIZE_RATIO
    frame.Spark:SetSize(sparkSize, sparkSize)

    local count = Geometry.TickFractions(settings, frame.tickFractions)
    for index = 1, count do
        local tick = frame.ticks[index]
        if not tick then
            tick = frame:CreateTexture(nil, "OVERLAY", nil, 0)
            tick:SetTexture(TICK_TEXTURE)
            frame.ticks[index] = tick
        end
        -- Moved, or the track opacity changed: PaintTicks repaints it.
        tick.onFill = nil
        local x, y, angle = Geometry.PointOnArc(arc, frame.tickFractions[index], mid)
        tick:SetSize(TICK_THICKNESS, band.width)
        tick:ClearAllPoints()
        tick:SetPoint("CENTER", frame, "CENTER", x, y)
        tick:SetRotation(Geometry.RadialRotation(angle))
        tick:Show()
    end
    for index = count + 1, #frame.ticks do
        frame.ticks[index]:Hide()
    end
    frame.tickCount = count

    local caps = Geometry.HasCaps(settings)
    local capSize = band.width * Geometry.CAP_TEXTURE_RATIO
    for p, cap in pairs({[0] = frame.StartCap, [1] = frame.EndCap}) do
        if caps then
            local x, y = Geometry.PointOnArc(arc, p, mid)
            cap:SetSize(capSize, capSize)
            cap:ClearAllPoints()
            cap:SetPoint("CENTER", frame, "CENTER", x, y)
            cap:SetRotation(Geometry.CapAngle(arc, p))
        end
        cap:SetShown(caps)
    end
    -- Force the next PaintCaps to repaint.
    frame.capPaintKey = nil
end

--- Put the spark on the fill's tip at fraction `p`, tinted `color`. Hidden when
--- off, and at 0 and 100 %, where there is no moving tip.
function RingBand.UpdateSpark(frame, enabled, p, color)
    local spark = frame.Spark
    if not enabled or p <= 0 or p >= 1 or not frame.ringArc then
        spark:Hide()
        frame.sparkAt = nil
        return
    end
    if frame.sparkAt ~= p then
        frame.sparkAt = p
        local x, y, angle = Geometry.PointOnArc(frame.ringArc, p, frame.ringMid)
        spark:ClearAllPoints()
        spark:SetPoint("CENTER", frame, "CENTER", x, y)
        spark:SetRotation(Geometry.RadialRotation(angle))
    end
    if color and color.r then
        spark:SetVertexColor(color.r, color.g, color.b, 1)
    end
    spark:Show()
end

--- Paint one cap: a fill colour (with the overlay alpha), or the track's.
local function PaintCap(cap, color, alpha, trackColor, trackAlpha)
    if color and color.r then
        cap:SetVertexColor(color.r, color.g, color.b, (color.a or 1) * alpha)
    else
        local track = trackColor or TRACK_COLOR
        cap:SetVertexColor(track.r, track.g, track.b, (track.a or 1) * trackAlpha)
    end
end

--- Paint the caps. A nil colour is the track.
--- `paintKey` skips the repaint while nothing changed: a table rebuilt whenever
--- the colours may have (the primary's render colours, rebuilt per render).
--- Never the colour tables themselves: Config:SetColor edits those in place,
--- so a changed colour is still the same table. nil repaints every time.
function RingBand.PaintCaps(frame, startColor, endColor, alpha, paintKey)
    if not frame.StartCap:IsShown() then
        return
    end
    -- The track itself fades through SetAlpha; a cap has its own texture, so
    -- the track alpha goes into the cap's vertex alpha instead.
    local trackAlpha = frame.ringSettings and frame.ringSettings.trackAlpha or 1
    local startKey, endKey = startColor or false, endColor or false
    if paintKey ~= nil and frame.capPaintKey == paintKey and frame.capStartColor == startKey
        and frame.capEndColor == endKey and frame.capAlpha == alpha then
        return
    end
    frame.capPaintKey = paintKey
    frame.capStartColor, frame.capEndColor, frame.capAlpha = startKey, endKey, alpha
    PaintCap(frame.StartCap, startColor, alpha, frame.trackColor, trackAlpha)
    PaintCap(frame.EndCap, endColor, alpha, frame.trackColor, trackAlpha)
end

-------------------------------------------------------------------
-- STYLE TEMPLATE
-------------------------------------------------------------------

local RingBarStyleTemplate = {}

-- Ring draws differently from Circular but renders through the same entry
-- points: AnimationManager calls AnimateBarPosition / AnimateBarEffect,
-- RenderBar ends in SetArcProgress, and the centre texts read the same. Those
-- come from Circular rather than being copied, so a fix there reaches both.
-- So does the attached secondary's mouse integration: attached, the secondary
-- ring takes no mouse, so this ring's tooltip carries its source and a
-- right-click opens its panel.
for _, method in ipairs({
    "OnEnter",
    "OnRightClick",
    "GetHintText",
    "AppendSecondaryToTooltip",
    "AnimateBarPosition",
    "AnimateBarEffect",
    "GetCelebrationMask",
    "GetRenderColors",
    "RenderBar",
    "UpdateGainedBar",
    "UpdateRestedBar",
    "UpdateQuestCompleteBar",
    "UpdateQuestIncompleteBar",
    "UpdateVisuals",
    "UpdateLevelText",
    "UpdatePercentText",
    "UpdateRateText",
    "UpdateBarColors",
    "OnHide",
}) do
    RingBarStyleTemplate[method] = CircularBarXPBarMixin[method]
end

local function ReadOption(key)
    return Config and Config.GetOptionValue and Config:GetOptionValue(key)
end

-------------------------------------------------------------------
-- INITIALIZATION
-------------------------------------------------------------------

function RingBarStyleTemplate:OnLoad()
    RingBand.CreateHole(self)

    self.Track = RingBand.CreateTexture(self, "BACKGROUND", 0)
    RingBand.PaintTrack(self, RingBand.TrackColor())

    self.fillLayers = {}
    for index, layer in ipairs(FILL_LAYERS) do
        local texture = RingBand.CreateTexture(self, "ARTWORK", layer.subLevel)
        texture:Hide()
        self[layer.key] = texture
        self.fillLayers[index] = texture
    end

    -- The gain flash lights the band itself, not a square around it. Additive:
    -- at full strength it would wash the band out to white.
    local flash = RingBand.CreateTexture(self, "OVERLAY", 1)
    flash:SetBlendMode("ADD")
    flash:SetVertexColor(1, 1, 1, 0.5)
    flash:SetAlpha(0)
    flash:Hide()
    self.GainFlash = flash

    RingBand.CreateExtras(self)

    self:RelayoutRing()

    -- Call base OnLoad (initializes animation system and calls Refresh)
    if XPBarMixinBase and XPBarMixinBase.OnLoad then
        XPBarMixinBase.OnLoad(self)
    end
end

-------------------------------------------------------------------
-- LAYOUT
-------------------------------------------------------------------

--- Apply the shape and size options. Called on load, by every Ring option and
--- after a profile switch; cheap enough to run while a slider is dragged.
function RingBarStyleTemplate:RelayoutRing()
    local settings = Geometry.Normalize(ReadOption)
    local arc = Geometry.Arc(settings)
    self.ringSettings = settings
    self.ringArc = arc

    local startOffset, endOffset = RingBand.Layout(self, settings, arc, settings.trackAlpha)
    RingBand.LayoutExtras(self, settings, settings, arc)

    -- The flash covers the whole arc.
    self.GainFlash:SetRadialProgressBarStartOffset(startOffset)
    self.GainFlash:SetRadialProgressBarEndOffset(endOffset)

    self:UpdateCenterTextLayout(settings)

    if self.Refresh then
        self:Refresh()
    end
end

--- Whether the secondary ring is in this ring's hole: Ring's own secondary
--- (it has a band), shown, and attached (detached, it is elsewhere).
function RingBarStyleTemplate:HasSecondaryInside()
    local manager = Addon.SecondaryBarManager
    local secondary = manager and manager.GetCurrentFrame and manager:GetCurrentFrame()
    return secondary ~= nil and secondary.ringBand ~= nil and secondary:IsShown()
        and not secondary._detachedInteractionEnabled
end

--- Scale and place the centre text, and note which lines have room.
function RingBarStyleTemplate:UpdateCenterTextLayout(settings)
    local scale, percentFits, rateFits = Geometry.CenterText(settings, self:HasSecondaryInside())
    self.percentTextFits = percentFits
    self.rateTextFits = rateFits

    for _, row in ipairs(CENTER_TEXT_ROWS) do
        local element = self[row.key]
        if element then
            if not element._baseFontSize then
                local fontFile, fontSize, fontFlags = element:GetFont()
                if type(fontSize) == "number" then
                    element._baseFontFile = fontFile
                    element._baseFontSize = fontSize
                    element._baseFontFlags = fontFlags or ""
                end
            end
            if element._baseFontSize then
                element:SetFont(element._baseFontFile, element._baseFontSize * scale, element._baseFontFlags)
            end
            element:ClearAllPoints()
            element:SetPoint("CENTER", self, "CENTER", 0, row.baseY * scale)
        end
    end
end

-------------------------------------------------------------------
-- RENDERING
-------------------------------------------------------------------

--- Only the leading tip is softened: a feathered edge between two layers would
--- leave a dim notch, and at the arc's end (tip = 0) there is nothing to blend.
local function TipFeather(from, to, tipEnd, tip)
    return (to == tipEnd and to > from) and tip or 0
end

--- Set arc progress: each layer's stretch, then its colour.
-- @param progress number: XP fill ratio (0-1)
-- @param context table: Immutable context with all state and flags
-- @param overlayAlpha number: Optional alpha for the filled layers
function RingBarStyleTemplate:SetArcProgress(progress, context, overlayAlpha)
    -- Defensive: if context is nil, return silently rather than raising errors.
    if not context or not self.ringArc then
        return
    end

    local arc = self.ringArc
    local xpEnd, completeEnd, incompleteEnd, restedEnd = Geometry.LayerEnds(progress, context)

    local tip = restedEnd < 1 and self.ringSettings.feather or 0

    ApplySpan(self.Fill, arc, 0, xpEnd, TipFeather(0, xpEnd, restedEnd, tip))
    ApplySpan(self.QuestComplete, arc, xpEnd, completeEnd, TipFeather(xpEnd, completeEnd, restedEnd, tip))
    ApplySpan(self.QuestIncomplete, arc, completeEnd, incompleteEnd, TipFeather(completeEnd, incompleteEnd, restedEnd, tip))
    ApplySpan(self.Rested, arc, incompleteEnd, restedEnd, TipFeather(incompleteEnd, restedEnd, restedEnd, tip))

    local alpha = overlayAlpha or 1
    local colors = self:UpdateLayerColors(context.hasRestedXP == true, alpha, context._secondaryColor)

    RingBand.UpdateSpark(self, self.ringSettings.spark, xpEnd, colors.currentXP)
    RingBand.PaintTicks(self, restedEnd)
    local first, last = Geometry.CapLayers(xpEnd, completeEnd, incompleteEnd, restedEnd)
    RingBand.PaintCaps(self, first and colors[ARC_COLOR_KEYS[first]], last and colors[ARC_COLOR_KEYS[last]], alpha, colors)
end

--- Paint the fill layers, only when the colours or the overlay alpha changed.
---@return table colors The render colours, painted or not
function RingBarStyleTemplate:UpdateLayerColors(hasRestedXP, overlayAlpha, secondaryColor)
    local colors = self:GetRenderColors(hasRestedXP, secondaryColor)
    if colors == self.paintedColors and overlayAlpha == self.paintedAlpha then
        return colors
    end
    self.paintedColors, self.paintedAlpha = colors, overlayAlpha

    -- The colours are rebuilt on every render, a colour change included: the
    -- track's swatch reaches the ring here, before the caps read it.
    RingBand.PaintTrack(self, RingBand.TrackColor())

    for index, layer in ipairs(FILL_LAYERS) do
        local color = colors[layer.color]
        if color and color.r then
            self.fillLayers[index]:SetVertexColor(color.r, color.g, color.b, (color.a or 1) * overlayAlpha)
        end
    end
    return colors
end

--- Text visibility: the options, then whether the line fits inside the ring.
--- Like Circular, not gated by Blizzard's xpBarText CVar: the centre text is
--- the ring's primary readout.
function RingBarStyleTemplate:UpdateTextVisibility(context)
    if self.LevelText then
        self.LevelText:SetShown(Addon.ConfigHelper.GetShowLevelText(context))
    end
    if self.PercentText then
        self.PercentText:SetShown(self.percentTextFits and Addon.ConfigHelper.GetShowPercentage(context))
    end
    if self.RateText then
        self.RateText:SetShown(self.rateTextFits and Addon.ConfigHelper.GetShowTimeToLevelText(context))
    end
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
    position = {mode = "DRAGGABLE", positionKey = Addon.StyleKeys.ring},
    style = {},
    capabilities = {
        statusBar      = false,
        overlays       = false,
        exhaustionTick = false,
        textBelowBar   = false,
        -- Time to level is the third centre row, refreshed while standing still.
        timeReadout    = true,
    }
}

-------------------------------------------------------------------
-- STYLE CREATION
-------------------------------------------------------------------

-- Create composed mixin (Base + Behaviors + Style)
RingBarXPBarMixin = XPBarStyleBuilder:Create(XPBarMixinBase, RingBarStyleTemplate, DefaultConfig)
XPBarStyleBuilder:RegisterStyle(Addon.StyleKeys.ring, RingBarXPBarMixin)
