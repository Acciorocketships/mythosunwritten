# Current Regressions and Test State

## Overall Status

Terrain integration behavior tests used for this investigation are passing, including:

- `test_integration_default_level_generation_forms_cluster_early`
- `test_integration_default_level_generation_not_sparse_or_isolated`
- `test_integration_default_level_generation_not_sparse_across_seeds`
- `test_integration_moving_player_frontier_keeps_generating_ground`
- `test_integration_out_of_range_requeue_does_not_duplicate_and_recovers`

`test_terrain_generator.gd` now passes fully on this branch.

## Known Failing Tests (Current Branch)

No current failing tests are known in `test_terrain_generator.gd`.

The previous 4 failures caused by calls to removed private helpers were fixed by updating tests to the current diagonal projection behavior path in `LevelEdgeRule`.

## Why This Matters

- The suite now provides a cleaner red/green signal for terrain changes.

## Repro

Run:

- `godot --path /Users/ryko/story -s res://addons/gut/gut_cmdln.gd -gconfig=res://tests/gutconfig.json -gtest=res://tests/test_terrain_generator.gd`

Current run should complete without those deprecated-method errors.

## Suggested Cleanup

1. Keep tests aligned to current behavior paths (avoid removed/private helper calls).
2. Prefer behavior-contract assertions over private helper symbol coupling.
3. Keep profiling diagnostics in dedicated tests.

## Runtime Startup State

Headless game startup succeeds during this investigation:

- `godot --headless --path /Users/ryko/story`

Observed warnings are UID/path resolution warnings (camera/character/terrain generator resources), not fatal startup errors.

## Latest Queue-Fix Validation Notes

- Full `test_terrain_generator.gd` run passes.
- New queue/regression tests pass and emit queue-health logs used in `generation-lag-and-stall.md`.
- No additional regressions were introduced by queue dedupe/deferred requeue/connection-query updates.

## Open Runtime Visual Issue (March 2026)

### Boundary level tile orientation occasionally incorrect

- User-observed issue during runtime profiling:
  - A boundary level tile can appear with an "edge" silhouette facing inward toward an adjacent level tile.
  - This is typically seen near level patch boundaries (not commonly in large interior clusters).
- Status: **known open issue**, not addressed in current perf-focused changes.

### Repro Notes (qualitative)

1. Run terrain generation long enough to form medium/large level patches.
2. Inspect boundary tiles around patch perimeter.
3. Occasionally one boundary tile appears visually mismatched, with an inward-facing edge toward a neighboring level tile.

### Investigation Context Link

- See `generation-lag-and-stall.md` for recent `LevelEdgeRule` performance findings and change history.

