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

local function ToDebugString(value)
    if value == nil then
        return "nil"
    end
    return tostring(value)
end

local StyleTemplateNameMap = {
    classic  = "ClassicBarTemplate",
    flat     = "FlatBarTemplate",
    vertical = "VerticalBarTemplate",
    circular = "CircularBarTemplate",
    minimap_ring = "MinimapRingBarTemplate",
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

function BarManager:IsMaxLevelDebugEnabled()
    return true
end

function BarManager:LogMaxLevel(...)
    if not self:IsMaxLevelDebugEnabled() then
        return
    end

    local parts = {}
    for i = 1, select("#", ...) do
        parts[#parts + 1] = ToDebugString(select(i, ...))
    end

    print("|cFFFFAA00[XPBarEnhanced:MaxLevel]|r " .. table.concat(parts, " "))
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

local VALID_MAX_LEVEL_BEHAVIORS = {
    always_show = true,
    show_reputation = true,
    hide = true,
    show_rested_only = true,
}

local function CloneContext(source)
    local clone = {}
    if not source then
        return clone
    end

    for k, v in pairs(source) do
        clone[k] = v
    end
    return clone
end

function BarManager:GetMaxLevelBehavior()
    local db = Addon.db or {}
    local behavior = db.maxLevelBehavior or (Addon.defaults and Addon.defaults.maxLevelBehavior) or "always_show"
    self:LogMaxLevel("GetMaxLevelBehavior db value:", db.maxLevelBehavior, "default:", Addon.defaults and Addon.defaults.maxLevelBehavior)
    if not VALID_MAX_LEVEL_BEHAVIORS[behavior] then
        self:LogMaxLevel("Invalid maxLevelBehavior in db:", behavior, "-> fallback always_show")
        behavior = "always_show"
    end
    self:LogMaxLevel("GetMaxLevelBehavior:", behavior)
    return behavior
end

function BarManager:BuildAlwaysShowContext(context)
    local adjusted = CloneContext(context)
    if adjusted.xpMax == nil or adjusted.xpMax <= 0 then
        adjusted.xpMax = math.max(1, adjusted.preLevelXPMax or 1)
    end
    adjusted.currentXP = math.max(0, math.min(adjusted.currentXP or 0, adjusted.xpMax))
    adjusted.maxLevelBehaviorMode = "always_show"
    return adjusted
end

function BarManager:BuildRestedOnlyContext(context)
    local adjusted = self:BuildAlwaysShowContext(context)

    adjusted.currentXP = 0
    adjusted.xpGained = 0
    adjusted.hasGainedXP = false
    adjusted.hasLeveledUp = false
    adjusted.shouldAnimate = false
    adjusted.shouldFlash = false
    adjusted.showQuestXP = false
    adjusted.showQuestPercent = false
    adjusted.showCompleteQuestOverlay = false
    adjusted.showIncompleteQuestOverlay = false
    adjusted.maxLevelBehaviorMode = "show_rested_only"

    return adjusted
end

function BarManager:BuildReputationAsPrimaryContext(context)
    local adjusted = self:BuildAlwaysShowContext(context)

    local repContext = XPBarContextBuilder and XPBarContextBuilder.BuildReputationContext and XPBarContextBuilder.BuildReputationContext()
    if not repContext or not repContext.isAvailable then
        self:LogMaxLevel("show_reputation fallback: watched reputation unavailable")
        return adjusted
    end

    local repMin = repContext.min or 0
    local repMax = repContext.max or 1
    local repCurrent = repContext.current or 0
    local range = math.max(1, repMax - repMin)
    local current = math.max(0, math.min(range, repCurrent - repMin))

    adjusted.currentXP = current
    adjusted.xpMax = range
    adjusted.xpGained = 0
    adjusted.hasGainedXP = false
    adjusted.hasLeveledUp = false
    adjusted.shouldAnimate = false
    adjusted.shouldFlash = false
    adjusted.totalQuestXP = 0
    adjusted.completeQuestXP = 0
    adjusted.incompleteQuestXP = 0
    adjusted.showQuestXP = false
    adjusted.showQuestPercent = false
    adjusted.showCompleteQuestOverlay = false
    adjusted.showIncompleteQuestOverlay = false
    adjusted.xpPerHour = repContext.repPerHour or 0
    adjusted.timeToLevel = repContext.timeToNextStanding or 0
    adjusted.maxLevelBehaviorMode = "show_reputation"
    adjusted.maxLevelReputationName = repContext.name
    adjusted.maxLevelReputationStanding = repContext.standingLabel

    return adjusted
end

function BarManager:AdjustContextForMaxLevel(context)
    if not context then
        self:LogMaxLevel("AdjustContextForMaxLevel: nil context")
        return context
    end

    local isMax = IsPlayerAtMaxLevel(context.level)
    self:LogMaxLevel(
        "AdjustContextForMaxLevel:",
        "event=", context.event,
        "level=", context.level,
        "xpMax=", context.xpMax,
        "isMax=", isMax
    )
    if not isMax then
        return context
    end

    -- Compatibility policy: keep historical behavior unchanged.
    -- At max level, the primary XP bar is always hidden.
    self:LogMaxLevel("AdjustContextForMaxLevel result: forced hide (primary hidden at cap)")
    return nil
end

function BarManager:ApplyDefaultXPBarVisibility()
    -- Hide only the Blizzard XP bar container when a custom XP style is active.
    -- Secondary/reputation tracking is managed independently by SecondaryBarManager.
    if self:IsCustomStyle(self.currentStyle) then
        if _G.MainStatusTrackingBarContainer then
            _G.MainStatusTrackingBarContainer:Hide()
        end
    else
        -- Otherwise, restore Blizzard XP bar visibility.
        if _G.MainStatusTrackingBarContainer then
            _G.MainStatusTrackingBarContainer:Show()
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

    self:LogMaxLevel("SetStyle request:", "prev=", previousStyle, "next=", nextStyle)

    -- XP-disabled and max-level modes always use Blizzard's default bar.
    if IsXPUserDisabled and IsXPUserDisabled() then
        self:LogMaxLevel("SetStyle override: XP gain disabled -> none")
        nextStyle = "none"
    elseif IsPlayerAtMaxLevel() then
        self:LogMaxLevel("SetStyle override: max level -> none")
        nextStyle = "none"
    end

    self:LogMaxLevel("SetStyle effective:", nextStyle)

    if previousStyle == nextStyle then
        self:LogMaxLevel("SetStyle no-op: style unchanged")
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
    self:LogMaxLevel("SetStyle applied:", self.currentStyle)

    if Addon.EventBus and Addon.EventBus.Emit and XPBarContextBuilder then
        Addon.EventBus:Emit(Addon.EventNames.XPBAR_BROADCAST_UPDATE, XPBarContextBuilder.BuildContext("XPBAR:BROADCAST_UPDATE"))
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
    -- Re-evaluate style in case player hit max level.
    -- Use the level passed from PLAYER_LEVEL_UP event for accuracy.
    local level = newLevel or (UnitLevel("player") or 0)
    local db = Addon.db or {}
    local userStyle = db.barStyle or "classic"

    if (IsXPUserDisabled and IsXPUserDisabled()) then
        self:SetStyle("none")
    elseif IsPlayerAtMaxLevel(level) then
        self:SetStyle("none")
    else
        self:SetStyle(userStyle)
    end
end

function BarManager:OnRestedChanged()
    if Addon.EventBus and Addon.EventBus.Emit and XPBarContextBuilder then
        Addon.EventBus:Emit(Addon.EventNames.XPBAR_BROADCAST_UPDATE, XPBarContextBuilder.BuildContext("UPDATE_EXHAUSTION"))
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
    if Addon.EventBus and Addon.EventBus.Emit and XPBarContextBuilder then
        Addon.EventBus:Emit(Addon.EventNames.XPBAR_BROADCAST_UPDATE, XPBarContextBuilder.BuildContext("XPBAR:BROADCAST_UPDATE"))
    end
end

return BarManager
