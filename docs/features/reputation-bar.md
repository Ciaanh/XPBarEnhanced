# Feature: Reputation Bar

A secondary progress bar that displays the player's watched faction reputation progression.

## Capabilities

- **Watched faction tracking**: Displays current standing and progress for the tracked faction
- **All reputation types**: Handles standard, friendship, major/renown, and paragon factions
- **Automatic updates**: Reacts to faction gain, standing changes, and tracked faction switches
- **Independent visibility**: Controlled by `reputationBarStyle` setting, separate from primary XP bar
- **Drag-to-move**: Repositionable with Shift+drag; position persists across sessions
- **Fade transitions**: Smooth fade-in/out on availability changes
- **Hover tooltip**: Shows session metrics on mouseover
- **Live text refresh**: Periodic text updates without full context rebuild

## Architecture

- **Data pipeline**: `ReputationSession` → `ContextBuilder` (BuildReputationContext) → `EventBus` → bar style
- **Session layer**: `ReputationSession` snapshots watched faction data and tracks session gains
- **Visibility ownership**: `SecondaryBarManager` controls both custom and Blizzard reputation bar visibility
- **Render model**: Bar renders from emitted context payloads; no listener-side rebuilding

## Key Components

- `core/services/ReputationSession.lua` — Faction state, session tracking
- `core/services/ContextBuilder.lua` (BuildReputationContext) — Immutable context builder
- `ui/secondary/FlatReputationBarStyle.lua` — Visual rendering
- `ui/SecondaryBarManager.lua` — Style activation and visibility

## Known Limitations

- Only one visual style currently available (flat)
- Fade polish is optional future work
