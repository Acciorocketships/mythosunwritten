# Destination-owned terminal stairs — P14 and P22

Accepted September 14 for the two reported empty upper stair/deck configurations.

The source planner previously retained the end of its elevation spine even when subsequent plot allocation placed every entrance below it. P22 also expanded that unused end into a two-by-two lookout. P14 retained two upper flights and a timber-faced supporting mass after issue 13 removed the unsupported lawn.

`WarrenMazeSitePlanner.finish_public_destinations` now runs after actual plot allocation and before sealing. It withdraws complete terminal transitions above the highest destination, including their optional empty lookout. Actual entrances, public deck destinations, gates, civic reservations, ordinary lane connections, loop connections and occupied spans protect their approaches. A fresh excavation retains the already released negative space; source ownership and ordinary surface/support generation then produce the lower endpoint and its guards. There are no photo coordinates, seed exceptions or rerolls in the production rule. The native house plots and their entrance addresses remain unchanged.

## Evidence

- `red.txt`: original behavior fails both photographed destination invariants, reaching band 3 above P14's highest entrance at 1 and P22's at 2. The intervening parse-error attempt is not credited as the red reproduction.
- `focused-final.txt`: eight destination and shared-stair tests, 99 assertions, pass. Upper entrances, exits and connecting lanes retain their complete approach.
- `related.txt`: 18/21 tests, 2,323/2,326 assertions. `related-baseline.txt` reproduces the same three carver failures with an isolated original-planner fixture: outward descent, dictionary-order signature and old parcel-count floor. No test threshold was changed. The original carver results are 10/13, 2,224/2,227 assertions.
- `matrix.json` / `matrix.txt`: 48/48 constructed towns. All 11,764 retained public positions and 16,891 crossings are clear and connected. Relative to issue 13, 104 positions and 144 crossings belong to withdrawn unused branches. The same 25 conservative off-center pillar contacts remain, with zero reported intrusion.
- `composition.txt`: fingerprinted gate passes 95/95 assertions.
- Native collision surveys: P22 changes from 112 positions / 163 crossings to 92 / 132; P14 changes from 76 / 108 to 56 / 82. All retained positions and crossings are clear. Counts are intentionally different because the unused routes are removed.
- Twenty-four inspected matched pairs and pixel differences: each town has three native photo/nearby views, six native orbit views and three frozen full-game views. `visual-review.json` records judgments. The orbit checks expose every side of the removed structures. The remaining guards and native house approaches stay coherent, with no new floating support or open terrain gap observed.

P22 uses world seed 2697992464, player (-227.9,18.1,422.1), crosshair (-230.8,18.8,425.1). P14 uses player (1233.9,24,521.1), crosshair (1225.9,24,541). Cameras use `ReviewCam.solve_cam` from those rounded original overlays. P14's baseline is the accepted issue-13 world, not the earlier floating-lawn version. Frozen replays share lighting and animation controls; fresh world captures verify actual regeneration.

Cold startup remains expensive: P22 before 289.024 seconds, after 297.987 seconds; P14 after 307.318 seconds, versus issue 13's 308.340-second snapshot. Concurrent diagnostics and host variability prevent a performance conclusion. Snapshot capture emits the existing editor-API warning, and frozen lighting emits existing owner warnings; inspected frames are valid, not black. This accepts the reported stair purpose repair, not all village design, terrain, streaming or renderer behavior.

![P22 matched comparison](game-contact.png)

![P14 matched comparison](P14/game-contact.png)
