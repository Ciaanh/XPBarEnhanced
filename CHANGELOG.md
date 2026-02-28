# Changelog

All notable changes to XP Bar Enhanced will be documented in this file.

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
