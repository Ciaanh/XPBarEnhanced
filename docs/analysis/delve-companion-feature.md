# Delve Companion XP Tracking - Feature Analysis

> Analysis of the delve companion XP tracking feature from a reference addon, intended as a
> specification basis for implementing similar functionality in XPBarEnhanced.

## Overview

Delve companions (Brann Bronzebeard, Valeera Sanguinar) are tracked in the WoW API as
**friendship reputations**, not via a dedicated `C_DelvesUI` API. The companion has levels,
and each level requires a certain amount of XP (friendship rep) to advance. This makes
companion tracking a specialized case of reputation tracking with additional visibility
rules tied to the player being inside a Delve instance.

---

## WoW API Reference

### Companion Data

Companion XP is accessed through the friendship reputation APIs:

| API | Returns | Purpose |
|-----|---------|---------|
| `C_GossipInfo.GetFriendshipReputation(factionID)` | `{ friendshipFactionID, standing, nextThreshold, reactionThreshold, reaction, name, friendTextNext, rankIndex }` | Core companion data |
| `C_GossipInfo.GetFriendshipReputationRanks(factionID)` | `{ currentLevel, maxLevel }` | Companion level (most reliable source) |
| `C_Reputation.GetFactionDataByID(factionID)` | `{ name, ... }` | Used as fallback for companion display name |
| `C_Reputation.GetNumFactions()` | `number` | Used to scan the full faction list for companion auto-detection |
| `C_Reputation.GetFactionDataByIndex(i)` | `{ isHeader, factionID, name, ... }` | Used in faction iteration for auto-detection |

### Delve Instance Detection

| API | Returns | Purpose |
|-----|---------|---------|
| `C_Garrison.IsInDelve()` | `boolean` | Primary: checks if player is currently inside a Delve |
| `IsInInstance()` | `inInstance, instanceType` | Fallback: `instanceType == "scenario"` as delve proxy |

**Note:** `C_Garrison.IsInDelve()` may not be available on all client versions, hence the
fallback to the more general `IsInInstance()` check.

---

## Data Model

### Friendship Data Fields (Companion Context)

```lua
---@class CompanionData
---@field name            string   -- Companion name (e.g., "Brann Bronzebeard")
---@field factionID       number   -- Faction ID for the companion
---@field currentLevel    number   -- Current companion level
---@field maxLevel        number?  -- Max companion level (from GetFriendshipReputationRanks)
---@field currentXP       number   -- XP within current level (friendData.standing)
---@field maxXP           number   -- XP needed for next level (friendData.nextThreshold)
---@field pct             number   -- Percentage progress 0-100
---@field isMaxLevel      boolean  -- true when at max level (nextThreshold is nil or 0)
---@field rankName        string   -- Current rank name (friendData.reaction)
```

### Known Companions

The reference addon uses a hardcoded whitelist:

```lua
local DELVE_COMPANIONS = {
    ["Brann Bronzebeard"] = true,
    ["Valeera Sanguinar"] = true,
}
```

This is used to:
1. Apply delve-specific visibility rules (only show inside delves)
2. Tag companions in the faction selection dropdown
3. Hide the bar at max friendship level

**Limitation:** Hardcoded names are English-only. For localization, faction IDs or a more
robust detection method would be needed.

---

## Data Fetch Flow

### Step 1: Resolve Faction ID

Two modes:
- **Watched mode**: `C_Reputation.GetWatchedFactionData()` returns whatever faction the
  player has pinned in the Blizzard reputation panel
- **Explicit mode**: A stored `factionID` chosen from a dropdown or auto-detected

### Step 2: Detect Friendship Type

```lua
local friendData = C_GossipInfo.GetFriendshipReputation(factionID)
if friendData and friendData.friendshipFactionID > 0 then
    -- This is a friendship faction (could be a companion)
end
```

### Step 3: Extract Level and XP

```lua
-- Current XP in level
local currentXP = friendData.standing or 0

-- XP needed for next level
local maxXP = friendData.nextThreshold or friendData.reactionThreshold or 1

-- Is at max level?
local isMaxLevel = (friendData.nextThreshold == nil or friendData.nextThreshold == 0)

-- Percentage
local pct = isMaxLevel and 100 or math.min((currentXP / maxXP) * 100, 100)
```

### Step 4: Resolve Level Number (3-tier fallback)

```lua
local levelNum = 0

-- 1. Primary: GetFriendshipReputationRanks (most reliable)
local ranks = C_GossipInfo.GetFriendshipReputationRanks(factionID)
if ranks and ranks.currentLevel then
    levelNum = ranks.currentLevel

-- 2. Fallback: rankIndex field (older API)
elseif friendData.rankIndex then
    levelNum = friendData.rankIndex

-- 3. Last resort: parse digit from reaction string
elseif friendData.reaction then
    local n = tostring(friendData.reaction):match("(%d+)")
    levelNum = tonumber(n) or 0
end
```

### Step 5: Resolve Display Name

```lua
-- Prefer the standard faction name, fall back to friendship name
local factionInfo = C_Reputation.GetFactionDataByID(factionID)
local name = (factionInfo and factionInfo.name)
          or (friendData.name)
          or "Unknown"
```

### Step 6: Auto-Detection on First Login

To avoid hardcoding faction IDs (which may change between patches/regions):

```lua
local function FindCompanionFactionID(targetName)
    local lower = targetName:lower()
    local numFactions = C_Reputation.GetNumFactions()
    for i = 1, numFactions do
        local fdata = C_Reputation.GetFactionDataByIndex(i)
        if fdata and not fdata.isHeader and fdata.factionID > 0 then
            local friendData = C_GossipInfo.GetFriendshipReputation(fdata.factionID)
            local name = (friendData and friendData.name) or fdata.name or ""
            if name:lower():find(lower, 1, true) then
                return fdata.factionID
            end
        end
    end
    return nil
end
```

This scans by case-insensitive substring match, avoiding ID brittleness.

---

## Visibility Rules

The companion bar has a multi-gate visibility system:

```
Gate 1: Master toggle (factionEnabled)
  |
  v  if disabled -> HIDE
Gate 2: Data availability
  |
  v  if no faction data -> HIDE (placeholder in settings mode)
Gate 3: Delve context (companions only)
  |
  v  if companion + not in delve -> HIDE
Gate 4: Max level (companions only)
  |
  v  if companion + max friendship -> HIDE
  |
  v  SHOW
```

**Gate bypass:** When the bar is unlocked or settings panel is open, gates 3 and 4 are
skipped so the user can always see and reposition the bar during configuration.

### Companion Detection for Gate Application

```lua
-- Strip any color codes from the name for clean matching
local bareName = fdata.name:gsub("|c%x%x%x%x%x%x%x%x.+|r$", ""):match("^(.-)%s*$")
local isDelveCompanion = DELVE_COMPANIONS[bareName]
```

### Delve Detection

```lua
local inDelve = false
if C_Garrison and C_Garrison.IsInDelve then
    inDelve = C_Garrison.IsInDelve()
else
    -- Fallback for clients where C_Garrison.IsInDelve is unavailable
    local _, instanceType = IsInInstance()
    inDelve = (instanceType == "scenario")
end
```

---

## Events

| Event | Relevance | Action |
|-------|-----------|--------|
| `UPDATE_FACTION` | Companion XP changes | Refresh companion data |
| `ZONE_CHANGED_NEW_AREA` | Entering/leaving a delve | Re-evaluate visibility gate 3 |
| `PLAYER_LEAVING_WORLD` | Instance transition | Immediately hide to prevent lingering |
| `MAJOR_FACTION_RENOWN_LEVEL_CHANGED` | Not directly relevant to companions but part of the same system | Refresh if tracking a non-companion faction |

The reference addon also polls every 0.5s. This is heavy-handed but ensures no edge case
is missed. An event-driven approach with `UPDATE_FACTION` + `ZONE_CHANGED_NEW_AREA` should
be sufficient for companions.

---

## Display

### Text Format

```
Left:  "Brann Bronzebeard - Level 15 - 67.3%"
Right: "(1.2K / 1.8K)"
```

- Level defaults to `1` if `currentLevel` is nil or 0
- Right side uses abbreviated numbers (K/M suffixes)

### Bar Fill

- `StatusBar` with `MinMaxValues(0, 100)`, value set to `pct`
- At max level: bar shows 100%, but is hidden by Gate 4 in normal operation

---

## Integration Points with XPBarEnhanced

### Architecture Options

**Option A: Extension of a Reputation Service**

Since companions *are* friendship reputations, companion tracking could be a special case
within a broader `Reputation.lua` service. The service would detect companion factions and
apply companion-specific visibility rules.

```
Reputation.lua
  -> GetTrackedFaction() -> FactionData
  -> IsCompanion(factionData) -> boolean
  -> IsInDelve() -> boolean
```

**Option B: Dedicated Companion Service**

A standalone `CompanionTracker.lua` focused solely on delve companions, using the friendship
API internally. Simpler scope, but duplicates some reputation logic.

**Recommendation:** Option A is preferred — it avoids code duplication and naturally supports
both general reputation tracking and companion tracking in a single system. Companion-specific
behavior (delve gating, auto-detection) can be layered on top.

### Context Extension

Add companion/faction fields to the immutable context:

```lua
context.faction = {
    name         = "Brann Bronzebeard",
    factionID    = 12345,
    currentLevel = 15,
    currentXP    = 1200,
    maxXP        = 1800,
    pct          = 66.7,
    isCompanion  = true,
    isMaxLevel   = false,
    isInDelve    = true,
}
```

### EventBus Integration

```lua
EventNames.REPUTATION_UPDATED       = "REPUTATION:UPDATED"
EventNames.REPUTATION_CHANGED       = "REPUTATION:FACTION_CHANGED"
EventNames.DELVE_STATUS_CHANGED     = "DELVE:STATUS_CHANGED"
```

### Style Considerations

Each bar style would need to decide how to render companion data:
- **Classic/Flat**: Secondary bar below/above the XP bar
- **Vertical**: Second vertical bar alongside
- **Circular**: Inner ring or secondary ring segment
- **Minimap Ring**: Second ring layer (thinner, different color)
- **Terminal**: Additional ASCII row below the XP bar

### Tooltip Integration

Add a companion section to `TooltipMixin`:

```
Companion: Brann Bronzebeard
Level: 15
Progress: 1,200 / 1,800 (66.7%)
```

---

## Edge Cases to Handle

| Case | Behavior |
|------|----------|
| No companion unlocked yet | Graceful nil handling, bar stays hidden |
| Companion at max level, outside delve | Double-hidden (gates 3 and 4) |
| Companion at max level, inside delve | Hidden by gate 4 |
| Settings open, no faction selected | Show placeholder text |
| API unavailable (classic client) | Guard all API calls, return nil |
| Faction ID changes between patches | Use name-based auto-detection, not hardcoded IDs |
| Color-coded strings in faction names | Strip `|cXXXXXXXX...|r` before whitelist matching |
| Instance transition (loading screen) | Hide immediately on `PLAYER_LEAVING_WORLD` |

---

## Open Questions for Implementation

1. Should companions share the reputation bar or have their own dedicated frame?
2. Should we support auto-detection of future companions beyond the hardcoded list?
3. Should companion XP gain per session be tracked (companion XP/hour)?
4. Should the companion bar be visible outside delves as an option (toggle gate 3)?
5. How should we handle localization of companion names for the whitelist?
6. Should we use `C_DelvesUI` if/when Blizzard exposes a dedicated companion API?
