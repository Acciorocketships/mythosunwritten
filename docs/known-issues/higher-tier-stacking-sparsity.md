# Higher-tier level stacking sparsity

## Status: RESOLVED

## Goal

Level-center tiles have a `topcenter` fill_prob of 0.95. Every center tile should almost always
produce a stacked tile above it. With fill_prob set to 1.0 for testing, every center should stack
without exception.

## Observed behavior

Upper tiers are visibly sparse — many level-center tiles have no stacked tile above them, even with
fill_prob = 1.0. Something is preventing topcenter sockets from being processed or placed
successfully.

## What we know so far

- The fill_prob roll itself works: debug tracing in `_process_socket` shows that every topcenter
  socket that reaches the roll succeeds at 0.95 (and would always succeed at 1.0).
- Stacked tiles that ARE placed get immediately retiled by `LevelEdgeRule` from center to an edge
  variant. As neighbors appear, they retile progressively (island → peninsula → line → side →
  center).
- When `_replace_piece` retiles a piece to center, `add_piece_to_queue` enqueues the new center's
  topcenter (0.95).
- In a 10-second debug run, zero `level-stack-center` topcenter processing events were observed —
  no second-tier tiles ever reached center status and tried to stack further.

## To investigate

- Are all center tiles getting their topcenter enqueued? Could retiling churn cause sockets to be
  lost from the queue?
- Is `_is_socket_connected` incorrectly reporting topcenter as already connected?
- Are placement failures (`can_place` / overlap checks) silently preventing stacked tiles?
- Is `LevelContradictionRule` skipping valid placements?
- Is there a timing issue where the topcenter socket is enqueued, then the piece is retiled to an
  edge variant (removing the socket from the queue), and never re-enqueued when it becomes center
  again?

## Debug session (instrumentation)

**Hypotheses under test:**

- **H1**: Level-stack-center's topcenter is enqueued but then removed when `LevelEdgeRule` retiles
  the newly placed piece from center to an edge variant in the same pass
  (`_replace_piece(center, edge)` → `remove_piece(center)` drops the center's topcenter from the
  queue before it is ever processed).
- **H2**: level-stack-center topcenter is never enqueued (e.g. skipped in `add_piece_to_queue`
  because `query_other` finds an expandable socket at the same position).
- **H3**: When a level-stack-center topcenter is popped, `_is_socket_connected` returns true so we
  skip processing.
- **H4**: level-stack-center topcenter entries are always deferred (out of range) and rarely
  re-queued.
- **H5**: Stacked tiles fail `can_place` or placement fails for another reason.

**Log messages (NDJSON at `.cursor/debug-076d6c.log`):**

| message | hypothesisId | meaning |
|--------|---------------|---------|
| `enqueued_topcenter` | H1 | add_piece_to_queue enqueued a level-stack-center's topcenter |
| `replace_piece_center_to_edge` | H1 | _replace_piece called with old_piece = level-stack-center |
| `remove_piece_center` | H1 | remove_piece called for a level-stack-center (drops its topcenter from queue) |
| `skip_enqueue_has_neighbor` | H2 | add_piece_to_queue skipped topcenter because existing expandable socket at position |
| `process_socket_topcenter` | H3 | _process_socket entered for a level-stack-center topcenter (socket was popped) |
| `socket_connected_skip` | H3 | _process_socket returned early because _is_socket_connected was true |
| `deferred_topcenter` | H4 | level-stack topcenter was deferred (out of range) |
| `add_piece_failed` | H5 | add_piece returned false when placing a level-stack tile from topcenter |

## Log analysis (run with instrumentation)

- **H1 CONFIRMED**: Every `enqueued_topcenter` was followed within 1–3 ms by `replace_piece_center_to_edge` and `remove_piece_center` (same piece_id). Zero `process_socket_topcenter` entries — level-stack-center topcenter was never popped and processed. Root cause: we enqueue the new center's topcenter, then LevelEdgeRule immediately retiles that piece to an edge variant in the same pass, so `_replace_piece(center, edge)` → `remove_piece(center)` drops the center's topcenter from the queue before it is ever processed.
- **H2**: One `skip_enqueue_has_neighbor`; minor.
- **H3, H4, H5 REJECTED**: No `process_socket_topcenter`, `deferred_topcenter`, or `add_piece_failed` in the log.

## Fix (implemented)

When `_replace_piece(old_piece, new_piece)` retiles a level-stack-center to an edge variant, the edge piece occupies the same position but has `topcenter: null`, so its topcenter would not be enqueued. Preserve stacking for that position by:

1. **TerrainModuleInstance.socket_fill_prob_override**: Optional `Dictionary` (e.g. `{"topcenter": 0.95}`). When set, the generator and LevelContradictionRule use this value for expandability/fill checks instead of `def.socket_fill_prob` for that socket.
2. **In _replace_piece**: If old is level-stack-center and new is level-stack (edge), set `new_piece.socket_fill_prob_override["topcenter"]` **only when `preserve_topcenter` is true**. Use `preserve_topcenter = true` when retiling an *existing* piece (neighbor update in `_apply_piece_updates_after_placement`) or when retiling the *just-placed* piece **if it was placed by lateral expansion** (so that position gets one stacked tile). Use `preserve_topcenter = false` only when the just-placed piece was placed **by stacking** (orig_piece_socket.socket_name == "topcenter"), so we don't enqueue that edge's topcenter and build infinite towers.
3. **TerrainGenerator._get_socket_fill_prob** and **LevelContradictionRule._socket_fill_prob**: Check `piece.socket_fill_prob_override` first; if present for the socket, return that value.

Post-fix verification: re-run with instrumentation; expect `process_socket_topcenter` entries and continued stacking from edge positions that inherited the override. Instrumentation has been removed after confirmation.
