# Rocks stream: moss seam, stone colour, triangle glitches, clustering (September 27 judging)

## Proposed AGENTS.md paragraph

> September 27 judging, rocks (seed 2697992464, photos 3 and 6). A Meadow
> slope rock is set into a surface and, at its contact, is that surface: the
> rock carries the substrate's rock exposure and moss grade averaged round its
> base (`CliffSlopeField._substrate`, the sheet's own formulas; terrain = plain
> lawn) and its clamped lawn tint; `meadow_rock.gdshader` draws the sheet's
> colour (`meadow_stone.gdshaderinc`: `bedrock_stone/bare/tread`, shared with
> `cliff_crag`) and lighting normal only in a soft 0.3 m contact band above
> its contact plane (the surface where the rock finally stands, lifted to its
> skirt's mound top, `RockSkirt.rise_for`); above it the rock keeps stone
> sides and Meadow grass on its tops (`top_offset` .4), and over bare stone
> keeps the grass top off its edges (only its level treads, like the sheet's).
> The sheet's placement no longer multiplies a second anchor tint into its
> per-vertex tints (it was darker than the terrain by a per-chunk constant).
> Ambient embedded rocks take the terrain's own tint. One stone colour for all
> rock: `rock_style.MEADOW_STONE_TINT` = (.52,.475,.40), a low-saturation
> warm grey-tan overlaid on the Meadow rocks' neutral grey albedos (bedrock,
> Meadow rocks and native `stone_albedo` all match; warmer than the old cool
> bedrock (.5,.46,.42), far less saturated than the pack's S_Props tint
> (.552,.418,.342), which read salmon on cliffs).
> Bedrock facet shading keeps only a facet's tilt in the fall-line plane (the
> surface net's contour tilt drew saw teeth along diagonal bench lips).
> Clustering supersedes "bases never interpenetrate": one shared rule,
> `DressingCompiler.nestle_distance(a,b) = max(a,b) + 0.25 min(a,b)` (bases
> overlap, the smaller centre always outside the larger rock). Slope clusters
> are 3-4 rocks nestled round the main rock's placed centre (sides + one
> uphill), `COLONY_COVER` .5; ambient colonies are a main rock with members
> nestled round it (colony_radius bounds reach: 3 / 4.5 / 4 m). Grass is
> blocked under any overlapping skirt's rock. Chunk (1,4): slope rocks 62 -> 58,
> Clark-Evans .41 -> .28, bases touching a neighbour 37 -> 56. Tests:
> `test_september27_rock_substrate_gpu`, `test_september27_rock_placement`.
> See `docs/qa/2026-09-27-judging/rocks/result.md`.

## Sites and method

F3 numbers re-read from the photos: photo 3 player (288.9, 44.7, 904.9),
crosshair (290.2, 46.9, 904.6); photo 6 player (330.4, 44.0, 968.5),
crosshair (334.2, 44.3, 962.2). Photo 6's player z is 968.5, not 963.5.

`tests/harness/cliff_site_review.tscn` streamed the site at (310, 45, 935),
radius 1 (chunks x 0..2, z 3..5, covering photos 3, 6 and 12). The baseline
run (`siteB`) used the stashed baseline source. The final run (`siteF`) is a
fresh process on the final code with the same cameras. Comparison images are
in `comparisons/` (left: baseline, right: final). Most views are free cameras
around the owner's points. Photo 3 was a near top-down view; `p3top`
approximates it. The tactical `--shot` cameras at these points ended up
behind the hill and in the mist.

Probes that identify the owners and the geometry: `tests/harness/rock_substrate_probe.gd`
(rocks near the photos with owner/colour/custom data, plus mesh spike scan),
`rock_pixel_probe.gd` (world point, sheet triangle, vertex/instance colour
under a pixel), `bare_rock_probe.gd` (slope rocks set into bare bedrock),
`unshaded_rock_probe.gd` (albedo-only recapture), `shader_include_reload_probe.gd`.
The harness reload now also refreshes shader includes.

Every rock in both photos is a slope foot rock (`CliffSlopeRocks`, owned by
`CliffSlopeField._find_rocks`). None is ambient dressing.

## Integration fix (merged tree, September 28)

After the slopes merge, `test_basal_slope_rocks_get_a_ground_skirt` failed
("the mound stays below the rock's top", 3.490 vs 3.432). This was a real,
pre-existing defect, not fixture drift.

The skirt mound rose by one height all round each rock, computed from the
rock's visible height at its centre. On a slope the uphill side of the
contact outline lies at or above the rock's top, where the rock is buried.
Probed on the fixture wall: 25 of 26 basal rocks had the uphill mound above
the rock's top, by up to 1.99 m, with the ground itself up to 1.8 m above it.
So uphill of every slope rock the ground bulged up to 0.45 m over nothing.
The test checked only one ring vertex (direction +x), which happened to stay
clear until the merged envelope steepened the fixture.

Fix (`RockSkirt.build`): the mound's rise varies by direction. At each
contact it is `rise_for(max(0, rock top - ground there))`, so it meets the
rock where the rock shows and adds nothing where the rock is buried. The
test now checks all 32 contact directions: the mound rises by at most
`rise_for` of the local visible height, and wherever the rock shows it stays
below the rock's top. The old code fails this (a 0.059 m excess over the
limit on every direction).

Merged tree test results:
- `test_september27_rock_placement` 10/10
- `test_september27_edge_slopes` 10/10
- `test_slope_face_inclusions` 2/2
- `test_meadow_rocks` 3/3
- `test_september27_rock_substrate_gpu` 3/3

A merged-tree re-render of p6close (same camera) shows the nestled cluster
sitting on the new slope sheet: stone sides, grass tops, blended contacts,
no floating or bulging.

## Pass 2 (coordinator review): tint and lawn humps

Coordinator findings on pass 1: the cliffs were too salmon/pink, and on grass
slopes some rocks turned into ghostly lawn-coloured humps. Also, the photo-3
pair no longer spawns, so a bedrock cluster view near the photo-3 camera was
added.

**Tint.** The Meadow rock albedos are neutral grey: mean sRGB 0.505-0.521 in
every channel (T_Rock_01-06). All the hue came from the overlay tint, so the
shared tint was desaturated toward grey instead of pushing the cliffs to it.

| tint | overlay on the mean albedo (sRGB) | saturation |
|---|---|---|
| old bedrock (.5,.46,.42) | (127,123,118) | .08 |
| pass 1 S_Props (.552,.418,.342) | (148,117,107) | .28 |
| final (.52,.475,.40) | (136,124,115) | .15 |

Judged in three lighting contexts, each rendered with the pass-1 tint, the
old bedrock tint and the final tint:
- Opal Highlands mist: `tint-opal-*`, including photo-3/6 cameras.
- Sunwash Meadows in clear light, the terraced cliffs at (1540, 12, 572):
  `tint-sunwash-*`.
- Amber Heath, a golden low sun at (-445, 34, -338): `tint-amber-*`.

In all three the final stone is a warm grey-tan. It is clearly warmer than
the old stone, with no salmon, and rocks and cliffs still match. Measured
albedo in the GPU test: cliff (.250, .206, .172), rock (.227, .196, .155),
native (.250, .206, .172).

**Lawn humps.** `rock_contact_probe.gd` measured every slope rock near
photo 6: rocks show only 0.25-1.6 m above their material's contact plane,
typically 0.5-0.9 m. Two causes followed from that:
1. The pass-1 0.7 m contact band covered most or all of such a rock.
2. The contact plane was wrong. A basal rock's stored normal came from the
   steeper point it was sought from (up to 70 degrees off: normal.y 0.29
   near a wall), not from where it finally stands after the fall-line shift
   or nestle station. The low rock then lay largely "below" its plane and
   drew entirely as substrate.

Fixes:
- Plane normal at the rock's final point (`CliffSlopeField._add_rock`).
- Contact plane lifted to the skirt's mound top (`RockSkirt.rise_for`, one
  formula shared with the skirt), so the band starts where the rock actually
  leaves the ground.
- Band 0.3 m, soft (`base_blend`).
- Grass top rule tightened (`top_offset` .5 → .4): full grass up to about 50
  degrees from level, none on sides steeper than about 65.

Result: stone sides and grass tops above a blended contact
(`passes-p6close`, `passes-p6rocks`, `tint-opal-cluster_*`). A rock is
wholly substrate-coloured only when it shows less than about 0.3 m.

Tests, all red on pass 1 and green on pass 2:
- `test_rock_body_keeps_stone_sides_above_the_contact_band` (GPU): a
  vertical side 0.32-0.52 m above the contact plane matches the same face at
  2.4 m. Pass 1 mean difference 0.084; final 0.000. The contact test still
  passes at ≤ 0.001.
- `test_basal_rock_support_plane_is_the_surface_it_stands_on`: pass-1 dot
  products 0.34-0.84; final ≈ 1.

The photo-3 bedrock evidence is `passes-p3near`: the nearest bedrock-embedded
cluster to photo 3, at (294.5, 55, 880.5), seen from near the photo-3 camera.

Comparison images live in `comparisons/`. They are gitignored
(`/docs/qa/**/*.jpg`), so they are in the worktree only.
- `passes-*`: baseline db59f0c8, pass 1 and pass 2 at the same cameras.
- `tint-*`: the three tints in each biome.

## 1. Moss seam at the rock/mountain junction — fixed

Root causes (measured):
- The rock's base blended to 0.9 lawn over 0.7 m whatever the substrate was.
  Its top grass followed Meadow's broad rule (faces up to about 60 degrees
  from vertical). A rock in bare bedrock therefore showed a green base and
  top against bare stone.
- The rock's lawn did not match the surrounding lawn either, for two reasons.
  (a) The slope sheet's MultiMesh instance colour (`ground_tint_at(anchor)`)
  multiplied its per-vertex tints. A GPU check confirmed that Godot
  multiplies instance colour into COLOR. The sheet was darker than the
  terrain by a per-chunk constant, and the rock took the tint only once.
  (b) The rock's moss grade came from its own slope normal. The sheet's grade
  also includes the envelope's `moss_grade` × exposure. This is why photo 6's
  rock tops read pale or white against the teal slope.

Changes:
- `CliffSlopeField._substrate` gives each rock the exposure and grade of the
  visible surface. These are averaged over 8 points round its base, using the
  sheet's exact formulas (`sheet_normal`, `rock_at`, `moss_grade_at`). Points
  where the terrain is the visible surface count as lawn (0, 0).
  `CliffSlopeRocks` packs this into the instance colour alpha and
  `INSTANCE_CUSTOM.w`. The tint is clamped like the 8-bit vertex tints.
- `meadow_rock.gdshader`: the substrate colour is
  `mix(lawn, bedrock_stone, bedrock_bare*(1-tread))`, the functions the sheet
  uses (new `meadow_stone.gdshaderinc`, used by `cliff_crag` too). The rock
  becomes exactly that colour, with the substrate's lighting normal, at its
  contact (pass 2: a 0.3 m band). Over bare stone the grass top is limited
  to the rock's level treads and kept off its edges (pass 2: 0.3 + 1.0 m). Turf and substrate parts light
  like the terrain (roughness 1, specular 0).
- `CliffRockDressing.build`: native-crag and sheet placements get a white
  instance colour, because their vertices already carry the tint.
- Ambient embedded rocks (`DressingField`): colour = the terrain tint their
  skirt takes (clamped, alpha 0).

Tests (red on the baseline, green now):
- `test_september27_rock_substrate_gpu.gd::test_a_rock_at_its_contact_is_the_surface_it_meets`
  renders the sheet through `CliffRockCrags.mesh_arrays` + `CliffRockDressing.build`
  and the rock through `CliffSlopeRocks.build`, in the same plane.
  Baseline: bare mean 0.337 (max 0.408), patchy 0.198. With the shader fix
  but the old sheet tint: lawn mean 0.048. Final: every case has mean ≤ 0.001
  and max ≤ 0.008.

Renders: `comparisons/passes-bare1.jpg` and `passes-bare1b`. They show the same
bedrock cluster at (295, 55.6, 881), which has exposure 0.75-0.98. Before,
the rocks had mint tops and edges against grey stone. After, the stone is
continuous and the seam is gone. `bare3` (285-290, 20, 981) shows rocks with
turf only on their own treads. `p6rocks` and `p6close` show rock tops that
are now the slope's lawn instead of white caps.

## 2. Stone colour — fixed (one palette; pass-2 values above supersede the salmon numbers here)

Measured in linear albedo (unshaded GPU test):
- Bedrock before: (.22, .20, .18) (tint .5/.46/.42).
- Meadow rocks: (.29, .18, .14) (tint .552/.418/.342).
- Native `stone_albedo` (terrain rock texels, field rocks) before:
  `source_color` (.40, .39, .42), i.e. (.13, .13, .15) linear.

`rock_style.gdshaderinc` now owns `MEADOW_STONE_TINT` and `meadow_stone()`.
The bedrock (`bedrock_stone`) uses them. The rocks use `meadow_stone(albedo)`.
Native stone uses `meadow_stone(0.214)`, the Meadow albedos' mean grey.
The `rock_tint`, `base_tint` and `stone_color` uniforms are removed; nothing
set them.

Final means: cliff (.300, .181, .147), rock (.286, .177, .139), native
(.301, .181, .147). `test_rock_and_bedrock_share_one_stone_colour` asserts
matching warmth (r/b) and value for rock and native stone against the
bedrock. It failed on the baseline.

Pass 1 used the pack's saturated tint and read salmon. Pass 2 retuned the one
constant to (.52,.475,.40); see above.

## 3. Tiny triangle glitches — fixed (shading), geometry noted

Owner found by probe. They are slope-sheet (`solid()`) triangles along
bedrock bench lips that run diagonally to the 0.5 m surface-net grid. The
spike scan found no vertex displaced more than 0.18 m, so they are not
spikes. The triangles are small (0.009-0.035 m²), with facet normals tilted
16-31° from the smooth gradient normal, mostly *along the contour*
(`rock_pixel_probe`: face (-.57,.70,.44) against smooth (-.76,.64,-.03)).
`cliff_crag`'s bare-rock facet shading (0.85 × per-triangle normal) drew
each tooth as a light/dark pyramid.

Fix: the facet keeps only its tilt in the vertical plane of the smooth
normal. Bedrock benches vary only down the fall line, so tread/riser
crispness is kept and the contour tilt from triangulation is dropped.

Rejected options:
- Removing facets entirely: the teeth went, but the bedrock became a flat
  pink blob.
- A triplanar Meadow normal map: it amplified pre-existing stretched
  projection streaks on steep faces.

Renders: `passes-spike1` (the photo-3 lip at (291, 47.5, 911)) show
the saw teeth before and none after. `bare3` before shows a strong tooth
patch at (1100-1500, 400-540).

The geometry itself is unchanged: surface nets still zigzag at sub-grid
creases, which shows only as a slightly notched silhouette seen edge-on.
That belongs to the slopes stream (envelope and bench corner radius).

## 4. Clustering — done (supersedes the September 27 "never interpenetrate" rule)

- Shared rule: `DressingCompiler.nestle_distance(a,b) = max(a,b) + .25·min(a,b)`.
  Bases overlap, the smaller centre stays outside the larger base, and nothing
  is swallowed or stacked. It replaces both `BASE_NESTLE = .8` (ambient) and
  `CliffSlopeField.NESTLE = .8`. Two embedded rocks use the nestle distance
  alone. Rock versus tree still uses the structural spacing.
- Slope clusters: 3-4 rocks (was 2-3) at `COLONY_COVER` .5 (was .55).
  Companions are placed from the main rock's *placed* centre, between the
  nestle distance and touching (`NESTLE_SPREAD` .15-.55), one on each side
  along the foot and one uphill behind. When a station leaves the rock too
  buried, it turns toward the flatter foot (`NESTLE_TURNS`). Previously each
  companion was re-derived from the line, which drifted 1-2 m. Singletons are
  still dropped, and clusters compete by Matérn II.
- Ambient colonies: the main member sits at the centre, and the others nestle
  round it at spread angles. Every member's stone community is the colony's.
  colony_radius now bounds the reach: rock 5 → 3 m, large 7 → 4.5 m,
  cliff 6 → 4 m. Non-colony sets are unchanged.
- `GrassSupportSurfaces.at_index`: a point under any overlapping skirt's rock
  grows no grass, even where a neighbour's mound is higher.

Numbers (`rock_distribution_metrics.gd`, chunk (1,4); now also reports `touching_share`):

| | baseline | final |
|---|---|---|
| slope rocks | 62 | 58 |
| slope Clark-Evans R | .413 | .282 |
| slope rocks whose base overlaps a neighbour's | 37 (60%) | 56 (97%) |
| slope median nearest-neighbour gap (bounds) | -0.25 m | -0.79 m |
| ambient rocks | 12 | 10 |
| ambient touching / median gap | 2 / +3.36 m | 8 / -0.39 m |
| plateau rect rocks | 21 | 26 |

Tests (`test_september27_rock_placement.gd`, 9/9). On the baseline, with the
rule inlined, 6/9 pass; all failures are the new invariants:
- ambient: most colony rocks touch a neighbour. Baseline 4 of 17.
- ambient: none is swallowed.
- slope: clusters average more than 2.6 rocks (baseline 2.4) and every
  cluster rock touches another (24 baseline failures).
- no stacking (nestle distance).
- overlapping skirts: no grass under either rock. Baseline edge distance 3.92.

Updated for the superseded rule: `test_ambient_rock_bases_never_interpenetrate`
→ `..._nestle_but_never_swallow`, the slope 2..3 cluster assertions, and
`test_september23_cliff_directions` "Clusters of two or three" → 2..4. The
colony test now uses the production `ambient_rock.tres`.

Renders: `passes-p6rocks` and `passes-p6close` show nestled pairs and
triples in place of spaced singles.

Caveat: the cluster layout changed, so the photo-3 pair at (291.8, 902.8) is
not generated any more (its foot slot falls out at cover .5). The matched
bedrock evidence is therefore the `bare*` cluster 24 m north.

## Other tests

Relevant files and their results:
- Pass: `test_meadow_rocks` 3/3, `test_slope_face_inclusions` 2/2,
  `test_dressing_ecology`, `test_dressing_collision_builder`,
  `test_dressing_commit_queue`, `test_september26_bedrock` 6/6,
  `test_p03_constrained_cliffs` 13/13, `test_september27_slope_ledges` 7/7,
  `test_september27_road_grade` 5/5, `test_p03_cliff_followup` 10/10,
  `test_september16_cliff_grass`, `test_september17_support_refinement`,
  `test_september19_bank_grass_water`, and the GPU tests
  `test_september17_stone_colour_gpu`, `test_september16_rock_materials_gpu`.
- Same failures as baseline: `test_dressing_field` 6/7 (lpfv.big_rock),
  `test_environment_catalog` 18/21, `test_september23_cliff_directions`
  32/34 (two envelope-shape tests), `test_september13_terrace_hierarchy`
  2/3, `test_september17_crag_weathering_gpu` 1/2.

## Open / not verified

- The warm grey-tan stone is a global look change that the owner has not yet
  reviewed; `MEADOW_STONE_TINT` is the one knob.
- Rocks showing less than about 0.3 m above their mound are still wholly
  substrate-coloured ("nearly buried", by design). A rock's grass top is the
  slope's exact lawn, so a low rock with a large flat top reads mostly as
  lawn with stone sides.
- Sawtooth silhouettes of surface nets at bench lips remain (geometry, slopes
  stream).
- No grass-enabled renders and no player walk over overlapping hulls. Static
  convex hulls overlap, so there are no thin gaps between nestled bases, but
  this was not walked.
- The sheet's per-chunk instance-tint change also brightens slope lawn
  everywhere to the terrain's exact lawn. That may relate to photo 9's "dark
  strip next to a light strip" (paths/slopes stream), but I did not check it.
