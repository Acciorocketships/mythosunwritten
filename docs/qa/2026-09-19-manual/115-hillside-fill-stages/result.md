# Pass 115 — isolate coarse/fine water grading

**Experimental; no production promotion or original issue closure.** The larger
reported downstream rise is introduced by fine surface processing, not by the
coarse grade pass. Including wet diagonal neighbors with their world-space
length removes that rise in the isolated reach-network candidate. The smaller
confluence rise persists and the complete downhill gate remains red.

## Reproduction and stage evidence

Seed 2697992464; the same original geology and P10/P21 snapshot terrain as passes
113–114. `probe.gd` instruments the unchanged pass-114 water candidate. Six
source-stage binaries retain the complete rectangular solve, base (-2586,-1854),
370 columns / 668 rows. Nineteen contributor profiles are frozen separately.

The first probe completed its hydraulic solve and binary writes but its JSON
observer failed because a PackedFloat32Array cannot directly construct a
PackedFloat64Array. `recover_reports.gd` reads those exact saved binaries after
fixing the conversion. It does not rerun or change the solve. Both logs remain.
The initial seed stage has queued rather than settled heads: its absent route
values must not be interpreted as a demonstrated level surface.

The 34-point sampled reach has a 0.040104623 m rise at station 190 after relaxation,
containment, smoothing, coarse grading and crest support. None of those coarse
stages has the larger station-177 rise. The final fine sampling introduces that
0.269750862 m rise. `replay.gd` reconstructs the original terrain and runs the
final grading/refinement from the frozen smooth-stage input. Every original
final sample matches pass 114 exactly (zero error), validating the isolation.

## Candidate and rejection

The trial keeps the 0.30 grade and native wet-bed floor, adding diagonal edges
with Euclidean lengths. Diagonals require both intervening side vertices to be
actually wet above their sampled ground. This is a more complete discrete slope
constraint, not a proof of an isotropic continuum solution or downstream flow.

The first candidate checked only finite side levels. A deliberately finite but
buried dry-ridge control demonstrated that this could join separate pools.
It was rejected; the incomplete native process was explicitly terminated
(exit 143). It produced no accepted comparison. `first-*` replay artifacts and
`logs/grade-first.log` preserve this rejected version's evidence.

The corrected candidate passes 4 focused tests / 13 assertions: world-distance
diagonal grade, dry corner separation (including finite buried samples), native
bed/dry-mask preservation, settled lake preservation and idempotence. Original
production fails the diagonal test (12/13 assertions); the first trial fails
the dry-corner test (12/13); the corrected trial passes all 13.

The final frozen replay has only the station-190 rise. The first-descent check
is red on the four-neighbor control and green on the candidate; the whole-route
check stays red. Fresh native generation exactly reproduces all 34 candidate
field samples from the frozen replay.

## Native meshes, coverage and visual judgment

Both sites regenerate water over the identical saved terrain. Each has the
reported reconstructed ReviewCam pose, ±8° controls, a 90° view and an overview.
Opaque cyan is a coverage diagnostic; it does not establish optics, temporal
motion, swimming or final art acceptance. The inspected source, side and overview
views retain pass 114's removal of the high unsupported sheet, without the extra
background flooding seen in pass 114's rejected bank-loss candidate. The small
slope correction is chiefly established by field/mesh probes, not these distant
screenshots. Bare native cliff repetition remains visible and is not accepted
as finished cliff art.

Non-water meshes, transforms, instances and collision hash identically before
and after (P10: 787 records / 38 collision shapes; P21: 720 / 36). The sites overlap,
so these are per-site counts. All 882 paired native ground rays remain identical.
All 24 paired water-triangle centroid controls hit their actual meshes.

| Survey | Before | Candidate | Wet→dry | Dry→wet | Retained height changes |
|---|---:|---:|---:|---:|---|
| P10, 441 positions | 100 wet | 100 wet | 0 | 0 | -0.773224 to +0.029922 m |
| P21, 441 positions | 196 wet | 196 wet | 0 | 0 | -0.524597 to 0 m |

Coverage equality applies to these samples, not every shoreline. A small positive
mesh difference can arise from changed meshing/refinement; it is reported rather
than silently treated as a globally lower-only guarantee.

The complete route retains 268 probes: 247 inside the snapshot and 21 outside.
All 247 inside probes hit water in both versions. Two samples remain more than
10 cm below native ground in both versions. Actual mesh rises fall from three
(maximum 0.141433716 m) to one (0.027206421 m at station 190). The physical
`--require-downhill` assertion still fails and is not relaxed.

## Remaining cause and next action

At (-1122,-624), closest-interior ownership selects tributary (-2,-1)'s head
2.550221 m; nearby receiving-water nodes are 1.700000 m. The recipient centreline
itself also selects 1.700000 m, but interpolating the neighboring high tributary
sample carries a bump onto it. `mouth-cells.json` and `mouth-claims.json` pin the
heads and competing segments. This is a confluence surface/ownership defect,
separate from the diagonal grading artifact. The next correction must coordinate
the supplied tributary and receiving surface across their actual overlap, with
bank/sill and supply preservation; blanket lowest-head priority is not accepted.

Production hashes match pass 114. The long reach-discovery adapter, longitudinal
profile shaping and this diagonal candidate are all isolated fixtures. Their
combined remaining route, terrain-contact, source discovery and performance
limitations prevent shipping this as the full original water fix. No whole-suite,
streaming, town, biome or cliff-art acceptance is claimed.

## Commands and process outcomes

All commands use `/Applications/Godot.app/Contents/MacOS/Godot --path /Users/ryko/story`
and explicit `--log-file` paths. Fixtures are under
`tests/fixtures/september19/hillside-fill-stages/`.

- `recover_reports.gd`: headless exit 0; all six saved reports recovered.
- `replay.gd`: headless exit 0 for original and corrected diagonal candidates.
- GUT `test_grade.gd`: `GRADE_CONTROL=four` exit 1; first candidate exit 1;
  corrected candidate exit 0, 4 tests / 13 assertions.
- `native.gd -- --reaches --opaque-water --spots=P10,P21`: native Metal exit 0.
- `physical_samples.gd -- --supply --spots=P10`: headless exit 0.
- `physical_samples.gd -- --survey`: headless exit 0.
- `geometry_identity.gd`: headless exit 0.
- `native_audit.py`: exit 0; exact terrain/camera checks and survey report.
- `audit.py --variant eight --require-primary-descent`: exit 0; four control exit 1.
- `audit.py --variant eight --require-downhill`: expected exit 1.
- `supply_audit.py --require-downhill`: expected exit 1; residual physical rise.

The known macOS certificate-store warning appears in headless logs. Native
snapshot save reports the existing editor-only shader-parameter-list warning.
Neither is being claimed fixed. All processes are terminal at completion.
