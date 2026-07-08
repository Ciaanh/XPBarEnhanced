# Changelog

All notable changes to XP Bar Enhanced will be documented in this file.

## [Unreleased]

### Added

- **Fade when inactive**: optional auto-fade of the bar to a configurable idle opacity after a delay with no XP gain; wakes on XP gain, level-up, mouseover, or option change, and never fades during combat (`fadeWhenInactive`, `fadeDelay`, `idleOpacity`).
- **Level-up celebration**: optional golden glow pulse on the bar at level-up, with an optional fanfare sound (`levelUpCelebration`, `celebrationSound`).
- **Session charts** in the Stats window: an XP/hour histogram across the session plus a quest-vs-other XP split bar, rendered in a new chart panel.

## [1.1.7] - 2026-07-03

### Fixed

- **Level-Up XP Accounting**: Session XP no longer drops the level-crossing amount. `Session:OnLevelUp` now credits the wrap-around XP of the old level before re-baselining (handles `PLAYER_LEVEL_UP` arriving before `PLAYER_XP_UPDATE`), and `XPCalculations.ComputeGain` detects level-ups from level snapshots instead of relying solely on `xpMax` changes (fixes equal-`xpMax` consecutive levels and multi-level jumps).
- **Renown/Paragon/Housing Gains at Thresholds**: Reputation gained across a renown level or paragon cycle is now credited via wrap-aware gain computation; housing favor gained across a house level-up is no longer discarded; paragon `threshold = 0` no longer produces NaN.
- **Minimap Ring Zoom Error**: Mouse-wheeling over the minimap ring hit strips no longer throws — replaced removed `Minimap_ZoomIn`/`Minimap_ZoomOut` globals with `Minimap:SetZoom`.
- **Profile Overrides Everywhere**: Session, ReputationSession, ContextBuilder, TextFormatter and quest-summary paths now resolve options through `Config:GetOptionValue`, so active profile overrides apply; `Config:SetOptionKey` writes profile overrides even when the value matches the inherited one; `/xpbe resetcolors` and `Colors:ResetAll` clear profile color overrides and refresh without `/reload`.
- **Per-Character Sessions**: XP/reputation/housing session data is now stored per character (alts no longer inherit played time); housing session resets on login like the other sessions; level time no longer inflated by offline wall-clock.
- **Chat Filter**: The played-time chat suppression now only blocks the actual "Time played" lines and times out after 5 seconds, instead of swallowing all system messages indefinitely on a lost response.
- **Animation Flash**: Tiny XP gains with flash enabled no longer overwrite the bar fill with a stale ratio for the flash duration.
- **Combat Deferral**: Deferred Blizzard-bar hides reuse a single frame (no frame leak) and re-check style state at combat end, so switching to style "none" mid-combat can no longer hide Blizzard's XP bar; profile-change deferral no longer misses combat ending within 0.1s.
- **EventBus**: Removed the deferred-registration mechanism (subscriptions made during dispatch could never be unregistered and leaked); handlers unregistered mid-dispatch are no longer invoked from the stale snapshot.
- **Stats Window**: No longer leaks a global `frame`; subscribes to EventBus broadcasts instead of registering WoW events directly; skips refreshes while hidden; honors `abbreviateNumbers`; removed per-frame empty `OnUpdate`; window position restore prefers saved anchor data (survives UI-scale changes).
- **Options Panel**: Scroll height now measures actual content instead of a hardcoded 800px, making tall tabs fully scrollable; removed dead `hideBlizzardBar`/`questOverlaysEnabled` branches and 13 orphaned defaults for features that don't exist.
- **Bar Position**: Switching the classic bar from static to draggable positioning no longer teleports it to the screen corner (positions are captured as true screen coordinates).
- **Misc**: Exhaustion-tick tooltip now reports actual rested XP; XP/h text honors `abbreviateNumbers`; tooltips only hide when owned (no longer dismissing other addons' tooltips); changelog popup shows only unseen entries and pools its font strings; secret-safe housing GUID handling; profile names count UTF-8 characters; full-circle secondary ring no longer overlaps its first segment.

## [1.1.6] - 2026-06-21

### Fixed

- **Housing XP Bar Refresh**: Secondary bar no longer displays stale data after gaining housing favor. Fixed a bug in `SecondaryBarBaseMixin.MarkDirty` where the force-refresh sentinel was cleared before `GetLatestContext` could see it, causing the bar to re-render with the previous context instead of fetching fresh data from `HousingSession`.

## [1.1.5] - 2026-06-21

### Added

- **Secondary Source Selection**: Added `secondaryBarSource` option with `reputation` and `housing` modes.
- **Housing Session Service**: Added `HousingSession` to track and broadcast tracked-house favor progress for secondary bars.
- **Housing Event Routing**: Routed `TRACKED_HOUSE_CHANGED` and `HOUSE_LEVEL_FAVOR_UPDATED` through `EventRouter`.

### Changed

- **Secondary Source Resolution**: Shared secondary style helpers now resolve context from either reputation or housing based on config and availability.
- **Secondary Event Subscription**: Secondary bar base mixin now supports multi-event subscriptions so the live secondary bar refreshes immediately when the selected source changes.

### Fixed

- **Secondary Refresh Consistency**: Secondary bar source and style-sensitive option changes now trigger both reputation and housing update emissions to avoid stale displays.

## [1.1.4] - 2026-05-12

### Added

- **Flat Bar Size Presets**: New `flatSize` option (Small / Default / Large / Huge) scales the Flat bar and its secondary reputation bar proportionally without shrinking text readability.
- **Vertical Bar Size Presets**: New `verticalSize` option (Small / Default / Large / Huge) scales the Vertical bar and its secondary reputation bar proportionally.
- **Flat Under-Bar Text Scaling**: Flat style now scales below-bar text with `flatSize` so typography remains proportional at every bar size.

### Fixed

- **Overlay Height Mismatch**: Quest-complete, quest-incomplete, and rested overlays now inherit their height from the live StatusBar rather than defaulting to a hardcoded value, so overlays fill the full bar height on scaled Flat and Vertical bars.
- **Overlay Width on Scaled Bars**: `ValidateBarWidth` now reads the live `StatusBar:GetWidth()` first, ensuring overlay pixel math is based on the current runtime size rather than the style's initial config width.
- **Milestone Ticks on Scaled Flat Bar**: Milestone tick positions and heights are recalculated after every `ResizeToScale` call so ticks remain correctly spaced on Large and Huge flat bars.
- **Milestone Ticks Setting Toggle**: Toggling `showMilestoneTicks` in the options panel now immediately triggers `UpdateMilestoneTicks` without requiring a full bar reload.
- **Secondary Tooltip on Unavailable Bar**: `ShowSecondaryTooltip` now early-returns when `context.isAvailable == false`, preventing a tooltip from appearing on a hidden secondary bar.
- **Terminal Secondary Bar Tooltip Guard**: `OnEnter` on the terminal secondary bar now skips tooltip display when the context marks the bar as unavailable.
- **Terminal Custom Color Resolution**: Terminal palette rendering now resolves `terminalUseCustomColors` via config accessors, keeping custom color behavior consistent with active profile settings.

## [1.1.3] - 2026-04-22

### Added

- **Profile System**: New profile workflow in the options panel, including profile selection, creation, rename, and delete.
- **Blizzard-Style Profile Menu**: Profiles dropdown with radio selection plus inline row actions and an in-menu New Profile action.
- **Profile-Aware Settings Access**: Added centralized profile-aware option lookups via `Utils.GetOptionValue` and migrated key callers to the shared helper.

### Fixed

- **Reputation Bar at Max Level**: Secondary reputation bar now renders correctly when the player is at max level and the primary XP bar is hidden.
- **Companion Detection in Delves**: Companion presence is now detected via party roster name match (`UnitName` on `partyN` slots) instead of the unreliable `C_DelvesUI.GetFactionForCompanion` path, which returned `nil` in all tested cases.
- **Companion Bar Refresh on Roster Change**: `GROUP_ROSTER_UPDATE` now triggers a reputation visibility refresh so the companion bar appears and disappears correctly as Brann joins or leaves the delve group.
- **Minimap Ring Button Collection**: Fixed button collection ownership and shared scan timer to prevent duplicate registrations and nil-reference errors.

## [1.1.2] - 2026-04-19

### Fixed

- **Bar Hidden After Level-Up**: The XP bar was being hidden a second or so after every level-up due to `UIFrameFlash` being called with `showWhenDone=false` in `BaseMixin:OnLevelUpCelebration`. Blizzard's `UIFrameFlash` calls `frame:Hide()` at the end of the animation when this flag is false. Changed to `true` so the frame remains visible after the flash completes.
- **Blizzard Bar Taint on Combat Start/End**: `BarManager` and `SecondaryBarManager` now guard all `Hide()` calls on `MainStatusTrackingBarContainer` behind `InCombatLockdown()`, deferring to `PLAYER_REGEN_ENABLED` to prevent taint during combat.
- **TIME_PLAYED_MSG Chat Noise**: A chat-frame filter now suppresses the system time-played message that fired whenever the addon internally requested `RequestTimePlayed`. The filter is active only during the request window and is cleared immediately after the message is caught.
- **Delve Companion Detection Fallback**: `ReputationSession` now falls back to `IsInInstance()` returning `"scenario"` to detect Delves when `C_Garrison.IsInDelve` is unavailable, ensuring companion decoration mode activates correctly in all cases.
- **GetQuestCounts Off-by-One**: `QuestXP:GetQuestCounts()` was counting XP amounts instead of quest entries, producing incorrect quest overlay totals. Fixed to count entries.
- **Redundant DB Assignment on Init**: `AddOnLifecycle` was re-assigning `Addon.db` after `Database:Initialize` had already set it. Removed the redundant write.
- **ShortNumber Duplication**: `Utils.ShortNumber()` now delegates to `TextFormatter:AbbreviateNumber()` when available, eliminating two divergent number-abbreviation implementations.
- **Stale Reputation Delta**: `ReputationSession` now re-snapshots the watched faction when `GetFactionSnapshot` returns `nil`, preventing a stale delta from being carried into the next update.
- **Orphan xpBarColor Alias**: Removed the unused `xpBarColor` alias from `defaults.lua` and the redundant `Addon.db.xpBarColor` sync write in `Config:SetColor`.

## [1.1.1] - 2026-04-18

### Added

- **In-Game Update Popup**: Added a one-time "What's New" changelog splash shown after updating to a new addon version
- **Changelog Slash Command**: Added `/xpbe changelog` to reopen the in-game update notes on demand

### Changed

- **Popup Release Notes**: Added concise per-version summaries to the in-game changelog so it highlights key updates without duplicating the full release notes
- **Circular Secondary Refresh Path**: Circular secondary bar geometry now rebuilds immediately when relevant circular settings change

### Fixed

- **Circular Reputation Arc Scaling**: Fixed the circular secondary reputation bar not scaling with the circular size when center scaling was enabled
- **Changelog Viewer Availability**: Fixed `/xpbe changelog` failing after load due to addon namespace state being overwritten during startup

## [1.1.0] - 2026-04-17

### Added

- **Secondary Reputation Bar**: New `SecondaryBarManager` with unified tracked-reputation secondary bar
    - `FlatReputationBarTemplate` renders the watched faction name, standing, and progress (faction-type colour coding: standard=purple, friendship=green, major=blue, paragon=gold)
    - `ClassicReputationBarTemplate` label restored and refreshed by text ticker (`GetTextTickerInterval` / `OnTextTick`)
    - `VerticalReputationBarTemplate`: 20×300 vertical `StatusBar` (`orientation="VERTICAL"`) with right-side attachment via `GetAttachedAnchor() → "LEFT", "RIGHT", 2, 0`, `ANCHOR_RIGHT` tooltip, and style-aware fallback positioning
    - `TerminalReputationBarTemplate`: single-line 650×22 ASCII phosphor reputation bar using `DejaVuSansMono.ttf` in `OnSecondaryLoad`; 20-character `█`/`░` fill, standing-aware phosphor colors, and inline faction/standing/%/session delta text
    - Companion decoration mode: when tracking a Delve companion faction, bar switches to companion flavor (level display, teal colour) driven by `isCompanion` context flag
    - Locale-safe companion detection via `defaults.delveCompanions` factionID → name map (Brann 2640, Valeera 2744); ID-first lookup with name fallback
    - Fade transitions, drag-to-move with SavedVariables persistence, hover tooltips, live text refresh
    - Attached mode stacks secondary bar above primary; free drag at max level when primary is hidden
    - TEMPLATE_MAP-driven style derivation scales correctly as new styles are added
    - `ShouldSuppressMainContainer()` prevents duplicate Blizzard reputation bar at max level
- **Options — Secondary Bar**: `showSecondaryBar` toggle and `hideCompanionOutsideDelve` option to hide companion bar outside Delves
- **Options Panel Sections**: Grouped scroll layout with 9 section headers and style-conditional visibility for Circular, Minimap Ring, and Terminal options
- **Reputation Tracking**: New `ReputationSession` service tracks the player's watched faction gains per session
    - Supports all four faction types: standard, friendship, major (renown), and paragon
    - Companion tracking integrated as decoration mode (not a separate domain)
    - Session-owned context building via `ReputationSession._BuildContext()`
    - Computes rep/hour rate and estimated time to next standing
    - Emits `REPUTATION_BROADCAST_UPDATE` on every faction change
- **Reputation Calculations**: Pure stateless helpers in `ReputationCalculations` for all four WoW reputation types
    - `NormalizeRepData` produces a uniform `{current, min, max, ratio, percent, name, standingLabel, factionType, isMaxed}` table
- **Session XP Breakdown**: Session now separately tracks `questXP` and `otherXP` alongside total XP gained
- **Sliding-Window XP Rate**: `Session.GetRecentXPPerHour()` uses a 20-entry rolling window for more responsive XP/hour estimates
- **Text Ticker**: Lightweight `BuildTextRefreshContext()` path for periodic text refresh; avoids full context rebuild every 2.5s
- **Max-Level Events**: `UPDATE_EXPANSION_LEVEL` and `MAX_EXPANSION_LEVEL_UPDATED` added to EventRouter for immediate max-level visibility re-evaluation
- **Release Script**: `make-release.ps1` packages addon files from the project root into `XPBarEnhanced-<version>.zip` placed in `.build/`

### Changed

- **Context Ownership**: Session layers (`Session:EmitUpdate`, `ReputationSession:EmitUpdate`) are the sole emitters of domain EventBus events; managers and Config no longer build context directly
- **XP/hour Warm-up**: Lowered threshold from 30s to 10s for faster initial rate display
- **Quest XP Overlay**: Excluded `isTask` quests (world quests, bonus objectives) from XP overlay totals
- **Secondary Bar Position**: Dynamic `GetFallbackPosition()` derived from active XP bar style replaces static default
- **Secondary Bar Attachment API**: Added optional `GetAttachedAnchor()` hook on secondary style mixins; `ReapplyAttachedPositions()` in `SecondaryBarManager` now uses style-provided `(point, relPoint, x, y)` anchors when present
- **Secondary Bar Style Model**: Replaced `AUTO_PAIR` table and `secondaryBarStyle` user config with direct 1:1 `TEMPLATE_MAP[db.barStyle]` derivation. Primary styles without an entry produce no secondary bar.
- **Secondary Bar Strata**: Raised all secondary bar templates from `frameStrata="LOW"` to `frameStrata="MEDIUM"` to match primary text draw layer
- **EventBus**: Added `REPUTATION_BROADCAST_UPDATE` to the known event registry
- **Database**: Seeds `reputationSessionData` table on initialization
- **Config**: `ResetStats` now also clears reputation session data

### Fixed

- **Duplicate Blizzard Reputation Bar**: At max level, `MainStatusTrackingBarContainer` now suppressed when custom secondary bar is active
- **Fade-In Symmetry**: Fade-in and fade-out now use consistent animation patterns
- **SavePosition Bug**: Frame-reference serialization corrected to use UIParent BOTTOMLEFT normalization
- **Classic Bar — QuestSummaryText Overlap**: `QuestSummaryText` anchor in `ClassicBarTemplate.xml` was `y="30"` (above the bar), causing overlap with secondary bar space; corrected to `y="-14"`

### Removed

- `secondaryBarStyle` SavedVariables key and dropdown option (superseded by automatic 1:1 pairing)
- `AUTO_PAIR` table from `SecondaryBarManager.lua`
- Six `OPT_SECONDARY_BAR_STYLE*` locale strings
- `MinimalSecondaryBarStyle.lua` and `MinimalSecondaryBarTemplate.xml` (dead code, unreferenced by `TEMPLATE_MAP`)

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
- **Blizzard Bar Re-showing**: Fixed default XP bar reappearing on world enter
    - ApplyDefaultXPBarVisibility() now deferred via C_Timer.After(0) on PLAYER_ENTERING_WORLD
    - Runs after Blizzard's StatusTrackingBarManager re-shows containers via internal code paths
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
