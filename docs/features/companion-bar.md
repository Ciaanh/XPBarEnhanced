# Feature: Companion Bar

> **NR-3 (2026-04-07)**: The companion bar is no longer a separate bar. Companion tracking is a decoration mode on the unified secondary bar. This file documents the post-NR-3 behavior.

The secondary bar applies companion-specific display when the player's watched faction is a Delve companion (Brann). There is no separate companion bar frame, session service, or event bus event — companion rendering is a conditional branch within the reputation secondary bar system.

## Capabilities

- **Companion detection**: Companion mode activates when the watched faction's `factionID` matches a known Delve companion in `defaults.delveCompanions` (dict mapping ID → name), with legacy name-based fallback for compatibility; exposed via `isCompanion` in context emitted by `ReputationSession`
- **Companion label format**: Shows `"Name Lv.X (XX%)"` instead of the standard `"Name - Standing (XX%)"` format
- **Companion color**: Bar uses a distinct teal color (`{r=0.20, g=0.80, b=0.80}`) instead of the faction-type color
- **Companion tooltip**: Shows companion level and "Gained: +N" session gains; omits the standing-label line
- **Outside-Delve hiding**: Optional `hideCompanionOutsideDelve` setting hides the secondary bar when the watched faction is a companion and the player is outside a Delve; bar reappears on Delve entry
- **Fade transitions**: Standard secondary bar fade-in/out applies
- **Drag-to-move**: Standard secondary bar drag behavior applies (Shift+drag)
- **Session tracking**: `ReputationSession` tracks `sessionGained` for companion factions the same way as reputation factions

## Architecture

Companion is not a separate subsystem. All behavior is driven by `isCompanion = true` in the context emitted by `ReputationSession._BuildContext()`:

- **Data pipeline**: `ReputationSession._BuildContext()` → `EventBus` → `FlatSecondaryBarStyle.Render(ctx)`
- **Companion detection**: `ReputationSession:GetWatchedFactionInfo()` resolves `isCompanion` using `IsKnownDelveCompanion(factionID, name)`
- **Render branching**: `FlatSecondaryBarStyle` branches on `context.isCompanion` for label, color, and tooltip
- **Visibility rule**: `SecondaryBarManager` handles `hideCompanionOutsideDelve` by reacting to `ZONE_CHANGED_NEW_AREA` and C_Garrison Delve detection

## Key Components

- `core/services/ReputationSession.lua` — Detects companion faction, sets `isCompanion` and `currentLevel` in context
- `core/config/defaults.lua` — `delveCompanions` dict (factionID → name)
- `ui/styles/flat/FlatSecondaryBarStyle.lua` — Renders companion flavor when `context.isCompanion = true`
- `ui/SecondaryBarManager.lua` — `hideCompanionOutsideDelve` visibility logic

## Known Limitations

- Multiple companions are supported via configured companion faction IDs; UX for explicit companion selection is deferred (see `docs/backlog/companion-multi-companion.md`)
- Companion level display relies on the companion faction's renown/friendship level; no separate XP resource is tracked

