# Terrain Generation Refactor — Design

## Goal

Reduce complexity and dead code in the terrain generation pipeline without changing
generation behavior or visual output. Where behavior does change (tier-based priority),
the change is opt-in via configuration.

## Background

`TerrainGenerator.gd`, `TerrainModuleDefinitions.gd`, and the rule files have grown
substantially. A few patterns are leftovers from the previous directional-tags scheme
(removed earlier). Several large blocks of definition code are nearly identical and
should be data-driven. The two edge-rule files (level and cliff) duplicate ~80% of
their logic.

## Sections

### 1. Dead code removal

**1.1** Remove the 4-rotation loop in `TerrainGenerator._resolve_placement_context`
(lines 178-194). All four iterations produce identical `required_tags` because no
real `socket_required` entry uses the `[socket]…` prefix. Also remove
`Helper.rotate_adjacency` (the per-socket-name `rotate_socket_name` stays — rules use it).

**1.2** Remove `[socket]…` prefix machinery from `TerrainModuleLibrary`:
delete `combined_tag_socket_name`, delete `convert_tag_list` (call sites inline the
direct union), drop the unused `_attachment_socket_name` parameter from
`get_required_tags`, delete the `tags_per_socket` parameter on `TerrainModule.new`
and the corresponding loop in `sort_terrain_modules`. Delete the one test that
exercises the prefix.

**1.3** Delete the obsolete `# Removed ensure_ground_coverage_around_piece` comment
at TerrainGenerator.gd:565 (project convention).

### 2. Tier-based placement priority

Change socket queue priority from `distance` to `distance + TIER_OFFSET[tier]`.

- **Structural tier (0):** ground, level, cliff, cliff-interior → offset 0
- **Decorative tier (1):** grass, bush, rock, tree, hill, 8x8x2, 12x12x2 → offset large

Tier is inferred from the dominant tag in `piece.def.socket_tag_prob[socket_name]`
at enqueue time. New helper `_socket_tier(piece, socket_name) -> int` on
`TerrainGenerator`. Static `TAG_TIER` map lives in `TerrainModuleDefinitions`.

Applied at all enqueue sites: `_ready` initial seeding, `add_piece_to_queue`,
`_flush_deferred_sockets`, rule `sockets_for_queue` results (push with priority 0
currently — keep that override).

Magnitude: start at `RENDER_RANGE * 2` so one full visible ring of structural pops
before any decorative.

### 3. Deduplicate Level/Cliff edge rules

New base class `FamilyEdgeRule` in `scripts/terrain/rules/FamilyEdgeRule.gd`.
Parameterized by:

- `family_tag: String` — `"level"` or `"cliff"`
- `canonical_missing_by_tag: Dictionary[String, Array]`
- `tag_order: Array[String]`
- Module lookup — derived from `library.modules_by_tag` (see 3.2)
- Subclass hook for extras (LevelEdgeRule's stacked-piece support check)

Methods moved to base:
`matches`, `apply`, `_get_family_neighbors`, `_missing_sockets_for_piece`,
`_has_family_connection`, `_diagonal_target_center`,
`_get_diagonal_family_neighbor_piece`, `_create_replacement_for_target`,
`_rotation_steps_to_align_canonical`, `_same_socket_set`, `_rotate_socket_names_once`,
`_add_unique_piece`, `_is_same_height`, `_current_variant_tag`.

`LevelEdgeRule` and `CliffEdgeRule` shrink to subclasses that set constants and
override the extras hook.

**3.2** Replace hard-coded `module_by_*_tag` lookup dictionaries with a derivation
from `library.modules_by_tag`, filtering by family + variant + tier tags. Built
lazily on first use, keyed off the library reference.

### 4. Data-drive `TerrainModuleDefinitions`

Collapse the ~28 `load_level_*` / `load_level_stack_*` factory functions into a
single bulk loader `load_level_variants() -> Array[TerrainModule]` that iterates
a static `LEVEL_VARIANTS` table:

```gdscript
const LEVEL_VARIANTS: Array = [
    {"scene": "LevelSide", "variant": "level-side"},
    {"scene": "LevelCorner", "variant": "level-corner"},
    # ... etc, both ground and stack tiers
]
```

`load_level_middle_tile` and `load_level_stack_middle_tile` keep their extra tags
(`level-ground-center`, `ground-type`) via a special flag in the table entry. The
existing `_build_level_tile` helper stays — it's the right level of abstraction.

`TerrainModuleLibrary.load_terrain_modules` calls the new bulk loader instead of
the 28 individual functions.

Cliff variants stay as-is (only 4, not worth the abstraction yet).

### 5. Cache test-piece socket layouts

`get_adjacent_from_size` currently spawns + frees a Node3D scene for every socket
evaluation. Replace with a precomputed lookup populated once at `_ready`:

`_test_piece_sockets: Dictionary[String, Dictionary[String, Vector3]]` keyed by
`size_tag` → `{socket_name: relative_offset_from_attachment_socket}`.

`get_adjacent_from_size` becomes pure math: compute world position per socket from
`origin_socket_pos + cached_relative_offset`, then `socket_index.query_other`.

Drop `test_pieces_library` after the cache is built (we don't need the runtime
TerrainModule objects, only the offsets).

### 6. Minor structural cleanups

**6.1** Extract a `_attach_piece(piece)` helper shared by `add_piece` and
`_replace_piece` (both register, reparent, queue).

**6.2** Replace `_resolve_placement_context`'s untyped Dictionary return with a
typed `PlacementContext` class. Same for the rule context Dictionary in
`_build_rule_context`.

**6.3** Simplify the `_deferred_sockets` machinery. Out-of-range sockets popped
during a frame can simply be re-pushed with their existing priority; the existing
`peek()`-based early-out at the top of `load_terrain` already handles the
all-out-of-range case. Removes the dedup mirror dict and the per-piece-removal
cleanup pass over `_deferred_sockets`.

## Implementation order

1. Section 1 (deletions) — smallest diffs, removes noise for everything else.
2. Section 4 (data-drive definitions) — independent.
3. Section 2 (tier priority) — independent feature.
4. Section 3 (rule dedup) — biggest refactor; easier after 1 and 4.
5. Section 5 (test-piece caching) — perf improvement.
6. Section 6 (minor structural) — interleave at the end.

## Testing

Existing test suites must pass without modification (except for the deleted
`[socket]` prefix test in section 1.2). The visual output should be unchanged
except for the tier-based ordering change in section 2 (more uniform structural
fill in the near-player ring before foliage appears).

## Out of scope

- Cliff variant data-driving (small enough to leave alone).
- Generation rule architecture changes beyond deduplication (rule ordering,
  rule registration mechanism, etc.).
- Any changes to the `Distribution`, `TagList`, `PriorityQueue`, `PositionIndex`,
  or `TerrainIndex` data structures.
