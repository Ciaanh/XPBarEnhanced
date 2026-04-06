# Open Investigation Tracks

Items that need analysis before they can become backlog items. Partially addressed by Phase 7 work but not fully resolved.

## Track 1: Context/Session Workflow Consistency

**Goal**: Define one explicit context production/consumption contract across XP, reputation, and companion pipelines.

**Current state**: Phase 7 Slice 2 normalized secondary context sourcing (prefer emitted/cached, bootstrap fallback). But XP and secondary domains still differ — secondary uses session-centric internals while XP is more database-backed.

**Next step**: Compare the three pipelines side-by-side, identify remaining duplication, and propose a staged simplification plan.

## Track 2: Options Panel Structure

**Goal**: Evaluate whether the options panel needs restructuring as settings grow.

**Current state**: Functional but increasingly crowded with secondary-bar controls added in Phase 6.

**Next step**: Review tabbed layout vs grouped sections against Blizzard settings patterns. Recommend information hierarchy and progressive disclosure rules.

## Track 3: UI Folder Naming and Structure

**Goal**: Improve folder boundaries to reflect current architecture and module roles.

**Current state**: The `ui/` folder naming no longer cleanly maps to the architecture after Phase 5-7 changes.

**Next step**: Propose a migration-safe folder structure. Define file-move constraints to avoid TOC/load-order regressions.
