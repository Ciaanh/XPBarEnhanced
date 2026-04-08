# Feature: XP Bar

The primary addon feature — an enhanced experience bar that replaces and extends the default Blizzard XP tracking.

## Capabilities

- **Multiple visual styles**: None (Blizzard default), Classic, Flat, Vertical, Circular, Minimap Ring, Terminal
- **Quest XP overlay**: Shows pending and completed quest XP directly on the bar
- **Session tracking**: Tracks XP gained, time played, levels gained, XP/hour rate
- **Rested XP display**: Visualizes rested XP bonus on the bar
- **Smooth animations**: Fill transitions, flash-on-gain, two-phase level-up animations
- **Max-level behavior**: Primary XP bar automatically hides at level cap; secondary bars continue independently
- **Session persistence**: Session time/XP survives `/reload` (configurable via `resetOnReload` option)

## Bar Styles

| Style | Description |
| ----- | ----------- |
| None | Blizzard's default XP bar only |
| Classic | Blizzard-style bar with atlas textures and quest overlays |
| Flat | Full-width draggable bar with milestone ticks |
| Vertical | Vertical bar with falling XP animation |
| Circular | Progress ring with configurable size, segments, center text |
| Minimap Ring | XP ring anchored around the minimap with button collection |
| Terminal | ASCII-style retro bar with phosphor-green display |

## Architecture

- **Data pipeline**: `Session` → `ContextBuilder` → `EventBus` → bar mixins
- **Event routing**: Centralized via `EventRouter`; `EventBus` is dispatcher-only
- **Render model**: Context-first — emitters own context creation, bars render from immutable payloads
- **Style management**: `BarManager` owns style switching, frame lifecycle, and max-level visibility policy

## Key Components

- `core/services/Session.lua` — XP state, session timing, level-up tracking
- `core/services/ContextBuilder.lua` — Builds immutable render contexts
- `core/EventBus.lua` — Internal pub/sub dispatcher
- `core/EventRouter.lua` — Centralized WoW event registration
- `ui/BarManager.lua` — Style activation, frame lifecycle, Blizzard bar visibility
- `ui/mixins/BaseMixin.lua` — Shared bar lifecycle (OnLoad → OnShow → Render)

## Notes

- **Quest XP overlay filtering**: `isTask` quests (world quests, bonus objectives) are excluded from the overlay — they cannot be turned in normally and would inflate the pending-XP display
- **XP/hr rate warm-up**: Rate is held at zero for the first 10 seconds of a new session; the display shows `--` until enough data is available
- **Expansion level handling**: `UPDATE_EXPANSION_LEVEL` and `MAX_EXPANSION_LEVEL_UPDATED` route through `EventRouter` alongside `PLAYER_MAX_LEVEL_UPDATE`; all three call `DispatchPlayerMaxLevelUpdate()` to keep the max-level cap current
