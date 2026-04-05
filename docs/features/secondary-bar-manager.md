# Feature: Secondary Bar Manager

Owner scope: style activation, frame lifecycle, and visibility management for secondary bars.
Priority: P0

## Purpose

Manage reputation and companion bars independently while keeping style switching and lifecycle behavior predictable.

## Current Components

- ui/SecondaryBarManager.lua
- ui/mixins/SecondaryBarBaseMixin.lua
- ui/secondary/FlatReputationBarStyle.lua
- ui/secondary/FlatCompanionBarStyle.lua

## Current Gaps

1. Secondary bars still rely on a simpler lifecycle contract than primary bars.
2. Manager bootstrap currently triggers domain update emits and should be reduced to lifecycle/visibility ownership only.

## Planned Work

1. Keep manager focused on style/frame lifecycle, not render logic duplication.
2. Keep Blizzard reputation-bar visibility ownership in SecondaryBarManager.
3. Shift bootstrap emissions into domain/session orchestration so manager does not call private session context builders.
4. Adopt shared bar lifecycle contract before adding more secondary-bar polish features.

## Phase 2 Kickoff (2026-04-05)

1. Manager bootstrap emits were decoupled from private session context builders.
2. `SecondaryBarManager:OnEnteringWorld()` now uses `XPBarContextBuilder` entry points instead of `ReputationSession:_BuildContext()` / `CompanionSession:_BuildContext()`.
3. Full router migration is still pending; manager still owns initial broadcast trigger for visible secondary bars.

## Phase 2 Progress (2026-04-05)

1. Manager entering-world bootstrap emit ownership has been removed.
2. Reputation/companion entering-world emits now come from session layers, not manager orchestration.
3. AddOnLifecycle now reapplies secondary Blizzard visibility policy on the deferred entering-world pass.

## Session Milestone Mapping

1. ST-4 Secondary listeners render from emitted context only.
2. ST-5 Secondary anchors default from config and persist across login/reload.
3. ST-6 Options panel reset-anchor placement validated.

## Acceptance Criteria

1. Style changes are reliable and side-effect clean.
2. Manager does not reintroduce duplicate render paths.
3. Reputation and companion bars remain independently controllable.

## Implemented Status (2026-04-04)

1. Debug scaffolding removed from manager and style implementations.
2. Entering-world path emits session-built context via EventBus for secondary bars.
3. Secondary defaults and reset-anchor behavior are config-driven.
4. Blizzard reputation visibility is now independent from XP style selection.

## Implemented Status (2026-04-05)

1. Secondary lifecycle contract is now shared via `XPBarSecondaryBaseMixin`.
2. Secondary style mixins now provide domain hooks only (`GetBroadcastEventName`, `GetInitialContext`, `Render`).
3. EventBus updates for secondary bars now run through `MarkDirty` coalescing instead of direct render calls.
