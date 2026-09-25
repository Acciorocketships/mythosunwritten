# Issue 06 — loose rails beside the P08 ramp

Status: accepted for P08 and the measured guard/crossing controls.

Reference P08: Screenshot 2026-09-12 at 12.02.53 PM; seed 2697992464; player (-233.4,12.4,-954.4), crosshair (-235.2,13.5,-958.6). The original camera transform is unavailable beyond the rounded overlay. The persistent ReviewCam harness reconstructs the close view; both phases use identical transforms, FOV 75, at 0 and ±8°.

## Diagnosis and alternatives

The photo contains two separate defects. The masonry intrusion was already removed by issue 04's real ramp-air reservation. Two sloping timber bars remained across the finished wall. Transition 06 runs from (-234,11.08,-949) to (-234,14.08,-961); its left guard lies at x=-231, beside the upper house starting at y=14.08. Coarse retained-stone boxes hid portions of its posts, while its beams ignored the finished native house wall. Landing guards already consumed that wall envelope.

Adding arbitrary posts would leave rails crossing the house. Removing all ramp guards would expose genuine drops. The chosen repair passes the existing combined coarse/native wall envelope to deferred sloping-guard construction, retaining its ordinary wall intersection trimming and shared collision. Door panels remain excluded by the existing caller. No mesh, texture, floor, route or house asset changes.

## Red test, implementation and evidence

Before the production edit, both dedicated tests fail: the exact P08 ramp retains fragments across the upper house, and four rotated native-wall fixtures retain beams through a full wall. After the edit both pass (22 assertions). The fixtures retain the exposed continuation and opposite open edge, including all collision faces. Related low-parapet, native rail attachment, shading and P04/P05 route regressions pass: 12 tests / 368 assertions.

`current` is the post-issue-04, pre-issue-06 native world. `after` is a replay of the freshly generated `live-after/world.scn`, with the same original lighting as `current`. All three photo pairs in `diff` are judged: both floating bars disappear, stone/timber wall surfaces remain closed, and the path is intact. Rail-region mean absolute RGB difference is 2.42–5.11/255, with 6.24–13.26% of pixels changing by more than 20. Whole-frame differences are 0.44–0.58/255. The difference images concentrate on the removed bars rather than broad recoloring.

`before` and `original-diff` also retain the older pre-issue-04 scene and its masonry intrusion. Those combined comparisons show both the stone intrusion and bars removed; they are not credited as rail-only differences. The wider combined region changes by 6.34–13.66/255.

Ten actual player traversals on five lateral lines in both directions pass before and after this railing change. This is a visual repair with unchanged measured traversability, not a newly passable ramp. The full 48-town construction survey retains 11,868 clear public centres and 17,038 clear crossings; the same 24 off-centre pillar contacts remain.

`payload-comparison.json` proves every native asset batch and collision box stays identical. Seventeen transition surface payloads change as guards yield to existing walls; 59 mesh payloads are identical. Treads and their physical support remain covered by the route regressions. Four additional native detail pairs include one useful unobstructed corridor view and three largely occluded controls; the latter are not credited as proof of the railing repair. The useful view also removes analogous bars across the opposite house wall without opening the house.

Fresh startup took 188.802 seconds under concurrent verification load. No startup/performance improvement or broad-suite acceptance is claimed. The historical broad composition failures documented with issue 04 remain outside this focused acceptance.

Four wider native pairs preserve visible exposed platform/stair guards; facade-covered bars disappear. All four are judged as collateral controls. The fingerprinted corpus composition gate passes all 95 assertions.
