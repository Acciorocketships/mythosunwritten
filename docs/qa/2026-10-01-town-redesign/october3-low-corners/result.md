# Short grounded corner turrets — October 3

Retained after native review. This extends the corner system to lower wings and
small houses; it is not completion of the full redesign or tall compound grammar.

## Change

A short building had been categorically excluded by both the town proposer
(minimum two storeys) and corner fitter (minimum four bands). One native window
course plus its quarter-metre-lapped cap is a complete grounded short turret.
It now competes at actual convex corners, under the same full-footprint bearing,
public air, neighbour, opening and other-tower checks. Single-storey houses have
a seeded 30% proposal share; admission remains geometrically constrained.
Existing multi-storey selection is unchanged. A short shaft uses the window
course itself at ground level, not a blank course with a cap perched on a roof.

Diagnostics disproved the tentative inset explanation: the examined host-join
failures were mostly inconsistent corner occupancy, with some doors and shifted
storeys. No inset, door or clearance constraint was relaxed. No seeds are
special-cased and the previous rejected inward-corner rule remains absent.
Cap materials still follow the adjoining wood/slate roof family.

## Validation

Nine targeted tests / 5,065 assertions passed, including actual generated short
turrets, complete cap collision, intentional missing-cap failure, public air,
full-foot bearing and material/geometry invariants. Existing five-town corner
count rises from 1 to 12, appearing in four rather than one of five towns.
Public-cell and inhabited overhead-coverage counts are unchanged in each town.
Three further towns also build. These are measured construction audits, not
universal assertions about unseen seeds.

| Town | Corner towers | All towers | Floating masses | Roof/public-air intrusions |
| --- | ---: | ---: | ---: | ---: |
| 101:large | 4 | 4 | 0 | 0 |
| 103:grand | 2 | 2 | 0 | 0 |
| 13:large | 2 | 2 | 0 | 0 |
| 31:large | 0 | 0 | 0 | 0 |
| 43:grand | 4 | 5 | 0 | 0 |
| 211:grand | 4 | 8 | 0 | 0 |
| 58:large | 2 | 3 | 0 | 0 |
| 7:standard | 1 | 1 | 0 | 0 |

Native controlled low-course fixture (`gallery/`) and generated 13/large and
43/grand (`native/`) reviewed: the shafts meet real corners, roof caps match,
and window courses remain visible. Inspected 13 tower0/1 front views and 43
new tower2/4 front views, plus the fixture. Earlier tiny Pure eave-fragment
cleanup is still open; this pass did not change its clipping.

Actual-player covered-street traversal in 13/large passes both directions
(`player.json`), with the new tower collision present. The isolated real-terrain production gate also passes (1/1, 125 assertions;
6,776ms town build in `production.log`, unchanged 8,000ms ceiling). No full-suite or streamed
world acceptance is claimed. The harness's plain surroundings omit production
terrain grass/dressing and are not a vegetation acceptance image.

## Remaining architecture work

Tall corner towers integrated with lower wings still need joint planning.
Whole-compound palettes, additional wood/green/stone families, Gothic composition,
massif enclosure and the main plan's final multi-seed art/world review remain
active. The successful short-course variation does not substitute for them.
