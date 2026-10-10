# Remote wings on skywalk hosts — October 5

Accepted a local architectural rule: a house with a skywalk doorway may lower a remote wing while retaining the actual landing rooms and bearings. Previously `KitSteppedWings` refused every upper-storey cut if the whole storey carried `abutted`, even when the candidate was at the opposite end.

## Construction contract

Removed that whole-storey veto from wing shaping only. Existing per-cell external construction, walked-floor, bracket-bearing and doorway checks still reject a cut through an obligation. Complete lower room support, unchanged repeated footprints, connected roofable remaining rooms and whole storey heights remain required. Jetties still keep abutted storeys flush; this does not reintroduce the half-module dead slot around bridge doors.

The new 12-seed fixture fails before the change (24 failed assertions), then passes all 312 assertions: each house gains a remote lower wing and retains every cell of its two-bay landing, its passage edge and its doorway. The finished seed-8/grand regression fails both silhouette assertions under the restored baseline (5/7), then passes (7/7). It additionally checks that house.014 gains a stepped wing and lower roof while retaining a real skywalk doorway.

## Finished towns

The ten-town corpus is 31/large and 8,9,13,43,53,63,83,103,301/grand. Three additional houses receive lower wings: 8 house.014 (L-shaped crown), 301 house.022 (L-shaped crown), and 301 house.024 (lower end wing). The other eight towns keep their stepped-wing records. All 480 previously covered walkway quarters retain their exact ceiling heights. Floating masses and public-air intrusions stay zero; corner turret counts remain unchanged.

Matched native views show that the blue-roofed house in 8 loses its oversized simple roof and gains a lower corner with a complete gable and connected roofs. The mixed-kit bridge doorway remains on the intact side. Both changed 301 houses gain a different-height roofed wing. The reverse view of 301 house.024 is foreground-occluded and is retained only as context; the other view shows its changed wing. These remain ordinary asset-derived kit buildings, not proof that the complete authored-house grammar is finished.

## Verification

- Ten stepped-wing tests / 838 assertions pass; the separate finished-town regression passes 7 assertions. The original negative fixtures still refuse removal of door, public-floor and structural-bearing cells.
- Actual-player traversals pass 12/12 in 8 and 8/8 in 301, covering skywalks, source bridges and underpasses in both directions.
- Detailed roof audits: 8 goes 53→55 roofs with the same pre-existing three tiny roofs and one gable hole; 301 goes 50→53 with no tiny roofs or gable holes. Both retain zero exposed open ends, unsupported roof air, cut eaves, uncapped towers and native public-air intrusions. This is not global-suite acceptance.
- Fixed native before/after pairs inspected for all three altered buildings. Source-restored baseline audits and renders restore the candidate byte-for-byte in finally blocks.

## Next root issue

The current façade diagnostic now includes source plot and height-decision records for directly matched house ids. In 8/grand house.012 and 9/grand houses.007/.035, five-storey repeated wall runs correspond to optional `skyline_peak` plots with `tiered=false`. They are not an upper street forcing those particular plot heights. This identifies a narrower planning cause than a global house-height cap; it does not prove that later private balconies or skywalks would survive shortening them. Their room/circulation dependencies still need joint treatment.

Tall repeated façades elsewhere, broad square supply, the full prefab-generalizing grammar and overall town art acceptance remain open. This local wing change does not claim to resolve those issues.
