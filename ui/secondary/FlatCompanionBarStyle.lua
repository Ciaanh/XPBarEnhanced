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
    print("[XPBE-DBG] FlatCompanionBarMixin:OnLoad fired")
    self:ClearAllPoints()
    self:SetPoint("CENTER", UIParent, "CENTER", 0, -22)
    self.Bar:SetStatusBarColor(BAR_COLOR.r, BAR_COLOR.g, BAR_COLOR.b)
    print("[XPBE-DBG] FlatCompanionBarMixin:OnLoad Bar=" .. tostring(self.Bar) .. " LabelContainer=" .. tostring(self.LabelContainer))
end

function Mixin:OnShow()
    print("[XPBE-DBG] FlatCompanionBarMixin:OnShow fired")
    self._busHandle = Addon.EventBus:RegisterWithHandle(
        Addon.EventNames.COMPANION_BROADCAST_UPDATE,
        function(_)
            if XPBarContextBuilder and XPBarContextBuilder.BuildCompanionContext then
                self:Render(XPBarContextBuilder.BuildCompanionContext())
            end
        end
    )
    if XPBarContextBuilder and XPBarContextBuilder.BuildCompanionContext then
        local ctx = XPBarContextBuilder.BuildCompanionContext()
        print("[XPBE-DBG] FlatCompanionBarMixin:OnShow initial context isAvailable=" .. tostring(ctx.isAvailable) .. " name=" .. tostring(ctx.name))
        self:Render(ctx)
    else
        print("[XPBE-DBG] FlatCompanionBarMixin:OnShow XPBarContextBuilder.BuildCompanionContext not found!")
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
        print("[XPBE-DBG] FlatCompanionBarMixin:Render context is nil")
        return
    end

    print("[XPBE-DBG] FlatCompanionBarMixin:Render isAvailable=" .. tostring(context.isAvailable) .. " name=" .. tostring(context.name) .. " current=" .. tostring(context.current) .. " max=" .. tostring(context.max))

    if not context.isAvailable then
        print("[XPBE-DBG] FlatCompanionBarMixin:Render hiding (isAvailable=false)")
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
