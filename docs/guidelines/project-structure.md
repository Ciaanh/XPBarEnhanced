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
