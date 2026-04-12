-- XP Bar Enhanced - Secondary Bar Manager
-- Manages the unified tracked-reputation secondary progress bar.

local Addon = XPBarEnhanced
Addon.SecondaryBarManager = Addon.SecondaryBarManager or {}
local Manager = Addon.SecondaryBarManager
local Utils = Addon.Utils

local TEMPLATE_MAP = {
    flat = "FlatReputationBarTemplate",
}

local function DeriveSecondaryStyle()
    local db = Addon.db or {}
    if not db.showSecondaryBar then
        return "none"
    end
    -- Use db.barStyle (user preference) not runtime style — secondary bar should
    -- remain visible at max level even though the primary bar hides itself.
    -- Only show a secondary bar when a matching template exists for the selected style.
    local primaryStyle = db.barStyle or "none"
    if TEMPLATE_MAP[primaryStyle] then
        return primaryStyle
    end
    return "none"
end

local function IsCustomStyle(style)
    return style and TEMPLATE_MAP[style] ~= nil
end

-- Returns true when our secondary bar is active at max level and Blizzard
-- would otherwise promote the reputation bar into the main status bar container.
local function ShouldSuppressMainContainer()
    local barManagerStyle = Addon.BarManager and Addon.BarManager.currentStyle
    local barManagerIdle = not barManagerStyle or barManagerStyle == "none"
    return IsCustomStyle(Manager._currentStyle) and barManagerIdle
end

function Manager:ShouldSuppressMainContainer()
    return ShouldSuppressMainContainer()
end

-------------------------------------------------------------------
-- INTERNAL
-------------------------------------------------------------------

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
-- When attached mode is off, or when at max level (primary bar hidden), restores
-- each bar to its saved/fallback position.
function Manager:ReapplyAttachedPositions()
    local db = Addon.db or {}
    local frame = self:GetCurrentFrame()
    if not frame then
        return
    end

    -- At max level BarManager:GetCurrentFrame() returns nil (runtime style = "none").
    -- In that case no functional attachment target exists, so act as detached.
    local primaryFrame = Addon.BarManager and Addon.BarManager:GetCurrentFrame()
    local isAttachedAndPrimaryVisible = db.secondaryBarsAttached and primaryFrame ~= nil

    if not isAttachedAndPrimaryVisible then
        if frame.ApplyInitialPosition then
            frame:ApplyInitialPosition()
        end
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
        -- At max level Blizzard promotes the reputation bar to the main container.
        -- Suppress it there too so only our secondary bar is visible.
        if ShouldSuppressMainContainer() and _G.MainStatusTrackingBarContainer then
            _G.MainStatusTrackingBarContainer:Hide()
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

    local secondaryContainer = _G.SecondaryStatusTrackingBarContainer
    if secondaryContainer and secondaryContainer.Show then
        hooksecurefunc(secondaryContainer, "Show", function()
            if IsCustomStyle(self._currentStyle) then
                secondaryContainer:Hide()
            end
        end)
    end
    if secondaryContainer and secondaryContainer.SetShown then
        hooksecurefunc(secondaryContainer, "SetShown", function(_, shown)
            if shown and IsCustomStyle(self._currentStyle) then
                secondaryContainer:Hide()
            end
        end)
    end

    -- At max level Blizzard promotes the watched reputation bar into the main
    -- status bar container. Hook it so we can suppress it when our own bar is active.
    local mainContainer = _G.MainStatusTrackingBarContainer
    if mainContainer and mainContainer.Show then
        hooksecurefunc(mainContainer, "Show", function()
            if ShouldSuppressMainContainer() then
                mainContainer:Hide()
            end
        end)
    end
    if mainContainer and mainContainer.SetShown then
        hooksecurefunc(mainContainer, "SetShown", function(_, shown)
            if shown and ShouldSuppressMainContainer() then
                mainContainer:Hide()
            end
        end)
    end

    self._blizzardHooksInstalled = true
end

function Manager:SetSecondaryStyle(style)
    xpcall(self._SetStyle, Utils.ReportError, self, style)
    self:ApplyDefaultReputationBarVisibility()
end

function Manager:ResetBarPositions()
    local db = Addon.db or {}
    local configKey = "secondaryBarPositions"
    local style = db.barStyle

    if db[configKey] and style then
        db[configKey][style] = nil
    end

    local frame = self:GetCurrentFrame()
    if frame and frame.ResetPosition then
        frame:ResetPosition()
    end

    self:ReapplyAttachedPositions()
end

return Manager
