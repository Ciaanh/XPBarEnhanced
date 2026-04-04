-- XP Bar Enhanced - Flat Companion Bar Style
-- Displays the Delve companion (Brann) XP progress as a simple flat status bar.

local Addon = XPBarEnhanced

---@class FlatCompanionBarMixin
FlatCompanionBarMixin = {}
local Mixin = FlatCompanionBarMixin

local BAR_COLOR = {r = 0.20, g = 0.80, b = 0.80}

-------------------------------------------------------------------
-- LIFECYCLE
-------------------------------------------------------------------

function Mixin:OnLoad()
    self:ClearAllPoints()
    self.Bar:SetStatusBarColor(BAR_COLOR.r, BAR_COLOR.g, BAR_COLOR.b)
    local db = XPBarEnhanced and XPBarEnhanced.db
    local pos = (db and db.companionBarPosition)
        or (XPBarEnhanced and XPBarEnhanced.defaults and XPBarEnhanced.defaults.companionBarPosition)
    if pos then
        self:SetPoint(pos.point, pos.relativeTo or "UIParent", pos.relativePoint, pos.x or 0, pos.y or 0)
    else
        self:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 54)
    end
end

function Mixin:OnShow()
    self._busHandle = Addon.EventBus:RegisterWithHandle(
        Addon.EventNames.COMPANION_BROADCAST_UPDATE,
        function(ctx)
            self:Render(ctx)
        end
    )
    if XPBarContextBuilder and XPBarContextBuilder.BuildCompanionContext then
        self:Render(XPBarContextBuilder.BuildCompanionContext())
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

    self.Bar:SetMinMaxValues(context.min, context.max)
    self.Bar:SetValue(context.current)

    -- Build label: "CompanionName Lv.X (percent%)"
    local label = context.name
    if context.currentLevel and context.currentLevel > 0 then
        label = label .. string.format(" Lv.%d", context.currentLevel)
    end
    if context.isMaxLevel then
        label = label .. " (MAX)"
    else
        label = label .. string.format(" (%d%%)", context.percent)
    end
    self.LabelContainer.Label:SetText(label)
end
