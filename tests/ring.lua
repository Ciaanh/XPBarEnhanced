-- The Ring style: its geometry (the radial offsets confirmed in game), the frame cutting each
-- layer to its stretch of the arc, and the clients without the radial fill showing Circular
-- while the saved style stays Ring.
local H = dofile((arg[1] or ".") .. "/tests/harness.lua")

local function Near(a, b) return a ~= nil and b ~= nil and math.abs(a - b) < 1e-9 end
local function CheckNear(label, got, expected) H.Check(label, Near(got, expected) and expected or got, expected) end

local function HasStyleOption(Addon, value)
    for _, option in ipairs(Addon.Config:GetOptionDetail("barStyle").options) do
        if option.value == value then return true end
    end
    return false
end

local function ChatHas(text)
    for _, line in ipairs(H.chat) do
        if line:find(text, 1, true) then return true end
    end
    return false
end

--------------------------------------------------------------------------------
H.Section("Geometry")
--------------------------------------------------------------------------------
local Addon = H.Load(nil)
local G = Addon.UI.RingGeometry

local function Settings(values)
    return G.Normalize(function(key) return values[key] end)
end

local defaults = G.Normalize(function(key) return Addon.defaults[key] end)
H.Check("defaults: complete ring", defaults.shape, "full")
H.Check("defaults: inner radius", defaults.innerRadius, 56)
H.Check("defaults: width", defaults.width, 12)
H.Check("defaults: clockwise", defaults.clockwise, true)
CheckNear("defaults: feather", defaults.feather, 0.02)

local odd = Settings({ ringShape = "square", ringGap = "north", ringArcDegrees = 1000, ringInnerRadius = 3,
    ringWidth = "wide", ringFeather = -1, ringTrackAlpha = 2, ringClockwise = false })
H.Check("unknown shape: complete ring", odd.shape, "full")
H.Check("unknown gap: bottom", odd.gap, "bottom")
H.Check("arc degrees clamped", odd.arcDegrees, 350)
H.Check("inner radius clamped", odd.innerRadius, 16)
H.Check("width not a number: default", odd.width, 12)
H.Check("feather clamped", odd.feather, 0)
H.Check("track alpha clamped", odd.trackAlpha, 1)
H.Check("counter-clockwise kept", odd.clockwise, false)
H.Check("pixel sizes rounded", Settings({ ringInnerRadius = 40.6 }).innerRadius, 41)

-- Complete ring: from the top, the end offset (the gap) 0.
local arc = G.Arc(Settings({ ringShape = "full" }))
CheckNear("full ring starts at the top", arc.start, 0.5)
local s, e = G.SpanOffsets(arc, 0, 1)
CheckNear("full ring: start", s, 0.5)
CheckNear("full ring: no gap", e, 0)
H.Check("full ring clockwise: not reversed", arc.reverse, false)
H.Check("full ring counter-clockwise: reversed", G.Arc(Settings({ ringClockwise = false })).reverse, true)

-- 270 degrees open at the bottom: 0.125 / 0.25, as drawn in game.
arc = G.Arc(Settings({ ringShape = "arc", ringArcDegrees = 270, ringGap = "bottom" }))
s, e = G.SpanOffsets(arc, 0, 1)
CheckNear("270 bottom, clockwise: start 0.125", s, 0.125)
CheckNear("270 bottom: gap 0.25", e, 0.25)
s, e = G.SpanOffsets(arc, 0, 0.5)
CheckNear("half the arc: same start", s, 0.125)
CheckNear("half the arc: gap 1 - 0.375", e, 0.625)
s, e = G.SpanOffsets(arc, 0.5, 1)
CheckNear("second half starts at the top", s, 0.5)
CheckNear("second half: gap", e, 0.625)
H.Check("an empty stretch has no offsets", G.SpanOffsets(arc, 0.3, 0.3), nil)

-- Counter-clockwise: reverse, and the start is the arc's other end.
arc = G.Arc(Settings({ ringShape = "arc", ringArcDegrees = 270, ringGap = "bottom", ringClockwise = false }))
s, e = G.SpanOffsets(arc, 0, 1)
CheckNear("270 bottom, counter-clockwise: start 0.875", s, 0.875)
CheckNear("270 bottom, counter-clockwise: gap 0.25", e, 0.25)
H.Check("counter-clockwise: reversed", arc.reverse, true)
s = G.SpanOffsets(arc, 0.5, 1)
CheckNear("counter-clockwise half way: the top", s, 0.5)

-- The opening on each side; offsets wrapped into 0..1 (the client clamps them).
arc = G.Arc(Settings({ ringShape = "arc", ringArcDegrees = 270, ringGap = "right" }))
CheckNear("gap on the right: start 0.875", G.SpanOffsets(arc, 0, 1), 0.875)
arc = G.Arc(Settings({ ringShape = "arc", ringArcDegrees = 270, ringGap = "left", ringClockwise = false }))
CheckNear("gap on the left, counter-clockwise: start 0.125", G.SpanOffsets(arc, 0, 1), 0.125)
arc = G.Arc(Settings({ ringShape = "arc", ringArcDegrees = 180, ringGap = "top" }))
s = G.SpanOffsets(arc, 0, 1)
CheckNear("180 open at the top: starts on the right", s, 0.75)
s = G.SpanOffsets(arc, 0.5, 1)
CheckNear("180 open at the top: half way at the bottom", s, 0)

-- Layers laid out as Circular's segments: XP, completed, incomplete, rested, each after the last.
local context = { currentXP = 4000, xpMax = 10000, completeQuestXP = 1000, incompleteQuestXP = 1500,
    restedXP = 2000, showQuestXP = true, showCompleteQuestOverlay = true, showIncompleteQuestOverlay = true,
    showRestedOverlay = true }
local xpEnd, completeEnd, incompleteEnd, restedEnd = G.LayerEnds(0.4, context)
CheckNear("xp end", xpEnd, 0.4)
CheckNear("completed quests end", completeEnd, 0.5)
CheckNear("incomplete quests end", incompleteEnd, 0.65)
CheckNear("rested end", restedEnd, 0.85)
context.showIncompleteQuestOverlay = false
xpEnd, completeEnd, incompleteEnd, restedEnd = G.LayerEnds(0.4, context)
CheckNear("a hidden layer takes no room", incompleteEnd, 0.5)
CheckNear("rested follows the shown ones", restedEnd, 0.7)
context.restedXP = 9000
xpEnd, completeEnd, incompleteEnd, restedEnd = G.LayerEnds(0.4, context)
CheckNear("clipped to the level's end", restedEnd, 1)
xpEnd, completeEnd, incompleteEnd, restedEnd = G.LayerEnds(0.7, { xpMax = 0 })
CheckNear("no max: the fill alone", restedEnd, 0.7)

-- Sizes: the textures are larger than the discs they hold.
local outer, disc, hole = G.Sizes(Settings({ ringInnerRadius = 56, ringWidth = 12 }))
H.Check("outer radius", outer, 68)
CheckNear("disc texture: 136 px of disc", disc * 254 / 256, 136)
CheckNear("hole texture: 112 px of hole", hole * 126 / 128, 112)

-- Offset angles: 0 at the bottom, 0.25 on the left (counter-clockwise from +x, as cos / sin).
CheckNear("bottom is -90 degrees", G.OffsetAngle(0), math.rad(-90))
local x, y = G.PointOnArc(G.Arc(Settings({})), 0, 10)
CheckNear("a complete ring starts at the top: x", x, 0)
CheckNear("a complete ring starts at the top: y", y, 10)
x, y = G.PointOnArc(G.Arc(Settings({})), 0.25, 10)
CheckNear("a quarter on, clockwise: the right", x, 10)

-- Centre text room.
local scale, percentFits, rateFits = G.CenterText(Settings({ ringInnerRadius = 30 }))
H.Check("inner 30: fixed size", scale, 1)
H.Check("inner 30: percent fits", percentFits, true)
H.Check("inner 30: no room for the rate", rateFits, false)
scale, percentFits = G.CenterText(Settings({ ringInnerRadius = 20 }))
H.Check("inner 20: no room for the percent", percentFits, false)
scale, percentFits, rateFits = G.CenterText(Settings({ ringInnerRadius = 112, ringScaleCenterText = true }))
H.Check("scaled text grows with the ring", scale, 2)
H.Check("scaled text: every line fits", rateFits, true)

-- The secondary ring's band.
local band = G.SecondaryBand(Settings({}))
H.Check("secondary: inside by default", band.placement, "inside")
H.Check("secondary: spacing short of the hole", band.innerRadius + band.width, 52)
H.Check("secondary: its own width", band.width, 6)
band = G.SecondaryBand(Settings({ ringInnerRadius = 16, ringSecondarySpacing = 12 }))
H.Check("secondary: narrows to fit the hole", band.width, 2)
H.Check("secondary: still inside", band.placement, "inside")
band = G.SecondaryBand(Settings({ ringInnerRadius = 16, ringSecondarySpacing = 13 }))
H.Check("secondary: no room inside, goes outside", band.placement, "outside")
H.Check("secondary: outside, spacing beyond the ring", band.innerRadius, 16 + 12 + 13)
band = G.SecondaryBand(Settings({ ringSecondaryPlacement = "outside", ringSecondaryWidth = 10 }))
H.Check("secondary: outside on request", band.innerRadius, 56 + 12 + 4)
H.Check("secondary: outside keeps its width", band.width, 10)
H.Check("unknown placement: inside", Settings({ ringSecondaryPlacement = "above" }).secondaryPlacement, "inside")

-- The centre text gives way to a secondary ring in the hole.
scale, percentFits, rateFits = G.CenterText(Settings({ ringInnerRadius = 48 }), true)
H.Check("inner 48, secondary inside: no room for the rate", rateFits, false)
scale, percentFits, rateFits = G.CenterText(Settings({ ringInnerRadius = 48 }), false)
H.Check("inner 48, no secondary: the rate fits", rateFits, true)
scale, percentFits, rateFits = G.CenterText(Settings({ ringInnerRadius = 48, ringSecondaryPlacement = "outside" }), true)
H.Check("inner 48, secondary outside: the rate fits", rateFits, true)

-- Ticks.
local fractions = {}
H.Check("no ticks by default", G.TickFractions(Settings({}), fractions), 0)
H.Check("an arc in 4 parts: 3 dividers", G.TickFractions(Settings({ ringShape = "arc", ringTicks = 4 }), fractions), 3)
CheckNear("first divider a quarter in", fractions[1], 0.25)
CheckNear("last divider three quarters in", fractions[3], 0.75)
H.Check("a complete ring in 4 parts: 4 dividers", G.TickFractions(Settings({ ringTicks = 4 }), fractions), 4)
CheckNear("one on the seam", fractions[1], 0)
H.Check("back to none clears the list", (G.TickFractions(Settings({}), fractions)) == 0 and #fractions, 0)
H.Check("unknown tick count: none", Settings({ ringTicks = 7 }).ticks, 0)
H.Check("tick count from a string", Settings({ ringTicks = "10" }).ticks, 10)

-- Round caps.
H.Check("no caps on a complete ring", G.HasCaps(Settings({ ringRoundCaps = true })), false)
H.Check("caps on an arc", G.HasCaps(Settings({ ringShape = "arc", ringRoundCaps = true })), true)
local overshoot = G.CapOvershoot(Settings({}))
CheckNear("a cap reaches half the width past the end", overshoot, 6 / (2 * math.pi * 62))
local capped = G.Arc(Settings({ ringShape = "arc", ringArcDegrees = 350, ringRoundCaps = true }))
CheckNear("350 with caps: shortened to keep a gap", capped.sweep, 1 - 2 * overshoot - 2 / 360)
capped = G.Arc(Settings({ ringShape = "arc", ringArcDegrees = 270, ringRoundCaps = true }))
CheckNear("270 with caps: unchanged", capped.sweep, 0.75)

-- A small thin ring with a thicker secondary inside: the secondary's caps reach
-- further than the primary's, and the shared arc leaves room for them.
local small = Settings({ ringShape = "arc", ringArcDegrees = 350, ringRoundCaps = true, ringInnerRadius = 16,
    ringWidth = 2, ringSecondaryWidth = 6, ringSecondarySpacing = 0 })
local secondaryOvershoot = G.CapOvershoot(G.SecondaryBand(small))
H.Check("secondary caps reach further than the primary's", secondaryOvershoot > G.CapOvershoot(small), true)
CheckNear("the gap is sized for the secondary's caps", G.Arc(small).sweep, 1 - 2 * secondaryOvershoot - 2 / 360)
-- 270 open at the bottom, clockwise: the start is at the bottom left (-135) and its
-- cap faces into the gap, down-right (-45); the end at the bottom right (-45) faces
-- down-left (-135). Angles compared modulo a turn.
local function Turn(angle) return angle % (2 * math.pi) end
CheckNear("start cap faces the gap", Turn(G.CapAngle(capped, 0)), Turn(math.rad(-45)))
CheckNear("end cap faces the gap", Turn(G.CapAngle(capped, 1)), Turn(math.rad(-135)))
local ccw = G.Arc(Settings({ ringShape = "arc", ringClockwise = false }))
CheckNear("counter-clockwise: the start at the bottom right faces the gap", Turn(G.CapAngle(ccw, 0)), Turn(math.rad(-135)))
CheckNear("counter-clockwise: the end at the bottom left faces the gap", Turn(G.CapAngle(ccw, 1)), Turn(math.rad(-45)))

local first, last = G.CapLayers(0.4, 0.5, 0.5, 0.7)
H.Check("start cap: the XP's colour", first, 1)
H.Check("end cap: the track until the end is reached", last, nil)
first, last = G.CapLayers(0, 0.1, 0.1, 0.1)
H.Check("no XP: the completed quests' colour", first, 2)
first, last = G.CapLayers(0, 0, 0, 0)
H.Check("empty: the track at both ends", first == nil and last == nil, true)
first, last = G.CapLayers(0.4, 0.5, 0.5, 1)
H.Check("rested reaching the end colours the end cap", last, 4)
first, last = G.CapLayers(1, 1, 1, 1)
H.Check("a full XP fill colours both caps", first == 1 and last == 1, true)
H.CheckNoErrors("no error in the geometry")

--------------------------------------------------------------------------------
H.Section("Retail 12.1: Ring drawn")
--------------------------------------------------------------------------------
H.LoadXMLScripts()
H.Check("radial fill detected", Addon:IsFeatureEnabled("nativeRadial"), true)
H.Check("Ring offered", HasStyleOption(Addon, "ring"), true)
H.Check("ring resolves to itself", Addon.BarManager:ResolveStyleKey("ring"), "ring")
H.Check("ring not substituted", Addon.BarManager:IsStyleSubstituted("ring"), false)

-- A Ring frame, its textures recording the radial calls.
local frame = CreateFrame("Frame")
Mixin(frame, RingBarXPBarMixin)
frame.LevelText = frame:CreateFontString()
frame.PercentText = frame:CreateFontString()
frame.RateText = frame:CreateFontString()
local realCreateTexture = frame.CreateTexture
function frame:CreateTexture(...)
    local texture = realCreateTexture(self, ...)
    texture.radial = {}
    for _, name in ipairs({ "Start", "End", "Feather", "Reverse", "Percent" }) do
        texture["SetRadialProgressBar" .. (name == "Start" and "StartOffset" or name == "End" and "EndOffset" or name)] =
            function(t, value) t.radial[name] = value end
    end
    function texture:SetVertexColor(r, g, b, a) self.color = { r, g, b, a } end
    return texture
end
frame:OnLoad()
H.CheckNoErrors("the Ring frame builds")

H.Check("frame is the outer diameter", frame.width, 136)
CheckNear("track: the whole ring, from the top", frame.Track.radial.Start, 0.5)
CheckNear("track: no gap", frame.Track.radial.End, 0)
CheckNear("track opacity", frame.Track.alpha, 0.35)
H.Check("every layer cut by the hole", frame.Hole ~= nil, true)

context = { currentXP = 4000, xpMax = 10000, completeQuestXP = 1000, incompleteQuestXP = 0,
    restedXP = 2000, showQuestXP = true, showCompleteQuestOverlay = true, showIncompleteQuestOverlay = true,
    showRestedOverlay = true, hasRestedXP = true }
frame:SetArcProgress(0.4, context)
CheckNear("XP fill: from the top", frame.Fill.radial.Start, 0.5)
CheckNear("XP fill: 40 %", frame.Fill.radial.End, 0.6)
CheckNear("completed quests: after the XP", frame.QuestComplete.radial.Start, 0.9)
CheckNear("completed quests: 10 %", frame.QuestComplete.radial.End, 0.9)
H.Check("no incomplete quest XP: hidden", frame.QuestIncomplete.shown, false)
CheckNear("rested: after the quests", frame.Rested.radial.Start, 0)
CheckNear("rested: 20 %", frame.Rested.radial.End, 0.8)
CheckNear("only the tip is softened", frame.Rested.radial.Feather, 0.02)
H.Check("no softening between layers", frame.Fill.radial.Feather, 0)
local xpColor = Addon.Colors:Get(Addon.Colors.Key.XpBarRested)
H.Check("XP fill coloured", frame.Fill.color and Near(frame.Fill.color[1], xpColor.r), true)

-- The arc, counter-clockwise, as the options set it.
Addon.Config:SetOptionKey("ringShape", "arc")
Addon.Config:SetOptionKey("ringClockwise", false)
Addon.Config:SetOptionKey("ringInnerRadius", 30)
H.Check("shape stored as a string", Addon.Config:GetOptionValue("ringShape"), "arc")
frame:RelayoutRing()
frame:SetArcProgress(0.5, { currentXP = 5000, xpMax = 10000 })
H.Check("frame follows the inner radius", frame.width, 84)
CheckNear("track: 270 open at the bottom, counter-clockwise", frame.Track.radial.Start, 0.875)
CheckNear("track: gap", frame.Track.radial.End, 0.25)
H.Check("every layer reversed", frame.Fill.radial.Reverse, true)
CheckNear("XP fill: half the arc from its start", frame.Fill.radial.End, 0.625)
H.Check("the overlays are gone", frame.QuestComplete.shown or frame.Rested.shown, false)
frame:SetArcProgress(1, { currentXP = 10000, xpMax = 10000 })
H.Check("a full arc has nothing to soften", frame.Fill.radial.Feather, 0)

frame:UpdateTextVisibility({})
H.Check("inner 30: no room for the rate line", frame.RateText.shown, false)

-- Spark, ticks and round caps.
frame:SetArcProgress(0.5, { currentXP = 5000, xpMax = 10000 })
H.Check("spark on the tip", frame.Spark.shown, true)
frame:SetArcProgress(0, { currentXP = 0, xpMax = 10000 })
H.Check("no spark on an empty ring", frame.Spark.shown, false)
frame:SetArcProgress(1, { currentXP = 10000, xpMax = 10000 })
H.Check("no spark on a full ring", frame.Spark.shown, false)
Addon.Config:SetOptionKey("ringSpark", false)
frame:RelayoutRing()
frame:SetArcProgress(0.5, { currentXP = 5000, xpMax = 10000 })
H.Check("spark off", frame.Spark.shown, false)

Addon.Config:SetOptionKey("ringTicks", 4)
Addon.Config:SetOptionKey("ringRoundCaps", true)
frame:RelayoutRing()
local function ShownTicks()
    local count = 0
    for _, tick in ipairs(frame.ticks) do
        if tick.shown then count = count + 1 end
    end
    return count
end
H.Check("an arc in 4 parts: 3 ticks", ShownTicks(), 3)
H.Check("caps on an arc", frame.StartCap.shown and frame.EndCap.shown, true)
frame:SetArcProgress(0.5, { currentXP = 5000, xpMax = 10000 })
local fillColor = Addon.Colors:Get(Addon.Colors.Key.XpBar)
H.Check("start cap: the XP's colour", frame.StartCap.color and Near(frame.StartCap.color[1], fillColor.r), true)
H.Check("end cap: the track's colour", frame.EndCap.color and Near(frame.EndCap.color[1], 0.1), true)
CheckNear("end cap: the track's opacity", frame.EndCap.color and frame.EndCap.color[4], 0.35)

-- A colour changed in the options: Config:SetColor edits the stored table in place, and
-- RenderBar rebuilds the render colours. The caps used to keep the old colour.
Addon.Config:SetColor(Addon.Colors.Key.XpBar, "336699", true)
frame._renderColors = nil -- what RenderBar does on entry
frame:SetArcProgress(0.5, { currentXP = 5000, xpMax = 10000 })
CheckNear("start cap follows a colour change", frame.StartCap.color and frame.StartCap.color[1], 0x33 / 255)
CheckNear("the fill follows it too", frame.Fill.color and frame.Fill.color[1], 0x33 / 255)
frame:SetArcProgress(0.5, { currentXP = 5000, xpMax = 10000 })
CheckNear("an animation frame keeps it", frame.StartCap.color and frame.StartCap.color[1], 0x33 / 255)

Addon.Config:SetOptionKey("ringTicks", 0)
Addon.Config:SetOptionKey("ringShape", "full")
frame:RelayoutRing()
H.Check("ticks off: all hidden", ShownTicks(), 0)
H.Check("no caps on a complete ring", frame.StartCap.shown or frame.EndCap.shown, false)
Addon.Config:SetOptionKey("ringShape", "arc")
Addon.Config:SetOptionKey("ringRoundCaps", false)
Addon.Config:SetOptionKey("ringSpark", true)
frame:RelayoutRing()
H.CheckNoErrors("no error drawing the ring")

-- The style gallery: Ring has no premade cell, its swatch cuts an arc live.
local realCreateFrame = CreateFrame
local ringSwatch
CreateFrame = function(kind, name, parent, template)
    local created = realCreateFrame(kind, name, parent, template)
    if template == "ConfigStyleSwatchTemplate" then
        created.Caption = created:CreateFontString()
        for _, edge in ipairs({ "RingTop", "RingBottom", "RingLeft", "RingRight" }) do
            created[edge] = created:CreateTexture()
        end
        created.Preview = realCreateFrame("Frame", nil, created)
        created.Preview.textures = {}
        local previewCreateTexture = created.Preview.CreateTexture
        function created.Preview:CreateTexture(...)
            local texture = previewCreateTexture(self, ...)
            texture.radial = {}
            texture.SetRadialProgressBarStartOffset = function(t, value) t.radial.Start = value end
            texture.SetRadialProgressBarEndOffset = function(t, value) t.radial.End = value end
            function texture:SetVertexColor(r, g, b, a) self.color = { r, g, b, a } end
            self.textures[#self.textures + 1] = texture
            return texture
        end
    end
    return created
end
local galleryRow = realCreateFrame("Frame")
galleryRow.Grid = realCreateFrame("Frame", nil, galleryRow)
Addon.StyleGallery:Build(galleryRow, function() end)
CreateFrame = realCreateFrame
for _, swatch in ipairs(galleryRow.__swatches or {}) do
    if swatch.styleValue == "ring" then
        ringSwatch = swatch
    end
end
H.Check("gallery has a Ring swatch", ringSwatch ~= nil, true)
local track, fill = ringSwatch.Preview.textures[1], ringSwatch.Preview.textures[2]
CheckNear("swatch track: 270 open at the bottom", track.radial.Start, 0.125)
CheckNear("swatch track: gap", track.radial.End, 0.25)
CheckNear("swatch fill: from the track's start", fill.radial.Start, 0.125)
CheckNear("swatch fill: 60 % of the arc", fill.radial.End, 1 - 0.6 * 0.75)
local barColor = Addon.Colors:Get(Addon.Colors.Key.XpBar)
H.Check("swatch fill takes the bar colour", fill.color and Near(fill.color[1], barColor.r), true)
H.CheckNoErrors("no error building the gallery")

-- The panel's Ring rows: every ordered key has its XML row, "Ring only" under another
-- style, and the arc rows greyed on a complete ring.
local panelFile = assert(io.open(H.ROOT .. "/ui/options/OptionsPanel.xml"))
local panelXML = panelFile:read("*a")
panelFile:close()
local ringRows = 0
for _, key in ipairs(Addon.Config.optionOrder) do
    if key:match("^ring") then
        ringRows = ringRows + 1
        H.Check("panel row for " .. key, panelXML:find('value="' .. key .. '"', 1, true) ~= nil, true)
    end
end
H.Check("every Ring option is in the panel", ringRows, 15)

local rows = {}
local panelStub = {}
function panelStub:SetRowAvailability(key, available, note) rows[key] = { available = available, note = note } end
Addon.Config:SetOptionKey("ringShape", "full")
XPBarEnhancedOptionsMixin.RefreshRowAvailability(panelStub, "ring")
H.Check("Ring rows open under Ring", rows.ringWidth.available, true)
H.Check("arc length greyed on a complete ring", rows.ringArcDegrees.available, false)
H.Check("opening greyed on a complete ring", rows.ringGap.available, false)
H.Check("rounded ends greyed on a complete ring", rows.ringRoundCaps.available, false)
H.Check("with the arc note", rows.ringGap.note, Addon.L["OPT_UNAVAIL_ARC_ONLY"])
Addon.Config:SetOptionKey("ringShape", "arc")
XPBarEnhancedOptionsMixin.RefreshRowAvailability(panelStub, "ring")
H.Check("arc rows open on an arc", rows.ringArcDegrees.available and rows.ringGap.available, true)
XPBarEnhancedOptionsMixin.RefreshRowAvailability(panelStub, "circular")
H.Check("Ring rows greyed under another style", rows.ringWidth.available, false)
H.CheckNoErrors("no error refreshing the panel rows")

-- The secondary ring: SecondaryBarManager picks Ring's template under Ring. The harness
-- cannot build the primary from its template, so the primary's rebuild is stubbed.
local realSetStyle = Addon.BarManager.SetStyle
Addon.BarManager.SetStyle = function() end
Addon.Config:SetOptionKey("showSecondaryBar", true)
Addon.Config:SetOptionKey("barStyle", "ring")
Addon.SecondaryBarManager:RefreshForPrimaryStyleChange()
Addon.BarManager.SetStyle = realSetStyle
H.Check("secondary bar follows Ring", Addon.SecondaryBarManager._currentStyle, "ring")

-- Its frame: one band on the primary's arc, here a 270 arc open at the bottom,
-- counter-clockwise, inner radius 30 (set above), so the band sits at 20..26.
local secondary = CreateFrame("Frame")
Mixin(secondary, XPBarRingReputationMixin)
local secondaryCreateTexture = secondary.CreateTexture
function secondary:CreateTexture(...)
    local texture = secondaryCreateTexture(self, ...)
    texture.radial = {}
    texture.SetRadialProgressBarStartOffset = function(t, value) t.radial.Start = value end
    texture.SetRadialProgressBarEndOffset = function(t, value) t.radial.End = value end
    texture.SetRadialProgressBarReverse = function(t, value) t.radial.Reverse = value end
    function texture:SetVertexColor(r, g, b, a) self.color = { r, g, b, a } end
    return texture
end
secondary:OnLoad()
H.CheckNoErrors("the secondary ring builds")
H.Check("secondary: sized to its band", secondary.width, 52)
H.Check("secondary: inside the primary", secondary.ringBand.placement, "inside")
CheckNear("secondary track: the primary's arc", secondary.Track.radial.Start, 0.875)
H.Check("secondary: same direction", secondary.Fill.radial.Reverse, true)
H.Check("secondary: starts attached", secondary._detachedInteractionEnabled, false)

secondary:Render({ isAvailable = true, percent = 50, factionType = "honor" })
CheckNear("secondary fill: half the arc", secondary.Fill.radial.End, 1 - 0.5 * 0.75)
H.Check("secondary fill shown", secondary.Fill.shown, true)
local honor = Addon.UI.StyleHelpers.GetFactionColor({ factionType = "honor" })
H.Check("secondary fill: the source's colour", secondary.Fill.color and Near(secondary.Fill.color[1], honor.r), true)
secondary:Render({ isAvailable = true, percent = 0 })
H.Check("secondary fill: empty hides it", secondary.Fill.shown, false)

Addon.Config:SetOptionKey("ringSecondaryPlacement", "outside")
secondary:RelayoutRing()
H.Check("secondary: outside, around the primary", secondary.width, 2 * (30 + 12 + 4 + 6))
H.CheckNoErrors("no error drawing the secondary ring")

-- Attached, the secondary ring takes no mouse: the primary's right-click opens
-- its source's panel and its hints say so, as under Circular. Detached, the
-- secondary ring handles its own clicks and the primary's right-click does nothing.
local shared = Addon.UI.SharedStyleHelpers
local realOpen, realCurrentFrame = shared.OpenReputationPanel, Addon.SecondaryBarManager.GetCurrentFrame
local opened = 0
shared.OpenReputationPanel = function() opened = opened + 1 end
Addon.SecondaryBarManager.GetCurrentFrame = function() return secondary end
local primaryStub = Mixin({}, RingBarXPBarMixin)
primaryStub.GetPositionMode = function() return "DRAGGABLE" end

primaryStub:OnRightClick()
H.Check("attached: right-click opens the source's panel", opened, 1)
H.Check("attached: the hints offer it",
    primaryStub:GetHintText():find(shared.GetOpenPanelHint(), 1, true) ~= nil, true)
H.Check("attached: the tooltip is Circular's, with the source",
    RingBarXPBarMixin.OnEnter, CircularBarXPBarMixin.OnEnter)

secondary:SetDetachedInteractionEnabled(true)
primaryStub:OnRightClick()
H.Check("detached: the primary's right-click does nothing", opened, 1)
secondary:SetDetachedInteractionEnabled(false)

shared.OpenReputationPanel, Addon.SecondaryBarManager.GetCurrentFrame = realOpen, realCurrentFrame
H.CheckNoErrors("no error from the attached secondary's integration")

--------------------------------------------------------------------------------
H.Section("Retail 12.0: no radial fill, Circular shown")
--------------------------------------------------------------------------------
H.ResetUI()
H.interface = 120007
H.missingMethods.SetRadialProgressBarPercent = true
Addon = H.Load({ barStyle = "ring" })
H.LoadXMLScripts()
H.Check("radial fill missing", Addon:IsFeatureEnabled("nativeRadial"), false)
H.Check("Ring not offered", HasStyleOption(Addon, "ring"), false)
H.Check("ring shown as Circular", Addon.BarManager:ResolveStyleKey("ring"), "circular")
H.Check("other styles untouched", Addon.BarManager:ResolveStyleKey("orb"), "orb")

-- Initialize repairs a style it cannot resolve, but not a substituted one.
local shown
Addon.BarManager.SetStyle = function(_, style) shown = style end
Addon.BarManager:Initialize()
H.Check("Circular drawn", shown, "circular")
H.Check("the saved style stays Ring", Addon.Config:GetOptionValue("barStyle"), "ring")

SlashCmdList["XPBARENHANCED"]("style ring")
H.Check("/xpbe style ring explains why", ChatHas("not available on this client"), true)
H.Check("/xpbe style ring changes nothing", Addon.Config:GetOptionValue("barStyle"), "ring")

Addon.Config:SetOptionKey("showSecondaryBar", true)
Addon.SecondaryBarManager:RefreshForPrimaryStyleChange()
H.Check("secondary bar: Circular's", Addon.SecondaryBarManager._currentStyle, "circular")
H.CheckNoErrors("no error without the radial fill")

--------------------------------------------------------------------------------
H.Section("Classic Era: Circular shown")
--------------------------------------------------------------------------------
H.ResetUI()
H.interface = 11508
H.missingMethods.SetRadialProgressBarPercent = nil
Addon = H.Load({ barStyle = "ring" })
H.LoadXMLScripts()
H.Check("not offered on a Classic flavor", Addon:IsFeatureEnabled("nativeRadial"), false)
H.Check("ring shown as Circular", Addon.BarManager:ResolveStyleKey("ring"), "circular")
H.CheckNoErrors("no error on Classic Era")

H.Done()
