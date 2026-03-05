# Current Regressions and Test State

## Overall Status

Terrain integration behavior tests used for this investigation are passing, including:

- `test_integration_default_level_generation_forms_cluster_early`
- `test_integration_default_level_generation_not_sparse_or_isolated`
- `test_integration_default_level_generation_not_sparse_across_seeds`
- `test_integration_moving_player_frontier_keeps_generating_ground`
- `test_integration_out_of_range_requeue_does_not_duplicate_and_recovers`

However, full `test_terrain_generator.gd` run still reports known failing tests unrelated to this socket-semantics profiling work.

## Known Failing Tests (Current Branch)

From recent run summaries, 4 failures are consistently present:

1. Calls to nonexistent `TerrainGenerator` method:
   - `_adjacent_hit_for_socket`
2. Calls to nonexistent `LevelEdgeRule` method:
   - `_get_diagonal_level_neighbor_piece_from_socket_adj`

These produce "Unexpected Errors" in tests that still reference those symbols.

## Why This Matters

- These failures create noise when validating new changes.
- They are not direct evidence that the socket fill-prob/lag changes are broken.
- They reduce confidence in red/green test signal unless filtered mentally.

## Repro

Run:

- `godot --path /Users/ryko/story -s res://addons/gut/gut_cmdln.gd -gconfig=res://tests/gutconfig.json -gtest=res://tests/test_terrain_generator.gd`

Look for:

- `Invalid call. Nonexistent function '_adjacent_hit_for_socket'`
- `Invalid call. Nonexistent function '_get_diagonal_level_neighbor_piece_from_socket_adj'`

## Suggested Cleanup

1. Update or remove tests referencing removed/private methods.
2. Prefer testing via public behavior contracts rather than private helper symbols.
3. Keep profiling diagnostics in dedicated tests to avoid coupling to deprecated internals.

## Runtime Startup State

Headless game startup succeeds during this investigation:

- `godot --headless --path /Users/ryko/story`

Observed warnings are UID/path resolution warnings (camera/character/terrain generator resources), not fatal startup errors.

## Latest Queue-Fix Validation Notes

- Full `test_terrain_generator.gd` run still reports the same 4 pre-existing failures.
- New queue/regression tests pass and emit queue-health logs used in `generation-lag-and-stall.md`.
- No additional regressions were introduced by queue dedupe/deferred requeue/connection-query updates.

