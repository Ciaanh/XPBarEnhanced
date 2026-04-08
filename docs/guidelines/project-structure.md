# Project Structure Guidelines

## Top-Level Layout

- core: lifecycle, config, event bus, calculations, services
- ui: managers, mixins, style builders, templates, options
  - styles: primary and secondary XP/reputation style implementations, grouped by style name
  - mixins: shared behavior mixins (primary + secondary)
  - templates: shared XML base templates for primary bar frames
  - stats: session statistics UI
  - options: options panel Lua and XML
- locales: localization strings
- docs: planning, memory, architecture, feature documentation

### ui/ File Catalog

| File | Role |
| ---- | ---- |
| `ui/BarManager.lua` | Manager: primary bar lifecycle, style switching, MarkDirty dispatch |
| `ui/SecondaryBarManager.lua` | Manager: secondary bar lifecycle, show/hide, subscribe/unsubscribe |
| `ui/MinimapButton.lua` | Minimap button: icon anchor, drag, right-click menu |
| `ui/StyleBuilder.lua` | Factory: creates primary bar style instance from config |
| `ui/mixins/BaseMixin.lua` | Mixin: base state/render lifecycle for all primary bar frames |
| `ui/mixins/SecondaryBarBaseMixin.lua` | Mixin: shared contract for secondary bars (context cache, ticker, fade, drag) |
| `ui/mixins/LayoutMixin.lua` | Mixin: frame sizing and anchoring |
| `ui/mixins/PaintMixin.lua` | Mixin: bar texture painting |
| `ui/mixins/DisplayMixin.lua` | Mixin: bar fill and alpha rendering |
| `ui/mixins/TextMixin.lua` | Mixin: text row rendering and font management |
| `ui/mixins/InteractionMixin.lua` | Mixin: drag, click, and hover input handling |
| `ui/mixins/TooltipMixin.lua` | Mixin: tooltip show/hide on hover |
| `ui/mixins/PositionMixin.lua` | Mixin: SavedPosition persistence and drag-stop handling |
| `ui/mixins/animation/AnimationUtils.lua` | Utility: common animation helper functions |
| `ui/mixins/animation/AnimationManager.lua` | Manager: level-up flash animation state machine |
| `ui/mixins/animation/AnimationBase.lua` | Mixin: shared animation building blocks |
| `ui/templates/XPBarBaseTemplate.xml` | XML: shared base template for primary bar frame sizing and scripts |
| `ui/stats/StatsFrame.xml` | XML: session statistics frame definition (loads Stats.lua via Script tag) |
| `ui/stats/Stats.lua` | Stats module: session statistics display logic |
| `ui/options/OptionsPanelTemplates.xml` | XML: reusable option widget templates |
| `ui/options/OptionMetadata.lua` | Options metadata: all option definitions, order, display names |
| `ui/options/ControlHelpers.lua` | Helpers: widget constructors for options panel |
| `ui/options/OptionsPanel.xml` | XML: options panel frame definition (loads Options.lua via Script tag) |
| `ui/options/Options.lua` | Options panel: Blizzard Settings registration and layout logic |
| `ui/styles/flat/FlatBarTemplate.xml` | XML: flat bar frame (loads FlatBarStyle.lua via Script tag) |
| `ui/styles/flat/FlatBarStyle.lua` | Primary style: flat horizontal XP bar rendering |
| `ui/styles/flat/FlatSecondaryBarTemplate.xml` | XML: flat secondary bar frame (loads FlatSecondaryBarStyle.lua via Script tag) |
| `ui/styles/flat/FlatSecondaryBarStyle.lua` | Secondary style: flat reputation/companion bar |
| `ui/styles/classic/ClassicBarTemplate.xml` | XML: classic bar frame (loads ClassicBarStyle.lua) |
| `ui/styles/classic/ClassicBarStyle.lua` | Primary style: classic horizontal XP bar |
| `ui/styles/vertical/VerticalBarTemplate.xml` | XML: vertical bar frame (loads VerticalBarStyle.lua) |
| `ui/styles/vertical/VerticalBarStyle.lua` | Primary style: vertical XP bar |
| `ui/styles/circular/CircularBarTemplate.xml` | XML: circular bar frame (loads CircularBarStyle.lua) |
| `ui/styles/circular/CircularBarStyle.lua` | Primary style: circular XP bar |
| `ui/styles/minimap_ring/MinimapRingBarTemplate.xml` | XML: minimap ring frame (loads MinimapRingBarStyle.lua) |
| `ui/styles/minimap_ring/MinimapRingBarStyle.lua` | Primary style: ring around minimap |
| `ui/styles/minimap_ring/MinimapButtonCollection.lua` | Helper: wraps minimap ring for Blizzard button collection API |
| `ui/styles/terminal/TerminalBarTemplate.xml` | XML: terminal bar frame (loads TerminalBarStyle.lua) |
| `ui/styles/terminal/TerminalBarStyle.lua` | Primary style: terminal (text-only) XP bar |

### Secondary Style Placement Rule

Secondary bar style files colocate with their primary visual counterpart under `ui/styles/<style>/`. There is no separate `ui/secondary/<style>/` folder. The shared secondary contract (`SecondaryBarBaseMixin`) lives in `ui/mixins/` because it is architecture-level shared infrastructure, not style-specific logic.

## File Placement Rules

1. Domain state tracking belongs in core/services.
2. Rendering logic belongs in ui or styles, not in services.
3. Shared behavior belongs in mixins/utilities.
4. Feature plans and operational notes belong in docs/features and docs/plan.
5. External WoW event routing belongs in orchestration modules (core lifecycle/router), not per-render mixins.
6. Manager modules own lifecycle/style/visibility policy only; context building stays in services/context builders.

## Documentation Rules

1. docs/plan.md is the project roadmap with goals, priorities, and next steps.
2. docs/features stores one file per addon feature describing what it does.
3. docs/backlog stores actionable future work items with goals and acceptance criteria.
4. docs/history stores archived implementation records (completed phases).
5. docs/memory stores decisions, lessons, and external analysis summaries.
6. docs/analysis stores deep technical investigations.
7. docs/guidelines stores durable architecture and structure guidance.
8. docs/notes stores open investigation tracks not yet resolved.

## Change Discipline

1. Any feature change should update the relevant feature doc in docs/features/.
2. Any architectural decision should append docs/memory/decision-log.md.
3. Any new recurring lesson should be added to docs/memory/lessons-learned.md.
4. Completed work should be recorded in docs/history/ and removed from active backlog.
5. Backlog items should have clear goals, not just task descriptions.
