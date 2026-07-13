# XP Bar Enhanced — Feature & Style Proposals

Working document for implementation and impact study. Proposals are grounded in the
existing architecture (capability system, EventBus, secondary-bar sources,
`gainsHistory`, per-character sessions) so effort estimates reflect real reuse.

Status values: `proposed` → `studying` → `planned` → `in progress` → `done` / `rejected`.

---

## New bar styles

### 1. "Bubbles" retro option for the classic style
| | |
|---|---|
| **Status** | proposed |
| **Impact** | High — strong nostalgia appeal (vanilla WoW 20-bubble XP bar), community-recognizable |
| **Effort** | Low-Medium |
| **Reuse** | Implemented as an option of the **classic** style, not a new style (decision 2026-07-08): a `classicBubbles` toggle that overlays 20 bubble separators on the classic bar |
| **Notes** | Quest overlay = tinted bubbles. Follows the classic style's existing conditional-row pattern in the options panel |

### 2. Orb style
| | |
|---|---|
| **Status** | planned |
| **Impact** | Medium — distinctive look (Diablo-style filling sphere) |
| **Effort** | Medium |
| **Reuse** | Circular masking/texcoord work already solved in `CircularBarStyle`; an orb is a vertical fill inside a round mask — simpler than the arc math |
| **Notes** | One of the two retained new-style candidates (decision 2026-07-08). Secondary bar variant: smaller companion orb |

### 3. Data-text / LibDataBroker feed
| | |
|---|---|
| **Status** | planned |
| **Impact** | High — reaches Titan Panel / Bazooka / ElvUI datatext users; big audience gain for little code |
| **Effort** | Low |
| **Reuse** | Style "none" is the precedent for barless operation; `ContextBuilder` already provides every formatted value (XP/h, time-to-level, session XP) |
| **Notes** | One of the two retained new-style candidates (decision 2026-07-08). Example feed: `12.4k XP/h · ding ~34 min`. Ship LibDataBroker-1.1 (embed like LibStub) |

### 4. Edge-of-screen strip
| | |
|---|---|
| **Status** | rejected |
| **Impact** | Low-Medium — appeals to minimalist/immersive UI users |
| **Effort** | Very low |
| **Reuse** | Not retained as a style candidate (decision 2026-07-08). Could resurface as a flat-style size preset if requested |

### 5. Fill-edge spark (capability, not a style)
| | |
|---|---|
| **Status** | proposed |
| **Impact** | Medium — polish parity with the Blizzard bar |
| **Effort** | Low-Medium |
| **Reuse** | `AnimationManager` already owns the OnUpdate driver and flash lifecycle; spark follows the same register/unregister cycle |
| **Notes** | Declare as a new style capability (`spark`) so styles opt in |

---

## Features (ranked by value/effort)

### 1. Fade when inactive + level-up celebration
| | |
|---|---|
| **Status** | in progress — implemented (fadeWhenInactive/fadeDelay/idleOpacity + levelUpCelebration/celebrationSound), pending in-game validation |
| **Impact** | High — highly visible user-facing options |
| **Effort** | Medium |
| **Reuse** | These options existed as defaults (`fadeWhenInactive`, `idleOpacity`, `fadeDelay`, `levelUpCelebration`, `celebrationSound`, `celebrationSparkles`, `celebrationSpeed`) before being removed as orphans in v1.1.7 — they were the implied roadmap. The animation infrastructure and the two-phase level-up hold provide ~80% of the base |
| **Notes** | Requires the full 4-layer config wiring (defaults → Config accessor → options control → runtime consumer). Fade must respect combat visibility rules |

### 2. Custom fonts via LibSharedMedia
| | |
|---|---|
| **Status** | proposed |
| **Impact** | Medium-High — standard expectation for UI addons |
| **Effort** | Low |
| **Reuse** | `textFontFace/Size/Outline/Shadow` were orphaned defaults too; `TextMixin` centralizes all text rendering — one option group + `SetFont` in a single mixin |
| **Notes** | Embed LibSharedMedia-3.0; fall back gracefully when absent |

### 3. Session charts in the Stats window
| | |
|---|---|
| **Status** | in progress — implemented (XP/hour histogram + quest-vs-other split bar in a new ChartPanel), pending in-game validation |
| **Impact** | High — turns dormant data into a headline feature |
| **Effort** | Medium |
| **Reuse** | `gainsHistory` already persists 500 timestamped gains with source attribution (quest/other). XP/h histogram per 15-min slice + quest-vs-other breakdown is pure rendering |
| **Notes** | Render with simple textures (no chart lib needed). Watch frame counts — pool bars like the changelog font strings |

### 4. Warband / alt overview
| | |
|---|---|
| **Status** | proposed |
| **Impact** | Medium-High — unique differentiator; leverages v1.1.7 per-character storage |
| **Effort** | Low-Medium |
| **Reuse** | Sessions became per-character in v1.1.7 (`db.sessionData[playerKey]`); a Stats tab listing each character's level, played time, and XP/h reads existing data |
| **Notes** | Data for other characters is read-only snapshots from their last session |

### 5. New secondary-bar sources
| | |
|---|---|
| **Status** | in progress — **Honor** (`HonorSession`) and **Profession** (`ProfessionSession`) implemented, pending in-game validation |
| **Impact** | Medium-High — extends the addon's core value |
| **Effort** | Medium per source |
| **Reuse** | `secondaryBarSource` architecture (reputation/housing) is designed for extension; `HousingSession` is the template: one service emitting a normalized context |
| **Candidates** | ~~Honor/PvP~~ ✅, ~~profession knowledge~~ ✅ (skill rank), Delve journey level (not started) |
| **Notes** | Honor uses wrap-aware gain (`ComputeWrappedGain`, like renown) via `UnitHonor/UnitHonorMax/UnitHonorLevel`; routed on `HONOR_XP_UPDATE`/`HONOR_LEVEL_UPDATE`. Profession tracks the first primary profession with room to grow (falls back to the first primary), via `GetProfessions`/`GetProfessionInfo`; routed on `SKILL_LINES_CHANGED`/`CHAT_MSG_SKILL`. Both sanitize with `issecretvalue`/`SafeNumber`. **Deferred:** per-profession sub-selection (which of the two primaries to track) — currently automatic. |

### 6. Goals & ETA notifications
| | |
|---|---|
| **Status** | planned |
| **Impact** | Medium — engagement feature ("ding at ~21:40", toast at 25/50/75%, "level 80 by Sunday") |
| **Effort** | Medium |
| **Reuse** | `TimeCalculations` already computes projections; missing piece is a toast/sound notifier (throttled, no OnUpdate polling) |
| **Notes** | Store goals per character; notify via EventBus subscriber, not direct calls |

### 7. Localization
| | |
|---|---|
| **Status** | proposed |
| **Impact** | Medium-High — CurseForge audience expansion; only `enUS.lua` exists while AceLocale is already embedded |
| **Effort** | Low (content, not code) |
| **Reuse** | v1.1.7 groundwork already handles UTF-8 profile names and localized chat patterns |
| **Candidates** | frFR, deDE, ruRU, esES/esMX first |

### 8. Profile import/export
| | |
|---|---|
| **Status** | proposed |
| **Impact** | Medium — sharing configs is a common ask |
| **Effort** | Medium |
| **Reuse** | `ProfileManager` owns the structure; serialize to a shareable string |
| **Notes** | Clipboard string exchange only (or out-of-instance): `SendAddonMessage` is blocked inside instances in 12.x |

---

## Agreed order (decision 2026-07-08)

1. **Fade when inactive + level-up celebration** — in progress (implemented, pending in-game validation).
2. **Session charts** in the Stats window — in progress (implemented, pending in-game validation).
3. **New secondary-bar sources** — in progress (Honor + Profession implemented, pending in-game validation).
4. **Goals & ETA notifications**.

New styles limited to **orb** and **data-text/LDB**; "bubbles" is reframed as an option of the classic style; edge strip rejected. Custom fonts, warband overview, localization, and profile import/export remain proposed (not scheduled).

## Design note — repurpose the primary bar for the secondary source at max level

**Status:** studied (2026-07-13), not scheduled. Requested alongside item 5.

**Idea:** at max level the primary XP bar is hidden (it has no XP to show). Instead, render the selected secondary source (reputation/housing/honor/profession) on the *primary* bar frame, so the big bar stays useful. This mirrors Blizzard's own status-tracking bar, which promotes reputation/honor into the main container at max level.

**Feasibility:** moderate effort, architecturally clean. The XP context and the secondary-source context are already separate data planes, and primary styles already paint a status bar from an immutable context. The catch is the primary render path is XP-shaped (`context.currentXP`/`xpMax`/`level`), so an adapter is needed.

**Lowest-risk shape** (confines new logic to `BarManager.lua` + `BaseMixin.lua`, leaves the 7 style `RenderBar` methods and the 4 session services untouched):
- Add `BarManager:GetMaxLevelSecondaryContext()` that, when `showSecondaryBar` is on and a source is active, resolves the active source (`SharedStyleHelpers.GetSecondaryInitialContext()`) and translates its `current/min/max/ratio` + `factionType` color into an XP-shaped context carrying a "secondary mode" flag.
- In `BaseMixin:TriggerBarRefresh`, replace the "hide at max level" branch with: if the adapter returns a context, render it (gating off XP-only capabilities — rested/quest overlays, exhaustion tick, XP/level text); else hide as today.
- Stop `BarManager:SetStyle` from collapsing to `"none"` at max level when this mode is enabled (the `IsPlayerAtMaxLevel` short-circuit appears in `SetStyle`, `OnLevelUp`, `AdjustContextForMaxLevel`).
- `SecondaryBarManager` must not also draw the standalone secondary bar for the same source (avoid double render).
- Primary `BaseMixin:OnShow` must additionally subscribe to the source broadcast(s) to live-update at max level.

**Concerns:** secret values are already laundered by the services (safe to pass the normalized fields to `SetValue`); the adapter must gate XP-only capabilities; no protected/secure frames involved, so no combat-taint risk from the render itself.

**Recommendation:** gate behind a new option (e.g. `maxLevelPrimaryShowsSecondary`, default off) and do it as its own change after item 5 validates. It touches the primary render path (higher blast radius) so it should not ride along with the source additions.

## Architecture constraints (apply to every item)

- WoW event registration only in `core/EventRouter.lua`; UI refresh through EventBus.
- 12.x secret values: never compare/branch/do arithmetic on raw API returns in UI code; sanitize in services/ContextBuilder.
- Every new option needs all four layers: `defaults.lua`, Config accessor, options control, runtime consumer.
- No `OnUpdate` polling without throttling; reuse the `AnimationManager` driver where possible.
- Styles must degrade gracefully when optional helpers are missing (capability system).
