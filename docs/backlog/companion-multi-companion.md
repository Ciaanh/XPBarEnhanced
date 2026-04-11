# Backlog: Multi-Companion Support

**Status: CLOSED — 2026-04-12**

Closed without implementation. Rationale: the `defaults.delveCompanions` faction ID dictionary (Brann 2640, Valeera 2744) is sufficient for the current companion roster. A `C_DelvesUI` API review and dynamic discovery system are not warranted at this time. If Blizzard adds further companions, extend the dictionary directly.

---

## Summary

Extend companion tracking to support multiple delve companions (currently Brann Bronzebeard and Valeera Sanguinar, with potential future additions).

## Motivation

The current companion tracking is handled by `ReputationSession` (NR-3 unified the former `CompanionSession` into it). The pipeline may only detect one companion automatically. As WoW adds more delve companions in future patches, the addon should be able to:
- Auto-detect all available companions.
- Let the user choose which companion to track.
- Display the tracked companion in the companion bar.

## Scope

### In Scope

- Auto-detection of all friendship factions that are delve companions (using `C_DelvesUI` if available, or faction ID whitelist).
- Config key to store selected companion factionID.
- Dropdown or selector in options to pick which companion to track.
- Graceful handling when a companion becomes unavailable.

### Out of Scope

- Displaying multiple companion bars simultaneously.
- Cross-character companion progress comparison.

## Tasks

1. Review `C_DelvesUI` API for companion enumeration capabilities.
2. Implement companion discovery that finds all available delve companions.
3. Add `trackedCompanionFactionID` config key (default: auto-detect primary companion).
4. Add companion selection dropdown to options panel.
5. Update `ReputationSession` to track the selected companion (companion detection uses `defaults.delveCompanions` dict, with legacy name fallback).
6. Add locale strings.

## Affected Files

- core/services/ReputationSession.lua
- core/config/defaults.lua
- ui/options/OptionMetadata.lua
- ui/options/Options.lua
- locales/enUS.lua

## Acceptance Criteria

- [ ] All available delve companions are discoverable.
- [ ] User can select which companion to track.
- [ ] Selected companion persists across reload/login.
- [ ] Companion bar displays the selected companion's data.
- [ ] Auto-detect mode picks the most relevant companion.
