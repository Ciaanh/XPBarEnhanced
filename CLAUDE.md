# CLAUDE.md

XP Bar Enhanced: replaces the experience bar with styled bars (Classic, Flat, Vertical, Circular,
Minimap Ring, Terminal, Orb, Ring), quest XP overlays, session statistics, kills to level and a
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
- Retail 12.1.5 (2026-11): the Ring style draws as `RingGeometry` computes. The full ring starts at
  the top and fills clockwise. The 270° arc is open at the bottom or the right, and fills in both
  directions. XP, completed quests and rested XP follow each other along the arc. At inner radius
  30 the time-to-level line is dropped. A width of 40 draws cleanly. The panel's Ring rows set it
  live, for example a 180° arc at inner radius 50 and width 15.
- Retail 12.1.5 (2026-11): Ring's secondary ring draws inside and outside the primary, follows its
  arc, and attaches and detaches like the other styles' secondary bars.
- Forever 1.60.1 (2026-11): Ring is offered and draws as on Retail. A 270° arc open at the bottom
  or the right fills as `RingGeometry` computes at 67.5% and 83.7%, including a fill that runs
  through the bottom (offset 0). The getters return the offsets as set (Track 0.125 / 0.25, Fill
  0.125 / 0.3725 for the arc open at the bottom). The radial fill turns with the texture:
  `SetRotation(math.pi)` on the track and fill moves the arc's opening to the top.
- Forever 1.60.1 (2026-11): the complete ring starts at the top and fills clockwise (83.7% ends near
  10 o'clock), with the spark on the tip. The track at opacity 1 is a clear dark band. At width 25,
  the rounded ends take the XP colour at the start and the track's at the far end. 10 ticks draw 9
  dividers across the band. The secondary ring inside follows the arc with its own fill, track and
  ticks, and the centre text still fits. No BugSack error. The ticks (black, 0.6) don't show on the
  track: only on the fill.
- Forever 1.60.1 (2026-11): a right-click opens the reputation panel from the main ring while the
  secondary ring is attached, and from the secondary ring once it is detached. Detached, the
  secondary ring moves with shift-drag and has its own tooltip (source, progress, click and drag
  hints).
- Forever 1.60.1 (2026-11): a standard faction's secondary tooltip reads its progress within the
  standing, matching the bar: Stormwind Friendly at 4,745 shows 1,745 / 6,000 and 29.1% (it read
  4,745 / 9,000 and 52.7% before `GetDisplayProgressValues` subtracted the standing's threshold).
- Forever 1.60.1 (2026-11): the secondary ring draws around the primary. Attached, the main ring's
  tooltip adds the source's section (Stormwind, 29.1%, 1,745 / 6,000) and the "Right-click: open
  Reputation" hint.

## To confirm in game

- Whether a texture's vertex colour and gradient replace each other or multiply. The painting in
  `ui/styles/SharedStyleHelpers.lua` is right either way; check that turning the gradient off
  brings the flat colour back without a `/reload`, on Retail, Classic Era and Forever.
- Whether `CHAT_MSG_COMBAT_XP_GAIN` comes before or after `PLAYER_XP_UPDATE`. After would leave the
  rate text's kills one kill behind until the 2.5 s text refresh.
- Whether the chat line is secret inside instances (kills there would go unrecorded).
- Opening the options in combat (`/xpbe options`, a right-click on the minimap button).
- The `COMBATLOG_XPGAIN_*` strings of the Classic clients (the fixture holds Retail's).
