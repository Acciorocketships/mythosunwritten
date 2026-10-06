# Native Suntail tight-eave seating

The remaining seven measured eave cuts in the 53/103/301/83 holdouts were Suntail straight panels used as tight eaves. Their source mesh extends **0.118539 native metres beyond the nominal wall plane**. Walking clearance clipped that foot and left the visible slots in the reviewed stair-side roof.

The tight-eave role now slides the complete source panel 0.12 m inward and 0.18 m upward, along the existing 3:2 roof plane. Pitch, scale, source texture coordinates and normals remain unchanged. Ordinary overhanging cornices retain their original placement. No town/seed-specific exception is used; the offset is derived from the source panel's measured foot.

The first native render showed that panel retraction alone leaves a wall-head seam. Rejected that version. A continuous course of existing `suntail.decor.crossbar_2` beams now closes the seam, one native beam per wall bay, with its outer face behind the public wall plane. Before, intermediate and final matched images are saved here. Final stair and landing views were inspected; the open slot is closed and the eave reads as a continuous timber joint.

Pure Village's native roof adapter explicitly removes these inherited Suntail-only anchors and fascia. Its own slope and end-cap seating remains unchanged. Pure facades that still use Suntail roofs correctly retain the Suntail join.

## Validation

- Native triangle test confirms the complete adjusted panel clears public air; the original source placement loses real material against the same volume. Both colour variants are exercised.
- Beam assembly test verifies actual stock asset, contiguous bay count, public-side clearance and overlap across the wall/roof head.
- Pure adapter test verifies its unchanged native seat and absence of the Suntail fascia.
- Roof, dormer and seating suite before the final Pure-specific isolation: **10 tests / 283 assertions pass** (`tight-eave-final-tests.out`). Final isolation checks and holdout results recorded below.
- Full generated-town player/controller walk on the affected 103/grand flight: **both directions pass** (`eave103-walk.json`). No stair geometry or navigation widths were changed by this repair.

## Remaining scope

The larger goal stays active. Three tiny roof wings remain in these four holdouts; broader facade, massif, asset-grammar and town-wide art acceptance are not implied by this repair. The early diagnosis found a flush legacy roof reservation beside the stair; this repair resolves the actual kit panel's small protruding foot without expanding that reservation or weakening clearance.

Final Pure-isolated state: **10 focused tests / 135 assertions pass** (`tight-seat-final.out`). Four towns rebuilt: **0 eave cuts, 0 gable holes, 0 exposed open gables, 0 unsupported roof corners, 0 uncapped towers** in each (`stair-profile-holdouts.json`). Three tiny roof wings remain, with unchanged locations. The seven original eave cuts are resolved.
