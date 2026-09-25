# Grass loading review — accepted candidate 4

## Cause and choice

The original grass jobs shared the terrain planning worker. A distant road/water job could occupy that worker for tens of seconds while already committed ground waited for its grass tiles. Uploading the resulting grass buffers was much cheaper than that queue delay. Increasing priority alone did not interrupt the occupied planner; the first scheduling candidates failed. Preparing every grass tile with its parent terrain removed grass delays but performed substantial unused work and delayed distant terrain/dressing, so candidate 3 was rejected.

Candidate 4 gives nearby grass its own single worker. Committed terrain publishes detached sampling data: exact field arrays, private grade caches and completed water fill/shore data, without canonical plans or source traces. The visual worker computes ordinary GrassField tiles in nearest order within the existing radius. Main-thread resource creation and uploads retain their existing budget. Teleports cancel queued distant visual work; terrain eviction and completion release the detached inputs. An idle-worker retention test caught the last local sampler surviving a semaphore wait; explicit release before completion publication fixes it.

## Validation

- 45 grass field, streamer, trample, sampling and queue tests pass with 452 assertions. A separate committed-parent test passes.
- The shared-cache regression fails before detachment. The idle-retention regression also fails before its fix. Completed coarse/fine water values, 1,008 signed shoreline samples, continuous ground grades and threaded grass buffers match the ordinary computation exactly.
- Fourteen fixed camera/focus pairs and their amplified pixel differences are inspected for a real 80-second distant walk. Live character motion, wind and orb lighting are not pixel-locked.

| Measurement | Accepted-13 baseline | Candidate 4 |
|---|---:|---:|
| Startup | 170.307 s | 169.477 s |
| Distant teleport arrival | 187.847 s | 189.817 s |
| Actual walk distance | 780.993 m | 775.333 m |
| Frozen walking time | 0 s | 0 s |
| Missing nonempty grass underfoot | 6.706 s | 0 s |
| Missing nearby grass | 14.832 s | 0 s |
| Settled local instances | 8,181 | 8,181 |
| Peak static memory | 2,969.238 MB | 2,968.315 MB |

At seconds 48/50/54 the candidate covers the delayed bare beds. At second 60 its distant trees are already present; the delayed terrain/dressing that rejected candidate 3 is absent in this comparison. The normal bare contour at second 20 remains unchanged. Whole-run static memory is essentially equal, not evidence of a reduction. At most 28 detached terrain samplers are present in this route. Creating 39 snapshots costs 341 ms total, 32 ms maximum; ordinary tile computation occurs separately.

## Independent teleport repeat and limits

Forest, photographed heath and corrected meadow walks complete 41.370 / 176.335 / 257.507 m with zero missing underfoot grass, zero missing nearby grass and zero terrain freezing. The forest route ends against its ordinary obstacle. Settled populations remain 11,204 / 3,920 / 13,297 instances. Baseline heath has 15.689 s of missing underfoot tiles (9.738 s proven nonempty) and 20.288 s missing nearby.

Twelve forest/heath camera pairs and differences pass visual review. Six corrected meadow pairs compare candidate 3 with candidate 4; the initial underground meadow baseline is excluded. Combined with the long route, 32 pairs are judged. At forest initial release a distant tree batch arrives later and is present by two seconds. Other far-background arrival timing and live animation differences remain in the evidence.

This repeat starts in 198.927 s versus the earlier baseline 169.200 s; heath arrival takes 203.947 versus 168.302 s. Corrected meadow arrival is 153.710 s, without a valid original baseline. Common startup phases are broadly 19% slower, including the first road phase before any grass request. The cause of that run-level timing variation is not established; the immediately paired long run has essentially equal startup/arrival. No startup speedup is claimed. Static peak is 2,706.871 MB versus the old 2,688.096 MB, with different valid traversal scope.

Acceptance covers the reported grass delay and these measured routes. Cold terrain generation remains expensive; prior water, contour and cold-start baseline failures are not claimed resolved by this visual-worker change.

## Evidence

- `investigation.md`, `visual-judgment.md`
- `crossing-comparison4.json`, `crossing-camera-check4.json`, `crossing-sampling-cost4.json`
- `crossing-before/`, `crossing-after4/`, `crossing-pixel-diff4/` (local render artifacts)
- `worker-final-tests.txt`, `idle-retention-red.txt`, `sampling-red-tests.txt`
- `crossing-before.json*`, `crossing-after4.json*` (reports, readiness and queue traces)
