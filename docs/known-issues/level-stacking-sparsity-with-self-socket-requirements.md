# Level Stacking Sparsity with Self Socket Requirements

## Goal

Enable multi-level level-tile stacking ("mountain" behavior) while enforcing support constraints:

- Level tiles should only be placeable when their `bottom` socket is supported by a tile with a required tag.
- Current authoring uses `socket_required["bottom"] = ["!ground-type"]` for level modules.
- `ground-type` is intended to represent valid support surfaces (ground + center-like level support).

## What We Are Trying to Prevent

- Infinite/over-aggressive upward growth.
- Visual artifacts where unsupported lateral expansion creates sparse/noisy level coverage.
- Edge/corner-on-edge/corner stacking that looks wrong.

## Semantics Introduced

During this investigation, socket requirement semantics were clarified:

- `!tag` in `socket_required` means **self placement requirement**:
  - this candidate piece requires an adjacent piece with `tag` on that same socket.
- `[socket]tag` means **adjacency-context rewrite** for tag indexing requirements.

This moved old `!` rewrite behavior to explicit `[socket]...` and reserved `!` for hard placement constraints.

## Runtime Findings (Debug Session 34c6f6)

### Confirmed

1. Most `!ground-type` failures were due to **missing `bottom` adjacency**, not wrong tags.
2. For lateral level expansion attempts, adjacency snapshots often include only:
   - `front/back/left/right/topcenter` (or subsets), with no `bottom`.
3. Candidate filtering commonly had:
   - `pre_socket_requirement_count = 1`
   - `post_socket_requirement_count = 0`
   when `bottom` support was missing.

### Rejected

- "Existing adjacent support has wrong tag" was not a major driver in captured runs.

## Solutions Tried So Far

### 1) Self-requirement filtering in module selection

- Added explicit filtering path so `!tag` requirements are enforced during candidate selection.
- Outcome: behavior became correct semantically, but level generation became noticeably more sparse.

### 2) Early skip of unsupported lateral level expansion attempts

- Added an early gate in placement context:
  - if expanding from level on cardinal socket and adjacency lacks `bottom`, skip that attempt.
- Outcome: eliminated many deep failures, but sparsity still persisted.

### 3) Scheduler adjustment to avoid starvation from unsupported attempts

- Tracked skipped reasons and attempted not counting specific unsupported skips against processing budget.
- Added pop cap to avoid runaway loops.
- Outcome: partial improvement, but still insufficient in observed runtime runs.

### 4) Additional adjacency diagnostics (`H6`)

- Added diagnostics to determine whether missing `bottom` means:
  - true topology gap (no support tile), or
  - alignment/index visibility miss (support exists nearby but is not recognized as adjacent).
- Outcome: this path is now instrumented for continuing analysis.

### 5) Restore level-center vertical expansion configuration

- Found a regression in module definitions: `_build_level_tile` was leaving `topcenter` fill as `null`, so authored `topcenter_fill_prob` was effectively ignored.
- Fix applied:
  - `socket_fill_prob_policy["topcenter"] = topcenter_fill_prob`
  - when `topcenter_fill_prob > 0`, set `socket_tag_prob["topcenter"] = {"level-center": 1.0}`.
- Runtime result:
  - `level-center` `topcenter` sockets began enqueuing and processing (`H8` logs).

### 6) Defer unsupported lateral attempts (instead of dropping)

- For lateral level expansions with missing `bottom` support adjacency, attempts are deferred and retried (`H7`) rather than discarded.
- Outcome: improved retry behavior, but sparsity still depends on support availability and retile timing.

### 7) Rule-retile interaction with queued vertical growth (`H8/H9/H10`)

- `H8`: many `level-center` `topcenter` sockets were enqueued.
- `H9`: frequent `level-center` replacements by `LevelEdgeRule` removed queued `topcenter` work before it executed (`had_topcenter_key_before: true` observed repeatedly).
- Attempted fix:
  - preserve `level-center` variant when vertical growth preconditions matched.
- Side effect:
  - user observed missing edge/corner visuals; `H10` fired very frequently, indicating over-preservation pressure.
- Status:
  - this preservation behavior is currently treated as **rejected as a direct fix** due to visual regression.
  - instrumentation remains to track when this condition matches (`H10`) without forcing variant preservation.

## Current Understanding

The dominant issue appears to be:

- Lateral level expansion generates many candidate contexts where valid `bottom` support is unavailable at evaluation time.
- Strict `!ground-type` is semantically correct but amplifies sparsity because many attempts are invalid by construction.

Current evidence indicates this is a combined scheduling + rule interaction problem:

- strict support requirement (`!ground-type`) is correct,
- many lateral contexts are invalid by construction (no exact `bottom` support),
- and rule-driven retile can interfere with queued vertical-growth opportunities.

## Future Ideas

### A) Bottom-to-top queue priority (user proposal)

Current queue priority is distance-driven. Add height bias so lower Y sockets are processed first:

- Example conceptual priority:
  - `priority = distance + (y_bias * socket_world_y)`
  - or lexicographic `(y_bucket, distance)` where lower Y buckets win.

Expected effect:

- Support layers (ground/support surfaces) materialize before higher/lateral expansions depend on them.
- Fewer invalid `!ground-type` attempts.

Risks:

- Could delay desirable high-elevation detail far from player.
- Needs careful balancing with render-range behavior and deferred sockets.

### B) Two-queue strategy

- Queue A: support-forming sockets (low Y / foundation-relevant).
- Queue B: lateral/detail sockets.
- Process A before B each step.

Expected effect:

- Cleaner dependency ordering without overloading one scalar priority.

### C) Context-aware level lateral throttling

- Dynamically reduce cardinal level expansion probability when support confidence is low.
- Keep strict `!ground-type`, but avoid spending budget on low-probability-valid contexts.

### D) Validate adjacency geometry assumptions

- Use `H6` logs to check if near-support pieces are present but not registered as socket adjacency hits.
- If yes, investigate socket alignment, snap, or test-piece probing geometry.

### E) Prioritize queued `topcenter` before retile-sensitive lateral updates

- Give temporary priority boost to `level-center/topcenter` queue items (or process these in a dedicated pass first).
- Goal: consume vertical-growth opportunities before edge retile replaces center pieces.
- This can be paired with your Y-biased priority idea.

## Recommended Next Step

Implement and test **priority shaping** first:

1. Add Y component to queue priority for expansion sockets (bottom-to-top control).
2. Add a temporary boost or dedicated pass for `level-center/topcenter` sockets.
2. Keep current strict `!ground-type` semantics.
3. Compare before/after:
   - number of unsupported skips,
   - successful vertical placements,
   - visual density of stacked level formations.

## Status

- Issue remains open.
- Instrumentation is active for continued runtime-driven debugging.

## Branch Reset Note

- Per user request, experimental code changes from this debugging pass were rolled back.
- This dossier is intentionally retained as the running record of:
  - hypotheses,
  - runtime evidence,
  - attempted fixes and side effects,
  - and next candidate directions.
