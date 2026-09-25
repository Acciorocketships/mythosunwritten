# Embedded shoulder and exact solid-union studies

No production promotion. The owner's request for actual bumps, outcroppings and
irregular formations remains open. Production retains pass 69 physical shapes
and pass 74 tread projection repair. No shader or texture change was made.

## What was tried

The first studies modify physical vertex positions after, or within, the final
body envelope. That envelope otherwise flattens some earlier formations.
`embedded.gd` passes the upper-projection regression (6/6 assertions, against a
3/6 baseline), but the tall image retains long upright supports and plain faces.
`finite.gd` and `finite-volume.gd` introduce more finite formations; their native
renders still look pressed onto the wall and develop small dark underedges.
They are rejected. `faceted-volume.gd` was generated but not rendered or accepted.

The next studies use Godot's native CSG union to join actual closed rock solids
to the photographed cliff shell. This preserves native ledge triangles instead
of voxelizing the complete wall. The fixed source is anchor 20, seed 2697992464,
position (-480, 32, -253.5), width 24 m, height 8 m. The same frozen P20 oblique
camera and lighting are used for all four game comparisons.

- `union-world/P20_oblique.png`: native bare Nature rocks. Too blocky, attached
  looking, and angular at their exposed faces. Rejected.
- `moss-union-world/P20_oblique.png`: native ledged moss rocks. Too rectangular,
  with striped, slab-like green surfaces. Rejected.
- `bevel-union-world/P20_oblique.png`: physically beveled convex hulls of native
  Rock 1/2/6, with wider buried feet. Bevels do not remove the underlying block
  composition; flat-topped additions still look attached. Rejected.
- `cluster-union-world/P20_oblique.png`: nine original irregular rounded solids,
  with varied dimensions and broader low bodies. The result is an obvious row
  of pods. This reproduces an explicitly rejected appearance. Rejected.

`blended-facets-world/P20_oblique.png` then tests overlapping physical shoulder
fields with differently oriented face planes and broad contact blending. It
avoids separate pod seams, but still reads as a smooth wall and exposes too much
of the periodic backing near the crown. Rejected, not production.

## Geometry evidence and limits

The source photograph shell has 17,936 triangles. Exact CSG outputs contain
17,466 bare-rock triangles, 15,842 moss-rock triangles, 18,212 beveled-rock
triangles, and 18,996 cluster triangles. The measured generation runs take
roughly 649–816 ms including fixture preparation; this is not a controlled
performance comparison or an acceptable production streaming budget.

The raw unions contain tiny duplicate/sliver triangles. Snapping the moss union
at 0.00001 m and removing duplicate-corner triangles yields 15,840 triangles,
zero unmatched edges, zero degenerate triangles, and signed volume -866.779.
This only establishes that fixture's edge closure and winding.

The cluster cleanup removes two duplicate-corner triangles, leaving 18,994
triangles and zero unmatched edges, but **three sub-threshold slivers remain**.
Its topology check deliberately fails. They are retained in the rejected study
rather than hidden by relaxing the threshold.

CSG runs on the main thread and is not integrated into detached worker planning.
Only the exact photographed shell is replaced in the frozen visual replay;
world collision, grass, wet/public reservations and surrounding terrain are not
regenerated. No collision, fresh-world traversal, broad performance, general
hydraulic or cliff-art acceptance is claimed. Rejected candidates do not change
production code. C01/C02/C03 and the original judging register remain open.

## Reproduction and provenance

Sources, build scripts, raw union meshes and detached arrays are in
`tests/fixtures/september18/cliff-embedded-shoulders/`.
Each `*-union.gd` runs headlessly with Godot 4.5.1. The corresponding
`*-union-replay.gd` is supplied to the existing
`september16_cliff_transition_context.tscn` harness using `--generator`,
`--corner-study`, `--shot=P20_oblique`, and an explicit `--output` directory.
`union-check.gd` and `weld-union.gd` accept `--prefix=cluster-` (or `moss-`);
add `--welded` for the cleaned topology check. Raw arrays remain preserved.

The shape regression's passing projection measurement is not an art-quality
metric. Native visual review overrules it here. `source-hashes.json` records
study sources, images, manifests and the unchanged production baseline.
