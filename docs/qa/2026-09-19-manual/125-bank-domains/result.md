# Independent neighboring bank domains

Two separately created WaterPlans and WorldFieldBlockCaches build neighboring
owners (-3,0) and (-3,1), with complete 26 m query margins. Twenty-eight source
formations fit wholly inside their shared query overlap. Fourteen become fitted
banks. All 28 admission decisions, rock faces, turf faces, bounds, native roots
and other payload fields are byte-identical across the two domains.

The strict whole-record gate reports seven differences. `differences.json`
isolates every one to `replay_recipe.shore_level`, with absolute differences of
1.776e-15 or 3.553e-15 m. No geometry differs. The strict gate remains reported
as failed; there is no production rounding change merely to make it green.
This supports local spatial geometry consistency, not global water-domain or
whole-record bitwise invariance. Plants and grass were not compared here.

The first fixture omitted `CliffRockDressing.prepare()` and produced repeated
native-relief bounds errors. It is invalid. Preparation was added, and the
fresh corrected run completed both domains in 97.771 and 72.360 seconds.
The corrected run has no script errors. The expected corner clearance veto
at (-589.5,8,181.5) is identical in both domains.

The existing narrow shoreline fitter remains experimental. Together with
pass 124's wider native collision survey, these results advance integration
evidence but do not close missing waterside dressing, joined recipes, plant/
grass publication, or the requested art improvements.
