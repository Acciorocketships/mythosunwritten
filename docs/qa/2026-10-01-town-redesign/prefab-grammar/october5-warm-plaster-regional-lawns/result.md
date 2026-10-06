# Warm plaster and regional courtyard lawns

Suntail’s `Wall` material now receives a warm lime-plaster multiplier (0.92, 0.86, 0.76) during visual preparation. All Suntail panels, bays, gables and dormers using that material share it; timber, stone, glass and roof finishes remain independent. This is a material colour adjustment retaining the authored texture and normal maps, not a newly painted texture. Source resources remain immutable. The native comparison shows original Suntail, prepared Suntail and native Pure Village under identical light (`plaster-comparison.png`).

Courtyard ground already used `TerrainChunkMesher.field_ground_surface` and the shared terrain material. Its colour sampled the continuous biome field directly, whereas the terrain samples that field on a 24 m lattice. Dense grass used a third, 3 m sampled version. `BiomeRegistry.terrain_tint_at` now samples the terrain’s exact 24 m bilinear colour field for raised lawns and the grass field, using worker-local corner caches. Elevation affects support, not region colour. The underlying biome noise already ignored Y; height was not the actual cause.

The town review harness now applies production world-space lawn colours; previously its untinted lawns did not show production colour. Existing raised-garden support uses the actual `GrassField`/`GrassStreamer` pipeline, with projected lower streets excluded from upper-floor clearance tests. Native seed13/grand review generates 349 grass instances, visible beneath the tree canopy in `detail/13_grand_court_plaza.00_0.png` and reverse view `_2.png`. The distant study plane remains a plain diagnostic background and is not evidence of world terrain colour.

## Validation

- Red-first: plaster warmth and terrain-lattice comparison both fail before changes.
- Final new tests: 3 tests / 19 assertions pass, including grass/lawn parity at 12 points across four regional locations.
- Existing raised-garden support and biome checks pass (combined initial run: 13 tests / 328 assertions including the first two new tests).
- Broader grass/terrain suite: 35 of 36 tests pass, 1116/1117 assertions. The remaining September10 sampler test indexes the retired `terrain_grades[0]` array. It also fails with this change disabled; no test expectation was weakened.
- Active falsification: disabling the plaster and field changes makes all three new tests fail; final source restored in a `finally` block.
- Matched overview before/after and player-height courtyard/reverse/street views reviewed. The material comparison verifies warmth directly without geometry or lighting differences.

This completes this palette/parity change, not the wider town redesign. The interior-square layout prototype, higher crossing/spire supply and broader art acceptance remain open.
