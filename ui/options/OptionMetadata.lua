-- OptionMetadata.lua
-- Extracted options metadata from core/Config.lua into a separable file

local Addon = XPBarEnhanced
local Config = Addon.Config

local optionDetails = {
    barStyle = {
        key = "barStyle",
        type = "dropdown",
        label = Addon.L["OPT_BAR_STYLE"],
        description = Addon.L["OPT_BAR_STYLE_DESC"],
        options = {
            {value = "none", label = Addon.L["OPT_BAR_STYLE_NONE"]},
            {value = "classic", label = Addon.L["OPT_BAR_STYLE_CLASSIC"]},
            {value = "flat", label = Addon.L["OPT_BAR_STYLE_FLAT"]},
            {value = "vertical", label = Addon.L["OPT_BAR_STYLE_VERTICAL"]},
            {value = "circular", label = Addon.L["OPT_BAR_STYLE_CIRCULAR"]},
            {value = "minimap_ring", label = Addon.L["OPT_BAR_STYLE_MINIMAP_RING"]},
            {value = "terminal", label = Addon.L["OPT_BAR_STYLE_TERMINAL"]},
        },
        commandKeys = {"style", "mode", "barstyle"}
    },
    showSecondaryBar = {
        key = "showSecondaryBar",
        label = Addon.L["OPT_SHOW_SECONDARY_BAR"],
        description = Addon.L["OPT_SHOW_SECONDARY_BAR_DESC"],
        commandKeys = {}
    },
    hideCompanionOutsideDelve = {
        key = "hideCompanionOutsideDelve",
        label = Addon.L["OPT_HIDE_COMPANION_OUTSIDE_DELVE"],
        description = Addon.L["OPT_HIDE_COMPANION_OUTSIDE_DELVE_DESC"],
        commandKeys = {}
    },
    secondaryBarsAttached = {
        key = "secondaryBarsAttached",
        label = Addon.L["OPT_SECONDARY_BARS_ATTACHED"],
        description = Addon.L["OPT_SECONDARY_BARS_ATTACHED_DESC"],
        commandKeys = {}
    },
    barLocked = {
        key = "barLocked",
        label = Addon.L["OPT_BAR_LOCKED"],
        description = Addon.L["OPT_BAR_LOCKED_DESC"],
        commandKeys = {"lock", "locked"}
    },
    classicBarDraggable = {
        key = "classicBarDraggable",
        label = Addon.L["OPT_CLASSIC_DRAGGABLE"] or "Classic Bar Draggable",
        description = Addon.L["OPT_CLASSIC_DRAGGABLE_DESC"] or "Allow the Classic bar to be dragged and positioned manually. When disabled, the Classic bar will be anchored to Blizzard's default position.",
        commandKeys = {"classicdraggable", "classicdrag"}
    },
    showMinimapButton = {
        key = "showMinimapButton",
        label = Addon.L["OPT_SHOW_MINIMAP_BUTTON"],
        description = Addon.L["OPT_SHOW_MINIMAP_BUTTON_DESC"],
        commandKeys = {"minimapbutton", "minimap"}
    },
    showRestedOverlay = {
        key = "showRestedOverlay",
        label = Addon.L["OPT_SHOW_RESTED_OVERLAY"],
        description = Addon.L["OPT_SHOW_RESTED_OVERLAY_DESC"],
        commandKeys = {"rested", "rest", "restoverlay"}
    },
    showQuestXP = {
        key = "showQuestXP",
        label = Addon.L["OPT_QUEST_XP"],
        description = Addon.L["OPT_QUEST_XP_DESC"],
        commandKeys = {"questxp", "quest"}
    },
    showCompleteQuestOverlay = {
        key = "showCompleteQuestOverlay",
        label = Addon.L["OPT_SHOW_COMPLETE_OVERLAY"],
        description = Addon.L["OPT_SHOW_COMPLETE_OVERLAY_DESC"],
        commandKeys = {"completeoverlay"}
    },
    showIncompleteQuestOverlay = {
        key = "showIncompleteQuestOverlay",
        label = Addon.L["OPT_SHOW_INCOMPLETE_OVERLAY"],
        description = Addon.L["OPT_SHOW_INCOMPLETE_OVERLAY_DESC"],
        commandKeys = {"incompleteoverlay"}
    },
    showPercentage = {
        key = "showPercentage",
        label = Addon.L["OPT_PERCENTAGE"],
        description = Addon.L["OPT_PERCENTAGE_DESC"],
        commandKeys = {"percentage"}
    },
    showMilestoneTicks = {
        key = "showMilestoneTicks",
        label = Addon.L["OPT_SHOW_MILESTONE_TICKS"],
        description = Addon.L["OPT_SHOW_MILESTONE_TICKS_DESC"],
        commandKeys = {"milestoneticks", "ticks"}
    },
    showQuestPercent = {
        key = "showQuestPercent",
        label = Addon.L["OPT_QUEST_PERCENT"],
        description = Addon.L["OPT_QUEST_PERCENT_DESC"],
        commandKeys = {"questpercent", "questpct"}
    },
    showLevelText = {
        key = "showLevelText",
        label = Addon.L["OPT_LEVEL_TEXT"],
        description = Addon.L["OPT_LEVEL_TEXT_DESC"],
        commandKeys = {"leveltext"}
    },
    showXPText = {
        key = "showXPText",
        label = Addon.L["OPT_XP_TEXT"],
        description = Addon.L["OPT_XP_TEXT_DESC"],
        commandKeys = {"xptext"}
    },
    showRemainingXP = {
        key = "showRemainingXP",
        label = Addon.L["OPT_REMAINING_XP"],
        description = Addon.L["OPT_REMAINING_XP_DESC"],
        commandKeys = {"remaining"}
    },
    showXPPerHourText = {
        key = "showXPPerHourText",
        label = Addon.L["OPT_XP_HOUR"],
        description = Addon.L["OPT_XP_HOUR_DESC"],
        commandKeys = {"xphour"}
    },
    showLevelTimeText = {
        key = "showLevelTimeText",
        label = Addon.L["OPT_LEVEL_TIME"],
        description = Addon.L["OPT_LEVEL_TIME_DESC"],
        commandKeys = {"leveltime"}
    },
    showSessionTimeText = {
        key = "showSessionTimeText",
        label = Addon.L["OPT_SESSION_TIME"],
        description = Addon.L["OPT_SESSION_TIME_DESC"],
        commandKeys = {"sessiontime"}
    },
    resetOnReload = {
        key = "resetOnReload",
        label = Addon.L["OPT_RESET_ON_RELOAD"],
        description = Addon.L["OPT_RESET_ON_RELOAD_DESC"],
        commandKeys = {"resetonreload", "reloadreset"}
    },
    showTimeToLevelText = {
        key = "showTimeToLevelText",
        label = Addon.L["OPT_TIME_TO_LEVEL"],
        description = Addon.L["OPT_TIME_TO_LEVEL_DESC"],
        commandKeys = {"timetolevel", "ttl"}
    },
    abbreviateNumbers = {
        key = "abbreviateNumbers",
        label = Addon.L["OPT_ABBREVIATE_NUMBERS"],
        description = Addon.L["OPT_ABBREVIATE_NUMBERS_DESC"],
        commandKeys = {"abbreviate"}
    },
    enableAnimations = {
        key = "enableAnimations",
        label = Addon.L["OPT_ENABLE_ANIMATIONS"],
        description = Addon.L["OPT_ENABLE_ANIMATIONS_DESC"],
        commandKeys = {"animations", "animate"}
    },
    flashOnGain = {
        key = "flashOnGain",
        label = Addon.L["OPT_FLASH_ON_GAIN"],
        description = Addon.L["OPT_FLASH_ON_GAIN_DESC"],
        commandKeys = {"flash"}
    },
    twoPhaseOnLevelUp = {
        key = "twoPhaseOnLevelUp",
        label = Addon.L["OPT_TWO_PHASE_LEVEL_UP"],
        description = Addon.L["OPT_TWO_PHASE_LEVEL_UP_DESC"],
        commandKeys = {"twophase", "levelupanimation"}
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
        },
        commandKeys = {"size", "circlesize", "circularsize"}
    },
    circularSegments = {
        key = "circularSegments",
        type = "slider",
        label = Addon.L["OPT_CIRCULAR_SEGMENTS"],
        description = Addon.L["OPT_CIRCULAR_SEGMENTS_DESC"],
        min = 25,
        max = 100,
        step = 5,
        format = "%.0f",
        commandKeys = {"segments", "circlesegments"}
    },
    circularUseTexture = {
        key = "circularUseTexture",
        label = Addon.L["OPT_CIRCULAR_USE_TEXTURE"],
        description = Addon.L["OPT_CIRCULAR_USE_TEXTURE_DESC"],
        commandKeys = {"texture", "circletexture"}
    },
    circularScaleCenterText = {
        key = "circularScaleCenterText",
        label = Addon.L["OPT_CIRCULAR_SCALE_CENTER_TEXT"],
        description = Addon.L["OPT_CIRCULAR_SCALE_CENTER_TEXT_DESC"],
        commandKeys = {"scalecentertext", "scaletext"}
    },
    circularSecondaryFullCircle = {
        key = "circularSecondaryFullCircle",
        label = Addon.L["OPT_CIRCULAR_SECONDARY_FULL_CIRCLE"],
        description = Addon.L["OPT_CIRCULAR_SECONDARY_FULL_CIRCLE_DESC"],
        commandKeys = {"secondaryfullcircle", "circlefull"}
    },
    minimapRingPadding = {
        key = "minimapRingPadding",
        type = "slider",
        label = Addon.L["OPT_MINIMAP_RING_PADDING"],
        description = Addon.L["OPT_MINIMAP_RING_PADDING_DESC"],
        min = 0,
        max = 32,
        step = 1,
        format = "%.0f",
        commandKeys = {"minimappadding", "ringpadding"}
    },
    minimapRingSegments = {
        key = "minimapRingSegments",
        type = "slider",
        label = Addon.L["OPT_MINIMAP_RING_SEGMENTS"],
        description = Addon.L["OPT_MINIMAP_RING_SEGMENTS_DESC"],
        min = 25,
        max = 100,
        step = 5,
        format = "%.0f",
        commandKeys = {"minimapsegments", "ringsegments"}
    },
    minimapRingCollectButtons = {
        key = "minimapRingCollectButtons",
        label = Addon.L["OPT_MINIMAP_RING_COLLECT_BUTTONS"],
        description = Addon.L["OPT_MINIMAP_RING_COLLECT_BUTTONS_DESC"],
        commandKeys = {"collectbuttons", "ringbuttons"}
    },
    minimapRingSegmentWidth = {
        key = "minimapRingSegmentWidth",
        type = "slider",
        label = Addon.L["OPT_MINIMAP_RING_SEGMENT_WIDTH"],
        description = Addon.L["OPT_MINIMAP_RING_SEGMENT_WIDTH_DESC"],
        min = 2,
        max = 10,
        step = 1,
        format = "%.0f",
        commandKeys = {"segmentwidth", "ringsegmentwidth"}
    },
    minimapRingSegmentHeight = {
        key = "minimapRingSegmentHeight",
        type = "slider",
        label = Addon.L["OPT_MINIMAP_RING_SEGMENT_HEIGHT"],
        description = Addon.L["OPT_MINIMAP_RING_SEGMENT_HEIGHT_DESC"],
        min = 5,
        max = 25,
        step = 1,
        format = "%.0f",
        commandKeys = {"segmentheight", "ringsegmentheight"}
    },
    minimapArcStartExpanded = {
        key = "minimapArcStartExpanded",
        label = Addon.L["OPT_MINIMAP_ARC_START_EXPANDED"],
        description = Addon.L["OPT_MINIMAP_ARC_START_EXPANDED_DESC"],
        commandKeys = {"arcstartexpanded", "minimaparcexpanded"}
    },
    terminalUseCustomColors = {
        key = "terminalUseCustomColors",
        label = Addon.L["OPT_TERMINAL_USE_CUSTOM_COLORS"],
        description = Addon.L["OPT_TERMINAL_USE_CUSTOM_COLORS_DESC"],
        commandKeys = {"terminalcustomcolors", "terminalcolors"}
    }
}

local optionOrder = {
    "barStyle",
    "showSecondaryBar",
    "hideCompanionOutsideDelve",
    "secondaryBarsAttached",
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
    "circularSize",
    "circularSegments",
    "circularUseTexture",
    "circularScaleCenterText",
    "circularSecondaryFullCircle",
    "minimapRingPadding",
    "minimapRingSegments",
    "minimapRingCollectButtons",
    "minimapRingSegmentWidth",
    "minimapRingSegmentHeight",
    "minimapArcStartExpanded",
    "terminalUseCustomColors"
}

local colorOptionsList = {
    { key = "xpBar", command = "xpbar", aliases = {"bar"}, label = Addon.L["COLOR_XP_BAR"], description = Addon.L["COLOR_XP_BAR_DESC"], preview = "statusbar" },
    { key = "xpBarRested", command = "xpBarRested", aliases = {"barrested","restedbar"}, label = Addon.L["COLOR_XP_BAR_RESTED"], description = Addon.L["COLOR_XP_BAR_RESTED_DESC"], preview = "statusbar" },
    { key = "questComplete", command = "questcomplete", aliases = {"complete"}, label = Addon.L["COLOR_QUEST_COMPLETE"], description = Addon.L["COLOR_QUEST_COMPLETE_DESC"], preview = "texture" },
    { key = "questIncomplete", command = "questincomplete", aliases = {"incomplete"}, label = Addon.L["COLOR_QUEST_INCOMPLETE"], description = Addon.L["COLOR_QUEST_INCOMPLETE_DESC"], preview = "texture" },
    { key = "rested", command = "rested", aliases = {"rest"}, label = Addon.L["COLOR_RESTED"], description = Addon.L["COLOR_RESTED_DESC"], preview = "texture" }
}

-- Build lookup maps
local colorOptionMap = {}
local colorOptionByKey = {}
for index, info in ipairs(colorOptionsList) do
    info.order = index
    colorOptionByKey[info.key] = info
    colorOptionMap[info.command] = info
    if info.aliases then
        for _, alias in ipairs(info.aliases) do
            colorOptionMap[alias] = info
        end
    end
end

-- Export metadata to Config
Config.optionDetails = optionDetails
Config.optionOrder = optionOrder
Config.colorOptionsList = colorOptionsList
Config.colorOptionMap = colorOptionMap
Config.colorOptionByKey = colorOptionByKey

return true
