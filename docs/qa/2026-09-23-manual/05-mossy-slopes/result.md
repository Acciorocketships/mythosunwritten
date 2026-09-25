# Mossy talus slopes with protruding rocks (owner trial, September 23)

Owner: Raygeas moss is selected. Try mossy slopes on the lower cliff with
exposed rock above and rocks protruding (reference: chunky layered rocks);
extend the lawn-colour gradient and make the secondary colour patchier; the
slopes should have rolling ridges and mesh with ground, wall and rocks.
Images: chosen (default) | slopes, same cameras, seed 2697992464.

## Default style changes (chosen)

- The lawn colour fades up into the moss over 4 m (was 1.6 m) and reappears
  in broad patches above it (`moss_blend_height`, `moss_secondary`).
- Moss texture stays `raygeas`.

## `slopes` trial (CliffRockStyle "slopes"; not default)

- Below a varying height (36-66% of the wall; higher on ridges) each column
  becomes a slightly concave talus at about 41-51 degrees. Broad rolling ridges
  6-12 m apart run down it; crests reach higher and 28% further out than
  gullies. Treads under the slope collapse into it.
- The talus continues below the formation base (to -2.4 m) so it runs into
  the terrain rather than ending at a floor edge. Terrace-edge support still
  compresses it before a lower cliff.
- Slope surfaces are fully mossy (`moss_slopes`); steep upper faces stay
  exposed rock with patchy moss.
- `CliffSlopeRocks`: ANGRY MESH meadow rocks (P_Rock_01-05, the reference
  shapes) and Polyart RockMedium 01/03/05/07, 2-3.6 m, about 75% of 3.6 m slots,
  tilted halfway to the slope normal and sunk by half their height plus their
  depth along the run. They use the cliff stone colour with their own facet
  texture as value, and moss on upward faces.

## Limits

Trial only: the rocks load from the source packs (not baked) and have no
collision; slope footprints are wide (up to ~9 m on an 8 m wall at a ridge
crest on open ground). Some vertical creases remain where neighbouring
formations' slopes meet. September 22/23 cliff tests pass.
