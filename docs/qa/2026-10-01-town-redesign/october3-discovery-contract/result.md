# Wider-town discovery contract — open

A fresh baseline run of world1 confirms record validation=true, urban=true,
payload=true, no missing assets, bound ending208.011m. The redesigned record
ends263.838m and is rejected by the old permitted240.001m envelope. Current
urban construction and payload independently validate after asset registration.

The new real-town regression `test_october3_town_discovery` fails exactly two
assertions: record validation and discovery at its far finite control fringe.
The world planner is given the already-built, cached canonical record; its
query is inside record.bounds but the early192m layout/record cull returns[].
The query100m beyond the record correctly returns[]. This proves an actual
query mismatch, not just an overly strict record validator. 3/5 assertions,
14.246 seconds. Leave red until the shared discovery contract is corrected.

Do not solve only the assertion or inflate an arbitrary constant. The source
field may extend beyond its ordinary2.5*radius box for central-green layouts.
Placement anchors the primary entrance to the site, so source radius is not
world reach. The192m SETTLEMENT_INSET is also referenced by an older program
contract, while WorldFeaturePlan uses both layout_record_radius and record_bound
for early culling. WorldFeaturePlan emits each town's complete payload only
from its site chunk; geometry_halo currently derives from individual asset
reach. Audit actual geometry reach before altering that ownership scheme.

A viable next implementation must separate seed-derived conservative discovery
from site spacing and prove finite source/kit/road/grade reach. If using a broad
outer bound plus a cheaper seed-specific inner bound, test uncached and cached
discovery and avoid multiplying distant full town builds. Preserve current
geometry and spacing. Only change render ownership/halo if actual geometry
exceeds its current residence guarantee. Verify both canonical world1/16 and
holdout towns, existing grade-edge tests, deterministic records, and streaming.

Full suite runner24812 is independently still live. This new regression was
created after its file list was captured and is not part of that392-file run.

Actual world1 native-instance and surface-vertex bounds end at200.060m; halo=1.
This exceeds the old192m prose assumption but does NOT alone prove a render
residency failure: sites sit on24m lattice points, so their largest positive
in-chunk offset is168m, and168+200.06 remains below384m. Audit the whole supported
source distribution before changing render ownership; do not claim this seed
already loses geometry. The terrain-control discovery failure above is proven.

## Implemented discovery correction

`WarrenTownDiscovery` derives an outer bound from the maximum sampling extent
using the same crown/green/width constants as WarrenTownField. Before a full
town build, a cached seed-specific bound uses the actual field's longest span
from any possible entrance, plus complete native-part, entry, external-road,
claim-rounding and finite smooth-min collar margins. Native control reach stays
in the existing query/validation margin. VillagePlan publishes that independent
bound on the record; WorldFeaturePlan uses it instead of the legacy192m culls.
FeatureProgram's outer super-cell search covers the maximum derived bound.
The legacy site/layout budget is retained separately. No buildings, site
positions, road geometry, random draws, or rendering ownership changed.

The initial fix passes10/10 (new regression plus nine grade-topology tests),
41 assertions. Extended test passes2/2,169 assertions: real cached/uncached
record discovery, one build across repeated queries, finite far rejection,
32 seeded bounds and128 field envelopes across all size anchors. Canonical
production hamlet-record test now passes1/1,50 assertions, including world1
and16 (formerly both failed after registration repair). All focused jobs done.

Planning cost probe:32 cold seed bounds1407.194ms, warm32 bounds0.012ms in a
concurrent run. Actual sampled bounds316.0–461.2m (see all32 in log); global outer
radius822.974m using measured asset reach30.564m. This is conservative query
metadata, not expanded town geometry or a new site reservation. Full streaming
build-count/memory/performance acceptance remains open: the broader search may
admit additional complete towns, so metadata timing alone is insufficient.
The native render-owner reach assumption is still a separate distribution audit.

This is the fourth production edit during full runner24812. Use the focused
logs and fixed-manifest for affected earlier files; initial full-run logs are
not all the final revision. New discovery tests were added after its392-file
list was captured. Comment/constant naming cleanup after tests changes no
expressions or behavior (WARREN_RECORD_REACH -> LEGACY_LAYOUT_REACH).
