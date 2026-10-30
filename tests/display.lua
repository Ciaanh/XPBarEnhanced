-- What the player reads: the kills line in the bar tooltip, the rate text under the bar (the base
-- one and Vertical's own), the LibDataBroker tooltip and the Stats window; and which styles offer
-- the gradient fill, against the options panel's own list. The XML-listed files (styles, Stats,
-- Options) are run; their frames are built here over font strings that record their text.
local H = dofile((arg[1] or ".") .. "/tests/harness.lua")

COMBATLOG_XPGAIN_FIRSTPERSON = "%s dies, you gain %d experience."
H.player.level, H.player.xp, H.player.max = 20, 1000, 10000
local Addon = H.Load(nil)

-- A LibDataBroker, from another addon, that keeps the data objects it is given.
local brokers = {}
LibStub:NewLibrary("LibDataBroker-1.1", 1).NewDataObject = function(_, name, object)
    brokers[name] = object
    return object
end

H.Login()
H.LoadXMLScripts()
local L = Addon.L

local function FontString()
    local f = { text = "" }
    function f:SetText(text) self.text = text end
    function f:GetText() return self.text end
    function f:SetShown() end
    function f:Show() end
    function f:Hide() end
    return f
end

-- A fresh context: the builder keeps one per frame, emptied on the next.
local function Context()
    H.RunTimers()
    return XPBarContextBuilder.BuildContext("MANUAL_REFRESH")
end

-- The tooltip line whose left side is label, or nil.
local function TooltipLine(label)
    local content = { lines = {} }
    Mixin({}, XPBarTooltipMixin):AddXPSection(content, Context(), {})
    for _, line in ipairs(content.lines) do
        if type(line) == "table" and line.left == label .. ":" then
            return line.right
        end
    end
    return nil
end

local function RateText(mixin)
    local frame = Mixin({}, mixin)
    frame.RateText = FontString()
    frame:UpdateRateText(Context())
    return frame.RateText.text
end

local function BrokerLines()
    local lines = {}
    local tooltip = {}
    function tooltip:AddLine(text) table.insert(lines, { text }) end
    function tooltip:AddDoubleLine(left, right) table.insert(lines, { left, right }) end
    brokers.XPBarEnhanced.OnTooltipShow(tooltip)
    return lines
end

local function BrokerValue(label)
    for _, line in ipairs(BrokerLines()) do
        if line[1] == label then return line[2] end
    end
    return nil
end

-- A Stats window whose fields are font strings made on first use.
local function StatsKills()
    local fields = setmetatable({}, { __index = function(t, k) local f = FontString() rawset(t, k, f) return f end })
    Addon.Stats:UpdateLevelStats({ Fields = fields })
    return fields.KillsToLevelValue.text
end

H.Section("Before the first kill")
H.Check("tooltip: no kills line", TooltipLine(L["TT_KILLS_TO_LEVEL"]), nil)
Addon.Config:SetOptionKey("showKillsToLevelText", true)
H.Check("rate text: no kills part", RateText(XPBarTextMixin):find(L["TT_KILLS_SHORT"]:gsub("%%s", ""), 1, true), nil)
H.Check("data broker: no kills line", BrokerValue(L["LDB_TT_KILLS"]), nil)
H.Check("Stats: N/A", StatsKills(), L["TT_NA"])
H.CheckNoErrors("no errors")

H.Section("After a kill (9000 XP left, 100 a kill)")
H.Fire("CHAT_MSG_COMBAT_XP_GAIN", "Kobold Miner dies, you gain 100 experience.")
H.Check("tooltip", TooltipLine(L["TT_KILLS_TO_LEVEL"]), "90")
local kills = L["TT_KILLS_SHORT"]:format("90")
H.Check("rate text", RateText(XPBarTextMixin):find(kills, 1, true) ~= nil, true)
-- Like XP/hour: only the styles with a text row under the bar (Flat, Classic) show it.
H.Check("Vertical's on-bar readout keeps to time to level", RateText(VerticalBarXPBarMixin):find(kills, 1, true), nil)
H.Check("data broker", BrokerValue(L["LDB_TT_KILLS"]), "90")
H.Check("Stats", StatsKills(), L["STATS_KILLS_FMT"]:format("90", "100"))
Addon.Config:SetOptionKey("showKillsToLevelText", false)
H.Check("rate text, option off: no kills part", RateText(XPBarTextMixin):find(kills, 1, true), nil)
H.CheckNoErrors("no errors")

H.Section("A secondary bar with nothing to show")
local function SecondaryFrame(mouse)
    local f = { alpha = 1, mouse = mouse }
    function f:SetAlpha(a) self.alpha = a end
    function f:FadeToAlpha(a) self.alpha = a end
    function f:EnableMouse(on) self.mouse = on and true or false end
    function f:IsMouseEnabled() return self.mouse end
    return f
end
local Shared = Addon.UI.SharedStyleHelpers
local secondary = SecondaryFrame(true)
Shared.BeginSecondaryRender(secondary, { isAvailable = true })
Shared.BeginSecondaryRender(secondary, { isAvailable = false })
H.Check("hidden", secondary.alpha, 0)
H.Check("and no longer takes clicks", secondary.mouse, false)
Shared.BeginSecondaryRender(secondary, { isAvailable = false })
Shared.BeginSecondaryRender(secondary, { isAvailable = true })
H.Check("shown again", secondary.alpha, 1)
H.Check("and takes clicks again", secondary.mouse, true)
local mouseless = SecondaryFrame(false)
Shared.BeginSecondaryRender(mouseless, { isAvailable = false })
Shared.BeginSecondaryRender(mouseless, { isAvailable = true })
H.Check("a bar its style keeps mouseless stays so", mouseless.mouse, false)

H.Section("An update during the level-up hold")
local held = Mixin({}, XPBarMixinBase)
held.renders, held.cleanups = 0, 0
function held:RenderBar() self.renders = self.renders + 1 end
function held:UpdateOverlays() end
function held:UpdateAllText() end
function held:CleanupAnimation() self.cleanups = self.cleanups + 1 self.animation.holdStartTime = nil
    self.animation.pendingSecondPhase = nil end
held.animation = { isAnimating = false, holdStartTime = 1, pendingSecondPhase = {} }
local heldContext = Context()
held:HandleImmediateUpdate(heldContext, false)
H.Check("the fill is left at 100%", held.renders, 0)
H.Check("the update kept for the animation", held.animation.eventContext, heldContext)
held:HandleImmediateUpdate(heldContext, true)
H.Check("a forced update ends the animation", held.cleanups, 1)
H.Check("and renders", held.renders, 1)

H.Section("Gradient fill: the styles that offer it")
local source = assert(io.open(H.ROOT .. "/ui/options/Options.lua")):read("*a")
local owners = {}
for style in source:match("fillGradient%s*=%s*(%b{})"):gmatch('"([%w_]+)"') do owners[style] = true end
local styles = {}
for key in pairs(Addon.Styles) do table.insert(styles, key) end
table.sort(styles)
H.Check("every style registered", #styles >= 7, true)
for _, key in ipairs(styles) do
    local declares = (Addon.Styles[key].__xpbar_capabilities or {}).fillGradient == true
    H.Check(key .. ": declares it as the options panel says", declares, owners[key] == true)
end
H.Check("Flat, Vertical and Classic", owners.flat and owners.vertical and owners.classic, true)
H.Check("Vertical runs bottom to top", VerticalBarXPBarMixin.gradientOrientation, "VERTICAL")

H.CheckNoErrors("no errors")
H.Done()
