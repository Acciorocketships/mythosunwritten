# Issue 18 — arches belong to real tunnel mouths

Accepted after matched renders, pixel inspection and physical checks.
Starting source is the accepted issue-17 state,
retained at `/private/tmp/september9-arches-baseline`.

## Options and rejected render

The road generator placed a 21.1 m wide roofed gateway several road cells away
from each settlement. Moving that complete object to a narrow warren entrance
would require different streets, footings and upper buildings. The smaller
native timber entrance frame is suitable for a passage instead.

The first render placed half-sized entrance frames on every exterior portal.
It was rejected: an open street is not a tunnel, and the raised flight cannot
support the frame's wider feet. Its images and judgment remain in
`first-candidate/`. The accepted candidate selects the existing transition
from open public air into a complete three-band bore, bounded by two solid
jamb columns. Both jambs need real lower bearings or their declared ground
base. Missing walls, ceiling, bearings, or an open approach cannot produce a
frame. There is no town deletion, relocation, placement retry, or new route.

## Construction

`sfv.fabric.tunnel_arch.001` bakes the existing entrance frame at its native
scale into a 3.871 × 4.195 × 0.251 m local module. Its 540 triangles retain the
original form and texture; matching native mesh collision covers posts,
header and braces. No enclosing solid box blocks the aperture. The new asset
uses the existing bake pipeline and ordinary environment commit queues.

The source's two walking cells center the opening. A 10 cm inset joins the
native posts to the existing masonry returns. The frame remains below the
4.5 m bore ceiling, and its physical aperture clears the two walking lanes.
The placement belongs to the fabric plan and construction signature. It is
prepared through the normal declared asset list.

The frozen offset town gains one frame at local `(-0.65, 0, 0.75)`. The other
two photographed towns lack this complete supported tunnel-mouth contract,
so their open stairs and streets receive no fake tunnel frames. Oversized
roadside village gateways are removed. Separate biome-transition markers
retain their existing ownership and spacing.

## Evidence

- The frozen-mouth test failed before (0 frames instead of 1). Three revised
  road tests failed before (4/1/3 detached gates instead of zero).
- Ten targeted tests pass with 55 assertions, including four orientations,
  missing-wall/ceiling/bearing negatives, native collision and body clearance,
  and biome-marker regressions. GPU-compressed visual vertices are compared
  geometrically with the original collision vertices, not by array order.
- All 100 walk cells and 140 crossings retain their previous physical clearance.
- Five fixed native-town before/after pairs and their pixel differences were
  inspected. Cameras are identical. Whole-image mean absolute RGB differences
  are 2.556, 1.529, 3.604, 3.246 and 2.671 for front, inside, left, overview and
  right. Changes follow the timber frame and local shading; nearby doors and
  masonry remain intact. The gallery deliberately omits natural ground.
- The streamed game supplies the missing ground evidence: six traversals pass
  in both directions at lateral offsets -1.5, 0 and +1.5 m. All 294 recorded
  physics ticks remain grounded. Five close game views and the six reconstructed
  photo-12 views are captured separately from the isolated gallery.

The final streamed comparison keeps the player fixed at photo 12 while its
complete streaming footprint loads. All eleven before/after pairs and amplified
differences were inspected: five close tunnel views and six photo-12 views.
The five close-camera transforms, photo reconstruction, player position and town
transform match. The new posts join the existing masonry, the header frames
the covered passage, and the ground remains continuous. Photo 12 retains the
previously repaired bay supports and neighboring architecture.

[Front comparison](game-diff/tunnel_front_comparison.png),
[inside comparison](game-diff/tunnel_inside_comparison.png),
[photo 12 comparison](game-diff/12_offset_room_exact_comparison.png).
Mean absolute RGB changes are 2.560 front, 2.006 inside, 3.689 left,
3.340 overview and 2.714 right. Photo 12's exact view changes by 0.251,
with 0.275% of pixels differing by more than 20 levels. Animated orbs and
grass contribute small incidental differences.

The inside view also loses a background house from that line of sight. This
is accounted for in the construction census: both versions have nine outskirts
houses, with four lots changed and five identical. Removing the old road gates
also removes their conservative ground reservations. Those rectangles feed
`VillageOutskirtsConstruction` before deterministic frontage allocation;
the settlement seed is unchanged. House 06 moves from x=284.3551 to
x=272.8573 at z=-1199.9, explaining the visible background change. The
complete before/after asset and transform census is in `verification.json`.
Six frontage regressions pass with 5,266 assertions. No invisible gate
reservation is retained just to freeze the old lot arrangement.

The earlier captures taken after walking are retained under
`game-*-moving-footprint` but superseded for visual judgment by the stable
captures. Their six successful walking traces remain the motion evidence.

The final aggregate run passes all 95 tests with 78,973 assertions across 33
scripts. This includes all September 9 regression scripts, path features and
the atmosphere director. The additional frontage run also passes. These are
focused acceptance checks; the separately documented full-suite baseline
failures are not reported as resolved.
