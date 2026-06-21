-- XP Bar Enhanced - Terminal Secondary Bar Style
-- Single ASCII line in the terminal bar's phosphor aesthetic.
-- Renders the watched faction's reputation progress as a coloured block bar.
--
-- Format:
--   > rep | FactionName [████████████████░░░░] Standing XX%  sess:+NNN
--
-- Standing-mapped phosphor fill colours:
--   Hated/Hostile  → deep red      Unfriendly → orange
--   Neutral        → amber         Friendly+  → phosphor green
--   Major/Paragon  → blue          Companion  → cyan

local Addon = XPBarEnhanced
local FALLBACK_SHARED_STYLE_HELPERS = {
    GetSecondaryPositionConfigKey = function()
        return "secondaryBarPositions"
    end,
    BuildConfiguredStyleCenterFallback = function(x, y)
        return {
            point = "CENTER",
            relativeTo = "UIParent",
            relativePoint = "CENTER",
            x = x or 0,
            y = y or 0,
        }
    end,
    GetSecondaryBroadcastEventName = function()
        return (Addon.EventNames and Addon.EventNames.REPUTATION_BROADCAST_UPDATE) or "REPUTATION:BROADCAST_UPDATE"
    end,
    GetSecondaryInitialContext = function()
        if Addon.ReputationSession and Addon.ReputationSession.GetCurrentContext then
            return Addon.ReputationSession:GetCurrentContext()
        end
        return nil
    end,
    BeginSecondaryRender = function(frame, context)
        frame._lastContext = context
        if not context or not context.isAvailable then
            frame:SetAlpha(0)
            return false
        end
        frame:SetAlpha(1)
        return true
    end,
    ShowSecondaryTooltip = function(frame, context, anchor)
        if not GameTooltip then
            return
        end
        GameTooltip:SetOwner(frame, anchor or "ANCHOR_TOP")
        GameTooltip:AddLine((context and context.name) or "", 1, 1, 1)
    end,
    AddSecondaryTooltipMoveHint = function()
    end,
    FinishSecondaryTooltip = function()
        if GameTooltip then
            GameTooltip:Show()
        end
    end,
    HideTooltip = function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end,
    HandleStandardSecondaryMouseUp = function(frame, button, onRightClick)
        if button == "RightButton" and onRightClick then
            onRightClick(frame)
        end
    end,
    OpenReputationPanel = function()
        if ToggleCharacter then
            ToggleCharacter("ReputationFrame")
        end
    end,
    BeginSecondaryShiftDrag = function()
        return false
    end,
    EndSecondaryDrag = function(frame)
        if frame and frame.StopMovingOrSizing then
            frame:StopMovingOrSizing()
        end
    end,
}

local function ResolveSharedStyleHelpers()
    local shared = Addon and Addon.UI and Addon.UI.SharedStyleHelpers
    return shared or FALLBACK_SHARED_STYLE_HELPERS
end

local SharedStyleHelpers = setmetatable({}, {
    __index = function(_, key)
        return ResolveSharedStyleHelpers()[key]
    end,
})

---@class XPBarTerminalReputationMixin
XPBarTerminalReputationMixin = {}
local StyleMixin = {}

-------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------

local TERMINAL_FONT = "Interface\\AddOns\\XPBarEnhanced\\fonts\\DejaVuSansMono.ttf"
local BAR_CHARS = 20
local TPAD = 10
local BASE_WIDTH = 650
local BASE_HEIGHT = 22

-- Unicode block fill characters (UTF-8 byte sequences matching TerminalBarStyle)
local CH_FULL  = "\226\150\136"  -- U+2588 █  FULL BLOCK  (filled)
local CH_DARK  = "\226\150\147"  -- U+2593 ▓  DARK SHADE  
local CH_EMPTY = "\226\150\145"  -- U+2591 ░  LIGHT SHADE (empty)

local function Hex(r, g, b)
    return string.format("|cFF%02X%02X%02X",
        math.min(255, math.floor(r * 255 + 0.5)),
        math.min(255, math.floor(g * 255 + 0.5)),
        math.min(255, math.floor(b * 255 + 0.5)))
end

-- Phosphor palette (matches TerminalBarStyle colour semantics)
local C_LABEL = Hex(0.00, 0.65, 0.00)   -- medium green  (brackets, prefixes)
local C_STATS = Hex(0.00, 0.48, 0.00)   -- dim green     (secondary info)
local C_EMPTY_COL = Hex(0.18, 0.18, 0.18)   -- very dim gray (empty segments)
local C_VALUE = Hex(0.00, 0.90, 0.00)
local CH_SEP = "\226\148\128"

-- Standing-level fill colours
local STANDING_COLORS = {
    [1] = Hex(0.80, 0.05, 0.05),  -- Hated      → deep red
    [2] = Hex(0.80, 0.05, 0.05),  -- Hostile    → deep red
    [3] = Hex(0.75, 0.35, 0.05),  -- Unfriendly → orange
    [4] = Hex(0.80, 0.65, 0.05),  -- Neutral    → amber
    [5] = Hex(0.00, 1.00, 0.00),  -- Friendly   → phosphor green
    [6] = Hex(0.00, 1.00, 0.00),  -- Honored    → phosphor green
    [7] = Hex(0.20, 1.00, 0.20),  -- Revered    → bright green
    [8] = Hex(0.60, 1.00, 0.20),  -- Exalted    → lime green
}

local C_MAJOR     = Hex(0.20, 0.60, 1.00)  -- major/paragon factions → blue
local C_COMPANION = Hex(0.20, 0.85, 0.85)  -- delve companion        → cyan

local TerminalRepTooltip = nil

local function GetOrCreateTerminalRepTooltip()
    if TerminalRepTooltip then
        return TerminalRepTooltip
    end

    local tooltip = CreateFrame("Frame", "XPBarTerminalRepTooltip", UIParent, "BackdropTemplate")
    tooltip:SetFrameStrata("TOOLTIP")
    tooltip:SetClampedToScreen(true)
    tooltip:Hide()

    tooltip:SetBackdrop({
        bgFile   = "Interface/Buttons/WHITE8X8",
        edgeFile = "Interface/Buttons/WHITE8X8",
        edgeSize = 1,
        insets   = {left = 1, right = 1, top = 1, bottom = 1},
    })
    tooltip:SetBackdropColor(0.02, 0.02, 0.02, 0.96)
    tooltip:SetBackdropBorderColor(0.00, 0.55, 0.00, 0.90)

    local text = tooltip:CreateFontString(nil, "OVERLAY")
    text:SetFont(TERMINAL_FONT, 11, "MONOCHROME")
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    text:SetPoint("TOPLEFT", tooltip, "TOPLEFT", TPAD, -TPAD)
    tooltip._text = text

    TerminalRepTooltip = tooltip
    return tooltip
end

local function BuildTerminalRepTooltipText(context)
    local formatter = Addon.TextFormatter
    local styleHelpers = Addon.UI and Addon.UI.StyleHelpers
    local lines = {}
    local sep = C_STATS .. string.rep(CH_SEP, 42) .. "|r"

    lines[#lines + 1] = C_LABEL .. "> REP_BAR" .. "|r"
    lines[#lines + 1] = sep

    local title = context.name or ""
    if context.isCompanion and context.currentLevel and context.currentLevel > 0 then
        title = title .. " Lv." .. tostring(context.currentLevel)
    elseif context.standingLabel and context.standingLabel ~= "" then
        title = title .. " - " .. context.standingLabel
    end
    lines[#lines + 1] = C_VALUE .. title .. "|r"

    if context.isMaxed then
        lines[#lines + 1] = C_STATS .. "progress:|r " .. C_VALUE .. "MAX|r"
    else
        local displayCurrent = context.current or 0
        local displayMax = context.max or 1
        local displayRemaining = math.max(0, displayMax - displayCurrent)

        if styleHelpers and styleHelpers.GetDisplayProgressValues then
            displayCurrent, displayMax, displayRemaining = styleHelpers.GetDisplayProgressValues(context)
        end

        lines[#lines + 1] = C_STATS .. "progress:|r " .. C_VALUE .. tostring(context.percent or 0) .. "%|r"
        if formatter and formatter.FormatNumber then
            local current = formatter:FormatNumber(displayCurrent, false)
            local maxValue = formatter:FormatNumber(displayMax, false)
            lines[#lines + 1] = C_STATS .. "current: |r" .. C_VALUE .. current .. " / " .. maxValue .. "|r"
        end
    end

    if context.sessionGained and context.sessionGained > 0 and formatter and formatter.FormatNumber then
        lines[#lines + 1] = C_STATS .. "gained:  |r" .. C_VALUE .. "+" .. formatter:FormatNumber(context.sessionGained, false) .. "|r"
    end
    if context.repPerHour and context.repPerHour > 0 and formatter and formatter.FormatNumber then
        lines[#lines + 1] = C_STATS .. "rate:    |r" .. C_VALUE .. formatter:FormatNumber(context.repPerHour, false) .. "/hr|r"
    end
    if context.timeToNextLevel and context.timeToNextLevel > 0 and formatter and formatter.FormatTime then
        lines[#lines + 1] = C_STATS .. "next:    |r" .. C_VALUE .. formatter:FormatTime(context.timeToNextLevel, true) .. "|r"
    end

    lines[#lines + 1] = ""
    lines[#lines + 1] = sep
    lines[#lines + 1] = C_STATS .. "right-click: reputation  |  shift+drag: move|r"

    return table.concat(lines, "\n")
end

local function ShowTerminalRepTooltip(owner, context)
    if not owner or not context then
        return
    end

    local tooltip = GetOrCreateTerminalRepTooltip()
    local text = tooltip._text

    -- Match terminal XP tooltip placement: prefer anchoring from the primary bar frame.
    local anchorOwner = owner
    if Addon.BarManager and Addon.BarManager.GetCurrentFrame then
        local primary = Addon.BarManager:GetCurrentFrame()
        if primary and primary:IsShown() then
            anchorOwner = primary
        end
    end

    text:SetWidth(0)
    text:SetText(BuildTerminalRepTooltipText(context))

    local tw = math.max(220, math.ceil(text:GetStringWidth()) + 1)
    local th = math.ceil(text:GetStringHeight()) + 1
    tooltip:SetSize(tw + TPAD * 2, th + TPAD * 2)
    text:SetWidth(tw)

    tooltip:ClearAllPoints()
    local _, centerY = anchorOwner:GetCenter()
    local screenHeight = UIParent:GetTop() or GetScreenHeight()
    if centerY and centerY < screenHeight / 2 then
        tooltip:SetPoint("BOTTOMLEFT", anchorOwner, "TOPLEFT", 0, 6)
    else
        tooltip:SetPoint("TOPLEFT", anchorOwner, "BOTTOMLEFT", 0, -6)
    end

    tooltip:Show()
end

local function HideTerminalRepTooltip()
    if TerminalRepTooltip then
        TerminalRepTooltip:Hide()
    end
end

-------------------------------------------------------------------
-- LINE BUILDER
-------------------------------------------------------------------

local function GetFillColor(context)
    if context.isCompanion then
        return C_COMPANION
    end
    if context.factionType == "major" or context.factionType == "paragon" then
        return C_MAJOR
    end
    local level = context.reactionLevel
    if level and STANDING_COLORS[level] then
        return STANDING_COLORS[level]
    end
    return Hex(0.00, 1.00, 0.00)  -- fallback: phosphor green
end

local function BuildRepLine(context)
    -- Progress ratio from context.percent (0-100 integer, same source as BuildLabel in flat)
    local ratio = math.max(0, math.min(1, (context.percent or 0) / 100))
    local filled = math.floor(ratio * BAR_CHARS + 0.5)
    local fillColor = GetFillColor(context)

    -- Coloured block bar: filled portion in standing colour, remainder in dim gray
    local inner = ""
    if filled > 0 then
        inner = inner .. fillColor .. string.rep(CH_DARK, filled) .. "|r"
    end
    if filled < BAR_CHARS then
        inner = inner .. C_EMPTY_COL .. string.rep(CH_EMPTY, BAR_CHARS - filled) .. "|r"
    end

    -- Faction name (truncate to 22 chars to keep the line tight)
    local name = context.name or "?"
    if #name > 22 then
        name = string.sub(name, 1, 21) .. "~"
    end

    -- Standing label or companion level
    local standing = ""
    if context.isCompanion and context.currentLevel and context.currentLevel > 0 then
        standing = string.format("Lv.%d", context.currentLevel)
    elseif context.standingLabel and context.standingLabel ~= "" then
        standing = context.standingLabel
    end

    -- Percentage or MAX
    local pct = context.isMaxed and "MAX" or string.format("%d%%", context.percent or 0)

    -- Session gained (omitted when zero)
    local sess = ""
    if context.sessionGained and context.sessionGained > 0 then
        sess = C_STATS .. "  sess:+" .. tostring(context.sessionGained) .. "|r"
    end

    return C_STATS .. "> rep |" .. "|r"
        .. " " .. C_LABEL .. name .. "|r"
        .. " " .. C_LABEL .. "[" .. "|r"
        .. inner
        .. C_LABEL .. "]" .. "|r"
        .. " " .. fillColor .. standing .. " " .. pct .. "|r"
        .. sess
end

-------------------------------------------------------------------
-- POSITION
-------------------------------------------------------------------

function StyleMixin:GetPositionConfigKey()
    return SharedStyleHelpers.GetSecondaryPositionConfigKey()
end

function StyleMixin:GetFallbackPosition()
    return SharedStyleHelpers.BuildConfiguredStyleCenterFallback(0, -36, 0, -36)
end

-------------------------------------------------------------------
-- SECONDARY BAR CONTRACT
-------------------------------------------------------------------

function StyleMixin:GetBroadcastEventName()
    return SharedStyleHelpers.GetSecondaryBroadcastEventName()
end

function StyleMixin:GetInitialContext()
    return SharedStyleHelpers.GetSecondaryInitialContext()
end

function StyleMixin:ResizeToScale()
    local width = BASE_WIDTH
    local height = BASE_HEIGHT

    self:SetSize(width, height)

    -- Keep the text line width synced to the scaled frame width.
    if self.RepLine and self.RepLine.SetWidth then
        self.RepLine:SetWidth(math.max(1, width - 16))
    end
end

function StyleMixin:Render(context)
    if not SharedStyleHelpers.BeginSecondaryRender(self, context) then
        return
    end

    if self.RepLine then
        self.RepLine:SetText(BuildRepLine(context))
    end
end

-------------------------------------------------------------------
-- INTERACTION
-------------------------------------------------------------------

function StyleMixin:OnEnter()
    if not self._lastContext or self._lastContext.isAvailable == false then
        return
    end
    local context = self._lastContext
    ShowTerminalRepTooltip(self, context)
end

function StyleMixin:OnLeave()
    HideTerminalRepTooltip()
end

function StyleMixin:OnMouseUp(button)
    SharedStyleHelpers.HandleStandardSecondaryMouseUp(self, button, self.OnRightClick)
end

function StyleMixin:OnRightClick()
    SharedStyleHelpers.OpenReputationPanel()
end

function StyleMixin:OnDragStart()
    SharedStyleHelpers.BeginSecondaryShiftDrag(self)
end

function StyleMixin:OnDragStop()
    SharedStyleHelpers.EndSecondaryDrag(self)
end

function StyleMixin:OnSecondaryLoad()
    self:ResizeToScale()
    self:ConfigureDragSupport()
    if self.RepLine then
        self.RepLine:SetFont(TERMINAL_FONT, 12, "MONOCHROME")
        self.RepLine:SetTextColor(1, 1, 1, 1)
    end
end

XPBarTerminalReputationMixin = CreateFromMixins(XPBarSecondaryBaseMixin, StyleMixin)
