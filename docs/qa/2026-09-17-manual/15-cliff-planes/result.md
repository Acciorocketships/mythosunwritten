# Native-wall cut depth: scoped repair, cliff art remains open

The selected change prevents deep erosion cuts in an exposed added shoulder from re-entering the native cliff. It repairs five reproduced intersections at P20. It does **not** resolve the owner's broader complaint about soft faces, the quality of the native transition, or the reference's irregular rock composition.

## Selected change

`CliffRockCrags._body_depth` retains the native attachment beneath deep erosion. Ordinary cuts remain unchanged until they consume 65% of the available depth; deeper cuts approach the remaining backing smoothly instead of crossing it or hitting a flat clamp. The existing attachment plane and projection scale determine that budget. Mass placement, fracture distribution, material, and corner adapter are unchanged in this pass. The prior full-height and wider-foot work remains in place.

The original photo anchor is `(-480, 32, -253.5)`, seed `2697992464`. The new regression examines actual generated vertices against actual native-wall depth, rather than testing the budget formula.

| Local XY | Original clearance (m) | Selected clearance (m) |
|---|---:|---:|
| 3.25, 6.60 | -0.071847 | 0.020353 |
| 3.25, 6.40 | -0.005775 | 0.040825 |
| 3.50, 6.60 | -0.359566 | 0.005234 |
| 3.50, 6.40 | -0.136433 | 0.015467 |
| 3.75, 6.60 | -0.187959 | 0.011141 |

[Original red run](cut-red.log): five clearance failures, five vertex-existence passes. [Candidate run](cut-candidate.log): all ten assertions pass. The production [focused run](focused-tests.log) passes **42 tests / 1,042 assertions** across fourteen files in 258.694 seconds, including native attachment, closed geometry, corner joints, turf, full-height coverage, lower projection, and composition controls.

The earlier scale regression compared every live short-wall vertex to its historical pre-scale version, thereby forbidding unrelated later repairs. That exact comparison now uses the frozen selected scale fixture. A separate live test preserves short-wall mass and fracture composition at four heights and three horizontal locations. No geometric acceptance threshold was relaxed.

## Visual judgment

All seventeen selected frozen views in [limited](limited/) were inspected: P05/P12/P17/P20 reported poses and both nearby offsets, plus five supplemental contextual views. Reported poses retain the existing reconstruction from the owner's screenshot overlays. They are not exact unrecorded original camera transforms.

Four additional close views compare the actual cut region: [front before](detail-before/P20_cut_front.png), [front after](detail-after/P20_cut_front.png), [oblique before](detail-before/P20_cut_oblique.png), [oblique after](detail-after/P20_cut_oblique.png). These show a subtle local cleanup of intersecting relief. Recomputed crevice planting also changes a fern; that is not evidence of improved stone shape.

Fresh production generation completed with exit code zero. All three fresh P20 views were inspected: [center](fresh/P20_0.png), [left](fresh/P20_-8.png), [right](fresh/P20_8.png). The changed geometry survives the real generation pipeline. Broad faces still look soft; some turf edges remain visually stripe-like. P12's central mass, P17's angular cleft borders, and repeated native upper relief also remain unsatisfactory. This result does not accept overall C01–C04 art.

Fresh startup was **421.173 seconds**, under concurrent test/study work; it is not a controlled performance comparison. [Fresh log](fresh.log) includes the snapshot harness's `global_shader_parameter_get_list` outside-editor ERROR diagnostic, after which the world and all three captures save successfully. No actual player traversal was conducted, and no full-suite, general streaming, hydraulic, or performance acceptance is claimed.

## Rejected studies

Fixtures are retained in `tests/fixtures/september17/cliff-planes/` for reproducibility. Representative views, not every rejected capture, were inspected.

- `candidate`: independently tilted broad surface cells. Broad faces still read as soft and the visual gain was insufficient.
- `erosion`: asymmetric deeper cuts and earlier independent detail. Long horizontal cuts remained too prominent.
- `erosion-normals`: altered normal fans and a narrower straight-face native blend. Angular shading concerns remained; the corner blend was not narrowed by that experiment.
- `bounded-erosion`: erosion study with bounded negative displacement. The unwanted overall shape remained.
- `bounded`: bounded all negative displacement, unnecessarily softening ordinary cuts. The selected `limited` version applies the budget only near cut-through.
- `identity` and `blend-map`: diagnostic shaders confirm that the broad soft face belongs to the added rock and is already largely outside the thin native blend. Increasing surface bump alone does not repair its shape.

The experimental `detail_probe`'s cut-coverage threshold already passes on baseline. Its coverage result is not a red regression or proof of artistic success; only the native-wall intersection failure led to the selected production repair.

Next art work must improve coherent face structure and irregular projection without returning to bulbous pods, continuous rows, repeated native tiles, or triangular facets. The [original issue register](../../2026-09-16-manual/issues.md) remains active.
