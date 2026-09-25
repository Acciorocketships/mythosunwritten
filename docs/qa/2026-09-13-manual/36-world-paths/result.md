# Issue 36 — restore intertown roads

The original rules rejected all four reviewed neighboring-town links. They tested the entire 24 m terrain edge even when the actual 4 m road crossed a continuous part of it, limited total vertical travel to 28 m despite the enlarged terrain range, and only searched monotonically toward the destination. The shared planner now checks the actual road width, allows the net endpoint elevation difference plus the existing 28 m extra variation budget, and searches a finite 96 m detour corridor in all four directions. Settlement entrances derive from the actual first and last road edges.

The search uses lazy edge evaluation and exact-cost A* labels retaining distinct height-variation budgets. These are general terrain and routing rules, without seed exceptions, forced roads through cliffs, or retries. Two reviewed links return: 936 m / 39 edges and 792 m / 33 edges. The other two remain rejected by real terrain barriers. The three accepted entrance masks equal the projected geometry (4, 8, 2).

## Verification

- Original width, climb, endpoint-direction and eager-work invariants fail in the recorded red runs. Final focused tests pass 15 tests / 1,968 assertions, including 24 graphs compared with an independent exhaustive simple-path reference and dense width sampling.
- Three decision tests / 64 assertions compare selection and entrance projection with exhaustive policy across three seeds. Seventeen related path/program/bridge tests pass 145 assertions. The old node-build count failure reproduces on the original implementation and remains open.
- The final lazy solver produces exactly the same four route records and three gate masks as the version used for the rendered comparisons and walks (`lazy-identity.json`).
- The mandatory native town matrix retains 48/48 towns, 11,868 clear centers / 17,035 crossings and the same 24 off-center pillar contacts. There are no blocked centers, crossings or disconnected public routes. The fingerprinted composition gate passes 95 assertions.
- Two real streamed character walks traverse the same 672 m country-road segment in opposite directions, about 90 seconds each. All 179 recorded samples per walk report zero frozen samples. This does not claim every restored link was walked end to end.
- Six frozen native-collision entrance traversals pass, both directions at three towns. The southern straight approach crosses grass beside the bent painted road before reaching the public stair; it proves physical access, not a trace following the painted bend. An earlier high-town target inside the central well was rejected as a diagnostic error; the final target is the public walking area beside it.

## Visual judgment

Nine live matched pairs at three road sites and fifteen usable native entrance pairs show restored painted roads, cleared grass and connected town approaches. All were inspected. Three additional entrance pairs are obscured by a tree or roof and excluded. Earlier inside-town southern camera attempts are also excluded. `live-all-pairs.jpg` and the three `gates-*-pairs.jpg` contacts contain the reviewed frames; full-resolution differences are under `differences/live` and `differences/gates`. Live atmosphere and orb clocks were not identical, so unrelated pixel changes are not credited to routing.

The user supplied this issue in text without a road screenshot. The harness records the chosen terrain/entrance poses; these are not claimed as reconstructed original photographs.

## Performance remains unresolved

The unchanged 60-second path-context gate fails on both the original and final implementations: the recorded original is 87.748 s, final lazy candidate 95.012 s. An eager intermediate candidate was 175.073 s and was replaced. These runs have different host load and are not a controlled speedup comparison. The final run has 21 nodes, 95 route cells and no exact-coordinate route mismatches; it still does not meet the timing bound. No bound was raised. Road connectivity is accepted for the tested links; startup, global streaming performance and the timing regression remain open.
