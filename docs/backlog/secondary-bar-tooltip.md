# Backlog: Secondary Bar Tooltip

Priority: P2
Effort: Small
Risk: Low
Source: docs/secondary-bars-next-phase.md, docs/analysis/reference-addon-comparison.md

## Summary

Add GameTooltip on hover for reputation and companion bars, showing session gains, rate, and estimated time to next standing/level.

Dependency: implement after shared secondary lifecycle contract so tooltip hooks are not duplicated per style.

## Motivation

The primary XP bar has a rich multi-section tooltip (via TooltipMixin) showing XP, rested, quest, and session data. The secondary bars display only on-bar text with no tooltip. Users hovering the bar get no additional context.

## Scope

### In Scope

- Reputation bar tooltip: faction name, standing, progress, session gained, rep/hour, time to next standing.
- Companion bar tooltip: companion name, level, progress, session gained, XP/hour, time to next level.
- Anchor-aware positioning (ANCHOR_TOP/BOTTOM based on screen position, same as TooltipMixin).
- Consistent formatting via TextFormatter.

### Out of Scope

- Tooltip for primary XP bar (already implemented).
- Click actions from the tooltip.

## Tasks

1. Add `OnEnter` / `OnLeave` scripts to `FlatReputationBarTemplate.xml` and `FlatCompanionBarTemplate.xml`.
2. In `FlatReputationBarStyle.lua`, implement `OnEnter` handler that reads the last rendered context and populates `GameTooltip` with reputation details.
3. In `FlatCompanionBarStyle.lua`, implement matching `OnEnter` handler for companion data.
4. Reuse `TooltipMixin:GetBestAnchor()` logic (or extract it as a shared utility) for anchor positioning.
5. Use `TextFormatter` for number and time formatting in tooltip lines.
6. Hide tooltip on `OnLeave`.

## Affected Files

- ui/secondary/FlatReputationBarStyle.lua
- ui/secondary/FlatReputationBarTemplate.xml
- ui/secondary/FlatCompanionBarStyle.lua
- ui/secondary/FlatCompanionBarTemplate.xml

## Acceptance Criteria

- [ ] Hovering the reputation bar shows a tooltip with faction name, standing, progress %, session gained, rep/hour, and time to next standing.
- [ ] Hovering the companion bar shows a tooltip with companion name, level, progress %, session gained, XP/hour, and time to next level.
- [ ] Tooltip anchors correctly based on bar screen position.
- [ ] Tooltip disappears on mouse leave.
- [ ] Tooltip updates if the bar re-renders while hovered.
