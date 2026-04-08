# Code Architecture Choices

## Current Architectural Choices

1. Separate managers

- BarManager handles XP bar lifecycle and style concerns.
- SecondaryBarManager handles reputation and companion bars.
- Blizzard tracking visibility ownership follows the same split.
- BarManager controls Blizzard XP visibility.
- SecondaryBarManager controls Blizzard reputation visibility.

1. Per-domain sessions

- Session and ReputationSession are domain-specific.
- CompanionSession was merged into ReputationSession in NR-3 (2026-04-07). Companion tracking is a specialization of reputation tracking, not a separate domain.

1. Event-driven updates

- Domain changes emit internal events.
- UI consumers render from event context.

1. Context-first render model

- Emitters own context creation.
- EventBus dispatches and does not infer domain-specific context.
- EventBus contract: every Emit() call MUST pass a fully-built context. nil is never a valid context payload (EventBus.Emit errors if context is nil).
- Stylistic asymmetry: XP uses the global XPBarContextBuilder.BuildContext() before emitting; Reputation uses ReputationSession:_BuildContext() (internal method). Both result in a full context being emitted. XP context aggregates from many external sources (ContextBuilder is the multi-source combiner); Reputation context is session-owned.

1. Deferred rendering where needed

- Use MarkDirty-style coalescing for burst event domains.

1. Router/service boundary

- EventRouter owns WoW event registration and dispatch only.
- Lifecycle handlers and domain services own side effects (style swaps, visibility reconciliation, EventBus emissions).
- EventRouter must not call EventBus:Emit() directly.

## Blizzard-Aligned Principles (Status/Progress UI)

1. Central orchestration, local rendering

- External WoW event ownership should be centralized by domain orchestration layers.
- Render frames should consume prepared context and avoid external event fan-in logic.

1. Shared lifecycle contracts

- Progress bars should follow a shared lifecycle contract.
- OnLoad for visuals/wiring.
- OnShow for subscription/timer start.
- OnHide for unsubscription/timer cleanup.
- MarkDirty for coalesced redraws.
- Render(context) for paint only.

1. Manager boundaries are strict

- Managers coordinate style/frame lifecycle and visibility policy.
- Managers do not build domain context and should not call private session context builders.

1. Coalescing by default for event-driven UI

- Burst-prone domains should use dirty-mark coalescing to avoid duplicate render paths.
- Optional polish features (fade, tooltip, live text) should plug into the shared lifecycle.

1. Additive migration over rewrite

- Event-router consolidation should be staged (domain-by-domain) with acceptance checks per phase.
- Avoid large all-at-once event ownership migrations.

## Constraints

1. Respect WoW 12.0.0 API changes and restrictions.
1. Keep secure frame concerns in mind for any UI behavior changes.
1. Prefer additive refactoring phases over large all-at-once rewrites.
1. Keep internal pub/sub transport (EventBus) domain-agnostic and explicit-context only.

## Refactor Priorities

1. Enforce shared bar lifecycle contract across primary and secondary bars.
1. Consolidate external WoW event ownership incrementally behind a router layer.
1. Keep manager scope lifecycle-only; remove context-builder coupling from managers.
1. Implement polish (fade/tooltip/drag/live text) on top of shared lifecycle utilities.
1. Improve performance by reducing redundant renders and repeated config/context work.
