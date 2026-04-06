# Feature: Phase 7 Slice 1 - Secondary Bar Compliance Hardening

Status: Ready for implementation approval
Last updated: 2026-04-06
Priority: P1 (pre-feature-expansion hardening)

## Objective

Apply the highest-priority UI compliance and interaction safety fixes to secondary bars before any new Phase 7 feature work.

This slice is derived from:

- `docs/analysis/pre-phase-7-architecture-compliance-deliverable.md`

## Scope

### In Scope

1. Drag/user-placement semantics hardening.
2. Combat-safe movement gating for draggable behavior setup.
3. Tooltip safety guards for secondary bars.
4. Fade animation lifecycle hygiene in shared secondary base mixin.
5. Ticker context source optimization (prefer cached last context when valid).

### Out of Scope

1. New visual styles.
2. New options-panel layouts.
3. New domain features (faction selector, size/scale, font, localization).

## Implementation Tasks

1. Normalize drag stop semantics.
- Update both secondary style mixins to avoid setting user placement false on drag stop.
- Ensure position persistence remains managed by `SavePosition()`.

2. Add combat-safe movement guards.
- Guard movement toggles/setup paths that can run during combat-sensitive states.
- Defer movement-state changes when needed and apply safely post-combat.

3. Harden tooltip handlers.
- Add `GameTooltip` existence guards and defensive early returns.
- Ensure leave handlers are safe even if tooltip owner state changed.

4. Improve fade lifecycle safety.
- Reuse/reset animation primitives safely across repeated fades.
- Prevent stale animation state from accumulating.

5. Optimize ticker context sourcing.
- Prefer last rendered context for ticker text updates when valid.
- Keep context rebuild fallback only when cache is unavailable.

## Candidate File Targets

- `ui/secondary/FlatReputationBarStyle.lua`
- `ui/secondary/FlatCompanionBarStyle.lua`
- `ui/mixins/SecondaryBarBaseMixin.lua`
- `ui/SecondaryBarManager.lua` (only if movement/lock enforcement needs manager coordination)

## Validation Matrix

1. Drag and persistence
- Unlocked + Shift-drag works for both secondary bars.
- Positions persist across reload.
- Reset anchor returns defaults.

2. Lock and combat safety
- Locked bars cannot be dragged.
- No taint/errors from movement setup when entering or leaving combat.

3. Tooltip safety
- Hover/leave produces no errors with and without valid context.
- Tooltip content remains consistent during rapid context updates.

4. Fade/ticker stability
- Repeated availability transitions do not accumulate broken animation state.
- Ticker updates text without unnecessary full context rebuild churn.

## Exit Criteria

1. All in-scope tasks implemented and verified against validation matrix.
2. No regressions in existing Phase 6 behavior.
3. Results documented in `docs/memory/decision-log.md`.
4. Follow-up slice selection can proceed from a stable baseline.
