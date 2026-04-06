# Backlog: Per-Bar Font Customization

Status: Closed - Not Planned (2026-04-06)

Priority: P2
Effort: Small
Risk: Low
Source: docs/analysis/reference-addon-comparison.md

## Summary

This item is no longer part of the active roadmap.

Expand font customization from global-only to per-bar or per-bar-type (primary vs secondary), allowing users to set different font faces, sizes, and outlines for different bars.

## Motivation

Decision update (2026-04-06): per-bar font overrides are not needed for the current scope.

The addon has global font settings (`textFontFace`, `textFontSize`, `textFontOutline`, `textFontShadow`) but some users may want different font sizes on the compact secondary bars vs the main XP bar, or may want a different font for the terminal style.

The reference addon supports per-bar font settings.

## Scope

Roadmap status: superseded by planning decision; implementation is not approved.

### In Scope

- Add optional per-bar-type font override keys (e.g., `secondaryFontSize`, `secondaryFontFace`).
- Falls back to global font settings when per-bar overrides are nil/default.
- Options panel controls for secondary bar font overrides.

### Out of Scope

- Per-style font overrides for each of the 6 primary styles (over-engineering for now).

## Tasks

1. Add `secondaryFontFace`, `secondaryFontSize`, `secondaryFontOutline` to `defaults.lua` (default: nil = use global).
2. In secondary bar render paths, resolve font settings: use secondary override if set, else fall back to global.
3. Add font option controls in the "Secondary Bars" options section.
4. Add locale strings.

## Affected Files

- core/config/defaults.lua
- ui/secondary/FlatReputationBarStyle.lua
- ui/secondary/FlatCompanionBarStyle.lua
- ui/options/OptionMetadata.lua
- ui/options/Options.lua
- locales/enUS.lua

## Acceptance Criteria

- [ ] Secondary bars can use a different font size than the primary bar.
- [ ] When override is unset, secondary bars use global font settings.
- [ ] Font changes apply immediately.
- [ ] Settings persist across reload.

## Closure Note

- Closed by product direction during pre-Phase-7 planning.
- Keep this document as historical reference only.
