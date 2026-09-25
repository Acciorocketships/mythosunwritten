# Streaming investigation — in progress

The issue remains open. Neither a passing short walk nor exact geometry hashes establish streaming acceptance.

The initial real walk reached an obstacle after roughly 68 seconds. Its zero frozen time cannot prove that terrain keeps up along an unobstructed route. The new survey moves at 10 m/s through obstacles but obeys the production readiness freeze, and supplies its actual velocity to the existing directional lookahead. It is a scheduling stress test, not a physical walking test.

The measured queue has not reproduced duplicate starts or an endless requeue. The costly phase is usually `feature_paths`, which performs substantial hidden water/terrain work. Source solves span whole river systems rather than just the requested visible chunk; single cold source operations measured 20–33 seconds. Nearby work can wait behind those complete operations. Startup and travel are measured separately.

The corrected baseline survey reproduces 36.219 seconds of readiness freezing over 180 seconds (1,440 m travelled). Job 145, feature chunk `(-5,-9)`, starts while the player is in `(-3,-6)` and occupies the worker for 83,581 ms. Its completed cold water operations include 24.4 s, 14.3 s, 8.1 s and 13.0 s calls. As the player approaches `(-3,-8)`, the job remains active even though upcoming ground is now more urgent. Existing cancellation only removes jobs outside the keep radius; rebasing the queued jobs cannot interrupt the active job.

The candidate uses existing cancellation boundaries between complete cached planning operations to yield to a strictly more urgent queue tier. Feature dependencies inherit the urgency of their actual waiting terrain parents. Equal tiers do not interrupt each other. A yielded job resumes with its same generation and merged follow-up requirements; it publishes no partial or failed terrain result. Startup keeps its existing dependency order. The new `priority_yields` counter and explicit yield event distinguish resumption from duplicate job starts. These rules pass the scheduling regression; the full candidate traversal is still under review.

Experiments, not final acceptance:

- Reusing a certified natural region for hydraulic profile samples did not materially improve the three-context cost.
- Rectangular terrain surveys retain the exact dependency margins. They reduced final reported static memory by about 62 MB, without a material speed improvement in isolation.
- Exact per-WaterPlan field sample reuse reduced the rectangular experiment from 182.3 s to 176.7 s in one run. This is a modest observation, not a calibrated performance guarantee.
- All 19 context payload, coarse water, fine water and contour hashes match the original for both rectangular and sample-reuse experiments.
- Further province-parameter and finished-river bounds reuse is under evaluation. These changes have not been accepted yet.

`experiment-costs.json` records isolated runs. `before-survey.json` and its event log record the corrected traversal baseline. Final matching views, collateral checks and a successful candidate traversal remain required.

The first candidate survey completes 1,688 m with 11.209 s frozen and one priority yield. This is an improvement, not acceptance. At the remaining stall, a lateral terrain parent lends its near tier to the background feature job. Upcoming crossings and lateral neighbors previously shared tier 1. The second candidate assigns lateral prefetch tier 2 while moving, preserving current support tier 0 and upcoming crossings tier 1. Stopping restores ordinary nearest-ground ordering. The reproduced lateral-dependency test fails before this rule and passes after it; all 46 focused tests / 479 assertions pass. The second full graphical traversal is pending.

The second candidate completes 1,803.265 m in the 180-second survey with **0 frozen seconds**, six priority yields, and no duplicate-start counter. Its travel frame p95 is 46.908 ms versus 46.604 ms in the original; this is a scheduling repair, not a frame-rate improvement. All 19 final complete field payload/coarse/fine/contour hashes equal baseline (76 comparisons). Final hash-run timings are not credited because that run overlapped visual loading. Matched three-angle photo renders remain pending; the original P05 foreground void has not yet been recreated by the timed route, whose reproduced freeze occurs farther south.
