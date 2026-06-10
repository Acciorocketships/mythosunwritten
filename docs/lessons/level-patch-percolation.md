# Level patches are a percolation system; lateral fill_prob sits at the critical threshold

## TL;DR

Lateral expansion of level tiles is **2D bond percolation on a square lattice**. The
mathematical critical threshold is exactly `p_c = 1/2`. Our authored
`LEVEL_BASE_LATERAL_FILL_PROB = 0.5` sat *exactly* on this threshold, hidden by an
incidental "site dilution" from decoratives (grass/rock/tree/bush) blocking ~40% of
ground tiles. Setting `replace_existing = true` on level modules removed that
dilution — level placements now vaporized the decoratives instead of failing — and
exposed the bare-lattice critical point. Lateral patches went from naturally bounded
("a few connected tiles") to effectively unbounded ("fill the explored world"),
which then drove vertical stacking far higher via the natural pyramid mechanism.

The vertical "explosion" was a downstream symptom, not the actual bug. The bug
was a probability tuned to a critical point that *appeared* safe only because
of an undocumented secondary mechanism.

## What we observed

Enabling `replace_existing` on level modules caused vertical stacks of
`level-stack-center` to reach y ≥ 4.0 within a 25s headless run, with hundreds of
tiles at each y level. Intuitively this should not have happened, because:

1. `socket_fill_prob` should limit expansion probability.
2. Level tiles can only stack on level-center tiles, and `LevelEdgeRule` retiles
   any piece without all four cardinal neighbors to a non-center variant whose
   `topcenter` fill_prob is `null`. So each layer up should be strictly smaller
   than the layer below, yielding a finite pyramid.

Both arguments are correct. They just don't bound the pyramid as tightly as
expected, because the *base* of the pyramid is itself unbounded under the
authored settings.

## How the level system actually generates patches

Lateral expansion of `level-ground-center` proceeds as follows. When a
`level-ground-center` is placed, each of its four cardinal sockets
(`front`/`back`/`left`/`right`) has independent probability
`LEVEL_BASE_LATERAL_FILL_PROB = 0.5` of being enqueued and then expanding into a
new `level-ground-center` (tag-sampled with `level-ground-center` weight 1.0).
That neighbor in turn has the same chance on each of its four cardinals, and so
on.

This is exactly **bond percolation on a 2D square lattice**:

- Sites are ground-tile XZ positions (lattice cells on the 24-unit grid).
- Each lattice edge between adjacent sites is "open" with probability `p`
  (independent of other edges) when the level lateral expansion fires.
- A level patch is the connected component of open edges starting from a seed
  `level-ground-center` (placed via the ground tile's `topcenter` expansion at
  `top_fill_prob_center = 0.2`).

For 2D bond percolation on the square lattice, Kesten's theorem gives exactly
`p_c = 1/2`. Below this, all clusters are finite and their sizes decay
exponentially. At `p_c`, cluster sizes follow a power-law and grow without
bound in a growing lattice. Above `p_c`, an infinite percolating cluster forms.

Our authored value `p = 0.5` sits *exactly* on the critical line.

## Why this normally appeared bounded

The level lateral expansion isn't quite pure bond percolation; the ground also
generates decorative items on the same cells:

- 20% of ground tiles get a `level-ground-center` on their `topcenter`.
- ~40% of ground tiles get a decorative (grass/rock/bush/tree/hill) via the
  ground's top corner / cardinal sockets.

A decorative on the cell next to a level patch *blocks* lateral expansion into
that cell when `replace_existing = false`. `can_place` finds the decorative as
a non-ground, non-parent overlap and returns false, so the level sample is
discarded and the patch terminates in that direction.

This is *site dilution* of the percolation lattice: roughly 40% of sites are
unavailable. The effective threshold for site-diluted bond percolation is
higher than the bare-lattice threshold (the precise value depends on how the
site probability composes with edge probability, but the qualitative shift is
robust). Our `p = 0.5` was therefore *subcritical against the diluted lattice*
— clusters were small, naturally bounded, and the pyramid stayed short.

The system worked, but for a reason nobody had written down: an incidental
correlation between decorative placement and "blocks level expansion".

## What `replace_existing = true` actually changed

The commit message for `1786e5c` described the change as:

> Lets a new level placement remove and replace overlapping non-ground pieces
> (typically other level variants) rather than failing can_place.

The intent was to handle level-on-level overlap during retile. But the
implementation in
[`TerrainGenerator.add_piece`](../../scripts/terrain/TerrainGenerator.gd) is
indiscriminate: when `replace_existing` is true, *all* non-ground non-parent
overlapping pieces are removed, including decoratives. And `can_place` returns
`true` unconditionally for `replace_existing` modules.

Empirically (7s run), the replace-existing block removed 46 decoratives —
grass, rock, tree, bush, even small hills — to make room for advancing level
patches. The level system no longer respected the decoratives blocking its
spread.

**The site dilution disappeared. The lattice was now bare. `p = 0.5` was at
the critical threshold.**

## Empirical confirmation of the phase transition

We held seed rate fixed (`top_fill_prob_center = 0.01`, deliberately tiny to
prove that seed rate isn't the cause) and `replace_existing = true`, then
varied `LEVEL_BASE_LATERAL_FILL_PROB` (15s headless runs):

| `p` (lateral) | total level placements | max y reached |
|---------------|------------------------|---------------|
| 0.20          | 29                     | 1.0           |
| 0.30          | 61                     | 1.0           |
| 0.40          | 558                    | 2.5           |
| 0.45          | 864                    | 3.5           |
| 0.50          | 1036                   | 4.0           |

The discontinuity between 0.3 and 0.4 is the classic critical-window signature.
Below `p_c` the patch starves out exponentially; above (or near) `p_c` it eats
the whole explored area, and the pyramid amplifies the difference vertically.

For comparison, the original setting (`p = 0.5`,
`top_fill_prob_center = 0.2`) on 7s runs produced:

| config | `level-ground` placements (y=0.5) | max y |
|--------|-----------------------------------|-------|
| `replace_existing = false` | 379 | 1.5 |
| `replace_existing = true`  | 568 | 3.5 |

The y=0.5 count grew only ~50% with `replace_existing = true`, but max y grew
from 1.5 to 3.5. This is the pyramid amplifying small lateral differences into
large vertical ones — the inner `(N-2)x(N-2)` of a contiguous `NxN` patch
becomes the base of the next level up, so even small base-size differences
produce large height differences after a few layers.

**Crucially, lowering the seed rate to 0.01 (20× less than the authored value)
did nothing**: still 1036 placements at `p = 0.5`. A single seed was enough to
fill the explored area once decoratives no longer blocked expansion. The
controlling parameter is `p`, not the seed rate.

## How the vertical pyramid actually works

For completeness, the vertical mechanism is mechanical, not stochastic:

1. A `level-ground-center` at y=0.5 with `topcenter` fill_prob = 1.0 spawns a
   `level-stack-center` at y=1.0 (each stack adds +0.5 in y, derived from
   `topcenter` local y=0 and `bottom` local y=-0.5).
2. `LevelEdgeRule` immediately retiles the new piece based on how many of its
   four same-y cardinal neighbors are level. Zero connected → `level-island`,
   one → `peninsula`, two → `line`/`corner`, three → `side`, four →
   `level-center`.
3. Non-center variants have `topcenter` fill_prob = `null`. They do *not*
   stack further. Only `level-center` keeps the topcenter expandable.
4. As more level pieces accumulate at the same y, `LevelEdgeRule` re-runs over
   affected pieces (chosen + cardinal neighbors + their neighbors). Pieces that
   gain cardinals can be retiled *up* the variant ladder, all the way to
   `level-center` if they end up with all four. A center that arises this way
   has its topcenter enqueued (the module def's fill_prob = 1.0 takes effect
   on `add_piece_to_queue`).
5. So at each y, only the inner part of the patch (cells with all four
   cardinal neighbors at that y) stacks further. Each layer is at most
   `(N-2) x (N-2)` of the layer below for a contiguous `NxN` base.

This is correct and intentional. It produces a clean stepped pyramid when the
base is finite. It produces an unbounded tower when the base is unbounded.

## The lesson

**Don't tune a percolation/cascade probability to its critical value, even
incidentally.**

A probability is "safe" subcritically and "explodes" supercritically; the
threshold is a phase boundary, not a gradient. If your system's `p` sits at or
near `p_c`, then:

- Output looks fine for small samples and "explodes" for large ones, because
  cluster size at `p_c` follows a power-law and has no characteristic scale.
- Tiny changes in `p` (or in any secondary mechanism that effectively shifts
  `p`) cause dramatic, qualitatively different behavior. Code that *seems*
  unrelated — like "replace decorative items when overlapping" — can be the
  thing holding `p` below `p_c` via site dilution.
- Reviewers won't catch it because there's no obvious bug. The numbers look
  reasonable in isolation.

For our level system specifically: `p = 0.5` for a single fill_prob driving
expansion on a 4-connected grid is the *exact* analytical threshold. There is
no value more dangerous to author.

### General heuristics

- For cascade/percolation systems on regular lattices, target `p` well below
  `p_c` (factor of ~1.5–2× headroom). On a 4-connected square lattice that
  means `p ≤ 0.35` or so.
- Sanity-test cascade systems by varying the parameter across the suspected
  critical region (e.g., `p ∈ {0.2, 0.3, 0.4, 0.5}`) on long runs and looking
  for discontinuities, not just monotone trends.
- If a system "works because of" a secondary mechanism (e.g., decorative
  blocking), document that the secondary mechanism is load-bearing. Changing
  it then becomes a conscious decision instead of an invisible regression.
- When investigating "unbounded" behavior, ask whether the system has any
  positive-feedback loop characterized by an independent per-step probability.
  If so, suspect a phase transition before suspecting a logic bug.

## Outcome

`LEVEL_BASE_LATERAL_FILL_PROB` was reduced from `0.5` to `0.35` —
unambiguously subcritical against the bare lattice, with enough headroom to
remain subcritical even if a future change re-introduces decorative-vaporizing
behavior. This is the durable fix; it does not depend on incidental site
dilution.

`replace_existing` on level modules was left at `false` for now (its intended
"level-on-level retile" use case wasn't actually needed by current systems and
the indiscriminate decorative removal was the larger side effect). If it is
re-enabled in the future, the lateral fill_prob already has the headroom to
absorb the loss of dilution.

## References

- Kesten, H. (1980). *The critical probability of bond percolation on the
  square lattice equals 1/2.* Comm. Math. Phys. 74, 41–59.
- Commit `1786e5c` — original "enable replace_existing on level tiles"
  change.
- Investigation conversation, 2026-05-23.
