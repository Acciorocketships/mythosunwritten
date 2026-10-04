# Performance profiling and optimisation plan (2026-10-04)

Owner request: the game lags while running around and terrain generation
takes very long. Profile framerate and region-load time (including while
moving), find the specific causes, test hypotheses, land small safe fixes,
and plan the larger ones (including moving math-heavy code to C#).

Branch `claude/terrain-generation-overhaul-adb98f`. Measurements are at
`e1e738d1c` (clean, without the terrain session's later uncommitted 480 m
amplification, which makes `compute_region` ~55% slower on top of this) plus
the fixes below, seed 2697992464, Apple M1 Pro, Godot 4.5.1 (non-.NET).

## How it was measured

- **Function-level GDScript profiler, all threads.** `tools/profiling/gdprof.py`
  is a minimal
  Godot remote-debugger server: run any scene/script with
  `--remote-debug tcp://127.0.0.1:PORT`; it enables the script profiler and
  accumulates per-function calls / self / total time across frames,
  including the terrain worker thread. Numbers are ~2-4x inflated by
  profiler overhead on call-heavy code; ratios are reliable.
- `tests/harness/profile_startup_threaded.gd` (new): production `_ready`
  order, then the startup feature contexts and support chunks on a worker
  thread while frames tick (so the profiler reports), per-stage timings.
- `tests/harness/travel_profile.tscn` (existing; `--startup-timeout` added):
  real character walking / render ablation, `PROFILE_STREAMING` telemetry.
- `tests/harness/profile_chunk_commit.gd` (new): windowed per-step cost of
  integrating chunks (no road layer, so no cold road planning);
  `--chunks=`, `--skip=` ablations, idle-frame baseline.
- Microbenchmarks: GDScript vs C# noise core (`tools/profiling/noise_bench.cs`);
  queue/grass/stencil old-vs-new identity checks; collision-shape build cost
  (Godot Physics vs Jolt vs HeightMapShape3D).

## Findings

### 1. Cold startup: 15 min to playable, ~13 min of it is road/water planning

| Stage (clean HEAD) | Time |
| --- | --- |
| `_ready` on the main thread (before the loading screen can animate) | 34-39 s -> **10.8 s (fixed)** |
| spawn chunk's feature context (`PathPlan`, roads + town sites) | **757 s** headless |
| other 24 startup feature contexts | < 50 ms each (warm) |
| 9 startup support chunks | 3.4-15 s each |
| windowed live run to `startup_loading_complete` | 889 s |

Inside the 757 s: `PathPlan._compute_node` (deciding whether each nearby
settlement site is dry and flat) took 589 s for 7 nodes; 406 s of that is
`WorldFieldBlockCache.water_at` -> `WaterFieldContext.build`, i.e. a
complete hydraulic water solve of each block a candidate site touches
(single blocks took 75-192 s, e.g. (-6,-3), (-2,2), (1,-2), up to 1.2 km
from spawn). Those solves, and the cold river planner before them, are in
turn ~90% **terrain height samples**: `TerrainField.height_m` was called
4.0 M times (WaterPlan.smooth01 2.65 M direct, noise_h 1.39 M, lattice
`_sample` misses ~0.76 M), at ~25-60 us each unprofiled.

Inside `height_m` (profile, self time): `LandformFeatures._memo` 35-73 M
calls (18 memo lookups per sample: `_main` + `_links_owned` for each of 9
cells; every lookup locks a mutex twice, builds a `Vector3i` key, does a
nested dictionary get and allocates a lambda even on a hit),
`LandformFeatures.sample`, `TerrainRegimeField.sample`,
`LandformSetpieces._cached` (35 M), `Helper._value_noise_corners` /
`_mix64` (27 M / 92 M).

### 2. Main-thread startup was decoding the same 4K textures 3+ times (fixed)

The 12 Meadow rock visuals reference 4096x4096 RGBA8 textures stored
losslessly (~0.4-0.55 s to decode each). `DressingCompiler` loaded each
visual to read its base stencil and dropped it, so rocks 7-12 re-decoded
`T_Rock_06_*`; the render cache then loaded them all again, and
`CliffSlopeRocks.prepare` loaded the 17 source GLBs one by one (whose own
textures it never uses).

### 3. Streaming throughput: the worker cannot keep up with walking

At 10 m/s the player crosses a 192 m chunk every 19 s; each crossing asks
for a new row of 7 chunks (CHUNK_RADIUS 3 = 49 chunks) plus feature blocks.
Measured worker cost per chunk: 2.3-5 s on dry ground (terrain mesh +
cliff sheet 2.9-8 s of it with cliffs, `cliff_formations` up to 41 s), and
13-268 s when a new hydraulic water domain is needed. In the 240 s live walk
the worker built 3 chunks; the player was **frozen 100+ s** after 400 m,
waiting for ground. One worker thread on a 10-core machine.

### 4. Main-thread hitches while moving

| Source | Before | After |
| --- | --- | --- |
| `_request_neighborhood` on each chunk crossing (re-sorted the whole queue on each of ~90 enqueues, with a backlog) | 50-154 ms | **3.4-4 ms (fixed)** |
| `_refresh_job_priorities_locked` every 8 m of travel | ~4.5 ms | open (Task 7) |
| `GrassStreamer.desired_tiles` every frame | 0.80 ms | **0.49 ms (fixed)** |
| terrain chunk integration (`commit_chunk`) | 23-36 ms, of which collision BVH build (`ConcavePolygonShape3D.set_faces`, 18,432 tris) 12-23 ms | open (Task 5) |
| whole frame in which a chunk is integrated (commit + first draw) | 45-60 ms; 200-1030 ms on first use of a material/pipeline | open (Task 5, 6) |
| cliff-heavy chunk commits (live) | 300-870 ms | open (Task 5) |

The per-chunk frame cost is the same whether the worker is busy or idle
(`profile_chunk_commit.gd --serial`), and skipping any single part (surface,
collision, dressing) only removes that part's share: it is the sum of the
steps, led by the collision BVH build.

Steady-state rendering is not the problem in the scenes measured. Render
ablation at spawn (`travel_profile --render-only`, 1280x720 window, vsync
off): full 5.5 ms mean / p99 8.9 ms; no shadows 4.9; no atmosphere 4.9;
half resolution 5.2; no grass / nature / water ~5.5. Idle with nine chunks
drawn: 4.6 ms (p95 6.7). The live walk averaged 5.5 ms (p95 8.5, p99 10.1,
max 1036 ms). The lag the owner feels is the hitches above plus the player
being frozen while terrain catches up. (Dense towns and cliff areas were
not reached in these runs; profile them once streaming keeps up.)

### 5. Textures

~20 Meadow textures at 4096^2 RGBA8 uncompressed with mips: ~89 MB each in
VRAM, ~1.8 GB total, for rocks a few metres across; plus the source GLBs'
unused textures. (`terrain/environment/textures/meadow` is 372 MB on disk.)

### 6. Release-build correctness bug (fixed)

Five `assert(...)` calls did real work in their expression (render-cache
`prepare`, a visual load, two `occupancy.add_all` mutations). Asserts are
compiled out of release exports, so an exported build would have skipped
them.

## Landed (small, output-identical)

- `760f32e97` startup visuals decoded once, in parallel
  (`scripts/core/ResourcePrefetch.gd`, render cache prepared before the
  compilers); stencil scan reads only the near-ground band. `_ready`
  39 s -> 10.8 s; stencils byte-identical. Stream queue sorted once per
  request batch under one lock: identical order, 50-154 ms -> 3.4-4 ms.
- `0a55d1293` `GrassStreamer.desired_tiles` distance cache: identical on
  3,200 origins, 0.80 -> 0.49 ms/frame.
- `06183069d` side-effecting asserts; `profile_chunk_commit.gd`.

## Plan (larger or riskier work)

Ordered by expected impact per unit of risk. Owner of the heightfield /
water files is the terrain-regime work; coordinate before touching
`TerrainField`, `LandformFeatures`, `TerrainRegime*`, `LandformSetpieces`,
`RegimeRelief`, `ReliefPrimitives`, `WaterPlan`.

### Task 0 - document the tooling

`tools/profiling/gdprof.py` + `show_profile.py`, `profile_startup_threaded.gd`
and `profile_chunk_commit.gd` are in the repo; add the loop to AGENTS.md
(not done here: AGENTS.md carries the terrain session's uncommitted entry).

### Task 1 - compiled height field (biggest single win)

Measured: the noise/hash core (`Helper._value_noise01` + `_mix64` +
`_cell_hash01`) in C# runs at **0.0146 us/call vs 0.93 us** in GDScript
(cached) - **~64x** - and produced a **bit-identical** checksum over 1 M
samples (GDScript `int` is 64-bit two's complement with arithmetic `>>`;
C# `long` matches exactly). `height_m` is pure arithmetic over seeds and
positions, so the same port should give 30-60x on the function that is
~90% of cold planning: the 757 s spawn context would become roughly
15-30 s before any algorithmic change.

Options:
- **C# (Godot .NET).** Needs the Godot .NET editor/export templates instead
  of the current standard build (the .NET 9 SDK is already installed), a
  `.csproj`, and C# export templates. GDScript keeps working beside it.
  Each GDScript->C# call costs roughly 0.5-1 us of marshalling, so expose
  batch APIs (`HeightsAt(PackedVector2Array)`, region grids) and/or move
  whole consumers (the river contour walk, region fill) across, not a
  per-sample call from GDScript. Easiest to write and debug.
- **GDExtension (C++ via godot-cpp, or Rust via gdext).** Works with the
  existing non-.NET binary and exports, lowest call overhead, but needs a
  native toolchain and per-platform builds.

Either way: port `TerrainField.height_m` and its dependencies as one
module, keep the GDScript as the reference, and add a parity test over a
fixed point set (bit-identical, as the benchmark shows is achievable).
Do this **after** the regime/landform design settles, or each design change
must be made twice. Recommendation: C# if the owner is happy to switch to
the .NET editor; otherwise Rust/C++ GDExtension.

### Task 2 - cheaper GDScript height sampling (until/unless Task 1)

Output-identical ideas, all in the terrain session's files:
- Cache the 3x3 neighbourhood gather per landform cell (features + owned
  links whose radius can reach it) so `LandformFeatures.sample` does one
  memo lookup instead of 18; check the cache before building the lambda;
  make worker-confined memos lock-free.
- `LandformSetpieces._cached` (35 M calls): same treatment.
- `WaterPlan.smooth01`/`noise_h` (4 M uncached samples): memoize per exact
  query point within a trace, or sample a lattice once per traced region.
Expected 2-3x on `height_m`.

### Task 3 - persistent planning cache for the pinned seed

`world.tscn` pins `SEED_OVERRIDE = 2697992464`, so every launch redoes the
same ~13 min of cold planning. Cache the pure, seed-level results on disk
(`user://plan_cache/<seed>/<code-hash>/`): `WaterFieldContext` fill arrays
per block, `PathPlan` nodes/routes/bridges, `VillageRecord`s, height
regions. Key on the seed plus a hash of every script that feeds them, so a
code change invalidates it. Warm launches would skip straight to meshing.
Medium size; the risk is staleness, which the code hash controls.

### Task 4 - more than one worker thread

Chunk jobs are independent pure functions once their inputs exist; the
caches are worker-confined dictionaries (some already behind mutexes).
Options, in increasing scope:
1. Run the per-chunk pure tail (mesh, cliff sheet, water skin, dressing,
   grass sampling, fx: 2.3-8 s of a dry chunk) on `WorkerThreadPool` tasks
   once the region/water/feature context exists; keep planning serial.
2. Give each of N workers its own `WorldFieldBlockCache`, or make the block
   cache's region/water entries compute-once futures shared by workers.
With 8 performance cores, (1) alone should roughly quadruple steady
streaming throughput, which is what the frozen walk needs.

### Task 5 - spread / shrink chunk integration

- Integrate a chunk over several frames (surface mesh, collision, cliff
  sheet, dressing in separate frames), keeping the readiness gate on the
  collision step.
- Collision BVH (the largest step). Measured on the same 18,432-triangle
  2 m sheet: Godot Physics `ConcavePolygonShape3D` 20-25 ms; **Jolt is not a
  fix** (0.4 ms at `set_faces`, but 12-28 ms once the body enters the space:
  it only defers the build); `HeightMapShape3D` of the same grid **0.06 ms**.
  A heightmap cannot hold the two heights a wall line has, so use it for
  wall-free chunks/tiles (check that Godot's cell diagonal matches the
  mesher's v00-v11 split) and keep the trimesh for wall tiles plus the
  existing wall skirts. Alternatively drop coplanar 2 m quads from the
  trimesh (flat and graded ground).

### Task 6 - shader/pipeline warm-up during loading

First use of each material costs 300-880 ms. During the loading screen,
draw one instance of every terrain/cliff/water/grass/dressing material
off-screen (Godot 4.5 pipeline cache + ubershaders help, but custom
shaders still compile on first draw).

### Task 7 - smaller main-thread items

- `_refresh_job_priorities_locked` (4.5 ms per 8 m): index feature parents
  by chunk instead of scanning all parents per job.
- `FeatureProgram.compile` (4.8 s of `_ready`, 7,242 village recipes):
  compile concurrently with the texture prefetch, or cache to disk.
- Grass: skip `_queue_grass_jobs` when nothing can be requested.

### Task 8 - textures

Rebake the Meadow rock textures at 1024-2048 with VRAM compression
(BPTC/ASTC) instead of lossless 4K RGBA8: ~1.8 GB -> ~60-120 MB VRAM and
near-instant loads. Needs an owner visual check (close-up rock A/B).
Load only meshes for `CliffSlopeRocks` (its GLB textures are unused).

### Task 9 - reduce the work itself (design-level, needs owner input)

- `CHUNK_RADIUS 3` (49 chunks, 1.3 km square) vs a fogged view distance:
  radius 2 is 25 chunks, about half the streaming work.
- Settlement-site validation (`PathPlan._compute_node`, 5 support points)
  and route validation ask for the exact hydraulic water of every block they
  touch. Blocks with no water body are already cheap (~50 ms); the 75-192 s
  ones contain rivers, and a hydrostatic fill can wet ground far from its
  channel, so there is no cheap exact shortcut. Options: decide site
  dryness from a smaller, still-exact domain, or accept the cost and cache
  it (Task 3) / make it fast (Tasks 1, 4).
