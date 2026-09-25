# Cliff rock directions (owner review, September 23)

Owner: the rock reads as tar/honey oozing at the foot; make it rockier and
more subtle, and try KayKit platforms/rocks instead of or with the crags.
Nothing is promoted: production keeps `CliffRockStyle` defaults (current).
Seed 2697992464; sites (300,20,995) and (-480,34,-248), grass on.

## Measured cause

Without a terrace edge to stop it, the crag foot measured 6.3 m median /
8.9 m p90 from a 4 m wall, 7.7/10.1 m from 8 m and 8.3/11.3 m from 16 m:
a talus apron, not a rock face. Earlier support scaling only trimmed it
where a lower cliff edge was nearby.

## Variants (`CliffRockStyle.apply(name)`)

- `subtle`: projection beyond the 0.6 m native attachment scales from 0.17
  at the foot to 0.92 near the crown, applied per sampling column before
  the tread-grade correction (ledges keep their grade and turf). Foot:
  1.6 m (4 m wall), 2.1 m (8 m), 2.4 m (16 m); widest slightly above the
  ground. Convex corners stop compressing their foot a second time.
- `rocky`: `subtle` plus low-poly facets. The smooth relief is resampled on
  a coarse irregular triangle lattice (horizontal strata lines 1.35 m apart,
  nodes about 1.9 m apart, +-0.17 m seeded node offsets); every fine vertex
  takes its coarse triangle's plane, so facets meet on straight continuous
  creases. Turf, tread edges and their collar are fixed. Normals crease at
  24 degrees. A first version with independent per-cell planes left
  sawtooth steps on the 0.25 m grid and was replaced.
- `kit`: no crags. KayKit Hill pieces on the native 3 m tile grid
  (`CliffKitDressing`): an outer corner takes a 9 m piece (Hill_12x12 x0.75)
  buried in the cliff so one 3 m row shows along each edge; an inner corner
  takes a 6 m piece (Hill_8x8 x0.75) centred on the corner, showing one full
  3 m square in the pocket. Both protrude 3 m; turf at half the cliff
  height; some carry Rock_4 spires. Straight-edge squares were removed at
  the owner's request. Shared cliff material and biome tint.
- `hybrid`: `rocky` plus the kit corner pieces.

## Limits

Visual study only. The kit loads source glTF on the main thread (no bake,
no collision, no grass support, no production streaming). Kit-only exposes
the repeating native wall between corners. Existing September 22 tests and
the September 18/19 corner/outcrop tests pass with default style.
