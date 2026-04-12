# XPBarEnhanced — Project Plan

Last updated: 2026-04-13 (session 5)

## Addon Summary

Enhanced XP bar addon for WoW Retail with 7 visual styles, quest XP overlay, session statistics, reputation tracking, companion tracking, and full color customization. Current version: **1.1.0**.

## Current State

The addon is feature-complete for its core scope (v1.1.0, shipped 2026-04-12):

- **Primary XP bar**: 7 styles, animations, quest overlay, session tracking, max-level auto-hide
- **Unified secondary bar**: Watched-faction tracking with companion-aware display, fade, drag, tooltip, live text
- **Secondary bar styles**: Flat (original), Classic (atlas fill, bordered, label), and Minimal (6 px dormant) implemented. Style selection is 1:1 with primary bar style via `TEMPLATE_MAP` in `SecondaryBarManager` — no user-facing override config. Vertical/Circular/Minimap Ring/Terminal produce no secondary bar until their templates are built.
- **Architecture**: Centralized event router, context-first render model, shared secondary lifecycle
- **Quality**: Compliance hardened (combat safety, fade lifecycle, context contracts, emission ownership)

See `docs/history/phases.md` for full implementation history.

## Goals

### Active — Secondary Bar: Style-Matched Coverage for All Primary Styles

**Approved 2026-04-13.**

All 6 primary styles should produce a secondary bar that matches the visual language of its primary.
Current coverage: `flat` ✅, `classic` ✅. Four styles produce no secondary bar yet.

Each remaining style is a separate phase because the implementation approach differs significantly.

---

#### Phase 3 — Vertical Secondary

**Visual spec:** Narrow vertical bar placed alongside the primary column. Mirrors the vertical primary's orientation and solid-color fill.

- **Primary shape**: 60×300 px, `StatusBar orientation="VERTICAL"`
- **Secondary shape**: ~20×300 px, `StatusBar orientation="VERTICAL"`, same height, placed to the left (or right) of the primary
- **Fill**: solid `SetStatusBarColor` using the same `FACTION_COLORS` map as Flat/Classic secondary
- **Label**: tooltip-only — too narrow for readable on-bar text
- **Position**: `GetFallbackPosition()` offsets left by primary width + gap; uses `secondaryBarPositions` for user drag

Steps:
1. Create `ui/styles/vertical/VerticalSecondaryBarStyle.lua` — 3 hooks + drag/tooltip/load. `Render`: solid color fill, min/max/value. No label.
2. Create `ui/styles/vertical/VerticalSecondaryBarTemplate.xml` — 20×300 root frame, single `StatusBar orientation="VERTICAL"` at full size, `frameStrata="MEDIUM"`.
3. `ui/SecondaryBarManager.lua`: add `vertical = "VerticalReputationBarTemplate"` to `TEMPLATE_MAP`.
4. `XPBarEnhanced.toc`: add `ui\styles\vertical\VerticalSecondaryBarTemplate.xml` in Styles section.

Verification: primary=vertical → vertical reputation bar appears to one side; fill reflects faction color; tooltip shows faction data; drag/save works independently.

---

#### Phase 5 — Circular Secondary (Investigation required before implementation)

**Not started.**

The Circular primary uses a 100-segment ring built by `CircularBarStyleTemplate:CreateRingSegments()` — each segment is a manually positioned and rotated `Texture` quad arranged around a center point. There is no `StatusBar` widget. A style-matched secondary must use the same or a factored version of this infrastructure.

Key questions before implementation:
- **Shape**: inner concentric ring (smaller radius) vs. a separate floating ring?
- **Reuse**: can `CreateRingSegments` be parameterized (radius, width, count) to share the implementation, or does the secondary need its own copy?
- **Anchor**: where does the secondary ring sit relative to the 256×256 primary frame?
- **Text**: abbreviated faction name + standing below or inside the ring?

Deliver a `docs/analysis/circular-secondary-investigation.md` before starting code.

---

#### Phase 6 — Minimap Ring Secondary (Investigation required before implementation)

**Not started.**

The Minimap Ring sits at `BACKGROUND` strata and positions segments dynamically around the minimap button's circumference. A secondary ring would need a different radius (inside or outside the XP ring). Additional constraint: the minimap ring manages the button collection (`MinimapButtonCollection`) and must not be disrupted.

Key questions before implementation:
- **Radius**: inner ring (inside XP ring) or outer ring (outside)? Does either interfere with minimap interaction?
- **Button collection**: does a second ring at a different radius conflict with the button repositioning logic?
- **Strata**: secondary ring must not occlude the minimap or its buttons.

Deliver a `docs/analysis/minimap-ring-secondary-investigation.md` before starting code.

---

## Open Backlog

| Item | Priority | Status |
| ---- | -------- | ------ |

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
