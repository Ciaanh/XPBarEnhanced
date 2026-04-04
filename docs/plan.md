# XPBarEnhanced Session Plan

Last updated: 2026-04-04
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
- Defer event router consolidation until after secondary-bar polish is stable.
- Backlog items are in `docs/backlog/` — one file per feature with priority, scope, and acceptance criteria.

## Previous Session Summary (2026-04-04)

- Event contract hardening implemented: EventBus now requires explicit context payloads.
- Secondary bars stabilized: debug scaffolding removed, listeners render from emitted context, and default anchors moved to config.
- Reputation watched-faction transitions fixed: clear/switch now emits update immediately so the custom bar hides/shows correctly.
- Blizzard container ownership split: XP style controls Blizzard XP bar visibility; reputation style controls Blizzard reputation bar visibility.
- Options reset-anchor now resets secondary bar anchors and button placement aligns with secondary-bar controls.
