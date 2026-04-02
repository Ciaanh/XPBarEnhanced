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
    print("[XPBE-DBG] FlatReputationBarMixin:OnLoad fired")
    self:ClearAllPoints()
    self:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    print("[XPBE-DBG] FlatReputationBarMixin:OnLoad Bar=" .. tostring(self.Bar) .. " LabelContainer=" .. tostring(self.LabelContainer))
end

function Mixin:OnShow()
    print("[XPBE-DBG] FlatReputationBarMixin:OnShow fired")
    self._busHandle = Addon.EventBus:RegisterWithHandle(
        Addon.EventNames.REPUTATION_BROADCAST_UPDATE,
        function(_)
            if XPBarContextBuilder and XPBarContextBuilder.BuildReputationContext then
                self:Render(XPBarContextBuilder.BuildReputationContext())
            end
        end
    )
    if XPBarContextBuilder and XPBarContextBuilder.BuildReputationContext then
        local ctx = XPBarContextBuilder.BuildReputationContext()
        print("[XPBE-DBG] FlatReputationBarMixin:OnShow initial context isAvailable=" .. tostring(ctx.isAvailable) .. " name=" .. tostring(ctx.name))
        self:Render(ctx)
    else
        print("[XPBE-DBG] FlatReputationBarMixin:OnShow XPBarContextBuilder.BuildReputationContext not found!")
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
        print("[XPBE-DBG] FlatReputationBarMixin:Render context is nil")
        return
    end

    print("[XPBE-DBG] FlatReputationBarMixin:Render isAvailable=" .. tostring(context.isAvailable) .. " name=" .. tostring(context.name) .. " current=" .. tostring(context.current) .. " max=" .. tostring(context.max))

    if not context.isAvailable then
        print("[XPBE-DBG] FlatReputationBarMixin:Render hiding (isAvailable=false)")
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
