# Changelog

All notable changes to XP Bar Enhanced will be documented in this file.

## [1.3.0] - 2026-09-19

### Added

- **More clients**: one manifest now loads on Classic Era, the Forever beta, Burning Crusade, Wrath, Cataclysm and Mists Classic as well as Retail, replacing the separate Classic manifest. The client's build decides which features run, so a client never starts a feature it cannot serve.
- **Classic bar width**: a slider (200-1400px) sets the Classic bar's width. The border's end caps keep a fixed size while the middle stretches, so the frame stays crisp instead of smearing.
- **Classic segment count**: a slider (0-40) divides the Classic bar into evenly spaced segments, following Blizzard's new experience bar. 0 or 1 gives one unbroken bar, 10 matches the previous art, 20 matches Blizzard's wide bar.

### Changed

- **Classic bar art**: redrawn after Blizzard's newer experience bar, with a chamfered frame, a two-tone fill in your chosen color, and new dividers and rested marker. The Classic reputation bar uses the same frame, so the two bars stay identical when stacked. All of it ships with the addon, so a Blizzard art change can no longer alter or blank the bar.
- The bar style gallery draws premade previews instead of assembling each style from dozens of textures when the options open.
- Rested XP that overflows the current level now fills the bar to its edge instead of hiding the rested overlay entirely, matching Blizzard's newer experience bar.
- The rested marker now hides within 1% of either end of the bar, where it used to sit half off the frame.
- **Reset Settings** now asks first and resets only the active profile's settings, colors and bar positions. It used to wipe every profile, every character's profile choice and all tracked statistics in one click. `/xpbe reset` does the same without the prompt.
- Played time is requested once per login instead of on every loading screen.

### Fixed

- Logging in on the Forever beta no longer drops the connection: housing, which that realm cannot serve, stays off there.
- Characters on the Forever beta keep their profile and statistics between sessions.
- Watching a paragon faction on Retail no longer stops the bars from loading.
- A module that fails to start at login is reported without stopping the others, so the bars still appear.
- Quest XP on the Classic clients counted no quest shown on the current map and dropped quests under a collapsed header.
- The two "Time played" lines no longer print in chat when the addon asks for played time.
- A secondary bar source the client does not offer is moved to one it does in every profile, not only in Global Settings.
- Blizzard's own XP or reputation bar no longer reappears beside the addon's after Edit Mode, at the level cap, or on Retail while a house is tracked.
- Turning off "Classic Bar Draggable" now survives a reload, and a fixed Classic bar keeps its configured width and sits where Blizzard's bar does.
- Reset Bar Position leaves the Minimap Ring and a fixed Classic bar on their anchors instead of moving them to the middle of the screen.
- Profiles keep their own secondary bar positions: resetting one on a profile no longer resets Global Settings' positions for other characters.
- XP per hour is one figure everywhere: the bar, its tooltip and the Stats window no longer show different rates, and the bar text no longer flips between two values every few seconds.
- The time-on-level readout keeps running after a level-up instead of vanishing until the next loading screen, and XP per hour no longer drops by about half after a ding.
- XP per hour waits a minute of data before showing, so a quest turned in right after login no longer reads as millions per hour.
- The Stats window's time on level and time to level now advance while you play.
- The rested percentage in the quest summary shows up to 150% instead of stopping at 100%.
- Reputation gained per session no longer jumps by the whole standing when faction data is briefly unavailable, and a renown level-up no longer counts a phantom extra level.
- Paragon reputation past the renown cap is tracked as paragon, and paragon gains are counted exactly across reward cycles.
- The Classic and Terminal reputation bars show standing colors for regular factions, and the housing bar no longer takes standing colors from its house level.
- Housing favor earned on another character, or while logged out, is no longer counted in this session.
- On Retail, the housing bar and its favor tracking start once the housing service comes up, even when it was not ready at login.
- With "primary shows secondary source" at max level, the Circular and Minimap Ring fills take the source's color, and Circular, Vertical and Terminal show the source's standing or level instead of "0".
- A second XP gain during the two-step level-up animation no longer drains the bar back down and leaves it short of your real XP.
- Quest and rested overlays update when a quest is turned in during a gain animation instead of staying stale until the next XP gain.
- The Minimap Ring picks up color and profile changes immediately, and its hover area no longer blocks the minimap's zoom and tracking buttons.
- The Circular bar's tooltip and right-click follow the attached secondary source (honor, housing, profession) instead of always showing reputation.
- Terminal: its session and level timers keep running while idle, it respects the Quest XP master toggle, its tooltip labels rested XP "rested" rather than a leftover legend line, and long faction names in Cyrillic or East Asian scripts are shortened cleanly.
- The Vertical bar's percentage follows Blizzard's status-text setting like its other texts.
- Classic on-bar texts are cut short on a narrow bar instead of wrapping out of it.
- Secondary bar hints and the rested marker's tooltip are localized, and name the right panel for each source.
- Readout presets change only what the bar shows. They used to reset unrelated settings too, so picking one could unlock the bar, re-show the minimap button or hide the secondary bar.
- Options that other paths change (presets, profile switches, resets) now update the bars at once, like the matching checkbox or slider does.
- Option dropdowns show the right value after a profile switch, reset or rename.
- The opacity slider no longer runs backwards in the Classic clients' color picker, opening or cancelling a color no longer pins an inherited color onto a profile, and a second color opened from the picker starts at its own opacity.
- `/xpbe resetcolors` on a profile resets to the default colors, not Global Settings' colors.
- Option descriptions show as tooltips, including the readout preset buttons.
- The Stats window closes with Esc, and Enter and Esc work in the new- and rename-profile dialogs.
- "Use textured segments" is available under the Minimap Ring style, which also uses it; the Advanced section opens by default for a Custom readout; the Colors tab no longer shows an empty "Other secondary sources" header on the Classic clients.
- The addon no longer prints "Loaded!" in chat at every login.
- Without a LibDataBroker display installed, the feed no longer checks for one every five seconds all session; it waits for an addon to load.
- A party member's quest log changing no longer rebuilds your quest XP totals, and a quest turn-in scans the quest log once instead of twice.

### Removed

- `/xpbe enable`, `/xpbe disable` and `/xpbe status`. The disable command never stopped the addon and did not survive a reload; disable the addon from the AddOns list instead.
- The Classic bar's fill no longer spills past the rounded ends of its frame.
- The Classic bar's fill and the Classic reputation bar no longer use Blizzard's pre-colored fill textures, which tinted custom colors or went blank on clients that lack them.

## [1.2.6] - 2026-09-11

### Fixed

- Improved recovery from malformed saved settings and profile data instead of failing during initialization.
- Coalesced quest-cache rebuilds during bursts of quest events to reduce redundant work.
- LibDataBroker registration now retries when a display addon loads after the player login event.
- Reduced EventBus dispatch allocations on frequent update events.
- Made option checkbox rows easier to use by allowing the label area to be clicked.
- Added width limits to Classic, Terminal and Stats text fields to reduce overlap at large values.
- Moved shared secondary-bar tooltip labels into the localization system.
- Repaired corrupted profile assignments during startup and made Terminal respect active profile settings.
- Improved small-screen options layout and ScrollBox content handling.

## [1.2.5] - 2026-09-10

### Added

- Added support for World of Warcraft Classic Era 1.15.9 alongside Retail.
- Added a dedicated Classic manifest while retaining the Retail manifest.

### Changed

- Retail-only features such as Housing, Delves, modern renown, and modern reputation sources are hidden or disabled on Classic.
- Classic and Retail now use Blizzard's quest turn-in icon for the addon list, minimap button, and notifications.

## [1.2.0] - 2026-08-16

### Added

- **Readout presets**: Minimal, Standard and Leveller configure text and overlay settings in one click, with a Custom mode for manual changes.
- **Style gallery**: choose among all bar styles from labelled visual previews. `/xpbe style <name>` remains available.

### Changed

- Updated for Patch 12.1 (`Interface: 120100`).
- Moved individual text controls under an Advanced section and kept unavailable options visible but disabled with an explanation.
- Level-up celebrations now work across all bar styles, including Circular, Minimap Ring and Terminal.
- Improved the Colors tab, Stats window, minimap tooltip and LibDataBroker feed for clearer, more consistent readouts.
- Circular and Vertical styles now keep time-to-level current while the player is idle.
- Improved Circular bar rendering performance without changing its appearance.

### Fixed

- XP session totals are no longer duplicated, lost at level boundaries, or credited twice.
- XP/hour and time-to-level estimates no longer spike during the first seconds of a session.
- Circular border and center artwork now render correctly.
- Invalid saved bar styles now fall back to the default instead of preventing the addon from loading.
- Rested XP colors, style gallery sizing and `/xpbe style` validation now remain consistent.
- Development-only files are excluded from published packages.

## [1.1.8] - 2026-07-16

### Changed

- **Level progress notifications** now appear as a compact bordered toast with the addon icon, auto-sized to its text, instead of plain text at the top of the screen.

### Fixed

- The Orb style was missing from the `/xpbe help` style list, the invalid-style error message, and the README command reference.
- Documentation: the README's secondary-bar configuration section now lists all four sources (Reputation, Housing Favor, Honor, Profession).

## [1.1.7] - 2026-07-14

### Added

- **Level-up celebration** with a golden glow pulse.
- **Session charts** showing XP/hour and quest-versus-other XP.
- **Honor and Profession** as secondary-bar sources, including profession selection.
- **Max-level secondary display** to show the selected source on the main bar.
- **Level progress notifications** at 25%, 50% and 75% with an estimated time to level.
- **LibDataBroker feed** for XP/hour and time-to-level displays such as Titan Panel, Bazooka and ElvUI.
- **Orb bar style** with a companion orb, custom colors, animations, rested XP and quest overlays.

### Fixed

- Session XP, reputation and housing gains are now tracked correctly across level and standing thresholds.
- Profile overrides consistently apply to sessions, colors, overlays and text settings.
- Session data is stored per character, and XP/hour, tooltips and stats remain accurate after reloads or UI-scale changes.
- Fixed minimap ring zoom errors, combat visibility issues, stale XP flashes, options scrolling and several stability problems.

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

- **Profile-Aware Settings Access**: Added centralized profile-aware option lookups via `Utils.GetOptionValue` and migrated key callers to the shared helper.
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

## [1.0.4] - 2026-03-01

### Added

- **Circular Bar Size Presets**: New size selector for the circular progress ring with four preset options:
    - Small (0.75× scale)
    - Medium (default, 1.0× scale)
    - Large (1.5× scale)
    - Huge (2.0× scale)
- Selective scaling: Ring segments, border, and glow effects scale with the preset size; center background image remains fixed at its original size for optimal visual presentation

## [1.0.3] - 2026-02-28

### Fixed

- **Time-to-Level Estimates**: Improved accuracy of XP/hour and time-to-level calculations by automatically detecting when level time includes significant idle time. When session-based rate is 2.5x or higher than level-based rate, the addon now uses session time for estimates, eliminating inflated times for new expansion levels



## [1.0.1] - 2026-01-11

### Fixed

- **Max Level Bar Visibility**: Fixed issue where the XP bar wasn't hidden when reaching max level (80). Now correctly detects level-up and switches to Blizzard bar at max level
- **Classic Bar Draggability**: Fixed classic bar not being draggable even when `classicBarDraggable` setting was enabled. Added missing mouse event handler registration in frame initialization
- **Position Mode Detection**: Improved level-up event handling to use the actual level parameter from `PLAYER_LEVEL_UP` event instead of calculating it

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

