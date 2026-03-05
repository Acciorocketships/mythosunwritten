# Socket Fill-Prob Semantics

## Summary

Terrain behavior currently depends on three socket states, but historical code treated only two states consistently.

- Expandable: `socket_fill_prob > 0`
- Non-expandable + blocking: explicit `0`
- Non-expandable + non-blocking: `null` (new behavior)
- Missing key: currently treated like `null` (new behavior), historically behaved like `0`

This area is still in flux and needs a final policy decision plus explicit per-socket authoring.

## Why This Matters

Adjacency resolution in terrain generation uses `_has_forbidden_adjacency()`. A socket that is treated as blocking can veto placement entirely.

Desired behavior from investigation:

- Diagonal sockets used for rule context should **not** expand.
- Those diagonal sockets should also **not** block placement.

## Repro

1. Run terrain generator tests:
   - `godot --path /Users/ryko/story -s res://addons/gut/gut_cmdln.gd -gconfig=res://tests/gutconfig.json -gtest=res://tests/test_terrain_generator.gd`
2. Inspect debug output from `test_integration_default_level_generation_forms_cluster_early`.
3. Compare `forbidden_blocking_socket_names` and `nonblocking_missing_socket_names`.

## Key Findings (From Debug Logs)

### Blocking hits

Only `topcenter` appeared as a blocking forbidden-adjacency hit in profiled runs:

- `forbidden_blocking_socket_names={ "topcenter": 173 }`
- Earlier run: `forbidden_blocking_socket_names={ "topcenter": 560 }`

### Missing entries that were encountered

When missing keys were made non-blocking, the following missing sockets were actively present in adjacency checks:

- `topfrontleft`: 101
- `topbackright`: 97
- `topbackleft`: 74
- `topfrontright`: 67

Observed debug map:

- `nonblocking_missing_socket_names={ "topfrontleft": 101, "topbackright": 97, "topbackleft": 74, "topfrontright": 67 }`

### Clarification: why top-corner sockets can appear as adjacency hits

This does **not** necessarily mean cardinal/diagonal neighbor tiles are physically touching at those top-corner points.

A key pattern in pair logs is that some expanders are ground tiles:

- `expander=["ground","24x24","side"] ... hit_socket=top...`

This indicates many top-corner hits happen during attempts to place a level tile from a ground `topcenter` socket on a cell that already has a level tile at that same XZ.

Relevant mechanics:

- `_is_socket_connected()` only treats sockets as connected when they are on the same layer (`ground` with `ground`, non-ground with non-ground).
- Ground `topcenter` vs existing level `bottom` is cross-layer, so it is **not** considered connected and can keep being processed.
- `get_adjacent_from_size()` then probes adjacency around that would-be placement and can hit existing level top-corner sockets.

So top-corner sockets being reported in adjacency logs can be a side effect of repeated same-cell elevation attempts, not direct corner contact between neighboring level tiles.

### Explicit `null` entries encountered

Diagonal sockets authored as `null` were also actively observed:

- `frontright`: 91
- `frontleft`: 91
- `backleft`: 64
- `backright`: 44

Observed debug map:

- `nonblocking_null_socket_names={ "frontright": 91, "frontleft": 91, "backright": 44, "backleft": 64 }`

### Audited missing sockets on level module(s)

`level-center` currently has omitted fill-prob entries for several sockets inherited from `GroundTile`:

- `topfrontright`, `topfrontleft`, `topbackright`, `topbackleft`
- `topfront`, `topright`, `topleft`, `topback`
- `bottom`

Observed debug map:

- `level_module_missing_fill_prob={ "[\"level\", \"level-center\", \"24x24\"]": ["topfrontright", "topfrontleft", "topbackright", "topbackleft", "topfront", "topright", "topleft", "topback", "bottom"] }`

## Fixes Attempted

### Attempt 0: Remove same-layer tag hardcoding from socket connection

- `_is_socket_connected()` changed from same-layer tag matching to "expandable hit" matching.
- `_sockets_same_layer()` was removed.
- Queue-link checks were updated to use expandability checks instead of tag/layer checks.
- Result: aligns with design goal of avoiding tag-hardcoded connection logic.
- Status: **successful architectural cleanup**; behavior tuning still required.

### Attempt A: Make missing entries non-blocking

- Code path changed: `_is_socket_blocking()` returns `false` when key missing.
- Result: behavior shifted substantially; more adjacency candidates became allowed.
- Status: **partially successful**, but increased generation workload and changed map behavior.

### Attempt B: Add explicit `null` diagonals in level definitions

- `frontright`, `frontleft`, `backright`, `backleft` changed from `0.0` to `null`.
- Result: diagonals stop blocking while remaining non-expandable.
- Status: **successful for intended diagonal behavior**.

### Attempt C: Safe null-aware readers

- Updated fill-prob reads in generator and contradiction rule to avoid `float(null)` errors.
- Result: removed runtime constructor errors from `float(null)`.
- Status: **successful**.

## Decision (March 2026)

Final policy is now explicit and enforced:

1. Missing `socket_fill_prob` keys are invalid.
2. Every scene socket must have an explicit `socket_fill_prob` entry.
3. `topcenter` on level tiles remains explicit `0` (non-expandable and blocking).

Validation now fails fast at `TerrainModule` construction when:

- a scene socket is missing from `socket_fill_prob`, or
- `socket_fill_prob` contains a key that is not present on the scene.

## Recommended Next Actions

1. Keep `socket_fill_prob` explicit for all sockets on all modules.
2. Keep only intentional blockers as explicit `0`.
3. Use `null` for non-expandable sockets that must not block adjacency.
4. Treat validation failures as module authoring errors and fix definitions immediately.

