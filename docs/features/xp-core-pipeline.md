# Feature: XP Core Pipeline

Owner scope: primary XP bar data and rendering pipeline.
Priority: P0

## Purpose

Provide stable, accurate XP state updates to XP bar rendering with predictable timing and minimal redundant work.

## Current Components

- core/services/Session.lua
- core/services/ContextBuilder.lua
- core/EventBus.lua
- ui/mixins/BaseMixin.lua
- ui/BarManager.lua

## Current Gaps

1. External WoW event ownership remains distributed across multiple service frames, increasing trace complexity.
2. Level-up dependents still use targeted cross-service calls in Session and can be router-dispatch candidates.

## Planned Work

1. Preserve explicit context payloads for all XP and config-driven emit paths.
2. Keep EventBus dispatcher-only behavior.
3. Migrate to staged central event-router ownership while preserving current payload contracts.
4. Evaluate further subscriber-model migration for level-up dependents after router stage 1 lands.

## Session Milestone Mapping

1. ST-1 Event emits normalized (XP + config explicit payloads).
2. ST-2 Listener nil-context assumptions removed.
3. ST-3 EventBus fallback retired (dispatcher-only behavior).

## Acceptance Criteria

1. XP bar updates continue to work across login, reload, and level-up.
2. EventBus operates as dispatcher only.
3. No regressions in session XP, rested, or quest overlay updates.

## Implemented Status (2026-04-04)

1. XP emit sites and related config/options emit paths provide explicit context payloads.
2. EventBus no longer infers/builds XP context.
3. Listener contracts now assume explicit payloads only.
