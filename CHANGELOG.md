# Changelog

All notable changes to XP Bar Enhanced will be documented in this file.

## [1.0.5] - 2026-03-01

### Fixed

- **Bar Update Rendering**: Fixed critical bug where broadcast updates weren't triggering full re-renders. The `forceRender` flag now correctly matches the actual EventBus event name (`XPBAR:BROADCAST_UPDATE`) instead of incomplete string
- **Level-Up Event Dispatch**: Eliminated duplicate level-up processing that was being triggered three times per event. Session now owns all level-up dependencies (QuestXP, BarManager, Stats) and broadcasts once via EventBus

### Changed

- **Removed Deprecated Global Shims**: Completely removed `_G.XPBarColors` and `_G.Color` globals that provided backward compatibility. All style files and mixins now use the canonical `Addon.Colors:Get()` / `Addon.Colors.Key` API
  - VerticalBarStyle: Updated `UpdateBarColors` to use `Addon.Colors`
  - SegmentedBarStyle: Updated `RenderBar` color lookups to use `Addon.Colors`
  - CircularBarStyle: Updated `UpdateSegmentColors` to use `Addon.Colors`
  - TooltipMixin: Updated `AddRestedSection` and `AddQuestSection` to use `Addon.Colors`

### Removed

- **Dead Code Cleanup**: Removed 4 unused event handlers from `AddOnLifecycle` that were never dispatched:
  - `OnPlayerXPUpdate` (XP updates handled by Session)
  - `OnUpdateExhaustion` (rested updates handled by Session)
  - `OnPlayerUpdateResting` (rested updates handled by Session)
  - `OnTimePlayedMsg` (time played handled by Session)
- **Removed No-Op Stub**: Deleted `BaseMixin:RegisterQuestEvents()` which was kept for backward compatibility but had no callers
- **Removed Duplicate Event Registration**: Session event frame no longer registers `PLAYER_LEVEL_UP` (handled exclusively by AddOnLifecycle)

### Technical

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
