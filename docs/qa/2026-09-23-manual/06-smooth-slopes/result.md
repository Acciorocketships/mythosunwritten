# Smooth mossy slopes (owner trial, September 23, second pass)

Owner rejected `05-mossy-slopes`:
- The colours formed distinct bands.
- Seams showed at the ground and at the cliff face.
- The slope carried the old rock-work randomness.
- The rocks were small and scattered, and sat on top of the slope.

The slope should be:
- smooth and gently rolling;
- one continuous surface with the ground and the wall;
- rocky only at the junction and where ledges or rocks break out;
- dressed with bunched rocks set into the slope.

Images: `<view>.jpg` is previous | new slopes. `<view>-vs-chosen.jpg` is default | new slopes. Same cameras as 05, seed 2697992464.

## Geometry (`CliffRockCrags._slope_faces`, `slopes` style only)

- **Fillet shape.** After all rock shaping, the lower wall becomes one concave quarter-superellipse (power 1.4). It leaves the wall vertically at `slope_top` and flattens to horizontal just below the base, so it meets the terrain tangentially.
  - `slope_top` is 36-60% of the wall height, higher on ridges.
  - The run is 1.55-2.1 times the slope height, higher on crests, capped at 7 m.
  - Near the ground the slope is under 30 degrees; the average slope is about 30-35 degrees.
- **Rock detail.** The fillet is a smooth union (radius 0.9 m) with the finished rock. Crag relief shows only where rock stands proud of it: near the junction, and at the occasional ledge.
- **Anchor.** The fillet leaves the wall at the averaged face depth, not per column, so crag relief does not ripple the slope.
- **Turf.** Treads within 2.5 m of the slope top drop their pale turf. They read as a horizontal band.
- **End tapers.** Every slope end tapers, including ends continued by a corner.
  - Free ends taper over 3.5 m, and ends against a shorter neighbour over 2.5 m.
  - Collinear continued joints taper over the outer 1.5 m of their 6 m overlap.
  - Corner arms taper over 2 m.
  - Cutting a slope short left thin dark vertical blades.
- **Mounds.** Rock-cluster mounds are raised by every formation they overlap. The owner of the cluster's rocks alone raising the mound cut it off at the neighbour, which was another blade.

## Rocks (`CliffSlopeRocks`)

- Clusters sit on 12 m slots along the wall line (about 70% kept). Each has one 3.2-5 m rock with two to four smaller ones (35-68% of its size) around it.
- A cluster belongs to one formation, away from its ends. It stands on a mound in the slope.
- Rocks lean 70% of the way into the slope and are sunk just over halfway.
- Each instance carries its slope plane. The shader grows the slope's moss and lawn over the rock's base, from 15 to 45 cm above the slope.
- Moss covers only the rocks' near-horizontal tops, so they read as grey stone.

## Colour (`cliff_crag.gdshader`, also the default style)

- **Lawn-to-moss grade.** The lawn colour grades into moss by height, across a wide boundary warped by fbm noise. This replaces a fixed band.
- **Mixes and drift.** Broad, low-contrast fbm patches mix the two tones, and a slow brightness/warmth drift runs across them.
- **Stone-to-moss edge.** The transition is 0.4 wide (was 0.12), so moss thins into stone.
- **Slope surfaces.** On mossy slopes, cover follows the normal with a noise-broken threshold. Stone appears only as the fillet steepens into the wall.
- **Biome tint.** The tint is bilinear on a 3 m lattice (was snapped to 6 m cells, which stepped across the fine mesh).

## Limits

- **Status.** Trial style: `slopes` is not the default.
- **Rocks.** They still load from the source packs, with no collision.
- **Where slopes meet.** Two slopes meeting at an inner corner or across stacked walls form a valley crease. Where a wall slope tapers into a smaller corner slope, a shallow cove remains.
- **Footprint.** Slopes are wide: up to 7 m out from an 8 m wall.

The 9 September 23 tests pass, including three new slope tests: gentle foot and no ripple, tapers at every end, and shared mounds.
