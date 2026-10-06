# October 3: native embedded-frontage study and shed-roof admission

Status: limited repair retained; the requested projecting inhabited facades,
stepped tower/wing compositions and enclosed massif streets remain OPEN.
No new bow-window assembly was enabled in production in this pass.

## Native parts inspected

Reproducible study: `tests/harness/suntail/pure_village_frontage_parts.gd`.
Original Pure Village assets are rendered at their authored scale, front and back.
BowWindow_1 through _6 measure roughly 6.6–7.2 native metres tall; _7 through
_9 measure roughly 10.2–10.5 m. These are complete masonry/window/roof assemblies,
not small one-storey inserts. BowWindow_4 has a closed stone front and returns,
a circular window, an authored curved shed roof, timber brackets and boarded
roof underside. Its rear is open for joining the host. Its measured size is
3.903 x 6.727 x 2.960 m; min Y is -0.990 m.

The current low wall-room storey is 3 native metres tall. Uniformly shrinking
these whole pieces to fit it would also shrink the window, masonry and timber.
Their use needs a multi-storey frontage reservation and a host opening, roof seat,
backing and street-clearance contract. Merely placing one over the existing
facade is not accepted. The one-metre-wide Wall_Start_10x30_0 is genuine native
return-wall stock; Wall_Slice_Start_20x15 is a triangular 2 x 1.5 m closure.
A recessed entry with those parts was considered but not implemented: corner
windows, return closures and the actual doorway/circulation must be co-designed.
Do not report a projecting or recessed inhabited facade as delivered by this pass.

The source filename is `BowWIndow_8.glb` (capital I). The study now preserves
that spelling; the first exploratory render logged a case warning.

## Retained production repair

`BuildingKitAssembler._emit_pent_eaves` now admits each contiguous, same-facing
shed-eave run independently. Previously the first rejected piece erased all
pent eaves on every face of the room. Each accepted run still contains all its
native eave panels and both barge end boards. A blocked panel or end rejects
that entire run. Lone panels remain rejected. Finished public-air clearance
is unchanged, and refusing a roof never removes the inhabited wall.

This repairs optional roof admission; it does not change the room footprint,
wall projection, tower count, bore planning or walking geometry.

## Validation and visual judgment

- Wall-room and initial per-run regression: 6/6 tests, 82 assertions, 59.254 s.
- Final expanded roof-admission tests: 2/2, 17 assertions, 15.548 s. One local
  obstruction rejects its complete run while clear faces survive; total
  rejection leaves all eight native wall panels intact.
- Native 13/large build rendered platform and wall-room views successfully.
  Inspected platform_wall0, platform_wall2 and upper_wall_room0. Existing
  streets/doors remain clear in these views. Broad flat wall bands and the
  unchanged flush room fronts are still apparent; this is not art acceptance
  of embedded frontages or the overall redesign.
- Source part front/back views inspected for BowWindow_4, front for BowWindow_7,
  and the triangular return piece. Full outputs and measured bounds are beside
  this report. No new texture or primitive architecture was introduced.
- No production timing rerun: the 7.208 s result in the parent plan predates
  this small admission change. No full-suite or new player-walk claim.

Next architectural step: reserve a complete stepped facade/room/roof volume
before fitting its source assets, with actual route air and bearing represented
in the same proposal. Continue to reject visually worse covered passages even
when source tunnel counts increase (previous tunnel-bearing review).
