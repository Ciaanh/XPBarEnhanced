-- XP Bar Enhanced - Ring geometry
-- Pure functions behind the Ring style: settings clamping, the arc's radial
-- offsets, each layer's stretch of the arc and the centre text's room. No frame
-- code, so the suite covers all of it.
--
-- The client's radial fill (Texture:SetRadialProgressBar*), as confirmed in game
-- on Retail 12.1.5:
--   * offsets are fractions of a turn: 0 is the bottom, 0.25 the left, and the
--     fill runs clockwise on screen;
--   * the start offset is where the arc begins, the end offset is the GAP: the
--     arc runs from the start over 1 - end of a turn (0 = a full ring);
--   * both are clamped to 0..1, never wrapped, so they are wrapped here;
--   * reverse runs the arc and the fill counter-clockwise from the start.

local Addon = XPBarEnhanced
Addon.UI = Addon.UI or {}
Addon.UI.RingGeometry = Addon.UI.RingGeometry or {}

local Geometry = Addon.UI.RingGeometry

-------------------------------------------------------------------
-- SETTINGS
-------------------------------------------------------------------

Geometry.SHAPES = {full = true, arc = true}

-- Base offset of each side the arc's opening can face.
Geometry.GAP_OFFSETS = {bottom = 0, left = 0.25, top = 0.5, right = 0.75}

-- Where a complete ring starts: the top, like Blizzard's rings.
Geometry.FULL_RING_START = 0.5

-- Where the secondary ring sits: in the primary's hole, or around it.
Geometry.PLACEMENTS = {inside = true, outside = true}

-- How many equal parts the ticks split the arc into (0 = no ticks; 20 is
-- Blizzard's XP bar bubbles).
Geometry.TICK_COUNTS = {[0] = true, [4] = true, [10] = true, [20] = true}
Geometry.MAX_TICKS = 20

Geometry.LIMITS = {
    arcDegrees = {min = 90, max = 350, default = 270},
    innerRadius = {min = 16, max = 200, default = 56},
    width = {min = 2, max = 64, default = 12},
    feather = {min = 0, max = 0.1, default = 0.02},
    trackAlpha = {min = 0, max = 1, default = 0.35},
    secondaryWidth = {min = 2, max = 64, default = 6},
    secondarySpacing = {min = 0, max = 32, default = 4},
}

local function Clamp(value, limits, integer)
    value = tonumber(value)
    if not value or value ~= value then
        return limits.default
    end
    if integer then
        value = math.floor(value + 0.5)
    end
    return math.max(limits.min, math.min(limits.max, value))
end

--- The Ring settings, clamped to what the style can draw. Saved variables can
--- hold anything (an older version's value, a hand edit), and the options only
--- offer valid ones, so an invalid value falls back rather than erroring.
---@param read fun(key: string): any Option reader (Config:GetOptionValue)
---@return table settings
function Geometry.Normalize(read)
    local LIMITS = Geometry.LIMITS
    local shape = read("ringShape")
    local gap = read("ringGap")
    local placement = read("ringSecondaryPlacement")
    local ticks = tonumber(read("ringTicks"))
    return {
        shape = Geometry.SHAPES[shape] and shape or "full",
        arcDegrees = Clamp(read("ringArcDegrees"), LIMITS.arcDegrees, true),
        gap = Geometry.GAP_OFFSETS[gap] and gap or "bottom",
        innerRadius = Clamp(read("ringInnerRadius"), LIMITS.innerRadius, true),
        width = Clamp(read("ringWidth"), LIMITS.width, true),
        clockwise = read("ringClockwise") ~= false,
        feather = Clamp(read("ringFeather"), LIMITS.feather),
        trackAlpha = Clamp(read("ringTrackAlpha"), LIMITS.trackAlpha),
        scaleCenterText = read("ringScaleCenterText") == true,
        secondaryPlacement = Geometry.PLACEMENTS[placement] and placement or "inside",
        secondaryWidth = Clamp(read("ringSecondaryWidth"), LIMITS.secondaryWidth, true),
        secondarySpacing = Clamp(read("ringSecondarySpacing"), LIMITS.secondarySpacing, true),
        spark = read("ringSpark") ~= false,
        ticks = Geometry.TICK_COUNTS[ticks] and ticks or 0,
        roundCaps = read("ringRoundCaps") == true,
    }
end

-------------------------------------------------------------------
-- ARC
-------------------------------------------------------------------

--- The arc every layer of a ring shares.
---@param settings table From Normalize
---@return table arc {start, sweep (fraction of a turn), dir (+1 clockwise), reverse}
function Geometry.Arc(settings)
    local dir = settings.clockwise and 1 or -1
    if settings.shape ~= "arc" then
        return {start = Geometry.FULL_RING_START, sweep = 1, dir = dir, reverse = dir < 0}
    end

    -- The opening is centred on its side: the arc starts half the gap away
    -- from it, on the side the fill moves away from. Round caps reach past
    -- both ends, so with them the arc shortens until a gap stays open. The
    -- secondary ring shares this arc, and its caps can reach further (a wider
    -- band, or a smaller circle): the gap is sized for the larger of the two.
    local sweep = settings.arcDegrees / 360
    if Geometry.HasCaps(settings) then
        local overshoot = math.max(Geometry.CapOvershoot(settings),
            Geometry.CapOvershoot(Geometry.SecondaryBand(settings)))
        sweep = math.min(sweep, 1 - 2 * overshoot - Geometry.CAP_MIN_GAP)
    end
    local base = Geometry.GAP_OFFSETS[settings.gap] or 0
    return {
        start = (base + dir * (1 - sweep) / 2) % 1,
        sweep = sweep,
        dir = dir,
        reverse = dir < 0,
    }
end

--- Radial offsets of the stretch of the arc from fraction `from` to `to`.
---@param arc table From Arc
---@param from number Fraction of the arc, 0..1
---@param to number Fraction of the arc, 0..1
---@return number|nil startOffset nil when the stretch is empty
---@return number|nil endOffset The gap left by the stretch
function Geometry.SpanOffsets(arc, from, to)
    if not (to > from) then
        return nil, nil
    end
    local startOffset = (arc.start + arc.dir * from * arc.sweep) % 1
    local endOffset = math.max(0, math.min(1, 1 - (to - from) * arc.sweep))
    return startOffset, endOffset
end

--- Where each layer ends along the arc, as Circular lays its segments out:
--- the XP fill from the start, then completed quests, incomplete quests and
--- rested XP, each after the previous one and as long as its XP, all clipped
--- to the level's end.
---@param progress number XP fill ratio (animated), 0..1
---@param context table Bar context (xpMax, currentXP, quest / rested XP, show flags)
---@return number xpEnd, number completeEnd, number incompleteEnd, number restedEnd
function Geometry.LayerEnds(progress, context)
    local xpEnd = math.max(0, math.min(1, tonumber(progress) or 0))
    local xpMax = context and tonumber(context.xpMax) or 0
    if xpMax <= 0 then
        return xpEnd, xpEnd, xpEnd, xpEnd
    end

    local remaining = math.max(0, xpMax - (tonumber(context.currentXP) or 0))
    local function Take(amount, shown)
        amount = shown and tonumber(amount) or 0
        if amount <= 0 or remaining <= 0 then
            return 0
        end
        local used = math.min(amount, remaining)
        remaining = remaining - used
        return used / xpMax
    end

    local quests = context.showQuestXP
    local complete = Take(context.completeQuestXP, quests and context.showCompleteQuestOverlay)
    local incomplete = Take(context.incompleteQuestXP, quests and context.showIncompleteQuestOverlay)
    local rested = Take(context.restedXP, context.showRestedOverlay)

    local completeEnd = math.min(1, xpEnd + complete)
    local incompleteEnd = math.min(1, completeEnd + incomplete)
    local restedEnd = math.min(1, incompleteEnd + rested)
    return xpEnd, completeEnd, incompleteEnd, restedEnd
end

--- Screen angle of a radial offset: radians, counter-clockwise from +x, the
--- convention of cos / sin and of Texture:SetRotation.
---@param offset number
---@return number
function Geometry.OffsetAngle(offset)
    return math.rad(-90 - 360 * offset)
end

--- Point at fraction `p` of the arc, on a circle of `radius` around the centre.
---@return number x, number y Offsets from the ring's centre
---@return number angle Its screen angle
function Geometry.PointOnArc(arc, p, radius)
    local angle = Geometry.OffsetAngle(arc.start + arc.dir * p * arc.sweep)
    return math.cos(angle) * radius, math.sin(angle) * radius, angle
end

--- Rotation laying vertical art (the spark, a tick) across the band at a point
--- of screen angle `angle`: along the radius.
function Geometry.RadialRotation(angle)
    return angle - math.pi / 2
end

--- The circle the band's middle runs along: where the spark, ticks and caps sit.
---@param band table {innerRadius, width}
function Geometry.MidRadius(band)
    return band.innerRadius + band.width / 2
end

-------------------------------------------------------------------
-- TICKS AND CAPS
-------------------------------------------------------------------

--- Fractions of the arc the ticks sit at, written into `out` (reused across
--- layouts). N parts take N - 1 dividers on an arc, and N on a complete ring,
--- one of them on the seam.
---@param out table
---@return integer count
function Geometry.TickFractions(settings, out)
    local parts = settings.ticks
    local count = 0
    if parts > 0 then
        for k = (settings.shape == "arc") and 1 or 0, parts - 1 do
            count = count + 1
            out[count] = k / parts
        end
    end
    for index = #out, count + 1, -1 do
        out[index] = nil
    end
    return count
end

-- The smallest gap round caps leave between them, as a fraction of a turn.
Geometry.CAP_MIN_GAP = 2 / 360

--- Round caps are an arc's: a complete ring has no ends.
function Geometry.HasCaps(settings)
    return settings.roundCaps == true and settings.shape == "arc"
end

--- How far a cap reaches past its end of the arc, as a fraction of a turn: a
--- half-disc of the band's width, on the band's middle circle.
---@param band table {innerRadius, width}
function Geometry.CapOvershoot(band)
    return (band.width / 2) / (2 * math.pi * Geometry.MidRadius(band))
end

--- Screen angle a cap's round side faces: away from the arc, along it.
---@param p number 0 for the start cap, 1 for the end cap
function Geometry.CapAngle(arc, p)
    local angle = Geometry.OffsetAngle(arc.start + arc.dir * p * arc.sweep)
    local outward = (p <= 0) and 1 or -1
    return angle + outward * arc.dir * math.pi / 2
end

--- Which layer each cap takes its colour from, as an index in arc order (1 XP,
--- 2 completed quests, 3 incomplete quests, 4 rested; LayerEnds' order). The
--- start cap takes the first layer with any fill, the end cap the last one
--- when it reaches the end; nil means the track's colour. Runs every
--- animation frame, so no table.
---@return integer|nil startLayer, integer|nil endLayer
function Geometry.CapLayers(xpEnd, completeEnd, incompleteEnd, restedEnd)
    local first, last
    if xpEnd > 0 then
        first, last = 1, 1
    end
    if completeEnd > xpEnd then
        first, last = first or 2, 2
    end
    if incompleteEnd > completeEnd then
        first, last = first or 3, 3
    end
    if restedEnd > incompleteEnd then
        first, last = first or 4, 4
    end
    return first, (restedEnd >= 1) and last or nil
end

-------------------------------------------------------------------
-- SIZES
-------------------------------------------------------------------

-- The art's discs stop short of their texture's edge (room for the anti-aliased
-- rim): assets/ring-disc is 512 px with a 254 px disc, assets/ring-hole 256 px
-- with a 126 px hole, assets/ring-cap 128 px with a half-disc of 62. Sizing
-- each texture by these ratios puts the disc edge
-- exactly on the radius asked for. Kept in step with assets/raw/build_ring_assets.py.
-- The disc is the source every layer is cut from: the radial cut follows the
-- source's texels, so a small one (WHITE8X8) cuts in visible steps. The hole,
-- white around a transparent disc, is the mask that punches the band.
Geometry.DISC_TEXTURE = "Interface\\AddOns\\XPBarEnhanced\\assets\\ring-disc"
Geometry.HOLE_TEXTURE = "Interface\\AddOns\\XPBarEnhanced\\assets\\ring-hole"
Geometry.DISC_TEXTURE_RATIO = 256 / 254
Geometry.HOLE_TEXTURE_RATIO = 128 / 126
-- A round cap: the right half of a disc (radius 62 in 128 px), its flat side
-- on the texture's vertical centre line, so it sits on the arc's cut without
-- overlapping the band (a whole disc would double a translucent track).
Geometry.CAP_TEXTURE = "Interface\\AddOns\\XPBarEnhanced\\assets\\ring-cap"
Geometry.CAP_TEXTURE_RATIO = 64 / 62

---@param band table {innerRadius, width}: the settings, or a SecondaryBand
---@return number outerRadius, number discSize, number holeSize
function Geometry.Sizes(band)
    local outer = band.innerRadius + band.width
    return outer, 2 * outer * Geometry.DISC_TEXTURE_RATIO, 2 * band.innerRadius * Geometry.HOLE_TEXTURE_RATIO
end

-- The narrowest secondary band, and the smallest hole one leaves inside the
-- primary's: below either, an inside band moves outside rather than vanish.
Geometry.MIN_SECONDARY_WIDTH = 2
Geometry.MIN_SECONDARY_HOLE = 2

--- The secondary ring's band, concentric with the primary. Inside, it ends
--- `spacing` short of the primary's hole and narrows to fit what is left;
--- when that is too little, it goes outside, so a small inner radius never
--- hides the bar. Outside, it starts `spacing` beyond the primary's edge.
---@param settings table From Normalize
---@return table band {innerRadius, width, placement}
function Geometry.SecondaryBand(settings)
    local width = settings.secondaryWidth
    local spacing = settings.secondarySpacing
    if settings.secondaryPlacement ~= "outside" then
        local outer = settings.innerRadius - spacing
        local fitted = math.min(width, outer - Geometry.MIN_SECONDARY_HOLE)
        if fitted >= Geometry.MIN_SECONDARY_WIDTH then
            return {innerRadius = outer - fitted, width = fitted, placement = "inside"}
        end
    end
    return {innerRadius = settings.innerRadius + settings.width + spacing, width = width, placement = "outside"}
end

-------------------------------------------------------------------
-- CENTRE TEXT
-------------------------------------------------------------------

-- The default inner radius is the one the centre text is laid out for.
Geometry.TEXT_REFERENCE_RADIUS = 56
-- Below these inner radii the line no longer fits inside the ring.
Geometry.MIN_RADIUS_PERCENT = 24
Geometry.MIN_RADIUS_RATE = 40

--- How the centre text fits: its scale and which lines have room. A scaled text
--- grows with the ring, so every line fits; a fixed one loses its lower lines
--- as the hole shrinks. The room is the primary's hole, or the secondary
--- ring's when that one sits inside it.
---@param secondaryInside boolean The secondary ring is shown in the primary's hole
---@return number scale, boolean percentFits, boolean rateFits
function Geometry.CenterText(settings, secondaryInside)
    local room = settings.innerRadius
    if secondaryInside then
        local band = Geometry.SecondaryBand(settings)
        if band.placement == "inside" then
            room = band.innerRadius
        end
    end
    if settings.scaleCenterText then
        return room / Geometry.TEXT_REFERENCE_RADIUS, true, true
    end
    return 1, room >= Geometry.MIN_RADIUS_PERCENT, room >= Geometry.MIN_RADIUS_RATE
end
