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

---@class XPBarTerminalReputationMixin
XPBarTerminalReputationMixin = {}
local StyleMixin = {}

-------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------

local TERMINAL_FONT = "Interface\\AddOns\\XPBarEnhanced\\fonts\\DejaVuSansMono.ttf"
local BAR_CHARS = 20

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
    return "secondaryBarPositions"
end

function StyleMixin:GetFallbackPosition()
    local db = Addon and Addon.db
    local configuredStyle = db and db.barStyle
    if configuredStyle and configuredStyle ~= "none" then
        local barDefPos = Addon.defaults
            and Addon.defaults.barPositions
            and Addon.defaults.barPositions[configuredStyle]
        if barDefPos then
            return {
                point         = barDefPos.point or "CENTER",
                relativeTo    = barDefPos.relativeTo or "UIParent",
                relativePoint = barDefPos.relativePoint or "CENTER",
                x             = barDefPos.x or 0,
                -- Below primary: half of primary height (21) + gap (4) + half of secondary (11) = 36
                y             = (barDefPos.y or 0) - 36,
            }
        end
    end
    -- Terminal primary has no barPositions default; place below screen center.
    return {
        point         = "CENTER",
        relativeTo    = "UIParent",
        relativePoint = "CENTER",
        x             = 0,
        y             = -36,
    }
end

-------------------------------------------------------------------
-- SECONDARY BAR CONTRACT
-------------------------------------------------------------------

function StyleMixin:GetBroadcastEventName()
    return Addon.EventNames.REPUTATION_BROADCAST_UPDATE
end

function StyleMixin:GetInitialContext()
    if Addon.ReputationSession and Addon.ReputationSession.GetCurrentContext then
        return Addon.ReputationSession:GetCurrentContext()
    end
    return nil
end

function StyleMixin:Render(context)
    if not context then
        return
    end

    local wasAvailable = self._lastContext and self._lastContext.isAvailable
    local isAvailable = context.isAvailable

    self._lastContext = context

    if wasAvailable and not isAvailable then
        self:FadeToAlpha(0)
        return
    end

    if not isAvailable then
        self:SetAlpha(0)
        return
    end

    if not wasAvailable then
        self:FadeToAlpha(1)
    else
        self:SetAlpha(1)
    end

    if self.RepLine then
        self.RepLine:SetText(BuildRepLine(context))
    end
end

-------------------------------------------------------------------
-- INTERACTION
-------------------------------------------------------------------

function StyleMixin:OnEnter()
    if not GameTooltip or not self._lastContext then
        return
    end

    local context = self._lastContext
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(context.name, 1, 1, 1)

    if context.isCompanion and context.currentLevel and context.currentLevel > 0 then
        GameTooltip:AddLine(string.format("Level: %d", context.currentLevel), 0.7, 0.7, 0.7)
    elseif context.standingLabel and context.standingLabel ~= "" then
        GameTooltip:AddLine(context.standingLabel, 0.7, 0.7, 0.7)
    end

    if context.isMaxed then
        GameTooltip:AddLine("Progress: MAX", 0.7, 1, 0.7)
    else
        local TextFormatter = Addon.TextFormatter
        local progressText = TextFormatter:FormatPercent(context.current, context.max)
        GameTooltip:AddLine(string.format("Progress: %s", progressText), 0.7, 1, 0.7)
    end

    if context.sessionGained and context.sessionGained > 0 then
        local TextFormatter = Addon.TextFormatter
        local gained = TextFormatter:FormatNumber(context.sessionGained, false)
        GameTooltip:AddLine(string.format("Gained: +%s", gained), 0.5, 1, 0.5)
    end

    if context.repPerHour and context.repPerHour > 0 then
        local TextFormatter = Addon.TextFormatter
        local rate = TextFormatter:FormatNumber(context.repPerHour, false)
        GameTooltip:AddLine(string.format("Rate: %s/hr", rate), 0.5, 0.8, 1)
    end

    if context.timeToNextLevel and context.timeToNextLevel > 0 then
        local TextFormatter = Addon.TextFormatter
        local timeStr = TextFormatter:FormatTime(context.timeToNextLevel, true)
        GameTooltip:AddLine(string.format("Next: %s", timeStr), 0.8, 0.8, 0.5)
    end

    GameTooltip:AddLine("Click to open Reputation", 0.4, 0.4, 0.4)
    GameTooltip:Show()
end

function StyleMixin:OnLeave()
    if GameTooltip then
        GameTooltip:Hide()
    end
end

function StyleMixin:OnMouseUp(button)
    if self.__isDragging then
        self:StopMovingOrSizing()
        self.__isDragging = nil
        if self.SavePosition then
            self:SavePosition()
        end
        return
    end

    if button == "LeftButton" and not IsShiftKeyDown() then
        self:OnLeftClick()
    end
end

function StyleMixin:OnLeftClick()
    if ToggleCharacter then
        ToggleCharacter("ReputationFrame")
    end
end

function StyleMixin:OnDragStart()
    if not IsShiftKeyDown() then
        return
    end

    local AddonGlobal = XPBarEnhanced
    if not AddonGlobal.db or AddonGlobal.db.barLocked then
        return
    end

    if AddonGlobal.db.secondaryBarsAttached then
        local primaryFrame = Addon.BarManager and Addon.BarManager:GetCurrentFrame()
        if primaryFrame then
            return
        end
    end

    if InCombatLockdown and InCombatLockdown() then
        return
    end

    self:StartMoving()
    self.__isDragging = true
end

function StyleMixin:OnDragStop()
    self.__isDragging = nil
    local db = Addon and Addon.db
    if db and db.secondaryBarsAttached then
        local primaryFrame = Addon.BarManager and Addon.BarManager:GetCurrentFrame()
        if primaryFrame then
            self:StopMovingOrSizing()
            return
        end
    end

    self:StopMovingOrSizing()
    self:SetUserPlaced(true)
    self:SavePosition()
end

function StyleMixin:OnSecondaryLoad()
    self:ConfigureDragSupport()
    -- Override XML inherited font with the same monospace face used by the primary terminal bar.
    if self.RepLine then
        self.RepLine:SetFont(TERMINAL_FONT, 12, "MONOCHROME")
        self.RepLine:SetTextColor(1, 1, 1, 1)
    end
end

XPBarTerminalReputationMixin = CreateFromMixins(XPBarSecondaryBaseMixin, StyleMixin)
