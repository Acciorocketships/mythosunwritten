# October 3: inhabited bridge clearance; enclosure experiments rejected

Status: narrow collision-prevention repair retained. Neither architectural
experiment passed the combined geometry/visual review. Embedded projecting
wall rooms, more inhabited bores, and enclosed climbing streets remain OPEN.

## Retained change

`KitPublicClearance.inhabited_bridge_rooms` protects the bridge room and its
two actual support rooms at the shared passage floor. These are private room
cells, so the exterior public-floor mesh does not describe their internal
through-route. Complete native tower envelopes must now clear these rooms.
These reservations reject optional shafts only; they are never roof/wall cutters.
No route, room footprint, support, doorway, terrain or source-volume rule changed.

An architectural candidate exposed the problem during actual-player testing:
13/large's new turret shaft blocked the upper route at z29.85/34.15. The slide
collider was `pure_village_roof_turret_middle_0337`. The baseline passed the
same walk. Adding the private-room reservation restored both directions. The
architectural candidate was subsequently rejected on visual grounds, but this
independent clearance rule also excludes two unsafe shaft proposals in the
unmerged 43/grand town. Current native tower totals: 13/large4,31/large1,43/grand5
(previously4,1,7). Existing native towers remain where their complete volumes fit.

## Rejected source-selection experiment

Prioritizing thicker interior source mass over exterior depth shifted bridge
placement rather than reliably adding enclosure. A new probe measures actual
finished inhabited storey footprints above each quarter of every source walk
cell. It does not count source tunnel labels as successful enclosure.

| Town | Baseline covered quarters / full cells | Interior priority |
|---|---:|---:|
|13/large|24 / 6|28 / 7|
|31/large|8 / 2|8 / 2|
|43/grand|24 / 6|24 / 6|
|101/large|16 / 3|16 / 3|
|103/grand|32 / 7|24 / 6|

103 lost upper coverage while gaining a lower span. Both ranking variants were
rejected. `WarrenMazeCarver.gd` is byte-identical to its turn-start snapshot.
Candidate patch and JSON measurements are archived here; `candidate/` renders
are rejected evidence, not production output.

## Rejected architectural merge

Joined each proven bridge body and both endpoint houses into one kit building,
bounded by existing compound-size and common-floor-phase rules. Six compounds
formed across the five towns. Original cells, doors, grounding and measured
overhead room coverage survived; focused topology/geometry checks passed.

The isolated result appeared coherent, but matched native street views exposed
a worse tradeoff: a projecting endpoint roof volume disappeared, reducing the
lane's enclosure and revealing more fragmented neighboring blue roof edges.
That fails the owner's architectural priority even though the route passed and
the structural metrics stayed equal. The entire merge and helper refactor were
reverted. `merged-rejected/`, `merged-isolated-rejected/`, `compound-towns/`
and `compounds/` are rejected candidates. `baseline/` is the matched prior shape.

## Validation of retained code

- New bridge-room clearance suite:2/2,143 assertions,55.28s. Includes three
  real towns, native tower envelopes, public roof air, floating-mass checks,
  both endpoint rooms, and keeping reservations out of roof cutting.
- Existing roof-turret suite:3/3,3,091 assertions,29.879s on retained code.
  An initial new-test constructor error prevented that new script loading;
  it was repaired and rerun separately to obtain the2/2 result above.
- Final retained13/large actual-player walk:8/8 directions, including two
  exterior skywalks, the inhabited source bridge, and the street beneath it.
- Matched43/grand actual-player comparison: baseline4/8, retained6/8. Both
  directions through `source_bridge.00` failed against native turret shaft
  colliders before the repair and pass afterward. The second exterior skywalk
  and underpass pass in both versions. Exterior `skywalk.0` fails identically
  in both: forward hits `suntail_stair_wooden_railings_1` near(21.47,12.26,-16);
  the expected landing at(24,12,-16) has no floor, and reverse falls to y6.26
  against a timber frame. This pre-existing landing/guard issue is OPEN and
  is not counted as a passing town. Source/carver geometry was not changed.
- Native retained13/31/43 overviews and turret views generated. Reviewed43's
  skyline and shaft junction; five towers survive, and the broader flat-front /
  exposed-boardwalk criticism remains visible. This is not art acceptance.
- Experimental merge checks (not retained-code claims):1/1,172 assertions;
  skywalk/build-order/turret regression9/9,3,100 assertions. One attempted
  filtered run used GUT's script filter incorrectly and ran no tests; its
  corrected compound filter is separately logged.
- No fresh full-suite, production timing, or world-streaming claim.

Next enclosure attempt should retain existing overhead rooms and native roof
projections while adding independently supported interior covers. A higher
source count or cleaner isolated building is insufficient if the finished
street becomes more exposed. The requested shallow inhabited wall facades
need a reserved room/return/shed-roof volume, not a detached house or an applique.

Probe: `tests/harness/suntail/inhabited_enclosure_probe.gd -- --cities
13:large,31:large,43:grand,101:large,103:grand --output FILE`.
Player: `tests/harness/suntail/nested_gate_walk.gd -- --seed 13 --profile large
--skywalks --output FILE`.
