# Docs Index

Canonical source for project planning and technical documentation.

## Start Here

- **Project plan and goals**: [plan.md](plan.md)
- **What to work on next**: [backlog/README.md](backlog/README.md)

## Features (What the Addon Does)

- [XP bar](features/xp-bar.md) — Primary experience bar with 7 styles, animations, session tracking
- [Reputation bar](features/reputation-bar.md) — Watched faction tracking secondary bar
- [Companion bar](features/companion-bar.md) — Delve companion tracking secondary bar
- [Secondary bar system](features/secondary-bar-manager.md) — Shared infrastructure for secondary bars
- [Options and config](features/options-and-config.md) — Settings panel, slash commands, minimap button

## Backlog (Future Work)

- [Backlog index](backlog/README.md) — Prioritized items with goals and readiness status

## History (Completed Work)

- [Implementation phases](history/phases.md) — Consolidated Phase 5–7 implementation records

## Analysis (Research)

- [Architecture analysis](analysis/architecture-analysis.md) — Comprehensive architecture audit
- [Pre-Phase-7 deliverable](analysis/pre-phase-7-architecture-compliance-deliverable.md) — Compliance and consistency analysis
- [Reputation bar analysis](analysis/reputation-bar-feature.md) — Reputation type model and API research
- [Companion feature analysis](analysis/delve-companion-feature.md) — Companion API and integration options
- [Reference addon comparison](analysis/reference-addon-comparison.md) — Comparative analysis with reference addon
- [XP tracking improvements](analysis/xp-tracking-improvements-plan.md) — Actionable XP pipeline improvement list

## Memory (Decisions and Lessons)

- [Decision log](memory/decision-log.md) — Canonical record of all decisions with rationale
- [Lessons learned](memory/lessons-learned.md) — Recurring patterns and insights
- [External analysis](memory/external-project-analysis.md) — Findings from Blizzard UI source

## Guidelines (Standards)

- [Project structure](guidelines/project-structure.md) — File placement rules and doc ownership
- [Architecture choices](guidelines/code-architecture-choices.md) — Design principles and constraints

## Open Investigation Tracks

- [Notes](notes.md) — Analysis tracks not yet resolved (workflow consistency, options panel, UI naming)

## Documentation Rules

1. `plan.md` = project goals, priorities, and next steps
2. `features/` = one file per addon feature describing what it does
3. `backlog/` = actionable future work items with goals and acceptance criteria
4. `history/` = archived implementation records
5. `memory/` = durable decisions and lessons across sessions
6. `analysis/` = deep technical investigations
7. `guidelines/` = architecture and structure standards
8. One source of truth per concern — don't duplicate across files
