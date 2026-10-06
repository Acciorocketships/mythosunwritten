# Interior citadel climbs, October 4

Status: implementation checkpoint; the full town redesign remains open. No seed-specific placement rules were added.

## Behavior

`WarrenPlatformStreets.carve_gate` first searches for a route entering the district below grade and climbing within it. Acceptance requires a complete stair path to upper grade and at least one retained entrance ceiling with two solid neighboring supports. The ceiling test uses the complete swept stair slot, including intermediate rises. The selected lateral load paths are reserved against later excavation. Ordinary alleys still cannot bore through platform foundations. The previous exterior flight remains the fallback where an interior route cannot fit (including 31/large).

Nested districts are entered in height order: a climb can bore only the next plinth height, not a taller district's foundation. Without this constraint, 13/grand produced an unsupported room; it is fixed and the finished town now builds. Fortification occurrence itself is unchanged.

`WarrenMazeCarver` retains explicitly proved gate ceiling cells rather than treating every flight as open to sky. `WarrenPassageLatticeRules` exposes the exception only to the gate planner; ordinary level platform tunnels retain their original ceiling restriction.

## Collision and visual repair discovered by traversal

103/grand initially ascended into a stone block. A temporary character trace (removed afterward) identified `pure_village_stone_block_4`, rather than the stair tread, as the raised movement obstruction. `KitPublicClearance.fit_decor` now checks native fortification trim against the exact public tread prisms, removing whole conflicting assets and their collision.

An intermediate render exposed floating merlons when their supporting parapet base alone was removed. `BuildingKitAssembler._emit_parapet` now groups each base/merlon assembly; clearance omits the complete group. The final upper-entry image was inspected and those floating blocks are absent. The structural wall remains, and ordinary public guards continue to bound exposed walking edges.

## Verification

- Final source-plan survey: 32/32 plans build; 13 interior climbs in 12 towns. Thirteen towns in that corpus have gate routes at all. This is a planner survey, not a claim that all 32 finished towns received visual or character review.
- Six tests / 940 assertions pass (`test_interior_citadel_gate`, `test_october1_facade_prop_clearance`). The tests exercise swept ceiling clearance, final structural ceilings and headroom, nested-tier boundaries, complete parapet omission, and existing facade dressing clearance.
- Finished 63/83/103 grand towns: no floating-mass or roof/public-air intrusion failures; roof audit has no exposed open ends, gable holes, unsupported roofs or clipped eaves. Nested 13/grand separately builds with zero floating/public-air intrusions.
- Final geometry: 14/14 actual-character ascents/descents pass across grand seeds 63, 83, 103, 2 and 13, including both climbs in each nested-tier town. Results are in `player-walks.json`.
- Matched 83/grand renders compare the same seed and camera configuration before/after the gate change. The gate-relative street cameras follow the relocated gate, so those are route comparisons, not fixed-camera pixel differences. The upper exit is now flanked by inhabited facades and structure overhead. `interior-stair.png` shows the climbing channel between walls, with daylight above the emerging stair.

## Limits and remaining work

This does not finish the requested art direction. Seed 31 still needs better enclosure on its exterior fallback climb. Broad blank retaining faces, long rooflines and some tall flat house fronts remain visible in the wider views. The lower entrance ceiling is structurally tested and visibly closed in the upward-looking `entrance-ceiling.png`; the forward stair view naturally looks out from under it into daylight. Global performance and the full historical test suite were not rerun in this checkpoint.
