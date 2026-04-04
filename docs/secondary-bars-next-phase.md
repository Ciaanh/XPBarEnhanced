# Secondary Bars — Next Phase Notes

## Pending Testing

- **Companion XP bar** has not been tested in-game yet.
  - Requires an active Delve session with Brann to trigger `CompanionSession` data.
  - Set `companionBarStyle = "flat"` in options and enter a Delve to verify rendering.

---

## Known Issues

### Reputation bar does not react to watched faction changes at runtime

When the player opens the Reputation panel and changes which faction is tracked
(or clears tracking entirely), the bar does not show or hide automatically.

- **Root cause**: `UPDATE_FACTION` fires and `ReputationSession` emits
  `REPUTATION:BROADCAST_UPDATE`, which calls `BuildReputationContext()`. If the
  new context has `isAvailable = false` (no faction watched) the bar fades to
  alpha 0 — but when a faction is later watched it only becomes visible again if
  another `REPUTATION:BROADCAST_UPDATE` fires with `isAvailable = true`.
  In practice the event does fire when tracking is toggled, but this flow should
  be verified end-to-end and explicitly covered.
- **Potential gap**: if `_SnapshotWatchedFaction()` clears `watchedFactionID`
  without emitting an update broadcast, the bar stays visible at alpha 1 with
  stale data.
- **Action**: trace the event chain when the player hits "Track" / "Untrack" in
  the Blizzard Reputation UI and ensure a broadcast is always emitted so the
  bar responds immediately.

---

## Enhancement Ideas

### Fade in / fade out effect (matching Blizzard bar behaviour)

The default Blizzard XP/reputation status bar fades in when it gains a value and
fades out after a short delay when inactive. We could reproduce this on both
secondary bars.

**Suggested approach**

1. Add a `C_Timer.After` idle timer that starts (or resets) every time `Render`
   is called with new data.
2. When the timer fires, tween `SetAlpha` from 1 → 0 over ~0.5 s using an
   `OnUpdate` loop or the Animation system (`AnimationGroup` with `Alpha` child).
3. On the next `Render` call, cancel any running fade-out and tween alpha back
   to 1 (fade-in).
4. The fade should **not** trigger when `isAvailable` changes from false → true
   on login; only on reputation/XP gain events.

**Reference**: `Blizzard_StatusTrackingBar` in BlizzardInterfaceCode uses
`StatusTrackingBarMixin` with `AnimationGroup` fade logic — worth checking for
the exact timing and easing values Blizzard uses.

---

## Future Work (lower priority)

- **Drag-to-move**: Both bars currently default to `CENTER`. Add a draggable
  anchor (similar to the main XP bar) with position saved to `SavedVariables`.
- **Per-bar size / scale option** in the options panel.
- **Tooltip on hover**: show session gained, rep/hour, time-to-next-standing
  (data already computed by `ReputationSession`).
