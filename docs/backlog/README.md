# Backlog

Future work items for XPBarEnhanced. Each file is one actionable work item with goal, scope, tasks, and acceptance criteria.

Completed and closed items have been archived to `docs/history/phases.md`. Decisions are recorded in `docs/memory/decision-log.md`.

## How to Use This Backlog

1. **Pick a goal** — Review the items below and select one that aligns with the current product direction.
2. **Validate readiness** — Ensure any prerequisites (investigation, analysis) are complete before starting.
3. **Create a plan** — Add concrete steps to `docs/plan.md` with scope, checklist, and validation criteria.
4. **Record decisions** — Append approval and key decisions to `docs/memory/decision-log.md`.

## Active Backlog Items

| Item | Goal | Status | Priority | Prerequisite |
| ---- | ---- | ------ | -------- | ------------ |
| [secondary-bar-styles.md](secondary-bar-styles.md) | Give users visual style options for secondary bars beyond "flat" | Investigation in progress — see `docs/analysis/secondary-bar-styles-investigation.md` | P3 | Architecture review, UX review, delivery plan |
| [secondary-bar-per-style-position.md](secondary-bar-per-style-position.md) | Per-style independent saved position for the secondary bar | **Approved — next session** | P2 | None |

## Completed Work (Archived)

See `docs/history/phases.md` for implementation records of:

- Shared bar contract (Phase 5)
- Event router consolidation (Phase 5, 3 stages)
- Session persistence across /reload (Phase 5)
- XP tracking quick wins (Phase 7 follow-up)
- Secondary bar fade, drag, tooltip, live text (Phase 6)
- Compliance hardening, context contract, max-level behavior (Phase 7, Slices 1-3)

## Closed / Archived

- `options-panel-sections` — closed 2026-04-08; already implemented. Archived to `docs/history/`
- `max-level-enhancements` — completed Phase 7 Slice 3. Archived to `docs/history/`
- `phase-7-planning-gate` — all slices complete. Archived to `docs/history/`

## Closed / Not Planned

- Faction selection dropdown — closed 2026-04-06
- Bar size/scale options — closed 2026-04-06
- Per-bar font customization — closed 2026-04-06
- Multi-language localization — closed 2026-04-06
- Companion multi-companion (`companion-multi-companion.md`) — closed 2026-04-12; C_DelvesUI API review not warranted; current Brann + Valeera ID list in `defaults.delveCompanions` is sufficient
- Font customization (global) — closed 2026-04-12; not a prioritized feature
- Edit Mode compat validation — closed 2026-04-12; too complex to implement correctly given Blizzard's internal Edit Mode architecture; current behavior preserved as-is
