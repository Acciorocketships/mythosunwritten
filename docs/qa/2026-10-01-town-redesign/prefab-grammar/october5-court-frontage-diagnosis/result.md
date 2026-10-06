# Finished court frontages — October 5 diagnosis

Previous goal turn: progress (native supported corner turrets accepted). This turn adds a reusable finished-court diagnostic and identifies a specific missing planning contract. No production layout change is accepted or claimed.

`tests/harness/suntail/court_frontage_probe.gd` builds six complete towns, measures occupied house storeys at each court's walking band, and separately tests native facade triangles with the existing `native_facade_enclosure` helper. It records nearest walls up to six fine modules away, adjacent source plots, their floor/top, raw massif height and passage bands. Roofs and private reservation boxes are not treated as occupied rooms. Native facade detection covers the helper's wall/window/door vocabulary, not arbitrary decoration or every possible prefab surface. Occupied room cells are a planning proxy; this is not a substitute for native art review.

The table counts boundary samples with a room or measured native wall within three fine modules (direction order +X,+Z,-X,-Z). Broad dimensions and enclosure both fail: nine of ten decks occupy only four macro columns; the remaining deck occupies six. No existing court has a three-module minimum side. Raised plazas in 53 and 301 stand at band 6, above several neighboring houses' occupied rooms. The neighboring plot's `top` includes roof reservation and must not be mistaken for a room reaching that height.

| Town | Court | Macro area | Floor band | Nearby inhabited boundary samples by side |
|---|---|---:|---:|---|
| 103:grand | plaza.00 | 4 | 0 | 2/4, 0/4, 0/4, 2/4 |
| 103:grand | deck.00 | 4 | 0 | 2/4, 0/4, 0/4, 0/4 |
| 301:grand | plaza.00 | 4 | 6 | 0/4, 2/4, 0/4, 0/4 |
| 31:large | plaza.00 | 4 | 2 | 0/4, 0/4, 0/4, 0/4 |
| 53:grand | plaza.00 | 4 | 6 | 0/4, 0/4, 0/4, 2/4 |
| 53:grand | deck.00 | 4 | 2 | 0/4, 0/4, 0/4, 0/4 |
| 53:grand | deck.01 | 4 | 2 | 0/4, 0/4, 4/4, 2/4 |
| 63:grand | plaza.00 | 6 | 4 | 0/4, 0/6, 0/4, 4/6 |
| 63:grand | deck.00 | 4 | 0 | 2/4, 4/4, 2/4, 0/4 |
| 83:grand | plaza.00 | 4 | 0 | 4/4, 0/4, 0/4, 0/4 |

## Binding contract found

- `WarrenPlotPlanner._seed_buildings` enumerates only `walk_order(plan)`, which contains excavation route/lane/passage cells. Deck footprints are absent.
- `street_bands` likewise contains passage cells only.
- `WarrenMazeSourcePlan` rejects a house or asset whose `door_walk` is not in `passage_kinds`. A square cannot currently supply a house address merely by being a connected walkable deck.
- `_preview_reserved_columns` protects the square footprint against later carving, but not surrounding inhabited frontages.

Consequently, increasing square area or preferring raw massif neighbors cannot by itself ensure houses at the square's own level. The rejected earlier ranking experiment should not be repeated.

## Next implementation

Introduce court-boundary addresses as real connected public destinations, with the court's existing entry and level floor providing reachability. Carry those addresses consistently through source door validation, plot seeding, destination pruning, composition door placement and player traversal. Plan at least three suitable surrounding frontage runs together with a broad court, including raised courts, while preserving existing below-court bores and exact inhabited route coverage. Do not merely add imaginary passage cells or weaken the door validator. Pin a real raised court before changing this contract; judge finished frontages and a matched native view after construction.

The initial room-only probe and corrected native-aware six-town probe both completed normally. The macOS certificate warning is unrelated to scene generation. No production source swap or live process remains. Broad internal squares, more covered routes and full art acceptance remain outstanding.
