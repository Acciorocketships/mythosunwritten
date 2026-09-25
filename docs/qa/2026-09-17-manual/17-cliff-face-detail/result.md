# Rejected face-detail experiments

The owner prefers the earlier face treatment and rejects the added gouges, noisy head-on appearance, dark/light streaks and thin ledges. None of this directory's geometry or shader trials was promoted to production. The next investigation is [localized terraced bases](../18-cliff-terraced-base/), using broader lower shoulders and actual Ultimate Nature rock shapes.

Trials are preserved under `tests/fixtures/september17/cliff-face-detail/`:

- `interior` and `interior-strong`: authored stone normal-map crop, too weak to address the broad soft faces. Four representative interior views and the stronger P12 reported view were inspected.
- `interior-coarse`: stronger/finer texture, revealing an incorrect crop that included an atlas border and produced repeated bands. The P12 reported view was rejected.
- `interior-clean`: corrected crop plus mirrored-boundary fading. P12 reported, P17 reported, P20 oblique and P05 vines were inspected. The face detail is visible, but the head-on result is too noisy; rejected following owner feedback. Seventeen views were captured, not all judged.
- `spalls`: shallow finite geometry cuts. The P12 reported view barely changes the broad face; rejected.
- `spalls-deep`: stronger asymmetric cuts. P12 front and P17 front show unwanted gouges; rejected. This process stopped producing output after three supplemental views and was terminated; no complete capture-set claim.

The normal source is the existing `assets/Medieval Village MegaKit/Textures/Normals Godot-Unity/T_RockTrim_Normal.png`. No texture image was edited. The context harness gained an optional `--stone-normal` parameter solely to bind this trial's source texture. Shader/geometry production remains at the previous shoulder-repair version. No new regression test, fresh world, physical traversal or performance acceptance is claimed for these rejected studies.
