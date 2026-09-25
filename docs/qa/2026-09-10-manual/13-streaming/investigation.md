# Terrain loading investigation — September 10 manual pass

Seed 2697992464. Photo 11 records player `(1618, 12, -571)` beside missing terrain. The 16-teleport harness moves the actual character through the production world, with 10-second transient visits and four longer activation waits. Queue lifecycle records include enqueue, start, phase, completion and cancellation, timestamps, generation ownership and the player chunk at dispatch. JSONL snapshots include pending and built chunks, the active job, the first eight queued jobs and bounded cache counts.

## Brainstorm and observed causes

Increasing radius alone gives expensive cold planning more work and does not interrupt an obsolete job. Publishing ground before its final feature grade risks disagreeing collision and house foundations. Neither is the chosen fix.

The baseline reproduced an obsolete `(8, 0)` road-feature job continuing after the character moved to `(2, -11)`. That complete job took 54.314 seconds. The first settled destination required 210.501 seconds to activate. Complete-domain water solves within road planning dominate the measured field cost; their physical source domain cannot simply be cropped to the player's chunk.

Three bounded changes are under verification:

1. Cancel an obsolete road-context build between complete node/route operations. Completed atomic decisions remain cached, but no partial context becomes valid. Required feature-halo work is retained. This also makes shutdown responsive at those boundaries. A return teleport during unwinding gets a main-thread request-ownership recheck.
2. Reject an unsuitable road-node support span before constructing exact water for its five support samples. The same independent terrain and wetness predicates decide node existence.
3. Evict one least-recently-used world feature context at capacity, preserving the other 95. Cancellation does not evict an otherwise valid context.

## Red-first evidence

`/tmp/september10-stream-red.txt`: three cancellation tests fail seven assertions; immediate cancellation previously builds 13 nodes and publishes a context.

`/tmp/september10-steep-red.txt`: a terrain-rejected site unnecessarily constructs four exact water blocks. Expected zero.

`/tmp/september10-cache-red.txt`: adding block 97 leaves only one cached block and loses the recently used block. Expected 96 with only the oldest evicted.

`/tmp/september10-cancel-race-red.txt`: returning during cancellation loses the original request. A separate regression now checks terrain and feature ownership are restored.

## Validation limits while in progress

The first two baseline 40-second character walks stop against real town geometry after 4.91 m and 5.38 m. Their zero frozen time is **not** evidence of sustained streaming travel. Separate long-distance traversal is still required. Headless runs use the game's normal disabled grass runtime; graphical verification is still required.

The related streamer suite retains its documented cold-start failure: the fixed timeout expires before all nine startup chunks are built (two assertions). Cancellation and request-priority tests are separate from that historical timing failure.

The repeated teleport comparison, graphical photo-11 comparison, long travel and final acceptance remain pending.


## Complete baseline and first candidate

The baseline completed all 16 teleports. Its four settled walks measured 4.911 m / 0 frozen seconds, 5.382 m / 0, 288.106 m / 11.217, and 41.370 m / 22.696. The two short town routes hit physical obstacles; only the other routes expose meaningful streaming travel. Initial startup was 242.492 seconds, separate from the per-teleport readiness waits (210.501, 29.293, 405.843 and 35.187 seconds).

All 2,794 lifecycle events were captured without serial gaps. Sampled obsolete active work totalled 262.839 seconds. One repeated start with identical ownership was a feature owner first completed after its destination had been abandoned and then requested again on return; this is distinct from repeatedly adding the same outstanding job every frame.

Candidate 1 completed the same 16 teleports. Cancellation plus cheap support rejection and bounded context eviction reduced sampled obsolete work to 55.300 seconds. Its waits were 162.611, 13.182, 157.510 and 10.012 seconds; initial startup was 243.635 seconds. The final walk no longer froze, but the distant 288.106 m walk still froze for 11.208 seconds. **Candidate 1 is not accepted.** `comparison-candidate1.json` preserves the complete numbers and slow jobs.

The baseline's final walk also demonstrates a distinct queue inversion: feature owner `(9, -2)` finishes, then its terrain follow-up starts at inherited priority tier 0, ahead of ground `(8, -4)` only 5 m from the player. The unrelated terrain is about 217 m away. Its meshing takes 12.594 seconds. The follow-up now recomputes priority from its actual remaining components before dispatch. The frozen dispatch regression fails both ordering and priority assertions before this correction.

Finally, cold return teleports were released with only their current chunk ready. A discontinuous relocation now requires the same existing 192 m support footprint as startup before movement resumes. It does not enlarge the ordinary requested radius, restart startup, or gate ordinary chunk crossings. Arrival latency remains a separately reported cost. Candidate 2 includes this handoff and the follow-up correction, followed by a 120-second south walk after the 16-teleport sequence.

The context-cache capacity flaw was found by code inspection and reproduced by the forced-capacity regression; the initial 16-teleport baseline did not itself cross all 96 completed world contexts.


## Second candidate and continued falsification

Candidate 2 completes all 16 relocations and the additional 120-second physical south walk: 823.989 m with zero frozen seconds, after a separately recorded 144.687-second relocation wait. Startup is 240.232 seconds. The distant negative-coordinate route still freezes for 11.217 seconds at 288.106 m, however, so this candidate remains rejected. Its complete comparison is `comparison-candidate2.json`.

Arrival buffering increases the two town readiness waits to 313.164 and 122.147 seconds; it cannot be described as a latency improvement. The distant wait is 166.820 seconds and the final return is 35.600 seconds. Sampled obsolete active work is 90.585 seconds. These measurements distinguish preparation delay from movement freezing.

The distant trace reaches `(-1440, -3648.106)` while a required `(-8,-21)` road context is still calculating water. It is an actual dependency of the next ground chunk, rather than an arbitrary background job that can simply be skipped. Its road phase exceeds 30 seconds. The subsequent work therefore targets equivalent reductions in field calculation and avoidable bridge queries.

The accepted water surface reconciliation formerly queued every wet vertex, including an already settled flat lake. A new initial frontier queues only vertices incident to a violated grade constraint. Subsequent lowering retains the original relaxation. The frozen complete-queue reference agrees exactly on 96 randomized rectangular fields and three 120,000-vertex examples. The flat-lake red test records 32,000 unnecessary initial offers; the candidate has zero. Microbenchmarks are saved in `water-relaxation-benchmark.json`; actual photographed-field comparison is still required.

An independent bridge regression also records an exact hydraulic query before the existing complete terrain-span check rejects that bridge. Native support and the same nine underlying ground samples now reject impossible sites first. The predicate thresholds and accepted placement transforms are unchanged. `/tmp/september10-bridge-order-red.txt` fails one assertion; the focused candidate passes both.


The optimized photographed-field census retains all 6,724 samples exactly (`water-field-optimization-comparison.json`), taking 57.006 seconds versus the earlier 63.518-second C14 census. The combined new streamer, bridge, water-work, surface and shore checks pass 23 tests / 526 assertions in 98.444 seconds (`/tmp/september10-stream-third-unit.txt`). A focused four-relocation retry now gives the distant route 80 seconds of physical travel.

The lifecycle review additionally finds terrain `(10,1)` beginning terrain meshing at 843.550 s after two successive position samples already put it outside the complete keep halo. It proceeds through water meshing and dressing for another 2.467 seconds. Cancellation is now also observed after completed feature, water-field and mesh operations; completed cached fields remain reusable, while an obsolete job avoids its next stage. This later correction is not loaded in the running focused candidate 3 and needs final-run validation.


A further context-planning regression exposes eager construction of the second endpoint after the first is already absent. The exact empty road result is unchanged when this partner is skipped. `pair-order-red-tests.txt` records both endpoint requests; `pair-order-green-tests.txt` records only the necessary first request. This correction, like the additional stage cancellation checks, is reserved for the next complete run.


The 80-second focused candidate 3 travels 433.058 m with 36.733 seconds frozen; startup is 219.753 seconds and the cold distant arrival wait is 245.224 seconds. This run deliberately contains only the final four relocation sites, so its cache history differs from the full 16-site runs. It remains rejected. Its required `(-8,-21)` road phase is 42.877 seconds, including water requests for `(-3,-26)`, `(-7,-31)`, `(-7,-29)` and `(-2,-24)`. The full dependency takes 46.448 seconds. `comparison-candidate3-far.json` preserves its measurements.

Roadside native support checks also used water before rejecting an unsupported placement. The new failing fixture records three water builds for an impossible lamp. Moving the same support and aperture predicates before exact wetness preserves the decision. The combined cancellation/node/bridge tests pass 19 tests / 110 assertions (`stream-fourth-unit-tests.txt`). Focused candidate 4 includes this, the missing-partner shortcut and the later-stage cancellation checks.

A further alternative addresses why a local road job asks for water kilometres away: the context planner solved all four incident alternatives of every relevant endpoint before determining any accepted road. An already selected optional loop needs only its own route. For a backbone candidate, one strictly cheaper incident route proves that endpoint does not choose it; both endpoints must reject before the candidate is excluded. Full evaluation remains necessary when proving the candidate is preferred. The frozen exhaustive method is retained in `September10ExhaustivePathContext.gd`. The selected-loop regression fails at eight calls before and passes at one afterward; 12 contexts across three test seeds match complete masks, nodes, bridges and placements. Production-site comparison remains pending. This newest algorithm is not loaded in candidate 4.


The road-context cache itself also evicted a completed entry before attempting a replacement. Cancellation at its 96-entry cap therefore left 95 valid contexts. The capacity regression fails before and passes after deferring the single eviction until a complete replacement exists. This is separate from the earlier whole-world feature-context cache correction.

The full-square collision dependency gate remains intact. Relaxing it would require a new proof of native geometry reach at every physical character position; simply publishing terrain early could omit real colliders. The current candidate instead reduces exact planning work while retaining that existing activation contract.


Candidate 4 is also rejected: the same focused four-relocation/80-second route travels 411.381 m with 38.873 seconds frozen. Startup falls to 209.156 seconds, arrival is 235.641 seconds and sampled obsolete work is 10.051 seconds. These are improvements in preparation cost and discarded work, not a solution to sustained travel. `comparison-candidate4-far.json` retains the comparison with candidate 3.

The same unnecessary ranking occurred in settlement entrance masks: four already selected loop roads triggered 20 route calls. The red mask test records 20 calls; the new decision uses four. The exhaustive context and settlement-mask methods remain test-only references, including their complete preferred-route calculation. Production uses the exact cheaper-witness proof and stores only fully proven preferred routes.


All seven production-site comparisons pass (`path-context-comparison.json`): complete road masks, nodes, bridge cells, native placement batches and settlement entrance masks are identical. The six photographed contexts contain 108, 0, 0, 22, 22 and 0 road cells; the distant `(-8,-21)` context contains 63. Canonical fields are shared by the comparison, so its elapsed time is not a performance result. Candidate 5 now retests the same four-relocation/80-second distant route with the exact early-decision planner and all prior corrections.


The production comparison performs 40 exact route solves and 111 bridge profiles in the exhaustive reference, versus 28 solves and 81 profiles in the candidate; route queries fall from 131 to 71 and materialized nodes from 43 to 36. These counts accompany identical output at all seven sites. They are work counts rather than timing claims, since the comparison deliberately shares canonical field caches.


Candidate 5 passes the focused distant route: 800.478 m in 80 seconds with zero frozen time. Startup is 167.103 seconds, cold relocation readiness is 186.060 seconds, and sampled obsolete active work is 11.104 seconds. The prior candidate used 209.156 seconds at startup and still froze for 38.873 seconds during the same 80-second route. `comparison-candidate5-far.json` preserves the focused measurements. Full 16-relocation/long-route and graphical return-handoff verification remain required before accepting issue 13.

The graphical before fixture overlays the starting revision's streamer, PathPlan and WorldFeaturePlan onto the current accepted assets and the equivalent optimized water calculation. Before and after use the same water geometry. Graphical timings therefore do not replace the original fully instrumented headless baseline. Both views are captured at the production movement-release event, with readiness waits recorded separately.
