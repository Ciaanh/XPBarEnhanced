# Feature: Reputation Bar

Owner scope: watched-faction secondary progress bar.
Priority: P0

## Purpose

Display watched reputation progression with clear standing and progress state.

## Current Components

- core/services/ReputationSession.lua
- core/services/ContextBuilder.lua (BuildReputationContext)
- ui/secondary/FlatReputationBarStyle.lua
- ui/SecondaryBarManager.lua

## Current Gaps

1. Fade polish is still optional future work if needed.

## Planned Work

1. Keep rendering from emitted context payload.
2. Preserve config/default-driven bar position and reset-anchor behavior.
3. Preserve watched-faction transition correctness (clear/switch should emit immediate update).

## Acceptance Criteria

1. Updates are accurate on faction gain/standing changes.
2. No duplicate context-build path in listener.
3. Visibility transitions are smooth and stable.

## Implemented Status (2026-04-04)

1. Listener consumes emitted context directly.
2. Anchoring is config/default-driven.
3. Clearing tracked reputation and switching tracked faction emits immediate updates, keeping hide/show behavior correct.
4. Blizzard reputation bar visibility is controlled by reputation style, not XP style.
