# XPBarEnhanced — login disconnect on the Forever beta

**Status: root cause identified and confirmed. Fix implemented, not yet verified in game.**

Last updated 2026-09-19. This replaces an earlier handoff whose leading
hypothesis (a protected Blizzard status-bar race) has since been disproven. See
"Retired hypotheses" below so nobody re-opens them.

---

## 1. Symptom

On the WoW beta client codenamed "Forever" (`_classic_beta_`), XPBarEnhanced
caused a silent client disconnect on login. No Lua traceback. The addon's own
startup log always reached its final line and then the connection dropped:

```
OnAddonLoaded start / complete
OnPlayerLogin start / complete
OnPlayerEnteringWorld start (initial=true reload=false)
OnPlayerEnteringWorld complete
<disconnect>
```

---

## 2. Root cause

The Forever beta runs as Blizzard game type **`camelot`**, which is a distinct
game type from `classic` and `vanilla`. The addon's classic detection did not
recognise it, so every classic guard in the codebase was inert on the one client
being tested, and the retail-only housing subsystem ran against a realm with no
housing service.

### The detection failed on both branches

Old code in `XPBarEnhanced.lua`:

```lua
Addon.IsClassicEra = rawget(_G, "WOW_PROJECT_ID") == rawget(_G, "WOW_PROJECT_CLASSIC")
if not Addon.IsClassicEra and GetBuildInfo then
    local interfaceVersion = tonumber(select(4, GetBuildInfo())) or 0
    Addon.IsClassicEra = interfaceVersion >= 11500 and interfaceVersion < 12000
end
```

Runtime evidence captured in game (addon disabled, so the client survived long
enough to run it):

```
/run print(WOW_PROJECT_ID, WOW_PROJECT_CLASSIC, select(4,GetBuildInfo()))
--> 1   2   16001
```

| Value | Result |
| --- | --- |
| `WOW_PROJECT_ID` | 1, which is `WOW_PROJECT_MAINLINE`, not 2 |
| interface version | 16001, outside the 11500 to 11999 band |

So `IsClassicEra` was **false**, and every `not Addon.IsClassicEra` gate opened.

Corroboration: the comparison addon at `_refs/XPBarEnhanced` declares
`## Interface: 16001,11508,20505,38000,50503,120100`, listing 16001 first. That
independently confirms 16001 is the Forever interface version.

### Why the project constants cannot work here

From the Blizzard source dump at
`/Volumes/Dev/WoW/_Workspace/Blizzard_UI_refs/Forever/BlizzardInterfaceCode`:

- `Blizzard_ProjectConstants/ProjectConstants.lua` defines only
  `WOW_PROJECT_MAINLINE = 1` and `WOW_PROJECT_CLASSIC = 2`.
- Nothing assigns `WOW_PROJECT_ID` on camelot. Only `Cata/Constants.lua`,
  `Mists/Constants.lua` and `Blizzard_BNet/Mainline/BNet.lua` assign it, and the
  BNet fallback is `WOW_PROJECT_ID or WOW_PROJECT_MAINLINE`.
- For a camelot client, `[Family]` resolves to `Mainline` and `[Game]` resolves
  to `Camelot`, so it is built on the 12.x codebase.
- `Blizzard_Deprecated` maps game type `classic` to 1.15.8 and `mainline` to
  12.x. Camelot gets neither.

A camelot client therefore reports mainline. Any `WOW_PROJECT_CLASSIC`
comparison will misclassify it as retail, permanently.

### The TOC compounds it

TOC filename suffixes select the file list. A camelot client does **not** pick
`-Classic`, so it falls back to the unsuffixed `XPBarEnhanced.toc`. That is the
retail file list, and unlike `XPBarEnhanced-Classic.toc` it ships
`core/services/HousingSession.lua` and `core/services/ReputationSession.lua`.
The housing module was both loaded and ungated.

### What actually hit the wire

A full sweep found only **three** server-bound calls in the whole addon.
Everything else, including all XP, honor, profession, quest-log and reputation
work, is a client-side read.

| Call | Timing on a fresh login |
| --- | --- |
| `RequestTimePlayed` | +0.5s after entering world |
| `C_Housing.GetCurrentHouseLevelFavor` | at login and at entering world |
| `C_Housing.GetPlayerOwnedHouses` | +2s after entering world |

`RequestTimePlayed` is cleared as a suspect: the `_refs` addon calls it on this
same client and does not disconnect. The housing pair is the only server traffic
unique to this addon, and the two-second timer in
`HousingSession:OnEnteringWorld` lands exactly in the observed gap after
"OnPlayerEnteringWorld complete".

There was a second, independent failure mode in the same file.
`OnHouseLevelFavorUpdated` re-issued the favor request on every payload it could
not normalise, with no cap and no backoff. A realm that keeps answering with an
unusable payload produces an unbounded request storm.

### Confirmation test already run

Forcing `IsClassicEra = true` on the testing machine stopped the disconnect.
Since the only server-bound calls that flag gates are the two housing ones,
this isolates housing. It also proves `C_Housing` **exists** on this client but
is non-functional, because the pre-existing `not C_Housing` existence guard had
not been enough on its own.

---

## 3. Fix implemented in this working tree

Not committed. Not yet verified in game.

1. **`XPBarEnhanced.lua:23-30`** — flavor detection now keys on a retail
   interface floor of 100000. Retail has been six digits since 10.0, every
   classic-style flavor is five (Classic Era 11508, camelot 16001, Mists 50500).
   Also exposes `Addon.InterfaceVersion`.

2. **`XPBarEnhanced.lua:39`** — new `Addon.IsHousingAvailable()`. It asks
   `C_Housing.IsHousingServiceEnabled()`, which is the predicate Blizzard itself
   uses in `Blizzard_HousingEventHandler` and the micro menu. **Fails closed**:
   anything other than an explicit true disables housing.

3. **Housing gates replaced** at `core/AddOnLifecycle.lua:61`,
   `core/EventRouter.lua:207`, `core/services/HousingSession.lua:157` and
   `core/services/HousingSession.lua:184`. Note that line 157 is
   `RequestCurrentTrackedHouseFavor` itself, which was reachable from four
   housing events with no flavor check at all, so gating only the lifecycle
   callers would have left a hole.

4. **`core/services/HousingSession.lua:16, 188, 294-303`** — the favor
   re-request is capped by `MAX_FAVOR_RETRIES`, reset on a good payload and on
   entering world.

5. **Reputation keyed on the module, not the flavor**, at
   `core/config/Config.lua:74`, `core/config/defaults.lua`,
   `ui/options/OptionMetadata.lua:10` and `ui/options/Options.lua:98`. Widening
   `IsClassicEra` would otherwise have forced the secondary source to profession
   and stripped the reputation option and colour swatch on camelot, where
   reputation genuinely works because the retail TOC ships
   `ReputationSession.lua`.

---

## 4. Next steps on the testing machine

1. **Remove the forced `IsClassicEra = true`** from the installed copy first,
   or you will be testing the hack rather than the fix.
2. Sync this working tree to
   `.../_classic_beta_/Interface/AddOns/XPBarEnhanced` and log in.
3. Confirm state in game:
   ```
   /run print(XPBarEnhanced.InterfaceVersion, XPBarEnhanced.IsClassicEra, XPBarEnhanced.IsHousingAvailable(), C_Housing and C_Housing.IsHousingServiceEnabled ~= nil)
   ```
   Expect interface 16001, `IsClassicEra` true, `IsHousingAvailable()` false.
4. Expected behaviour on camelot: no disconnect, housing absent, honor absent,
   reputation still selectable as a secondary source.
5. **Regression-check retail.** The flavor change and the housing gate both
   affect it. Housing should still work there, which requires
   `IsHousingServiceEnabled()` to return true on a retail character.

### Open items

- No Lua toolchain was available on the analysis machine, so the edits are
  verified by inspection and exact-match replacement, not compiled. A syntax
  error is unlikely but has not been mechanically excluded.
- If `IsHousingAvailable()` returns false on **retail**, the capability query is
  not answerable at `PLAYER_LOGIN` time and the gate needs to be re-evaluated
  after entering world instead. This is the one design risk in the fix.
- `XPBarEnhanced.toc` still declares only interface 120100, so the addon shows
  as out of date on the beta. Adding 16001 to that line would clear it. That is
  a support statement, so it was left alone deliberately.
- The unsuffixed TOC is what camelot loads. If you ever want camelot to get the
  reduced classic file list, that needs a TOC suffix the client actually
  recognises, not `-Classic`.

---

## 5. Retired hypotheses

Do not re-open these without new evidence.

- **Protected Blizzard status-bar race.** Disproven. The `_refs/XPBarEnhanced`
  addon installs a `hooksecurefunc` on `StatusTrackingBarManager` and calls
  `Hide()` on it, on this same client, with no disconnect. Hiding or hooking
  Blizzard status containers is not what dropped the connection, and the
  visibility rework in this branch was not the culprit.
- **`RequestTimePlayed` flooding.** Cleared. The comparison addon issues the
  same call on the same client without incident, and the request is guarded by
  `Addon.state.requestingTimePlayed` with no re-request from the response.
- **Saved-variable or profile corruption.** Already weakened in the previous
  handoff, and nothing in this investigation supports it.
- **A generic Lua exception.** There was never a traceback, and the failing call
  was wrapped in `pcall`, which protects against a Lua error but not against the
  server closing the connection.

---

## 6. Reference paths

- Blizzard source for this client:
  `/Volumes/Dev/WoW/_Workspace/Blizzard_UI_refs/Forever/BlizzardInterfaceCode`
- Comparison addon that does not disconnect:
  `/Volumes/Dev/WoW/_Workspace/_refs/XPBarEnhanced`
- Useful greps: `AllowLoadGameType camelot` across `Interface/AddOns`,
  `Blizzard_ProjectConstants/ProjectConstants.lua`,
  `Blizzard_SharedXML/GameRulesUtil.lua`,
  `Blizzard_APIDocumentationGenerated/HousingUIDocumentation.lua`.
