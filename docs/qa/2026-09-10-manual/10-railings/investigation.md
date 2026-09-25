# Railing surfaces — in progress

Photo 12's post top and lower cut member trace to the generated mesh
`public-transition/volume.transition.05.mesh`. The solid box faces use an inward
corner order. Their normals inherit that inward cross product, and applying
the floor quad's reversed fan makes the render fronts face inward too. This
renders an open-looking shell and shades its back surfaces inconsistently.
The regression fails all 144 face-normal/front-orientation checks across
vertical, sloping and horizontal members in four orientations.

Alternatives considered: change material culling, replace the complete guard
with native rails, or correct its face orientation. Double-sided rendering
would retain incorrect lighting and overlapping inside faces. Replacing the
sloped guard would also change established wall sockets. The candidate will
correct winding and normals while preserving the precise vertices, UVs,
collision and reserved span.

Photo 1's broad circled fascia traces to native `sfv.fabric.floor.l.001`
substrate plus the lawn border, not the railing beams. Its soil/underside
closure was handled in issue 6. This pass also checks the stair guards visible
around that platform and retains the native timber board seams.

The first native candidate closes both circled members. Original and candidate
streams have identical vertices, UVs, collision faces and triangle counts for
all eleven transitions across the two photographed towns. Only render winding
and normals change. The UV basis is computed from the original corners,
independently of the corrected lighting normal.

The focused run passes ten of eleven tests (352/353 assertions). Its one older
failure counts 14 faces inside the historical full-height hanging-course
region in the September 8 town. An independently loaded frozen pre-change
builder reconstructs that exact transition with identical vertices and
collision, proving this failure predates the railing correction. The current
short masonry ends above most of that historic region, with measured nearby
stone bounds retained in `legacy-probe.json`. This report does not accept the
old course test or claim a globally green railing suite.

The pixel diff also exposed a caller that compensated for the old inward box
faces: `suspended_lawn_border` reversed them a second time. Candidate one
therefore regressed the lawn border. The existing border test fails 72 top-face
checks on that candidate. Removing only the redundant caller reversal restores
its original appearance; `native-diff` now shows changes only to the stair rails.
The rejected full-game run is retained in `candidate1`, and the rejected native
differences in `native-diff-candidate1`.

The legacy probe found all 14 historical assertion points outside actual native
stone bounds. The old test now checks actual emitted masonry within the same
photographed region, including a nonempty masonry witness. Its three tests pass
with 20 assertions. Nine final rail/attachment/turf tests pass with 4,422
assertions. Combined with the unaffected initial focused cases, 17 distinct
tests / 4,490 assertions pass. This is focused acceptance, not a full-suite run.
