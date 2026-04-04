# External Project Analysis Memory

Purpose: capture reusable findings from external references and comparative analysis.

## Blizzard UI Reference Access

Reference root:
- i:/Dev/WoW/_Workspace/Blizzard_UI_refs/BlizzardInterfaceCode/Interface/AddOns

Use cases:
1. Verify Blizzard event/lifecycle usage patterns.
2. Compare show/hide and fade behavior for status bars.
3. Check safe API migration patterns for current patch.

## Relevant Findings

1. Multi-step lifecycle handling in Blizzard code reinforces deferred visibility adjustments after entering world.
2. Event-heavy systems typically separate data update from view refresh timing.
3. Transition polish (fade/show) should avoid direct alpha jumps when frame state changes frequently.

## Practical Follow-up

1. Continue matching status bar visibility timing to Blizzard-style deferred updates.
2. Keep fade behavior in a shared utility to prevent drift across bar types.
3. Validate every external-pattern adoption against WoW 12.0.0 constraints before implementation.
