# FR-3: Field-driven decoration scatter + delete the socket engine

**Date:** 2026-06-23
**Status:** Design — part 3 of 3 in the field-driven terrain rewrite
(FR-1 unify descriptor + water → FR-2 unify mesh layer → **FR-3 decoration
scatter + delete socket engine**).

## Why

After FR-1 (water folded in, `WaterRule` gone) the socket-expansion engine has
exactly one remaining job: scatter decorations (grass/rock/bush/tree/hills). That
engine — `TerrainGenerator`'s priority queue, `_lateral_neighbours`,
`TerrainDensity`'s curve zoo, the per-socket data, and the eight reconciliation
flags — is the entire source of the special cases the owner wants gone. The flags
exist only to make opportunistic socket-scatter coexist with the deterministic
heightfield ("will a mesa rise here later and bury this decoration?").

Decorations do not need any of it. A decoration is just a point on a cell's
walkable surface. With structure deterministic and known up-front, decoration is a
**pure per-cell scatter from the field** — and the suppression machinery, the
flags, and the whole engine delete.

## Goal

- Replace socket-based decoration with a deterministic per-cell scatter computed
  from the field, placed in the same streaming pass as structure.
- **Delete the socket-expansion engine** and everything that exists only to serve
  it. **Tag the pre-deletion commit** (`git tag wfc-socket-engine-archive <sha>`)
  so the full engine is recoverable from git if a future feature wants WFC-style
  placement (per the owner's decision — rebuild fresh when a real use arises, do
  not carry it coupled).

## The scatter model

For each placed **walkable-surface** cell (a cell whose top is final walkable
ground/level/cliff-plateau — NOT a cell that gets a storey on top, which the
field already knows):
- Derive `K` candidate points from `hash(cell, seed)` — jittered positions within
  the 24×24 cell (blue-noise / poisson-disc-ish jitter to avoid a gridded look;
  this replaces the WFC engine's organic clustering).
- At each candidate, sample a weighted roll — *nothing* / grass / rock / bush /
  tree / hill — using the existing small weight tables (`FOLIAGE_TAG_WEIGHTS`),
  scaled by the biome/foliage density field (`Helper.biome_foliage_density`) at
  that XZ.
- Place the chosen foliage gltf at the candidate XZ, at the surface height the
  descriptor already provides, with deterministic yaw from the hash.

**No suppression hacks needed.** We only scatter on cells the field marks as final
walkable surface, so "a structure will later cover this" cannot happen — the four
suppressors (`socket_suppressed_by`, `cliff_foliage_covered_by_stack`, the
cliff-core deco gate, slope `filter_for_category`) all evaporate. The slope-gating
intent (no protruding decorations on tilted faces) is preserved trivially: we
scatter on the walkable top, and a cell's surface descriptor already says where
that is.

### Hills
Hills are footprint decorations, not point decorations. A hill is placed at a cell
when (a) the field rolls a hill there and (b) the cell's surface descriptor says
the footprint is flat/clear. **Hill-stacking** becomes a single deterministic
field roll (a hill cell may carry a smaller hill on top per `hash(cell, seed)`),
replacing socket-recursion. (Open sub-decision for planning: keep one level of
deterministic stacking, or simplify to no stacking — resolve by what looks best.)

## What gets deleted

- **`scripts/terrain/TerrainGenerator.gd`** socket/queue machinery: `load_terrain`'s
  priority-queue + stale-repair + deferral loops, `_process_socket`,
  `_resolve_placement_context`, `_lateral_neighbours`, `_try_place_with_rules`,
  `add_piece`/`can_place`/`transform_to_socket`, `_enqueue_socket`/`_stage_deferred`/
  `_flush_deferred`/`queued_socket_keys`, `_purge_orphaned_stacks`/`_has_surface_support`/
  `_support_sweep_pieces`, `_ensure_seed_under_player`, the reveal margin
  (`_apply_initial_visibility`/`_reveal_settled_pieces`/`_hidden_*`), the rule
  pipeline remnants, `register_piece`/`remove_piece` socket bookkeeping. What
  remains is a thin **streaming driver**: per frame, `place_region`/evict structure
  + scatter decoration within radius of the player (frame-budgeted; deterministic
  per cell makes budgeting trivial). Consider absorbing it into
  `HeightfieldInstantiator`.
- **`scripts/terrain/TerrainDensity.gd`** — the curve zoo (`route_fill_prob`,
  `_gentle_/_level_/_macro_scaled_fill`, `effective_fill_prob`, `in_cliff_core`,
  `cliff_foliage_covered_by_stack`, `biome_scaled_dist`, `suppressor_roll_passes`,
  `is_structural_socket`). Decoration density uses only `biome_foliage_density`.
- **`scripts/terrain/TerrainModuleSocket.gd`**, `PositionIndex.gd` (if only used by
  sockets), and the socket data on `TerrainModule` (`socket_size`/`socket_required`/
  `socket_fill_prob`/`socket_tag_prob`/`socket_suppressed_by`/`socket_role`/
  `socket_category`/`attachment_socket`) and all of `TerrainSpawnConfig`'s socket
  builder + curve constants + `surface_spawn_sockets` + `filter_for_category`.
- **All eight reconciliation flags** on `TerrainModule` (`is_base_plane`,
  `requires_surface_support`, `structural_socket_names`, `density_profile`,
  `grows_in_cliff_core`, `covered_by_storey_above`, `vertical_stack_family`,
  `socket_role`/`attachment_socket`). `TerrainModule` reduces to (mesh/scene, tags,
  AABB, `displaceable`) — and `displaceable` likely goes too (deterministic
  ordering means no displacement).
- **Test pieces** (`create_*_test_piece`, `test_pieces_library`) and the
  characterization/placement tests whose subject (the socket engine) is removed.
- `TerrainGenerationRule` / `TerrainGenerationRuleLibrary` (empty after FR-1).

## What is kept

- `HeightfieldPlan` (+ FR-1 water), `HeightfieldVariant`, `HeightfieldInstantiator`
  (now also scatters), `HeightfieldFacing`, `HeightfieldRegion`.
- `TerrainIndex` (gameplay/collision queries + eviction).
- Authored foliage gltf art + the small `FOLIAGE_TAG_WEIGHTS`-style tables (kept as
  honest explicit data — not derived).
- The streaming/eviction skeleton (place within radius, evict beyond) — this is
  infrastructure, not a special case.

## Risks

- **Decoration aesthetics.** WFC scatter produced organic clustering; a naive
  per-cell sample can look gridded. Mitigate with jittered/blue-noise candidate
  points and density from the continuous field. Tune visually.
- **Frame budgeting.** The queue spread placements across frames; the scatter must
  too. Deterministic per-cell scatter makes this a simple "N cells/frame" cap with
  no repair/defer bookkeeping.
- **Player overlap.** The queue had a player-blocked retry/cooldown. Replace with:
  skip scattering decorations inside the player's footprint this frame; retry when
  clear (decorations are cosmetic, so a one-frame skip is invisible). Far simpler
  than the cooldown machinery.
- **Determinism + streaming consistency.** A cell's decorations must be identical
  whether first seen near or far, and on re-entry after eviction. Pure
  `hash(cell, seed)` derivation guarantees this (the heightfield already relies on
  the same property).

## Testing / verification

- New `tests/test_decoration_scatter.gd`: for a given cell+seed, the scatter is
  deterministic; density tracks the biome field (dense vs sparse positions);
  decorations land on the cell's walkable surface height; none scatter on
  covered/interior cells; none on a slope's tilted band.
- Remove the now-obsolete socket/placement characterization tests
  (`test_placement_pipeline_characterization`, `test_route_fill_prob_pinning`,
  `test_terrain_decoration_characterization`, `test_socket_category`,
  `test_spawn_config`, `test_slope_spawn_gating`) whose subjects are deleted; keep
  any assertion still meaningful by porting it to the scatter test.
- Full GUT suite green; `TerrainGenerator.gd` line count drops dramatically.
- **Visual (primary):** run the game; decoration density, variety, and placement
  on flat tops (and absence on slopes/interiors) look as good or better than the
  socket engine. Screenshot before/after.

## Dependencies

Depends on FR-1 (so `WaterRule`/the rule pipeline is already gone and the engine
has no remaining consumer). Independent of FR-2 (mesh generation), which can run
before or after. This is the sub-project that removes the eight flags and the
special-case bridge — the owner's core goal.
