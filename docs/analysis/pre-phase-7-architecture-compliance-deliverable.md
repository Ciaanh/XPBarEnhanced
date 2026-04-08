# Pre-Phase-7 Planning Deliverable

Last updated: 2026-04-06
Scope: Combined architecture-consistency analysis + Blizzard UI compliance hardening checklist
Status: Planning artifact (no direct runtime changes)

> **MQ-4 Audit (2026-04-08)**:
> - §2.1 gap 1 (session ownership model) — PARTIALLY RESOLVED: XP uses SavedVariables-backed Session; secondary uses ReputationSession with `_session` local. Intentional split per architecture guidelines; remaining contract asymmetry tracked in MQ-1.
> - §2.1 gap 2 (secondary rebuilds context on ticker) — **RESOLVED**: `SecondaryBarBaseMixin` caches `_lastContext`; ticker uses cached context via `GetTextTickerContext()`.
> - §3.1 Critical: drag persistence semantics — **RESOLVED**: `OnDragStop`/`SavePosition` rewritten in NR-4 and session 6 fixes. `SetUserPlaced` only called after a real drag.
> - §3.1 Critical: combat-safe movement — **RESOLVED**: `InCombatLockdown()` guards in `OnDragStart`.
> - §3.2 High: tooltip safety guards — **RESOLVED**: nil-check guards on `GameTooltip` and `_lastContext` in `FlatSecondaryBarStyle`.
> - §3.2 High: animation lifecycle hygiene — **RESOLVED** in NR-4: fade animation reuses single `_fadeAnim`; stopped on `OnHide`.
> - §3.2 High: movement/lock semantic parity — **RESOLVED** in session 6: attached/free drag semantics unified; max-level override implemented.
> - §3.3 Medium: ticker context sourcing — **RESOLVED**: `GetTextTickerContext()` returns `_lastContext` when available.
> - §3.3 Medium: 12.0 compliance checkpoints — OPEN: documentation in `docs/guidelines/code-architecture-choices.md` not yet updated with explicit checklist. Candidate for MQ-1 or documentation pass.
> - File path references in this doc point to old `ui/secondary/` paths (removed in NR-3); current paths are `ui/styles/flat/FlatSecondaryBarStyle.lua` and `ui/mixins/SecondaryBarBaseMixin.lua`.

## 1) Executive Summary

This deliverable stages both required Session 2 outputs in one package:

1. Architecture consistency analysis for XP vs secondary (reputation/companion) workflows.
2. Prioritized Blizzard UI best-practice and compliance hardening checklist.

Current state is stable and functional, but there are inconsistencies in context ownership and interaction safety that should be addressed before any broader Phase 7 expansion.

## 2) Architecture Consistency Analysis

### 2.1 Confirmed Consistency Gaps

1. Session ownership model differs across domains.
- XP path is primarily database-backed through `Session:GetCurrent()` and immediate context broadcast in `Session:OnXPUpdate()`.
- Reputation and companion paths rely on service-local `_session` ownership.
- References: `core/services/Session.lua`, `core/services/ReputationSession.lua`.

2. Secondary styles rebuild context on refresh/ticker instead of using a single source.
- Secondary bars consume emitted context when available via `MarkDirty(context)`.
- On `Refresh()` and 1s text ticker callbacks, styles call `GetInitialContext()` which rebuilds context from `XPBarContextBuilder`.
- References: `ui/mixins/SecondaryBarBaseMixin.lua`, `ui/secondary/FlatReputationBarStyle.lua`, `ui/secondary/FlatCompanionBarStyle.lua`.

3. Context lifecycle is not fully unified across bar types.
- XP and secondary bars share event-driven rendering but still differ in context rehydration behavior and some interaction semantics.
- This creates avoidable duplication and harder reasoning about data freshness.

### 2.2 Target Contract (Pre-Phase-7)

Adopt one explicit contract across XP, reputation, and companion flows:

1. Services emit canonical context payloads for domain update events.
2. Bar listeners render from emitted context whenever available.
3. Fallback context rebuild is allowed only for first-show bootstrap and must be centralized.
4. Ticker paths should prefer cached last-rendered context and only rebuild if cache is missing.
5. Manager modules remain orchestration-only (style/lifecycle/visibility), not context builders.

### 2.3 Incremental Migration Slices (Planning Only)

1. Slice A: Define and document canonical context-source rules in architecture guidelines.
2. Slice B: Add secondary-style cache usage for ticker/refresh to reduce duplicate rebuilds.
3. Slice C: Normalize service-side context emit semantics for all domains.
4. Slice D: Validate consistency via in-game matrix before approving any new feature expansion.

## 3) Blizzard UI Compliance Hardening Checklist

Priority legend: Critical > High > Medium.

### 3.1 Critical

1. Drag persistence semantics: stop using `SetUserPlaced(false)` on drag stop.
- Risk: can conflict with expected user-placement behavior.
- Target: set user placement consistently only after successful move-save flow.
- References: `ui/secondary/FlatReputationBarStyle.lua`, `ui/secondary/FlatCompanionBarStyle.lua`.

2. Combat-safe movement toggles for draggable bars.
- Risk: frame movement configuration updates during combat can taint protected flows.
- Target: gate movement state changes with combat-safe checks and defer if needed.
- References: `ui/secondary/FlatReputationBarStyle.lua`, `ui/secondary/FlatCompanionBarStyle.lua`, `ui/mixins/SecondaryBarBaseMixin.lua`.

### 3.2 High

1. Tooltip safety guards.
- Risk: `GameTooltip` assumptions in edge/runtime states.
- Target: add guard checks and safe early returns in hover handlers.
- References: `ui/secondary/FlatReputationBarStyle.lua`, `ui/secondary/FlatCompanionBarStyle.lua`.

2. Animation lifecycle hygiene.
- Risk: repeated fade animation object growth and stale animation state.
- Target: ensure fade animation path reuses or resets animation primitives safely.
- Reference: `ui/mixins/SecondaryBarBaseMixin.lua`.

3. Movement/lock semantic parity.
- Risk: divergence from primary bar interaction expectations.
- Target: codify and validate one lock/drag policy across primary and secondary bars.
- References: `ui/secondary/FlatReputationBarStyle.lua`, `ui/secondary/FlatCompanionBarStyle.lua`, `ui/SecondaryBarManager.lua`.

### 3.3 Medium

1. Ticker context sourcing optimization.
- Risk: unnecessary repeated context rebuilding while shown.
- Target: prefer `_lastContext` for ticker display updates when valid.
- References: `ui/mixins/SecondaryBarBaseMixin.lua`, `ui/secondary/FlatReputationBarStyle.lua`, `ui/secondary/FlatCompanionBarStyle.lua`.

2. Document 12.0 compliance checkpoints in architecture guidance.
- Risk: future regressions toward restricted APIs/patterns.
- Target: explicit checklist section in architecture docs for combat data, comms, and secure-frame constraints.
- References: `docs/guidelines/code-architecture-choices.md`, `.github/instructions/wow-api-important.instructions.md`.

## 4) Validation Matrix For Hardening Slices

1. Drag behavior
- unlocked + shift-drag works
- locked bars cannot drag
- saved position survives reload
- reset position returns defaults

2. Combat safety
- entering combat during secondary-bar interaction causes no errors/taint warnings
- post-combat deferred updates apply correctly

3. Tooltip integrity
- hover/leave works with no errors
- tooltip lines update correctly with changing context

4. Context consistency
- event-driven render uses emitted payload
- bootstrap fallback only when no payload/cache exists
- ticker updates avoid redundant full context rebuilds

## 5) Proposed Next Implementation Order

1. Compliance hardening (critical + high) before any feature expansion.
2. Context contract normalization (slice A/B).
3. Re-run validation matrix and capture results.
4. Only then approve first post-gate implementation slice.

## 6) Gate Impact

This artifact satisfies the two planning outputs requested for Session 2:

1. Architecture consistency analysis is documented.
2. Blizzard UI compliance hardening checklist is documented and prioritized.

Approval is still required before Phase 7 coding begins, per `docs/features/phase-7-planning-gate.md`.
