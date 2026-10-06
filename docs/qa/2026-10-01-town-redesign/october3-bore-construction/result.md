# October 3 — preserve inhabited mass above bored streets

This continues the deferred `october3-bore-headroom` experiment. It is a bounded
construction improvement, not acceptance of the complete town redesign.

## Construction

`WarrenExcavation.HEADROOM_BANDS` now shares the volume/transition contract:
two bands, or six world metres. The former third band excavated nine metres
and removed room-bearing mass. Real surface/headroom checks remain in place.
There is still one deterministic town solve; no seed exception, audit-driven
regeneration, or alternate-town retry was added.

The earlier candidate could not compile 58/large: a private five-cell L-shaped
crown cannot be covered by the existing two-, four-, or six-cell gable strips.
A final single-cell remainder now has a complete smaller native gable recipe.
It uses cropped original LowPolyFantasyVillage Roof_03 stock at uniform half
module scale, plus two fitted native SFV timber attic panels. Both ends close;
this is neither a public deck nor an open quarter of a larger roof. The usual
measured public-air, bearing and roof-contact checks still apply. A crown may
use this recipe only for its last cell. Completing the first failing crown
revealed a second odd crown in the same town; both now compile. Manifest and
provenance are `town_corner_roofs`.

A four-quarter hip prototype was rejected for visible cut seams and a detached
underside. Its two assets were removed from the production catalog and disk;
`rejected-hip/` preserves the visual evidence only. A first complete-gable
prototype lacked attic panels; the final gallery includes both closures.

The lower bore also exposed an architectural omission in 60/standard: the
long wings created by the cross-gable planner never received dormer proposals.
They now use an independent seeded dormer draw. The existing measured fitter
moves/rejects blocked openings against adjoining roofs and public clearance.
This does not consume the RNG used for the house's other design choices.
The previously bare town proposes five dormers, one moved to a clear bay.

## Evidence

Across the five matched towns, finished inhabited coverage above streets rises
from 104/1344 to 148/1388 quarter-cells (7.74% to 10.66%). This is a 42% increase
in covered quarters, not a claim that every town or every street improves.

| Town | Before covered quarters | After |
| --- | ---: | ---: |
| 13/large | 24 | 28 |
| 31/large | 8 | 12 |
| 43/grand | 24 | 72 |
| 101/large | 16 | 8 |
| 103/grand | 32 | 28 |

The expanded nine-town survey also includes 58/large, 67/large, 34/compact and
60/standard. `corpus.json` is before the cross-wing dormer repair;
`final-corpus.json` is the retained version. These count actual finished rooms,
not merely natural-tunnel labels or unsupported crowns.

Native `13_large_town13.png` shows the new complete timber ceiling over the
lower alley, with daylight at its far end. The previous matched open view is
in `../october3-bore-headroom/before/`. The overview of 58/large confirms it now
builds; it still shows exposed upper walks and repeated wall bands. The small
roof gallery judges construction stock only, not an entire building design.
The flat-stage harness does not establish streamed terrain/grass quality.

Actual player: 43/grand passes ten directions across two exterior skywalks,
an occupied bridge and two underpasses. 13/large's specifically newly covered
street (2,0,-4) passes both directions. See `player43.json` and
`player13-covered.json`. These walks preceded the final roof-only dormer repair;
final measured public-air checks additionally cover that repair.

## Validation status

The initial related suite passes 8/8 tests, 138 assertions. The new corner and
headroom tests, including native triangle rays through both attic ends, pass
4/4, 89 assertions before the cross-wing follow-up.

The broad native roof suite initially fails three dormer-sample assertions in
two tests. A matched pre-change run fails two such assertions in the same two
tests. A separate native asset/material probe identifies the additional case
as 60/standard having no dormer placements at all, rather than a material-name
mismatch. That is why the cross-wing omission above was fixed; the test was not
weakened. Final test, survey and quiet timing results are recorded below.

## Still open

This does not settle the user's larger architectural concerns. Dense upper
frontages still look repetitive, some climbing walks remain exposed, and the
mix of integrated towers, inhabited retaining fronts and canopy streets still
needs broader visual iteration. The full suite and streamed-world acceptance
are not claimed here.

## Final retained checks

- New corner/headroom, connected-range and native town roof suites: **19/19
  tests, 13,761 assertions**. The cross-wing dormer repair also resolves the two
  pre-existing missing-sample failures in this selected roof suite. No test
  requirement was removed.
- Final nine-town survey: **212 covered quarters / 652 public cells**, zero
  floating masses and zero measured roof/public-air intrusions. The dormer
  repair leaves every surveyed street coverage record unchanged.
- Final native views: `final-native/13_large_town13.png` and
  `final-native/60_standard_roof60.png` inspected. The latter shows a complete
  Pure Village dormer on the long wing meeting its transverse pavilion.
- `tests/test_october3_bore_headroom.gd` now contains the previously deferred
  contract tests; the study under `tests/harness/suntail/` has been promoted.
- `git diff --check` passes. No commit or PR was created.

- Quiet real-terrain production check: **1/1, 125 assertions**; town build
  **5,103 ms**, below the unchanged 8,000 ms ceiling. This is one measured
  production site, not a general performance guarantee or a full world run.
