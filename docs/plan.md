# XPBarEnhanced — Project Plan

Last updated: 2026-04-08 (architecture hardening + backlog normalization)

## Addon Summary

Enhanced XP bar addon for WoW Retail with 7 visual styles, quest XP overlay, session statistics, reputation tracking, companion tracking, and full color customization.

## Current State

The addon is feature-complete for its core scope:

- **Primary XP bar**: 7 styles, animations, quest overlay, session tracking, max-level auto-hide
- **Unified secondary bar**: Watched-faction tracking with companion-aware display, fade, drag, tooltip, live text
- **Architecture**: Centralized event router, context-first render model, shared secondary lifecycle
- **Quality**: Compliance hardened (combat safety, fade lifecycle, context contracts)

All Phase 5 (foundations), Phase 6 (secondary polish), and Phase 7 (hardening) work is complete and validated. See `docs/history/phases.md` for implementation records.

Completed (sessions 4–6):

- **NR-1**: Dead Slice 3 exploration code removed
- **NR-2**: MaxLevel debug logs removed
- **Bug fix**: `SavePosition` frame-reference serialization bug corrected
- **Default position**: Secondary bar default anchor corrected; attached mode re-anchors to active XP bar
- **NR-3 complete**: companion/reputation pipelines unified into one tracked-reputation secondary bar
- **UI regrouping**: flat secondary style/template moved under `ui/styles/flat/`
- **Interaction**: click on secondary bar opens Character Reputation panel
- **New option**: `hideCompanionOutsideDelve` hides companion bar when outside Delves
- **NR-4 complete**: full regression pass — 3 bugs found and fixed (debug default shipped on, dead `__isDragging` flag, fade-in symmetry); `debugSecondaryBars` infrastructure removed entirely; all 7 primary styles, secondary bar, lifecycle paths, and Blizzard bar ownership validated in-game
- Max-level fixes (session 6): resolved duplicate Blizzard reputation bar at max level; secondary bar style derivation now TEMPLATE_MAP-driven; free drag and correct reset position at max level when primary bar is hidden; `secondaryBarPosition` static default removed in favour of dynamic `GetFallbackPosition()`
- **NR-5 complete**: Delve companion decoration validated in-game — companion flavor triggers correctly inside Delve, standard reputation flavor outside, transitions between companion/non-companion factions clean
- **NR-6 complete**: README updated to reflect reputation/companion secondary bar, new config options, fixed `portrait_arc` ghost in slash command help

Validation status:

- Release package builds successfully (`make-release.ps1`)
- Near-term and medium-term quality tracks are complete (MQ-1 through MQ-5)
- Current focus: backlog execution and incremental hardening

## Goals

### Near-Term: ~~Complete~~

### ~~NR-6: Release-facing docs sync~~ ✅ Complete

Objective: ensure public docs match current shipped behavior.

Execution steps:

1. Compare README feature list against actual behavior after NR-3..NR-5.
2. Update wording for any changed behavior or known constraints.
3. Ensure docs avoid implementation-phase language and remain feature-focused.

Expected output:

- README aligned with current behavior and constraints.

Definition of done:

- No mismatch between documented and observed behavior in release-critical paths.

### Near-Term Exit Gate

All items NR-3 through NR-6 complete, with no unresolved release-blocking defects.

### Medium-Term: Code Quality

All medium-term tracks are complete.

- MQ-1: context/session workflow consistency
- MQ-2: options panel architecture proposal
- MQ-3: UI structure and naming cleanup
- MQ-4: analysis-to-backlog normalization
- MQ-5: manager boundary enforcement + doc normalization

Key implementation note:

- Companion detection is now localization-safe by design: `defaults.delveCompanions` is a dict mapping factionID → name, with name-based fallback for compatibility.

### Next Phase: Backlog Execution

**Goal**: Continue with deferred/approved backlog items after closing documentation drift and architecture debt.

**Active backlog — implementation candidates (see `docs/backlog/README.md`)**:

| Item | Goal | Notes |
| ---- | ---- | ----- |
| [secondary-bar-per-style-position](docs/backlog/secondary-bar-per-style-position.md) | Per-style independent saved position for the secondary bar | P2, deferred but actionable after migration design |

**Deferred backlog (P3)**:

- `secondary-bar-styles` — investigation only, not approved for coding
- `companion-multi-companion` — awaiting C_DelvesUI API review

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
