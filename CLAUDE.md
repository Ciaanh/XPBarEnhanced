# CLAUDE.md

XP Bar Enhanced: replaces the experience bar with styled bars (Classic, Flat, Vertical, Circular,
Minimap Ring, Terminal, Orb), quest XP overlays, session statistics, kills to level and a
secondary bar (reputation, housing, honor, profession). The workspace `CLAUDE.md` covers the
release standard, the dev loop and the harness; `.claude/rules/wow-addon.md` the shared rules.

## Clients

One toc, one manifest: `## Interface:` lists Classic Era, Forever, Burning Crusade, Wrath,
Cataclysm, Mists and Retail. `core/FlavorDetection.lua` resolves the client to a flavor and the
flavor turns features on (`Addon:IsFeatureEnabled`); housing, delves and modern reputation are
Retail only. A Blizzard symbol is checked in every targeted client before use.

## Layout

- `XPBarEnhanced.lua` creates the namespace (`XPBarEnhanced`) and `EventNames`.
- `core/EventRouter.lua` is the only place that registers WoW events; the services under
  `core/services/` (Session, KillXP, QuestXP, the secondary sessions) handle them and broadcast on
  `core/EventBus.lua`. `ContextBuilder` builds the immutable context every bar renders from (one
  per frame, cached until the next).
- `core/config/`: defaults, `Config` (every setting goes through it), presets, profiles.
- `ui/`: `BarManager` / `SecondaryBarManager`, the mixins every style composes, `ui/styles/<style>/`
  (an XML template plus the Lua it lists), options, Stats, minimap button, LibDataBroker feed.
- `tests/`: the Lua 5.1 suite (`tests/README.md`).

## Versions

A version bump touches four places: `XPBarEnhanced.toc` (`## Version:`), the `README.md` header,
`CHANGELOG.md` and `ui/changelog/Changelog.lua` (the in-game What's New).

## Confirmed in game

- Retail 12.1.5, French client (2026-10): `CHAT_MSG_COMBAT_XP_GAIN` carries the kill line in the
  client's language, and the patterns built from the French `COMBATLOG_XPGAIN_*` strings read it
  (kills recorded at level 81; a lower XP for a weaker mob).
- Retail 12.1.5 (2026-10): the gradient fill renders as intended with the option on.
- Retail 12.1.5 (2026-10): with the fold decided once at login, Text › Advanced stays open across
  several setting changes.

## To confirm in game

- Whether a texture's vertex colour and gradient replace each other or multiply. The painting in
  `ui/styles/SharedStyleHelpers.lua` is right either way; check that turning the gradient off
  brings the flat colour back without a `/reload`, on Retail, Classic Era and Forever.
- Whether `CHAT_MSG_COMBAT_XP_GAIN` comes before or after `PLAYER_XP_UPDATE`. After would leave the
  rate text's kills one kill behind until the 2.5 s text refresh.
- Whether the chat line is secret inside instances (kills there would go unrecorded).
- Opening the options in combat (`/xpbe options`, a right-click on the minimap button).
- The `COMBATLOG_XPGAIN_*` strings of the Classic clients (the fixture holds Retail's).
