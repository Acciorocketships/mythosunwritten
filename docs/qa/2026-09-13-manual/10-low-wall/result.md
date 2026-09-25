# Issue 10 — partial facade inside a retaining wall

P27's lower timber/plaster patch was the ordinary facade treatment applied to a single exposed band. The native house wall spans two bands; its lower half was buried while the upper half appeared as an isolated patch in the stone column.

The shared skin classifier now assigns the existing fitted masonry treatment when a side requires a short course. Complete house storeys retain the alternating facade vocabulary. Emission, clearance and corner ownership consume that same classification. There is no coordinate exception, new asset, or overlay.

## Evidence

- P27: seed 2697992464, player `(-192.3,11.1,-951.3)`, crosshair `(-195.4,11.1,-953.9)`. The native owner is `maze-stone/-6/1/4/0`.
- The original rule fails the photo regression and all four orientation controls: two tests, five failed assertions (`red2.txt`). The final focused run passes four tests / 44 assertions, including actual native replacement bounds and complete-storey controls (`final-focused.txt`).
- The replacement is `sfv.fabric.wall.rock.retaining.001`, fitted from world Y 11.08 to 14.080122, rather than the former 6 m timber panel starting at 8.08. Its complete stock closes the owned half-storey. See `nearby-after.json`.
- All 77 generated surface arrays and generated collision boxes remain identical (`payload-comparison.json`). The actual native collision survey retains every result across 356 positions and 502 crossings (`clearance.json`). This comparison preserves the existing offset-only crossings; it does not claim those older crossings are repaired.
- The mandatory native matrix seals 48/48 towns, with 11,868 clear centers and 17,035 clear crossings, no disconnected routes, and the same 24 off-center pillar contacts. The fingerprinted gate passes one test / 95 assertions (`corpus.json`, `gate.txt`).
- The broader nearby run passes 8/10 tests and 108/110 assertions. Both failures reproduce unchanged under the original rule: an old six-versus-five fixture count and a no-longer-present retained face key (`focused-baseline.txt`). No historical expectation was relaxed. No full-suite or performance acceptance is claimed.

## Visual judgment

Three live game pairs and three isolated native pairs use the original overlay through `ReviewCam.solve_cam` and production close-camera obstruction handling. All paired poses are identical, including the ±8-degree controls. The first isolated attempt without obstruction handling was inside a foreground room and was replaced; it is not positive evidence.

The patch becomes a continuous stone face at all six inspected pairs. Surrounding wall, doorway and floor remain stable in the differences. The small preexisting light sliver at the neighboring wall-floor junction appears in both native versions; it is not introduced by this substitution. Live views do not expose a new gap. See `pairs.jpg`, `differences.jpg`, and `native-reproduction/` for the paired detail views, with full frames in `before/` and `after/`.
