# Reputation / Faction Bar - Feature Analysis

> Analysis of the reputation tracking bar feature from a reference addon, intended as a
> specification basis for implementing similar functionality in XPBarEnhanced.

> **MQ-4 Audit (2026-04-08)**: **SUPERSEDED by NR-3 (2026-04-07)**. The reputation bar is implemented as the unified tracked-reputation secondary bar supporting standard, friendship, major-faction/renown, and paragon reputation types. See `docs/features/reputation-bar.md` and `docs/features/secondary-bar-manager.md`. This analysis document is retained as reference for WoW API details and data-model normalization patterns.

## Overview

A reputation bar is a secondary progress bar (independent of the XP bar) that tracks the
player's standing with a chosen faction. It must handle four distinct reputation systems
exposed by the WoW API:

| Type | API Namespace | Examples |
|------|--------------|----------|
| **Standard** | `C_Reputation` | Most classic/expansion factions |
| **Friendship** | `C_GossipInfo` | Delve companions (Brann, Valeera), NPC followers |
| **Major Faction / Renown** | `C_MajorFactions` | TWW+ factions (Hara'ti, The Singularity) |
| **Paragon** | `C_Reputation` (paragon subset) | Post-Exalted repeatable rep |

Each type has different data shapes, thresholds, and display conventions that must be
normalized into a single data model before rendering.

---

## WoW API Reference

### Faction Selection

| API | Returns | Purpose |
|-----|---------|---------|
| `C_Reputation.GetWatchedFactionData()` | `{ factionID, name, ... }` | Gets the player's pinned/watched faction |
| `C_Reputation.GetNumFactions()` | `number` | Total faction entries in the reputation list |
| `C_Reputation.GetFactionDataByIndex(i)` | `{ isHeader, isChild, isCollapsed, factionID, name, ... }` | Faction data by list index |
| `C_Reputation.ExpandFactionHeader(i)` | - | Expands a collapsed header (shifts subsequent indices) |

### Standard Reputation

| API | Returns | Purpose |
|-----|---------|---------|
| `C_Reputation.GetFactionDataByID(factionID)` | `{ name, reaction, currentStanding, currentReactionThreshold, nextReactionThreshold, ... }` | Full reputation data for a faction |

Key fields:
- `reaction` - localized standing name ("Hostile", "Neutral", "Friendly", "Honored", "Revered", "Exalted")
- `currentStanding` - raw rep value (absolute, not relative to tier)
- `currentReactionThreshold` - start of current tier
- `nextReactionThreshold` - start of next tier
- Progress within tier = `currentStanding - currentReactionThreshold`
- Tier size = `nextReactionThreshold - currentReactionThreshold`
- When `nextReactionThreshold <= currentReactionThreshold`, the player is at the cap (Exalted)

### Friendship Reputation

| API | Returns | Purpose |
|-----|---------|---------|
| `C_GossipInfo.GetFriendshipReputation(factionID)` | `{ friendshipFactionID, standing, nextThreshold, reactionThreshold, reaction, name, friendTextNext, rankIndex }` | Friendship-specific data |
| `C_GossipInfo.GetFriendshipReputationRanks(factionID)` | `{ currentLevel, maxLevel }` | Numeric level for the friendship |

Key fields:
- `friendshipFactionID > 0` confirms this is a friendship faction
- `standing` - current rep within the current rank (not a standing name)
- `nextThreshold` - rep needed for next rank (`nil` or `0` = max rank)
- `reactionThreshold` - used as fallback cap at max rank
- `reaction` - rank name string (varies by faction)

Level detection priority:
1. `GetFriendshipReputationRanks(factionID).currentLevel` (most reliable)
2. `friendData.rankIndex` (older API)
3. Parse digit from `friendData.reaction` string (last resort)

### Major Factions (Renown)

| API | Returns | Purpose |
|-----|---------|---------|
| `C_MajorFactions.GetMajorFactionData(factionID)` | `{ renownReputationEarned, renownLevelThreshold, renownLevel, maxRenownLevel, name }` | Renown data |

Key fields:
- `renownReputationEarned` - rep earned within current renown level
- `renownLevelThreshold` - rep needed for next renown level (typical: 2500)
- `renownLevel` / `maxRenownLevel` - current and cap renown levels

**Important:** Must check major factions *before* standard rep because `GetFactionDataByID`
returns zeroed standing fields for renown factions, producing a misleading blank bar.

### Paragon

| API | Returns | Purpose |
|-----|---------|---------|
| `C_Reputation.IsFactionParagon(factionID)` | `boolean` | Whether faction is in paragon mode |
| `C_Reputation.GetFactionParagonInfo(factionID)` | `currentParagonRep, maxPerCycle` | Paragon progress |

**Encoding quirk:** `currentParagonRep` encodes total rewards earned as a prefix
(e.g., 12 rewards + 717 rep = 120717). Strip with modulo: `currentRep % maxPerCycle`.

---

## Normalized Data Model

All four reputation types must be normalized into a single structure:

```lua
---@class FactionData
---@field name            string   -- Display name
---@field factionID       number   -- Blizzard faction ID
---@field isFriendship    boolean  -- true for friendship/companion factions
---@field isMajorFaction  boolean  -- true for renown factions
---@field isParagon       boolean  -- true for paragon factions
---@field isMaxRank       boolean  -- true at cap (max friendship, max renown, Exalted+)
---@field currentLevel    number?  -- Friendship level or renown level (nil for standard)
---@field currentValue    number   -- Rep within current tier (0-based)
---@field maxValue        number   -- Total rep needed for current tier
---@field pct             number   -- Percentage 0-100
---@field standingName    string?  -- Reaction name (standard) or rank name (friendship)
```

### Normalization Logic (priority order)

```
1. Try friendship:  C_GossipInfo.GetFriendshipReputation(factionID)
     -> if friendshipFactionID > 0: normalize friendship data, return

2. Try major faction: C_MajorFactions.GetMajorFactionData(factionID)
     -> if returns data: normalize renown data, return

3. Standard rep: C_Reputation.GetFactionDataByID(factionID)
     -> check IsFactionParagon for paragon overlay
     -> normalize standard/paragon data, return
```

---

## Events

### Required Events

| Event | Fires When | Action |
|-------|-----------|--------|
| `UPDATE_FACTION` | Any reputation changes | Refresh faction data and bar |
| `MAJOR_FACTION_RENOWN_LEVEL_CHANGED` | Renown level-up | Refresh faction data and bar |
| `ZONE_CHANGED_NEW_AREA` | Zone/instance change | Re-evaluate visibility gates |
| `PLAYER_LEAVING_WORLD` | Instance transition begins | Hide bar to prevent lingering |

### Optional Polling

The reference addon polls every 0.5s via a repeating timer. This is a brute-force approach
that could be replaced by more targeted event-driven updates. However, it ensures the bar
stays current even if an edge-case event is missed.

---

## Visibility Gates

The bar should implement layered visibility checks:

```
Gate 1: Master toggle
  -> if not enabled: HIDE

Gate 2: Data availability
  -> if no faction data: HIDE (or show placeholder in settings mode)

Gate 3: Context-specific (delve companions only)
  -> if companion + not inside delve: HIDE

Gate 4: Max rank
  -> if at cap (max friendship, max renown, Exalted, paragon 100%): HIDE
```

Gates 3 and 4 should be bypassed when the bar is unlocked or settings are open,
so the user can always see and reposition the bar during configuration.

### Delve Detection

```lua
-- Primary
C_Garrison.IsInDelve()  -- returns boolean

-- Fallback (if C_Garrison.IsInDelve unavailable)
local _, instanceType = IsInInstance()
local inDelve = (instanceType == "scenario")
```

---

## UI Structure

### Frame Hierarchy

```
FactionFrame (Button, movable, clamped to screen)
  |
  +-- BackgroundBar (StatusBar, frame level 10)
  |     black at 50% alpha, always at value=100
  |
  +-- FillBar (StatusBar, frame level 20)
  |     textured with horizontal gradient (60% -> 100% of user color)
  |
  +-- LeftText (FontString on FillBar)
  |     anchored LEFT, 65% max width
  |     shows: "Name - Standing/Level/Renown N - X.X%"
  |
  +-- RightText (FontString on FillBar)
        anchored RIGHT, 30% max width
        shows: "(current / max)" with abbreviated numbers
```

### Text Formatting Rules

| Faction Type | Left Text | Right Text |
|-------------|-----------|------------|
| Standard | `"Name - Standing - X.X%"` | `"(curr / max)"` |
| Friendship | `"Name - Level N - X.X%"` | `"(curr / max)"` |
| Major/Renown | `"Name - Renown N - X.X%"` | `"(curr / max)"` |
| Paragon | `"Name - Paragon - X.X%"` | `"(curr / max)"` |

---

## Configuration Settings

### Minimum Settings for a Faction Bar

| Setting | Type | Default | Purpose |
|---------|------|---------|---------|
| `factionEnabled` | boolean | `true` | Master toggle |
| `factionUseWatched` | boolean | `true` | Auto-follow watched faction vs explicit selection |
| `factionID` | number | `0` | Explicit faction ID when not using watched |
| `factionBarWidth` | number | `400` | Bar width |
| `factionBarHeight` | number | `20` | Bar height |
| `factionBarColor` | `{r,g,b,a}` | `{0.196, 0.388, 0.800, 1.0}` | Bar fill color |
| `factionLocked` | boolean | `true` | Lock/drag toggle |
| `factionCenterOnHide` | boolean | `true` | Reposition when XP bar hidden at max level |

### Faction Selection UI

Building a faction dropdown requires iterating the full reputation list with header expansion:

1. Collect collapsed header names (not indices, to avoid shift issues)
2. Expand each header by re-scanning for its name
3. Build a flat list of `{ factionID, name, expansion, subgroup }`
4. Sort by expansion -> subgroup -> name
5. Tag known delve companions (e.g., with a green "(Delve Companion)" suffix)
6. Always include the watched faction even if it was hidden in a collapsed group

---

## Integration Points with XPBarEnhanced

### Where This Fits in Our Architecture

| Concern | Approach |
|---------|----------|
| **Data fetching** | New `core/services/Reputation.lua` service, analogous to `QuestXP.lua` |
| **Data model** | `FactionData` context object, fed into the immutable context pipeline |
| **EventBus** | New event names: `REPUTATION:UPDATED`, `REPUTATION:FACTION_CHANGED` |
| **Bar rendering** | Could be a new style, or an overlay/companion widget on existing styles |
| **Configuration** | New config keys in `defaults.lua`, new options panel section |
| **Tooltip** | Add a reputation section to `TooltipMixin` when tracking a faction |

### Mixin Compatibility

The reputation bar is fundamentally a StatusBar with text overlays. It could be implemented:

1. **As a standalone bar** (new style): A new `ReputationBarStyle` registered with `BarManager`
2. **As an attached widget**: A subordinate frame that attaches below/above the active XP style
3. **As a context extension**: Add `context.faction.*` fields and let existing styles optionally render them

Option 2 (attached widget) would be most consistent with our architecture while keeping the
reputation bar independent of specific style implementations.

---

## Open Questions for Implementation

1. Should the reputation bar be a separate bar style or an attached widget to any existing style?
2. Should we support per-standing automatic colors (e.g., red for Hated, green for Exalted)?
3. Should the reputation bar share the active style's visual language or have its own appearance?
4. Do we need a faction selection dropdown in settings, or is following the watched faction sufficient?
5. Should we track reputation session gains (rep/hour) like we do for XP?
6. How should the reputation bar interact with the Minimap Ring and Terminal styles?
