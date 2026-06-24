# FR-2: Unified mesh layer (one bitmask-driven composite edge tile) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Behavior-preserving *appearance* (terrain must look the same); large content deletion guarded by visual checks + tests.

**Goal:** Generate every edge-tile family (level/cliff/bank) from one parameterized component set + the FR-1 bitmask, deleting the ~29 authored variant scenes, the variant tables, and `VARIANT_MASKS`.

**Architecture:** The slope system already generates cliff slope meshes from 4 canonical components (`top`/`edge`/`outer_corner`/`inner_corner` + 2 stacked) composed on an N×N grid by a bitmask with rotation (`SlopeMeshGenerator`/`SlopeProfile`/`SlopeVariantLayout`). Parameterize that by **drop_height** (0.5 level, 4 cliff/bank) and **top material** (grass land top / water-facing bank wall), derive the component layout **directly from the FR-1 `edge_bitmask`** (not `VARIANT_MASKS`), and extend the offline bake to emit all families. Runtime placement is unchanged (instance a generated scene by tag).

**Tech Stack:** Godot 4 / GDScript, GUT. Bake is a headless `SceneTree` script. Binary `/Applications/Godot.app/Contents/MacOS/Godot`.

**Branch:** `refactor/terrain-field-driven`. **Depends on FR-1** (the unified `edge_bitmask` / `drop_height` / `material` descriptor and the one canonical catalog).

**Grounding:** `scripts/terrain/tools/SlopeMeshGenerator.gd` (`build_top/edge/inner_corner/outer_corner/*_stacked` + `_collision`), `SlopeProfile.gd` (height curves, `HEIGHT=4.0`), `SlopeVariantLayout.gd` (`VARIANT_MASKS`, `layout()`, `generated_stacked_variants`), `bake_slope_cliffs.gd` (the bake), `HeightfieldVariant.CANONICAL_MISSING_BY_TAG`/`TAG_ORDER`.

---

## File structure
- **Modify** `SlopeProfile.gd` / `SlopeMeshGenerator.gd` — parameterize by `drop_height` + `top_material`.
- **Modify** `SlopeVariantLayout.gd` — derive the N×N component layout from a bitmask; drop `VARIANT_MASKS`.
- **Rename/extend** `bake_slope_cliffs.gd` → `bake_edge_tiles.gd` — emit level/cliff/bank variants from the one component set.
- **Modify** `TerrainModuleDefinitions.gd` — load all edge families from generated scenes by canonical tag; delete `LEVEL_VARIANT_TABLE`/`CLIFF_VARIANT_TABLE`/`CLIFF_STACKED_VARIANT_TABLE`.
- **Delete** `terrain/scenes/level/*.tscn` (authored) and `terrain/scenes/cliff/*.tscn` (authored sheer; banks now generated) after the generated equivalents exist and verify.
- **Tests** — extend `test_slope_*`; new `test_edge_tile_generation.gd`.

---

## Task 1: Parameterize the component generator by drop height + top material
**Files:** `SlopeProfile.gd`, `SlopeMeshGenerator.gd`; Test `tests/test_slope_profile.gd`/`test_slope_mesh_generator.gd` (extend).
- [ ] Add `drop_height` param to `SlopeProfile`'s height functions (replace the hardcoded `HEIGHT=4.0`) and to `SlopeMeshGenerator.build_*`; add a `top_material`/`wall_material` parameter to the mesh builder.
- [ ] Tests: a `drop_height=0.5` edge spans 0.5 not 4.0; endpoints/flat-tangents hold at any drop; collision spans the parameterized drop. Extend the existing profile/mesh tests with a parameterized case.
- [ ] Commit `feat(terrain): parameterize slope components by drop height + material (FR-2)`.

## Task 2: Derive component layout from the bitmask (delete `VARIANT_MASKS`)
**Files:** `SlopeVariantLayout.gd`; Test `tests/test_slope_variant_layout.gd` (extend).
- [ ] Add `static func layout_for_bitmask(missing: Array) -> Array` that produces the N×N component grid (`top`/`edge`/`outer_corner`/`inner_corner` + rotations) directly from the FR-1 wall-set, replacing the per-variant `VARIANT_MASKS` lookup. Verify it reproduces today's `layout(name)` for each canonical tag (a table-driven equivalence test over `HeightfieldVariant.TAG_ORDER`).
- [ ] Generalize `generated_stacked_variants`/stacked-corner handling to a **corner-depth** parameter (from FR-1 `corner_depths`) rather than an enumerated subset list.
- [ ] Delete `VARIANT_MASKS` once `layout_for_bitmask` matches it for all tags.
- [ ] Commit `refactor(terrain): derive slope layout from the canonical bitmask (FR-2)`.

## Task 3: Extend the bake to all edge families
**Files:** rename `bake_slope_cliffs.gd` → `tools/bake_edge_tiles.gd`; Test `tests/test_edge_tile_generation.gd`.
- [ ] Generate, for each canonical shape in `TAG_ORDER` × {level (drop 0.5, grass top), cliff (drop 4, grass top), bank (drop 4, water-facing wall)}, a variant scene built from the parameterized components via `layout_for_bitmask`, copying the surface markers as today (`_ground_surface_sockets`) so socket parity holds while FR-3 still uses sockets.
- [ ] Output dirs: `terrain/scenes/level/`, `terrain/scenes/cliff/` (now generated), keep `terrain/scenes/slope/` or fold cliff into it — pick one convention and document. Write the bake command in the file header.
- [ ] Test: for each (shape, family) the generated scene loads, has the right walkable-surface height/collision, and markers match the catalog. Run the bake in the test setup or check committed artifacts.
- [ ] Commit `feat(terrain): generate level/cliff/bank variant scenes from one component set (FR-2)`.

## Task 4: Load generated scenes by canonical tag; delete the variant tables
**Files:** `TerrainModuleDefinitions.gd`.
- [ ] Replace `LEVEL_VARIANT_TABLE`/`CLIFF_VARIANT_TABLE`/`CLIFF_STACKED_VARIANT_TABLE` iteration with a single loop over `HeightfieldVariant.TAG_ORDER` × tiers, loading the generated scene for each `(shape, family, tier)` and tagging it with the canonical descriptor tag (`cliff-side`, `level-side`, `bank-side`, …). One source of shapes.
- [ ] `test_heightfield_coverage` still green (every emittable tag has a module). `test_slope_cliff_integration` updated for generated paths.
- [ ] Commit `refactor(terrain): load edge tiles from generated scenes via one tag loop (FR-2)`.

## Task 5: Delete authored variant scenes + visual verification
**Files:** delete `terrain/scenes/level/*.tscn` + the authored sheer `terrain/scenes/cliff/*.tscn` (now generated); keep foliage/base/gltf.
- [ ] After the generated scenes are committed and Task 4 resolves all tags to them, delete the authored variant scenes. `grep`/coverage test confirms no tag resolves to a deleted authored scene.
- [ ] **Visual (primary):** run the game; screenshot cliffs, terraces (levels), shorelines (banks), and 2-storey diagonal corners. Compare against the pre-FR-2 authored-scene appearance — terrain must look the same or cleaner at seams. Tune `SlopeProfile` per-drop-height if a family looks off.
- [ ] Full GUT suite green.
- [ ] Commit `refactor(terrain): delete authored variant scenes; all edges generated (FR-2)`.

## Self-review notes
- Spec coverage: parameterized components (T1), bitmask layout + delete VARIANT_MASKS (T2), bake all families (T3), one tag loop + delete tables (T4), delete authored scenes + visual (T5). ✔
- Hard case (2-storey diagonal ramp) handled as a corner-depth parameter (T2), not a general N-storey mechanism.
- Socket-marker parity preserved in generated scenes (T3) while FR-3 still uses sockets; constraint relaxes after FR-3.
