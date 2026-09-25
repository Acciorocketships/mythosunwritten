# Irregular patches of physical rock detail

The previous goal turn completed fresh P20 judgment and recorded the hybrid relief result. That was progress, but did not complete the cliff art direction. This pass changes the physical stone surface while retaining its curved terraces, broad rooted feet, crown retreat and shared colour field.

## Selected change

`CliffRockCrags.gd` now combines quiet oblique weathering with irregular patches of chipped planes. The plane field has a short rounded bevel and broad interior; it is rotated relative to the wall's construction axes. A slower continuous field varies its coverage. Thin attachments retain the existing blend into native wall relief. The existing fracture contribution is reduced so the new detail does not simply add more dark grooves.

The detail is part of the emitted stone triangles and their collision. It is not a replacement texture or a shader-only normal effect. Ledge ownership, tread construction, turf material and the warm/cool stone-colour shader are unchanged.

The selected implementation is archived as `tests/fixtures/september17/cliff-oblique-relief/cached.gd`. Seed positions are cached inside each formation's `make()` call, without mutable shared worker state. `cache-proof-tall.log` verifies byte-identical stone and turf geometry against the uncached `patches.gd` for all 31 photo formations and separate 32/64 m controls.

## Rejected studies

- `candidate.gd`: oblique ridged noise still looks soft. P20 oblique, P05 reported and P12 side were inspected; not selected.
- `bearing.gd`: allowing deeper source-profile recesses passes six support/channel tests / twelve assertions but offers little visual improvement. P20 oblique and P12 side were inspected; not selected.
- `planes.gd`: chipped planes across the entire surface give short faces more detail, but the 64 m control becomes a uniformly cobbled pattern. Twelve geometry tests / 27 assertions pass; the art rejection takes precedence.

The selected `patches.gd` study avoids that continuous coverage. Its 17 frozen-context captures and five tall controls are retained. Inspected final views include P20 oblique/reported +8, P12 side, P05 reported +8 and the tall oblique view. The cached implementation emits identical geometry, as verified separately.

## Verification

The production combined run passes **38 tests / 192 assertions** across fifteen scripts (`final-tests.log`). It checks closed short/tall corner solids, all 31 closed nondegenerate photo shells, physical root attachment, independent projections, full-height coverage, broad curved treads, native crown clearance, public/wet exclusions and chunk ownership.

Selected measurements:

| Check | Result |
|---|---:|
| Reported P05 cap contacts carrying turf | 57/57 |
| Largest photo undercut below an upper projection | 0.5057 m, below the existing 0.85 m bound |
| Largest convex-corner undercut | 0.3276 m |
| Excess projection at native crown | 0 |
| Broad turf area across photo formations | 236.006 m² |
| Isolated narrow turf area | 0 |
| Deep / quiet basal samples | 161 / 158 |
| Actual worker grass roots | 8, none escaped or buried |
| Widened authored lower profiles | 12/12 |

An independent plane-field boundary probe covers both axes, negative coordinates and three salts. Its largest change across a 0.0002-unit boundary interval is 0.0007652 (`plane-probe.log`). The retained generic-mass continuity test passes 76,599 samples; the authored-profile test checks 179 steep intervals with a worst fine/coarse ratio of 0.06088. These checks support physical continuity, not aesthetic acceptance.

## Cost and limits

The final alternating three-formation microbenchmark takes 532.142/542.218 ms for the previous geometry and 615.637/617.955 ms for the selected geometry: about 15% more local generation time. Triangle counts are 48,250 versus 48,252. This is not a full-world timing or a GPU measurement; the extra work is not claimed as a performance improvement. The first uncached full-coverage study was more expensive. The cache preserves geometry exactly.

This pass makes some broad faces less smooth and more varied. The tall composition still has excessively vertical forms, repeated native backing and thin-looking distant shelves. It does not reach the supplied art reference. No fresh-world generation, traversal, hydraulic, streaming or overall cliff acceptance is claimed. All other original judging issues remain in the register; read-only inspection of the biome and water code made no production changes to those systems.
