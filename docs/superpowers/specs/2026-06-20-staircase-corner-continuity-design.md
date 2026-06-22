# Staircase Corner Continuity (mating corner pieces) — Design Spec

**Date:** 2026-06-20
**Status:** Approved (design); pending implementation plan
**Branch:** feat/sloped-cliffs
**Builds on:** [2026-06-20-sloped-cliffs-design.md](2026-06-20-sloped-cliffs-design.md), [2026-06-20-sloped-cliffs-gentler-design.md](2026-06-20-sloped-cliffs-gentler-design.md)

## Problem

At a multi-storey staircase, an **outer (convex) corner** one storey above sits diagonally
over an **inner (concave) corner** below, their corner vertices aligned. Both corner
profiles flatten to a horizontal tangent at the storey seam, so instead of one continuous
descent there is a **flat ledge / crease** at the corner. Confirmed in-world at the 50%
band; it is structural (convex-over-concave + the corner formulas `a+b−ab` / `a·b` go flat
at the corner vertex regardless of the ramp shape), so the global ramp tweak ("SHELF_MIX")
could not fix it and was reverted.

## Goal

A 2-storey corner reads as **one continuous S-curve** from the upper plateau, through an
inflection at the storey seam, down to the lower ground — no ledge — by splitting that S
into two **mating half-pieces**: a convex top half (upper tile) and a concave bottom half
(lower tile), selected by heightfield context. Isolated corners are unchanged.

## Continuity requirements (the correctness bar)

The stacked corner pieces must be **C1 (continuous value AND gradient)** at every seam:

1. **Plateau-top seam** (inner side, where the corner meets its own flat plateau): flat
   tangent — unchanged from today.
2. **Same-level edge-seams** (the two cell boundaries where the corner meets the flanking
   `edge` pieces of the same cliff face): value AND cross-gradient must match the **normal
   `edge` profile**, because those flanking edges are NOT changed. ⇒ The mating steepness
   must **taper to flat at the edge-seams.**
3. **Storey seam below** (the corner's outer/diagonal bottom, where it meets the inner
   corner's notch top one storey down): value AND tangent must match the lower piece. ⇒ The
   mating steepness is **maximal at the corner diagonal.**

The combination of (2) and (3) is the central geometric constraint: **the seam tangent
varies across the corner — steep at the diagonal vertex, flat at the two edge-seams.** A
uniformly-steep corner would crease against the flat flanking edges; a uniformly-flat one
is today's ledge. The two stacked halves share this tangent field at the seam, so the
combined surface is C1 across the cell offset.

## Geometry approach

Author both stacked halves from a single 2-storey corner S so they mate by construction:

- **`outer_corner_stacked`** — convex top half. Flat at plateau (req 1); along each
  edge-seam it reduces to the normal `edge` profile with matching cross-gradient (req 2);
  at the corner diagonal it descends to the seam with the shared non-zero tangent (req 3).
- **`inner_corner_stacked`** — concave bottom half. At the corner diagonal its top has the
  same non-zero tangent (mates with the outer's bottom, req 3); along its edge-seams it
  reduces to flat / the lower plateau (req 2); flat at the ground (analogue of req 1).

New profile math goes in `SlopeProfile` (e.g. `outer_corner_stacked_height(x,z)`,
`inner_corner_stacked_height(x,z)`). The exact formulation is derived and **measured
against reqs 1–3 in a prototype task before anything else is built** (see Plan note): the
prototype renders the two halves stacked + flanked by normal edges and a plateau, and a
test asserts the seam values/tangents match numerically.

Meshes/collision are produced by the existing generator/baker as two additional 12×12
components (convex slabs as for the others).

## Detection (heightfield)

`HeightfieldInstantiator` selects the `_stacked` corner variant for a cell's corner when
the staircase context holds. The detection is a pure function of the settled storey field
(`plan.surface_height` / storey is available for any cell, so a wider look is cheap):

- An **outer corner** at cell C (storey s) uses `outer_corner_stacked` at its diagonal
  when the cell diagonally-outward from C is at storey `s−1` **and** is itself an inner
  corner (its own outward diagonal is `s−2`), i.e. the descent continues below.
- The **inner corner** at that lower cell uses `inner_corner_stacked` at the matching
  diagonal (an outer corner at `s+1` descends onto it).

Both sides derive the same condition from the same storey field, so the upper and lower
tiles independently agree to use the mating pair (no cross-tile messaging needed).
Edge cases (a corner stacked on one diagonal but isolated on another; chains of >2
storeys) are enumerated and tested in the plan.

## Scope

- **Primary:** outer-over-inner stacked corners (the observed artifact), fully C1 per reqs 1–3.
- The mechanism generalizes to other stacked combinations (outer-over-outer, inner-over-inner)
  via the same "mate with what's above/below" principle; the plan will note which combos are
  implemented vs deferred so coverage is explicit (no silent gaps).
- Isolated corners, edges, top, and the heightfield placement of non-corner tiles are
  unchanged. Levels/Hills out of scope.

## Risks / approach

- **Largest piece in this effort** — touches heightfield *placement*, not just the slope
  generator.
- **Geometry is intricate** (the tapering seam tangent across a one-cell offset). Mitigation:
  the FIRST implementation task is a geometry prototype with a numeric C1 test + render, gated
  before detection/wiring is built.
- **Detection edge cases** — enumerated and unit-tested against synthetic storey fields
  (the heightfield is a pure function, so this is straightforward to test).

## Testing

- Profile unit tests: seam value + tangent continuity for reqs 1–3 (numeric finite-difference
  checks that the stacked halves mate and that edge-seams match the normal `edge`).
- Mesh/component/variant-scene tests as for the existing slope components.
- Detection unit tests: synthetic storey fields → expected `_stacked` selection, incl. edge cases.
- Visual: in-world render of a real staircase corner showing a continuous descent (no ledge),
  plus an isolated corner unchanged.
- Regression: existing slope + heightfield suites stay green (baseline: the pre-existing
  `test_heightfield_interior_corners` failure is unrelated).
