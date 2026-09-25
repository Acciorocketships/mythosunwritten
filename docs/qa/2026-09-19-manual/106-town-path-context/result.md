# P02 town path: retained garden reservation

The external road now passes around the photographed raised garden instead of through its stone base. The final retained ground transaction joins the town's occupied bounds before routing. Houses, garden, props, native public floors, collision boxes and sealed town grade are preserved.

## Evidence

- Seed 2697992464, town frame (-2,1), town cell (-43,45), original P02 camera plus ±8-degree controls.
- Original route: (-1056,1056) → (-1056,1064) → (-1032,1064) → (-1032,1082). Final route: (-1056,1044) → (-1056,1052) → (-1032,1052) → (-1032,1082). The actual town gate remains unchanged.
- Red-first tests miss all 16 photographed garden corners and 24 retained columns before the fix. The final focused run passes 9 tests / 409 assertions, including payload, collision and sealed-grade preservation plus existing rotated road handoff controls.
- The actual player fails both directions on the original frozen world and completes both directions on the freshly generated final world. See `control-walk/physics.json` and `after-walk/physics.json`.
- Supplemental player-capsule surveys find 12 blocked samples out of 396 before, and zero out of 468 after. These surveys use a fixed 9.05 m foot height; the actual walking runs additionally prove the lower outside ground and transitions. They do not establish all off-centre traversals.
- All three fresh before/after source views are inspected. The complete-route overhead, gate and garden-side views are supplemental fixed diagnostic cameras; they are not replacements for the original camera. Final forward/reverse walking views are inspected.
- The old retaining-block board defect remains absent in these fresh surrounding-world views; the garden keeps native stone below and its furnishings above. This closes the pending P02 context review for T05, not every possible town timber junction.

## Judgment and remaining scope

T04's photographed obstruction is repaired and physically traversable. The garden and house remain visually intact. T05's previously repaired boards are verified in fresh world context. T06 is **still open**: the complete-route overhead reveals a square projection where the incoming world road meets the rounded town approach. This is a separate surface-ownership defect and is being investigated in pass 107. The town approach is not represented as fully finished while that defect remains.

The broader original register, cliff art, other town locations, all-town road clearance and global performance remain open. No full-suite acceptance is claimed. An additional 12-test related run passed 11 tests / 477 of 478 assertions: the historical `test_village_reported_ground` fixture dereferences `record.outskirts.placements`, while unchanged `VillagePlan.gd` sets outskirts to null for unified construction. This stale fixture was not weakened or silently counted as passing.

Fresh startup was 224.309 s before and 202.754 s after; these are not controlled performance comparisons. Frozen loads retain two known stale material UID warnings with successful text fallback. Snapshot capture retains the known editor-only shader-parameter warning; headless tools may emit a macOS certificate lookup warning despite no network operation. Logs are retained.
