# Backlog: XP Tracking Quick Wins

Status: Ready for implementation
Priority: P2
Effort: Trivial (3 one-to-two line changes)
Risk: Low
Source: `docs/analysis/xp-tracking-improvements-plan.md` items 3, 4, 5

## Summary

Three small, independent improvements to XP tracking identified during the reference-addon
comparison analysis. Items 1 (session persistence) and 2 (time refresh timer) from the same
plan have already been implemented.

---

## Item A: Quest XP `isTask` Filtering

**Problem**: `QuestXP.lua` filters `isHeader` and `isHidden` but not `isTask`. World quests,
bonus objectives, and threat quests have `isTask = true` and report XP via
`C_QuestLog.GetInfo()`. Including them inflates the overlay and misleads the player about
expected turn-in XP.

**Fix**: Add `not info.isTask` to the existing guard in `QuestXP.lua`.

**File**: `core/services/QuestXP.lua` line ~65
**Before**: `if info and not info.isHeader and not info.isHidden and info.questID then`
**After**: `if info and not info.isHeader and not info.isHidden and not info.isTask and info.questID then`

**Acceptance**: World quests and bonus objectives absent from XP overlay. Normal and
campaign quests unaffected.

---

## Item B: Expansion Level Change Events

**Problem**: `EventRouter.lua` handles `PLAYER_MAX_LEVEL_UPDATE` but not
`UPDATE_EXPANSION_LEVEL` or `MAX_EXPANSION_LEVEL_UPDATED`. During pre-patches or mid-session
expansion purchases the bar may not re-evaluate visibility until the next login.

**Fix**: Add both events to `ROUTER_DISPATCH` in `EventRouter.lua`, routing to
`DispatchPlayerMaxLevelUpdate()`.

**File**: `core/EventRouter.lua`

```lua
UPDATE_EXPANSION_LEVEL = function()
    DispatchPlayerMaxLevelUpdate()
end,
MAX_EXPANSION_LEVEL_UPDATED = function()
    DispatchPlayerMaxLevelUpdate()
end,
```

**Acceptance**: On expansion-level change event, bar visibility re-evaluates correctly
(same behaviour as `PLAYER_MAX_LEVEL_UPDATE`).

---

## Item C: XP/Hour Minimum Threshold Reduction

**Problem**: `TimeCalculations.CalculateXPPerHour` requires 30 seconds of elapsed time
before producing a rate. Players see `0 XP/hr` for the first 30 seconds of a session.
10 seconds balances responsiveness with stability (the existing dual-rate heuristic still
prevents wild fluctuations).

**Fix**: Lower the threshold constant from `30` to `10` in `TimeCalculations.lua`.

**File**: `core/calculations/TimeCalculations.lua` line ~26
**Before**: `if elapsed < 30 then`
**After**: `if elapsed < 10 then`

**Note**: The second `elapsed < 30` on line ~259 guards the level-time rate and should
also be reduced to `10` for consistency.

**Acceptance**: XP/hr rate appears within 10 seconds of first XP gain. Rate is stable (not
erratic) after the threshold.

---

## Implementation Order

| Order | Item | File | Lines changed |
|-------|------|------|---------------|
| 1 | A — isTask filter | `core/services/QuestXP.lua` | 1 |
| 2 | B — Expansion events | `core/EventRouter.lua` | ~6 |
| 3 | C — XP/hr threshold | `core/calculations/TimeCalculations.lua` | 2 |

All three are independent and can be applied in one commit.

## Definition of Done

- All three changes applied and validated in-game.
- World quests absent from XP overlay.
- XP/hr rate appears within 10 seconds of session start.
- No regression on normal quest overlay, rate display, or bar visibility on max-level change.
