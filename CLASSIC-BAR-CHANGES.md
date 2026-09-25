# Classic bar: customizable width and segments

> **Superseded art.** The border slicing of `legacy-border.tga` described below
> was replaced by bundled Forever-style art (`classic-bar.tga`,
> `classic-bar-fill.tga`; see `ClassicChrome.lua` and
> `assets/raw/build_classic_bar.py`). The width and segment options still work
> as described.

2026-09-19 — 11 files modified, 1 added (284 insertions, 26 deletions, plus a
246-line new file).

Derived from an analysis of Blizzard's experience bar in the Forever/camelot
client (`Blizzard_StatusTrackingBar`), which is full-width, segmented, and lays
its dividers out at runtime rather than baking them into art.

---

## What Blizzard changed in camelot

All camelot-specific tuning lives in one constants file; the rest of the addon
is shared with Mainline.

| | Mainline | Camelot |
| --- | --- | --- |
| Container width | 571 | **1192** |
| Height | 17 | 17 |
| Frame inset (`SIZE_ADJUSTMENT`) | 6 | **3** |
| Segments | 1 | **20** |
| Gamepad | — | **half width, 10 segments** |
| Rested overflow | hidden | **fills to the bar edge** |

Two mechanisms make an arbitrary width possible there, and both are what this
change adopts:

1. **Dividers are a frame pool, not a texture.** `UpdateDividers(numSegments)`
   places `numSegments - 1` dividers at `containerWidth / numSegments`, and
   `CheckForLayoutChange()` re-runs it on every layout change.
2. **Width is decoupled from art.** The frame art is fixed-size and never
   scaled; the bar is inset from it and the fill simply stretches.

---

## New file

**`ui/styles/classic/ClassicChrome.lua`** — geometry shared by the Classic
primary and secondary bars, so the two stay dimensionally identical while
anchored to one another. Four public functions:

- `GetWidth()` / `GetSegmentCount()` — clamped config reads
- `ResolveAtlas(candidates)` — first atlas name this client actually has.
  `SetAtlas` on an unknown name blanks the texture silently rather than
  erroring, so every candidate must be probed with `GetAtlasInfo` first.
- `BuildSlicedChrome(frame, borderKey)` — retargets the border and background
  textures into left cap / stretched middle / right cap
- `LayoutDividers(frame)` — places `segments - 1` dividers at `width / segments`

### Why the border had to be sliced

`legacy-border.tga` is not a uniform strip. Decoding it gives:

```
deviating runs (start, end, width):
      0 ..     9   w=10     <- left cap
     97 ..   104   w=8   \
    200 ..   207   w=8    |
    303 ..   310   w=8    |  nine ticks, 103px apart
     ...                  |
    921 ..   928   w=8   /
   1014 ..  1023   w=10    <- right cap
```

The Classic border has always been a **ten-segment bar with its dividers
painted in**. Slicing it apart lets the caps hold a fixed pixel size at any
width, and lets the dividers be redrawn at a configurable count instead of the
baked nine. The middle is stretched from a deliberately tick-free span
(source x 110–195).

---

## Modified files

| File | Change |
| --- | --- |
| `ui/styles/classic/ClassicBarStyle.lua` | Added `ResizeToConfiguredWidth()` and a `BuildVisuals` override; fill atlas became a probed candidate list |
| `ui/styles/classic/ClassicSecondaryBarStyle.lua` | Same resize + slicing, wired into `OnSecondaryLoad` |
| `ui/styles/classic/ClassicBarTemplate.xml` | One line: loads `ClassicChrome.lua` ahead of the style file |
| `ui/mixins/LayoutMixin.lua` | Dropped the `isFullyRested` early-out; pip visibility now derives from the overlay bounds within a 1%–99% band |
| `core/config/Config.lua` | `ApplyOptionSideEffects` resizes both bars on `classicWidth` / `classicSegments` |
| `core/config/defaults.lua` | `classicWidth = 566`, `classicSegments = 10` |
| `ui/options/OptionMetadata.lua` | Two slider definitions plus order entries |
| `ui/options/OptionsPanel.xml` | Two `ConfigSliderTemplate` rows under a new "Classic Bar" heading |
| `ui/options/Options.lua` | Both keys marked Classic-only in `ROW_OWNER_STYLE` |
| `locales/enUS.lua` | Four strings |
| `CHANGELOG.md` | Unreleased entry |

---

## Behavior

### Defaults reproduce the previous bar exactly

At 566px the caps land where the old uniform stretch put them:

```
old src x=10   -> 5.527px     new left cap edge   5.527px
old src x=1014 -> 560.473px   new right cap edge  560.473px
```

Ten segments match the baked art to within 1.9px at the far end (the art's
spacing is 103px against a true 102.4px, so the generated positions are in fact
the more evenly spaced of the two).

### New options

- **`classicWidth`** — 200–1400px, default 566. Caps hold a fixed size; only the
  middle stretches.
- **`classicSegments`** — 0–40, default 10. `0` or `1` gives one unbroken bar,
  `10` matches the previous art, `20` matches Blizzard's camelot bar.

Overlay, quest and rested geometry needed no changes: `ValidateBarWidth` already
reads the live `StatusBar:GetWidth()` and everything downstream is ratio-based.

### Two changes that ship regardless of settings

1. **Atlas fix.** The fill was requested as `UI-HUD-ExperienceBar-Fill-XP`, a
   name that appears nowhere in the current Blizzard UI source. Because
   `ApplyAtlasOrTexture` gates on `GetAtlasInfo`, it failed silently and fell
   back to the bundled TGA. Now probes `-Fill-Experience` first.
2. **Rested overflow.** Overflowing rested XP fills the bar to its edge instead
   of blanking the overlay, and the pip hides within 1% of either end — matching
   Blizzard's `ShouldRestedXpBarDisplayWhenOverflowing` and `hideAtBarEdge`.
   **This lives in the shared mixin, so it affects all eight styles, not just
   Classic.**

---

## Verification status

- Every edited Lua file parses under `luaparser`; all three XML files are
  well-formed; slice and divider geometry checked numerically.
- **Nothing has been run in WoW.** No client on the build machine.

Worth testing first:

- A wide bar (1200px / 20 segments) for cap and divider placement.
- A fully-rested character for the overflow fill and the hidden pip.
- The Classic secondary (reputation) bar, to confirm it tracks the primary's
  width rather than stacking at a different length.

## Known gaps, not addressed here

- **Profile switches do not re-apply bar geometry.** `PROFILE_CHANGED` only
  refreshes the options panel and never calls `ApplyOptionSideEffects`. This is
  pre-existing and affects `flatSize`, `circularSize` and `barStyle` equally,
  but it means a profile carrying a different `classicWidth` will not resize
  until something else re-drives it.
- **`commandKeys` is dead metadata.** Every option in `OptionMetadata.lua`
  declares it and nothing in the codebase consumes it — there is no generic
  option slash command. The two new options declare it for consistency only.
- **AppleDouble files.** Creating the new source file produced another `._*`
  fork alongside those already untracked in this repo. Confirm
  `make-release.ps1` excludes `._*` before the next package.
