# Implementation History

Consolidated record of completed implementation phases. Detailed decisions are in `docs/memory/decision-log.md`.

## Phase 5 — Foundations (2026-04-05)

### Shared Bar Contract

- Created `SecondaryBarBaseMixin` for shared lifecycle: OnLoad → OnShow → OnHide → MarkDirty → Render
- Secondary style mixins reduced to domain hooks only (GetBroadcastEventName, GetInitialContext, Render)
- EventBus updates run through MarkDirty coalescing

### Event Router Consolidation (3 stages)

- Stage 1: Moved reputation/companion event registration to `core/EventRouter.lua`
- Stage 2: Migrated QuestXP and Session events to router
- Stage 3: Moved lifecycle fan-out and startup/shutdown events to router
- Result: Single-frame external event ownership; AddOnLifecycle is handler-only

### Session Persistence

- Added `sessionAccumTime` persistence across `/reload` via SavedVariables
- New `resetOnReload` option (default: off) for user-controlled session reset behavior

## Phase 6 — Secondary Bar Polish (2026-04-05 to 2026-04-06)

### Delivered Features

1. **Fade transitions** — State-change-based fade-in/out (not idle timers); matches Blizzard behavior
2. **Drag-to-move** — Shift+drag with SavedVariables position persistence, lock support, reset-anchor
3. **Hover tooltips** — Session metrics (gained, rates, time-to-next) via GameTooltip
4. **Live text refresh** — 1.0s ticker interval using shared base mixin hooks

### Key Decisions

- Fade triggers only on availability state changes (track/untrack), not idle delays
- Tooltip uses TextFormatter for consistent formatting with primary bar
- All polish wired through SecondaryBarBaseMixin hooks, no lifecycle duplication

## Phase 7 — Hardening and Contract Work (2026-04-06 to 2026-04-07)

### Slice 1: Compliance Hardening (P1)

Scope: Critical/high UI compliance fixes before feature expansion.

1. Drag semantics — Removed conflicting SetUserPlaced calls; persistence via SavePosition
2. Combat safety — Deferred drag setup to PLAYER_REGEN_ENABLED when in combat
3. Tooltip guards — GameTooltip existence checks and safe leave handlers
4. Fade lifecycle — Single reusable animation object; stop-before-retarget pattern
5. Ticker optimization — Prefer cached last context over rebuild fallback

### Slice 2: Context Contract Normalization (P1)

Scope: Standardize secondary context sourcing to reduce redundant rebuilds.

1. Added `GetLatestContext()` to SecondaryBarBaseMixin
2. Refresh and ticker paths prefer emitted/cached context
3. Bootstrap fallback (GetInitialContext) used only when cache is missing

### Slice 3: Max-Level Behavior (P2)

Scope: Preserve historical max-level contract.

1. Primary XP bar unconditionally hidden at level cap
2. Secondary reputation/companion bars remain style-driven and independently visible
3. Explored configurable modes (always_show, show_reputation, etc.) but reverted to unconditional hide per historical contract

## Phase 7 Follow-up — XP Tracking Quick Wins (2026-04-08)

1. Excluded `isTask` quests from quest XP overlays so world quests and bonus objectives no longer inflate pending XP
2. Added `UPDATE_EXPANSION_LEVEL` and `MAX_EXPANSION_LEVEL_UPDATED` to the event router so max-level visibility re-evaluates immediately
3. Lowered XP/hour warm-up thresholds from 30 seconds to 10 seconds for faster initial rate display

## Pre-Phase-7 Analysis Artifacts

- Architecture consistency analysis: `docs/analysis/pre-phase-7-architecture-compliance-deliverable.md`
- Planning gate and approval tracking: archived from `docs/features/` (decisions in decision-log)
