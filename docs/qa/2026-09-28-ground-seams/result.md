# Ground seams, inner-corner cut-outs, water spikes (September 28)

Owner photos 1-5, seed 2697992464, all taken with the close mouse-view camera
(boom 8.2 m from a pivot 3.2 m over the player). Renders reproduce them with
`tests/harness/cliff_site_review.tscn --full --grass --categories` and views
solved from the F3 player/crosshair readouts (camera = pivot - 8.2 m along the
pivot->crosshair ray). Evidence JPGs are on disk only (`images/`, gitignored).

| Photo | Player | Reported |
|---|---|---|
| 1 | (509.4, 16.0, 1145.8) | seam along a slope foot; small "platforms" either side of a cliff |
| 2 | (713.5, 9.8, 1451.5) | two seam strips; a shallower cross slope |
| 3 | (377.0, 41.5, 994.1) | a seam strip down the slope |
| 4 | (827.2, 28.0, 1427.2) | spikes, sharp corners, water not pouring smoothly |
| 5 | (491.0, 34.9, 1742.9) | L-shaped seam, a seam band, an inner-corner cut-out |

## What the seams were

The visible ground is two meshes: the terrain sheet (2 m chords of the field)
and, around cliffs, the `sheet` slope solid (0.5 m surface nets of the rounded
envelope). Every seam was a place where the eye switched from one to the other
and the two did not match.

1. **Normals.** The terrain sheet used `SurfaceTool.generate_normals`: facet
   averages over each chunk's own triangles. Along every 192 m chunk border the
   average is one-sided (photo 3's strip is the x = 384 border), and everywhere
   it differed from the solid's exact gradient normals. Now
   `TerrainChunkMesher.field_normals` gives each vertex the exact gradient of
   the surface it lies on (C1 away from cliff edges, so both owners of a seam
   agree). Red first: 0.071 normal mismatch across the border, 0.060 from the
   gradient; both 0 now.
2. **Crease where the solid emerged.** The solid stayed 2-14 cm under the
   terrain until the envelope stood 0.15-0.5 m above the ground, so it broke
   through at an angle along every slope foot, and its normals (of the
   envelope) differed from the terrain's there. It now lies on the terrain's own
   chords plus 1 cm (`COVER`) where the lift is nil and blends to the exact
   envelope as the lift grows: coplanar where it meets uncovered terrain.
   Roads/plazas/towns (`env.excluded`) keep the old sunk backing so paint shows.
3. **Colour.** Moss on the solid was driven by steepness alone; the terrain
   never takes moss, so an ordinary slope the solid merely covered turned
   darker. Moss grade is now scaled by the lift over the ground. Both meshes use
   the same 24 m cell-centre tint lattice (the solid used a 3 m lattice).
4. **Grass.** Grass on the solid passed a footprint-flatness test against
   surface-net facets and dwindled to tiny clumps on curved feet: the smooth
   grass-less strip in photo 1. Where the solid stands < 0.1 m over the terrain
   the terrain's own grass grows (`GrassField.SUPPORT_MIN_LIFT`).
5. **Crest.** The across-wall shoulder started at the last node inside the
   high cell, 0.5 m before the wall line where the terrain's flat top ends: a
   slope kink along every crest (photo 5's L). It now starts at the wall line.

## Cut-outs and water spikes

Photo 5's inner-corner "cut-out" and photo 4's pale prism and green fins were
the same mechanism: rounded walls reaching into a pool were sliced by planar
54-degree water caps (`WATER_REACH`), a steep receiver slot, and a 2 m block
wet mask, leaving pits, prisms and fins. The water no longer cuts the slope:

- banks round down to the carved bed; the water covers what lies below its
  surface and the shore is where the bank rises out of it;
- a wall does not round from a wet crest (water pouring over it stays visible;
  `test_september27_mountain_water` cascade);
- a wall facing a broad corridor (>= 2 x `CHANNEL_CORE` = 16 m) is fitted: its
  analytic closed profile (shoulder, then foot fillet) is squeezed across the
  wall so the bank goes under the water a quarter core short of mid-channel,
  the squeeze varying smoothly along the wall; the concave-crease fillet never
  rises above the water there (it dammed channels). Narrower pockets are
  absorbed by the bank, as ruled on September 26;
- levels are queried per node at the shore and wherever the level changes
  (interpolating across a level step raised bedrock above a stepped river);
- no bedrock benches below the water surface.

The water MESH itself is unchanged: it is solved on the kernel terrain, so
where water leaves a cell over a fall it still descends as the kernel's
square-cornered sheet (see "Open").

## Why some geometry deviates from the standard slope

There are still two edge categories (not tile categories): a side whose
storeys differ by one is the smootherstep slope, two or more is a cliff edge
(wall). Heights are storey x 4 m + level x 1 m, so a "slope" edge spans 1-7 m
and a same-storey level edge 1-3 m: a shallower cross slope (photo 2) is a
level edge or a small storey step. Deviations from the plain kernel come from
the cliff envelope only: rounded shoulders and feet around cliff edges; a
cliff that dies into a slope (its corner ring is slope-connected) fades along
its edge and ends in a round blob, whose widened shoulder reads as a small
platform (photo 1 has a two-cell, 8 m cliff dying at both ends); bedrock
benches (treads >= 1.75 m) on tall faces; ridge/bump noise on faces over
4.5-8 m relief. The F9 view shows all of these.

## Diagnostic view (F9)

`TerrainCategoryOverlay` draws one full-screen deferred decal over every
rendered surface from `FieldTerrainStreamer.loaded_cell_at` snapshots (cell
height + graded flag). It re-evaluates the terrain kernel in the shader:

- grey: plateau (cell centre); green: 1-storey slope edge; blue: same-storey
  level edge; red: cliff edge; orange: dying cliff;
- magenta / cyan: rendered above / below the slope kernel (envelope, bedrock,
  rocks / cuts); yellow: town or road grade;
- thin dark lines every metre, white every storey (4 m), black cell grid, blue
  192 m chunk borders. Grass is hidden while it is on.

## Tests

- `tests/test_september28_ground_seams.gd` (5): chunk-border normals, exact
  gradient normals, shoulder starts at the wall line, solid flush on the
  terrain chords, pocket-pool banks without cut creases. All red on the
  previous code (the pocket-pool test: 0.45 crease and a non-monotone bank).
- `tests/test_september28_category_overlay.gd` (3).
- Envelope/slope suites green: `test_p03_constrained_cliffs` (12/13; the one
  failure, "ledges return across distinct patches" 8 > 8, is the baseline
  failure), `test_p03_cliff_followup`, `test_september26_bedrock`,
  `test_september26_manual_cliffs`, `test_september27_edge_slopes`,
  `test_september27_slope_ledges`, `test_september27_mountain_water`,
  `test_september27_rock_placement`, `test_september27_road_grade`,
  `test_september15_water_drops`, `test_cliff_sheet_normals`,
  `test_terrain_chunk_mesher` (51), `test_terrain_surface_field`,
  `test_terrain_september6`, `test_terrain_tinting`, `test_grass_field`,
  `test_grass_streamer`, `test_september15_grade_topology`,
  `test_september16_cliff_grass`, `test_september17_cliff_grass_seams`,
  `test_september19_bank_grass_water`, `test_september13_terrace_grass`,
  `test_field_streamer`.
- Unchanged failures, independent of this change: `test_cliff_dressing`
  (40/44, baseline), `test_september10_grass_sampling` (script error, in the
  Sep 27 baseline list), `test_september13_water_turf` (native cliff piece
  count; `CliffDressing` untouched), `test_field_streamer` 15/16 and
  `test_september13_terrace_grass` 2/3 (stale-UID warning), both listed as
  known failures in the September 26/27 baselines.
- `test_p03_constrained_cliffs` ledge-area assertion now counts dry ground
  only: all 19 benches it lost stood inside the fixture's 11 m deep tarn (dry
  ground: 35 before, 32 after).

## Evidence

`images/photo{1,2,3,4,5}_before_after.jpg` (left: start of the session,
right: final; same mouse-view cameras), `images/photo4close_before_after.jpg`
(a closer oblique of the water site), `images/photo{1..5}_categories.jpg` (the
F9 view of each final render).

- Photo 1: the grass-less strip along the dying cliff's foot is grass again;
  the dome's rounded crest highlight is lighting, not a seam.
- Photo 2: both strips gone; the ground is one continuous surface.
- Photo 3: the broad smooth band is gone. What remains is the lawn-to-moss
  change at the crest of a 12 m cliff (the sheet's own moss grading on the
  rounded shoulder), not a mesh mismatch: unshaded renders show the terrain
  and the sheet with identical albedo on the plateau.
- Photo 4: the pale prism and the green fins are gone; the rounded banks run
  into the pools. The kernel water's square fall sheet is now more exposed.
- Photo 5: the L-shaped band and the inner-corner cut-out are gone.

A render-only rounding of the water surface at falls (the envelope closing on
the 2 m water lattice) was tried and rejected: it made the fall a faceted,
bulging lobe. WaterSkin is unchanged.

## Open

- The water mesh at falls still follows the kernel's square cells; a water
  surface draped over the rounded lip needs WaterSkin to read the envelope.
- Dying-cliff blob ends (the `LOW`/`WIDEN` shoulder) still read as small
  platforms; left as ruled on September 27.
