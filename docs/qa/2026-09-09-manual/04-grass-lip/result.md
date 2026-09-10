# Photo 2: narrow grass lip

Accepted for the photographed site. The native lips were present, but their flat
backs crossed the rounded nose on the opposite side of a one-cell-wide lawn.
A full lip reaches 0.75 m from the local cell center behind itself; the opposing
rounded nose reaches only 0.625 m. At the town’s 2× scale this exposed a 25 cm shelf.

Considered adding more edge pieces or altering the ground sheet. Neither addresses
the overlapping native backs. The implemented ownership splits opposing native
pieces at the cell center, including paired outer corners and the inner corner.
Actual source triangles retain their positions, normals, interpolated UVs and
native material. Main-thread preparation exports resource-free arrays for workers;
world placement applies the same biome tint as the original complete instance.
The ground field and collision do not change.

All six matched before/after views and pixel differences were inspected. The shelf
is gone; the rounded perimeter, lawn top and nearby walls remain intact. The exact
view has mean absolute RGB difference 0.21594/255, with 0.14496% of full-frame pixels
changing by more than 20. The other localized change is the animated spirit orb.
The paired camera JSON is identical; source coordinates are rounded and cannot
recover the original full-precision camera or animation time.

The native-asset regression covers the straight strip, narrow cap and concave
corner in four orientations, verifies that the original back protrudes, and checks
that the corrected surface retains the nose and closed interior. Texture/tint,
collision metadata, triangle subtraction and terrain checks total 29 passing tests
and 12,984 assertions (7.945 s, exit 0). The photographed town has identical results
across all 124 public cells and 179 crossings: none blocked, four crossings require
the same lateral offset as before. This is targeted acceptance, not a globally
green baseline.

Evidence: `verification.json`, `tests.txt`, `probe-before.json`, paired clearance
JSON, source hashes, and `diff/metrics.json`. The local before/after PNG sequences
and pixel-difference images are ignored QA artifacts.
