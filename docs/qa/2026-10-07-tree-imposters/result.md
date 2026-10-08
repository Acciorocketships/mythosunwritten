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
