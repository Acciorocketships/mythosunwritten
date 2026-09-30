# September 27 judging pass — details stream (photos 2, 4, 7, 8)

## Proposed AGENTS.md paragraph

> September 27 town details (owner judging pass, seed 2697992464, photos
> 2/4/7/8). (1) Storey masonry has depth: the Suntail stone panels are baked
> 0.2 m thicker in front (`masonry_depth` manifest op,
> `EnvironmentBakeGeometry.deepen_masonry`, variants `suntail.stone.*_deep`):
> the stone face, its timber frame and every window/door reveal deepen while
> the window frame, glass and door leaf stay in the original plane (set back
> 0.06 m), so openings sit in deep stone reveals and the stone storey stands
> proud of the timber storey above. `BuildingKit.masonry_depth` /
> `face_of(material, retaining)` carry the thicker face to corner posts
> (grown to cover the deeper corner; inner corners of deep storeys get one
> too), porch canopies, doorstep props and ivy (`proud` on decor items).
> Retaining masonry (`storey.retaining`, `wall.stone.retaining`, courses)
> stays flush. (2) `KitSubstitution` redraws only complete legacy objects: a
> `sfm.stall.` descriptor must carry the `stall` tag and no `support` tag
> before it becomes a kit shop; the legacy canopy's hanging string
> (`DRESSING_OF_REDRAWN`) is withdrawn with the canopy it hung from (it was
> fitted as a floating miniature shop). (3) `PathProgram.filleted_path_shapes`:
> a turn without a fillet is a square joint; the incoming run continues half
> a width past the vertex so the outer corner is painted (town road handoffs
> with a short stub left a notch). (4) Wall-tied supports bear on wall-module
> joints: balcony rakers (`KitVillageBuildings._balcony_bearing` returns the
> joints either side of the bearing point and runs each brace square to the
> wall) and lot-house projection brackets, never across the window centred
> between two joints. Porch canopies are arbitrated across houses of one town
> (`BuildingDesigner.canopy_claims`). Tests:
> `tests/test_september27_town_details.gd` (4 tests, red on baseline). See
> `docs/qa/2026-09-27-judging/details/result.md`.

Evidence images (`*_before_after.jpg`, left before / right after) sit beside
this file on disk; `docs/qa/**/*.jpg` is gitignored, so they are not versioned.

## 1. Flat stone walls (photo 4) — fixed

**Root cause.** The pack's `Stone_Wall_W` is a 0.19 m slab (stone face at
z = +0.094) and its `Window_1` frame stands at z = +0.136, i.e. *in front of*
the stone. Windows could not read as sunk, and the stone storey (face 0.094)
was actually behind the timber storey above (0.157). The pack has no stone
window surround, sill or framed stone variant (only Stone_Base, Stone_Wall,
_W, _D, _D_1), so a real depth change had to come from the geometry.

**Change (bake, no runtime offsets).**
- New manifest op `masonry_depth {depth, setback, body_paths, opening_paths}`
  (`tools/environment_bake/environment_bake.gd`,
  `EnvironmentBakeGeometry.deepen_masonry`): before merging, every vertex of
  the panel body in front of its mid-plane moves +0.2 m; the window frame and
  glass / door leaf node moves back 0.06 m. Faces, winding and UVs are kept;
  visual and building_trimesh collision come from the same mesh.
- Four new catalog assets `suntail.stone.stone_wall{,_w,_d,_d_1}_deep`
  (baked with `--keep-existing`; all other baked resources are unchanged).
  Result: glass 0.41 m behind the stone face (was 0.09), stone face 0.29 vs
  timber 0.094 plaster / 0.157 posts.
- Kit: `wall.stone.plain/window/door` use the deep variants;
  `wall.stone.retaining` (and `wall.stone.course`) keep the flush source
  panel. `KitVillageBuildings._retained_mass` marks storeys `retaining`, the
  sunk foot course uses the retaining role (Sep 27 flush-course ruling kept).
- `BuildingKit.masonry_depth` + `face_of()`. `_emit_corner_post` takes the
  panels' face and grows the post to cover the deeper corner square; deep
  storeys also fill an inner corner (`right_concave` on wall slots). Decor on
  a deep storey carries `proud` (awning back posts, awning footprint, doorstep
  props, ivy).
- No jetty change: jettied stone storeys keep working (bracket fix below);
  the owner's alternative (upper storey jettying out) already exists and was
  not made more frequent.

**Tests.** `test_stone_storey_windows_are_sunk_and_the_masonry_stands_proud`:
baseline red (reveal 0.090 vs timber 0.094; stone face not proud), green now.
`test_town_canopies` pinned the canopy back beam 0–0.25 m from the wall
origin; it now measures from the owning wall asset's own measured front
(deep stone is prouder). That exposed one new cross-house canopy overlap (a
stone porch's canopy moved 0.15 m out into a perpendicular neighbour's), fixed
by town-wide canopy arbitration (`canopy_claims`).

**Evidence.** `p4_stone_storey_before_after.jpg` (in-world, photo-4 camera),
`p4_stone_close_before_after.jpg` (in-world close), 
`p4_stone_near_kit_before_after.jpg` (kit review, very close),
`corpus_3std_street2_before_after.jpg`, `corpus_7std_street1_before_after.jpg`.
Lane clearance probe (capsule r 0.397 at every route floor cell centre and
±0.6 m, 7 towns, 5,740 samples): 175 blocked before and after, identical per
town (`lane_clearance_before/after.txt`) — the thicker masonry closes no lane.

**Open / judgement calls.** Head-on at distance the effect is a clear but
moderate shadowed reveal; depth 0.2 m native (0.4 m world) was chosen so
alleys keep width. The reveal faces reuse the stone texture stretched along
depth (reads as a stone surround). The plinth (Stone_Base, front 0.345) now
projects only 0.05 beyond the deep face. The concave-corner filler is correct
by construction but no corpus stone storey has an inner corner, so it is not
visually verified. `terrain/environment/catalog/index.tres` is rewritten by
the bake (ext_resource ids renumbered): on merge, rerun
`godot --headless --path . -s res://tools/environment_bake/environment_bake.gd -- --manifest res://tools/environment_bake/manifests/suntail_village_kit.json --keep-existing`
instead of hand-merging it.

## 2. Floating mini market tent (photo 8) — fixed

**Root cause.** The perimeter frontage stall (`sfm.stall.variant.001`) is
stocked with a hanging vegetable string `sfm.stall.veg_string.001`
(`SettlementFabricAssembler.maze_stall_goods`). `KitSubstitution` mapped every
id with prefix `sfm.stall.` to the kit role `prop.shop`, so the 1.7 × 1.27 ×
0.11 m string was redrawn as a whole Suntail shop shrunk to fit its bounds
(scale 0.13) at 3.9 m — the miniature tent. The same prefix rule would also
have turned the stall attachments, chimney, support, stand and wheel into
miniature shops.

**Change.** `KitSubstitution._prop_role` admits a family prefix only for a
complete object: `sfm.stall.` needs the descriptor tag `stall` and no
`support` tag. The hanging string, whose station was measured on the legacy
canopy the kit replaces, is withdrawn (`DRESSING_OF_REDRAWN`) instead of
floating in front of the kit shop.

**Tests.** `test_a_stall_and_its_dressing_become_one_kit_stall`: baseline 2
shops per stall plus six stall parts redrawn as shops; now exactly one.
**Evidence.** `p8_mini_stall_before_after.jpg` (in-world, photo-8 camera).

## 3. Path notch (photo 7) — fixed

**Root cause.** Probe of the ground field at (264, 1054): the world road
arrives along z = 1056 (lattice cells (11,44) mask 3); the town street-domain
(surface NATURAL, priority 119) erases it from x = 265.12; the town route
`[(264,1056), (265.12,1056), (265.12,1086.6)…]` turns 90° after a 1.12 m stub.
The fillet needs radius ≥ half width, so the joint fell back to two butt-ended
rectangles: the incoming one ended at the vertex, the outgoing one started at
the road centreline, leaving the outer corner square (2 × 2 m) unpainted.

**Change.** `PathProgram.filleted_path_shapes`: any interior turn without an
arc is a square joint; the incoming run's rectangle continues half a width
past the vertex (the next run still starts at the vertex). This is the shared
builder for town road handoffs, outskirts lanes and door spurs, so every
approach gets the same rule.

**Tests.** `test_a_square_path_joint_closes_its_outer_corner` (reported
geometry): 16 unpainted samples on baseline, 0 now. Path/street suites green
(test_path_program, test_path_features, test_village_street_junctions,
test_september7_street_ownership, test_september13_street_handoffs,
test_september19_road_bend_ownership, test_village_gate_handoffs).
**Evidence.** `p7_path_notch_before_after.jpg` (in-world, photo-7 camera),
`p7_path_notch_plan_before_after.jpg` (plan).

## 4. Brace through window (photo 2) — fixed

**Root cause.** The braces are balcony rakers
(`KitVillageBuildings._balcony_mass`): each deck cell's bearing point was the
cell centre clamped onto the neighbouring house wall, i.e. the centre of a
wall module — exactly where that module's window is. The diagonal raker from
0.85 band below the deck to the deck edge crossed the arch. (Jetty brackets
were already at module joints, matching the pack's House_1; lot-house
projection brackets in `KitStandaloneHouse` had the same centre bug.)

**Change.** `_balcony_bearing` returns the wall joints either side of the
bearing point (a wall corner already is one) and the wall normal; one raker
pair per joint (deduplicated), square to the wall. Lot-house projection
brackets likewise stand on the joints of the edge below.

**Tests.** `test_supports_never_cross_a_window_or_door` (6 towns: photo-2 and
photo-4 towns plus corpus): every wall-tied support (bracket, raker, post
centre lines) vs every window/door aperture box extended 1.2 m out: 15
crossings on baseline, 0 now. Free-standing room-overhang posts 1.2 m out
beside a window are not counted as crossings.
**Evidence.** `p2_braces_before_after.jpg` (in-world, photo-2 camera),
`p2_braces_crop_before_after.jpg` (production payload, same camera, crop).

## Tests run (worktree vs baseline copy)
Green: test_september27_town_details 4/4 (baseline 0/4), test_building_kit
8/8, test_environment_bake_geometry 14/14, test_kit_roof_junctions 8/8,
test_path_features, test_path_program, test_september13_street_handoffs,
test_september19_road_bend_ownership, test_september19_prefab_stair_guards,
test_town_architecture 11/11, test_town_canopies 2/2 (bound updated, see 1),
test_town_closures, test_town_court_enclosure, test_town_depth,
test_town_layout_field, test_village_gate_handoffs,
test_village_street_junctions, test_september7_street_ownership,
test_september27_road_grade.
Identical failures on the baseline: test_environment_catalog 3 (UID
warnings on kaykit terrace / sfv door meshes), test_village_outskirts_construction
1 ("house must not overlap the town path"), test_village_outskirts_solver 1
(legacy edge prefab size).

## Falsification done
- Matched in-world captures (`village_site_capture`, fresh worlds, both trees)
  at photos 2, 4, 7, 8 plus close views; every "before" reproduces the owner's
  defect.
- Kit-review orbit/street views of three other towns (3 standard, 7 standard,
  2 compact) before/after: deep reveals on stone storeys, retaining courses
  unchanged, no new holes at corners.
- Lane capsule clearance unchanged (above). Canopy overlap regression found
  and fixed.
