# Turf edges and exposed undersides

Final implementation verified at the reported sites. Gardens above the base
terrain retain their exposed lower shell, closed with the existing fitted native
timber boards. Ground-level gardens keep their buried interface. The turf,
rounded native lips, planted public lawn, and walking surfaces retain their
existing geometry. Photo 2/17 footprint ownership was repaired in issue 3.

The first broad restoration was rejected after photo 2 exposed a new low timber
strip. The final lower-boundary rule removes that regression. A shallow soil
workaround was also rejected after actual native triangles disproved its test's
assumption. See [investigation.md](investigation.md).

All 36 before/final game pairs and amplified pixel differences were inspected:
photos 2, 7, 12 and 17 plus the suspended lawn in photos 1 and 3, each with the
reconstructed photo camera, two nearby angles, two jitter samples and the
production camera solver. All six camera records match. The final photo 2
comparison removes the rejected strip. Photo 17 exposes the new closure below
the garden; the additional low views directly show the previously open interior
closed. Photos 1/3/7/12 preserve their existing lawn edges and nearby details.
Small unrelated differences come from the avatar, moving orbs and wind/shadows.

| Photo | Full-frame mean RGB difference / 255 | Pixels changing >20/255 |
| --- | --- | --- |
| 01 | 0.102921 | 0.0082% |
| 02 | 0.023857 | 0.0276% |
| 03 | 0.088438 | 0.0108% |
| 07 | 0.159141 | 0.0097% |
| 12 | 0.117272 | 0.0056% |
| 17 | 0.292091 | 0.1220% |

The 74-cell native depth survey found two exposed interior samples lacking a
lower closure; other single-sheet samples have retained terrain beneath. The
16-cell suspended lawn already has closed soil. The two new regressions verify
actual underside triangles at the open garden and suppress 18 ground-level
interfaces. All 42 focused tests pass with 5,652 assertions and a clean exit.
The final physical survey is identical to the previous accepted survey across
112 walk cells and 164 crossings.

Evidence: `final/`, `final-diff/`, `underside-before/`, `underside-after/`,
`underside-diff/`, `native-depth-survey.json`, `final-tests.txt`,
`clearance-final.json`. `after/` is a rejected candidate, not the final result.
The camera pins are rounded reconstructions, not recovered full-precision
original poses. This accepts the inspected turf/underside fixes, not universal
city or terrain health. Roof, railing, skywalk and water issues remain separate.
