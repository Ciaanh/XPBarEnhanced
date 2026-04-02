# WoW Addon Development Environment

## Project Type
World of Warcraft Addon — Retail (Patch 12.0.0+ / Midnight)

## Interface Version
120000

## Language & Framework
- Primary: Lua 5.1 (WoW variant — no os/io/debug libraries)
- UI Definitions: XML (Blizzard XML schema)
- Configuration: TOC (Table of Contents) files
- Optional Libraries: Ace3 suite, LibStub, CallbackHandler

## Reference Data Locations
Adjust REFS_ROOT if your addon project is not a sibling of these directories.

REFS_ROOT: ../../Blizzard_UI_refs

- Blizzard UI Source: ${REFS_ROOT}/BlizzardInterfaceCode/Interface/AddOns/
- KethoDoc Resources: ${REFS_ROOT}/BlizzardInterfaceResources/Resources/
- Art Assets: ${REFS_ROOT}/BlizzardInterfaceArt/Interface/

## Key Resource Files (searchable via Grep/Read)
- Global C APIs: ${REFS_ROOT}/BlizzardInterfaceResources/Resources/GlobalAPI.lua
- Events by system: ${REFS_ROOT}/BlizzardInterfaceResources/Resources/Events.lua
- Widget methods: ${REFS_ROOT}/BlizzardInterfaceResources/Resources/WidgetAPI.lua
- CVars: ${REFS_ROOT}/BlizzardInterfaceResources/Resources/CVars.lua
- Enumerations: ${REFS_ROOT}/BlizzardInterfaceResources/Resources/LuaEnum.lua
- Atlas textures: ${REFS_ROOT}/BlizzardInterfaceResources/Resources/AtlasInfo.lua
- FrameXML functions: ${REFS_ROOT}/BlizzardInterfaceResources/Resources/FrameXML.lua
- XML Templates: ${REFS_ROOT}/BlizzardInterfaceResources/Resources/Templates.lua
- Mixin classes: ${REFS_ROOT}/BlizzardInterfaceResources/Resources/Mixins.lua
- Global frames: ${REFS_ROOT}/BlizzardInterfaceResources/Resources/Frames.lua

## Coding Standards
- ALL variables and functions must be local unless required to be global
- Prefix necessary globals with the addon name: MyAddon_GlobalFunc
- Use PascalCase for frame names, camelCase for local variables
- Use the addon namespace table: local addonName, ns = ...
- Cache frequently-used globals: local UnitHealth = UnitHealth
- Prefer events over OnUpdate polling
- Always check InCombatLockdown() before modifying secure frames
- Validate API existence: if C_Namespace and C_Namespace.Func then
- Never replace Blizzard functions directly — use hooksecurefunc()

## CRITICAL: Patch 12.0.0 Breaking Changes
Read the wow-api-midnight-changes skill BEFORE writing code that touches:
- Combat data (health, combat log, damage meters) — Secret Values system
- Unit identification in combat — Secret aspects on widgets
- Addon communication in instances — SendAddonMessage blocked
- Spell APIs — old GetSpellInfo/GetSpellCooldown fully removed
- Combat log — COMBAT_LOG_EVENT_UNFILTERED no longer available

## API Lookup Workflow
1. Check the wow-api-index skill to find which domain skill covers the API
2. Read that domain skill for function signatures, parameters, and examples
3. Grep BlizzardInterfaceResources for raw API/event/enum data
4. Grep BlizzardInterfaceCode for Blizzard's own usage patterns
5. Fall back to https://warcraft.wiki.gg/wiki/API_<FunctionName>

## Specialized Agents
- @developer or /project:developer — WoW addon developer expert
- @validator or /project:validator — Blizzard UI & API validator
- @uiux or /project:uiux — UI/UX design expert
- @tester or /project:tester — Addon testing specialist

## Addon File Structure Convention
```
MyAddon/
  MyAddon.toc           -- Metadata and file list
  Init.lua              -- Namespace setup, constants
  Core.lua              -- Event handling, initialization
  UI.xml                -- Frame definitions
  UI.lua                -- Frame scripts, UI logic
  Config.lua            -- Settings, slash commands
  Libs/                 -- Embedded libraries
  Locales/              -- Localization files
```
