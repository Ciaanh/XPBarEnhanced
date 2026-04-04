# Decision Log

## 2026-04-03

Decision: Move active planning and backlog documentation to docs folder hierarchy.
Reason: reduce dependence on AI-specific folder conventions and keep project knowledge portable.
Impact: docs/plan.md becomes active session guide; docs/memory, docs/guidelines, docs/features become canonical project docs.

Decision: Keep BarManager and SecondaryBarManager split.
Reason: responsibilities differ and forcing merge adds complexity without clear gain.
Impact: refactoring focuses on event/context/render contract consistency, not manager unification.

Decision: Defer full Event Router consolidation.
Reason: high-change operation best done after contract normalization.
Impact: short-term work prioritizes correctness and stabilization first.

## 2026-04-04

Decision: EventBus no longer auto-builds XP context; emitters must provide explicit payloads.
Reason: remove domain-specific implicit behavior from shared infrastructure.
Impact: emit sites were normalized; listeners now receive predictable payload contracts.

Decision: Secondary session emitters return the same flat context shape consumed by secondary bar styles.
Reason: avoid listener-side rebuilding and context-shape mismatches.
Impact: reputation/companion bars render from emitted context consistently.

Decision: Split Blizzard tracking-bar visibility ownership by domain.
Reason: XP style selection should not hide Blizzard reputation tracking when custom reputation style is disabled.
Impact: BarManager controls Blizzard XP visibility; SecondaryBarManager controls Blizzard reputation visibility.

Decision: On watched-faction clear/switch, ReputationSession emits immediate update.
Reason: prevent stale custom reputation bar state after tracked faction transitions.
Impact: custom reputation bar now hides/shows correctly when tracked faction changes.

## 2026-04-04 (Backlog)

Decision: Create docs/backlog/ folder with individual feature files, replacing inline plan.md backlog.
Reason: one-file-per-feature allows independent tracking, clear scope, and avoids plan.md bloat.
Impact: plan.md now references backlog folder; backlog README provides priority index.

Decision: Prioritize secondary bar polish (fade, tooltip, drag) as P1 before architecture refactors.
Reason: user-visible improvements deliver value immediately; architecture work is internal and can wait.
Impact: P1 items are all small-effort, low-risk secondary bar enhancements.

Decision: Defer event router consolidation and shared bar contract to P3.
Reason: high-change refactors best done after secondary bar polish is stable and well-tested.
Impact: current multi-frame event registration remains until all P1/P2 work is complete.

## 2026-04-04 (Architecture Alignment Update)

Decision: Re-prioritize shared bar contract and event router consolidation ahead of secondary-bar polish tasks.
Reason: architecture-enabling work reduces duplicated implementation effort and improves traceability.
Impact: `shared-bar-contract.md` and `event-router-consolidation.md` promoted to P1; secondary polish items moved to P2.

Decision: Enforce strict manager boundaries in architecture guidance.
Reason: managers should remain lifecycle/style/visibility orchestrators and avoid domain context-building responsibilities.
Impact: guidelines and feature docs now explicitly require manager-layer context decoupling.

Decision: Adopt Blizzard-aligned status/progress UI principles as architecture references.
Reason: Blizzard patterns favor central orchestration, shared bar contracts, and coalesced animation/update handling.
Impact: `docs/guidelines/code-architecture-choices.md` updated with explicit architecture principles and migration priorities.
