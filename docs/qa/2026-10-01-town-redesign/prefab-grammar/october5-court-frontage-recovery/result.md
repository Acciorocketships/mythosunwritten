# Broad court and recovered inhabited frontage — October 5

The bounded court/frontage change is accepted after structural, traversal and matched visual checks. The suspected turret fragment was traced to a complete background dormer, not a damaged cap. Overall redesign acceptance remains open.

## Cause and implementation

Seven of ten reviewed towns have no eligible broad deck after carving. A study of deeper corners found a viable 3×3 site in 53/grand at macro columns (-3,7) through (-1,9), floor band 1. The deeper-cut-only candidate selected it but failed actual enclosure: only two sides retained majority room frontage. That version alone was rejected (see ../october5-court-cut-study/result.md).

The missing third-side house was not blocked by a flight or unsupported. Court address (-1,1,8) remains flat and reachable. Source tracing shows house.043 at (0,8) seeded normally, absorbed by house.041 at (0,7), then removed when the latter's final height could not fit both columns. The reserved, still-viable court frontage was never reallocated.

`WarrenPlotPlanner._fill_court_frontages` now makes one ordinary seeding/growth/height-admission pass over only committed court-house columns after main height assignment. Existing plot ownership, support, doors, street bearings and edge envelopes remain authoritative. Unique `house.court.*` ids avoid replacing existing plots. Recovery has its own audit records and does not retry the whole town or relax failures.

`WarrenPlotReservations` permits a six-band worst-corner cut only for a broad site with at least three predicted buildable sides. All other courts keep four bands. The mean excavation budget remains three bands, with complete support and no upper-street stranding. This and recovery must be evaluated together, not treated as an independently accepted excavation widening.

## Verification

- Before recovery, the exact viable-frontage regression fails; afterward it passes. The initial broad-size regression separately failed 2×2 before the candidate and passed 3×3 after it.
- Final focused runs: five tests / 74 assertions (broad finished frontages and recovery), plus three court-address tests / 16 assertions from the preceding unchanged-source run. Eight tests / 90 assertions total; no global-suite claim.
- Finished 53 square has 4/6, 0/6, 4/6, 4/6 directly adjacent inhabited fine cells on its four edges: three majority sides, compared with 2/6,0/6,4/6,4/6 before recovery. Existing 31/large remains 4/6,0/6,4/6,6/6.
- All 32 actual-player checks pass in final 53: six court crossings, twelve door approaches and fourteen bridge/underpass traversals, including reverse travel.
- Ten towns (31/large; 8,9,13,43,53,63,83,103,301/grand) preserve every one of 480 existing covered quarters at its exact ceiling height. Floating and public-air audits remain zero. The other nine towns have identical source plots.
- 53 roof audit remains 46 roofs, one old tiny roof on house.018; zero gable holes, exposed open ends, unsupported roof air, cut eaves and uncapped towers. 31 remains 55 roofs with zero such defects. These metrics do not establish that every decorative seam looks good.
- Fixed overhead and inside before/after cameras reviewed, plus all new square context views. The square replaces a narrow outer planted strip with a broader deck circulation ring, central green/well and inhabited enclosure. It is still open toward the town edge; this does not finish the requested deeper internal/upper-square distribution.

## Turret visual follow-up and corrected attribution

53's corner turret count rises 3→4. The old house.032 pose remains under renumbered house.033 at native O=(-8,13.5,-4). The new house.032 turret sits at O=(-8,9,16). Render view ordering follows payload asset type, not the tower array: **turret1 is new; turret2 is the existing, renumbered tower**. The preceding review incorrectly attributed turret2 to the new tower.

Both `turrets/53_grand_turret1_-1.png` and `turret1_1.png` were inspected. The new corner shaft, corbel and cap remain connected, and the cap matches its host's wood roof palette. The taller façades in these views still warrant broader articulation work; this is not full architectural acceptance.

The small brown detail in `turret2_1.png` is a background Suntail dormer seen beside the cone silhouette. Native geometry rays at pixels (774,286), (777,288) and (770,287) hit `suntail.roof.roof_1_cornice_w_blue`, not the cap. The first hit is native (-7.9761,21.6565,-8.3663); the cap is centred at (-8,19.25,-4). The opposite view (`turret2_-1.png`) shows the complete dormer. A matched diagnostic with dormers disabled removes the brown detail. No cap change is justified by this evidence.

An exact-native-cap clipping study (5,292 triangle-prism cutters instead of the baked inner core) also left the detail unchanged and raised build time from about 25 to 73 seconds. It was rejected and the source restored byte-for-byte. The no-dormer study was also restored byte-for-byte; production retains its dormers. Study logs and the diagnostic view are in `junction-study/`. No new production geometry changes were made during this follow-up, so the preceding candidate's structural/traversal results remain applicable.

All baseline and diagnostic substitutions restored source in finally blocks, and all jobs completed. Full façade variety, deeper internal/upper squares, prefab-generative grammar and overall redesign acceptance remain open.
