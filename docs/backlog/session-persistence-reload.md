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

1. Add `resetOnReload = false` to `core/config/defaults.lua`.
2. Add `sessionAccumTime` field initialization in `Session:ensureSessionDefaults()`.
3. In `Session:OnEnteringWorld()`, on reload path: rebase `sessionStart = time() - sessionAccumTime`.
4. In `Session:OnXPUpdate()`, persist `sessionAccumTime = time() - sessionStart`.
5. Add locale strings: `OPT_RESET_ON_RELOAD`, `OPT_RESET_ON_RELOAD_DESC`.
6. Add checkbox option in `OptionMetadata.lua` and `Options.lua` under a "Session" section.

## Affected Files

- core/config/defaults.lua
- core/services/Session.lua
- locales/enUS.lua
- ui/options/OptionMetadata.lua
- ui/options/Options.lua

## Acceptance Criteria

- [ ] After `/reload`, session time continues from where it was (no reset).
- [ ] After `/reload`, XP/hour calculation uses accumulated time, not time since reload.
- [ ] With `resetOnReload = true`, session resets on reload (original behavior).
- [ ] Fresh login always starts a new session regardless of setting.
- [ ] Option toggle appears in the options panel.
