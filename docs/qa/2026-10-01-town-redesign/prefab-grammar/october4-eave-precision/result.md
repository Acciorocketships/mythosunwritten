# October 4: preserve intact eaves at tangent public surfaces

`KitRoofEaveFits` previously treated any nonempty roof-union result as an
obstruction. A clipping operation can re-triangulate the native skin without
removing material. In the compact photo-town's Suntail comparison, four courses
reported changes while their total area differed by only -0.84 to +0.28 millionths
of a square native metre. That is not a reason to replace their authored cornice.

The fitter now measures loss separately on each material surface. Its allowance
is the area of one triangle with the longest source edge and altitude equal to
the clipping kernel's existing spatial precision. Different materials cannot
compensate for one another. This changes assembly selection only; the public
clearance volumes and final render/collision clipping remain unchanged.

The native interior-run regression selects a retracted eave with the previous
code (two assertions fail), and preserves the complete cornice with the repair.
Tests also retain real centimetre-scale loss and reject the genuine photographed
corner obstruction. The three focused tests pass, with eight assertions. The combined precision,
fragment, roof and junction run passes 19/20 tests and 12,158/12,159 assertions;
its only failure is the same compact photo-town eave. The separate facade run
passes 14/15 tests; its upper-street assertion also fails with the old fitter.

The native hip alternative was measured and rejected: its forward corner loses
1.31 square native metres to the same stair clearance. Source-surface inspection
also confirms that the existing cap loses roof tiles, not merely hidden rafters.
No hip substitution or decorative cover was added to production. The inspected
native stair view remains in the preceding `october4-eave-stair` review.

The actual corner at `kit.spatial.parcel.maze.house.000/k0062` remains unresolved.
The roof audit still flags it. This is not completion of the roof/stair repair or
of the wider redesign. A nearby upper-street facade assertion also fails with
the old fitter (saved baseline run), and is not attributed to this change.
