# October 3: excavation clearance and inhabited street coverage

Status: promising experiment, NOT retained in production yet. The worktree's
WarrenExcavation and WarrenSpatialFabricCompiler were restored exactly to their
pre-experiment contents. `candidate.patch` preserves the tested rule. The generic
`--covered-cell x,y,z` actual-player harness mode is retained.

## Root finding

WarrenExcavation reserves three bands while WarrenVolumePlan and transition
clearance reserve two. At current production scale these are nine and six world
metres respectively; actual finished-route minimum headroom remains 2.4 m.
The candidate makes excavation use the existing volume contract. Flight swept
volumes, public-air checks, bearing proofs and roof intrusion checks are unchanged.

Finished inhabited room coverage, measured in four quarters per source street
cell (not merely source tunnel labels):

| Town | Public cells before/after | Covered quarters before/after |
|---|---:|---:|
|13/large|67 / 69|24 / 28|
|31/large|39 / 39|8 / 12|
|43/grand|89 / 98|24 / 72|
|101/large|59 / 59|16 / 8|
|103/grand|82 / 82|32 / 28|

Aggregate coverage is104/1344 ->148/1388 quarters,7.74% ->10.66%. This is not
an every-town improvement and still does not satisfy the full enclosure goal.
Source natural tunnel counts rise7/2/12/1/5 ->11/6/19/6/10. Do not conflate
these labels with the finished inhabited coverage: the new covered13/large
street at(2,0,-4) is verified from its actual finished rooms, not a tunnel label.
All five candidate builds have zero floating-mass and native-roof/public-air
intrusions under the existing audits.

## Native judgment and traversal

Matched `before/13_large_town13.png` and `candidate/13_large_town13.png` show
an open alley becoming an inhabited underpass with a full timber ceiling and
daylight at the far end. `43_grand_lower.png` likewise gains lower, closer
coverage. The upper custom camera faces a doorway on both versions; those
images are not evidence of upper-street enclosure. Overviews remain dense and
retain apartment-like massing, so the full architecture is NOT accepted.

Actual candidate13/large player:8/8 existing skywalk/bridge/underpass directions;
new exact covered-cell walk2/2 directions. Results are `player13.json` and
`covered13.json`. The new harness walks only published opposite route edges,
never a guessed geometric shortcut.

Focused candidate contract:2/2 tests,18 assertions. It verifies agreement of
clearance contracts, all four finished room quarters above each of two newly
covered streets, bearing and native roof clearance. The reusable study is
`tests/harness/suntail/bore_headroom_contract.gd`; it intentionally is not an
automatically discovered production test while the rule remains deferred.
The first test draft incorrectly required a natural-tunnel label; it failed,
and was corrected to require the real published passage plus finished rooms.

## Why the candidate is deferred

Related projection/hood/landing tests:9/10,173/175 assertions.58/large fails
construction: `spatial.maze_back.13.room00` exposes five PRIVATE roof faces in
an L. Exact native tiling explores11 states but its private gable vocabulary
has only2/4/6-cell pieces. Every arrangement leaves one private cell. This is
an actual missing roof grammar, not a clearance obstruction. `odd-crown.json`
records the precise fixture. Temporary diagnostic prints were removed by exact
compiler restoration. The previous projection corpus also no longer admits a
projection; that coverage must be restored/proved on the completed candidate.

Carver suite:12/13 tests,2089/2094 assertions. The five failures are all in the
spine-descent test. Running that test on the prior rule reproduces the same
five failing requirements (small-town descent/turning, mean outward gain,
aggregate descent); numerical means differ. No green full-suite claim.
Four-world-seed production records build, but the corpus verifier rejects two:
991177 lacks typed occupancy role4,3046246887 shares4242's normalized route.
Both exact failures also occur before the change. `production-before.json`
and `production.json` retain the full evidence; do not call this corpus green.

## Next concrete implementation

1. Add a complete native solution for an odd private crown corner, with real
   roof surfaces/closed exterior ends and proper adjoining-mass seams. Inspect
   existing pack corner/shed pieces or derive a finite cropped native corner;
   do not substitute a flat public deck or waive the roof coverage gate.
   Existing partial-gable recipes live in SettlementFabricProgram; their source
   compact roof derivatives are in low_poly_fantasy_village_fabric.json.
2. Exercise the recorded five-cell L and holdout odd crowns, then reapply the
   shared two-band rule. Rebuild58/large and re-prove wall-room projections.
3. Recheck native junctions, private/public clearance, actual lower AND upper
   route traversal, wider generated corpus and quiet production timing.
4. Continue actual enclosed climbs/canopy, nonrectangular massing and all
   remaining October1 plan goals. This experiment does not complete them.

No live jobs, commit or PR remain at this checkpoint. Previous retained room
projection and skywalk fixes remain intact. No fresh production timing or
world-streaming acceptance claim for this experiment.
