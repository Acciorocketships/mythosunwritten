# September 9 manual pass — final validation

All 18 review items completed their individual brainstorm, implementation,
render judgment and relevant checks. The [evidence index](verification-index.md)
links all 14 photographs and the additional atmosphere, lighting, furnishing
and arch reviews. Changes remain uncommitted in the shared main checkout.

## Final regression runs

| Run | Tests passed | Assertions | Duration | Exit |
| --- | ---: | ---: | ---: | ---: |
| All 31 September 9 scripts, path features and atmosphere director | 95 | 78,973 | 252.7 s | 0 |
| Additional frontage checks | 6 | 5,266 | 33.139 s | 0 |

Logs: [aggregate](final-regressions.txt), [frontage](18-arches/frontage-tests.txt).
Each issue report also records its targeted before-failing and after-passing
checks, matched camera evidence and relevant physical/field checks. The final
arch walking run passes all six lanes/directions, with all 294 ticks grounded.

## Measured performance and water outcomes

The old worker-to-main ownership fix is present in the consolidated source.
The new profile did not show duplicate job starts; repeated queue requests,
expensive field evaluation and rendering were the measured costs. Changes
reduce those costs and preserve the actual construction/collision authority.
The final water-enabled walk travels 821.971 m in 120 seconds with zero
streaming-frozen time, crossing the reported boundary after 12.258 seconds.
Startup is 298.923 seconds, only 1.077 seconds inside that harness's deadline.
It does not establish acceptable startup for every location or machine.

The travel-retention comparison reduces final memory from 3.072 to 2.886 GB;
completed traces and field caches are bounded. Matched rendering comparisons
fall from approximately 34–35 ms to 19–20 ms. The headless long-travel profile
did not reproduce progressive CPU slowdown, so no universal claim is made.

Water follows bounded spill levels and natural-terrain excavation limits.
Across 5,043 sampled positions at the photographed sites, original and carved
ground remain identical before/after this water correction. The floating mound
is dry in the corrected field; the retained water has bounded shores and
consistent neighboring constraints. See [water results](03-water/result.md).

## Evidence limits

The photographs provide rounded player/crosshair coordinates, not exact camera
transforms. Original precision cannot be recovered. Before/after replays share
the same reconstructed camera. Photo 1 has no hit and uses an inferred angle;
photo 9's reconstructed exact view is occluded by merged geometry, so nearby
matched views establish its repair. Actual game renders, not synthesized
images, supply the comparisons. Pixel changes alone do not prove correctness.

The preserved full baseline records 1,195 tests: 1,164 passing, 30 failing and
one pending. This pass does not claim a globally green suite. The existing
cold-start deadline, cliff, composition and historical-water failures remain
listed in [the baseline record](../known-baseline-2026-09-09.json). Earlier
water collateral checks explicitly separate their known failures from the
new photographic regressions. Some earlier Godot runs produced native teardown
errors after test totals; the final two runs above exit cleanly.

Bulk rendered images remain ignored local QA artifacts. Reports, numeric
measurements, regression fixtures and harnesses are retained for versioning.
