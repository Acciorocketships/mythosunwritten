# Photo 11 envelope regression

`photo11-envelope.var` is a 49 × 49 numeric crop on the 0.5 m world grid, origin (288, 760), from seed 2697992464 with the original September 26 bedrock envelope. It contains only origin, dimensions, ground, surface and rock arrays. Captured before production changes using `tests/harness/cliff_manual_probe.gd` and the native heightfield region (12, 32, radius 6).

Feature grading and water cuts are deliberately absent: this fixture isolates the mesher defect. Full streamed-site captures provide integration evidence in `docs/qa/2026-09-26-manual-cliffs/`.

`photo13-fins.var` is a 17 × 17 crop at (288, 998), captured with the widened profile before fin trimming. It preserves the 4.55 m single-node projection at (291.5, 1002). The backing is 12 m high at that point. Generated from the real seed region (12, 42, radius 6) using `cliff_manual_fins.gd` and cropped with `cliff_manual_trim.gd`.

`photo11-original-mesh.var` freezes the original HEAD surface-net mesh and shading roots over `(296,768,8,8)`, built from `photo11-envelope.var`. It pins the 15 inconsistent shared edges, 16 omitted-column rays, and unchanged rounded surface vertices/normals away from the repair. The prior widened-profile/fin study was rejected by the owner; its fixture is historical, not the production target.

`p03-constrained-inputs.var.gz`: 21 KB gzip-compressed Godot Variant with
native ground heights, canonical wet levels and exclusion flags for seed
2697992464, rectangle `(476,924,92,96)` plus the envelope halo. Captured from
the settled production world on September 26 for the owner's second P03
annotation. It contains inputs, not expected output geometry. Used by
`test_p03_constrained_cliffs.gd` to test the exact marked crowns and rock
patch rather than an unconstrained synthetic wall. Reproduce extraction
with `cliff_p03_continuity_probe.gd` and `cliff_p03_freeze_inputs.gd`.

`dead-end-road-inputs.var.gz`: 23 KB gzip-compressed Godot Variant of the
native envelope inputs (ground, exclusion kinds 0/1/2, water) around the
owner's September 27 dead-end road photo (player 1177.8, 24, 527), seed
2697992464, captured from the defective graded world in which the town
grade had lowered cell (49,22) a storey, so the road crossed an 8 m step at
x = 1163.5. Historical only: the envelope mitigation it pinned was removed
when the town grade itself was fixed to ramp accepted roads
(`test_september27_road_grade.gd`, fixture
`tests/fixtures/september27-dead-end-grade.var.gz`). Captured with
`cliff_slope_dead_end_probe.gd`, frozen by `cliff_slope_dead_end_freeze.gd`.
