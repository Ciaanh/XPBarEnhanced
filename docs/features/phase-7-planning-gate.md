# Feature: Phase 7 Planning Gate (No Implementation)

Status: Deferred pending approval
Last updated: 2026-04-06

## Purpose

Define what must be completed before any Phase 7 implementation can begin.

## Closed / Not Planned Items

The following items are intentionally out of scope for the current product direction:

1. `docs/backlog/faction-selection-dropdown.md`
2. `docs/backlog/bar-size-scale-options.md`
3. `docs/backlog/font-customization-per-bar.md`
4. `docs/backlog/localization-multi-language.md`

These items are documented for historical reference only and are not approved for implementation.

## Investigation-Only Item

`docs/backlog/secondary-bar-styles.md` remains investigation-only.

Approval prerequisites:

1. Architecture compatibility review with shared lifecycle contracts.
2. UX review for compact secondary-bar readability and style parity goals.
3. Incremental delivery plan with effort/risk estimate.

## Pre-Phase-7 Analysis Tracks

1. Session/context workflow consistency between XP and secondary domains.
2. Options panel structure review against Blizzard UI patterns.
3. UI folder structure and naming clarity improvements.

Current consolidated output:

- `docs/analysis/pre-phase-7-architecture-compliance-deliverable.md` (architecture consistency + Blizzard compliance hardening checklist)

Selected first implementation slice:

- `docs/features/phase-7-slice-1-compliance-hardening.md` (approval-ready)

## Entry Criteria For Any Phase 7 Coding

All items below must be complete:

1. Backlog and plan documents are aligned with current scope decisions.
2. Analysis outputs are captured in docs with a recommended implementation sequence.
3. Risks and validation matrix are updated for the approved slice.
4. Explicit approval is recorded in this feature file and summarized in `docs/memory/decision-log.md`.

## Exit Criteria For This Gate

1. One implementation slice is approved with clear scope and acceptance criteria.
2. Non-approved items remain excluded from active roadmap execution.

## Immediate Approval Checklist (Slice 1)

1. Confirm Slice 1 scope remains limited to compliance hardening only.
2. Confirm no closed/not-planned features are reintroduced.
3. Confirm validation matrix for drag, tooltip, fade, ticker, and combat safety is accepted.
4. Record explicit approval in this file and append the decision to `docs/memory/decision-log.md` before starting code edits.

## Approval Record

Current state: Approved for Slice 1 implementation (2026-04-06).

When approved, capture:

1. Approved slice ID and scope lock.
2. Approval date.
3. Decision-log reference entry.

Recorded approval:

1. Approved slice: `docs/features/phase-7-slice-1-compliance-hardening.md`
2. Approval date: 2026-04-06
3. Decision log: `docs/memory/decision-log.md` (2026-04-06 entries)

Current progress:

1. Slice 1 implementation completed.
2. In-game validation reported no errors.
3. Slice 2 implementation started.
4. Slice 2 current batch validated in-game with no errors.

Selected next implementation slice:

- `docs/features/phase-7-slice-2-context-contract.md`
