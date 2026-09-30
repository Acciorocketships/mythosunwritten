# Rock placement and embedding (September 27)

Owner report (seed 2697992464, F3 world coordinates):

1. Plateau, player (327.4, 61.8, 904.5) / crosshair (328.2, 63.5, 901.8), and
   slope crest near (371.4, 67.9, 873.7): rocks scattered evenly, too many on
   the mountaintop, some stacked on others.
2. Player (321.4, 48.6, 955.9) / crosshair (321.2, 50.8, 954.9): a mossy rock
   sits on the smooth slope like a separate object; plateau rocks sit on the
   ground. Rocks should look embedded, with the ground meshing into them.

## Which system placed the rocks (measured, not guessed)

`tests/harness/rock_placement_probe.gd` ran inside the streamed site
(`cliff_site_review.tscn`). It lists every rendered rock instance within 40 m
of each reported point with its owning node. The results are in
`live-probe-before.json`.

| site (40 m) | slope foot rocks (`CliffSlopeField._find_rocks`) | ambient dressing (`DressingField`) |
|---|---|---|
| plateau | 73 | 5 (`meadow.rock.02–04` large boulders, `.11`) |
| crest   | 36 | 10 (`meadow.rock.07–10` small rocks, `.03/.04`) |
| embed   | 73 | 1 |

The headless site metric (`tests/harness/rock_distribution_metrics.gd`,
chunk (1,4), 100 × 110 m site rect) gives the same picture: **94 of 105**
rocks were bedrock slope foot rocks. The site had 85.5 slope rocks/ha and
**104 base-overlapping pairs** (the stacked pairs). The isolated big boulders
on the flat snowy top were `ambient.rock_large`; the small crest rocks were
`ambient.rock`. The embed-shot rock is a slope foot rock (`angry_03`/`angry_04`
at (317.0, 954.6)/(317.25, 954.75), 0.3 m apart, i.e. stacked).

## Root causes

- **Slope foot rocks** (bedrock style, in game): every 7 m slot along every
  foot line had an independent 75% chance of a 2–3 rock cluster. That
  produced an even string of boulders along every plateau step. Companions
  were spread ±0.625 × main size along the line, so they often landed on the
  main rock. No arbitration between rocks existed at all.
- **Ambient rocks**: independent thinned-Poisson anchors (Matérn only by a
  small spacing radius). This gave uniformly sprinkled singles: every ambient
  rock at the site was isolated. `ambient.rock_large` accepted any flat,
  open plateau.
- **Not embedded**: ambient rocks were placed at the anchor's ground height
  with nothing sunk. Their base stencil stood up to +0.02 m above the ground
  on 3 of 30 rocks. Slope foot rocks were sunk, but the bedrock slope solid
  deliberately skips the old rock swell union (chunk disagreement), so the
  ground never rose to meet them.

## Changes

**Slope foot rocks** (`scripts/terrain/field/CliffSlopeField.gd`, rock placement only):
- `colony01()`: a coherent 56 m `DressingEcology` habitat field decides which
  foot slots carry a cluster. This gives runs of clusters and genuinely bare
  stretches. Slots are now 10 m apart; outer corners are ×1.5 more likely.
- Companions are placed beside the main rock, with nestled bases, never on top of it.
- `_thin_rocks()`: a companion that overlaps its own cluster is dropped, and
  a cluster left with one rock goes. Clusters then compete as units by
  Matérn II on a per-cluster hash key, which is order-free.
- `skirt()` / `skirts()` / `skirt_sheet()`: each basal rock's ground skirt
  is emitted as a slope-sheet placement. It has the slope's own material,
  normals, moss grade and exposure, plus collision.

**Ambient rocks** (`scripts/terrain/dressing/**`, `terrain/dressing/sets/ambient_*rock*.tres`):
- New `DressingSet.colony_radius` / `colony_members` (Neyman–Scott): one
  jittered colony centre per 24 m proposal cell, decided once from the
  existing intensity (fill × land occupancy × habitat layers), with members
  in a disc. Non-colony sets keep their exact previous code path.
- `ambient.rock_large` needs a break of slope (≥ 1.5 m rise within 9 m,
  the existing relief habitat), so no boulder can stand on an open flat top.
- Base-footprint arbitration (`DressingCompiler.BASE_NESTLE`): an embedded
  rock and any neighbour in its spacing group keep centres at least 0.8 ×
  the sum of their compiled base radii apart.
- New `DressingSet.embed_fraction`: every compiled base-outline point is
  sunk that share of the rock's height below the ground (rocks 0.2–0.22).
- `RockSkirt` (new, `scripts/terrain/dressing/RockSkirt.gd`): a 32-sided
  ground skirt from inside the rock's contact outline (a low mound, 0.2 ×
  exposed height, ≤ 0.45 m) out to a rim sunk 5 cm below the covered
  surface. It is that surface, swollen; see the follow-up section below.
  Each skirt belongs to its rock (half-open ownership), so chunk seams cannot
  split or duplicate it.
- Skirts are mesh-backed `GrassSupportSurfaces` grids. Blades grow on the
  skirt, and nodes inside the contact outline block blades, so none root in
  terrain buried under the rock or mound.
- Slope rock bases are now terrain reservations for ambient rocks. The slope
  reservation rectangle grows 16 m instead of 4 m; the chunk core is offset
  half a cell from the owned rectangle, so its +x/+z band was previously
  unchecked.

**Also**: `CliffSlopeRocks._add_collision` gives slope ground rocks the
catalog Meadow convex hulls; they were visual-only before. `meadow_rock.gdshader`
blends a slope-attached rock's base into the slope green over 0.7 m above
its mound top. `FieldTerrainStreamer` commits ambient skirts with the dressing
collision and passes their grass supports to the grass sampler (two small
edits). `EnvironmentInstancePayload.ground_skirts` carries the plain arrays.

## Numbers (same harness, same chunk; `metrics-before.json` / `metrics-after.json`)

| | before | after |
|---|---|---|
| site rocks (1.1 ha) | 105 (95.5/ha) | 21 (19.1/ha) |
| site Clark–Evans R (lower = clustered) | 0.49 | 0.38 |
| site isolated share (no rock within 8 m) | 0.086 (ambient: 1.0) | 0.0 |
| site pairs closer than 0.9 × summed base radii | 104 | 5 (rule is 0.8; all nestled, none closer) |
| chunk slope foot rocks | 389 | 99 |
| chunk ambient rocks | 30 (R 0.87, 93% isolated) | 9 (R 0.29, 11% isolated) |
| ambient base-outline max height above ground | +0.022 m (3 rocks) | −0.125 m (none above) |

Live probe after, on the final code (40 m radius, `live-probe-after.json`):
plateau 10, crest 0 and embed 36 rocks. All are slope foot rocks; no ambient
rock falls in those discs.

## Tests

New `tests/test_september27_rock_placement.gd`: 8 tests, all pass.
- Colonies: Clark–Evans < 0.5; fewer than 20% isolated.
- No interpenetrating bases, for both ambient and slope rocks.
- Whole base outline sunk ≥ 0.22 × height.
- Skirt: rim under the ground, mound above it, up-facing collision equal to
  the visual.
- No boulder on an open flat plateau.
- Slope clusters: colonial, with bare stretches, 2–3 rocks each.
- Skirt ownership is identical across chunk windows.
- Slope rock hull aligned with its render mesh.

These invariants were measured red on the original code by the site harness
(overlaps 104, all ambient rocks isolated, base outline above ground). I
could not rerun the unit file on the pre-change tree: the shared worktree
carries other agents' uncommitted work, so it could not be stashed.

The pre-change baseline is recorded in the scratch logs. After the change:
- `test_dressing_field`: 6/7. The same pre-existing failure (`lpfv.big_rock.01`
  nature-wave asset) as before. The grounding assertion was updated: embedded
  rocks sink.
- `test_dressing_ecology`, `test_dressing_collision_builder`,
  `test_dressing_commit_queue`, `test_meadow_rocks`, `test_september26_bedrock`:
  all pass, as before.
- `test_environment_catalog`: 18/21, the same 3 failures as baseline.
- `test_slope_face_inclusions`: 2/2. The baseline failed 1 (face count).
- `test_september23_cliff_directions`: 31/34. Three September 25 density assertions
  were rewritten to the September 27 direction: "many clusters", "no bare
  stretch over 21 m", "corner carries rocks", and the face/basal counts.
  3 remaining failures are envelope-shape tests: ridges, corner reach and flat
  terraces. They sample `envelope().sample` only, independent of rocks. The
  envelope is being reworked concurrently by another agent. I have no
  pre-change baseline for this file.

## Renders

Matched before/after at the owner's F3 poses, via `ReviewCam.solve_cam`
through `cliff_site_review --shot`, plus two overhead views:
`plateau-`, `embed-`, `crest-`, `plan_plateau-` and `plan_south-comparison.jpg`.
Both sides are grass-free, and the after side is the final code. Pixel
differences are in `diff/`. An intermediate run used ground-material skirts
for slope rocks. It showed pale halos around every foot rock
(`rejected/ground-material-slope-skirts-plan_south.jpg`), so slope skirts now
use the slope sheet's material. `final-close_b.jpg` shows a foot cluster
rising out of its mound. `final-grass-*.jpg` are the final code with grass
enabled, including the same close-up with grass stopping at the skirt. `close_a`'s camera ended up under the slope surface and is not
valid evidence. There are no grass-enabled before images. Note the terrain
itself changed between the before and final runs because of concurrent
envelope/ledge work by another agent (compare the plan views).

## Follow-up: the mound read as a pale pad (coordinator review)

In `final-close_b.jpg` the slope-rock mound read as a paler, smoother pad
with an outline. Three root causes were measured and fixed.

1. **A separate placement with its own moss scale.** The mound was its own
   slope-sheet placement. `cliff_crag.gdshader` grades moss by `UV2.x / UV2.y`,
   and `UV2.y` is the placement's `top`, so the mound's much lower top gave
   different moss. The mound's sheet-covering triangles now join the slope
   solid placement itself (`CliffSlopeField.add_skirts(solid(owned)[0])`).
   It is one mesh, with the same top, tint lattice and collision.
2. **Own normals.** Mound normals came from its own triangles and later from
   the covered normal tilted by the mound's gradient. Either way the lighting
   and moss grade differed from the ground (tilted mounds showed as lighter or
   darker pads). Every vertex now takes the covered surface's own normal,
   rock exposure and moss grade (`sheet_normal()` mirrors `solid()`'s bedrock
   gradient exactly). Only the height differs. Where a triangle straddles the
   sheet's edge, each corner keeps its own surface's inputs.
3. **The wrong covered surface.** Terrain heights and normals were
   interpolated across cliff edges, so normals near a lip tilted up to 45°.
   These showed as moss-coloured slivers (confirmed by a physics ray at the
   pixels). `RockSkirt.terrain_surface` now evaluates the mesher's 2 m quads
   in their own cell (`surface_y_in_cell`) with the same diagonal and tint
   lattice. Each vertex is classified as sheet or terrain by which surface is
   actually higher (`envelope - SINK` against the terrain). A 3 cm or `RAISED`
   margin was tried and rejected: it drew terrain material over the visible
   sheet as a darker ellipse.

Rim: 32 sides and rings at 0.85/1.0, sunk 5 cm. An intermediate 2 cm sink
with dense rings z-fought.

`tests/harness/rock_skirt_seam_audit.gd` compares chunk (1,4) skirt rim
vertices with the nearest rendered solid vertex. The moss scale is now
shared. Normal error is median 0.89° and p90 3.0° (the maximum of 23.6° is a
nearest-vertex mismatch at bedrock steps). Grade error is at most 0.11,
previously 0.66. `tests/test_september27_rock_placement.gd` now asserts that
every skirt vertex has the covered surface's exact normal and the terrain's
own tint (8/8 pass, 26,878 assertions).

Renders are in `followup/`. They use hot-reload iterations of
`cliff_site_review --full` at the Sunwash Meadows bank (1497.8, 7.3, 590) and
the snowy highland (330, 60, 910). They cover four slope-foot clusters per
site, chosen by `rock_cluster_views.gd`, plus two ambient rocks per site, all
at 8–9 m.
- `highland-close_b.jpg` compares the reported pale pad, no skirt, and the
  final version at the reviewed camera. Terrain from other agents also
  changed between the reported run and now.
- `*-cluster_N.jpg` compares the first follow-up pass (tilted normals,
  separate placement), no skirt (the skirts toggled off by hot reload) and
  the final version.
- `highland-cluster_4-zoom.jpg` shows the former moss slivers.
- `*-ambient_N.jpg` show the final version only.

In the final images the mound is indistinguishable in colour, texture and
moss grade. What remains visible is geometry: the rock's base is buried and
the ground contour rises to it. The existing sheet/terrain material boundary
of the world is unchanged and still shows where it crosses nearby.
`rock_skirt_paint_probe.gd` paints the terrain-covering parts magenta. Test
and review harnesses added: `rock_skirt_seam_audit.gd`, `rock_skirt_dump.gd`,
`rock_cluster_views.gd` and `rock_skirt_paint_probe.gd`.
`cliff_site_review.gd`'s reload list now includes `RockSkirt.gd`.

Not verified: grass-enabled close-ups of the final mound, and ambient mounds
before/after (only the final version was rendered). The pixel-diff numbers
in `diff/` predate this follow-up.

## Open / unverified

- Density is a judgement call. The reported plateau top and crest are now
  bare, with rocks gathered in the colonies below. `COLONY_COVER` (0.55) and
  the rock set fills are the knobs.
- A neighbouring chunk's ambient skirt that crosses a chunk border gets no
  grass support in this chunk. Blades there root in the terrain below the
  thin skirt edge. Deciding neighbour rocks exactly would exceed the
  canonical water query margin (34 m vs 26 m budget).
- Ambient (dressing) Meadow rocks get no shader base-colour blend. Their
  instance custom data carries tactical footprints. The skirt geometry and
  the grass support provide the continuity instead.
- No player walk over skirts or rocks was run. Collision is the visual
  triangles and catalog hulls; neither was checked by a physical walk.
- The owner's exact embed-shot rock is covered only at the reported camera.
  Most of it is below frame in the tactical view.
