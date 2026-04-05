-- XP Bar Enhanced - Secondary Bar Base Mixin
-- Shared lifecycle contract for secondary bars (reputation/companion).

local Addon = XPBarEnhanced

---@class XPBarSecondaryBaseMixin
XPBarSecondaryBaseMixin = {}
Addon.UI.Mixins.SecondaryBase = XPBarSecondaryBaseMixin

local SecondaryBaseMixin = XPBarSecondaryBaseMixin

local function SafeCallErrorHandler(err)
    if CallErrorHandler then
        CallErrorHandler(err)
    else
        print(tostring(err))
    end
end

local function GetFallbackAnchor(anchor)
    if not anchor then
        return "BOTTOM", "UIParent", "BOTTOM", 0, 0
    end

    return anchor.point or "BOTTOM",
        anchor.relativeTo or "UIParent",
        anchor.relativePoint or anchor.point or "BOTTOM",
        anchor.x or 0,
        anchor.y or 0
end

function SecondaryBaseMixin:OnLoad()
    if self.OnSecondaryLoad then
        self:OnSecondaryLoad()
    end

    self:ApplyInitialPosition()
end

function SecondaryBaseMixin:ApplyInitialPosition()
    self:ClearAllPoints()

    local key = self.GetPositionConfigKey and self:GetPositionConfigKey()
    local db = Addon and Addon.db
    local defaults = Addon and Addon.defaults
    local pos = (key and db and db[key]) or (key and defaults and defaults[key])

    if pos then
        self:SetPoint(pos.point, pos.relativeTo or "UIParent", pos.relativePoint, pos.x or 0, pos.y or 0)
        return
    end

    local point, relativeTo, relativePoint, x, y = GetFallbackAnchor(self.GetFallbackPosition and self:GetFallbackPosition())
    self:SetPoint(point, relativeTo, relativePoint, x, y)
end

function SecondaryBaseMixin:OnShow()
    self:Subscribe()
    self:StartTextTicker()
    self:Refresh()
end

function SecondaryBaseMixin:OnHide()
    self:StopTextTicker()
    self:Unsubscribe()
    self._dirty = nil
    self._pendingContext = nil
end

function SecondaryBaseMixin:StartTextTicker()
    self:StopTextTicker()

    if not self.OnTextTick then
        return
    end

    local interval = self.GetTextTickerInterval and self:GetTextTickerInterval() or nil
    if not interval or interval <= 0 then
        return
    end

    local self_ref = self
    self._textTicker = C_Timer.NewTicker(interval, function()
        if not self_ref or not self_ref:IsShown() then
            return
        end

        local context = nil
        if self_ref.GetTextTickerContext then
            context = self_ref:GetTextTickerContext()
        elseif self_ref.GetInitialContext then
            context = self_ref:GetInitialContext()
        end

        xpcall(self_ref.OnTextTick, SafeCallErrorHandler, self_ref, context)
    end)
end

function SecondaryBaseMixin:StopTextTicker()
    if self._textTicker then
        self._textTicker:Cancel()
        self._textTicker = nil
    end
end

function SecondaryBaseMixin:Subscribe()
    local eventName = self.GetBroadcastEventName and self:GetBroadcastEventName()
    if not eventName or not Addon.EventBus or not Addon.EventBus.RegisterWithHandle then
        return
    end

    local self_ref = self
    self._busHandle = Addon.EventBus:RegisterWithHandle(eventName, function(ctx)
        if self_ref then
            self_ref:MarkDirty(ctx)
        end
    end)
end

function SecondaryBaseMixin:Unsubscribe()
    if self._busHandle then
        self._busHandle:Unregister()
        self._busHandle = nil
    end
end

function SecondaryBaseMixin:Refresh()
    if not self.Render then
        return
    end

    local context = self.GetInitialContext and self:GetInitialContext()
    if context then
        xpcall(self.Render, SafeCallErrorHandler, self, context)
    end
end

function SecondaryBaseMixin:MarkDirty(context)
    self._pendingContext = context

    if self._dirty then
        return
    end

    self._dirty = true
    local self_ref = self
    local runFn = RunNextFrame or function(fn)
        C_Timer.After(0, fn)
    end

    runFn(function()
        if not self_ref then
            return
        end

        local pending = self_ref._pendingContext
        self_ref._pendingContext = nil
        self_ref._dirty = nil

        if not self_ref:IsShown() then
            return
        end

        if pending then
            xpcall(self_ref.Render, SafeCallErrorHandler, self_ref, pending)
        else
            xpcall(self_ref.Refresh, SafeCallErrorHandler, self_ref)
        end
    end)
end
