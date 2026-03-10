-- XP Bar Enhanced - Bar Manager (UI)
-- Responsible for creating style frames, switching styles, and hiding Blizzard's default XP bar if enabled.

local Addon = XPBarEnhanced
Addon.BarManager = Addon.BarManager or {}
local BarManager = Addon.BarManager

local StyleBuilder = XPBarStyleBuilder
local EventNames = Addon.EventNames

local function SafeCallErrorHandler(err)
    if CallErrorHandler then
        CallErrorHandler(err)
    else
        print(tostring(err))
    end
end

local StyleTemplateNameMap = {
    classic  = "ClassicBarTemplate",
    flat     = "FlatBarTemplate",
    vertical = "VerticalBarTemplate",
    circular = "CircularBarTemplate",
    terminal = "TerminalBarTemplate",
}

-- Helper: true if style key corresponds to a custom addon style (not Blizzard's bar)
function BarManager:IsCustomStyle(style)
    return style and StyleTemplateNameMap[style] ~= nil
end

function BarManager:Initialize()
    local db = Addon.db or {}
    local defaultStyle = (Addon.defaults and Addon.defaults.barStyle) or "classic"
    local style = db.barStyle or defaultStyle

    -- Install hooks before SetStyle so they are in place when bars are hidden
    self:InstallBlizzardBarHooks()

    self:SetStyle(style)

    -- Ensure lock state is applied at startup
    if Addon.db == nil then
        Addon.db = {}
    end
    
    if Addon.db.barLocked == nil then
        Addon.db.barLocked = false
    end

    -- Hide Blizzard default whenever a custom style is active
    self:ApplyDefaultXPBarVisibility()
end

local function IsPlayerAtMaxLevel(currentLevel)
    local level = currentLevel or UnitLevel("player") or 0
    local maxLevel = (GetMaxPlayerLevel and GetMaxPlayerLevel()) or 80

    -- When PLAYER_LEVEL_UP provides the new level, trust it immediately.
    -- IsPlayerAtEffectiveMaxLevel() can lag one frame behind the event.
    if currentLevel and level >= maxLevel then
        return true
    end

    -- Prefer IsPlayerAtEffectiveMaxLevel() which accounts for expansion state
    if IsPlayerAtEffectiveMaxLevel then
        local atEffectiveMax = IsPlayerAtEffectiveMaxLevel()
        if atEffectiveMax then
            return true
        end
    end

    -- Fallback for older API
    return level >= maxLevel
end

function BarManager:ApplyDefaultXPBarVisibility()
    -- Hide both Blizzard bar containers whenever we are using a custom style
    -- (classic, flat, vertical, circular)
    if self:IsCustomStyle(self.currentStyle) then
        if _G.MainStatusTrackingBarContainer then
            _G.MainStatusTrackingBarContainer:Hide()
        end
        if _G.SecondaryStatusTrackingBarContainer then
            _G.SecondaryStatusTrackingBarContainer:Hide()
        end
    else
        -- Otherwise, restore Blizzard defaults
        if _G.MainStatusTrackingBarContainer then
            _G.MainStatusTrackingBarContainer:Show()
        end
        if _G.SecondaryStatusTrackingBarContainer then
            _G.SecondaryStatusTrackingBarContainer:Show()
        end
    end
    self:DebugContainerState()
end

function BarManager:DebugContainerState()
    -- debug logging removed (was too verbose on every visibility update)
end

-- Install hooksecurefunc hooks to prevent Blizzard's bar from re-showing
-- while a custom style is active. Called once during Initialize().
function BarManager:InstallBlizzardBarHooks()
    local containers = {
        _G.MainStatusTrackingBarContainer,
        _G.SecondaryStatusTrackingBarContainer,
    }

    for _, container in ipairs(containers) do
        if container and container.Show then
            hooksecurefunc(container, "Show", function()
                if self:IsCustomStyle(self.currentStyle) then
                    container:Hide()
                end
            end)
        end
        if container and container.SetShown then
            hooksecurefunc(container, "SetShown", function(_, shown)
                if shown and self:IsCustomStyle(self.currentStyle) then
                    container:Hide()
                end
            end)
        end
    end
end

function BarManager:GetCurrentFrame()
    self.barFrames = self.barFrames or {}
    return self.barFrames[self.currentStyle]
end

function BarManager:SetStyle(nextStyle)
    self.barFrames = self.barFrames or {}

    local previousStyle = self.currentStyle
    if not nextStyle or type(nextStyle) ~= "string" then
        nextStyle = (Addon.defaults and Addon.defaults.barStyle) or "classic"
    end

    -- If player is at max level or XP gain is disabled, force Blizzard bar
    if IsPlayerAtMaxLevel() or (IsXPUserDisabled and IsXPUserDisabled()) then
        nextStyle = "none"
    end

    if previousStyle == nextStyle then
        return
    end

    -- Special case: "none" (Blizzard default) should not attempt to create a custom frame
    if nextStyle == "none" then
        -- Hide any custom frames and restore Blizzard bar visibility
        for key, frame in pairs(self.barFrames) do
            if frame and frame.SetShown then
                frame:SetShown(false)
            end
        end
        self.currentStyle = "none"
        self:ApplyDefaultXPBarVisibility()
        return
    end

    -- Hide any other frames except the selected style to ensure only one visible
    for key, frame in pairs(self.barFrames) do
        if key ~= nextStyle and frame and frame.SetShown then
            frame:SetShown(false)
        end
    end

    local nextFrame = self.barFrames[nextStyle]

    if not nextFrame and StyleBuilder and StyleBuilder.CreateFrameForStyle then
        local templateName = StyleTemplateNameMap[nextStyle]
        local mixin = StyleBuilder:GetStyleMixin(nextStyle)
        if not mixin then
            error("BarManager:SetStyle: Unknown style key: " .. tostring(nextStyle))
        end

        local frame = StyleBuilder:CreateFrameForStyle(nextStyle, mixin.__xpbar_config or {}, templateName)
        self.barFrames[nextStyle] = frame

        if frame and frame.Show then
            frame:SetShown(true)
        end
    else
        if nextFrame and nextFrame.Show then
            nextFrame:SetShown(true)
        end
    end

    self.currentStyle = nextStyle

    if Addon.EventBus and Addon.EventBus.Emit then
        Addon.EventBus:Emit(Addon.EventNames.XPBAR_BROADCAST_UPDATE)
    end

    -- Always hide the Blizzard XP bar when we are using a custom style
    self:ApplyDefaultXPBarVisibility()
end

function BarManager:GetCurrentStyle()
    return self.currentStyle
end

function BarManager:ResetBarPosition()
    for key, value in pairs(self.barFrames) do
        if value.ClearSavedPosition and value.SetDefaultDraggablePosition then
            value:ClearSavedPosition()
            value:SetDefaultDraggablePosition()
        end
    end
end

-- Update animation settings for views (emit broadcast for views to reconfigure)
function BarManager:UpdateAnimationSettings()
    if Addon.AnimationManager and Addon.AnimationManager.UpdateSettings then
        xpcall(Addon.AnimationManager.UpdateSettings, SafeCallErrorHandler, Addon.AnimationManager)
        return true
    end
    return false
end

-- Lifecycle wrappers (compatibility helpers / convenience)
function BarManager:OnEnteringWorld()
    -- Invalidate Quest cache and notify listeners
    if Addon.QuestXP and Addon.QuestXP.InvalidateQuestCache then
        xpcall(Addon.QuestXP.InvalidateQuestCache, SafeCallErrorHandler, Addon.QuestXP)
        return true
    end
    return false
end

function BarManager:OnLevelUp(newLevel)
    -- Re-evaluate style in case player hit max level (will hide bar if at max)
    -- Use the level passed from PLAYER_LEVEL_UP event for accuracy
    local level = newLevel or (UnitLevel("player") or 0) + 1
    local db = Addon.db or {}
    local userStyle = db.barStyle or "classic"

    -- UnitXPMax() reaches 0 as soon as the player can no longer earn XP.
    if (UnitXPMax("player") or 0) <= 0 or IsPlayerAtMaxLevel(level) then
        self:SetStyle("none")
    else
        self:SetStyle(userStyle)
    end
end

function BarManager:OnRestedChanged()
    if Addon.EventBus and Addon.EventBus.Emit then
        Addon.EventBus:Emit(Addon.EventNames.XPBAR_BROADCAST_UPDATE)
    end
end

function BarManager:Shutdown()
    -- Hide any frames and perform light cleanup
    self.barFrames = self.barFrames or {}
    for style, frame in pairs(self.barFrames) do
        if frame and frame.Hide then
            xpcall(frame.Hide, SafeCallErrorHandler, frame)
        end
    end
    self.currentFrame = nil
    self.currentStyle = nil
    if Addon.EventBus and Addon.EventBus.Emit then
        Addon.EventBus:Emit(Addon.EventNames.XPBAR_BROADCAST_UPDATE)
    end
end

return BarManager
