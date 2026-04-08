# Feature: Options and Configuration

User-facing settings, slash commands, and minimap button.

## Layout Architecture Decision (MQ-2, 2026-04-08)

**Current state**: 36 options in a single flat list (`optionOrder` in `OptionMetadata.lua`). Style-specific groups (circular: 4, minimap_ring: 5, terminal: 1) are mixed in at the end with no visual grouping. The panel is registered as a `Settings.RegisterCanvasLayoutCategory` (full custom XML canvas). Layout is driven by `OptionMetadata.lua` + `ControlHelpers.lua` building widgets into a scroll frame.

**Chosen direction: Grouped scroll with conditional style-section visibility**

Rationale:
- 36 options across 8 sections (average 4–5 per section) is manageable on a single scrollable page
- Blizzard's Settings framework supports custom section headers in canvas-layout panels
- Style-specific sections (Circular, Minimap Ring, Terminal) must already listen for `barStyle` changes to toggle their option states — adding `SetShown()` calls for the whole section header+options block is a natural extension
- Tabbed panels would require a custom tab-widget system inside the canvas — significant XML/Lua complexity with no material UX advantage at this option count

**Proposed section grouping**:

| Section | Options |
|---------|---------|
| Core | barStyle, barLocked, classicBarDraggable |
| Secondary Bar | showSecondaryBar, hideCompanionOutsideDelve, secondaryBarsAttached |
| Minimap | showMinimapButton |
| XP Overlays | showRestedOverlay, showQuestXP, showCompleteQuestOverlay, showIncompleteQuestOverlay, showMilestoneTicks |
| XP Text | showLevelText, showXPText, showRemainingXP, showXPPerHourText, showTimeToLevelText, showLevelTimeText, showSessionTimeText, showPercentage, showQuestPercent, abbreviateNumbers, resetOnReload |
| Animations | enableAnimations, flashOnGain, twoPhaseOnLevelUp |
| Style: Circular *(visible only when barStyle = circular)* | circularSize, circularSegments, circularUseTexture, circularScaleCenterText |
| Style: Minimap Ring *(visible only when barStyle = minimap_ring)* | minimapRingPadding, minimapRingSegments, minimapRingCollectButtons, minimapRingSegmentWidth, minimapRingSegmentHeight |
| Style: Terminal *(visible only when barStyle = terminal)* | terminalUseCustomColors |

**Implementation approach**:
- Extend `optionOrder` structure (or replace with `optionSections` table keyed by group) to carry a `section` label per option
- Add a `SectionDivider` widget type to `OptionsPanelTemplates.xml`
- `ControlHelpers.lua` emits a section header row before the first option in each new section
- The style-specific sections' header + all contained option widgets are collected into a group; the group receives `SetShown(barStyle == expectedStyle)` calls from a `BAR_STYLE_CHANGED` listener in `Options.lua`
- Backlog item: see `docs/backlog/options-panel-sections.md`

## Settings Panel

Access via `/xpbe options` or minimap button right-click.

### Bar Style

- Style selector dropdown (None, Classic, Flat, Vertical, Circular, Minimap Ring, Terminal)
- Unified secondary bar uses a dedicated visibility toggle instead of per-bar style dropdowns

### Display Options

- Text row visibility toggles (top/bottom text)
- Quest XP overlay toggle
- Animation toggle
- Minimap button visibility
- Reset-on-reload toggle (session continuity vs fresh start on `/reload`)

### Color Customization

- XP bar color
- Rested XP color
- Quest XP overlay color
- Per-style color overrides (Terminal phosphor mode)

### Style-Specific Options

- Circular: ring size (Small/Medium/Large/Huge), segment count, texture style, center text scaling
- Minimap Ring: ring padding, segment count, segment dimensions, button collection
- Terminal: authentic colors vs custom scheme

### Secondary Bar Options

- Show/hide the unified secondary tracked-reputation bar
- Optional hide rule for Delve companions outside Delves
- Attach/detach secondary bar positioning relative to the primary XP bar

## Slash Commands

| Command | Action |
| ------- | ------ |
| `/xpbe` | Show help |
| `/xpbe options` | Open settings |
| `/xpbe stats` | Toggle statistics window |
| `/xpbe style <name>` | Set bar style |
| `/xpbe reps` | Export all faction IDs |
| `/xpbe reset` | Reset all settings |
| `/xpbe resetstats` | Reset session statistics |
| `/xpbe resetcolors` | Reset colors to defaults |

Aliases: `/xpbarenhanced`, `/xpbar`

## Minimap Button

- Left-click: toggle statistics window
- Right-click: open options panel
- Draggable around minimap border

## Architecture

- `core/config/defaults.lua` — Default values for all settings
- `core/config/Config.lua` — Config read/write, migration, side effects
- `core/config/ConfigHelper.lua` — Config access helpers
- `ui/options/Options.lua` — Option change handlers and side-effect dispatch
- `ui/options/OptionsPanel.xml` — Settings panel layout
- `ui/options/OptionMetadata.lua` — Option definitions (type, range, values)
- `ui/MinimapButton.lua` — Minimap button logic
- `core/AddOnCommands.lua` — Slash command registration and dispatch
