# Decision Log

## 2026-04-13 — Circular and minimap secondary prototypes implemented with options coverage

Decision: Activate secondary style mapping for `circular` and `minimap_ring` in `SecondaryBarManager.TEMPLATE_MAP`.
Reason: Prototype implementation approved for C3/C1 hybrid circular secondary and minimap icon-centered arc secondary.
Impact:

- `SecondaryBarManager.lua`: `circular` now maps to `CircularReputationBarTemplate`; `minimap_ring` maps to `MinimapArcReputationBarTemplate`.
- `SecondaryBarManager:ReapplyAttachedPositions()` now respects optional `frame:ShouldAttachToPrimary()` so styles can explicitly opt out of attachment behavior.

Decision: Implement circular secondary as an inner segment arc with optional full-circle mode.
Reason: Preserve visual coherence with the circular primary while reducing center clutter by default.
Impact:

- Added `CircularSecondaryBarTemplate.xml` + `CircularSecondaryBarStyle.lua`.
- Default rendering is semi-circular; `circularSecondaryFullCircle` toggles 360-degree mode.
- Style remains attachable to the primary bar center in attached mode.

Decision: Implement minimap secondary as a draggable icon that toggles a centered arc.
Reason: Matches desired interaction model where icon position controls arc position and avoids permanent minimap ring clutter.
Impact:

- Added `MinimapArcSecondaryBarTemplate.xml` + `MinimapArcSecondaryBarStyle.lua`.
- Left-click toggles arc visibility; shift-drag repositions icon/arc together.
- Style opts out of primary attached mode (`ShouldAttachToPrimary() == false`).

Decision: Add option panel coverage for all new prototype settings.
Reason: Ensure prototype behavior is user-adjustable without editing SavedVariables manually.
Impact:

- `defaults.lua`: added `circularSecondaryFullCircle`, `minimapArcStartExpanded`, `minimapArcIconScale`.
- `OptionMetadata.lua`, `OptionsPanel.xml`, `Options.lua`, `locales/enUS.lua`: added and surfaced new controls in the options panel with style-conditional visibility.
- `XPBarEnhanced.toc`: added new circular/minimap secondary template files.

## 2026-04-13 — Secondary bar style selection model simplified; Classic label restored

Decision: Remove `AUTO_PAIR`, `secondaryBarStyle` config key, and the options dropdown. Replace with a direct `TEMPLATE_MAP[db.barStyle]` lookup.
Reason: User clarified that style pairing should be 1:1 (primary style key = secondary template). No per-user override needed. New styles are added progressively by inserting entries into `TEMPLATE_MAP` only.
Impact:
- `SecondaryBarManager.lua`: `TEMPLATE_MAP` now only has `flat` and `classic` entries. `DeriveSecondaryStyle()` is a direct map lookup, returning `"none"` for unmapped primaries.
- `defaults.lua`: `secondaryBarStyle = "auto"` removed.
- `OptionMetadata.lua`: `secondaryBarStyle` dropdown and its `optionOrder` entry removed.
- `locales/enUS.lua`: 6 `OPT_SECONDARY_BAR_STYLE*` strings removed.
- `MinimalSecondaryBarStyle.lua` + `MinimalSecondaryBarTemplate.xml` remain on disk but are dormant — no `TEMPLATE_MAP` entry activates them.

Decision: Restore the text label on the Classic secondary bar.
Reason: The original reason for removal was text overlap with the primary bar's `QuestSummaryText`. The root cause (`y="30"` anchor in `ClassicBarTemplate.xml`) was fixed separately. With that fix in place the label is safe to restore.
Impact:
- `ClassicBarTemplate.xml`: `QuestSummaryText` anchor changed from `y="30"` to `y="-24"` (below rate/session text line, never bleeds into secondary bar space).
- `ClassicSecondaryBarStyle.lua`: `BuildLabel`, `GetTextTickerInterval`, `GetTextTickerContext`, `OnTextTick` restored; `Render` now also updates the label.
- `ClassicSecondaryBarTemplate.xml`: `LabelContainer` with centered `GameFontNormalSmall` FontString re-added.
- All secondary bar templates at `frameStrata="MEDIUM"` (was LOW; raised to match primary text frames).

## 2026-04-12 — Classic and Minimal secondary bar styles implemented

Decision: Add Classic and Minimal secondary bar styles alongside the existing Flat style.
Reason: Approved by user 2026-04-12. Classic provides a visual match for the Classic primary bar (Blizzard atlas fill, bordered). Minimal provides a compact 6 px option suitable for non-bar primaries.
Implementation:

- `ClassicReputationBarTemplate` (566×12): Blizzard-style bordered bar, standing-color atlas fill via `UI-HUD-ExperienceBar-Fill-Reputation-Faction-{Red/Orange/Yellow/Green/Blue}`. Atlas applied at runtime in `Render`; falls back to `WHITE8X8` + solid color when atlas unavailable. `C_Texture.GetAtlasInfo` + `SetAtlas` pattern mirrors `PaintMixin:ApplyBarAtlasOrTexture`.
- `MinimalReputationBarTemplate` (565×6): Slim solid-color bar, no label frame. All information via same tooltip as Flat. Suitable for Vertical, Circular, Minimap Ring, Terminal primaries.
- `TEMPLATE_MAP` and `AUTO_PAIR` added to `SecondaryBarManager.lua`. `DeriveSecondaryStyle` checks `db.secondaryBarStyle` override first, then pairs from `AUTO_PAIR` using `db.barStyle`.
- `db.secondaryBarStyle = "auto"` added to defaults.
- `secondaryBarStyle` dropdown added to `OptionMetadata.lua` and `optionOrder`.
- Six locale strings added to `enUS.lua` (`OPT_SECONDARY_BAR_STYLE`, `OPT_SECONDARY_BAR_STYLE_DESC`, `OPT_SECONDARY_STYLE_AUTO/FLAT/CLASSIC/MINIMAL`).

## 2026-04-12 — v1.1.0 session: README sync, Session.lua cleanup, per-style secondary position

Decision: Implement per-style secondary bar position (`secondaryBarPositions` keyed by primary bar style).
Reason: Approved 2026-04-12; mirrors how `barPositions` works for primary bars; prevents position bleed between styles.
Implementation:

- `db.secondaryBarPositions` (table) replaces `db.secondaryBarPosition` (single table) as the SavedVariables key.
- `SecondaryBarBaseMixin` gains `GetPositionStyleKey()` returning `db.barStyle`; `SavePosition`, `ApplyInitialPosition`, `ResetPosition` all use the two-level `db[configKey][styleKey]` read/write pattern.
- `FlatSecondaryBarStyle.GetPositionConfigKey()` now returns `"secondaryBarPositions"`.
- `SecondaryBarManager:ResetBarPositions()` clears only the current style's entry.
- `Options.lua` `OnResetBarPositionClicked` clears the entire `secondaryBarPositions` table (full reset intent).
- One-time migration in `Database:Initialize()`: if old `secondaryBarPosition` key exists, copy to `secondaryBarPositions[barStyle]` and remove the old key.

Decision: Remove `Session:SetupEventFrame()` (dead method, no callers).
Reason: The router architecture owns all event registration; this method was a no-op returning false, tagged `@deprecated`.
Decision: `session.sessionXP` field retained (actively written as a SavedVariables mirror of `gainedXP`); annotation kept accurate.

Decision: Update README version from 1.0.7 to 1.1.0.
Reason: README was the last file still referencing the old version.

## 2026-04-09 — Contract enforcement and visibility ownership hardening

Decision: Enforce session-owned XP broadcast emissions and remove direct XP context emissions from UI/services.
Reason: Keep context ownership consistent with architecture rules and avoid redundant emit paths.
Impact:

- `Options.lua` now refreshes XP bars through `Session:EmitUpdate(...)`.
- `QuestXP.lua` rebuild path now triggers `Session:EmitUpdate("QUEST_LOG_UPDATE")`.

Decision: Consolidate error handling and main-container suppression coordination.
Reason: Remove undefined handlers and avoid visibility policy drift between managers.
Impact:

- `BarManager:Shutdown()` now uses `Utils.ReportError` instead of undefined `SafeCallErrorHandler`.
- `Session.lua` now uses `Utils.ReportError` for internal `xpcall` guards.
- `SecondaryBarManager:ShouldSuppressMainContainer()` is now exposed; `BarManager` respects this before showing Blizzard main container.

Decision: Align type/doc contracts with implemented behavior.
Reason: Static-analysis signals and stale docs were diverging from runtime architecture.
Impact:

- `EventBus.lua` docs now state mandatory `context` for `Emit` and use module-scoped type aliases.
- `Colors.lua` LuaCAT annotations renamed to module-scoped symbols to reduce duplicate type diagnostics.
- `docs/features/reputation-bar.md` now reflects `ReputationSession:GetCurrentContext()` bootstrap flow.

## 2026-04-08 — Architecture hardening pass (router boundaries, context ownership, emission normalization)

Decision: Keep `core/EventRouter.lua` as an external-event dispatcher only.
Reason: Router should own WoW event registration/dispatch, not domain event emission or UI manager orchestration.
Impact:

- Router no longer emits XP EventBus updates directly in `PLAYER_ENTERING_WORLD`/max-level paths.
- Router no longer performs XP enable/disable style orchestration directly.
- Lifecycle handlers now own entering-world UI visibility reconciliation and XP-gain enable/disable/max-level style transitions.

Decision: Move reputation render-context construction fully into `ReputationSession`.
Reason: Previous flow introduced a circular dependency (`ReputationSession -> ContextBuilder -> ReputationSession`).
Impact:

- `ReputationSession:_BuildContext()` now builds reputation context internally.
- `XPBarContextBuilder.BuildReputationContext()` removed from `core/services/ContextBuilder.lua`.
- Secondary bar initial context path stays session-owned (`GetCurrentContext()`).

Decision: Reduce duplicate XP broadcasts in quest-turn-in and config side-effect paths.
Reason: Several flows emitted both generic config updates and domain XP updates, producing redundant refresh pressure.
Impact:

- `Session:OnQuestTurnedIn()` now calls `OnXPUpdate(true)` (no immediate emit) and emits one coalesced `EmitUpdate("QUEST_LOG_UPDATE")`.
- `Config:ApplyOptionSideEffects()` no longer emits extra XP broadcasts for visual toggles; XP bars refresh via `CONFIG_UPDATED` subscription.

Decision: Add lightweight text ticker context for primary XP bars.
Reason: Text ticker previously rebuilt full XP context every 2.5s (`BuildContext("MANUAL_REFRESH")`) although only text/time/rate fields are needed.
Impact:

- Added `XPBarContextBuilder.BuildTextRefreshContext()`.
- `BaseMixin` ticker now uses this lightweight path (`TEXT_TICK`) with backward-compatible fallback.

Decision: Close `options-panel-sections` backlog item as already implemented.
Reason: Audit confirmed grouped headers and style-conditional visibility are already shipping in `Options.lua`.
Impact:

- Removed from active backlog index.
- Marked as closed (historical trace only) in backlog file.

## 2026-04-08 — xp-tracking-quick-wins implemented

- `core/services/QuestXP.lua`: added `not info.isTask` guard — world quests and bonus objectives now excluded from XP overlay
- `core/EventRouter.lua`: added `UPDATE_EXPANSION_LEVEL` and `MAX_EXPANSION_LEVEL_UPDATED` to `ROUTER_DISPATCH` → both route to `DispatchPlayerMaxLevelUpdate()`
- `core/calculations/TimeCalculations.lua`: lowered both `elapsed < 30` thresholds to `elapsed < 10` — XP/hr rate now appears within 10 s of first XP gain

Next: `options-panel-sections` backlog item (P2)

## 2026-04-08 — MQ-1: Context/session workflow consistency — complete (no code changes)

Audited all architecture-analysis §3.1–3.6 pipeline inconsistencies against live code.

All issues were already resolved by prior implementation:

- §3.1 Context location: both XP (`Session.lua` → `XPBarContextBuilder.BuildContext()`) and Reputation (`ReputationSession._BuildContext()`) use emitter-builds. `MarkDirty(ctx)` flows the emitted context directly to `Render(ctx)`
- §3.2 XP emits nil: FALSE — `Session.lua` line 200-202 emits `XPBarContextBuilder.BuildContext()` (a full context)
- §3.4 Context rebuilt on every render: FALSE — `MarkDirty` coalescing stores `_pendingContext`; context built once at emit time and cached in `_lastContext`
- §3.6 No shared bar contract: FALSE — both `BaseMixin` and `SecondaryBarBaseMixin` implement identical `MarkDirty` → RunNextFrame → `Render(context)` lifecycle
- CompanionSession/CompanionCalculations: already deleted; auto-resolved

Remaining intentional asymmetry: XP uses global `XPBarContextBuilder.BuildContext()` (multi-source combiner); Reputation uses internal `ReputationSession._BuildContext()` (session-owned). Both are correct; documented in guidelines.

Updated:

- `docs/analysis/architecture-analysis.md` — §3.1/3.2/3.4/3.6 marked RESOLVED
- `docs/guidelines/code-architecture-choices.md` — CompanionSession removed; EventBus contract and asymmetry documented

**MEDIUM-TERM EXIT GATE REACHED: all MQ-1 through MQ-4 complete.**

## 2026-04-08 — MQ-2: Options panel architecture proposal complete

- Audited all 36 options in `OptionMetadata.lua`; grouped into 9 logical sections (Core, Secondary Bar, Minimap, XP Overlays, XP Text, Animations, Style: Circular, Style: Minimap Ring, Style: Terminal)
- Chosen direction: **grouped scroll** (single page, section headers) — NOT tabbed panels
  - Panel is `Settings.RegisterCanvasLayoutCategory` (full custom XML canvas); tabs would require custom tab widget
  - 36 options / 9 sections is well-suited to a single scrollable page
  - Style-specific sections (Circular, Minimap Ring, Terminal) will be hidden when the matching style is not selected
- Decision documented in `docs/features/options-and-config.md`
- Backlog item filed: `docs/backlog/options-panel-sections.md` (P2)

Next: MQ-1 (context/session workflow consistency)

## 2026-04-08 — MQ-3: UI structure and naming cleanup complete

- `ui/secondary/` folder deleted (was empty; secondary style files correctly live in `ui/styles/flat/`)
- Confirmed: secondary styles colocate with their primary style partner under `ui/styles/<style>/` — no separate `ui/secondary/<style>/` structure needed
- `SecondaryBarBaseMixin` placement in `ui/mixins/` confirmed intentional (shared infrastructure, not style-specific)
- All `ui/` files catalogued in `docs/guidelines/project-structure.md` with role descriptions
- No file moves or TOC changes were required

Next: MQ-2 (options panel architecture proposal)

## 2026-04-08 — MQ-4: Analysis-to-backlog normalization complete

Completed audit of all 6 analysis docs (`docs/analysis/`). All annotated with MQ-4 status headers.

Key findings:

- `EventRouter.lua` already centralizes all WoW event frames (architecture-analysis §3.3 was pre-EventRouter and is now resolved)
- `SecondaryBarBaseMixin` resolves §3.5/3.6 and Phase 3 of the roadmap
- Session persistence and time-refresh ticker were already implemented before this audit
- `delve-companion-feature.md` and `reputation-bar-feature.md` are superseded by NR-3
- `reference-addon-comparison.md` feature matrix updated (reputation/companion now Yes)
- 3 trivial XP improvements filed as `docs/backlog/xp-tracking-quick-wins.md` (isTask filter, expansion events, XP/hr threshold)
- Open items: architecture §3.1 (context location inconsistency) and §3.4 (context rebuild on every render) → MQ-1
- 12.0 compliance checklist not yet in `docs/guidelines/` → MQ-1 or doc pass

Next: MQ-3 (UI structure and naming cleanup)

## 2026-04-08 — MQ-5: Manager boundary enforcement + doc normalization

Architectural audit and enforcement pass. Root cause: managers (BarManager, Config, Options) were building XP/Reputation contexts and emitting directly onto EventBus, violating the documented contract that session layer owns context construction.

Changes made:

- **`Session:EmitUpdate(reason)`** added (`core/services/Session.lua`) — single canonical point for all `XPBAR_BROADCAST_UPDATE` emissions; all callers use this instead of constructing context themselves
- **`ReputationSession:EmitUpdate()` + `GetCurrentContext()`** added (`core/services/ReputationSession.lua`) — symmetric helpers for reputation domain
- **`defaults.delveCompanions`** dict added (`core/config/defaults.lua`) mapping faction ID → name for locale-safe companion detection
- **`BarManager:SetStyle`** emit migrated to `Session:EmitUpdate` — BarManager no longer touches context construction
- **`BarManager:OnRestedChanged`** removed — dead method never called (EventRouter dispatches direct to `Session:OnRestedChanged`)
- **`Config:ApplyOptionSideEffects`** two direct EventBus emits replaced with `Session:EmitUpdate` / `ReputationSession:EmitUpdate`
- **`Options:OnOptionChanged`** unconditional `XPBAR_BROADCAST_UPDATE` emit removed — genuinely redundant: `ApplyOptionSideEffects` always emits `CONFIG_UPDATED`, which `BaseMixin` subscribes to with `MarkDirty` (confirmed by reading BaseMixin.lua line 131)
- **`FlatSecondaryBarStyle:GetInitialContext()`** now routes through `ReputationSession:GetCurrentContext()` — bootstrap path no longer bypasses the session layer
- Docs corrected: `architecture-analysis.md` load order + lifecycle table + Pipeline C annotated; `companion-multi-companion.md` CompanionSession references removed; `pre-phase-7` §2.1 reference fixed

## 2026-04-08 — Localization-safe companion detection

Decision: Companion detection should use faction ID lookup instead of name matching.
Reason: IDs are locale-independent and stable; names are localized and fragile.
Implementation:

- `defaults.delveCompanions` is now a dict mapping factionID → display name (not a list).
- `ReputationSession.IsKnownDelveCompanion(factionID, name)` checks the dict by ID first, with name fallback for legacy compat.
- Companion faction list can be extended by admins by adding `[id] = "Name"` entries to `delveCompanions`.
- `/xpbe reps` command exports all faction IDs for easy reference.

## 2026-04-08 (session 6 continued)

Validation: NR-5 Delve companion decoration confirmed in-game.

- Unified secondary bar shows companion flavor (level display, companion text format) when tracking a Delve companion faction inside a Delve.
- Standard reputation flavor shown when tracking any non-companion faction.
- Bar correctly hides when outside Delve with `hideCompanionOutsideDelve` enabled and companion faction tracked.
- Transitions between companion and non-companion watched factions are clean.

## 2026-04-07 (session 6)

Decision: Suppress `MainStatusTrackingBarContainer` in addition to `SecondaryStatusTrackingBarContainer` when the addon's secondary bar is active.
Reason: At max level Blizzard's `StatusTrackingManagerMixin:UpdateBarsShown()` promotes the watched reputation bar into the main container (not the secondary container). Our existing hooks only covered the secondary container, so both bars appeared simultaneously on max-level characters.
Impact:

- `ShouldSuppressMainContainer()` local helper added to `SecondaryBarManager`; returns true when `Manager._currentStyle` is a custom style and `BarManager.currentStyle` is idle (`"none"`).
- `ApplyDefaultReputationBarVisibility` now also hides `MainStatusTrackingBarContainer` when the helper returns true.
- `InstallBlizzardBarHooks` now hooks `MainStatusTrackingBarContainer:Show` and `SetShown` with the same guard.

Decision: `DeriveSecondaryStyle` uses `TEMPLATE_MAP` lookup instead of hardcoded `"flat"` return.
Reason: The hardcoded return would silently show the flat secondary bar for styles that have no secondary template defined, and would not scale as new styles are added.
Impact: Style derivation returns the primary style key when a matching secondary template exists, otherwise `"none"`. `TEMPLATE_MAP` moved above `DeriveSecondaryStyle` to avoid a forward-reference bug.

Decision: Secondary bar at max level behaves as freely moveable (drag enabled, position saved) when `secondaryBarsAttached` is true but the primary frame is hidden.
Reason: In attached mode the bar is supposed to follow the primary bar's position. At max level the primary bar is hidden and `GetCurrentFrame()` returns nil — there is no target to attach to. Locking drag in this state offered no benefit and made the bar immovable without a config toggle.
Impact: `OnDragStart` and `OnDragStop` in `FlatSecondaryBarStyle` now check for a live primary frame before enforcing the attached-mode lock. `ReapplyAttachedPositions` in `SecondaryBarManager` uses the same nil-primary guard to fall back to `ApplyInitialPosition`.

Decision: Remove `secondaryBarPosition` from `defaults.lua`; make `GetFallbackPosition()` the sole dynamic default.
Reason: `ApplyInitialPosition` checks `defaults[configKey]` before calling `GetFallbackPosition()`. The static entry in defaults always won, so the per-style dynamic fallback (derived from `barPositions[barStyle]` + y-offset) was never reached. Removing the static entry lets the dynamic fallback run correctly.
Impact: `defaults.secondaryBarPosition` removed. `Manager:ResetBarPositions` simplified (the static-fallback branch removed). On reset, the secondary bar now lands at a position derived from the active XP bar style's default anchor.

Decision: Log per-style secondary bar position as a deferred backlog item.
Reason: Currently all styles share one `secondaryBarPosition` saved variable. Each style should eventually have its own independent saved position (mirroring `barPositions` for the primary bar). Not approved for immediate coding — complexity is low but requires a migration path and is not blocking anything now.
Impact: Documented in `docs/features/secondary-bar-manager.md` Backlog section with proposed approach.

## 2026-04-07 (session 4)

Decision: Add a user option to hide the secondary bar when the watched faction is a Delve companion and the player is outside a Delve.
Reason: Companion progression is only actionable in Delves for this use case, and some users prefer not to keep the companion-flavored secondary bar visible while in open-world or non-Delve content.
Impact:

- New config key `hideCompanionOutsideDelve` (default `false`) with options panel checkbox.
- `ContextBuilder.BuildReputationContext()` now applies a stricter companion visibility gate when the option is enabled.
- Toggling the option emits `REPUTATION_BROADCAST_UPDATE` immediately so bar visibility updates without requiring zoning or faction changes.

## 2026-04-07 (session 3)

Decision: Companion and reputation tracking are the same data source — unify into a single tracked-reputation secondary bar per style, with companion-specific decoration when the tracked faction is a delve companion.
Reason: In-game investigation and reference-addon comparison confirmed that companion XP is accessed entirely through the friendship reputation API (`C_GossipInfo.GetFriendshipReputation`). The companion bar was never a separate data domain — it was always a watched reputation faction that happens to be a friendship faction flagged as a known delve companion. Maintaining two separate service/session/context/style pipelines for the same underlying data source creates duplication, identity-resolution bugs (fallback selecting wrong companion), and unnecessary user-facing complexity (two checkboxes for what is conceptually one tracked bar).

Key findings:

- Companion data comes from `C_GossipInfo.GetFriendshipReputation(factionID)` — the same API path used for friendship-type reputations.
- The reference addon resolves companion identity by scanning the faction list for known names (`FindCompanionFactionID`), then applies delve-specific visibility gates (in-delve check, max-level hide). The underlying data fetch is identical to any other friendship faction.
- In-delve testing showed the current separate-pipeline approach produces fallback misdetection (Valeera selected when wrong companion is active) because the identity resolution runs independently of the watched faction state.
- The watched faction is the correct single source of truth — if the player tracks a delve companion, the bar should show companion flavor (delve gating, level display); if they track any other faction, it renders as a standard reputation bar.

Impact:

- Two separate bars (reputation + companion) will be replaced by one secondary "tracked reputation" bar per style.
- Companion decoration (in-delve visibility gate, level display, companion-specific text) is conditional — applied only when the tracked faction is detected as a known delve companion.
- `showReputationBar` and `showCompanionBar` collapse into a single `showSecondaryBar` toggle (or renamed equivalent).
- `CompanionSession`, `CompanionCalculations`, `FlatCompanionBarStyle`, and companion-specific context builder paths can be removed or folded into the reputation pipeline.
- `ReputationSession` gains companion-aware detection: is-companion check + delve-context gating.
- Reduces total secondary bar code, eliminates identity-resolution bugs, and simplifies the options panel.

Decision: NR-3 implementation has defects that should be fixed as part of the unification rather than patched independently.
Reason: Two bugs were found during NR-3 testing — (1) attached mode drag lock does not fully prevent position save on drag stop, (2) companion identity resolution falls back to wrong companion. Both stem from the two-bar architecture that the unification will replace. Patching them in the current split model would be throwaway work.
Impact: NR-3 execution steps remain structurally valid (checkboxes, attached mode, style derivation) but the companion-specific paths need to be replaced by the unified model before the regression pass.

## 2026-04-07 (session 2)

Decision: Replace per-bar style dropdowns with boolean enable/disable checkboxes and add an attached/free position toggle (NR-3).
Reason: Testing revealed the "none / flat" dropdown was a confusing proxy for a simple on/off choice — bars only ever had one style. A checkbox is clearer. The attached/free option was needed to let secondary bars follow the XP bar position without requiring manual realignment.

Impact:

- `defaults.lua`: `reputationBarStyle`/`companionBarStyle` removed; `showReputationBar = false`, `showCompanionBar = false`, `secondaryBarsAttached = true` added.
- `Database:Initialize`: migration converts old style keys on first load (non-"none" → true, "none" → false).
- `SecondaryBarManager`: `_DeriveSecondaryStyle(key)` replaces direct style reads; returns `"flat"` when bar enabled and primary style is not "none", else `"none"`.
- `OptionsPanel.xml`: two `ConfigDropdownTemplate` rows replaced with three `ConfigCheckboxTemplate` rows.
- `OptionMetadata.lua`: old dropdown entries removed; three checkbox entries added; `optionOrder` updated.
- `locales/enUS.lua`: old style locale keys replaced with `OPT_SHOW_REPUTATION_BAR`, `OPT_SHOW_COMPANION_BAR`, `OPT_SECONDARY_BARS_ATTACHED` (plus `_DESC` variants).

## 2026-04-07

Decision: Remove all dead Slice 3 max-level exploration code (NR-1 + NR-2).
Reason: Slice 3 explored configurable max-level behavior modes (always_show, show_reputation, show_rested_only, hide) then reverted to unconditional hide. The exploration builders and behavior dispatch were never activated in the shipped contract and produced noisy investigation logs on every XP event.
Impact: Removed from `BarManager`: `ToDebugString`, `IsMaxLevelDebugEnabled`, `LogMaxLevel`, `GetMaxLevelBehavior`, `VALID_MAX_LEVEL_BEHAVIORS`, `CloneContext`, `BuildAlwaysShowContext`, `BuildRestedOnlyContext`, `BuildReputationAsPrimaryContext`, all `LogMaxLevel` call sites. Removed from `defaults.lua`: `maxLevelBehavior`, `debugMaxLevelLogs`. Removed from `BaseMixin`: all `manager:LogMaxLevel` call sites. `AdjustContextForMaxLevel` simplified to an unconditional nil-at-cap return with no logging. Runtime is now silent by default.

## 2026-04-03

Decision: Move active planning and backlog documentation to docs folder hierarchy.
Reason: reduce dependence on AI-specific folder conventions and keep project knowledge portable.
Impact: docs/plan.md becomes active session guide; docs/memory, docs/guidelines, docs/features become canonical project docs.

Decision: Keep BarManager and SecondaryBarManager split.
Reason: responsibilities differ and forcing merge adds complexity without clear gain.
Impact: refactoring focuses on event/context/render contract consistency, not manager unification.

Decision: Defer full Event Router consolidation.
Reason: high-change operation best done after contract normalization.
Impact: short-term work prioritizes correctness and stabilization first.

## 2026-04-04

Decision: EventBus no longer auto-builds XP context; emitters must provide explicit payloads.
Reason: remove domain-specific implicit behavior from shared infrastructure.
Impact: emit sites were normalized; listeners now receive predictable payload contracts.

Decision: Secondary session emitters return the same flat context shape consumed by secondary bar styles.
Reason: avoid listener-side rebuilding and context-shape mismatches.
Impact: reputation/companion bars render from emitted context consistently.

Decision: Split Blizzard tracking-bar visibility ownership by domain.
Reason: XP style selection should not hide Blizzard reputation tracking when custom reputation style is disabled.
Impact: BarManager controls Blizzard XP visibility; SecondaryBarManager controls Blizzard reputation visibility.

Decision: On watched-faction clear/switch, ReputationSession emits immediate update.
Reason: prevent stale custom reputation bar state after tracked faction transitions.
Impact: custom reputation bar now hides/shows correctly when tracked faction changes.

## 2026-04-04 (Backlog)

Decision: Create docs/backlog/ folder with individual feature files, replacing inline plan.md backlog.
Reason: one-file-per-feature allows independent tracking, clear scope, and avoids plan.md bloat.
Impact: plan.md now references backlog folder; backlog README provides priority index.

Decision: Prioritize secondary bar polish (fade, tooltip, drag) as P1 before architecture refactors.
Reason: user-visible improvements deliver value immediately; architecture work is internal and can wait.
Impact: P1 items are all small-effort, low-risk secondary bar enhancements.

Decision: Defer event router consolidation and shared bar contract to P3.
Reason: high-change refactors best done after secondary bar polish is stable and well-tested.
Impact: current multi-frame event registration remains until all P1/P2 work is complete.

## 2026-04-04 (Architecture Alignment Update)

Decision: Re-prioritize shared bar contract and event router consolidation ahead of secondary-bar polish tasks.
Reason: architecture-enabling work reduces duplicated implementation effort and improves traceability.
Impact: `shared-bar-contract.md` and `event-router-consolidation.md` promoted to P1; secondary polish items moved to P2.

Decision: Enforce strict manager boundaries in architecture guidance.
Reason: managers should remain lifecycle/style/visibility orchestrators and avoid domain context-building responsibilities.
Impact: guidelines and feature docs now explicitly require manager-layer context decoupling.

Decision: Adopt Blizzard-aligned status/progress UI principles as architecture references.
Reason: Blizzard patterns favor central orchestration, shared bar contracts, and coalesced animation/update handling.
Impact: `docs/guidelines/code-architecture-choices.md` updated with explicit architecture principles and migration priorities.

## 2026-04-05

Decision: Start shared secondary-bar lifecycle migration with a dedicated base mixin.
Reason: secondary bars duplicated lifecycle wiring and rendered immediately on each event; this blocks additive polish work.
Impact: `XPBarSecondaryBaseMixin` now owns `OnLoad`/`OnShow`/`OnHide`/`Refresh`/`MarkDirty`, while secondary styles only provide domain hooks and render logic.

Decision: Keep shared-contract Phase 1 scoped to secondary bars first.
Reason: minimize blast radius and preserve stable primary XP behavior while validating the contract pattern.
Impact: `XPBarFlatReputationMixin` and the former companion secondary mixin now compose from the shared base; XP primary mixin remains unchanged for this step.

Decision: Add optional secondary text ticker support to shared lifecycle mixin.
Reason: enable follow-on live text/tooltip polish without re-adding per-style ticker wiring.
Impact: secondary styles can opt in with `GetTextTickerInterval` and `OnTextTick`; no behavior changes for styles that do not implement these hooks.

Decision: Begin Phase 2 by removing manager dependency on private session context builders.
Reason: private session methods should not be called outside service scope; manager responsibilities should remain lifecycle/visibility focused.
Impact: `SecondaryBarManager` now builds startup contexts through `XPBarContextBuilder` instead of `_BuildContext` session internals.

Decision: Remove secondary entering-world broadcast ownership from `SecondaryBarManager`.
Reason: entering-world domain refresh belongs to session/service orchestration, not style/visibility manager layer.
Impact: manager no longer emits reputation/companion updates on entering world; session layers are now the source for those broadcasts.

Decision: Re-apply secondary Blizzard visibility policy from lifecycle defer pass.
Reason: Blizzard status tracking containers can be re-shown during entering-world internals and must be corrected after all handlers finish.
Impact: `AddOnLifecycle:OnPlayerEnteringWorld` now defers both XP and secondary visibility policy re-application.

Decision: Introduce `core/EventRouter.lua` for staged secondary-domain event ownership.
Reason: continue modularization by reducing distributed hidden event frames while keeping migration incremental.
Impact: router now owns `UPDATE_FACTION`, `CHAT_MSG_COMBAT_FACTION_CHANGE`, `MAJOR_FACTION_RENOWN_LEVEL_CHANGED`, and `DELVES_ACCOUNT_DATA_ELEMENT_CHANGED` dispatch for reputation/companion services.

Decision: Remove event frame creation from `ReputationSession` (and the former `CompanionSession`, deleted in NR-3).
Reason: event ownership moved to router; duplicate registration would cause redundant updates.
Impact: these services are now state/handler modules for external events rather than event-frame owners.

Decision: Migrate `QuestXP` external events to `EventRouter` and remove QuestXP listener frame.
Reason: continue staged consolidation of distributed event ownership while preserving existing rebuild delay behavior.
Impact: `QuestXP` now exposes `HandleRoutedEvent(event)`; router owns QuestXP event registrations and forwards to service handler.

Decision: Migrate Session external event ownership to `EventRouter` while preserving level-up lifecycle ownership.
Reason: reduce distributed event-frame ownership without changing existing `AddOnLifecycle -> Session:OnLevelUp` flow.
Impact: Session no longer registers WoW events directly; router now dispatches XP, quest, rested, and time-played events into Session handlers.

Decision: Start Stage 3 by moving remaining lifecycle fan-out events to `EventRouter`.
Reason: centralize runtime event routing in one place and reduce orchestration spread across modules.
Impact: router now dispatches entering-world, level-up, XP gain enable/disable, and max-level-update fan-out behavior; `AddOnLifecycle` was reduced to startup/shutdown handlers.

Decision: Complete Stage 3 by moving startup/shutdown event registrations into `EventRouter`.
Reason: satisfy single-frame external event ownership target and keep AddOnLifecycle focused on handler logic only.
Impact: `AddOnLifecycle` no longer owns a frame or event map; `EventRouter` now registers and dispatches `ADDON_LOADED`, `PLAYER_LOGIN`, and `PLAYER_LOGOUT` in addition to domain and lifecycle fan-out events.

Decision: Stabilize Stage 3 startup ordering by gating routed reputation/companion handlers on initialized session state, while keeping Session routed handlers ungated.
Reason: reputation/companion handlers depend on local `_session` seeded during login; Session uses database-backed `GetCurrent()` and must continue processing XP updates without `_session` gating.
Impact: nil-session faults on early routed events were resolved and XP refresh/animation behavior was restored after removing incorrect Session dispatcher gating.

Decision: Close Stage 3 consolidation after in-game validation pass.
Reason: runtime testing confirmed no errors and restored XP gain refresh behavior after startup-order stabilization fixes.
Impact: event-router consolidation backlog item is now considered implemented and validated for current scope.

Decision: Prepare Phase 5 execution as a staged implementation plan before touching runtime code.
Reason: session persistence changes affect saved variables, options wiring, and time-based calculations; staged rollout lowers regression risk.
Impact: Phase 5 now has a concrete, ordered checklist and validated target file map, ready for implementation kickoff.

Decision: Implement Phase 5 with `sessionAccumTime` persistence and configurable `/reload` reset policy.
Reason: keep XP/hour, session-time, and time-to-level stable across UI reload by default while still supporting opt-in reset semantics.
Impact: `Session` now persists/rebases elapsed session time through `/reload`; new `resetOnReload` option (default false) controls whether reload continues or resets the session window.

Decision: Close Phase 5 after in-game validation pass.
Reason: runtime checks confirmed correct continuity when `resetOnReload=false` and correct reset behavior when `resetOnReload=true`, with fresh login still starting a new session.
Impact: session-persistence-reload backlog item is now implemented and validated for current scope.

Decision: Carry `docs/notes.md` findings into next planning cycle as analysis tasks.
Reason: observed differences in XP vs secondary session/context workflow and options panel complexity are architectural/UX opportunities but not blockers for Phase 5 closure.
Impact: next-phase readiness now includes analysis tasks for workflow harmonization and options panel structure review against Blizzard patterns.

Decision: Gate Phase 7 behind a dedicated planning/approval session after Phase 6.
Reason: follow-on scope is not yet approved and needs separate review of priority, risk, and acceptance criteria before implementation.
Impact: `docs/plan.md` now treats Phase 6 as implementation-ready and Phase 7 as planning-only until explicit approval is documented.

Decision: Implement Phase 6 four features using shared base mixin hooks without lifecycle duplication.
Reason: all four polish features (fade, drag, tooltip, ticker) can be wired into hooks already present in `SecondaryBarBaseMixin` without adding new lifecycle paths.
Impact: style mixins implement feature-specific logic only; no duplicate controller/manager code required across styles.

Decision: Fade secondary bars only on tracking state changes, not idle timers.
Reason: fade should match Blizzard's reputation bar behavior, which occurs when the player tracks/untracks a faction or when companion availability changes, not on arbitrary idle periods.
Impact: `FadeToAlpha(targetAlpha)` triggers when `context.isAvailable` transitions from false→true or true→false; no delay or idle gating required.

Decision: Persist bar positions to SavedVariables on drag-stop, with config-driven key per bar type.
Reason: positions survive across reload and re-login, and can be cleared independently via reset button.
Impact: each style's `SavePosition()` stores point/relativeTo/relativePoint/x/y to `Addon.db[configKey]`; reset clears key and re-anchors.

Decision: Use TextFormatter for all tooltip and live-text number/time formatting.
Reason: maintain consistent formatting with primary XP bar tooltips and avoid format logic duplication.
Impact: both styles import and call `TextFormatter:FormatNumber()`, `:FormatTime()`, `:FormatPercent()` for display.

Decision: Implement live text ticker at 1.0s interval for both reputation and companion bars.
Reason: 1s update frequency matches primary XP bar ticker and provides real-time rate/gained feedback without excessive re-renders.
Impact: `GetTextTickerInterval()` returns 1.0; `OnTextTick(context)` rebuilds on-bar text label with fresh calculations every 1s.

Decision: Tooltip content includes session metrics (gained, rates, time-to-next) in addition to bar-displayed progress.
Reason: tooltips provide user with deeper context on session performance without cluttering on-bar text.
Impact: `OnEnter()` reads `_lastContext` and populates GameTooltip with faction/companion name, progress, session gained, rep/hour or XP/hour, and time projections.

Decision: Simplify fade implementation to state-change-based transitions instead of idle timers.
Reason: fade-out should only occur when faction tracking is disabled or companion becomes unavailable, not on arbitrary idle delays; this matches Blizzard's behavior.
Impact: removed `FadeOut()` idle timer logic and `secondaryFadeDelay` config; replaced with `FadeToAlpha(targetAlpha)` that triggers only when `context.isAvailable` state changes frame-to-frame.

## 2026-04-06

Decision: Close faction selector, size/scale options, per-bar font customization, and localization from the active roadmap.
Reason: these items are not needed for the current product scope and should not consume near-term implementation capacity.
Impact: related backlog files are now marked closed/not planned and removed from active execution ordering.

Decision: Keep additional secondary styles as investigation-only.
Reason: style expansion requires deeper architecture and UX analysis before accurate effort/risk estimation.
Impact: `docs/backlog/secondary-bar-styles.md` now includes an explicit investigation gate and is not approved for coding.

Decision: Start pre-Phase-7 implementation with documentation and governance alignment.
Reason: roadmap and phase guidance must be synchronized before any next feature implementation begins.
Impact: `docs/plan.md`, `docs/backlog/README.md`, and `docs/notes.md` were updated to reflect active priorities, analysis tracks, and approval gates.

Decision: Stage Session 2 architecture and Blizzard-compliance outputs as one combined planning deliverable.
Reason: keep pre-Phase-7 approval inputs centralized, reduce fragmentation, and make gate review explicit.
Impact: `docs/analysis/pre-phase-7-architecture-compliance-deliverable.md` is now the canonical Session 2 artifact and is referenced by gate/planning docs.

Decision: Select Phase 7 Slice 1 as compliance-hardening-first before any feature expansion.
Reason: critical/high-risk interaction safety and Blizzard-aligned behavior should be stabilized before broader post-gate changes.
Impact: `docs/features/phase-7-slice-1-compliance-hardening.md` is now the next coding slice target and is linked from planning-gate and plan docs.

Decision: Compact planning and phase documentation to enforce concise, bounded docs.
Reason: phase/session docs were growing with duplicated historical narrative and drifting from governance intent.
Impact: `docs/plan.md` is now a concise execution guide, `docs/features/phase-6-secondary-polish.md` is a compact feature summary, and `docs/README.md` now documents clear boundaries for plan vs feature vs analysis vs decision-log content.

Decision: Enforce strict doc ownership model: plan=session planning, features+memory=decisions/analysis context.
Reason: prevent documentation growth from mixed responsibilities and keep one source of truth per concern.
Impact: `docs/plan.md` now excludes durable approvals/decisions, `docs/features/phase-7-planning-gate.md` owns approval state, and approvals/decision rationale are required in `docs/memory/decision-log.md`.

Decision: Approve Phase 7 Slice 1 and begin compliance hardening implementation.
Reason: planning gate criteria were met and the next safe step is targeted hardening before broader feature expansion.
Impact: `docs/features/phase-7-planning-gate.md` now records approval; `docs/features/phase-7-slice-1-compliance-hardening.md` status moved to in-progress.
Decision: Harden secondary drag semantics by removing SetUserPlaced(false) on drag paths and setting user placement true on drag stop.
Reason: avoid conflicting placement semantics while preserving explicit SavedVariables persistence flow.
Impact: secondary style mixins now call `SetUserPlaced(true)` on drag stop and no longer force false on drag start/stop.

Decision: Add combat-safe drag setup and movement gating for secondary bars.
Reason: movement-related setup should not run unsafely during combat-sensitive windows.
Impact: `SecondaryBarBaseMixin:ConfigureDragSupport()` now defers drag setup to `PLAYER_REGEN_ENABLED` when needed; drag start is blocked while in combat.

Decision: Add tooltip safety guards and ticker context caching preference.
Reason: avoid tooltip nil access issues and reduce avoidable context rebuild churn.
Impact: tooltip handlers now guard `GameTooltip`; text ticker now prefers `_lastContext` before rebuilding fallback context.

Decision: Rework fade animation lifecycle to reuse a single animation object.
Reason: prevent repeated animation allocation/stale state accumulation during frequent availability transitions.
Impact: `FadeToAlpha()` now reuses cached animation objects, stops in-flight animation before retargeting, and stops cleanly on hide.

Decision: Close Slice 1 hardening after in-game validation pass.
Reason: runtime testing reported no errors after drag/combat-safety/tooltip/fade/ticker hardening changes.
Impact: `docs/features/phase-7-slice-1-compliance-hardening.md` marked implemented and validated; repository is ready to move to next approved slice selection.

Decision: Start Slice 2 for secondary context contract normalization.
Reason: next planned consistency work is to reduce redundant context rebuilds and standardize source preference for secondary lifecycle paths.
Impact: `docs/features/phase-7-slice-2-context-contract.md` added and set in-progress; gate/plan now point to Slice 2 as active execution target.

Decision: Centralize latest-context resolution in `SecondaryBarBaseMixin`.
Reason: refresh/ticker paths should prefer emitted/cached context and use initial-context rebuild only as bootstrap fallback.
Impact: `GetLatestContext()` added and wired into shared `Refresh()` and text ticker flow.

Decision: Validate current Slice 2 batch in-game and proceed.
Reason: runtime verification reported no errors after context-source normalization changes.
Impact: Slice 2 remains in-progress, with current batch accepted as stable baseline for next incremental step.

Decision: Close Slice 2 context-contract normalization and mark it validated.
Reason: all planned Slice 2 scope items are complete and in-game checks reported no errors/regressions.
Impact: `docs/features/phase-7-slice-2-context-contract.md`, gate status, and plan phase table now treat Slice 2 as closed.

Decision: Select max-level behavior enhancements as Phase 7 Slice 3 and prepare kickoff docs.
Reason: it is the remaining approved near-term active backlog item and can be implemented incrementally with low risk.
Impact: created `docs/features/phase-7-slice-3-max-level-behavior.md`; plan and gate now point to Slice 3 as next execution target.

Decision: Start Slice 3 implementation with max-level behavior mode wiring.
Reason: move from planning to incremental execution while keeping scope limited to approved Slice 3 targets.
Impact: options now expose `maxLevelBehavior`; `BarManager` and base mixin now apply max-level behavior modes (`always_show`, `show_reputation`, `hide`, `show_rested_only`) during style selection and render context handling.

Decision: Switch active-development max-level default behavior to `hide` and migrate legacy `always_show` defaults.
Reason: runtime logs showed capped characters remained visible because legacy/default mode was `always_show`, which conflicted with expected development behavior for max-level testing.
Impact: `maxLevelBehavior` now defaults to `hide`; `Config:Initialize()` performs a one-time migration from legacy default to `hide` for existing profiles unless users later reselect another mode.

Decision: Preserve historical max-level behavior contract by removing user-facing max-level mode selection.
Reason: Slice 3 did not explicitly approve changing long-standing behavior; expected behavior is primary XP hidden at cap while secondary styles remain independently visible.
Impact: primary XP bar now always hides at max level in `BarManager` regardless of prior mode experiments; temporary max-level option wiring and side effects were removed from options/config.

Decision: Close Slice 3 after in-game validation pass.
Reason: runtime validation confirmed expected behavior contract on capped characters.
Impact: Slice 3 is now complete: primary XP bar hides at max level, and secondary reputation/companion bars remain style-driven and visible when configured.
