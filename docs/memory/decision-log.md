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

## 2026-04-05

Decision: Start shared secondary-bar lifecycle migration with a dedicated base mixin.
Reason: secondary bars duplicated lifecycle wiring and rendered immediately on each event; this blocks additive polish work.
Impact: `XPBarSecondaryBaseMixin` now owns `OnLoad`/`OnShow`/`OnHide`/`Refresh`/`MarkDirty`, while secondary styles only provide domain hooks and render logic.

Decision: Keep shared-contract Phase 1 scoped to secondary bars first.
Reason: minimize blast radius and preserve stable primary XP behavior while validating the contract pattern.
Impact: `FlatReputationBarMixin` and `FlatCompanionBarMixin` now compose from the shared base; XP primary mixin remains unchanged for this step.

Decision: Add optional secondary text ticker support to shared lifecycle mixin.
Reason: enable follow-on live text/tooltip polish without re-adding per-style ticker wiring.
Impact: secondary styles can opt in with `GetTextTickerInterval` and `OnTextTick`; no behavior changes for styles that do not implement these hooks.

Decision: Begin Phase 2 by removing manager dependency on private session context builders.
Reason: private session methods should not be called outside service scope; manager responsibilities should remain lifecycle/visibility focused.
Impact: `SecondaryBarManager` now builds startup contexts through `XPBarContextBuilder` instead of `_BuildContext` session internals.

Decision: Remove secondary entering-world broadcast ownership from `SecondaryBarManager`.
Reason: entering-world domain refresh belongs to session/service orchestration, not style/visibility manager layer.
Impact: manager no longer emits reputation/companion updates on entering world; session layers are now the source for those broadcasts.

Decision: Re-apply secondary Blizzard visibility policy from lifecycle defer pass.
Reason: Blizzard status tracking containers can be re-shown during entering-world internals and must be corrected after all handlers finish.
Impact: `AddOnLifecycle:OnPlayerEnteringWorld` now defers both XP and secondary visibility policy re-application.

Decision: Introduce `core/EventRouter.lua` for staged secondary-domain event ownership.
Reason: continue modularization by reducing distributed hidden event frames while keeping migration incremental.
Impact: router now owns `UPDATE_FACTION`, `CHAT_MSG_COMBAT_FACTION_CHANGE`, `MAJOR_FACTION_RENOWN_LEVEL_CHANGED`, and `DELVES_ACCOUNT_DATA_ELEMENT_CHANGED` dispatch for reputation/companion services.

Decision: Remove event frame creation from `ReputationSession` and `CompanionSession`.
Reason: event ownership moved to router; duplicate registration would cause redundant updates.
Impact: these services are now state/handler modules for external events rather than event-frame owners.

Decision: Migrate `QuestXP` external events to `EventRouter` and remove QuestXP listener frame.
Reason: continue staged consolidation of distributed event ownership while preserving existing rebuild delay behavior.
Impact: `QuestXP` now exposes `HandleRoutedEvent(event)`; router owns QuestXP event registrations and forwards to service handler.

Decision: Migrate Session external event ownership to `EventRouter` while preserving level-up lifecycle ownership.
Reason: reduce distributed event-frame ownership without changing existing `AddOnLifecycle -> Session:OnLevelUp` flow.
Impact: Session no longer registers WoW events directly; router now dispatches XP, quest, rested, and time-played events into Session handlers.
