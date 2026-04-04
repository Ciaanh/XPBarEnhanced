# Backlog: Faction Selection Dropdown

Priority: P2
Effort: Medium
Risk: Medium
Source: docs/analysis/reputation-bar-feature.md, docs/analysis/reference-addon-comparison.md

## Summary

Add a dropdown UI in the options panel (or a right-click context menu on the reputation bar) that lets the user pick a specific faction to track, instead of always following the Blizzard watched faction.

## Motivation

Currently the reputation bar always tracks whichever faction the player has pinned in the Blizzard Reputation panel. Users may want to track a different faction without changing their Blizzard watched faction, or may want to track a faction that can't be easily watched via the default UI.

The reference addon implements this feature with a full faction list dropdown organized by expansion/subgroup, including tagging of delve companions.

## Scope

### In Scope

- Dropdown or context menu listing all known factions (iterated via `C_Reputation.GetNumFactions` / `GetFactionDataByIndex`).
- Expand collapsed headers during iteration (with restore).
- Organize by expansion or category headers.
- Tag delve companions.
- "Follow Watched Faction" option (default, current behavior).
- Store selected `factionID` in SavedVariables.
- `ReputationSession` reads the stored factionID instead of always calling `GetWatchedFactionData()`.

### Out of Scope

- Multiple simultaneous faction bars (one bar, one faction).
- Companion-specific faction selection (companion bar has its own detection logic).

## Tasks

1. Build a faction iteration utility that expands headers, collects all non-header factions, and restores collapse state.
2. Create a dropdown or context menu UI populated from the faction list.
3. Add `trackedFactionID` config key (default: nil = follow watched).
4. Modify `ReputationSession._SnapshotWatchedFaction()` to prefer `trackedFactionID` when set.
5. Add "Follow Watched Faction" as the first option (clears `trackedFactionID`).
6. Wire the dropdown into the options panel or as a right-click menu on the reputation bar.
7. Add locale strings.

## Affected Files

- core/services/ReputationSession.lua
- core/config/defaults.lua
- ui/options/Options.lua or ui/secondary/FlatReputationBarStyle.lua (context menu)
- locales/enUS.lua

## Acceptance Criteria

- [ ] User can select a specific faction from the dropdown.
- [ ] Selected faction persists across reload/login.
- [ ] "Follow Watched Faction" restores default behavior.
- [ ] Reputation bar renders the selected faction's data correctly for all 4 rep types.
- [ ] Faction list handles collapsed headers without corrupting the Blizzard UI state.

## References

- docs/analysis/reputation-bar-feature.md "Faction Selection" section.
- Reference addon's `BuildFactionDropdown()` pattern (documented in analysis).
