# Feature: Reputation Bar

A secondary progress bar that displays the player's watched faction reputation progression.

## Capabilities

- **Watched faction tracking**: Displays current standing and progress for the tracked faction
- **All reputation types**: Handles standard, friendship, major/renown, and paragon factions
- **Automatic updates**: Reacts to faction gain, standing changes, and tracked faction switches
- **Independent visibility**: Enabled via `showSecondaryBar` checkbox in settings; hidden when disabled or when primary XP bar style is "none"
- **Companion visibility rule toggle**: Optional setting `hideCompanionOutsideDelve` hides the secondary bar when the watched faction is a Delve companion and the player is outside a Delve
- **Drag-to-move**: Repositionable with Shift+drag; position persists across sessions
- **Fade transitions**: Smooth fade-in/out on availability changes
- **Hover tooltip**: Shows session metrics on mouseover
- **Live text refresh**: Periodic text updates without full context rebuild

## Architecture

- **Primary data pipeline**: `ReputationSession._BuildContext()` → `EventBus.Emit(REPUTATION_BROADCAST_UPDATE, ctx)` → `SecondaryBarBaseMixin.MarkDirty(ctx)` → `FlatSecondaryBarStyle.Render(ctx)`
- **Bootstrap path** (first-show): `FlatSecondaryBarStyle.GetInitialContext()` pulls from `ReputationSession:GetCurrentContext()`
- **Session layer**: `ReputationSession` owns all faction state, session gains, and context construction
- **Visibility ownership**: `SecondaryBarManager` controls both custom and Blizzard reputation bar visibility
- **Render model**: Bar renders from emitted context payloads via `MarkDirty` coalescing; no listener-side context rebuilding during normal updates

## Key Components

- `core/services/ReputationSession.lua` — Faction state, session tracking
- `ui/styles/flat/FlatSecondaryBarStyle.lua` — Visual rendering
- `ui/SecondaryBarManager.lua` — Style activation and visibility

## Known Limitations

- Only one visual style currently available (flat), derived automatically from the primary bar being active
- Delve companion display is layered on top of the watched-faction path and still relies on a known-companion list
