# Cliff sampling and triangulation correction

The tall-wall hatching was a mesh construction defect. Neighboring columns joined by sampling index even when their ledges were at different heights. This made elongated diagonal triangles across otherwise continuous stone. Turning off shadows, shader bump and SSAO did not remove the pattern; geometric-normal and unlit controls isolated it to the surface triangulation.

The final generator samples continuous faces on a shared 0.20 m height lattice, retaining each exact ledge boundary. Neighboring bands join by elevation. The buried rear skin uses the same edge topology, keeping the actual collision solid closed. Crag shapes, native thin-root detail blending, varied full-height crowns and selected broader lower feet remain. No lighting or production shader changes conceal the defect.

## Iteration and judgment

- [Original close geometric-normal control](geometry-controls/close_facets.png): conspicuous diagonal teeth on steep faces. `geometry-controls/` contains seven material/light modes at five cameras.
- [First candidate](candidate1/close.png): elevation-based connections remove most hatching, but dense unequal rows still create fans beside ledges. Superseded.
- [Final close view](candidate2/close.png): shared physical samples remove those remaining fans; short fractures and block shoulders are retained.
- [Final oblique](candidate2/oblique.png) and [ledge view](candidate2/ledges.png): relief continues up the tall wall, with irregular depth and a wider selected toe. Native patterned recesses remain visible. The deliberately straight study crown is unchanged.

Five final 64 m study views and 17 frozen game-context views were captured. The front, close, oblique, wide and ledge study cameras were inspected, along with P20 oblique/reported, P12 front/side/+8 degrees, P17 −8 degrees and P05 vines. P20 has readable carved joints; P12 keeps rounded projecting faces and sharp finite shelves. The visible native corner at P17 remains more repetitive than the surrounding crags. Some broad faces remain soft and the close fern distribution is uneven. These are remaining art issues; this result accepts the triangulation repair, not the entire original judging pass or a match to the gold-standard reference.

| View | Before | Final |
|---|---|---|
| Tall front | [Before](geometry-controls/front_base.png) | [Final](candidate2/front.png) |
| Tall close | [Before](geometry-controls/close_base.png) | [Final](candidate2/close.png) |
| P20 oblique | [Before](../../2026-09-16-manual/18-cliff-crags/final/P20_oblique.png) | [Final](context/P20_oblique.png) |
| P12 front | [Before](../../2026-09-16-manual/18-cliff-crags/final/P12_front.png) | [Final](context/P12_front.png) |

## Verification

[Focused suite](verified-tests.log): 27 tests / 1,316 assertions pass. [Final sampling tests](sampling-tests.log): two tests / two assertions pass, including one added after the suite began. Together these are **28 distinct tests / 1,317 assertions**. The two new checks both [fail on the saved original generator](red-final.log).

- Stretched cross-column edges: 1.234% before; 0.0603% final. Remaining steep constrained boundary edges are a small fraction.
- Maximum sampled exposed vertical edge: 0.654 m before; 0.2001 m final.
- Mean thin-attachment normal mismatch: 0.97 degrees across 823 actual attachment samples.
- Near-crown coverage: 19/23 sampled positions on each of 16, 32 and 64 m walls.
- Lower projection: 21 broadened and 10 restrained sample positions, maximum 7.70 m against the earlier baseline.
- Closed actual triangle topology, canonical owner seams, native and added-rock plant contacts, worker grass ownership and turf slope all pass.
- 31 finite turf components span ten height bins and about 74.14 square metres in the control.

The saved starting generator is `tests/fixtures/september17/cliff-triangulation/before.gd`. Production source SHA-256: `2acf41c590378a167c0bd320daeefcf30129fb0034b09c74c97f3af05dd23ccc`.

The game replay rebuilds current visible rock/plant meshes at frozen anchors; it does not regenerate terrain, hydraulic admission or grass and does not prove fresh player traversal. Native study construction is fresh. No startup/global performance claim. The native runs completed without script errors; the headless runs retain the known non-fatal macOS certificate message.

## Reproduction

`tests/harness/september16_cliff_transition_study.tscn -- --height=64 --output=res://OUTPUT`; add `--diagnose` for the seven lighting/material controls.

`tests/harness/september16_cliff_transition_context.tscn -- --output=res://OUTPUT` for the 17 frozen game cameras. Add `--generator=res://tests/fixtures/september17/cliff-triangulation/before.gd` to reproduce the prior mesh.
