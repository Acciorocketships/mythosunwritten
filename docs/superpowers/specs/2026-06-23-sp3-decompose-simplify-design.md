# SP-3: Decompose the god-object + simplify placement

**Date:** 2026-06-23
**Status:** Design — part 3 (final) of the terrain simplification.

## Goal

Make `TerrainGenerator.gd` (1,444 lines) simpler and more readable by (1)
extracting the one genuinely-cohesive cluster, (2) deleting the test-piece WFC
machinery that decorations don't need, and (3) small deferred cleanups. User
guidance honored: **avoid thin wrappers** — extract only where a unit has a clean
interface and reduced coupling; otherwise leave it. Behavior preserved (full
suite 203/203 with scenes present; the `_route_fill_prob` pinning test).

## Key findings (from the coupling/evidence trace)

- The per-frame **scheduler**, the **placement pipeline**, **seed-under-player**,
  and the **queue bookkeeping** form one irreducible knot of shared mutable state
  (`queue`/`queued_socket_keys`/`terrain_index`/`socket_index` mutated from a
  dozen sites). Splitting them produces thin wrappers → **not extracted**.
- The **density / fill-probability** cluster (`_route_fill_prob`, the `_*_scaled_fill`
  curves, `_in_cliff_core`, `_cliff_*`, `_biome_scaled_dist`, `_effective_fill_prob`,
  `_is_structural_socket`, `_socket_can_spawn_point`, `_suppressor_roll_passes`,
  `_is_socket_blocking`, fill-prob getters) is **near-pure functions of
  (piece, socket, pos) + world_seed**, writes no instance state, and is locked by
  the pinning + characterization tests → **clean extraction**.
- **Decorations do NOT need WFC adjacency.** For `point` foliage, `get_adjacent_from_size`
  already short-circuits to the origin socket; the tag/size come entirely from the
  *origin* surface socket's `socket_tag_prob` (`FOLIAGE_TAG_WEIGHTS`). Hills carry no
  lateral `socket_required`/`socket_tag_prob`, so neighbours don't influence the
  choice either. The test-piece probe contributes only a redundant
  forbidden-adjacency pre-check that `can_place` already enforces. → decorations
  get **direct placement**; the test-piece machinery is **deleted**.
- **Lateral base-plane expansion** (ground/water/bank `24x24x0.5`) uses the probe
  only for the over-water forbidden-adjacency guard — expressible by probing the
  *real* piece's own facing sockets (no dummy-scene spawn).

## Accepted changes

### 1. Extract `TerrainDensity` (new file)
`scripts/terrain/TerrainDensity.gd` (`class_name TerrainDensity extends RefCounted`).
- Constructor: `TerrainDensity.new(world_seed: int)` — stores `_world_seed`, the only borrowed state.
- Moves the entire density cluster verbatim (public methods: `effective_fill_prob`, `route_fill_prob`, `is_structural_socket`, `in_cliff_core`, `socket_can_spawn_point`, `cliff_foliage_covered_by_stack`, `biome_scaled_dist`, `suppressor_roll_passes`, `is_socket_blocking`, `get_socket_fill_prob`, `is_socket_expandable`; privates `_gentle/_level/_macro_scaled_fill`, `_cliff_storey_threshold`).
- `TerrainGenerator` holds `var density: TerrainDensity` (built in `_ready` after `world_seed`, and in `init_for_test`), and calls `density.<m>(...)`.
- Not a thin wrapper: ~220 lines of cohesive domain logic behind a small interface; removes ~17 methods from the god-object.
- **Tests:** retarget `test_route_fill_prob_pinning.gd` and the density assertions in `test_terrain_decoration_characterization.gd` to construct `TerrainDensity.new(seed)` directly (cleanest) or call `gen.density.*`. Pinned constants are SACRED → byte-identical output proves equivalence.

### 2. Delete the test-piece WFC machinery + direct decoration placement
- Replace `get_adjacent_from_size` with `_lateral_neighbours(piece_socket)` probing the **real** piece's facing sockets (no dummy spawn); decorations bypass it.
- Rewrite `_process_socket` / `_resolve_placement_context` into two explicit paths: **decoration** (sample tag from origin socket → `get_by_tags([size,tag])` → sample → spawn → `add_piece`, no adjacency) and **lateral/structural** (real-socket neighbour probe → existing `_has_forbidden_adjacency` + required/combined dist).
- Delete `test_pieces_library`, `init_test_pieces`/`load_test_pieces`, and `create_8x8/12x12/4x4x4/24x24_test_piece` (~150 lines). The suppressed topcenter test-piece data (SP-1 Item B) dies here cleanly.
- **Prerequisite:** the placement pipeline is UNTESTED → add characterization tests FIRST (Task 3) pinning `can_place`, `add_piece`, decoration placement, and lateral over-water rejection.

### 3. Small cleanups
- Remove `HeightfieldInstantiator._lookup_tag` (`"ground"→"ground-plain"`): make the heightfield descriptor emit `"ground-plain"` directly, inline the two call sites. Keep the `test_place_region_reports_dropped_cells_for_unknown_tag` early-return structure. Guard: `test_heightfield_*`.

## Rejected (kept in place — would be thin wrappers / false seams)

- `DecorationSpawner` — the decoration tail still mutates index/queue/parent; a class would shuffle borrowed mutable state across a boundary. The straight-line win is achieved in place.
- Heightfield-driver class — `_drive_heightfield_structure` is 19 lines already delegating to the tested `HeightfieldInstantiator`; a class adds coupling surface.
- Orphan-purge class — mutates terrain via `remove_piece`/recheck callbacks (the placement knot).
- WaterRule `CARDINAL_SOCKETS`/`DIAGONAL_SOCKETS` merge — would add call-site filtering, not remove code.
- `RevealBuffer` — borderline; optional stretch only if it isn't a wrapper on the hot `register_piece` path. Default: skip.

## Tasks (least-risky first; baseline 203/203 with scenes)

- **T1 — Extract `TerrainDensity`** (low risk): move cluster, retarget pins. Guard: pinning + characterization (byte-identical).
- **T2 — `_lookup_tag` cleanup** (low risk): heightfield emits `ground-plain`. Guard: `test_heightfield_*`.
- **T3 — Placement-pipeline characterization tests** (no prod change; prereq for T4): new `tests/test_placement_pipeline_characterization.gd` pinning `can_place` (base-plane/replace/displaceable/vertical-stack), `add_piece` (player-reject, replace-eat), decoration end-to-end (sampled tag ∈ FOLIAGE_TAG_WEIGHTS, attached), lateral ground expansion + over-water rejection. Fixed seed, pin module *sets*.
- **T4 — Test-piece deletion + direct decoration placement** (HIGH risk, gated by T3): migrate `test_socket_category.gd` off `create_24x24_test_piece`, add `_lateral_neighbours`, rewrite the two paths, delete test-piece machinery. Guard: T3 suite + characterization + `test_water_rule` + full 203.

## Risks

- Placement pipeline untested → T3 is a hard prerequisite for T4.
- `_lateral_neighbours` must probe the same neighbour cells the old 24x24 test plate did for lateral sizes (over-water guard is the lock).
- New tests must use fixed `world_seed=0` and pin module *sets*, not single stochastic samples.
- `test_socket_category.gd`'s vestigial `create_24x24_test_piece()` call must be cut before the factory is deleted.
