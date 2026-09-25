# Moss detail, bare wall joints and hanging slabs (owner review, September 23)

Owner flags on `02-subtle-moss-terraces`: a flat-bottomed outcrop (photo 7,
top left), bare wall sections (photo 2), darker textured moss that reaches
higher while ledges keep the ground colour. Seed 2697992464; images compare
the previous default with the new one at the same harness cameras.

## Causes and changes

1. **Bare walls.** Colour-by-formation renders showed native wall columns with
   no formation at all. The ground steps a storey along a straight cliff, so
   one face splits into two collinear panels with different bases.
   `RELIEF.panels` treated each as a free end, and both faded out over 2.5 m.
   Panels now mark such ends `left_abut`/`right_abut`; under subtle an abutting
   end fades over 1.2 m (a narrow sloped joint; 0.5 m left a planar end cap)
   and a free end over at most 30% of the panel width. Panels narrower than
   6 m are dressed only when they abut such a neighbour; isolated remnants
   stay bare so they cannot grow freestanding fins. Terrace faces continue one
   buried module into the higher cliff so their junction is mid-run.
2. **Flat-bottomed slab.** An upper-tier convex corner stood on a narrower
   lower tier. The terrace-edge support allowed up to 0.6 m overhang plus
   half-metre sampling, so its flat floor shelved past the tier edge. Corner
   columns with a measured edge (`_nearest_edges`) now stand on it: depth is
   capped at the edge minus 0.2 m at the base and may lean out at most 0.5 m
   above. A 45-degree undercut still read as a slab, and a first per-vertex
   taper folded neighbouring vertices into holes; both were replaced.
   Straight columns under subtle also cannot recede faster than 45 degrees
   going down (`_support_overhangs`), so ledges never end in flat undersides.
3. **Moss.** Darker, cooler lawn-derived green (x0.50/0.66/0.48), modulated
   by a triplanar leaf texture (Raygeas `Grass_1`, a 512 px copy in
   `terrain/materials/cliff_moss_detail.png`), graded to 8 m (was 4.5 m).
   Ledge turf is a separate ground surface and keeps the lawn colour.

## Evidence

- Temporary diagnostics listed every panel decision and hanging underside
  near the reviewed terrace (removed afterwards); colour-by-formation renders
  located the unowned wall columns.
- `tests/test_september23_cliff_directions.gd`: 6 tests (adds the abutting
  collinear panel case). The 81-file cliff sweep matches the previous round
  apart from the September 16 remnant test, which the abut-only rule restores.
- Images: 1-6 previous default vs now; 7 original (pre-September 23) vs now.

## Limits

Joints between abutting panels remain visible as narrow cracks. The slab in
photo 7 is now a thin ledge rather than gone. Moss reaches 8 m and reads
olive on the Amber biome.
