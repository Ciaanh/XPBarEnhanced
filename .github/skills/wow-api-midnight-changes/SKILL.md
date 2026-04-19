---
name: wow-api-midnight-changes
description: "Complete reference for Patch 12.0.0 (Midnight) API breaking changes. Covers Secret Values system, combat log removal, instance restrictions, 138 removed APIs, 437 new APIs, 76 new events, and migration patterns. MUST be consulted before writing code involving combat data, spell APIs, unit identification, addon messaging, or combat log."
---

# Patch 12.0.0 (Midnight) — Critical API Changes

> **Interface baseline: `120001+` (this repo currently uses `120005`)**
> These changes are ACTIVE in pre-patch (12.0.0) and Midnight launch (12.0.1).
> Prior API knowledge from 11.x and earlier **does not apply** for the systems listed below.

For the full detailed reference, read the instruction file:
`wow-api-important.instructions.md` (auto-applied to *.lua, *.xml, *.toc files)

---

## 1. Secret Values — The New Security Model

Many APIs that previously returned plain numbers/strings now return **secret values** that addon code cannot inspect.

### What Addon Code CANNOT Do With Secrets
- **Compare** (`if secret then`, `secret == x`) → Lua error
- **Arithmetic** (`secret + 1`) → Lua error
- **Use as table keys** (`t[secret] = x`) → Lua error
- **Length operator** (`#secret`) → Lua error
- **Index** (`secret["foo"]`) → Lua error

### What Addon Code CAN Do With Secrets
- Store in variables/tables (as values, not keys)
- Pass to C API functions marked as accepting secrets
- Concatenate via `string.format`, `string.join`
- Check type with `type(secret)` → returns real type
- Test with `issecretvalue(value)` and `canaccessvalue(value)`

### Affected APIs (return secrets in combat)
- `UnitHealth()`, `UnitHealthMax()`, `UnitPower()`, `UnitPowerMax()`
- `UnitName()`, `UnitClass()`, `UnitRace()`, `UnitLevel()` (when restricted)
- Most unit information functions in combat context

### Correct Pattern
```lua
-- WRONG: branches on secret
local health = UnitHealth("target")
if health > 0 then ... end  -- ERROR in combat

-- RIGHT: pass secrets directly to APIs documented as secret-compatible
healthBar:SetMinMaxValues(0, UnitHealthMax("target"))
healthBar:SetValue(health)
```

## 2. Combat Log Removal
- `COMBAT_LOG_EVENT_UNFILTERED` → **no longer fires for addon code**
- `CombatLogGetCurrentEventInfo()` → **blocked for addon code**
- **Replacement**: `C_DamageMeter` namespace for aggregate combat data
- Individual combat events still fire (UNIT_HEALTH, SPELL_CAST_*, etc.)

## 3. Instance Restrictions
- `SendAddonMessage()` → **blocked in instances**
- Chat messages in instances → **secret strings**
- `C_ChatInfo.SendAddonMessage()` → same restriction
- Design addOns to function without in-instance addon comms; pre-instance coordination remains possible

## 4. Major Removed APIs (138 total)
Key removals — do NOT use these:
- `GetSpellInfo()`, `GetSpellCooldown()`, `GetSpellCharges()`, `GetSpellCount()`
- `GetSpellTexture()`, `GetSpellDescription()`, `GetSpellBaseCooldown()`
- `CombatLogGetCurrentEventInfo()`
- `UnitCastingInfo()`, `UnitChannelInfo()` (old signatures)
- `GetActionInfo()`, `GetActionTexture()` (old forms)

### Replacements
| Removed | Replacement |
|---------|------------|
| `GetSpellInfo(id)` | `C_Spell.GetSpellInfo(id)` → SpellInfo table |
| `GetSpellCooldown(id)` | `C_Spell.GetSpellCooldown(id)` → CooldownInfo table |
| `GetSpellCharges(id)` | `C_Spell.GetSpellCharges(id)` → ChargesInfo table |
| `GetSpellTexture(id)` | `C_Spell.GetSpellTexture(id)` |
| `GetSpellDescription(id)` | `C_Spell.GetSpellDescription(id)` |
| `CombatLogGetCurrentEventInfo()` | `C_DamageMeter.*` APIs |
| `UnitCastingInfo(unit)` | Use updated return handling (`notInterruptible` can be nil) and `UNIT_SPELLCAST_*` events where appropriate |

## 5. Major New APIs (437 total)
Key new namespaces:
- `C_DamageMeter` — aggregate combat data (replaces combat log parsing)
- `C_CurveUtil` — create curves from secret values for display
- `C_DurationUtil` — duration objects for secret time values
- `C_RestrictedActions` — instance-safe action framework
- `C_Secrets` — secret value management utilities
- `C_ActionBar` — new action bar query functions

## 6. New Events (76 total)
Key new events:
- `DAMAGE_METER_*` events replacing combat log events
- `ADDON_RESTRICTION_STATE_CHANGED` for restriction state transitions
- `ENCOUNTER_STATE_CHANGED` and `ENCOUNTER_WARNING` for encounter-driven flows

## 7. Design Philosophy
These changes exist to:
- Prevent automated decision-making based on combat state (bot prevention)
- Allow UI display while constraining decision-making on combat-sensitive values
- Maintain addon communication outside instances
- Provide aggregate data (damage meters) without per-event combat log
