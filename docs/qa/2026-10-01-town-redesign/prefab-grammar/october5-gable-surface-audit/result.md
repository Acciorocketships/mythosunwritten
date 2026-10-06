# Native gable surfaces and low terrace regression

Previous goal turn: progress, recording completed native/player/corpus evidence. This turn resolves two candidate acceptance questions without declaring the whole redesign complete. The interior-square candidate remains applied.

## Gable finding: sampling the wrong plane

Frozen current43/grand source: `tests/fixtures/october5-court43-gable-source.txt`, signature `98fd7e399f025146a4f0992c4bd7c8d31bfd2f4a78fb04b9d329127f2fb551dc`. Roof40 of house027 is rectangle(2,-16;6,4), axis0, eave6. Its positive gable loses four nominal audit samples at native x16, y12.113, z-27.633..-26.433. Only adjoining roof35 (rectangle8,-14;2,2; axis1,eave8) cuts these samples.

The actual authored outward plaster intersects those rays at x16.157. Every actual face hit is inside the neighbouring attic, including a further0.01m outward probe. The audit checked x16±0.05 and thus classified correctly buried faces as exposed. Native close/reverse views inspect the complete assembly. This differs from the previous archived cutter experiment: production roof geometry is unchanged; no extra plaster is inserted inside the neighbouring roof.

`kit_roof_audit._native_gable_faces_buried` now checks every actual outward authored face hit for an otherwise missing nominal sample. All hits must be enclosed; zero hits still counts as missing. The existing nominal and realized-triangle checks remain.

Red-first:2/3 tests fail,9/18 assertions. Green initial3/18. Expanded5 tests/22 assertions pass: both packs, all four orientations, removed gable panels, the same cut without its enclosing attic, and frozen43. The destructive tests still find real holes. Three current holdout towns (8,103,13) have zero gable-hole findings across149 roofs. Two genuine one-module roof strips remain (8 house000;103 bridge00.end1.lower); these are not suppressed.

## Short terrace room

The saved pre-candidate carver/planner/source implementation also produces no short room in2/grand. Captured source `tests/fixtures/october5-short-terrace-before-courts-source.txt`, signature `752178da3d1d8a7633ce4609522ce634de9327cafbf74b776fa1142fd390ff8a`; temporary source restoration used a finally block. Both baseline and candidate retain six ordinary taller wall rooms and have no three-band terrace candidates.

Current41/large has a genuine floor0..3 terrace room at(2,2), addressed from(1,0,2), accepted by the unchanged support/clearance contract. The short-room regression now checks and compiles this same source, retaining its positive count, public terrace, flight exclusion, floating and public-air assertions. It no longer assumes2/grand retains a particular old route. Existing wall-room tests plus bridge-bearing tests:7/7,92 assertions pass.

## Remaining

Active falsification restores nominal-only sampling in an isolated audit copy:3/5 tests fail (12/22 assertions); both deliberately broken-geometry checks continue to pass. Final test preload restored in a finally block. The refreshed ten-town enclosure/tower/floating/public-air survey is still running; append terminal results before acceptance. Broad town art, tiny roof strips, additional fitted spires and enclosed circulation remain open.


## Next roof diagnosis

Read-only finished-mass probe identifies the remaining8/grand house000 strip at(-2,7;2,1), eave10: lower crown part(-2,6;2,2) is only half exposed beneath the floor10 room at(-2,5;2,2). The103/grand bridge00.end1.lower strip is(-2,1;2,1), eave6; other parts of the lower crown are public/covered (two cells explicitly `covered_crown`). These need contextual roof/upper-footprint design, not a blind roof removal or a relaxed audit. Enclosed narrow skywalk roofs are separately intentional and already excluded by the roof audit. Full source/storey details are in `oct5-thin-roof-probe.out`. No production roof-shape changes were made this turn.


Live continuation handle: unified exec session46825, refreshed10-town `inhabited_enclosure_probe`, confirmed running by `write_stdin` after the other jobs completed. Output `/tmp/oct5-court-safety-current.out`, final JSON target `/tmp/oct5-court-safety-current.json`. Completed rows so far13,43,301,8,9,31 have floating=0/public-air=0 and covered quarters36,100,126,112,71,38 respectively. Do not restart from a missing final JSON: poll the existing handle. All other jobs from this turn are terminal.


## Ten-town survey terminal result

Session46825 completed normally (exit0); all ten towns build. Across the exact earlier comparison cohort, covered quarters480→711 and fitting generated turrets18→16. All ten floating/public-air audits are zero. The current43 result is100 covered quarters (the earlier archived prototype had128), with one fitted turret. The current candidate remains a changed route network, not preservation of every old crossing:9 still falls80→71. See `current-comparison.json` and full per-town native enclosure/tower admission data. All processes from this turn and the previous turn are now terminal.

The upper footprint of8 house000 covers half of a lower pavilion;103's lower strip is bounded by structural/public occupancy. A suitable next experiment is a native backed shed roof where a complete higher wall encloses its uphill half, with the existing union closing the junction. It must preserve higher windows, public clearance, and the lower roof's eave, and be judged natively before acceptance. Simply suppressing the roof or changing the audit would not address the roof-shape request. No such production change is claimed here.
