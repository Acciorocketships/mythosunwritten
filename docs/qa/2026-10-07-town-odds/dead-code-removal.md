# Dead town-generator code removal (October 7)

Branch `town-redesign`, from `8bcfa6798`. Commits:

1. `7b8cdd6c5` delete the retired plot-void/rising-ring planners and their proofs
2. `fd7e184d0` drop unread feature targets and the paired-relief knob
3. `293dcca06` delete the terrain-massing village and outskirts generators
4. `a3ec7d84c` delete three never-called VillageWarrenFabricSolver helpers
5. `74cc93f26` AGENTS.md: record the removal
6. this report

Net: 122 files, +162 / -17,179 lines (before this report). Default towns are
byte-identical (fingerprint below).

## Method

Reachability, not guesswork: a script resolved every `class_name` token (with
strings and comments stripped), `res://` path and `uid://` reference starting
from `project.godot`, `scenes/world.tscn` and `ui/loading_screens/*.tscn`, and
listed the scripts under `scripts/` it never reached. Because the token walk
also follows references inside dead functions of live files, member-level
candidates were checked by hand (every caller grepped), then the walk was re-run
after each step until only the intentionally kept scripts remained unreached.
A throwaway compile-everything script (load every `.gd` under `scripts/` and
`tests/`) was run on the baseline and on the final tree: the same four
pre-existing failures both times (`test_september10_grass_latency`,
`test_september15_water_sample_work`, `test_village_frame`,
`harness/probe_warren_spatial_layout`), nothing new.

## Deleted production files (48 files, 10845 lines)

| File | Lines |
|---|---|
| `scripts/terrain/features/villages/FoundationRequest.gd` | 97 |
| `scripts/terrain/features/villages/FoundationSolver.gd` | 215 |
| `scripts/terrain/features/villages/SupportRequest.gd` | 46 |
| `scripts/terrain/features/villages/SupportSolver.gd` | 179 |
| `scripts/terrain/features/villages/VillageAerialRouter.gd` | 178 |
| `scripts/terrain/features/villages/VillageBuildingSupportPlan.gd` | 30 |
| `scripts/terrain/features/villages/VillageBuildingSupportSolver.gd` | 90 |
| `scripts/terrain/features/villages/VillageCirculationLink.gd` | 82 |
| `scripts/terrain/features/villages/VillageCirculationPlan.gd` | 84 |
| `scripts/terrain/features/villages/VillageDoorGeometry.gd` | 34 |
| `scripts/terrain/features/villages/VillageFrontageDomain.gd` | 103 |
| `scripts/terrain/features/villages/VillageGroundRouter.gd` | 431 |
| `scripts/terrain/features/villages/VillageMarketPlan.gd` | 63 |
| `scripts/terrain/features/villages/VillageMarketProgram.gd` | 85 |
| `scripts/terrain/features/villages/VillageMarketStall.gd` | 18 |
| `scripts/terrain/features/villages/VillageMassingPlacement.gd` | 297 |
| `scripts/terrain/features/villages/VillageMassingPlan.gd` | 62 |
| `scripts/terrain/features/villages/VillageMassingProgram.gd` | 147 |
| `scripts/terrain/features/villages/VillageMassingSlot.gd` | 32 |
| `scripts/terrain/features/villages/VillageModuleCell.gd` | 36 |
| `scripts/terrain/features/villages/VillageModuleGrid.gd` | 49 |
| `scripts/terrain/features/villages/VillageOutskirtsPlan.gd` | 58 |
| `scripts/terrain/features/villages/VillageOutskirtsProgram.gd` | 119 |
| `scripts/terrain/features/villages/VillageOutskirtsSolver.gd` | 1939 |
| `scripts/terrain/features/villages/VillagePlatformRegion.gd` | 70 |
| `scripts/terrain/features/villages/VillagePlatformSolver.gd` | 380 |
| `scripts/terrain/features/villages/VillageRockCoreSolver.gd` | 232 |
| `scripts/terrain/features/villages/VillageRouteGeometry.gd` | 248 |
| `scripts/terrain/features/villages/VillageRouteStairFabricPlan.gd` | 52 |
| `scripts/terrain/features/villages/VillageRouteStairFabricSolver.gd` | 250 |
| `scripts/terrain/features/villages/VillageRouteStairRun.gd` | 37 |
| `scripts/terrain/features/villages/VillageSkirtDeckPlan.gd` | 23 |
| `scripts/terrain/features/villages/VillageStairSolver.gd` | 25 |
| `scripts/terrain/features/villages/VillageStairTransition.gd` | 26 |
| `scripts/terrain/features/villages/VillageTerrainPerch.gd` | 79 |
| `scripts/terrain/features/villages/VillageTerrainSurvey.gd` | 342 |
| `scripts/terrain/features/villages/VillageTimberCell.gd` | 38 |
| `scripts/terrain/features/villages/VillageTimberCellCompiler.gd` | 169 |
| `scripts/terrain/features/villages/VillageTimberFabricPlan.gd` | 49 |
| `scripts/terrain/features/villages/VillageVerticalProfile.gd` | 68 |
| `scripts/terrain/features/villages/fabric/SectionalPublicRealmBuilder.gd` | 376 |
| `scripts/terrain/features/villages/fabric/StaggeredFabricEmbedder.gd` | 1047 |
| `scripts/terrain/features/villages/fabric/WarrenOverheadSolver.gd` | 714 |
| `scripts/terrain/features/villages/fabric/WarrenPlotVoidGrammar.gd` | 444 |
| `scripts/terrain/features/villages/fabric/WarrenPlotVoidPlan.gd` | 230 |
| `scripts/terrain/features/villages/fabric/WarrenPlotVoidPlanner.gd` | 489 |
| `scripts/terrain/features/villages/fabric/WarrenPrefabSolver.gd` | 139 |
| `scripts/terrain/features/villages/fabric/WarrenRisingRingPlanner.gd` | 844 |

## Deleted test files, fixtures and harnesses (29 files, 3385 lines)

| File | Lines |
|---|---|
| `tests/fixtures/warren_folded_proof.gd` | 472 |
| `tests/harness/perimeter_gate_corpus.gd` | 59 |
| `tests/harness/probe_warren_loop.gd` | 211 |
| `tests/harness/probe_warren_planner.gd` | 495 |
| `tests/harness/review_warren_phase0_pins.json` | 10 |
| `tests/harness/review_warren_phase0_v1.json` | 30 |
| `tests/harness/review_warren_phase0_v3.json` | 26 |
| `tests/harness/september10_city_complete_qa.gd` | 75 |
| `tests/harness/september10_city_complete_qa.tscn` | 6 |
| `tests/harness/september10_city_frontage_probe.gd` | 35 |
| `tests/harness/september10_hamlet_asset_probe.gd` | 6 |
| `tests/harness/september7_path_probe.gd` | 30 |
| `tests/harness/september8_door_probe.gd` | 35 |
| `tests/harness/september8_porch_walk.gd` | 63 |
| `tests/harness/september8_porch_walk.tscn` | 6 |
| `tests/harness/september9_path_probe.gd` | 30 |
| `tests/harness/september9_tunnel_stable_qa.gd` | 35 |
| `tests/harness/september9_tunnel_stable_qa.tscn` | 6 |
| `tests/harness/warren_phase0_review.gd` | 889 |
| `tests/harness/warren_phase0_review.tscn` | 6 |
| `tests/harness/warren_seed_corpus.gd` | 162 |
| `tests/test_foundation_solver.gd` | 95 |
| `tests/test_september8_night_door_path.gd` | 38 |
| `tests/test_september8_porch_path.gd` | 31 |
| `tests/test_september9_road_exit.gd` | 47 |
| `tests/test_support_solver.gd` | 112 |
| `tests/test_village_frontage_domain.gd` | 56 |
| `tests/test_village_outskirts_construction.gd` | 173 |
| `tests/test_village_terrain_survey.gd` | 146 |

## Deleted / trimmed members

- `WarrenMarketSolver`: everything except `MARKET_MINIMUM`, `MARKET_SIZE`,
  `COVERED_MARKET_MINIMUM/SIZE` and `_bearing_follows_local_ground` (the
  candidate search, `REQUIRED_MARKETS`, `TARGET_MARKETS`,
  `MAX_FAMILIES_PER_PLACEMENT`, `_family`, ...). 322 -> 25 lines.
- `WarrenElevatedFrontageSolver`: everything except `MIN_COURTYARD_UNDERBUILT_COLUMNS`,
  `MIN_COURTYARD_DAYLIGHT_COLUMNS`, `_courtyard_vertical_route_floor_counts`,
  `_fine_square`, `_has_inhabited_mass_below` (`extend`, `variants`, the branch
  search). 684 -> 57 lines.
- `WarrenSpatialFeatureSolver`: `TARGET_SKYWALKS`, `TARGET_PREFAB_LANDMARKS`,
  `TARGET_BALCONIES`, `TARGET_ROOM_OUTCROPPINGS`; the two parameters that defaulted
  to them are now required (the one caller already passed the profile values).
- `WarrenRoomCompositionPlanner`: `MAX_PAIRED_RELIEF_FRONTIER/COLUMN_DISTANCE/PAIR_CHECKS`
  (moved into `tests/fixtures/legacy_room_repair.gd`, their only reader) and the
  unread `enable_paired_registration_relief` parameter; removed likewise from
  `WarrenVolumetricSolver.from_volume`, `_partition_rooms` and `_maze_feature_pass`.
  Callers updated (4 tests, 1 fixture, 8 harnesses; two harnesses were passing
  `profile.requires_elevated_courtyard` into that dead slot).
- `VillageUrbanFabricPlan`: fields `ground_settlement`, `massing`, `market`,
  `circulation`, `timber`, `route_stairs`, `supports`, `skirts`,
  `public_stair_count`, `natural_building_count`, `retained_building_count`,
  `rock_piece_count`, `foundation_piece_count`, `candidate_audit`; `validate`
  keeps only the volumetric branch (sectional/ground-hamlet/terrain-massing
  branches, `_validate_sectional_warren`, `requires_outskirts` deleted).
- `VillageRecord.outskirts` and its validation branch (production always set it
  to null); `VillagePlan` no longer assigns it.
- `VillageProgram`: `massing_program`, `market_program`, `outskirts_program` and
  their compilation, `massing_slots_for_tier`.
- `VillageOutskirtsConstruction`: everything except the world-road street
  helpers production calls (`_append_street`, `_extend_street_grade`,
  `_world_road_handoffs`), plus `_ground_contacts` moved in from the deleted
  solver (its never-taken `urban.circulation` branch dropped; the source-less
  fixture fallback keeps the literal 36 m radius). `_append_street` now writes
  straight onto the `VillageUrbanFabricPlan` (same append order, so identical
  output) instead of a throwaway `VillageOutskirtsPlan`. 490 -> 139 lines.
- `VillageWarrenFabricSolver`: `_append_terrain_bearing_foundations`, `_all_zero`,
  `_terrain_qualified_frontage_payload` (no callers).
- Harness edits (legacy branches only): `village_visual_corpus.gd` (terrain-massing
  entry/views and outskirts JSON; report keys kept at zero), `village_corpus.gd`,
  `village_record_probe.gd`, `village_urban_probe.gd`, `village_manual_probe.gd`,
  `september11_landform_world_records.gd`, `september11_unified_world_probe.gd`.

## Tests

Deleted whole (every case exercised deleted code only): `test_foundation_solver`,
`test_support_solver`, `test_village_terrain_survey`, `test_village_frontage_domain`,
`test_village_outskirts_construction`, `test_september8_night_door_path`,
`test_september8_porch_path` (both test the outskirts `_ground_entrance`),
`test_september9_road_exit` (outskirts `generate`).

Edited (before = `8bcfa6798`, after = final tree `74cc93f26`; GUT headless, one
file per run). Failures after are a subset of failures before in every file.

| Test file | Removed cases | Before (tests / failing) | After (tests / failing) |
|---|---|---|---|
| test_settlement_fabric | 7 (folded proof, plot-void grammar, staggered embedder, sectional builder) | 52 / 3: circulation_recipes, plot_void_stairs, program_compiles | 45 / 2: circulation_recipes, program_compiles |
| test_warren_facade_variety | 2 (market family walk) | 22 / 0 | 20 / 0 |
| test_warren_village_scale_profile | 0 (TARGET_* -> literals 4, 3) | 10 / 0 | 10 / 0 |
| test_warren_volumetric_solver | 0 (MAX_PAIRED_* -> LegacyRoomRepair) | 41 / 0 | 41 / 0 |
| test_room_band_construction | 0 (call signature) | 3 / 1: paired_projection | 3 / 1: paired_projection |
| test_september11_roof_domain | 0 (call signature) | 1 / 0 | 1 / 0 |
| test_september13_shared_stair_landing | 0 (call signature) | 4 / 0 | 4 / 0 |
| test_town_layout_field | 0 (call signature) | 6 / 0 | 6 / 0 |
| test_village_program | massing/market/outskirts program asserts | 2 / 1: default_program_compiles | 2 / 1: default_program_compiles |
| test_september7_street_ownership | 1 (outskirts generate) | 2 / 0 | 1 / 0 |
| test_village_street_junctions | 1 (outskirts `_frontage_path`) | 3 / 0 | 2 / 0 |
| test_september10_city_form | 2 (frontage domain, outskirts generate) | 10 / 2: native_houses_share, source_city_shapes | 8 / 1: source_city_shapes |
| test_village_reported_ground | the `record.outskirts` assertion | 4 / 2 (+1 script error): edits_ground, stair_blocked_door | 4 / 1: stair_blocked_door |
| test_september11_unified_city | 1 (`requires_outskirts`) | 4 / 1: photographed_city_allocates | 3 / 1: photographed_city_allocates |
| test_village_outskirts_solver | 10 (solver cases); keeps the 2 live street-fillet / contact-geometry cases | 12 / 1: volumetric_warren_approach | 2 / 0 |
| test_village_capture_views (preloads the edited visual corpus) | 0 | 8 / 0 | 8 / 0 |

`tests/fixtures/frozen_maze_source.gd` (used by ~200 tests) changed only its
`from_volume` call (dead positional argument dropped); the fingerprint and the
compile-everything check cover it.

## Kept on purpose

1. `KitStandaloneHouse` (unreached from production): `test_town_architecture`,
   `test_september27_roofs` and `harness/suntail/gallery_masses` use it to cover
   the live kit (BuildingDesigner/assembler) on lot houses.
2. `BuildingDesigner.design_standalone`: backs the House_1 replica test and
   KitStandaloneHouse.
3. `KitFloatingMassAudit`: test oracle for the corpus invariant.
4. `SettlementFabricAssembler` NATURAL_ROCK_* / `maze_natural_*`: the owner's
   I2 ruling kept it as a named switch; `kaykit.cliff.wall` is in the fabric
   program's referenced assets, which feed `VillageProgram.max_asset_reach` and
   so the discovery radius / geometry halo; the arithmetic is pinned by
   `test_warren_maze_composition` (11k lines). Removing it could move production.
5. `VillageElevatedProgram` (+ its specs): contributes referenced assets and
   `max_asset_reach` to `VillageProgram`.
6. `VillageProgram` asset/prop/street/slot tables, `LEGACY_LAYOUT_REACH`, layout
   radii: they feed `referenced_asset_ids`, `runtime_aabbs`, `max_asset_reach`,
   `record_bound` and prop slots (validated records).
7. `VillagePlan` tier/theme rolls and `record.tier/theme`: tier selects the prop
   slots behind `record.prop_results`; theme is read by `test_village_plan` and
   the visual-corpus tier/theme buckets.
8. `VillageUrbanFabricPlan.validate(program, _tier)`: the tier argument is now
   unread but has four callers including `test_warren_maze_composition`; the
   `GenerationKind` enum keeps its four values (ordinals; harness references).
9. `KitRoofTurrets.parts` / `CAP_LAP`: production uses only `cutters`, but
   `test_october3_roof_turrets` builds its fixture with `parts`.
10. The class name `VillageOutskirtsConstruction` (now world-road street helpers)
    to avoid renaming churn in two live tests.
11. `VillageCirculationNode`: still the road-connection contact record.
12. Non-town unreached scripts (`camera/legacy_camera_view.gd`,
    `core/Distribution.gd`, `diagnostics/LoadedTerrainBoundary.gd`,
    `tools/ReviewCam.gd`): outside the town scope.
13. Harness-internal helpers in `village_visual_corpus.gd` that no longer have an
    in-file caller but reference only live types: left as harness code.

## Gates

- Fingerprint (final tree `74cc93f26`, `town_fingerprint.gd --compare
  docs/qa/2026-10-07-town-odds/fingerprint/baseline.json`): `FINGERPRINT_MATCH`,
  exit 0 (also matched at commit 3 `293dcca06`).
- `--import` on the worktree after every commit: no SCRIPT ERROR / Parse Error /
  "Could not find".
- No path or class-name references to deleted files remain in `scripts/`,
  `tests/`, `scenes/`, `ui/`, `tools/`, `project.godot` (archived `docs/qa` copies
  are `.gdignore`d).
- World load (throwaway script, deleted): `scenes/world.tscn` and
  `ui/loading_screens/mythos_loading_screen.tscn` both load, exit 0.
