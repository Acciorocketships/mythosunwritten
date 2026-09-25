# P02 rounded town-road corner

The incoming world road no longer leaves a square spur outside the curved town approach. A finite natural-ground reservation retires the replaced straight corridor; the higher-priority curved road retains its full width. Pass 106's garden-avoiding route, gate, construction and collision are unchanged.

## Verification

- The original composed ground field painted 207 excess samples outside the authored curve. The exact photographed junction and pinned point fail before the fix. The final focused run passes 14 tests / 4,929 assertions, including four orientations, unrelated-road preservation, full curved width and retained town bounds.
- Fresh production-grass rendering uses original P02 and ±8-degree poses. All three are inspected, together with route-overhead, gate, garden-side and both walking endpoints. The square projection is absent; the garden, previous retaining-board repair and connected route remain intact. Diagnostic cameras supplement rather than replace the saved reference poses.
- Actual character traversal completes both directions. The supplemental fixed-height capsule survey has zero blocked samples out of 468. This is local route evidence, not every possible off-centre approach.
- Production grass reports 56 tiles, 51 batches, 9,170 roots and 6,201 visible roots. The earlier `fresh/` render had grass disabled and is retained only as diagnostic geometry evidence; `fresh-grass/` is the final visual set.
- The required 48-town / four-scale construction sweep passes all 48 cases, with 11,772 clear centres and 16,915 clear crossings. The same 25 conservative offset pillar candidates remain, with no measured centre/gate blockage or intrusion. Its fingerprinted composition gate passes 1 test / 95 assertions. This validates town construction; it does not establish every external world-road approach.

## Scope and limitations

T06's P02 corner is repaired. The original issue register remains open for other water, town, streaming, biome and cliff work. No full-suite or performance acceptance is claimed. Fresh startup was 201.085 seconds during concurrent validation. Snapshot saving retains the known editor-only shader-parameter warning.

The first rotated test fixture omitted the west arm of its own baseline road and failed four checks. The fixture was corrected to represent the native continuation, explicitly verifies that baseline road, and then passes without another production change. Both logs remain available.
