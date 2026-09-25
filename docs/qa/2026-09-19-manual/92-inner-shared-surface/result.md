# Continuing adjoining rock through inner corners — pass 92

Matching-height concave junctions now continue their two actual wall formations into the turn. Previously both wall ends tapered to native backing, while a third independently seeded corner formation supplied another set of shelves. Their intersections produced the pointed turf and competing shelf tips in the close review.

Each admitted end extends three metres behind the adjoining wall, preserving its original world-coordinate rock and ledge field. Both extensions are staged together. The separate inner formation withdraws only when both complete wall candidates pass the existing ground-grade, public-clearance and water checks. The original canonical anchors and IDs remain the chunk owners even though mesh centres move. Unequal-height, incomplete and rejected pairs retain pass-89 rooted inner dressing. Outer corner construction is unchanged.

The new scene-free `CliffInnerConnections.gd` operates before owner selection, reservations, grass and physical triangles are compiled. Its inputs and outputs remain detached values. The extension's ordinary wall replay recipe records its new width and the connected corner lineage; no new renderer or runtime scene is introduced.

## Native judgment

The selected photographed join is at **(-445.5, 32, -301.5)** in seed **2697992464**. Two current wall formations extend, and one competing inner formation withdraws. The other 35 nearby formations are unchanged. Front and elevated views show broader existing treads continuing into the junction without the remeshed fins or the extra pointed corner tips. The gray faces keep their current material and world-coordinate variation. Broad plain faces, some inherited thin treads and unequal-height joins still need work; this is not overall cliff-art acceptance.

[Previous elevated join](../89-inner-attachment/final/inner_above.png) · [Selected elevated join](final/inner_above.png) · [Selected front](final/inner_front.png) · [Outer context](final/outer_oblique.png).

These replay the pass-88 fresh world with current production geometry at the same saved native poses. No full-world regeneration or player traversal is claimed. The close poses are supplementary junction diagnostics, not replacements for the older F3 reported cameras.

## Verification

- **22 tests / 184 assertions pass** across connection, corner geometry, native attachment and snapshot replay tests. This includes unchanged canonical ownership, atomic whole-pair rejection by public reservations or a wet-admission callback, dictionary-order independence, detached thread parity, unmatched-height preservation, closed/nondegenerate photo shells and complete turf membership.
- Whole-region and four separate chunk queries yield identical rock IDs, transforms, anchors and triangle arrays, without duplicate ownership. Sampled roots in the generated synthetic concave region stay buried.
- A frozen pre-change geometric control reproduces **seven failed bearings among 18 probes** within the last 1.5 m of the photographed wall ends. All 18 meet the same 0.5 m rock-depth bound after connection. This is a backing-continuity check on the actual source triangles, not a proxy for all art or traversal requirements. The baseline control was added after the art prototypes; it is not claimed as the first action of this pass.
- **440 native physics contacts** on the changed wall triangles hit their intended bodies. Maximum discrepancy is **0.0000315 m**. All **412 unique foot samples** stay buried against native ground in the actual saved world, with no missing ground.
- The first regression run retained an old assertion requiring a separate inner mesh and therefore failed two assertions after that mesh was deliberately replaced. The test now follows both valid inner constructions, retaining its ownership, grounding, duplicate and collision checks. The corrected full run is green.

[Before bearing control](before-continuity.json) · [After bearing control](after-continuity.json) · [Native physics and grounding](physics.json) · [Production integration delta](dressing.patch).

## Rejected studies and limits

The initial shared-depth grid remeshed all three inner joins at regular height intervals. It produced stair-step turf and many unwanted green facets. The adaptive version aligned rows to source tread boundaries and reduced that speckling, but still produced thin fins and slits. Neither is in production. Their sources and captures remain under `initial` and `adaptive`; the latter's unused `missing` statistic is not a validated coverage measurement.

The selected extension study was then implemented with production footprint admission and ownership preservation. The final native capture precedes only the addition of diagnostic `inner_connections` recipe metadata; geometry is unchanged by that annotation, which is covered by the final tests.

This implementation regenerates eligible wall pairs after initial planning. Generation cost has not been accepted or optimized. It intentionally leaves unequal-height connections on their prior treatment and does not establish a boolean single-shell union between overlapping walls. Water, town, streaming and other original-register work remains open.
