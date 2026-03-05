# Generation Lag and "Map Edge Stall"

## Symptom

After changing blocking behavior for missing `socket_fill_prob` keys, generation became noticeably laggier and appeared to stop keeping up with player movement ("can run to edge of map").

## Repro

1. Use current branch with non-blocking missing key behavior.
2. Run the game headless (or run integration tests with debug counters):
   - `godot --headless --path /Users/ryko/story`
   - `godot --path /Users/ryko/story -s res://addons/gut/gut_cmdln.gd -gconfig=res://tests/gutconfig.json -gtest=res://tests/test_terrain_generator.gd`
3. Observe early generation debug in `test_integration_default_level_generation_forms_cluster_early`.

## Profile Data Collected

Instrumentation was added inside `_DebugTerrainGenerator._process_socket` in tests.

Representative run:

- `debug_time_us={ "process_socket_total": 7170793, "resolve_context": 902230, "try_place_with_rules": 6235929, "forbidden_scan": 4404 }`

Interpretation:

- `try_place_with_rules` dominates runtime (~6.24s of ~7.17s).
- Forbidden-adjacency scanning itself is negligible.
- Primary cost is placement attempt path (sampling, spawn/create, add/collision/rules).

## Why It Feels Like Generation Halts

In measured runs, generation was still progressing, but not fast enough relative to movement:

- `iter=220 level_tiles=293 open_level_cardinal=354 blocked_same_layer=818`

This suggests frontier still exists (`open_level_cardinal` > 0), but throughput per frame is insufficient, creating a perceived stall at render/generation boundary.

## Additional Root-Cause Context (High Confidence)

Repeated same-cell attempts from ground `topcenter` appear to amplify load:

- Ground expanders are present in socket-pair logs against level top sockets.
- `_is_socket_connected()` currently gates only same-layer matches.
- Ground `topcenter` sockets can remain "open" even when a level tile already occupies that vertical column.

That leads to repeated expensive processing cycles that often fail later in placement/rule checks, increasing frame-time pressure and contributing to perceived generation stalls.

## Fixes Attempted

### Attempt A: Missing keys non-blocking

- Increased available adjacency paths.
- Side effect: more candidate processing and more expensive generation.
- Status: **introduced performance side effects**.

### Attempt B: Reduce placement retries

- `_try_place_with_rules` changed from 4 attempts to 1.
- Profiling improved somewhat but hotspot remained dominant:
  - before approx: `try_place_with_rules` ~6.8s
  - after approx: `try_place_with_rules` ~6.2s
- Status: **partial improvement**, insufficient alone.

## Likely Root Cause

The big cost is cumulative work in `_try_place_with_rules` pipeline:

- module sampling
- instantiation (`spawn`/`create`)
- transform/collision placement checks
- rule application and possible replacement/removal operations

Allowing more non-blocking adjacency expands the candidate search space and number of expensive attempts.

## Recommended Fix Strategy

1. **Stabilize semantics first**:
   - Make socket config explicit, avoid accidental non-blocking via omissions.
2. **Reduce expensive failed attempts**:
   - Pre-filter more aggressively before spawn/create where possible.
3. **Budget work per frame**:
   - Tune dynamic cap by frame time, not fixed `MAX_LOAD_PER_STEP`.
4. **Avoid repeated expensive checks**:
   - Cache reusable adjacency/context info per socket pop.
5. **Measure each change**:
   - Keep existing debug timing counters while iterating.

## Additional Notes

- Headless startup runs succeeded (warnings only for invalid UIDs resolving via text path).
- Lag issue appears algorithmic/load-related, not crash-related.

## March 2026 Deep Investigation (Queue-Focused)

### New Repro/Instrumentation Tests

Added deterministic integration tests and queue instrumentation in `tests/test_terrain_generator.gd`:

- `test_integration_moving_player_frontier_keeps_generating_ground`
- `test_integration_out_of_range_requeue_does_not_duplicate_and_recovers`

Added debug helpers/counters:

- queue health snapshots (`queue_size`, duplicate entry count)
- out-of-range defer counts by socket name (`deferred_socket_counts`)
- moving-frontier starvation signals (`longest_zero_placement_streak`)

### Root Cause (Confirmed)

The "edge stall + lag spike" behavior was primarily queue churn and queue correctness:

1. **Duplicate queue entries were possible** for the same `(piece, socket)` and could accumulate.
2. **Out-of-range sockets were immediately requeued**, allowing same-frame churn and wasted processing budget.
3. **Connection checks used only one hit** at a socket position, despite `PositionIndex` storing multiple sockets per snapped position.

This combined into low effective throughput near the moving frontier even though generation was still "running."

### Code Fixes Implemented

#### `scripts/terrain/TerrainGenerator.gd`

- Added queue-key tracking for one-entry-per-socket dedupe.
- Added deferred requeue staging:
  - out-of-range sockets are staged during `load_terrain()`
  - re-enqueued once after the main pop/process loop
  - prevents same-frame pop/requeue churn loops
- Batched linked-socket queue removal in one `remove_where` pass.
- Updated `_is_socket_connected()` to treat a socket as connected if **any** overlapping other socket is expandable.

#### `scripts/terrain/PositionIndex.gd`

- Added `query_others(pos, piece)` to return all overlapping sockets at a snapped position.

#### `scripts/core/PriorityQueue.gd`

- `remove_where()` now returns the number of removed entries (supports queue maintenance instrumentation/cleanup paths).

### Collected Logs (Post-Fix)

From:

`godot --path /Users/ryko/story -s res://addons/gut/gut_cmdln.gd -gconfig=res://tests/gutconfig.json -gtest=res://tests/test_terrain_generator.gd`

`moving-frontier-debug`:

- `player_x=828.0`
- `max_ground_x=1008.0` (frontier remained ahead of player)
- `queue_peak=829`
- `duplicate_entry_peak=0`
- `no_ground_near_player_checks=0`
- `longest_zero_placement_streak=2`
- `deferred_total=152`
- `placed_total=1080`

`requeue-recovery-debug`:

- `queue_size_during_deferral_peak=230`
- `duplicate_entry_peak=0`
- `deferred_total_after_far=2800`
- `placed_before_far=335`
- `placed_after_recovery=518`

Interpretation:

- Duplicate queue growth is eliminated (`duplicate_entry_peak=0`).
- Generation recovers after long out-of-range periods (`placed_after_recovery > placed_before_far`).
- Moving-frontier run maintained nearby ground and kept frontier ahead of player.

### Current Status

- Core queue bug/optimization issue has a concrete fix in place.
- Remaining full-suite failures are the pre-existing test regressions documented in `current-regressions-and-test-state.md` (deprecated private-method calls), not this queue fix.

