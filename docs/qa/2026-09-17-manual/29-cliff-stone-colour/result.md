# Subtle colour variation across cliff stone

The shared stone material now adds continuous warm/cool gray patches and restrained value variation. A quintic-interpolated world-space field combines broad 0.14 and secondary 0.43 spatial scales, with a 0.84–1.16 value multiplier and muted temperature variation. Native cliff stone, added crags, field rocks and legacy cliff relief use the same function. Turf follows its existing material path.

The field is independent of mesh triangles and local UVs, so it does not outline facets or restart at outcrop joins. Existing authored stone texture and surface detail remain.

## Evidence

The native GPU regression first fails on the archived uniform-colour shader (`red.log`, zero measured spatial contrast at three positions). The final actual crag and field-rock shaders pass all 12 assertions in `gpu-tests.log`:

| World position | 5th–95th percentile contrast / median | Largest neighboring pixel step / median | Native/crag join colour error |
|---|---:|---:|---:|
| (-443, 36, -266) | 0.251247 | 0.022014 | 0 |
| (-1262, 64, -537) | 0.227445 | 0.021025 | 0 |
| (10, 12, 30) | 0.305908 | 0.023296 | 0 |

These are controlled unshaded 20 m material probes, not measurements of whole-game lighting. Contrast is bounded between 0.07 and 0.40, neighboring steps below 0.03, and join errors below 0.003.

The final clean-process combined run passes **50 tests / 1,988 assertions** across 16 scripts (`focused-tests.log`). The independent native GPU run passes **one test / 12 assertions**. Earlier partial runs are retained for diagnosis, not added to these counts.

## Art review

`current/` contains 17 native saved-camera captures. Compare [P20 oblique before colour](../28-cliff-ledge-channels/final/P20_oblique.png) with [current P20 oblique](current/P20_oblique.png): the geometry is the same. The broad gray surfaces now have restrained warm/cool variation without new painted stripes. It is intentionally subtle in P05's shadow. P05 front/alternate views, P12 side/front, P17 front and P20 oblique/alternate views were inspected. The [P05 ledge](current/P05_reported_0.png) also retains the channel repair and pointed turf coverage from pass 28.

This does not complete the broader cliff art direction. Vertical mass organization, repeated backing relief, some thin upper ledges and coarse joins still need work. No fresh-world run, player traversal, full-suite acceptance or GPU performance claim is made.

## Current production verification

The colour field remains selected with the pass 34 physical rock detail. A clean native Metal run again passes the GPU test's twelve assertions at all three positions, with the same contrast, neighboring-step and zero join-error measurements above. The output is retained as `current-production-gpu.log`.

`current-production-review/` contains seventeen newly rendered saved/alternate views of that production combination. P20 oblique, P05 reported 0 and P12 side were inspected. Broad warm/cool gray variation remains restrained, and the P05/P12 turf follows the curved caps through their narrowing ends. Shadowed faces show less colour variation than sunlit faces. The replay uses frozen terrain, atmosphere and grass; it is not a fresh-world or traversal check. No extra material-strength change was needed during this verification.
