# Terrain review: "yellow" deformation, ground seams, road divots (September 29)

Owner photos 1-11, seed 2697992464. Renders reproduce them with
`tests/harness/cliff_site_review.tscn --full --grass --categories --plain`
and `--mouse-shot id:player:crosshair` (the close mouse-view camera solved
from the F3 readouts). Evidence JPGs are on disk only (`images/`, gitignored).

| Photo | Player | Reported |
|---|---|---|
| 1 | (412.5, 27.5, 1742.1) | seam: grass ends on a straight line |
| 2 | (313.8, 15.9, 1535.7) | deformed ground (a water sheet over a dying-cliff slope) |
| 3 | (363.1, 24.0, 1695.2) | grass-free mound with a hard grass edge |
| 4 | (265.2, 8.0, 1379.6) | pale line along a bank |
| 5 | (405.6, 12.0, 1278.9) | patchy squares (top-down) |
| 6, 7 | (454.6, 75.8, 913.5), (443.0, 71.6, 802.2) | F9 "yellow" deformed ground |
| 8, 9 | (310.8, 16.9, 477.8) | a large divot on the road, F9 view of it |
| 10 | (465.6, 75.8, 921.4) | seam at a crest |
| 11 | (505.4, 24.9, 481.2) | bridge over a river (reviewed, nothing changed) |

## 1. The "yellow" is not grading

F9 marked a cell "town / road grade" when a `TerrainGradePatch`'s bounds met
it (`HeightfieldRegion.has_grade_in`). A graded region carries its grade only
as native lattice controls (`native_control_heights`); its `terrain_grades`
list is empty, so the flag was always 0 and F9 never drew grade yellow at
all. The yellow was the overlay averaging the colours of a quadrant's two
edges: orange (dying cliff) + green (slope). Photos 6/7 are 350+ m from the
nearest town.

- `FieldTerrainStreamer._cell_snapshot` flags exactly the cells whose native
  control a town moved (pads, collar, pad support, road ramps).
- The overlay shader lets the stronger edge own the colour (a thin blend at
  the quadrant diagonal) instead of averaging, draws the grade as yellow
  diagonal stripes no blend can imitate, and the dying-cliff orange is deeper.

### What the deformation actually is

A cliff edge whose corner ring is slope-connected "dies" there
(`TerrainSurfaceField._edge_control`, September 27 coordinator review): its
high side lowers the edge midpoint halfway toward that corner, so the wall
fades along the whole 24 m edge. The midpoint is a control of both quadrants
along the edge, while the far corner still stands at the full height, so the
plateau beside the edge sags into a spoon-shaped trough (the U-shaped
contours and the grassy bowl in photo 7). Kernel hillshade with and without
the lowering: `images/kernel_p7_dying_vs_plain.jpg`.

**Follow-up (owner): standardize.** The special case is removed
(`TerrainSurfaceField._edge_control`): every edge is flat, a one-storey
smootherstep slope, or a full-height cliff, and a cliff whose corner ring is
slope-connected ends through the ordinary corner blend in its last half
cell. Plateaus beside a cliff stay level. F9 lost its dying category.
`test_a_cliff_keeps_its_height_and_ends_through_the_standard_corner` replaces
the September 27 fade test (red: the plateau sat 1.6 m low at (-4, 6));
`test_september15_grade_topology` no longer exempts ending cliffs.

That exposed one more seam at photo 3: the end ramp (up to ~60 deg) is
terrain the sheet merely covers, and the sheet's moss was gated by its lift
over the terrain (September 28), so the ramp stayed lawn beside the mossy
face. The sheet's colour is now a function of steepness alone: exactly the
terrain's lawn up to the steepest ordinary slope (one storey plus three
levels, 47.6 deg, `SHEET_LAWN_STEEPNESS`), fully mossy from 60 deg.
`test_sheet_moss_depends_on_steepness_alone` (red: 0.32 grade error).
`images/standard_p3_three_steps.jpg` (dying rule / standard ends / plus
colour by steepness), `standard_p1_three_steps.jpg`,
`standard_p7_p6_p10_p2_p4.jpg` (left before, right final).

## 2. Seams: grass stopped where the slope sheet took over

Photos 1, 3, 10 (and the dark halos in 4, 5): dense terrain grass ended on a
straight line at a cliff's wall line and the rounded slope sheet beyond it
carried quarter-size clumps. Layer isolation (sheet hidden / terrain hidden)
shows both meshes have the same lawn colour; the line is the grass.

Root cause: `GrassSupportSurfaces.footprint_scale` shrinks a clump until its
root plane stays within 6 cm over the sheet under its whole footprint. On a
rounded crest (1.5-4 m shoulder) that allows only a quarter-size clump.
Terrain grass has no such test and floats 0.2-0.4 m over the terrain
kernel's own convex bends. The sheet now allows the same float as the terrain
(`FOOTPRINT_FLOAT` 0.2 m; sinking stays 0.25 m), so benches and folds still
shrink a clump but a smooth crest does not.

Synthetic 16 m cliff, real rock-sheet + grass workers, grass area per metre:
plateau 130 -> crest 10 (8%) before, 55-75 (40-55%) after; the steep face
stays almost bare. `test_grass_carries_over_a_rounded_crest_without_a_line`:
crest/plateau area 0.077 before, 0.35 after.

Renders (`images/seam_p{1,3,4,5,7,10}.jpg`, left before, right after): the
straight grass line in 1 and 10 is gone; grass runs over the crest and
thins as the face steepens; 3's mound keeps a softer grass edge (it is
steep); the moss band now starts where the face steepens.

Photo 4's pale line is the sheet's bedrock exposure just above the water
(the relief measured to the water surface, `CliffSlopeEnvelope`); unchanged.

## 3. Road divots

Photo 8 (cell (12..14, 20)): the town `settlement.45e145055531090d` at
(122..302, 408..600) blends its 12 m collar into the road: road cell (12,20)
went 16 -> 12.79 -> rounded 13 m, one storey down, next to (13,20) at 20 m: a
two-storey cliff across the road. `_grade_roads` then lowered (13,20) to its
lowest 3x3 neighbour + 4 = 17 m, which walled it against (14,20) at 24 m,
outside the ramp's reach. The envelope rounded both walls into the hump and
trench.

`NativeTerrainGrade._grade_roads` is now a relaxation along the accepted road
edges (not 3x3 neighbourhoods), run last, after the pad-support raise that
could also lift a road cell 8 m (town (1,-1)): lower a free road cell
standing two storeys over its road neighbour to one storey above it, then
raise one standing two storeys under it to one storey below. Town claims and
road cells beyond the reach are fixed; only road cells move. For photo 8 the
road ends on its natural 12, 16, 20, 24 m.

Corpus (`tests/harness/road_grade_walkability_probe.gd --radius 2`, 23
towns): 5 broken road edges in 3 towns before, 0 after.
`images/road_p8.jpg`, `images/road_p9_categories.jpg`.

## 4. Stray cliffs near towns (follow-up)

Off the roads, the town collar's blend is rounded to whole metres, so a
blended cell could land a storey or more off its natural height beside an
untouched neighbour: a natural slope became a cliff and the sheet rounded
it into a stray mound (e.g. town (0,-2): (17,-50) 4 -> 10 m beside 0 m).
`NativeTerrainGrade._relax_free` pulls free cells back toward their natural
height, never past it, until every natural slope between two free cells is
a slope again (always possible: natural neighbours are a slope). Pad
owners, pad-support cells and regraded roads are construction
(`NativeTerrainGrade.construction_cells`) and never move; a cliff against
them is the construction's retaining edge. The pass runs before the road
relaxation and again after it with road cells fixed.

Corpus (23 towns, radius 2): new cliffs between free cells 40 -> 0;
retaining edges against construction 130; broken road edges still 0.
`test_town_grades_make_no_new_cliffs_between_free_cells` (red with the pass
disabled). Height map at town (0,-2), before/after:
`images/town_free_cliffs_heightmap.jpg`. Town-grading suites green:
`test_september15_grade_topology`, `test_graded_cliff_construction`,
`test_september13_village_grade`, `test_september7_continuous_street_grade`,
`test_september7_street_ownership`, `test_terrain_grade_patch`,
`test_september8_night_ground_crease`, `test_september27_road_grade`.

## Tests

`tests/test_september29_terrain_review.gd` (5), with three frozen towns
(`tests/fixtures/september29-road-divot-*.var.gz`, frozen by
`road_grade_freeze.gd`):

- `test_category_snapshot_flags_exactly_the_graded_cells` (red before: 0 flags)
- `test_reported_road_keeps_its_natural_climb_out_of_the_town` (red: 17/24 wall)
- `test_town_grades_leave_every_natural_road_edge_walkable` (red in all 3)
- `test_road_grading_moves_only_road_cells` (guard)
- `test_grass_carries_over_a_rounded_crest_without_a_line` (red: 0.077)
- `test_sheet_moss_depends_on_steepness_alone` (red: 0.32)
- `test_september27_edge_slopes`: the cliff-end test rewritten for the standard
  rule (red on the dying rule); all 10 pass.

Regression runs (all green): `test_september28_category_overlay`,
`test_september27_road_grade`, `test_terrain_grade_patch`,
`test_september15_grade_topology`, `test_graded_cliff_construction`,
`test_september13_village_grade`, `test_september7_continuous_street_grade`,
`test_september7_street_ownership`, `test_september8_night_ground_crease`,
`test_september15_water_profile_work`, `test_terrain_chunk_mesher` (51),
`test_grass_field` (16), `test_september16_cliff_grass`,
`test_september17_support_refinement`, `test_september19_bank_grass_water`,
`test_september19_inner_water_ownership`, `test_september26_bedrock`,
`test_p03_cliff_followup` (10), `test_september27_rock_placement` (10),
`test_september28_ground_seams`.

Failing identically with this change removed (not regressions):
`test_september15_cliff_vegetation`, `test_september13_terrace_hierarchy`,
`test_september13_terrace_grass` (stale kaykit terrace UIDs),
`test_september9_flat_collision` (legacy fine-grade fixture),
`test_september15_grass_lips` (script error in the fixture),
`test_september10_grass_sampling` (Sep 27 baseline list),
`test_village_outskirts_construction`, `test_september9_road_exit` (village
layout work in progress in the tree).

## Open

- A cliff that ends in a hillside now ends within its last half cell: the
  end ramp is steep (up to ~60 deg), rounded across by the sheet but not
  along the wall.
- Pad-support cells (lifted to hold a pad) keep a retaining edge against
  lower natural ground next to them; they are construction, not moved.
