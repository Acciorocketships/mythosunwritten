# Atmosphere and biome rebuild

The landscape now owns its mood. Walking into a region no longer recolours the
entire view. A single warm sun and cool sky illuminate continuous local palettes,
world-space mist, vegetation and water. The references guided the soft light and
colour separation; no assets or code were copied from the lab repository.

| Region | Ground and vegetation | Atmosphere |
| --- | --- | --- |
| Sunwash Meadows | Sage grass, flowers, open canopy | Clear light, sparse golden motes |
| Cherryveil | Warm pale floor, wind-gathered pink petal litter, pink crowns | Rose mist and falling petals |
| Lanternwood | Mossy blue-green substrate, crooked trees, low grass | Low teal mist, fireflies and spirit lights |
| Opal Highlands | Pale mineral islands, cool grass, narrow tree silhouettes | Clear air, pale blue foliage |
| Moonfen | Indigo silt, reeds and dark canopy | Ground-hugging blue mist, warm/cyan spirits |
| Amber Heath | Ochre grass, exposed earth, amber leaves | Warm fine haze and drifting leaves |
| Jade Estuary | Green silt, wetland plants and shoreline foliage | Jade mist, softly coloured water |

The independent tree species affinities, canopy habitat, flowers, mushrooms,
rocks, reeds, lilies and deadwood give each region a different population mix.
Grass retains the ecological clearings and feature reservations.

## Geographic variation

A deterministic province field supplies long escarpments, horseshoe
amphitheatres, terraced valleys, isolated mesas with subsidiary needles,
ridgelines with saddles, sheltered hollows and winding clefts. Rivers descend the
same field used by final terrain, with the existing water carve and final height
clamp. Large lakes can preserve islands or shore-connected peninsulas.
Water colours blend by position, and steep exact-water samples emit spray.

True underground caves, overhead natural arches, branching delta topology and
braided rivers are not represented by this heightfield pass. Those require
additional geometry/topology contracts, rather than painted suggestions.

## Rendering and determinism

- Sky, sun, ambient illumination and global fog remain fixed during travel.
- Local mist is sampled every 16m, including identical values on shared chunk
  boundaries; the shader adds ground-height falloff and slow world-space drift.
- Spirit sprites and their lights share a moving parent. Light counts are capped
  at four per chunk and lights fade by distance. Glow emission uses soft masks.
- Seven biome channels and their canonical substrate colours are projected to a
  48m render lattice. The bounded map scrolls by exact lattice increments. Terrain,
  grass and rolled lips use the same ground function, including texture details.
- The source palette still distinguishes turf, rock and path texels. Terrain
  collision and water displacement/buoyancy contracts are unchanged.
- Tree foliage changes hue without recolouring its bark. Manifest flags preserve
  the treatment when rebaking the same measured meshes and colliders.
- Focus softness is an exported atmosphere control. The player and nearby walking
  surface remain readable; bloom favours luminous particles over whole-scene glare.

## Review

Run `res://tests/harness/atmosphere_review.tscn` with `--x`, `--z`, `--capture`,
and optional `--wide`. It streams the real game, including settlement reservations,
water, nature, grass and atmosphere before saving a frame. The pinned seed is
2697992464. `biome_review_teleports.json` is the F6 tour; F4 is unchanged.

The camera-independence regression fails against the former player-driven director.
New tests cover mist seams, grounded anchors, walking-speed blend continuity,
province seams/silhouettes, island/peninsula carve ownership, and identical
substrate samples after a render-map scroll. The water screenshot fixtures now
freeze their historical natural-height input alongside their existing frozen river
traces; their live terrain, contour, skin and swimming assertions remain intact.
Production river tests continue to exercise the new landforms.

QA images and final test results are recorded in `docs/qa/2026-09-07-atmosphere/`.
