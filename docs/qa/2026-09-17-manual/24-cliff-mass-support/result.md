# Continuous rock feet and reliable ledge support

This revision repairs two actual discontinuities in the ordinary rock-mass field. It retains the preceding sloped broad terraces and their along-wall curves. It is **not overall cliff-art acceptance**: the repeated native courses, broad soft fronts and vertical organization still fall short of the owner's reference.

## Geometry faults and repair

The body widened each rock's foot by up to 38%, with asymmetric cross-section noise and lateral drift, but candidate discovery discarded the rock outside its narrower upper radius. The foot therefore ended abruptly at an unrelated vertical boundary. Discovery now covers the complete mathematical support envelope, including the noise minimum and drift. Tall rocks require three neighboring 5 m cells rather than two. The existing mass dimensions and depth budgets are preserved.

A second discontinuity changed the cross-section noise seed whenever the already tilted crest crossed a rounded integer height. The shape seed now belongs to the mass before that tilt. This preserves variation without changing the seed partway across one rock.

The new regression samples the 31 saved photo formations and 32/64 m controls at three elevations, **76,599 samples**. Its largest depth jump over a 2 cm horizontal step is **0.609898 m before**, failing the unchanged 0.15 m bound, and **0.074629 m after**. See [expanded-red.log](expanded-red.log) and [complete-tests.log](complete-tests.log). The first bounds-only repair still had a 0.227708 m jump in the initial lower-foot survey, which exposed the separate seed discontinuity; it was not selected alone.

Production `CliffRockCrags.gd` matches `tests/fixtures/september17/cliff-mass-support/candidate.gd`. The short-scale regression now checks that every original mass's center, radii and depth budget is retained, rather than requiring identical candidate-list length: complete foot discovery intentionally admits previously omitted neighbors. No original dimension or geometric acceptance threshold was relaxed.

## Grass support fault

The first full run passed 32/33 tests and retained five grass patches instead of six. A survey across four tile columns confirmed that the missing root had not merely moved to a neighboring tile. At `(85.45217, 38.24749)`, the actual support height changed only from 6.056082 to 6.055934 m, but its reported edge distance collapsed from 0.247490 to 0.002510 m. The surface's tiny normal change had crossed an angle-only coplanarity threshold, falsely turning an internal tessellation edge into an exposed border.

`CliffRockRelief._turf_component_borders` now checks actual plane fit. Every face plane in a merged component must contain every other member's vertices within 1 mm. Testing complete components prevents many individually shallow bends from accumulating into a falsely flat support claim. Actual root heights, normals, occluding rocks and complete patch-footprint checks remain unchanged.

The new three-case regression first fails for the submillimetre bend, while real creases and accumulated curvature stay protected: [seam-red.log](seam-red.log). All three pass after the repair. The unchanged production grass test now retains **seven** roots, with **zero escaped and zero buried samples**, and identical chunk ownership. See [seam-green.log](seam-green.log). No grass-count threshold was lowered.

## Final verification and limits

**36 tests / 610 assertions pass** in [complete-tests.log](complete-tests.log). This includes closed straight/corner collision, 16/32/64 m corner closure, lower bearing, crown clearance, native attachments, public/wet exclusions, ownership, turf width, grass support, scale preservation and seven independent prominence samples. Straight-photo recession is 0.6762 m; crown excess is zero; wide-tread area is 90.389 square metres. The macOS certificate-loader diagnostic remains unrelated to GUT results. The earlier [final-tests.log](final-tests.log) is the superseded run with the grass failure, not final acceptance.

[fixed/](fixed/) contains 17 native context captures with matching straight and corner generators. P05_reported_0, P20_oblique, P12_side and P20_reported_0 were inspected. [tall/](tall/) contains five 64 m controls; front was inspected. These show a scoped continuity repair, not the desired complete art transformation. They regenerate rock geometry in a frozen world; grass/support is verified separately through the real worker, not fresh-world screenshots. No streaming, hydraulic, actual-player traversal or general performance acceptance is claimed.
