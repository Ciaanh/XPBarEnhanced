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
| [secondary-bar-styles.md](secondary-bar-styles.md) | Give users visual style options for secondary bars beyond "flat" | Investigation only — not approved for coding | P3 | Architecture review, UX review, delivery plan |
| [companion-multi-companion.md](companion-multi-companion.md) | Support tracking any delve companion, not just Brann | Deferred — future work | P3 | C_DelvesUI API review |
| [xp-tracking-quick-wins.md](xp-tracking-quick-wins.md) | Three trivial XP improvements (isTask filter, expansion events, XP/hr threshold) | Ready to implement | P2 | None |
| [options-panel-sections.md](options-panel-sections.md) | Group the 36-option flat list into labelled sections; hide inactive style sections | Ready to implement | P2 | None |

## Potential New Work (Not Yet Filed)

Ideas that have surfaced but don't have backlog files yet. File them when they're ready for investigation.

- **Options panel restructure** — Tabbed or grouped layout for growing settings (noted in `docs/notes.md` Track 2)
- **UI folder naming cleanup** — Migration-safe folder/file rename pass (noted in `docs/notes.md` Track 3)
- **Dead code cleanup** — Remove unused max-level context builders and vestigial config keys from Slice 3 exploration
- **Debug log removal** — Remove or gate investigation logs before release build

## Completed Work (Archived)

See `docs/history/phases.md` for implementation records of:

- Shared bar contract (Phase 5)
- Event router consolidation (Phase 5, 3 stages)
- Session persistence across /reload (Phase 5)
- Secondary bar fade, drag, tooltip, live text (Phase 6)
- Compliance hardening, context contract, max-level behavior (Phase 7, Slices 1-3)

## Closed / Not Planned

These were explicitly closed on 2026-04-06 (rationale in decision-log):

- Faction selection dropdown
- Bar size/scale options
- Per-bar font customization
- Multi-language localization
