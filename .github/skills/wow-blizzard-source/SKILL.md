---
name: wow-blizzard-source
description: "Guide for searching Blizzard's official UI source code (BlizzardInterfaceCode). Use when you need to find how Blizzard implements specific UI patterns, uses APIs, structures XML templates, or handles events. Contains search instructions and key addon directory references."
---

# Searching Blizzard UI Source Code

The Blizzard UI source code contains 310 addon directories with 2257 Lua files, 1026 XML files, and 345 TOC files. It is the definitive reference for how WoW's UI works.

## Location

```
${REFS_ROOT}/BlizzardInterfaceCode/Interface/AddOns/
```

All addons are prefixed with `Blizzard_`.

## How to Search

### Find API Usage Patterns
```
Grep "FunctionName" in ${REFS_ROOT}/BlizzardInterfaceCode/Interface/AddOns/ --type lua
```

### Find XML Templates and Frames
```
Grep "TemplateName" in ${REFS_ROOT}/BlizzardInterfaceCode/Interface/AddOns/ --type xml
```

### Find Event Handling Patterns
```
Grep "EVENT_NAME" in ${REFS_ROOT}/BlizzardInterfaceCode/Interface/AddOns/ --type lua
```

### Find Mixin Implementations
```
Grep "MixinNameMixin" in ${REFS_ROOT}/BlizzardInterfaceCode/Interface/AddOns/ --type lua
```

### Read a Specific Addon's Structure
1. Read its TOC file: `Blizzard_<Name>/<Name>.toc` or `Blizzard_<Name>/Blizzard_<Name>.toc`
2. TOC lists files in load order — read them in that order
3. Check for flavor subdirectories: Mainline/, Shared/, Classic/, Mists/

## Key Addons by Domain

### Core Framework
| Addon | Content |
|-------|---------|
| `Blizzard_SharedXMLBase` | Mixin.lua, TableUtil, Color, Pools, EnumUtil, CallbackRegistry |
| `Blizzard_SharedXML` | Scroll system, layout frames, NineSlice, selectors, data providers |
| `Blizzard_FrameXMLBase` | Constants, animated status bars, flow containers |
| `Blizzard_FrameXML` | Core frames: secure templates, tooltips, cinematic, toasts |
| `Blizzard_UIParent` | Root UI parent, chat bubbles |

### API Documentation
| Addon | Content |
|-------|---------|
| `Blizzard_APIDocumentationGenerated` | 576 auto-generated API docs (every C API surface) |
| `Blizzard_APIDocumentation` | API documentation framework |

### Major UI Systems
| Addon | Content |
|-------|---------|
| `Blizzard_UIPanels_Game` | Character, quest log, gossip, merchant panels |
| `Blizzard_ActionBar` | Action bar system |
| `Blizzard_UnitFrame` | Player/target/focus/party unit frames |
| `Blizzard_NamePlates` | Nameplate system |
| `Blizzard_ObjectiveTracker` | Quest/achievement tracker |
| `Blizzard_PlayerSpells` | Spellbook, talents, class specializations |
| `Blizzard_WorldMap` | World map |
| `Blizzard_Settings` | Modern settings framework |
| `Blizzard_Menu` | Modern dropdown menu system |
| `Blizzard_AuctionHouseUI` | Auction house |
| `Blizzard_Communities` | Guild & communities |
| `Blizzard_Collections` | Mount/pet/toy/heirloom journal |
| `Blizzard_UIWidgets` | In-game widget system |
| `Blizzard_SharedTalentUI` | Talent tree framework |
| `Blizzard_EditMode` | UI customization (Edit Mode) |

### Templates & Patterns to Reference
| Pattern | Where to find |
|---------|--------------|
| Button templates | `Blizzard_SharedXML` XML files |
| Scroll/list patterns | `Blizzard_SharedXML` (ScrollBox, DataProvider) |
| Tab system | `Blizzard_SharedXML` (TabSystem) |
| Dialog/popup | `Blizzard_FrameXML` (StaticPopup) |
| Tooltip | `Blizzard_FrameXML` (GameTooltip, SharedTooltipTemplates) |
| Settings panel | `Blizzard_Settings` |
| Dropdown menu | `Blizzard_Menu` |

## Multi-Flavor Structure
Many addons have subdirectories for game versions:
- `Mainline/` — Retail-specific code
- `Shared/` — Code shared across flavors
- `Classic/`, `Cata/`, `Mists/`, `Wrath/` — Classic-specific
- `WoWLabs/` — Plunderstorm
