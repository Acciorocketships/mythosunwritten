# Interior square and climbing-route prototype — October 5

**Rejected candidate, archived for continued development. Production carver restored byte-for-byte.** No new placement rule shipped this turn. Previous goal turn was progress: it established interior field capacity and the addressed-height mismatch. This turn proves that a route can address such a square, then exposes downstream ownership/support failures.

## Prototype and first regression

A resource-free selector searches supported 3×3 sites at least three rings inside the massif, with three majority buildable sides after allowing an entrance. It uses existing house support, edge/plinth limits, cut-depth six and mean budget three. Seeded stable ranking picks a proposal; no seed-specific production coordinates. The selected floor and prospective frontage reserve their support/room interval before the climbing route. The route targets a level entrance at the square datum and preserves existing span/crown rules. Failed route search releases reservations and falls back to the ordinary portal search. The preview receives the proposed court as a preferred site.

The initial study addresses 13/grand at (-2,-5)..(0,-3), floor 2, entrance (-1,2,-2), and 43/grand at (-5,-3)..(-3,-1), floor 7. Attempts in 53 and 103 exhaust the existing 40,000-visit budget and fall back. A 1,000-visit trial misses 13's valid route; successful 13 needs 10,740 visits. Lowering only the proposal's minimum path length leaves this count unchanged and was reverted. The prototype still treats the entrance as the summit; a waypoint formulation is a possible extension, not implemented or evaluated here.

The new regression fails against production because 13's square is only eight columns (2×4). The candidate passes size, raised floor, interior ring depth and genuine level entrance: 16 assertions. This green check is **insufficient** for acceptance.

## Active falsification

Finished native renders show a larger green/deck square with a tree, but surrounding source house slots become roofs at square level. The finished-room audit counts only **one** majority inhabited side. For example, the east frontage belongs to house.031 with source floor 0/top 4, but there is no finished room at court band 2; the house's roof consumes that part of its envelope. The candidate reserves prospective room columns at the court datum, but ordinary lower-floor seeding/growth can still own them. Existing `_fill_court_frontages` cannot recover already-owned columns.

43/grand fails the full fabric gate: `spatial.parcel.maze.house.009.part00.room00` is marked terrain-bearing but has 0/4 exact source-bearing columns and no grounded tunnel portal. No exception was added to the foundation gate.

The strengthened candidate regression has three tests: initial placement passes; actual three-sided finished-room enclosure and 43's foundation proof both fail. Final run: 1/3 tests, 18/20 assertions, ~52 s. Native views are saved under `native/`; views plaza.00_0 and plaza.00_2 show why source admission is not art acceptance. No player traversal or broad corpus acceptance is claimed.

## Continue from this evidence

The next iteration needs court-frontage ownership and real room height co-decided with the square, rather than assuming an unclaimed supported column survives ordinary lower-floor allocation. A lower house may need an occupied upper frontage or yield that frontage to a court-level parcel, but roof reservation, ground doors, bearing and public routes must remain proved. Diagnose the 43 exact-foundation failure from the source-to-room translation before shipping a rerouted town. Bound route-search cost; do not simply allow every failed optional proposal another full search budget.

`carver-candidate.patch` is relative to the unchanged accepted carver; `WarrenInteriorCourt.gd` and `test_interior_court_route.gd` are archived here instead of active source/tests. Restore them to their original production/test paths and apply the patch only to resume the candidate. All candidate processes completed before restoration. The exact same 43/grand foundation regression then passes against the restored accepted generator (one test / one assertion), confirming the failure belongs to the route candidate. The rejected prototype must not be described as delivered square generation; broader architecture and the original redesign remain active.
