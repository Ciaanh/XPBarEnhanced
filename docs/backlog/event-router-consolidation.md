# Backlog: Event Router Consolidation

Priority: P1
Effort: Large
Risk: Medium
Source: docs/analysis/architecture-analysis.md §3.3

## Summary

Consolidate the 5 independent `CreateFrame("Frame") + RegisterEvent` sites into a single event router that dispatches WoW events to the correct domain handlers via method calls.

Implementation policy: staged migration (domain-by-domain), not one-shot rewrite.

## Motivation

Currently, WoW events are registered independently by AddOnLifecycle, Session, ReputationSession, CompanionSession, and QuestXP — each creating its own hidden frame. This works but makes the event flow hard to trace and risks redundant broadcasts (e.g., `QUEST_TURNED_IN` fires in both Session and QuestXP, each potentially emitting `XPBAR_BROADCAST_UPDATE`).

A central event router would:

- Make the event → handler flow explicit and traceable.
- Eliminate hidden frame overhead (5 frames → 1).
- Allow deduplication of overlapping event registrations.
- Simplify future event additions.

## Scope

### In Scope

- Single event router frame registering all external WoW events.
- Router dispatches to domain handler methods (no EventBus interaction, just direct calls).
- Session services become pure state objects — no frame creation, no event registration.
- QuestXP cache becomes event-driven from the router.

### Out of Scope

- Changing the EventBus (remains for internal addon pub/sub).
- Changing the context builder or render pipeline.

## Tasks

1. Create `core/EventRouter.lua` with a single frame and a dispatch table.
2. Stage 1: migrate QuestXP + Session event ownership first; preserve behavior.
3. Stage 2: migrate ReputationSession + CompanionSession ownership.
4. Stage 3: collapse remaining lifecycle event fan-out into router dispatch.
5. Router calls appropriate handler methods on each service.
6. Remove `CreateFrame` and `RegisterEvent` from migrated services.
7. Update TOC load order.
8. Verify no regressions in event handling across all domains.

## Progress (2026-04-05)

- [x] Task 1 completed for secondary-domain events.
- [x] Task 2 completed: `QuestXP` and `Session` external event ownership migrated.
- [x] Task 3 completed: `ReputationSession` and `CompanionSession` external event ownership moved to `EventRouter`.
- [x] Task 4 completed for lifecycle fan-out scope, including startup/shutdown dispatch migration into `EventRouter`.
- [x] Task 5 completed for stage-2 mappings and stage-1 Session/QuestXP mappings.
- [x] Task 6 completed for stage-2 services and stage-1 Session/QuestXP service cleanup.
- [x] Task 7 completed for `EventRouter` module load.
- [x] Post-Stage-3 regression fix: guarded reputation/companion dispatch before service initialization and restored Session XP gain refresh path.
- [x] Task 8 completed: in-game validation passed (no errors, XP gain refresh restored, no visible regressions observed).

## Affected Files

- New: core/EventRouter.lua
- core/AddOnLifecycle.lua
- core/services/Session.lua
- core/services/ReputationSession.lua
- core/services/CompanionSession.lua
- core/services/QuestXP.lua
- XPBarEnhanced.toc

## Acceptance Criteria

- [x] Only one hidden frame registers WoW events.
- [x] All existing event-driven behavior is preserved.
- [x] Event → handler mapping is documented in the router.
- [x] No double-broadcast from overlapping events.
- [x] Services no longer create frames or register events directly.

## Risk Mitigation

- Implement incrementally and keep each stage shippable.
- Verify event parity per stage before deleting old registration paths.
- Do not keep commented dead code long-term; remove superseded paths after validation.

## References

- docs/analysis/architecture-analysis.md §3.3 "Session services own WoW event frames."
- docs/analysis/architecture-analysis.md §4 "Proposed Streamlined Architecture."
