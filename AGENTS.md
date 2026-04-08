# WoW Addon Development Environment

World of Warcraft Addon project targeting Retail Patch 12.0.0+ (Midnight).

## Interface Version
120001

## Language & Framework
- Lua 5.1 (WoW variant — no os/io/debug libraries)
- XML (Blizzard XML schema for UI definitions)
- TOC (Table of Contents for addon metadata)
- Optional: Ace3 suite, LibStub, CallbackHandler

## Reference Data
Adjust REFS_ROOT if your addon project is not a sibling of the reference directories.

REFS_ROOT: ../../Blizzard_UI_refs

- Blizzard UI Source: ${REFS_ROOT}/BlizzardInterfaceCode/Interface/AddOns/
- KethoDoc Resources: ${REFS_ROOT}/BlizzardInterfaceResources/Resources/
- Art Assets: ${REFS_ROOT}/BlizzardInterfaceArt/Interface/

### Searchable Resource Files
| File | Content |
|------|---------|
| GlobalAPI.lua | ~6600 global C API function names |
| Events.lua | ~2100 events categorized by system |
| WidgetAPI.lua | Widget types, inheritance, methods, handlers |
| CVars.lua | ~1740 CVars with defaults and help text |
| LuaEnum.lua | ~9000 enum constant definitions |
| AtlasInfo.lua | ~21000 atlas texture coordinates |
| FrameXML.lua | ~6200 FrameXML-defined Lua functions |
| Templates.lua | ~3690 XML templates with types and mixins |
| Mixins.lua | ~3045 mixin class names |
| Frames.lua | ~540 named global frames |

## Coding Standards
- ALL variables local unless required global (SavedVariables, SLASH_ globals)
- Prefix globals with addon name
- PascalCase frame names, camelCase locals
- Namespace via: local addonName, ns = ...
- Cache globals: local UnitHealth = UnitHealth
- Prefer events over OnUpdate
- Check InCombatLockdown() before secure frame changes
- Validate APIs: if C_Namespace and C_Namespace.Func then
- Never replace Blizzard functions — use hooksecurefunc()

## CRITICAL: Patch 12.0.0 Breaking Changes
Consult the wow-api-midnight-changes skill before writing code involving:
combat data, unit identification, addon messaging, spell APIs, or combat log.

## API Lookup
1. wow-api-index skill → find domain skill
2. Domain skill → signatures, params, examples
3. Search BlizzardInterfaceResources for raw data
4. Search BlizzardInterfaceCode for Blizzard usage patterns
5. Fallback: https://warcraft.wiki.gg/wiki/API_<FunctionName>

## Available Agents
- @developer — WoW addon developer expert
- @validator — Blizzard UI & API validator
- @uiux — UI/UX design expert
- @tester — Addon testing specialist

## Documentation Governance
- Canonical planning/backlog/docs location is `docs/`.
- Active coding session guide: `docs/plan.md`.
- Durable analysis and lessons: `docs/memory/*.md`.
- Architecture and structure guidance: `docs/guidelines/*.md`.
- Feature tracking: one file per feature under `docs/features/*.md`.
- `.claude/plan.md` is compatibility pointer-only and MUST NOT be used as source of truth.
- Any change that affects behavior or architecture should update the relevant file in `docs/` in the same PR.
