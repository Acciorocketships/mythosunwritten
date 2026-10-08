# Tree imposters: switch distance (Task 5)

Seed 2697992464. Painted trees (Meadow, Farmlands; 69 visuals) hand over to
their baked imposter card at **100 m** (`EnvironmentCommitQueue.IMPOSTER_DISTANCE`,
shader global `tree_imposter_fade` = (100, 12)), dithering per tree over
88-112 m. `mip_alpha_boost` is 1.0.

## How the handover works (and why not FADE_SELF)

The plan's GeometryInstance3D `visibility_range_*` with `FADE_SELF` was built
first and rejected on the first render: Godot sets the fade range on the
instance once a range is set, which draws the whole batch in the alpha pass at
*every* distance. At 60 m the trees lost their trunks and the leaves sorted
wrongly (`/private/tmp/ir60/cmp.png`: mesh | imposter | FADE_SELF tree).

Instead the crossfade is per instance and per pixel in the shaders, all in the
opaque pipeline:

- `painted_leaf.gdshader` (`imposter_crossfade` on the visible mesh's copy) and
  the new `tree_bark.gdshader` keep the interleaved-gradient cells where
  `near_fade >= noise`; `tree_imposter.gdshader` keeps exactly the others.
  `near_fade = 1 - smoothstep(D - F, D + F, |camera - instance origin|)`.
- Bark: the baked StandardMaterial3D's object dither cannot do this (in the
  fragment stage MODEL_MATRIX is the MultiMesh node, not the instance; the
  reversed min/max also misbehaved on Metal). `tree_bark.gdshader` rebuilds the
  features the 78 tree StandardMaterials use (albedo x texture x vertex colour,
  normal map + scale, red AO, roughness, optional alpha-scissor double-sided
  variant derived from the same text). Rendered against the baked material:
  dE 0.0-0.2, coverage 1.000 at every dolly step ("orig" column).
- `EnvironmentRenderCache` gives the visible mesh the crossfade copies; the
  shadow proxy (`LeafShadow`) keeps the baked materials (meta `baked_material`
  links them for tests). Legacy LPFV/KayKit trees (biome_canopy shader, none
  placed by any dressing set) drop their imposter.
- Node ranges only cull: near batch ends at D + F + 34 + 8 m, cards begin at
  D - F - 34 - 8 m (34 = the 48 m tile's half diagonal), FADE_DISABLED.
- Imposter MultiMesh: one shared unit QuadMesh, one ShaderMaterial per imposter
  (cached), one `buffer` upload (placements, tints, footprints), cast_shadow OFF,
  group `tactical_preserve_surface`, custom_aabb = near AABB grown evenly.
  Cost per tile batch: ~30 us main thread (bench: 16 trees; the batch itself
  ~100-200 us warm).
- Shader fixes from Task 4: `repeat_disable` on both atlases; texture reads and
  the LOD derivative precede the dither discard.

## Dolly (tests/harness/imposter_review.gd)

`Godot --path . -s res://tests/harness/imposter_review.gd -- --centre=-4,3 --boosts=0,1.0 --out=/private/tmp/imposter-review`

Chunks (-5..-3, 2..4) through the real chunk pipeline; one 48 m tile with 12
trees (tile (-15, 15), target (-700, 85, 748)), camera 12 deg above it at
azimuth 225, 60-300 m. Coverage = pixels differing from the tile-less frame;
ratios and CIELAB dE against the painted meshes.

| d (m) | mesh cov (frame) | imposter b=0 | imposter b=1 | on_100 | on_140 | on_180 |
|---|---|---|---|---|---|---|
| 60 | 0.276 | 0.904 / 1.9 | 0.904 / 1.9 | 1.000 / 0.0 | 1.000 / 0.0 | 1.000 / 0.0 |
| 100 | 0.073 | 0.931 / 1.1 | 0.941 / 1.2 | 0.996 / 0.3 | 1.000 / 0.0 | 1.000 / 0.0 |
| 120 | 0.048 | 0.937 / 1.0 | 0.950 / 1.0 | 0.968 / 0.7 | 0.998 / 0.1 | 1.000 / 0.0 |
| 140 | 0.034 | 0.940 / 0.9 | 0.964 / 1.0 | 0.964 / 1.0 | 1.000 / 0.3 | 1.000 / 0.0 |
| 180 | 0.020 | 0.942 / 0.9 | 0.972 / 0.9 | 0.972 / 0.9 | 0.972 / 0.9 | 0.999 / 0.3 |
| 300 | 0.007 | 0.941 / 1.5 | 0.991 / 1.2 | 0.991 / 1.2 | 0.991 / 1.2 | 0.992 / 1.2 |

(cells: coverage ratio / dE). Every step 60-300 m and every candidate switch
is within 10% coverage and dE < 2 (bar: 6). `mip_alpha_boost` 0 / 0.25 / 0.5 /
0.75 / 1.0 at 200 m: 0.940 / 0.957 / 0.964 / 0.970 / 0.975; 1.0 is closest at
every distance and never exceeds the mesh. 100 m is the smallest candidate
that passes, so it is the switch.

PNGs (not committed): `/private/tmp/imposter-review/d<ddd>_<mode>.png`
(mesh, orig, imp_b0.0, imp_b1.0, on_100/140/180, every 10 m). Reviewed: d060,
d100, d140, d200 mesh vs imposter vs on_100 crops — same crowns, trunks and
tint; the imposter reads slightly smoother and its lowest trunk shows where
the mesh's lower leaves hide it.

## In game (frame_feel_profile, forest at (-672, 672), 1280x720, no vsync)

Close (over-the-shoulder) view, two runs each, `--imposter-distance 1000000`
(never) vs default 100 m:

| phase | dt p50 off | dt p50 on | dt p95 off | dt p95 on | dt p99 off | dt p99 on | prims off | prims on | draws off | draws on |
|---|---|---|---|---|---|---|---|---|---|---|
| idle | 16.15 / 16.02 | 14.21 / 14.08 | 18.19 / 18.26 | 16.89 / 16.97 | 26.07 / 25.65 | 23.90 / 23.42 | 2.04M / 2.05M | 1.88M / 1.87M | 1453 / 1444 | 1378 / 1374 |
| turn | 17.38 / 17.40 | 16.25 / 16.15 | 20.08 / 23.40 | 21.59 / 22.01 | 25.27 / 28.77 | 24.97 / 25.77 | 2.68M / 2.69M | 2.48M / 2.50M | 1734 / 1740 | 1717 / 1720 |
| run | 18.32 / 18.24 | 18.49 / 18.34 | 24.95 / 23.25 | 26.00 / 27.20 | 29.73 / 29.67 | 32.65 / 31.39 | 3.11M / 3.07M | 3.03M / 3.02M | 2041 / 2018 | 2073 / 2062 |
| run_turn | 19.43 / 18.38 | 18.79 / 17.88 | 24.71 / 26.71 | 26.35 / 23.55 | 34.22 / 32.43 | 29.66 / 28.29 | 3.03M / 3.06M | 2.77M / 2.77M | 1912 / 1920 | 1853 / 1854 |

Process p95 (main-thread scripts) is unchanged within noise (idle 1.80/1.85 vs
1.69/1.68; the moving phases swing 4-12 ms with streaming in both). Standing
and turning get ~1-2 ms faster at p50 and p95 (idle) with 7-10% fewer
primitives; the running phases are dominated by streaming and stay within
run-to-run noise. The close view in a forest rarely sees trees past 100 m,
so the gain is modest; the tactical view sees more (prims at the same spot,
four headings, off vs on: 1.99M/1.98M/1.94M/2.52M vs 1.99M/1.77M/1.72M/2.46M).

The first forest site picked (-480, 480) holds 3 trees in its chunk (a
clearing); the numbers above use the dense chunk (-4, 3), 110 trees.

Views (`--view-shots`): `/private/tmp/imposter-views/{off,on}/{close,tactical}_h0-3.png`,
side by side in `/private/tmp/imposter-views/cmp_*.png`, zooms `zoom_c1.png`,
`zoom_t1.png`. Both views look the same at a glance; zoomed, the 100-200 m
imposters are rounder and softer than the leaf-card crowns and a touch
darker against a low sun (close view, backlit). No seams, holes or doubled
trees at the switch; the camera bubble keeps working (its instrumented
copies of both new shaders compile).

## Tests

- `test_dressing_commit_queue.gd` 11/11 (headless 439 asserts; windowed also
  checks transforms/colours/custom data): imposter child, culling ranges,
  FADE_DISABLED, crossfade materials on the visible mesh and baked ones on the
  shadow proxy, shared quad/material, shader global matches project.godot,
  every placed tree keeps its imposter, bubble-compatible shaders.
- `test_tree_imposters.gd` 7/7 windowed + headless (the render test now sets
  the switch to 0 m, and checks the card yields inside the switch).
- `test_environment_catalog.gd` 24/24 (bake-output checks read `baked_material`).
- `test_canopy_shadows.gd` 3/3 windowed, 2/2 headless.

## Final review fixes (October 8)

### Imposter VRAM: lossless RGBA8 -> BC7

`Performance.RENDER_TEXTURE_MEM_USED` at `idle_end` (frame_feel_profile, forest
(-672, 672), 1920x1080, windowed):

| build | texture MB | video MB |
|---|---|---|
| base 8a6441058 (no imposters) | 2510 | 3235 |
| head, lossless atlases (before) | 2873 | 3599 |
| head, BC7 atlases (after) | 2601 | 3327 |

Imposters went from +363 MB to +91 MB of texture memory. Format:
`PortableCompressedTexture2D.COMPRESSION_MODE_BPTC` (BC7 RGBA, format 22; Metal on
the M1 Pro reports `bptc` and uploads it compressed), 2048x256 with mips =
0.70 MB per atlas, saved with `ResourceSaver.FLAG_COMPRESS` (zstd): 41 MB on disk
(lossless was 51 MB). frame_px stays 256. Dolly (`imposter_review.gd --centre=-4,3
--boosts=0,1.0 --distances=100`) after BC7: imp_b1.0 coverage 0.903-0.991 and
dE 0.9-1.9 from 60-300 m, on_100 coverage 0.954-1.000 and dE 0.0-1.5; at the
switch (100 m) on_100 0.995 / dE 0.3: identical to the lossless table above to
within 0.01 coverage and 0.1 dE. Alpha-scissor edges unchanged.

### Stale imposters

`EnvironmentImposter.geometry_signature` (md5 over each piece's local transform,
mesh AABB and per-surface vertex counts, mm precision) is written at capture;
`_carry_imposter` drops an imposter whose signature differs from the re-baked
visual (prints a warning; rerun `--imposters-only` windowed).
`test_environment_catalog::test_every_tree_imposter_matches_its_current_geometry`
pins all 83; the carry test covers a rescaled tree. Backfilled by the BC7
`--imposters-only` rerun (only the 83 tree visuals and 166 atlases changed).

### Culling and custom data

Near batch and cards share pinned CPU bounds (`custom_aabb`, also correct
headless); cull slack = half the bounds' 3D diagonal (+ VISIBILITY_MARGIN 8 m)
instead of the 48 m tile's flat half diagonal. The cards no longer carry the
owner-footprint custom data or meta: the visibility bubble skips them
(`tactical_preserve_surface`, checked in `CameraVisibilityBubble._select`), and
the imposter shader never read it. `RenderWarmup` had kept custom data on its
warm-up card, which would have warmed a pipeline the cards no longer use; it now
matches (test pins the formats).

### Base vs head feel (pre-branch build 8a6441058 in a temporary worktree)

`frame_feel_profile -- --no-vsync --size 1920x1080 --phase-seconds 8 --x -672
--z 672`. The machine ran unrelated jobs throughout (load average 20-58, rising
during the session), so batches drift; compare within a batch. Cells: mean over
runs (per-run values). Ablations in batch 1: `nodither` = `--bark-dither off`
(opaque trunks without the crossfade discard, Apple HSR on; the card still
dithers), `never` = `--imposter-distance 1000000` (cards never drawn).

Batch 1 (base 5 runs, head 4, then ablations):

| phase | metric | base | head | nodither | never |
|---|---|---|---|---|---|
| idle | dt p50 | 22.69 (22.9/22.7/22.5/22.5/22.9) | 19.78 (19.7/19.7/19.9/19.9) | 19.84 (19.9/19.9/19.7) | 23.38 (23.4/23.3/23.4) |
| idle | dt p95 | 25.22 (26.8/24.9/24.9/24.6/25.0) | 21.92 (21.2/21.1/22.9/22.4) | 22.31 (21.8/23.8/21.4) | 26.68 (25.7/25.5/28.9) |
| idle | dt p99 | 30.57 (30.8/30.2/30.3/30.6/30.9) | 28.33 (27.3/27.9/29.5/28.7) | 28.83 (29.6/28.9/28.0) | 31.29 (31.0/31.3/31.5) |
| idle | process p95 | 2.38 | 2.18 | 2.21 | 2.42 |
| turn | dt p50 | 24.39 (24.3/24.5/24.4/24.3/24.5) | 23.39 (23.2/23.1/23.6/23.6) | 23.26 (23.1/23.5/23.2) | 24.95 (24.9/24.9/25.1) |
| turn | dt p95 | 29.51 (29.5/30.3/28.4/29.7/29.7) | 28.01 (29.8/26.8/28.2/27.3) | 27.97 (27.8/28.5/27.6) | 30.26 (30.8/29.3/30.7) |
| turn | dt p99 | 33.75 (33.5/33.1/34.6/32.9/34.6) | 32.08 (33.7/31.3/32.1/31.2) | 33.49 (33.0/36.2/31.3) | 34.55 (34.4/34.3/35.0) |
| turn | process p95 | 9.26 | 9.02 | 9.22 | 9.25 |
| run | dt p50 | 25.02 (24.7/25.1/25.2/24.9/25.2) | 25.31 (25.1/25.2/25.6/25.3) | 25.48 (25.5/25.2/25.7) | 25.50 (25.7/25.2/25.6) |
| run | dt p95 | 31.85 (32.5/29.2/32.4/31.9/33.3) | 33.04 (31.8/31.6/35.5/33.3) | 33.79 (33.5/33.2/34.7) | 34.20 (34.4/33.6/34.5) |
| run | dt p99 | 38.50 (38.9/37.4/39.6/38.8/37.8) | 42.37 (39.4/36.4/46.9/46.8) | 40.19 (39.0/40.8/40.8) | 40.93 (40.3/41.1/41.4) |
| run | process p95 | 12.42 | 12.61 | 12.64 | 12.38 |
| run_turn | dt p50 | 25.85 (26.1/25.8/25.8/25.4/26.2) | 25.23 (25.0/25.2/25.1/25.6) | 25.53 (25.6/25.2/25.9) | 26.51 (26.7/26.5/26.3) |
| run_turn | dt p95 | 31.65 (31.7/31.7/31.8/31.2/31.8) | 30.10 (29.9/30.2/30.5/29.8) | 31.79 (31.5/31.7/32.2) | 34.12 (34.1/35.5/32.8) |
| run_turn | dt p99 | 37.57 (36.5/37.2/36.7/37.3/40.1) | 35.03 (34.4/36.2/34.7/34.8) | 35.50 (34.6/35.6/36.2) | 40.80 (42.7/42.9/36.8) |
| run_turn | process p95 | 4.84 | 5.03 | 5.12 | 5.06 |
| idle_end | dt p50 | 24.81 (25.9/22.5/25.5/25.2/24.9) | 24.43 (25.1/23.8/24.4/24.4) | 26.39 (27.0/25.4/26.8) | 24.75 (24.6/25.4/24.2) |
| idle_end | dt p95 | 32.96 (34.1/30.0/34.1/34.3/32.4) | 32.28 (32.2/30.7/33.7/32.4) | 35.00 (35.6/35.5/34.0) | 34.51 (34.6/34.8/34.1) |
| idle_end | dt p99 | 39.20 (40.0/37.5/39.4/42.4/36.7) | 40.82 (37.5/35.9/43.9/46.0) | 46.16 (44.2/54.0/40.3) | 43.63 (39.7/45.6/45.5) |
| idle_end | process p95 | 13.09 | 13.04 | 13.51 | 12.61 |
base n= 5 tex MB [2510, 2510, 2510, 2510, 2510] video MB [3235, 3235, 3237, 3235, 3236]
head n= 4 tex MB [2601, 2601, 2601, 2601] video MB [3327, 3328, 3327, 3327]
nodither n= 3 tex MB [2601, 2601, 2601] video MB [3327, 3327, 3327]
never n= 3 tex MB [2601, 2601, 2601] video MB [3327, 3327, 3327]

Batch 3 (alternating, new background jobs started mid-batch):

| phase | metric | base | head |
|---|---|---|---|
| idle | dt p50 | 23.09 (22.7/23.4) | 20.21 (19.7/19.9/20.6/20.6) |
| idle | dt p95 | 26.00 (24.7/27.3) | 22.53 (21.7/21.4/23.6/23.4) |
| idle | dt p99 | 31.14 (30.1/32.1) | 28.92 (27.4/28.2/29.4/30.7) |
| idle | process p95 | 2.44 | 2.28 |
| turn | dt p50 | 25.10 (24.8/25.4) | 23.82 (23.2/23.9/23.9/24.2) |
| turn | dt p95 | 30.94 (31.0/30.9) | 29.21 (28.2/31.9/27.8/28.9) |
| turn | dt p99 | 33.55 (33.8/33.3) | 35.26 (32.3/42.1/32.2/34.4) |
| turn | process p95 | 9.36 | 9.41 |
| run | dt p50 | 26.00 (25.7/26.3) | 26.48 (25.6/25.8/27.5/27.1) |
| run | dt p95 | 35.75 (35.8/35.7) | 35.09 (32.3/32.7/38.5/36.8) |
| run | dt p99 | 42.81 (43.4/42.2) | 43.09 (35.0/41.3/49.5/46.5) |
| run | process p95 | 12.45 | 12.23 |
| run_turn | dt p50 | 27.32 (27.0/27.6) | 30.08 (25.8/29.6/29.4/35.5) |
| run_turn | dt p95 | 34.55 (32.1/37.0) | 40.53 (30.6/42.5/42.8/46.1) |
| run_turn | dt p99 | 39.66 (40.2/39.1) | 47.09 (34.3/50.4/52.1/51.6) |
| run_turn | process p95 | 6.87 | 6.87 |
| idle_end | dt p50 | 28.71 (28.2/29.2) | 26.57 (27.1/27.1/28.3/23.7) |
| idle_end | dt p95 | 37.81 (37.0/38.6) | 36.30 (34.6/39.4/36.1/35.1) |
| idle_end | dt p99 | 49.27 (47.4/51.1) | 47.43 (43.6/50.6/40.3/55.2) |
| idle_end | process p95 | 14.06 | 12.91 |
base n= 2 tex MB [2510, 2510] video MB [3235, 3236]
head n= 4 tex MB [2601, 2601, 2601, 2601] video MB [3327, 3327, 3328, 3327]

Batch 4 (strictly alternating base/head x 3):

| phase | metric | base | head |
|---|---|---|---|
| idle | dt p50 | 22.87 (22.8/23.1/22.7) | 20.01 (20.0/20.2/19.8) |
| idle | dt p95 | 26.18 (24.8/25.3/28.4) | 23.31 (21.7/26.9/21.4) |
| idle | dt p99 | 30.67 (31.3/30.5/30.1) | 29.39 (27.9/32.4/27.9) |
| idle | process p95 | 2.33 | 2.17 |
| turn | dt p50 | 24.82 (24.4/24.6/25.4) | 24.82 (23.4/28.0/23.1) |
| turn | dt p95 | 31.02 (30.4/30.8/31.9) | 30.06 (28.5/34.4/27.3) |
| turn | dt p99 | 34.37 (33.3/35.3/34.5) | 34.06 (32.4/37.7/32.1) |
| turn | process p95 | 9.55 | 9.32 |
| run | dt p50 | 28.42 (25.4/25.0/34.8) | 25.64 (26.1/25.1/25.7) |
| run | dt p95 | 37.80 (34.7/32.3/46.5) | 33.94 (36.3/31.6/33.9) |
| run | dt p99 | 44.91 (40.2/38.8/55.7) | 41.03 (44.7/37.3/41.1) |
| run | process p95 | 12.99 | 12.50 |
| run_turn | dt p50 | 28.02 (26.3/26.3/31.5) | 25.66 (26.1/25.2/25.7) |
| run_turn | dt p95 | 36.57 (32.5/32.2/45.1) | 30.62 (30.3/29.7/31.9) |
| run_turn | dt p99 | 43.31 (41.5/38.9/49.6) | 35.22 (35.9/34.3/35.4) |
| run_turn | process p95 | 5.07 | 4.97 |
| idle_end | dt p50 | 25.78 (25.6/25.1/26.6) | 26.73 (27.5/25.4/27.3) |
| idle_end | dt p95 | 35.61 (34.3/32.9/39.6) | 34.27 (35.0/32.7/35.1) |
| idle_end | dt p99 | 43.95 (41.6/39.4/50.9) | 41.34 (43.7/39.5/40.9) |
| idle_end | process p95 | 12.53 | 13.26 |
base n= 3 tex MB [2510, 2510, 2510] video MB [3236, 3235, 3235]
head n= 3 tex MB [2601, 2601, 2601] video MB [3328, 3327, 3327]

Frames over 50 / 75 ms and the max per run: base (1,0,57) (1,0,68) (1,0,56)
(3,0,59) (3,0,59) (6,0,68) (7,2,122) (1,0,58) (2,0,58) (14,1,97); head
(2,0,59) (2,1,103) (4,2,87) (8,5,121) (2,1,78) (12,4,141) (11,1,104) (17,2,140)
(2,1,77) (5,1,114) (1,1,80); never (4,1,115) (4,1,95) (6,3,117); nodither
(2,1,75) (7,0,73) (4,1,96). The long frames have low script (1-12 ms) and
render-CPU (2-3 ms) time and no new pipelines, i.e. a GPU-side or OS stall.

Decision: idle is ~3 ms faster at p50/p95 in every batch. Moving-phase p95/p99
differences swing from -6 to +6 ms between batches with the load, so there is
no regression separable from noise; the batch run strictly alternately favours
head. Removing the bark discard measured no better (run p95 33.8 vs 33.0 ms,
idle_end worse), so the bark keeps its dither (it is what keeps the trunk from
doubling or popping at the switch). The slightly higher rate of single 75-140 ms
frames on head persists with the cards never drawn and without the discard, so
neither causes it; open, worth a quiet-machine rerun with GPU capture.
A pre-existing startup race crashed 3 of 14 head launches (signal 11 at
`NativeRiverWalk.ready_for` -> `_gate` on a pool thread: "Caller thread can't
call this function in this node (/root)"); unchanged since the base commit.

### Tests (October 8)

test_tree_imposters 7/7 headless (267) and windowed (309);
test_dressing_commit_queue 15/15 headless (503) and windowed (508);
test_environment_catalog 25/25; test_canopy_shadows 2/2 headless, 3/3 windowed.
