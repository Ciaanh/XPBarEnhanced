# Backlog: Bar Size and Scale Options

Status: Closed - Not Planned (2026-04-06)

Priority: P2
Effort: Medium
Risk: Low
Source: docs/analysis/reference-addon-comparison.md

## Summary

This item is no longer part of the active roadmap.

Add width, height, and/or scale options for bars so users can customize bar dimensions beyond the style-defined defaults.

## Motivation

Decision update (2026-04-06): size/scale customization is intentionally excluded from the near-term product scope.

The reference addon supports per-bar width and height customization. Our addon currently uses fixed dimensions per style (except circular which has a size dropdown). Users with different screen resolutions or UI scales may want larger or smaller bars.

## Scope

Roadmap status: superseded by planning decision; implementation is not approved.

### In Scope

- Per-style width/height or uniform scale slider for primary bars that support it (flat, classic, terminal).
- Width/height options for secondary bars (reputation, companion).
- Options panel controls (sliders).
- Position re-anchoring after size change.

### Out of Scope

- Circular bar (already has size dropdown).
- Minimap ring (anchored to minimap, size is implicit).
- Vertical bar (height is primary dimension, may need special handling).

## Tasks

1. Add `barWidth`, `barHeight` or `barScale` config keys to `defaults.lua` with per-style defaults.
2. Add slider controls in the options panel under "Bar Settings" section.
3. In StyleBuilder or individual style Lua files, apply the configured dimensions on frame creation/resize.
4. Ensure text elements scale or reflow when bar size changes.
5. For secondary bars, add `secondaryBarWidth` / `secondaryBarHeight` config keys.
6. Fire CONFIG_UPDATED on change so bars redraw at new size.

## Affected Files

- core/config/defaults.lua
- ui/options/OptionMetadata.lua
- ui/options/Options.lua
- ui/StyleBuilder.lua (or individual style Lua files)
- ui/secondary/FlatReputationBarStyle.lua
- ui/secondary/FlatCompanionBarStyle.lua
- locales/enUS.lua

## Acceptance Criteria

- [ ] User can adjust bar width/height via sliders in options.
- [ ] Changes apply immediately (live preview).
- [ ] Settings persist across reload/login.
- [ ] Text remains readable at different bar sizes.
- [ ] Secondary bars can be independently sized.

## Closure Note

- Closed by product direction during pre-Phase-7 planning.
- Keep this document as historical reference only.
