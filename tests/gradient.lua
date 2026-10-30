-- The fill gradient: colours derived from the configured one, the fill and the rested and quest
-- overlays painted as stretches of one gradient across the bar, only for styles that declare the
-- fillGradient capability and only with the option on, and the flat colour back when the option
-- goes off or SetGradient refuses. The bars' XML is not loaded, so a bar is built here from the
-- paint and layout mixins over textures that record what was set on them.
--
-- Whether the engine lets a vertex colour and a gradient replace each other or multiplies them is
-- not known from the sources, so every check runs under both, on what the player would see.
local H = dofile((arg[1] or ".") .. "/tests/harness.lua")

local Addon = H.Load(nil)
H.Login()
local Shared = Addon.UI.SharedStyleHelpers

-- "replace": the last of SetVertexColor / SetGradient wins. "multiply": the two are kept apart
-- and the texture shows their product.
local engine = "replace"

local WHITE = { 1, 1, 1, 1 }

-- A texture starting with vertex colour `initial` (the XML's, e.g. Flat's magenta BarColor).
local function Texture(initial)
    local t = { shown = false, points = {}, vertex = initial or WHITE, gradient = nil }
    function t:SetVertexColor(r, g, b, a)
        self.vertex = { r, g, b, a or 1 }
        if engine == "replace" then self.gradient = nil end
    end
    function t:SetGradient(orientation, from, to)
        if type(from) ~= "table" or type(to) ~= "table" then error("SetGradient takes two colours", 2) end
        -- Copied, as the engine does: the caller may reuse its colour objects.
        self.gradient = { orientation = orientation, from = { from.r, from.g, from.b, from.a },
            to = { to.r, to.g, to.b, to.a } }
        if engine == "replace" then self.vertex = WHITE end
    end
    function t:SetShown(shown) self.shown = shown and true or false end
    function t:Show() self.shown = true end
    function t:Hide() self.shown = false end
    function t:SetWidth(w) self.width = w end
    function t:SetHeight(h) self.height = h end
    function t:ClearAllPoints() self.points = {} end
    function t:SetPoint(...) table.insert(self.points, { ... }) end
    return t
end

-- What the player sees at the texture's two ends: {r, g, b, a} each, and the orientation.
local function Seen(texture)
    local v, g = texture.vertex, texture.gradient
    local function times(a, b) return { a[1] * b[1], a[2] * b[2], a[3] * b[3], a[4] * b[4] } end
    if not g then return v, v, nil end
    return times(v, g.from), times(v, g.to), g.orientation
end

local function StatusBar()
    local fill = Texture({ 0.58, 0, 0.55, 1 })
    local bar = { value = 0, low = 0, high = 1, fill = fill }
    function bar:SetValue(v) self.value = v end
    function bar:GetValue() return self.value end
    function bar:GetMinMaxValues() return self.low, self.high end
    function bar:GetStatusBarTexture() return self.fill end
    function bar:SetStatusBarColor(r, g, b, a) self.fill:SetVertexColor(r, g, b, a) end
    function bar:GetWidth() return 500 end
    function bar:GetHeight() return 20 end
    return bar
end

-- A bar built from the mixins every StatusBar style composes. fillGradient: whether its style
-- declares the capability (Flat, Vertical and Classic do).
-- style: a registered style's mixin, used as it is (its capabilities, orientation and overrides).
local function Bar(fillGradient, orientation, style)
    local frame
    if style then
        frame = Mixin({}, style)
    else
        frame = Mixin({}, XPBarLayoutMixin, XPBarPaintMixin, XPBarDisplayMixin)
        frame.__xpbar_capabilities = { statusBar = true, overlays = true, barColors = true, fillGradient = fillGradient }
        frame.gradientOrientation = orientation
    end
    frame.StatusBar = StatusBar()
    frame.RestedOverlay = Texture()
    frame.QuestOverlayComplete = Texture()
    frame.QuestOverlayIncomplete = Texture()
    -- Children of the StatusBar in the XML; BuildVisuals aliases them onto the frame.
    frame.StatusBar.RestedOverlay = frame.RestedOverlay
    frame.StatusBar.QuestOverlayComplete = frame.QuestOverlayComplete
    frame.StatusBar.QuestOverlayIncomplete = frame.QuestOverlayIncomplete
    function frame:HasCapability(cap) return self.__xpbar_capabilities[cap] ~= false end
    function frame:GetHeight() return 20 end
    frame:InitializeColors()
    return frame
end

-- 4000 / 10000 XP, 1000 of finished quests, 1000 of unfinished, 2000 rested.
local context = {
    currentXP = 4000, xpMax = 10000, restedXP = 2000, hasRestedXP = true,
    completeQuestXP = 1000, incompleteQuestXP = 1000,
    showQuestXP = true, showCompleteQuestOverlay = true, showIncompleteQuestOverlay = true,
}

local function Paint(frame)
    frame:UpdateGainedBar(0.4, context)
    frame:UpdateRestedBar(context)
    frame:UpdateQuestCompleteBar(context)
    frame:UpdateQuestIncompleteBar(context)
end

local function Near(a, b) return math.abs(a - b) < 1e-6 end
local function SameColour(seen, r, g, b, a)
    return Near(seen[1], r) and Near(seen[2], g) and Near(seen[3], b) and Near(seen[4], a)
end

-- The texture shows the bar's colour at `from` on one end and at `to` on the other.
local function CheckSpan(label, texture, color, from, to, orientation)
    local first, last, seenOrientation = Seen(texture)
    local r1, g1, b1 = Shared.GradientColorAt(color, from)
    local r2, g2, b2 = Shared.GradientColorAt(color, to)
    local a = color.a or 1
    H.Check(label .. ": orientation", seenOrientation, orientation or "HORIZONTAL")
    H.Check(label .. ": start colour and alpha", SameColour(first, r1, g1, b1, a), true)
    H.Check(label .. ": end colour and alpha", SameColour(last, r2, g2, b2, a), true)
end

-- The texture shows `color`, flat.
local function CheckFlat(label, texture, color)
    local first, last = Seen(texture)
    local a = color.a or 1
    H.Check(label, SameColour(first, color.r, color.g, color.b, a) and SameColour(last, color.r, color.g, color.b, a), true)
end

local Colors = Addon.Colors
local function Fill() return Colors:Get(Colors.Key.XpBarRested) end
local function Rested() return Colors:Get(Colors.Key.Rested) end
local function Complete() return Colors:Get(Colors.Key.QuestComplete) end
local function Incomplete() return Colors:Get(Colors.Key.QuestIncomplete) end

H.Section("Derived colours")
local r, g, b = Shared.GradientColorAt({ r = 1, g = 0.5, b = 0 }, 0)
H.Check("empty end: 60% of the colour", Near(r, 0.6) and Near(g, 0.3) and Near(b, 0), true)
r, g, b = Shared.GradientColorAt({ r = 1, g = 0.5, b = 0 }, 1)
H.Check("full end: 35% towards white", Near(r, 1) and Near(g, 0.675) and Near(b, 0.35), true)
r = Shared.GradientColorAt({ r = 1, g = 1, b = 1 }, 2)
H.Check("clamped past the end", Near(r, 1), true)
H.Check("off by default", Addon.Config:GetOptionValue("fillGradient"), false)

for _, mode in ipairs({ "replace", "multiply" }) do
    engine = mode

    H.Section("Option off (" .. mode .. ")")
    Addon.Config:SetOptionKey("fillGradient", false)
    local flat = Bar(true)
    Paint(flat)
    CheckFlat("fill: flat colour", flat.StatusBar.fill, Fill())
    CheckFlat("rested: flat colour", flat.RestedOverlay, Rested())
    CheckFlat("finished quests: flat colour", flat.QuestOverlayComplete, Complete())

    H.Section("Option on, Flat or Classic (" .. mode .. ")")
    Addon.Config:SetOptionKey("fillGradient", true)
    local bar = Bar(true)
    Paint(bar)
    CheckSpan("fill over [0, 0.4]", bar.StatusBar.fill, Fill(), 0, 0.4)
    CheckSpan("finished quests over [0.4, 0.5]", bar.QuestOverlayComplete, Complete(), 0.4, 0.5)
    CheckSpan("unfinished quests over [0.5, 0.6]", bar.QuestOverlayIncomplete, Incomplete(), 0.5, 0.6)
    CheckSpan("rested over [0, 0.8]", bar.RestedOverlay, Rested(), 0, 0.8)

    bar:UpdateGainedBar(0.7, context)
    CheckSpan("the fill follows its value", bar.StatusBar.fill, Fill(), 0, 0.7)
    bar.StatusBar.low, bar.StatusBar.high = 0, 10000
    bar.StatusBar:SetValue(2500)
    bar:UpdateBarColors(context)
    CheckSpan("a bar on XP values, not 0..1", bar.StatusBar.fill, Fill(), 0, 0.25)
    bar:InitializeColors()
    Paint(bar)
    CheckSpan("colours set again (a colour change), then laid out", bar.RestedOverlay, Rested(), 0, 0.8)

    H.Section("Option on, Vertical (" .. mode .. ")")
    local vertical = Bar(true, "VERTICAL")
    Paint(vertical)
    CheckSpan("fill, bottom to top", vertical.StatusBar.fill, Fill(), 0, 0.4, "VERTICAL")
    CheckSpan("finished quests, bottom to top", vertical.QuestOverlayComplete, Complete(), 0.4, 0.5, "VERTICAL")

    H.Section("Option on, a style without the capability (" .. mode .. ")")
    local orb = Bar(nil)
    Paint(orb)
    CheckFlat("fill: flat colour", orb.StatusBar.fill, Fill())
    CheckFlat("overlay: flat colour", orb.QuestOverlayComplete, Complete())

    H.Section("Option back off (" .. mode .. ")")
    Addon.Config:SetOptionKey("fillGradient", false)
    Paint(bar)
    CheckFlat("fill: flat colour again", bar.StatusBar.fill, Fill())
    CheckFlat("rested: flat colour again", bar.RestedOverlay, Rested())
    CheckFlat("unfinished quests: flat colour again", bar.QuestOverlayIncomplete, Incomplete())
    bar:InitializeColors()
    CheckFlat("and after the colours are set again", bar.RestedOverlay, Rested())
end

H.Section("The styles' own code")
H.LoadXMLScripts()
engine = "multiply"
Addon.Config:SetOptionKey("fillGradient", true)
for _, key in ipairs({ "flat", "classic" }) do
    local styled = Bar(nil, nil, Addon.Styles[key])
    Paint(styled)
    CheckSpan(key .. ": fill", styled.StatusBar.fill, Fill(), 0, 0.4)
    CheckSpan(key .. ": rested", styled.RestedOverlay, Rested(), 0, 0.8)
end
local styledVertical = Bar(nil, nil, Addon.Styles.vertical)
Paint(styledVertical)
CheckSpan("vertical: fill, bottom to top", styledVertical.StatusBar.fill, Fill(), 0, 0.4, "VERTICAL")
CheckSpan("vertical: finished quests", styledVertical.QuestOverlayComplete, Complete(), 0.4, 0.5, "VERTICAL")
CheckSpan("vertical: unfinished quests", styledVertical.QuestOverlayIncomplete, Incomplete(), 0.5, 0.6, "VERTICAL")
CheckSpan("vertical: rested", styledVertical.RestedOverlay, Rested(), 0, 0.8, "VERTICAL")
local styledOrb = Bar(nil, nil, Addon.Styles.orb)
H.Check("orb: no gradient", Shared.UsesFillGradient(styledOrb), false)
H.CheckNoErrors("no errors")

H.Section("Two colour objects for every paint, not two a paint")
engine = "replace"
Addon.Config:SetOptionKey("fillGradient", true)
local created, createColor = 0, CreateColor
CreateColor = function(...) created = created + 1 return createColor(...) end
local animated = Bar(true)
for step = 1, 30 do animated:UpdateGainedBar(step / 30, context) end
CreateColor = createColor
H.Check("no colour created per frame of a fill animation", created, 0)

-- Last: a refusal turns the gradient off for the rest of the session.
H.Section("SetGradient refusing")
local refused = Bar(true)
refused.StatusBar.fill.SetGradient = function() error("SetGradient refused", 2) end
Paint(refused)
CheckFlat("fill: flat colour", refused.StatusBar.fill, Fill())
H.CheckNoErrors("the refusal is not reported as an error")
local after = Bar(true)
Paint(after)
H.Check("flat for the rest of the session", after.StatusBar.fill.gradient == nil and after.RestedOverlay.gradient == nil, true)

H.CheckNoErrors("no errors")
H.Done()
