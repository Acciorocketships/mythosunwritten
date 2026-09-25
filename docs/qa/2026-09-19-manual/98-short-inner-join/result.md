# Short inner-corner investigation — pass 98

No production change is accepted from this pass. The pass-97 dressing and join implementations are restored byte-for-byte. Its outer-corner and broad inner-ledge improvements remain; the short stepped inner seam remains open.

## Reproduction

The remaining short inner corner is at **(-421.5, 28, -349.5)**, height 4 m, seed 2697992464. The actual fresh pass-97 native terrain includes a 3 m wide / 8 m high transition panel at (-421.5, 28, -346.5) and a 3 m wide / 4 m high panel at the corner. The dressing's minimum 6 m width discards both. The tall 12 m wall ends 4.5 m from the turn, beyond the join selector's 2 m eligibility bound. The independent corner consequently remains.

`native-walls.bin` captures nearby native wall transforms from the fresh pass-97 snapshot. It is a finite 23 m inspection set, not proof of complete world-generation domains. The older pass-92 fixture omitted relevant surrounding geometry at this site because of its inspection radius; it is unsuitable as the sole short-turn control.

## Rejected candidates

1. **Narrow panels plus ordinary join:** removing the width guard supplies the missing panels and admits one connection. The pinned structural test changes from zero of three assertions passing to three of three. However, the matched native render produces a pointed slab and thin turf strips. Rejected despite the passing test.
2. **Prefer a parent already spanning the corner:** use the actual containing short panel rather than extending a more distant parent through it. The same three assertions pass, but the visible slab remains. Rejected. This prototype also lacks a final deterministic equal-score tie-break; it must not be adopted as production code.
3. **Narrow panels without join:** the native renderer crashed with SIG11 during capture. Its partial image is excluded from acceptance. This does not establish a production renderer defect or a successful repair.
4. **Local projected-surface blend:** a marching-tetrahedra study combines existing nearby rock surfaces. The first version produces jagged fragments and broken turf. A 0.10 m outward-offset control retains the defects, so simple coincident overlap is insufficient to explain them. A finite-bound / gray-only diagnostic removes the distracting turf classification but retains jagged interfaces and box-clipped edges. All versions are rejected. No collision, gameplay or production admission acceptance is claimed for these art-only experiments.

The experimental scripts and unresolved regression live under `tests/fixtures/september19/short-inner-join`; the unresolved test is deliberately outside the ordinary test catalogue. The production min-width guard and original parent selection are unchanged.

## Review evidence and scope

[Before](before/short_inner.png) · [Narrow panels and join](candidate/short_inner.png) · [Containing-parent variant](candidate2/short_inner.png) · [Rejected blend](blend/short_inner.png) · [Gray-only geometric diagnostic](blend-bounds/short_inner.png).

The first before/candidate sets retain twelve original reported camera poses plus three supplemental short-corner views. Later blend diagnostics use the same three supplemental views only. Frozen replay replaces 26 nearby formations and retains the snapshot terrain; it does not regenerate terrain, hydraulic admission, grass or collision. Supplemental poses are explicitly diagnostic, not substituted reported-camera evidence. No fresh-world, physical traversal, performance or broad art acceptance is claimed in this pass.

The next repair needs a coherent transition across adjoining wall heights and shapes, including the finite boundaries. Another independently shaped corner piece or locally clipped overlay repeats the demonstrated mismatch. The outer turn, matching-height inner ledge, lower shelf crossings, short transition and original issue register must continue to be judged separately.

## Restored-state verification

The unchanged production inner-connection and ledge-level suites pass **8 tests / 83 assertions**, including all 34 shared tread samples (maximum height mismatch 0.00000047683716 m). The isolated review harness passes GDScript parse checking. Production hashes are recorded; the two temporarily edited production files match their pre-study backups byte-for-byte. This validates restoration, not the unresolved short corner.
