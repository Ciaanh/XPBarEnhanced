-- defaults.lua
-- Extracted default configuration values for XPBarEnhanced

local Addon = XPBarEnhanced

local defaults = {
    barStyle = "classic",
    showSecondaryBar = false,
    hideCompanionOutsideDelve = false,
    secondaryBarsAttached = true,
    barLocked = false,
    circularSize = "medium",
    circularSegments = 50,
    circularUseTexture = true,
    circularScaleCenterText = false,
    circularSecondaryFullCircle = false,
    minimapRingPadding = 10,
    minimapRingSegments = 100,
    minimapRingCollectButtons = false,
    minimapRingBagAngle = 200,
    minimapArcIconAngle = 315,
    minimapArcDisplayAngle = 135,
    minimapRingSegmentWidth = 8,
    minimapRingSegmentHeight = 25,
    minimapArcStartExpanded = false,

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
    enableAnimations = true,
    flashOnGain = true,
    twoPhaseOnLevelUp = true,
    levelUpCelebration = true,
    celebrationSparkles = false,
    celebrationSound = true,
    celebrationSpeed = "normal",
    fadeWhenInactive = false,
    fadeDelay = 5.0,
    idleOpacity = 0.0,
    fadeInSpeed = 0.3,
    fadeOutSpeed = 0.5,
    classicBarDraggable = true,
    showMinimapButton = true,
    textFontFace = "Fonts\\FRIZQT__.TTF",
    textFontSize = 12,
    textFontOutline = "NONE",
    textFontShadow = false,
    terminalUseCustomColors = false,
    colors = {
        xpBar = {r = 0.58, g = 0.0, b = 0.55, a = 1},
        xpBarRested = {r = 0.0, g = 0.44, b = 1.0, a = 1},
        rested = {r = 0.07, g = 0.58, b = 0.95, a = 0.5},
        questComplete = {r = 1.0, g = 0.65, b = 0.0, a = 0.85},
        questIncomplete = {r = 0.5, g = 1.0, b = 0.2, a = 0.85}
    },
    barPosition = {
        point = "CENTER",
        relativeTo = "UIParent",
        relativePoint = "CENTER",
        x = 0,
        y = 0
    },
    barPositions = {
        classic = {point = "BOTTOM", relativeTo = "UIParent", relativePoint = "BOTTOM", x = 0, y = 12},
        flat = {point = "CENTER", relativeTo = "UIParent", relativePoint = "CENTER", x = 0, y = 0},
        circular = {point = "CENTER", relativeTo = "UIParent", relativePoint = "CENTER", x = 0, y = 0}
    },
    secondaryFadeInSpeed = 0.3,
    secondaryFadeOutSpeed = 0.5,
    -- Known Delve companion factions (by faction ID).
    -- Maps faction ID -> display name for locale-independent companion detection.
    delveCompanions = {
        [2640] = "Brann Bronzebeard",
        [2744] = "Valeera Sanguinar"
    }
}

defaults.xpBarColor = defaults.colors.xpBar

Addon.defaults = defaults
return defaults
