-- XP Bar Enhanced - Secondary Bar Base Mixin
-- Shared lifecycle contract for secondary bars (reputation/companion).

local Addon = XPBarEnhanced
local Utils = Addon.Utils

local function GetOptionValue(key, fallback)
    if Addon.Config and Addon.Config.GetOptionValue then
        local value = Addon.Config:GetOptionValue(key)
        if value ~= nil then
            return value
        end
    end
    return fallback
end

local function GetSettingsTable(key, createIfMissing)
    if Addon.Config and Addon.Config.GetSettingsTable then
        return Addon.Config:GetSettingsTable(key, createIfMissing)
    end

    Addon.db = Addon.db or {}
    if Addon.db[key] == nil and createIfMissing then
        Addon.db[key] = {}
    end
    return Addon.db[key]
end

---@class XPBarSecondaryBaseMixin
XPBarSecondaryBaseMixin = {}
Addon.UI.Mixins.SecondaryBase = XPBarSecondaryBaseMixin

local SecondaryBaseMixin = XPBarSecondaryBaseMixin

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

function SecondaryBaseMixin:SetDetachedInteractionEnabled(enabled)
    self._detachedInteractionEnabled = enabled and true or false
end

function SecondaryBaseMixin:IsDetachedInteractionEnabled()
    return self._detachedInteractionEnabled == true
end

function SecondaryBaseMixin:ApplyInitialPosition()
    self:ClearAllPoints()

    local key = self.GetPositionConfigKey and self:GetPositionConfigKey()
    local styleKey = self.GetPositionStyleKey and self:GetPositionStyleKey()
    local pos
    if key then
        local store = GetSettingsTable(key)
        if styleKey and store then
            pos = store[styleKey]
        elseif store then
            pos = store
        end
    end

    if pos then
        self:SetPoint(pos.point, pos.relativeTo or "UIParent", pos.relativePoint, pos.x or 0, pos.y or 0)
        return
    end

    local point, relativeTo, relativePoint, x, y = GetFallbackAnchor(self.GetFallbackPosition and self:GetFallbackPosition())
    self:SetPoint(point, relativeTo, relativePoint, x, y)
end

function SecondaryBaseMixin:OnShow()
    if self.OnSecondaryShow then
        self:OnSecondaryShow()
    end

    self:Subscribe()
    self:StartTextTicker()
    self:Refresh()
end

function SecondaryBaseMixin:OnHide()
    if self.OnSecondaryHide then
        self:OnSecondaryHide()
    end

    self:StopTextTicker()
    self:Unsubscribe()
    if self._fadeAnim and self._fadeAnim:IsPlaying() then
        self._fadeAnim:Stop()
    end
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

        local context = self_ref:GetLatestContext()
        if not context and self_ref.GetTextTickerContext then
            context = self_ref:GetTextTickerContext()
        end

        xpcall(self_ref.OnTextTick, Utils.ReportError, self_ref, context)
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
    if type(eventName) == "table" then
        self._busHandles = self._busHandles or {}
        for _, name in ipairs(eventName) do
            local handle = Addon.EventBus:RegisterWithHandle(name, function()
                if self_ref then
                    self_ref:MarkDirty(nil, true)
                end
            end)
            if handle then
                table.insert(self._busHandles, handle)
            end
        end
        return
    end

    self._busHandle = Addon.EventBus:RegisterWithHandle(eventName, function(ctx)
        if self_ref then
            self_ref:MarkDirty(ctx)
        end
    end)
end

function SecondaryBaseMixin:Unsubscribe()
    if self._busHandles then
        for _, handle in ipairs(self._busHandles) do
            if handle and handle.Unregister then
                handle:Unregister()
            end
        end
        self._busHandles = nil
    end

    if self._busHandle then
        self._busHandle:Unregister()
        self._busHandle = nil
    end
end

function SecondaryBaseMixin:Refresh()
    if not self.Render then
        return
    end

    local context = self:GetLatestContext()
    if context then
        xpcall(self.Render, Utils.ReportError, self, context)
    end
end

function SecondaryBaseMixin:GetLatestContext()
    if self._pendingContext == false then
        if self.GetInitialContext then
            return self:GetInitialContext()
        end

        return nil
    end

    local context = self._pendingContext or self._lastContext
    if context then
        return context
    end

    if self.GetInitialContext then
        return self:GetInitialContext()
    end

    return nil
end

function SecondaryBaseMixin:MarkDirty(context, forceRefresh)
    if forceRefresh and context == nil then
        self._pendingContext = false
    else
        self._pendingContext = context
    end

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

        if pending == false then
            xpcall(self_ref.Refresh, Utils.ReportError, self_ref)
        elseif pending then
            xpcall(self_ref.Render, Utils.ReportError, self_ref, pending)
        else
            xpcall(self_ref.Refresh, Utils.ReportError, self_ref)
        end
    end)
end

-------------------------------------------------------------------
-- FADE/ANIMATION SUPPORT
-------------------------------------------------------------------

function SecondaryBaseMixin:FadeToAlpha(targetAlpha)
    local fadeSpeed = targetAlpha == 1 and GetOptionValue("secondaryFadeInSpeed", (Addon.defaults and Addon.defaults.secondaryFadeInSpeed or 0.3))
                      or GetOptionValue("secondaryFadeOutSpeed", (Addon.defaults and Addon.defaults.secondaryFadeOutSpeed or 0.5))
    
    if not self:IsShown() then
        self:SetAlpha(targetAlpha)
        return
    end
    
    local currentAlpha = self:GetAlpha() or 0
    if math.abs(currentAlpha - targetAlpha) < 0.01 then
        return
    end
    
    if not self._fadeAnim then
        self._fadeAnim = self:CreateAnimationGroup()
        self._fadeAlpha = self._fadeAnim:CreateAnimation("Alpha")
        self._fadeAnim:SetLooping("NONE")
        self._fadeAnim:SetScript("OnFinished", function()
            if self and self._fadeTargetAlpha ~= nil then
                self:SetAlpha(self._fadeTargetAlpha)
            end
        end)
    end

    if self._fadeAnim:IsPlaying() then
        self._fadeAnim:Stop()
    end

    self._fadeTargetAlpha = targetAlpha
    self._fadeAlpha:SetDuration(fadeSpeed)
    self._fadeAlpha:SetFromAlpha(currentAlpha)
    self._fadeAlpha:SetToAlpha(targetAlpha)

    self._fadeAnim:Play()
end

-------------------------------------------------------------------
-- INTERACTION SAFETY SUPPORT
-------------------------------------------------------------------

function SecondaryBaseMixin:ConfigureDragSupport()
    if not self.SetMovable then
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        if self._dragSetupPending then
            return
        end

        self._dragSetupPending = true
        if not self._dragSetupFrame then
            self._dragSetupFrame = CreateFrame("Frame")
        end

        self._dragSetupFrame:SetScript("OnEvent", function(frame, event)
            if event ~= "PLAYER_REGEN_ENABLED" then
                return
            end

            frame:UnregisterEvent("PLAYER_REGEN_ENABLED")
            self._dragSetupPending = nil
            self:ConfigureDragSupport()
        end)
        self._dragSetupFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end

    self:SetMovable(true)
    self:SetClampedToScreen(true)
    if self.RegisterForDrag then
        self:RegisterForDrag("LeftButton")
    end
    self._dragSetupPending = nil
end

-------------------------------------------------------------------
-- POSITION PERSISTENCE SUPPORT
-------------------------------------------------------------------

-- Returns the primary bar style key used to namespace per-style saved positions.
-- Override in a style mixin to return a different key.
function SecondaryBaseMixin:GetPositionStyleKey()
    return GetOptionValue("barStyle")
end

function SecondaryBaseMixin:SavePosition()
    local configKey = self.GetPositionConfigKey and self:GetPositionConfigKey()
    local styleKey = self.GetPositionStyleKey and self:GetPositionStyleKey()
    if not configKey then
        return
    end

    local positions = GetSettingsTable(configKey, true)

    -- Normalize to UIParent BOTTOMLEFT pixel coordinates so the saved value
    -- survives reload. Frame object references from GetPoint() can't be
    -- serialized into SavedVariables.
    local left = self:GetLeft()
    local bottom = self:GetBottom()
    if not left or not bottom then
        return
    end

    local posData = {
        point = "BOTTOMLEFT",
        relativeTo = "UIParent",
        relativePoint = "BOTTOMLEFT",
        x = left,
        y = bottom,
    }

    if styleKey then
        positions[styleKey] = posData
    else
        local storage = Addon.Config and Addon.Config.GetSettingsStorage and Addon.Config:GetSettingsStorage() or Addon.db
        storage[configKey] = posData
    end
end

function SecondaryBaseMixin:ResetPosition()
    local configKey = self.GetPositionConfigKey and self:GetPositionConfigKey()
    local styleKey = self.GetPositionStyleKey and self:GetPositionStyleKey()
    if not configKey then
        return
    end

    local positions = GetSettingsTable(configKey)
    if styleKey and positions then
        positions[styleKey] = nil
    else
        local storage = Addon.Config and Addon.Config.GetSettingsStorage and Addon.Config:GetSettingsStorage() or Addon.db
        storage[configKey] = nil
    end
    self:ApplyInitialPosition()
end

