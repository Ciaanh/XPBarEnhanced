# XPBarEnhanced — Project Plan

Last updated: 2026-04-08 (Medium-Term complete)

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
- NR-4 through NR-6 complete; near-term exit gate reached
- Next focus: Medium-Term code quality tracks (MQ-1 through MQ-4)

## Goals

### Near-Term: \~\~Complete\~\~ — all NR items done, advancing to Medium-Term

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

**Goal**: Reduce technical debt and improve maintainability across four tracks. Tracks are ordered by dependency and risk — MQ-4 and MQ-3 first (bounded, low-risk), then MQ-2 (design proposal), then MQ-1 (heaviest, refactoring).

---

### ~~MQ-4: Analysis-to-backlog normalization~~ ✅ COMPLETE (2026-04-08)

**Objective**: ensure all actionable findings from prior investigation are tracked or explicitly closed.

**Outcome**:
- All 6 analysis docs in `docs/analysis/` read, audited, and annotated with MQ-4 status headers
- `EventRouter.lua` confirmed as single centralized event frame (architecture-analysis §3.3 resolved)
- `SecondaryBarBaseMixin` confirmed implemented (§3.5/3.6, Phases 2+3 resolved)
- Session persistence + time refresh ticker already implemented (xp-tracking items 1+2 resolved)
- `delve-companion-feature.md` and `reputation-bar-feature.md` marked superseded by NR-3
- `reference-addon-comparison.md` feature matrix updated (reputation/companion now Yes)
- `pre-phase-7-architecture-compliance-deliverable.md` compliance items audited — most resolved in NR-3/NR-4/session 6
- New backlog: `docs/backlog/xp-tracking-quick-wins.md` (3 trivial items: isTask filter, expansion events, XP/hr threshold)
- Open items carried forward: architecture §3.1/3.4 → MQ-1; 12.0 compliance docs checkpoint → MQ-1 or doc pass

---

### ~~MQ-3: UI structure and naming cleanup~~ ✅ COMPLETE (2026-04-08)

**Objective**: make `ui/` folder boundaries reflect current architecture cleanly.

**Outcome**:
- `ui/secondary/` confirmed empty; deleted — no TOC references (secondary style files live in `ui/styles/flat/`)
- All `ui/` files catalogued with role descriptions in `docs/guidelines/project-structure.md`
- Secondary style placement rule documented: secondary styles colocate with their primary style in `ui/styles/<style>/`; `SecondaryBarBaseMixin` correctly in `ui/mixins/` as shared infrastructure
- `ui/templates/XPBarBaseTemplate.xml` confirmed as shared primary-bar base template (correctly loaded before styles in TOC)
- `ui/stats/` (StatsFrame.xml + Stats.lua via Script tag) and `ui/options/` (OptionsPanel.xml + Options.lua via Script tag) confirmed correct; no orphaned files
- No file moves or TOC reordering required — structure already matches the documented rule

---

### ~~MQ-2: Options panel architecture proposal~~ ✅ COMPLETE (2026-04-08)

**Objective**: define a scalable layout for the options panel before more settings are added.

**Outcome**:
- Audited all 36 options in `OptionMetadata.lua`; grouped into 9 logical sections
- Evaluated grouped-scroll vs tabbed panel — **chosen: grouped scroll with conditional style-section visibility**
  - Rationale: 36 options in 8–9 sections is manageable on a single page; panel is custom canvas layout (not Blizzard Settings.CreateSetting); tabs require custom XML tab widget with no clear UX gain at current option count
  - Style-specific sections (Circular, Minimap Ring, Terminal) to be hidden when inactive style is selected
- Decision and section map documented in `docs/features/options-and-config.md`
- Backlog item filed: `docs/backlog/options-panel-sections.md` (P2, ready to implement)

---

### ~~MQ-1: Context/session workflow consistency~~ ✅ COMPLETE (2026-04-08)

**Objective**: resolve the three pipeline inconsistencies identified in `docs/analysis/architecture-analysis.md` (sections 3.1–3.6).

**Outcome (all issues resolved by prior implementation — no code changes required)**:

| # | Problem (from analysis) | Resolution |
|---|---|---|
| 3.1 | Context build location inconsistent | RESOLVED: both XP and Reputation emit full contexts via EventBus; `MarkDirty(ctx)` flows emitted context to `Render(ctx)`. Stylistic asymmetry (global ContextBuilder for XP, internal `_BuildContext` for Reputation) is intentional — documented in guidelines |
| 3.2 | XP emits nil payload | RESOLVED: `Session.lua` calls `XPBarContextBuilder.BuildContext()` at emit time, not nil |
| 3.3 | 5 independent event frames | RESOLVED: EventRouter is single central frame |
| 3.4 | Context rebuilt on every render | RESOLVED: `MarkDirty` coalescing + `_pendingContext`/`_lastContext` caching prevents redundant rebuilds |
| 3.6 | No shared bar contract | RESOLVED: both `BaseMixin` and `SecondaryBarBaseMixin` use identical `MarkDirty` → RunNextFrame → `Render(context)` lifecycle |
| Companion orphan | CompanionSession / CompanionCalculations exist? | DELETED in NR-3 — both files are gone |

**Documents updated**:
- `docs/analysis/architecture-analysis.md` — §3.1/3.2/3.4/3.6 all marked RESOLVED
- `docs/guidelines/code-architecture-choices.md` — CompanionSession reference removed; EventBus contract and XP/Reputation stylistic asymmetry documented

---

### ~~Medium-Term Exit Gate~~ ✅ ALL FOUR MQ TRACKS COMPLETE (2026-04-08)

- ~~MQ-4~~: backlog reflects all actionable analysis outputs ✅
- ~~MQ-3~~: `ui/` structure clean and documented ✅
- ~~MQ-2~~: options panel direction chosen and backlog-filed ✅
- ~~MQ-1~~: secondary pipeline inconsistency confirmed resolved; architecture contract documented ✅


### Next Phase: Backlog Execution

**Goal**: Work through the two P2 ready-to-implement backlog items, then consider P3 items or new feature work.

**Active backlog — ready to implement (see `docs/backlog/README.md`)**:

| Item | Goal | Notes |
|------|------|-------|
| [xp-tracking-quick-wins](docs/backlog/xp-tracking-quick-wins.md) | isTask filter, expansion events, XP/hr threshold | 3 trivial one-line changes across 3 files |
| [options-panel-sections](docs/backlog/options-panel-sections.md) | Group 36-option flat list into labelled sections | Requires new SectionDivider template + metadata restructure |

**Recommended order**:
1. `xp-tracking-quick-wins` first — trivial, low-risk, delivers real correctness improvements
2. `options-panel-sections` second — moderate scope, no runtime risk

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
