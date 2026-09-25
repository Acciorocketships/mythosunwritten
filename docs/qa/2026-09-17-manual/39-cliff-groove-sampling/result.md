# Narrow groove sampling follow-up

The short narrow-groove treatment remains the preferred small-detail experiment. **Production is unchanged.** This follow-up halves lateral sample density from the refined pass-37 study, retaining its 0.1 m vertical spacing. Physical grooves, quiet stone shader, broad grey colour and existing ledge composition are unchanged in definition.

## Visual result

Seventeen native frozen-game context views and five 16 m studio views are retained. The inspected [P20 oblique](context/P20_oblique.png), [P05 reported camera](context/P05_reported_0.png) and [studio close view](short/close.png) preserve the quieter surface and sparse distinct fractures. The lighter lattice is a useful study replacement for the expensive pass-37 variant. It does not fix large smooth faces, column-like composition, narrow upper turf or exposed repeating native wall relief. The close studio view still exposes those shortcomings; this is not final cliff-art acceptance.

For the requested alternatives, compare [no small crags](../37-cliff-detail-options/clean/P20_oblique.png), [more outcrops without crags](../37-cliff-detail-options/outcrops/P20_oblique.png), [narrow grooves](context/P20_oblique.png) and [current production](../37-cliff-detail-options/before/P20_oblique.png). Clean is too plain; adding the tested rounded masses barely changes the photographed cliff and reinforces columns in the studio. Sparse short grooves give the strongest improvement in surface detail, while the larger forms need separate work.

## Verification and cost

The six reported ledge/support tests pass twelve assertions. The duplicate-fracture regression passes one test / two assertions: coincident fracture owners do not deepen the cut twice. This is seven focused tests / fourteen assertions, not a full suite.

For exactly the same three photo formations (anchor indices 0, 11 and 20):

| Mesh | Triangles | Single local generation measurement |
|---|---:|---:|
| Production | 48,252 | 612.081 ms |
| Refined dense study | 179,580 | 1,471.677 ms |
| Lighter groove study | 90,356 | 754.717 ms |

The lighter version has 49.7% fewer triangles than the dense study, but still 87.3% more than production. Timings are a single local headless sample, not a benchmark of game frames, streaming, startup or GPU cost. No global performance acceptance. The measurement process logged the known macOS certificate lookup warning before generating the data; it exited normally.

These images reconstruct rocks and crevice plants on a frozen world. They do not establish fresh-world placement, regenerated grass, hydraulic admission, traversal or universal collision. Production remains byte-identical to the pass-37 `before.gd` fixture. Tall production investigations remain open. The separate [broader terrace study](../38-cliff-terrace-composition/result.md) was rejected visually even though its first variant passes the relevant measured gates.
