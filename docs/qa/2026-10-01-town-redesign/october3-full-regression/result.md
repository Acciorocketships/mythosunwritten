# Full isolated regression — running

Fresh sequential full repository run: `/tmp/october3-full-suite.py`, live exec
session24812, stdout `/tmp/october3-full-suite-driver.log`. `state.json` records
finished files and the current one. Poll this exact handle; do not duplicate.
`source-manifest.json` records initial scripts/tests. Initial production source remained unchanged through the roof-construction
file. The subsequent turned-roof repair is recorded below. Two already-completed tests were revised;
`repaired-test-manifest.json` records their new hashes and reruns below.

Refresh `classification.json` with `python3 /tmp/october3-classify.py`. It compares
failed methods AND their messages with preserved baseline batches at b8e130d9.
A matching failed method alone is not proof of a baseline-only failure. Many old
baseline GUT failures are UID warnings; those do not establish the same failed
assertion. The refreshed baseline city-form file still has those warnings.

## Reconciled expectations

- Rim boring: reserve planting cores as well as cottage footprints. The test
  still checks all remaining rim cells permit at-grade boring, never below
  ground, and retains the height cap. Focused rerun1/1,9,171 assertions.
- Plot height: a wall room immediately beneath a real nonflight public terrace
  may have one full storey plus its slab (three bands). All other houses retain
  the four-band minimum; wall rooms additionally prove `wall_room_support_ok`.
- Floor support: inhabited supports can reduce the bore's unsupported-floor
  count. Assert no increase instead of demanding equality with old gaps.
- Sloped admission: step3/standard now seals; remove its obsolete refusal pin
  so it participates in ALL the existing sloped support/translation checks.

Full plot rerun:40/42 tests,3,163/3,165 assertions. At that run, plaza-positive frequency
(2 vs3) and buildable coverage(0.87261 vs0.89) failed. Neither threshold was
lowered. A later focused coverage rerun passes (1/1,16 assertions): its eligible
ordinary house runs now begin at the platform bearing surface, excluding solid
foundation below upper streets. The probe finds exactly seven unowned foundation
columns in3/standard;137 occupied /150 eligible =0.91333 (previously137/157).
The unchanged0.89 floor passes; wall-room support remains checked separately. The newly admitted sloped case completes the existing translation
checks. Original failures remain in the first-run logs.

## Unresolved evidence

- City-form legacy form-id diversity fails at baseline and current. Current
  outer-frontage count is0; baseline has only unexpected-UID-warning failures
  in that method, not the same explicit assertion. Not classified baseline.
- Carver spine metrics: compact17 and standard29 have no post-summit descent;
  compact17 is straight; corpus outward gain and descending bands fall below
  their old bounds. Production carve frontage has a0.30769 case vs0.40 floor.
  Need explain/measure against redesigned layouts before accepting or changing.
- Other full-suite files are still running; this is not a complete regression
  result, nor approval of the remaining visual/performance acceptance gates.

## Expanded plaza acceptance

Fresh same-script baseline/current48-town comparison has27 ->29 plaza towns,
23 ->22 raised plazas. The old exact3/4 pin becomes a baseline27/48 floor;
ALL existing structural checks now cover the broader corpus. A plaza may keep
a different entrance after pruning, so the oracle proves its original source
address and an adjacent live level landing on the final graph. Focused1/1,
782 assertions; whole plot file rerun passes42/42,3,894 assertions. See
`../october3-plaza-corpus/result.md` for the full count/area tradeoffs.

Classifier now confirms identical explicit assertion messages at baseline,
never just matching method names. Four non-town failed files and the legacy
city-form diversity method have identical baseline failures so far. Repaired
reruns still live separately from immutable first-run logs.

## Production revision during run

A real turned-chimney / bearing-wall collision was found in roof-construction.
The admission guard now checks complete rotated extras against parent walls,
retaining the original orientation on failure. Full focused file13/13,42
assertions. See `../october3-turned-roof/result.md` and its source hash. The
initial runner manifest predates this edit; do not present all first-run files
as tested against one final source revision. Native finished-air rerun passes1/1,19 assertions; all six finished
meshes have zero intrusions. Stronger original-chimney/positive-turn test passes.

## Legacy outer-frontage oracle

`test_native_houses_share_inner_and_outer_town_street_frontage` directly calls
`VillageOutskirtsConstruction.generate`. Production `VillagePlan` creates one
`VillageWarrenFabricSolver` transaction and explicitly sets `record.outskirts`
to null. Repository caller search finds no production call to that legacy
generate method. Some helper methods remain active (road handoffs/grade/paint);
this does not reactivate its house allocation or four-sided perimeter circuit.

The failing exterior-house-count assertion is therefore a retired-generator
result, not evidence that production needs its old perimeter restored. Current
cottage-site occupation/access and clearance are exercised by
`test_october1_town_lobes`; the first-run full suite passed that file. The legacy
assertion is left unchanged and red; it is not classified as a baseline match
or included in current-layout acceptance. Source hashes recorded below.


## Direct wall-tunnel validation follow-up

A supported straight wall tunnel now uses the district-connection validator,
retaining its existing bore budget and structural proof. Wall-tunnel tests5/5;
48-town skywalk corpus passes with35 spans. Combined6/7: the remaining
photographed-seed span assertion has the identical baseline failure. Evidence
in `october3-wall-tunnel-validation/` (sibling of full-regression). This second
production edit during the full runner changes validation, not generated geometry.


## Native attachment demand

Registered retaining corbels/windows and all native tower parts in VillageProgram.
Tower assembly suite11/11; production record failures7 ->2. The remaining
world1/16 extent failures are a real discovery-bound issue, still open. See
`october3-asset-demand/result.md` under the redesign QA root. Third production
edit during the full run; focused source hashes/logs retained. No geometry changed.


## Wider-town discovery correction

Source-derived global and cached seed-specific bounds replace the old192m
early culls for volumetric towns. The actual far-control query now finds its
owner; canonical world1/16 records validate. Grade topology/new test10/10;
extended cached/uncached/128-envelope tests2/2; canonical records1/1. QA
`october3-discovery-contract/` contains red-first and fixed evidence. Fourth
production edit during the full runner. Full streaming build-count/memory cost
remains open; metadata timing alone does not close performance acceptance.


## Completed captured full run

Session24812 completed all392 captured files:294 passed,98 failed or could
not execute cleanly. The refreshed classifier identifies67 failed methods
with matching explicit baseline assertions and65 whose baseline equivalence
is not proved. These method counts do not cover every parse/load failure.
Original logs are immutable; this is not a single final-revision green gate.
Five production changes and documented test reconciliations happened during
the run; focused reruns carry their own source hashes. The latest native-verge
repair passes both eave and September27 roof suites9/9,262 assertions.
New October3 discovery tests were outside the captured392 file list.
No broad completion claim follows from these totals.
