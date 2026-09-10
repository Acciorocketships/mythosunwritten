# September 9 manual review

Starting revision: `f3203d96` (consolidated `main`). Seed: `2697992464`.
The source photographs were taken before consolidation on the September 5
village branch. Historical reproduction and current-world regression evidence
must identify their revision; a changed landscape is not evidence of a repair.

Work proceeds individually in the following order. No item is accepted until
its targeted regression, game output and relevant collateral checks pass.

| Order | Issue | Source photos | State |
| --- | --- | --- | --- |
| 1 | Terrain streaming cannot keep up | 1 | Reported route accepted; broader limits below |
| 2 | Performance degrades during travel | — | Measured retention/rendering fixes accepted; limits below |
| 3 | Unbounded/floating/creased water | 5, 7, 8 | Reported sites accepted; historical water/startup limits below |
| 4 | Missing town grass lips | 2 | Accepted: native back-panel ownership |
| 5 | Repeated doors on one building face | 3 | Accepted: one entrance per connected facade |
| 6 | Stair rail/post connection | 6 | Accepted: measured native post attachment |
| 7 | Unsupported offset building | 12 | Accepted: native timber bay supports |
| 8 | Country path ends abruptly | 4 | Accepted: actual world-road exits only |
| 9 | Thin exposed town turf | 9 | Accepted: enclosed soil bed and timber border |
| 10 | Tiny roof interrupts town composition | 14 | Accepted: exact public ceiling owns upper interface |
| 11 | Open building seams / roof end | 10, 13 | Accepted: complete gable and closed doorway return |
| 12 | Restrict broadleaf fern to suitable biomes | 11 | Accepted: broadleaf family limited to Jade Estuary |
| 13 | Larger slowly drifting spirit orbs | — | Accepted: visible larger sprites and slow shared motion |
| 14 | Remove camera blur | — | Accepted: near/far depth of field removed |
| 15 | Biome atmosphere and broader warm lights | — | Accepted: seven lighting profiles, grounded mist and native warm lamps |
| 16 | City lanterns | — | Accepted: native wall brackets and supported garden posts |
| 17 | Search existing assets and dress cities | — | Accepted: supported native seating and storage |
| 18 | Integrate arches at warren tunnel mouths | — | Accepted: supported native frames at covered passage mouths |

## Camera evidence limits

Photographs contain rounded player/crosshair coordinates, not full camera
transforms. Use `ReviewCam.solve_cam` for the reconstruction and preserve the
identical resulting transform in before/after renders. These are matched
reconstructions, not provably pixel-exact original cameras. Photo 1 explicitly
has no terrain hit, so its azimuth cannot be recovered by that method; record
any inferred view separately. Exclude editor chrome and red annotations from
render comparisons. Pixel differences locate changes; visual inspection and
physical/field checks decide whether the defect is fixed.

## 1. Streaming

The merged source contains the earlier completion-handoff ownership fix,
unchanged-request suppression, proximity/velocity priority rebasing and feature
dependency splitting. Earlier accepted runs covered two other coordinates;
the full baseline still records a failed cold-start deadline.

First measurement: production streaming, headless diagnostic traversal from
`(287.4, -1238)` southward at 10 m/s for 120 seconds after startup. This
obstacle-bypassing diagnostic measures throughput; it is not a walking or GPU
performance acceptance test. The existing harness resets velocity during this
mode, so it also does not exercise production velocity lookahead. Results:
`01-streaming/before.json` and its time series.

Candidate approaches to evaluate against the profile:

1. Correct remaining queue ownership/order defects if repeat starts or delayed
   dependencies are observed.
2. Remove repeated sampling/computation in the measured expensive generation
   stage while requiring identical geometry/collision results.
3. Bound main-thread commits and avoid unnecessary full-queue work if frame
   timings implicate those stages.

Increasing the keep radius alone cannot fix insufficient generation throughput.
Changing terrain or omitting towns to make a benchmark pass is not acceptable.

### Baseline findings

The 120-second obstacle-bypassing traversal records 99.31 seconds with missing
ground readiness. It moved 1,194.54 m; because this mode bypasses the freeze,
that distance is not a successful walking traversal. Startup took about 212 s.
There were 3,413,066 chunk request calls, 2,809,304 unchanged queued requests,
and no recorded duplicate job starts. Worker feature contexts totalled 278.87 s;
four terrain meshes took 23.63 s. Main-thread terrain commits peaked at 1.18 s.

The isolated first feature context took 190.67 s. Its 31 water contexts spent
141.47 s in hydraulic fills and less than 1 ms total in contour construction.
One 471-by-471 source solve spent 8.92 s constructing its terrain region,
17.13 s preparing seeds, and 0.31 s relaxing the flood. This implicates broad
terrain/source preparation, not just queue order or shoreline texturing.

### Iterations (not whole-issue acceptance)

* Request scheduling: the new stationary-frame regression failed with 29,951
  requests versus 491 expected. Scheduling only on a changed desired footprint
  passes; all 15 request, ownership and proximity regressions pass (68 assertions).
* Rejected experiment: shared 32-cell terrain pages retained all 31 local water
  and contour hashes, but increased the isolated context time from 190.67 s to
  217.02 s. The paged runtime was removed. Numeric evidence remains in
  `01-streaming/water-cost-candidate.json`; local experimental source is archived
  under `.artifacts/september9-rejected-paging/`. It is not an accepted fix.
* Regional water indexing: the frozen straight-river regression exposed
  thousands of bucket cells outside each index's owner. Clipping index storage
  to its half-open owner passes 12,904 assertions, including independent
  enumeration of every original sample in four positive/negative-boundary
  regions. Full river records and local sample order remain unchanged.
  The production comparison preserves all 31 fill and contour hashes. Static
  memory falls from 5.05 GB to 1.42 GB; first-context time changes from
  190.67 s to 185.76 s. This substantially reduces storage but does not solve
  the cold preparation time. See `01-streaming/water-cost-buckets.json`.
* Flat graded collision: the regression failed with 384 submitted vertices
  instead of six on a constant 2 m square. The candidate preserves the exact
  boundary and height using two triangles only when **every** fine-grid
  height is identical. Slopes retain every original triangle, and visual
  vertices are unchanged. The focused 18-test suite passes 12,994 assertions;
  integration and walking acceptance remain pending.

### Integration evidence so far

The first candidate still fails throughput acceptance. The 120-second bypass
run records 103.32 s without ready ground (baseline 99.31 s). Request calls fall
from 3,413,066 to 3,371; maximum terrain commit falls from 1.181 s to 0.407 s.
These are useful improvements, but not proof of a fixed streaming boundary.
See `01-streaming/candidate-comparison.json`.

The graphical baseline uses unchanged `f3203d96` scripts in an isolated local
project with the same new `september9_stream_walk.tscn` harness. It drives the
ordinary character south from `(287.4,-1238)` with production streaming and
honors the player freeze. In 60 seconds it travels about 106 m, reaches
`(287.4,4.920656,-1344.226)`, and freezes for 47.843 s. It does not cross 12 m
beyond the boundary. This reproduces photo 1's failure at its reported position.
The two PNGs use the explicitly **inferred** camera recorded in
`walk-before.json.crossing.json`; photo 1 has no crosshair terrain hit.

The next candidate replaces dictionary sweeps in the rectangular terrain
compiler with contiguous integer arrays and separable cardinal distance
transforms. The original dictionary compiler remains a test oracle. Seven
focused tests pass 2,734 assertions, including exact complete maps (outer margins
too), three clamp steps/rounding modes, negative coordinates and carve flags.
Alternating warm benchmarks take roughly 0.17 s versus 0.35 s for the
original compiler, with identical hashes. The production first-feature run
improves from 185.76 s to 178.71 s, again preserving all 31 water/contour hashes.
See `region-cost.json` and `water-cost-dense.json`.

A further seeding regression fails with 161 detailed evaluations of a pond
that cannot reach any tested bank point. The candidate checks the existing
conservative pond bound before its detailed shape. It retains complete source
inventories and exact nearby-pond ownership. Three focused tests pass (26
assertions); the first-feature profile improves to 138.96 s, with all 31
water/contour hashes unchanged. The rendered candidate walking run is pending.

The rendered candidate crosses the boundary after 45.51 s, including 33.146 s
frozen. Its 15-second image still shows the missing half-plane. Visual review of
both captures and the 5x pixel difference rejects whole-issue acceptance:
2,186 / 921,600 pixels change by more than eight intensity units, mainly around
the character. Mean absolute RGB difference is 0.399. See
`walk-candidate-15s-diff.json` and `walk-candidate-15s-diff-x5.png`.

The next constant-profile regression initially records 5,400 unnecessary terrain
reads on a level reach and one full terrain-region build for a flat trace. The
candidate skips shaping only when the packed hydraulic targets are constant;
a real terminal pond drop still requests canonical terrain. Four tests pass ten
assertions, although Godot then hits the known native mutex shutdown failure
(exit 134). All 31 production water hashes remain unchanged; the first-feature
profile improves to 130.43 s.

A bounded, mutex-protected cache of exact 64-bit noise corners reduces the
isolated terrain sampling benchmark from about 1.24 s to 0.79–0.83 s with the
same output hash. Sixteen noise/helper/biome tests pass 846 assertions and exit
0, including full-width seeds, negative boundaries, eviction and concurrent
queries. Its rendered travel comparison still fails: 38.648 s frozen and a
crossing at 51.212 s, versus 33.146 s and 45.51 s for the preceding candidate.
Cold feature preparation falls to 130.446 s, but that microbenchmark improvement
does not establish an end-to-end improvement. See `walk-cache-candidate.json`.

The next iteration exposes requested character movement to streaming before
acceleration and while frozen, without moving the character. A bounded 30-second
forward segment prioritizes each intervening crossing; feature owners inherit
their waiting terrain's entry distance. The former endpoint-only priority could
skip an intervening chunk. Direction, intervening-ground and existing queue
regressions pass; rendered acceptance is in progress.

A separate red regression shows the height sample cache discarding all 200,000
entries when one new cell arrives at capacity. One-entry FIFO eviction preserves
recently warmed samples within the same bound, with ordinary source-change
invalidation. Six focused tests pass 37 assertions, including exact complete
terrain maps and movement intent. The reported route has not yet established
how much of its delay came from this cache policy. The combined rendered
forward-priority candidate reduces frozen time to 23.724 s, crossing at 35.852 s.
Its 15-second image still has no ground beyond the boundary, so it is rejected
as a complete fix. The remaining lead feature `(0,-9)` takes 30.284 s; the
character reaches the boundary in roughly 11 s.

The source-solve cache previously keyed initiating source lists even though each
solve rediscovers the complete inventory in its final domain. Different initial
lists can produce the same domain. The new key uses the terrain and water owners,
aligned base and lattice size. A red regression records two identical solves;
the candidate reuses one and keeps a different water owner's inventory separate
(six assertions, clean exit). All 31 production fill/contour hashes match the
starting revision. Combined first-feature cost is 99.501 s, versus 190.668 s
initially; this does not isolate the contribution of the cache key alone. See
`water-cost-domain-cache.json`. The 120-second rendered run crosses at 31.043 s
and freezes for 18.893 s, all at the first boundary. It then reaches
`(286.9533,0.124742,-1948.707)` with no further freezes. This remains a failed
initial crossing, despite improved subsequent throughput.

The initial loading boundary previously supplied only the camera's nearby
terrain (one chunk at this pin). The next candidate prepares the surrounding
ring before releasing movement, supplying at least one full chunk of travel
in every direction. This deliberately moves preparation into initial loading;
its added startup time must be reported separately. The new regression fails
eight of 54 direction/distance checks before the change. Five focused startup
tests now pass 69 assertions, including integrated readiness and latched
completion after eviction. The rendered 120.061-second route now travels
820.534 m with **zero frozen time**, crossing 12 m beyond the photographed
boundary at 12.385 s while grounded. Initial loading takes 207.592 s for nine
ready chunks, versus 137.393 s for the preceding one-chunk candidate and
248.369 s for the original rendered baseline. It adds 70.199 s to the optimized
one-chunk startup while remaining 40.777 s faster than the original baseline.

Visual judgment: both the event-matched crossing and 15-second captures replace
the missing half-plane with continuous terrain and vegetation. The identical
inferred camera is retained. At the crossing, 756,456/921,600 pixels exceed eight
intensity units; mean absolute RGB difference is 41.439. The strongest difference
is the previously absent ground, with additional grass/dressing becoming ready
inside the old visible chunk. At 15 s the runner has already left the pinned
camera. These are genuine runtime readiness changes, not matched fully-settled
terrain geometry comparisons. See `walk-buffer-pixel-diff.json` and the paired
PNGs. Exact water/contour hashes provide the independent field parity check.

Queue sort scratch fields initially leaked `inf` into three final JSON reports.
They are now removed after sorting; a regression failed before the cleanup.
Only these temporary fields were removed from those report objects to restore
valid JSON; original reports are archived in `.artifacts/september9-raw-metrics`.
Measured values and original time-series strings are unchanged. The 24-script
streaming/heightfield/water suite passes all 105 tests and 18,372 assertions in
237.778 s. Godot subsequently exits 134 during native teardown, matching the
documented baseline shutdown failure category; this is not a clean process exit.

The reported walking route, image comparison and related assertions pass. This
accepts the reported issue at these coordinates, not every possible long-distance
route or the full baseline suite. Work moves to issue 2; issues 3–18 remain pending.

## 2. Performance degrades during travel

Separate changing scene complexity, active generation and retained state. Compare
the same pinned view across time; measure memory, nodes, terrain/grass counts and
bounded cache occupancy. Then stop generation for a fixed-scene rendering probe
and disable grass, atmosphere, nature, water, shadows and resolution separately.
Repeated full-scene controls bracket the variants. Larger caches or less visible
content are not automatically accepted fixes; preserve exact field output and
judge any changed image.

The issue-2 baseline is preserved at `/private/tmp/september9-lag-baseline`, with
source hashes in `02-lag/baseline-source-sha256.json`. Its stationary probe uses
the photo-1 location and identical fixed camera. After the scene fills and
generation stops, full-scene controls average 36.58, 36.30 and 36.99 ms/frame.
Removing grass averages 16.96 ms; removing directional shadows 18.73 ms; half
resolution 22.32 ms. Atmosphere removal reaches 33.80 ms, nature 37.31 ms and
water 35.81 ms. The final scene contains 52 grass batches with 9,425 submitted
visible instances. This is a rendering-cost result, not yet a long-travel leak
measurement. See `02-lag/stationary-before.json`.

That run retains 71 complete trace terrain regions for 73 compact hydraulic
profiles. A weak-reference regression fails because a finished profile keeps
its construction region alive. A 1,100-trace test also fails the new bound and
eviction checks. The candidate releases construction regions after profile
completion, retains at most one scratch region during construction, and keeps
1,024 compact profiles with individual LRU eviction. Both focused tests pass
seven assertions with a clean exit; the preceding nine-test river/profile suite
passes 27,603 assertions. Production parity and sustained-travel comparison
remain pending. A reusable snapshot of actual generated geometry is being
captured for graphics comparisons.

WaterPlan's source/trace/region memos also grew without bounds. Two further
tests fail five of ten assertions before the change; the candidate caps regions
at 256 and each source/trace memo at 8,192, evicting one oldest entry at a time.
All four retention tests now pass 17 assertions with a clean exit. The production
31-context fixture preserves every fill and contour hash. Retained static memory
at its last sample falls from 1,423,989,230 to 1,322,390,790 bytes; this short fixture
does not establish the sustained-travel outcome.

The corrected render snapshot restores live global shader parameters from their
owning adapters. Its replay matches the captured scene apart from moving shader
detail and the script-drawn crosshair. Original/return full controls measure
37.35/34.93 ms. Removing both grass and shadows reaches 5.58 ms; ordinary filtered
sun shadows reach 20.37 ms, while very-low soft shadows reach 26.79 ms. The former
has distinctly sharper tree shadows; the latter shows visible sampling noise.
Neither appearance change is accepted yet. A separate grass-shader candidate
skips deformation for dropped patches and for stationary, untrampled far blades;
its first comparison was invalid: the shader override visited tile roots instead
of their nested MultiMesh batches, so it changed no materials. Those timings and
pixel differences cannot establish the candidate's effect. The harness now
requires actual descendant batches, verifies assignment and records shader hashes.
The production shader is restored while the corrected comparison is pending.
The earlier `grass-branch-candidate.json` and pixel report remain marked invalid.

The corrected comparison (`grass-branch-verified.json`) reaches all 52 batches
and records distinct original/candidate shader hashes. Original soft-shadow
controls average 35.15/34.77 ms; candidate controls 34.32/34.55 ms. With ordinary
filtered shadows, original controls average 20.37/20.36 ms and the candidate
19.89 ms. The fixed-time candidate image has mean absolute RGB difference 0.184
and 155 pixels above eight levels, versus 0.241 and 215 pixels between unchanged
controls. The amplified difference is predominantly dark, with tiny orb/upper
scene changes also present in the control. This is a small rendering saving;
shadow filtering remains the larger cost. Native resource warnings occur during
render-fixture teardown despite exit 0 and are recorded separately from results.

The shadow-width comparison (`shadow-filter-candidate.json`) brackets 35.00/34.98
ms original controls with 20.30 ms for PCF width 2 and 20.35 ms for width 4. Width 2
retains a softened contact edge without the very-low-PCSS sampling noise. The
candidate applies width 2 with angular distance zero in AtmosphereDirector and
includes the small, image-preserving grass branch optimization. Combined
production-setting and nearby-view comparisons remain pending.

The sustained residency test uses a declared obstacle-bypassing trajectory:
1,200 m south, 1,200 m back, then 120 seconds at the starting coordinates. It
retains ordinary streaming/readiness and records caches after worker jobs.
It is not evidence of walkability or zero frozen time, which are tested separately.

Both 360-second residency runs finish with empty queues, 56 built terrain chunks,
11,541 nodes, 192 field entries, 190 water builds and 79 hydraulic profiles.
The candidate retains zero construction regions instead of 77; regional indexes
stop at 256 instead of growing to 271. Final static memory falls from
3,071,808,866 to 2,885,599,258 bytes (186.2 MB); peak memory falls from
3,264,838,338 to 3,052,399,642 bytes (212.4 MB). Both processes exit cleanly.
Headless frame means and p99s remain essentially unchanged under the 60 fps cap;
this does not prove that cache retention caused the reported frame-rate decline.
It proves a retained-memory improvement on matched resident content. The distinct
rendering ablations establish the large scene-complexity cost and measured remedy.
See `02-lag/travel-comparison.json` and the underlying per-second records.

Final visual acceptance uses the actual generated scene with the production
AtmosphereDirector settings and grass shader, holding geometry, instance buffers,
camera and grass shader time fixed in each pair. The pinned view improves from
34.936 to 19.937 ms; left nearby from 34.744 to 18.879 ms; right nearby from
33.656 to 19.350 ms. All retain 52 grass batches. Paired cameras match exactly.
Pixel differences average 7.942/8.450/7.453 RGB levels respectively. The amplified
pinned difference follows the tree/bush shadows and their grass receivers;
nearby views retain complete coverage, geometry and softened contact edges.
These are inferred-camera performance views, not reconstructed photo angles.
The six-script collateral suite passes all 40 tests and 435 assertions in
13.81 seconds with a clean exit. The rendered fixture retains its separately
documented teardown warnings. See `02-lag/production-comparison.json`,
`02-lag/production-pixel-diff.json` and their paired PNGs.

The measured retained-memory and rendering-cost defects are accepted. The
headless experiment did not reproduce progressive CPU slowdown, and these
results do not promise a universal frame-rate floor or eliminate every long-run
failure. Work moves to water; issues 4–18 remain pending.

## 3. Floating, unbounded and creased water

Preserved starting source: `/private/tmp/september9-water-baseline`, with 588
source hashes in `03-water/baseline-source-sha256.json`. It includes accepted
issues 1–2 so the water comparisons isolate subsequent changes. Photos 5, 7 and 8
are being reconstructed with grass enabled, identical rounded camera pins and
nearby views. Historical pre-generation-revision fixtures remain separate.

Candidate directions, to choose after reproduction and numeric diagnosis:

1. Repair a mismatch between the current terrain carve, hydraulic level and
   shoreline/mesh sampling if the basin is already properly bounded.
2. Derive a basin's admissible level from its actual enclosing terrain and spill
   outlet, preserving a level lake and a downhill river profile. A high source
   with an open lower outlet cannot justify a suspended sheet over that outlet.
3. Couple the downward-only carve and hydraulic planning more directly, as the
   owner suggests: reserve a depressed bed and banks before publishing water.
   Simply clamping water below every uncarved sample would erase natural
   inundation and make a lake follow terrain undulations; a basin-level spill
   constraint and separate monotone river profile avoid that failure.

Current code already has downward-only pond/channel carving, a pre-carve minimum
for pond datums, terminal datum caps, complete-source hydraulic solves and dry-bank
constraints. Determine which ownership/representation fails in these photos
before replacing that architecture. Pixel appearance alone is not evidence of
hydraulic containment; test escape routes, mesh seams, dry standing ground and
connected wet sampling independently.

The three before views reproduce all reported water defects on the preserved
merged source. The capture run completed with ready=true and exit 0. Photo 7's
rounded reconstruction includes a foreground tree absent from the original
silhouette; its defect remains clearly visible and nearby views are retained.
A production field census now samples final graded ground, uncarved natural
ground, wet water level and raw level independently around each photograph.

The census finds water up to 9.24 m above unchanged natural plateaus. A high
seed can flood downhill without an enclosing rim; the old solver has no spill
outlet limit. First candidate: a minimax terrain-saddle solve over the complete
source domain caps hydrostatic water at its escape height, retaining river
profile constraints. Open-flat, enclosed-bowl and lower-outlet tests distinguish
valid retained water from an unsupported source head. The original code fails
three of four tests (including all three production samples).

The first coarse-only candidate passes three tests but still fails photo 5.
Its census removes the high sheets in photos 7/8 (photo 8 retains its 1.2 m
lower water), yet photo 5 remains unchanged. Point tracing proves the coarse
source leaves that plateau dry while the 3 m topology-rescue flood reinstates
12.171 m water over 8 m ground. The next candidate applies the same spill rule
to new fine pockets, with existing coarse water as boundary heads. It also
caps smoothing at the retained level so averaging cannot raise a lake above
its outlet. All four initial tests then pass (8 assertions, 42.758 s, exit 0).
These are candidate results, not visual acceptance. The finite source-domain
and fine-window seam behavior still require collateral review.

The first fine-spill renders remove the three photographed defects and keep
lower water; paired camera JSON files are identical. Exact-view mean absolute
RGB differences are 10.929, 9.804 and 10.440 (photos 5/7/8), with 23.89%, 13.25%
and 13.74% of pixels changing by >20 in a channel. Viewed amplified differences
follow the old water shelves and vegetation reclaimed by dry ground; minor
background differences include moving grass/orbs. Six nearby views were also
inspected. These images remain a rejected/intermediate candidate, because the
collateral test subsequently exposed excessive drainage elsewhere.

The old flat topology-pocket fixture expected unbounded 4.7 m water. Its exact
open-flat layout is retained as a new negative regression, and the positive
pocket test now supplies an 8 m enclosing rim while preserving its original
level and frozen-sampler assertions. That valid basin exposed use of tapered
shoreline heights as outlet heads; hydraulic (untapered) heads correct it.
A historical swimming passage still failed. Independent ground connectivity
found no sampled exit below its 3 m level: the spill candidate incorrectly used
an unfilled neighbor as a drain. The corrected search traverses the complete
terrain domain, including dry cells, and seeds only actual flowing river levels
and the outer source-domain boundary. This restores all six swimming-volume
tests without changing the historical fixture or its assertions. The expanded
photo-border harness initially omitted its 12 m declared query margin; its
coverage errors are a harness defect, not water seams, and were corrected.

### Water performance rejection

The shared square fine solve passes the containment and historical-swimming checks, but it is not accepted: the actual south-walk run exceeds its 300-second startup deadline with zero travel. Its first feature context takes 370.649 seconds. `03-water/walk-shared-fine.json` records that failure. Priority-flood and baked-ground optimizations preserve exact one-source output hashes but do not resolve that startup regression. Rectangular complete-source domains are now under numerical and performance review; earlier `spill-candidate` images remain rejected-candidate evidence.

The full rectangular workload contains 27 contexts. Interpolation memoization
and sparse anchor preparation reduce its feature time from 274.519 s to
235.840 s; a reverse minimax search reduces it to 178.084 s. All 27 coarse,
fine, fill and contour hashes match between these candidates. The reverse
search starts at an actual rescue pocket and stops at a physical outlet or a
proven escape height. It memoizes only nodes proven to share that escape;
it does not treat an unfilled neighbor or a cropped chunk edge as an outlet.
The forward heap reference remains frozen in a test fixture. Forty mixed
flat/sloped domains compare the full, pruned and reverse searches (120 exact
array assertions). Lazy fine-ground preparation is under test next.

Baked cell controls reused only within the current solve, plus the same reverse
spill search at both resolutions, reduce the feature context to 151.764 s.
All 27 fill, coarse and fine hashes match the preceding lazy-sampling candidate.
The feature benchmark does not request shoreline contours: its contour hashes
are empty and do not replace dedicated contour tests or actual renders.
The 120-second ordinary-physics south walk is the next acceptance gate.

The 151.764 s offline candidate still fails the graphical 300-second startup
deadline (`walk-final.json`): its first feature context takes 176.471 s while
the window renders, and a required later feature context adds 65.318 s. Zero
travel occurred; this is not an accepted streaming result.

The next candidate consults the same physical escape field during fine
expansion. Water cannot cross a point that must remain dry and leave a
separately filled pocket beyond it. Twenty-one checks pass with 856 assertions
in 100.013 s, including historical swimming and complete-source cache ownership.
The cache test now supplies a real enclosing terrain rim instead of relying on
an unsupported eight-metre head on an open flat.

The production streamer also limits redraws to 30 FPS only during graphical
startup, preserving any existing lower limit. It restores the previous limit
on completion or cancellation; a later explicit setting takes precedence.
Headless execution and gameplay keep their existing limits. The live walking
harness records the restored limit in its crossing report.

The revised graphical walk completes: startup 288.712 s; 821.182 m in the
120-second ordinary-physics traversal; zero frozen time. The reported edge
is crossed grounded at 12.249 s. The previous unlimited frame setting (`0`)
is restored for gameplay. Startup remains slower than the earlier 207.592 s
streaming-only accepted run; this is a documented cost of the containment
work, not a globally resolved cold-start claim. Actual final water images and
broader water collateral still gate issue 3 acceptance.

The broad 70-test water collateral run finds 12 failures: eight known baseline
failures and four new failures at the historical terminal junction near
(42,-1080). The new failures are a sharp river-to-pool join, 12 falsely dry
samples, an unbounded shore contact and its exposed outer mesh row. This
rejects the otherwise improved `03-water/contained-expansion` candidate. Its three camera
files match the before files exactly; those images remain intermediate evidence.

`junction-candidate.json` and `junction-before.json` independently compare
chunk ground, complete-source ground, original uncarved ground and water.
Both terrain domains agree: the channel floor is 4 m inside an originally
24 m hillside. The static spill rule drains its sides toward the 3 m terminal
pool despite a 10–13 m flowing centre. The next candidate permits previously
connected water to occupy excavated ground below the original rendered surface,
while retaining physical spill limits on untouched terrain. Original ground is
compiled with the same seed, raw input, quantization and clamping, with water
subtraction disabled. This is a containment ceiling, not a new water seed.

The first excavation candidate restores all dry-hole checks but retains a
1.290 m step at the join: capping smoothing at the initial flood's stepwise
level prevents its normal continuous transition. That run passes 24/25 water
field tests (847/849 assertions, 210.979 s). Smoothing now uses the physical
spill/excavation ceiling instead; the unchanged terminal-join regression passes
its three assertions in 1.322 s. Broad collateral and photo containment checks
are running before any acceptance or new final renders.

The excavation-ceiling candidate completes 94 water tests: 86 pass and eight
retain their baseline failures (26,281/26,293 assertions, 403.378 s, exit 1).
The complete failure messages, including measured coordinates and distances,
match the preserved September 8 final-candidate water log byte for byte after
ANSI removal. All four newly introduced junction failures are resolved without
changing those historical fixtures or their assertions. The 16 containment
tests, six swimming tests, divot and source-domain cache checks pass. See
`03-water/excavation-collateral.json` and its complete text log. Matched current
production renders, a new field census and the ordinary-physics travel rerun
remain outstanding acceptance gates.

Visual review rejects the blanket excavation allowance despite its passing
point tests. Photo 5 loses its suspended shelf and photo 7 loses its mound,
but photo 8 still has a raised folded surface. The full census has zero water
samples above original ground, demonstrating that this condition alone is
insufficient: at (180,-1830), water is 15.836 m above a 4 m carved floor, within
a 16 m original hillside. That cut belongs to the nearby river whose hydraulic
level is only 1.2 m. Images/differences are archived as `excavation-blanket`
and `excavation-blanket-diff`; `field-excavation-blanket.json` records the census.

The next candidate additionally constrains an excavation allowance by the
nearest local river's projected continuous profile, including its dense
descents. It does not turn a bank into a seed. The historical terminal-join
check still passes (3 assertions, 1.432 s). The formerly missed photo 8 sample
is added to the production regression, alongside a synthetic high-source /
low-river example. Natural terrain reuses the ordinary baked cell sampler
within each solve, as the existing lattice parity tests require.

The local-river-ceiling capture completes all 18 images with ready=true and
exit 0 (`after`). The three exact before/after camera files are byte-identical.
Visual inspection of all three exact pairs, all six nearby paired comparisons
and all three amplified exact differences finds the reported suspended shelf,
water mound and folded edge removed. Photo 8 now retains its lower lake behind
a dry grassy bank; photo 5 retains lower water below the exposed ledges.
Dry foreground and the character retain their geometry. Newly dry land gains
its ordinary vegetation; moving grass/orbs and water add minor temporal pixels.
Mean absolute RGB differences for photos 5/7/8 are 7.955/10.238/11.036, with
12.526%/13.347%/13.802% of full-frame pixels changing by >20 in any channel.
`visual-review.json` records the limits and checks. Broader collateral, final
field census and live travel still gate issue 3 acceptance.

The current local-river candidate passes all 25 focused checks (883 assertions,
103.707 s, exit 0). The separate 70-test collateral run passes 62, with the same
eight baseline failures and exactly the same twelve failed assertion messages
as the preserved baseline (25,404/25,416 assertions, 302.217 s, exit 1).
`03-water/local-flow-collateral.json` records the comparison and source hash.
There are no newly failing tests across these 95 checks; this does not make
the historical contour/skin suite green.

The final local-flow census completes in 237.741 s. All 5,043 final-terrain
and uncarved-terrain samples are identical to the before census. Photo 5's
water decreases from 622 to 468 samples (maximum level 12.171 → 4.849 m);
photo 7's 777 mound samples become dry; photo 8 retains 337 samples, all at
1.2 m, versus 666 reaching 21.244 m before. All four pinned high-water sites
are dry. `03-water/field-comparison.json` records exact values.

The final local-flow graphical walk **fails** its 300-second startup deadline
with zero travel (`03-water/walk-local-flow.json`). Nine terrain results are
prepared, but only one has committed while the required (1,-9) feature
dependency is still computing. The local-flow candidate remains unaccepted.
Added phase instrumentation separates natural terrain, projected local river
heads and physical spill capping before optimizing this additional cost.

The instrumented local-flow feature context takes 166.092 s. Fine preparation
repeatedly scans the complete source grid to initialize outlets, even though
the anchor-building pass already enumerates exactly those points. The next
candidate reuses that list plus the explicit outer boundary; unchanged callers
retain the dense scan. It also reads the four coarse corners directly instead
of allocating a four-vector array at every cell. A new rectangular-domain
regression compares all initial escape values and every subsequent queried
height, including boundary anchors: 454 assertions pass in 0.412 s.

Sparse outlet preparation preserves all 30 current production fill, coarse
and fine hashes, but reduces context time only from 166.092 to 162.426 s.
Original-input preparation costs another 9.268 s across eleven source solves.
The terrain sample cache now retains the exact pre-subtraction input as a
third value, alongside its carved height and carve amount. The temporary
uncarved compiler reads that cached value; it does not recompute noise or
recover a potentially rounded value by adding the carve back. The existing
200,000-entry bound remains. Five cache/compiler tests pass with 36 assertions
in 23.021 s, including a deliberate subtraction precision-loss example and
complete natural-region equality. Fixed river anchors also skip unused flow
ceiling projections; those anchors were already exempt from physical capping.

The combined exact-output optimization takes 150.239 s versus 166.092 s for
the current local-flow feature workload. All 30 complete fill, coarse-level
and fine-level hashes are identical. Original-terrain preparation falls from
9.268 to 2.124 s and flow-ceiling projection from 7.116 to 4.304 s across the
eleven source solves; fine work falls from 45.743 to 41.866 s. The feature
benchmark does not request contours. `03-water/reused-input-parity.json`
records current source hashes and comparisons. A new graphical walk retains
the same 300-second startup deadline and ordinary-physics route.

The optimized local-flow walk completes with exit 0: startup 298.923 s,
821.971 m traveled in 120 s, zero frozen time, grounded crossing at 12.258 s,
and the previous unlimited frame setting restored. The startup margin is
only 1.077 s and loading remains materially slower than the earlier accepted
streaming-only run; this is not universal cold-start acceptance. See
`03-water/travel-verification.json` and the complete walk telemetry. The
final optimized source is receiving its focused regression and render refresh
before the water issue is accepted.

The final optimized source passes all 26 focused water tests (1,337 assertions,
100.296 s, exit 0), including the new dense/sparse escape comparison, all four
high-water pins, photographed chunk seams and historical swimming. The final
18-image refresh is running. `03-water/final-focused.json` and the complete
text log record the exact tested source.

### Water acceptance

The final optimized render pass completes all 18 PNGs with ready=true and
exit 0. The main three camera records match the before records byte for byte.
All three exact before/after pairs, all six nearby comparisons and amplified
differences are visually accepted: the reported floating shelf, mound and
folded water edge are absent, lower lakes remain, and the changed vegetation
belongs to newly dry ground. Final mean absolute RGB differences are
8.390 / 10.203 / 10.578, with 12.587% / 13.306% / 13.625% of full-frame
pixels changing by >20 in a channel for photos 5/7/8.

Issue 3 is accepted for the reported sites. The terrain census, 26 final
focused tests, exact-output optimizations and 822 m unfrozen physical walk
support the visual judgment. Eight historical contour/skin tests retain their
baseline failures, and 298.923 s walk startup has little deadline margin.
Those are explicit remaining limits. See `03-water/result.md`. Work now
proceeds to issue 4, photo 2's missing town grass lip.

## 4. Missing grass lips

Accepted after native-panel ownership, all six matched views/pixel differences,
29 tests / 12,984 assertions, and identical 124-cell / 179-crossing physical
surveys with no blocked samples. See [the issue report](04-grass-lip/result.md).

## 5. Repeated doors

Accepted after shared entrance ownership and a second render iteration closing
the replacement window’s deep doorway join. All six matched views/differences,
four new tests and identical public clearance pass. The related suite retains
one known baseline test failure; see [the issue report](05-doors/result.md).

## 6. Stair rail/post connection

Accepted after measured native attachment, six matched views and differences,
six live traversals, 18 tests / 1,507 assertions and unchanged 124-cell /
179-crossing clearance. [Result](06-stair-rail/result.md).

## 7. Unsupported offset building

The photographed facade bay now has visible native timber supports. Six
matched views/differences, 25 tests / 3,725 assertions and unchanged 100-cell /
140-crossing clearance verify the repair. [Result](07-offset-room/result.md).

## 8. Country road endpoint

The invented north spur is removed; the actual south connection remains.
[Evidence and visual judgment](08-path-end/result.md) cover six matched views,
pixel differences, recorded road masks and rotated construction checks.

## 9. Suspended turf

Accepted after enclosed soil and timber construction, six matched differences,
16 tests / 7,654 assertions and identical collision hashes. The exact camera is
occluded; clear nearby views establish the repair. [Result](09-thin-turf/result.md).

## 10. Interior tiny roof

Accepted after exact public-ceiling ownership, six matched views/differences,
21 tests / 110 assertions and identical 132-cell / 188-crossing clearance.
[Result](10-tiny-roof/result.md).

## 11. Building seams

Photo 10 is accepted after fitting the complete native gable into the flush
end. Six matched views/differences, actual triangle checks and unchanged public
clearance pass. [Roof result](11-seams/roof-result.md). Photo 13 is active.

Photo 13 is also accepted: native timber closes the return cut. Six matched
views/differences, 14 related tests, three final targeted tests and unchanged
public clearance pass. [Wall result](11-seams/wall-result.md).

## Issue 12 — broadleaf habitat

Accepted after rejecting the single-species replacement. [Result and matched differences](12-fern/result.md); 16 tests / 660 assertions pass. All four broadleaf variants retain their original Jade Estuary distribution and fade with its continuous biome weight.

## Issue 13 — spirit orbs

[Accepted size, motion and shader visibility repair](13-orbs/result.md). Twelve timed comparisons inspected; rendered cores track their projected parents within 0.72px. Seventeen tests / 1,190 assertions pass.

## Issue 14 — camera blur

[Depth of field removed and visually accepted](14-blur/result.md). Three matched comparisons preserve bloom; the two director tests pass.

## Issue 15 — atmosphere

[Accepted profiles and warm lighting](15-atmosphere/result.md). Fourteen controlled pairs, six native lamp pairs, a current streamed Moonfen pair and their differences are inspected; 40 tests / 1,379 assertions pass.

## Issue 16 — city lanterns

[Accepted placement and matched comparisons](16-city-lanterns/result.md). Nine render pairs, native mount contacts and unchanged physical clearance pass.

## Issue 17 — city furnishings

[Accepted native seating and storage](17-props/result.md). Eleven matched pairs and their differences, seven tests and unchanged physical clearance pass.


## 18. Tunnel entrance arches

The detached road-gate approach and an initial frame-on-every-portal candidate
were rejected. The accepted construction uses the existing native timber
frame only where two public walking cells enter a complete three-band bore
with supported masonry jambs. Oversized road gates and their reservations
are removed; unrelated biome markers remain. Five isolated and eleven streamed
matched pairs were inspected, with identical cameras and explicit accounting
for four changed outskirts lots (nine houses remain). Six live traversals and
100-cell / 140-crossing physical parity pass. See [the full result](18-arches/result.md)
for the rejected candidate, native mesh collision, pixel differences and
frontage checks. All 18 items have completed their individual review.

Final focused acceptance: [95 tests / 78,973 assertions](final-regressions.txt),
plus [six frontage tests / 5,266 assertions](18-arches/frontage-tests.txt).
[Validation limits](final-validation.md) retain the known broader baseline failures.
