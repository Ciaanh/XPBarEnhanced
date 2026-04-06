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

Decision: Start Stage 3 by moving remaining lifecycle fan-out events to `EventRouter`.
Reason: centralize runtime event routing in one place and reduce orchestration spread across modules.
Impact: router now dispatches entering-world, level-up, XP gain enable/disable, and max-level-update fan-out behavior; `AddOnLifecycle` was reduced to startup/shutdown handlers.

Decision: Complete Stage 3 by moving startup/shutdown event registrations into `EventRouter`.
Reason: satisfy single-frame external event ownership target and keep AddOnLifecycle focused on handler logic only.
Impact: `AddOnLifecycle` no longer owns a frame or event map; `EventRouter` now registers and dispatches `ADDON_LOADED`, `PLAYER_LOGIN`, and `PLAYER_LOGOUT` in addition to domain and lifecycle fan-out events.

Decision: Stabilize Stage 3 startup ordering by gating routed reputation/companion handlers on initialized session state, while keeping Session routed handlers ungated.
Reason: reputation/companion handlers depend on local `_session` seeded during login; Session uses database-backed `GetCurrent()` and must continue processing XP updates without `_session` gating.
Impact: nil-session faults on early routed events were resolved and XP refresh/animation behavior was restored after removing incorrect Session dispatcher gating.

Decision: Close Stage 3 consolidation after in-game validation pass.
Reason: runtime testing confirmed no errors and restored XP gain refresh behavior after startup-order stabilization fixes.
Impact: event-router consolidation backlog item is now considered implemented and validated for current scope.

Decision: Prepare Phase 5 execution as a staged implementation plan before touching runtime code.
Reason: session persistence changes affect saved variables, options wiring, and time-based calculations; staged rollout lowers regression risk.
Impact: Phase 5 now has a concrete, ordered checklist and validated target file map, ready for implementation kickoff.

Decision: Implement Phase 5 with `sessionAccumTime` persistence and configurable `/reload` reset policy.
Reason: keep XP/hour, session-time, and time-to-level stable across UI reload by default while still supporting opt-in reset semantics.
Impact: `Session` now persists/rebases elapsed session time through `/reload`; new `resetOnReload` option (default false) controls whether reload continues or resets the session window.

Decision: Close Phase 5 after in-game validation pass.
Reason: runtime checks confirmed correct continuity when `resetOnReload=false` and correct reset behavior when `resetOnReload=true`, with fresh login still starting a new session.
Impact: session-persistence-reload backlog item is now implemented and validated for current scope.

Decision: Carry `docs/notes.md` findings into next planning cycle as analysis tasks.
Reason: observed differences in XP vs secondary session/context workflow and options panel complexity are architectural/UX opportunities but not blockers for Phase 5 closure.
Impact: next-phase readiness now includes analysis tasks for workflow harmonization and options panel structure review against Blizzard patterns.

Decision: Gate Phase 7 behind a dedicated planning/approval session after Phase 6.
Reason: follow-on scope is not yet approved and needs separate review of priority, risk, and acceptance criteria before implementation.
Impact: `docs/plan.md` now treats Phase 6 as implementation-ready and Phase 7 as planning-only until explicit approval is documented.

Decision: Implement Phase 6 four features using shared base mixin hooks without lifecycle duplication.
Reason: all four polish features (fade, drag, tooltip, ticker) can be wired into hooks already present in `SecondaryBarBaseMixin` without adding new lifecycle paths.
Impact: style mixins implement feature-specific logic only; no duplicate controller/manager code required across styles.

Decision: Fade secondary bars only on tracking state changes, not idle timers.
Reason: fade should match Blizzard's reputation bar behavior, which occurs when the player tracks/untracks a faction or when companion availability changes, not on arbitrary idle periods.
Impact: `FadeToAlpha(targetAlpha)` triggers when `context.isAvailable` transitions from false→true or true→false; no delay or idle gating required.

Decision: Persist bar positions to SavedVariables on drag-stop, with config-driven key per bar type.
Reason: positions survive across reload and re-login, and can be cleared independently via reset button.
Impact: each style's `SavePosition()` stores point/relativeTo/relativePoint/x/y to `Addon.db[configKey]`; reset clears key and re-anchors.

Decision: Use TextFormatter for all tooltip and live-text number/time formatting.
Reason: maintain consistent formatting with primary XP bar tooltips and avoid format logic duplication.
Impact: both styles import and call `TextFormatter:FormatNumber()`, `:FormatTime()`, `:FormatPercent()` for display.

Decision: Implement live text ticker at 1.0s interval for both reputation and companion bars.
Reason: 1s update frequency matches primary XP bar ticker and provides real-time rate/gained feedback without excessive re-renders.
Impact: `GetTextTickerInterval()` returns 1.0; `OnTextTick(context)` rebuilds on-bar text label with fresh calculations every 1s.

Decision: Tooltip content includes session metrics (gained, rates, time-to-next) in addition to bar-displayed progress.
Reason: tooltips provide user with deeper context on session performance without cluttering on-bar text.
Impact: `OnEnter()` reads `_lastContext` and populates GameTooltip with faction/companion name, progress, session gained, rep/hour or XP/hour, and time projections.

Decision: Simplify fade implementation to state-change-based transitions instead of idle timers.
Reason: fade-out should only occur when faction tracking is disabled or companion becomes unavailable, not on arbitrary idle delays; this matches Blizzard's behavior.
Impact: removed `FadeOut()` idle timer logic and `secondaryFadeDelay` config; replaced with `FadeToAlpha(targetAlpha)` that triggers only when `context.isAvailable` state changes frame-to-frame.

## 2026-04-06

Decision: Close faction selector, size/scale options, per-bar font customization, and localization from the active roadmap.
Reason: these items are not needed for the current product scope and should not consume near-term implementation capacity.
Impact: related backlog files are now marked closed/not planned and removed from active execution ordering.

Decision: Keep additional secondary styles as investigation-only.
Reason: style expansion requires deeper architecture and UX analysis before accurate effort/risk estimation.
Impact: `docs/backlog/secondary-bar-styles.md` now includes an explicit investigation gate and is not approved for coding.

Decision: Start pre-Phase-7 implementation with documentation and governance alignment.
Reason: roadmap and phase guidance must be synchronized before any next feature implementation begins.
Impact: `docs/plan.md`, `docs/backlog/README.md`, and `docs/notes.md` were updated to reflect active priorities, analysis tracks, and approval gates.

Decision: Stage Session 2 architecture and Blizzard-compliance outputs as one combined planning deliverable.
Reason: keep pre-Phase-7 approval inputs centralized, reduce fragmentation, and make gate review explicit.
Impact: `docs/analysis/pre-phase-7-architecture-compliance-deliverable.md` is now the canonical Session 2 artifact and is referenced by gate/planning docs.

Decision: Select Phase 7 Slice 1 as compliance-hardening-first before any feature expansion.
Reason: critical/high-risk interaction safety and Blizzard-aligned behavior should be stabilized before broader post-gate changes.
Impact: `docs/features/phase-7-slice-1-compliance-hardening.md` is now the next coding slice target and is linked from planning-gate and plan docs.

Decision: Compact planning and phase documentation to enforce concise, bounded docs.
Reason: phase/session docs were growing with duplicated historical narrative and drifting from governance intent.
Impact: `docs/plan.md` is now a concise execution guide, `docs/features/phase-6-secondary-polish.md` is a compact feature summary, and `docs/README.md` now documents clear boundaries for plan vs feature vs analysis vs decision-log content.

Decision: Enforce strict doc ownership model: plan=session planning, features+memory=decisions/analysis context.
Reason: prevent documentation growth from mixed responsibilities and keep one source of truth per concern.
Impact: `docs/plan.md` now excludes durable approvals/decisions, `docs/features/phase-7-planning-gate.md` owns approval state, and approvals/decision rationale are required in `docs/memory/decision-log.md`.

Decision: Approve Phase 7 Slice 1 and begin compliance hardening implementation.
Reason: planning gate criteria were met and the next safe step is targeted hardening before broader feature expansion.
Impact: `docs/features/phase-7-planning-gate.md` now records approval; `docs/features/phase-7-slice-1-compliance-hardening.md` status moved to in-progress.

Decision: Harden secondary drag semantics by removing SetUserPlaced(false) on drag paths and setting user placement true on drag stop.
Reason: avoid conflicting placement semantics while preserving explicit SavedVariables persistence flow.
Impact: secondary style mixins now call `SetUserPlaced(true)` on drag stop and no longer force false on drag start/stop.

Decision: Add combat-safe drag setup and movement gating for secondary bars.
Reason: movement-related setup should not run unsafely during combat-sensitive windows.
Impact: `SecondaryBarBaseMixin:ConfigureDragSupport()` now defers drag setup to `PLAYER_REGEN_ENABLED` when needed; drag start is blocked while in combat.

Decision: Add tooltip safety guards and ticker context caching preference.
Reason: avoid tooltip nil access issues and reduce avoidable context rebuild churn.
Impact: tooltip handlers now guard `GameTooltip`; text ticker now prefers `_lastContext` before rebuilding fallback context.

Decision: Rework fade animation lifecycle to reuse a single animation object.
Reason: prevent repeated animation allocation/stale state accumulation during frequent availability transitions.
Impact: `FadeToAlpha()` now reuses cached animation objects, stops in-flight animation before retargeting, and stops cleanly on hide.

Decision: Close Slice 1 hardening after in-game validation pass.
Reason: runtime testing reported no errors after drag/combat-safety/tooltip/fade/ticker hardening changes.
Impact: `docs/features/phase-7-slice-1-compliance-hardening.md` marked implemented and validated; repository is ready to move to next approved slice selection.

