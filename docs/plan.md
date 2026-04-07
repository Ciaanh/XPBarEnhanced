# XPBarEnhanced — Project Plan

Last updated: 2026-04-07 (session 5)

## Addon Summary

Enhanced XP bar addon for WoW Retail with 7 visual styles, quest XP overlay, session statistics, reputation tracking, companion tracking, and full color customization.

## Current State

The addon is feature-complete for its core scope:

- **Primary XP bar**: 7 styles, animations, quest overlay, session tracking, max-level auto-hide
- **Unified secondary bar**: Watched-faction tracking with companion-aware display, fade, drag, tooltip, live text
- **Architecture**: Centralized event router, context-first render model, shared secondary lifecycle
- **Quality**: Compliance hardened (combat safety, fade lifecycle, context contracts)

All Phase 5 (foundations), Phase 6 (secondary polish), and Phase 7 (hardening) work is complete and validated. See `docs/history/phases.md` for implementation records.

Completed (sessions 4–5):

- **NR-1**: Dead Slice 3 exploration code removed
- **NR-2**: MaxLevel debug logs removed
- **Bug fix**: `SavePosition` frame-reference serialization bug corrected
- **Default position**: Secondary bar default anchor corrected; attached mode re-anchors to active XP bar
- **NR-3 complete**: companion/reputation pipelines unified into one tracked-reputation secondary bar
- **UI regrouping**: flat secondary style/template moved under `ui/styles/flat/`
- **Interaction**: click on secondary bar opens Character Reputation panel
- **New option**: `hideCompanionOutsideDelve` hides companion bar when outside Delves
- **NR-4 complete**: full regression pass — 3 bugs found and fixed (debug default shipped on, dead `__isDragging` flag, fade-in symmetry); `debugSecondaryBars` infrastructure removed entirely; all 7 primary styles, secondary bar, lifecycle paths, and Blizzard bar ownership validated in-game

Validation status:

- Release package builds successfully (`make-release.ps1`)
- NR-4 regression pass complete with no outstanding defects
- Next gate: NR-5 companion decoration validation (requires in-Delve gameplay)

## Goals

### Near-Term: NR-5 — Delve companion decoration validation

### NR-5: Delve companion decoration validation

Objective: validate companion-flavored behavior of the unified secondary bar under real Delve gameplay data.

Execution steps:

1. Set watched faction to a delve companion (Brann). Confirm bar displays companion flavor outside delve only when settings/unlock mode is open.
2. Enter an active Delve session. Confirm bar transitions to visible with companion text format.
3. Validate XP progression updates and text/tooltip correctness during Delve progress.
4. Exit Delve and confirm bar hides (companion gate) or reverts to standard rep display.
5. Switch watched faction to a non-companion. Confirm bar shows standard reputation behavior everywhere.

Expected output:

- Validation notes confirming companion decoration triggers correctly based on watched faction + delve context.

Definition of done:

- Unified bar shows companion flavor inside delve when tracking a companion faction.
- Unified bar shows standard reputation flavor when tracking any other faction.
- Transitions between companion/non-companion tracked factions are clean.

### NR-6: Release-facing docs sync

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

**Goal**: Reduce technical debt and improve maintainability.

### MQ-1: Track 1 implementation plan (workflow consistency)

Objective: harmonize XP/reputation/companion context-session contracts.

Execution steps:

1. Map current XP vs secondary context production/consumption paths side-by-side.
2. Identify remaining duplicated or asymmetric patterns.
3. Define a staged migration sequence with low blast radius.
4. Convert plan into backlog item(s) with clear acceptance criteria.

Expected output:

- Approved technical plan for Track 1 with implementation slices.

Definition of done:

- Track 1 has an actionable backlog item and sequencing rationale.

### MQ-2: Track 2 options panel architecture proposal

Objective: improve settings scalability and discoverability.

Execution steps:

1. Inventory current options and groupings by user intent.
2. Propose at least two layout approaches (grouped sections vs tabbed/hybrid).
3. Evaluate against Blizzard UX patterns and addon complexity.
4. Select preferred direction and document migration constraints.

Expected output:

- Options panel restructuring proposal with chosen direction.

Definition of done:

- Preferred structure is documented and ready to be scoped into backlog work.

### MQ-3: Track 3 UI structure and naming cleanup plan

Objective: make `ui/` boundaries align with current architecture.

Execution steps:

1. Catalog current UI files by responsibility (manager/mixin/style/options/templates).
2. Propose target folder taxonomy and naming conventions.
3. Define migration safety rules for TOC ordering and load dependencies.
4. Break migration into incremental, low-risk file move batches.

Expected output:

- Migration-safe refactor plan for UI structure/naming clarity.

Definition of done:

- Refactor plan is actionable with explicit safety checks and batch order.

### MQ-4: Analysis-to-backlog normalization

Objective: ensure research outputs become trackable work.

Execution steps:

1. Audit `docs/analysis/*.md` for actionable but untracked recommendations.
2. Create/update backlog items for qualified work.
3. Mark non-actionable findings as reference-only in analysis docs.

Expected output:

- Backlog fully reflects actionable analysis outputs.

Definition of done:

- No high-value actionable recommendation remains untracked.

### Medium-Term Exit Gate

All tracks in `docs/notes.md` have an approved execution plan and corresponding backlog representation.

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
