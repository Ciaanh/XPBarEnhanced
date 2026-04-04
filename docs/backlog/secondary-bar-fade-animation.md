# Backlog: Secondary Bar Fade Animation

Priority: P2
Effort: Small
Risk: Low
Source: docs/secondary-bars-next-phase.md, docs/analysis/architecture-analysis.md

## Summary

Add fade-in/fade-out transitions to reputation and companion bars, matching Blizzard's status bar behavior. Bars should fade in when data arrives and fade out after an idle period.

Dependency: implement after shared secondary lifecycle/coalescing contract is in place.

## Motivation

Currently secondary bars snap between alpha 0 and alpha 1 when availability changes or data updates. This feels abrupt compared to the polished animation system on the primary XP bar.

## Scope

### In Scope

- Fade-in on data availability or reputation/companion gain.
- Fade-out after configurable idle delay (default ~5s).
- Bypass fade during config/unlock mode so the bar is always visible while repositioning.
- Shared fade utility usable by both reputation and companion bars.

### Out of Scope

- XP gain animations on secondary bars (separate backlog item if desired).
- Coalesced rendering (MarkDirty) — evaluate after fade is stable.

## Tasks

1. Create a shared fade helper (or reuse AnimationBase patterns) that wraps `AnimationGroup` + `Alpha` animation.
2. Wire fade-in into `FlatReputationBarStyle.Render()` and `FlatCompanionBarStyle.Render()` when `isAvailable` transitions from false→true or when gain data arrives.
3. Wire fade-out via `C_Timer.After(delay, ...)` that triggers when no new Render call arrives for the configured period.
4. Add `secondaryFadeDelay` config key to `defaults.lua` (default: 5.0).
5. Skip fade logic when bar is in unlocked/settings mode.
6. Cancel pending fade timers on `OnHide`.

## Affected Files

- ui/secondary/FlatReputationBarStyle.lua
- ui/secondary/FlatCompanionBarStyle.lua
- core/config/defaults.lua (new key)
- Optionally: new shared utility in ui/mixins/ or ui/secondary/

## Acceptance Criteria

- [ ] Reputation bar fades in smoothly when a new faction gain occurs.
- [ ] Reputation bar fades out after idle delay when no further updates arrive.
- [ ] Companion bar has identical fade behavior.
- [ ] Fade is bypassed during unlock/settings mode.
- [ ] No visual flicker on rapid consecutive updates.
- [ ] Timer cleanup on OnHide prevents orphaned callbacks.

## References

- Blizzard `StatusTrackingBarMixin` fade logic in BlizzardInterfaceCode.
- docs/secondary-bars-next-phase.md "Fade in / fade out effect" section.
- docs/memory/external-project-analysis.md item 3: "Transition polish should avoid direct alpha jumps."
