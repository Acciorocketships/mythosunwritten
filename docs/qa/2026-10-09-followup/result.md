# October 9 follow-up

The photographed water defects and several measured loading stalls have fixes. **The full hitch investigation remains open:** the latest traversal peaked at 93 ms (none over 100 ms), while earlier clean traversals had occasional 100–141 ms frames. The earlier 1.4-second pause was caused by automatic replay capture in the profiling harness, not normal gameplay.

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

Correction: the former worst frame (1,391.9 ms) coincides exactly with the harness’s first qualifying water replay capture. That capture serialized frozen water samplers on the main thread after the callback timer ended. Replay capture is now opt-in (`--capture-ripple`) and explicitly marked as intrusive. Other 150–187 ms frames also have much smaller script, physics and render-CPU spans. Do not attribute those pauses to the grass or attachment fixes. A native sample from the earlier traversal reported a 14.5 GiB physical process footprint on this 16 GiB Mac and substantial Metal command submission work; other heavy jobs were running. Memory pressure or engine/render synchronization remains a hypothesis requiring targeted profiling.

Automatic judging logs now also record render CPU time, separate texture/buffer memory, and macOS process footprint, resident memory, disk I/O and page-in counters (schema 4), alongside existing frame, streaming, water, atmosphere, system-memory and managed-GC counters.

Clean repeat with replay capture disabled: 6,509 frames over six 30-second phases; zero frozen frames; worst frame 141.4 ms, 21 frames over 100 ms. The logger itself peaked at 11.4 ms. No claim of a controlled FPS improvement: background workload varied.

The cached river carving region no longer retains its obsolete point-bucket index after building the segment index. Three regions retained 9.47 MiB instead of 21.71 MiB, with all 3,072 sampled double-precision carve values identical. Ten carving tests pass 101,068 assertions. This is a bounded memory saving, not a complete explanation of the multi-gigabyte footprint.

## Collision memory follow-up

A destructive test of the settled nine-chunk world released 1,401 MiB by removing collision shapes; clearing the measured planning caches released about 241 MiB. This identifies collision as a major memory owner. Production now compresses exact generated collision farther than 160 m from every actor/predicted position and restores it within 96 m (formerly 384/256 m). Prediction already extends up to 192 m ahead. Rendered geometry is unchanged.

The repeated route and guarded return completed with zero frozen frames during the six measured phases. Final engine memory was 6,534 MiB versus 8,572 MiB, and running/turning p95 was 35.55 ms versus 51.81 ms. These are observations, not a controlled FPS claim: background load changed and the later run had 19 registered chunks at its worst return frame versus 24 in the earlier run. The deliberate teleport return needed 10.25 seconds of readiness waiting versus 11.18 seconds previously; this interval is outside the measured phases. Nine of 7,236 frames still exceeded 100 ms, maximum 139.1 ms. **Occasional hitches remain open.** Four collision residency tests pass 23 assertions, including partial suspension, reversal, budgets, and physics registration.

## Validation

- Focused final tests: 17/17, 87 assertions (water confluence, grass batch, atmosphere ownership/settings, collision residency).
- Feature staging: 7/7, 32 assertions. Existing invalid resource UID warnings excluded from GUT error tracking; assertions and push_error checks remain active.
- Attached/unpublished cancellation: passes; published chunks survive cancellation of remaining effect steps.
- Connected-river audit: 37 joined rivers, two seeds, no stranded endpoints. Terminal topology audit: 35 rivers, no failures. Full final channel: 525/525 wet samples.
- Water regression suite originally had two failures: the old higher-priority-only assertion was updated to test actual receiving geometry and passes; the local source peak assertion fails identically in unchanged HEAD/reference code (seed 991177, source (3,-6)).
- Full streamer test run hit its 60-second background-build deadline under concurrent load and also reported preexisting UID warnings. Isolated repeat also misses that deadline (17/19 assertions); the full windowed nine-chunk review completes successfully in about 140 seconds. This timing failure remains open rather than weakening the test deadline.

PNG images are local QA artifacts, copied to the primary checkout for review. Numeric reports, tests and audit scripts are retained with the change.

## Render warm-up investigation

The next diagnostic separates macOS main-thread CPU time from wall time. Several 100–125 ms frames used only 20–32 ms of CPU; other frames used 80–99 ms of CPU despite short script callbacks. The latter coincided with the first-view warmer drawing extra scenery (5,308–6,174 total draws). A bounded native sample shows substantial Metal draw submission work. The sample is intrusive, so this run is diagnostic evidence rather than an uncontaminated FPS benchmark.

A same-world render-category comparison at the settled forest pose reduced median main-thread CPU from 20.74 to 13.19 ms when the cliff group was hidden (4,024 to 2,403 draws). Fog/glow were much smaller costs. No production effects were removed by this test. This identifies cliff submission as a further optimization target.

The warm-up experiment divides each hidden view into four off-axis sections over four frames. Coverage and queue ordering pass 47 assertions. In traversal, quadrants reduced the largest warm-frame CPU observation from 99.0 to 51.9 ms; vertical sections reached 70.7 ms. Background load and streaming progress differed, so these separate runs do not decide the layout. The actual game camera and visible materials are unchanged.

The logger now records main-thread CPU time for hitches (schema 5). An injected 180 ms sleep is logged as wall time without being mistaken for 180 ms of CPU work. Unsupported platforms report unavailable CPU timing. The test uses rendered projection matrices to check off-axis coverage: Godot's ray-normal helper does not incorporate the frustum offset in its ray construction ([Godot 4.5 camera source](https://github.com/godotengine/godot/blob/4.5/scene/3d/camera_3d.cpp#L372)).

The final alternating comparison holds the same 25-chunk world and full-view coverage per four frames. Vertical sections are selected: main-thread CPU p95 was 26.16/26.75 ms versus whole-view 32.05/30.43 ms; peak was 30.34/29.57 versus 35.83/36.08 ms. Mean CPU stayed similar (24.28/24.68 versus 25.17/24.15 ms). Quadrants had less balanced results (p95 29.75/26.07 ms). Vertical sections reduced peak extra draw calls from about 1,872 to 597. This reduces render warm-up spikes without removing scenery or effects. It does not eliminate all wall-time stalls: a baseline interval with no warm-up still reached 126.43 ms with only 32.06 ms peak main-thread CPU. Data: `warm-balanced.json` and compressed per-frame capture.

## Cliff draw-call isolation

A second alternating same-world test separates the nested rock batches from cliff surfaces and their ground skirts. Baseline median CPU was 20.75–21.54 ms and 4,022–4,024 draws. Hiding slope rocks reduced it to 14.53–14.58 ms and 2,703 draws. Hiding the remaining cliff surfaces/skirts gave 18.99–19.12 ms and 3,722 draws. This identifies individual rock batching as the larger cost; no production geometry was removed. The test-only rebatcher preserves exact instance transforms, tints, contact planes, mesh/material identity and LOD bias (13 assertions with the real renderer; headless dummy MultiMesh readback is unsuitable). The following comparison tests larger batches before production adoption.


The 64 m large-rock trial reduced median CPU from 20.51–20.96 ms to 16.87–16.96 ms in alternating intervals, and total draws from about 4,024 to 3,334. Median wall-frame time stayed around 23 ms: this adds CPU headroom but is not an overall FPS win at this pose. The 96 m trial saved another ~1 ms CPU without improving wall time; 64 m retains finer spatial culling. The production candidate keeps the original 32 m cells and 70 m fade for pebbles, all source meshes/materials and every collision hull. Two renderer tests pass 49 assertions, including negative coordinates and exact instance preservation. Only known catalogue UID fallback warnings are excluded; other errors remain failures. Production traversal completed: 6,977 frames over six 30-second phases, no frozen frames, none over 100 ms, maximum 93.18 ms. Running-and-turning p95 was 35.09 ms; return-idle maximum 36.06 ms. The guarded teleport return required 8.97 seconds of readiness waiting outside the phases. Engine memory ended at 7,930 MiB. This is an acceptance observation, not a controlled improvement claim against earlier traversals with different background load and streaming progress. The largest frame still combined 17.0 ms script time, 13.8 ms physics and additional rendering/waiting, so occasional smaller hitches remain.

| Original rock batches | 64 m large-rock trial |
| --- | --- |
| ![Original](/Users/ryko/story/docs/qa/2026-10-09-followup/rock-batches-before.png) | ![Same rocks, fewer submissions](/Users/ryko/story/docs/qa/2026-10-09-followup/rock-batches-64.png) |

Same scene and fixed camera; animated particles may differ. No rocks or effects are intentionally removed.
