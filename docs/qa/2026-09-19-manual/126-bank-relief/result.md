# Shoreline contact repair — experimental

The old narrow bank compression could move a formerly exposed rock face behind
its native backing. The representative far wall at (-466.5, 8, 240), crown 20 m,
shows this most clearly around world height 17–18 m (`profile.json`).

The current detached mapper retains the earlier lower-rock compression and adds
a smooth minimum contact depth only where the original source already clears the
native wall. The minimum approaches 0.18 m above the backing; it never extends
farther than the source. Originally buried vertices and crown roots stay unchanged.
This corrects 13,748 lost source contacts among 118,459 examined exposed vertices.
The red control fails that invariant; the candidate passes all five assertions.

An earlier exponential compression was rejected: it covered more upper wall but
flattened the lower rock too much. Its source and native images remain in
`rejected-exponential/`. It is not the current mapper.

## Fresh admission and verification

A new seed-2697992464 region/water domain for owner (-3, 1) reevaluates all owned
wet source formations. All 41 studied banks pass with identical face/turf arrays.
A separate formation at (-541.5, 20, 217.5) is rejected for channel clearance.
`admission.json` records every wet candidate; `validated-banks.bin` contains the
fresh results. No water or native terrain geometry is changed.

The native frozen-world survey covers 36 complete formations: 43,366 wet backing
probes have no missing contact, all 5,544 sampled feet remain buried, and no
sampled outward passage is obstructed. Maximum measured projection is 1.488 m.
Five other formations extend beyond the saved world's complete collision footprint
and are explicitly excluded, not counted as passing. See `native-contact.json`.

Canonical source plant proposals use the same deformed triangles. Fresh admission
and competition retain 55 plants. Native collision rays hit all intended owners;
maximum root error is 0.000072 m (`native-plants.json`). The five attachment tests
pass 37 assertions, including split ownership, canopy competition, water query
coverage and public clearance. Four reach tests pass six assertions, including
narrow-channel and flooded-crown rejection. Together with the red/green contact
regression, the final focused total is ten tests / 48 assertions.

## Visual judgment and limits

Five reconstructed N04 F3 angle pairs (0, ±10, ±35 degrees), two close contact
pairs and five planted/bare angle pairs use the same frozen production world.
The 503 original grass instances restored by the pass-124 helper are identical
across comparisons. The close fern pair demonstrates a genuine wall attachment.
`bank-before-*` is the older narrow bank study, not bare production.

The contact repair reduces the broken upper seam while preserving the earlier
submerged profile. It is useful, but not final art acceptance: the thin upper
transition still reveals too much native column repetition, some lower faces
remain too smooth, and broad grassy shelves are not established by this study.
The mapped plants improve attachment coverage but do not repair those shapes.

No bank fitting is promoted into production. Remaining work includes adjoining
mixed-height surface recipes, a less repetitive upper transition, actual usable
ledge/grass support, independent-domain checks on the revised mapper, and native
traversal/swim verification. Wider cliff, town, water and loading issues remain
open under the original goal. The known frozen village material UID warning is
unchanged; current native runs exit successfully.
