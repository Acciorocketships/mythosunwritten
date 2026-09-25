# P23: coherent ground streets

The photographed grass hole and narrow exit notch are repaired by general source and road-connection rules. The photo uses seed 2697992464, feet (-248.9, 12, 432.7), and crosshair (-248.8, 12, 435.9). `ReviewCam.solve_cam` supplies the original and ±8° cameras.

The hole was an unused frontage reservation at macro cell (2, 0, 1), completely surrounded by streets. After plot allocation, the source planner now claims a ground parcel enclosed by four same-level public neighbors as part of that public graph. Occupied house/deck columns, intentional features and open courts are excluded. It reads the original street set once, so this cannot cascade into a flood across lawns. Compilation gives the same owner to all four fine floor cells, their ground grade and public clearance.

The narrow notch had a second cause: an unused level exit painted a short four-metre-wide spur beside its six-metre street. Gate approach paint now follows actual external-road selection. A level exit with no road opens directly onto natural ground. A connected road keeps its complete approach, and a raised gate keeps its built stair approach. Structural clearance remains independent of paint.

## Evidence

- `source.txt` records the original canonical world shapes and placement. `before-payload.bin` and `after-payload.bin` compile the same photographed plots and accepted terminal-stair rules with/without public infill.
- `native/` contains three inspected matched native pairs. The neutral ground plane isolates the source paving; it does not reproduce terrain grading or external gate paint.
- `before/` and `after/` contain three inspected matched game pairs; `game-pairs.png` and `diff/` record the comparisons. The final snapshot comes from a fresh production load in `live-final/`. The baseline snapshot predates the separate accepted approach-collar repair, but its photographed street/house allocation is unchanged.
- `live-after/` is the intermediate hole-only candidate: the exit notch remained, and that candidate was not accepted as the complete repair.
- The original infill test failed both public-claim assertions. The original unused-handoff test failed in all four orientations. The final checks cover real road continuity in four orientations, raised approaches, protected plots, open lawns, upper courts and full native compilation.
- Thirteen focused tests pass 172 assertions. The related fourteen-test run passes 234/236 assertions: the older September 9 road-exit test retains two fixed-coordinate failures (6 m and 12 m) while its actual connection checks pass. `baseline_road_exit_test.gd` restores the original unconditional gate paint and reproduces exactly those two failures (62/64 assertions); neither historical coordinate pin was changed.
- `clearance.json` preserves all 92 old public positions and 132 crossings, adding four clear positions and twelve clear crossings: 96/144. The new positions and crossings explicitly assert clear physical capsule results.
- `corpus.json`: all 48 towns construct, with 11,772 clear positions and 16,915 clear crossings. Twenty-five conservative off-centre pillar contacts remain, with no blocked centres/crossings and zero reported intrusion. The fingerprinted composition gate passes 95/95 assertions.

Final fresh startup was 305.349 seconds under concurrent review load. No performance improvement, complete road-suite acceptance, or resolution of the separate terrain-bank defect is claimed. Snapshot capture logs contain Godot's existing warning about querying shader globals outside the editor; all credited frames are visibly complete.
