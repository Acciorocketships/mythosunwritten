# September 29 town review: skywalks stream (photos 4, 8, 9)

World seed 2697992464. Town A = city 1260018864828801968 compact (site (13,44),
frame origin (306, 12.08, 1088) yaw 0). Town B = city 1998423929946073270 compact
(frame origin (202, 12.08, 504)). Renders: `tests/harness/suntail/kit_town_review.gd`
with `--frame`; evidence JPGs beside this file (gitignored, on disk only).

## Photo 4: gabled bridge-house not connected to either side

**What was wrong.** The circled house over the street is the exterior skywalk
network's enclosed span (`SettlementFabricAssembler._maze_skywalk_network_from`),
not a planner bridge compound. The planner's own bridge-houses
(`spatial.maze_bridge.NN` + `maze_bridge_end.NN.MM`) are fine: all 8 bodies in the
corpus are abutted by endpoint houses at both ends.

**Root cause.** Exterior spans are selected between *walk surfaces* (roof decks,
terrace crowns, public floors, and for "private" links, flat roof crowns of two
units). An even-gap span with clear sides was then drawn as a full bridge-house
(`enclosed = true`) and `_skywalk_mass` gave it a storey + roof at the deck band.
A walk surface has nothing standing on it at that band, so the house shell met no
wall at either end: its floor lay on a deck or roof edge ("connected by its bottom
edges"). In Town A span `(3,2,-11)+z` landed on public air over a deck at one end
and on a stone terrace top at the other. The "private" pass likewise joined two
roof *crowns*, i.e. a house sitting on two roofs.

**Fix.** The enclosed form is a structural fact, not a visual upgrade of a deck
span:
* Public spans between walk surfaces are always the open railed timber bridge
  (`enclosed: false`); two adjacent public lanes over the same gap form one 3 m
  bridge (`_maze_paired_open_skywalk_candidates`) instead of two railed bridges
  side by side.
* Bridge-houses come only from `_maze_passage_house_candidates`: both end lanes
  are room cells of two *different* units whose storey floor is the bridge floor
  (the band above is the same unit, the band below is not), the gap is air over
  the whole storey, a street keeps its headroom, gaps are whole 3 m bays and the
  existing shell clearances hold. Two adjacent lanes joining the same pair of
  units form the 3 m house. So every bridge-house meets a building wall over its
  full storey at both ends by construction.
* `KitVillageBuildings._passage_house_claims`: each endpoint house opens a door
  onto the passage at the bridge floor and keeps the passage body/roof air out of
  its own articulation (jetties, bays, canopies).
* Removed `_maze_paired_skywalk_candidates` and
  `_skywalk_structural_companion_lane` (the cantilevered half-bay form existed
  only for the deck-landing house).

Town A now has no bridge-house (no two building storeys face each other across a
street at one height); its span over the lane is an open bridge between the two
decks (`PAIR_photo4_p4wide.jpg`, left = before, right = after). Towns B, 3, 4, 5,
10, 11, 12 gain real passage-houses between buildings (`tops_sheet.jpg`,
`below_sheet.jpg`; roofs run into both endpoint roofs). 7/standard and 9/standard,
which had deck-landing houses, now carry open 3 m bridges (`cmp_7_sw1_side.jpg`).

## Photo 8: flickering edges on a skywalk underside

**Root cause.** The planner bridge-house body (`kit.spatial.maze_bridge.NN`) has no
terrain-bearing room, so its only storey IS the house datum. `BuildingKitAssembler
._assemble_soffit` boards it (via the adapter's `soffit` flag) but returned before
the rim trim for storeys at the datum. The wall panels' plaster bottom face and the
soffit boards' outer edge then met in one plane along both long sides with no
beam: a plaster/board hairline that shimmers and flickers as the camera moves
(`PAIR_photo8_rim.jpg`, left). The flag was also storey-wide, so any datum storey
with one cell over air boarded every cell.

**Fix.** The adapter records exactly which datum cells hang over air
(`soffit_cells`); those, and every storey above the datum, board only overhanging
cells and close every exposed rim with the continuous floor beam
(`trim.floor_beam[_corner]`), as jetties already did. `PAIR_photo8_street.jpg`
shows the photo-8 street view: the underside now has a beam on both rims.

## Photo 9: no roof above a balcony

**Root cause.** Not a missing roof: `KitLoggias.recess` cut a loggia into the top
storey of the house at Town A (-8..-2, 4..8) (landmark house) and the roof wing
still spans the full footprint. Roof over free air emits only corner posts
(`_porch_posts`), so from the street one looked up into the hollow attic: roof
boards from below, gable walls from behind, a floating chimney base
(`PAIR_photo9_inside_up.jpg`, left), read as "no roof". The same applies to every
porch/loggia under a roof.

**Fix.** `BuildingKitAssembler._assemble_attic_ceiling` closes the attic over
free air with boards at the eave, exactly as the floor of a storey above closes a
lower loggia. `PAIR_photo9_up.jpg`, `PAIR_photo9_inside_up.jpg`.

## Tests

New `tests/test_september29_skywalks.gd` (5 towns: A, B, 5/7/9 standard), each red
on the baseline and green after:
* `test_every_enclosed_skywalk_abuts_a_building_storey_at_both_ends` (red: Town A
  span; 7/9 standard deck-landing houses)
* `test_source_bridge_houses_abut_endpoint_houses` (guard; green on both)
* `test_exposed_wall_bases_over_air_carry_a_floor_beam` (red: Town B bridge rims)
* `test_roof_over_free_air_closes_the_attic` (red: Town A loggia)

`test_warren_maze_composition.gd::test_the_town_gets_its_life` pinned the old
private-link semantics (ends are roof crowns); updated to the new invariant (ends
are the bridge storey of two different buildings); 83/83.

Focused files, baseline vs branch, identical pass/fail: test_building_kit,
test_kit_roof_junctions, test_september16_skywalk_guards,
test_september17_bridge_overlap, test_september18_buried_soffits,
test_september27_town_details, test_september27_roofs, test_town_architecture,
test_town_canopies, test_town_depth, test_town_closures, test_town_layout_field,
test_warren_facade_variety, test_warren_interstitial_joins,
test_september10_roof_alignment, test_september13_floating_lawn all pass.
Pre-existing failures, identical on baseline: test_september10_skywalk_bearing
(15/16), test_september11_skywalk_integration (90/91),
test_september11_skywalk_neighborhood (431/435), test_september11_unified_city
(111/113), test_september11_architectural_variety (115/116). Composition:
test_finished_city_connectivity_uses_its_valid_private_skywalk_sites,
test_bridges_become_rooms_decks_or_audited_releases,
test_skywalk_corbel_course_stays_inside_the_crossing_lane,
test_flat_crowns_have_railings_on_open_edges pass on both. 11 cities build the kit
without errors.

## Open items

* Town A itself has no bridge-house any more; whether a town grows passage-houses
  is decided by whether two building storeys face each other across a gap at one
  height (planner mass), not by this stream.
* The in-game flicker in photo 8 was judged from harness renders (flat ground,
  SSAO on); the live-world capture was not run.
* Harness: `kit_town_review --views skywalk` cameras now use the town frame and
  add a top view; `tests/harness/suntail/skywalk_probe.gd` lists spans/bridge
  bodies with world coordinates.
