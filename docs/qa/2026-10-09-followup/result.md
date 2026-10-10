# October 9 follow-up

The photographed water defects and several measured loading stalls have fixes. **The full hitch investigation remains open:** the final traversal still captured a 1.4-second pause that was mostly outside instrumented game callbacks.

| Issue | Cause and change | Evidence |
| --- | --- | --- |
| Water draped over hills | A tributary crossed a lower river 36 m above its bed because the original priority rule missed the confluence. The lower river also excavated the bank the tributary had surveyed. Joined branches now connect to immutable terminal rivers and lower their beds against those rivers' excavated banks. | Both photographed sites reviewed; 525 centerline samples remain wet, minimum depth 0.449 m. All 37 audited joined rivers across two seeds still touch their actual final receivers. |
| Grass scheduling hitch | A scan sorted the queue once per tile. It now submits the whole scan and sorts once. | Identical 132-tile queue: 43.3 ms → 0.96 ms in the isolated check. Final travel grass backlog p95 was six tiles while running, zero after stopping. |
| Chunk / town loading stalls | Bounded pieces were built off-tree, then all their scene and physics registrations happened together. Empty roots now enter the scene first; existing steps register their pieces incrementally. Terrain stays hidden and unready until complete. Grass footprint calculations move to the worker. | Prior terrain attachment reached 42.7 ms; largest logged final attach was 10.3 ms. Cancellation and feature queue tests pass. These are diagnostic observations, not controlled overall FPS claims. |
| Fog and lighting | Fog extending far beyond the sun's shadow range produced bright distant silhouettes. Forest fog now uses the shadowed 60 m range. Every biome has editable fog range, sky influence, ambient scattering and shadow softness. | Production-setting lighting comparison below. Forest uses warm canopy scattering; marsh uses blue twilight; other palettes retain separate settings. |
| Bloom and short birch | Previous delivery normalized bloom and preserved highlights, removed all seasons of the actual short white-trunked variant 04, and restored interrupted orb/mist creation. | [Matched screenshots and original log analysis](../2026-10-09-evening-pass/result.md), already merged at e15a7b2d5. |

## Water before / after

Owner screenshot and current capture at its recorded camera location. The erroneous uphill sheet is gone; its tributary joins the lower channel earlier. Lighting also changed, and the review harness omits the character.

| Before | After |
| --- | --- |
| ![Owner's hillside sheet](/Users/ryko/story/docs/qa/2026-10-09-followup/water-owner-before.png) | ![Corrected hillside](/Users/ryko/story/docs/qa/2026-10-09-followup/water-close-final.png) |

[Descending channel overview](/Users/ryko/story/docs/qa/2026-10-09-followup/channel-final.png). The other photographed hillside was also reviewed during bank reconciliation: [bank-aware candidate](/Users/ryko/story/docs/qa/2026-10-09-followup/water-hill-bank-aware.png). This is a tested correction, not a proof that every generated waterway in every seed is contained.

## Biome lighting comparison

Same forest geometry and camera, applying each biome's production lighting settings. Local forest effects remain the same, so this isolates lighting rather than depicting three different generated biomes.

| Meadow | Forest | Twilight marsh |
| --- | --- | --- |
| ![Meadow](/Users/ryko/story/docs/qa/2026-10-09-followup/meadow-light-final.png) | ![Forest mist and canopy scattering](/Users/ryko/story/docs/qa/2026-10-09-followup/forest-light-final.png) | ![Blue twilight](/Users/ryko/story/docs/qa/2026-10-09-followup/twilight-light-final.png) |

## Performance limits and next investigation

.NET Godot, 1600×900, no vsync, seed 2697992464, start (679,1539), fixed run/turn route and return to the initial pose. Final run: six 30-second phases, 6,033 sampled frames, no frozen frames. Running grass backlog p95 six tiles; running-and-turning p95 two; idle zero. Engine memory ended at 8,715 MiB. The earlier 45-second-phase run is longer and covers more ground, so aggregate before/after FPS is not a controlled comparison.

Final worst frame: 1,391.9 ms, process span 1,264.1 ms, measured water callback 34.5 ms, streamer 5.4 ms, atmosphere 6.0 ms, no increment in managed GC pause time. Other 150–187 ms frames also have much smaller script, physics and render-CPU spans. Do not attribute those pauses to the grass or attachment fixes. A native sample from the earlier traversal reported a 14.5 GiB physical process footprint on this 16 GiB Mac and substantial Metal command submission work; other heavy jobs were running. Memory pressure or engine/render synchronization remains a hypothesis requiring targeted profiling.

Automatic judging logs now also record render CPU time and separate texture/buffer memory (schema 3), alongside existing frame, streaming, water, atmosphere, system-memory and managed-GC counters.

## Validation

- Focused final tests: 17/17, 87 assertions (water confluence, grass batch, atmosphere ownership/settings, collision residency).
- Feature staging: 7/7, 32 assertions. Existing invalid resource UID warnings excluded from GUT error tracking; assertions and push_error checks remain active.
- Attached/unpublished cancellation: passes; published chunks survive cancellation of remaining effect steps.
- Connected-river audit: 37 joined rivers, two seeds, no stranded endpoints. Terminal topology audit: 35 rivers, no failures. Full final channel: 525/525 wet samples.
- Water regression suite originally had two failures: the old higher-priority-only assertion was updated to test actual receiving geometry and passes; the local source peak assertion fails identically in unchanged HEAD/reference code (seed 991177, source (3,-6)).
- Full streamer test run hit its 60-second background-build deadline under concurrent load and also reported preexisting UID warnings. Isolated repeat also misses that deadline (17/19 assertions); the full windowed nine-chunk review completes successfully in about 140 seconds. This timing failure remains open rather than weakening the test deadline.

PNG images are local QA artifacts, copied to the primary checkout for review. Numeric reports, tests and audit scripts are retained with the change.
