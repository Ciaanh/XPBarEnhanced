# XPBarEnhanced — Project Plan

Last updated: 2026-04-15 (post-analysis session)

## Addon Summary

Enhanced XP bar addon for WoW Retail with 7 visual styles, quest XP overlay, session statistics, reputation and companion tracking, and full color customization. Current version: **1.1.0**.

## Current State

The addon is feature-complete for its v1.1.0 scope (shipped 2026-04-12), with secondary bar coverage extended through 2026-04-13 prototype sessions:

- **Primary XP bar**: 7 styles (flat, classic, vertical, circular, minimap_ring, terminal), animations, quest overlay, session tracking, max-level auto-hide
- **Secondary bar** (unified): Watched-faction + companion-aware display with fade, drag, tooltip, live text
- **Secondary bar styles**: Full style parity achieved — `flat` ✅, `classic` ✅, `vertical` ✅, `circular` ✅, `minimap_ring` ✅, `terminal` ✅. All active in `TEMPLATE_MAP`.
- **Architecture**: Centralized event router, context-first render model, shared secondary lifecycle, compliance hardened
- **Quality**: Combat safety, fade lifecycle, context contracts, emission ownership validated

See `docs/history/phases.md` for full implementation history.

---

## Analysis Findings (2026-04-15)

A full architecture and UI/UX audit was completed. Key findings are summarized below.
Detailed reports are available in the project conversation history.

### Architecture Issues

| # | Severity | Issue | Location |
|---|----------|-------|----------|
| A1 | **Critical** | Global namespace pollution — `local Addon = XPBarEnhanced` relies on a bare global; should use `local addonName, ns = ...` at the entry point | [XPBarEnhanced.lua](../XPBarEnhanced.lua) |
| A2 | **High** | Context rebuilt on every render — `UnitXP`, `UnitXPMax`, `GetWatchedFactionInfo` called without per-frame caching | [core/services/ContextBuilder.lua](../core/services/ContextBuilder.lua) |
| A3 | **High** | Style overlay update logic duplicated across styles | [ui/styles/](../ui/styles/) |
| A4 | **High** | Mixin chain complexity — 9 mixin files; PositionMixin and LayoutMixin could merge; DisplayMixin and PaintMixin partially overlap | [ui/mixins/](../ui/mixins/) |
| A5 | **Medium** | Config and ConfigHelper have overlapping API surface | [core/config/](../core/config/) |
| A6 | **Medium** | EventRouter dispatch table: large, repetitive, hard to extend | [core/EventRouter.lua](../core/EventRouter.lua) |
| A7 | **Low** | Inconsistent parameter validation across calculation modules | [core/calculations/](../core/calculations/) |
| A8 | **Low** | Animation config table allocated in hot update path | [ui/mixins/BaseMixin.lua](../ui/mixins/BaseMixin.lua) |

### UI/UX Issues

| # | Severity | Issue | Location |
|---|----------|-------|----------|
| U1 | **Critical** | Options panel: 40+ controls in a single scrollable list; no grouping, no progressive disclosure | [ui/options/](../ui/options/) |
| U2 | **High** | Text hierarchy undefined — font sizes, colors, positions inconsistent across styles | [ui/mixins/TextMixin.lua](../ui/mixins/TextMixin.lua) |
| U3 | **High** | Animation system underutilized; little visual feedback for state changes | — |
| U4 | **Medium** | Quest complete/incomplete overlays can visually interfere | [ui/styles/classic/ClassicBarTemplate.xml](../ui/styles/classic/ClassicBarTemplate.xml) |
| U5 | **Medium** | Tooltip positioning basic — no edge-of-screen or multi-monitor awareness | [ui/mixins/TooltipMixin.lua](../ui/mixins/TooltipMixin.lua) |

---

## Roadmap

Phases are ordered by impact and risk. Each phase is independently mergeable.

### Scope Lock (2026-04-15)

Approved implementation candidates:
- A1, A2, A3, A4, A5
- B1, B2
- C4
- D1

Removed from active implementation scope (not kept):
- B3
- C1, C2, C3
- D2, D3, D4

---

### Phase A — Architecture Cleanup

**Goal:** Address technical debt before adding new features.
*Prerequisite for all subsequent phases to avoid compounding debt.*

#### A1 — Fix Global Namespace (Critical)

The addon entry point assigns `local Addon = XPBarEnhanced` across every file, relying on the global being populated in `XPBarEnhanced.lua`. The entry point must use the standard WoW two-value vararg pattern so the namespace is never a bare global.

Steps:
1. `XPBarEnhanced.lua`: Replace global assignment with `local addonName, ns = ...; XPBarEnhanced = ns` (XPBarEnhanced must remain as a named global for SavedVariables and slash commands, but all internal consumers should reference `ns` — verify what Blizzard requires for `SavedVariablesPerCharacter`).
2. Verify each file's `local Addon = XPBarEnhanced` still resolves after load-order checks (it will, because TOC loads `XPBarEnhanced.lua` first).
3. Update architecture-contracts.ps1 to assert the `local addonName, ns = ...` pattern appears in the entry point.

Verification: `/reload` with no Lua errors; architecture contracts pass.

---

#### A2 — Context Build Caching (High)

`ContextBuilder.BuildContext()` is called on every `Render(context)` invocation. For burst-prone events (XP gain flooding from multi-mob kills) this hammers `UnitXP`, `UnitXPMax`, and `GetWatchedFactionInfo` per frame.

Steps:
1. `core/services/ContextBuilder.lua`: Add a frame-level cache using `C_Timer.After(0, flush)` or `OnUpdate` cleared each frame. Cache context keyed by `GetTime()` / frame counter.
2. Alternatively: move context building out of Render into the EventBus emit path (the emitter already owns context — verify if the current XP context path already does this for deduplication).
3. Measure: add optional `XPBE_DEBUG_CONTEXT` CVar path that logs context build frequency.

Verification: No observable behavior change; repeated events within one frame produce one context build.

---

#### A3 — Style Base Class Extraction (High)

Overlay update logic (fill, color, alpha) is duplicated across `FlatBarStyle`, `ClassicBarStyle`, `VerticalBarStyle`, and their secondary counterparts.

Steps:
1. Create `ui/styles/SharedStyleHelpers.lua` (note: `SecondaryBarStyleHelpers.lua` already exists — consolidate or extend it).
2. Extract common patterns: `ApplyFillColor(bar, r, g, b)`, `ApplyFillAlpha(bar, alpha)`, overlay update.
3. Refactor each style to call the helper; keep style-specific logic inline.
4. Add to TOC before style files.

Verification: All styles render identically; no regressions on fill color or alpha behavior.

---

#### A4 — Mixin Consolidation (High — lower urgency)

`PositionMixin` and `LayoutMixin` manage complementary concerns (drag persistence vs. frame sizing) but are thin enough to merge. `DisplayMixin` and `PaintMixin` partially overlap on bar rendering.

Steps:
1. Audit: list all public methods from each mixin; identify true overlaps vs. distinct concerns.
2. Merge `PositionMixin` into `LayoutMixin` if no circular dependency exists.
3. Decide on `DisplayMixin`/`PaintMixin` boundary — merge only if doing so reduces LOC without obscuring responsibility.
4. Update all `Mixin(self, ...)` call sites.

Verification: Architecture contracts pass; style visual output unchanged.

---

#### A5 — Config/ConfigHelper Unification (Medium)

`Config.lua` and `ConfigHelper.lua` have overlapping accessor surfaces. Consumers call both inconsistently.

Steps:
1. Map all public functions in each; identify duplicates.
2. Move canonical implementations into `Config.lua`; make `ConfigHelper` a thin re-export shim or eliminate it.
3. Update all call sites.

Verification: All config reads/writes work; no nil-access on startup.

---

### Phase B — Options Panel UX Overhaul

**Goal:** Reduce option overload; improve discoverability.
*Independent of Phase A — can be worked in parallel.*

#### B1 — Tab-Based Categorization (Critical UX)

The current single-scroll list of 40+ controls overwhelms new users and makes targeted configuration slow.

Proposed tab structure:
- **Visual** — style selector, bar textures, colors, size presets
- **Text** — which text rows show, font, size, outline
- **Behavior** — animations, fade, quest XP, session resets
- **Secondary Bar** — show/hide, style-specific options (circular full-circle, minimap arc angle, etc.)
- **Advanced** — debug flags, migration controls

Steps:
1. Audit `OptionMetadata.lua` — assign each option a tab category field.
2. `Options.lua`: Replace single panel layout with `CreateTabGroup()` (Blizzard Settings API) or manual tab frame using `PanelTemplates`.
3. `OptionsPanel.xml`: Update frame structure.
4. Validate option visibility rules (style-conditional controls) still work per-tab.

Verification: All existing options accessible; style-conditional options appear/disappear correctly per tab.

---

#### B2 — Visual Style Previews (High)

The style selector dropdown shows text names ("flat", "classic", etc.). Users cannot know what a style looks like without switching.

Steps:
1. Design a thumbnail atlas or generate small preview frames (64×32 px rendered StatusBar snapshots per style, baked as atlas textures).
2. Add a preview region above the style dropdown in the Visual tab.
3. Update preview on dropdown selection change via `OnValueChanged`.

Verification: Selecting each style in the dropdown updates the preview without triggering a full style reload.

---

### Phase C — Polish & Quick Wins

**Goal:** Small, high-visibility improvements that don't require architectural changes.

#### C4 — Smart Tooltip Positioning (Low)

Tooltip should not clip at screen edges or overlap the bar it belongs to.

Steps:
1. `ui/mixins/TooltipMixin.lua`: After `tooltip:Show()`, read `tooltip:GetWidth()`/`GetHeight()` and compare against `GetScreenWidth()`/`GetScreenHeight()`.
2. Flip anchor point if tooltip would overflow the screen edge.

Verification: Tooltip remains visible when bar is at right/bottom screen edge.

---

### Phase D — New Features

*Only D1 is currently in implementation scope. Each item in this phase requires individual acceptance before implementation starts.*

#### D1 — Level-Up Celebration Enhancement (Medium)

The animation system has `levelUpCelebration`, `celebrationSparkles`, and `celebrationSound` flags, but the implementation is style-agnostic. Make celebrations style-aware.

Proposed per-style behaviors:
- **Circular**: Radial sparkle burst emanating from the ring center
- **Terminal**: ASCII splash — `*** LEVEL UP ***` text animation with CRT scan-line flash
- **Flat/Classic**: Color pulse + horizontal shimmer across the bar

Steps:
1. `ui/mixins/animation/AnimationManager.lua`: Add `TriggerStyleCelebration(styleName)` dispatch.
2. Implement style-specific celebration in each `*BarStyle.lua` file as an optional `OnLevelUpCelebration()` hook.
3. `defaults.lua`: No new keys needed; reuse `levelUpCelebration` toggle.

Verification: Level-up triggers correct style animation; toggling `levelUpCelebration` suppresses it.

---

## Open Backlog

| Item | Priority | Status |
| ---- | -------- | ------ |
| [secondary-bar-styles.md](backlog/secondary-bar-styles.md) | Secondary bar style coverage | **Complete** — all 6 styles active in TEMPLATE_MAP as of 2026-04-13 |

---

## Phase Priority Summary

| Phase | Item | Impact | Effort | Status |
|-------|------|--------|--------|--------|
| A1 | Fix global namespace | High | Small | Completed (2026-04-16) |
| A2 | Context build caching | High | Small | Completed (2026-04-16) |
| A3 | Style base class extraction | Medium | Medium | Completed (2026-04-16) |
| A4 | Mixin consolidation | Medium | Medium | Assessed: no-op — PositionMixin and LayoutMixin are correctly separated |
| A5 | Config/ConfigHelper unification | Low | Small | Assessed: no-op — already cleanly split |
| B1 | Options panel tabs | Critical UX | Large | Completed (2026-04-16) |
| B2 | Visual style previews | High UX | Medium | Completed (2026-04-16) |
| C4 | Smart tooltip positioning | Low | Small | Completed (2026-04-16) |
| D1 | Level-up celebration, style-specific | Medium | Medium | Completed (2026-04-16) |

**Recommended start order:** A1 → A2 → B1 → B2 → C4 → A3 → A4 → A5 → D1

---

## How to Start a Session

1. Review this plan for current goals and priorities
2. Pick the highest-priority not-started item from the Phase Priority Summary
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
