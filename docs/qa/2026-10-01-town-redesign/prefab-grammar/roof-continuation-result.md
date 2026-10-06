# First screenshot repair: continuous host ridge

The reported7/standard Pure Village landmark has an L-shaped upper floor.
Its rectangular roof decomposition produced an equal-width continuation beyond
the primary gable. `BuildingDesigner._wing_axis` only aligned narrower
continuations, so this equal-width piece retained a perpendicular ridge and
created the disconnected high gable highlighted by the owner.

Equal-width continuations now share the host axis. Existing native roof-fit
checks still run before accepting that axis, and `KitRoofJunctions` merges
collinear equal-profile neighbors into one roof. No new mesh or clipped roof
patch was introduced. The same rule applies on both axes and either gable end;
offset or wider wings keep their own orientation choice.

Native matched before/after review shows the extra disconnected roof replaced
by one continuous main roof. The marked front projection no longer penetrates
the main eave because it now stands beneath the main gable. The reverse-side
projection still meets the roof edge closely: this pass does not establish a
general projection/roof socket rule or accept all hood junctions.

The missing side was an isolation artifact. Instrumented source checks found
those facade edges abut `kit.tunnel-ceilings` (plus retained structure on the
back). `--context` was added to `stepped_wing_review.gd`; its images retain
neighboring town geometry with the same camera targeting. Do not use an
isolated, neighbor-culled payload to assess standalone closure. The temporary
production instrumentation was fully removed.

The flush lower eave is still open: its roof has `tight_eave=true` after public
clearance fitting. The current choice applies to both faces. The next eave
work must preserve clear-side overhangs with matching side-specific end trim,
and change reservations where even that cannot achieve a valid native roof.
Do not simply restore a cornice that intersects a walkway.

Tests:2new tests14assertions pass; existing9roof-junction tests12002assertions
pass. Matched native views in `roof-after/`; original contextual views in
`context/`. These are review evidence, not full-building art acceptance.

Full prefab-derived grammar, exact reference reconstruction and novel sampling
remain open in the linked implementation plan.

Eight-town finished-kit survey:all build,zero floating masses and roof-air
intrusions. Covered quarters remain36,18,42,68,14,24,40,92 for
7/standard,31/large,13/large,43/grand,58/large,101/large,103/grand,211/grand.
