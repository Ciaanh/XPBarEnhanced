# Project Structure Guidelines

## Top-Level Layout

- core: lifecycle, config, event bus, calculations, services
- ui: managers, mixins, style builders, templates, options
- styles: primary XP style implementations
- secondary: secondary bar style implementations
- stats: statistics UI and metrics
- locales: localization strings
- docs: planning, memory, architecture, feature documentation

## File Placement Rules

1. Domain state tracking belongs in core/services.
2. Rendering logic belongs in ui or styles, not in services.
3. Shared behavior belongs in mixins/utilities.
4. Feature plans and operational notes belong in docs/features and docs/plan.
5. External WoW event routing belongs in orchestration modules (core lifecycle/router), not per-render mixins.
6. Manager modules own lifecycle/style/visibility policy only; context building stays in services/context builders.

## Documentation Rules

1. docs/plan.md is the active coding session guide.
2. docs/memory stores decisions, lessons, and external analysis summaries.
3. docs/guidelines stores durable architecture and structure guidance.
4. docs/features stores one file per feature domain.

## Change Discipline

1. Any feature refactor should update its feature doc.
2. Any architectural decision should append docs/memory/decision-log.md.
3. Any new recurring lesson should be added to docs/memory/lessons-learned.md.
4. If a feature requires duplicated lifecycle logic across bars, add or update shared lifecycle utilities first.
5. Backlog ordering should prioritize architecture-enabling work when it reduces repeated implementation cost.
