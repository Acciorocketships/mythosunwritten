# Exposed rock geometry — pass 79

The selected production change adds more localized physical rock-face variation without replacing the ledge construction. The Nature-derived bumps are closer together, have more varied short dimensions and slightly stronger depth, and no longer grow into very large smooth patches simply because a wall is taller. Existing large shoulders and new bumps share a 1.3 m allowance. A broader transition near finished treads prevents added faces from producing a second exposed lip beside the turf.

These are changes to the closed mesh and its collision vertices. Materials, crack overlays, native crown, original ledge geometry, and triangle topology are unchanged. This is incremental improvement in exposed lower/middle faces, not acceptance of the complete requested cliff composition.

## Evidence

- The new photo regression uses anchor 20, seed 2697992464, and the saved pass-77 mesh. It reproduces red with zero changed vertices on the baseline. Final production changes 982 vertices by more than 0.08 m across 91 columns; 318 move outward. All 1,230 original turf points remain and the crown delta is zero.
- The existing overlap-depth guard rejected the unbounded candidate at 1.972800 m; final is 1.302800 m. The new allowance applies to combined overlapping shoulders, not a world-coordinate exception.
- The ledge regression rejected stronger variants at 43/57 and 47/57 turf probes. Final retains 57/57, with 31 closed shells, no degenerate triangles, and no adjacent narrow ledge channels. Both 8 m and 32 m ledge-area controls retain their original areas (69.137629 / 48.922539 square metres).
- Final focused/integration run: **31 tests / 101 assertions pass** (`cliff79-final-tests.log`), including 347 actual grass-worker roots with no escaped or buried roots, chunk ownership, admission and 16/32/64 m corner checks.
- Actual Godot collision survey: 266 changed-face contacts pass, out of 887 total sampled contacts. The same previously documented baseline miss remains at `(76.16666, 0.398533, 7.696733)`. Maximum contact error is 0.000010874 m. This is a changed-surface check, not a claim that every total probe passes.
- Seventeen final native Metal frozen-world captures and a 32 m tall study were produced. Reported F3 poses use the existing ReviewCam harness; supplemental oblique/side views are labeled accordingly. Final P20 oblique, P20 reported, P17 front, and tall oblique were inspected. The stronger middle/lower variation is visible, while broad smooth upper faces and some angular details remain. The other thirteen captures are retained for review, not individually accepted.

## Rejected studies

`coupled.gd` connected ledges directly to Nature-derived formations but lost useful shelf area and produced large plain slab-like masses. It failed five of eleven tests, including upper projection and both ledge-area controls. It is not selected.

`sampled.gd` tried refining long riser triangles. The ordinary photo already passed the sampling diagnostic, and refinement did not terminate promptly on protected long boundaries; both processes were stopped. This experimental source is not production and must not be used as a successful mesh repair.

The initial stronger Nature relief formed overly sharp shelf-adjacent bumps. A rear-of-ledge projection limit did not fix the complete cap regression. Broader tread transitions repaired it. The broad-plane alternative stayed too smooth in the game view. None of those intermediate artifacts serves as final visual evidence.

## Art limits and scope

Final ordinary cliffs have more localized body variation, while pointed turf and the existing curved shelves remain intact. Tall upper walls still have broad smooth regions and an inherited upright composition. Some edges still read angularly; the complete cliff art direction is open. The selected change does not restore crack overlays, change material texturing, or claim that all earlier art concerns are fixed.

The captures replay a frozen world. No fresh-world traversal or controlled generation/frame-time benchmark was performed. The original water, village, streaming and biome issue register remains open.

[Final game view](final-world/P20_oblique.png) · [Tall study](final-tall/oblique.png) · [Exact production delta](production.patch)
