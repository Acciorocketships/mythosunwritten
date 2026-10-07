# Native terrain/water ports (October 7, 2026)

## Task 2: ground grids sample through the native tile kernel

`TerrainTileField.sample_grid(region, xs, zs)` (one `dense_window` + one
`sample_window` batch, grades applied after the ungraded value exactly as
`sample_baked(..., region)` does) now backs `CliffSlopeField._ground_grid` and
`WaterField._sample_ground_lattice`; the chunk mesher's quad loop collects all
96 x 96 x 4 corners (each on its quad's centre owner) and samples them in one
`sample_window` call. Under Godot_mono the batch runs in C#
(`NativeTileKernel.SampleOwned`, enabled only after its bit-identity gate).

All timings: Godot_mono 4.5.1, headless, seed 2697992464, one process at a
time on the same machine. Single runs; planning phases are noisy (+-30%).

### Identity

| harness | before (HEAD df1ce9ba0) | after |
|---|---|---|
| `profile_mesh_phases --chunks "0,-2;0,-1;1,-1"` | (0,-2) 3c960e38..., (0,-1) b7871a95..., (1,-1) 356b34c1... | `HASH CHECK: IDENTICAL` |
| `water_block_cost --chunk=-4,-5 --no-disk` digest | `b6c965def22e7e93` | `b6c965def22e7e93` |
| `parallel_tail_check --rounds=2` | - | `PASS failures=0` |

### Chunk (0, -2) mesh phases (`profile_mesh_phases --chunks "0,-2" --detail`, ms)

| phase | before | after |
|---|---|---|
| sheet (excl paths) (the quad loop) | 335 | 72 |
| d.slope_init(rocks) (includes the envelope ground grid) | 14987 | 13492 |
| cliff dressing | 84509 | 80132 |
| total | 86028 | 81781 |

### Water source solve for chunk (-4, -5) (`PROFILE_WATER_COST=1 water_block_cost --no-disk`, ms)

| stage | before | after |
|---|---|---|
| ground_ms (`_sample_ground_lattice`, 697 x 613 lattice) | 4269 | 269 |
| harness water_ms | 55072 | 47510 |
| harness region_ms | 10511 | 15100 |

The harness `region_ms` (plain `fields.region(chunk)`: heightfield
planning, which touches none of the changed sites) varied 9.9-15.1 s across
the four runs (two per side); the source solve's own inner `region_ms` was
12.6 s before and 12.8 s after.

### Fix round 1 (separable grid entry, O(1) window assert)

`NativeTileKernel.SampleGrid` / `SampleGrid32` (owners per column and per row,
no flattened sample arrays; float32 variant = `(float)` cast, parity-checked
against a PackedFloat32Array store of the GDScript reference) back
`sample_grid` / `sample_grid32`; the per-sample `_owners_inside` assert left
`sample_window` (O(1) `_window_holds` at the call sites). Identity unchanged:
mesh `HASH CHECK: IDENTICAL`, water digest `b6c965def22e7e93`.

| measure | before Task 2 | Task 2 | fix round 1 |
|---|---|---|---|
| ground_ms, water (-4,-5) | 4269 | 269 | 158 |
| d.slope_init(rocks), chunk (0,-2) | 14987 | 13492 | 13046 |
| sheet (excl paths), chunk (0,-2) | 335 | 72 | 77 |

## Task 3: remaining per-sample callers (measured under Godot_mono)

Method: temporary `Time.get_ticks_usec` accumulators around every
`TerrainTileField.*` call site (timer pair 0.05 us; not committed).

**GrassField.compute: not batched (share < 1%).** 192 real tiles (seed
3046246887, chunks (0,-2), (0,-1), (1,-1), detached `GrassSamplingContext`
with the chunks' cliff grass supports): 283 s total; `wall_segments` 0.58 s
(193 calls), owner `point_of` 0.37 s (368k), `_surface_y` (point_of + bake +
`sample_baked`, 229k calls, 1,039 bakes) 0.98 s: 0.7%. Chunk (0,-2) alone:
0.75 s of 171.7 s; even without the support-surface time below the share is
~9%. The stock `profile_grass_field.gd` (flat tile) computes in 29.9 ms.
Where grass time really goes on cliff chunks: `GrassSupportSurfaces.at_index`
57.8 s and `footprint_scale` 105.3 s (9,404 mesh-support candidates) of
171.7 s for chunk (0,-2)'s 64 tiles, ~2.7 s per tile. Not a tile-kernel
cost; left for a separate task.

**RockSkirt.build: batched (share 61-66%).** `profile_mesh_phases --detail`:
`terrain_ground` 51.2 s over 1.13M calls (~613 per skirt: centre, contacts,
and three reads per ring vertex: height, sheet test, normal's sheet test) and
the terrain normal 4.6 s, of 84.4 s in 1,846 builds. Micro-bench:
`terrain_ground` ~42 us/call, `surface_y_on_side` ~14 us, `_apply_grade`
0.2 us, a native `sample_window` sample 0.1-2.5 us. Each skirt now prefetches
the four 2 m quad corners of its 225 points in one `sample_window` call
(`RockSkirt.prefetch_corners`); `d.add_skirts` 45.8 -> 17.5 s, mesher total
over the three chunks 151.2 -> 127.3 s. `HASH CHECK: IDENTICAL`;
`test_rock_skirt_batch` (corners == `surface_y_on_side`, batched build ==
per-sample build on ungraded/native-graded/listed-grade regions),
`test_september27_rock_placement`, `test_dressing_field`, `test_grass_field`
pass.
