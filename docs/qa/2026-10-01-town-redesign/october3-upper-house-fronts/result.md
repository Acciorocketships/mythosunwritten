# Ordinary upper-house fronts — October 3

Ordinary houses with three or more storeys can now receive one closed projecting
room front. Previously `KitRoomProjections` admitted only embedded wall-room
houses, so the same depth never reached ordinary tall facades. Selection uses
seeded middle-storey order and the existing native frontage parts. The projection
extends 0.65 native metres (1.3 world metres), with a floor, ceiling, side returns,
beams and joint brackets. Each selected ordinary-house bay receives a window.
Embedded wall-room behavior remains separate and retains its prior opening rule.

The proposal requires a room below and an upper closure, preserves doorways,
and rejects public-air, neighboring-room, native-part and tower conflicts.
It now also rejects contact with its own lower-wing roof. A regression fixture
covers that previously ignored obstacle. One accepted front per ordinary house
avoids repeating an identical projection on every floor; long fronts leave
flush shoulders around a smaller selected bay.

## Iteration and evidence

The first eight-town candidate placed 16 fronts. Adding the own-roof guard
reduced that to 13. A close render then exposed a broad blank panel within a new
front, so ordinary fronts now give every bay a window. Final exact-code survey
retains 13 fronts: 11 ordinary-house fronts and two existing embedded-wall fronts.
All eight towns build; floating-mass and roof/public-air audits are zero.
The corrected inhabited street coverage remains 328 quarters, unchanged from
the stable-building-draw baseline. This is a facade-depth improvement, not an
increase in enclosed streets.

| Town | Projecting fronts | Covered street quarters |
|---|---:|---:|
| 7/standard | 1 | 36 |
| 13/large | 1 | 36 |
| 31/large | 1 | 18 |
| 43/grand | 4 | 68 |
| 58/large | 2 | 14 |
| 101/large | 0 | 24 |
| 103/grand | 0 | 40 |
| 211/grand | 4 | 92 |

Nine targeted tests / 82 assertions pass (room projections and climbing support).
Actual-player traversal on 43/grand passes all ten directed skywalk/underpass
walks. The isolated real-terrain production test passes 1/1, 125 assertions,
with generation at 6,799 ms against the unchanged 8,000 ms ceiling. No new
full-suite or full-world art acceptance is claimed.

The review harness now offers `--views projections`, recording cameras near
actual accepted fronts. `native/` contains initial, often occluded captures;
`close/` follows roof avoidance but precedes the final all-window rule. `final/`
contains the exact retained 43/grand views. The paired projection2 views and
projection3 negative-side view show closed returns, windows and brackets.
Some cameras enter neighboring geometry; those frames are not acceptance proof.
The overview still shows tall simple facades and insufficiently varied compounds.
That broader architectural problem, stronger massif enclosure and Gothic stone
composition remain open.

The enclosure probe was repaired after an earlier formatter pass misindented
lambda expressions and the final output/quit block. It now uses explicit loops,
includes enclosed skywalk storeys, and records accepted room fronts. Do not
format this harness without validating its parse and a multi-town run.
