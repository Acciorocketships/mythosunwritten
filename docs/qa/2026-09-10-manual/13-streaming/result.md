# Terrain streaming — accepted on the reproduced routes

The repeated teleport test reproduces two distinct stalls before the fix: a distant walk freezes for 11.217 s at 288.106 m, and the photo-11 return freezes for 22.696 s. Four intermediate candidates were rejected. Candidate 5 completes all 16 teleports with zero frozen time on both walks and then travels 823.961 m in 120 s without freezing. The independent four-teleport retry also travels 800.478 m in 80 s with zero frozen time.

## Cause and implementation

The baseline spends 952.36 worker seconds in road-feature planning, including exact water domains for remote alternatives that cannot affect the relevant road. Obsolete active work also continues after teleports. A feature job's terrain follow-up inherits the feature's nearby dependency priority and can precede ground only five metres from the player.

The ordinary planner now rejects impossible terrain support before wetness work, skips a partner when an endpoint is absent, and uses exact early witnesses for road selection. Selected loops need no alternative ranking; a cheaper feasible route proves rejection at an endpoint. Fully proven selections retain the existing bounded cache. Seven real production contexts and their settlement masks are identical to the frozen exhaustive reference.

Obsolete jobs cancel between complete cached operations; partial feature contexts are never published. Required feature/collision halos remain intact. Terrain follow-ups recompute their priority. World-context eviction retains the other 95 entries, and cancellation cannot evict a valid replacement candidate. A discontinuous relocation prepares the existing nine-chunk travel buffer before movement release. Ordinary travel does not restart that gate or enlarge the streaming radius.

Equivalent water relaxation starts only on violated edges rather than queuing every wet point. The frozen full-queue reference, 96 randomized rectangles, three large fields and all 6,724 photographed water samples agree exactly. This changes calculation work, not the accepted water surface.

## Actual character measurements

| Measurement | Original baseline | Candidate 5 |
| --- | ---: | ---: |
| Startup | 242.492 s | 168.671 s |
| First town arrival | 210.501 s | 254.910 s |
| Second town arrival | 29.293 s | 109.351 s |
| Distant arrival | 405.843 s | 135.756 s |
| Final return arrival | 35.187 s | 28.412 s |
| Distant 40 s walk | 288.106 m / 11.217 s frozen | 400.209 m / 0 s frozen |
| Final return walk | 41.370 m / 22.696 s frozen | 41.370 m / 0 s frozen |
| Additional 120 s walk | Not run in original baseline | 823.961 m / 0 s frozen |

The two town walks stop at the same real obstacles after 4.911 m and 5.382 m; their zero freezing is not long-distance evidence. Arrival gates increase some preparation waits. Candidate 2 already had this gate but still froze on the distant route; candidate 5 reduces its arrival waits from 313.164/122.147/166.820/35.600 s to the values above. The additional long-route preparation falls from 144.687 s in candidate 2 to 89.243 s.

## Queue review

`comparison-candidate5.json` includes all recorded lifecycle events plus any final-report tail: 2,794 baseline and 4,806 candidate events, with no internal serial gaps. Sampled obsolete work falls from 262.839 s to 67.624 s despite the candidate's additional route. Nine active obsolete jobs cancel. The longest candidate job is 84.889 s; the baseline's longest is 197.326 s. Long candidate queue waits belong to outer tier-3 chunks; the independently reproduced near-ground follow-up inversion passes its regression.

Both traces count one repeated `(8,0)` feature owner across separate visits. The candidate abandons the first visit and requests it again on return, rather than continually starting the same outstanding request. Raw repeated-start records are retained. Completed world/path context caches end at their 96-entry caps after the candidate's longer route. Peak static memory is 3,612.5 MB versus 3,293.2 MB in the shorter baseline; this is not a memory-reduction claim.

## Visual and regression judgment

See `visual-judgment.md` and `pixel-diff/all-views.jpg`. All six camera poses match, and nine support chunks replace three at movement release. The return fixture shows the previously empty distant forest populated, but does not reproduce the original screenshot's large foreground void. The physical baseline's nearby freeze and matched repeated traversal establish the measured correction; the image difference alone does not.

The final cancellation/decision suite passes 16 tests / 102 assertions. Related streamer, bridge and water checks pass 23 tests / 526 assertions. Seven production road contexts and masks match exactly. The broader streamer run retains its documented fixed-timeout cold-start failure (30/31 tests, 157/159 assertions); the accepted water suite retains its eight historical failures. Reports and logs are preserved in this directory.

Cold generation remains expensive and these routes do not prove universal streaming performance. Grass scheduling is the next separate issue. Full investigation, rejected candidates and validation limits are in `investigation.md`.
