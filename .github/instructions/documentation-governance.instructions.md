---
applyTo: "**/*.md,**/*.lua,**/*.xml,**/*.toc"
---

# Documentation Governance (Project Requirement)

This repository uses a docs-first documentation model.

## Canonical Locations

- Project plan and goals: `docs/plan.md`
- Feature descriptions (what the addon does): `docs/features/*.md`
- Actionable future work: `docs/backlog/*.md`
- Completed implementation records: `docs/history/*.md`
- Durable memory/lessons/decision logs: `docs/memory/*.md`
- Architecture and structure standards: `docs/guidelines/*.md`
- Deep technical investigations: `docs/analysis/*.md`
- Open investigation tracks: `docs/notes.md`

## Required Agent Behavior

1. Do not place canonical project plans/backlogs in AI-tool folders.
2. Treat `.claude/plan.md` as compatibility pointer-only.
3. Feature files describe what the addon does, not implementation tasks or phases.
4. For changes that affect behavior, architecture, or user-facing options:
   - update the relevant `docs/features/*.md` file
   - append/update decision notes in `docs/memory/decision-log.md`
   - if structure/architecture assumptions changed, update `docs/guidelines/*.md`
5. Keep documentation updates in the same PR/change set as code updates when feasible.
6. Completed work goes to `docs/history/`, not left in backlog or features.

## Quality Bar

- Keep docs concise and actionable.
- Prefer incremental updates over full rewrites.
- Preserve historical rationale; do not erase previous lessons without replacement context.
