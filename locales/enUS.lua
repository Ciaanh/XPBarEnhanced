local ADDON_NAME = "XPBarEnhanced"
local L = LibStub("AceLocale-3.0"):NewLocale(ADDON_NAME, "enUS", true)

if not L then
    return
end

-- ============================================================================
-- ADDON GENERAL
-- ============================================================================
L["ADDON_NAME"] = "XP Bar Enhanced"
L["ADDON_LOADED"] = "Loaded!"
L["CHANGELOG_TITLE"] = "What's New in XP Bar Enhanced"

-- ============================================================================
-- TOOLTIPS
-- ============================================================================
L["TT_EXPERIENCE"] = "Experience"
L["TT_CURRENT"] = "Current"
L["TT_REMAINING"] = "Remaining"
L["TT_CURRENT_FMT"] = "%s / %s (%.1f%%)"
L["TT_AMOUNT"] = "Amount"
L["TT_TO_LEVEL"] = "%s to level %d"
L["TT_RESTED"] = "Rested"
L["TT_RESTED_XP"] = "Rested XP"
L["TT_QUEST_XP"] = "Quest XP"
L["TT_STATUS"] = "Status"
L["TT_FULLY_RESTED"] = "Fully Rested"
L["TT_RESTED_TO_LEVEL"] = "Rested (to level)"
L["TT_RESTED_LOW_WARNING"] = "Almost out of rest! Visit an inn or city to rest."
L["TT_NORMAL"] = "Normal"
L["TT_QUEST_XP_AVAILABLE"] = "Quest XP Available"
L["TT_COMPLETE"] = "Complete"
L["TT_INCOMPLETE"] = "Incomplete"
L["TT_TOTAL"] = "Total"
L["TT_SESSION"] = "Session"
L["TT_GAINED"] = "Gained"
L["TT_TIME"] = "Time"
L["TT_XP_PER_HOUR"] = "XP/Hour"
L["TT_TIME_TO_LEVEL"] = "Time to level"
L["TT_SESSION_XP"] = "Session XP"
L["TT_CALCULATING"] = "Calculating..."
L["TT_OVER_99_HOURS"] = "99+ hours"
L["TT_SESSION_XP_GAINED"] = "Session XP Gained"
L["TT_SESSION_TIME"] = "Session Time"
L["TT_SESSION_STATS"] = "Session Stats"
L["TT_LEVEL_TIME"] = "Level Time"
L["TT_QUEST_XP_COMPLETE"] = "Completed Quest XP"
L["TT_QUEST_XP_INCOMPLETE"] = "Incomplete Quest XP"
L["TT_QUEST"] = "%d quest"
L["TT_QUESTS"] = "%d quests"
L["TT_QUESTS_COMPLETE"] = "Completed Quests: %s"
L["TT_QUESTS_INCOMPLETE"] = "Incomplete Quests: %s"
L["TT_NONE"] = "None"
L["TT_NA"] = "N/A"
L["TT_LEVELING_IN"] = "Leveling in"
L["TT_RESTED_FMT"] = "%s (%.1f%%)"
L["TT_RESTING"] = "Resting"

-- Tooltip hints and formatting
L["TT_HINTS"] = "Alt+Click to reset; Shift+Drag to move; Ctrl+Click for options."
L["TT_HINT_DRAG"] = "Shift+Drag to move"
L["TT_HINT_ALT_OPTIONS"] = "Alt+Click for options"
L["TT_HINT_CTRL_STATS"] = "Ctrl+Click to toggle stats"

L["TT_LEVEL_FMT"] = "Level %d"
-- Tooltip hints
L["TT_HINT_CONFIG"] = "Right-click to configure XP Bar"

-- Terminal style legend
L["TT_TERMINAL_LEGEND"]    = "Terminal Legend"
L["TT_TERMINAL_EARNED"]    = "█ Green: Earned XP"
L["TT_TERMINAL_QUEST_DONE"]= "█ Amber: Quest XP (completed)"
L["TT_TERMINAL_QUEST_TODO"]= "▒ Amber: Quest XP (in progress)"
L["TT_TERMINAL_RESTED"]    = "▒ Teal: Rested bonus"
L["TT_TERMINAL_EMPTY"]     = "░ Dim: Not earned"

-- Modifier display names
L["KEY_SHIFT"] = "Shift"
L["KEY_CTRL"] = "Ctrl"
L["KEY_ALT"] = "Alt"

-- ============================================================================
-- OPTIONS PANEL
-- ============================================================================
-- Muted notes on rows the active bar style cannot render. Such rows stay visible
-- but disabled, so the panel's shape does not change when switching style.
L["OPT_UNAVAIL_NO_BAR"] = "— no bar to animate"
-- %s is a bar style's display name, e.g. "— Circular only".
L["OPT_UNAVAIL_STYLE_ONLY"] = "— %s only"
-- The Sigil pinned-tier row while the tier mode is automatic.
L["OPT_UNAVAIL_TIER_AUTO"] = "— pinned tier only"
-- Colours belonging to a secondary source that is not the one on screen.
L["OPT_UNAVAIL_NOT_ACTIVE"] = "— not active"
L["OPT_COLOR_ACTIVE"] = "(active)"

-- Readout presets: named starting points for the boolean options
L["OPT_READOUT_PRESET"] = "Readout preset"
L["OPT_READOUT_PRESET_DESC"] =
    "A starting point for every on/off setting. Changing any individual toggle switches this to Custom."
L["OPT_READOUT_PRESET_MINIMAL"] = "Minimal"
L["OPT_READOUT_PRESET_MINIMAL_DESC"] = "Percentage only — nothing beneath the bar."
L["OPT_READOUT_PRESET_STANDARD"] = "Standard"
L["OPT_READOUT_PRESET_STANDARD_DESC"] = "Level, XP, percentage, and the session readouts."
L["OPT_READOUT_PRESET_LEVELLER"] = "Leveller"
L["OPT_READOUT_PRESET_LEVELLER_DESC"] = "Standard plus milestone ticks and incomplete quest XP."
L["OPT_READOUT_PRESET_CUSTOM"] = "Custom"
L["OPT_READOUT_PRESET_RESET"] = "Reset to Standard"

-- Collapsible section holding the individual toggles a preset covers
L["OPT_SECTION_ADVANCED"] = "Advanced"
-- Collapsible section holding the colours of the secondary sources not in use
L["OPT_SECTION_OTHERSOURCES"] = "Other secondary sources"

-- Current options in OptionsMetadata
L["OPT_SHOW_RESTED_OVERLAY"] = "Show rested overlay"
L["OPT_SHOW_RESTED_OVERLAY_DESC"] = "Show an overlay for rested XP on the XP bar when rested XP is available."

L["OPT_QUEST_XP"] = "Quest XP display"
L["OPT_QUEST_XP_DESC"] = "Display quest XP overlays and tooltip breakdown."
L["OPT_SHOW_COMPLETE_OVERLAY"] = "Show completed quest overlay"
L["OPT_SHOW_COMPLETE_OVERLAY_DESC"] = "Display the orange overlay showing XP from completed quests ready to turn in."
L["OPT_SHOW_INCOMPLETE_OVERLAY"] = "Show incomplete quest overlay"
L["OPT_SHOW_INCOMPLETE_OVERLAY_DESC"] =
    "Display the yellow semi-transparent overlay showing XP from incomplete quests (doesn't reduce bar width)."
L["OPT_PERCENTAGE"] = "Show percentage"
L["OPT_PERCENTAGE_DESC"] = "Display current percentage progress as text overlaid on the XP bar itself."
L["OPT_SHOW_MILESTONE_TICKS"] = "Show milestone ticks"
L["OPT_SHOW_MILESTONE_TICKS_DESC"] = "Overlay small tick marks and percent labels at 25%, 50%, 75%, and 100% on the Flat bar. Ticks before the current position take on the bar color; remaining ticks are dimmed."
L["OPT_QUEST_PERCENT"] = "Include quest XP in percentage"
L["OPT_QUEST_PERCENT_DESC"] =
    "Show percentage with quest XP included. Example: '75% (80%)' where 80% includes completed quest XP ready to turn in. Requires 'Show percentage ON the bar' to be enabled."
L["OPT_LEVEL_TEXT"] = "Show level"
L["OPT_LEVEL_TEXT_DESC"] = "Display your current level number as text overlaid on the left side of the XP bar."
L["OPT_XP_TEXT"] = "Show XP amounts"
L["OPT_XP_TEXT_DESC"] = "Display current/max XP numbers as text overlaid on the XP bar itself (e.g., '1250/5000')."
L["OPT_REMAINING_XP"] = "Show remaining XP"
L["OPT_REMAINING_XP_DESC"] = "Display how much XP is needed to level as text beneath the XP bar."
L["OPT_XP_HOUR"] = "Show XP/hour"
L["OPT_XP_HOUR_DESC"] = "Display experience gained per hour as text beneath the XP bar."
L["OPT_LEVEL_TIME"] = "Show level time"
L["OPT_LEVEL_TIME_DESC"] = "Display time spent on current level as text beneath the XP bar."
L["OPT_SESSION_TIME"] = "Show session time"
L["OPT_SESSION_TIME_DESC"] = "Display time played this session as text beneath the XP bar."
L["OPT_RESET_ON_RELOAD"] = "Reset session on /reload"
L["OPT_RESET_ON_RELOAD_DESC"] = "When enabled, UI reload starts a fresh XP session. When disabled, session elapsed time and rates continue across /reload."
L["OPT_TIME_TO_LEVEL"] = "Show time to next level"
L["OPT_TIME_TO_LEVEL_DESC"] =
    "Display estimated time remaining to reach next level (based on current XP/hour rate) as text beneath the XP bar."
L["OPT_ABBREVIATE_NUMBERS"] = "Abbreviate numbers"
L["OPT_ABBREVIATE_NUMBERS_DESC"] = "Use abbreviated number format (K, M, B) instead of full numbers in all displays."

-- Subsection headers
-- (see "Text Display Section Headers" below for the canonical definitions)

-- Options
L["OPT_BAR_STYLE"] = "Bar Style"
L["OPT_BAR_STYLE_DESC"] = "Choose which XP bar to display: None (Blizzard only), Classic (Blizzard-style), Flat (Draggable), Vertical, Circular (Progress ring), Minimap Ring, Terminal (ASCII progress bar), or Orb (filling sphere)."
-- Short forms for the style gallery captions and the "<Style> only" row notes.
-- The long labels above stay for prose; they do not fit a 120px swatch.
L["OPT_BAR_STYLE_SHORT_NONE"] = "None"
L["OPT_BAR_STYLE_SHORT_CLASSIC"] = "Classic"
L["OPT_BAR_STYLE_SHORT_FLAT"] = "Flat"
L["OPT_BAR_STYLE_SHORT_VERTICAL"] = "Vertical"
L["OPT_BAR_STYLE_SHORT_CIRCULAR"] = "Circular"
L["OPT_BAR_STYLE_SHORT_MINIMAP_RING"] = "Minimap Ring"
L["OPT_BAR_STYLE_SHORT_TERMINAL"] = "Terminal"
L["OPT_BAR_STYLE_SHORT_ORB"] = "Orb"
L["OPT_BAR_STYLE_SHORT_SIGIL"] = "Sigil"
L["OPT_BAR_STYLE_NONE"] = "None (Blizzard only)"
L["OPT_BAR_STYLE_CLASSIC"] = "Classic (Blizzard-style)"
L["OPT_BAR_STYLE_FLAT"] = "Flat (Custom draggable)"
L["OPT_BAR_STYLE_VERTICAL"] = "Vertical (Falling XP)"
L["OPT_BAR_STYLE_CIRCULAR"] = "Circular (Progress ring)"
L["OPT_BAR_STYLE_MINIMAP_RING"] = "Minimap Ring"
L["OPT_BAR_STYLE_TERMINAL"] = "Terminal (ASCII progress bar)"
L["OPT_BAR_STYLE_ORB"] = "Orb (filling sphere)"
L["OPT_BAR_STYLE_SIGIL"] = "Sigil (tiered class ring)"
L["OPT_BAR_STYLE_MAX_LEVEL"] = "Blizzard Bar (Max Level)"
L["OPT_BAR_STYLE_MAX_LEVEL_DESC"] = "Disabled at max level: Blizzard experience bar enforced"
L["OPT_BAR_LOCKED"] = "Lock bar position"
L["OPT_BAR_LOCKED_DESC"] = "Prevent the Flat bar from being moved with Shift+Drag. Applies only to Flat bar style."
L["OPT_SHOW_MINIMAP_BUTTON"] = "Show minimap button"
L["OPT_SHOW_MINIMAP_BUTTON_DESC"] = "Display the XP Bar Enhanced button on the minimap for quick access to stats and options."
L["OPT_CLASSIC_DRAGGABLE"] = "Classic bar draggable"
L["OPT_CLASSIC_DRAGGABLE_DESC"] = "Allow the Classic bar to be dragged and positioned manually. When disabled, the Classic bar will be anchored to Blizzard's default position."
L["OPT_RESET_BAR_POSITION"] = "Reset Bar Position"
L["OPT_RESET_BAR_POSITION_DESC"] = "Reset the Flat bar to its default position at the bottom center of the screen."
L["OPT_RESET_SETTINGS"] = "Reset Settings"
L["OPT_RESET_STATS"] = "Reset Statistics"

-- Text Display Section Headers
L["OPT_TEXT_ON_BAR"] = "Text ON the Bar"
L["OPT_TEXT_BELOW_BAR"] = "Text BELOW the Bar"
L["OPT_TEXT_LEFT"] = "Left"
L["OPT_TEXT_MIDDLE"] = "Middle"
L["OPT_TEXT_RIGHT"] = "Right"

-- Header labels for Options UI
L["OPT_HEADER_BAR_SETTINGS"] = "Bar Settings"
L["OPT_HEADER_DISPLAY_FEATURES"] = "Display Features"
L["OPT_HEADER_QUEST_FEATURES"] = "Quest Features"
L["OPT_HEADER_TEXT_DISPLAY"] = "Text Display"
L["OPT_HEADER_ANIMATION"] = "Animation"
L["OPT_HEADER_COLORS"] = "Colors"
L["OPT_HEADER_CIRCULAR"] = "Circular Bar"
L["OPT_HEADER_SECONDARY_BARS"] = "Secondary Bars"

-- Options panel chrome (subtitle + tab labels)
L["OPT_SUBTITLE"] = "Configure the custom experience bar, quest overlays, and leveling statistics."
L["OPT_TAB_VISUAL"] = "Visual"
L["OPT_TAB_TEXT"] = "Text"
L["OPT_TAB_BEHAVIOR"] = "Behavior"
L["OPT_TAB_SECONDARY"] = "Secondary Bar"
L["OPT_TAB_COLORS"] = "Colors"

L["OPT_HEADER_PROFILES"] = "Profiles"
L["OPT_PROFILE_SELECTOR"] = "Profile => "
L["OPT_PROFILE_GLOBAL"] = "Global Settings"
L["OPT_PROFILE_NEW"] = "New"
L["OPT_PROFILE_RENAME"] = "Rename"
L["OPT_PROFILE_DELETE"] = "Delete"
L["OPT_PROFILE_CREATE_DIALOG"] = "Create a new profile"
L["OPT_PROFILE_CREATE_INSTRUCTIONS"] = "New profiles copy the current effective settings and can be shared across characters."
L["OPT_PROFILE_RENAME_DIALOG"] = "Rename profile"
L["OPT_PROFILE_DELETE_DIALOG"] = "Delete profile '%s'?\n\nAll characters using it will fall back to Global Settings."
L["MSG_PROFILE_CREATED"] = "Profile created: %s"
L["MSG_PROFILE_RENAMED"] = "Profile renamed to: %s"
L["MSG_PROFILE_DELETED"] = "Profile deleted: %s"
L["MSG_PROFILE_SELECTED"] = "Active profile: %s"
L["MSG_PROFILE_GLOBAL"] = "Using global shared settings"
L["ERR_PROFILE_INVALID_NAME"] = "Invalid profile name."
L["ERR_PROFILE_EXISTS"] = "A profile with that name already exists."
L["ERR_PROFILE_MISSING"] = "Profile not found."
L["ERR_PROFILE_GLOBAL_RENAME"] = "Global settings cannot be renamed."
L["ERR_PROFILE_GLOBAL_DELETE"] = "Global settings cannot be deleted."

-- Secondary bar options
L["OPT_SHOW_SECONDARY_BAR"] = "Show secondary bar"
L["OPT_SHOW_SECONDARY_BAR_DESC"] = "Show the tracked reputation bar as a secondary progress bar. When the watched faction is a Delve companion, the bar uses companion-specific display rules."
L["OPT_SECONDARY_BAR_SOURCE"] = "Secondary source"
L["OPT_SECONDARY_BAR_SOURCE_DESC"] = "Choose which progression source drives the secondary bar."
L["OPT_SECONDARY_BAR_SOURCE_REPUTATION"] = "Reputation"
L["OPT_SECONDARY_BAR_SOURCE_HOUSING"] = "Housing Favor"
L["OPT_SECONDARY_BAR_SOURCE_HONOR"] = "Honor"
L["OPT_SECONDARY_BAR_SOURCE_PROFESSION"] = "Profession"
L["OPT_PROFESSION_SLOT"] = "Tracked profession"
L["OPT_PROFESSION_SLOT_DESC"] = "Which profession the Profession secondary source tracks. Auto picks the first primary profession that still has room to grow."
L["OPT_PROFESSION_SLOT_AUTO"] = "Auto"
L["OPT_PROFESSION_SLOT_FIRST"] = "First profession"
L["OPT_PROFESSION_SLOT_SECOND"] = "Second profession"
L["OPT_HIDE_COMPANION_OUTSIDE_DELVE"] = "Hide companion bar outside Delves"
L["OPT_HIDE_COMPANION_OUTSIDE_DELVE_DESC"] = "When enabled, the secondary bar is hidden if the watched faction is a Delve companion and you are not inside a Delve."
L["OPT_SECONDARY_BARS_ATTACHED"] = "Attach to XP bar"
L["OPT_SECONDARY_BARS_ATTACHED_DESC"] = "When enabled, the secondary bar is locked to the XP bar position. When disabled, it can be positioned independently by dragging."
L["OPT_MAX_LEVEL_PRIMARY_SECONDARY"] = "Use main bar at max level"
L["OPT_MAX_LEVEL_PRIMARY_SECONDARY_DESC"] = "At max level, show the selected secondary source on the main bar instead of hiding it. Requires a custom bar style and the secondary bar enabled. The standalone secondary bar is hidden while this is active to avoid showing the same source twice."

-- Animation options
L["OPT_ENABLE_ANIMATIONS"] = "Enable animations"
L["OPT_ENABLE_ANIMATIONS_DESC"] = "Enable smooth fill animations when XP changes."
L["OPT_FLASH_ON_GAIN"] = "Flash on XP gain"
L["OPT_FLASH_ON_GAIN_DESC"] = "Briefly flash the bar when XP is gained."
L["OPT_TWO_PHASE_LEVEL_UP"] = "Two-phase level-up animation"
L["OPT_TWO_PHASE_LEVEL_UP_DESC"] = "When leveling up, animate the bar filling to 100% first, then reset and animate to your new XP."
L["OPT_LEVEL_UP_CELEBRATION"] = "Level-up celebration"
L["OPT_LEVEL_UP_CELEBRATION_DESC"] = "Play a golden glow effect on the bar when you level up."
L["OPT_GOAL_NOTIFICATIONS"] = "Level progress notifications"
L["OPT_GOAL_NOTIFICATIONS_DESC"] = "Announce 25%, 50% and 75% level progress with the estimated time to level up."
L["OPT_DATA_BROKER_FEED"] = "LibDataBroker feed"
L["OPT_DATA_BROKER_FEED_DESC"] = "Publish XP rate and time-to-level to LibDataBroker displays such as Titan Panel, Bazooka, or ElvUI datatexts."

-- Goal / milestone notifications
L["GOAL_MILESTONE"] = "Level %d: %d%%"
L["GOAL_MILESTONE_ETA"] = "Level %d: %d%% - ding in ~%s"

-- LibDataBroker feed
L["LDB_LABEL"] = "XP Bar Enhanced"
L["LDB_TEXT_FMT"] = "%s XP/h \194\183 ~%s"
L["LDB_RATE_FMT"] = "%s XP/h"
L["LDB_SOURCE_FMT"] = "%s: %d%%"
L["LDB_CALCULATING"] = "XP: calculating..."
L["LDB_MAX_LEVEL"] = "Max level"
L["LDB_TT_SESSION_XP"] = "Session XP:"
L["LDB_TT_RATE"] = "XP per hour:"
L["LDB_TT_CLICK"] = "Click to toggle the stats window"

-- Session chart (Stats window)
L["STATS_CHART_TITLE"] = "Session XP Rate"
L["STATS_CHART_EMPTY"] = "No XP gained yet this session."
L["STATS_CHART_RATE_FORMAT"] = "%s/h"
L["STATS_CHART_SPLIT_LEGEND"] = "Quest %d%%  \194\183  Other %d%%"

-- Stats window row labels
-- The hero cards and the summary strip print their label above or beside a
-- number, so those three carry no trailing colon; the detail rows keep theirs.
L["STATS_LABEL_XP_PER_HOUR"] = "XP/hour"
L["STATS_LABEL_EST_TIME_TO_LEVEL"] = "Time to level"
L["STATS_LABEL_XP_GAINED"] = "Gained"
L["STATS_LABEL_LEVELS_GAINED"] = "Levels"
L["STATS_LABEL_DURATION"] = "Played"
-- Collapsible section holding the bookkeeping rows
L["STATS_SECTION_DETAIL"] = "Details"
L["STATS_LABEL_LEVEL"] = "Level:"
L["STATS_LABEL_CURRENT_XP"] = "Current XP:"
L["STATS_LABEL_MAX_XP"] = "Max XP:"
L["STATS_LABEL_PROGRESS"] = "Progress:"
L["STATS_LABEL_XP_TO_LEVEL"] = "XP to Level:"
L["STATS_LABEL_RESTED_XP"] = "Rested XP:"
L["STATS_LABEL_QUEST_XP"] = "Quest XP:"
L["STATS_LABEL_TIME_ON_LEVEL"] = "Time on Level:"
L["STATS_LABEL_STARTED"] = "Started:"

-- Minimap button
L["MINIMAP_TT_SESSION_XP"] = "Session XP:"
L["MINIMAP_TT_SESSION_TIME"] = "Session Time:"
L["MINIMAP_TT_HINT_LEFT_CLICK"] = "|cff00ff00Left-Click:|r Open Stats"
L["MINIMAP_TT_HINT_RIGHT_CLICK"] = "|cff00ff00Right-Click:|r Open Options"
L["MINIMAP_TT_HINT_SHIFT_CLICK"] = "|cff00ff00Shift-Click:|r Reset Session"
L["MINIMAP_TT_HINT_DRAG"] = "|cff00ff00Drag:|r Move Button"

-- Circular bar options
L["OPT_BAR_SIZE_SMALL"] = "Small"
L["OPT_BAR_SIZE_DEFAULT"] = "Default"
L["OPT_BAR_SIZE_LARGE"] = "Large"
L["OPT_BAR_SIZE_HUGE"] = "Huge"
L["OPT_FLAT_SIZE"] = "Flat bar size"
L["OPT_FLAT_SIZE_DESC"] = "Scale up the Flat bar without shrinking it, preserving text readability."
L["OPT_VERTICAL_SIZE"] = "Vertical bar size"
L["OPT_VERTICAL_SIZE_DESC"] = "Scale up the Vertical bar without shrinking it, preserving text readability."
L["OPT_CIRCULAR_SIZE"] = "Ring size"
L["OPT_CIRCULAR_SIZE_DESC"] = "Size of the circular progress ring. Enable 'Scale center text with ring' to make center text grow with the ring."
L["OPT_CIRCULAR_SIZE_SMALL"] = "Small"
L["OPT_CIRCULAR_SIZE_MEDIUM"] = "Medium"
L["OPT_CIRCULAR_SIZE_LARGE"] = "Large"
L["OPT_CIRCULAR_SIZE_HUGE"] = "Huge"

-- Sigil style
L["SKIN_SIGIL"] = "Sigil"
L["SKIN_HALO"] = "Halo"
L["OPT_SIGIL_SKIN"] = "Sigil skin"
L["OPT_SIGIL_SKIN_DESC"] = "Which frame set the Sigil ring wears."
L["OPT_SIGIL_SIZE"] = "Sigil size"
L["OPT_SIGIL_SIZE_DESC"] = "Size of the Sigil ring. The centre readout scales with it; at Small the percentage row is hidden so the level stays legible."
L["OPT_SIGIL_SIZE_SMALL"] = "Small"
L["OPT_SIGIL_SIZE_MEDIUM"] = "Medium"
L["OPT_SIGIL_SIZE_LARGE"] = "Large"
L["OPT_SIGIL_SIZE_HUGE"] = "Huge"
L["OPT_SIGIL_TIER_MODE"] = "Tier"
L["OPT_SIGIL_TIER_MODE_DESC"] = "Automatic advances the frame through four tiers as you approach the level cap. Pinned keeps one tier regardless of level."
L["OPT_SIGIL_TIER_MODE_AUTO"] = "Automatic (by level)"
L["OPT_SIGIL_TIER_MODE_PINNED"] = "Pinned"
L["OPT_SIGIL_PINNED_TIER"] = "Pinned tier"
L["OPT_SIGIL_PINNED_TIER_DESC"] = "Which tier to display when Tier is set to Pinned."
L["OPT_SIGIL_USE_CLASS_COLOR"] = "Tint with class colour"
L["OPT_SIGIL_USE_CLASS_COLOR_DESC"] = "Tint the Sigil frame and crest with your class colour. Off uses the configured XP bar colour instead."
L["OPT_CIRCULAR_SEGMENTS"] = "Segment count"
L["OPT_CIRCULAR_SEGMENTS_DESC"] = "Number of segments in the circular progress ring. Lower values give a chunky look, higher values appear smoother."
L["OPT_CIRCULAR_USE_TEXTURE"] = "Use textured segments"
L["OPT_CIRCULAR_USE_TEXTURE_DESC"] = "Use a textured appearance for segments instead of solid color. Gives a more detailed look to the circular bar."
L["OPT_CIRCULAR_SCALE_CENTER_TEXT"] = "Scale center text with ring"
L["OPT_CIRCULAR_SCALE_CENTER_TEXT_DESC"] = "When enabled, the level, percentage, and time-to-level text in the center of the ring scales proportionally with the ring size. Useful for streamers or anyone who wants larger numbers."
L["OPT_CIRCULAR_SECONDARY_FULL_CIRCLE"] = "Secondary arc as full circle"
L["OPT_CIRCULAR_SECONDARY_FULL_CIRCLE_DESC"] = "For circular style secondary bars, render a full 360-degree inner ring instead of the default semi-circular arc."

L["OPT_MINIMAP_RING_PADDING"] = "Minimap ring padding"
L["OPT_MINIMAP_RING_PADDING_DESC"] = "Extra distance between the minimap edge and the XP ring segments."
L["OPT_MINIMAP_RING_SEGMENTS"] = "Minimap ring segments"
L["OPT_MINIMAP_RING_SEGMENTS_DESC"] = "Number of visible segments in the minimap ring. Lower values look chunkier; higher values appear smoother."
L["OPT_MINIMAP_RING_COLLECT_BUTTONS"] = "Collect addon minimap buttons"
L["OPT_MINIMAP_RING_COLLECT_BUTTONS_DESC"] = "Collapse addon minimap buttons into an XP Bar Enhanced bag button to keep the ring clear. Blizzard minimap buttons are ignored."
L["OPT_MINIMAP_RING_BAG_ANGLE"] = "Bag button angle"
L["OPT_MINIMAP_RING_BAG_ANGLE_DESC"] = "Angle in degrees used to place the minimap button bag around the ring. 0 is right, 90 is top."

L["OPT_MINIMAP_RING_SEGMENT_WIDTH"] = "Segment width"
L["OPT_MINIMAP_RING_SEGMENT_WIDTH_DESC"] = "Base width of each ring segment in pixels. The value auto-scales with segment count so spacing stays consistent."
L["OPT_MINIMAP_RING_SEGMENT_HEIGHT"] = "Segment height"
L["OPT_MINIMAP_RING_SEGMENT_HEIGHT_DESC"] = "Radial height (thickness) of each ring segment in pixels."
L["OPT_MINIMAP_ARC_START_EXPANDED"] = "Start minimap arc expanded"
L["OPT_MINIMAP_ARC_START_EXPANDED_DESC"] = "For minimap ring secondary bars, show the reputation arc by default when it appears."
L["OPT_MINIMAP_ARC_ICON_SCALE"] = "Minimap arc icon scale"
L["OPT_MINIMAP_ARC_ICON_SCALE_DESC"] = "Scale of the minimap reputation toggle icon."

-- Terminal bar options
L["OPT_TERMINAL_USE_CUSTOM_COLORS"] = "Use custom bar colors"
L["OPT_TERMINAL_USE_CUSTOM_COLORS_DESC"] = "When disabled, the Terminal bar uses hardcoded authentic terminal colors (phosphor green, amber, teal). When enabled, Terminal bar will use your custom color settings from the Colors panel."

-- Color options
L["COLOR_XP_BAR"] = "XP Bar Fill"
L["COLOR_XP_BAR_DESC"] = "Primary color of the experience bar."
L["COLOR_XP_BAR_RESTED"] = "XP Bar Fill (Rested)"
L["COLOR_XP_BAR_RESTED_DESC"] = "Color of the experience bar when you are rested."
L["COLOR_QUEST_COMPLETE"] = "Completed Quest Overlay"
L["COLOR_QUEST_COMPLETE_DESC"] = "Color of XP earned from completed quests."
L["COLOR_QUEST_INCOMPLETE"] = "Incomplete Quest Overlay"
L["COLOR_QUEST_INCOMPLETE_DESC"] = "Color of XP from quests still in progress."
L["COLOR_RESTED"] = "Rested XP Overlay"
L["COLOR_RESTED_DESC"] = "Color of the rested XP segment of the bar."
L["COLOR_SECONDARY_REPUTATION"] = "Secondary Bar: Reputation"
L["COLOR_SECONDARY_REPUTATION_DESC"] = "Color of the secondary bar when Reputation is selected as the source."
L["COLOR_SECONDARY_HOUSING"] = "Secondary Bar: Housing Favor"
L["COLOR_SECONDARY_HOUSING_DESC"] = "Color of the secondary bar when Housing Favor is selected as the source."
L["COLOR_SECONDARY_HONOR"] = "Secondary Bar: Honor"
L["COLOR_SECONDARY_HONOR_DESC"] = "Color of the secondary bar when Honor is selected as the source."
L["COLOR_SECONDARY_PROFESSION"] = "Secondary Bar: Profession"
L["COLOR_SECONDARY_PROFESSION_DESC"] = "Color of the secondary bar when Profession is selected as the source."

-- Color picker rows (Options panel)
L["OPT_COLOR_CURRENT_FMT"] = "Current: #%s (Alpha %d%%)"
L["OPT_COLOR_SWATCH_TITLE_FMT"] = "%s Color"
L["OPT_COLOR_SWATCH_RESET_HINT"] = "Shift-Click to restore the default color."

-- ============================================================================
-- MESSAGES
-- ============================================================================
L["MSG_OPTION_ENABLED"] = "%s enabled"
L["MSG_OPTION_DISABLED"] = "%s disabled"
L["MSG_COLOR_SET"] = "%s color set to #%s"
L["MSG_COLOR_RESET"] = "%s color reset to default"
L["MSG_UNKNOWN_COMMAND"] = "Unknown command:"
L["MSG_STATS_UNAVAILABLE"] = "Stats feature is unavailable."
L["MSG_OPTIONS_UNAVAILABLE"] = "Options panel is unavailable."
L["MSG_RESET_UNAVAILABLE"] = "Unable to reset settings."
L["MSG_RESET_STATS_UNAVAILABLE"] = "Unable to reset statistics."
L["MSG_SETTINGS_RESET"] = "Settings reset to defaults"
L["MSG_SESSION_RESET"] = "Session reset."
L["MSG_USE_STATS_COMMAND"] = "Use /xpbe stats to open stats window."
L["MSG_USE_OPTIONS_COMMAND"] = "Use /xpbe to open options."
L["MSG_COLOR_PICKER_UNAVAILABLE"] = "Color picker is not available."

-- ============================================================================
-- REPUTATION
-- ============================================================================
L["REP_STANDING_RENOWN"] = "Renown %d"
L["REP_STANDING_PARAGON"] = "Paragon"
L["HOUSING_NAME"] = "Housing Favor"
L["HOUSING_MAX_LEVEL_LABEL"] = "Max House Level"
L["HOUSING_LEVEL_FMT"] = "Level %d"

-- ============================================================================
-- HONOR / PROFESSION (secondary bar sources)
-- ============================================================================
L["HONOR_NAME"] = "Honor"
L["HONOR_LEVEL_FMT"] = "Honor Level %d"
L["PROFESSION_NAME"] = "Profession"
L["PROFESSION_MAX_LABEL"] = "Max Skill"
L["LABEL_MAX"] = "MAX"

-- ============================================================================
-- ERRORS
-- ============================================================================
L["ERR_UNKNOWN_COLOR_TARGET"] = "Unknown color target."
L["ERR_INVALID_COLOR"] = "Invalid color. Use a hex value such as 4C63FF or 4C63FFFF."
L["ERR_NO_DEFAULT_COLOR"] = "No default color available."
L["ERR_INIT_FAILED"] = "Initialization failed: missing core modules."
L["ERR_EVENT_HANDLER_FAILED"] = "Event %s handler failed: %s"
