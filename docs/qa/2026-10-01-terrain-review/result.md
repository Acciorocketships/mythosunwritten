# October 1 terrain review (owner photos 1-5, seed 2697992464)

**Owner follow-up: section 1 is REVERTED.** Confining the cliff dressing to
cliff tiles made cliffs angular and tile-shaped (`compare-revert/`: before |
confined | reverted). The smooth rounding is back; the lips on plain slopes it
caused remain open. Moss default is now `village` (Pure Village Grass01);
`village_cliff` was indistinguishable and is removed. Ambient Meadow rocks had
the old moss baked in and now follow the current choice.

Five reports after the dual-grid tiles landed. Sites reproduced in
`tests/harness/cliff_site_review.tscn` (`--at 500,40,1050 --radius 1`) from the
F3 readouts (`--mouse-shot`), plus overhead views; probes
`tests/harness/oct1_site_probe.gd` (point storeys, walls, rendered minus kernel
on a 2 m grid) and `oct1_coverage_probe.gd`. Before = `site2/00`, after =
`final/00`; side by side in `compare/` (`before | after`, plain and F9);
cliff-end tile gallery `cmp-cliff-end/`; moss options `moss-compare/`.

## 1. Lips on mountain sides that are not cliffs (photos 4, 5; site D)

Cause: the cliff sheet's rounding of a wall (shoulder + foot fillet, 10-14 m
for an 8 m wall) ran past the wall's own tiles onto plain slope tiles. The
probe shows 4-5 m of sheet over tile (26, 83), whose four edges are slopes.

Fix (one rule, `CliffSlopeEnvelope`): the dressing stays inside CLIFF TILES
(a cliff edge crosses the tile, `TerrainTileField.is_cliff_tile`). Each wall's
profile is fitted into its room (wall line to the first non-cliff tile or
road, less 1 m) the way a bank was already fitted to a water channel; the rest
fades over 3 m at the cliff tiles' edge. Every other tile is exactly the
kernel. Two bugs found on the way: the fitted profile stamped one node past
its end (a spike row along tile edges) and a fitted channel read the water
array where there was no water.

Cost: a wall now drops within the half tile in front of it (8 m in about
5 m), so cliffs read as steep mossy faces that follow the kernel's walls; in
plan they are straighter and squarer than the wide old rounding (C_top). Tall
walls over flat ground lose the grassy rounded crest (the grass now runs full
size to the lip and stops; `test_september29_terrain_review`).

## 2. Why the F9 colours came in strips, not cells

The categories belong to the EDGES between 12 m points (flat, level, slope,
cliff); a tile's shape follows from its four edges. The old F9 coloured a
diamond around each edge, and the cliff sheet's magenta fill covered most of
a mountain side, so the visible boundaries were the sheet's outline. F9 now
fills each 12 m tile with its strongest edge (grey flat, blue level, green
slope, red cliff, brown cliff end = a cliff edge with a slope or level edge in
the same tile), draws every lattice edge as a line in its own colour, and
hatches the sheet/cut deviation instead of filling over the tile colour.

## 3. Divots (photo 3; site C)

Cause: the kernel's E2 cliff end. Past the tile centre a ramp fanned out from
the wall to the slope profile, centred on the wall line; next to the wall's
end it was centimetres wide, so it cut a V-notch into the plateau (2.6 m of
drop within 0.6 m of the wall line, `test_terrain_tile_field`).

Fix: E2 keeps the full wall to the tile centre, then the wall shortens
smoothly to nothing 2.4 m before the slope edge
(`TerrainTileField.CLIFF_END_CLEAR` = 0.2 tile: a 4 m road crossing that slope
edge meets no step, `test_september13_world_paths`). The plateau dips gently
instead. The GPU port in F9 matches (`test_september28_category_overlay`,
windowed). Residual: in the synthetic gallery a thin shading fold remains
beside the shortening wall's end; at the reported site it does not show.

## 4. Sheer face beside the path (photo 1; site A)

Cause: a two-storey wall stood on the dual border 6 m from the road's centre
(4 m from its edge); the sheet's rounding ran into the road's keep-out and was
cut off as a sheer face.

Fix (heightmap, as the owner allowed): ROAD VERGES. A point beside a road
point that stands two or more storeys above it is lowered to one storey above
it (`HeightfieldRegion.with_road_verges`, applied after town grades). The
nearest wall rising from a road is then one point back (18 m from the road's
centre). Never raised, never on water (water is solved on the natural field),
never over a town's own control. F9 shows verge points with the yellow graded
stripes. The streamer's feature contexts now reach the cliff sheet's ground
reach plus one point (72 m) so neighbouring chunks see the same roads.

## 5. Levels (photo 2)

The blue hill is level steps stacked: within one storey a point may sit 1, 2
or 3 m above the storey (its LEVEL), and neighbouring points of the same
storey differ by at most one level, so each blue edge is a 1 m smootherstep
slope over 12 m. A 1 m bump next to a 4 m step cannot happen: every point that
touches a different storey (also diagonally) is pinned to level 0, so a slope
edge is always exactly 4 m and a cliff exactly 8 or 12 m. The price is that
levels can never lean into a storey step: they form domes inside a storey's
interior and come back to level 0 before its edge.

## 6. Moss seams (photo 4)

Cause: three different steepness rules. The sheet turned to moss from 47.6 to
60 degrees, its grass thinned from 26 to 52 degrees, and terrain grass ran
full size to 45 degrees and stopped, while steep terrain was never mossy. The
light/dark corners were grass carpet edges and sheet/terrain switches.

Fix: one band for every ground surface (`SlopeProfile.LAWN_STEEPNESS` /
`MOSS_STEEPNESS`): lawn with full grass up to 47.6 degrees, moss without grass
by 60. The terrain shader now grades moss by the same rule as the sheet.

Owner follow-up (October 2): the first band ran 41.5-50 degrees, starting AT
the steepest ordinary slope (a tile rising one storey along both axes). Every
mountainside reaches 41.5, so each rock mound, ridge or bedrock bump on it
tipped into moss with no grass: hard dark patches. The rounded cliff
shoulders went dark from 41.5 down, which made the reverted cliff end read
sheerer than the September 30 one although its shape is unchanged
(`band-end/`: old | 41.5-50 | 47.6-60). The band now starts 6 degrees above
any ordinary slope (`test_slope_profile::test_ordinary_slopes_and_their_bumps_are_lawn`,
red on the 41.5 band). Site D side by side: `compare-band/` (before | 41.5-50 |
47.6-60): the dark patches on the mountainside are gone. 
Rings round the slope rocks (October 2, also present before October 1): a
rock's ground skirt joins the sheet's mesh, and each skirt vertex stored its
raw steepness (1 - normal.y) where the sheet stores only bedrock's moss grade;
`CliffRockCrags.mesh_arrays` took that as a grade, so a 15 degree mound read
as full moss: a dark, grass-free disc round every rock. Skirt vertices now
store bedrock's grade only, and the rocks' contact band (`_substrate`) uses
the same band grade (`SlopeProfile.moss_grade`, shared with the sheet).
Test `test_september29_terrain_review::test_rock_skirts_on_the_sheet_follow_the_sheet_moss_rule`
(red at 0.54). Before/after: `compare-rings/` (`rings/00` | `rings-fix/00`).

## 7. Moss textures

Seven options, all rendered in `moss/00/<style>/`: `raygeas` (current,
Suntail terrain Grass_1), `suntail` (Suntail stone mask), `angry` (Meadow
T_Terrain_Grass_01), `polyart` (Farmlands Grass_02), and new from Pure Village:
`village` (Grass01), `village_patches` (Grass02, green over sandy earth) and
`village_cliff` (Grass01 with the pack's Cliff5 moss mask). Pick one with
`CliffRockStyle.moss_texture` (or a style name like `sheet_bedrock@village`).

## Validation

Isolated suite (`tests/tools/run_suite_isolated.sh`, 344 files): 117 failing
tests, the same files and counts as the September 30 cleanup run, once the
world-paths road-step regression found by it was fixed (E2's clear stretch)
and re-run green with the other kernel-sensitive files. Changed expectations,
each with a written reason in the test: `test_terrain_tile_field` (E2 shape,
red on the old kernel), `test_cliff_sheet_ends` (confined to cliff tiles,
straight-wall sums re-frozen), `test_september29_terrain_review` (grass runs
full size to the crest's lip). New: road-verge tests in
`test_heightfield_region`. Site load time with the wider feature context:
630 s (earlier runs 620-740 s).
