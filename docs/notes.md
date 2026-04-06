# Notes (Promoted to Analysis Tracks)

Last updated: 2026-04-06

## Track 1: Session/Context Workflow Consistency

Observation:
- XP and secondary domains do not follow the same context/session ownership pattern.
- Secondary flows still rely on `_session`-centric service internals while XP flow is more database-backed and globally consumed.

Planned analysis outcome:
- Define one explicit context production/consumption contract across XP, reputation, and companion pipelines.
- Identify duplicated context-building paths and propose a staged simplification plan.

## Track 2: Options Panel Structure and Blizzard UX Alignment

Observation:
- Current options organization is functional but becoming crowded with secondary-bar controls.

Planned analysis outcome:
- Evaluate tabbed layout vs grouped sections against Blizzard settings patterns.
- Recommend information hierarchy and progressive disclosure rules for future options growth.

## Track 3: UI Folder Structure and Naming Clarity

Observation:
- The `ui/` folder naming and boundaries no longer cleanly reflect architecture and module roles.

Planned analysis outcome:
- Propose a migration-safe folder structure and naming strategy.
- Define file-move constraints to avoid TOC/load-order regressions.