# SP-2: Metadata-ize the live special-cases — Implementation Plan

> Implement task-by-task. Each task: add metadata field(s) defaulted to today's
> behavior, set them on the differing modules, rewrite the core reader, run guards,
> commit. **Behavior must not change.**

**Branch:** `refactor/terrain-simplification`.

**Conventions:**
- Godot `/Applications/Godot.app/Contents/MacOS/Godot`; one test: `… -s addons/gut/gut_cmdln.gd -gtest=res://tests/<f>.gd -gexit`; full suite `-gconfig=res://tests/gutconfig.json`. `--import` after new test files.
- The Cliff scenes are RESTORED for SP-2 work (the controller did this); do NOT re-delete them. Stage only named files; never `*.uid`.
- New fields on `TerrainModule` are set **post-construction** (e.g. `m.is_base_plane = true`), NOT via the constructor. Defaults reproduce today's behavior.

**Primary guard (run after every task):**
`/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_terrain_decoration_characterization.gd -gexit`
Tests 1–4 lock: foliage live, hill-stack live, `_has_surface_support`, cliff-core suppression.

**Audit invariant (carry through all tasks):**
- `is_base_plane = true` on EXACTLY ground-plain, water, bank (the modules carrying the bare `"ground"` tag today).
- `structural_socket_names = ["front","back","left","right","topcenter"]` on EXACTLY ground-plain, every level variant/center, every cliff edge variant, cliff interiors. **NOT** on water/bank (they are non-structural today).

---

## Task 1: `structural_socket_names` → rewrite `_is_structural_socket`

**Files:** `TerrainModule.gd`, `TerrainModuleDefinitions.gd`, `TerrainGenerator.gd`.

- [ ] **Step 1 — Add the field.** In `TerrainModule.gd`, add `@export var structural_socket_names: Array[String] = []` (placed with the other socket-policy fields). Do NOT touch the constructor.
- [ ] **Step 2 — Set it on the structural modules** (post-construction, named assignment):
  - `load_ground_tile`, `_build_level_tile` (covers level variants + both centers), `_build_cliff_tile` (cliff edges), `_build_cliff_interior_module` (cliff interiors): `m.structural_socket_names = ["front", "back", "left", "right", "topcenter"]`.
  - Leave water (`load_water_tile`), bank (`load_bank_variant`), hills, foliage, test pieces at default `[]`.
  Read each builder; identify the constructed `TerrainModule` (it may be `return TerrainModule.new(...)` — change to assign to a local `var m`, set the field, `return m`).
- [ ] **Step 3 — Rewrite the reader.** In `TerrainGenerator._is_structural_socket`, replace the whole body with `return socket_name in piece.def.structural_socket_names`.
- [ ] **Step 4 — Verify.** `test_terrain_decoration_characterization` + `test_heightfield_cutover` + `test_heightfield_coverage`. The cutover test `test_is_structural_socket_classifies_seeds_vs_decoration` asserts exact true/false for ground/cliff/water sockets — it must stay green (it is the authoritative behavior lock for this task).
- [ ] **Step 5 — Commit.** `git add` the three files; `git commit -m "refactor(terrain): structural sockets via metadata, not tags (SP-2)"`.

---

## Task 2: `is_base_plane` + `requires_surface_support`

**Files:** `TerrainModule.gd`, `TerrainModuleDefinitions.gd`, `TerrainGenerator.gd`.

- [ ] **Step 1 — Add fields.** `@export var is_base_plane: bool = false` and `@export var requires_surface_support: bool = false`.
- [ ] **Step 2 — Set them.** `is_base_plane = true` on ground-plain (`load_ground_tile`), water (`load_water_tile`), every bank (`load_bank_variant`). `requires_surface_support = true` on the three hill loaders (`load_8x8x2_tile`, `load_12x12x2_tile`, `load_4x4x4_tile`).
- [ ] **Step 3 — Rewrite readers** in `TerrainGenerator.gd`:
  - `can_place`: the `tags.has("ground")` unconditional-pass `(A)` → `if new_piece.def.is_base_plane: return true`; the blocker-filter `(B)` `not p.def.tags.has("ground")` → `not p.def.is_base_plane`.
  - `add_piece`: the player-footprint reject `not new_piece.def.tags.has("ground")` → `not new_piece.def.is_base_plane`; the replace_existing overlap filter `not p.def.tags.has("ground")` → `not p.def.is_base_plane`.
  - `_drive_heightfield_structure`: the WaterRule-run gate `inst.def.tags.has("ground")` → `inst.def.is_base_plane`.
  - `_purge_orphaned_stacks` sweep: `tags.has("hill") or …displaceable` → `swept_piece.def.requires_surface_support or swept_piece.def.displaceable`.
  Read each site first; `grep -n 'tags.has("ground")\|tags.has("hill")' scripts/terrain/TerrainGenerator.gd` to find them all. Replace ONLY the listed sites (do not touch any `tags.has("ground")` that is genuinely about the literal ground tag in a content-coupled spot if one exists — but per the design these five are the live core sites; if grep shows others, report them).
- [ ] **Step 4 — Verify.** characterization (Test 3 orphan predicate) + `test_water_rule` + `test_seed_under_player` + `test_heightfield_cutover` + `test_heightfield_coverage`.
- [ ] **Step 5 — Commit.** `refactor(terrain): base-plane + surface-support via metadata (SP-2)`.

---

## Task 2b: `vertical_stack_family` → rewrite the level-below-level filter

**Files:** `TerrainModule.gd`, `TerrainModuleDefinitions.gd`, `TerrainGenerator.gd`.

- [ ] **Step 1 — Add field.** `@export var vertical_stack_family: String = ""`.
- [ ] **Step 2 — Set it.** `vertical_stack_family = "level"` on every level variant + both centers (`_build_level_tile` and the two center loaders).
- [ ] **Step 3 — Rewrite** the `can_place` level-below-level filter. Current (read it exactly first): it fires when `new_piece.def.tags.has("level") and parent_piece != null and parent_piece.def.tags.has("level")` and filters out overlapping pieces that are `p.def.tags.has("level") and p below new_y - 0.1`. Rewrite the outer guard to `new_piece.def.vertical_stack_family != "" and parent_piece != null and parent_piece.def.vertical_stack_family == new_piece.def.vertical_stack_family`, and the inner `p.def.tags.has("level")` to `p.def.vertical_stack_family == new_piece.def.vertical_stack_family`. **Keep the `< new_y - 0.1` y-comparison byte-identical.**
- [ ] **Step 4 — Verify.** Full characterization + `test_heightfield_cutover` + `test_heightfield_coverage` + `test_heightfield_interior_corners`. If any level-stacking integration test exists, run it.
- [ ] **Step 5 — Commit.** `refactor(terrain): level vertical-stack filter via metadata (SP-2)`.

---

## Task 3: density profile (HIGH RISK — pinning test first)

**Files:** add `tests/test_route_fill_prob_pinning.gd`; then `TerrainModule.gd`, `TerrainModuleDefinitions.gd`, `TerrainGenerator.gd`.

- [ ] **Step 1 — Capture current behavior (pinning test).** Before any code change, write `tests/test_route_fill_prob_pinning.gd` that constructs a generator (minimal lib like the characterization test, or full lib with scenes restored) and asserts `gen._route_fill_prob(piece, socket, pos, fill)` returns the SAME value (assert_almost_eq, 1e-6) as the current implementation for a representative set: (a) ground-plain `topcenter` (gentle path) at a low-density pos AND a cliff-core pos; (b) a level tile lateral (`front`) at a mid-density pos; (c) a cliff tile lateral at a mid-density pos; (d) a ground-plain foliage `topfront` at low-density and at cliff-core (must be 0). RUN it against current code, capture the exact numeric values it asserts (hard-code them from the first run). It must pass on current code.
- [ ] **Step 2 — Commit the pinning test** alone: `test(terrain): pin _route_fill_prob outputs before density-profile refactor (SP-2)`.
- [ ] **Step 3 — Add fields.** `@export var density_profile: String = "macro"` and `@export var grows_in_cliff_core: bool = false`.
- [ ] **Step 4 — Set them.** `density_profile = "gentle"` on ground-plain; `density_profile = "level"` on level variants + centers. `grows_in_cliff_core = true` on cliff edge variants AND cliff interiors. Leave the rest default (`"macro"`, false).
- [ ] **Step 5 — Rewrite `_route_fill_prob`.** Read it exactly. Preserve the early `if fill <= 0.0: return 0.0`, the `if fill < 1.0:` block's foliage sub-branch `if _socket_can_spawn_point(piece, socket_name): …` UNCHANGED EXCEPT replace `not piece.def.tags.has("cliff")` with `not piece.def.grows_in_cliff_core`. Replace the family discriminators with `match piece.def.density_profile:` — `"level"` → (core→0 else `_level_scaled_fill`), `"gentle"` → (`_gentle_scaled_fill` + the `_in_cliff_core` eager-seed `maxf(..., CLIFF_CORE_SEED_FILL_PROB)`), default `_` falls through to `return _macro_scaled_fill(fill, pos)`. **Preserve the foliage-branch-first ordering.** Do not touch `_gentle_scaled_fill`/`_level_scaled_fill`/`_macro_scaled_fill`.
- [ ] **Step 6 — Verify.** The pinning test (Step 1) MUST stay green — this is the authoritative behavior lock. Plus characterization Tests 1,2,4 + `test_biomes` + `test_spawn_config`. If the pinning test fails, the dispatch is wrong — fix until identical, do not adjust the pinned values.
- [ ] **Step 7 — Commit.** `refactor(terrain): density profile via metadata, not tags (SP-2)`.

---

## Task 4: surface-socket role + attachment socket

**Files:** `TerrainSpawnConfig.gd`, `TerrainModule.gd`, `TerrainModuleDefinitions.gd`, `TerrainGenerator.gd`.

- [ ] **Step 1 — Add fields.** `@export var socket_role: Dictionary[String, String] = {}` and `@export var attachment_socket: String = "bottom"`.
- [ ] **Step 2 — Emit `socket_role` centrally.** In `TerrainSpawnConfig.surface_spawn_sockets`, build a `socket_role` sub-dict marking every socket it creates (`topcenter`, `topfront/…`, the corner tops) as `"surface"`, and add it to the returned dict (alongside `socket_size`/`socket_fill_prob`/`socket_tag_prob`/`socket_suppressed_by`).
- [ ] **Step 3 — Merge it in builders.** Every builder that merges `surface[...]` sub-dicts (`load_ground_tile`, `_build_level_tile`, `_build_cliff_interior_module`, `load_bank_variant`, others using `surface_spawn_sockets`) also does `m.socket_role.merge(surface["socket_role"])` (or sets it before return). No other module needs `socket_role`.
- [ ] **Step 4 — Rewrite `get_adjacent_from_size`.** Point case: `return { Helper.get_attachment_socket_name(orig_piece_socket.socket_name): orig_piece_socket }` (drops the `"bottom"` literal via the geometry mapping). Ground-special adjacency: `hit.piece.def.tags.has("ground")` → `hit.piece.def.is_base_plane`; `orig_piece.def.tags.has("ground")` → `orig_piece.def.is_base_plane`; `orig_piece_socket.socket_name.begins_with("top")` → `orig_piece.def.socket_role.get(orig_piece_socket.socket_name, "") == "surface"`.
- [ ] **Step 5 — Verify.** `test_spawn_config` (surface dict shape) + characterization + `test_heightfield_cutover` + `test_heightfield_coverage` + `test_terrain_module_library`.
- [ ] **Step 6 — Commit.** `refactor(terrain): surface-socket role + attachment via metadata (SP-2)`.

---

## Task 5: Full-suite gate + audit

- [ ] **Step 1 — Grep audit.** `grep -nE 'tags.has\("(level|cliff|ground|ground-plain|hill)"\)' scripts/terrain/TerrainGenerator.gd` — the only remaining hits (if any) should be ones the design explicitly keeps or defers (none expected in the rewritten functions). List anything left and confirm it is intended (e.g. none). Also `grep -n 'begins_with("top")\|"front","back"' scripts/terrain/TerrainGenerator.gd` → none in the rewritten paths.
- [ ] **Step 2 — Full suite** (scenes restored): `-gconfig=res://tests/gutconfig.json`. Expected: same pass count as the SP-2 starting baseline (193/193 + the new pinning test). Any new failure is a regression.
- [ ] **Step 3 — Hand back the user's working state** (controller will re-delete the Cliff scenes at the end of SP-2).

---

## Notes / out of scope (per spec)
- WaterRule `"ground"`/`"water"` tags and its `CARDINAL_SOCKETS`/`DIAGONAL_SOCKETS` stay (content rule).
- `HeightfieldInstantiator._lookup_tag` (`"ground"→"ground-plain"`) deferred to SP-3.
- `Helper.get_attachment_socket_name` directional mapping and `HeightfieldFacing.OFFSET_TO_SOCKET` stay (geometry).
