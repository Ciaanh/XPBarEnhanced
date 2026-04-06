# Backlog: Multi-Language Localization

Status: Closed - Not Planned (2026-04-06)

Priority: P3
Effort: Medium
Risk: Low
Source: docs/analysis/delve-companion-feature.md, feature gap analysis

## Summary

This item is no longer part of the active roadmap.

Add localization support for additional languages beyond enUS. The addon uses AceLocale-3.0 but currently only ships enUS strings.

## Motivation

Decision update (2026-04-06): localization expansion is not needed for the current product scope.

The addon already has the localization infrastructure (LibStub + AceLocale-3.0) and all user-facing strings use `L["KEY"]` lookups. Adding translation files is straightforward. Additionally, the companion detection logic uses English companion names ("Brann Bronzebeard", "Valeera Sanguinar") as hardcoded strings, which won't work on non-English clients.

## Scope

Roadmap status: superseded by planning decision; implementation is not approved.

### In Scope

- Add locale files for high-demand languages: deDE, frFR, esES, ptBR, zhCN, zhTW, koKR, ruRU.
- Convert companion name detection from hardcoded English strings to faction ID-based detection (locale-safe).
- Ensure all option labels, tooltips, and user-visible text use locale keys.

### Out of Scope

- Community translation management (CurseForge/Crowdin integration).
- Dynamic language switching at runtime.

## Tasks

1. Audit `locales/enUS.lua` for completeness — ensure every user-visible string has a key.
2. Create locale stub files (e.g., `locales/deDE.lua`) with `AceLocale-3.0` `NewLocale` calls.
3. Populate translations for priority languages (community contributions welcome).
4. Convert companion detection in `CompanionCalculations.lua` from name-based to factionID-based lookup.
5. Add locale files to TOC.
6. Add `X-Localizations` metadata to TOC.

## Affected Files

- New: locales/deDE.lua, locales/frFR.lua, etc.
- core/calculations/CompanionCalculations.lua
- XPBarEnhanced.toc

## Acceptance Criteria

- [ ] Non-English clients display translated strings (where translations exist).
- [ ] Missing translations fall back to enUS gracefully (AceLocale default behavior).
- [ ] Companion detection works on non-English clients.
- [ ] No hardcoded English strings in user-visible paths.

## Closure Note

- Closed by product direction during pre-Phase-7 planning.
- Keep this document as historical reference only.
