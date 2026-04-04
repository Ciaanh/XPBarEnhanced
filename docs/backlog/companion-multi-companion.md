# Backlog: Multi-Companion Support

Priority: P3
Effort: Small
Risk: Low
Source: docs/analysis/delve-companion-feature.md

## Summary

Extend companion tracking to support multiple delve companions (currently Brann Bronzebeard and Valeera Sanguinar, with potential future additions).

## Motivation

The current `CompanionSession` is implemented generically but may only detect one companion automatically. As WoW adds more delve companions in future patches, the addon should be able to:
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
5. Update `CompanionSession` to track the selected companion.
6. Add locale strings.

## Affected Files

- core/services/CompanionSession.lua
- core/calculations/CompanionCalculations.lua
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
