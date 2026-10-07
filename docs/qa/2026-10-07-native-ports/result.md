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
