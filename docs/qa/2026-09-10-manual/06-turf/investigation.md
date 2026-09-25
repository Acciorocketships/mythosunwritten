# Turf edges and hollow platforms

The source camera overlays are rounded player/crosshair coordinates. The four
photo reconstructions (2, 7, 12, 17) use the same camera transforms on both sides.
Photos 1 and 3 additionally inspect the already framed suspended lawn.

## Alternatives and falsification

1. Add shallow soil beneath every garden lacking a retained lower cell. Rejected
   as initially specified: the four chosen edge points already hit both the top
   and bottom of their actual native lip, about 0.25–0.30 m apart. A test requiring
   a particular `soil_bed` record would incorrectly reject those real solid
   meshes. The rejected test and actual triangle surveys are retained here.
2. Sample the complete native payload, including interior cells. This found the
   open interior at local cells `(1,3,-3)` and `(2,3,-3)` in the photo 17 town.
   Their turf is a single upward-facing sheet. The retained garden's lower cell
   is open, and the final shell has incorrectly erased its exposed DOWN face.
   Two native full-town underside views look through that hole into the sky.
3. Preserve that lower boundary and use the existing fitted native timber
   soffit. Selected. The deleted suppression dates from the former rotated rock
   cap; the current builder already uses exact one/two-cell timber boards.
   Ordinary buried boundaries remain absent from the exposed-face transaction.

The new regression first fails four assertions: both exposed lower faces are
missing and neither point hits actual native underside triangles. After removing
that obsolete suppression, all ten assertions pass. The original turf mesh and
native lip geometry are unchanged. The already suspended plaza retains its
existing closed soil, timber frame and deck. The complete 32-test focused run
passes 5,072 assertions and exits cleanly.

The two supplemental underside comparisons use identical explicit local camera
poses under the actual frozen town, with all native construction committed.
They are geometry diagnostics with neutral lighting, not replacements for the
photo reconstructions. `garden_under` changes 65.08% of pixels above threshold
20/255; `garden_side` changes 32.35%. Inspection of both differences shows timber
closing the formerly transparent underside. Public clearance remains identical
to issue 5 across 112 cells and 164 crossings.

Full-game photo comparison review is still pending. The earlier prefab fix
already repairs the mixed grass/wood footprint and exposed base at photos 2/17;
that evidence is retained under `03-prefab` and is not credited a second time to
this underside repair.

## Rejected first full-game candidate

The final photo 2 comparison exposed an unwanted timber strip beneath its low
garden. This falsified the first candidate despite its passing focused tests:
it had also restored DOWN faces at local base band zero, where natural terrain
owns the lower interface. The second regression reproduced 18 such wrongly
exposed boundaries in the frozen photo 2 town. The candidate now preserves
exposed garden undersides only above base band zero. Ground-level gardens retain
their original buried interface. `after/` is the rejected first candidate;
`final/` is the new full-game verification run. No soil-sheet workaround remains.
