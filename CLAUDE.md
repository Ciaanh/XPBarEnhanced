# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Release

**Build a release ZIP:**
```powershell
./make-release.ps1
```
Reads version from `XPBarEnhanced.toc`, stages addon files into an `XPBarEnhanced/` directory, and produces `.build/XPBarEnhanced-v<version>.zip`. There are no automated tests or lint steps — behavioural validation is manual, in-game.

**The mechanical gate is not optional and it is not conditional.** Lua 5.1.5 is installed at `C:\Program Files (x86)\Lua\5.1\` with both `lua.exe` and `luac.exe` on PATH, so run `luac -p <file>` on every touched Lua file before considering a change done. Never syntax-check with `lua5.4` — 5.4 accepts syntax the 5.1 client rejects, so a 5.4 pass is false confidence.

The workspace harness at `d:\Dev\WoW\_Workspace\tools\harness.ps1` wraps this and adds the check no manual command can do — walking the TOC load graph to catch a file that is on disk but never loaded:

```powershell
./tools/harness.ps1 check   -Addon XPBarEnhanced   # load graph + XML well-formedness + luac -p over every file
./tools/harness.ps1 version -Addon XPBarEnhanced   # the four version locations below must agree
```

Since this addon has no test suite, `check` is the only automated verification that runs anywhere outside a release tag.

**Publish:** pushing a `v*` tag triggers `.github/workflows/release.yml` (BigWigs packager), which packages per `.pkgmeta` and publishes to CurseForge, WoWInterface, and GitHub Releases (project IDs come from the TOC; changelog from `CHANGELOG.md`; requires the `CF_API_KEY`/`WOWI_API_TOKEN` repo secrets).

Feature/style proposals and their impact studies live in `ROADMAP.md`.

Assets (`orb_*`, `border`, `center`, `glow`, `tick*`, `xp-bar`) are hand-authored, with their sources as `.pdn`/`.xcf` in `assets/raw/`. `assets/raw` and `refs` are excluded from the package by both `.pkgmeta` and `make-release.ps1`, so sources ship to neither CurseForge nor the zip.

**This branch (`release/1.3.0-no-sigil`) does not carry the Sigil style.** It was cut from `feat/options-honesty` and had `ui/styles/sigil/`, its 43 generated TGAs and `assets/raw/generate_sigil.py` removed, so 1.3.0 ships the XP-accounting and Circular work without the style. Sigil development continues on `feat/options-honesty`; do not re-add it here — merge or re-cut instead.

**Version changes must stay consistent across all four locations:**
1. `XPBarEnhanced.toc` (`## Version:`)
2. `README.md`
3. `CHANGELOG.md`
4. `ui/changelog/Changelog.lua` (the in-game changelog popup)

## Target Platform

WoW Retail only — interface `120100` (Patch 12.1). All API usage must comply with Patch 12.0.0 constraints (see "WoW API Constraints" below).

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
    → Domain handlers           (Session, ReputationSession, HousingSession, HonorSession,
                                 ProfessionSession, QuestXP, GoalTracker)
    → core/EventBus.lua         (internal pub/sub — XPBAR_BROADCAST_UPDATE, REPUTATION_BROADCAST_UPDATE,
                                 HOUSING_BROADCAST_UPDATE, QUESTS_CACHE_INVALIDATED/REBUILT,
                                 CONFIG_UPDATED, COLORS_UPDATED, PROFILE_CHANGED/PROFILES_UPDATED)
    → UI subscribers            (BarManager, SecondaryBarManager, options panel, stats window,
                                 ui/DataBrokerFeed.lua)
```

Bars repaint from the domain broadcasts (`XPBAR/REPUTATION/HOUSING_BROADCAST_UPDATE`) and `CONFIG_UPDATED`. `COLORS_UPDATED` only drives the options-panel color swatches — to repaint bars after a color change, also emit the domain updates (see `Colors:NotifyColorsChanged`).

`EventBus` dispatches over a snapshot, so handlers may safely register/unregister during dispatch. UI components subscribe with:
```lua
local handle = EventBus:RegisterWithHandle(eventName, handler)
-- handle.Unregister() to unregister
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

Four-layer wiring — all four must be present for a new setting to work:
1. `core/config/defaults.lua` — default value
2. Config accessor/helper in `core/config/Config.lua`
3. Options UI control (options panel)
4. Runtime consumer code

**Always read options through `Config:GetOptionValue(key)`** (resolves active profile → global → defaults) — never raw `Addon.db.<key>` reads, which silently ignore profile overrides.

Changes broadcast via `CONFIG_UPDATED` on EventBus. Batching: `Config:SetOptionKey(key, value, true)` defers side effects into `_pendingOptionKeys`; a following `Config:ApplyPendingOptionChanges()` applies them and emits exactly one `CONFIG_UPDATED`.

Storage in `XPBarEnhancedDB`: options are global with optional named profiles layered on top (`ProfileManager`); session data is per character, keyed by `Database:GetPlayerKey()` (`"Name-Realm"`) — always access it through `Database:GetSessionData()` / `GetReputationSessionData()` / `GetHousingSessionData()`, never the raw `db.sessionData` table.

### Style System

Eight bar styles: `flat`, `classic`, `vertical`, `circular`, `minimap_ring`, `terminal`, `orb`, plus `none`.

`StyleBuilder` composes mixins (LayoutMixin, PaintMixin, DisplayMixin, TextMixin, InteractionMixin, TooltipMixin, PositionMixin, AnimationManager) into registered style objects. `BarManager` switches styles via `SetStyle(styleName)` — frames are cached per style and hidden/reused, never destroyed (WoW frames cannot be garbage-collected). `OnShow`/`OnHide` in `BaseMixin` own the EventBus subscription lifecycle. Secondary bars mirror this via `SecondaryBarManager`.

Each style declares **capabilities** (`statusBar`, `overlays`, `textOnBar`, `barColors`, etc.) so consumers know what features are available. Style render paths must degrade gracefully when optional helpers are unavailable — no hard errors from style code.

### Session Tracking

- `Session` — XP gained, time played, levels, quest XP breakdown (with 0.5s cache TTL)
- `ReputationSession` — watched faction/companion data (wrap-aware gains across renown levels and paragon cycles)
- `HousingSession` — tracked-house favor progress (favor is cumulative across house levels; only credit deltas from the tracked house's GUID)
- `HonorSession` — honor progress and honor-level gains
- `ProfessionSession` — tracked-profession skill progress
- `GoalTracker` — user-set goals evaluated against the sessions above
- The four secondary-bar sources are Reputation / Housing Favor / Honor / Profession — `SecondaryBarManager` picks between them.
- All persist per character in `XPBarEnhancedDB` (via the `Database` getters). Reset semantics: initial login always starts a fresh session; `/reload` resets only when the `resetOnReload` option is enabled.
- Level-boundary accounting is subtle: `PLAYER_LEVEL_UP` and `PLAYER_XP_UPDATE` can arrive in either order and `UnitLevel`/`UnitXP` can lag the event. `Session:OnLevelUp` credits the old-level remainder only when `session.lastXP > UnitXP("player")` (unambiguous stale baseline) — preserve this guard when touching XP accounting, or gains get dropped or double-counted.

## Coding Rules

- **WoW event registration belongs only in `core/EventRouter.lua`.** Never scatter `RegisterEvent` calls across other modules.
- **Use EventBus for UI refresh paths**, not direct cross-module calls.
- **Prefer targeted fixes over broad rewrites.** Match existing patterns unless explicitly asked to change behavior.
- **No polling with `OnUpdate`** unless truly required — throttle aggressively.
- **Taint and combat-lockdown safety are design-time constraints**, not post-fix bugs. To hide a Blizzard container during combat, use `Utils.SafeHideContainer(container, predicate)` — it defers to `PLAYER_REGEN_ENABLED` on one shared frame (frames are never GC'd, so never allocate one per call) and re-checks the predicate at combat end so a stale request cannot hide a bar that should be visible again.
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
