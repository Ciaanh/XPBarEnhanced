# Reference Addon Comparative Analysis

> Side-by-side comparison of XPBarEnhanced (Ciaanh, v1.0.6) and the reference addon
> (v1.3.2) found in `refs/XPBarEnhanced/`.

## Identity

| Attribute | XPBarEnhanced (ours) | Reference Addon |
|-----------|---------------------|-----------------|
| Folder name | `XPBarEnhanced` | `XPBarEnhanced` |
| Display title | `XP Bar Enhanced` | `XPBar Enhanced` |
| Internal name | `"XPBarEnhanced"` | `"XPBarEnhanced"` |
| SavedVariables | `XPBarEnhancedDB` | `XPBarDB` |
| Author | Ciaanh | "You" |
| Version | 1.0.6 | 1.3.2 |
| License | MIT | Not specified |

Both addons use the identical folder name, making them mutually exclusive at the filesystem
level (only one can be installed at a time).

---

## Architecture Comparison

| Aspect | XPBarEnhanced (ours) | Reference Addon |
|--------|---------------------|-----------------|
| File count | ~50 files across modules | 1 single Lua file (1813 lines) |
| Pattern | Mixin composition + EventBus | Monolithic Ace3 addon |
| UI creation | XML templates + Lua mixins | Pure Lua frame creation |
| Dependencies | LibStub + AceLocale | Full Ace3 suite (13 libraries) |
| Config system | Custom `Config.lua` + `ConfigHelper.lua` | AceDB + AceConfig |
| Event dispatch | Custom EventBus with handle-based unsub | AceEvent unified dispatch |
| Context passing | Immutable context objects with metatable guard | Direct DB reads + local state |

### Our Architecture Strengths
- Modular separation of concerns (core/services/ui/styles)
- Style system allows multiple distinct bar appearances
- Immutable context prevents accidental state mutation
- EventBus with handle-based unsubscription enables clean lifecycle management

### Reference Architecture Strengths
- Single-file simplicity, easy to read end-to-end
- Ace3 provides battle-tested config UI, DB profiles, and event handling
- Reputation/faction bar as a first-class feature
- Delve companion tracking with context-aware visibility

---

## Feature Matrix

| Feature | Ours | Reference |
|---------|------|-----------|
| XP bar | Yes | Yes |
| Bar styles | 7 (classic, flat, vertical, circular, minimap ring, terminal, none) | 1 (horizontal) |
| Quest XP overlay | Yes (complete + incomplete, separate toggles) | Yes (complete only) |
| Rested XP overlay | Yes | Yes (separate bar) |
| Session tracking | Yes (XP gained, XP/hr, time to level, session time) | Yes (same metrics) |
| Smooth animations | Yes (fill, flash, two-phase level-up, accumulation batching) | No |
| Tooltip | Yes (rich GameTooltip via mixin) | No (on-bar text only) |
| Minimap button | Yes (LibDBIcon) | No |
| Statistics panel | Yes | No |
| Color customization | Yes (5 color keys) | Yes (bar color + gradient) |
| **Reputation/faction bar** | **No** | **Yes** |
| **Delve companion tracking** | **No** | **Yes** |
| **Faction selection UI** | **No** | **Yes (dropdown with full faction list)** |
| Multi-client support | Retail only | Classic/Wrath/Retail shims |
| Blizzard bar hiding | Yes (`MainStatusTrackingBarContainer` hooks) | Yes (`StatusTrackingBarManager`) |
| Draggable positioning | Yes (per-style) | Yes |
| Font customization | Partial (terminal only) | Yes (global + per-bar) |
| Bar size customization | No (style-defined) | Yes (width, height) |

---

## Code Comparison

### No Direct Code Copying

After line-by-line comparison, **no identical or near-identical code blocks** were found.
Shared patterns exist but are all standard WoW addon conventions:

| Pattern | Verdict |
|---------|---------|
| Quest log iteration (skip headers, accumulate XP) | Standard WoW API usage pattern |
| `gainedXP = current - last` gain detection | Mathematically obvious approach |
| `(gainedXP / elapsed) * 3600` for XP/hour | Basic arithmetic |
| `%dh %dm` time format strings | Universal WoW addon convention |
| K/M number abbreviation | Extremely common pattern (dozens of addons) |
| Event names (`PLAYER_XP_UPDATE`, etc.) | Dictated by the WoW API |

### Meaningful Differences

| Aspect | Ours | Reference |
|--------|------|-----------|
| Color palette | Purple XP bar (0.58, 0.0, 0.55) | Blue gradient (0.335, 0.388, 1.0) |
| Settings keys | `showPercentage`, `showXPPerHourText` | `showLevelingRate`, `showPlayedTime` |
| Blizzard bar target | `MainStatusTrackingBarContainer` | `StatusTrackingBarManager` |
| Session persistence | Not persisted across reloads | Persisted via AceDB char storage |
| Quest XP caching | TTL-based cache with per-quest data | No cache, recalculated each call |
| Error handling | `xpcall` + `CallErrorHandler` | Lua default |

---

## Features Worth Adopting

### 1. Reputation / Faction Bar

See: [Reputation Bar Feature Analysis](./reputation-bar-feature.md)

A secondary progress bar tracking the player's standing with a chosen faction. Handles four
distinct reputation systems (standard, friendship, major/renown, paragon) through a
normalized data model. Includes a faction selection dropdown and auto-follows the player's
watched faction.

### 2. Delve Companion XP Tracking

See: [Delve Companion Feature Analysis](./delve-companion-feature.md)

Context-aware tracking of delve companion levels (Brann Bronzebeard, Valeera Sanguinar).
Companions are friendship factions, so this is a specialization of reputation tracking with
delve-specific visibility gates (only visible inside delves, hidden at max level).

### 3. Session Persistence Across Reloads

The reference addon persists `sessionAccumTime` and `gainedXP` in character-scoped saved
variables, so a `/reload` does not reset the session. Our addon resets session data on each
login. This could be a useful option.

### 4. Faction Selection Dropdown

A UI that iterates the full reputation list, expands collapsed headers, organizes factions
by expansion/subgroup, and lets the user pick a specific faction to track. Tags known delve
companions. Handles the tricky case of collapsed headers shifting indices during iteration.

---

## Conclusion

The two addons are independent implementations solving the same problem. No code was copied.
Our addon is significantly more architecturally ambitious (7 styles, animations, mixin
composition, EventBus, immutable contexts) while the reference addon covers reputation and
companion tracking that we currently lack. The detailed feature analyses linked above
provide a specification basis for implementing these features within our existing architecture.
