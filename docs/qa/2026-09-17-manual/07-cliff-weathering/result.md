# Cliff stone surface detail — scoped material improvement

The added rock now has short, irregular, bevelled fractures alongside restrained grain. A world-space field stretches the fractures vertically and exposes them in broken patches. The existing attachment weight fades both bump and color variation to zero at the native wall. Native wall texture, stone palette, turf, all rock vertices, ledges, collision and placement stay unchanged.

This is a material improvement, not acceptance of the whole cliff shape. Broad soft forms, visible convex-corner transitions and ledge composition still need work. The rejected convex-wrap investigation is recorded in [06-cliff-corners](../06-cliff-corners/result.md).

## Evidence

The calibrated native GPU diagnostic reads the actual material's rendered normals on a 16 m stone patch at three reported world locations. Baseline soft grain has zero adjacent-pixel transitions above 20 degrees at all three locations; the [red run](final-red.log) fails the requirement for a small resolved fraction of sharper creases. The separate 65-degree spike limit rejects unstable shading rather than rewarding arbitrary noise. This diagnostic is a bounded contrast/stability check, not an aesthetic score.

The final [native GPU run](angles-final-gpu.log) also tests 0, 45 and 90-degree wall orientations. All nine patches have 1,402–4,832 sharp transitions and zero spikes. The maximum adjacent normal change is 46.48 degrees. A zero-weight attachment retains its original normal within one degree. The first diagnostic incorrectly routed normals through emission in unshaded mode and returned black; `red.log` and `calibration.log` are invalid evidence. `red2.log` shows soft grain also passes the preliminary low-contrast criterion; that criterion was replaced by the calibrated sharp-crease requirement, with the true baseline failure in `final-red.log`.

The final native run includes the existing ground-tint GPU tests: **four tests / 79 assertions pass**. The [focused geometry and normal suite](tests.log) passes **11 tests / 31 assertions**, preserving full-height coverage, selected broader lower shoulders, thin native joins, closed sampling topology and connected shading. Total: **15 tests / 110 assertions**. The geometry generator is byte-identical to the preceding accepted normal correction (`c5bf218b90503a712e3a504160b8a367562ba69262b5c95af9b9d919fa15c01d`).

Seventeen final native context captures are in `accepted/`. P05/P12/P17/P20 reported cameras use the saved ReviewCam-derived records; five nearby views supplement them. The replay keeps frozen terrain, grass and collision and rebuilds rocks/plants. Five newly constructed 64 m cliff views are in `tall-final/`. Reviewed P12 +8 degrees retains distinct ledge edges and gains restrained vertical fractures through the broad stone faces. P20 oblique retains its varied lower outline. The tall close view avoids the earlier closed-cell quilt, though the underlying broad forms still need art work. No fresh hydraulic admission or character traversal is inferred from these captures.

| Control | Before | Final |
|---|---|---|
| P12 +8 degrees | [Before](../05-cliff-normal-fans/candidate/P12_reported_8.png) | [Final](accepted/P12_reported_8.png) |
| P20 oblique | [Before](../05-cliff-normal-fans/candidate/P20_oblique.png) | [Final](accepted/P20_oblique.png) |
| Tall close | [Before](../05-cliff-normal-fans/tall/close.png) | [Final](tall-final/close.png) |

## Rejected studies

- `study/`: additional cellular geometry produces uneven gains in measured small clefts and unwanted near-face facets. The geometry remains a detached fixture; it is not production.
- `stone/`: nearest/second-nearest distance approximation produces dotted seams. Its native diagnostic reproduces 329, 421 and 157 flipped-normal spikes. Rejected.
- `stone2/` and `tall/`: exact nearest dividing-plane distance removes those spikes, but the tall view reveals a busy closed-cell fracture network. Rejected as final art.
- `tall3/`: orientation-weighted edge selection breaks up the network but reintroduces junction discontinuities. The native diagnostic catches 96, 49 and 77 spikes. Combining weighted crevice heights still leaves 60, 34 and 72. Both directional-weighting versions are rejected.
- Final: the continuous unweighted distance field remains, elongated vertically and revealed sparsely by a smooth spatial mask. This avoids the discontinuous edge selector.

## Local frame cost

The [final alternating benchmark](final-benchmark.log) uses one loaded scene, identical cameras, uncapped rendering with VSync disabled, 40 warm frames and 120 measured frames per block. Order is old/new/new/old. P12 front increases from a mean of **18.56 ms to 21.49 ms**; P20 oblique increases from **26.81 ms to 28.74 ms**. This is a local rendered-frame cost of approximately 2–3 ms. These are frame timings, not isolated Metal GPU timings, startup measurements or global performance acceptance.

Production shader SHA-256: `f91a0a3088f8790d45030665824aa055e74a97b00d21f3f30fb8bbcc83859d8a`.

Reproduce the current context with `tests/harness/september16_cliff_transition_context.tscn -- --output=res://OUTPUT`; add `--benchmark-stone` for the alternating comparison. `--stone-shader=res://tests/fixtures/september17/cliff-weathering/before.gdshader` restores the old material only in the review. Tall construction uses `tests/harness/september16_cliff_transition_study.tscn -- --height=64 --output=res://OUTPUT`. Run `test_september17_crag_weathering_gpu.gd` without `--headless`; `STORY_STONE_TEST_SHADER` selects a saved rejected shader for reproduction.
