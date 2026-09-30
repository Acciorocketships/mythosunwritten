# Slopes: per-edge slope versus cliff, the photo-12 divot, path-side glitches

Owner judging pass, September 27, seed 2697992464. Stream `slopes`, branch
`judge-slopes`.

## Proposed AGENTS.md paragraph

> September 27 judging pass, slopes (owner photos 12 and 9): slope versus
> cliff is decided per EDGE, not per tile. A cardinal side whose storeys
> differ by two or more is a cliff edge (`TerrainSurfaceField.is_cliff_edge`,
> high side `is_wall_edge`); every other side, including the one-storey side
> of a cell that walls elsewhere, is the ordinary smootherstep slope. The
> owner's "one level" is one 4 m storey: the cliff rule was already "two
> storeys or more", but it made the whole cell a flat cliff top, so its
> one-storey sides were 4 m walls. Controls: a slope edge takes the pairwise
> minimum, a cliff edge keeps each owner's height, and a corner is the minimum
> over the slope-connected component of its four cells, so every slope seam,
> corner and T-junction stays single-valued; a cliff edge whose ring is
> slope-connected around its corner tapers to zero there (a cliff running out
> into a hillside). Diagonals never wall by themselves. The mesher skirts only
> cliff edges, with the top following the cell's own boundary; walkability is
> `not is_cliff_edge`; native KayKit pieces dress fully flat cells as before
> plus the flat slots of a sloped cliff cell. The `sheet` envelope closes only
> the CRESTS of ground discontinuities (`CliffSlopeEnvelope._close_walls`):
> the old closing of the whole ground lifted every sloped plane by
> s^2 SHOULDER/2 (0.57 m on a one-storey slope) and cut that lift back at
> every road, which was the photo-9 jagged edge and dark/light strip, and
> the photo-12 groove was a one-storey wall plus a partial wall at a corner
> dip. `LOCAL_RELIEF` is removed; bedrock needs the envelope's own rounded
> face. Unrecessed skirts measure envelope coverage from the cell edge
> (a 2 cm skirt top otherwise showed as a black crest line), and the slope
> solid's unraised margin follows the rendered 2 m terrain chords. Tests:
> `test_september27_edge_slopes` (5 of 6 red on baseline); tile-era fixtures in
> `test_terrain_surface_field`, `test_terrain_chunk_mesher`,
> `test_cliff_dressing`, `test_september15_grade_topology`,
> `test_september15_water_drops`, `test_september13_world_paths` updated to
> two-storey walls or to the per-edge assertion (this supersedes the older
> rulings that a one-storey notch is an inner-corner cliff and that a cliff
> top walls every drop, and the slope-ledges pass's statement that every
> storey cliff, including a single storey, takes the envelope). Cliff ends
> (coordinator review): where a cliff edge's corner ring is slope-connected
> the cliff dies there; its high side lowers the edge midpoint halfway toward
> that corner (`TerrainSurfaceField._edge_control`), so the wall fades along
> the whole cell edge. The envelope closes each wall ACROSS itself only
> (walls are cell edges: 1-D closings along the grid axes), convex corners
> isotropically, then fillets concave creases with one equal-radius closing
> (FOOT) where walls are rounded: a crest descending along its wall no longer
> spills a raised curled nose over the sloping top. Walls are found where
> the terrain's two owners differ at a cell boundary, down to any height, so
> a dying cliff is rounded to its very end, and below `LOW` (3 m) its
> shoulder widens as LOW/H (at most `WIDEN` 20x): the face ends in a round
> blob, not a spike (other discontinuities of 2 m between nodes still count,
> for synthetic grounds). Faces under `LOW_WALL` (1.5 m) are drawn as turf;
> skirt coverage is tested per skirt column; the unraised slope solid sinks
> 0.12 m further on sloping ground. Water: lakes now meet formerly
> walled one-storey banks on the slope (a normal shoreline); a perched water
> slab on a ledge is gone; one-storey table islands become mounds and shrink
> in lakes. The historical photo-16 fixtures were updated (frozen fill kept on
> its flat ledge; the supplied outlet is checked where the dying lip fades).
> See
> `docs/qa/2026-09-27-judging/slopes/result.md`.

## 1. Per-edge slope versus cliff (photo 12)

### Site and root cause

Photo 12: player (397.3, 68.0, 929.4), crosshair (396.4, 68.0, 926.9), cell
(17,39). Probe (`probe_site.gd`, graded production region):

```
          x=14   15    16    17    18    19    20
z=38:   15.0C 16.0C 17.0  17.0  18.0  19.0C 20.0C
z=39:   14.0C 16.0C 16.0C 17.0C 17.0C 17.0C 17.0C
z=40:   11.0C 13.0C 14.0C 14.0C 14.0C 14.0C 14.0C
```

(17,39) drops three storeys south, so the tile rule (`_is_cliff_top`: any
cardinal or diagonal neighbour two or more storeys lower) made the whole
cell a flat plateau at 68 m. Its one-storey west side to (16,39) (64 m)
became a vertical 4 m wall, and the envelope rounded it into a steep
cliff-style bank beside ordinary smootherstep slope tiles. The unit: the
cliff threshold is storeys (4 m); 1 m levels are always part of the slope.

### Change

`TerrainSurfaceField`:

- `is_cliff_edge(c, d)`: `|storey(c) - storey(c+d)| >= 2`. `is_wall_edge` /
  `_is_wall_edge`: the high side of one. `_is_cliff_top`: has a wall edge
  (cardinal only).
- `_edge_control`: slope edge = `min(h, h_nb)` (both owners name the same
  value); cliff edge = the owner's own height.
- `_corner_control`: the four cells around a corner form a ring; the corner
  is the minimum height over the slope-connected component of the cell in
  that ring. Every member computes the same component, so a corner is
  single-valued wherever a seam is. This also reproduces the inner-corner
  rule (level arms walling a two-storey pocket keep the corner at their
  height) and replaces the special cases in `_quadrant_corner_height`.
- No flat-cell shortcut in the surface; `bake_cell` flags a cell flat when
  all its controls equal its height. `is_flat_cell` = renders flat and walls
  (or owns an inner corner); legacy dressing keys off it.
- `own_edge_flat` samples the cell's own boundary (`own_edge_profile`).
- `is_walkable_edge` = `not is_cliff_edge`.

`TerrainChunkMesher`: skirts on `is_wall_edge` only, top = the cell's own
boundary profile (flat along a cliff side, descending where a slope side
carries the corner down); recessed only under native pieces (flat cells).
`CliffDressing`: `_sloped_cliff_cell` places straight wall/lip pieces on the
flat slots of a cliff cell with slope sides (keeps rock foot lines); ghost
inner corners test `is_wall_edge` for a continuing diagonal wall.
`GrassField`: cliff masks from `is_wall_edge`.

`CliffSlopeEnvelope`: see section 3; the same change removes the envelope
from one-storey sides: `F = max(g, erode_foot(max(g, dilate(crests(g)))))`
where `crests` are the high nodes of 0.5 m neighbours differing by
`JUMP` = 2 m. A wall keeps exactly its former rounding (identical for a
step); continuous ground, however steep, keeps its own surface.

Corners where a slope side meets a cliff side:

- Clean case (photo 12, cell (17,39)): its south cliff edge's top descends
  from 68 to 64 over the west half, meeting (16,39); the wall below goes
  from 12 m to 8 m. Seams (17,39)|(16,39) and every corner around (396,924)
  are single-valued (all four owners meet at 64 m there; test).
- Wrap case (a ring slope-connected around a cliff edge's end, e.g. cells
  (14..15,38..39)): the cliff tapers to zero at that corner inside the high
  cell. Single-valuedness forces this: every slope seam around the corner
  must agree at the corner point and no cell may ramp up. The taper is the
  only non-standard slope; it is steep (up to about 51 deg for two storeys).

### Tests (red on baseline -> green)

`tests/test_september27_edge_slopes.gd` (6 tests). Baseline run
(`red-baseline.txt`, with a two-function storey shim so the file parses):
5 fail, 1 passes (the varied-field guard).

| Test | Baseline | After |
|---|---|---|
| one-storey side of a cliff cell equals the standard slope tile (every point) | fail (flat 16 m vs 12 m) | pass |
| only cliff edges double-valued (4 seeds incl. 2697992464) | pass (guard) | pass |
| rock skirts only on cliff edges, tops on the ground they back | fail (144 skirt vertices on the slope seam) | pass |
| envelope dresses the cliff, not the one-storey side | fail (1.62 m lift) | pass |
| ordinary slope beside a road keeps its surface (photo 9) | fail (0.57 m) | pass |
| reported site (17,39): west side walkable, corner (396,924) single-valued | fail ([64,64,64,68]) | pass |

## 2. "We don't need this divot" (photo 12)

Root cause: two tile-rule walls at the corner (396, 924). The long leg was
the rounded 4 m wall between (16,39) at 64 m and flat (17,39) at 68 m. The
short leg along z = 924 was a partial wall: (17,38) (68 m) dipped toward
its corner (four-cell minimum 64 m) while the flat cliff top (17,39) stayed
at 68 m, exposing a wedge that deepened toward the corner; the envelope
rounded both into an L-shaped trench. With per-edge controls both seams are
single-valued smootherstep slopes; the corner is an ordinary slope dip.

Evidence: `images/p12_shot_before_after.jpg`, `images/p12_plan_before_after.jpg`,
`images/p12_side_before_after.jpg` (before = baseline worktree, after = final
code, same `cliff_site_review --shot` camera). The groove is gone; the
one-storey terraces on the plateau behind are smooth slopes.

## 3. Path-side glitches (photo 9)

Site: player (-165.4, 11.0, 1099.3), crosshair (-169.7, 10.7, 1099.3),
storeys 3 2 2 / 3[3]2 / 3 3 3: only one-storey slopes, no cliff. Not
path-specific in origin: the envelope's closing (dilation radius larger than
erosion radius) lifts any sloped plane by s^2 SHOULDER/2; on a smootherstep
storey slope that is 0.57 m (`ramp_lift.gd`), above `RAISED` (0.15), so the
slope solid (another colour, other grass) covered the middle of every
ordinary storey slope. `LOCAL_RELIEF` (24 m window relief >= 3.2 m) did not
exclude them. A road caps the envelope with a 1.4-grade cut from its edge,
so beside a path the lifted solid was cut back to the ground: the jagged
edge, light cut strip and dark solid strip. The fix is the crest-only
closing (section 1): plain slopes are no longer lifted anywhere, so there is
nothing to cut. `ramp_lift.gd` now reports 0.000 m everywhere.

Evidence: `images/p9_shot_before_after.jpg`,
`images/p9_path_edge_zoom_before_after.jpg`, `images/p9_plan_before_after.jpg`.
Survey of other road-beside-one-storey-slope sites (`road_slope_sites.gd`):
24 road cells beside a one-storey slope in blocks (-2..3, 4..6). Two more
sites rendered before (baseline worktree) and after, same cameras:
`images/survey_{s1,s2,plans1,plans2}_before_after.jpg`. Road along x = 216
(z 768..888, slope to the west, plans1): the baseline has two dark solid
strips running parallel to the road on the slope, gone after. Road along
x = 240 (z 984..1032, plans2 / s2): the baseline has a pale strip beside
the road and a darker, differently textured patch on the slope beyond; after
the slope is uniform. The real river-valley cliffs in the same views keep
their envelope, moss and bedrock. The s1 camera sits in tall grass and is
not informative.

Corpus probe `tests/harness/road_grade_walkability_probe.gd --radius 1`
after: 9 towns, 0 bad edges (`road_grade_probe_after.txt`). No town needed
a road ramp any more (the September 27 dead-end fix ramped (48,22)
32 -> 28 m before); the frozen `test_september27_road_grade` still passes.

## Falsification and collateral checks

- Hot-reload iterations at photo 12 (not committed) exposed and fixed, in
  order: (a) a gate by distance to cliffs lifted one-storey ramps near
  cliffs (a pale blob and strip); (b) a one-sided gate made curls at taper
  ends; both replaced by the crest-only closing. (c) Unrecessed skirts on
  descending cliff sides kept their top 2 cm above the slope solid: black
  lines along crests (`skirt_probe.gd`, `ray_probe.gd` located one at
  z = 947.75 on the (17,39) crest); fixed by measuring coverage from the
  cell edge. (d) Teal patches where the solid's margin (2 cm under the exact
  surface) showed through 2 m terrain chords on steep taper ground; fixed by
  following the chord height where the envelope is not raised. A variant
  that rose out of the chords by the envelope lift made more streaks and was
  rejected.
- Nearby views after (`images/p12_after_{hookA,hookE,hookW,crest}.jpg`): crest
  lines gone, hookE and crest clean; hookA (the crest step 68 -> 64 m) smooth.
- Chunk independence: the envelope still depends only on ground inside its
  32 m pad (crest dilation reach sqrt(2 H 10.9) < 32 m for H <= 47 m).

## Test results

`tests-baseline.txt` / `tests-after.txt` (one GUT file per headless run,
`run_tests.sh`). Baseline = the worktree's baseline commit `db59f0c8` in a
temporary separate copy (deleted afterwards), plus the two-function storey
shim for the red run of the new file.

- 76 test files run: 35 terrain/cliff/slope/path/grade files and 41 further
  files that reference `TerrainSurfaceField`, the envelope or the slope field.
- Every file has the same pass/fail counts as baseline, except
  `test_september27_edge_slopes`: new, 10/10 (5 of the first 6 red on the
  baseline, the 3 cliff-end tests red on 22fa7da6, the blob test red on
  26b0ad94).
  `test_september10_water_surface` is 9/9 after the fixture update (4.3).
  (Final run after the coordinator review: `tests-after.txt`.)
- Baseline failures that remain unchanged (not caused here): `test_cliff_dressing`
  3 (carved-pocket fixtures), `test_p03_constrained_cliffs` 1,
  `test_september13_cliff_dressing` 2, `test_september23_cliff_directions` 2,
  `test_september8_river_banks` 2, `test_water_contour` 3, `test_field_streamer`
  1, `test_september11_cliff_terraces` 2, `test_september16_cliff_grass` 1,
  `test_dressing_field` 1, `test_path_plan_nodes` 1,
  `test_september10_ceiling_courses` 1, `test_september11_unified_city` 1,
  `test_september13_terrace_grass` 1, `test_september13_terrace_hierarchy` 1,
  `test_september15_moss_rocks` 1, `test_september8_night_lamp` 1,
  `test_september9_flat_collision` 2, `test_september9_grass_lip` 2,
  `test_warren_maze_composition` 17, `test_water_skin` 5;
  `test_september10_grass_sampling` and `test_village_reported_ground` end in a
  script error on both.
- Updated tile-era fixtures (their invariant is kept on two-storey walls, or
  replaced by the per-edge assertion where the premise itself was a one-storey
  wall): `test_terrain_surface_field` (6 tests), `test_terrain_chunk_mesher`
  (about 10), `test_cliff_dressing` (about 20), `test_september15_grade_topology` (crowns
  stay level along their cliff sides), `test_september15_water_drops` (a taller
  neighbour two storeys up), `test_september13_world_paths` (a hillside node's
  faces are walkable exactly when they are not cliff edges), and after the
  review `test_september10_water_surface` (4.3).

## Scripts in this folder

- `probe_site.gd -- --cell X,Z`: storeys, levels and cliff flags around a cell
  (graded production region).
- `ramp_lift.gd`: envelope lift over a synthetic one-storey slope.
- `road_slope_sites.gd -- --blocks A,B:C,D`: road cells beside one-storey slopes.
- `photo16_probe.gd`: storeys and water around the photo-16 fixture lip.
- `skirt_probe.gd`, `ray_probe.gd`: `cliff_site_review` probes (copy under
  `res://tests/` and write the path to `<output>/probe`).
- `run_tests.sh OUTDIR test_a test_b ...`: one headless GUT file per run.
- Renders: `cliff_site_review.tscn --full --plain --grass --shot p12:397.3,68.0,929.4:396.4,68.0,926.9`
  (and `p9:-165.4,11.0,1099.3:-169.7,10.7,1099.3`), before in the baseline
  copy, after in this worktree; full-size PNGs were in the session scratchpad,
  the composites are in `images/` (on disk; `docs/qa/**/*.jpg` is gitignored).

## 4. Coordinator review: cliff ends, streaks, water

### 4.1 Cliff ends (was open item 1)

**Two causes.**

1. *Stepped crest (hookA, the reported "darker curled nose").* The crest of
   (17,39)'s south cliff steps down 68 -> 64 m along the wall. The envelope
   dilated the crest line isotropically: along a crest with slope s it spills
   over the sloping top beside it and above the crest in front by
   s^2 SHOULDER/2 (0.3-0.8 m), a raised darker nose with a crisp outline.
2. *Dying cliff (hookW, dieB/C/D).* Where the ring around a cliff edge's
   corner is slope-connected, the corner meets the low side and the whole
   drop (8-12 m) happened inside one 12 m quadrant (51-62 deg), plus the same
   isotropic spill.

**Change.**

- `TerrainSurfaceField._edge_control`: for the high side of a cliff edge,
  each "open" corner (its corner control is at or below the low side's
  height, i.e. the cliff dies there) lowers the edge midpoint to halfway
  (`(h + corner)/2`, the lower of the two for a cliff dying at both ends).
  The seam is double-valued so only the owner reads it; every slope seam and
  corner stays single-valued. The wall now fades 12 -> 6 -> 0 m (or 8 -> 4 ->
  0) along the full 24 m edge; the crest falls no steeper than an ordinary
  one-storey slope.
- `CliffSlopeEnvelope._close_walls`: walls are cell edges, so they run along
  a grid axis. Each wall direction's crests are dilated and eroded ACROSS the
  wall only (1-D along the other axis): in front of a crest c(x) this is
  exactly c(x) - y^2/(2 SHOULDER), and the ground itself behind, for any
  crest profile. Convex corners (crests of both directions) keep the
  isotropic closing (slopes still round corners in plan). One equal-radius
  closing (FOOT) of the rounded walls then fillets concave creases (inner
  corners, feet); equal radii preserve planes and convex shapes, so it neither
  lifts slopes nor spills. It is weighted by the envelope's own lift, so the
  ground's natural concave bends are untouched.
- `TerrainChunkMesher` draws skirt quads lower than `LOW_WALL` = 1.5 m with
  the turf texel: the last metre of a dying wall reads as a turf step, not a
  dark rock tick. (The crest fade used here at first was replaced in 4.4.)
- `uncovered_faces` tests each skirt point against the skirt's own top and
  drop in its column (the triangle's highest vertex hid nothing along a
  descending crest; walls under 1 m had no "low side").

**Evidence** (before = the reviewed commit 22fa7da6, after = final; same
cameras, one fresh process each):
`images/ends_{hookA,hookW,planA,planW,dieB,planB,dieC,planC,dieD,planD,p12}_before_after.jpg`.

- hookA / planA: the nose at the crest step is gone; the rounded wall follows
  the descending crest.
- hookW / planW (two-storey cliff dying at (348,924)): the curled nose and the
  teal streaks become a face that fades along the edge into the slope.
- dieB / planB (a staircase of two-storey cliffs dying at (396,780), (372,756),
  (420,804)): rounded hook ends become faces fading into rounded ends (4.4).
- dieC / planC (a one-cell cliff (12,25) dying at both ends): a rounded dome
  becomes a low face fading at both ends.
- dieD / planD (the only three-storey dying cliff found, a river bank at
  (612,996)): the face and its rock shrink toward the dying corner.
- A variant without the midpoint lowering (1-D closing only) was rendered as a
  control: its ends stay rounded hooks (dieB, hookW). Rejected.

**Tests.** `test_september27_edge_slopes` gained three tests, red on the
reviewed commit, green now: `test_a_dying_cliff_fades_along_its_whole_edge`
(midpoint 20 -> 16 m, crest slope 1.24 -> < 0.7),
`test_no_raised_nose_on_a_crest_that_steps_down` (0.81 m -> < 0.05),
`test_no_raised_nose_where_a_cliff_dies` (2.46 m -> < 0.05).
`test_september15_grade_topology` now checks crown flatness only along
continuing cliff sides.

### 4.2 Teal streaks (was open item 2)

Gone at hookW with 4.1. A few dark specks remained on the three-storey taper
(dieD): the unraised slope solid, 2 cm under the exact surface, crossed the 2 m
terrain chords on steep curved ground. The unraised solid now sinks a further
`DEEP` = 0.12 m where the terrain slopes (flat cliff tops keep 2 cm, where the
solid draws the band behind hidden lips). dieD after: no specks.

### 4.3 Water (was open item 3): a fixture expectation, not a current-world regression

**Current world.** `water_dump.gd` sampled every block with carved water in
blocks (-4..4, 2..8) on a 2 m lattice, baseline (tile rule, db59f0c8) versus
final: 50,022 vs 50,889 wet samples; 1,030 gained, 163 lost.

- Gained (1,030, depth mostly 0.7-2 m, 40% adjacent to old water): lakes rising
  onto banks that were flat one-storey cliff tops and are now slopes, to their
  own contour with depth -> 0 at the edge (`water_site.gd --at -570,864`):
  exactly how water meets an ordinary slope. Render:
  `images/water_bank_before_after.jpg`, `water_planBank_before_after.jpg`
  (no gap or step; the shoreline follows the slope).
- Lost (163): 144 are one perched water slab on an 8 m ledge (11,61) beside a
  river at 0-2 m, with levels 8.1 m directly over 0 m ground (a vertical water
  wall): `images/water_ledge_before_after.jpg`, `water_planLedge_before_after.jpg`.
  The rest are 6-7-sample films at fall lips that now cross where the lip is
  lower; the dry gap between a descending reach and its pool shrank (e.g.
  (872,384): two dry samples before, one after).
- One-storey table islands in lakes become mounds and shrink; a foreground
  hill at (848,408) goes under the 17.7 m lake (`images/water_fall_before_after.jpg`).
  Most of that change is the per-edge rule itself (the reviewed commit shows it
  too), the midpoint lowering adds a little. This is the requested geometry:
  a one-storey side is a slope.
- Sheet-edge heuristic (wet samples > 0.3 m deep next to dry): 4,765 vs 4,788
  (+0.5%), the same distribution by 48 m block.

**Photo-16 fixtures** (`test_september10_water_surface`, frozen historical
geography). With the dying-cliff midpoint, four tests failed: the lip cell
(29,-72)'s two-storey lip dies at its south-west corner (ring through (29,-71),
one storey lower), so the lip now fades along its side.

- Three tests evaluate a frozen fill solved over the tile-era flat ledge
  against current ground: the lowered ledge made that fill "enter" 0.36 m
  above ground. That is a stale input pair, not production behaviour. The
  helper now raises (29,-71) to the ledge's storey (commented), which keeps
  the tested rows on a flat 16 m ledge exactly as the fill was solved.
- The supplied-outlet test (production water on the photo geography) now
  checks the lines where the outlet crosses the faded lip (z = -1734, -1731,
  -1728: continuous, steps < 0.03); the 3-6 m band beside the higher north bank
  is dry sloping ground. The higher crown stays dry.

### 4.4 Second review: spikes at dying ends

The coordinator saw thin sharp "water tongues" at the two dieB pond ends.
They are not water: those dark areas are the moss-shaded rounded cliff
faces (the snow biome shades steep slope teal). No dying cliff in that view
touches water (`dying_cliffs.gd`: `wet=false`). The spike was the face
itself: after 4.1 the wall's drop falls cubically toward its dying corner
(smootherstep controls have zero slope there), a fixed shoulder's plan width
falls with the square root of the drop, and crests stopped at 1 m with a
fade, so the face pinched to a point and the last metre of skirt showed as a
thin dark tail (the grass ticks).

**Change** (`CliffSlopeEnvelope._walls`, `_close_walls`): walls are found
where the terrain's two owners differ at a cell boundary (probing the
ground 1 mm either side of each boundary line), down to 2 cm, so the rounding
reaches the dying corner; any other 2 m node step still counts (synthetic
grounds, graded edits). Each crest's parabola is stamped across its wall
toward the low side with a shoulder that widens as LOW/H below LOW = 3 m
(at most 20x). The face keeps its width almost to the end and closes in a
round blob; the widened end is gentle, so its steep-moss colour fades out
instead of ending in a dark point, and it covers the last low skirt, which
removes the dark tail and the grass ticks.

**Evidence:** `images/tips_{dieB,planB,dieC,dieD,hookW}_tile_spike_blob.jpg`
(three panels: tile rule at db59f0c8, the reviewed commit 26b0ad94 with the
spikes, final). `images/ends_*_before_after.jpg` are regenerated tile rule ->
final. hookA stays nose-free.

**Test:** `test_a_dying_cliff_ends_in_a_rounded_blob_not_a_spike`: where the
drop is 0.3-1.0 m the face is still at least 2 m wide (26b0ad94: 0 m, red;
now green).

**Water at dying cliffs** (survey): 117 dying-cliff corners in blocks
(-4..4, 2..8), 48 beside carved water. In the 2 m water lattice around each
(20 m), wet samples with at most one wet neighbour (a one-sample tongue): 0
on the tile rule, 1 on the final terrain (at (876,396)). No water tongues.

## Remaining open items

1. Path routing uses `is_walkable_edge`, so roads may now take the one-storey
   sides of cliff cells; route geometry near cliffs can change.
2. Legacy (non-`sheet`) styles: a cliff side whose top descends into a slope
   side has a bare skirt and no native lip on its descending slots.
3. Water: some one-storey islands shrink or go under water (4.3).
