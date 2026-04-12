# XPBarEnhanced — Project Plan

Last updated: 2026-04-12 (session 2)

## Addon Summary

Enhanced XP bar addon for WoW Retail with 7 visual styles, quest XP overlay, session statistics, reputation tracking, companion tracking, and full color customization. Current version: **1.1.0**.

## Current State

The addon is feature-complete for its core scope (v1.1.0, shipped 2026-04-12):

- **Primary XP bar**: 7 styles, animations, quest overlay, session tracking, max-level auto-hide
- **Unified secondary bar**: Watched-faction tracking with companion-aware display, fade, drag, tooltip, live text
- **Architecture**: Centralized event router, context-first render model, shared secondary lifecycle
- **Quality**: Compliance hardened (combat safety, fade lifecycle, context contracts, emission ownership)

See `docs/history/phases.md` for full implementation history.

## Goals

### Completed This Session

- **README version sync** — `1.0.7` → `1.1.0` in README.md
- **Session.lua cleanup** — `SetupEventFrame()` dead method removed; `session.sessionXP` annotation confirmed accurate (active SavedVariables mirror field)
- **Per-style secondary bar position** — implemented; see decision-log for full scope

---

### Next Session

#### 1. README Update

Sync public-facing documentation to v1.1.0.

Steps:
1. Update version string (`1.0.7` → `1.1.0`) in README header.
2. Verify feature list matches current shipped behavior (unified secondary bar, companion decoration, options).
3. Confirm slash command table is accurate.

Definition of done: README version matches TOC; no feature described in README differs from actual behavior.

---

#### 2. Code Cleanup

Remove two stale artifacts in `core/services/Session.lua`.

Steps:
1. Grep for all call sites of `Session:SetupEventFrame()`. If none found, delete the method body entirely (keep `@deprecated` note as a one-line comment if referenced in tests).
2. Grep for all read sites of `session.sessionXP`. If only the annotation references it, remove the `@field` doc line and confirm no SavedVariables migration needed.

Definition of done: no dead methods or misleading annotations remain in Session.lua.

---

#### 3. Per-Style Secondary Bar Position

**Approved 2026-04-12.** Full scope in [docs/backlog/secondary-bar-per-style-position.md](docs/backlog/secondary-bar-per-style-position.md).

Steps:
1. Replace `db.secondaryBarPosition` (single table) with `db.secondaryBarPositions` (table keyed by primary style name — e.g. `{ flat = {...}, classic = {...} }`) in `Database.lua` seeding and `defaults.lua`.
2. Update `SecondaryBarBaseMixin`: `SavePosition` writes to `db.secondaryBarPositions[currentPrimaryStyle]`; `GetSavedPosition` reads the same key.
3. Update `GetFallbackPosition()` — no change needed (already derives from `barPositions[barStyle]`).
4. Update `ResetBarPositions` in `SecondaryBarManager` to clear only the current style's entry, not the whole table.
5. Add one-time migration in `Database:Initialize()`: if `db.secondaryBarPosition` exists and `db.secondaryBarPositions` is nil, copy the value into the slot for the currently active style then clear the old key.
6. Validation: switch primary styles and confirm secondary bar position is independently saved per style; test free-drag and attached-mode paths; test reset; test reload persistence.

Definition of done: dragging secondary bar in style A does not affect its position in style B; no nil errors on first login after upgrade; existing drag/attach paths unaffected.

---

### Under Investigation

#### Secondary Bar Styles

Dedicated analysis document: [docs/analysis/secondary-bar-styles-investigation.md](docs/analysis/secondary-bar-styles-investigation.md)

Goal: determine which additional visual styles are viable for the secondary bar, how they integrate with the existing primary XP bar style system, and what the delivery plan should look like. Outcome will be either an approved backlog item with scope or a decision to keep flat-only.

---

## Open Backlog

| Item | Priority | Status |
| ---- | -------- | ------ |
| [secondary-bar-styles](docs/backlog/secondary-bar-styles.md) | P3 | Investigation in progress — see analysis doc |

## How to Start a Session

1. Review this plan for current goals and priorities
2. Pick a goal or step to work on
3. Check `docs/backlog/README.md` if picking feature work
4. Record decisions in `docs/memory/decision-log.md`
5. Update this plan when goals shift or steps are completed

## Documentation Map

| Location | Purpose |
| ---------- | ------- |
| `docs/plan.md` | This file — project goals, priorities, next steps |
| `docs/features/` | What the addon does — one file per feature |
| `docs/backlog/` | Future work items with goals, scope, and acceptance criteria |
| `docs/history/` | Completed implementation phases (archive) |
| `docs/analysis/` | Deep technical investigations and research |
| `docs/memory/` | Decision log, lessons learned, external analysis |
| `docs/guidelines/` | Architecture and project structure standards |
| `docs/notes.md` | Open analysis tracks for future investigation |
