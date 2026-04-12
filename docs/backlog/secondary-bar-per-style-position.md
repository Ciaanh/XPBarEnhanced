# Backlog: Per-style Secondary Bar Position

Priority: P2 · Effort: Small · Status: **IMPLEMENTED — 2026-04-12**

Implemented in session 2026-04-12. See `docs/memory/decision-log.md` for implementation notes.

## Summary

Replaced `db.secondaryBarPosition` (single key) with `db.secondaryBarPositions` (table keyed by primary bar style).
Each primary style now saves its secondary bar position independently, mirroring how `barPositions` works for the primary bar.
One-time migration handles existing SavedVariables.

## Goal

Give each primary XP bar style its own independent saved position for the secondary bar, mirroring how `barPositions` works for the primary bar.

## Background

Currently all secondary bar styles share a single `secondaryBarPosition` saved-variables key. When the user switches primary bar styles the secondary bar jumps to wherever it was last left regardless of which primary style is active. Users who use multiple primary styles are likely to want different secondary bar positions for each.

## Proposed Approach

- Replace `db.secondaryBarPosition` (single table) with `db.secondaryBarPositions` (table keyed by style name — e.g. `{ flat = {...}, classic = {...} }`).
- `SavePosition` / `GetSavedPosition` in `PositionMixin` (or `SecondaryBarBaseMixin`) resolve the per-style key using the active primary bar style.
- `GetFallbackPosition()` continues to derive from `Addon.defaults.barPositions[barStyle]` + y-offset.
- Reset clears the per-style entry rather than the entire shared key.
- **Migration**: on first load after upgrade, copy the existing `secondaryBarPosition` into the slot for the currently active style.

## Acceptance Criteria

- Dragging the secondary bar in Style A does not affect its position in Style B.
- Resetting position in Style A resets only Style A's saved position.
- SavedVariables upgrade from single key to per-style table is handled gracefully (no nil errors on first login after upgrade).
- No secondary-bar position regressions in the existing free-drag or attached-mode paths.

## Notes

- Deferred until at least one user request surfaces this as a pain point — the benefit is real but the current single-position behavior is not clearly broken.
- Do not begin implementation without explicit approval recorded in `docs/memory/decision-log.md`.
