# Feature: Companion Bar

Owner scope: Delve companion progression bar.
Priority: P0

## Purpose

Track and display companion progression in a stable secondary bar with reliable availability handling.

## Current Components

- core/services/CompanionSession.lua
- core/services/ContextBuilder.lua (BuildCompanionContext)
- ui/secondary/FlatCompanionBarStyle.lua
- ui/SecondaryBarManager.lua

## Current Gaps

1. Optional fade/coalescing polish remains future work if required.

## Planned Work

1. Keep rendering from emitted companion context.
2. Preserve config/default-driven anchors and reset behavior.
3. Add MarkDirty/fade behavior only if additional polish is required.

## Acceptance Criteria

1. Companion updates stay accurate and stable on event changes.
2. Unavailable states hide gracefully without flicker.
3. No redundant context build in listener render path.

## Implemented Status (2026-04-04)

1. Listener now consumes emitted context directly.
2. Companion context is emitted in the same flat UI-ready shape used by the style renderer.
3. Anchor defaults are config-driven and reset-anchor support is wired through options.
