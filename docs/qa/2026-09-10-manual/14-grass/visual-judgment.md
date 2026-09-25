# Grass latency visual review (in progress)

## Forest, candidate 3

All six matched forest comparisons are inspected in `pixel-diff3/forest-views.jpg`: initial release, 2/10/30 seconds and two 8-degree nearby views. The foreground carpet remains continuous with the same grass-bed boundaries and source trees/props. Settled differences follow moving orbs, their pools of light and wind; these real-time animations are not pixel-locked. The initial candidate frame has a missing distant tree batch near the horizon which is present by two seconds. This is a transient dressing timing difference, not grass improvement, and is retained in the difference evidence rather than excluded.

The forest already had grass ready in the baseline, so these views are a collateral check. The heath and grounded long-route views must establish faster arrival; acceptance remains pending.

## Grounded long-route baseline

`long-before-views.jpg` shows all ten baseline views. The first stationary frame has only two grass tiles ready, with most of the nearby carpet appearing by two seconds. The time-20-second view has a bare strip, but paired inspection shows it in both versions. It is not the measured delayed-grass interval. The actual delay is at 45.95–50.56 seconds and was captured by the readiness trace, not the four walking screenshots. The fixed route cameras use declared world coordinates rather than following small run-dependent physical displacements. Their time-20 focus is below the local higher ground, so the character appears high in the frame; this is documented and the identical view is required after the fix. The 792.15 m actual walk is independently measured, with 4.873 s missing nonempty underfoot grass and zero terrain freeze.


## Heath, candidate 3

All six paired views in `pixel-diff3/heath-views.jpg` are inspected. At initial release the bare upper bank in the baseline already has its full grass carpet in the candidate. At 2/10/30 seconds and both nearby angles the shoreline and mature grass bed match; the accepted water surface remains continuous without the original fold. Real-time water normals, wind and orb motion create additional differences. The farther horizon also contains differing tree/dressing arrival timing, which cannot be credited as grass geometry improvement. The moving route readiness trace, not the stationary pixel differences alone, establishes whether the later pop-in is removed.


## Corrected unpictured meadow

All six candidate images in `meadow-candidate3.jpg` are inspected. Grass is present at release and remains continuous at 2/10/30 seconds and both side views; the actual character is fully above its collision floor at y=5.314722. This is additional candidate-only evidence, since the old baseline datum placed the character below ground and cannot be used for a matched improvement claim. The grounded walk travels 257.50 m with zero missing grass samples and zero terrain freeze.

All twelve forest/heath camera, player and crosshair records are identical between the paired runs. Their mature instance counts are identical. The full grass field, streaming, trample and queue run passes 43 tests / 450 assertions.


## Long candidate 3 — acceptance withheld

All ten long-route pairs have been inspected (six stationary/nearby in `long-pixel-diff/available-views.jpg`, four walking views in `long-pixel-diff/walk-views.jpg`). Initial grass arrives earlier and the mature carpet matches. The 792.150 m candidate walk has zero missing-grass and zero frozen samples, versus 4.873 s missing underfoot and 11.589 s missing nearby in baseline. However, the time-60 view has missing distant ground/dressing toward the left horizon compared with baseline. Preparing every chunk's entire grass population delays that other work. Candidate 3 is rejected for this collateral regression and added CPU work. The next candidate must isolate grass computation from the terrain planner using private sampling data.

Correction to the earlier baseline inference: the bare strip at time 20 is present in both images, with grass readiness true at that capture. Baseline underfoot grass delay occurs around seconds 46–51. The stationary initial-release images are valid visual evidence of earlier grass, while the walking improvement is established by the readiness trace.


## Candidate 4 long crossing

All fourteen pairs and their amplified differences are inspected in `crossing-pixel-diff4/stationary-views.jpg`, `walking-first.jpg`, and `walking-last.jpg`. At seconds 48/50/54 the candidate has grass on the previously bare beds; time 80 also shows earlier grass farther along the visible corridor. The normal bare contour at time 20 remains in both, as expected. The time-60 horizon now has distant trees already present in the candidate, reversing the delayed-dressing concern that rejected candidate 3. Mature stationary populations remain identical at 8,181 instances. Wind, orb lighting and the live character contribute unrelated pixel changes; fixed cameras and aim/focus records match in all fourteen views, while the character is allowed to keep walking and differs slightly in position.

The new paired route measures 780.993 m before and 775.333 m after, both without terrain freezing. The ordinary nonempty grass population is verified by the union of both observed runs: all 6.706 seconds of missing-underfoot baseline samples are confirmed nonempty. Candidate underfoot and nearby missing durations are both zero, versus 14.832 seconds missing nearby before. Startup is 170.307/169.477 seconds and distant arrival 187.847/189.817 seconds. Total static peaks are 2,969.238/2,968.315 MB; these essentially equal totals do not establish a memory reduction. The candidate retains at most 28 detached ground samplers in this route, subject to terrain eviction. The three-site repeat remains pending.


Candidate-4 forest: all six matched images and differences are inspected in `sites-pixel-diff4/forest-views.jpg`. The grass bed boundaries and settled geometry match. At initial release a distant tree batch is absent in the candidate and present by the two-second image; this bounded arrival-timing difference remains visible in the evidence and is not credited as an improvement. Later views preserve that batch. Moving orbs, their light pools and wind explain most remaining differences. All 153 forest walking samples have prepared underfoot/nearby grass and zero terrain freezing; the 41.370 m path reaches its ordinary obstacle.

Candidate-4 heath: all six matched views and differences are inspected in `sites-pixel-diff4/heath-views.jpg`. Grass covers the formerly bare upper bank at release. The settled bank and repaired shoreline are retained. Far terrain and dressing arrive at different moments, and water/orb animation changes pixels independently; these are not hidden or credited as grass geometry changes. All 158 walking samples have underfoot and nearby grass prepared, with zero frozen time over 176.335 m. Arrival takes 203.947 s versus the earlier baseline 168.302 s.

Timing qualification: 30 common startup phases longer than 200 ms total 163.045 s in the old baseline and 193.612 s in this candidate repeat, with a median ratio of 1.1855. The first feature-path phase, before any grass tile can be requested, is already 58.028 s versus 48.871 s (1.1874×). This demonstrates a broad run-level slowdown rather than added grass preparation work alone; it does not identify an external cause. The immediately paired long-route run has nearly equal startup/arrival timings. Both raw times remain reported, without a startup speedup claim.

Candidate-4 corrected meadow: six candidate-3/candidate-4 pairs and differences are inspected in `meadow-iteration-diff4/meadow-views.jpg`. These compare two valid corrected camera replays, not the invalid original underground baseline. All fixed camera/focus records match. Grass beds and distant settlement/terrain remain the same; orb motion/light and wind account for visible differences. The final 257.507 m walk has zero missing grass and zero terrain freezing. All twelve forest/heath fixed camera/focus records also match their original baseline. Issue 14 is accepted for these measured routes and views, with the stated startup and original-camera limitations.
