-- XP Bar Enhanced - Terminal Style  (Easter Egg)
-- Two-line ASCII display: progress bar with per-segment coloring + stats prompt.
--
--   [█████████████████████████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░] 46.7%  Lv.23
--   > xp/hr:44K | eta:9h31m | sess:55m | lvl:2h12m
--
-- Segment colours are fixed terminal semantics (not user-configured):
--   █ (green)  – earned XP
--   █ (teal)   – rested XP bonus
--   █ (amber)  – quest XP overlay
--   ░ (dim)    – not yet earned

-------------------------------------------------------------------
-- DEPENDENCIES
-------------------------------------------------------------------

if not XPBarStyleBuilder or not XPBarMixinBase then
    error("TerminalBarStyle: core (StyleBuilder/BaseMixin) not loaded.")
end

local Addon = XPBarEnhanced

-------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------

local BAR_CHARS = 50  -- character cells in the progress section

-- Unicode block characters (UTF-8 byte sequences)
local CH_FULL  = "\226\150\136"  -- U+2588  █  FULL BLOCK  (earned)
local CH_DARK  = "\226\150\147"  -- U+2593  ▓  DARK SHADE  (rested)
local CH_MED   = "\226\150\146"  -- U+2592  ▒  MEDIUM SHADE (quest)
local CH_EMPTY = "\226\150\145"  -- U+2591  ░  LIGHT SHADE  (not earned)

local DELTA_FADE_DURATION = 1.8  -- seconds for "+XP" popup to fade out

local TERMINAL_FONT = "Interface\\AddOns\\XPBarEnhanced\\fonts\\DejaVuSansMono.ttf"
local BASE_WIDTH = 650
local BASE_HEIGHT = 42

-------------------------------------------------------------------
-- TERMINAL COLOUR PALETTE  (WoW |cFF escape code strings)
-------------------------------------------------------------------

local function Hex(r, g, b)
    return string.format("|cFF%02X%02X%02X",
        math.min(255, math.floor(r * 255 + 0.5)),
        math.min(255, math.floor(g * 255 + 0.5)),
        math.min(255, math.floor(b * 255 + 0.5)))
end

local C_EARNED = Hex(0.00, 1.00, 0.00)  -- phosphor green
local C_RESTED = Hex(0.00, 0.85, 0.80)  -- teal
local C_QUEST  = Hex(1.00, 0.55, 0.00)  -- darker orange (complete quest)
local C_QUEST_INC = Hex(1.00, 0.85, 0.00)  -- bright gold (incomplete quest)
local C_EMPTY  = Hex(0.18, 0.18, 0.18)  -- very dim gray
local C_LABEL  = Hex(0.00, 0.65, 0.00)  -- dimmer green (brackets, pct, level)
local C_STATS  = Hex(0.00, 0.48, 0.00)  -- even dimmer (stats prompt line)
local C_DELTA  = Hex(0.45, 1.00, 0.45)  -- bright mint ("+XP" popup)

local function ResolveHexColor(color, fallbackHex)
    if not color then
        return fallbackHex
    end
    return Hex(color.r or 0, color.g or 0, color.b or 0)
end

local function ResolveTerminalPalette()
    local palette = {
        earned = C_EARNED,
        quest = C_QUEST,
        questIncomplete = C_QUEST_INC,
        rested = C_RESTED,
        empty = C_EMPTY,
    }

    local useCustom = Addon.Config and Addon.Config.GetOptionValue
        and Addon.Config:GetOptionValue("terminalUseCustomColors")
    if not useCustom then
        return palette
    end

    local Colors = Addon and Addon.Colors
    if not Colors then
        return palette
    end

    palette.earned = ResolveHexColor(Colors:Get(Colors.Key.XpBar), C_EARNED)
    palette.quest = ResolveHexColor(Colors:Get(Colors.Key.QuestComplete), C_QUEST)
    palette.questIncomplete = ResolveHexColor(Colors:Get(Colors.Key.QuestIncomplete), C_QUEST_INC)
    palette.rested = ResolveHexColor(Colors:Get(Colors.Key.Rested), C_RESTED)

    return palette
end

-------------------------------------------------------------------
-- BAR STRING BUILDER
-------------------------------------------------------------------

--- Build the inner block string with per-segment WoW colour escape codes.
--- Segment order (left to right): earned → complete quest → incomplete quest → rested → empty
--- Character semantics:
---   █ green  = earned         ▓ amber = complete quest (solid: ready to collect)
---   ▒ orange = incomplete quest (medium: needs work first)
---   ▓ teal   = rested         ░ dim = not yet earned
local function BuildColoredBar(filled, questCompleteEnd, questIncompleteEnd, restedEnd, barChars)
    barChars = barChars or BAR_CHARS
    local parts     = {}
    local lastColor = nil

    local db = Addon.db or {}
    local palette = ResolveTerminalPalette()

    local useEarned = palette.earned
    local useQuest = palette.quest
    local useQuestInc = palette.questIncomplete
    local useRested = palette.rested
    local useEmpty = palette.empty

    for i = 1, barChars do
        local ch, col
        if     i <= filled             then ch, col = CH_DARK,  useEarned
        elseif i <= questCompleteEnd   then ch, col = CH_MED,  useQuest
        elseif i <= questIncompleteEnd then ch, col = CH_MED,   useQuestInc
        elseif i <= restedEnd          then ch, col = CH_MED,  useRested
        else                                ch, col = CH_EMPTY, useEmpty
        end

        if col ~= lastColor then
            if lastColor then parts[#parts + 1] = "|r" end
            parts[#parts + 1] = col
            lastColor = col
        end
        parts[#parts + 1] = ch
    end

    if lastColor then parts[#parts + 1] = "|r" end
    return table.concat(parts)
end

-------------------------------------------------------------------
-- STATS LINE HELPERS
-------------------------------------------------------------------

local function FormatTime(seconds)
    if not seconds or seconds <= 0 then return nil end
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    if h > 0 then
        return string.format("%dh%02dm", h, m)
    elseif m > 0 then
        return string.format("%dm", m)
    else
        return string.format("%ds", math.floor(seconds))
    end
end

local function FormatXP(xp, abbreviate)
    if not xp or xp <= 0 then return nil end
    if abbreviate ~= false then
        if xp >= 1000000 then return string.format("%.1fM", xp / 1000000) end
        if xp >= 1000    then return string.format("%.0fK", xp / 1000) end
    end
    return tostring(math.floor(xp))
end

--- Build the terminal prompt stats line (with embedded colour codes).
local function BuildTerminalStatsLine(db)
    db = db or {}
    local parts      = {}
    local abbreviate = db.abbreviateNumbers ~= false

    if db.showXPPerHourText ~= false and Addon.Session and Addon.Session.GetXPPerHour then
        local fmt = FormatXP(Addon.Session:GetXPPerHour(), abbreviate)
        if fmt then parts[#parts + 1] = "xp/hr:" .. fmt end
    end

    if db.showTimeToLevelText ~= false and Addon.Session and Addon.Session.GetTimeToLevel then
        local fmt = FormatTime(Addon.Session:GetTimeToLevel())
        if fmt then parts[#parts + 1] = "eta:" .. fmt end
    end

    local session = Addon.Session and Addon.Session.GetCurrent and Addon.Session:GetCurrent()
    if session then
        if db.showSessionTimeText ~= false and session.sessionStart then
            local fmt = FormatTime(time() - session.sessionStart)
            if fmt then parts[#parts + 1] = "sess:" .. fmt end
        end
        if db.showLevelTimeText ~= false and session.realLevelTime and session.realLevelTime > 0 then
            local lvlSec = session.realLevelTime
            if session.lastTimePlayedRequest and session.lastTimePlayedRequest > 0 then
                lvlSec = lvlSec + (time() - session.lastTimePlayedRequest)
            end
            local fmt = FormatTime(lvlSec)
            if fmt then parts[#parts + 1] = "lvl:" .. fmt end
        end
    end

    if #parts == 0 then return nil end
    return C_STATS .. "> " .. table.concat(parts, " | ") .. "|r"
end

-------------------------------------------------------------------
-- STYLE TEMPLATE
-------------------------------------------------------------------

local TerminalBarStyleTemplate = {}

function TerminalBarStyleTemplate:ResizeToScale()
    local width = BASE_WIDTH
    local height = BASE_HEIGHT

    self:SetSize(width, height)

    -- Keep hidden compatibility StatusBar dimensions aligned with frame scale.
    if self.StatusBar and self.StatusBar.SetSize then
        self.StatusBar:SetSize(width, height)
    end
end

-- Reusable table for UpdateGainedBar → RenderBar to avoid per-frame allocation
local _renderCtx = {}

-------------------------------------------------------------------
-- RENDERING
-------------------------------------------------------------------

--- Called by the animation system every frame with the interpolated ratio.
function TerminalBarStyleTemplate:UpdateGainedBar(currentRatio, eventContext)
    local ctx = eventContext or {}
    _renderCtx.ratio             = currentRatio
    _renderCtx.currentXP         = ctx.currentXP
    _renderCtx.xpMax             = ctx.xpMax
    _renderCtx.restedXP          = ctx.restedXP
    _renderCtx.hasRestedXP       = ctx.hasRestedXP
    _renderCtx.completeQuestXP   = ctx.completeQuestXP
    _renderCtx.incompleteQuestXP = ctx.incompleteQuestXP
    _renderCtx.level             = ctx.level
    self:RenderBar(_renderCtx)
end

--- Rebuild both terminal lines from a context table.
function TerminalBarStyleTemplate:RenderBar(context)
    local barText = self._terminalBarText
    if not barText or not context then return end

    local ratio = context.ratio
    if not ratio then
        local xp    = context.currentXP or 0
        local xpMax = context.xpMax or 1
        ratio = xpMax > 0 and (xp / xpMax) or 0
    end

    local db = Addon.db or {}

    local pct   = string.format("%.1f%%", ratio * 100)
    local level = context.level or (UnitLevel and UnitLevel("player")) or "?"
    local barChars = BAR_CHARS

    -- Segment boundaries — stacked left-to-right, each proportional to its XP amount
    local filled = math.floor(ratio * barChars + 0.5)

    -- Complete quest XP (solid amber █ — ready to collect right now)
    local questCompleteEnd = filled
    if db.showCompleteQuestOverlay ~= false and context.completeQuestXP and context.completeQuestXP > 0
       and context.xpMax and context.xpMax > 0 then
        local chars = math.floor(context.completeQuestXP / context.xpMax * barChars + 0.5)
        questCompleteEnd = math.min(barChars, filled + chars)
    end

    -- Incomplete quest XP (medium amber ▒ — needs completing first)
    local questIncompleteEnd = questCompleteEnd
    if db.showIncompleteQuestOverlay == true and context.incompleteQuestXP and context.incompleteQuestXP > 0
       and context.xpMax and context.xpMax > 0 then
        local chars = math.floor(context.incompleteQuestXP / context.xpMax * barChars + 0.5)
        questIncompleteEnd = math.min(barChars, questCompleteEnd + chars)
    end

    -- Rested XP (dark teal ▓ — after quest segments)
    local restedEnd    = questIncompleteEnd
    local hasRestedXP  = context.hasRestedXP or (context.restedXP and context.restedXP > 0)
    if db.showRestedOverlay ~= false and hasRestedXP
       and context.restedXP and context.xpMax and context.xpMax > 0 then
        local chars = math.floor(context.restedXP / context.xpMax * barChars + 0.5)
        restedEnd = math.min(barChars, questIncompleteEnd + chars)
    end

    -- Build bar line: [coloured blocks] (left) + XX.X%  Lv.N (right, separate element)
    local inner = BuildColoredBar(filled, questCompleteEnd, questIncompleteEnd, restedEnd, barChars)
    local display = C_LABEL .. "[|r" .. inner .. C_LABEL .. "]|r"
    local label   = C_LABEL .. pct .. "  Lv." .. tostring(level) .. "|r"

    if display ~= self._lastDisplay then
        barText:SetText(display)
        self._lastDisplay = display
    end

    local labelText = self._terminalLabelText
    if labelText then
        if label ~= self._lastLabel then
            labelText:SetText(label)
            self._lastLabel = label
        end
    end

    -- Stats prompt line
    local statsText = self._terminalStatsText
    if statsText then
        local statsLine = BuildTerminalStatsLine(db)
        if statsLine then
            if statsLine ~= self._lastStatsLine then
                statsText:SetText(statsLine)
                self._lastStatsLine = statsLine
            end
            statsText:Show()
        else
            statsText:Hide()
        end
    end

    -- Sync hidden StatusBar value
    if self.StatusBar then
        self.StatusBar:SetMinMaxValues(0, 1)
        self.StatusBar:SetValue(ratio)
    end
end

-------------------------------------------------------------------
-- TERMINAL TOOLTIP  (custom frame — replaces GameTooltip entirely)
-------------------------------------------------------------------

local TPAD = 10  -- inner padding in pixels
local CH_SEP = "\226\148\128"  -- U+2500 ─ BOX DRAWINGS LIGHT HORIZONTAL

local TerminalTooltip = nil

local function GetOrCreateTerminalTooltip()
    if TerminalTooltip then return TerminalTooltip end

    local f = CreateFrame("Frame", "XPBarTerminalTooltip", UIParent, "BackdropTemplate")
    f:SetFrameStrata("TOOLTIP")
    f:SetClampedToScreen(true)
    f:Hide()

    f:SetBackdrop({
        bgFile   = "Interface/Buttons/WHITE8X8",
        edgeFile = "Interface/Buttons/WHITE8X8",
        edgeSize = 1,
        insets   = {left = 1, right = 1, top = 1, bottom = 1},
    })
    f:SetBackdropColor(0.02, 0.02, 0.02, 0.96)
    f:SetBackdropBorderColor(0.00, 0.55, 0.00, 0.90)

    local txt = f:CreateFontString(nil, "OVERLAY")
    txt:SetFont(TERMINAL_FONT, 11, "MONOCHROME")
    txt:SetJustifyH("LEFT")
    txt:SetJustifyV("TOP")
    txt:SetPoint("TOPLEFT", f, "TOPLEFT", TPAD, -TPAD)
    f._txt = txt

    TerminalTooltip = f
    return f
end

local function BuildTerminalTooltipText(context)
    local db  = Addon.db or {}
    local sep = C_STATS .. string.rep(CH_SEP, 42) .. "|r"
    local lines = {}
    local palette = ResolveTerminalPalette()

    local colorEarned = palette.earned
    local colorQuest = palette.quest
    local colorQuestInc = palette.questIncomplete
    local colorRested = palette.rested

    -- Header
    local level = context.level or (UnitLevel and UnitLevel("player")) or "?"
    lines[#lines+1] = C_LABEL .. "> XP_BAR_ENHANCED" .. string.rep(" ", 8) .. "Lv." .. tostring(level) .. "|r"
    lines[#lines+1] = sep

    -- XP
    if context.currentXP and context.xpMax and context.xpMax > 0 then
        local pct  = context.currentXP / context.xpMax * 100
        local rem  = context.xpMax - context.currentXP
        local currentXPText = FormatXP(context.currentXP, false) or "0"
        local maxXPText = FormatXP(context.xpMax, false) or "0"
        local remainingXPText = FormatXP(rem, false) or "0"
        lines[#lines+1] = C_STATS .. "current:   |r"
            .. colorEarned .. currentXPText .. " / " .. maxXPText
            .. C_STATS  .. string.format("  (%.1f%%)", pct) .. "|r"
        lines[#lines+1] = C_STATS .. "remaining: |r"
            .. colorEarned .. remainingXPText .. "|r"
    end

    -- Rested
    if context.restedXP and context.restedXP > 0 and context.xpMax and context.xpMax > 0 then
        local rpct = context.restedXP / context.xpMax * 100
        lines[#lines+1] = ""
        lines[#lines+1] = C_STATS .. "rested:    |r"
            .. colorRested .. FormatXP(context.restedXP, false)
            .. C_STATS  .. string.format("  (%.1f%%)", rpct) .. "|r"
    end

    -- Quest XP
    local cq = context.completeQuestXP   or 0
    local iq = context.incompleteQuestXP or 0
    local showCQ = db.showCompleteQuestOverlay ~= false
    local showIQ = db.showIncompleteQuestOverlay == true
    if (cq > 0 and showCQ) or (iq > 0 and showIQ) then
        lines[#lines+1] = ""
        lines[#lines+1] = C_LABEL .. "> quest xp|r"
        if cq > 0 and showCQ then
            local pct = context.xpMax and context.xpMax > 0 and (cq / context.xpMax * 100) or 0
            lines[#lines+1] = C_STATS .. "  complete:   |r"
                .. colorQuest .. FormatXP(cq)
                .. C_STATS .. string.format("  (%.1f%%)", pct) .. "|r"
        end
        if iq > 0 and showIQ then
            local pct = context.xpMax and context.xpMax > 0 and (iq / context.xpMax * 100) or 0
            lines[#lines+1] = C_STATS .. "  incomplete: |r"
                .. colorQuestInc .. FormatXP(iq)
                .. C_STATS .. string.format("  (%.1f%%)", pct) .. "|r"
        end
    end

    -- Session
    local parts = {}
    if Addon.Session and Addon.Session.GetXPPerHour then
        local xphr = Addon.Session:GetXPPerHour()
        if xphr and xphr > 0 then
            parts[#parts+1] = C_STATS .. "xp/hr:|r" .. colorEarned .. FormatXP(xphr) .. "|r"
        end
    end
    if Addon.Session and Addon.Session.GetTimeToLevel then
        local fmt = FormatTime(Addon.Session:GetTimeToLevel())
        if fmt then parts[#parts+1] = C_STATS .. "eta:|r" .. colorEarned .. fmt .. "|r" end
    end
    local session = Addon.Session and Addon.Session.GetCurrent and Addon.Session:GetCurrent()
    if session and session.sessionStart then
        local fmt = FormatTime(time() - session.sessionStart)
        if fmt then parts[#parts+1] = C_STATS .. "sess:|r" .. colorEarned .. fmt .. "|r" end
    end
    if #parts > 0 then
        lines[#lines+1] = ""
        lines[#lines+1] = C_LABEL .. "> session|r"
        lines[#lines+1] = "  " .. table.concat(parts, C_STATS .. "  |  |r")
    end

    -- Legend (using resolved colors from bar, not hardcoded constants)
    lines[#lines+1] = ""
    lines[#lines+1] = C_LABEL .. "> legend|r"
    lines[#lines+1] = "  "
        .. colorEarned .. CH_DARK  .. " earned|r  "
        .. colorQuest  .. CH_MED  .. " quest:done|r  "
        .. colorQuestInc .. CH_MED   .. " quest:todo|r  "
        .. colorRested .. CH_MED   .. " rested|r  "
        .. C_EMPTY  .. CH_EMPTY .. " free|r"

    -- Footer
    lines[#lines+1] = ""
    lines[#lines+1] = sep
    lines[#lines+1] = C_STATS .. "shift+drag to move  |  alt+click options|r"

    return table.concat(lines, "\n")
end

local function ShowTerminalTooltip(owner)
    local cfg = owner.__xpbar_config or {}
    -- Profile-aware read (falls back to raw db pre-Config)
    local showTooltip
    if Addon.Config and Addon.Config.GetOptionValue then
        showTooltip = Addon.Config:GetOptionValue("showTooltip")
    else
        showTooltip = Addon.db and Addon.db.showTooltip
    end
    if (cfg.tooltip and cfg.tooltip.enabled == false) or showTooltip == false then return end

    local context = XPBarContextBuilder and XPBarContextBuilder.BuildContext("TOOLTIP") or {}
    local f   = GetOrCreateTerminalTooltip()
    local txt = f._txt

    txt:SetWidth(0)
    txt:SetText(BuildTerminalTooltipText(context))

    local tw = math.max(220, math.ceil(txt:GetStringWidth())  + 1)
    local th =              math.ceil(txt:GetStringHeight()) + 1
    f:SetSize(tw + TPAD * 2, th + TPAD * 2)
    txt:SetWidth(tw)

    f:ClearAllPoints()
    local _, cy   = owner:GetCenter()
    local screenH = UIParent:GetTop() or GetScreenHeight()
    if cy and cy < screenH / 2 then
        f:SetPoint("BOTTOMLEFT", owner, "TOPLEFT",   0,  6)
    else
        f:SetPoint("TOPLEFT",    owner, "BOTTOMLEFT", 0, -6)
    end
    f:Show()
end

local function HideTerminalTooltip()
    if TerminalTooltip then TerminalTooltip:Hide() end
end

function TerminalBarStyleTemplate:OnEnter()
    ShowTerminalTooltip(self)
end

function TerminalBarStyleTemplate:OnLeave()
    HideTerminalTooltip()
end

-------------------------------------------------------------------

function TerminalBarStyleTemplate:AnimateBarEffect(iterationData, eventContext)
    local now          = GetTime()
    local isFlashingNow = iterationData and iterationData.isFlashing

    if isFlashingNow and not self._deltaShown then
        local gained = eventContext and eventContext.xpGained or 0
        if gained > 0 and self._deltaText then
            self._deltaText:SetText(C_DELTA .. "+" .. tostring(gained) .. " XP|r")
            self._deltaText:SetAlpha(1)
            self._deltaText:Show()
            self._deltaShown  = true
            self._deltaFadeAt = now
        end
    end

    if self._deltaShown and self._deltaText then
        local alpha = math.max(0, 1 - (now - (self._deltaFadeAt or now)) / DELTA_FADE_DURATION)
        self._deltaText:SetAlpha(alpha)
        if alpha <= 0 then
            self._deltaText:Hide()
            self._deltaShown = false
        end
    end

    if not isFlashingNow then
        self._deltaShown = false
    end
end

-------------------------------------------------------------------
-- LIFECYCLE OVERRIDES
-------------------------------------------------------------------

function TerminalBarStyleTemplate:BuildVisuals()
    if XPBarPaintMixin and XPBarPaintMixin.BuildVisuals then
        XPBarPaintMixin.BuildVisuals(self)
    end

    self:ResizeToScale()

    if self.OverlayFrameTextContainer then
        self._terminalBarText   = self.OverlayFrameTextContainer.TerminalBarText
        self._terminalLabelText = self.OverlayFrameTextContainer.TerminalLabelText
        self._deltaText         = self.OverlayFrameTextContainer.DeltaText
        self._terminalStatsText = self.OverlayFrameTextContainer.TerminalStatsText

        if self._terminalBarText then
            self._terminalBarText:SetFont(TERMINAL_FONT, 14, "MONOCHROME")
            self._terminalBarText:SetTextColor(1, 1, 1, 1)  -- base white; colour via escape codes
        end
        if self._terminalLabelText then
            self._terminalLabelText:SetFont(TERMINAL_FONT, 14, "MONOCHROME")
            self._terminalLabelText:SetTextColor(1, 1, 1, 1)
        end
        if self._deltaText then
            self._deltaText:SetFont(TERMINAL_FONT, 12, "MONOCHROME")
        end
        if self._terminalStatsText then
            self._terminalStatsText:SetFont(TERMINAL_FONT, 11, "MONOCHROME")
            self._terminalStatsText:SetTextColor(1, 1, 1, 1)
        end

    end

    self._lastDisplay   = nil
    self._lastLabel     = nil
    self._lastStatsLine = nil

    if self.StatusBar then
        self.StatusBar:SetAlpha(0)
    end

end

-- Suppress paint-mixin overlay and text methods (terminal manages its own display)
function TerminalBarStyleTemplate:UpdateBarColors() end
function TerminalBarStyleTemplate:UpdateRestedBarColor() end
function TerminalBarStyleTemplate:UpdateQuestCompleteBarColor() end
function TerminalBarStyleTemplate:UpdateQuestIncompleteBarColor() end
function TerminalBarStyleTemplate:UpdateTexts() end

-------------------------------------------------------------------
-- DEFAULT CONFIG
-------------------------------------------------------------------

local DefaultConfig = {
    interaction = {enabled = true},
    tooltip     = {enabled = true},
    animation   = {enableAnimations = true, flashOnGain = true},
    position    = {mode = "DRAGGABLE", positionKey = "TerminalBar"},
    style       = {},
    capabilities = {
        statusBar      = false,
        overlays       = false,
        exhaustionTick = false,
        textOnBar      = false,
        textBelowBar   = false,
        barColors      = false,
    },
}

-------------------------------------------------------------------
-- STYLE CREATION
-------------------------------------------------------------------

TerminalBarXPBarMixin = XPBarStyleBuilder:Create(XPBarMixinBase, TerminalBarStyleTemplate, DefaultConfig)
XPBarStyleBuilder:RegisterStyle("terminal", TerminalBarXPBarMixin)
