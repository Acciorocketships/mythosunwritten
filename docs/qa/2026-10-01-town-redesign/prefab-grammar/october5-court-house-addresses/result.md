# Houses addressed to connected courts — October 5

The preceding goal turn was progress: it identified a missing court-address contract. This pass implements that contract and validates it through constructed houses and actual player traversal. It does not complete the requested broad internal town squares.

## Change

`WarrenMazeSourcePlan.court_addresses()` flood-fills level court floor columns from genuine public landings or a proved court access flight. Disconnected courts and stair cutouts are excluded. Houses may address those connected floors without inventing excavation passages. `WarrenPlotPlanner.walk_order` offers the addresses to house seeding in deterministic order. Existing growth, height, support and clearance rules remain.

`WarrenMazeVolumeAdapter` passes the addresses through `WarrenExcavationVolumeAdapter` before volume sealing. The parcel translator proves each exact fine-grid threshold against the existing deck paving set, excluding planting and stair cutouts. It does not treat a macro address as proof of a floor. Paving remains owned by the existing deck compiler; no duplicate surfaces or walk nodes are created.

New regression suite covers the real raised 301/grand court, disconnected courts, absent upper floors, actual translated parcels and exact doorway landing support. The player harness gains `--court-doors` to approach real built door thresholds from adjacent court floors; town-entry access is checked separately by `--courts`.

## Tests and comparison

Red-first test: 301/grand's four court columns were absent from house seeding (1 test, 3/4 assertions). Final focused suite: 3 tests / 16 assertions pass. Initial incomplete candidates failed parcel translation, first at volume frontage and then at exact public-floor proof; both gates were integrated rather than bypassed.

Plot suite: candidate and temporarily restored baseline both pass 39/42 tests and 3,821/3,924 assertions. Failure summaries are identical apart from elapsed time: asset catalog template expectations, minimum-modification asset site, and pinned buildable coverage. No repinning. Baseline source swap completed and restored all five candidate files.

| Town | Covered quarters before | After | Floating masses | Roof-air intrusions |
|---|---:|---:|---:|---:|
| 31/large | 22 | 22 | 0 | 0 |
| 53/grand | 76 | 84 | 0 | 0 |
| 63/grand | 22 | 38 | 0 | 0 |
| 83/grand | 16 | 16 | 0 | 0 |
| 103/grand | 40 | 40 | 0 | 0 |
| 301/grand | 44 | 44 | 0 | 0 |

All 220 prior covered quarters remain at the same or closer overhead height; the total grows to 244. Source tunnel counts and new dedicated bridge counts are not claimed to increase. The added rooms cover existing passages. Four holdouts also build with zero floating/roof-air failures: 7/standard 36→36, 43/grand 44→48, 201/large 64→64, 503/grand 36→36 covered quarters. These holdout totals do not substitute for exact route-by-route comparison.

Actual player checks: raised 301 court from town entry both ways, new court door threshold both ways, and newly covered 63 passage (-2,0,3) both ways — six requested traversals pass. An earlier malformed `--covered-cell=` command ran the default gate route instead; it is not counted as underpass evidence.

## Native review and limitations

Reviewed all four 301 court angles and matched before views 2/3; the new occupied facade and door face the raised court. Reviewed angle 2 of all five courts in 53/63. Additional captured angles are retained but not claimed as inspected. The new facade is real, correctly roofed and accessible. This is bounded structural progress, not full court art acceptance.

301 loses its previous courtyard tree. Follow-up diagnosis in `../october5-irregular-court-planting/result.md` establishes that the doorway leaves an L-shaped three-cell planting bed, rejected by the old 2x2-block search before measured tree clearance. The initial attribution to roof clearance was incorrect. Its green floor is now bare apart from a lamp. Several squares still face the countryside; 53's new small frontage alone is not an enclosed square. Court footprints remain too small and are not relocated inward by this change. Future court planning must reserve a broader floor, at least three inhabited frontage runs, and durable tree/planting space together. The tower/apartment-like tall facades and broader art requirements remain open. Do not report this as completion of internal squares or the full town redesign.

All listed test, render and traversal processes finished; no temporary source swap remains.
