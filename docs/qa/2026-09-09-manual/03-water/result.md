# Water containment review — reported sites accepted

The current candidate removes the suspended shelves in photo 5, the mound in
photo 7 and the folded raised surface in photo 8. Lower water remains below
the banks in photos 5 and 8. All three main before/after pairs, six nearby
pairs and their amplified differences were inspected. The 18 captures finish
with terrain ready and Godot exit 0.

Water now respects actual terrain escape heights. A flowing channel may use
its excavated volume only below both the original rendered terrain and the
local river profile. The complete source domain is solved before projecting
coarse and fine water into chunks. This preserves downhill channels without
allowing a distant high source to fill a lower river's excavation.

A blanket allowance below the original hillside was rejected after visual
review exposed a remaining mound in photo 8. A static-basin-only candidate was
also rejected because it drained a valid flowing river-to-pool junction.
Those iterations and measurements remain in the main review log.

| Photo | Before | After | Amplified difference | Mean absolute RGB difference | Pixels changing >20 in a channel |
| --- | --- | --- | --- | --- | --- |
| 5 | [Before](before/05_water_edge_exact.png) | [After](after/05_water_edge_exact.png) | [Difference](diff/05_water_edge_exact_diff.png) | 8.390 | 12.587% |
| 7 | [Before](before/07_water_mound_exact.png) | [After](after/07_water_mound_exact.png) | [Difference](diff/07_water_mound_exact_diff.png) | 10.203 | 13.306% |
| 8 | [Before](before/08_water_crease_exact.png) | [After](after/08_water_crease_exact.png) | [Difference](diff/08_water_crease_exact_diff.png) | 10.578 | 13.625% |

These are full-frame metrics at 1718×1034. The three camera JSON files are
byte-identical between the paired renders. The original overlay rounds
coordinates to 0.1 m, so the reconstructed camera cannot establish the
original full-precision transform. The original avatar pose and animation
time were not recorded. Difference images include ordinary vegetation on
newly dry ground and minor moving grass, orb and water pixels.

The local-flow candidate passes all 25 original focused tests (883 assertions). The separate 70-test collateral
run has 62 passes and eight failures whose twelve assertion messages match
the preserved baseline exactly; no new failed test is introduced. The
existing contour and skin failures remain unresolved. See
[collateral comparison](local-flow-collateral.json) and
[visual judgment](visual-review.json).

The final census samples 5,043 points and finds **zero terrain changes**. All
previous water above the original ground is removed. Photo 5 retains 468 wet
samples at 1.625–4.849 m; photo 7 has no remaining water in the sampled hill;
photo 8 retains 337 wet samples, all at the lower 1.2 m lake level. The four
reported high-water probes are dry. See [field comparison](field-comparison.json).

The original local-flow candidate missed its 300-second graphical startup
deadline. The final optimization preserves all water arrays across 30
production contexts and reduces the feature workload from 166.092 to
150.239 seconds. It reuses already enumerated spill outlets and the exact
original terrain inputs in the existing bounded sample cache.

The final ordinary-physics walk completes with exit 0: **821.971 m in 120 s,
zero frozen time**, and a grounded crossing of the reported edge at 12.258 s.
The original frame limit is restored. Startup takes 298.923 s, leaving only
1.077 s before the test deadline; cold loading remains a substantial limitation.
See [travel verification](travel-verification.json) and
[output parity](reused-input-parity.json).

All 26 final focused water tests pass (1,337 assertions, 100.296 s, clean exit).
Five additional cache/terrain tests pass with 36 assertions. The broader
local-flow collateral results above retain eight historical failures; they
are not a globally green water suite. The final source's 18-image refresh completes with ready=true and exit 0.
The three exact pairs, six nearby comparisons and their amplified differences
are visually accepted. This accepts the reported sites, with the historical
contour/skin failures and slow startup explicitly remaining open.
