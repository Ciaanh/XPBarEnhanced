# Feature: Companion Bar

A secondary progress bar that tracks Delve companion (Brann) progression.

## Capabilities

- **Companion XP tracking**: Displays current companion level and XP progress
- **Availability detection**: Shows only when companion data is available (active Delve session)
- **Graceful hiding**: Unavailable states hide without flicker
- **Independent visibility**: Controlled by `companionBarStyle` setting, separate from primary XP bar
- **Drag-to-move**: Repositionable with Shift+drag; position persists across sessions
- **Fade transitions**: Smooth fade-in/out on availability changes
- **Hover tooltip**: Shows companion session metrics on mouseover
- **Live text refresh**: Periodic text updates without full context rebuild

## Architecture

- **Data pipeline**: `CompanionSession` → `ContextBuilder` (BuildCompanionContext) → `EventBus` → bar style
- **Session layer**: `CompanionSession` tracks companion state and session gains
- **Visibility ownership**: `SecondaryBarManager` controls custom companion bar visibility
- **Render model**: Bar renders from emitted context payloads; flat UI-ready shape

## Key Components

- `core/services/CompanionSession.lua` — Companion state and session tracking
- `core/services/ContextBuilder.lua` (BuildCompanionContext) — Immutable context builder
- `ui/secondary/FlatCompanionBarStyle.lua` — Visual rendering
- `ui/SecondaryBarManager.lua` — Style activation and visibility

## Known Limitations

- Only one visual style currently available (flat)
- Only supports single companion (Brann); multi-companion is deferred
- Requires active Delve context for data availability
