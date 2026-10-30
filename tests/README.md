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
  `H.LoadXMLScripts()` runs the Lua files they list (`<Script file>`: the styles, Stats, Options)
  for a test that builds its frames from those mixins. Frames accept any method named like a widget method (`Set*`, `Get*`, `Is*`, `Create*`, ...):
  `Get*` returns 0, `Is*` / `Has*` / `Can*` false, the rest does nothing; any other unset field
  reads as nil. The bars' drawing is not under test; the services behind them are.
- **WoW's `xpcall`**: extra arguments reach the function, as in the client.
- **State, not redefinition.** The unit and XP apis read `H.player` (`level`, `xp`, `max`,
  `rested`, `resting`, `maxLevel`, `xpDisabled`); `GetBuildInfo` reads `H.interface`.
- **Time only passes when a test says so.** `time()` is `H.epoch`, `GetTime()` is `H.clock`.
  `H.Advance(seconds)` moves both and runs each `C_Timer` callback when it falls due;
  `H.RunTimers()` runs the ones due now.
- **Sessions**: `H.Login()` (first login), `H.Reload()` (`PLAYER_LOGOUT`, SavedVariables copied,
  addon loaded again, `PLAYER_ENTERING_WORLD(false, true)`), `H.Restart(true, offlineSeconds)`
  (logout, time offline, login). `H.ResetUI()` drops the running UI so a test can `H.Load` other
  SavedVariables (an older version's, say).
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
| `xp_rate.lua` | `CalculateXPPerHour` (windows, "This session", the 5-minute floor, the fallback before anything is measured) and `LevelRate`; through real events: gains merged within 5 s (never across sources or levels), the 1000-entry cap, the `xpRateWindow` setting, a burst of quest XP right after a ding adding only its XP to the hour |
| `kill_xp.lua` | Kill lines read with patterns built from the game's strings: English (plain, group, raid, rested, tired, and their mixes), French, Korean (positional arguments, `|1` grammar) and Russian (`|4`); every Retail locale's own strings together (`fixtures/combatlog_xpgain.lua`, from the KethoDoc dump), each kind of line in each; unnamed, quest and secret lines are no kill; the rested sum; through `CHAT_MSG_COMBAT_XP_GAIN`: the average (this level's once there are 3, else the last two levels', unknown further up), the last 20 kept, unknown at max level or with XP turned off, kept across a logout, cleared by `resetstats`; the option, the presets, and Leveller settings saved before the option still Leveller |
| `gradient.lua` | Colours derived from the configured one; with `fillGradient` on, the fill and the rested and quest overlays painted as their stretch of one gradient across the bar (horizontal, or bottom to top for Vertical), only for styles declaring the capability; flat colours back when the option goes off, and for the session when `SetGradient` refuses. Every check is on what the player sees, with a vertex colour and a gradient replacing each other and with them multiplied; the Flat, Classic and Vertical mixins' own code; no colour object made per animation frame |
| `played_time.lua` | Level time counted by the addon: a lower bound ("+") from a login, exact from a ding or any played time reply, carried across `/reload` and logout (offline time left out), reset when the level changed with the addon off; `requestPlayedTime` off never asks, on asks once 5 s after a login while not exact, with the reply kept out of chat and the chat frames' event handed back (also when the reply is lost); a secret reply changes nothing; the minimap button's Shift+click and `resetstats` keep it; a store with no anchor carries nothing; 1.3.0 SavedVariables read as a lower bound |
| `display.lua` | The kills line in the bar tooltip, the rate text, the LibDataBroker tooltip and the Stats window, before and after a kill; the secondary bar taking no clicks while hidden; an update during the level-up hold leaving the fill alone; the styles declaring `fillGradient` are the ones the options panel lists |
| `options_panel.lua` | The options panel's fold state is decided at login, after a profile switch and after a reset: a setting change refreshes the panel without folding Advanced away (`Options.lua` is loaded by hand, as its XML is skipped) |
