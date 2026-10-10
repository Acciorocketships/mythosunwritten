# October 4 — articulated two-to-one roof ranges

Two-to-one and longer ranges now always attempt a connected cross-gabled
pavilion. Previously the mandatory attempt started at 3:1, so a random roll
left many common 4x2 and 6x3 crowns simple even where articulation fit.
Neighbor, headroom, walking-rim and bearing constraints remain unchanged. The
native junction system still closes the roofs; no room is deleted to fit them.

BuildingMass retains roof_design_trace diagnostics recording the range, outcome,
roof-space rejections and gable-contact rejections. The new probe explains
why a range stays simple instead of treating all rectangular roofs alike.

## Evidence

The red-first regression found 20 of 96 unobstructed 2:1 configurations skipped
articulation. All 96 now preserve full crown coverage and have both roof axes
(1,440 assertions). The wider range suite passes 10/11 tests, 6,446/6,447 asserts.
The one failure expects two specific old parcel IDs in seed 2; only one remains.
It fails identically with the old 3:1 rule (saved baseline). It was not weakened.

Matched generation before/after:
- 7/standard: 3 cross-gable plans, unchanged; one genuinely roof-blocked range.
- 31/large: 6 -> 7 cross-gable plans; one roof-blocked range remains.
- 103/grand: 5 -> 9 cross-gable plans. The fifth formerly skipped range is
  correctly rejected by constraints. No random simple outcomes remain there.

All three have zero exposed open gables, gable holes, unsupported roof air,
cut eaves, uncapped towers and public-air intrusions, before and after. The two
pre-existing thin roof strips in 103 remain; no new ones were introduced.
Additional 53/83/301 grand holdouts have zero on the same safety measures and
public-air intrusion checks. The pre-existing 1x1 roof in 53 remains.

Native overheads in 31 and 103 were inspected, with 31's previous view retained
for comparison. This adds real joined roof geometry; the visual improvement is
localized and does not eliminate every long roof. Some long runs are formed by
later collinear joining; others remain constrained by public space. Do not
remove enclosed passages or supporting rooms to improve the roof metrics.

## Remaining

The broader roofline and building-composition request is still open, as are
exposed upper streets, massif enclosure and full terrain/player acceptance.
This change is not whole-town art completion. The old seed-specific test failure
and the three existing thin/tiny crowns remain recorded limitations.
