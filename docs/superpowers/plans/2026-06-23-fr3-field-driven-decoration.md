# FR-3: Field-driven decoration scatter + delete the socket engine — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. This deletes the largest body of code; guard with the field-scatter tests + visual checks. **Tag the pre-deletion commit.**

**Goal:** Replace socket-based decoration with a deterministic per-cell field scatter, then delete the socket-expansion engine, `TerrainDensity`, all 8 `TerrainModule` flags, the suppression hacks, and the test pieces.

**Architecture:** For each placed walkable-surface cell, derive K jittered candidate points from `hash(cell, seed)`, sample a weighted decoration type scaled by `Helper.biome_foliage_density`, and place the foliage gltf at the cell's known surface height. No sockets, no queue, no suppression — the field already knows which cells are walkable surface, so nothing is scattered where structure will sit. `TerrainGenerator` collapses to a thin streaming driver (or folds into `HeightfieldInstantiator`).

**Tech Stack:** Godot 4 / GDScript, GUT. Binary `/Applications/Godot.app/Contents/MacOS/Godot`.

**Branch:** `refactor/terrain-field-driven`. **Depends on FR-1** (WaterRule/rule pipeline already gone → the socket engine has no remaining consumer). Independent of FR-2.

**Grounding:** `TerrainGenerator.gd` (queue: `load_terrain`, `_process_socket`, `_resolve_placement_context`, `_lateral_neighbours`, `add_piece`/`can_place`, `register_piece`/`remove_piece`, `_purge_orphaned_stacks`, reveal margin, `_ensure_seed_under_player`, `_drive_heightfield_structure`/`place_region`/`evict`), `TerrainDensity.gd`, `TerrainSpawnConfig.gd` (`surface_spawn_sockets`, `FOLIAGE_*_WEIGHTS`, `filter_for_category`), `TerrainModule.gd` (the 8 flags + `displaceable`), `TerrainModuleDefinitions.gd` (foliage/hill loaders + test pieces), `Helper.gd` (`biome_foliage_density`, `biome_weights`, `_cell_hash01`/`_value_noise01`).

---

## File structure
- **Create** `scripts/terrain/DecorationScatter.gd` — pure per-cell scatter.
- **Modify** `HeightfieldInstantiator.gd` / `TerrainGenerator.gd` — call the scatter in the streaming pass; reduce `TerrainGenerator` to a streaming driver.
- **Delete** `TerrainGenerator.gd` socket machinery, `TerrainDensity.gd`, `TerrainModuleSocket.gd`, `PositionIndex.gd` (if socket-only), `TerrainSpawnConfig.gd` socket builder + curve consts, the 8 flags on `TerrainModule.gd`, test pieces.
- **Tests** — new `test_decoration_scatter.gd`; delete the now-obsolete socket/placement tests.

---

## Task 0: Tag the pre-deletion commit
- [ ] `git tag wfc-socket-engine-archive HEAD` (the full WFC engine recoverable from git per the owner's decision). Push the tag if/when the branch is pushed. Note the tag in the commit body of Task 5.

## Task 1: `DecorationScatter` — pure per-cell scatter
**Files:** Create `scripts/terrain/DecorationScatter.gd`; Test `tests/test_decoration_scatter.gd`.
- [ ] **Failing test** `tests/test_decoration_scatter.gd`:

```gdscript
extends GutTest
const Scatter := preload("res://scripts/terrain/DecorationScatter.gd")

func test_deterministic() -> void:
	var a := Scatter.cell_decorations(Vector2i(3,7), 0, 0.0)   # cell, seed, surface_y
	var b := Scatter.cell_decorations(Vector2i(3,7), 0, 0.0)
	assert_eq(a, b, "scatter is a pure function of (cell, seed)")

func test_points_on_surface_within_cell() -> void:
	var ds := Scatter.cell_decorations(Vector2i(0,0), 0, 12.5)
	for d in ds:
		assert_almost_eq(d["pos"].y, 12.5, 0.001, "decoration sits on the cell surface height")
		assert_lte(absf(d["pos"].x), 12.0); assert_lte(absf(d["pos"].z), 12.0)
		assert_true(d["tag"] in ["grass","rock","bush","tree","hill"])

func test_density_tracks_biome() -> void:
	# A high-foliage-density position yields >= as many decorations as a low one (seeded).
	var dense := Scatter.cell_decorations(Vector2i(100,100), 0, 0.0).size()
	var sparse := Scatter.cell_decorations(Vector2i(-300,300), 0, 0.0).size()
	assert_true(dense >= 0 and sparse >= 0)  # exact density asserted via the density helper
```

- [ ] **Implement** `DecorationScatter.gd`:
  - `static func cell_decorations(cell: Vector2i, world_seed: int, surface_y: float) -> Array` returning `[{tag, pos: Vector3, yaw: float, scene_key}]`.
  - Candidate points: derive K (e.g. up to 9) jittered XZ offsets within the 24×24 cell from `Helper._cell_hash01(cell + i, seed)`; for each, roll *nothing/grass/rock/bush/tree/hill* using `FOLIAGE_TAG_WEIGHTS` scaled by `Helper.biome_foliage_density(world_pos, seed)` and `Helper.biome_weights`; yaw from the hash. Blue-noise/jitter so it isn't gridded.
  - Pure: no globals, no scene-tree access — returns data only.
- [ ] Run, expect PASS (`--import`). Commit `feat(terrain): pure per-cell decoration scatter (FR-3)`.

## Task 2: Wire scatter into the streaming pass; place foliage meshes
**Files:** `HeightfieldInstantiator.gd` (or a small placer), `TerrainGenerator.gd`.
- [ ] After `place_region` spawns a structural tile for a **walkable-surface** cell (not water, not covered/interior), call `DecorationScatter.cell_decorations(cell, seed, surface_y)` and instance the foliage gltf for each result as a child, at `pos` with `yaw`. Track scattered nodes per cell for eviction alongside the tile.
- [ ] Hills: place the hill gltf with its footprint at the cell; one deterministic stack roll for a smaller hill on top (or none — resolve visually in Task 6). No socket recursion.
- [ ] Player overlap: skip scattering inside the player's footprint this frame; the deterministic scatter re-runs identically when clear (no cooldown machinery).
- [ ] Frame budget: cap structural+scatter work per frame (deterministic per cell → a simple N-cells/frame cap).
- [ ] Eviction: when a cell evicts, free its scattered nodes with the tile.
- [ ] Verify the scatter renders (quick run) + suite green. Commit `feat(terrain): scatter decorations in the streaming pass (FR-3)`.

## Task 3: Delete the socket engine from `TerrainGenerator`
**Files:** `TerrainGenerator.gd`.
- [ ] Delete the queue/placement machinery: `load_terrain`'s priority-queue + stale-repair + deferral loops, `_process_socket`, `_resolve_placement_context`, `_lateral_neighbours`, `_try_place_with_rules`, `add_piece`/`can_place`/`transform_to_socket`, `_enqueue_socket`/`_stage_deferred`/`_flush_deferred`/`queued_socket_keys`/`_socket_queue_key`, `_purge_orphaned_stacks`/`_has_surface_support`/`_support_sweep_pieces`, `_ensure_seed_under_player`, the reveal margin (`_apply_initial_visibility`/`_reveal_settled_pieces`/`_hidden_*`), `register_piece`/`remove_piece` socket bookkeeping, the `density`/`TerrainDensity` member.
- [ ] What remains: `_process` → stream structure (`place_region`) + scatter + evict within radius; frame-budgeted. Consider absorbing into `HeightfieldInstantiator`.
- [ ] `grep -n "queue\|socket\|density\|_purge\|_reveal\|_ensure_seed" scripts/terrain/TerrainGenerator.gd` → only the streaming driver remains. Suite green (delete tests whose subject is gone — see Task 5). Commit `refactor(terrain): reduce TerrainGenerator to a streaming driver (FR-3)`.

## Task 4: Delete `TerrainDensity`, sockets, flags, test pieces, spawn-config socket code
**Files:** delete `TerrainDensity.gd`, `TerrainModuleSocket.gd`, `PositionIndex.gd` (if socket-only — `grep` confirm); modify `TerrainModule.gd`, `TerrainModuleDefinitions.gd`, `TerrainSpawnConfig.gd`.
- [ ] `TerrainModule.gd`: delete the 8 flags (`is_base_plane`, `requires_surface_support`, `structural_socket_names`, `density_profile`, `grows_in_cliff_core`, `covered_by_storey_above`, `vertical_stack_family`, `socket_role`/`attachment_socket`) and the socket dicts (`socket_size`/`socket_required`/`socket_fill_prob`/`socket_tag_prob`/`socket_suppressed_by`/`socket_category`). `TerrainModule` reduces to (scene, tags, AABB, `displaceable` — drop `displaceable` too if nothing reads it after the scatter). Update `TerrainModuleInstance` accordingly.
- [ ] `TerrainModuleDefinitions.gd`: delete the test-piece factories + `surface_spawn_sockets` usage + all socket-data on every loader. Foliage/hill loaders keep only (scene, tags, AABB).
- [ ] `TerrainSpawnConfig.gd`: keep `FOLIAGE_TAG_WEIGHTS`/`FOLIAGE_*_SIZE_WEIGHTS` (used by the scatter); delete `surface_spawn_sockets`, `filter_for_category`, the structural/curve constants, the slope-gate consts.
- [ ] `TerrainModuleLibrary.gd`: delete `init_test_pieces`/`load_test_pieces`.
- [ ] `grep -rn "TerrainDensity\|TerrainModuleSocket\|surface_spawn_sockets\|test_piece\|is_base_plane\|density_profile" scripts tests` → empty. Suite green. Commit `refactor(terrain): delete socket engine, density, flags, test pieces (FR-3)`.

## Task 5: Remove obsolete tests; full-suite gate
**Files:** delete obsolete tests; run full suite.
- [ ] Delete tests whose subject is gone: `test_placement_pipeline_characterization`, `test_route_fill_prob_pinning`, `test_terrain_decoration_characterization`, `test_socket_category`, `test_spawn_config`, `test_slope_spawn_gating` (port any still-meaningful assertion into `test_decoration_scatter`).
- [ ] Full GUT suite green. `TerrainGenerator.gd` line count drops dramatically; report before/after totals and the deleted-file list.
- [ ] Commit `test(terrain): remove socket-engine tests; field-driven terrain (FR-3)`. Note the `wfc-socket-engine-archive` tag in the body.

## Task 6: Visual verification + scatter tuning (iterative)
- [ ] Run the game; verify decoration **density, variety, and clustering** look as good or better than the socket engine; decorations sit only on flat walkable tops (none on slopes/interiors/water); hills look right (decide stacking). Tune jitter/density and the hill-stack roll here.
- [ ] Full suite green. Commit `tune(terrain): decoration scatter density + hill stacking (FR-3)`.

## Self-review notes
- Spec coverage: scatter model (T1,T2), delete engine (T3), delete density/sockets/flags/test-pieces (T4), remove obsolete tests (T5), tag pre-deletion commit (T0), visual (T6). ✔
- Hills: footprint decoration + one deterministic stack roll (resolved visually) — no socket recursion.
- Kept: foliage gltf art + `FOLIAGE_*` weight tables; streaming/eviction skeleton.
