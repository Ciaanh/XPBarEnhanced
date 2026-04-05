# XPBarEnhanced Session Plan

Last updated: 2026-04-05
Scope: Current implementation guide for ongoing coding work.

## How To Use This Plan

1. This file is the active session guide.
2. Strategic context lives in:
   - docs/memory — decisions, lessons, external analysis
   - docs/guidelines — architecture and structure rules
   - docs/features — per-feature status tracking
   - docs/backlog — prioritized backlog of future work (one file per feature)
   - docs/analysis — deep-dive analysis documents (input only, not updated during sessions)
3. At end of each work session:
   - update status in this file
   - append key decisions to docs/memory/decision-log.md
   - move durable lessons to docs/memory/lessons-learned.md

## Project Status (v1.0.7)

The addon is **feature-complete for its initial scope**. All P0 work is done.

### Completed Milestones

| Milestone | Status | Version |
|-----------|--------|---------|
| Core XP bar with 6 styles | Done | 1.0.0–1.0.5 |
| Terminal + minimap ring styles | Done | 1.0.5 |
| Edit Mode awareness | Done | 1.0.5 |
| Circular center text fix + scaling | Done | 1.0.6 |
| Secondary bars (reputation + companion) | Done | 1.0.7 |
| Event contract hardening (dispatcher-only EventBus) | Done | 1.0.7 |
| Secondary bar stabilization (anchors, context, lifecycle) | Done | 1.0.7 |

### Architecture Health

- EventBus: pure dispatcher, no domain-specific behavior.
- Three isolated data pipelines (XP, reputation, companion) with per-domain sessions.
- Context-first rendering: emitters own context, listeners consume.
- MarkDirty coalescing and 2.5s text ticker active on primary bar.
- Secondary bars are functional but still use a simpler lifecycle contract than primary bars.
- External WoW event ownership remains distributed across multiple frames and should be consolidated incrementally.

## Current Priorities

No active P0 work. Next priorities should be selected from `docs/backlog/`.

Recommended execution order:
1. Shared bar contract baseline — `docs/backlog/shared-bar-contract.md`
2. Event router consolidation (staged migration) — `docs/backlog/event-router-consolidation.md`
3. Session persistence across /reload — `docs/backlog/session-persistence-reload.md`
4. Secondary bar polish (fade, tooltip, drag-to-move) — `docs/backlog/secondary-bar-fade-animation.md`, `docs/backlog/secondary-bar-tooltip.md`, `docs/backlog/secondary-bar-drag-to-move.md`
5. Time display improvements — `docs/backlog/time-display-live-refresh.md`
6. Faction selection UI — `docs/backlog/faction-selection-dropdown.md`
7. Bar size/scale options — `docs/backlog/bar-size-scale-options.md`
8. New secondary bar styles — `docs/backlog/secondary-bar-styles.md`
9. Font customization expansion — `docs/backlog/font-customization-per-bar.md`
10. Localization — `docs/backlog/localization-multi-language.md`
11. Max level behavior expansion — `docs/backlog/max-level-enhancements.md`

## Multi-Step Implementation Plan

### Phase 0 — Baseline and Safety Rails

Goal: lock current behavior before refactors.

1. Confirm current validation matrix baseline in-game (login, reload, level-up, rep, companion, style switch, reset anchor).
2. Add temporary debug counters/trace toggles for event fan-out and render count (dev-only, removable).
3. Document baseline observations in `docs/memory/decision-log.md`.

Exit criteria:
- Baseline behavior and known edge cases are recorded.
- Refactor regressions can be identified quickly.

### Phase 1 — Shared Bar Lifecycle Contract (P1)

Goal: create one reusable lifecycle for all bars.

1. Extract generic lifecycle behavior from primary mixins into a shared base (`OnLoad`, `OnShow`, `OnHide`, `MarkDirty`, optional ticker hooks).
2. Keep XP-specific animation/render behavior in XP-specific mixins.
3. Define explicit extension points for secondary bars (`Render(context)`, optional `OnTextTick`, optional fade hooks).
4. Update feature docs for XP and secondary manager contracts.

Exit criteria:
- Secondary bars can opt into the same dirty/coalesced lifecycle contract.
- No XP bar behavior regression.

### Phase 2 — Secondary Bars on Shared Contract (P1)

Goal: remove ad-hoc secondary lifecycle duplication.

1. Refactor reputation and companion style mixins to use shared base lifecycle.
2. Move repeated subscription/ticker cleanup logic into shared code.
3. Keep rendering domain-specific and context-driven.

Exit criteria:
- Secondary bars use shared lifecycle hooks.
- Event bursts do not cause duplicate same-frame redraws.

### Phase 3 — Event Router Consolidation Stage 1 (P1)

Goal: centralize highest-overlap event ownership first.

1. Introduce `core/EventRouter.lua` with explicit event → handler mapping.
2. Migrate Session + QuestXP external event registration to router.
3. Preserve existing internal EventBus payload contracts.

Exit criteria:
- Session/QuestXP no longer create their own event frames.
- No regressions in XP, quest overlay, level-up flow.

### Phase 4 — Event Router Consolidation Stage 2/3 (P1)

Goal: complete event ownership centralization incrementally.

1. Migrate ReputationSession and CompanionSession external events into router.
2. Remove remaining per-service frame registration paths.
3. Keep manager modules lifecycle/style-only.

Exit criteria:
- Single external event owner is in place for addon domains.
- Event flow is traceable from router mapping.

### Phase 5 — Session Persistence Across Reload (P1)

Goal: make time-based metrics stable across `/reload`.

1. Implement `sessionAccumTime` + `resetOnReload` behavior.
2. Add option wiring and locale strings.
3. Validate XP/hour and time-to-level continuity across reload.

Exit criteria:
- Reload preserves or resets session by config as expected.

### Phase 6 — Secondary Bar Polish on Stable Foundation (P2)

Goal: deliver UX improvements without duplicating infrastructure.

1. Implement fade transitions via shared lifecycle hooks.
2. Implement tooltip via shared anchor/formatting utility.
3. Implement drag-to-move using shared position behavior.
4. Add secondary time text refresh using shared ticker path.

Exit criteria:
- Fade/tooltip/drag/live-text work with no lifecycle duplication.

### Phase 7 — Follow-On Feature Work (P2/P3)

Goal: continue backlog work on a simplified architecture.

1. Faction selector, size/scale, font customization.
2. Additional secondary styles and localization.
3. Max-level behavior enhancements.

Exit criteria:
- New features integrate through shared contracts, not parallel custom flows.

## Validation Matrix

- [ ] Login: XP + secondary bars initialize with expected visibility/position.
- [ ] Reload UI: bars preserve anchors and render from event payloads.
- [ ] Level-up: XP updates and dependent bars do not regress.
- [ ] Reputation gain/standing change: reputation bar updates with smooth visibility transitions.
- [ ] Companion update/availability change: companion bar updates and hides without flicker.
- [ ] Style switch: manager lifecycle remains stable and side-effect clean.
- [ ] Reset anchor (options): controls remain coherent and bars move to expected defaults.

## Notes

- Keep manager split (XP vs secondary) unless architecture guidance changes.
- Keep manager responsibilities strict: lifecycle/style/visibility orchestration only.
- Backlog items are in `docs/backlog/` — one file per feature with priority, scope, and acceptance criteria.

## Previous Session Summary (2026-04-04)

- Event contract hardening implemented: EventBus now requires explicit context payloads.
- Secondary bars stabilized: debug scaffolding removed, listeners render from emitted context, and default anchors moved to config.
- Reputation watched-faction transitions fixed: clear/switch now emits update immediately so the custom bar hides/shows correctly.
- Blizzard container ownership split: XP style controls Blizzard XP bar visibility; reputation style controls Blizzard reputation bar visibility.
- Options reset-anchor now resets secondary bar anchors and button placement aligns with secondary-bar controls.

## Current Session Progress (2026-04-05)

- Phase 1 implementation started: added `ui/mixins/SecondaryBarBaseMixin.lua` with shared secondary lifecycle hooks (`OnLoad`, `OnShow`, `OnHide`, `Refresh`, `MarkDirty`).
- `ui/secondary/FlatReputationBarStyle.lua` and `ui/secondary/FlatCompanionBarStyle.lua` now compose from the shared base and provide domain-specific hooks/rendering only.
- `docs/backlog/shared-bar-contract.md` updated to reflect initial completed tasks and acceptance criteria progress.
- Optional secondary text ticker support added to shared mixin (`GetTextTickerInterval` + `OnTextTick` hook contract).
- Phase 2 kickoff: `SecondaryBarManager` no longer calls private session `_BuildContext()` methods during entering-world bootstrap.
- Phase 2 continued: entering-world secondary broadcast ownership moved off manager and into session flows; lifecycle now only reapplies secondary Blizzard visibility policy after world entry.
- Phase 2 continued: added `core/EventRouter.lua` and migrated reputation/companion external event ownership from per-service frames to centralized router dispatch.
- Phase 2 continued: migrated `QuestXP` external events to `EventRouter` and removed QuestXP event frame ownership.
- Phase 2 continued: migrated Session external event ownership to `EventRouter`; Session now acts as routed handler module (level-up remains lifecycle-owned).
- Stage 3 started: lifecycle fan-out events (`PLAYER_ENTERING_WORLD`, `PLAYER_LEVEL_UP`, `ENABLE_XP_GAIN`, `DISABLE_XP_GAIN`, `PLAYER_MAX_LEVEL_UPDATE`) moved into `EventRouter` dispatch; `AddOnLifecycle` now handles startup/shutdown only.
- Stage 3 continued: startup/shutdown registrations (`ADDON_LOADED`, `PLAYER_LOGIN`, `PLAYER_LOGOUT`) moved into `EventRouter`; `AddOnLifecycle` now provides lifecycle handler methods only.
- Stage 3 stabilization: fixed startup-order nil session faults by gating reputation/companion routed handlers until initialized; restored Session XP gain accumulation path so XP refresh and animation behavior resumed.
- Stage 3 validation complete: in-game verification passed with no errors; XP gain refresh/animation behavior confirmed restored and overall routing behavior stable.

## Next Phase Readiness (Planning Only)

Target next phase: **Phase 5 — Session Persistence Across Reload**.

Prepared scope (no implementation started):

1. Add explicit persistence model for session continuity across `/reload` (`sessionAccumTime` + reset policy).
2. Wire config toggle for reset behavior and update locale strings.
3. Validate XP/hour and time-to-level continuity with and without reset enabled.

Entry checklist prepared:

- Confirm current session fields in `core/services/Session.lua` and `services/Database.lua` support additive time accounting.
- Define migration-safe defaults for existing users in `config/defaults.lua`.
- Prepare in-game test matrix for `/reload` continuity and option toggle behavior.
