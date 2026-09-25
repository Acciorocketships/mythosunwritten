# City form, tiny settlements and connected roofs

The generator now chooses small ground settlements as well as inhabited warrens. Default tier weights are 50% hamlet, 40% village and 10% town; explicit compact, standard, large and grand profiles remain available. A hamlet contains 3–6 supported native houses around a well, campfire or tree green. It does not first build a warren and then surround it with houses.

Warren sources now include hill, ridge, courtyard and crescent forms. The occupied footprint and intentional open ground are decided before routes, plots and support. Compact profiles are smaller and outer bands can descend to one storey and at-grade streets. Complete prefabs participate in supported interior reservations and shared street frontages; native ground houses can sit inside the perimeter as well as outside it. The street circuit remains rectilinear.

## Iteration and construction

The initial form candidate failed five of 48 construction cases. A later low-edge candidate still failed two roof partitions and narrowed 17 public crossings. Those candidates were rejected. Bounded exact native roof tiling resolves the incomplete mixed crowns; final roof commitment preserves previously approved measured party seams. Optional bay supports now test the complete swept body corridor between walking cells, rather than only isolated cell centres. Native supports and collision remain unchanged where they fit.

Tiny-town iterations rejected grass cutouts, oversized civic houses and an untinted tree. The final plan uses complete measured house footprints, height eligibility, real door approaches and reserved focal clearance. Nearby real road crossings enlarge the tiny square only when needed; a distant road does not.

T roofs needed compatible source geometry, not just texture reassignment. Four offline S002 slope derivatives retain native UVs/materials and meet the original pitch. Two host cuts and complementary branch quarters close each supported valley. The baker records these finite clipping operations; no runtime arbitrary roof patch is used.

## Evidence

- `visual-judgment.md`: twenty matched complete-town comparisons, ten compact views, twelve tiny-town iteration comparisons and twelve T-roof comparisons, all inspected with differences.
- `final-comparisons/metrics.json`: 44 matched pixel comparisons. These locate changes and do not by themselves prove quality.
- `hamlet-walk/{1,3,4}/walking.json`: all 50 real-physics square/house-approach traversals pass.
- `world-records.json`: three actual canonical world sites for seed 2697992464 validate, including a six-house tree hamlet and two warren villages. Record construction alone takes 70 / 1929 / 1483 ms after field/road preparation; these are not cold-start times.
- `corpus-gate-tests.txt`: fingerprint-current corpus/timing gate passes all 95 assertions after the documented timing recalibration.
- `final-focused-tests.txt`: all 18 final city-form, native T-roof, roofability/cache and hamlet tests pass, 7,560 assertions.
- `optimization-hamlet-tests.txt`: seven cap-cache, frozen roofability and hamlet tests pass, 1,237 assertions.
- `architecture-regressions.txt`: 22 earlier photographed architecture regressions pass, 736 assertions.
- The supported T-roof signatures pass 20,532 actual triangle coverage samples. Blue/orange, both eaves and the legal 6 m / 9 m host offsets are covered; arbitrary widths are not certified.

## Performance and limits

The new standard crescent is larger than the former round town (83 buildings, 87 rooms). Its first candidate took 11,943 ms and failed the old timing gate. Profiling found repeated complete roof-closure and native cap-partition queries. A bounded 256-entry resource-free cap cache, indexed upper-band occupancy and proposal-local closure reuse reduce composition from 8,389 to 3,325 ms; final fabric costs about 2,059 ms. Three quiet in-suite whole solves are 5,397 / 5,501 / 5,284 ms. Only this changed town's timing ceiling is recalibrated using the existing median ×1.5 rule (8,100 ms). It remains more expensive than the old round town; the unchanged old timing ceiling did not pass.

Four optimized render views match the pre-optimization final geometry exactly; the fifth differs by one color level in two channel values. The cache is bounded and returns private copies; frozen-reference tests check exact partition order and roofability, including eviction.

The final fingerprinted four-scale corpus seals all 48 towns: all 11,112 sampled standing positions and 15,923 crossings are clear, with zero required sideways offsets, blocked crossings, disconnected components or unreachable public cells. All 16 non-timing summary lines match the pre-optimization final corpus. Total sweep time falls from 531.039 s for the unoptimized new forms to 250.336 s; the pre-form baseline was 330.398 s. The optimized sweep briefly shared the machine with a render, so this is a practical run comparison rather than an isolated CPU benchmark. Thirty off-centre pillar contacts remain (baseline eleven), at most three per town; they block no sampled centre or crossing. Private garden reachability diagnostics are retained and are not claimed universally clear. Flat rendering/physics fixtures isolate construction and omit streamed biome dressing. The canonical-world records verify integration but are not whole-world visual coverage. Existing cold-start and historical water/contour failures remain outside this acceptance.

Windmills, watermills, island hamlets and paired villages are concrete asset-informed proposals in `asset-compositions.md`, not claimed implemented features.
