# September 29 town review — stream "edges" (bare, sheer town perimeter)

Owner (photo 7, Town A = city 1260018864828801968 compact): "the outside of the
towns appear very bare. there are often multi-storey buildings lining the
outside of the town, so it's just a sheer face. it would be nice if the
building height went down to single-storey ... i would have thought that this
would in part be solved by the fact that we create the mass with a gaussian
mixture model, which goes down towards the edges".

## What was wrong (measured)

New metric `tests/fixtures/town_perimeter_profile.gd` (harness
`tests/harness/layout_judging/perimeter_profile.gd`). For every exterior edge of
the massif footprint (a massif column facing open ground that reaches the far
outside) it reads the BUILT kit masses (`KitVillageBuildings.build(...).masses`,
houses, landmarks, retained terraces, bridge-houses) over the rim column and
the column one ring inside:

* `rim_over` — rim wall more than 2 storeys above the column's ground
* `inner_over` — second-ring wall more than 3 storeys above ground
* `rim_tall_house` — a house on the rim more than one storey above its floor
* `sheer` — rim wall >= 2 storeys above ground (plinth included, informational)

Corpus: towns A and B plus cities 1-12 x compact/standard/large (38 towns,
flat ground, `perimeter_baseline.txt` / `perimeter_after.txt`), 2876 exterior
edges:

| metric | baseline 71398f7c | after |
|---|---|---|
| towns built | 38/38 | 38/38 |
| `rim_over` (rim > 2 storeys above lawn) | 299 (10.4%) | 0 |
| `inner_over` (2nd ring > 3 storeys) | 247 (8.6%) | 1 |
| `rim_tall_house` (multi-storey house on the rim) | 457 (15.9%) | 7 |
| `sheer` (rim >= 2 storeys incl. plinth) | 691 (24.0%) | 330 (11.5%) |
| rim storeys histogram 0/1/2/3/4/5 | 1000/826/751/168/104/27 | 1011/1138/727/0/0/0 |
| mean rim storeys | 1.18 | 0.90 |
| house plots / house columns | 887 / 2671 | 872 / 2562 (-4% columns) |
| `bridge_over` (only a bridge-house over profile) | 83 | 56 |

Town A (photo 7): baseline rim_over 15, rim_tall_house 11, inner_over 3 -> 0/0/0.
The 8 residual edges are in 7/standard (4, a tiered house whose street crosses
its roof), 7/large (2), 9/large (1), 3/large (1).

## Root cause

The Gaussian-mixture massif (`WarrenTownField` + `WarrenMassifBuilder`) does go
down to the edge: the rim ring is exactly one terrace (one storey of mass), the
next ring at most three. But the massif is only an advisory envelope — "`top` is
NOT clamped to the massif" — and the house layer broke it in four ways
(categorised over 9 towns: 383 rim edges of 2+ storeys, 17 of them bare retained terrace):

1. **Raised rim houses** (236 edges at 2 storeys, 29 at 3): streets near the
   edge run on top of the one-storey rim terrace, so rim houses stand on a
   full-storey plinth and then add their own storeys.
2. **`_outer_terrace_top` loophole** (35 edges): the one-storey-per-ring cap
   applied only when a *non-member* deeper neighbour existed, so any parcel
   that itself reached inward (a 2x2 or 1x3 house on the rim) kept its full
   storey roll (3 storeys) on the lawn.
3. **Skyline peaks on the rim** (20 edges): the "local maximum tower" rule
   keeps a narrow parcel's complete seeded stack — rim towers of 4 storeys
   (the left half of photo 7).
4. **Kit landmarks** (39 edges): `KitVillageBuildings._landmark_house` always
   builds 2-3 storeys regardless of where the prefab stands.
5. Minor: composition shifting an upper floorplate out over a one-storey rim
   house (7 edges, `WarrenRoomCompositionPlanner` accepts OUTSIDE air).

## Fix (generator rules, no site exceptions)

* `WarrenPlotPlanner`
  * `_outer_terrace_top`: always one storey per complete massif ring above the
    parcel floor, counted from its shallowest column (exemption removed).
  * `EDGE_RINGS = 2`, `PLINTH_STOREYS = 1`, `_edge_envelope_top`: on the two
    outer rings walls stand at most `ring + 1` storeys above the column's own
    ground (the +1 is the rim terrace a house may stand on). Snapped to whole
    storeys; columns that cannot host a storey under it leave the footprint
    (the ordinary `_keep_component` path); a tiered house (street on its roof)
    reads the envelope without the roof reservation.
  * Skyline peaks only off the edge rings.
  * `edge_storey_cap` / `edge_wall_top`: the same profile, exported.
* `KitVillageBuildings._landmark_house`: landmark storeys capped by
  `edge_storey_cap`; the reserved air above a capped landmark stays its own
  (`own_air`) so its roof still fits (otherwise the roof test hit the landmark's
  own PRIVATE_VOLUME and the crown became a flat railed deck).
* `WarrenSpatialGrid.profile_ceiling` (filled in
  `WarrenVolumetricSolver.from_volume` from the source plan) +
  `WarrenRoomCompositionPlanner._cell_is_clear_for_lineage`: rooms may not
  project into OUTSIDE air above the edge profile.

The massif builder and carver are unchanged (compatible with the parallel
"tiers" raised-district stream: the profile only binds the two outer rings).

## Tried and rejected

* **Ground-relative one storey per ring with no plinth** (rim walls <= 1 storey
  above the lawn): rim raised houses were refused, their columns became bare
  one-storey stone retaining walls with railed lawns on top (a rampart /
  fortress look), house columns fell 674 -> 441 on the 10-town subset. Renders
  judged worse than the fix above.
* **Lowering the massif edge ceilings** (one terrace per ring): starves the
  carver — ring-2 columns stop being house-capable for band-2 streets, alleys
  no longer reach satellites (4/standard went 122 -> 21 house columns).
* **Perimeter lane** (a carver pass laying an at-grade lane along the rim so
  ground-floor houses face outward): almost never legal — the ring behind the
  rim is carved by raised streets or is thinner than a house at grade; 2-9
  lane cells over 10 towns. Removed.
* **Outskirts market lanes**: `VillageOutskirtsSolver` is not used in
  production any more (`VillagePlan` sets `record.outskirts = null`; the
  separate ground-house ring was removed on Sep 12 by owner direction), so it
  produces nothing in kit towns. Not revived.

## Evidence (JPG/PNG on disk only)

`docs/qa/2026-09-29-town-review/edges/before|after/`:
* `1260018864828801968_compact_photo7.png` — photo-7 angle (production frame
  from `tests/harness/layout_judging/production_frame.gd -- 0,1`).
* `*_far7.png`, `*_edge0..7.png` (eight lawn-level bearings), `*_overview.png`,
  `*_orbit0..3.png` for Town A, Town B (`photo11` too), 3/standard,
  7/standard, 4/large, 1/compact, 11/compact.
* Corpus tables: `perimeter_baseline.txt`, `perimeter_after.txt`.

Side-by-side sheets (before left, after right): `compare_townA.jpg`,
`compare_townB.jpg`, `compare_corpus.jpg`.

* Photo 7 angle: the 4-storey tower block on the left of the photo is gone;
  the rim is now a row of one-storey gabled houses on the rim terrace course.
  The terrace course (stone) and the one-storey house on it remain — see Open.
* far7 / edge views of Town A: the 3-4 storey rim stacks are replaced by a
  terraced silhouette; the tallest mass sits in the middle of the town.
* Town B: the 3-storey landmark on the rim is now a long one-storey hall with a
  full roof (edge0); the tower at the edge (edge5) is gone.
* 3/standard, 7/standard, 11/compact, 1/compact, 4/large: rim towers and
  3-storey rim rows removed; landmarks on the rim become one-storey halls.
  Retained-terrace faces (stone course / blank timber retaining walls with
  railed gardens) are unchanged where no house stands on the rim.
* A first "after" set showed capped landmarks with flat railed decks instead
  of roofs (their roof test hit their own reserved PRIVATE_VOLUME); fixed with
  `own_air` and re-rendered.

## Tests

* `test_september29_town_edges.gd` (new; towns A, B, 3/standard, 6/large):
  red on baseline (3/3 metric tests fail: rim_over 15/10/16/9, rim_tall_house
  11/16/12/6, inner_over 3/4/23/15), green after (4/4, 74 asserts).
* `test_warren_maze_plots.gd`: 38/42 after; the same 4 tests (11 asserts) fail
  on baseline identically (plaza pin, floating-street pins, stacked roof,
  sloped refusal pins).
* `test_warren_maze_carver.gd`: 12/13 after, same single failure on baseline
  (descent outward gain 0.95 < 1.0).
* Pass after: `test_building_kit` 8/8, `test_town_depth` 4/4,
  `test_town_canopies` 2/2, `test_town_closures` 4/4,
  `test_september27_town_details` 4/4, `test_september27_roofs` 5/5.

## Open

* Rim houses still stand on the one-storey rim terrace (stone course + one
  timber storey + roof). A true ground-level outer ring needs at-grade streets
  along the rim, i.e. a carver/massif change (a rim ring thick enough to carry a
  house at grade and a street network that reaches it at grade). The stone
  course itself is the materials stream's concern.
* Bridge-houses are exempt from the metric (`bridge_over`, 56 edges): the
  bridge span, its endpoint rooms and the `bridge.NN.end.K.lower` endpoint
  houses carrying it (allocated in `WarrenPlotPlanner.allocate_bridges`, which
  bypasses `_building_top`) can still stand 2 storeys on the rim / 4 bands on
  the second ring. A rule to keep bridge spans off the edge rings belongs with
  the skywalks stream.
* 8 residual edges (tiered single-column houses whose street crosses the roof).
* Retained terrace faces (no house) on the rim are unchanged: one-storey stone
  course with a railed garden on top.


---

# Follow-up: the rim terrace rampart and an at-grade outer lane

Coordinator follow-up after the first merge: the renders still showed a
one-storey stone retaining course running round the whole rim with houses on
top (Town A photo 7 / far7, Town B edge5). Owner: "a path lined with market
stalls, or a path with houses on either side".

## Why the earlier perimeter-lane attempt found no cells (measured)

`WarrenMazeCarver` debug of the first attempt (lane walked the rim ring after
the whole street network was carved):

* The lane required `_addressable_sides >= 1` with the carver's notion of a
  house-capable column (`street + MIN_HOUSE_BANDS <= massif.top`). Rim columns
  are one terrace (2 bands) thick, so they never count, even though the plot
  planner happily seeds a one-storey house at grade there (plot tops are not
  clamped to the massif).
* By then loops, alleys and the spine's descent had already bored the second
  ring at bands 1-3 (raised streets whose houses stand on the rim terrace --
  the rampart itself); `slot_is_borable` refused an at-grade lane under them.
* The rim / second ring is not 4-connected where the boundary steps
  diagonally, so a lane walking one ring stalls at every staircase corner.

## Rules changed

* **Perimeter lane on the second ring** (`WarrenMazeCarver._lay_perimeter_lanes`,
  `PERIMETER_RING = 2`), laid right after the spine and market, before loops
  and alleys: level at-grade steps along ring 2 from every at-grade walk node
  on the edge rings, single-cell ring-1/ring-3 connectors across diagonal
  steps, ends joined into the network where it meets another street (loop
  edges). Both sides are reserved as house frontage at grade
  (`frontage_reservations`), so later streets don't bore them. The plot planner
  then seeds single-storey cottages on the rim (backs = the town's outer face)
  and houses across the lane: a lane with houses on either side.
* **Edge rings stay at grade for optional streets**
  (`WarrenPassageLatticeRules.raises_edge`, `WarrenMassif.GRADE_RINGS = 2`,
  `WarrenMassif.ring_depth`): alleys, loop connectors and the spine's descent
  may not bore above ground on rings 1-2. (A hard rule for the spine too made
  the compact super-cell (-1,1) town fail its spine search -- rejected.)
* **The town square keeps its site**: the plaza competes with the lane for the
  flat edge band, so the carver previews the plot reservation on a sealed copy
  of the streets laid so far (`_preview_reserved_columns`) and keeps the lane
  off the plaza's columns (reserved from later streets too).
* **Market never strands a leaf**: the covered market may displace a house,
  but not the only doorway at the outermost addressed node of a public walk
  leaf (`WarrenVolumetricSolver.sole_leaf_destination_parcels`); otherwise the
  lane end became a pathway to nowhere (2/compact).
* **Edge envelope in whole storeys** (`WarrenPlotPlanner._edge_limit`): a house
  on an odd-band floor or capped by a claim above could round a part storey up
  past the envelope (6/large); tunnel covers (`cover_tunnels`) obey the same
  limit (3/standard).
* **Hanging stone released** (`WarrenVolumetricSolver._release_hanging_maze_stone`,
  after rock retention): retention could take back source mass above a crown
  already released over a lane, leaving a stone block on air under nothing
  (Town A over.02) -- a floating box the audit did not count (air below was
  OUTSIDE, not PUBLIC_AIR). Fixpoint release of maze stone standing on air
  above its ground that carries nothing.
* **Tunnel covers sit on their crown** (`TUNNEL_OVER_MAX_LIFT` 3 -> 1): a cover
  lifted above its crown left a gap band the rock retention does not reliably
  keep, so a cover storey stood half on air (Town A). Floating-stream rule,
  changed minimally; flag for that stream.

## Rejected (measured on 13 towns: A, B, 1/3/11 compact, 3/4/7 standard,
4/6 large, super(-1,1) compact, 8 compact, 12 grand)

| variant | rampart edges | lane cells | decks | landmarks | builds |
|---|---|---|---|---|---|
| integration head (no lane) | 258 | 0 | 14 | 20 | 13/13 |
| grade rule only, no lane | 130 | 0 | 10 | 17 | 12/13 |
| hard grade rule incl. spine | 4 | 521 | - | - | super(-1,1) fails |
| lane after plot reservation | 83 | 108 | - | - | 12/13 |
| lane on ring 3 | 100 | 213 | 13 | 7 | 13/13 |
| lane last + full reservation preview | 90 | 111 | 11 | 18 | 12/13 |
| lane first, no preview | 19 | 564 | 6 | 8 | 13/13 |
| **chosen: lane first + plaza preview** | **26-37** | **433-495** | **10** | **7-9** | **13/13** |

Landmark prefabs (3x3+ macro-column sites) and the perimeter lane compete for
the same flat edge band; keeping both was not possible (holding every
reserved site leaves the lane no ring to run on). The trade-off is surfaced
below as an open item.

## Results (integration head f1e5f619 vs this branch)

Corpus: towns A, B + cities 1-12 x compact/standard/large, flat ground (38
towns). `perimeter_lane_before.txt` / `perimeter_lane_after.txt`.

| metric | f1e5f619 | after |
|---|---|---|
| towns built | 38/38 | 38/38 |
| `rampart` (rim column with a full storey of retaining stone) | 288 (10.0%) | 91 (3.2%) |
| `rim_over` / `rim_tall_house` / `inner_over` | 0 / 26 / 1 | 0 / 0 / 1 |
| `sheer` (rim >= 2 storeys incl. plinth) | 180 | 44 |
| perimeter lane cells | 0 | 1314 |
| house plots / house columns | 765 / 2407 | 1165 / 2879 |
| decks (plaza + courts) | 39 | 34 |
| landmark prefabs (asset plots) | 58 | 20 |

(Integration had regained 26 multi-storey rim houses after the other streams'
merges; the pinned towns of `test_september29_town_edges` still passed there.
The residual `inner_over` is 8/standard: a tiers citadel landmark at ring 2.)

Renders (same cameras before/after; before = f1e5f619, on disk):
`lane_before/`, `lane_after/`, sheets `lane_compare_townA.jpg` (photo 7, far,
edge views), `lane_compare_townB.jpg` (photo 11 view, edges),
`lane_compare_corpus.jpg`, street-level `lane_street_views.jpg`
(kit_town_review `--views lane`: from each perimeter lane's first cell along
its longest straight run).

* Town A photo 7: the stone rampart with houses on top is gone; the outer face
  is single-storey cottages at grade, gables to the lawn, a lane mouth between
  them, mass rising inward. far7/edge3/edge6: a ring of low roofs, taller
  houses in the middle.
* Town B: edges 0/2 are cottage rows; edge5 keeps a stone face -- the tiers
  stream's citadel plinth (intended, "almost like a castle").
* Lane views: a paved lane with doors, window boxes and ivy on both sides.
* Corpus: 11/compact and 4/large lose their long retaining walls; 7/standard
  keeps one raised terrace wall at a plaza (residual `rampart`).

## Tests (this branch vs f1e5f619, same files)

Pass on both: september29 town_edges (5/5, new rampart test), floating_masses
(5/5), town_platform (6/6), town_build_order, skywalks, town_materials,
roofline_variety, town_public_walk_dead_ends, town_destination_agreement,
town_depth, town_closures, town_canopies, building_kit, september27_roofs.
Same failures on both: `test_warren_maze_carver` (descent pin),
`test_warren_maze_composition` (17 failing here vs 20 on f1e5f619; stale corpus
pins on both).

Changed/new here:
* `test_september29_town_edges`: new `test_the_town_meets_the_lawn_without_a_stone_rampart`
  (every pinned town lays a perimeter lane; rampart <= 10% of edges). Fails on
  f1e5f619 (no lanes; Town A 9/48).
* `test_september29_floating_masses`: the photographed-crown and cover pins
  were layout coordinates; re-pinned to Town A's realized cover (2,-4); a
  feature's own volume (a balcony over a lane) is not counted as a cover room.
* `test_september29_town_platform`: `PLAIN_SIGNATURE` re-pinned (every town is
  re-laid).
* `test_warren_maze_plots`: 37/42 vs 38/42 on f1e5f619. Passage covers are
  skipped in the one-back-room-record check (a cover is a second record of its
  host by design). NEW failures here: `the asset stands at the minimum cost
  among REALISABLE sites` (12/compact: planner 44 vs the test's own oracle 38;
  the oracle ignores bridges/door access -- adding them did not reconcile it,
  so left open) and `BUILDABLE_COVERAGE_FLOOR` 0.9086 < 0.91 (a real drop to
  report: rim columns beside the lane that no house takes).
* `test_september27_town_details`: NEW failure -- a skywalk portal post in
  7/standard crosses an endpoint window (skywalk layout moved; not fixed).

## Open (follow-up)

* Landmark prefabs: 58 -> 20 over the corpus. Their 3x3+ column sites and the
  perimeter lane compete for the same flat edge band; protecting every
  previewed site starved the lane (see table above). Needs an owner call
  (lane everywhere vs landmarks on the edge) or a landmark siting rule that
  uses the inner side of the lane.
* Decks 39 -> 34 (the plaza itself is protected by the preview).
* Market stalls lining the lane (owner's other option) are not added: the
  lawn side of the lane is the rim cottages' backs.
* `TUNNEL_OVER_MAX_LIFT` 3 -> 1 and the hanging-stone release touch the
  floating stream's rules; the gap-band retention (`_retain_maze_rock`
  releasing single cells under a lifted cover) is the real bug there.
* The plots-test oracle mismatch and the skywalk post over a window above.



---

# Second follow-up: landmark prefabs beside the lane, the plots-test oracle, coverage

Coordinator: the owner also wants more building variety, so the lane's
58 -> 20 landmark loss is not acceptable; restore landmarks near the previous
count without bringing the rampart back. Also: the `BUILDABLE_COVERAGE_FLOOR`
drop and the 12/compact oracle mismatch (planner 44 vs oracle 38).

## Root cause of the landmark loss

The lane is laid (after the spine and market, before loops and alleys) on the
second ring at grade. Landmark prefabs want exactly that band: the cheapest
realisable sites are 3x3+ rectangles on rings 1-3 at grade on the town's edge.
The plot reservation ran after the lane, found the band taken, and 38 of 58
landmarks had no site left. A landmark on the rim is 3 columns deep, so it
always crosses the lane's ring: holding its site means the lane has to go
round it, and in most towns that strands part of the ring (measured with a
faithful lane simulation: only 8 of 20 subset landmarks leave the whole ring
reachable). Landmarks and a continuous lane genuinely compete; a stranded
stretch only becomes a rampart when a raised town square cuts the ring too.

## Rules changed

* **Held landmark sites** (`WarrenMazeCarver._preview_reserved_columns`): the
  preview of the plot reservation on the streets laid so far (spine + market)
  now also holds its landmark sites: the profile's guaranteed count
  (`landmark_range.x`), each only where it stands at grade on the edge rings.
  The lane stays off them; their bands are reserved from later streets; their
  measured reach (`asset_clearance_reservations`) keeps bridge endpoint houses
  off them (`_select_bridge_spans` seeded with the held columns -- without it a
  bridge endpoint foundation took an asset column and the real reservation
  refused the site as `body_outside_plot`).
* **The lane walks round a held site** (`_perimeter_detour`): when the ring
  step is blocked, a bounded BFS (14 cells) through rings 1..5, level at grade
  and borable, finds the next fresh ring-2 cell -- outside the site along the
  rim, or round its inner face.
* **The town square is held only where it does not strand the lane**
  (`_perimeter_ring_cover`, a throwaway lane lay): a square raised on the rim
  that cuts the lane off from part of the ring leaves that stretch of rim
  houses standing on their terrace -- the photo-7 rampart -- and is itself a
  storey of retaining stone on the lawn. The real reservation may still site a
  square elsewhere.
* **Rim house height from its own floor** (`WarrenPlotPlanner._edge_limit`):
  one storey per ring above the house's floor as well (a claim cap could lift a
  rim house past it; 10/standard).
* **Edge profile in every composition clearance test**
  (`WarrenRoomCompositionPlanner._above_edge_profile`): the participant and
  pair re-partition records ignored `profile_ceiling`, so a repartitioned top
  storey overhung the lane four storeys up on the second ring (Town A
  `inner_over` at (-1,-4)).

## Measured (38 towns: A, B, 1-12 x compact/standard/large, flat ground)

| metric | f1e5f619 (no lane) | c3968a42 (lane first) | after |
|---|---|---|---|
| towns built | 38/38 | 38/38 | 38/38 |
| landmark prefabs | 58 | 20 | **52** |
| `rampart` edges | 288 (10.0%) | 91 (3.2%) | **34 (1.2%)** |
| `sheer` | 180 | 44 | 14 |
| perimeter lane cells | 0 | 1314 | 1282 |
| houses / house columns | 765 / 2407 | 1165 / 2879 | 986 / 2224 |
| decks (plaza + courts) | 39 | 34 | 20 |
| towns with a deck | 28 | 25 | 15 |
| `rim_over` / `rim_tall_house` / `inner_over` | 0 / 26 / 1 | 0 / 0 / 1 | 0 / 0 / 1 |

`perimeter_landmark_after.txt`. The four pinned towns (A, B, 3/standard,
6/large) carry 7 landmarks, as on f1e5f619 (c3968a42: 3).

Variants measured on the 13-town subset (landmarks / rampart / lane cells /
houses / decks; f1e5f619 20/136/0/230/12, c3968a42 7/26/433/389/10):

| variant | result | verdict |
|---|---|---|
| hold every at-grade previewed landmark + plaza | 16/24/222/273/11 | 12/compact became 4 landmarks + 1 house |
| + detour through ring 1 | 16/13/324/278/8 | Town A photo 7: a stone rampart under the houses (9/48 edges) |
| landmarks never on ring 1 | 10/17/424/331/9 | worse |
| raised plaza never held | 17/7/418/322/6 | planner corpus lost every deck |
| second preview after the lane | 6/11/555/397/8 | no at-grade sites left |
| landmark held only if it strands nothing | 8/14/568/397/8 | landmarks lost again |
| decks at grade on the edge rings (reservation rule) | 17/4/418/324/4 | squares vanish |
| **landmarks held, plaza held unless it strands the lane** | **17/7/420/320/7** | chosen |

Renders (before = c3968a42 `lane_after/`, after = `landmark_after/`; on disk):
`landmark_compare_townA.jpg` (photo 7, far7, edge3, edge6, overview),
`landmark_compare_townB.jpg`, `landmark_compare_corpus.jpg`.

* Town A photo 7: no stone rampart; the landmark hall and cottages at grade.
  Its raised railed square (the stone block with railings at the right of the
  before image) is gone -- it stranded the south rim.
* 4/large, 3/standard, 7/standard: landmark halls back on the edge, lanes
  running round them; 7/standard loses its raised green square.

## The plots-test oracle (planner 44 vs oracle 38): the oracle was stale

`test_assets_sit_at_the_minimum_modification_site` enumerated one door per
datum (`_fronting_doors`, the lowest-ordered street cell). The planner tries
EVERY fronting door on the band (`_fronting_door_candidates` from landings,
never a flight tread), keeps off `blocked_columns` and checks the doorway and
body against the street's public air (door access). On c3968a42 the planner's
site (4x3 at (4,-3), cost 44, cut class 1) is realisable only through its
second door candidate, so the oracle called it unrealisable and reported a
cut-class-2 site at 38. The planner was right. The oracle now states the same
facts from the same plot-free plan: landing doors, every candidate, blocked
columns, and door access through the planner's own
`WarrenPlotReservations.door_access_for` (factored out of `_place_assets`,
behaviour identical). On c3968a42 it gives 44 = 44; the test passes here.

## BUILDABLE_COVERAGE_FLOOR (0.9064 < 0.91): a denominator effect, not lost coverage

Buildable-but-unplotted columns on the four planner towns: f1e5f619 19 of
233 (0.918), c3968a42 17 of 186 (0.909), after 16 of 171 (0.906). The
absolute count FELL; the share fell because the perimeter lane bores two bands
at grade on ring-2 columns, which then no longer count as buildable (a
column needs a MIN_HOUSE_BANDS uncarved run) -- and those were columns houses
owned. 10 of the 16 are the same 3/standard summit columns (rings 6-7) that
are unplotted on f1e5f619 too. Not recovered, not re-pinned (the file says a
drop is reported, never silently re-pinned).

## Tests (this branch vs c3968a42)

* `test_september29_town_edges`: 6/6, new
  `test_landmarks_keep_their_sites_beside_the_lane` (>= 7 on the four pinned
  towns: red on f0b63782 at 3).
* `test_september29_town_platform`: `PLAIN_SIGNATURE` re-pinned again (every
  town re-laid).
* Pass: floating_masses, town_build_order, skywalks, town_materials,
  public_walk_dead_ends, destination_agreement, town_depth, town_closures,
  town_canopies, building_kit, september27_roofs, warren_maze_carver 13/13.
* `test_warren_maze_plots` 35/42: fixed the oracle test. Still failing as on
  c3968a42: coverage floor (above), floating-street pins, sloped-refusal pins,
  "standing on a roof", 12/compact sloped addressing (0.542 -> 0.400 now).
  NEW: planner towns with a plaza 2 (pin 3); "the corpus really contains
  decks" (the three bridge-planner towns lost their raised rim squares);
  "the planner corpus really does stack houses on houses" (9/standard's one
  stacked house moved).
* `test_warren_maze_composition` 17 failing (17 on c3968a42; stale corpus
  pins on both, the set shifts with every re-laid town).
* `test_september29_roofline_variety` NEW failures: Town A has no compound
  (merged) building (needs > 1) and corpus twin share 0.20 (< 0.18) -- the
  re-laid Town A is mostly lane cottages. Variety stream's pins, not re-pinned.
* `test_september27_town_details` (skywalk post over a window in 7/standard):
  the skywalks stream's.

## Open

* Squares: 25 -> 15 towns with a deck. A square raised on the rim is either
  held (and strands part of the lane: rampart) or dropped. A rule that sites
  the plaza off the edge rings or at grade there (tried as a reservation rule:
  squares simply vanish, no flat site remains) needs a massif/plaza-shape
  change.
* Roofline variety pins on Town A (compound buildings, twins) -- lane
  cottages rarely merge.
