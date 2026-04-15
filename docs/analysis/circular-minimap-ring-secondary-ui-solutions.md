# Investigation: Circular + Minimap Ring Secondary UI Solutions

Status: **Prototype implemented — under feedback validation**
Created: 2026-04-13
Owner: `docs/plan.md` (Phase 5 / Phase 6 pre-implementation analysis)

## Purpose

Define practical UI solution candidates for the two remaining secondary bar style families:

- `circular` primary style
- `minimap_ring` primary style

This document started as pre-implementation option analysis. It now includes reconciliation notes for what was actually prototyped so planning and implementation stay aligned.

## Prototype Outcome (Implemented)

### Circular secondary

- Implemented as a **C3 + C1 hybrid**:
	- default: inner **semi-circular** arc (partial arc behavior)
	- option: full 360-degree inner ring (concentric inner ring behavior)
- Style mapping is 1:1 via `SecondaryBarManager.TEMPLATE_MAP`:
	- `circular` -> `CircularReputationBarTemplate`
- New option panel setting:
	- `circularSecondaryFullCircle`

### Minimap secondary

- Implemented as **icon + centered toggle arc** (not M1/M2):
	- draggable icon controls placement
	- clicking icon toggles reputation arc visibility
	- arc is centered on the icon, so movement keeps icon/arc aligned
- Style mapping is 1:1 via `SecondaryBarManager.TEMPLATE_MAP`:
	- `minimap_ring` -> `MinimapArcReputationBarTemplate`
- New option panel settings:
	- `minimapArcStartExpanded`
	- `minimapArcIconScale`

### Attachment behavior

- Circular style remains attachable to the primary bar center in attached mode.
- Minimap icon+arc style intentionally opts out of primary attachment and remains free-floating (`ShouldAttachToPrimary() == false`).

## Current Implementation Constraints

### Circular primary (`circular`)

The circular XP bar uses a segment ring renderer (pooled textures, per-segment placement + rotation), not a `StatusBar` fill. Any style-matched circular secondary should reuse the same segment/ring rendering model.

### Minimap ring primary (`minimap_ring`)

The minimap XP style dynamically computes ring radius from minimap scale and padding, and also owns minimap button collection behavior. A secondary solution must avoid:

- minimap click interference
- overlap with collected addon buttons
- layout regressions during display scale and UI scale changes

## Design Goals

1. Visual coherence with the active primary style.
2. Readability at common UI scales.
3. Minimal interaction risk (especially around minimap).
4. Low maintenance by reusing existing segment infrastructure.
5. Respect existing secondary-bar behavior model (tooltip-first details, optional on-bar text).

## Circular Secondary Candidates

### Option C1: Concentric Inner Ring

Secondary ring shares center with the primary ring but uses a smaller radius.

Pros:
- Strongest visual match with circular primary.
- High code reuse potential (segment placement math and type/color pipeline).
- Easy conceptual model for users (outer XP, inner reputation).

Cons:
- Smaller circumference can reduce segment readability.
- Potential center-text crowding if labels are added.

Risk level: Medium

Implementation fit: High

Reconciliation: **Partially implemented** via full-circle toggle mode of the circular prototype.

### Option C2: Outer Halo Ring

Secondary ring is rendered at a larger radius than primary.

Pros:
- Better readability than inner ring (longer circumference).
- Keeps center region cleaner.

Cons:
- Increases frame footprint and potential overlap with nearby UI.
- May look visually heavy at high scale.

Risk level: Medium

Implementation fit: High

### Option C3: Partial Arc Secondary

Secondary uses a fixed arc region (for example lower semicircle) instead of full 360 degrees.

Pros:
- Reduces visual clutter.
- Clear separation between XP and reputation semantics.

Cons:
- Less intuitive progress mapping than full ring.
- Requires clear start/end anchor convention and consistent orientation.

Risk level: Medium

Implementation fit: Medium

Reconciliation: **Implemented as default** for the circular prototype.

### Option C4: Tick-Only Micro Ring

Very thin or sparse/dotted ring intended as ambient progress hint, with details in tooltip.

Pros:
- Lowest visual noise.
- Works well with tooltip-first secondary UX.

Cons:
- Lower legibility for quick glance reading.
- May feel too subtle for some users.

Risk level: Low

Implementation fit: High

## Minimap Ring Secondary Candidates

Note: The implemented prototype uses an icon-centered toggle arc pattern requested in-session, so it does not directly match M1/M2/M3/M4.

### Option M1: Outer Secondary Ring (Recommended baseline)

Render reputation ring outside the primary minimap XP ring using a second radius.

Pros:
- Safest minimap readability and click behavior profile.
- Keeps minimap center unobscured.
- Can align with existing ring math and radius computation.

Cons:
- Must coordinate with button-bag anchor and collected button panel spacing.
- Increases minimap visual footprint.

Risk level: Medium

Implementation fit: High

### Option M2: Inner Secondary Ring

Render reputation ring inside the primary minimap XP ring.

Pros:
- Compact visual footprint.
- Clean double-ring look when tuned well.

Cons:
- Higher risk of minimap content obstruction.
- More sensitive to minimap shape/scale variation.

Risk level: High

Implementation fit: Medium

### Option M3: Split-Arc Ring

Render secondary only over selected arc zones (for example lower 120-180 degrees).

Pros:
- Reduces collisions with common minimap affordances/buttons.
- Lower visual density than full double ring.

Cons:
- Requires arc layout rules and strong defaults.
- Progress continuity may be less obvious to users.

Risk level: Medium

Implementation fit: Medium

### Option M4: Hybrid Ring + Badge

Keep ring minimal, move richer secondary state to minimap bag/badge indicator.

Pros:
- Preserves minimap clarity.
- Strong fallback if dual-ring interaction proves fragile.

Cons:
- Less direct parity with non-minimap secondary bar experiences.
- More behavior split across two UI surfaces.

Risk level: Medium

Implementation fit: Medium

## Recommended Prototype Sequence

Historical sequence (pre-implementation):

1. Circular: C1 (Concentric Inner Ring)
2. Minimap Ring: M1 (Outer Secondary Ring)
3. If clutter/interactions regress: evaluate C3 and M3 (split-arc variants)
4. Keep C4/M4 as low-noise fallback options

Prototype actually delivered:

1. Circular: C3 default with C1 toggle path (full-circle option)
2. Minimap Ring: icon-centered toggle arc
3. Gather feedback before revisiting M1/M2/M3 alternatives

## Evaluation Checklist

### Interaction Safety

- Minimap click-through remains functional.
- No interference with minimap button collection behavior.
- Drag/position interactions remain stable.

### Visual Legibility

- Standing color remains distinguishable at small segment sizes.
- Progress state is interpretable at a glance.
- Tooltip remains the detailed source of truth.

### Stability and Performance

- No noticeable frame hitching during XP/rep updates.
- Reposition remains correct after `DISPLAY_SIZE_CHANGED` / `UI_SCALE_CHANGED` / `PLAYER_ENTERING_WORLD`.
- Ring redraw costs remain acceptable at high segment counts.

## Decision Gate

This investigation is complete when:

- [x] Circular style direction selected (C3 default + C1 full-circle option).
- [x] Minimap direction selected (icon-centered toggle arc variant).
- [ ] Primary fallback path agreed if selected direction fails interaction testing.
- [x] Final decision recorded in `docs/memory/decision-log.md`.
- [ ] `docs/plan.md` updated with selected implementation approach.
