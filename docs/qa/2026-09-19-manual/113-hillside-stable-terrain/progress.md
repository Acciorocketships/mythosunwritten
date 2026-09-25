> Completed: process 54762 and all associated replays/probes have exited. See [result and remaining downhill failure](result.md). Historical in-flight notes below are superseded.

# Routing on unchanged terrain — experiment

This is a controlled ablation of pass 112, not a production implementation. The exact pass-112 baseline terrain meshes and collision are reused, with old water meshes removed. Fresh WaterField/WaterSurfaceBuilder output uses the long reach adapter against HeightfieldPlan backed by the original production carving plan. This separates changed supply from changed erosion geometry. It does not establish a permanent two-planner architecture or accept the existing routing/budget/land-bar risks.

P10 and P21 use their saved source ReviewCam poses plus nearby/overview angles. Ground preservation, water supply continuity, physical surface, and native visual results must be checked. Original judging issues remain open.

Native process exec session **54762**, log `/tmp/hillside113-native.log`. It was confirmed live after announcing `HILLSIDE_NATIVE experiment=true`. Poll this exact handle; do not restart from this note alone. It runs P10 then P21 and saves under `after/`. Check-only completed with exit 0 using `/tmp/hillside113-parse.log`.

Prepared verification (not yet run on candidate output): `physical_samples.gd -- --spots=P10 --survey` compares 441 actual native-ground/water rays; `geometry_identity.gd -- --spots=P10` hashes every non-water mesh surface array, instance buffer, transform and ground collision shape against the baseline. The identity harness parses successfully. Run these after the respective snapshot is complete, then repeat for P21. Opaque diagnostic replays use the existing `september18_hillside_replay.gd` and must be judged as coverage, not final optical appearance.
