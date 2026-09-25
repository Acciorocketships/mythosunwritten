# Roof extent and alignment — accepted at the reported site

Photo 14's two circled roofs are corrected. The foreground terminal gable now
sits above its supporting wall instead of leaving a broad exposed ledge. The
smaller continuous roof preserves the original partial crowns' end boundaries
instead of adding an unsupported projection. The first candidate fixed only
the foreground roof and was rejected; its evidence remains in `candidate1`.

The offline baker's version 35 applies a monotonic longitudinal fit at measured
native gable datums, after the ordinary bounds fit. Twelve finite orange/slate
terminal and tight flush alternatives retain 16,864 native triangles, unchanged
X/Y coordinates, full height, UVs, inner seams and outer stock boundaries.
There are no degenerate triangles. End ornament becomes thinner longitudinally;
the five inspected native views retain coherent shingles, trim and closed seams.
The continuous roof compiler carries bounded ends from the original partial
crowns. Complete roof runs keep their ordinary eaves.

## Evidence

- `before` / `after`: six full-game matched reconstructed, nearby, jitter and
  gameplay views. All six comparison panels and the full-view heatmap inspected.
- `native-before` / `native-after`: five matched native views, including rear and
  overhead checks. Every comparison inspected, with additional close crops of
  the smaller roof.
- `diff`: final pixel differences. The reconstructed view has mean absolute RGB
  difference 1.046/255 across the frame and 2.681/255 in the roof region;
  4.8003% of that region changes by more than 20 in any channel. The intended
  changes follow the gable surfaces and end trim. Small character/orb timing
  differences outside the roof are not evidence of the fix.
- `red.txt` and `second-roof-red.txt`: the initial 72 native gable samples fail;
  the second roof separately fails both extent limits and 12 gable samples.
- `focused-candidate2.txt` / `roof-end-recheck.txt`: 30 distinct roof tests and
  55,338 assertions pass across the focused run and corrected test-only rerun.
  The first run's new ordering assertion was stricter than float32 precision;
  the revised check preserves single-valued, non-reversing coordinates and
  strictly orders samples separated by more than 10 micrometres.
- `native-preservation.json` records all twelve actual triangle streams.
- `clearance-before.json` / `clearance-after.json`: identical actual collision
  surveys across 132 walk cells and 188 crossings.

The matching camera metadata is identical. F3 pins are rounded player and
crosshair coordinates, so these are matched reconstructions, not a claim that
the original full-precision pose was recovered. Startup took 384.351 seconds;
this roof acceptance does not accept terrain loading speed or the pending water,
railing, overhang and city-shape work.
