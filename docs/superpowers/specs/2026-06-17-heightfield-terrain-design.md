# Heightfield-Driven Terrain — Design

## Goal

Replace the emergent socket-growth + retiling structural terrain with a
**deterministic heightfield plan**. A continuous height field `H(x,z)` is
quantized into discrete tile elevations ahead of placement; tiles are then
instantiated to match that plan when the player walks near. Because a tile's
elevation, type, and variant are all pure functions of position, they never
change after placement.

This delivers four things the user asked for:

1. **No churn.** The "appear-then-disappear / retile" class of bugs disappears
   by construction — placement reads a frozen plan, it is not itself the
   generative process.
2. **Speed.** No per-frame socket expansion, sparsity rolls, cluster-fill
   convexification, or edge re-evaluation. The hot path becomes "read plan cell
   → instantiate tile."
3. **Tunability.** Terrain shape is controlled by an understandable band table
   (which height ranges become which tile) and noise parameters, not by
   socket fill probabilities.
4. **Taller mountains.** Mountains are staircases of cliff storeys produced
   directly by the height field; raising the field's amplitude makes them
   taller without new rules.

## Background

The current generator grows terrain outward from sockets, choosing tile
variants from neighbour occupancy and re-tiling edges as neighbours fill in.
Retiling is the root cause of visible churn: an edge tile swaps variant (or a
level/cliff overwrites another via `replace_existing`) as the frontier
advances. Prior mitigations (reveal margin in `TerrainGenerator.gd`, pop-budget
decoupling, tiered placement priority) reduce the *symptom* but the emergent
architecture makes it fundamental.

A previous attempt to make cliff variants a pure field function failed: the
cliff footprint is contour + `ClusterFillRule` convexification + sub-threshold
seeds, not a field function, so incremental socket expansion cannot exactly
realize a field. This design removes that mismatch by making the **whole
structural surface** a field function and dropping incremental expansion for
structure entirely.

## The model

### Vertical vocabulary (unchanged assets)

- **Level tile** — 0.5m tall step, gentle terraces.
- **Cliff tile** — 4m tall step (= 8 level steps), mountains.
- Walls are **never scaled** and **never stacked** (no 2+ tiles exposed on one
  face). The existing per-side variant set (side / corner / inner-corner /
  peninsula / island …) is reused to render which sides of a tile are walls.

### The invariant

Every pair of cardinally-adjacent tiles differs in rendered height by exactly
**0, 0.5, or 4 metres** — nothing else. With fixed wall heights, no scaling and
no stacking, this is the *only* renderable set of adjacent drops, so the entire
design exists to guarantee it.

### Pipeline

```
H(x,z)  →  per-tier residual quantization  →  trickle-down clamp  →  plan cell
                                                                       │
                                          (numerical, computed to plan radius)
                                                                       ▼
                                              instantiate tile  (at place radius)
```

1. **Height field `H(x,z)`** — layered value/simplex noise, biome-scaled
   amplitude (meadow flat, rocky tall/steep). Pointwise; needs no horizon.

2. **Per-tier residual quantization (largest unit first).** Walk tiers from
   largest unit to smallest. This is one loop, identical shape per tier — cliffs
   and levels are tier 0 and tier 1, not special cases.

   For tier `T` with unit `u_T` (cliff: 4.0, level: 0.5):
   - `target_T(t) = round(remaining(t) / u_T)` — the tier's quantization of the
     height not yet captured by larger tiers.
   - Restrict to **central** tiles: a tile may take a tier-`T` step only if it is
     not on the edge of any *larger* tier (see Central/edge rule).
   - **Trickle-down clamp** in this tier's own unit (see Clamp).
   - Subtract placed height into `remaining` and pass the residual to the next
     tier.

   Working per-tier in the tier's own unit is essential: a cliff is 8 level
   units, so a clamp measured in level units would treat every cliff as a
   violation and erase all mountains. The central/edge rule is what isolates the
   scales.

3. **Central / edge rule.** When placing tier `T`, for each neighbour:
   - neighbour a **step down** in a larger tier (a cliff-top edge) → **skip**
     this tile for tier `T`. Raising it would make the larger drop exceed the
     wall height and gap.
   - neighbour a **step up** in a larger tier (a cliff-bottom edge) → **ignore**
     that neighbour and proceed. Raising the tile just builds a terrace at the
     foot of the cliff, occluding the bottom of the cliff face — no gap.

4. **Trickle-down clamp (per tier).** Enforce adjacent tiles differ by ≤1 step
   in this tier:
   `height(t) = min( height(t), min_neighbour_height + 1 step )`, iterated to a
   fixpoint. A tile whose neighbours span more than one step on each side (a
   neighbour +1 and a neighbour −1) sits at the middle (+0); where the source
   field is steeper than one step per tile, the higher side is lowered and the
   change cascades outward ("mountains trickle down") until the invariant holds.

   This is a **monotone potential clamp**: it has a unique fixpoint that is a
   pure function of `H`, so the result is independent of processing order — the
   opposite of the rejected edge-delta relaxation, which constrained edges
   (over-determined) and was order-dependent. The clamp only fires where `H` is
   steeper than one step per tile; on smooth `H` it does nothing.

### Why placement is type-stable

A plan cell stores its elevation. A tile's **type** (level vs cliff face) and
**variant** (which sides are walls/corners) are read from the differences to
neighbour plan cells — all already settled. So type and variant are as stable as
elevation.

## Churn-freedom: plan radius vs place radius

The numerical plan is computed to a **plan radius** larger than the **place
radius** at which tiles are instantiated:

```
plan_radius − place_radius  ≥  max trickle-down distance
                            =  tallest mountain measured in tiles
```

A peak's clamp influence fans out one step per tile and no farther, so once the
plan extends beyond the place radius by the tallest-mountain-in-tiles, every
tile is fully settled before it is ever instantiated — a placed tile only ever
*reads* a final value. Capping max mountain height bounds the margin. The plan
is arrays only, so even a generous margin is a few hundred extra cells.

This is the core anti-churn guarantee and replaces the current reveal-margin
hide mechanism for structure.

## Tuning surface

- **Band table** — height ranges → tier unit. Sliding band edges tunes
  prevalence independently of noise amplitude (e.g. a `[0, floor)` dead band
  kills low-amplitude level spam; lowering the cliff band edge yields more
  cliffs). Replaces socket fill-rate constants in `TerrainModuleDefinitions.gd`.
- **Noise params** — per-biome amplitude/frequency set mountain height and how
  often the clamp fires.
- **Aggregation knob (min/max/mean)** — the rounding direction when `H` sits
  between rungs at the quantization step: min rounds down (hugs valleys, fewer
  raised tiles), max rounds up (builds terrain up), mean is nearest. The clamp
  itself is always a `min` (it only lowers); this knob shapes the pre-clamp
  target. Config-selectable.
- **Max mountain height** — caps the plan margin.

## What is kept vs replaced

**Kept:** water / banks (already a deterministic field via `WaterRule.gd`),
decorations / foliage, the per-side variant tile assets and the variant
selection logic (now fed by plan neighbour-deltas instead of live occupancy),
the terrain index, plan-vs-place streaming scaffolding.

**Replaced / removed for structure:** `CliffEdgeRule.gd`, `LevelEdgeRule.gd`,
`ClusterFillRule.gd` retiling/convexification, socket expansion + sparsity rolls
for structural tiles, `replace_existing` overwrite churn between level/cliff.

## Testing strategy

1. **Invariant test (unit, fails first).** Over a seeded plan region, assert
   every cardinal adjacent pair differs by exactly 0, 0.5, or 4. No gaps.
2. **Determinism test.** Compute the plan for a tile from two different plan
   windows (both ≥ required margin); assert identical elevation/type/variant.
3. **Churn harness.** Reuse `tests/harness/burst_harness.gd`; assert
   `churn_total == 0` for structural families (cliff/bank, level) while running.
4. **Player-safety regression.** Keep `tests/test_player_safety.gd` green — no
   tile of any kind spawns on/traps the player.
5. **Clamp convergence test.** A steep synthetic `H` produces a finite staircase
   and the clamp reaches a fixpoint within the bounded margin.
6. **Visual iteration.** Screenshots: terraced hills, cliff staircases for
   mountains, terraces at the foot of cliffs, no vertical gaps.

## Out of scope

- Decoration/foliage redesign (placement stays as-is, reading the new plan for
  surface height).
- Water/bank rule changes beyond reading the new plan elevations.
- Smooth-sided wall textures (a future asset change; the no-stacking invariant
  is what makes it safe).
- Rock collision-mesh work in progress (`rock_2_e_color_12.tscn`,
  `rock_3_h_color_12.tscn`) — untouched.

## Sequencing

Full rewrite + simplification of the structural pipeline on
`feat/heightfield-terrain`, prototype-and-validate first: build the numerical
plan + invariant/determinism tests before wiring instantiation, then swap the
emergent rules out. Keep water/banks/decorations throughout.
