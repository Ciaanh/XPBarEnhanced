# Docs Index

This folder is the canonical source for project planning and technical documentation.

## Core Files

- Session guide: [plan.md](plan.md)
- Architecture analysis: [analysis/architecture-analysis.md](analysis/architecture-analysis.md)

## Memory

- Lessons learned: [memory/lessons-learned.md](memory/lessons-learned.md)
- Decision log: [memory/decision-log.md](memory/decision-log.md)
- External analysis: [memory/external-project-analysis.md](memory/external-project-analysis.md)

## Guidelines

- Project structure: [guidelines/project-structure.md](guidelines/project-structure.md)
- Architecture choices: [guidelines/code-architecture-choices.md](guidelines/code-architecture-choices.md)

## Features

- XP core pipeline: [features/xp-core-pipeline.md](features/xp-core-pipeline.md)
- Reputation bar: [features/reputation-bar.md](features/reputation-bar.md)
- Companion bar: [features/companion-bar.md](features/companion-bar.md)
- Secondary bar manager: [features/secondary-bar-manager.md](features/secondary-bar-manager.md)

## Update Workflow

1. Start from [plan.md](plan.md) for active work.
2. Record durable decisions in [memory/decision-log.md](memory/decision-log.md).
3. Add recurring insights to [memory/lessons-learned.md](memory/lessons-learned.md).
4. Update affected feature docs in [features](features).
5. If architecture direction changes, update [guidelines/code-architecture-choices.md](guidelines/code-architecture-choices.md).

## Policy

- Planning and backlog documentation must live in `docs/`.
- `.claude/plan.md` is a compatibility pointer only, not a source of truth.
