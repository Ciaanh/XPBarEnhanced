---
name: XPBarEnhanced Repository Rules
description: Repository-specific guardrails for XPBarEnhanced architecture, load order, style system safety, and release/version consistency.
applyTo: "**/*.lua,**/*.xml,**/*.toc,README.md,CHANGELOG.md,make-release.ps1,ui/changelog/Changelog.lua"
---

# XPBarEnhanced Repository Rules

These rules are specific to this repository and should be applied before writing or editing code.

## 1. Scope and Compatibility

- Target is WoW Retail only.
- Keep API usage compatible with Patch 12.x constraints and Secret Values rules.
- Keep TOC/interface metadata aligned with the current project versioning (do not introduce stale sample values).

## 2. Namespace and Globals

- Use `local Addon = XPBarEnhanced` in module files.
- Do not create new global tables or compatibility shims unless explicitly required.
- Keep shared module state under `Addon.*` (for example `Addon.UI`, `Addon.Session`, `Addon.Config`).

## 3. TOC Load Order Is Authoritative

- Treat `XPBarEnhanced.toc` order as runtime truth.
- Respect this sequence when adding files:
  1. Core namespace and config defaults
  2. Services and routing/event layers
  3. Base mixins and animation mixins
  4. Style builder/managers
  5. Shared style helpers
  6. XML templates and concrete style implementations
- If a change adds a new module, ensure TOC placement matches its dependencies.

## 4. Event Ownership Boundaries

- WoW event registration should stay centralized in `core/EventRouter.lua`.
- Session domains own emit/update fanout (`Session`, `ReputationSession`) and should remain the source for domain broadcast updates.
- Use `core/EventBus.lua` events for UI refresh paths rather than scattering direct cross-module calls.

## 5. Style System Safety Rules

- Style modules must tolerate helper availability/order differences.
- For shared helper access, prefer lazy resolver patterns and safe fallbacks over hard assumptions.
- Avoid hard errors from style render paths when optional helpers are unavailable; degrade gracefully.
- Keep primary/secondary style pairing aligned with manager/template mapping strategy.

## 6. Config and Options Consistency

- New settings must be wired end-to-end:
  1. `core/config/defaults.lua`
  2. config accessors/helpers
  3. options metadata/UI controls
  4. consuming runtime code
- Keep naming consistent and avoid orphaned SavedVariables keys.

## 7. Release Hygiene

- Version changes must remain consistent across:
  - `XPBarEnhanced.toc` (`## Version:`)
  - `README.md` version text (if present)
  - `CHANGELOG.md`
- Keep the in-game changelog system synchronized with each release:
  - Add/update the corresponding version entry in `ui/changelog/Changelog.lua`.
  - Ensure the popup summary matches the same release highlights documented in `CHANGELOG.md`.
- Ensure packaging assumptions in `make-release.ps1` remain valid when folders/files move.

## 8. Change Discipline

- Prefer focused edits over broad rewrites.
- Preserve user-facing behavior unless the task explicitly changes behavior.
- For risky UI changes, include fallbacks to avoid runtime Lua errors in live gameplay.

## 9. Simplicity First (Hard Rule)

- Prefer the simplest solution that satisfies the requirement.
- Match existing behavior patterns in this repo unless a change request explicitly asks for different behavior.
- Avoid adding extra timers, retries, indirection, or abstraction layers unless there is a demonstrated need.
- When two approaches are equivalent, choose the one with fewer moving parts and clearer runtime flow.

## 10. Engineering Heuristics (High-Value Defaults)

- Verify APIs before introducing them. If an API is uncertain, consult `wow-api-index` first, then the matching domain skill; do not assume legacy behavior from pre-12.x.
- Prefer event-driven flows over polling. Use `OnUpdate` only when required, and throttle aggressively.
- Treat taint and combat-lockdown safety as design-time constraints, not post-fix bugs.
- Before adding new settings or data shape changes, confirm the full wiring path and runtime consumer behavior to avoid orphaned config keys.
- When implementing new behavior, decide explicitly whether the request needs a quick targeted fix or a reusable architecture change; default to targeted.
- Avoid fabricating function signatures, event payloads, or return value semantics. If uncertain, document the uncertainty and verify source references.
