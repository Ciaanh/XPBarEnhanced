# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Release

**Build a release ZIP:**
```powershell
./make-release.ps1
```
Reads version from `XPBarEnhanced.toc`, stages addon files into an `XPBarEnhanced/` directory, and produces `.build/XPBarEnhanced-v<version>.zip`. There are no automated tests or lint steps — validation is manual, in-game.

**Version changes must stay consistent across all four locations:**
1. `XPBarEnhanced.toc` (`## Version:`)
2. `README.md`
3. `CHANGELOG.md`
4. `ui/changelog/Changelog.lua` (the in-game changelog popup)

## Target Platform

WoW Retail only — interface `120005` (Patch 12.0.5). All API usage must comply with Patch 12.0.0 constraints (see "WoW API Constraints" below).

## Architecture Overview

### Entry Point & Namespace

`XPBarEnhanced.lua` initializes the addon namespace and `EventNames` table. All module files extend it with:
```lua
local Addon = XPBarEnhanced
Addon.ModuleName = Addon.ModuleName or {}
```
No new globals. Shared state lives under `Addon.*` (e.g., `Addon.Session`, `Addon.Config`).

### Event Flow (End-to-End)

```
WoW Events
    → core/EventRouter.lua      (central WoW event registration — only place to register WoW events)
    → Domain handlers           (Session, ReputationSession, QuestXP)
    → core/EventBus.lua         (internal pub/sub — XPBAR_BROADCAST_UPDATE, REPUTATION_BROADCAST_UPDATE, CONFIG_UPDATED)
    → UI subscribers            (BarManager, options panel, stats window)
```

`EventBus` prevents re-entrancy during dispatch. UI components subscribe with:
```lua
local handle = EventBus:RegisterWithHandle(eventName, handler)
-- handle() to unregister
```

### Load Order (TOC is authoritative)

The `XPBarEnhanced.toc` defines strict runtime load order — respect it when adding files:
1. Libraries (LibStub, AceLocale-3.0)
2. Localization (`locales/enUS.lua`)
3. Core namespace + defaults (`XPBarEnhanced.lua`, `core/config/defaults.lua`)
4. Lifecycle, commands, utils, EventBus, EventRouter
5. Calculation modules (`XP`, `Time`, `Reputation`)
6. Services (`Session`, `Database`, `Config`, `ContextBuilder`)
7. UI entry (`MinimapButton`)
8. Mixins (`ui/mixins/` — Base → Secondary → Layout → Paint → Display → Text → Interaction → Tooltip → Position → Animation*)
9. Style system (`StyleBuilder`, `BarManager`, `SecondaryBarManager`, helpers)
10. XML templates and concrete style implementations

### Configuration System

Three-layer wiring — all four must be present for a new setting to work:
1. `core/config/defaults.lua` — default value
2. Config accessor/helper in `core/Config.lua`
3. Options UI control (options panel)
4. Runtime consumer code

Changes broadcast via `CONFIG_UPDATED` on EventBus. Per-character data stored in `XPBarEnhancedDB` under player realm key.

### Style System

Seven bar styles: `flat`, `classic`, `vertical`, `circular`, `minimap_ring`, `terminal`, `none`.

`StyleBuilder` composes mixins (LayoutMixin, PaintMixin, DisplayMixin, TextMixin, InteractionMixin, TooltipMixin, PositionMixin, AnimationManager) into registered style objects. `BarManager` switches styles via `SetStyle(styleName)` — creates/destroys frames. Secondary bars mirror this via `SecondaryBarManager`.

Each style declares **capabilities** (`statusBar`, `overlays`, `textOnBar`, `barColors`, etc.) so consumers know what features are available. Style render paths must degrade gracefully when optional helpers are unavailable — no hard errors from style code.

### Session Tracking

- `Session` — XP gained, time played, levels, quest XP breakdown (with 0.5s cache TTL)
- `ReputationSession` — watched faction/companion data
- Both persist in `XPBarEnhancedDB`; reset behavior controlled by `resetOnReload` config

## Coding Rules

- **WoW event registration belongs only in `core/EventRouter.lua`.** Never scatter `RegisterEvent` calls across other modules.
- **Use EventBus for UI refresh paths**, not direct cross-module calls.
- **Prefer targeted fixes over broad rewrites.** Match existing patterns unless explicitly asked to change behavior.
- **No polling with `OnUpdate`** unless truly required — throttle aggressively.
- **Taint and combat-lockdown safety are design-time constraints**, not post-fix bugs.
- **Simplest solution wins.** No extra timers, retries, indirection, or abstraction layers without demonstrated need.
- **Verify APIs before using them.** Do not assume legacy behavior from pre-12.x.

## WoW API Constraints (Patch 12.0.0+)

### Secret Values

Many APIs that previously returned plain numbers/strings now return **secret values** that tainted addon code cannot inspect. Violations produce immediate Lua errors.

**Tainted code cannot:**
- Compare or branch on secrets (`if secret then`, `secret == x`, `secret < x`)
- Do arithmetic on secrets (`secret + 1`)
- Use secrets as table keys
- Use `#secret` (length operator)

**Tainted code can:**
- Store secrets in variables/tables (as values, not keys)
- Pass secrets to widget APIs that accept them (e.g., `StatusBar:SetValue()`, `FontString:SetText()`)
- Concatenate secret strings/numbers

```lua
-- WRONG — errors in 12.0.0:
local hp = UnitHealth("target")
if hp < 0.3 * UnitHealthMax("target") then ... end

-- CORRECT — pass directly to widget:
healthBar:SetMinMaxValues(0, UnitHealthMax("target"))
healthBar:SetValue(UnitHealth("target"))
```

### Combat Log

`COMBAT_LOG_EVENT_UNFILTERED` and `CombatLogGetCurrentEventInfo()` are **no longer available to addons**. Do not use them.

### Removed APIs

Use `C_Spell.*` instead of old global spell functions (`GetSpellInfo`, `GetSpellCooldown`, etc.). Use `C_Log.LogMessage()` instead of `ConsolePrint()`. See `.github/instructions/wow-api-important.instructions.md` for the full removal list.

### Instance Restrictions

`SendAddonMessage()` is blocked inside instances. Addons must function without inter-player communication during instanced content.
