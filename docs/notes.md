# Open Investigation Tracks

Items that need analysis before they can become backlog items. Partially addressed by Phase 7 work but not fully resolved.

## Track 1: Context/Session Workflow Consistency

**Goal**: Define one explicit context production/consumption contract across XP, reputation, and companion pipelines.

**Current state**: The companion/reputation unification (NR-3 rewrite, decision log session 3) will collapse two of the three pipelines into one. After NR-3 lands, this track should re-evaluate whether the remaining XP vs unified-secondary asymmetry still warrants a shared contract or is acceptable as-is.

**Next step**: Defer re-evaluation until after NR-3 unified bar is implemented and validated.

## Track 2: Options Panel Structure

**Goal**: Evaluate whether the options panel needs restructuring as settings grow.

**Current state**: NR-3 unification reduces the secondary controls from three checkboxes to two, easing panel crowding slightly. Functional but still worth evaluating once all near-term work is done.

**Next step**: Review tabbed layout vs grouped sections against Blizzard settings patterns. Recommend information hierarchy and progressive disclosure rules.

## Track 3: UI Folder Naming and Structure

**Goal**: Improve folder boundaries to reflect current architecture and module roles.

**Current state**: The companion-specific files (`FlatCompanionBarStyle.lua`, `FlatCompanionBarTemplate.xml`, `CompanionSession.lua`, `CompanionCalculations.lua`) will be removed or folded as part of NR-3. This simplifies the file count under `ui/secondary/` and `core/`.

**Next step**: After NR-3, re-assess whether remaining structure warrants a rename pass or is clean enough.

