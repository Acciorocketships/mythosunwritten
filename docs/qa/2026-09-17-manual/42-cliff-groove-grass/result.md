# Groove grass diagnosis and stronger sampling coverage

The pass-41 8-to-5 grass count was investigated instead of forcing the old anchor count back. The lost anchors retain exactly the same height and slope; real tread boundaries move by up to roughly eight centimetres as the small crag field is removed. Their clearance shrinks enough to reject some globally sampled patches. These are actual rim changes, not false internal tessellation edges.

Across sixteen paired **grass-placement seeds on the same fixed geometry**, the pre-groove fixture has 176 supported roots and the groove study has 170 (96.59%). This is not a sixteen-world terrain corpus. The former single-seed minimum was sensitive to movement of narrow rims relative to the fixed world lattice.

`test_september16_cliff_grass.gd` now checks the full fixed sixteen-seed corpus: many distinct supported faces, at least six patches per seed on average, every complete patch within the actual support plane, and no buried roots. A new paired test compares against the frozen pre-groove geometry and requires at least 90% of its total coverage. Existing chunk-owner equality and foliage ownership checks remain. No grass implementation or density setting changed.

Production baseline: four tests / eleven assertions pass, 176 roots, zero escaped/buried samples. Groove fixture: the same four tests / eleven assertions pass, 170 roots, zero escaped/buried samples. The groove's precise corner fixture also passes nine tests / 37 assertions. Logs: `grass-baseline.log`, `grass-candidate.log`, `corners.log`; original point diagnosis: `diagnose.log`, `edges.log`, `density.log`.

This resolves the uncertainty behind the reported grass count. It does **not** adopt the grooves: the owner subsequently rejected the tall-wall columns and independent scratches. Production art remains unchanged. The new direction is the [connected-stone geometry study](../43-cliff-connected-stone/result.md).
