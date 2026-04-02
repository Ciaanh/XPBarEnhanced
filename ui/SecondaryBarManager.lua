-- XP Bar Enhanced - Secondary Bar Manager
-- Manages the reputation and companion secondary progress bars independently.
-- Each bar has its own style setting: "none" (hidden) or "flat".

local Addon = XPBarEnhanced
Addon.SecondaryBarManager = Addon.SecondaryBarManager or {}
local Manager = Addon.SecondaryBarManager

local TEMPLATE_MAP = {
    reputation = { flat = "FlatReputationBarTemplate" },
    companion  = { flat = "FlatCompanionBarTemplate" },
}

-------------------------------------------------------------------
-- INTERNAL
-------------------------------------------------------------------

local function SafeCallErrorHandler(err)
    if CallErrorHandler then
        CallErrorHandler(err)
    else
        print(tostring(err))
    end
end

function Manager:_GetOrCreateFrame(key, style)
    self._frames = self._frames or {}
    self._frames[key] = self._frames[key] or {}

    local frame = self._frames[key][style]
    if not frame then
        local templates = TEMPLATE_MAP[key]
        local templateName = templates and templates[style]
        if not templateName then
            print("[XPBE-DBG] _GetOrCreateFrame: no templateName for key=" .. tostring(key) .. " style=" .. tostring(style))
            return nil
        end

        print("[XPBE-DBG] _GetOrCreateFrame: CreateFrame key=" .. key .. " template=" .. templateName)
        frame = CreateFrame("Frame", nil, UIParent, templateName)
        if not frame then
            error("SecondaryBarManager: failed to create frame from template: " .. templateName)
        end
        print("[XPBE-DBG] _GetOrCreateFrame: frame created ok, IsShown=" .. tostring(frame:IsShown()))
        self._frames[key][style] = frame
    end
    return frame
end

function Manager:_SetStyle(key, style)
    self._currentStyles = self._currentStyles or {}
    self._frames = self._frames or {}

    print("[XPBE-DBG] _SetStyle key=" .. tostring(key) .. " style=" .. tostring(style) .. " current=" .. tostring(self._currentStyles[key]))

    if self._currentStyles[key] == style then
        print("[XPBE-DBG] _SetStyle: no change, skipping")
        return
    end

    -- Hide all existing frames for this key
    for _, frame in pairs(self._frames[key] or {}) do
        if frame and frame.SetShown then
            frame:SetShown(false)
        end
    end

    self._currentStyles[key] = style

    if style == "none" then
        print("[XPBE-DBG] _SetStyle: style=none, bar hidden")
        return
    end

    local frame = self:_GetOrCreateFrame(key, style)
    if frame and frame.SetShown then
        print("[XPBE-DBG] _SetStyle: calling SetShown(true) on frame")
        frame:SetShown(true)
        print("[XPBE-DBG] _SetStyle: after SetShown, IsShown=" .. tostring(frame:IsShown()))
    else
        print("[XPBE-DBG] _SetStyle: frame is nil or missing SetShown!")
    end
end

-------------------------------------------------------------------
-- PUBLIC API
-------------------------------------------------------------------

function Manager:Initialize()
    local db = Addon.db or {}

    print("[XPBE-DBG] SecondaryBarManager:Initialize reputationBarStyle=" .. tostring(db.reputationBarStyle) .. " companionBarStyle=" .. tostring(db.companionBarStyle))

    self:SetReputationStyle(db.reputationBarStyle or "none")
    self:SetCompanionStyle(db.companionBarStyle or "none")

    Addon.EventBus:Register(
        Addon.EventNames.CONFIG_UPDATED,
        "SecondaryBarManager_ConfigUpdated",
        function()
            local d = Addon.db or {}
            self:SetReputationStyle(d.reputationBarStyle or "none")
            self:SetCompanionStyle(d.companionBarStyle or "none")
        end
    )
end

function Manager:SetReputationStyle(style)
    xpcall(self._SetStyle, SafeCallErrorHandler, self, "reputation", style)
end

function Manager:SetCompanionStyle(style)
    xpcall(self._SetStyle, SafeCallErrorHandler, self, "companion", style)
end

function Manager:OnEnteringWorld()
    self._frames = self._frames or {}
    self._currentStyles = self._currentStyles or {}

    if self._currentStyles["reputation"] and self._currentStyles["reputation"] ~= "none" then
        local frame = self._frames["reputation"] and self._frames["reputation"][self._currentStyles["reputation"]]
        if frame and frame:IsShown() and frame.Render and XPBarContextBuilder then
            xpcall(frame.Render, SafeCallErrorHandler, frame, XPBarContextBuilder.BuildReputationContext())
        end
    end

    if self._currentStyles["companion"] and self._currentStyles["companion"] ~= "none" then
        local frame = self._frames["companion"] and self._frames["companion"][self._currentStyles["companion"]]
        if frame and frame:IsShown() and frame.Render and XPBarContextBuilder then
            xpcall(frame.Render, SafeCallErrorHandler, frame, XPBarContextBuilder.BuildCompanionContext())
        end
    end
end

return Manager
