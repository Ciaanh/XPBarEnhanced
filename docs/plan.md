# XPBarEnhanced — Project Plan

Last updated: 2026-04-07 (session 2)

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

Completed this session (near-term stabilization):

- **NR-1**: Dead Slice 3 exploration code removed (BarManager, defaults)
- **NR-2**: MaxLevel debug logs removed (BarManager, BaseMixin, defaults)
- **Bug fix**: `SavePosition` frame-reference serialization bug corrected
- **Default position**: Secondary bar default anchor corrected to `UIParent` bottom offset; attached mode now re-anchors relative to the active XP bar
- **NR-3 (partial)**: Checkbox UX implemented but testing revealed companion identity bugs and drag-lock incompleteness
- **Key finding**: Companion and reputation are the same API data source — NR-3 rewritten as unified secondary bar model (see decision log session 3)

## Goals

### Near-Term: Stabilize for Release

**Goal**: Get the addon to a clean, release-ready state.

### NR-3: Unified secondary bar (tracked-reputation model)

Objective: replace the separate reputation and companion bar pipelines with a single tracked-reputation secondary bar that applies companion-specific decoration when the tracked faction is a delve companion.

Background: in-game investigation confirmed that companion XP uses the same friendship-reputation API as all other friendship factions. The two-bar split duplicated data pipelines and caused identity-resolution bugs (fallback selecting wrong companion). A single bar driven by watched-faction state eliminates duplication and simplifies the user model.

Execution steps:

1. **Config schema**: replace all previous secondary bar keys (`reputationBarStyle`, `companionBarStyle`, `showReputationBar`, `showCompanionBar`) with `showSecondaryBar` (bool, default false) and `secondaryBarsAttached` (bool, default true). No migration needed — secondary bars have never been released.
2. **Reputation pipeline gains companion awareness**:
   - `ReputationSession` checks whether the watched faction is a known delve companion (friendship faction + known-names list or future `C_DelvesUI` API).
   - Context includes `isCompanion` flag and companion-specific fields (level, delve-gating state).
   - When `isCompanion == true` and player is not in a delve, the bar applies companion visibility gate (hide unless settings open or bar unlocked).
3. **Remove companion-only pipeline**: delete or fold `CompanionSession`, `CompanionCalculations`, `FlatCompanionBarStyle`, `FlatCompanionBarTemplate.xml`, and companion-specific context builder paths into the reputation side.
4. **Style derivation**: `SecondaryBarManager._DeriveSecondaryStyle()` returns `"flat"` when `showSecondaryBar` is true and primary `barStyle ~= "none"`, else `"none"`. Only one secondary frame to manage.
5. **Attached mode**: when `secondaryBarsAttached = true`, the single secondary bar anchors relative to the XP bar; position stacking simplified (one bar instead of two).
6. **Drag fix**: ensure attached-mode guard blocks drag registration and prevents any save on drag stop (fixes NR-3 defect).
7. **Options UI**: two checkboxes in Secondary section — `showSecondaryBar` and `secondaryBarsAttached`; update reset button anchor.
8. **Locale**: update keys to reflect single-bar model (e.g., `OPT_SHOW_SECONDARY_BAR`, `OPT_SECONDARY_BAR_ATTACHED`).
9. **Dead code**: remove `repstyle`/`reputationstyle`/`companionstyle` commands, old companion config keys.

Expected output:

- One secondary bar tracks the player's watched faction — standard, friendship, major/renown, or paragon.
- When the watched faction is a known delve companion and the player is inside a delve, the bar shows companion-flavored display (level, companion text format).
- When the watched faction is a companion but the player is outside a delve, the bar hides (unless settings/unlock mode active).
- Options panel shows two checkboxes: enable secondary bar + attached mode.
- Attached mode fully prevents drag and position save.

Definition of done:

- No separate companion service/session/style/context paths remain.
- Watched-faction tracking works for all four reputation types plus companion decoration.
- Companion visibility gating (delve check, max-level hide) functions correctly.
- Existing user configs migrate cleanly on first load.
- No `companionBarStyle`, `showCompanionBar`, or `reputationBarStyle` keys remain in defaults, options, or runtime.

### NR-4: Full regression pass (core gameplay matrix)

Objective: verify no behavior regressions across primary and secondary systems.

Execution steps:

1. Primary bar styles:
   - Validate all 7 styles for visibility, XP updates, text, and animations.
2. Secondary bars:
   - Validate reputation and companion enable/disable checkboxes, attached/free modes, drag, fade, tooltip, live text.
3. Lifecycle paths:
   - Validate login, `/reload`, level-up, and max-level transitions.
4. Blizzard bar ownership:
   - Verify Blizzard XP and reputation bars hide/show according to manager ownership rules.
5. Capture pass/fail notes and unresolved defects.

Expected output:

- Regression report with pass/fail status per scenario.

Definition of done:

- All P0/P1 user-facing behaviors pass.
- Any failures are documented with reproducible steps and prioritized.

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
