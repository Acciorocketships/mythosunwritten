# Task 6 report

## _face_noise call sites (seed now required)
- Frontage (already seeded): `world_seed`.
- Stall goods (`maze_stall_goods`, new trailing `world_seed=0`): `world_seed`; passed from frontage payload, plaza feature clear check, garden dressing, `maze_perimeter_frontage_from_sites` (new `world_seed` param; VillageWarrenFabricSolver passes `fabric.world_seed`). VillageOutskirtsSolver market stalls have no world seed -> default 0 (unchanged).
- Plaza centre feature (pick, quarter, trees, island quarter): `world_seed` (new trailing param on `maze_plaza_centre_feature`, `_maze_plaza_feature_is_clear`); WarrenSpatialFabricCompiler audit passes `plan.world_seed`.
- Garden planting (yaw, pool picks, odds): `world_seed` via `maze_garden_planting_sites`/`_maze_garden_odds_say_plant`; `maze_garden_dressing` gets `plan.world_seed`; compiler audit also.
- Natural rock (5 calls): 0, "natural rock is off; seed irrelevant".
- Skywalk order (2 calls): 0 deliberately -- that is layout selection, not dressing (flagged below).
- Facade module: now `int(_face_noise(key, FACADE_MODULE_SALT, world_seed)*n) % n`.

## Ordering
`maze_garden_lamp_sites` / `maze_garden_furniture_sites` sort candidates by `_face_noise(cell,0, LAMP_/FURNITURE_ORDER_SALT, world_seed)`, tie -> `_cell_before` (helper `_station_order`). Constants added.

## Source hashes
All 8 seeds: source hash == baseline. Payload changed for 103,13,31,43,53,83; unchanged for 61 and 7. Baseline.json replaced.

## Audit (production range audit)
6 rows (53 grand, 31, 13, 43, 83, 103): valid_payload true, floating 0, roof intrusions 0.

## Tests
test_dressing_seed 1/1. test_settlement_fabric after: 49/52 pass (3 fail: market alley variety, oriel half-width column, prefab eave bounds). Before (d53b75857): 48/52 (same failures plus an "Unexpected Errors" in the before worktree, likely stale import there). test_garden_bearing_cap after 1/1 pass; before worktree 0/1 only due to "Unexpected Errors" noise. No new failures.

## Images (docs/qa/2026-10-07-town-odds/dressing-seed/{before,after})
- 53_grand_court_plaza.00_0: before a tree with benches; after a well and a lamp post at a different place, no clipping.
- 31_large_court_plaza.00_1: before a tree, benches, distant lamp; after a well. Different seeded plaza pick (expected).
- 53_grand_overview before/after look identical at that scale; 43_large_street2 after shows no props in rails/routes.
I did not find lamp clustering obvious in the sampled before images; not exhaustively compared all 45 frames.

## Concerns
1. Facade module pick: old comment argued for a sum on purpose (alternating window/boarded rhythm); brief says hash, so I hashed. Visual rhythm may be more random; overview renders show no obvious change.
2. Skywalk order left at seed 0 (layout); brief only lists dressing.
3. Seeds 61 and 7 payloads unchanged, which is a bit surprising (no facade/garden rolls changed?).
4. Before-worktree needed addons/gut copied in.

## Fix round 1
1. Seed made REQUIRED (no default) on maze_stall_goods, maze_plaza_centre_feature (and the params before it lost defaults, GDScript forbids required-after-default), _maze_plaza_feature_is_clear, maze_garden_dressing, maze_garden_planting_sites, maze_perimeter_frontage_from_sites, maze_garden_lamp_sites, maze_garden_furniture_sites. All tests callers updated to pass literal 1 (court_canopy_proportion, irregular_court_planting, october2_courtyard_planting, october3_street_canopy, september27_town_details, september9_city_lanterns, september9_city_props, warren_maze_composition). VillageOutskirtsSolver passes 0 with the comment "outskirts are off in production; no world seed reaches this solver".
2. Why 61:standard and 7:compact payload hashes did not change (tmp harness, deleted; output docs/.../dressing-seed/idcount.out): world_seed=61/7 is passed, but both towns have plaza_cells=0 and zero `maze-garden/`, `maze-plaza`, `maze-stall-goods`, `maze-frontage` ids (all 1968 / 1121 ids are "other"), so no seeded dressing path runs. The facade module pick is not hit in the kit payload path (kit replaces legacy facade units). 53:grand for contrast: 5 `maze-garden/` ids, 1 `maze-plaza`. No unseeded path remains.
3. New tests in tests/test_dressing_seed.gd (6 pass): lamp stations, furniture stations, plaza centre pick (seeds 1-12), garden planting, facade module all differ across seeds.
4. SKYWALK comment moved above SKYWALK_ORDER_SALT.
Runs: test_dressing_seed 6/6; test_settlement_fabric 49/52 (same 3); test_garden_bearing_cap 1/1; test_court_canopy_proportion 2/2; test_irregular_court_planting 3/3. Other touched-test files fail the same tests as at d53b75857: october2_courtyard_planting 1 fail (base 1), september27_town_details 1 (base 3), september9_city_lanterns 1 (base 1), september9_city_props 1 "east adds a real furniture group" (base same). Fingerprint rerun: all 8 source and payload hashes equal the committed baseline (no baseline change).
