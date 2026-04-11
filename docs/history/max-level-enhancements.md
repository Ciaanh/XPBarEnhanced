# Backlog: Max Level Enhancements

Status: Completed (Phase 7 Slice 3)
Priority: P2
Effort: Small
Risk: Low
Source: feature gap analysis

## Summary

Preserve and validate the max-level behavior contract: hide the primary XP bar at cap while allowing secondary reputation/companion bars to remain style-driven and visible when configured.

## Motivation

At max level, the XP bar is not useful for level progression. Players may want the bar to:

- Show reputation progress instead of XP.
- Show a celebration/completed state.
- Auto-switch to a secondary bar.
- Hide completely.

## Scope

### In Scope

- Add `maxLevelBehavior` options: "always_show", "show_reputation", "hide", "show_rested_only".
- When "show_reputation", primary bar slot renders the watched faction reputation data (reusing reputation context).
- When "hide", bar is hidden at max level.
- When "show_rested_only", show the rested XP overlay only (useful for tracking rested accumulation at cap).

### Out of Scope

- Automatic style switching at max level.
- Honor/conquest bar integration (PvP-specific).

## Tasks

1. Expand `maxLevelBehavior` dropdown options in `OptionMetadata.lua`.
2. In `BarManager`, after detecting max level, apply the chosen behavior.
3. For "show_reputation": build reputation context and feed it to the primary bar render path (requires adapter).
4. For "hide": `SetShown(false)` and restore Blizzard bar.
5. For "show_rested_only": render bar with only rested overlay, no XP fill.
6. Add locale strings for new options.

## Affected Files

- core/config/defaults.lua (expand maxLevelBehavior values)
- ui/BarManager.lua
- ui/options/OptionMetadata.lua
- locales/enUS.lua

## Acceptance Criteria

- [x] At max level, primary custom XP bar is hidden.
- [x] Blizzard primary tracking bar visibility is restored.
- [x] Level-up to max triggers primary-bar hide behavior.
- [x] Behavior applies correctly on login/reload.
- [x] Secondary reputation/companion bars remain visible when their styles are enabled.
