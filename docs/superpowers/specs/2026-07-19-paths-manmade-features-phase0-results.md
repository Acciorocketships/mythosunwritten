# Paths & Manmade Features — Phase 0 Results

**Date:** 2026-07-19
**Baseline commit:** `6fc64ba`
**Machine:** MacBook Pro (MacBookPro18,1), Apple M1 Pro, 16 GB, arm64
**Godot:** `4.5.1.stable.official.f62fdbde1`

This is the pre-path baseline. The profiler's optional warm sweep is the only code change included
while taking these measurements; it does not change runtime terrain behavior. Performance gates in
the implementation plan are relative to this machine and baseline, not portable hardware claims.

## Reproduction

Full GUT suite:

```bash
/Applications/Godot.app/Contents/MacOS/Godot -d --headless \
  --log-file /tmp/paths-gut.log \
  --path /Users/ryko/story \
  -s res://addons/gut/gut_cmdln.gd \
  -gconfig=res://tests/gutconfig.json
```

Cold plus repeat-in-process warm profile (run in three fresh processes):

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless \
  --log-file /tmp/paths-profile.log \
  --path /Users/ryko/story \
  -s res://tests/harness/profile_terrain.gd -- --warm
```

The profiler's existing single cold sweep remains the default when `-- --warm` is omitted.

## Test baseline

| Measure | Result |
|---|---:|
| Scripts | 34 |
| Tests | 353 |
| Passing | 352 |
| Failing | 0 |
| Risky/pending | 1 |
| Assertions | 57,269 |
| GUT elapsed | 632.365 s |

The one pre-existing risky result is
`test_joined_rivers_touch_higher_priority_water`, which performs no assertion. GUT printed
`Exiting with code 0`; during engine teardown Godot then aborted in a `recursive_mutex` lock and the
host process returned 1. The table reports the completed GUT result while retaining that teardown
failure as a baseline issue rather than treating the command as cleanly successful.

## Terrain profile baseline

Each process builds the radius-3 startup sweep (49 chunks) cold, frees committed nodes, then repeats
the same sweep using the same `HeightfieldPlan`, `WaterPlan`, mesher, and prepared resource objects.
Times are totals for 49 chunks.

| Run | Cold worker | Cold worst | Cold commit | Warm worker | Warm worst | Warm commit | Peak memory |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 49,284.8 ms | 24,616.2 ms | 1,520.6 ms | 23,373.8 ms | 1,694.9 ms | 1,507.2 ms | 113.1 MiB |
| 2 | 49,900.5 ms | 25,068.5 ms | 1,523.8 ms | 23,459.6 ms | 1,672.2 ms | 1,526.5 ms | 113.1 MiB |
| 3 | 49,144.5 ms | 24,461.9 ms | 1,535.1 ms | 23,530.0 ms | 1,700.6 ms | 1,525.2 ms | 113.1 MiB |
| **Median** | **49,284.8 ms** | **24,616.2 ms** | **1,523.8 ms** | **23,459.6 ms** | **1,694.9 ms** | **1,525.2 ms** | **113.1 MiB** |

Median phase attribution:

| Phase | Cold | Warm |
|---|---:|---:|
| Heightfield region | 26,313.8 ms | 614.2 ms |
| Shared water context | 666.4 ms | 595.4 ms |
| Terrain mesh payload | 13,196.6 ms | 13,165.0 ms |
| Water skin payload | 1,953.6 ms | 1,974.0 ms |
| Dressing field | 7,163.0 ms | 7,143.7 ms |
| Terrain commit | 1,495.7 ms | 1,499.0 ms |
| Water commit | 0.8 ms | 0.8 ms |
| Dressing collision commit | 13.3 ms | 11.9 ms |
| Dressing visual commit | 13.9 ms | 13.8 ms |

The cold worst chunk was `(-3, -3)` in all runs. The warm worst chunk was `(-2, -3)` in all runs.
Static memory settled at 90.9 MiB after both sweeps; process peak was 112.9 MiB after cold and
113.1 MiB after warm.

## Five source assets

All paths are relative to the repository root and intentionally retain the pack's spaces:

1. `assets/FantasyVillageFBX/FBX/Exterior Props/Light Pole/SFV_Light_Pole_001.fbx`
2. `assets/FantasyVillageFBX/FBX/Exterior Props/Arch/SFV_Arch_001.fbx`
3. `assets/FantasyVillageFBX/FBX/Exterior Props/Arch/SFV_Arch_002.fbx`
4. `assets/FantasyVillageFBX/FBX/Exterior Props/Arch/SFV_Entrance_Arch_001.fbx`
5. `assets/FantasyVillageFBX/FBX/Exterior Props/Bridge/SFV_Bridge_001.fbx`

## Frozen Phase 0 decisions

The bake-owned probe measured the raw assets before any runtime resource was
created. The raw bridge AABB is `4.686 × 2.266 × 10.507 m`; the two large arches
are `10.553 × 8.154 × 3.828 m`, the entrance arch is
`3.871 × 4.195 × 0.251 m`, and the pole is `0.346 × 2.970 × 1.355 m`.

The checked-in four-site crossing corpus found 23 dry-to-dry crossings (14
perpendicular, 9 oblique). Wet spans were p50 `23.93 m`, p90 `46.31 m`, p95
`46.33 m`, and max `46.84 m`. Planning/exact classification differed at
388/4,160 samples (`9.327%`); those are deliberately final-validation drops,
not a reason to duplicate hydrostatic water in the planning field.

| Value | Frozen decision |
|---|---|
| Path width | Centred `4 m`: exactly two columns on the real `2 m` quad-centre grid. The offset `6 m` alternative is rejected. |
| Freestanding feature scale | `2×` human scale (`[2.0, 2.0, 2.0]`) after in-game review found the arches and lamp too small. |
| Bridge vector scale | `[1.2, 1.0, 6.0]`; it retains its independently calibrated `5.6 m` width, human-scale deck/rail height, and `57.6 m` usable length. |
| Usable deck span | `57.6 m`, with `8.0 m` total dry landing allowance. |
| Crossing coverage target | `23/23` (`100%`) of this calibration corpus. The shorter 38.4 m and 48.0 m candidates each covered `15/23` (`65.2%`). |
| Planning/exact mismatch | `9.327%`, accepted only as one-shot exact route rejection. |
| Optional-loop probability | `0.18`; the synthetic 32-node/36-edge probe selected 30 edges, including 2 loops, with zero selection-induced isolates. |
| Bounded cache caps | fields `192`, nodes `64`, raw/resolved bridges `128` each, routes `64`, contexts `96`, planning graph points `8192`. |
| Warm performance gate | Worker overhead ≤ `15%` and main-thread commit overhead ≤ `20%` relative to the Phase 0 medians. The first path-enabled warm run was `26,374.6 ms` worker (`+12.4%`) and `1,750.9 ms` commit (`+14.8%`). |
| Player-critical halo gate | A cold radius-1 streamer integration, including terrain plus feature readiness, must finish within `60 s` on the baseline machine; observed `36.218 s`. An already-materialized nine-key readiness scan must remain under `50 µs`; the probe measured `2 µs`. |

The path-enabled 49-chunk cold run was `76,755.9 ms`, dominated by a one-time
`49,445.3 ms` canonical planning/context fill. The warm context lookup total was
`0.3 ms` for all 49 chunks. Peak process memory was `172.6 MiB`; the active
window held 147/192 field blocks, 20/64 nodes, 39/128 bridge profiles, 15/64
routes, and 49/96 contexts without eviction. These figures justify fixed caps
instead of unbounded memoization.

## Final implementation verification (2026-07-21)

This is the final pass after removing settlement terrain stamps, making large gates follow their
real village approaches, adding exact biome gates, inward-facing lamps, bounded path joins, the
compound large-arch collision, and varied circular path spots.

| Check | Final result |
|---|---:|
| GUT | 44 scripts; 413 tests; 412 passing; 0 failing; the same 1 no-assert risky test; 60,081 assertions |
| Full path corpus | 57 nodes; 201 route cells; 16 features; 0/34 exact failures across all 4 pinned seeds |
| Streaming crash harness | PASS after 15.0 s of movement with 11 live chunks |

One final cold-plus-warm profile after removing settlement terrain stamping and changing the mesher
to reuse its already-known terrain cell in the single path classifier produced:

| Phase | Cold | Warm |
|---|---:|---:|
| Worker total | 61,024.4 ms | 26,740.0 ms |
| Worst chunk | 32,246.6 ms | 1,738.5 ms |
| Path context | 33,252.7 ms | 0.3 ms |
| Terrain mesh payload | 15,910.3 ms | 16,003.7 ms |
| Main-thread commit | 1,776.8 ms | 1,769.4 ms |
| Process peak | 165.9 MiB | 167.7 MiB |

The final warm worker is `+14.0%` against the Phase 0 median (`≤15%` gate), and commit is `+16.0%`
against its median (`≤20%` gate). The final cold worker is `20.5%` faster than the first
path-enabled cold run, while peak memory is `2.8%` lower. The immutable path output and fixed cache
contents remain unchanged; the optimization removes the settlement-height dependency and repeated
division/rounding in lattice callers.
