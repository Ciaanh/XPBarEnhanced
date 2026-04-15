# Feature: Secondary Bar System

The shared infrastructure that manages reputation and companion secondary bars — style switching, lifecycle, shared behaviors, and Blizzard bar visibility.

## Capabilities

- **Single tracked-reputation bar**: One secondary bar renders the watched faction and applies companion-specific decoration when the watched faction is a delve companion
- **Circular inner-arc secondary style**: Circular primary style now maps to an inner reputation arc with a semi-circle default and optional full-circle rendering
- **Minimap icon+arc secondary style**: Minimap ring primary style now maps to a draggable icon that toggles a centered reputation arc
- **Attached/free positioning**: `secondaryBarsAttached` toggle locks the secondary bar relative to the XP bar or allows independent drag placement
- **Shared lifecycle contract**: All secondary bars follow OnLoad → OnShow → OnHide → MarkDirty → Render
- **Drag-to-move**: Shift+drag repositioning with SavedVariables persistence and position lock
- **Fade animations**: Smooth fade-in/out transitions on availability changes via shared mixin
- **Hover tooltips**: Session metrics tooltip with safety guards
- **Live text refresh**: Periodic ticker updates using cached context (no full rebuild)
- **Blizzard bar visibility**: Manager controls Blizzard reputation tracking bar independently from XP bar
- **Combat safety**: Movement and setup paths are guarded against combat lockdown
- **Config-driven defaults**: Anchor positions and reset behavior come from configuration

## Architecture

- **Manager pattern**: `SecondaryBarManager` owns style/frame lifecycle and visibility policy only
- **Shared base mixin**: `SecondaryBarBaseMixin` provides lifecycle, fade, tooltip, ticker, drag behaviors
- **Domain hooks**: Style mixins provide `GetBroadcastEventName`, `GetInitialContext`, `Render` only
- **Context sourcing**: Prefers emitted/cached context; bootstrap fallback for first-show only
- **MarkDirty coalescing**: EventBus updates run through dirty-mark coalescing instead of direct render
- **Session ownership**: Bootstrap emits come from session layers, not manager orchestration

## Key Components

- `ui/SecondaryBarManager.lua` — Style activation, frame lifecycle, Blizzard visibility
- `ui/mixins/SecondaryBarBaseMixin.lua` — Shared lifecycle, fade, tooltip, ticker, drag
- `ui/styles/flat/FlatSecondaryBarStyle.lua` — Flat secondary bar rendering
- `ui/styles/circular/CircularSecondaryBarStyle.lua` — Circular inner-arc secondary rendering
- `ui/styles/minimap_ring/MinimapArcSecondaryBarStyle.lua` — Minimap icon + arc toggle secondary rendering

## Design Decisions

- Manager does not build domain context — defers to session/context builder layers
- Blizzard reputation visibility is separate from Blizzard XP visibility
- Bootstrap emit ownership moved from manager to session layers (Phase 7 Slice 2)
- Drag semantics hardened: position persistence managed by SavePosition, not drag-stop (Slice 1)
- Companion and reputation rendering share one secondary frame and one style lifecycle
- `TEMPLATE_MAP` now includes `circular` and `minimap_ring` entries, preserving the 1:1 primary→secondary model
- Minimap arc style opts out of attached positioning intentionally (`ShouldAttachToPrimary() == false`), while circular style remains attachable to the primary center

## User-Facing Options

- `circularSecondaryFullCircle`: Circular inner secondary arc uses 360-degree full ring when enabled; defaults to semi-circle when disabled
- `minimapArcStartExpanded`: Minimap icon style starts with the arc shown when enabled
- `minimapArcIconScale`: Scales the minimap secondary icon size for readability and placement preference

## Backlog

- **Per-style Secondary Bar Position** (deferred, not approved for coding) — see `docs/backlog/secondary-bar-per-style-position.md`
