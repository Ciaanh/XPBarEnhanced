# XP Bar Enhanced - Implementation Roadmap

## Overview

This document is the master index for all planned improvements to XPBarEnhanced, organized by priority. Each improvement has its own detailed guide with implementation steps, debug logging instructions, manual testing checklists, and validation gates.

**Branch:** `dev/next`
**Source:** Analysis of Blizzard's UI code in `BlizzardInterfaceCode/` compared against the addon's current implementation.

---

## How to Use This Roadmap

1. **Follow steps in order** — Each step has dependencies listed. Complete validation gates before moving to the next step.
2. **Enable debug logging** — Run `/run XPBarEnhancedDB.debugMode = true` then `/reload` to see debug prints in chat.
3. **Test after each step** — Each guide has a manual testing checklist. Complete all items before proceeding.
4. **Validation gates are mandatory** — If ANY gate check fails, fix it before moving on.

---

## Dependency Graph

```
Step 1.1 ──→ Step 1.3
   │
   ├──→ Step 1.2 ──→ Step 2.2
   │         │
   │         └──→ Step 2.3
   │
   └──→ Step 3.1
        Step 3.2
        Step 3.3

Step 2.1 (independent)
Bonus (after all core steps)
```

---

## Step 1: High Priority

These fix correctness issues that affect users today.

| # | Title | File | Description |
|---|-------|------|-------------|
| [1.1](step1-high-priority/1.1-blizzard-bar-hiding.md) | Blizzard Bar Hiding | `ui/BarManager.lua`, `core/AddOnLifecycle.lua` | Install `hooksecurefunc` on both containers to prevent Blizzard's bar from re-showing. Remove `C_Timer.After` workaround. |
| [1.2](step1-high-priority/1.2-missing-events-apis.md) | Missing Events & APIs | `core/AddOnLifecycle.lua`, `ui/BarManager.lua`, `ui/mixins/BaseMixin.lua`, `core/services/ContextBuilder.lua` | Register `PLAYER_MAX_LEVEL_UPDATE`, use `IsPlayerAtEffectiveMaxLevel()`, check `IsXPUserDisabled()`, register `CVAR_UPDATE`. |
| [1.3](step1-high-priority/1.3-secondary-bar-container.md) | Secondary Bar Container | `ui/mixins/PositionMixin.lua`, `ui/BarManager.lua` | Handle `SecondaryStatusTrackingBarContainer` properly, fix STATIC positioning when containers are hidden. |

**Estimated scope:** 4 files modified, ~100 lines of code

---

## Step 2: Medium Priority

These improve the user experience with polish and better integration.

| # | Title | File | Description |
|---|-------|------|-------------|
| [2.1](step2-medium-priority/2.1-animation-accumulation.md) | Animation Accumulation | `ui/mixins/animation/AnimationManager.lua`, `ui/mixins/animation/AnimationUtils.lua` | Add 150ms accumulation timeout to batch rapid XP gains into a single smooth animation. |
| [2.2](step2-medium-priority/2.2-levelup-hold-polish.md) | Level-Up Hold & Polish | `ui/mixins/animation/AnimationManager.lua`, `ui/mixins/animation/AnimationUtils.lua`, `core/services/ContextBuilder.lua` | Fix PLAYER_LEVEL_UP context suppression, add 400ms hold at 100% before Phase 2. |
| [2.3](step2-medium-priority/2.3-cvar-xpbartext.md) | CVar xpBarText | `ui/mixins/TextMixin.lua` | Respect Blizzard's `xpBarText` CVar as a master toggle for on-bar text. |

**Estimated scope:** 4 files modified, ~80 lines of code

---

## Step 3: Low Priority

These add new features and improve native integration.

| # | Title | File | Description |
|---|-------|------|-------------|
| [3.1](step3-low-priority/3.1-reputation-bar.md) | Reputation Bar | New: `core/services/ReputationService.lua`, `ui/styles/reputation/` | Add reputation bar support for max-level characters (standard, major factions, friendships, paragon). |
| [3.2](step3-low-priority/3.2-edit-mode.md) | Edit Mode Integration | New: `ui/EditModeIntegration.lua` | Make bars movable via WoW's native Edit Mode system. |
| [3.3](step3-low-priority/3.3-classic-atlas-textures.md) | Atlas Textures | `ui/mixins/PaintMixin.lua` | Optional Blizzard atlas textures for authentic visual style. |

**Estimated scope:** 3 new files, 3 files modified, ~200 lines of code

---

## Bonus

| # | Title | File | Description |
|---|-------|------|-------------|
| [Bonus](bonus/segmented-bar-style.md) | Segmented Bar Style | New: `ui/styles/segmented/` | New bar style that divides XP into discrete segments for granular progress visualization. |

**Estimated scope:** 2 new files, 3 files modified, ~200 lines of code

---

## Files Modified Summary

### Core files touched across all steps:

| File | Steps |
|------|-------|
| `ui/BarManager.lua` | 1.1, 1.2, 1.3, 3.1, Bonus |
| `core/AddOnLifecycle.lua` | 1.1, 1.2, 3.1, 3.2 |
| `ui/mixins/BaseMixin.lua` | 1.2 |
| `core/services/ContextBuilder.lua` | 1.2, 2.2 |
| `ui/mixins/PositionMixin.lua` | 1.3 |
| `ui/mixins/animation/AnimationManager.lua` | 2.1, 2.2 |
| `ui/mixins/animation/AnimationUtils.lua` | 2.1, 2.2 |
| `ui/mixins/TextMixin.lua` | 2.3 |
| `ui/mixins/PaintMixin.lua` | 3.3 |
| `core/config/defaults.lua` | 3.1, 3.3, Bonus |
| `ui/options/OptionMetadata.lua` | 3.1, 3.3, Bonus |
| `locales/enUS.lua` | 3.1, 3.3, Bonus |
| `XPBarEnhanced.toc` | 3.1, 3.2, Bonus |

### New files created:

| File | Step |
|------|------|
| `core/services/ReputationService.lua` | 3.1 |
| `ui/styles/reputation/ReputationBarStyle.lua` | 3.1 |
| `ui/EditModeIntegration.lua` | 3.2 |
| `ui/styles/segmented/SegmentedBarStyle.lua` | Bonus |
| `ui/styles/segmented/SegmentedBarTemplate.xml` | Bonus |

---

## Debug Mode

All steps include debug logging gated by `debugMode`. To enable:

```
/run XPBarEnhancedDB.debugMode = true
/reload
```

To disable:
```
/run XPBarEnhancedDB.debugMode = false
/reload
```

Debug output appears as green `[XPBarEnhanced]` messages in the default chat window.

---

## Quick Start

1. Switch to branch `dev/next`
2. Open [Step 1.1](step1-high-priority/1.1-blizzard-bar-hiding.md)
3. Follow the implementation steps
4. Run through the manual testing checklist
5. Verify all validation gate items pass
6. Move to Step 1.2
