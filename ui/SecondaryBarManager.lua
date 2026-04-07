-- XP Bar Enhanced - Secondary Bar Manager
-- Manages the unified tracked-reputation secondary progress bar.

local Addon = XPBarEnhanced
Addon.SecondaryBarManager = Addon.SecondaryBarManager or {}
local Manager = Addon.SecondaryBarManager

local function DeriveSecondaryStyle()
    local db = Addon.db or {}
    if not db.showSecondaryBar then
        return "none"
    end
    local primaryStyle = db.barStyle or "none"
    if primaryStyle == "none" then
        return "none"
    end
    return "flat"
end

local TEMPLATE_MAP = {
    flat = "FlatReputationBarTemplate",
}

local function IsCustomStyle(style)
    return style and TEMPLATE_MAP[style] ~= nil
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

function Manager:_GetOrCreateFrame(style)
    self._frames = self._frames or {}

    local frame = self._frames[style]
    if not frame then
        local templateName = TEMPLATE_MAP[style]
        if not templateName then
            return nil
        end

        frame = CreateFrame("Frame", nil, UIParent, templateName)
        if not frame then
            error("SecondaryBarManager: failed to create frame from template: " .. templateName)
        end
        self._frames[style] = frame
    end
    return frame
end

function Manager:_SetStyle(style)
    self._frames = self._frames or {}

    if self._currentStyle == style then
        return
    end

    for _, frame in pairs(self._frames) do
        if frame and frame.SetShown then
            frame:SetShown(false)
        end
    end

    self._currentStyle = style

    if style == "none" then
        return
    end

    local frame = self:_GetOrCreateFrame(style)
    if frame and frame.SetShown then
        frame:SetShown(true)
    end
end

-------------------------------------------------------------------
-- PUBLIC API
-------------------------------------------------------------------

function Manager:Initialize()
    self:InstallBlizzardBarHooks()

    self:SetSecondaryStyle(DeriveSecondaryStyle())
    self:ApplyDefaultReputationBarVisibility()
    self:ReapplyAttachedPositions()

    Addon.EventBus:Register(
        Addon.EventNames.CONFIG_UPDATED,
        "SecondaryBarManager_ConfigUpdated",
        function(_ctx)
            self:SetSecondaryStyle(DeriveSecondaryStyle())
            self:ApplyDefaultReputationBarVisibility()
            self:ReapplyAttachedPositions()
        end
    )
end

-- Stack active secondary bars above the primary XP bar when attached mode is on.
-- When attached mode is off, restores each bar to its saved/fallback position.
function Manager:ReapplyAttachedPositions()
    local db = Addon.db or {}

    if not db.secondaryBarsAttached then
        local frame = self:GetCurrentFrame()
        if frame and frame.ApplyInitialPosition then
            frame:ApplyInitialPosition()
        end
        return
    end

    local frame = self:GetCurrentFrame()
    if not frame then
        return
    end

    local primaryFrame = Addon.BarManager and Addon.BarManager:GetCurrentFrame()
    if not primaryFrame then
        return
    end

    frame:ClearAllPoints()
    frame:SetPoint("BOTTOM", primaryFrame, "TOP", 0, 2)
end

function Manager:GetCurrentFrame()
    local style = self._currentStyle
    if not style or style == "none" then
        return nil
    end

    return self._frames and self._frames[style] or nil
end

function Manager:ApplyDefaultReputationBarVisibility()
    local hasCustomReputationStyle = IsCustomStyle(self._currentStyle)

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
            if IsCustomStyle(self._currentStyle) then
                container:Hide()
            end
        end)
    end
    if container and container.SetShown then
        hooksecurefunc(container, "SetShown", function(_, shown)
            if shown and IsCustomStyle(self._currentStyle) then
                container:Hide()
            end
        end)
    end

    self._blizzardHooksInstalled = true
end

function Manager:SetSecondaryStyle(style)
    xpcall(self._SetStyle, SafeCallErrorHandler, self, style)
    self:ApplyDefaultReputationBarVisibility()
end

function Manager:ResetBarPositions()
    local defaults = Addon.defaults or {}
    local db = Addon.db or {}
    local posInfo = {configKey = "secondaryBarPosition", defaultPos = defaults.secondaryBarPosition}

    if db[posInfo.configKey] then
        db[posInfo.configKey] = nil
    end

    local frame = self:GetCurrentFrame()
    if frame and frame.ResetPosition then
        frame:ResetPosition()
    elseif frame and frame.ClearAllPoints and posInfo.defaultPos then
        frame:ClearAllPoints()
        frame:SetPoint(
            posInfo.defaultPos.point,
            posInfo.defaultPos.relativeTo or "UIParent",
            posInfo.defaultPos.relativePoint,
            posInfo.defaultPos.x or 0,
            posInfo.defaultPos.y or 0
        )
    end

    self:ReapplyAttachedPositions()
end

return Manager
