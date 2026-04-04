---
applyTo: "**/*.md,**/*.lua,**/*.xml,**/*.toc"
---

# Documentation Governance (Project Requirement)

This repository uses a docs-first documentation model.

## Canonical Locations

- Active coding session plan: `docs/plan.md`
- Durable memory/lessons/decision logs: `docs/memory/*.md`
- Architecture and structure standards: `docs/guidelines/*.md`
- Feature documentation: one file per feature in `docs/features/*.md`

## Required Agent Behavior

1. Do not place canonical project plans/backlogs in AI-tool folders.
2. Treat `.claude/plan.md` as compatibility pointer-only.
3. For changes that affect behavior, architecture, or user-facing options:
- update the relevant `docs/features/*.md` file
- append/update decision notes in `docs/memory/decision-log.md`
- if structure/architecture assumptions changed, update `docs/guidelines/*.md`
4. Keep documentation updates in the same PR/change set as code updates when feasible.

## Quality Bar

- Keep docs concise and actionable.
- Prefer incremental updates over full rewrites.
- Preserve historical rationale; do not erase previous lessons without replacement context.
