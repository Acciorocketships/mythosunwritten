# Directional Socket Tags

**Status:** future work

## Motivation

Some terrain features want adjacency rules that depend on *direction*, not just
presence: rivers that flow in a consistent direction, paths that connect end-
to-end, edge tiles that match their neighbor's facing.

The cliff and level edge systems work around this by placing a generic seed
variant and re-tiling visually after the fact (LevelEdgeRule, CliffEdgeRule).
This works but it means we can't enforce shape invariants at placement time —
we get "eventually-consistent" shapes that may briefly look wrong.

A directional tag system would let a tile constrain its own facing relative to
neighbors. e.g., a river-source tile could require an adjacent tile tagged
`river[flow=south]` on its south side, and the lookup would prefer tiles whose
own `flow` tag is east-or-west (90° relative to incoming flow).

## What this would unlock

- **Rivers and paths.** Connected linear features that can't be done with
  isotropic socket constraints.
- **Direct-placement edge variants for cliffs and levels.** Replace the rule-
  based retiling with placement-time selection — simpler runtime, fewer
  transient invalid states.
- **Asymmetric tiles.** Bridges, ramps, doorways where which side faces "in"
  vs "out" matters.

## Sketch

Tags become parameterized: `river[flow=south]`. `socket_required` uses a
binding syntax: `"river[flow=$X]"` — the `$X` placeholder gets resolved at
placement time against the neighbor's tag, and the placed tile must have a
corresponding `flow` parameter that matches the rule (e.g., 90° rotated).

Implementation challenges:
- Tag parsing and binding semantics (still string-keyed, but with parameter
  resolution).
- Rotation handling — rotating a tile must update its directional tags.
- Backward compatibility — existing non-directional tags continue to work.

## Previous attempts

None on record. The "Level Stacking Sparsity with Self Socket Requirements"
issue solved a different problem (`!ground-type` self-requirement).
