# Cliff Terrain Generation — Design

## Goal

Add cliff-bordered plateaus to terrain generation: tall (4-unit) vertical drops that
form clustered, dramatic elevated regions distinct from the existing 0.5-unit "level"
plateaus. Cliffs spawn rarely but, once seeded, propagate strongly to nearby positions
so they form coherent regions rather than scattered isolated bumps. The interior of
a cliff plateau is a normal ground tile (with grass / trees / further cliffs spawning
on top), so multi-storey cliffs emerge naturally from the existing ground-generation
rules.

## Approach

Mirror the existing [LevelEdgeRule](../../../scripts/terrain/rules/LevelEdgeRule.gd)
pattern: all cliff variants share **identical socket layouts** (all 4 cardinals
`required=["cliff"]`, high lateral fill), and a new `CliffEdgeRule` retiles
each placed cliff piece to the correct visual variant based on actual connectivity
after placement. Direct placement via fill probabilities was considered and rejected
because the generator is incremental — at the moment of placing a cliff piece, only
existing-neighbour adjacency is known, and the rotation search cannot infer the
plateau shape needed to pick the right variant. The level system encountered this
same problem (it needs directional tags to do direct placement, which were removed
as overcomplicated). Mirroring its solution keeps cliffs consistent with that
proven pattern.

## Variant set (4 edge tiles + interior module)

Analysis (see "Variant impossibility proof" below) shows that with ≥2x2-wide
plateaus enforced, only four cliff edge configurations can actually occur. Plus
an interior module for inside-the-plateau positions:

| Variant | Asset | Canonical missing sockets | Description |
|---|---|---|---|
| cliff-edge | `CliffSide.tscn` (exists) | `["front"]` | 1 cardinal is a drop. |
| cliff-outer-corner | `CliffCorner.tscn` (exists) | `["front", "left"]` | 2 adjacent cardinals are drops. |
| cliff-inner-corner | `CliffInCorner.tscn` (to author) | `["frontleft"]` | All 4 cardinals connected, 1 diagonal missing. |
| cliff-inner-corner-diag | `CliffInCornerDiag.tscn` (to author) | `["frontleft", "backright"]` | All cardinals connected, 2 opposite diagonals missing. |
| cliff-interior | uses `GroundTile.tscn` | all cardinals + no diagonals missing | Inside-the-plateau position. Visually a ground tile but tagged for cliff connectivity. |
| (no match) | — | anything else (line / peninsula / island / impossible diagonals) | Rule leaves the piece unchanged; re-evaluates next placement. Steady-state regions don't end up here. |

The **cliff-interior** module is the most subtle piece. It reuses
`GroundTile.tscn` as its scene (so the visual is identical to ground), but it
is registered as a *separate* `TerrainModule` with tags
`["cliff", "ground-type", "24x24x4"]` and **non-expandable lateral cardinals**
(`fill_prob = null`). The reasons:

- The `"cliff"` tag satisfies surrounding cliff-edge cardinals'
  `socket_required = ["cliff"]` — without it, a later cliff-edge placement adjacent
  to a swapped-in interior could fail its required-tag filter.
- The `"ground-type"` tag lets the existing ground-tile topcenter distributions
  spawn grass / trees / further cliffs on top, achieving the user's stated intent
  ("the interior will have all the same generation rules as normal ground").
- Non-expandable cardinals because the lateral perimeter is already covered by
  cliff-edges; the interior should not try to grow the plateau itself.

## Tile geometry & sockets

All 4 cliff variants share an identical 24×24 footprint, 4 units tall, with the
tile origin at the **top** surface (project convention — same as ground tile, just
taller). The base of the cliff lands at world y=0; the top surface and walkable
plateau is at world y=+4.

| Socket | Local position | Purpose |
|---|---|---|
| `front` | `(0, 0, -12)` | top-elevation cardinal; required=`cliff` |
| `back`  | `(0, 0,  12)` | top-elevation cardinal; required=`cliff` |
| `left`  | `(-12, 0, 0)` | top-elevation cardinal; required=`cliff` |
| `right` | `( 12, 0, 0)` | top-elevation cardinal; required=`cliff` |
| `frontleft`  | `(-12, 0, -12)` | top-elevation diagonal marker for inner-corner detection |
| `frontright` | `( 12, 0, -12)` | top-elevation diagonal marker for inner-corner detection |
| `backleft`   | `(-12, 0,  12)` | top-elevation diagonal marker for inner-corner detection |
| `backright`  | `( 12, 0,  12)` | top-elevation diagonal marker for inner-corner detection |
| `bottom` | `(0, -4, 0)` | base of cliff; attaches to ground tile at world y=0 |
| `topcenter` | `(0, 0, 0)` | for grass/trees/multi-level cliff stacking on top |

Cardinal `fill_prob` is high (target **0.7**, tunable) to drive strong lateral
propagation — when a cliff is seeded, it aggressively recruits neighbours. Bottom
socket attaches via the parent ground tile's `topcenter`. Topcenter on the cliff
follows the same distribution as a normal ground tile's `topcenter` so grass,
trees, and further cliff-seeding all work on top of cliff interiors.

`replace_existing = true` on all cliff variants so the rule can swap one variant
for another in place without conflict.

## 3D size system migration

To support tiles of varying height with the same lateral footprint, the size tag
becomes 3D. The existing tags rename:

| Old | New |
|---|---|
| `"24x24"` | `"24x24x0.5"` |
| `"12x12"` | `"12x12x2"` |
| `"8x8"` | `"8x8x2"` |
| `"point"` | `"point"` (unchanged) |
| (new) | `"24x24x4"` for cliffs |

The size tag still serves both roles: test piece lookup (so adjacency probing
uses sockets at the correct heights) and module filtering. No logic changes — just
string updates in `TerrainModuleDefinitions.gd`, the test pieces, and tests.

A new test piece `create_24x24x4_test_piece()` mirrors the cliff socket layout
so `get_adjacent_from_size` probes lateral neighbours at y=+4 (not y=0).

## Seeding & propagation

`load_ground_tile()`'s `top_tag_prob_center` distribution gains a small probability
weight for cliffs, alongside the existing level seeding:

```gdscript
var top_tag_prob_center: Distribution = Distribution.new({
    "level-ground-center": 0.95,
    "cliff-edge": 0.05,
})
var top_size_dist_center: Distribution = Distribution.new({
    "24x24x0.5": 0.95,
    "24x24x4": 0.05,
})
```

Seeding uses the `cliff-edge` tag specifically (not the broader `cliff` tag)
so the initial sampled tile is the expandable edge variant — never the
cliff-interior (whose non-expandable cardinals would freeze plateau growth at
size 1).

Net per-ground-tile cliff seed rate = `top_fill_prob_center × 0.05 = 0.2 × 0.05
= 1%`. Once seeded, the cliff's cardinal sockets at `fill_prob=0.7` aggressively
recruit cliff neighbours, producing the clustered-region behaviour.

Cliff interiors (positions where the rule swaps in a normal ground tile) carry
the standard ground-tile `topcenter` distribution, so a second-storey cliff can
seed on top of a first-storey cliff via the normal mechanism.

## `CliffEdgeRule`

Lives at `scripts/terrain/rules/CliffEdgeRule.gd`. Same shape as
[LevelEdgeRule](../../../scripts/terrain/rules/LevelEdgeRule.gd), trimmed to the
4-variant set, with two new behaviours: swap-to-cliff-interior for inside-
plateau positions, and an eventually-consistent fallback (leave unchanged) for
intermediate states that haven't yet matured into a valid variant.

### Activation

`matches()` returns true when `context.chosen_piece.def.tags.has("cliff")`.

### `apply()` (mirrors LevelEdgeRule, with differences noted)

1. Walk the affected pieces (the placed piece + direct cliff neighbours +
   neighbour-of-neighbours), same as LevelEdgeRule.
2. For each affected piece, compute its `missing_sockets` from cliff connectivity
   using the same logic as LevelEdgeRule (cardinals + diagonals where both
   adjacent cardinals are connected).
3. Map missing-socket-set to target variant:
   - `[]` → swap to **cliff-interior** (the GroundTile-scene-with-cliff-tag module)
   - matches `["front"]` (rotated) → cliff-edge
   - matches `["front","left"]` (rotated) → cliff-outer-corner
   - matches `["frontleft"]` (rotated) → cliff-inner-corner
   - matches `["frontleft","backright"]` (rotated) → cliff-inner-corner-diag
   - **anything else (peninsula / line / island / >1 diagonal-missing cases) →
     keep the piece as-is**: no swap, no delete. The piece remains as whatever
     variant it currently is. The next rule pass — triggered when a neighbour
     spawns — will re-evaluate and may convert it to a valid variant then.
4. Compute rotation steps to align canonical missing set with actual missing,
   reusing LevelEdgeRule's `_rotation_steps_to_align_canonical` algorithm.
5. Spawn replacement, preserve transform, apply rotation. Return
   `chosen_piece` and `piece_updates`.

### Differences from LevelEdgeRule

- **Swap to cliff-interior for interior.** When `missing_sockets == []`,
  replacement is the cliff-interior module (defined above) — visually a ground
  tile, but tagged with `"cliff"` so neighbour cliff-edges' required-tag filters
  remain satisfied. LevelEdgeRule keeps a dedicated `level-center` tile; cliffs
  reuse the ground-tile scene with a cliff-aware tag set.
- **Eventually-consistent fallback (no peninsula/line/island variants).** When a
  piece's missing-socket pattern doesn't match any of the 4 variants, the rule
  leaves the piece untouched and waits for more neighbours to arrive. Why not
  delete? Because the very first cliff seeded from a ground tile has 0 cliff
  neighbours and would match no variant — deleting it would prevent any cliff
  from ever forming. With high lateral fill (~0.7), each cliff piece quickly
  recruits multiple neighbours, so invalid intermediate states resolve into
  valid variants within a few generation cycles. Rare leftover "stuck" 1-wide
  protrusions remain as cliff-edge variants — visually imperfect but acceptable
  and infrequent given the fill probability.
- **Initial seed variant: cliff-edge.** The ground-tile topcenter samples
  `cliff-edge` specifically (not just any cliff variant). Cliff-edge has
  expandable cardinals at high fill probability, so it actively grows the
  plateau. Other variants (corners, inner-corners) only arise via the rule's
  re-tiling pass. Cliff-interior is only ever produced by the rule, never by
  direct sampling, because its non-expandable cardinals would freeze plateau
  growth.
- **No tier system (level-ground / level-stack).** Cliffs are monolithic at 4
  units, so the level-stack mechanism (vertically-only-growing tier) isn't needed.
  Multi-storey cliffs emerge because cliff interior includes the ground-tile
  topcenter behaviour, and that distribution can itself seed a fresh cliff.

### Registration

Add to [TerrainGenerationRuleLibrary](../../../scripts/terrain/TerrainGenerationRuleLibrary.gd):
```gdscript
rules.append(CliffEdgeRule.new())
rules.append(LevelEdgeRule.new())
```

Order doesn't matter functionally (the two rules' `matches()` check disjoint tag
sets — `"cliff"` vs `"level"`), but list cliffs first as a convention since they
spawn from level / ground tiles.

## Variant impossibility proof

**Claim:** In a fully-generated, steady-state cliff plateau (every piece's
fill-prob expansion has had a chance to run), only `cliff-edge`,
`cliff-outer-corner`, `cliff-inner-corner`, `cliff-inner-corner-diag`, and
`cliff-interior` configurations are reachable. The high lateral fill prob makes
line/peninsula/island configurations transient: each cliff piece statistically
recruits ≥2 cliff neighbours, so 1-wide protrusions and isolated pieces only
exist briefly at the generation frontier before being incorporated into larger
plateaus.

**Setup:** Let T be a cliff tile at `(1,1)`. Cardinal axes: front=-z, back=+z,
left=-x, right=+x.

**Lemma:** *"2 adjacent diagonals missing with all 4 cardinals connected" is impossible.*

Suppose frontleft and frontright are both non-cliff while all 4 cardinals are
cliff. The cardinal between them — `(1,0)` (T's front) — has:
- back = T (cliff)
- left = `(0,0)` = frontleft of T (non-cliff)
- right = `(2,0)` = frontright of T (non-cliff)
- front = `(1,-1)` (unknown)

Whatever `(1,-1)` is, `(1,0)` has either 1 cardinal connected (back) → peninsula,
or 2 *opposite* cardinals connected (back + front) → line. Both are invalid under
≥2x2, so `(1,0)` would be deleted — contradicting "T's front cardinal is
connected." ∎

**Eliminated by the lemma:** `inner-corner-side` (2 adjacent diagonals),
`inner-corner-three` (3 diagonals — contains 2 adjacent), `inner-corner-all` (4
diagonals — contains 2 adjacent), `inner-corner-side-edge` (contains 2 adjacent
diagonals).

**Eliminated by ≥2x2 directly:** `line`, `peninsula`, `island`.

**Eliminated by visual irrelevance for cliffs:** `inner-corner-edge1`,
`inner-corner-edge2`, `inner-corner-edge-both`. In the level system these encode
how a rounded slope wraps around a missing-diagonal corner. The cliff equivalent
is a flat vertical wall, which doesn't need to wrap — adjacent edge/corner tiles'
walls meet at 90° angles naturally.

**Remaining (all 4 reachable):** `edge`, `outer-corner`, `inner-corner`,
`inner-corner-diag`.

## Files to add or modify

### New files
- `terrain/scenes/CliffInCorner.tscn` *(author by user)*
- `terrain/scenes/CliffInCornerDiag.tscn` *(author by user)*
- `scripts/terrain/rules/CliffEdgeRule.gd`
- `docs/future-work/directional-socket-tags.md` *(see below)*

### Modified files
- `terrain/scenes/CliffSide.tscn` *(user — verify / add full socket layout per spec)*
- `terrain/scenes/CliffCorner.tscn` *(user — verify / add full socket layout per spec)*
- `scripts/terrain/TerrainModuleDefinitions.gd` — add `load_cliff_edge_tile()`,
  `load_cliff_outer_corner_tile()`, `load_cliff_inner_corner_tile()`,
  `load_cliff_inner_corner_diag_tile()`, `load_cliff_interior_tile()` plus a
  `_build_cliff_tile()` helper that mirrors `_build_level_tile()`; add
  `create_24x24x4_test_piece()`; rename existing 2D size tags to 3D; update
  `load_ground_tile()` distributions to include cliff seeding.
- `scripts/terrain/TerrainModuleLibrary.gd` — register cliff tiles
  (incl. cliff-interior) in `load_terrain_modules()` and the cliff test piece
  in `load_test_pieces()`.
- `scripts/terrain/TerrainGenerationRuleLibrary.gd` — register `CliffEdgeRule`.
- `tests/test_terrain_generator.gd` — update size-tag strings; add cliff tests.
- `tests/test_terrain_module_library.gd` — update size-tag strings.

### Deleted / superseded
- `docs/future-work/cliffs-and-floating-islands.md` — narrower scope than this
  spec; delete and rely on follow-up items in this spec instead. Floating
  islands remain future work but live as their own item.

## Future work (deferred from this spec)

1. **Directional socket tags** — required for direct-placement of edge tiles
   (alternative to rewrite rules), and useful for laying rivers and paths in the
   future. Logged as `docs/future-work/directional-socket-tags.md`.
2. **More cliff variants and larger cliff pieces** — different heights, composed
   cliff shapes. (Previously logged in `cliffs-and-floating-islands.md`, which is
   replaced by this spec.)
3. **Floating islands** — empty/void tile support so cliffs / levels can have
   gaps underneath.

## Tests

`tests/test_terrain_generator.gd`:
- Generate a region with enough ground tiles that cliff seeding fires at least
  once (use a fixed seed for determinism).
- For pieces inside fully-generated areas (away from generation frontier),
  assert each cliff piece has ≥2 *adjacent* cliff cardinal neighbours — i.e.,
  no peninsula / line / island configurations remain in steady-state regions.
- Assert each cliff piece's variant tag matches its canonical missing-socket
  pattern, modulo rotation (proves the rule is correctly retiling).
- In a large enough seeded region, assert at least one of each variant
  (cliff-edge, cliff-outer-corner, cliff-inner-corner, cliff-interior) is
  present (sanity: the rule produces all variants). cliff-inner-corner-diag
  is rare enough that it shouldn't be required.

## Open questions / risks

- **Stuck 1-wide protrusions.** With the eventually-consistent fallback, a
  cliff piece can stay as an unmatched cliff-edge if its neighbours never
  materialize (e.g., generation reaches a render boundary). The visual is a
  cliff-edge in its default orientation rather than a proper plateau corner.
  Mitigation: high lateral fill prob (0.7) makes this rare; the test suite
  asserts the invariant in regions that have fully generated.
- **Two-storey cliff visual.** A cliff on top of a cliff (via the interior
  ground-tile's topcenter) sits 4 units higher with its own 4-unit wall — total
  visible cliff face of 8 units. Confirming this looks correct visually is part
  of acceptance.
- **Cliff-level boundary.** When a cliff plateau borders a level plateau (rare
  but possible), the cliff is at +4 and the level is at +0.5 — they don't
  physically overlap. The level's edge variant may pick incorrectly at the
  boundary because LevelEdgeRule doesn't re-evaluate level neighbours when a
  cliff replaces a ground tile. Acceptable v1 limitation; flag if it shows up.
- **Test piece spawning.** When a cliff socket triggers expansion, the new
  cliff is positioned via the `24x24x4` test piece. If the test piece's bottom
  socket doesn't precisely match the cliff variants' bottom socket position
  (local y=-4), placement will be misaligned. Test piece and variants must
  share the exact socket layout.
