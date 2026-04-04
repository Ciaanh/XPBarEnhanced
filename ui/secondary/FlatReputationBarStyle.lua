-- XP Bar Enhanced - Flat Reputation Bar Style
-- Displays the watched faction's reputation progress as a simple flat status bar.

local Addon = XPBarEnhanced

---@class FlatReputationBarMixin
FlatReputationBarMixin = {}
local Mixin = FlatReputationBarMixin

local FACTION_COLORS = {
    standard   = {r = 0.70, g = 0.30, b = 0.85},
    friendship = {r = 0.20, g = 0.85, b = 0.30},
    major      = {r = 0.20, g = 0.60, b = 1.00},
    paragon    = {r = 0.95, g = 0.75, b = 0.10},
}

local function GetFactionColor(factionType)
    return FACTION_COLORS[factionType] or FACTION_COLORS.standard
end

-------------------------------------------------------------------
-- LIFECYCLE
-------------------------------------------------------------------

function Mixin:OnLoad()
    self:ClearAllPoints()
    local db = XPBarEnhanced and XPBarEnhanced.db
    local pos = (db and db.reputationBarPosition)
        or (XPBarEnhanced and XPBarEnhanced.defaults and XPBarEnhanced.defaults.reputationBarPosition)
    if pos then
        self:SetPoint(pos.point, pos.relativeTo or "UIParent", pos.relativePoint, pos.x or 0, pos.y or 0)
    else
        self:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 34)
    end
end

function Mixin:OnShow()
    self._busHandle = Addon.EventBus:RegisterWithHandle(
        Addon.EventNames.REPUTATION_BROADCAST_UPDATE,
        function(ctx)
            self:Render(ctx)
        end
    )
    if XPBarContextBuilder and XPBarContextBuilder.BuildReputationContext then
        self:Render(XPBarContextBuilder.BuildReputationContext())
    end
end

function Mixin:OnHide()
    if self._busHandle then
        self._busHandle.Unregister()
        self._busHandle = nil
    end
end

-------------------------------------------------------------------
-- RENDER
-------------------------------------------------------------------

function Mixin:Render(context)
    if not context then
        return
    end

    if not context.isAvailable then
        self:SetAlpha(0)
        return
    end

    self:SetAlpha(1)

    local color = GetFactionColor(context.factionType)
    self.Bar:SetMinMaxValues(context.min, context.max)
    self.Bar:SetValue(context.current)
    self.Bar:SetStatusBarColor(color.r, color.g, color.b)

    -- Build label: "FactionName - Standing (percent%)"
    local label = context.name
    if context.standingLabel and context.standingLabel ~= "" then
        label = label .. " - " .. context.standingLabel
    end
    if context.isMaxed then
        label = label .. " (MAX)"
    else
        label = label .. string.format(" (%d%%)", context.percent)
    end
    self.LabelContainer.Label:SetText(label)
end
