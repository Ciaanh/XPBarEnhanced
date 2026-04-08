# XPBarEnhanced — Project Plan

Last updated: 2026-04-08 (session 6)

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

### MQ-4: Analysis-to-backlog normalization

**Objective**: ensure all actionable findings from prior investigation are tracked or explicitly closed.

**Why first**: cheap, bounded, and surfaces issues that inform MQ-1 and MQ-3 scope.

**Execution steps**:

1. Read each of the 6 analysis docs under `docs/analysis/`:
   - `architecture-analysis.md`
   - `delve-companion-feature.md`
   - `pre-phase-7-architecture-compliance-deliverable.md`
   - `reference-addon-comparison.md`
   - `reputation-bar-feature.md`
   - `xp-tracking-improvements-plan.md`
2. For each doc extract every recommendation, warning, or "next step" that has no matching backlog item.
3. For qualified items: create or update a backlog file under `docs/backlog/`.
4. For resolved or obsolete items: annotate the analysis doc with "superseded by …" or "NR-3/NR-4 resolved".
5. Update `docs/backlog/README.md` table to reflect current state.

**Definition of done**: No high-value actionable recommendation in any analysis doc is untracked. Every backlog item has a clear goal, not just a task description.

---

### MQ-3: UI structure and naming cleanup

**Objective**: make `ui/` folder boundaries reflect current architecture cleanly.

**Why second**: concrete, surgical, and prepares a tidy surface before MQ-1 refactoring touches the same files.

**Current issues identified**:
- `ui/secondary/` folder is **empty** (cleaned up during NR-3 unification) — needs removal from TOC
- `FlatSecondaryBarStyle.lua` and its XML template live under `ui/styles/flat/` — assess whether this is the right permanent home or if a `ui/styles/flat/secondary/` sub-folder would be clearer
- `ui/templates/` contents unknown — needs cataloguing
- `ui/stats/` role relative to mixins needs documenting
- `SecondaryBarBaseMixin.lua` lives under `ui/mixins/` but is architecture-level shared infrastructure — confirm placement is intentional

**Execution steps**:

1. Catalog every file under `ui/` with a one-line role description (manager / mixin / style / secondary-style / options / stats / template).
2. Confirm `ui/secondary/` is empty and safe to remove; remove from `XPBarEnhanced.toc` if referenced.
3. Decide: should secondary style files stay in `ui/styles/<style>/` or move to a dedicated `ui/secondary/` per-style folder? Document the chosen rule in `docs/guidelines/project-structure.md`.
4. Audit `ui/templates/` and `ui/stats/` for any orphaned or mislabelled files.
5. Draft a migration batch (file moves + TOC reorder) that can be applied incrementally without breaking load order.
6. Validate each batch step by confirming `make-release.ps1` still succeeds.

**Definition of done**: `ui/` structure matches the documented guidelines, no empty folders, no files in the wrong domain, `docs/guidelines/project-structure.md` updated.

---

### MQ-2: Options panel architecture proposal

**Objective**: define a scalable layout for the options panel before more settings are added.

**Why third**: independent of MQ-1 code changes but should be decided before any context-contract refactoring introduces new config keys.

**Current state**: 36 flat options in a single-page list (`optionOrder` in `OptionMetadata.lua`). Style-specific options (circular, minimap ring, terminal) are mixed into the generic list. Secondary bar options are grouped by proximity only.

**Execution steps**:

1. Group the current 36 options by user intent into sections:
   - **Core** — bar style, bar lock
   - **Secondary Bar** — show/attach/companion gate
   - **XP Display** — text rows, percentages, overlays, abbreviation
   - **Animations** — enable, flash, level-up mode, speed
   - **Style: Circular** — size, segments, texture, center text
   - **Style: Minimap Ring** — padding, segments, button collection, dimensions
   - **Style: Terminal** — custom color toggle
   - **Minimap** — button visibility
2. Evaluate two layout approaches:
   - **Grouped scroll** — single page with section headers above each group (minimal XML change)
   - **Tabbed panel** — top-level tabs per section (larger XML change, cleaner for many settings)
3. Evaluate each approach against: Blizzard UX patterns, number of options per group, current XML template infrastructure.
4. Select preferred direction. Document chosen approach, rationale, and known migration constraints in `docs/features/options-and-config.md`.
5. File a backlog item under `docs/backlog/` for the actual implementation.

**Definition of done**: Preferred layout approach chosen and documented. Backlog item filed with scope, acceptance criteria, and TOC/XML migration notes.

---

### MQ-1: Context/session workflow consistency

**Objective**: resolve the three pipeline inconsistencies identified in `docs/analysis/architecture-analysis.md` (sections 3.1–3.6).

**Why last**: highest blast radius; benefits from knowing MQ-3 file layout and MQ-4 backlog completeness.

**Known problems to address** (from architecture analysis):

| # | Problem | Impact |
|---|---------|--------|
| 3.1 | Context build location inconsistent: XP builds at emit-time; secondary ignores emitted context and rebuilds | Wasted work; unclear contract |
| 3.2 | XP emits nil payload (signal-only); secondary emits built context that consumer discards | Two patterns in one EventBus |
| 3.3 | 5 independent WoW event frame sites; `UPDATE_FACTION`, `QUEST_LOG_UPDATE`, `PLAYER_ENTERING_WORLD` registered more than once | Redundant broadcast risk, hard to trace |
| 3.6 | No shared bar frame contract: XP uses MarkDirty coalescing; secondary uses direct Render | Secondary can't share animation or coalescing logic |

**Execution steps**:

1. **Decide the canonical context contract** — choose one of:
   - *Emitter-builds*: Session builds and emits context; consumer uses it directly. Secondary already does this; XP needs updating.
   - *Signal-only*: Session emits nil; consumer builds lazily. XP already does this; secondary needs updating.
   - Preferred direction: **emitter-builds** — sessions already own the data and already build `_BuildContext()`, so the cost is paid; consumers should use what they receive.
2. **Fix the secondary consumer mismatch** (slice 1 — low risk):
   - `SecondaryBarBaseMixin`'s EventBus handler currently calls `GetInitialContext()` (which calls `BuildReputationContext()`) instead of using the emitted context.
   - Change: pass the emitted context directly to `Render(ctx)`. Keep `GetInitialContext()` as bootstrap-only fallback.
   - Acceptance: no redundant `BuildReputationContext()` calls during normal event flow.
3. **Audit CompanionSession post-NR-3** (slice 2 — scoping):
   - After NR-3 unification, `CompanionSession` may be orphaned (no UI consumer). Verify whether its `UPDATE_FACTION` listener is still wired and whether it can be safely removed or folded into `ReputationSession`.
4. **Plan XP pipeline alignment** (slice 3 — design only, no code):
   - Document what changing the XP pipeline to emitter-builds would require (Session emits a full context; ContextBuilder moves into Session or is called by Session before emit).
   - Assess risk and scope. If too large, accept asymmetry and document it as intentional.
5. **Document chosen contract** — update `docs/guidelines/code-architecture-choices.md` with the resolved contract rule.
6. Convert remaining items into backlog slices if full XP alignment is not done in this track.

**Definition of done**: Secondary consumer mismatch fixed and validated. CompanionSession status resolved. Architecture guidelines updated with the canonical context contract. Remaining XP alignment work (if deferred) filed as a backlog item.

---

### Medium-Term Exit Gate

All four MQ tracks complete:
- MQ-4: backlog reflects all actionable analysis outputs
- MQ-3: `ui/` structure clean and documented
- MQ-2: options panel direction chosen and backlog-filed
- MQ-1: secondary pipeline inconsistency fixed; architecture contract documented


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
