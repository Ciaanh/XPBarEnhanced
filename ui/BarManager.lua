-- XP Bar Enhanced - Bar Manager (UI)
-- Responsible for creating style frames, switching styles, and hiding Blizzard's default XP bar if enabled.

local Addon = XPBarEnhanced
Addon.BarManager = Addon.BarManager or {}
local BarManager = Addon.BarManager

local StyleBuilder = XPBarStyleBuilder
local EventNames = Addon.EventNames
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

local function ShouldSecondarySuppressMainContainer()
    local manager = Addon.SecondaryBarManager
    if manager and manager.ShouldSuppressMainContainer then
        return manager:ShouldSuppressMainContainer()
    end
    return false
end

local StyleTemplateNameMap = {
    classic  = "ClassicBarTemplate",
    flat     = "FlatBarTemplate",
    vertical = "VerticalBarTemplate",
    circular = "CircularBarTemplate",
    minimap_ring = "MinimapRingBarTemplate",
    terminal = "TerminalBarTemplate",
    orb      = "OrbBarTemplate",
}

-- Helper: true if style key corresponds to a custom addon style (not Blizzard's bar)
function BarManager:IsCustomStyle(style)
    return style and StyleTemplateNameMap[style] ~= nil
end

function BarManager:Initialize()
    local defaultStyle = (Addon.defaults and Addon.defaults.barStyle) or "classic"
    local style = GetOptionValue("barStyle", defaultStyle)

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

    -- Re-drive the style when the secondary source's availability changes at
    -- max level (e.g. watched-faction data loads after login), so the
    -- repurposed primary bar appears/disappears without a /reload. Single
    -- lifetime subscription (BarManager is never torn down).
    if Addon.EventBus and Addon.EventBus.Register and Addon.UI and Addon.UI.SharedStyleHelpers
        and Addon.UI.SharedStyleHelpers.GetSecondaryBroadcastEventName then
        for _, evName in ipairs(Addon.UI.SharedStyleHelpers.GetSecondaryBroadcastEventName()) do
            Addon.EventBus:Register(evName, "barmanager-maxlevel-repurpose", function()
                BarManager:RefreshMaxLevelRepurpose()
            end)
        end
    end
end

local function IsPlayerAtMaxLevel(currentLevel)
    local level = tonumber(currentLevel)
    if not level then
        level = tonumber(UnitLevel("player")) or 0
    end

    local maxLevel = tonumber((GetMaxPlayerLevel and GetMaxPlayerLevel()) or 80) or 80
    if level <= 0 then
        return false
    end

    -- Use an explicit level comparison only. Effective-max APIs can transiently
    -- report true during login/level transitions and incorrectly force style "none".
    return level >= maxLevel
end

-- True when the primary bar should be repurposed to display the selected
-- secondary source at max level: the option is on, the player is at max level,
-- a custom style is configured, the secondary bar is enabled, and the active
-- source has data to show.
function BarManager:ShouldRepurposePrimaryAtMaxLevel()
    if not IsPlayerAtMaxLevel() then
        return false
    end
    if not GetOptionValue("maxLevelPrimaryShowsSecondary", false) then
        return false
    end
    if not GetOptionValue("showSecondaryBar", false) then
        return false
    end
    if not self:IsCustomStyle(GetOptionValue("barStyle", "none")) then
        return false
    end
    local Shared = Addon.UI and Addon.UI.SharedStyleHelpers
    if not (Shared and Shared.GetSecondaryInitialContext) then
        return false
    end
    local ctx = Shared.GetSecondaryInitialContext()
    return (ctx and ctx.isAvailable) and true or false
end

-- If max-level repurpose eligibility no longer matches the shown style,
-- re-drive SetStyle. No-ops once stable, so it cannot loop.
function BarManager:RefreshMaxLevelRepurpose()
    if not IsPlayerAtMaxLevel() then
        return
    end
    local shouldRepurpose = self:ShouldRepurposePrimaryAtMaxLevel()
    local hasCustom = self:IsCustomStyle(self.currentStyle)
    if shouldRepurpose ~= hasCustom then
        self.currentStyle = nil
        self:SetStyle(GetOptionValue("barStyle"))
    end
end

-- Build an XP-shaped context from the active secondary source so the existing
-- primary style RenderBar paths can paint it unchanged. Overlays/quest/rested
-- fields are zeroed so those (XP-only) elements stay hidden; `_secondaryColor`
-- recolors the fill via Shared.GetXPBarColor.
function BarManager:GetMaxLevelSecondaryContext()
    if not self:ShouldRepurposePrimaryAtMaxLevel() then
        return nil
    end

    local Shared = Addon.UI and Addon.UI.SharedStyleHelpers
    local StyleHelpers = Addon.UI and Addon.UI.StyleHelpers
    local src = Shared and Shared.GetSecondaryInitialContext and Shared.GetSecondaryInitialContext()
    if not src or not src.isAvailable then
        return nil
    end

    local color = StyleHelpers and StyleHelpers.GetFactionColor and StyleHelpers.GetFactionColor(src) or nil
    local maxVal = (src.max and src.max > 0) and src.max or 1

    return {
        event = "XPBAR:BROADCAST_UPDATE",
        source = src.source,
        currentXP = src.current or 0,
        xpMax = maxVal,
        level = src.currentLevel or src.reactionLevel or 0,
        percent = src.percent,
        standingLabel = src.standingLabel,
        -- The on-bar "level" text shows the source's standing (e.g. "Renown 3",
        -- "Honor Level 5") instead of "Level N". Profession has no standing —
        -- its progress is numeric and already shown centered — so use the
        -- profession name there instead of duplicating the progress text.
        levelTextOverride = (src.factionType == "profession") and src.name or src.standingLabel,
        -- Suppress XP-only visuals
        restedXP = 0,
        hasRestedXP = false,
        isResting = false,
        isFullyRested = false,
        completeQuestXP = 0,
        incompleteQuestXP = 0,
        hasGainedXP = false,
        hasLeveledUp = false,
        shouldAnimate = false,
        shouldFlash = false,
        restedChanged = false,
        questsChanged = false,
        -- Session-style text fields (repurposed from the source's rate/gain)
        sessionXP = src.sessionGained,
        xpPerHour = src.repPerHour,
        timeToLevel = src.timeToNextLevel,
        -- Secondary-mode markers
        _secondaryMode = true,
        _secondaryColor = color,
        factionType = src.factionType,
    }
end

function BarManager:AdjustContextForMaxLevel(context)
    if not context then
        return context
    end

    if not IsPlayerAtMaxLevel(context.level) then
        return context
    end

    -- At max level, optionally repurpose the primary bar for the secondary
    -- source; otherwise the primary XP bar is hidden.
    return self:GetMaxLevelSecondaryContext()
end

-- True while the Blizzard main container must stay hidden. Re-checked when a
-- combat-deferred hide fires, so switching to style "none" mid-combat cannot
-- leave the player without any XP bar.
local function ShouldHideMainContainer()
    return BarManager:IsCustomStyle(BarManager.currentStyle) or ShouldSecondarySuppressMainContainer()
end

-- Safely hide a Blizzard container, deferring to after combat if in lockdown.
local function SafeHideContainer(container)
    Utils.SafeHideContainer(container, ShouldHideMainContainer)
end

function BarManager:ApplyDefaultXPBarVisibility()
    -- Hide only the Blizzard XP bar container when a custom XP style is active.
    -- Secondary/reputation tracking is managed independently by SecondaryBarManager.
    if self:IsCustomStyle(self.currentStyle) then
        SafeHideContainer(_G.MainStatusTrackingBarContainer)
    else
        -- Otherwise, restore Blizzard XP bar visibility.
        if _G.MainStatusTrackingBarContainer then
            if ShouldSecondarySuppressMainContainer() then
                SafeHideContainer(_G.MainStatusTrackingBarContainer)
            else
                _G.MainStatusTrackingBarContainer:Show()
            end
        end
    end
end

-- Install hooksecurefunc hooks to prevent Blizzard's bar from re-showing
-- while a custom style is active. Called once during Initialize().
function BarManager:InstallBlizzardBarHooks()
    local containers = {
        _G.MainStatusTrackingBarContainer,
    }

    for _, container in ipairs(containers) do
        if container and container.Show then
            hooksecurefunc(container, "Show", function()
                if self:IsCustomStyle(self.currentStyle) or ShouldSecondarySuppressMainContainer() then
                    SafeHideContainer(container)
                end
            end)
        end
        if container and container.SetShown then
            hooksecurefunc(container, "SetShown", function(_, shown)
                if shown and (self:IsCustomStyle(self.currentStyle) or ShouldSecondarySuppressMainContainer()) then
                    SafeHideContainer(container)
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

    -- XP-disabled and max-level modes normally use Blizzard's default bar,
    -- unless the max-level "primary shows secondary source" mode is active —
    -- then keep the configured custom style so it can render the source.
    if IsXPUserDisabled and IsXPUserDisabled() then
        nextStyle = "none"
    elseif IsPlayerAtMaxLevel() and not self:ShouldRepurposePrimaryAtMaxLevel() then
        nextStyle = "none"
    end

    if previousStyle == nextStyle then
        if Addon.SecondaryBarManager and Addon.SecondaryBarManager.RefreshForPrimaryStyleChange then
            Addon.SecondaryBarManager:RefreshForPrimaryStyleChange()
        end
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
        if Addon.SecondaryBarManager and Addon.SecondaryBarManager.RefreshForPrimaryStyleChange then
            Addon.SecondaryBarManager:RefreshForPrimaryStyleChange()
        end
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

    -- Trigger a broadcast through the session layer so context ownership stays in Session.
    if Addon.Session and Addon.Session.EmitUpdate then
        Addon.Session:EmitUpdate("XPBAR:BROADCAST_UPDATE")
    end

    -- Always hide the Blizzard XP bar when we are using a custom style
    self:ApplyDefaultXPBarVisibility()

    if Addon.SecondaryBarManager and Addon.SecondaryBarManager.RefreshForPrimaryStyleChange then
        Addon.SecondaryBarManager:RefreshForPrimaryStyleChange()
    end
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
        xpcall(Addon.AnimationManager.UpdateSettings, Utils.ReportError, Addon.AnimationManager)
        return true
    end
    return false
end

-- Lifecycle wrappers (compatibility helpers / convenience)
function BarManager:OnEnteringWorld()
    -- Invalidate Quest cache and notify listeners
    if Addon.QuestXP and Addon.QuestXP.InvalidateQuestCache then
        xpcall(Addon.QuestXP.InvalidateQuestCache, Utils.ReportError, Addon.QuestXP)
        return true
    end
    return false
end

function BarManager:TriggerStyleCelebration()
    -- Only trigger when animations are enabled
    if GetOptionValue("enableAnimations", true) == false then return end

    local frame = self:GetCurrentFrame()
    if frame and frame.OnLevelUpCelebration then
        frame:OnLevelUpCelebration()
    end
end

function BarManager:OnLevelUp(newLevel)
    -- Re-evaluate style in case player hit max level.
    -- Use the level passed from PLAYER_LEVEL_UP event for accuracy.
    local level = newLevel or (UnitLevel("player") or 0)
    local userStyle = GetOptionValue("barStyle", "classic")

    -- Fire style-specific celebration hook before switching style
    self:TriggerStyleCelebration()

    if (IsXPUserDisabled and IsXPUserDisabled()) then
        self:SetStyle("none")
    elseif IsPlayerAtMaxLevel(level) and not self:ShouldRepurposePrimaryAtMaxLevel() then
        self:SetStyle("none")
    else
        self:SetStyle(userStyle)
    end
end

function BarManager:Shutdown()
    -- Hide any frames and perform light cleanup
    self.barFrames = self.barFrames or {}
    for style, frame in pairs(self.barFrames) do
        if frame and frame.Hide then
            xpcall(frame.Hide, Utils.ReportError, frame)
        end
    end
    self.currentFrame = nil
    self.currentStyle = nil
end

return BarManager
