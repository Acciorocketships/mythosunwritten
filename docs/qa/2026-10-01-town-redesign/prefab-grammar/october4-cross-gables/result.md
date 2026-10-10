# Compound-roof gable closure — October 4

`PureVillageCrossRoof` now derives all four authored House_5 gables along
with the roof. Each end contains two curved lower halves and one upper peak.
Long X caps seat the gable at their outer end. Short Z caps have distinct
lower/upper seats: the positive-Z lower half is 125 mm ahead of the peak;
the negative-Z halves share a plane. All depend on the same arm dimensions.
The datum follows `seam - 3.125`, so changing roof height carries the closure.

Evidence:

- Seven source-reconstruction tests / 7874 assertions pass. House_5 now
  compares roof AND gable geometry, textures, UVs and materials within 0.2 mm.
- Two coverage tests / 2412 assertions pass over four X/Z arm combinations.
  Roof coverage explicitly excludes gable triangles, so new walls cannot mask
  roof gaps. Eighty additional segment probes check the lower gable faces and
  upper peaks at every end across those dimensions.
- Native source/reconstruction renders differ by 1, 4 and 8 pixels above
  8/255 in front/back/above views, respectively; channel mean error <0.001/255.
  Extended-wing front/back views inspected: all visible gable ends close
  against their authored roof/verge without exposed triangular holes.

Scope remains a component study. These views omit the ground-floor host and
short eave-side attic walls, intentionally. The new gables close the ends;
they do not make a complete enclosed building. House_5's remaining host parts
include small authored seat offsets and duplicate foundation panels; those
must be classified before a full-house reconstruction is claimed. There is
no production integration of this new roof family yet.
