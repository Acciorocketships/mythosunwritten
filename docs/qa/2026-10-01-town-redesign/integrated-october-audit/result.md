# Integrated October audit — active

Previous turn was progress: production floor-seat correction and regression/
walk evidence changed authoritative state. This turn adds a public-floor camera
review mode (`kit_town_review --views retaining`) and inspects three actual
street-facing relief views in41/large. The views confirm depth in silhouette and
shadow, and expose a neighbouring plain face; overall facade acceptance remains
open. Camera candidates use public floor cells, outward-facing support normals
and physics sight lines. An initial scope parse error was corrected before the
successful run. This review utility does not alter production generation.

## Current isolated run

`tests/tools/run_suite_isolated.sh /tmp/october-current-suite.txt 2
 'tests/test_october*.gd' /Users/ryko/.codex/worktrees/77a0/story`

**Running session74175**, last polled live.47 files total;28 completed at this
checkpoint. Logs `/tmp/october-current-suite.txt.logs/`. Do not restart because
of quiet output. The runner emits file results into its output file, not stdout.
Production code was unchanged during this run. Test corrections below were made
only after the runner had completed those files; the initial failures stay in
its raw evidence, with separate reruns documenting corrections.

## Verified test-oracle corrections

- Gate/parapet tests applied old Suntail wall bounds to every emitted native
  asset, including arches and closed caps. Now each part uses its own catalog
  bounds. Cap identification uses its role instead of an old panel orientation.
  Gatehouse3/3 pass; public split-landing guard check passes.
- PureVillage metric test applied two-metre wall width to standalone spires,
  arches and blocks. It now checks the module metric on wall panels, while
  retaining catalog and collision assertions for every asset.4/4,694 assertions.
- Nested-tier test assumed all six historical seeds had multiple tiers. Prior
  courtyard investigation proved58 now legitimately has one generated tier.
  Every generated tier still must be reachable and inhabited; corpus must
  exercise multiple nested examples, and separate seeded optionality test stays.
  All four ring tests pass,89 assertions. No production tier policy changed.

## Unresolved failures so far

Landmark reservation exact-footprint preservation, terminal roof fallback
fixture coverage, chimney variety, released bridge-site reclamation (including
missing audit-key script error). Do not repin or declare baseline-only without
investigation. These tests were introduced by this redesign. Some may reflect
later intentional grammar changes; others may expose regressions. Remaining
October files are still running. Full isolated project suite, broad render/
memory, mixed-kit holdout art and original plan gates remain incomplete.

Only session74175 remains active at this checkpoint. Other runs completed.


## Completed isolated run and landmark diagnosis

Session74175 completed normally:47 files,38 initially clean and9 with failures.
Three files were subsequently corrected and rerun successfully as documented
above; six remain unresolved: landmark_reservations, native_town_roofs,
released_bridge_sites, roof_details, town_lobes, joined_town_ranges (October
prefixes omitted here). Full raw logs and summary are saved in this directory.

Seed9/standard's held asset.00 is a3x4 site at(1,-4), floor0/top4. Final plots
contain a3x3 replacement at that corner and another asset elsewhere. This is a
source-planning change, not later L/T kit articulation. Temporary instrumentation
found the held candidate rejected at column(2,-1), datum0 with `hanging_street`:
`_no_street_left_hanging` rejects a street at a band other than the fixed top.
That column is absent from final excavation public_cells, so trace the reservation-
time street/transition and later pruning before deciding the root repair. The
body/bearing reservation covers only floor-1 through top-1, potentially leaving
higher routes free to invalidate the held fixed-height site. Do not simply weaken
the test. Instrumented production file restored byte-for-byte from clean copy,
verified with cmp. No production algorithm changed in this diagnostic turn.

Small-lobe tests also report zero addressed houses on sites in seeds6,9,12;
these require source-stage investigation, rather than further cosmetic work.
Roof fallback/joined-range failures may be stale geometry fixtures but remain
unclassified. Chimney-count reduction and released-footprint reclamation remain
unresolved. All processes now terminal. Full redesign goal remains active.
