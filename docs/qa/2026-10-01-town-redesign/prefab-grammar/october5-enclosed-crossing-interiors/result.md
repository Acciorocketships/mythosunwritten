# Enclosed crossing interiors

## Repair

Frozen experimental 43/grand's blue strip above the far doorway was a **facade canopy**, not the crossing's main roof. The earlier minimum-headroom rule removed a lower obstruction but admitted `kit.spatial.parcel.maze.house.wall-room.000/k0045` above walking clearance. `KitPublicClearance.skywalk_ornament_air` now protects the complete room height of enclosed crossings and their endpoint bays. Open crossings still reserve only walking headroom. This remains an ornament admission rule, never a wall/roof cutter; complete canopy assemblies are omitted atomically.

Enclosed bridge masses also request a ceiling. `BuildingKitAssembler` uses the existing native `deck.board` pieces at the upper storey band to close the attic, skipping cells already supplied by an upper room's floor. The same kit/finish supplies the interior timber. Roofs, spires, floors and crossing layouts are retained. Open bridges have no new ceiling.

The initial ceiling-only version improved the reverse view but did not remove the blue strip. An exploratory equal-height neighbouring-room roof cut also failed to change that visible strip. It was removed from production after the canopy was identified; its patch and isolated test are archived as an unretained study. Do not confuse its passing geometry assertion with validation of the final repair.

## Native evidence

Fixture: `tests/fixtures/october5-skywalk-hood-source.txt`; the experimental court route remains archived.

Matched cameras, FOV75:

- `skywalk-clear`: eye(4,10,-56), target(18,7,-56).
- `skywalk-reverse`: eye(14,9,-56), target(4,9,-56).

`after/` is the final source, after removal of the unrelated roof-cut experiment. Both views show a boarded ceiling and the blue canopy is absent. The overview preserves the exterior composition. Intermediate `ceiling-only/` and `unretained-roof-cut/` views document why those versions alone were insufficient.

## Checks

- Red-first ceiling test fails on all four width/orientation cases; the final version passes measured native-board coverage and player-headroom checks. Open crossings remain open.
- Strengthening the frozen canopy test from minimum headroom to complete enclosed-room height reproduces the exact remaining k0045 obstruction (1 failed assertion).
- Final focused suite: **8 tests /31 assertions pass**, covering ceiling geometry, frozen canopy clearance, supported enclosed span endpoints, soffits and porch attic closures.
- Final actual-player run: **8/8 crossing and underpass traversals pass**, including both directions. See `skywalk-interior-walk.json`.
- Earlier exploratory roof-cut suites and holdout audits are retained only as diagnostic records, not claimed as final-source coverage.

This repairs the visible bridge-interior defect. It does not promote the larger interior-square layout or add crossing/spire supply. The original goal remains active, including square layout acceptance, spire opportunities and whole-town art review.

Active falsification: disabling both repairs reproduces two failing tests. Matched baseline images are in `before/`; final source restored by the experiment’s `finally` block.
