# XPBarEnhanced — Project Plan

Last updated: 2026-04-07

## Addon Summary

Enhanced XP bar addon for WoW Retail with 7 visual styles, quest XP overlay, session statistics, reputation tracking, companion tracking, and full color customization.

## Current State

The addon is feature-complete for its core scope:

- **Primary XP bar**: 7 styles, animations, quest overlay, session tracking, max-level auto-hide
- **Reputation bar**: Watched faction tracking with fade, drag, tooltip, live text
- **Companion bar**: Delve companion tracking with the same polish features
- **Architecture**: Centralized event router, context-first render model, shared secondary lifecycle
- **Quality**: Compliance hardened (combat safety, fade lifecycle, context contracts)

All Phase 5 (foundations), Phase 6 (secondary polish), and Phase 7 (hardening) work is complete and validated. See `docs/history/phases.md` for implementation records.

## Goals

### Near-Term: Stabilize for Release

**Goal**: Get the addon to a clean, release-ready state.

Steps:

1. Remove dead code from Slice 3 exploration (unused context builders in BarManager, vestigial config keys)
2. Remove or gate debug investigation logs (MaxLevel logging throughout BarManager/BaseMixin)
3. In-game regression test across all 7 styles, secondary bars, max-level, and login/reload paths
4. Verify companion bar behavior in an actual Delve session
5. Update README if any user-facing behavior changed

### Medium-Term: Code Quality

**Goal**: Reduce technical debt and improve maintainability.

Steps:

1. Review and address `docs/notes.md` analysis tracks:
   - Track 1: Harmonize XP vs secondary context/session workflow patterns
   - Track 2: Evaluate options panel restructure for growing settings
   - Track 3: UI folder naming and structure cleanup
2. Assess whether additional analysis docs in `docs/analysis/` contain actionable items not yet captured in backlog

### Future: Feature Expansion

**Goal**: Expand addon capabilities based on user demand.

Available backlog items (see `docs/backlog/README.md` for details):

- Additional secondary bar styles (investigation required first)
- Multi-companion support (deferred, low priority)
- Any new ideas that arise from user feedback

## How to Start a Session

1. Review this plan for current goals and priorities
2. Pick a goal or step to work on
3. Check `docs/backlog/README.md` if picking feature work
4. Record decisions in `docs/memory/decision-log.md`
5. Update this plan when goals shift or steps are completed

## Documentation Map

| Location | Purpose |
| ---------- | ------- |
| `docs/plan.md` | This file — project goals, priorities, next steps |
| `docs/features/` | What the addon does — one file per feature |
| `docs/backlog/` | Future work items with goals, scope, and acceptance criteria |
| `docs/history/` | Completed implementation phases (archive) |
| `docs/analysis/` | Deep technical investigations and research |
| `docs/memory/` | Decision log, lessons learned, external analysis |
| `docs/guidelines/` | Architecture and project structure standards |
| `docs/notes.md` | Open analysis tracks for future investigation |
