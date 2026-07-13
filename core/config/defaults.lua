-- defaults.lua
-- Extracted default configuration values for XPBarEnhanced

local Addon = XPBarEnhanced

local defaults = {
    barStyle = "classic",
    showSecondaryBar = false,
    secondaryBarSource = "reputation",
    hideCompanionOutsideDelve = false,
    secondaryBarsAttached = true,
    maxLevelPrimaryShowsSecondary = false,
    barLocked = false,
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
    celebrationSound = true,
    fadeWhenInactive = false,
    fadeDelay = 5,
    idleOpacity = 30,
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
    profiles = {},
    characterProfileKeys = {},
    -- Known Delve companion factions (by faction ID).
    -- Maps faction ID -> display name for locale-independent companion detection.
    delveCompanions = {
        [2640] = "Brann Bronzebeard",
        [2744] = "Valeera Sanguinar"
    }
}

Addon.defaults = defaults
return defaults
