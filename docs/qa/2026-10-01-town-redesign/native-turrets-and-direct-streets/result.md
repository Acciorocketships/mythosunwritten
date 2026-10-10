# Native turrets, facade depth and direct streets — October 2

This continues the owner's marked 24/large overhead review. The original full redesign remains active; this is a tested architectural and access increment, not a claim that every remaining art/performance gate is closed.

## Prefab findings and implementation

The original Pure Village House_11c, House_16c and House_7b assemblies were inspected from front/back and their module transforms measured. Suntail's eight house prefabs were measured; House_1, House_4 and House_8 were also loaded directly from the original source and rendered. That source-only GLTF study reported missing imported texture references, so use it for composition, not material acceptance. Production images use the existing baked catalog.

The source grammar combines different roof wings, inset lower walls carrying supported upper rooms, native projecting window assemblies, and half-round stone towers transitioning to a full upper window course and conical roof. The implementation uses those existing pieces, original materials and measured envelopes.

- `KitTownTowers` admits seeded attached towers only with complete backing, intact doors, a matching closed gable, and clearance from finished walking air, other buildings' measured pieces, other towers and unrelated host roof wings. The entire native cap and corbel count toward clearance. `KitTowerHostFit` adjusts only the attached wing and its covered openings/dressing. Native cone cores cut the host roof; per-placement cutters now bypass the shared roof cache so earlier uncut geometry cannot leak into emission. Native courses retain catalog collision.
- `KitTownFacadeBays` fits supported projecting windows to long upper facades where the conservative route-column reservation had suppressed them. It checks finished headroom, private/structural reservations, existing projecting bays, towers and neighboring kit pieces. Doors survive; conflicting candidates are rejected whole. Repeating the pass is idempotent.
- Transverse end pavilions now apply to medium and broad ranges (including 5x2, 6x3 and 6x4 crowns), keeping at least two modules in both wing dimensions. Wider wings check roof reservations and taller neighboring gables. A seeded minority stays simple. Free square crowns favor the less-used town ridge direction while retaining their own seeded choice and geometric constraints. This repairs the reopened photo-town ridge-variety regression without changing its assertion.
- A new Suntail tight-eave role uses the complete existing straight slope plus matching native barge trim when the curved cornice intrudes into stair headroom. This repairs the reopened photo-town cut-eave regression without relaxing walking clearance or the roof audit.

## Streets

Perimeter lanes and their detours avoid reserved gardens. Existing entrances count toward the gate quota, and necessary gates are reserved before optional building envelopes. District access now uses a shortest legal connection without inheriting the four-cell straight-run cap of dense alleys. The cap had forced two extra cells and sideways jogs in a straight ten-cell open corridor; the red/green fixture now reaches the ten-cell lower bound. Planting cores, reservations, ground level, passage width and existing walk connections remain constraints.

This removes unnecessary garden circuits and artificial turns; some longer links remain because they serve separated inhabited districts within the legal field domain. The 17/large open-town view is deliberately included alongside wooded 24/large rather than selecting only the most favorable image.

## Verification at this checkpoint

- Roof grammar and September 29 variety: 12/12 tests, 7,828 assertions. Both reopened photo-town regressions are green.
- Integrated finished-roof clearance, build-order determinism, tower admission/emission/collision, facade bays, eaves and facade/roof contacts: 22/22 tests, 1,471 assertions before the final direct-road adjustment. Six finished-roof towns had zero walking-air triangle intrusions.
- Final direct-access and central-green checks: 6/6 tests, 171 assertions. Final production-size source sweep: 60/60 valid, all sampled districts inhabited (11 central-green towns).
- Native final renders: 13/large, then 17/large and 24/large after direct-road adjustment. 13 has two attached towers; final 24 has two. Native tower close view inspected for host/cap joints. Gallery overhead and street views inspected for roof forms and routes.
- Actual-character and final post-road roof-clearance reruns are recorded below when finished. Timing requires a quiet final production run; concurrent native generation timings are not benchmark acceptance.

The requested richer grammar is now present in ordinary generated towns, but further holdout art review, remaining large masonry faces, broader streaming/memory acceptance and full regression classification remain part of the original goal. No seed or coordinate special cases were added.

## Final post-road checks

The final six-town finished roof audit passes 19/19 assertions with zero walking-air triangle intrusions. The actual character passes all three published district-access routes in both directions (6/6); this count is routes tested, not a claim about every possible walk in the town. The close facade-bay view was inspected after emission, including its supporting assembly and neighboring gallery.

After every competing Godot process finished, the real-terrain production test passes 149/149 assertions: 6,533 ms against the unchanged 8,000 ms limit (calibration median 130 ms; factor 1.0). This is the existing production-site gate, not a universal all-town generation or rendering guarantee. All processes from this pass are terminal. `git diff --check` is clean. No commit or PR was created.
