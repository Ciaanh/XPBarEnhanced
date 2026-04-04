# XPBarEnhanced — Architecture & Lifecycle Analysis

> Produced April 2026 from full codebase read of `feature/reputation-companion-analysis` branch.

---

## 1. Global Initialization Sequence

```
TOC load order
──────────────
libs/LibStub  →  libs/AceLocale  →  locales/enUS.lua
                                          │
                                     XPBarEnhanced.lua   ← namespace + EventNames + module stubs
                                          │
                              defaults.lua  → Config.lua / ConfigHelper.lua
                              AddOnLifecycle.lua  → AddOnCommands.lua
                              Utils.lua  → Colors.lua
                              XPCalculations / TimeCalculations / ReputationCalculations / CompanionCalculations
                              QuestXP.lua  → TextFormatter.lua  → EventBus.lua
                              Database.lua  → Session.lua  → ReputationSession.lua  → CompanionSession.lua
                              ContextBuilder.lua
                                          │
                              UI chain: MinimapButton → mixins → StyleBuilder → BarManager
                                         SecondaryBarManager
                                         Options chain
                                         Stats chain
                                         Style templates (XML + Lua per style)
                                         Secondary templates (XML + Lua)
```

### WoW Event → Lifecycle Handler Mapping

| WoW Event | Lifecycle Handler | What Happens |
|---|---|---|
| `ADDON_LOADED` | `OnAddonLoaded` | Database:Initialize(), Config:Initialize(), sets Addon.db |
| `PLAYER_LOGIN` | `OnPlayerLogin` | Session:Init, RepSession:Init, CompSession:Init, BarManager:Init, SecondaryBarManager:Init, MinimapButton:Init, Options:Init |
| `PLAYER_ENTERING_WORLD` | `OnPlayerEnteringWorld` | Session/RepSession/CompSession:OnEnteringWorld, QuestXP invalidate, EventBus broadcast, SecondaryBarManager:OnEnteringWorld, deferred Blizzard bar visibility |
| `PLAYER_LEVEL_UP` | `OnPlayerLevelUp` | Session:OnLevelUp (cascade to QuestXP, BarManager, Stats, broadcast) |
| `PLAYER_LOGOUT` | `OnPlayerLogout` | broadcast / Shutdown |

---

## 2. The Three Independent Data Pipelines

The addon has **three parallel data domains**, each with its own session service, event sources, context builder, and UI consumer:

### Pipeline A — XP Bar (primary)

```
External WoW Events                     Session Service                  Context Builder           UI Consumer
─────────────────                        ───────────────                  ───────────────           ───────────
PLAYER_XP_UPDATE        ──→  Session:OnXPUpdate()     ──→  EventBus:Emit(XPBAR_BROADCAST_UPDATE)
TIME_PLAYED_MSG         ──→  Session:OnTimePlayed()   ──→  (updates session.realLevelTime)
QUEST_TURNED_IN         ──→  Session:OnQuestTurnedIn()──→  EventBus:Emit(XPBAR_BROADCAST_UPDATE)
QUEST_LOG_UPDATE        ──→  Session:RefreshTimes()
UPDATE_EXHAUSTION       ──→  Session:OnRestedChanged()──→  EventBus:Emit(XPBAR_BROADCAST_UPDATE)
PLAYER_UPDATE_RESTING   ──→  "                                                                      │
                                                                                                     ↓
                              On XPBAR_BROADCAST_UPDATE ──→  BaseMixin:MarkDirty(ctx)
                              (no context provided)    ──→  ContextBuilder.BuildContext("XPBAR:...")
                                                             reads UnitXP, Session, QuestXP
                                                             produces immutable context w/ config
                                                       ──→  TriggerBarRefresh(context)
                                                             → animation / RenderBar / overlays / text
```

**Key property:** `XPBAR_BROADCAST_UPDATE` is emitted with **nil context** by Session. The `EventBus:Emit` path then calls `ContextBuilder.BuildContext()` **on the receiver side** (inside EventBus:Emit when context==nil). This means the context is built once per emit — but all listeners see the **same** context object built at emit time.

### Pipeline B — Reputation Bar (secondary)

```
External WoW Events                     Session Service                  Context Builder           UI Consumer
─────────────────                        ───────────────                  ───────────────           ───────────
UPDATE_FACTION          ──→  RepSession:OnFactionUpdate()
CHAT_MSG_COMBAT_FACTION ──→  RepSession:OnFactionUpdate()   ── idempotent (delta-based)
MAJOR_FACTION_RENOWN    ──→  RepSession:OnRenownLevelChanged()
                                   │
                                   ↓
                              EventBus:Emit(REPUTATION_BROADCAST_UPDATE, self:_BuildContext())
                              ↑ emits WITH a pre-built internal context                          │
                                                                                                  ↓
                              FlatReputationBarMixin (EventBus listener)
                              handler: IGNORES the emitted context and calls
                                       XPBarContextBuilder.BuildReputationContext()
                              ──→  Render(flatContext)
```

### Pipeline C — Companion Bar (secondary)

```
External WoW Events                     Session Service                  Context Builder           UI Consumer
─────────────────                        ───────────────                  ───────────────           ───────────
UPDATE_FACTION          ──→  CompSession:OnFactionUpdate()
DELVES_ACCOUNT_DATA     ──→  CompSession:OnFactionUpdate()
                                   │
                                   ↓
                              EventBus:Emit(COMPANION_BROADCAST_UPDATE, self:_BuildContext())
                              ↑ emits WITH pre-built internal context                            │
                                                                                                  ↓
                              FlatCompanionBarMixin (EventBus listener)
                              handler: IGNORES the emitted context and calls
                                       XPBarContextBuilder.BuildCompanionContext()
                              ──→  Render(flatContext)
```

---

## 3. Architectural Inconsistencies

### 3.1 Context build location is inconsistent across pipelines

| Pipeline | Who builds the render context? | Where? |
|---|---|---|
| **XP** | `EventBus:Emit` itself | Inside `EventBus.lua` line ~140 — when context==nil, calls `BuildContext()`. All listeners receive the same object. |
| **Reputation** | The UI consumer | `FlatReputationBarStyle.lua` — handler receives `_BuildContext()` but **discards** it, re-builds from scratch via `BuildReputationContext()` |
| **Companion** | The UI consumer | Same pattern as Reputation |

**Problem:** The secondary bars receive a session-internal context they don't use, then make a redundant API call to rebuild a flat context. The `_BuildContext()` call in the session Emit is wasted work.

### 3.2 The XP pipeline conflates "something changed" with "here is the new state"

`XPBAR_BROADCAST_UPDATE` carries **no domain-specific payload**. It's a pure notification signal — the context is built lazily inside `EventBus:Emit` or by each listener.

The secondary pipelines carry a payload but it's **discarded**.

Neither approach is bad on its own, but having both patterns in the same EventBus is confusing and makes it unclear what contract a listener should follow.

### 3.3 Session services own WoW event frames; AddOnLifecycle also owns one

There are **5 independent `CreateFrame("Frame")` + RegisterEvent** sites:

| Owner | Events Registered |
|---|---|
| `AddOnLifecycle.lua` | ADDON_LOADED, PLAYER_LOGIN, PLAYER_ENTERING_WORLD, PLAYER_LEVEL_UP, ENABLE/DISABLE_XP_GAIN, PLAYER_LOGOUT, PLAYER_MAX_LEVEL_UPDATE |
| `Session.lua` | PLAYER_XP_UPDATE, TIME_PLAYED_MSG, QUEST_TURNED_IN, QUEST_LOG_UPDATE, UPDATE_EXHAUSTION, PLAYER_UPDATE_RESTING |
| `ReputationSession.lua` | UPDATE_FACTION, CHAT_MSG_COMBAT_FACTION_CHANGE, MAJOR_FACTION_RENOWN_LEVEL_CHANGED |
| `CompanionSession.lua` | UPDATE_FACTION, DELVES_ACCOUNT_DATA_ELEMENT_CHANGED |
| `QuestXP.lua` | QUEST_LOG_UPDATE, QUEST_DATA_LOAD_RESULT, PLAYER_ENTERING_WORLD, PLAYER_LEVEL_UP, ZONE_CHANGED_NEW_AREA, UNIT_QUEST_LOG_CHANGED, QUEST_TURNED_IN |

**Overlap:** `UPDATE_FACTION` is registered by both ReputationSession and CompanionSession. `QUEST_LOG_UPDATE` is registered by both Session and QuestXP. `PLAYER_ENTERING_WORLD` and `PLAYER_LEVEL_UP` and `QUEST_TURNED_IN` are registered by both AddOnLifecycle/Session and QuestXP.

This is not a bug — each handler does different work — but it makes the event flow hard to trace and risks redundant broadcasts (e.g. QuestXP fires XPBAR_BROADCAST_UPDATE from its scheduled rebuild, while Session:OnQuestTurnedIn also fires XPBAR_BROADCAST_UPDATE).

### 3.4 Context is rebuilt from scratch on every render

`BuildContext()` calls: `UnitXP`, `UnitXPMax`, `UnitLevel`, `GetXPExhaustion`, `IsResting`, `Session:GetCurrent`, `QuestXP:GetQuestXP`, plus `BuildDBConfig()` which copies ~20 db keys.

This happens on every `XPBAR_BROADCAST_UPDATE` emit. For rested ticks or quest log updates that fire rapidly, this is more work than needed.

### 3.5 SecondaryBarManager duplicates lifecycle patterns

`SecondaryBarManager` manually does `SetShown(true/false)` and `xpcall(frame.Render, ...)` in `OnEnteringWorld`, duplicating logic that could be handled by the bar frames' own `OnShow`/`OnHide` scripts (which already register for EventBus events).

### 3.6 No shared "bar frame" contract

The XP bars use `BaseMixin` with: `OnLoad`, `OnShow` (EventBus subscribe), `OnHide` (unsubscribe), `MarkDirty` (coalesced next-frame render), `TriggerBarRefresh` (animation/immediate dispatch), `RenderBar` (final paint).

The secondary bars use a completely separate contract: `OnLoad`, `OnShow` (EventBus subscribe + immediate render), `OnHide` (unsubscribe), `Render` (direct paint, no coalescing, no animation support).

Both contracts are correct, but adding features like fade animations or tooltip to secondary bars means re-implementing the same infrastructure that `BaseMixin` already provides.

---

## 4. Proposed Streamlined Architecture

### Goal: Unified "bar pipeline" with domain-specific data sources

```
┌─────────────────────────────────────────────────────────────────────┐
│  LAYER 1: External Event Router (single frame)                      │
│  ─────────────────────────────────────────────────────────────────── │
│  One CreateFrame registers ALL external WoW events.                 │
│  Routes each event to the correct domain handler(s).                │
│  No EventBus interaction — just method dispatch.                    │
│                                                                     │
│  PLAYER_XP_UPDATE        → SessionManager.OnXPUpdate()              │
│  UPDATE_FACTION           → ReputationManager.OnFactionUpdate()     │
│                           → CompanionManager.OnFactionUpdate()      │
│  QUEST_TURNED_IN          → SessionManager.OnQuestTurnedIn()        │
│                           → QuestXPCache.OnQuestTurnedIn()          │
│  etc.                                                               │
└─────────────────────────────────────────────────────────────────────┘
                    │                │                    │
                    ↓                ↓                    ↓
┌──────────────┐ ┌──────────────┐ ┌──────────────────────┐
│ XP Session   │ │ Rep Session  │ │ Companion Session    │
│ (data only)  │ │ (data only)  │ │ (data only)          │
│ No frames    │ │ No frames    │ │ No frames            │
│ No events    │ │ No events    │ │ No events            │
│ Pure state   │ │ Pure state   │ │ Pure state           │
└──────┬───────┘ └──────┬───────┘ └──────────┬───────────┘
       │                │                     │
       │  Each session's Update method returns a "did change" flag
       │                │                     │
       ↓                ↓                     ↓
┌─────────────────────────────────────────────────────────────────────┐
│  LAYER 2: Domain Context Builders (pure functions, no side effects) │
│  ─────────────────────────────────────────────────────────────────── │
│  BuildXPContext()         — reads XP Session + game APIs            │
│  BuildReputationContext() — reads Rep Session + game APIs           │
│  BuildCompanionContext()  — reads Comp Session + game APIs          │
│                                                                     │
│  Each returns a frozen, flat table. Config flags are merged in.     │
│  Called ONLY when the domain's session signals a change.            │
└─────────────────────────────────────────────────────────────────────┘
                    │                │                    │
                    ↓                ↓                    ↓
┌─────────────────────────────────────────────────────────────────────┐
│  LAYER 3: EventBus (signal + context delivery)                      │
│  ─────────────────────────────────────────────────────────────────── │
│  Emit("XP:UPDATE", xpContext)                                       │
│  Emit("REP:UPDATE", repContext)                                     │
│  Emit("COMPANION:UPDATE", compContext)                              │
│  Emit("CONFIG:UPDATED")  — no context, bars re-read db             │
│                                                                     │
│  Every emit carries the pre-built context. No lazy build inside     │
│  EventBus. Listeners receive ready-to-render data.                  │
└─────────────────────────────────────────────────────────────────────┘
                    │                │                    │
                    ↓                ↓                    ↓
┌─────────────────────────────────────────────────────────────────────┐
│  LAYER 4: Bar Frames (unified contract via shared base mixin)       │
│  ─────────────────────────────────────────────────────────────────── │
│  ALL bars (XP, Rep, Companion, future) implement:                   │
│    OnLoad()    — wire visuals                                       │
│    OnShow()    — EventBus:RegisterWithHandle(DOMAIN_EVENT)          │
│    OnHide()    — handle.Unregister()                                │
│    MarkDirty() — coalesce into next-frame render                    │
│    Render(ctx) — paint from context                                 │
│                                                                     │
│  XP bars additionally support animation, overlays, text.            │
│  Secondary bars can opt into animation/fade via shared utilities.   │
│  BarManager and SecondaryBarManager handle frame lifecycle only     │
│  (create, show/hide, style switch). No rendering logic.             │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 5. Concrete Refactoring Steps (prioritized)

### Phase 1 — Normalize event contracts (LOW risk, HIGH clarity)

1. **Make secondary bar listeners USE the emitted context** instead of discarding it and rebuilding. Change `_BuildContext()` in RepSession/CompSession to return the same flat format as `BuildReputationContext()` / `BuildCompanionContext()`, or have the session Emit call the public `Build*Context()` and pass that.

2. **Eliminate the nil-context path in EventBus:Emit**. Have Session call `BuildContext()` before emitting and pass the result. Remove the auto-build fallback from EventBus — it should be a pure dispatch mechanism.

3. **Give secondary bars `MarkDirty()` coalescing.** Either extract it from BaseMixin into a tiny standalone mixin, or have secondary bars inherit a lightweight version. This prevents double-render when both UPDATE_FACTION and CHAT_MSG_COMBAT_FACTION_CHANGE fire in the same frame.

### Phase 2 — Consolidate event frame registration (MEDIUM risk, MEDIUM clarity)

4. **Create a single central event router frame** in AddOnLifecycle (or a new `EventRouter.lua`). Register ALL external WoW events there and dispatch to domain handlers. Remove individual `CreateFrame` + `RegisterEvent` from Session, ReputationSession, CompanionSession, QuestXP.

   _Benefit:_ One place to see every external event the addon cares about. Easier to add/remove events. No accidental double-registration.

   _Risk:_ Large diff, touches many files, must preserve exact handler ordering.

### Phase 3 — Unify bar mixin contract (MEDIUM risk, HIGH future value)

5. **Extract a `SecondaryBarBaseMixin`** from the common parts of FlatReputationBarMixin and FlatCompanionBarMixin. This mixin provides: EventBus subscribe/unsubscribe, `MarkDirty`, `SetAlpha` fade transitions, and the `Render(context)` contract.

6. **Add fade animation as a shared utility** (not part of the AnimationBase system which is XP-specific). A simple `FadeController` table with `FadeIn(frame, duration)` / `FadeOut(frame, duration)` using `UIFrameFadeIn`/`UIFrameFadeOut` or raw `SetAlpha` + OnUpdate.

### Phase 4 — Optional: flatten context building (LOW risk, performance gain)

7. **Cache the config portion of the context.** The ~20 db keys copied in `BuildDBConfig()` only change on `CONFIG_UPDATED`. Build it once, invalidate on config change, merge into each domain context by reference.

8. **Make Session services pure-data objects** with no frame, no RegisterEvent, and a simple `Update(eventName, ...)` method. The central event router calls them.

---

## 6. What NOT to Refactor

- **StyleBuilder composition** — the mixin composition pattern is well-structured and extensible. No changes needed.
- **Immutable context pattern** — the metatable-based immutable wrapper in `MakeImmutable` is good defensive design. Keep it for XP contexts; secondary bars can use plain tables since they're simpler.
- **BarManager / SecondaryBarManager separation** — keeping these as separate managers is correct because XP bars have Blizzard bar suppression, max-level detection, and style switching that don't apply to secondary bars.
- **Per-domain Session services** — these are correctly separated. Each domain has different APIs, different gain detection logic, and different save data. Don't merge them.

---

## 7. Summary

The current architecture is **functional and correctly separated by domain**. The main friction points for adding more bars are:

1. **Inconsistent event→context→render contracts** between XP and secondary pipelines
2. **Scattered WoW event registration** making it hard to audit the full event surface
3. **No shared base mixin for secondary bars**, forcing feature duplication (fade, dirty coalescing, tooltip)

The proposed Phase 1 changes are safe, additive, and immediately improve clarity without restructuring the codebase. Phase 2-4 can be done incrementally as the project grows.
