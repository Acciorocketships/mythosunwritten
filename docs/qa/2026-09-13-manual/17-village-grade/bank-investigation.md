# P24 bank remains open

The fresh P24 world and the native terrain replay both reproduce the stone fins.
This is separate from the accepted P11 approach profile in `approach-result.md`.

Camera rays through native pixels (480,222) and (553,319) hit graded rock at
(-283.1662,17.84398,443.322) and (-279.9639,14.07237,443.2355), respectively,
without intersecting a ground triangle. Vertical probes above those points do
intersect ground: the independently graded owners retain a narrow vertical
cliff between their tops. A vertical-height-only test would miss this defect.
`visual-probe-full.txt` records these rays. Curvature of the native rock's
triangles contributes only about 3.2 cm; it does not explain the larger gap.

`seam-red.txt` reproduces a 1.666 m disagreement between the two owners of the
old z=444 cliff. A transfinite shoulder candidate made that boundary continuous
while narrowing its influence to the natural cliff outside the construction.
It passed the seam and existing climb tests (`seam-candidate.txt`), but its
matched native view developed a sharper fold at the far end and retained small
rock artifacts. It is rejected. `P24-native-seams` and the three
`rejected_shoulder_*.txt` files preserve the experiment. The production surface,
mesher and cliff dressing were restored from their exact pre-experiment copies;
the accepted distance-based collar remains.

The next design must treat the bank's terrain topology, complete mesh and
physical support together. Do not accept the pending regression alone, hide the
rock mesh, tessellate blindly, or claim P24 is repaired by the P11 slope change.
