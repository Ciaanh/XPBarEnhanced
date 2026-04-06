# Feature: Phase 7 Slice 2 - Secondary Context Contract Normalization

Status: In Progress
Last updated: 2026-04-06
Priority: P1 (post-hardening consistency)

## Objective

Normalize secondary-bar context sourcing so emitted payloads and cached rendered context are preferred over repeated rebuilds.

Derived from:

- `docs/analysis/pre-phase-7-architecture-compliance-deliverable.md` (Section 2, Slice A/B)

## Scope

### In Scope

1. Centralize context source selection in `SecondaryBarBaseMixin`.
2. Prefer latest emitted/cached context for `Refresh()` and ticker flows.
3. Keep first-show bootstrap fallback via `GetInitialContext()` only when cache is missing.
4. Document contract update in memory/gate docs.

### Out of Scope

1. Service-layer event payload redesign for XP/reputation/companion.
2. New feature behavior or UI changes.
3. Manager-level architecture refactors.

## Candidate File Targets

- `ui/mixins/SecondaryBarBaseMixin.lua`
- `ui/secondary/FlatReputationBarStyle.lua`
- `ui/secondary/FlatCompanionBarStyle.lua`

## Validation Matrix

1. Context consistency

- event-driven updates render from emitted payload
- refresh path uses cached context when available
- bootstrap fallback used only when no cache exists

1. Behavior regression

- no visual regression on secondary bars
- no loss of updates during faction/companion transitions

## Exit Criteria

1. Shared context-source logic implemented in base lifecycle.
2. No syntax/runtime errors observed in in-game validation.
3. Decision log updated with contract normalization result.

## Validation Result (Current Batch)

Date: 2026-04-06

- In-game validation reported no errors for this Slice 2 batch.
- No regressions observed in secondary bar behavior during this pass.
