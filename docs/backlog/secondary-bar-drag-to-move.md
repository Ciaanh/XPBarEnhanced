# Backlog: Secondary Bar Drag-to-Move

Priority: P2
Effort: Small
Risk: Low
Source: docs/secondary-bars-next-phase.md

## Summary

Allow users to drag-reposition reputation and companion bars independently, with position saved to SavedVariables and restored on login/reload.

Dependency: implement after shared bar lifecycle/position contract extraction to avoid duplicated drag handlers.

## Motivation

Secondary bars currently default to fixed positions (BOTTOM y=34 / y=54). Users cannot freely position them. The primary XP bar already supports drag-to-move via PositionMixin and Edit Mode.

## Scope

### In Scope

- Make secondary bars draggable when unlocked (bar unlocked via options or Edit Mode).
- Save position to `reputationBarPosition` / `companionBarPosition` in SavedVariables.
- Restore position on login/reload.
- Reset-anchor button in options panel resets secondary bars to defaults.
- Clamp to screen to prevent off-screen placement.

### Out of Scope

- Snap-to-grid or alignment guides.
- Resizing via drag (separate backlog item: bar-size-scale-options).

## Tasks

1. Add `RegisterForDrag("LeftButton")`, `SetMovable(true)`, `SetClampedToScreen(true)` to secondary bar templates.
2. Add `OnDragStart` / `OnDragStop` scripts that call `StartMoving()` / `StopMovingOrSizing()` and save the resulting anchor point to config.
3. Gate dragging behind `not Addon.db.barLocked` (or Edit Mode detection).
4. On `OnLoad`, restore saved position from `Addon.db.reputationBarPosition` / `Addon.db.companionBarPosition`.
5. Wire `SecondaryBarManager:ResetBarPositions()` to clear saved positions and re-anchor to defaults.
6. Verify Edit Mode integration: secondary bars should become draggable when Edit Mode is active.

## Affected Files

- ui/secondary/FlatReputationBarStyle.lua
- ui/secondary/FlatReputationBarTemplate.xml
- ui/secondary/FlatCompanionBarStyle.lua
- ui/secondary/FlatCompanionBarTemplate.xml
- ui/SecondaryBarManager.lua (ResetBarPositions)

## Acceptance Criteria

- [ ] Unlocked secondary bars can be dragged to any screen position.
- [ ] Position persists across /reload and re-login.
- [ ] Reset-anchor restores both bars to default positions.
- [ ] Bars are clamped to screen edges.
- [ ] Locked bars cannot be dragged.
- [ ] Edit Mode makes secondary bars draggable.
