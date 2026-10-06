# Native cross-roof junction rule — October 4

`PureVillageCrossRoof` reconstructs all roof meshes of Pure Village House_5
from four native inside-valley corners, whole 3 m arm bays, handed end caps,
and coordinated ridge pieces. House_5 itself is loaded only by tests/review.
The rule does not replay a serialized prefab list or intersect independent
complete roofs. X and Z arm lengths vary independently; opposite arms are
currently symmetric. Native corner geometry owns the first lower-course bay;
additional bays extend the regular upper and curved lower courses together.

The source has a 125 mm X pivot offset, differently sized X/Z verge caps, and
short Z ridge transition pieces with authored X scale 0.7641580700874329.
Those interface details are retained rather than normalized away. Otherwise
native module geometry is not stretched to change arm length.

Validation:

- Seven reconstruction tests / 7490 assertions pass, including previous full
  House_4 and StreetHouse_1 reconstructions. House_5 roof triangles match within
  0.2 mm, including original UVs, topology, material assignments and textures.
- One coverage test / 2332 assertions passes over four X/Z length combinations,
  casting through actual triangles across central valleys, base/cornice joints
  and regular bay seams. Samples stay inside the native eave (3.75 m from the
  axis); an initial 4.25 m probe incorrectly assumed a wider regular cornice,
  and missed even the exact source reconstruction. This is sampled coverage,
  not a proof of watertightness or collision freedom.
- Native front, back and overhead source/reconstruction pixel comparisons:
  1, 3 and 8 pixels respectively differ by more than 8/255; channel mean error
  below 0.001/255. The longer X-wing sample was inspected from all three views:
  valleys, ridge transitions and eaves remain connected.

Scope: roof skin only. The review deliberately hides source walls and gables;
these floating roof-only images are component studies. Matching wall/attic
closure, room topology, asymmetric arms, occupancy clearance and production
integration are still required. No town sampler uses this new rule yet.

Commands: `test_pure_village_native_roof.gd`,
`test_pure_village_cross_roof.gd`, and
`tests/harness/suntail/native_cross_roof_review.gd`.
