> Completed: both native runs and all diagnostic replays finished. See [result and corrected physical survey](result.md). Historical in-flight notes below are superseded.

# Native reach-network integration — in progress

No production water change. W01, the cliff art and the original judging register remain open. This pass follows the detached terminal-lake correction in pass 111.

## Evidence completed

- A detached `reach_plan.gd` converts composed station paths into ordinary RiverTrace inputs, retaining the actual source pool and selected receiving terminal pond. Its discovery envelope covers the full possible composed arc; it does not reuse the invalid raw-prefix bounds rejection.
- Three adapter tests / fourteen assertions pass: original source/receiving-pond identity, a borrowed reach outside the initiating raw trace's bounds, and adjacent region query-order consistency. An earlier test run had an incorrectly initialized synthetic source-presence cache and is excluded as red-first evidence.
- The first native inventory resolves 146 source routes for four review super-cells. It explicitly rejects `(-4,-7)` at the 4,320 m arc limit and `(-8,4)` at the 360-station limit. No incomplete river was promoted or rendered from that inventory.
- Neither failed path intersects an admissible raw terminal pond before its cutoff (`pond-contacts.json` is empty). Following them farther reaches existing basins in 433 stations / 5,233.47 m and 423 stations / 5,066.66 m respectively.
- The separate long-route experiment permits two raw river budgets (720 stations / 8,640 m). Its complete discovery radius is 9,038 m from the actual source, with ascent included in a 13-super-cell halo. The widened four-region inventory resolves **429** sources, all to existing basins. Six exceed the former single-river budget; the longest is 5,233.47 m. This is empirical coverage, not proof that all seeds fit the new limits. Rejection stays explicit.
- The adapter conservatively omits partially supplied native sandbars; 173 omissions occur across those 429 source records (not a unique-bar census). This is an unresolved collateral risk, not an accepted production policy. Shared downstream profile behavior and discovery cost also remain unverified.

## Native generation running

Two Metal Godot processes use `native.gd` and the reported seed / ReviewCam source poses for P10 and P21. Both build fresh ordinary TerrainChunkMesher and WaterSurfaceBuilder output. They are isolated terrain/water scenes, not full dressed-game or player-traversal acceptance.

- Baseline exec session **67449**, log `/tmp/hillside112-before-native.log`, output `before/`.
- Candidate exec session **25347**, log `/tmp/hillside112-after-native.log`, output `after/`.

Both handles were confirmed live after completing several chunks. **Poll those handles before starting or restarting anything.** A pending observation or this note does not establish completion. The baseline has completed P10 and is generating P21; the candidate is still generating P10 as of this note.

The baseline P10 original-material overview and source view were inspected. In this isolated scene, water is difficult to distinguish from green terrain; those images are excluded from optical/biome appearance acceptance. An opaque diagnostic replay of its saved geometry completed (session 86438 reaped, exit 0). `before-diagnostic/P10/view_0.png` and `overview.png` were inspected: they retain the broad high hillside supply and raised water sheets seen in the original report. The diagnostic material proves coverage only.

## Next checks

1. Wait for current generation. Inspect candidate P10 as soon as its snapshot and audit are complete. Replay it with the same existing `september18_hillside_replay.gd --opaque-water` harness into `after-diagnostic/`; inspect exact source, overview and alternate angles against baseline.
2. Complete the same review for P21 after both current processes finish. Do not silently accept changed landforms merely because the high water vanishes.
3. Run `physical_samples.gd` against all four completed snapshots. It compares native ground collision and actual saved water-mesh heights at nine fixed positions around each report. The script passes Godot check-only, but physical sampling has **not** run yet.
4. Inspect partial-sandbar losses, shared downstream profiles and complete source discovery. Any native rejection invalidates the candidate captures. A production solution must handle the finite bounds and costs without leaving failed routes as missing water.
5. If native geometry survives, use fresh dressed-game views, currents and actual traversal/swimming before production acceptance. The original task remains much broader than this experiment.

The snapshot helper emits its known editor-only global-shader-list warning. A separate check-only invocation without `--log-file` crashed in Godot's log rotation before parsing; it was reaped (exit 134), and the explicit `/tmp` log rerun parsed successfully (exit 0). Always supply an explicit log path. No engine crash was observed in either native generation process at the latest poll.
