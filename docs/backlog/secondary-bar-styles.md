# Backlog: Additional Secondary Bar Styles

Priority: P3
Effort: Large
Risk: Low
Source: feature gap analysis

## Summary

Create new visual styles for the reputation and companion bars beyond the current "flat" style, such as classic, minimal, or bar styles that match the active primary bar style.

## Motivation

The primary XP bar offers 6 distinct visual styles (classic, flat, vertical, circular, minimap ring, terminal). Secondary bars only have one style ("flat"). Users may want secondary bars to visually match their chosen primary style.

## Scope

### In Scope

- "Classic" style for secondary bars (matching the primary classic bar appearance).
- "Minimal" style (thin line, text only, no background).
- Style selection per secondary bar via the existing dropdown in options.
- Template XML + Lua for each new style.

### Out of Scope

- Circular or minimap ring secondary bars (architectural complexity too high for the return).
- Terminal-style secondary bars (niche demand).

## Tasks

1. Create `ui/secondary/ClassicReputationBarTemplate.xml` + `ClassicReputationBarStyle.lua`.
2. Create `ui/secondary/ClassicCompanionBarTemplate.xml` + `ClassicCompanionBarStyle.lua`.
3. Create `ui/secondary/MinimalReputationBarTemplate.xml` + `MinimalReputationBarStyle.lua`.
4. Create `ui/secondary/MinimalCompanionBarTemplate.xml` + `MinimalCompanionBarStyle.lua`.
5. Register new styles in `SecondaryBarManager` template mapping.
6. Add style options to dropdown choices in OptionMetadata.
7. Add locale strings.
8. Update TOC with new files.

## Affected Files

- New: 8 files in ui/secondary/
- ui/SecondaryBarManager.lua
- ui/options/OptionMetadata.lua
- locales/enUS.lua
- XPBarEnhanced.toc

## Acceptance Criteria

- [ ] At least 2 additional secondary bar styles are available.
- [ ] Style switching works without reload.
- [ ] New styles follow the same lifecycle contract as flat bars.
- [ ] Style-specific rendering matches the visual identity of the style name.
