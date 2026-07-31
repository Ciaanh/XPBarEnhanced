-- OptionMetadata.lua
-- Extracted options metadata from core/Config.lua into a separable file

local Addon = XPBarEnhanced
local Config = Addon.Config

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
        },
        commandKeys = {"preset", "readout"}
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
            {value = "sigil", label = Addon.L["OPT_BAR_STYLE_SIGIL"], shortLabel = Addon.L["OPT_BAR_STYLE_SHORT_SIGIL"]},
        },
        commandKeys = {"style", "mode", "barstyle"}
    },
    showSecondaryBar = {
        key = "showSecondaryBar",
        label = Addon.L["OPT_SHOW_SECONDARY_BAR"],
        description = Addon.L["OPT_SHOW_SECONDARY_BAR_DESC"],
        commandKeys = {}
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
        },
        commandKeys = {"secondarysource", "secondarybarsource"}
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
        },
        commandKeys = {"professionslot"}
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
    maxLevelPrimaryShowsSecondary = {
        key = "maxLevelPrimaryShowsSecondary",
        label = Addon.L["OPT_MAX_LEVEL_PRIMARY_SECONDARY"],
        description = Addon.L["OPT_MAX_LEVEL_PRIMARY_SECONDARY_DESC"],
        commandKeys = {"maxlevelsecondary", "maxsecondary"}
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
    levelUpCelebration = {
        key = "levelUpCelebration",
        label = Addon.L["OPT_LEVEL_UP_CELEBRATION"],
        description = Addon.L["OPT_LEVEL_UP_CELEBRATION_DESC"],
        commandKeys = {"celebration", "levelupcelebration"}
    },
    goalNotifications = {
        key = "goalNotifications",
        label = Addon.L["OPT_GOAL_NOTIFICATIONS"],
        description = Addon.L["OPT_GOAL_NOTIFICATIONS_DESC"],
        commandKeys = {"goalnotifications", "milestones"}
    },
    enableDataBrokerFeed = {
        key = "enableDataBrokerFeed",
        label = Addon.L["OPT_DATA_BROKER_FEED"],
        description = Addon.L["OPT_DATA_BROKER_FEED_DESC"],
        commandKeys = {"ldb", "databroker"}
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
        },
        commandKeys = {"flatsize"}
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
        },
        commandKeys = {"verticalsize"}
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
    -- Sigil. Populated from SigilSkins:GetSelectable(), which never lists the
    -- internal halo fallback -- so there is exactly one value at launch and
    -- Options.lua hides the row until a second selectable skin exists.
    sigilSkin = {
        key = "sigilSkin",
        type = "dropdown",
        label = Addon.L["OPT_SIGIL_SKIN"],
        description = Addon.L["OPT_SIGIL_SKIN_DESC"],
        options = (function()
            local skins = Addon.SigilSkins
            if skins and skins.GetSelectable then
                return skins:GetSelectable()
            end
            return {{value = "sigil", label = Addon.L["SKIN_SIGIL"]}}
        end)(),
        commandKeys = {"sigilskin"}
    },
    sigilSize = {
        key = "sigilSize",
        type = "dropdown",
        label = Addon.L["OPT_SIGIL_SIZE"],
        description = Addon.L["OPT_SIGIL_SIZE_DESC"],
        options = {
            {value = "small", label = Addon.L["OPT_SIGIL_SIZE_SMALL"]},
            {value = "medium", label = Addon.L["OPT_SIGIL_SIZE_MEDIUM"]},
            {value = "large", label = Addon.L["OPT_SIGIL_SIZE_LARGE"]},
            {value = "huge", label = Addon.L["OPT_SIGIL_SIZE_HUGE"]}
        },
        commandKeys = {"sigilsize"}
    },
    sigilTierMode = {
        key = "sigilTierMode",
        type = "dropdown",
        label = Addon.L["OPT_SIGIL_TIER_MODE"],
        description = Addon.L["OPT_SIGIL_TIER_MODE_DESC"],
        options = {
            {value = "auto", label = Addon.L["OPT_SIGIL_TIER_MODE_AUTO"]},
            {value = "pinned", label = Addon.L["OPT_SIGIL_TIER_MODE_PINNED"]}
        },
        commandKeys = {"sigiltier", "sigiltiermode"}
    },
    sigilPinnedTier = {
        key = "sigilPinnedTier",
        type = "slider",
        label = Addon.L["OPT_SIGIL_PINNED_TIER"],
        description = Addon.L["OPT_SIGIL_PINNED_TIER_DESC"],
        min = 1,
        max = 4,
        step = 1,
        format = "%.0f",
        commandKeys = {"sigilpinnedtier"}
    },
    sigilUseClassColor = {
        key = "sigilUseClassColor",
        label = Addon.L["OPT_SIGIL_USE_CLASS_COLOR"],
        description = Addon.L["OPT_SIGIL_USE_CLASS_COLOR_DESC"],
        commandKeys = {"sigilclasscolor"}
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
    "flatSize",
    "verticalSize",
    "circularSize",
    "circularSegments",
    "circularUseTexture",
    "circularScaleCenterText",
    "circularSecondaryFullCircle",
    -- optionOrder is a separate list from the definitions above: a key defined
    -- but not ordered here simply does not render.
    "sigilSkin",
    "sigilSize",
    "sigilTierMode",
    "sigilPinnedTier",
    "sigilUseClassColor",
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
    { key = "rested", command = "rested", aliases = {"rest"}, label = Addon.L["COLOR_RESTED"], description = Addon.L["COLOR_RESTED_DESC"], preview = "texture" },
    { key = "secondaryReputation", command = "secondaryreputation", aliases = {"repbar","reputationbar"}, label = Addon.L["COLOR_SECONDARY_REPUTATION"], description = Addon.L["COLOR_SECONDARY_REPUTATION_DESC"], preview = "statusbar" },
    { key = "secondaryHousing", command = "secondaryhousing", aliases = {"housingfavor"}, label = Addon.L["COLOR_SECONDARY_HOUSING"], description = Addon.L["COLOR_SECONDARY_HOUSING_DESC"], preview = "statusbar" },
    { key = "secondaryHonor", command = "secondaryhonor", aliases = {"honorbar"}, label = Addon.L["COLOR_SECONDARY_HONOR"], description = Addon.L["COLOR_SECONDARY_HONOR_DESC"], preview = "statusbar" },
    { key = "secondaryProfession", command = "secondaryprofession", aliases = {"professionbar","skillbar"}, label = Addon.L["COLOR_SECONDARY_PROFESSION"], description = Addon.L["COLOR_SECONDARY_PROFESSION_DESC"], preview = "statusbar" }
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
