# Backlog: Additional Secondary Bar Styles

Status: **DONE** — implemented 2026-04-12 (session 4), model simplified 2026-04-13 (session 5)

Priority: P3
Source: feature gap analysis

**Investigation document**: `docs/analysis/secondary-bar-styles-investigation.md`

## Delivered Scope

- **Classic** style (`classic`): Blizzard-style bordered bar with standing-color atlas fill (`UI-HUD-ExperienceBar-Fill-Reputation-Faction-*`). Centered label (faction name + standing + %). Matches the Classic primary bar appearance.
- **Minimal** style (`minimal`): 6 px slim bar, solid faction color fill, tooltip-only. Files exist; currently dormant — no `TEMPLATE_MAP` entry maps to it yet.
- **Style selection model**: 1:1 primary bar style → secondary template via `TEMPLATE_MAP` in `SecondaryBarManager.lua`. No user-facing `secondaryBarStyle` config key. New styles are activated purely by adding an entry to `TEMPLATE_MAP`. Primary styles without an entry (`vertical`, `circular`, `minimap_ring`, `terminal`) produce no secondary bar until their templates are built.

## Files

- `ui/styles/classic/ClassicSecondaryBarStyle.lua`
- `ui/styles/classic/ClassicSecondaryBarTemplate.xml`
- `ui/styles/minimal/MinimalSecondaryBarStyle.lua` *(dormant)*
- `ui/styles/minimal/MinimalSecondaryBarTemplate.xml` *(dormant)*
- `ui/SecondaryBarManager.lua` — `TEMPLATE_MAP` + `DeriveSecondaryStyle`

## Remaining Work

| Primary Style | Secondary Approach | Phase | Status |
| --- | --- | --- | --- |
| `flat` | `FlatReputationBarTemplate` — horizontal solid-color bar + label | — | ✅ Live |
| `classic` | `ClassicReputationBarTemplate` — bordered atlas fill + label | — | ✅ Live |
| `vertical` | `VerticalReputationBarTemplate` — 20×300 vertical StatusBar, right-attached | 3 | ✅ Live |
| `terminal` | `TerminalReputationBarTemplate` — single ASCII phosphor line | 4 | ✅ Live |
| `circular` | Concentric ring — approach TBD | 5 | ❌ Investigation needed |
| `minimap_ring` | Ring at different radius — approach TBD | 6 | ❌ Investigation needed |
