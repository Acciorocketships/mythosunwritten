# Level Stacking Sparsity with Self Socket Requirements

## Status: RESOLVED

The `!ground-type` self-requirement mechanism has been removed. The tiered level-module model
makes it unnecessary — see resolution below.

## Original Goal

Enable multi-level level-tile stacking ("mountain" behavior) while ensuring:

- Level tiles only stack on valid supports (not on edge/corner variants).
- Graduated slopes instead of cliffs (edge textures look bad when stacked).
- No infinite/over-aggressive upward growth.

## What Was Tried

### `!` self-requirement mechanism

`socket_required["bottom"] = ["!ground-type"]` required the adjacent piece at the bottom socket
to have the `ground-type` tag. This was semantically correct but caused sparsity because:

1. Most lateral level expansion contexts lacked a `bottom` adjacency entirely.
2. The filtering rejected all candidates whenever `bottom` support was missing.
3. Combined with `LevelEdgeRule` retiling (which replaced center tiles before their `topcenter`
   sockets could be processed), very few vertical placements succeeded.

### Coordinate system mismatch

`level-center` originally used `GroundTile.tscn`, whose socket coordinate system was rotated 90°
relative to all other level variant scenes. This caused `LevelEdgeRule` neighbor detection to fail,
preventing tiles from converging to center state. Fixed by creating `LevelCenter.tscn` with
sockets aligned to the standard level variant coordinate system (front=Z-, right=X+).

### Socket overlap issue

`LevelCenter.tscn` initially included `bottomfront/back/left/right` sockets that spatially
overlapped with ground cardinal sockets, causing `remove_linked_sockets_from_queue` to incorrectly
remove ground expansion sockets. Fixed by removing those unnecessary bottom-side sockets.

## Resolution: Tiered Level Modules

Instead of using `!` requirements to constrain stacking, the system now relies on **two explicit
families of level modules**:

- **Ground-level modules** carry the `level-ground` tier tag. Their cardinal sockets keep lateral
  fill probability so the first level can form dense connected patches, and their lateral
  distributions point back to the sampled `level-ground-center` module.
- **Elevated modules** carry the `level-stack` tier tag. Their cardinal sockets are non-expandable,
  so once terrain is above the base level it only grows vertically.
- **Ground `topcenter` seeding uses `{"level-ground-center": 1.0}`** so first-level 24x24 spawns
  always start from the ground-tier center module.
- **Ground-tier `level-center` tiles use `{"level-stack-center": 1.0}` on `topcenter`**, so
  stacked terrain samples the elevated center module instead of reusing the ground-tier one.
- **Elevated `level-stack-center` uses `topcenter` fill probability `0.95`**, so higher levels fill
  the interior of valid supports almost completely.
- **`LevelEdgeRule` removes stacked tiles** when a center support tile is retiled to an edge
  variant (the stacked tile would be visually unsupported).
- **`LevelEdgeRule` preserves the tier of the source piece** when it retile-swaps variants, so
  ground and elevated levels keep their own expansion behavior without any generator special cases.
- **`LevelEdgeRule` diagonal checks are same-layer only** — elevated tiles must not influence
  lower-level inner-corner/edge silhouette selection.
- **`LevelContradictionRule` remains disabled** — it caused stale references and false positives on
  vertical socket connections, removing stacked tiles immediately after placement.

This naturally produces the desired behavior:

- Ground seeding forms first-level level patches.
- Mountains grow vertically from upper-level supports without letting higher levels sprawl outward.
- Stacked tiles are only kept above supports that still have all four cardinal neighbors.
- Edge variants cannot keep stacked tiles above them.
- Upper levels no longer distort lower-level edge silhouettes.

## Additional Bugs Found During Implementation

### Second-level density still low after tier split — FIXED (rule-gated topcenter)

After splitting level tiles into `level-ground` and `level-stack` tiers, second-level stacking was
still sparse because:

1. The ground-tier center used `topcenter = 0.6`, so only 60% of centers tried to stack.
2. Tiles start as edge variants (no neighbors yet) and only become centers after all 4 cardinals
   are connected. The `topcenter` socket was enqueued/dequeued repeatedly during retiling churn,
   and only got a single fill-prob roll once the tile finally settled as a center.

**Fix**: topcenter is now **rule-gated**. All level center module definitions have
`topcenter = null` (non-expandable). `LevelEdgeRule` activates topcenter via a per-instance
`socket_fill_prob_override` when a tile is confirmed as center (all 4 cardinal neighbors connected).
The override value is `0.95` for both ground and stack tiers. This ensures:

- No wasted queue operations during retiling churn.
- The topcenter socket is only enqueued once, at the right time, with `0.95` probability.
- Replaced center pieces get their topcenter enqueued automatically via `_replace_piece` →
  `add_piece_to_queue` (which reads the override). Unchanged centers that newly gain the override
  use `sockets_for_queue` returned by the rule.

### Stale piece references in queue

`LevelContradictionRule.apply()` called `destroy()` on pieces directly and used incorrect
dictionary keys (`"updated_piece"` instead of `"chosen_piece"`). This caused:

- Stale `TerrainModuleSocket` references in the priority queue pointing to destroyed pieces
  (null root, empty sockets dict).
- `Invalid access to property or key 'topcenter' on Dictionary` errors when processing stale
  sockets.
- `Assertion failed` in `TerrainModuleSocket.get_socket_position()` when socket lookups
  returned null.

Fixed by:

1. Using `.get()` instead of `[]` for dictionary access in `TerrainModuleSocket.socket` getter.
2. Adding stale-piece guards at the top of `_process_socket` and `get_dist_from_player`.
3. Fixing `LevelContradictionRule` to use `"chosen_piece"` key (matching generator expectations)
   and to communicate removals via `"piece_updates"` instead of calling `destroy()` directly.
4. Adding `.has()` guards in `_socket_fill_prob` (both in `TerrainGenerator` and
   `LevelContradictionRule`) to handle pieces whose socket names don't match the adjacency keys.

### Vertical socket contradiction false positive

`LevelContradictionRule.has_contradictions()` treated the `bottom` ↔ `topcenter` connection as a
fillability contradiction (non-expandable bottom touching expandable topcenter). This caused every
stacked level tile to be removed immediately after placement. The bottom socket is naturally
non-expandable (it's the support connection), so this isn't a real contradiction. Fixed by skipping
vertical sockets (`bottom`, `topcenter`) in contradiction detection.

### Elevated tiles affecting lower-level edge silhouettes

`LevelEdgeRule` diagonal neighbor queries used a tall Y query range and only checked X/Z alignment.
That allowed elevated level tiles to count as diagonal neighbors for lower-level tiles, which
produced incorrect inner-corner and edge variants near stacked terrain. Fixed by requiring diagonal
neighbors to be on the same height level as the piece being retiled.

## Code Removed

- `!` prefix handling in `TerrainModuleLibrary.convert_tag_list()`
- `filter_by_socket_requirements()` and `_module_matches_socket_requirements()` methods
- `socket_fill_prob_override` field on `TerrainModuleInstance`
- `bottom: TagList.new(["!ground-type"])` from level module `socket_required`
- All `[stack-dbg]`, `[edge-dbg]`, `[fill-fail]` debug prints
- Related unit tests for `!` requirements
