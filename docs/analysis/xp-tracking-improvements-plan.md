# XP Tracking Improvements - Implementation Plan

> Actionable improvements identified from comparing our XP tracking implementation against
> a reference addon. Each item includes the rationale, affected files, and step-by-step
> implementation details.

---

## 1. Session Persistence Across `/reload`

### Problem

When a player does `/reload`, our `Session:OnEnteringWorld` correctly preserves `gainedXP`
(because `isInitialLogin` is false), but the session clock restarts because `sessionStart`
is a Unix timestamp set once and never adjusted. Time-dependent stats (XP/hour,
time-to-level) are recalculated from `time() - sessionStart`, which still works across
a reload — **but** there is no explicit accumulator being saved, so the behavior is fragile
and depends on the saved variable being written before the client shuts down.

More importantly, there is no user-facing option to control this behavior.

### Goal

- Add an explicit `sessionAccumTime` accumulator that is periodically written to saved
  variables, making session time resilient to `/reload`.
- Add a `resetOnReload` config option (default `false`) so users can choose.

### Affected Files

| File | Changes |
|------|---------|
| `core/config/defaults.lua` | Add `resetOnReload = false` default |
| `core/services/Session.lua` | Add accumulator logic, rebase clock on init, periodic persist |
| `core/services/ContextBuilder.lua` | Read `sessionAccumTime` for session duration |
| `locales/enUS.lua` | Add option label/tooltip strings |
| `ui/options/OptionMetadata.lua` | Add `resetOnReload` toggle to options |

### Implementation Steps

#### 1.1 Add default config key

In `core/config/defaults.lua`, add after line 42 (`fadeWhenInactive`):

```lua
resetOnReload = false,
```

#### 1.2 Add `sessionAccumTime` to session data

In `Session.lua`, extend `ensureSessionDefaults` (line 38) to include:

```lua
session.sessionAccumTime = session.sessionAccumTime or 0
```

#### 1.3 Rebase session clock on reload

In `Session:OnEnteringWorld` (line 116), update the reload path:

```lua
function Session:OnEnteringWorld(isInitialLogin, isReloadingUI)
    local session = self:GetCurrent()
    if not session then return end

    local db = Addon.db or {}

    if isInitialLogin or db.resetOnReload then
        -- Fresh session
        session.sessionStart = time()
        session.sessionAccumTime = 0
        session.gainedXP = 0
        session.startLevel = UnitLevel("player") or 1
        session.levelsGained = 0
    elseif isReloadingUI then
        -- Rebase: set sessionStart so that (time() - sessionStart) equals
        -- the previously accumulated seconds
        session.sessionStart = time() - (session.sessionAccumTime or 0)
    end

    if isInitialLogin or isReloadingUI then
        session.lastXP = UnitXP("player")
        session.maxXP = UnitXPMax("player")
    end

    -- Request time played if time text options are enabled
    if db.showLevelTimeText or db.showSessionTimeText then
        self:RequestTimePlayed()
    end
end
```

#### 1.4 Persist accumulator on XP updates

In `Session:OnXPUpdate` (line 140), after updating `session.lastUpdate`, add:

```lua
session.sessionAccumTime = time() - (session.sessionStart or time())
```

This writes the current elapsed time back to the saved variable on every XP event. Since
saved variables are flushed on `/reload`, this ensures the accumulator survives.

#### 1.5 Add locale strings and option toggle

Add `OPT_RESET_ON_RELOAD` / `OPT_RESET_ON_RELOAD_DESC` to `locales/enUS.lua`, and register
the toggle in `OptionMetadata.lua` under the Session section.

---

## 2. Time Display Refresh Timer

### Problem

Our UI is purely event-driven. The below-bar text for "Session Time", "Level Time", and
"Time to Level" only updates when a WoW event fires (typically `PLAYER_XP_UPDATE`). Between
XP gains, these time displays appear frozen — session time stays at "12m 34s" until the
next mob kill, which could be minutes later.

### Goal

Add a lightweight periodic timer that refreshes **only time-related text** on active bars,
without rebuilding the full immutable context or triggering animations.

### Affected Files

| File | Changes |
|------|---------|
| `ui/mixins/BaseMixin.lua` | Add time-tick timer on show, cancel on hide |
| `ui/mixins/TextMixin.lua` | Extract time-only refresh method |

### Implementation Steps

#### 2.1 Add time-only refresh to TextMixin

In `TextMixin.lua`, add a new method that **only** updates the two time-dependent text
elements, bypassing the full `UpdateTexts` pipeline:

```lua
--- Lightweight refresh for time-dependent texts only.
--- Does NOT require a full context rebuild; reads Session directly.
function XPBarTextMixin:RefreshTimeTexts()
    -- Reuse the existing UpdateSessionText and UpdateRateText methods,
    -- but skip visibility changes (those are config-driven, not time-driven).
    -- We need a minimal context for config flags only.
    if not Addon.TextFormatter then return end
    if not Addon.Session then return end

    -- Only refresh if the text elements exist and are shown
    if self.SessionText and self.SessionText:IsShown() then
        -- UpdateSessionText already reads Session:GetCurrent() directly (line 263),
        -- so passing a minimal context with just config flags is sufficient.
        local db = Addon.db or {}
        local miniCtx = {
            showSessionTimeText = db.showSessionTimeText,
            showLevelTimeText = db.showLevelTimeText,
        }
        self:UpdateSessionText(miniCtx)
    end

    if self.RateText and self.RateText:IsShown() then
        local db = Addon.db or {}
        local miniCtx = {
            showXPPerHourText = db.showXPPerHourText,
            showTimeToLevelText = db.showTimeToLevelText,
            abbreviateNumbers = db.abbreviateNumbers,
        }
        self:UpdateRateText(miniCtx)
    end
end
```

**Note:** `UpdateSessionText` (line 262-281) already reads fresh time from
`Addon.Session:GetCurrent()` and computes `time() - session.sessionStart` directly. It does
NOT use stale context values for time (the comment on line 261 confirms this was
intentional). So calling it with a minimal config-only context is safe and correct.

`UpdateRateText` (line 186-239) falls back to `Addon.Session:GetXPPerHour()` when context
values are nil (lines 204-209), so it will also compute fresh rates.

#### 2.2 Add timer to BaseMixin

In `BaseMixin:OnShow` (line 117), after the EventBus subscription, start a 2-second
repeating timer:

```lua
-- Periodic time-text refresh (2s interval, lightweight)
if not self.__timeTickTimer and C_Timer and C_Timer.NewTicker then
    self.__timeTickTimer = C_Timer.NewTicker(2, function()
        if self:IsVisible() and self.RefreshTimeTexts then
            self:RefreshTimeTexts()
        end
    end)
end
```

In `BaseMixin:OnHide` (after the EventBus unsubscribe), cancel it:

```lua
if self.__timeTickTimer then
    self.__timeTickTimer:Cancel()
    self.__timeTickTimer = nil
end
```

### Performance Note

This timer does NOT rebuild the immutable context, does NOT call `BuildContext()`, does NOT
trigger `MarkDirty()` or `TriggerBarRefresh()`, and does NOT touch bar fill/overlays/animations.
It only calls `SetText()` on 2 FontString elements at most. Cost is negligible.

### Interaction with Session Accumulator (Item 1)

The time ticker also ensures `sessionAccumTime` stays reasonably current even between XP
events. Add to the ticker callback:

```lua
-- Persist session elapsed time for reload resilience
if Addon.Session then
    local session = Addon.Session:GetCurrent()
    if session and session.sessionStart then
        session.sessionAccumTime = time() - session.sessionStart
    end
end
```

This replaces the need for a separate persistence timer and keeps both features tightly
integrated.

---

## 3. Expansion Level Change Events

### Problem

Our `AddOnLifecycle.lua` registers `PLAYER_MAX_LEVEL_UPDATE` but not
`UPDATE_EXPANSION_LEVEL` or `MAX_EXPANSION_LEVEL_UPDATED`. During pre-patch periods when
the level cap changes, or when a player purchases an expansion mid-session, we may not
re-evaluate bar visibility until the next login.

### Goal

Register the two missing events and route them to the existing max-level handler.

### Affected Files

| File | Changes |
|------|---------|
| `core/AddOnLifecycle.lua` | Add 2 events to `eventMap` |

### Implementation Steps

#### 3.1 Add events to the event map

In `AddOnLifecycle.lua`, extend `eventMap` (line 139):

```lua
local eventMap = {
    ADDON_LOADED = "OnAddonLoaded",
    PLAYER_LOGIN = "OnPlayerLogin",
    PLAYER_ENTERING_WORLD = "OnPlayerEnteringWorld",
    PLAYER_LEVEL_UP = "OnPlayerLevelUp",
    ENABLE_XP_GAIN = "OnEnableXPGain",
    DISABLE_XP_GAIN = "OnDisableXPGain",
    PLAYER_LOGOUT = "OnPlayerLogout",
    PLAYER_MAX_LEVEL_UPDATE = "OnPlayerMaxLevelUpdate",
    UPDATE_EXPANSION_LEVEL = "OnPlayerMaxLevelUpdate",        -- reuse handler
    MAX_EXPANSION_LEVEL_UPDATED = "OnPlayerMaxLevelUpdate",   -- reuse handler
}
```

That's it. The existing `OnPlayerMaxLevelUpdate` handler (line 119) already:
1. Forces `BarManager` to re-evaluate the current style
2. Emits `XPBAR_BROADCAST_UPDATE` via EventBus

Both new events will route to this handler, which correctly re-evaluates bar visibility.

### Verification

After this change, the registered events loop (line 160) will automatically pick up both
new events since it iterates `eventMap`:

```lua
for event in pairs(eventMap) do
    eventFrame:RegisterEvent(event)
end
```

---

## 4. Quest XP `isTask` Filtering

### Problem

Our `QuestXP.lua` filters `isHeader` and `isHidden` when iterating the quest log, but does
not filter `isTask`. The `isTask` flag is set on world quests, bonus objectives, and threat
quests. These quests report XP rewards via `GetQuestLogRewardXP(questID)` but behave
differently from normal quests:

- Their "completion" state may flip rapidly or be misleading
- Their XP rewards can be large and skew the overlay
- They often cannot be "turned in" in the traditional sense

Including them in the quest XP overlay gives the player a misleading impression of how much
XP they will gain from quest turn-ins.

### Goal

Add `isTask` filtering to `buildQuestCache()` to exclude world quests and bonus objectives
from the quest XP overlay.

### Affected Files

| File | Changes |
|------|---------|
| `core/services/QuestXP.lua` | Add `isTask` check in the cache build loop |

### Implementation Steps

#### 4.1 Add filter condition

In `QuestXP.lua`, modify the filter on line 65:

**Before:**
```lua
if info and not info.isHeader and not info.isHidden and info.questID then
```

**After:**
```lua
if info and not info.isHeader and not info.isHidden and not info.isTask and info.questID then
```

This is a single condition added to the existing guard clause. The `isTask` field is
documented in Blizzard's `QuestInfo` structure returned by `C_QuestLog.GetInfo()`.

### Verification

- World quests in the quest log should no longer appear in the XP overlay
- Bonus objectives should no longer appear
- Normal quests and campaign quests should be unaffected (`isTask` is false for them)

---

## 5. XP/Hour Minimum Threshold Reduction

### Problem

`TimeCalculations.CalculateXPPerHour` requires 30 seconds of elapsed time before computing
a rate (line 26). This means a player who gains XP at second 10 of their session sees
`0 XP/hr` for another 20 seconds. The reference addon uses 5 seconds, which is too
aggressive (produces wildly fluctuating rates). A 10-second threshold balances
responsiveness with stability.

### Goal

Reduce the minimum elapsed threshold from 30 seconds to 10 seconds.

### Affected Files

| File | Changes |
|------|---------|
| `core/calculations/TimeCalculations.lua` | Change threshold constant |

### Implementation Steps

#### 5.1 Lower the threshold

In `TimeCalculations.lua`, line 26:

**Before:**
```lua
if elapsed < 30 then
```

**After:**
```lua
if elapsed < 10 then
```

The dual-rate heuristic (session rate vs level rate comparison at line 45) already prevents
wild fluctuations by preferring the more stable level-time rate when both are available.
The 10-second minimum only affects the very start of a session before any level-time data
exists.

---

## Implementation Order

The recommended order minimizes dependencies between changes:

| Order | Item | Risk | Effort |
|-------|------|------|--------|
| 1 | **Item 4** - `isTask` filtering | None (additive filter) | Trivial (1 line) |
| 2 | **Item 3** - Expansion events | None (additive events) | Trivial (2 lines) |
| 3 | **Item 5** - XP/hr threshold | Low (behavioral change) | Trivial (1 line) |
| 4 | **Item 1** - Session persistence | Medium (saved variable schema change) | Moderate |
| 5 | **Item 2** - Time refresh timer | Low (additive feature) | Moderate |

Items 1 and 2 are coupled (the timer in item 2 doubles as the persistence mechanism for
item 1), so they should be implemented together or in sequence.

---

## Testing Checklist

- [ ] `/reload` preserves session XP gained and session time (item 1)
- [ ] Setting `resetOnReload = true` resets session on `/reload` (item 1)
- [ ] Session time text updates every ~2 seconds without XP events (item 2)
- [ ] Level time text updates every ~2 seconds without XP events (item 2)
- [ ] Timer is cancelled when bar is hidden and restarted when shown (item 2)
- [ ] Purchasing an expansion mid-session re-evaluates bar visibility (item 3)
- [ ] World quests are excluded from the quest XP overlay (item 4)
- [ ] Bonus objectives are excluded from the quest XP overlay (item 4)
- [ ] Normal quests still appear correctly in the overlay (item 4)
- [ ] XP/hour displays a value within 10 seconds of first XP gain (item 5)
- [ ] XP/hour is not wildly inaccurate in the first 30 seconds (item 5)
