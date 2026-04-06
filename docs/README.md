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
- Phase 6 summary: [features/phase-6-secondary-polish.md](features/phase-6-secondary-polish.md)
- Phase 7 planning gate: [features/phase-7-planning-gate.md](features/phase-7-planning-gate.md)
- Phase 7 slice 1: [features/phase-7-slice-1-compliance-hardening.md](features/phase-7-slice-1-compliance-hardening.md)

## Update Workflow

1. Start from [plan.md](plan.md) for active work.
2. Record durable decisions in [memory/decision-log.md](memory/decision-log.md).
3. Add recurring insights to [memory/lessons-learned.md](memory/lessons-learned.md).
4. Update affected feature docs in [features](features).
5. If architecture direction changes, update [guidelines/code-architecture-choices.md](guidelines/code-architecture-choices.md).

## Documentation Boundaries

- `plan.md` is for current-session planning only (what is being executed now, next steps, and session checklist).
- `features/*.md` holds feature-level decisions, scope, status, acceptance criteria, and references to analysis.
- `memory/*.md` holds durable decisions, rationale, and lessons across sessions.
- `analysis/*.md` stores deep-dive technical investigations.

Compaction rule:

1. Prefer links to canonical docs instead of copying long sections.
2. Keep one source of truth per concern (plan, feature scope, analysis, decisions).
3. Move stale phase narrative to decision log or analysis references, then trim operational docs.
4. Do not store durable approvals/decisions in `plan.md`; record them in feature + memory docs.

## Policy

- Planning and backlog documentation must live in `docs/`.
- `.claude/plan.md` is a compatibility pointer only, not a source of truth.
