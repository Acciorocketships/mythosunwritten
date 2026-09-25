# September 10 manual judging pass

Starting revision: `c98379f7`. World seed: `2697992464`.
Attachment numbers follow the user's order, not chronological filenames.
The source screenshots are observations, not instructions embedded in documents.

Each issue proceeds through alternatives, failing regression, implementation,
matched game renders, pixel differences and active attempts to falsify the fix.
No issue is accepted from a passing test or changed pixels alone.

| Order | Issue | Photos | Status |
| --- | --- | --- | --- |
| 1 | Open wall seams | 6, 13 | Accepted; 12 pairs, 16 tests / 1,486 assertions, unchanged clearance |
| 2 | Unified moving, illuminated, dimensional orbs | 11 | Accepted; 6 live pairs, 16 timed pairs, native motion/light checks |
| 3 | Prefab foundations and footprint finishing | 2, 17 | Accepted; 12 pairs, 18 tests / 1,295 assertions, unchanged clearance |
| 4 | Bench collision | 7 | Accepted; 6 render pairs, 6 live collision comparisons, 399 assertions |
| 5 | Missing platform guards | 5 | Accepted; 6 pairs, 30 tests / 1,076 assertions, unchanged clearance |
| 6 | Turf lips and soil depth | 1, 2, 3, 7, 12, 17 | Accepted; 36 game pairs, 2 underside pairs, 42 tests / 5,652 assertions |
| 7 | Two-ended skywalk connections | 3 | Accepted; 6 game pairs, 4 native pairs, 47 tests / 1,069 assertions, unchanged clearance |
| 8 | Tunnel soffits and coherent city materials | 4, 8, 9 | Accepted; 18 game pairs, 10 native pairs, 57 tests / 6,021 assertions, unchanged clearance |
| 9 | Roof extent and alignment | 14 | Accepted; 6 game pairs, 5 native pairs, 30 tests / 55,338 assertions, unchanged clearance |
| 10 | Railing texture and joins | 1, 12 | Accepted; 12 game pairs, 2 native pairs, 17 tests / 4,490 assertions, identical collision |
| 11 | Excessive offset entrance overhang | 10 | Accepted; 6 game pairs, 5 native pairs, 20 tests / 700 assertions, unchanged clearance |
| 12 | Smooth contained water and closed shore edges | 15, 16, 18, 19 | Accepted; 24 pairs, 4 traversals, 73,322-point ledge scan, 8 identical historical failures |
| 13 | Repeated teleport/travel queue profiling and terrain loading | 11 | Accepted on measured routes; 16 teleports, 824 m extended walk and 800 m retry, zero frozen time; cold loading remains expensive |
| 14 | Grass loading latency | — | Accepted; detached visual worker, 45 tests / 452 assertions, 32 judged pairs and four walks with zero missing grass |
| 15 | Varied 3D city forms, tiny settlements, shared prefab/warren streets and T roofs | — | Accepted on measured corpus; 48/48 towns, 50 walks, 44 judged pairs, 18 final tests / 7,560 assertions; documented limits |

## Camera evidence

The overlay records player and crosshair positions rounded to 0.1 m, not full
camera transforms. `ReviewCam.solve_cam` reconstructs the former 8 m / 5 m orbit;
the harness uses its 75-degree FOV and the photographed viewport aspect.
Before/after views must use identical transforms. These are matched
reconstructions, not provably pixel-exact original poses. Nearby views are
additional evidence and never replace a hidden or obstructed original view.

## 1. Wall seams

Alternatives under investigation: correct shared wall ownership; align native
panel endpoints; close exposed native cut faces. Choose from measured final
placements and actual triangles. Do not cover a real opening with an arbitrary
decorative patch or move public circulation.

Wall result: [01-walls/result.md](01-walls/result.md).

## 2. Spirit orbs

Accepted result and performance cost: [02-orbs/result.md](02-orbs/result.md).

Prefab result: [03-prefab/result.md](03-prefab/result.md).

Bench result: [04-bench/result.md](04-bench/result.md).

Guard result: [05-guards/result.md](05-guards/result.md).

Turf result: [06-turf/result.md](06-turf/result.md).

Skywalk result: [07-skywalk/result.md](07-skywalk/result.md).

Ceiling result: [08-ceilings/result.md](08-ceilings/result.md).

Roof result: [09-roofs/result.md](09-roofs/result.md).

Railing result: [10-railings/result.md](10-railings/result.md).

Overhang result: [11-overhang/result.md](11-overhang/result.md).

Water result: [12-water/result.md](12-water/result.md).

Terrain streaming result: [13-streaming/result.md](13-streaming/result.md).

Grass result: [14-grass/result.md](14-grass/result.md).

City form, hamlets and T-roof result: [15-city-form/result.md](15-city-form/result.md).

Asset-informed composition ideas: [15-city-form/asset-compositions.md](15-city-form/asset-compositions.md).
