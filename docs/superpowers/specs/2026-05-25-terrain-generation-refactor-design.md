# Terrain Generation Refactor — Design

## Goal

1. Strip out dead code in the terrain pipeline (rotation loop, `[socket]` prefix
   machinery, `tags_per_socket` field).
2. Data-drive the level/cliff variant definitions (~28+28 wrapper factories
   collapse into two tables).
3. Replace the hard-coded variant lookup dictionaries in LevelEdgeRule and
   CliffEdgeRule with library tag queries.
4. Generalize the existing level-stack player-spawn protection to all tiles
   (no tile of any kind should trap the player).
5. Add cliff-stack parity with level-stack — cliffs stack only on cliff-interior
   tiles, mirroring how levels stack on level-center.
6. Add tiered placement priority: cliffs first, then levels, then decoration.
   Fixes the observed level↔cliff churn where they overwrite each other.

## Background

`TerrainModuleDefinitions.gd` is ~1000 lines, ~80% of which is near-identical
factory functions for level/cliff variants. The two rule files
(`LevelEdgeRule.gd`, `CliffEdgeRule.gd`) duplicate ~80% of their logic and each
holds a hard-coded `variant_tag → loader_function` dictionary.

A 4-rotation loop in `_resolve_placement_context` exists from the previous
directional-tags scheme — that scheme was removed, so the loop now produces
identical results on each iteration. The `[socket]` tag prefix mechanism is
similarly unused outside one stale test.

The other Claude instance recently shipped 15 cliff variants but did not add a
stacked tier (cliff-stack analog of level-stack), so cliffs cannot grow upward.

The current generation order is purely distance-sorted. Levels and cliffs
sampled at similar distances overwrite each other because both carry
`replace_existing = true`, producing a visible "tile thrashing" loop.

## Sections / commits

### 1. Dead code removal

- Remove the 4-rotation loop in `TerrainGenerator._resolve_placement_context`.
- Remove `Helper.rotate_adjacency` and its tests.
- Remove `[socket]` prefix machinery from `TerrainModuleLibrary`:
  `combined_tag_socket_name`, `convert_tag_list`, the unused
  `_attachment_socket_name` param on `get_required_tags`, the prefix loop in
  `sort_terrain_modules`. Drop the matching test.
- Remove `tags_per_socket` field and parameter from `TerrainModule` + every
  caller (every factory in `TerrainModuleDefinitions`).
- Delete the obsolete `# Removed ensure_ground_coverage_around_piece` comment.

**Commit boundary.**

### 2. Data-drive level/cliff variant definitions

- Add `LEVEL_VARIANT_TABLE` and `CLIFF_VARIANT_TABLE` to
  `TerrainModuleDefinitions`. Each entry: `[scene_name, variant_tag]`.
- Add bulk loaders `load_level_variants() -> Array[TerrainModule]` and
  `load_cliff_variants() -> Array[TerrainModule]` that iterate the tables and
  produce all variants (both base and stack tiers for level; just base for cliff
  until section 5).
- Add `load_level_variant(scene_name, tier, variant_tag)` and
  `load_cliff_variant(scene_name, tier, variant_tag)` for direct access from
  tests.
- Delete every trivial wrapper factory (`load_level_side_tile`,
  `load_cliff_corner_tile`, etc.). Keep the special-tag ones
  (`load_level_middle_tile`, `load_level_stack_middle_tile`,
  `load_cliff_interior_tile`).
- Update `TerrainModuleLibrary.load_terrain_modules` to call the bulk loaders.
- Update tests that referenced deleted wrappers to use the new helpers.

**Commit boundary.**

### 3. Library-based variant lookup in rules

- Delete the static `module_by_*_tag` dictionaries from `LevelEdgeRule` and
  `CliffEdgeRule`.
- Replace `_get_module_for_level_tag(tag, tier)` body with
  `library.get_by_tags(TagList.new([tier, tag])).library[0]`.
- Replace `_get_module_for_cliff_tag(tag)` similarly.
- Thread `library` through `_create_replacement_for_target` (pull it from
  `context["library"]` which `_build_rule_context` already populates).
- Remove `LevelEdgeRule.module_by_level_tag.clear()` /
  `CliffEdgeRule.module_by_cliff_tag.clear()` from test setUp.

**Commit boundary.**

### 4. Generic player-spawn protection

- The current check in `TerrainGenerator.add_piece` is narrow: it only blocks
  `level-stack` tiles. Generalize to: any non-ground, non-foliage tile whose
  world AABB intersects the player's body footprint and whose top exceeds
  `PLAYER_FEET_Y + PLAYER_MAX_STEP_HEIGHT` is rejected.
- Foliage (point tiles) and ground are always allowed at the player position.
- Uses the same `PLAYER_FEET_Y` / `PLAYER_MAX_STEP_HEIGHT` constants.

**Commit boundary.**

### 5. Cliff-stack parity with level-stack

- Add cliff-stack tier to the `_build_cliff_edge_module` / variant table: a
  parameter `tier ∈ {"cliff-base", "cliff-stack"}` controls the `bottom`
  required-tag (`"ground"` vs `"cliff"`) and the tags carried by the module
  (`["cliff", "cliff-stack", variant, "24x24x4"]`).
- Add `load_cliff_stack_interior_tile` mirroring `load_level_stack_middle_tile`:
  same scene as cliff-interior, tagged for the stack tier, topcenter expansion
  enabled.
- Have `cliff-interior` topcenter seed `cliff-stack-side` (it currently doesn't
  seed anything). Tag distribution mirrors `level-center`'s topcenter.
- Update `CliffEdgeRule` to know about cliff-stack:
  - `_create_replacement_for_target` picks the right tier when looking up the
    replacement module (analog of LevelEdgeRule's `_level_tier_tag` /
    `_cliff_tier_tag` helper).
  - Apply LevelEdgeRule's support check (`_can_support_stacked_piece`,
    `_get_stacked_piece`) for cliff-stack tiles.
- Generator-side `_purge_orphaned_level_stacks` becomes `_purge_orphaned_stacks`
  with a `family_tag` parameter and is called for both `"level"` and `"cliff"`.

**Commit boundary.**

### 6. Tiered placement priority

- Replace queue `priority = distance` with `priority = TIER_OFFSET[tier] +
  distance`.
- Tier mapping (lowest priority value wins in the min-heap):
  - **Cliff (tier 0):** `cliff` tag → offset 0
  - **Level (tier 1):** `level` tag → offset `RENDER_RANGE`
  - **Decoration (tier 2):** anything else (grass, rock, bush, tree, hill,
    ground top-corners/cardinals) → offset `RENDER_RANGE * 2`
- Tier is inferred at enqueue time from the dominant tag in
  `socket_tag_prob[socket_name]`. Helper `_socket_tier(piece, socket_name)`
  returns the tier int. Lives in `TerrainGenerator`.
- Applied at every enqueue site: initial `_ready` seeding,
  `add_piece_to_queue`, `_flush_deferred_sockets`. Rule
  `sockets_for_queue` results keep their priority 0 override (they're
  rule-initiated, not distance-sorted).

**Commit boundary.**

## Out of scope

- Full Level/Cliff rule deduplication into a `FamilyEdgeRule` base class
  (potential follow-up; cliff-stack work in section 5 makes this larger but
  not blocking).
- Test-piece socket caching (Section 5 of the prior plan).
- Typed placement/rule context Resources.

## Risk

- The other Claude instance shipped cliff variants in parallel and may
  continue working. To survive parallel resets, this refactor commits after
  every section. Each commit is independently runnable.
- Section 5 (cliff-stack) is the largest behavior change. If it destabilizes
  the visual output, sections 1–4 still stand on their own and can be kept.
- Section 6 (tier priority) changes generation order. Foliage will appear
  later in the streaming lifecycle; if that's visually undesirable the
  tier offsets can be reduced without reverting.
