# P03 mountain cut-out repair

**Final reviewed build: `final/04`, all nine chunks rebuilt.** [Owner annotation](owner-annotated.png) · [enumerated issues](issues.md).

## What caused it

The preceding pass's water-channel protection introduced the large cut-outs. Its distance-ridge receiver treated narrow wet pockets beside the massif as corridors that had to cut through the bank. Exact-pixel collision rays found 74–80° faces; the actual input profiles dropped as much as 5.51 m in roughly one horizontal metre. Shading-only changes did not fix this geometry and were rejected.

The small upper-right notch had a separate cause: bedrock carving lowered its surface 1.25 m below the continuous hillside. A third, independent shading defect made some flat plateau areas look recessed because the surface-net normal calculation differentiated out-of-range solid/air sentinels as if they were distances.

## Final changes

- A receiver cut requires an **8 m wet core radius**. Narrow wet pockets are absorbed by the rounded bank; broader water corridors retain the submerged receiver. The opposing-bank clearance regression still passes. This intentionally changes which small wet pockets remain exposed beneath a tall bank; it is not a claim that every water route across the world was surveyed.
- Rock carving recesses at most **0.25 m** into the hillside. Outward rock relief remains bounded at 1.25 m. Fin smoothing respects the same inward bound.
- Bedrock shading normals use derivatives of the complete height envelope, cached per horizontal node, independent of the sparse meshing band's vertical limits.
- **The original moss colours and blend are retained.** The brighter material candidate was reverted after the geometry fix. The original surface-net mesher and rock material remain.

## Programmatic evidence

**34 tests / 613 assertions pass:** [final test log](tests.txt). This includes actual-site cut-out and upper-notch regressions, continuous normals, opposing-bank clearance, previous crown/water/grass-support checks and the original bedrock/restoration suite.

- [Large cut-out red regression](pocket-red.txt): nine actual-site sample failures before the repair.
- [Upper-right notch red regression](upper-red.txt): all four sites fail before, at 0.64–1.25 m recess.
- [Normal red regression](normal-red.txt): flat native plateau normal-vector error 1.567 before repair; below 0.01 after.
- The old colour test required the rejected deep benches to exist. It now tests the material's hillside-grade contract on an explicit flat-rock fixture. The original restoration test still pins vertex positions and stone exposure; corrected normals have their own native regression.

[Geometry identity](geometry-identity.json) verified that the NORMAL-ONLY diagnostic candidate preserved 97,660 triangles exactly. **That is not a final geometry claim:** the water-pocket and rock-recess repairs intentionally change both the rendered and collision surfaces.

## Native visual provenance

Seed 2697992464, nine chunks, production grass and collision. Front `(508,50,934)` → `(497,40,955)`, side `(516,49,963)` → `(497,40,955)`, overhead `(490,65,950)` → `(500,37,958)`, FOV 60.

- `00`: fresh before images reproducing the owner's annotation.
- `01`, `final/00`: material/normal candidates, rejected as insufficient after the exact-pixel ray check.
- `final/02`: water-pocket geometry correction with brighter material; `final/03` restores the original material.
- `final/04`: all nine chunks rebuilt with both geometry repairs, corrected normals and original material.

The detached neutral/lawn controls omit the rest of the world and diagnose individual causes only. Final before/after comparisons use the native world. Pixel differences show changed rendering; grass animation also contributes small differences, so they are not automatic quality scores.


## Final native checks and visual review

- Inspected [front before/after and pixel difference](front-comparison.jpg), [side](side-comparison.jpg), and [overhead](above-comparison.jpg). The large scalloped bowls and upper-right recessed shelf are filled into the hillside. Remaining rock relief stays attached; the original palette is retained.
- [Circled-pixel collision rays](final/circled-rays.json) now meet continuous surfaces. The formerly 74–80° large faces read approximately 26–41° at the corresponding image locations. The upper-right sample changes from 45.9° to 32.4°.
- [Six real-player walks](final/pocket-walks.json), uphill/downhill across all three large repaired regions: all pass and finish on floor.
- [152 native surface samples](final/surface-audit-final.json): 129 exact exposed contacts, 23 covered contacts, zero missing contacts. [185 grass roots](final/grass-after.json): zero misses.
- [1,449 shared height samples](final/seam-after.json) differ by at most 2.2e-14 m; [208 shared mesh vertices](final/normal-seam-native.json) have identical normals.

The first diagnostic probe had a parse error and the review process was restarted; the harness now logs a bad probe without terminating its watch loop. An intermediate surface audit had insufficient samples for its minimum coverage assertion; the final audit doubles the sample density and passes. These are recorded in the logs, not counted as passing checks.
