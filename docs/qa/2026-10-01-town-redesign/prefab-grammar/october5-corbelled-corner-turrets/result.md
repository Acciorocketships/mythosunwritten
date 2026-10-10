# Native corbelled corner turrets — October 5

Accepted bounded progress toward the owner's request for more properly connected corner spires. The previous raised-datum experiment added no supported towers. This pass adds an actual native support connection instead of weakening ground-bearing checks.

## Source and implementation

Inspected Pure Village House_11c and House_16c and the native narrow/full and half-tower support meshes. House_11c has a narrow shaft through a roof; House_16c uses wall-attached corbels. The new full-round corner connection generalizes the pack's `StoneTower_Support_15x30` stock. It is not claimed to reconstruct an exact authored corner assembly.

Baked the unmodified native support mesh through `pure_village_round_support.json`. `KitTowerAssembly` admits the new CORBELLED_ROUND form only on a continuous convex corner: the same one of four adjoining room quadrants must exist for the whole shaft and a full storey below the seat, without a jetty inset. The proposer requires at least three host levels and a two-storey shaft. Actual measured public/neighbor clearance, lower-door protection, host roof junctions and host palette rules remain active. Grounded shafts retain their original bearing proof. Stone supports retain their material; caps follow the host roof palette.

## Verification

- Red-first native corbel fixture: one of two tests failed, 3/4 assertions passed before the fit implementation.
- Focused corbel/corner/host-fit suites: 12 tests / 126 assertions passed. After adding the production-town regression, the corbel file passes 4 tests / 14 assertions (overlaps the preceding suite).
- Roof palette suite: 2 tests / 2,059 assertions passed.
- Six comparison towns retain all 220 compared covered quarters and identical recorded route coverage. Floating-mass and roof-air audits are zero in all six.
- Four additional holdouts (7/standard, 43/grand, 201/large, 503/grand) also have zero floating-mass and roof-air failures. No before/after holdout comparison is claimed.
- 31/large actual player: all ten traversals pass, covering two skywalks, two source bridges and the nearby underpass in both directions. Some isolated endpoint ray misses remain; the result proves these continuous traversals, not universal ray coverage.

| Town | Towers before | Towers after | New corbel form |
|---|---:|---:|---:|
| 31/large | 0 | 1 | 1 |
| 53/grand | 1 | 3 | 3 |
| 63/grand | 1 | 1 | 0 |
| 83/grand | 0 | 0 | 0 |
| 103/grand | 0 | 1 | 1 |
| 301/grand | 1 | 3 | 2 |

Total towers increase from 3 to 9, with seven corbel placements; one replaces an existing half-shaft. Some room projections yield to the accepted tower envelope.

## Native review

Reviewed isolated support seating from both faces, all seven new placements in the comparison towns, and two matched before/after camera pairs for 301/grand. The corner shafts meet both host faces, their native corbels close their bases, and caps match their host roofs. The automatic 301 `turret1_1` camera is inside another roof and is not acceptance evidence; its opposite view is usable. The initial close-gallery attempt had a script parse error and was rerun successfully; that failure is not test evidence.

The before-render source switch finished and restored production (`audit,true`). No temporary source switch remains.

## Remaining work

This pass increases supported spires; it does not increase tunnels/skywalks or deliver the requested broad internal town-square decks. Tall regular facades and exposed boardwalks remain visible. Those layout and architectural requirements remain active. Do not interpret clear safety audits as full visual acceptance of the town redesign.
