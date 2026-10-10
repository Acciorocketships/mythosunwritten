# Inhabited square frontages and large-bed canopy — October 5

Accepted a bounded improvement to internal town squares: retain the surrounding house sites that justified reserving the square, and use real leafy tree fitting for large planted islands.

## The lost-frontage defect

The broad-court rule checked for three buildable sides, but only reserved the deck itself. Later landmark bodies and measured clearance envelopes could consume those house sites. In 31/large the finished 3×3 raised deck had immediate occupied fronts on only two sides. The new finished-building regression failed at 2 versus 3 before implementation.

`WarrenPlotReservations` now carries eligible neighboring room columns as a temporary mask through landmark and optional-deck placement. It uses actual support, occupied space, tier, huddle and edge-height rules. This mask is not a plot: normal house partitioning can subsequently occupy it and use the connected court's doorway addresses. No house is forced through a failed room/clearance proof.

An initial version also changed preliminary perimeter-route planning and lost the square entirely; its three failed tests are retained. The corrected version explicitly leaves the preliminary reservation preview unchanged. Only a committed court protects house sites during final allocation. The candidate preview exception is an explicit argument from the throwaway preview caller, not a seed or coordinate special case.

## Finished result and trade-off

31/large retains exactly the same nine macro columns and band-two datum. East occupied frontage remains 4/6 fine cells, north 6/6, and west rises from 0/6 to 4/6. The south side connects to circulation. These are finished house rooms at the court walking level, not an inference from raw massif height. Native player-height views show doors and windowed fronts surrounding the planted deck.

One lower landmark no longer fits (three authored/native asset plots become two); ordinary room buildings take that frontage instead. The native arcade remains. Inhabited masses rise 24→27, and one nearby route gains an overhead room. This trade-off serves the owner's requested inhabited square; it is not a claim that every silhouette is already satisfactory.

## Large planting islands

Native review exposed a second defect: the wide centerpiece list still selected the old bare `lpfv.tree.05`, bypassing the leafy canopy grammar used by smaller and notched beds. Planted islands now route that tree choice through `TownCourtTrees.fit_island`, using measured native crown/root profiles, roof obstacles and public headroom. Wells and stalls remain seeded alternatives; if no whole canopy fits, the other legal furniture choices are tried. Non-planted legacy greens retain their existing contract.

A new 12-position regression failed with three bare trees and no living trees, then passed. The revised native court shows a leafy tree with ordinary seat/underplant dressing, entirely in the owned planting island. The deck loop and door approaches remain clear. Review-harness lawn is a plain backing; these images do not verify streamed-world grass shading.

## Verification

- Nine focused tests / 118 assertions pass across broad courts, court house addresses and irregular/large planting islands. Both new behavioral regressions were observed failing before their repairs.
- Ten-town structural comparison: 31/large and 8,9,13,43,53,63,83,103,301/grand. Covered quarters increase 476→480; all previous covered samples retain exactly their previous ceiling heights. The four new quarters are at route (1,1,-3), with a three-band ceiling. The other nine towns retain their covered samples/counts. All ten have zero floating masses and public-air intrusions; corner-turret counts are unchanged. This structural comparison preceded the finish-only canopy change.
- Final actual-player runs include both changes: court approach and loop 2/2, court-facing house approaches 10/10, skywalks/source bridges/underpasses 14/14. Total 26/26, each route in both directions.
- Four final native court directions and the intermediate bare-tree views inspected. Automatic court cameras moved with changed door-floor choices, so fixed front and elevated cameras are captured separately for comparison; temporary source swaps are restored byte-for-byte.

## Remaining work

This repairs an admitted broad square; it does not yet increase broad-square supply throughout the corpus. Smaller/exposed courts, remaining tall flat fronts and awkward roof joins still need joint architectural work. The full prefab-generalizing grammar, production-wide visual/performance acceptance and overall October 1 redesign remain open.

Fixed front views confirm the new inhabited edge and tree planting. The elevated pair has substantial foreground-roof occlusion and is retained as context, not evidence for unseen court corners. It also exposes the unresolved large roof planes; this change is not roofline acceptance. All rendering, traversal and survey jobs completed; source swaps restored and targeted whitespace checks pass.
