# Backlog: Session Persistence Across /reload

Priority: P1
Effort: Small
Risk: Low
Source: docs/analysis/xp-tracking-improvements-plan.md, docs/analysis/reference-addon-comparison.md

## Summary

Persist session elapsed time across `/reload` so that time-dependent stats (XP/hour, session time, time-to-level) are not disrupted by UI reloads.

## Motivation

Currently, `Session.sessionStart` is set on PLAYER_LOGIN and the elapsed time is computed as `time() - sessionStart`. Across a `/reload`, `gainedXP` is preserved (because `isInitialLogin` is false), but session timing depends on the TIME_PLAYED_MSG response which may lag. An explicit `sessionAccumTime` accumulator, periodically written to SavedVariables, makes session time resilient to reload.

The reference addon (v1.3.2) implements this pattern and users expect /reload to not reset their session stats.

## Scope

### In Scope

- Add `sessionAccumTime` accumulator to session data.
- Persist accumulator to SavedVariables on every XP event.
- Rebase `sessionStart` on reload so elapsed time equals accumulated seconds.
- Add `resetOnReload` config option (default: false) for users who prefer a fresh session on reload.
- Add locale strings and options panel toggle.

### Out of Scope

- Persisting session across full logout/login (session resets on fresh login).
- Reputation/companion session persistence (can be added later with same pattern).

## Tasks

1. [x] Add `resetOnReload = false` to `core/config/defaults.lua`.
2. [x] Add `sessionAccumTime` field initialization in `Session:ensureSessionDefaults()`.
3. [x] In `Session:OnEnteringWorld()`, on reload path: rebase `sessionStart = time() - sessionAccumTime`.
4. [x] In `Session:OnXPUpdate()`, persist `sessionAccumTime = time() - sessionStart`.
5. [x] Add locale strings: `OPT_RESET_ON_RELOAD`, `OPT_RESET_ON_RELOAD_DESC`.
6. [x] Add checkbox option in `OptionMetadata.lua` and `OptionsPanel.xml` under the session-time controls.

## Prep Status (2026-04-05)

- [x] Target file paths confirmed in current repo layout.
- [x] Phase sequencing prepared (data model → session behavior → options/locale → validation).
- [x] Implementation completed for data model, session behavior, and options/locale wiring.

## Implementation Slices (Do in Order)

1. **Data model slice**
   - Add defaults in `core/config/defaults.lua`.
   - Ensure backward compatibility for existing saved variables.
2. **Session logic slice**
   - Update `core/services/Session.lua` defaults and reload handling.
   - Persist accumulator updates during XP event flow.
3. **Options/UI slice**
   - Add metadata and checkbox wiring in `ui/options/OptionMetadata.lua` and `ui/options/Options.lua`.
   - Add labels/help text in `locales/enUS.lua`.
4. **Validation slice**
   - Test `/reload` continuity with `resetOnReload=false`.
   - Test `/reload` reset behavior with `resetOnReload=true`.
   - Test fresh login reset behavior independent of toggle.

## Implementation Status (2026-04-05)

- `resetOnReload` default added and exposed as an option.
- Session accumulator (`sessionAccumTime`) added with reload rebase logic.
- Reload behavior: `resetOnReload=false` continues session timing/rates through `/reload`.
- Reload behavior: `resetOnReload=true` starts a fresh session on `/reload`.
- Localization strings added for the new option.
- In-game validation passed.

## Affected Files

- core/config/defaults.lua
- core/services/Session.lua
- locales/enUS.lua
- ui/options/OptionMetadata.lua
- ui/options/OptionsPanel.xml
- core/services/Database.lua (verify no migration helper needed)

## Acceptance Criteria

- [x] After `/reload`, session time continues from where it was (no reset).
- [x] After `/reload`, XP/hour calculation uses accumulated time, not time since reload.
- [x] With `resetOnReload = true`, session resets on reload (original behavior).
- [x] Fresh login always starts a new session regardless of setting.
- [x] Option toggle appears in the options panel.
