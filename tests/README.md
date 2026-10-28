# Tests

A Lua 5.1 suite that loads the addon as the client does — the Lua files `XPBarEnhanced.toc`
lists, in its order, then `ADDON_LOADED`, `PLAYER_LOGIN` and `PLAYER_ENTERING_WORLD` through the
real event router — against stubbed WoW apis.

Run it from the repo root (override the interpreter with `LUA=` and `LUAC=` if it is not under
`C:\Program Files (x86)\Lua\5.1`):

```sh
./tests/run.sh
```

## The harness

`harness.lua` holds every stub, the loader and `Check`. A test sets state on the harness and then
loads the addon:

```lua
local H = dofile((arg[1] or ".") .. "/tests/harness.lua")
H.player.level = 20
local Addon = H.Load(nil)   -- nil SavedVariables: a first install
H.Login()
H.player.xp = 400
H.Fire("PLAYER_XP_UPDATE", "player")
H.Check("gain counted", Addon.Session:GetCurrent().gainedXP, 400)
H.Done()
```

- **XML is skipped.** The harness has no template system, so the toc's XML files are not loaded.
  Frames accept any method: `Get*` returns 0, `Is*` / `Has*` / `Can*` false, the rest does
  nothing. The bars' drawing is not under test; the services behind them are.
- **State, not redefinition.** The unit and XP apis read `H.player` (`level`, `xp`, `max`,
  `rested`, `resting`, `maxLevel`); `GetBuildInfo` reads `H.interface`.
- **Time only passes when a test says so.** `time()` is `H.epoch`, `GetTime()` is `H.clock`.
  `H.Advance(seconds)` moves both and runs each `C_Timer` callback when it falls due;
  `H.RunTimers()` runs the ones due now.
- **Sessions**: `H.Login()` (first login), `H.Reload()` (`PLAYER_LOGOUT`, SavedVariables copied,
  addon loaded again, `PLAYER_ENTERING_WORLD(false, true)`), `H.Restart(true, offlineSeconds)`
  (logout, time offline, login).
- **Played time**: `RequestTimePlayed` counts in `H.playedRequests` and answers nothing;
  `H.AnswerPlayed(total, thisLevel)` fires `TIME_PLAYED_MSG` as the server's reply does. Chat
  frames `ChatFrame1..3` listen for it like Blizzard's: `H.chatPlayedLines` counts the replies
  they printed, `H.chatEventChanges` every (un)registration of the event on them.
- **Errors**: the addon's error handler appends to `H.errors`; `H.CheckNoErrors(label)` checks
  it is empty and clears it.
- **Secrets**: `H.Secret(kind)` is a proxy that raises on any use; `type` reports `kind` and
  `issecretvalue` recognises it.

## Files

| File | Covers |
| --- | --- |
| `load.lua` | The addon loads, logs in, counts an XP gain and survives a `/reload` without an error |
