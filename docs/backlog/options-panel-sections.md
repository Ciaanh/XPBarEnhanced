# Backlog: Options Panel Section Grouping

## Goal

Replace the flat 36-option list in the settings panel with a visually grouped layout — section headers above each group, style-specific sections visible only when the matching bar style is active.

## Motivation

- 36 undifferentiated options are hard to scan; users hunting for "circular size" must scroll through all XP text and animation options first
- Style-specific options for inactive styles clutter the panel; they are visually confusing (e.g., "Minimap Ring Segment Width" visible when the Classic style is selected)

## Scope

**In scope**:
- Add a `SectionDivider` / section-header widget to `OptionsPanelTemplates.xml`
- Extend `OptionMetadata.lua` `optionOrder` (or introduce `optionSections`) to carry section labels per-option
- Modify `ControlHelpers.lua` and `Options.lua` to emit section headers and collect style-specific option groups
- Implement conditional visibility: style-specific sections (`Circular`, `Minimap Ring`, `Terminal`) shown/hidden via `SetShown()` on barStyle change

**Out of scope**:
- Tabbed or multi-subcategory navigation (decided against in MQ-2; revisit only if option count doubles)
- Color options (already in a logically separate part of the panel — can be reviewed in a follow-up)

## Acceptance Criteria

1. Settings panel shows section headers (localized) above each group
2. Style-specific sections (Circular, Minimap Ring, Terminal) are hidden when a different style is active, shown when their style is selected
3. All 36 options remain reachable and functionally identical
4. `/xpbe options` and minimap button still open the panel correctly
5. No nil errors in Options.lua on panel open, barStyle change, or reload

## Implementation Notes

**Proposed sections** (from MQ-2 analysis in `docs/features/options-and-config.md`):

| Section | Count |
|---------|-------|
| Core | 3 |
| Secondary Bar | 3 |
| Minimap | 1 |
| XP Overlays | 5 |
| XP Text | 11 |
| Animations | 3 |
| Style: Circular *(conditional)* | 4 |
| Style: Minimap Ring *(conditional)* | 5 |
| Style: Terminal *(conditional)* | 1 |

**Option metadata change options**:
- Option A: Add a `section` field to each entry in `optionDetails`; `optionOrder` stays flat; `ControlHelpers.lua` tracks the current section name and emits a divider row when it changes
- Option B: Replace `optionOrder` with an `optionSections` array of `{label, keys[]}` tables; iteration is explicit and ordered

Option A is smaller scope; Option B is cleaner for long-term maintenance. Recommend B if time allows, otherwise A is sufficient.

**Conditional visibility pattern**:
```lua
-- In Options.lua, after all options are built:
local styleGroupMap = {
    circular    = { circularSize, circularSegments, circularUseTexture, circularScaleCenterText, circularHeader },
    minimap_ring = { ... },
    terminal    = { ... },
}
-- On barStyle change:
local function RefreshStyleVisibility(style)
    for groupStyle, widgets in pairs(styleGroupMap) do
        local shown = (groupStyle == style)
        for _, w in ipairs(widgets) do w:SetShown(shown) end
    end
    -- Trigger layout recalculation
    Options.panel:Layout()
end
```

## Files Affected

- `ui/options/OptionMetadata.lua` — restructure optionOrder or add section field
- `ui/options/OptionsPanel.xml` — may need minor layout adjustments for header rows
- `ui/options/OptionsPanelTemplates.xml` — add SectionDivider template
- `ui/options/ControlHelpers.lua` — emit section headers during option build
- `ui/options/Options.lua` — collect conditional groups, hook barStyle change to toggle visibility
- `locales/enUS.lua` — localization keys for section header labels

## Priority

P2 — Useful quality-of-life improvement; no functional regression risk; prerequisite for any future option expansion.
