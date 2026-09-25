-- OptionMetadata.lua
-- Extracted options metadata from core/Config.lua into a separable file

local Addon = XPBarEnhanced
local Config = Addon.Config
-- A secondary source is offered when the resolved client feature profile
-- supports it. Module presence is not a capability signal because all clients
-- use one TOC, and the live probe is not either: Retail housing only reports
-- itself available once the housing service answers, after this file loads.
local HAS_REPUTATION = Addon:IsFeatureSupported("reputation")
local HAS_HOUSING = Addon:IsFeatureSupported("housing")
local HAS_HONOR = Addon:IsFeatureSupported("honor")
local HAS_PROFESSION = Addon:IsFeatureSupported("profession")

local optionDetails = {
    -- Declared as a dropdown so Config:SetOptionKey preserves the string value
    -- rather than coercing it to a boolean. Deliberately absent from optionOrder:
    -- the panel renders it as preset buttons, not an auto-built dropdown row.
    readoutPreset = {
        key = "readoutPreset",
        type = "dropdown",
        label = Addon.L["OPT_READOUT_PRESET"],
        description = Addon.L["OPT_READOUT_PRESET_DESC"],
        options = {
            {value = "minimal", label = Addon.L["OPT_READOUT_PRESET_MINIMAL"]},
            {value = "standard", label = Addon.L["OPT_READOUT_PRESET_STANDARD"]},
            {value = "leveller", label = Addon.L["OPT_READOUT_PRESET_LEVELLER"]},
            {value = "custom", label = Addon.L["OPT_READOUT_PRESET_CUSTOM"]},
        }
    },
    barStyle = {
        key = "barStyle",
        type = "dropdown",
        label = Addon.L["OPT_BAR_STYLE"],
        description = Addon.L["OPT_BAR_STYLE_DESC"],
        -- shortLabel is what the style gallery prints under each swatch and what
        -- the "<Style> only" row notes name; the long label stays for prose.
        options = {
            {value = "none", label = Addon.L["OPT_BAR_STYLE_NONE"], shortLabel = Addon.L["OPT_BAR_STYLE_SHORT_NONE"]},
            {value = "classic", label = Addon.L["OPT_BAR_STYLE_CLASSIC"], shortLabel = Addon.L["OPT_BAR_STYLE_SHORT_CLASSIC"]},
            {value = "flat", label = Addon.L["OPT_BAR_STYLE_FLAT"], shortLabel = Addon.L["OPT_BAR_STYLE_SHORT_FLAT"]},
            {value = "vertical", label = Addon.L["OPT_BAR_STYLE_VERTICAL"], shortLabel = Addon.L["OPT_BAR_STYLE_SHORT_VERTICAL"]},
            {value = "circular", label = Addon.L["OPT_BAR_STYLE_CIRCULAR"], shortLabel = Addon.L["OPT_BAR_STYLE_SHORT_CIRCULAR"]},
            {value = "minimap_ring", label = Addon.L["OPT_BAR_STYLE_MINIMAP_RING"], shortLabel = Addon.L["OPT_BAR_STYLE_SHORT_MINIMAP_RING"]},
            {value = "terminal", label = Addon.L["OPT_BAR_STYLE_TERMINAL"], shortLabel = Addon.L["OPT_BAR_STYLE_SHORT_TERMINAL"]},
            {value = "orb", label = Addon.L["OPT_BAR_STYLE_ORB"], shortLabel = Addon.L["OPT_BAR_STYLE_SHORT_ORB"]},
        }
    },
    showSecondaryBar = {
        key = "showSecondaryBar",
        label = Addon.L["OPT_SHOW_SECONDARY_BAR"],
        description = Addon.L["OPT_SHOW_SECONDARY_BAR_DESC"]
    },
    secondaryBarSource = {
        key = "secondaryBarSource",
        type = "dropdown",
        label = Addon.L["OPT_SECONDARY_BAR_SOURCE"],
        description = Addon.L["OPT_SECONDARY_BAR_SOURCE_DESC"],
        options = {
            {value = "reputation", label = Addon.L["OPT_SECONDARY_BAR_SOURCE_REPUTATION"]},
            {value = "housing", label = Addon.L["OPT_SECONDARY_BAR_SOURCE_HOUSING"]},
            {value = "honor", label = Addon.L["OPT_SECONDARY_BAR_SOURCE_HONOR"]},
            {value = "profession", label = Addon.L["OPT_SECONDARY_BAR_SOURCE_PROFESSION"]},
        }
    },
    professionSlot = {
        key = "professionSlot",
        type = "dropdown",
        label = Addon.L["OPT_PROFESSION_SLOT"],
        description = Addon.L["OPT_PROFESSION_SLOT_DESC"],
        options = {
            {value = "auto", label = Addon.L["OPT_PROFESSION_SLOT_AUTO"]},
            {value = "first", label = Addon.L["OPT_PROFESSION_SLOT_FIRST"]},
            {value = "second", label = Addon.L["OPT_PROFESSION_SLOT_SECOND"]},
        }
    },
    hideCompanionOutsideDelve = {
        key = "hideCompanionOutsideDelve",
        label = Addon.L["OPT_HIDE_COMPANION_OUTSIDE_DELVE"],
        description = Addon.L["OPT_HIDE_COMPANION_OUTSIDE_DELVE_DESC"]
    },
    secondaryBarsAttached = {
        key = "secondaryBarsAttached",
        label = Addon.L["OPT_SECONDARY_BARS_ATTACHED"],
        description = Addon.L["OPT_SECONDARY_BARS_ATTACHED_DESC"]
    },
    maxLevelPrimaryShowsSecondary = {
        key = "maxLevelPrimaryShowsSecondary",
        label = Addon.L["OPT_MAX_LEVEL_PRIMARY_SECONDARY"],
        description = Addon.L["OPT_MAX_LEVEL_PRIMARY_SECONDARY_DESC"]
    },
    barLocked = {
        key = "barLocked",
        label = Addon.L["OPT_BAR_LOCKED"],
        description = Addon.L["OPT_BAR_LOCKED_DESC"]
    },
    classicBarDraggable = {
        key = "classicBarDraggable",
        label = Addon.L["OPT_CLASSIC_DRAGGABLE"] or "Classic Bar Draggable",
        description = Addon.L["OPT_CLASSIC_DRAGGABLE_DESC"] or "Allow the Classic bar to be dragged and positioned manually. When disabled, the Classic bar will be anchored to Blizzard's default position."
    },
    showMinimapButton = {
        key = "showMinimapButton",
        label = Addon.L["OPT_SHOW_MINIMAP_BUTTON"],
        description = Addon.L["OPT_SHOW_MINIMAP_BUTTON_DESC"]
    },
    showRestedOverlay = {
        key = "showRestedOverlay",
        label = Addon.L["OPT_SHOW_RESTED_OVERLAY"],
        description = Addon.L["OPT_SHOW_RESTED_OVERLAY_DESC"]
    },
    showQuestXP = {
        key = "showQuestXP",
        label = Addon.L["OPT_QUEST_XP"],
        description = Addon.L["OPT_QUEST_XP_DESC"]
    },
    showCompleteQuestOverlay = {
        key = "showCompleteQuestOverlay",
        label = Addon.L["OPT_SHOW_COMPLETE_OVERLAY"],
        description = Addon.L["OPT_SHOW_COMPLETE_OVERLAY_DESC"]
    },
    showIncompleteQuestOverlay = {
        key = "showIncompleteQuestOverlay",
        label = Addon.L["OPT_SHOW_INCOMPLETE_OVERLAY"],
        description = Addon.L["OPT_SHOW_INCOMPLETE_OVERLAY_DESC"]
    },
    showPercentage = {
        key = "showPercentage",
        label = Addon.L["OPT_PERCENTAGE"],
        description = Addon.L["OPT_PERCENTAGE_DESC"]
    },
    showMilestoneTicks = {
        key = "showMilestoneTicks",
        label = Addon.L["OPT_SHOW_MILESTONE_TICKS"],
        description = Addon.L["OPT_SHOW_MILESTONE_TICKS_DESC"]
    },
    showQuestPercent = {
        key = "showQuestPercent",
        label = Addon.L["OPT_QUEST_PERCENT"],
        description = Addon.L["OPT_QUEST_PERCENT_DESC"]
    },
    showLevelText = {
        key = "showLevelText",
        label = Addon.L["OPT_LEVEL_TEXT"],
        description = Addon.L["OPT_LEVEL_TEXT_DESC"]
    },
    showXPText = {
        key = "showXPText",
        label = Addon.L["OPT_XP_TEXT"],
        description = Addon.L["OPT_XP_TEXT_DESC"]
    },
    showRemainingXP = {
        key = "showRemainingXP",
        label = Addon.L["OPT_REMAINING_XP"],
        description = Addon.L["OPT_REMAINING_XP_DESC"]
    },
    showXPPerHourText = {
        key = "showXPPerHourText",
        label = Addon.L["OPT_XP_HOUR"],
        description = Addon.L["OPT_XP_HOUR_DESC"]
    },
    showLevelTimeText = {
        key = "showLevelTimeText",
        label = Addon.L["OPT_LEVEL_TIME"],
        description = Addon.L["OPT_LEVEL_TIME_DESC"]
    },
    showSessionTimeText = {
        key = "showSessionTimeText",
        label = Addon.L["OPT_SESSION_TIME"],
        description = Addon.L["OPT_SESSION_TIME_DESC"]
    },
    resetOnReload = {
        key = "resetOnReload",
        label = Addon.L["OPT_RESET_ON_RELOAD"],
        description = Addon.L["OPT_RESET_ON_RELOAD_DESC"]
    },
    showTimeToLevelText = {
        key = "showTimeToLevelText",
        label = Addon.L["OPT_TIME_TO_LEVEL"],
        description = Addon.L["OPT_TIME_TO_LEVEL_DESC"]
    },
    abbreviateNumbers = {
        key = "abbreviateNumbers",
        label = Addon.L["OPT_ABBREVIATE_NUMBERS"],
        description = Addon.L["OPT_ABBREVIATE_NUMBERS_DESC"]
    },
    enableAnimations = {
        key = "enableAnimations",
        label = Addon.L["OPT_ENABLE_ANIMATIONS"],
        description = Addon.L["OPT_ENABLE_ANIMATIONS_DESC"]
    },
    flashOnGain = {
        key = "flashOnGain",
        label = Addon.L["OPT_FLASH_ON_GAIN"],
        description = Addon.L["OPT_FLASH_ON_GAIN_DESC"]
    },
    twoPhaseOnLevelUp = {
        key = "twoPhaseOnLevelUp",
        label = Addon.L["OPT_TWO_PHASE_LEVEL_UP"],
        description = Addon.L["OPT_TWO_PHASE_LEVEL_UP_DESC"]
    },
    levelUpCelebration = {
        key = "levelUpCelebration",
        label = Addon.L["OPT_LEVEL_UP_CELEBRATION"],
        description = Addon.L["OPT_LEVEL_UP_CELEBRATION_DESC"]
    },
    goalNotifications = {
        key = "goalNotifications",
        label = Addon.L["OPT_GOAL_NOTIFICATIONS"],
        description = Addon.L["OPT_GOAL_NOTIFICATIONS_DESC"]
    },
    enableDataBrokerFeed = {
        key = "enableDataBrokerFeed",
        label = Addon.L["OPT_DATA_BROKER_FEED"],
        description = Addon.L["OPT_DATA_BROKER_FEED_DESC"]
    },
    classicWidth = {
        key = "classicWidth",
        type = "slider",
        label = Addon.L["OPT_CLASSIC_WIDTH"],
        description = Addon.L["OPT_CLASSIC_WIDTH_DESC"],
        min = 200,
        max = 1400,
        step = 2,
        format = "%.0f"
    },
    classicSegments = {
        key = "classicSegments",
        type = "slider",
        label = Addon.L["OPT_CLASSIC_SEGMENTS"],
        description = Addon.L["OPT_CLASSIC_SEGMENTS_DESC"],
        min = 0,
        max = 40,
        step = 1,
        format = "%.0f"
    },
    circularSize = {
        key = "circularSize",
        type = "dropdown",
        label = Addon.L["OPT_CIRCULAR_SIZE"],
        description = Addon.L["OPT_CIRCULAR_SIZE_DESC"],
        options = {
            {value = "small", label = Addon.L["OPT_CIRCULAR_SIZE_SMALL"]},
            {value = "medium", label = Addon.L["OPT_CIRCULAR_SIZE_MEDIUM"]},
            {value = "large", label = Addon.L["OPT_CIRCULAR_SIZE_LARGE"]},
            {value = "huge", label = Addon.L["OPT_CIRCULAR_SIZE_HUGE"]}
        }
    },
    flatSize = {
        key = "flatSize",
        type = "dropdown",
        label = Addon.L["OPT_FLAT_SIZE"],
        description = Addon.L["OPT_FLAT_SIZE_DESC"],
        options = {
            {value = "small",   label = Addon.L["OPT_BAR_SIZE_SMALL"]},
            {value = "default", label = Addon.L["OPT_BAR_SIZE_DEFAULT"]},
            {value = "large",   label = Addon.L["OPT_BAR_SIZE_LARGE"]},
            {value = "huge",    label = Addon.L["OPT_BAR_SIZE_HUGE"]}
        }
    },
    verticalSize = {
        key = "verticalSize",
        type = "dropdown",
        label = Addon.L["OPT_VERTICAL_SIZE"],
        description = Addon.L["OPT_VERTICAL_SIZE_DESC"],
        options = {
            {value = "small",   label = Addon.L["OPT_BAR_SIZE_SMALL"]},
            {value = "default", label = Addon.L["OPT_BAR_SIZE_DEFAULT"]},
            {value = "large",   label = Addon.L["OPT_BAR_SIZE_LARGE"]},
            {value = "huge",    label = Addon.L["OPT_BAR_SIZE_HUGE"]}
        }
    },
    circularSegments = {
        key = "circularSegments",
        type = "slider",
        label = Addon.L["OPT_CIRCULAR_SEGMENTS"],
        description = Addon.L["OPT_CIRCULAR_SEGMENTS_DESC"],
        min = 25,
        max = 100,
        step = 5,
        format = "%.0f"
    },
    circularUseTexture = {
        key = "circularUseTexture",
        label = Addon.L["OPT_CIRCULAR_USE_TEXTURE"],
        description = Addon.L["OPT_CIRCULAR_USE_TEXTURE_DESC"]
    },
    circularScaleCenterText = {
        key = "circularScaleCenterText",
        label = Addon.L["OPT_CIRCULAR_SCALE_CENTER_TEXT"],
        description = Addon.L["OPT_CIRCULAR_SCALE_CENTER_TEXT_DESC"]
    },
    circularSecondaryFullCircle = {
        key = "circularSecondaryFullCircle",
        label = Addon.L["OPT_CIRCULAR_SECONDARY_FULL_CIRCLE"],
        description = Addon.L["OPT_CIRCULAR_SECONDARY_FULL_CIRCLE_DESC"]
    },
    minimapRingPadding = {
        key = "minimapRingPadding",
        type = "slider",
        label = Addon.L["OPT_MINIMAP_RING_PADDING"],
        description = Addon.L["OPT_MINIMAP_RING_PADDING_DESC"],
        min = 0,
        max = 32,
        step = 1,
        format = "%.0f"
    },
    minimapRingSegments = {
        key = "minimapRingSegments",
        type = "slider",
        label = Addon.L["OPT_MINIMAP_RING_SEGMENTS"],
        description = Addon.L["OPT_MINIMAP_RING_SEGMENTS_DESC"],
        min = 25,
        max = 100,
        step = 5,
        format = "%.0f"
    },
    minimapRingCollectButtons = {
        key = "minimapRingCollectButtons",
        label = Addon.L["OPT_MINIMAP_RING_COLLECT_BUTTONS"],
        description = Addon.L["OPT_MINIMAP_RING_COLLECT_BUTTONS_DESC"]
    },
    minimapRingSegmentWidth = {
        key = "minimapRingSegmentWidth",
        type = "slider",
        label = Addon.L["OPT_MINIMAP_RING_SEGMENT_WIDTH"],
        description = Addon.L["OPT_MINIMAP_RING_SEGMENT_WIDTH_DESC"],
        min = 2,
        max = 10,
        step = 1,
        format = "%.0f"
    },
    minimapRingSegmentHeight = {
        key = "minimapRingSegmentHeight",
        type = "slider",
        label = Addon.L["OPT_MINIMAP_RING_SEGMENT_HEIGHT"],
        description = Addon.L["OPT_MINIMAP_RING_SEGMENT_HEIGHT_DESC"],
        min = 5,
        max = 25,
        step = 1,
        format = "%.0f"
    },
    minimapArcStartExpanded = {
        key = "minimapArcStartExpanded",
        label = Addon.L["OPT_MINIMAP_ARC_START_EXPANDED"],
        description = Addon.L["OPT_MINIMAP_ARC_START_EXPANDED_DESC"]
    },
    terminalUseCustomColors = {
        key = "terminalUseCustomColors",
        label = Addon.L["OPT_TERMINAL_USE_CUSTOM_COLORS"],
        description = Addon.L["OPT_TERMINAL_USE_CUSTOM_COLORS_DESC"]
    }
}

-- Offer a secondary source only where its backing module can actually run.
do
    local availableSources = {
        profession = HAS_PROFESSION,
        reputation = HAS_REPUTATION,
        housing = HAS_HOUSING,
        honor = HAS_HONOR,
    }

    local sourceOptions = optionDetails.secondaryBarSource.options
    for index = #sourceOptions, 1, -1 do
        if not availableSources[sourceOptions[index].value] then
            table.remove(sourceOptions, index)
        end
    end
end

local optionOrder = {
    "barStyle",
    "showSecondaryBar",
    "secondaryBarSource",
    "professionSlot",
    "hideCompanionOutsideDelve",
    "secondaryBarsAttached",
    "maxLevelPrimaryShowsSecondary",
    "barLocked",
    "classicBarDraggable",
    "showMinimapButton",
    "showRestedOverlay",
    "showQuestXP",
    "showCompleteQuestOverlay",
    "showIncompleteQuestOverlay",
    "showPercentage",
    "showMilestoneTicks",
    "showQuestPercent",
    "showLevelText",
    "showXPText",
    "showRemainingXP",
    "showXPPerHourText",
    "showLevelTimeText",
    "showSessionTimeText",
    "resetOnReload",
    "showTimeToLevelText",
    "abbreviateNumbers",
    "enableAnimations",
    "flashOnGain",
    "twoPhaseOnLevelUp",
    "levelUpCelebration",
    "goalNotifications",
    "enableDataBrokerFeed",
    "classicWidth",
    "classicSegments",
    "flatSize",
    "verticalSize",
    "circularSize",
    "circularSegments",
    "circularUseTexture",
    "circularScaleCenterText",
    "circularSecondaryFullCircle",
    -- optionOrder is a separate list from the definitions above: a key defined
    -- but not ordered here simply does not render.
    "minimapRingPadding",
    "minimapRingSegments",
    "minimapRingCollectButtons",
    "minimapRingSegmentWidth",
    "minimapRingSegmentHeight",
    "minimapArcStartExpanded",
    "terminalUseCustomColors"
}

local colorOptionsList = {
    { key = "xpBar", label = Addon.L["COLOR_XP_BAR"], description = Addon.L["COLOR_XP_BAR_DESC"], preview = "statusbar" },
    { key = "xpBarRested", label = Addon.L["COLOR_XP_BAR_RESTED"], description = Addon.L["COLOR_XP_BAR_RESTED_DESC"], preview = "statusbar" },
    { key = "questComplete", label = Addon.L["COLOR_QUEST_COMPLETE"], description = Addon.L["COLOR_QUEST_COMPLETE_DESC"], preview = "texture" },
    { key = "questIncomplete", label = Addon.L["COLOR_QUEST_INCOMPLETE"], description = Addon.L["COLOR_QUEST_INCOMPLETE_DESC"], preview = "texture" },
    { key = "rested", label = Addon.L["COLOR_RESTED"], description = Addon.L["COLOR_RESTED_DESC"], preview = "texture" },
    { key = "secondaryProfession", label = Addon.L["COLOR_SECONDARY_PROFESSION"], description = Addon.L["COLOR_SECONDARY_PROFESSION_DESC"], preview = "statusbar" }
}

-- Inserted in display order; the index advances so a missing entry does not
-- leave a gap or reorder the ones that follow.
do
    local insertAt = 6

    if HAS_REPUTATION then
        table.insert(colorOptionsList, insertAt, { key = "secondaryReputation", label = Addon.L["COLOR_SECONDARY_REPUTATION"], description = Addon.L["COLOR_SECONDARY_REPUTATION_DESC"], preview = "statusbar" })
        insertAt = insertAt + 1
    end

    if HAS_HOUSING then
        table.insert(colorOptionsList, insertAt, { key = "secondaryHousing", label = Addon.L["COLOR_SECONDARY_HOUSING"], description = Addon.L["COLOR_SECONDARY_HOUSING_DESC"], preview = "statusbar" })
        insertAt = insertAt + 1
    end

    if HAS_HONOR then
        table.insert(colorOptionsList, insertAt, { key = "secondaryHonor", label = Addon.L["COLOR_SECONDARY_HONOR"], description = Addon.L["COLOR_SECONDARY_HONOR_DESC"], preview = "statusbar" })
        insertAt = insertAt + 1
    end
end

-- Build lookup map
local colorOptionByKey = {}
for index, info in ipairs(colorOptionsList) do
    info.order = index
    colorOptionByKey[info.key] = info
end

-- Export metadata to Config
Config.optionDetails = optionDetails
Config.optionOrder = optionOrder
Config.colorOptionsList = colorOptionsList
Config.colorOptionByKey = colorOptionByKey

return true
