# Photo 9 — suspended lawn depth

The preserved current-world source is settlement `1181f74a2f849a6a`, cell
`(20,-87)`, with town frame origin `(481.5,12.08,-2066.5)`, scale 2 and
180-degree yaw. The lawn top is 24.09 m. Actual native substrate deck tops
are 23.762104 m: an empty layer approximately 0.328 m deep. Native rounded
lips dress the perimeter but do not fill the interior.

The exact reconstructed camera intersects a foreground awning in the merged
construction. Preserve that view and its difference; the matched left/right
views expose the lawn and are required for the edge judgment. The original
photograph's full-precision camera cannot be recovered from its rounded pins.

Options considered: lift the wooden deck to the grass, stretch the green lip
downward, or fill the existing layer with a soil bed. Lifting timber would
change the substrate's collision and visible edge; stretching the lip would
distort its native profile. A shallow soil bed fills the missing volume while
retaining the grass datum, authored lips, deck and stair connections.

The first attempt extruded the clipped central grass mesh. Actual per-cell
rays rejected it: eleven lawn cells remained unfilled because native lip
panels, not that central mesh, own their tops. The revised bed starts from the
complete existing lawn collision footprint. Its shared perimeter vertices
inset by 0.28 fabric metres, behind the native lip's flat-top limit. Interior
edges cancel, including cell seams. The closed bed is 0.17 fabric metres deep,
with an 0.004 m cap recess. At production scale this is 0.34 m of soil, its
top 8 mm below grass and its bottom overlapping the actual deck by 20.1 mm.
No new collision is emitted. The main-thread commit creates one shared rough
brown material; the worker payload contains only geometry arrays.

The targeted and related suite passes 15 tests / 5,236 assertions, including
actual native deck contact, watertight boundary censuses, unchanged input
ground, and nondegenerate concave/disconnected beds in four orientations.
Final render judgment and source/collision parity are recorded separately.


The first full-game render was rejected: the inset square soil corner pierced
through the native rounded grass. The corner's actual flat-top mesh is a
quarter-circle tessellated at 22.5 degrees. Its inscribed radius is 0.49039
fabric metres. Convex soil corners now fit inside that polygon at radius 0.49;
concave vertices retain the union inset. A new regression rays every distinct
soil vertex against the actual native lip and central grass triangles. All
three final soil tests pass with 1,851 assertions (7.442 s), including complete
silhouette containment and no soil protruding above grass. Rejected images
and differences remain in `square-corner-rejected-*`.


The corrected soil-only render removed the protrusion but barely changed the
reported thin appearance. Its full six-view differences are retained in
`soil-only-diff`; it was not accepted as the visual repair. The final candidate
adds a shallow timber retaining border around the suspended lawn union. It
spans the deck-to-lawn layer inside the original footprint, remains below the
native lip top and emits no collision. X-facing members own convex corner
squares; perpendicular members stop at their inner faces rather than overlap.
The existing procedural timber material matches the nearby stairs. All 16
related tests / 6,950 assertions pass after this addition (20.968 s, exit 0).


The timber frame with the native rounded lip was also rejected in the actual
render: their overlap left green lobes and cuts along the border. Those views
remain in `rounded-lip-frame-rejected-*`. The next candidate gives suspended
lawns a flat grass surface contained by their timber frame. Ordinary grounded
gardens retain their native lips. Only visual vertices move inward; the public
collision surface stays unchanged. A small member closes concave frame corners.
The new frame corrects the box helper's inward face winding locally, without
changing existing stair geometry. Tests verify outward normals and complete
combined grass/frame top area as well as soil containment and deck contact.
The final related suite passes 16 tests / 7,654 assertions in 24.955 seconds.
Actual render judgment remains pending for this candidate.

Final contained-lawn render accepted after inspecting all six differences and
both clear side views. Actual collision hashes match; see `result.md` and
`verification.json` for numeric evidence and the occluded-camera limitation.
