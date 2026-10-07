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

## Task 4: native source search and raw contour walk

`WaterPlan.source_pos`, `_has_source_uncached` (all gates before the walk),
`_pond_level` and the raw `_walk` loop (`_contour_step`, `_contained_bed`,
`grad`, `_ascend`, `_ring_prominence`, `_jitter_pos`) run in C#
(`scripts/native/NativeRiverWalk.cs`) once `NativeRiverWalk.setup(seed)` has
verified them bit-identical for the seed (40 super-cells in +-12 cells:
source position, source gate, has_source, every walk point/bed, priority,
spring-pool level, the finished trace's widths/terminal pond/land bars, and
the native terminal-pond level; `!=` throughout). Only a plain `WaterPlan`
(not a test subclass), with the native height field ready and
`HeightfieldPlan.LOWPASS_M == 0`, is served natively. `_shape_alluvial_reach`,
`_make_pond`, `_fit_terminal_land` and the caches stay GDScript.

All timings: Godot_mono 4.5.1, headless, seed 2697992464, one process at a time.

### Identity

| check | result |
|---|---|
| parity gate, seed 2697992464 | 40 cells, 28 walks (7865 steps) identical |
| scratch sweep, 3 seeds x 225 cells (2697992464, 3046246887, 12345) | 448 walks, 0 mismatches |
| `water_block_cost --chunk=-4,-5 --no-disk` digest | `b6c965def22e7e93` (unchanged) |
| `parallel_tail_check --rounds=2` | `PASS failures=0` |
| `test_native_river_walk` | mono 1/1 (30 asserts), standard 1/1 (stays off) |
| `test_water_plan` (mono) | 29/29, 109686 asserts, 133.6 s |

### Water source solve for chunk (-4, -5) (`PROFILE_WATER_COST=1 water_block_cost --no-disk`, ms)

| stage | before (30aa163af) | after |
|---|---|---|
| harness region_ms | 11351 | 2990 |
| source solve inner region_ms | 18638 | 6990 |
| seeds_ms | 16208 | 13919 |
| harness water_ms | 52867 | 43559 |

Raw walks alone (30 cold super-cells, 22 sources): GDScript 578 ms, C# 203 ms.
The parity gate costs 1.76 s on the main thread at `WaterPlan._init` (after
the 2.17 s native height-field gate).

## Task 5: native batched carve

`HeightfieldPlan._prefetch_samples` now fills a large window in C#
(`scripts/native/NativeCarve.cs` `SampleBatch`: native height, the
`height01` wrapper, and the `WaterPlan.carve_at` river/pond carve, giving
`[h - carve, carve, h]` per point), one call per pool task, when the seed's
height field and carve are verified, the plans are plain `HeightfieldPlan` /
`WaterPlan`, `LOWPASS_M == 0`, there is no raw override, and every owner
super-cell's carve region carries a verified `"native"` copy. Otherwise the
window takes the unchanged GDScript prefetch. The serial `_sample` path is
unchanged. `carve_at`'s body after the region lookup moved, unchanged, into
`WaterPlan._carve_region(region, x, z)`.

Each carve region is flattened lazily, the first time the batched prefetch
needs it (`NativeCarve.region_for`). The flattened form holds the traces
(points, beds, widths, bank strengths, land bars, terminal pond), the ponds,
and the segment index as CSR over the region's 32 x 32 cells. The C# copy is
its own `NativeCarve` object, kept in `WaterPlan._native_regions`
(rc -> [region, copy], under the plan's lock). The published region
dictionaries are never mutated. If two threads build the same copy, the first
one stored wins. There is no handle table and no release, so an in-flight
batch keeps its regions alive.

Parity gate: it runs as copies are built. A copy must equal `_carve_region`
(`!=`) on probes in the region's own cells: 12 m lattice and quarter-metre
points on segment cells, points round ponds, and random points. Probe ground
comes from `HeightfieldPlan.natural01` directly, so `WaterPlan`'s field memo
is untouched. Probe counts per seed:

- the first 3 copies get 2000 probes each;
- the next 8 get 32 each;
- later copies get none.

One mismatch turns the seed off with a warning. `setup()` on the main thread
only loads C# and its constants.

| check | result |
|---|---|
| `test_native_carve` (mono) | 1/1, 3000 points `[h - carve, carve, h]` equal, 1296 carved, 6004 asserts |
| `test_native_carve` (standard editor) | 1/1, stays off |
| mutation: `maxf` + 1e-9 in C#, gate bypassed | test red (423 sample mismatches) |
| mutation: `maxf` + 1e-9 in C#, gate on | gate disables the seed at region (-4, -1); test red |
| `water_block_cost --chunk=-4,-5 --no-disk` digest | `b6c965def22e7e93` (unchanged) |
| `parallel_tail_check --rounds=2` | `PASS failures=0` |
| `test_water_plan` (mono) | 29/29, 109686 asserts, 133.7 s |
| `test_heightfield_plan`, `test_heightfield_lowpass`, `test_september9_water_buckets`, `test_native_river_walk` | pass |

### Water source solve for chunk (-4, -5) (`PROFILE_WATER_COST=1 water_block_cost --no-disk`, ms)

| stage | before (fe2aafcc7) | after |
|---|---|---|
| source solve inner region_ms | 9457 | 4527 |
| seeds_ms | 15610 | 8758 |
| harness region_ms | 2440 | 2464-3014 (run to run) |
| harness water_ms | 42388 | 31205-32186 |

In the first version every region was flattened, built and gated when it
was built, even regions only the serial path uses: 111 regions cost 1.48 s on
the worker (0.62 s flatten and build, 0.86 s gate), and the gate's `noise_h`
calls polluted the field memo. Fix round 1 made copies lazy, capped the gate
and read probe ground without the memo. A/B of the same tree, with
`NativeCarve.force_off` set from an environment variable for the
measurement only:

| run | harness region_ms | inner region_ms | seeds_ms | water_ms | digest |
|---|---|---|---|---|---|
| carve off #1 | 2894 | 10206 | 16642 | 44678 | b6c965def22e7e93 |
| carve off #2 | 3621 | 11059 | 17116 | 47264 | b6c965def22e7e93 |
| carve on #1 | 2470 | 7974 | 15117 | 41010 | b6c965def22e7e93 |
| carve on #2 | 2849 | 4936 | 13252 | 38777 | b6c965def22e7e93 |

These runs are noisy, about +-20%. The harness region_ms (the cold first
block region, dominated by river tracing) does not regress. The 8758 ms
seeds_ms of the first version came from the eager gate warming `noise_h`'s
memo, not from the carve. After the fix round: `test_native_carve` passes on
mono (1/1, 6016 asserts; each window's added samples equal the count the C#
batch filled) and on standard Godot; `test_water_plan` 29/29;
`test_heightfield_plan` 47/47; `parallel_tail_check` PASS.
