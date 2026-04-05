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

local function IsCustomStyle(styleMap, style)
    return style and styleMap and styleMap[style] ~= nil
end

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
            return nil
        end

        frame = CreateFrame("Frame", nil, UIParent, templateName)
        if not frame then
            error("SecondaryBarManager: failed to create frame from template: " .. templateName)
        end
        self._frames[key][style] = frame
    end
    return frame
end

function Manager:_SetStyle(key, style)
    self._currentStyles = self._currentStyles or {}
    self._frames = self._frames or {}

    if self._currentStyles[key] == style then
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
        return
    end

    local frame = self:_GetOrCreateFrame(key, style)
    if frame and frame.SetShown then
        frame:SetShown(true)
    end
end

-------------------------------------------------------------------
-- PUBLIC API
-------------------------------------------------------------------

function Manager:Initialize()
    local db = Addon.db or {}

    self:InstallBlizzardBarHooks()

    self:SetReputationStyle(db.reputationBarStyle or "none")
    self:SetCompanionStyle(db.companionBarStyle or "none")
    self:ApplyDefaultReputationBarVisibility()

    Addon.EventBus:Register(
        Addon.EventNames.CONFIG_UPDATED,
        "SecondaryBarManager_ConfigUpdated",
        function(_ctx)
            local d = Addon.db or {}
            self:SetReputationStyle(d.reputationBarStyle or "none")
            self:SetCompanionStyle(d.companionBarStyle or "none")
            self:ApplyDefaultReputationBarVisibility()
        end
    )
end

function Manager:ApplyDefaultReputationBarVisibility()
    local style = self._currentStyles and self._currentStyles["reputation"]
    local hasCustomReputationStyle = IsCustomStyle(TEMPLATE_MAP.reputation, style)

    if hasCustomReputationStyle then
        if _G.SecondaryStatusTrackingBarContainer then
            _G.SecondaryStatusTrackingBarContainer:Hide()
        end
    else
        if _G.SecondaryStatusTrackingBarContainer then
            _G.SecondaryStatusTrackingBarContainer:Show()
        end
    end
end

function Manager:InstallBlizzardBarHooks()
    if self._blizzardHooksInstalled then
        return
    end

    local container = _G.SecondaryStatusTrackingBarContainer
    if container and container.Show then
        hooksecurefunc(container, "Show", function()
            local style = self._currentStyles and self._currentStyles["reputation"]
            if IsCustomStyle(TEMPLATE_MAP.reputation, style) then
                container:Hide()
            end
        end)
    end
    if container and container.SetShown then
        hooksecurefunc(container, "SetShown", function(_, shown)
            local style = self._currentStyles and self._currentStyles["reputation"]
            if shown and IsCustomStyle(TEMPLATE_MAP.reputation, style) then
                container:Hide()
            end
        end)
    end

    self._blizzardHooksInstalled = true
end

function Manager:SetReputationStyle(style)
    xpcall(self._SetStyle, SafeCallErrorHandler, self, "reputation", style)
    self:ApplyDefaultReputationBarVisibility()
end

function Manager:SetCompanionStyle(style)
    xpcall(self._SetStyle, SafeCallErrorHandler, self, "companion", style)
end

function Manager:ResetBarPositions()
    local defaults = Addon.defaults or {}
    local posMap = {
        reputation = defaults.reputationBarPosition,
        companion  = defaults.companionBarPosition,
    }
    for key, defaultPos in pairs(posMap) do
        local style = self._currentStyles and self._currentStyles[key]
        if style and style ~= "none" then
            local frame = self._frames and self._frames[key] and self._frames[key][style]
            if frame and frame.ClearAllPoints and defaultPos then
                frame:ClearAllPoints()
                frame:SetPoint(
                    defaultPos.point,
                    defaultPos.relativeTo or "UIParent",
                    defaultPos.relativePoint,
                    defaultPos.x or 0,
                    defaultPos.y or 0
                )
            end
        end
    end
end

return Manager
