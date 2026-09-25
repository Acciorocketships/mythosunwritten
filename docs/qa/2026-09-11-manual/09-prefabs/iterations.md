# Prefab integration — active

Baseline: accepted issue 8, two complete LPFV source landmarks in the photographed
warren, alongside world frontage houses. `before-payload.bin` and `before.json`
retain that construction; live before is `../08-skywalk/live-after`.

Brainstorm: (1) select all measured-compatible complete buildings within each
source reservation rather than only its canonical representative; (2) reserve
more interior prefab sites before modular partitioning where the site can truly
fit; (3) define measured native connection interfaces for compatible prefabs,
while retaining freestanding sites for buildings that cannot share walls/roofs.
The outer/ground layout process itself is the next issue and stays separate
until this issue is verified.

Initial code finding: ASSET_TEMPLATES deduplicates the catalogue by derived
reservation envelope and stores only the first recipe. Realisation then tries
that exact recipe. This makes the other complete native buildings in each group
unreachable, even if their full doorway/bearing/clearance profile is compatible.
Measure those groups before changing selection. Complete native geometry stays
intact; actual final clearance and bearing remain mandatory.


Candidate 1 retains all 32 complete native recipes in 17 independently measured
reservation families. Source selection chooses a family once, then a native
member before partitioning. Every alternative has the same complete nine-field
door-relative visual/body/bearing profile as the canonical row. The failing
catalogue regression initially found 15 unreachable recipes (68/83 assertions);
the candidate passes all 128 catalogue assertions. The existing independent
canonical-table test also passes 207 assertions.

Each tier requests one additional prefab site, still under the existing complete
support, public-air, doorway and final composition checks. A red source test
found only one prefab in seed 11 compact; it now admits both complete sites.
The two new tests pass 130 assertions. The twelve-compact source comparison
increases the total from 9 to 10 prefabs; only seed 11 has an additional legal
site. The photographed town cannot fit a third, so remains at two. Its first
native recipe changes from anchor.prefab.10 to .16; all 28 modular room records
and every other unit recipe remain identical. Seed 11 changes from 27 modular
rooms plus one prefab to 18 modular rooms plus two prefabs. Both versions retain
identical native capsule surveys (76 positions, 108 crossings); the photo town
retains 88 positions and 124 crossings. Every tested centre/crossing is clear.

The source-plot and native-floor run passes 40/46 tests, 3,181/3,194 assertions.
An isolated pre-issue-9 project reproduces the exact same 13 failed assertions in
six source-plot tests. Object instance numbers are normalized in
baseline-failures.json; all failure values and explanations match. Native-floor
tests pass for all 32 complete recipes. The old scale test additionally pins
three already stale compact values. Its baseline passes 113/116 assertions.
Four landmark-range expectations are updated to this intentional budget change;
the two unrelated compact crown/skywalk pins are preserved as historical failures.

Native judging: all sixteen photo-context pairs preserve the completed warren,
with changed pixels confined to the selected prefab and its lighting. Sixteen
seed-11 overview/lower pairs show the added native house and changed modular
partition without disconnected streets. The first seed-11 overview framing was
rejected because it aimed above the town and clipped its lower half; those images
are archived in seed11-framing-rejected and are not acceptance evidence. Corrected
paired cameras frame the union of actual before/after native bounds.

Twenty additional paired detail renders inspect both prefab sites in each town.
The camera labels are relative to native -Z; the actual authored door faces +Z
and appears in the files labelled rear. Awning-obscured photo front/base views
are context only; clear oblique side views and the seed-11 door views establish
native floor contacts, closed shell/roof and ordinary street-facing placement.
The isolated native fixture omits the surrounding terrain; grey void outside
its owned public skin is not a newly removed ground surface. Existing roof
shimmer in seed 11 is present in both versions and is not a prefab regression.

Full 48-town construction sweep, final live photo replay and composition gate
are pending. Issue 9 remains active until those results are judged.


Candidate 2 review: source identity previously encoded only the shared plot
footprint, so selecting a different native building in the same family produced
the same source signature. A new red assertion mutates only that selected native
kind and requires the signature to change, while reversing the audit records
must retain identity. The first partial corpus is stopped and retained as
candidate1-partial-corpus.log; it is not a complete acceptance run. Live replay
started during that partial sweep, so overlapping solve timings are not isolated
performance evidence. The signature repair changes no geometry or placement.

The source identity regression fails at 131/132 assertions before repair and passes all 132 afterward. Final combined tests pass 10/11 tests, 246/248 assertions. The two remaining assertions are the baseline compact crown and skywalk pins; no new source or budget assertion fails. Final corpus restarts against all three production files. Its initial rows overlap live photo startup; timing remains unsuitable for a performance acceptance claim.

All twelve live pairs pass visual judging with exactly equal camera records. Startup 274.859 seconds. Final image audit contains 64 inspected pairs, of which 54 pass their stated scope and ten obscured details remain context-only.

Final acceptance: 48/48 towns, 11,112 clear positions and 15,923 clear crossings; same 27 off-centre pillar contacts. Composition gate passes 95/95 assertions, with invalid raw host calibration 2.810x explicitly retained. Isolated grand-town primary-stage totals are 57,197 ms before and 55,976 ms after; source plots rise from 1,050 to 1,304 ms, other stages vary. Same 57 plots / 48 parcels / 164 building records / 168 rooms. The earlier 185,120 ms outlier does not recur in that pair; no general performance bound is claimed. Issue 9 accepted for construction and visuals.
