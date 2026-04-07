# Lessons Learned

## Secondary Bars

1. Temporary diagnostics must be behind a flag or removed before merge.
Why: unchecked debug prints in render/event paths increase noise and hide real failures.

2. Event contracts must be explicit and single-source.
Why: emitting one context shape and rendering from another causes duplicate work and ambiguity.

3. Hardcoded UI anchors do not scale once multiple bars exist.
Why: default CENTER anchors worked for prototype only; stacking requires config-driven positions.

4. Options panel layout must be validated whenever new controls are added.
Why: row insertion can break existing button anchors and visual flow.

## Architecture

1. When two features share the same underlying API data source, they should be one feature with conditional decoration, not two parallel pipelines.
Why: companion and reputation tracking both read from the same watched-faction / friendship-reputation API. Splitting them into separate services, sessions, context builders, and bar styles created duplication, identity-resolution bugs, and user confusion.

2. EventBus should dispatch, not infer domain behavior.
Why: XP-only auto-context generation made shared infrastructure domain-coupled.

2. Coalesced rendering should be standard for event-driven bars.
Why: burst events can trigger redundant rendering without dirty-mark batching.

3. Preserve healthy boundaries while normalizing contracts.
Why: per-domain sessions and separate managers are valuable; flow consistency is the real gap.

4. Visibility ownership must follow domain ownership.
Why: hiding a shared Blizzard container from the XP manager caused reputation UI regressions.

5. State-clearing transitions should emit explicit UI updates.
Why: tracked-faction clear/switch paths can leave stale frames visible if no event is emitted.

6. Shared bar contracts should land before adding secondary-bar polish.
Why: fade/tooltip/drag/time-refresh features otherwise duplicate lifecycle and cleanup logic across styles.

7. Central orchestration improves event-flow traceability.
Why: Blizzard status tracking uses a manager/container hierarchy with shared animation and dirty-state handling, reducing hidden control flow.
