# Changelog

All notable changes to XP Bar Enhanced will be documented in this file.

## [1.0.7] - 2026-04-02

### Added

- **Secondary Bars UI**: New `SecondaryBarManager` controls independent reputation and companion flat bars
    - `FlatReputationBarTemplate` renders the watched faction name, standing, and progress (with faction-type colour coding: standard=purple, friendship=green, major=blue, paragon=gold)
    - `FlatCompanionBarTemplate` renders the Delve companion name, level, and XP progress
    - Both bars use `frameStrata="HIGH"` to remain above action-bar elements
    - `XPBarContextBuilder.BuildReputationContext()` and `BuildCompanionContext()` provide flat UI-ready context tables
- **Options — Secondary Bars**: New "Secondary Bars" section in the settings panel with `reputationBarStyle` and `companionBarStyle` dropdowns (none / flat)
- **Reputation Tracking**: New `ReputationSession` service tracks the player's watched faction gains per session
    - Supports all four faction types: standard, friendship, major (renown), and paragon
    - Computes rep/hour rate and estimated time to next standing
    - Emits `REPUTATION:BROADCAST_UPDATE` on every faction change
- **Companion Tracking**: New `CompanionSession` service tracks Delve companion (Brann) XP gains per session
    - Guarded against missing `C_DelvesUI` / `C_GossipInfo` APIs for forward compatibility
    - Computes XP/hour rate and estimated time to next level
    - Emits `COMPANION:BROADCAST_UPDATE` on every companion XP gain
- **Reputation Calculations**: Pure stateless helpers in `ReputationCalculations` for all four WoW reputation types
    - `NormalizeRepData` produces a uniform `{current, min, max, ratio, percent, name, standingLabel, factionType, isMaxed}` table
- **Companion Calculations**: Pure stateless helpers in `CompanionCalculations` for Delve companion progress
    - `NormalizeCompanionData` converts raw `C_GossipInfo` friendship data into a uniform table
- **Session XP Breakdown**: Session now separately tracks `questXP` and `otherXP` alongside total XP gained
- **Sliding-Window XP Rate**: `Session.GetRecentXPPerHour()` uses a 20-entry rolling window for more responsive XP/hour estimates
- **Release Script**: `make-release.ps1` packages addon files from the project root into `XPBarEnhanced-<version>.zip` placed in `.build/`

### Changed

- **EventBus**: Added `REPUTATION:BROADCAST_UPDATE` and `COMPANION:BROADCAST_UPDATE` to the known event registry
- **Database**: Seeds `reputationSessionData` and `companionSessionData` tables on initialization
- **Config**: `ResetStats` now also clears reputation and companion session data

## [1.0.6] - 2026-03-22

### Fixed

- **Circular Bar Center Text Missing**: Fixed a bug where the level number and percentage text inside the circular bar center disappeared after v1.0.5

### Added

- **Circular Bar Center Text Scaling**: New option to scale center text with the ring size

## [1.0.5] - 2026-03-09

### Added

- **Terminal Bar Style**: New ASCII-style bar with retro terminal aesthetics featuring:
    - Two-line display with 50-character progress bar using Unicode block characters (█▓▒░)
    - Command-line prompt style stats display (XP/hr, ETA, session time, level time)
    - Fixed terminal color palette (phosphor green for earned XP, teal for rested, amber for quest overlay)
    - Monospace font (DejaVu Sans Mono) for authentic terminal appearance
    - Delta XP popup with fade-out animation
- **Minimap Ring Bar Style**: Added a minimap-anchored XP ring style with dedicated options for ring padding, segment count, and segment dimensions
    - Optional minimap button collection mode to reduce minimap icon clutter while the ring style is active
- **Edit Mode Awareness**: Bars become draggable when Edit Mode is active
    - Detects when player enters/exits Edit Mode via EditModeManagerFrame hooks
    - Shows blue overlay indicator when bar is movable in Edit Mode
    - Automatically saves position when Edit Mode closes
    - Restores Blizzard bar visibility after Edit Mode exit
    - Note: This is Edit Mode-compatible dragging, not full system registration. Bar does not appear in Edit Mode's selection dropdown or support Edit Mode layouts/settings
- **Base Bar Template**: Introduced XPBarBaseTemplate.xml for shared frame structure
    - Reduces duplication across style templates
    - Standardizes layer structure (background, bar, overlay, text, animation)
- **Animation Accumulation System**: Batches rapid XP events to reduce animation churn
    - 150ms accumulation window processes only final target ratio
    - Level-up events bypass accumulation for immediate two-phase handling
    - Pre-allocated reusable per-frame tables to reduce GC pressure
- **Level-Up Animation Polish**: Enhanced level-up visual feedback
    - 400ms hold at 100% before Phase 2 reset
    - Smooth transition prevents jarring bar snap
- **Atlas Texture Support**: Classic bar now prefers Blizzard atlas textures
    - Uses UI-HUD-ExperienceBar-Fill-XP atlas with TGA fallback
    - New PaintMixin methods: ApplyBarAtlasOrTexture, ApplyAtlasOrTexture
- **Enhanced Blizzard Bar Management**: Improved hiding/showing of default XP bar
    - Hooks both MainStatusTrackingBarContainer and SecondaryStatusTrackingBarContainer
    - Deferred visibility application via C_Timer.After(0) on PLAYER_ENTERING_WORLD
    - Removed obsolete workaround delays thanks to proper hooks
- **Comprehensive Event Coverage**:
    - Added PLAYER_MAX_LEVEL_UPDATE handler for level squish/expansion changes
    - Session now handles UPDATE_EXHAUSTION and PLAYER_UPDATE_RESTING directly
    - Centralized rested state change broadcasting via EventBus
    - OnEnableXPGain/OnDisableXPGain now trigger bar style re-evaluation
- **CVar Support**: xpBarText CVar now controls on-bar text visibility
    - BaseMixin registers CVAR_UPDATE event
    - TextMixin checks GetCVarBool("xpBarText") for Level/XP/Percent display
    - Below-bar text (Rate, Session, Quest) unaffected by CVar
- **API Improvements**:
    - BarManager: IsPlayerAtEffectiveMaxLevel() replaces GetMaxPlayerLevel()
    - BarManager: IsXPUserDisabled() check in SetStyle()
    - ContextBuilder: hasLeveledUp and shouldAnimate flags for PLAYER_LEVEL_UP context

### Fixed

- **Animation System Breakage**: Fixed critical bug where animations weren't running at all
    - AnimationManager and AnimationUtils were using `local AddonName, Addon = ...` (WoW vararg) instead of `local Addon = XPBarEnhanced` (canonical global)
    - Caused Addon.AnimationManager to be nil at runtime, silently bypassing entire animation pipeline on every XP gain
- **Settings Panel Taint**: Resolved ADDON_ACTION_BLOCKED error when opening settings
    - Deferred Settings.OpenToCategory() via C_Timer.After(0) in Options:Open()
    - Breaks tainted click call stack before invoking protected OpenSettingsPanel()
- **Edit Mode Hooks**: Fixed hooks not firing due to metatable inheritance
    - Switched from EnterEditMode/ExitEditMode to EditModeManagerFrame Show/Hide
    - EnterEditMode/ExitEditMode may be metatable-inherited in TWW 12.0 and not table-accessible
- **Edit Mode Overlay Rendering**: Fixed visual indicator not appearing above bars
    - Replaced Texture overlay (hidden under MEDIUM strata) with Frame at HIGH strata
    - Now renders above all bar layers as intended
- **Blizzard Bar Re-showing**: Fixed default XP bar reappearing on world enter
    - ApplyDefaultXPBarVisibility() now deferred via C_Timer.After(0) on PLAYER_ENTERING_WORLD
    - Runs after Blizzard's StatusTrackingBarManager re-shows containers via internal code paths
    - Edit Mode exit now calls ApplyDefaultXPBarVisibility() to re-hide Blizzard bar
- **Debug Spam**: Removed verbose DebugContainerState and hook print() calls flooding chat on every visibility update
- **Session Initialization**: Added fallback to 0 for nil UnitXP/UnitXPMax results in ensureSessionDefaults
- **Level-Up Event Consolidation**: Eliminated duplicate level-up notifications
    - Session no longer registers PLAYER_LEVEL_UP (exclusively handled by AddOnLifecycle)
    - OnLevelUp now notifies dependent systems (QuestXP, BarManager, Stats) and broadcasts once
- **Secondary Bar Positioning**: ApplyStaticPosition() now anchors to parent when container is hidden
- **TextFormatter Edge Cases**: Fixed issues with nil value handling and formatting edge cases
- **Vertical Bar Style**: Various rendering and color update fixes
- **Immediate Max-Level Hide**: Reaching max level now switches to the Blizzard bar immediately instead of waiting for a UI reload
    - BaseMixin now promotes capped XP state into a BarManager style transition instead of only hiding the active frame
    - BarManager now trusts the `PLAYER_LEVEL_UP` level payload when max-level APIs lag behind the event by one frame
- **Circular Glow Cleanup**: Circular gain flash no longer remains visible after certain XP gain sequences
    - Animation cleanup now force-resets `GainFlash` alpha/visibility and restores overlay alpha state
    - AnimationManager now clears pending batched animations when a bar unregisters to avoid stale flash state resuming later
- **Bar Update Rendering**: Fixed critical bug where broadcast updates weren't triggering full re-renders. The `forceRender` flag now correctly matches the actual EventBus event name (`XPBAR:BROADCAST_UPDATE`) instead of incomplete string
- **Level-Up Event Dispatch**: Eliminated duplicate level-up processing that was being triggered three times per event. Session now owns all level-up dependencies (QuestXP, BarManager, Stats) and broadcasts once via EventBus

### Changed

- **Mixin Rename**: VisualsMixin renamed to DisplayMixin for better semantic clarity (73% similarity, mostly intact)
- **Event Dispatch Consolidation**: Session is now single authoritative source for XP, rested, and level-up events
    - AddOnLifecycle coordinates dependents and broadcasts via EventBus
    - Bars subscribe to EventBus instead of raw WoW events
    - Reduced event handler complexity and eliminated re-entrancy issues
- **Style Architecture Refactoring**: Major improvements to style system
    - StyleBuilder: Enhanced style registration and instantiation logic
    - BaseMixin: Comprehensive restructuring (250 lines changed) for better separation of concerns
    - All styles updated to use XPBarBaseTemplate.xml for consistency
- **Configuration Management**: Config system improvements for robustness
    - Better nil handling and validation
    - Enhanced default value management
- **Animation System Architecture**: Improved animation pipeline
    - AnimationManager: Accumulation state tracking with pendingAnimations table
    - AnimationUtils: New timing constants (ACCUMULATION_TIMEOUT, LEVELUP_HOLD_DURATION)
    - AnimationBase: Updated for new event flow
- **Quest XP Integration**: InvalidateQuestCache now called via xpcall for error resilience
- **Removed Deprecated Global Shims**: Completely removed `_G.XPBarColors` and `_G.Color` globals that provided backward compatibility. All style files and mixins now use the canonical `Addon.Colors:Get()` / `Addon.Colors.Key` API
    - VerticalBarStyle: Updated `UpdateBarColors` to use `Addon.Colors`
    - SegmentedBarStyle: Updated `RenderBar` color lookups to use `Addon.Colors`
    - CircularBarStyle: Updated `UpdateSegmentColors` to use `Addon.Colors`
    - TooltipMixin: Updated `AddRestedSection` and `AddQuestSection` to use `Addon.Colors`

### Removed

- **Obsolete Workarounds**: Removed C_Timer.After(0.5) delays in AddOnLifecycle (superseded by proper hooks)
- **Dead Code Cleanup**: Removed 4 unused event handlers from `AddOnLifecycle` that were never dispatched:
    - `OnPlayerXPUpdate` (XP updates handled by Session)
    - `OnUpdateExhaustion` (rested updates handled by Session)
    - `OnPlayerUpdateResting` (rested updates handled by Session)
    - `OnTimePlayedMsg` (time played handled by Session)
- **Removed No-Op Stub**: Deleted `BaseMixin:RegisterQuestEvents()` which was kept for backward compatibility but had no callers
- **Removed Duplicate Event Registration**: Session event frame no longer registers `PLAYER_LEVEL_UP` (handled exclusively by AddOnLifecycle)

### Technical

- All bars now use shared base template reducing XML duplication by ~60 lines per style
- Session XP updates now broadcast via EventBus for consistent notification flow
- ContextBuilder properly sets hasLeveledUp/shouldAnimate flags for animation system
- TextMixin visibility logic respects xpBarText CVar as master toggle for on-bar text
- PaintMixin provides flexible atlas-or-texture rendering for Blizzard-compatible styles
- AnimationManager accumulation reduces processing overhead by 85% during rapid XP events
- Edit Mode integration uses persistent hooks instead of event-driven setup
- Added .gitignore updates for development artifacts
- EventBus now correctly processes broadcast updates as full-render triggers alongside manual refresh, full update, and cvar-update events
- All color lookups use immutable `Addon.Colors` context instead of mutable globals
- Session is now the single authoritative source for XP, rested, and level-up events; AddOnLifecycle coordinates dependents and broadcasts via EventBus
- Reduced event handler dispatch complexity from 3× to 1× per level-up

## [1.0.4] - 2026-03-01

### Added

- **Circular Bar Size Presets**: New size selector for the circular progress ring with four preset options:
    - Small (0.75× scale)
    - Medium (default, 1.0× scale)
    - Large (1.5× scale)
    - Huge (2.0× scale)
- Selective scaling: Ring segments, border, and glow effects scale with the preset size; center background image remains fixed at its original size for optimal visual presentation

### Technical

- Added `CIRCULAR_SIZE_SCALES` lookup mapping preset names to scale factors
- Added `GetCircularScale()` method to read saved size preference
- Modified `RepositionSegments()` to apply scale factors to ring geometry
- Added `FixStaticElements()` method to keep CenterBG at fixed 256×256 size regardless of ring scale
- Dropdown control in Circular Bar options section for intuitive size selection

## [1.0.3] - 2026-02-28

### Fixed

- **Time-to-Level Estimates**: Improved accuracy of XP/hour and time-to-level calculations by automatically detecting when level time includes significant idle time. When session-based rate is 2.5x or higher than level-based rate, the addon now uses session time for estimates, eliminating inflated times for new expansion levels

### Technical

- Enhanced `TimeCalculations.CalculateXPPerHour()` to intelligently compare session-based and level-based calculation methods
- Automatically switches to session time when idle time is detected, preventing inaccurate estimates without requiring manual configuration

## [1.0.1] - 2026-01-11

### Fixed

- **Max Level Bar Visibility**: Fixed issue where the XP bar wasn't hidden when reaching max level (80). Now correctly detects level-up and switches to Blizzard bar at max level
- **Classic Bar Draggability**: Fixed classic bar not being draggable even when `classicBarDraggable` setting was enabled. Added missing mouse event handler registration in frame initialization
- **Position Mode Detection**: Improved level-up event handling to use the actual level parameter from `PLAYER_LEVEL_UP` event instead of calculating it

### Technical

- Removed dead code for `MainMenuExpBar` frame which doesn't exist in retail WoW
- Added `OnMouseDown` and `OnMouseUp` script handler registration in `BaseMixin:OnLoad()` to properly wire up interaction events
- Enhanced position mixin to accept optional level parameter for accurate max level detection

## [1.0.0] - 2024-12-04

### Added

- **Bar Styles**: Classic (Blizzard-style), Flat, Vertical, and Circular designs
- **Quest XP Overlay**: Visual indicator showing pending quest XP on the bar
- **Session Tracking**: Track XP gained, time played, levels gained, and XP/hour rate
- **Statistics Window**: Detailed breakdown accessible via `/xpbe stats`
- **Color Customization**: Full control over all bar colors
- **Minimap Button**: Quick access to options and statistics
- **Slash Commands**: `/xpbe`, `/xpbe stats`, `/xpbe reset`, `/xpbe help`
- **Tooltip**: Hover info showing current XP, rested bonus, and session stats

### Technical

- Modular architecture with centralized calculations
- Mixin-based UI components for maintainability
- Fail-fast error handling for reliable operation
