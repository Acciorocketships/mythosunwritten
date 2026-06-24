# SP-3: Decompose + simplify — Implementation Plan

> Implement task-by-task. Behavior-preserving. Baseline: full suite **203/203 with
> Cliff scenes restored** (the controller restores them for SP-3 work and re-deletes
> at the end). Stage only named files; never `*.uid`.

**Branch:** `refactor/terrain-simplification`. Godot: `/Applications/Godot.app/Contents/MacOS/Godot`.
One test: `… -s addons/gut/gut_cmdln.gd -gtest=res://tests/<f>.gd -gexit`; full suite `-gconfig=res://tests/gutconfig.json`. `--import` after new `class_name`/test files.

---

## Task 1 — Extract `TerrainDensity` (LOW risk)

Move the density/fill-probability cluster out of `TerrainGenerator.gd` into a new pure class. It writes no instance state (only reads `world_seed` + the passed piece), and is locked by the pinning + characterization tests.

**Files:** create `scripts/terrain/TerrainDensity.gd`; modify `TerrainGenerator.gd`, `tests/test_route_fill_prob_pinning.gd`, `tests/test_terrain_decoration_characterization.gd`.

- [ ] **Step 1 — Create `TerrainDensity.gd`.** `class_name TerrainDensity extends RefCounted`. `func _init(world_seed: int): _world_seed = world_seed`. Move these methods verbatim from `TerrainGenerator` (rename the references to `world_seed` → `_world_seed`; keep method names without the leading underscore for the public ones, OR keep underscores — pick one and be consistent; recommend dropping leading `_` for the public surface): `_effective_fill_prob`→`effective_fill_prob`, `_route_fill_prob`→`route_fill_prob`, `_is_structural_socket`→`is_structural_socket`, `_in_cliff_core`→`in_cliff_core`, `_socket_can_spawn_point`→`socket_can_spawn_point`, `_cliff_foliage_covered_by_stack`→`cliff_foliage_covered_by_stack`, `_biome_scaled_dist`→`biome_scaled_dist`, `_suppressor_roll_passes`→`suppressor_roll_passes`, `_is_socket_blocking`→`is_socket_blocking`, `_get_socket_fill_prob`→`get_socket_fill_prob`, `_is_socket_expandable`→`is_socket_expandable`. Keep as private helpers: `_gentle_scaled_fill`, `_level_scaled_fill`, `_macro_scaled_fill`, `_cliff_storey_threshold`. These methods reference `TerrainSpawnConfig`, `Helper`, `TerrainModuleInstance`, `Distribution` — all global classes, fine. Read each method to catch any stray `self.` state reference (there should be none except `world_seed`); if one touches other instance state, STOP and report (the move isn't clean).
- [ ] **Step 2 — Wire it into `TerrainGenerator`.** Add `var density: TerrainDensity`. Build it wherever `world_seed` is finalized: in `_ready()` after `world_seed` is set, and in `init_for_test()`. Replace every internal call `_route_fill_prob(...)`→`density.route_fill_prob(...)`, `_effective_fill_prob(...)`→`density.effective_fill_prob(...)`, `_is_structural_socket(...)`→`density.is_structural_socket(...)`, `_in_cliff_core(...)`→`density.in_cliff_core(...)`, `_is_socket_expandable(...)`→`density.is_socket_expandable(...)`, `_is_socket_blocking(...)`→`density.is_socket_blocking(...)`, `_get_socket_fill_prob(...)`→`density.get_socket_fill_prob(...)`, `_biome_scaled_dist(...)`→`density.biome_scaled_dist(...)`, `_socket_can_spawn_point(...)`→`density.socket_can_spawn_point(...)`, `_suppressor_roll_passes(...)`→`density.suppressor_roll_passes(...)`, `_cliff_foliage_covered_by_stack(...)`→`density.cliff_foliage_covered_by_stack(...)`. Delete the moved methods from `TerrainGenerator`. `grep -n` for each moved name afterward to confirm no stale calls remain.
- [ ] **Step 3 — Retarget the tests.** Both `test_route_fill_prob_pinning.gd` and the density-touching tests in `test_terrain_decoration_characterization.gd` call `gen._route_fill_prob(...)`, `gen._effective_fill_prob(...)`, `gen._in_cliff_core(...)`, `gen._is_structural_socket(...)`. Change them to construct a `TerrainDensity` directly: `var density := TerrainDensity.new(0)` (seed 0, matching the prior `gen.world_seed` of 0) and call `density.route_fill_prob(...)` etc. The pinned numeric expecteds MUST stay identical (they prove the move is behavior-preserving). `--import` (new class).
- [ ] **Step 4 — Verify.** `test_route_fill_prob_pinning.gd` (same pinned values), `test_terrain_decoration_characterization.gd`, `test_biomes.gd`, `test_heightfield_cutover.gd`. All green. Then full suite — expect 203/203.
- [ ] **Step 5 — Commit.** `git add scripts/terrain/TerrainDensity.gd scripts/terrain/TerrainGenerator.gd tests/test_route_fill_prob_pinning.gd tests/test_terrain_decoration_characterization.gd` → `refactor(terrain): extract TerrainDensity from the generator (SP-3)`.

---

## Task 2 — Remove `HeightfieldInstantiator._lookup_tag` alias (LOW risk)

**Files:** `scripts/terrain/heightfield/HeightfieldInstantiator.gd`, possibly `heightfield/HeightfieldVariant.gd`.

- [ ] **Step 1 — Read `_lookup_tag`** (maps `"ground"`→`"ground-plain"`) and its two call sites, and find where the descriptor's bare `"ground"` variant_tag originates (`HeightfieldVariant.cell_descriptor` or similar). 
- [ ] **Step 2 — Emit `ground-plain` at the source.** Make the descriptor emit `"ground-plain"` directly for the ground family (the cleanest single-point fix), and inline the two `_lookup_tag(...)` call sites to use the variant_tag directly. Delete `_lookup_tag`. Keep the `test_place_region_reports_dropped_cells_for_unknown_tag` early-return / dropped-count structure intact (only the alias is removed). Confirm no other producer emits bare `"ground"` as a library sampling tag (`grep`).
- [ ] **Step 3 — Verify.** `test_heightfield_coverage.gd`, `test_heightfield_cutover.gd`, `test_heightfield_instantiator.gd`, `test_heightfield_variant.gd`, and `test_place_region_reports_dropped_cells_for_unknown_tag` (in whichever file). All green.
- [ ] **Step 4 — Commit.** `refactor(terrain): emit ground-plain directly, drop _lookup_tag alias (SP-3)`.

---

## Task 3 — Placement-pipeline characterization tests (NO production change; prereq for T4)

**Files:** create `tests/test_placement_pipeline_characterization.gd`.

Build a bare generator with injected subsystems (study `test_terrain_decoration_characterization.gd` + `test_heightfield_cutover.gd` for the harness; inject `terrain_index`, `socket_index`, `queue`, `terrain_parent`, `player`, `library`, `density` as needed; use `world_seed = 0`). Use the full library where scenes are needed (scenes are restored).

- [ ] **Step 1 — Write the tests** (each its own `test_*`, deterministic, pin *sets* not single stochastic samples):
  1. **`can_place` matrix:** base-plane piece → always true; a piece with `replace_existing` → true; a structure over a displaceable → true (displaceable yields); a structure over a non-displaceable structure (no replace) → false; `vertical_stack_family` same-family overlapping piece strictly below new_y → filtered (the 951–959 rule).
  2. **`add_piece`:** with a `player` standing in the footprint, placing a non-base piece returns false and sets `_blocked_by_player`; placing a base-plane piece is exempt; a `replace_existing` piece removes the overlapping non-base piece it lands on.
  3. **Decoration end-to-end:** for a ground tile's `topfront` socket at a low-density position, drive the decoration placement path; assert the chosen module carries a tag in `FOLIAGE_TAG_WEIGHTS` and a size in the foliage size weights, and is attached at the socket. Pin the reachable-module *set* (deterministic at seed 0).
  4. **Lateral ground expansion:** a ground tile's `front` socket expands to a `ground-plain` neighbour; with a water-blocking neighbour socket present (`topcenter` fill 0), the forbidden-adjacency guard rejects the expansion. (This is the lock for T4's `_lateral_neighbours`.)
- [ ] **Step 2 — Run** against current code; all must pass (they pin today's behavior). If a behavior is too stochastic to pin as a single value, pin the *set* / a deterministic predicate and comment it.
- [ ] **Step 3 — Commit.** `test(terrain): characterize placement pipeline before test-piece removal (SP-3)`.

---

## Task 4 — Delete test-piece WFC machinery + direct decoration placement (HIGH risk; gated by Task 3 green)

**Files:** `TerrainGenerator.gd`, `TerrainModuleDefinitions.gd`, `TerrainModuleLibrary.gd`, `tests/test_socket_category.gd`.

- [ ] **Step 1 — Cut the vestigial fixture.** In `tests/test_socket_category.gd`, replace the `TerrainModuleInstance.new(TerrainModuleDefinitions.create_24x24_test_piece())` construction with a minimal real/def-only module (it builds its own `Marker3D`s, so any module def works — use `TerrainModuleDefinitions.load_ground_tile()`); confirm the test still passes. This must precede deleting the factory.
- [ ] **Step 2 — Add `_lateral_neighbours(piece_socket)`.** A method that, for a lateral/structural expansion socket, probes the **real** piece's facing socket positions via `socket_index.query_other`/`query_others` (the same neighbour cells the old 24x24 test plate reached) and returns the adjacency dict the rest of `_resolve_placement_context` expects. Read the old `get_adjacent_from_size` to replicate exactly which neighbour positions it probed for the `24x24x0.5` and cliff/level lateral sizes, and the `{attachment: orig}` shape.
- [ ] **Step 3 — Rewrite `_process_socket` / `_resolve_placement_context` into two explicit paths.** Decoration path (size is `point` or a hill size, i.e. `density.socket_can_spawn_point` / size category): sample the tag from the origin socket's biome-scaled `socket_tag_prob`, `library.get_by_tags([size, tag])`, `sample_from_modules`, spawn, `add_piece` — no `get_adjacent_from_size`, no `get_required_tags`/`get_combined_distribution`. Lateral/structural path: use `_lateral_neighbours` → existing `_has_forbidden_adjacency` + `get_required_tags` + `get_combined_distribution`. Keep the placement/`add_piece`/rules tail shared. Preserve the exact tag/size sampling for decorations (the chosen-module distribution must match what T3 pinned).
- [ ] **Step 4 — Delete the machinery.** Remove `get_adjacent_from_size`, the `test_pieces_library` member + its construction in `_ready`/`init_for_test`, `TerrainModuleLibrary.init_test_pieces`/`load_test_pieces`, and `create_8x8_test_piece`/`create_12x12_test_piece`/`create_4x4x4_test_piece`/`create_24x24_test_piece` in `TerrainModuleDefinitions`. `grep` each name to confirm zero remaining references (production + tests).
- [ ] **Step 5 — Verify.** The Task-3 suite (decoration placement + lateral over-water rejection MUST stay green — they are the behavior lock), `test_terrain_decoration_characterization.gd`, `test_water_rule.gd`, `test_terrain_module_library.gd`, `test_socket_category.gd`, then full suite. Expect the same pass count minus any test that only existed to exercise the deleted machinery (there should be none beyond the fixture migration in Step 1).
- [ ] **Step 6 — Commit.** `refactor(terrain): delete test-piece WFC; decorations place directly (SP-3)`.

---

## Task 5 — Full-suite gate + audit

- [ ] **Step 1 — Full suite** (scenes restored), expect 203/203 (± the pinning/characterization additions). Any new failure is a regression.
- [ ] **Step 2 — Readability audit.** Confirm `TerrainGenerator.gd` line count dropped meaningfully (density extraction + test-piece deletion ≈ −370 lines) and `grep` shows no remaining `tags.has("<family>")` or hardcoded socket-name special-cases (carried from SP-2). 
- [ ] **Step 3 — Controller restores the user's working state** (re-deletes the 14 Cliff scenes).

## Out of scope (per spec)
- `DecorationSpawner` / heightfield-driver / orphan-purge classes (would be thin wrappers).
- WaterRule socket-name-list merge (adds call-site filtering).
- `RevealBuffer` (optional; skip unless clearly not a wrapper).
