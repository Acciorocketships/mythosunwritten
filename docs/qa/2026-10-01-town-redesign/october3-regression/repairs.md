# Failures classified during the October 3 run

Production code remained unchanged throughout this run. Two already-completed
test files were repaired; original failing logs remain intact, and their fresh
combined run is `repaired-fixtures.log` (7/7 tests,600 assertions,39.852 s).
The initial source manifest predates these two test-only edits; exact revised
test hashes are in `repaired-test-manifest.json`.

- `test_october1_pure_village`: the blanket same-pack prefix assertion rejected
  the deliberately measured high-window fallback. The replacement still rejects
  all foreign facade panels except the kit-declared native high timber window,
  requires its exact asset ID, and checks the necessary native timber head is
  emitted. Ordinary per-house family selection, datums, native module dimensions,
  collision, and single-joint tests remain.
- `test_october1_roof_details`: the frozen source preserves the original roof and
  public walkway, but articulation now selects the clear end of that roof for
  its chimney. The positive fixture now reconstructs the original obstructed
  end on that actual roof (6,4 size4x2,axis0,eave2). It proves the native body/cap
  intersects this town's real public air, then moves on its own ridge without
  omission, lost pieces or triangle clipping. The final generated and frozen
  towns remain separately checked for whole chimney clearance and variety.

These are coverage repairs for changed intended behavior, not exemptions to
production collision or structure rules. Main47-file run is still in progress;
consult `state.json` and the live runner rather than treating this note as its
final result.

The47-file run finished:44 passed initially; the three failing files were the
two above and `test_october2_inhabited_walls`. Its old checks assumed every
wall room belonged to a citadel. The revised check requires either the actual
platform bearing datum, an existing house at the room ceiling, or a published
nonflight terrace. The elevated-tier positive count still requires platform
rooms; full construction, masonry caps, floating masses and public-air checks
remain. Fresh rerun:4/4 tests,312 assertions,71.295 s in
`repaired-inhabited-walls.log`. Production code was unchanged. Together these
runs pass all47 October files, not the full repository suite.

## Older town regressions

An additional four-file run passed excavation construction (7/7), but found
three test files with expectations superseded by the requested generation.
Original evidence is `prior-regressions-initial.log`.

- Floating masses: the old photographed fine cell(1,3,1) is now a structural
  ceiling directly below real private room bands4–5 and above public air0–2.
  `crown-probe.log` records the ownership. The test explicitly requires that
  real house bearing for retained stone. The whole-cover corpus still requires
  a positive complete room/crown/headroom case, now independent of coordinates
  (current positive4/large:(3,-2)); all candidate checks remain. Rerun5/5,
  65 assertions,80.630 s. No floating audit or production rule changed.
- Town edges: direct-access towns need not keep redundant perimeter circuits,
  nor must every town have a suitable reserved landmark. Both features must
  remain positive in the unchanged four-town corpus; every town still meets
  its edge/rampart bounds, and every held landmark must survive and be built.
- Narrow houses: the old depth<=2 check rejected the requested native cross
  pavilion on6x2 houses. The revised test keeps the low hall, allows only a
  three-module profile spanning at most two modules along its ridge, and
  requires an adjacent, overlapping lower hall with its roof end open into it.
  This does not permit broad tall gables or arbitrary long cross ranges.

Town-edge/architecture rerun:17/17,1,733 assertions,28.280 s. The narrower
pavilion test was strengthened with transverse overlap after that run started;
its separate rerun is `narrow-pavilion-repaired.log`. All are test-only changes.
Full repository regression classification remains unfinished.
