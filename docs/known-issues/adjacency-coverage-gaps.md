# Adjacency Coverage Gaps (Diagonal Context vs Placement)

## Symptom / Question

"If diagonals are blocked (or controlled), why do diagonal level relationships still appear?"

## Core Finding

Placement adjacency is derived from the **test piece** in `get_adjacent_from_size()`, not directly from all sockets that exist on final level module variants.

This means adjacency used for placement can differ from adjacency used by level rules, depending on which sockets exist on the test piece for the chosen size.

## Repro Context

- Generation uses `test_pieces_library` for size probing.
- For `24x24`, adjacency depends on sockets in `create_24x24_test_piece()` definition.
- Level rule logic (`LevelEdgeRule`) uses cardinal and diagonal semantics for retiling/neighbor shape logic.

## Why This Can Produce Surprises

- If a socket type exists on level modules but is absent from the test piece for a size, placement-time adjacency may not "see" it.
- Rules may later reason over diagonals using different information sources.
- Result can look inconsistent: world has diagonal relationships that were not constrained the same way at placement time.

## Clarification on Top-Corner "Collisions"

A frequent misconception is that top-corner sockets on neighboring level tiles must be touching to appear in adjacency logs.

Observed behavior suggests a different path:

- same-cell generation attempts (ground `topcenter` attempting level placement where level already exists) can cause adjacency probing to encounter existing level top-corner sockets.
- This creates top-corner hit records without requiring literal corner contact between neighboring tiles.

## Related Evidence

Debug instrumentation showed missing and null diagonal/top-corner sockets are actively encountered in adjacency checks once non-blocking semantics are enabled:

- Missing encountered:
  - `topfrontleft`, `topbackright`, `topbackleft`, `topfrontright`
- Null encountered:
  - `frontright`, `frontleft`, `backright`, `backleft`

This confirms these socket classes are materially involved in generation behavior.

## Fixes Tried / Status

- No complete structural fix implemented yet for adjacency coverage parity.
- Current work focused on fill-prob semantics and profiling.
- Status: **open issue**.

## Recommended Next Actions

1. Define expected socket set per size for adjacency probing (especially `24x24`).
2. Ensure test piece sockets match intended constraints/rule inputs.
3. Add a consistency test:
   - Compare important socket classes on generated module family vs test-piece family.
   - Fail when required sockets are missing on test piece.
4. Re-validate generation density/performance after alignment.

