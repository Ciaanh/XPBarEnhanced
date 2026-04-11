# Investigation: Secondary Bar Visual Styles

Status: In Progress
Created: 2026-04-12
Owner: `docs/backlog/secondary-bar-styles.md`

## Purpose

Determine which additional visual styles are viable for the secondary bar, how they integrate with the existing primary XP bar style system, and what a realistic delivery plan looks like. The outcome of this investigation is either:

- **Approval**: an updated backlog item with concrete scope, file list, and effort estimate, or
- **Rejection**: a documented rationale for keeping flat-only indefinitely.

---

## Current State

The secondary bar has exactly one style: `flat` (`FlatReputationBarTemplate` / `FlatSecondaryBarStyle.lua`).

Primary XP bars have 6 active styles: `classic`, `flat`, `vertical`, `circular`, `minimap_ring`, `terminal`.

The secondary bar is shown when `showSecondaryBar = true` and a watched faction exists. It renders:
- Faction name + standing label (or companion name + level)
- Progress bar fill
- Session rep/companion gain text
- Hover tooltip with metrics

---

## Architecture Analysis

### How the flat secondary bar is built

`FlatSecondaryBarStyle` is composed via `StyleBuilder:Create(SecondaryBarBaseMixin, template, config)`. The lifecycle is entirely inherited from `SecondaryBarBaseMixin`:

```
OnLoad → OnShow → Subscribe → Refresh → MarkDirty → Render(context)
OnHide → Unsubscribe → StopTicker → FadeOut
```

A secondary style mixin must implement only three hooks:
- `GetBroadcastEventName()` — returns the EventBus event name to subscribe to
- `GetInitialContext()` — bootstraps context on first show (delegates to `ReputationSession:GetCurrentContext()`)
- `Render(context)` — draws the bar from the provided context

All lifecycle, fade, drag, tooltip, and text ticker behavior is in `SecondaryBarBaseMixin` and requires **no duplication** in new styles.

### Template requirements

A secondary bar XML template must define:
- A root `Frame` (or `StatusBar`) with `OnLoad` wiring the mixin
- A `StatusBar` child for the progress fill
- Optional: `NameText`, `StandingText`, `GainText` FontStrings for live text

The flat template (`FlatReputationBarTemplate`) is ~40 lines of XML. A new secondary style template would be of similar size.

### Style derivation

`SecondaryBarManager:DeriveSecondaryStyle(primaryStyle)` uses `TEMPLATE_MAP` to decide which secondary template to show alongside the active primary style:

```lua
local TEMPLATE_MAP = {
    flat = "FlatReputationBarTemplate",
}
```

Adding a new secondary style = adding an entry to this map. The manager handles the rest automatically.

### Conclusion: architecture is ready

The secondary bar infrastructure is purpose-built for extension. Adding a new style requires:
1. One XML template file
2. One Lua style file (implementing the three hooks above)
3. One entry in `TEMPLATE_MAP`
4. TOC registration

**There is no architectural blocker.** The risk is purely UX and visual design.

---

## UX Analysis

### What secondary bars must communicate

All secondary styles must render the same content regardless of visual treatment:
1. **Identity**: faction/companion name
2. **Progress**: fill ratio (0–1) within current standing bracket
3. **Standing context**: current standing label or companion level
4. **Live session data** (optional): rep/XP gained this session, rate

### Compact bar constraints

The secondary bar is typically narrower and shorter than the primary XP bar. Design constraints:
- Text must be legible at reduced height
- Quest overlays and milestone ticks (primary-only features) do not apply
- Rested XP overlay does not apply
- Animations: fill animation is appropriate; flash-on-gain is optional
- Tooltip handles the detailed metrics — bar text should be minimal

### Style candidates

#### A. Classic Secondary

Mirrors the primary `classic` style appearance: Blizzard atlas textures, no custom background, standard bar height.

- **Pros**: visually matched to players using the classic primary style; no custom texture assets needed (reuses atlas)
- **Cons**: Blizzard XP atlas textures are semantically XP-specific; using them for reputation may feel incongruous
- **Feasibility**: High — atlas fallback pattern already exists in `PaintMixin`
- **Verdict**: Viable. Needs UX confirmation that atlas reuse is acceptable.

#### B. Minimal Secondary

Thin line bar (4–6px height), no background frame, text only below. No visible border.

- **Pros**: unobtrusive; works well as an "always visible" overlay bar near any primary style
- **Cons**: very small hit surface for tooltip; low visibility in busy UI environments
- **Feasibility**: High — StatusBar at reduced height, most PaintMixin features skipped
- **Verdict**: Viable. Most universally compatible with all primary styles.

#### C. Style-Matching Secondary

Secondary bar automatically adopts the visual language of the active primary style. E.g., when primary is `terminal`, secondary renders in terminal ASCII style.

- **Pros**: coherent look; no style-selection UI needed
- **Cons**: requires one template + style per primary variant; `circular` and `minimap_ring` are impractical for secondary bars; increases maintenance surface significantly
- **Feasibility**: Partial — flat/classic/vertical are feasible; circular/minimap_ring/terminal are not
- **Verdict**: Viable only for flat/classic/vertical subset. Full parity is out of scope.

#### D. Vertical Secondary

A vertical secondary bar for players using the vertical primary style.

- **Pros**: natural pairing with vertical primary
- **Cons**: limited display area for text; positioning relative to vertical primary bar is non-obvious
- **Feasibility**: Medium — requires position logic adjustment and narrow text layout
- **Verdict**: Possible but low priority unless vertical primary has significant adoption.

---

## Style-to-Primary Compatibility Matrix

| Primary Style | Best Secondary Match | Notes |
|---|---|---|
| flat | flat (existing) | Already implemented |
| classic | classic | Atlas reuse; feasible |
| vertical | minimal or vertical | Vertical secondary is complex |
| circular | minimal | Circular secondary is out of scope |
| minimap_ring | minimal | Minimap secondary is out of scope |
| terminal | minimal or terminal | Terminal secondary is complex |

---

## Recommended Scope for First Delivery

If approved, the recommended first increment is:

**Two new styles: Classic and Minimal**

- Classic secondary pairs with the classic primary; reuses atlas textures
- Minimal secondary works alongside any primary style as a low-profile option
- Style selection exposed as a dropdown in the Secondary Bar options section
- Secondary style saved in `db.secondaryBarStyle` (new config key)
- `TEMPLATE_MAP` updated to support style-override (user selection overrides auto-derive)

**Out of scope for first delivery:**
- Vertical secondary bar
- Terminal secondary bar
- Style-auto-matching (manual selection is simpler and more predictable)
- Circular / minimap ring secondary bars

### Estimated effort

| Deliverable | Effort |
|---|---|
| `ClassicReputationBarTemplate.xml` | 1h |
| `ClassicSecondaryBarStyle.lua` | 1h |
| `MinimalReputationBarTemplate.xml` | 1h |
| `MinimalSecondaryBarStyle.lua` | 1h |
| `SecondaryBarManager` TEMPLATE_MAP + style key | 0.5h |
| `OptionMetadata` + Options UI dropdown | 1h |
| `defaults.lua` + `Config` side-effect | 0.5h |
| TOC + locale strings | 0.5h |
| Testing + validation | 1.5h |
| **Total** | **~8h (1 session)** |

---

## Open Questions

1. Should secondary style selection be per-primary-style (e.g., "when primary=classic, secondary=classic") or a single global setting? Global is simpler; per-primary could be combined with the per-style-position backlog item.
2. What atlas textures are appropriate for a "classic" secondary reputation bar? The XP atlas (`UI-HUD-ExperienceBar-Fill-XP`) is XP-specific; a reputation equivalent should be identified (check `AtlasInfo.lua` for StatusBar-type atlases).
3. Is the minimal style height configurable or fixed? A fixed 4px default with no user control is simplest.

---

## Decision Gate

This investigation is complete when:

- [ ] Open questions above are resolved
- [ ] Atlas options for classic style are identified (see `BlizzardInterfaceResources/AtlasInfo.lua`)
- [ ] UX decision on global vs. per-primary style selection is made
- [ ] Recommended scope above is accepted or revised
- [ ] Entry added to `docs/memory/decision-log.md` with approval or rejection rationale
- [ ] `docs/backlog/secondary-bar-styles.md` updated with final scope if approved
