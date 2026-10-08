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

## Task 6: native water fill kernels and an exact binary heap

`WaterField._relax_fill`, `_reconcile_connected_surface`,
`_smooth_fill_surface` and `_retain_source_connected_fill` dispatch to
`NativeWaterFill` (C#, `scripts/native/NativeWaterFill.cs`) once its parity
gate passes; the GDScript bodies stay the reference. `GdPriorityQueue<T>` is
a line-for-line port of `PriorityQueue.gd` (hole sifts, `>=` / `<`
comparisons), so equal levels settle in the same order. Relax and smooth run
natively only when their ground array is complete (`not gnd.has(INF)`, one C++
scan); `_build_fill`'s lazily sampled lattice keeps GDScript. One C# call per
kernel invocation; the relax queue is handed over as the GDScript heap's
entries in heap order.

Gate: `FieldTerrainStreamer._ready` only loads the C# class (`prepare()`,
about 30 ms); the parity gate (four heap replays with heavy ties, twelve
random 20..60-side terraced lattices with river seeds, pond discs at double
levels, levels EPS above terrace steps, ceilings, shallow nodes, INF ground
for reconcile, both lattice steps) runs lazily on the first `on()` call,
i.e. the first worker water solve: about 0.4 s of GDScript reference runs,
never on the main thread in the game. Threads arriving while it runs use
GDScript (`try_lock`). Falsification: flipping the heap's `>=` to `>`, its
right-child `<` to `<=`, the relax spread's `<` to `<=`, pushing the stored
float32 instead of the double level, or a 1e-9 perturbation in reconcile
each disables the gate.

Godot_mono 4.5.1, headless, seed 2697992464, one process at a time.

| measure (`PROFILE_WATER_COST=1 water_block_cost --chunk=-4,-5 --no-disk`) | before (916fdbcdc) | after |
|---|---|---|
| relax_ms (697 x 613 source lattice) | 1767 | 69 |
| smooth_ms (smooth + reconcile) | 261 | 32 |
| harness water_ms | 31028 | 29423 |
| digest | `b6c965def22e7e93` | `b6c965def22e7e93` |

`parallel_tail_check --rounds=2`: PASS failures=0. Tests on both binaries:
`test_native_water_fill` 3/3, `test_september9_water_containment` 18/18,
`test_september10_water_surface` 7/7 (+2 pending, as at baseline),
`test_september10_water_relaxation_work` 2/2,
`test_september11_water_rounding` 1/1, `test_september15_water_drops` 8/8,
`test_september15_water_source_connectivity` 5/5, `test_priority_queue` 2/2.

## Task 7: native spill search and hydrostatic cap

`WaterField._cap_hydrostatic_fill` dispatches to
`NativeWaterFill.CapHydrostatic` (C#) when its `ground` is dense
(`not ground.has(INF)`) and the uncarved ground is absent or dense. The C#
holds a private port of `SpillSearch` (escape / marks / distance arrays,
generation counter, reverse minimax search stopping at the first finite
escape, the same memo writes) on `GdPriorityQueue<int>` (new `Clear()` =
`heap.clear()`). Ceilings stay float32, like the GDScript's
`levels.duplicate()`. The GDScript `SpillSearch` is unchanged and still serves
the fine rescue (`_build_sub_lattice_rescue`) and the lazy (region) callers.

`_source_fill` now samples the uncarved `natural` region once, densely
(`_sample_ground_lattice` -> `TerrainTileField.sample_grid32`, one native call),
instead of lazily through `_ground_at`'s baked path inside the cap.
`_cap_hydrostatic_fill`'s `natural` accepts that dense array or a region (the
lazy path, kept for tests and probes). Proof:
`test_dense_natural_ground_equals_the_lazy_samples_on_a_real_domain` (seed
2697992464, a 70 x 61 source lattice at the -4,-5 domain's base, carved
channels present): every node equal.

Gate: the twelve random lattices also run the cap (relaxed flood plus a
uniform high head on 60% of dry nodes, river anchors, a dense uncarved ground
on 8 of 12, mixed INF / -INF / finite flow ceilings). Gate cost about 0.53 s
(was about 0.41). Falsification: `<` -> `<=` in the memo write disables it
("hydrostatic cap differs (case 0)").

| measure (`PROFILE_WATER_COST=1 water_block_cost --chunk=-4,-5 --no-disk`) | before (ba3d4ae46) | after |
|---|---|---|
| cap_ms | 3992 | 39-87 |
| natural_ms (region + now the dense sample) | 1059 | 1068-1795 (noise) |
| spill_ms (natural + flow + cap + retain) | 5906 | 1974-3408 |
| harness water_ms | 28100 | 25055-27863 |
| digest | `b6c965def22e7e93` | `b6c965def22e7e93` |

`parallel_tail_check --rounds=2`: PASS failures=0. Tests:
`test_native_water_fill` 5/5 (both binaries), `test_september9_water_containment`
18/18 (both), `test_september15_water_source_connectivity` 5/5 (both),
`test_water_field` 25/25 (mono). `test_september9_source_domain_cache` fails
1/1 on both binaries, identically at ba3d4ae46 (its `CountedPlan.compute_region`
count reads 0: pre-existing, unrelated to this task).

## Task 8: native river seeding (segment claims and containment)

`WaterField._seed_rivers` is split into `_river_claims` (per trace: bank
strengths and `profile()`, still GDScript until Task 9), `_claim_rivers`
(`_claim_river_segment` over the dense descent curves and the trace samples;
returns the margins) and `_contain_rivers` (pond-owned banks, the ground gate,
`_settle`). The GDScript stays the reference and fallback; the signature of
`_seed_rivers` is unchanged for its callers and probes.

C#: `scripts/native/NativeWaterSeed.cs` (a partial of `NativeWaterFill`)
mirrors `_claim_rivers` + `_contain_rivers` + `_seed_ponds` over a complete
ground lattice (float32 `V2` math for q, ab, nearest and distances, double
lerps, float32 margin/level storage, the 0.0001 tie rule, the terminal-pond
collar test) and pushes the offers through the `PriorityQueue.gd` port in the
same order; the heap comes back as three arrays (`GdPriorityQueue.ExportHeap`).
`_source_fill` uses it through `WaterField._seed_sources_native` (native on,
ground dense), takes `source_indices` straight from the heap index array and
relaxes with `NativeWaterFill.relax_heap`, so the queue never becomes a
GDScript Dictionary heap (that conversion was most of the old relax_ms).
Per trace only array references are flattened (no per-sample marshalling).
`PondStamp` geometry is shared: `GdPond.cs` (radius_at, footprint_t,
bound_radius, surface_y, read from `NativeCarve.gd.flatten_ponds`) now serves
both NativeCarve and the seeding; `flatten_ponds` maps a pond to its first
occurrence.

Gate: `_seed_parity`, appended to the existing lazy NativeWaterFill gate: 16
random terraced lattices, 1-6 rivers (single-point and zero-length segments,
descent spans, half-metre level ties, bank weights 0..1), 0-3 ponds with
aspect and ceilings, terminal ponds in and outside the pond list, and a twin
river whose widths are 0..0.0003 wider (margins inside and just outside the
tie band). Compares river levels, margins and the heap (index, level,
priority) with `!=`. Gate total 0.56-0.57 s (was about 0.55). Falsification:
`margin < current - 0.0001` -> `0.00011` disables it ("river seeding differs
(case 5, 40x41)"); `abs <= 0.0001` -> `0.00009` disables it ("river claim
margins differ (case 3)"). The real-domain test also fails on the first.

Tests: `test_river_seeding_matches_gdscript_on_real_domains` (seed
2697992464, four real source lattices 61-72 rows: contributors from
`bodies_in_rect`, the owned region, the dense carved ground; river levels,
margins, source indices, seed levels and priorities equal) and
`test_seeded_heap_relaxes_like_the_gdscript_queue` (the September 9 bank
fixture with complete ground and a terminal pond, through relax).

| measure (`PROFILE_WATER_COST=1 water_block_cost --chunk=-4,-5 --no-disk`) | before (b69495aac) | after |
|---|---|---|
| claim_ms | 1391 | 22.5 (C#) |
| containment_ms (+ pond seeds) | 800 (+ ~37) | 9.7 (C#, ponds included) |
| native call incl. marshalling | - | 35.8 |
| profile_ms (Task 9) | 6993 | 6548 |
| seeds_ms | 9220 | 6585 |
| relax_ms | 43.6 | 16.9 |
| harness water_ms | 24704 | 21382 |
| digest | `b6c965def22e7e93` | `b6c965def22e7e93` |

`parallel_tail_check --rounds=2`: PASS failures=0. Tests (mono and standard):
`test_native_water_fill` 7/7, `test_september9_pond_seed_queries` 1/1,
`test_september9_water_containment` 18/18,
`test_september15_water_source_connectivity` 5/5; `test_native_carve` 1/1 and
`test_water_field` 25/25 (mono).

## Task 9: hydraulic profiles (corridor terrain, knot search in C#)

Measured first: `profile_ms` (7.1 s on chunk (-4,-5)) was 96% building the
trace-owned regions (`_trace_owned_region` -> `compute_rect_region` over each
trace's bounding box plus the 40-point clamp margin, 16-64 k points each, 22
traces): about 3.3 s sampling cold heights over the margin, 2.6 s of GDScript
region kernel, 0.2 s of dictionaries. Ground samples and the knot search were
about 0.26 s. So the port covers both: the profile math, and the terrain it
reads, without building a region.

- `NativeWaterProfile.cs` (partial `NativeWaterFill`): `ProfileLattice` lists
  every lattice point the profile can read (the 3 x 3 points round the owner
  of each trace point, every `_descend_segment` substep and every span's dense
  point: a superset, since which are read depends on ground); `Profile` is the
  terrain-shaped branch of `profile()` (spans, `_descend_segment`,
  `_shape_descent_span`, `_dense_span_curve`, the Fritsch-Carlson knot search
  on parallel int/double lists, `_dense_span_points`, the terminal pond
  reconcile) over that lattice data, sampled with `NativeTileKernel.Sample`.
- Corridor terrain (`CorridorPoints` / `CorridorDisks` / `CorridorTerrain`):
  `compute_rect_region`'s certified values on just those points. A certified
  storey is min over q of target(q) + max_step * |p - q|_1 (targets >= 0, so
  only q closer than ceil(target(p) / max_step) - 1 can lower it: the disk
  union is sampled, then one separable L1 distance transform); a level reads
  storeys within (LEVELS - 1) relaxation + (CLIFF - 1) cliff-distance steps +
  one ring (7 points). Samples come from `HeightfieldPlan.sample_heights`
  (the `_sample` memo; misses filled by `NativeCarve.sample_batch`, on the pool
  from 512 misses when not already on it).
- `WaterField.profile` = cache + `_profile_compute(trace, region, plan_backed,
  native)`; `_profile_native` takes corners from a region the GDScript would
  read (an earlier trace region, the caller's certifying region, a hand-built
  natural region) or else the corridor; graded/duck regions and plan
  subclasses without a certifying region stay GDScript.
- `HeightfieldPlan.region_kernel` (static) is `compute_rect_region`'s kernel
  split out unchanged, so the gate can run it on synthetic samples.
- Gate (appended to the lazy NativeWaterFill gate; the earlier 12 fill cases
  are unchanged): 15 random traces (zero and 0.0004 m segments, storey drops,
  pools under DESCENT_POOL_GAP, EPS ties, source pools, terminal ponds
  above/below the end) over random natural regions with cliffs (local-bed,
  source-height and low ground), profile vs `_profile_compute(..., native =
  false)` (levels, `var_to_bytes(descents)`); 3 random corridor cases (one per
  aggregation, terraced blocks with diagonal-only cliffs, pits, x.5 storeys
  and levels) and 6 sparse cone cases (one point / a diagonal line of 3 x 3
  blocks, max_step 1-3, 12 storeys: targets ms * (|x - pit|_1 + 1) round a
  pit 8 points outside the corridor, so only the outermost clamp disks reach
  it, at exactly their radius) vs `region_kernel`. Gate total 0.76-0.78 s in
  quiet fresh-process runs (0.64 s before Task 9; runs with another
  session's Godot busy read 1.0-1.2 s).
- Moved to tests (`test_native_water_profile`): 12 random corridor cases and
  the cones at production scale (120 storeys, max_step 3 and 1).
- Falsification (each disables the gate): knot tie `>=` -> `>`; FILM + 1e-3;
  FC limit 3.0 -> 2.9; pond trailing raise ps + 1e-3; dense pond raise ps - 1e-3;
  steep-pond dense pin + 1e-3; pool gap `>=` -> `> + 3`; width lerp + 1e-3;
  resample t + 1e-4; diagonal cap removed / always on; storey rounding
  floor -> round, ceil -> floor + 1, away-from-zero -> banker's; clamp DT step
  + 1; clamp radius one below ceil(t/ms) - 1 (red only since the cone cases,
  fix round 1; also red in the production-scale test). Mutations that are
  equivalent: cliff-distance depth and relaxation depth one shorter (the
  relaxation from the boundary cell implies the cap; a 3-step path cannot
  lower a level <= 3), and widening the radius from ceil(t/ms) - 1 to
  ceil(t/ms) (distance ceil(t/ms) can never lower the storey). The first
  version of this section called a radius one smaller than the shipped one
  equivalent: wrong. On a sparse corridor a pit just outside it is reached
  only by the outermost disks at exactly their radius (review counterexample,
  ms 1: target 3, neighbour 2, pit at distance 2 -> storey 2, not 3).

Tests: `tests/test_native_water_profile.gd` (30 real traces of seeds
2697992464 and 3046246887, 260 descent spans, all native: corridor and a
certifying-region source vs the GDScript over `_trace_owned_region`, levels
and descents exact). Red check: with the gate bypassed and the knot tie
mutated, 6 of 80 asserts fail.

| measure (`PROFILE_WATER_COST=1 water_block_cost --chunk=-4,-5 --no-disk`) | before (927892fee) | after |
|---|---|---|
| profile_ms | 7097 | 1839 |
| seeds_ms | 7134 | 1871 |
| harness water_ms | 22609 | 17376 |
| harness region_ms | 2194 | 2165 |
| cold block (region + water) vs the plan's 59 s | 24.8 s | 19.5 s |
| height samples computed | 381638 | 223960 |
| digest | `b6c965def22e7e93` | `b6c965def22e7e93` (also `--serial`) |

What remains in profile_ms is cold height sampling of the corridors (about
150 k points, native batches) and the GDScript memo reads.
`parallel_tail_check --rounds=2`: PASS failures=0. Tests (mono):
`test_native_water_profile` 1/1, `test_native_water_fill` 7/7,
`test_water_field` 25/25, `test_september15_water_profile_work` 3/3,
`test_water_dual_grid` 17/17; standard: `test_native_water_profile` 1/1
(native off), `test_native_water_fill` 7/7, `test_water_field` 25/25,
`test_september15_water_profile_work` 3/3. Pre-existing failures, identical at
HEAD 927892fee: `test_river_generation::test_production_channel_has_no_dry_diagonal_interruptions`
(`river_for` returns null: geography-pinned) and
`test_september9_water_profile_retention::test_completed_profile_keeps_its_values_without_retaining_construction_terrain`
(counts `compute_region` overrides; the trace region uses `compute_rect_region`).

Phase 3 exit check: the fine rescue (`fine_ms` 8.0-9.2 s) is now the largest
water cost, ahead of spill (1.9-3.5 s), source region (3.7 s) and profiles
(1.8 s). Follow-up: measure `_fill_bilinear_coarse`, wall spans and shore
support inside it before porting (`docs/superpowers/plans/2026-10-07-native-fine-rescue-followup.md`).

240 s walk (`travel_profile.tscn -- --seconds 240 --mode walk --startup-timeout
3000`, Godot_mono, windowed): startup 155 s, distance 1004 m, frozen 134.9 s
(earlier today, before Task 9: 1037 m, 121 s frozen). Single run each: no
change in walking freeze within run-to-run noise; the walk's frozen time is
not bound by profiles (fine rescue, cliff dressing and cold planning remain).
Walk frame p50 6.8 ms, p95 15.6 ms, p99 28.3 ms.

### Task 9 fix round 1

- `_parity`'s fill/relax/smooth/reconcile cases restored to 12 (a stray sed
  had cut them to 9).
- Sparse cone corridor cases in the gate (12 storeys) and at production scale
  in `test_native_water_profile` (120 storeys, max_step 3 and 1); the random
  corridor cases are split: 3 in the gate, 12 in the test
  (`NativeWaterFill.corridor_random`, `cone_case`, `corridor_check`).
- Red check: `ClampRadius` one smaller (`/ maxStep - 2`) -> gate "corridor
  terrain differs (mean, step 1, 12 storeys) (cone case 0)", and with the
  gate bypassed the production test fails 3 of 84 asserts; restored, green.
- `_profile_native`: dropped the unreachable `_trace_regions` source;
  `profiles_served` no longer takes the mutex.
- Gate 0.76-0.78 s (quiet runs). Tests: `test_native_water_profile` 3/3 and
  `test_native_water_fill` 7/7 on mono and standard (native off there),
  `test_water_field` 25/25 mono. Digest `b6c965def22e7e93`;
  `parallel_tail_check --rounds=2` PASS failures=0.

## Task 10: native cliff envelope (the whole numeric build in C#)

`CliffSlopeEnvelope.build` keeps its inputs in GDScript, unchanged: the ground
grid (native `sample_grid`), the keep-out mask with its coarse-then-edge
refinement, and `_levels` (adaptive water queries). New: `_wall_lines` gathers
the ground on both sides (+-0.001) of every 12 m wall line `_walls` scans, as
the same float32 points, in two batched `TerrainTileField.sample_grid` calls
(`CliffSlopeField._ground_points`; a `ground_at` loop only for callable-only
callers such as tests). Everything after that runs in
`scripts/native/NativeCliffEnvelope.cs` when `NativeCliffEnvelope.on()`:
`_walls`, `_close_walls` (x4, with `_channel_scale` and the corner rounding),
`_lips` (insertion-ordered map, float32 run values as the Vector2 stores
them), the transforms, `_ridges`, blend, fillet, caps, `_distance`,
`_bedrock`/`_bench`/`_bench_profile`, `_level_outward`, `_moss_grade` (the
no-wall shortcut too). `always_transform` (tests) stays GDScript.

One numeric trap: `Vector2.snapped` runs Godot's `Math::snapped` in double; in
float32 a tie at x/step + 0.5 rounds up (0.12499999 snapped to 0.25 instead
of 0). Found by the per-stage comparison ("stage ridges differs").

Gate: lazy, like NativeWaterFill (`prepare()` in the streamer, first `on()`
on the first chunk tail, try_lock): constants list + 4 synthetic 28 m sites
(storeyed walls with corners, a wall ending in a slope, a jump off the wall
lines, a road, a channel fitted between two walls (1702 channel nodes), the
plain sheet, ground without walls; 290/187 carved bedrock nodes). 0.45 s
cold. Debug knob: `NATIVE_CLIFF_ENVELOPE_OFF=1` keeps the GDScript build in
the .NET binary. Test `test_native_cliff_envelope.gd`: P03 fixture (bedrock
and plain), 12 synthetic point regions through the real tile kernel (half with
the batched grid/line samples), the dispatch; every stage's arrays compared
(`CliffSlopeEnvelope.capture_stages`).

| check | result |
|---|---|
| `profile_mesh_phases --chunks "0,-2;0,-1;1,-1"` vs HEAD | `HASH CHECK: IDENTICAL` |
| `--seed 2697992464 --chunks "2,4;1,4;1,3"` (cliffy) vs `NATIVE_CLIFF_ENVELOPE_OFF=1` | `HASH CHECK: IDENTICAL` |
| `parallel_tail_check --rounds=2` | PASS failures=0 |
| tests (mono / standard) | shortcuts 4/4, sheet_ends 8/8, sheet_normals 2/2, sept26_bedrock 5/5, sept28_ground_seams 5/5, native_cliff_envelope 4/4 (standard: enabled == false), native_grid_kernels 1/1 |

`d.slope_init` (`--detail`, Godot_mono, ms):

| chunk | before | Task 10 |
|---|---|---|
| (0,-2) | 12812 | 5664 |
| (0,-1) | 5099 | 1118 |
| (1,-1) | 11205 | 3588 |
| seed 2697992464 (2,4) | 10506 | 4755 |
| (1,4) | 13049 | 5393 |
| (1,3) | 6326 | 1525 |

What remains in `slope_init` is the GDScript input stage: `SLOPE_ENV_PROFILE`
on (1,4) (625x625 grid) shows exclusion + water levels 15.7 s on the cold
timed build (water contexts) and 1.35 s warm, against 0.39 s for the whole
native rest (wall-line samples included). Next target: `_exclusion` /
`_water_level` queries.

## Task 11: native cliff solid (bedrock surface net in C#)

`CliffSlopeField.solid` (production `sheet_bedrock`, no rock swells) now runs
in `scripts/native/NativeCliffSolid.cs` when `NativeCliffSolid.on()`:
`_columns` with `_window_max` (returned as a row-major `ColumnMask` with the
Dictionary's `has` / `is_empty`, also used for `env.replacement_columns` and
by `grass_support`), the per-column `_solid_top_over` / `_mesh_height`, the
level ranges (float32 column values), the surface-nets meshing (points /
field order, vertex snap, winding by grid edge, degenerate threshold),
`_drop_fragments` and the per-vertex gradient normal, rock exposure and moss
grade, plus the AABB (float32 `expand`). The 2 m quad corners `_mesh_height`
bakes are presampled in one `TerrainTileField.sample_grid_window` call (two
samples per quad and axis, each owned by the quad centre's lattice point);
a region with a grade list grades only the quads the columns read
(`NeededQuads`). GDScript rebuilds `native_roots` from the parallel arrays in
first-occurrence order. `solid(owned, mode)`: 0 auto, 1 GDScript, 2 native.

Numerics: `Vector3.snapped` evaluates `Math::snapped` in double (as Task 10
found for Vector2); Vector3 sums, cross products, lengths and normalize in
float32 without FMA; Variant Vector3 keys compare with float `==`.

Gate: lazy like the envelope (`prepare()` in the streamer, first `on()` on a
chunk tail, try_lock, only while `sheet_study == "bedrock"`): constants + 3
synthetic `HeightfieldRegion` sites (stepped massif, cliff ending in a slope
with a keep-out stripe, cliff beside a gentle slope) with a small envelope
(owned rect grown by 8 m), comparing faces, every placement field,
`native_roots` keys/values/order, and both column sets. 0.41-0.46 s cold
(C# load and JIT included). Debug knob `NATIVE_CLIFF_SOLID_OFF=1`.
Test `test_native_cliff_solid.gd`: gate, P03 fixture (no region), 96 m
windows of seed 2697992464 chunks (2,4), (1,4), (1,3) through the real tile
kernel (one with a grade list), and the dispatch incl. grass support.

| check | result |
|---|---|
| `--chunks "0,-2;0,-1;1,-1"` native | hashes 3c960e38 / b7871a95 / 356b34c1 (= HEAD, recorded above); vs `NATIVE_CLIFF_SOLID_OFF=1` `HASH CHECK: IDENTICAL` |
| `--seed 2697992464 --chunks "2,4;1,4;1,3"` native vs HEAD-tree GDScript baseline | `HASH CHECK: IDENTICAL`; `NATIVE_CLIFF_SOLID_OFF=1` vs the same baseline: IDENTICAL |
| `parallel_tail_check --rounds=2` | PASS failures=0 |
| tests (mono / standard) | shortcuts 4/4, sheet_ends 8/8, sheet_normals 2/2, sept26_bedrock 5/5, sept28_ground_seams 5/5, sheet_tiles 2/2, native_cliff_envelope 4/4, native_cliff_solid 5/5 (standard: enabled == false) |

`d.solid` (`--detail`, Godot_mono, ms; before = `NATIVE_CLIFF_SOLID_OFF=1`):

| chunk | before | Task 11 |
|---|---|---|
| (0,-2) | 10400 | 336 |
| (0,-1) | 2036 | 47 |
| (1,-1) | 9570 | 250 |
| seed 2697992464 (2,4) | 10569 | 261 |
| (1,4) | 12147 | 317 |
| (1,3) | 5077 | 111 |

`d.grass_support` also drops a little (native columns): 3324 -> 2582 ms over
the first set. The cliff dressing's largest remaining stages are now
`d.add_skirts` (2.4-8.7 s) and `d.mesh_arrays` (0.5-4.3 s).

## Task 12: rock skirts (memoized tints, node normals)

The skirt ring's terrain ground samples were already batched by Task 3
(`RockSkirt.terrain_surface` `prefetch` + corner memo). Two per-surface memos
(each surface is built and read by one thread: a slope rock's skirt in
`CliffSlopeField.skirt`, or an ambient candidate's in `DressingField._skirt`):

1. `tint`: the 24 m lattice corner tints (`BiomeRegistry.ground_tint_at`,
   was 4 calls per vertex). Test
   `test_rock_skirt_batch::test_skirt_tints_read_each_lattice_corner_once`
   (counting `corner_tint` hook; red at 4/vertex, green at <= corners touched,
   colours equal).
2. `normal`: the terrain normal ran `TerrainChunkMesher.field_normals` on the
   2 m quad's four nodes for every vertex; it is per node and pure in the
   node, so the surface memoizes node -> normal.

| check | result |
|---|---|
| `--chunks "0,-2;0,-1;1,-1"` vs HEAD 3fc32682d baseline | `HASH CHECK: IDENTICAL` after each commit |
| `--seed 2697992464 --chunks "2,4;1,4;1,3"` vs HEAD 3fc32682d baseline | `HASH CHECK: IDENTICAL` after each commit |
| `parallel_tail_check --rounds=2` | PASS failures=0 (both commits) |
| tests (mono) | rock_skirt_batch 3/3, september27_rock_placement 10/10, dressing_field 6/7 + 1 pre-existing risky (no assert) |

`d.add_skirts` (`--detail`, Godot_mono, ms; single runs, noisy ~±20%):

| chunk | before | tints | + node normals |
|---|---|---|---|
| (0,-2) | 10289 | 4039 | 2589 |
| (0,-1) | 1491 | 568 | 414 |
| (1,-1) | 5531 | 1744 | 1698 |
| seed 2697992464 (2,4) | 6184 | 2695 | 1643 |
| (1,4) | 5533 | 1882 | 1354 |
| (1,3) | 2947 | 1242 | 645 |
| totals | 17311 / 14664 | 6351 / 5820 | 4701 / 3642 |

Breakdown after the tint memo (instrumented, chunk (0,-2), 519 skirts,
3.83 s): normal 2.28 s (60%: terrain `field_normals` per vertex, now
memoized), prefetch 0.27, grass_support 0.26, tint 0.24, append loop 0.23,
height+bump 0.21, triangles 0.18, sheet flag 0.17, setup 0.05. What remains
is spread over many small GDScript loops (~0.5 ms per skirt); no single
dominant hotspot left.
