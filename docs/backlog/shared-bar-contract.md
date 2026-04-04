# Backlog: Shared Bar Contract (Mixin Unification)

Priority: P1
Effort: Medium
Risk: Medium
Source: docs/analysis/architecture-analysis.md §3.6

## Summary

Unify the primary XP bar lifecycle contract (BaseMixin with OnLoad/OnShow/OnHide/MarkDirty/TriggerBarRefresh/RenderBar) and the secondary bar contract (direct OnLoad/OnShow/OnHide/Render) into a shared base that supports coalescing, animations, and consistent lifecycle management.

This is the architecture-enabler for secondary bar polish tasks and should land before further secondary-bar UX work.

## Motivation

Primary bars use BaseMixin with: dirty-mark coalescing, animation support, text ticker, position persistence, and Edit Mode awareness. Secondary bars use a separate, simpler contract with no coalescing, no animation, and hard-coded lifecycle methods.

Adding features like fade animations, tooltip, or drag-to-move to secondary bars means re-implementing infrastructure that BaseMixin already provides. A shared base contract would:
- Reduce code duplication when adding polish to secondary bars.
- Make it easier to create new bar types (e.g., honor bar, artifact power bar).
- Ensure consistent lifecycle behavior across all bars.

## Scope

### In Scope

- Extract a "BarFrameMixin" or "BarBaseMixin" from BaseMixin that provides: OnLoad, OnShow (EventBus sub + ticker), OnHide (unsub + ticker cancel), MarkDirty, position save/restore.
- Secondary bar styles adopt this shared base instead of their ad-hoc lifecycle.
- Domain-specific rendering remains in style-specific mixins (`Render` method).

### Out of Scope

- Merging BarManager and SecondaryBarManager.
- Changing the EventBus or context builder patterns.
- Full visual redesign of existing styles.

## Tasks

1. Audit BaseMixin to identify which behaviors are XP-specific vs generic.
2. Extract generic lifecycle mixin (subscribe/unsubscribe, dirty-mark, position, ticker).
3. Refactor secondary bar styles to inherit from the shared mixin.
4. Verify all existing behavior is preserved.
5. Document the shared bar contract in code comments.

## Affected Files

- ui/mixins/BaseMixin.lua (extract generic parts)
- New: ui/mixins/BarBaseMixin.lua (or rename)
- ui/secondary/FlatReputationBarStyle.lua
- ui/secondary/FlatCompanionBarStyle.lua

## Acceptance Criteria

- [ ] Secondary bars use the same lifecycle hooks as primary bars.
- [ ] MarkDirty coalescing is available to secondary bars.
- [ ] Text ticker is available to secondary bars.
- [ ] No regressions in primary bar behavior.
- [ ] Adding a new bar type requires only a Render method and event name.

## References

- docs/analysis/architecture-analysis.md §3.6 "No shared bar frame contract."
