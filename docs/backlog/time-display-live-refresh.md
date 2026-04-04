# Backlog: Secondary Bar Time Text Refresh

Priority: P2
Effort: Small
Risk: Low
Source: docs/analysis/xp-tracking-improvements-plan.md

## Summary

Add a lightweight periodic timer to secondary bars that refreshes time-dependent text (rep/hour, time-to-next-standing, XP/hour, time-to-next-level) without requiring a full data refresh event.

Dependency: implement after shared bar lifecycle contract extraction so ticker lifecycle is standardized.

## Motivation

The primary XP bar already has a 2.5s text ticker (in BaseMixin) that keeps session time and rate displays current between XP events. Secondary bars only update text when an event fires, so their rate/time displays can appear stale during long gaps between reputation or companion XP gains.

## Scope

### In Scope

- Add a `C_Timer.NewTicker` to secondary bar `OnShow`, cancelled on `OnHide`.
- Timer re-reads time-dependent fields from the session service and updates label text.
- Does NOT trigger a full Render cycle or event emission.

### Out of Scope

- Full MarkDirty coalescing for secondary bars (separate architecture item).

## Tasks

1. In `FlatReputationBarStyle.lua` `OnShow`, start a 3–5s ticker that calls a lightweight text-only updater.
2. The updater reads `ReputationSession:GetRepPerHour()` and `GetTimeToNextStanding()` and re-formats the label.
3. Same pattern in `FlatCompanionBarStyle.lua` for companion rate/time.
4. Cancel ticker in `OnHide`.
5. Verify ticker does not fire after bar is hidden or destroyed.

## Affected Files

- ui/secondary/FlatReputationBarStyle.lua
- ui/secondary/FlatCompanionBarStyle.lua

## Acceptance Criteria

- [ ] Rep/hour and time-to-next-standing text updates every few seconds while the reputation bar is visible.
- [ ] Companion XP/hour and time-to-next-level updates similarly.
- [ ] Ticker is cancelled on hide; no orphaned timers.
- [ ] No full re-render or event emission from the ticker path.
