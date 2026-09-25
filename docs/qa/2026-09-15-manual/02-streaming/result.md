# Streaming review — reproduced travel stall repaired

The revised candidate completes the reproduced 180-second, 10 m/s southward survey without a readiness freeze. The original freezes for 36.219 seconds. This is a measured travel-scheduling repair; cold startup remains expensive. Acceptance is scoped to the reproduced route and the matched loaded-site controls below.

## Cause and final rule

One background feature job held the worker for 83.581 seconds while the next terrain crossing became urgent. Its road planning performs complete river-system solves. Queue rebasing reordered waiting work but did not interrupt the active job.

The worker now yields at existing completed planning boundaries to strictly more urgent work, then resumes the same generation using completed field/route caches. Current terrain retains first priority. While moving, upcoming crossings precede lateral neighbors; feature owners inherit the priority of their actual waiting terrain parents. Stopping restores nearest-ground prefetch. Equal tiers do not repeatedly interrupt one another, and no partial terrain or failed-result marker is published for a yield.

The first candidate retained the shared lateral/forward tier and still froze for 11.209 seconds. Its incomplete result is retained in the evidence rather than credited as a fix.

Exact field reuse also reduces redundant work: rectangular surveys retain the original dependency margins, repeated field samples preserve their exact coordinates and double values, geological province parameters use bounded synchronized storage, and completed river bounds do not retain evicted traces. These optimizations do not approximate terrain or water.

## Live traversal

Seed **2697992464**, start `(-530.6, 32, -96)`, movement south at 10 m/s, survey height 44 m after movement starts. The survey bypasses obstacles but obeys the actual terrain readiness freeze and supplies its velocity to production lookahead. It is distinct from a physical character walk. GUI Metal, 1920×1080, 60 FPS cap with the existing startup cap; no camera captures or other heavy jobs overlap these timings.

| Run | Distance | Frozen time | Travel frame p95 | Priority yields |
|---|---:|---:|---:|---:|
| Original | 1,440.061 m | 36.219 s | 46.604 ms | 0 |
| First candidate, rejected | 1,688.467 m | 11.209 s | 46.930 ms | 1 |
| Revised candidate | 1,803.265 m | 0 s | 46.908 ms | 6 |

![Recorded traversal distance](travel-comparison.png)

The successful candidate has no unexpected duplicate job starts. Frame rate is effectively unchanged. Startup remains roughly seven minutes in these runs; this review does not claim a startup speedup or universal streaming performance across all terrain and travel speeds.

## Correctness and visual evidence

- 46 focused tests / 479 assertions pass, including the new failing-then-passing lateral dependency case, exact cache eviction/concurrent-seed controls, obsolete-job cancellation, startup ordering and resumed context ownership.
- All 19 original complete water contexts match the final payload, coarse-level, fine-level and contour hashes: **76/76 exact comparisons**. The last hash run overlapped visual loading, so its timings are excluded.
- Matched P05 photo and ±8° views: **three inspected pairs pass as appearance controls**. Ground, path shape, bushes and distant terrain remain unchanged; the displayed differences are small character/ambient details. Thresholded changed pixels are 0.076–0.078%, not evidence of a terrain alteration. All three camera transforms match exactly between runs. [Pairs and absolute differences](photos/differences/) and [metrics](photos/metrics.json). The reconstructed camera derives from the rounded player/crosshair overlays via `ReviewCam.solve_cam` and the actual collision obstruction solver.
- The baseline survey reproduces freezing farther south than P05. It does not recreate the original photographed foreground void. A loaded-site image comparison is a visual control, not proof of an identical temporal reproduction.

The earlier actual-character walk stopped at an obstacle after about 68 seconds; its zero frozen time is not credited as an unobstructed streaming stress test. An earlier survey with a stalled screenshot coroutine is explicitly excluded (`invalid-capture-survey*`).

Raw surveys, per-second records and lifecycle event logs are adjacent to this report. `survey-comparison-in-progress.json`, `water-hash-comparison.json`, and `investigation.md` retain the intermediate evidence and its limits.
