-- defaults.lua
-- Extracted default configuration values for XPBarEnhanced

local Addon = XPBarEnhanced

local styleKey = (Addon.StyleKeys and Addon.StyleKeys.classic) or "classic"
local flatStyleKey = (Addon.StyleKeys and Addon.StyleKeys.flat) or "flat"
local circularStyleKey = (Addon.StyleKeys and Addon.StyleKeys.circular) or "circular"

local defaults = {
    barStyle = styleKey,
    showSecondaryBar = false,
    secondaryBarSource = "reputation",
    professionSlot = "auto",
    hideCompanionOutsideDelve = false,
    secondaryBarsAttached = true,
    maxLevelPrimaryShowsSecondary = false,
    barLocked = false,
    -- 566 and 10 are the dimensions the Classic templates were authored at, and
    -- the legacy border art already paints nine dividers at exactly the ten-
    -- segment positions -- so these defaults reproduce the pre-option bar.
    classicWidth = 566,
    classicSegments = 10,
    circularSize = "medium",
    flatSize = "default",
    verticalSize = "default",
    circularSegments = 50,
    circularUseTexture = true,
    circularScaleCenterText = false,
    circularSecondaryFullCircle = false,
    minimapRingPadding = 0,
    minimapRingSegments = 100,
    minimapRingCollectButtons = false,
    minimapRingBagAngle = 200,
    minimapArcIconAngle = 315,
    minimapArcDisplayAngle = 135,
    minimapRingSegmentWidth = 8,
    minimapRingSegmentHeight = 25,
    minimapArcStartExpanded = false,

    -- Named starting point for the boolean options; see core/config/ReadoutPresets.lua.
    -- "custom" once any owned boolean diverges from every preset.
    readoutPreset = "standard",

    showPercentage = true,
    showMilestoneTicks = false,
    showQuestXP = true,
    showQuestPercent = true,
    showXPPerHourText = true,
    showLevelTimeText = true,
    showSessionTimeText = true,
    resetOnReload = false,
    showTimeToLevelText = true,
    abbreviateNumbers = true,
    showRemainingXP = true,
    showLevelText = true,
    showXPText = true,
    showCompleteQuestOverlay = true,
    showIncompleteQuestOverlay = false,
    showRestedOverlay = true,
    enableAnimations = true,
    flashOnGain = true,
    twoPhaseOnLevelUp = true,
    levelUpCelebration = true,
    goalNotifications = true,
    enableDataBrokerFeed = true,
    classicBarDraggable = true,
    showMinimapButton = true,
    terminalUseCustomColors = false,
    colors = {
        xpBar = {r = 0.58, g = 0.0, b = 0.55, a = 1},
        xpBarRested = {r = 0.0, g = 0.44, b = 1.0, a = 1},
        rested = {r = 0.07, g = 0.58, b = 0.95, a = 0.5},
        questComplete = {r = 1.0, g = 0.65, b = 0.0, a = 0.85},
        questIncomplete = {r = 0.5, g = 1.0, b = 0.2, a = 0.85},
        secondaryReputation = {r = 0.70, g = 0.30, b = 0.85, a = 1},
        secondaryHousing = {r = 0.85, g = 0.55, b = 0.20, a = 1},
        secondaryHonor = {r = 0.80, g = 0.20, b = 0.20, a = 1},
        secondaryProfession = {r = 0.30, g = 0.65, b = 0.75, a = 1}
    },
    barPositions = {
        [styleKey] = {point = "BOTTOM", relativeTo = "UIParent", relativePoint = "CENTER", x = 0, y = 0},
        [flatStyleKey] = {point = "CENTER", relativeTo = "UIParent", relativePoint = "CENTER", x = 0, y = 0},
        [circularStyleKey] = {point = "CENTER", relativeTo = "UIParent", relativePoint = "CENTER", x = 0, y = 0}
    },
    secondaryFadeInSpeed = 0.3,
    secondaryFadeOutSpeed = 0.5,
    profiles = {},
    characterProfileKeys = {},
}

Addon.defaults = defaults
return defaults
