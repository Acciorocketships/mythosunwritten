# Slope sheet, no ledges, thick moss, layered rocks (September 24)

Owner on `06-smooth-slopes`: right direction, but:
- glitchy areas remain; do a quality pass, predictable first and variability after;
- slopes fall short around corners;
- the rocks should be like the reference (layered, grass-topped);
- the slope should undulate along the wall;
- are there rocky cliff assets for the walls above the slopes?

Mid-pass:
- two flagged slivers (amber, `amber-user8.jpg`);
- remove the ledges for now;
- moss thick at the bottom, thinning only near the very top.

Images:
- `amber-*` and `green-*`: default | slopes, seed 2697992464;
- `cliffs-*`: slopes | slopes with the Farmlands cliff pieces;
- `lineup-*`: the pack rocks surveyed.

## Root cause of the glitches

Each rock formation used to carry its own slope. Wherever a formation ended, the neighbour did not continue exactly the same slope, so its end face showed as a thin vertical blade:
- at collinear joints;
- at corners, where the corner body is compressed;
- at base steps;
- at cluster mounds.

Per-joint tapers only moved the problem.

## Slope (`CliffSlopeField`, `slopes` style)

- **One sheet per foot line.** The slope is its own mesh. There is one sheet per straight foot line (collinear walls and corner arms merged) and one per outer-corner arc. Sheets are sampled on world-aligned 0.5 m columns, so neighbouring chunks share edge vertices.
- **Profile.** Rows follow the quarter superellipse (power 1.4). It is vertical where it leaves the wall and nearly tangent to the ground (tangent 5 cm below). A skirt is buried below the base, and a lip curls back into the wall above the top.
- **Formations.** They keep their rock. Below the 2 m rock band, any rock standing out of the sheet is pulled 0.3 m inside it.
- **Parameters.** These are world-space functions of the foot point, so every piece agrees:
  - top: half the wall height, at most about 3.8 m;
  - reach: 1.8 times the top, at most 7 m;
  - mini ridges and valleys: noise at about 5 m along the wall (reach ±22%, top ±10%);
  - a broad ±8% at 16 m.
- **Terrace edges.** A slope steepens before a lower cliff edge and vanishes on a narrow tier.
- **Corners.** Outer corners are cones at the full reach.
- **Open ends.** A sheet tapers over 3.5 m wherever its foot line stops without a continuation (no collinear run, corner arc or crossing foot line). Formation end flags missed base steps and joined formations; that was the flagged sliver.

## Default style (also slopes)

- **Ledges off.** `CliffRockStyle.ledges`: the historical `current` style keeps them; ledge-generator tests pin them on.
- **Moss.** Moss is thick from the ground up and thins only above 60% of the wall height (from 100% to 25% cover at the crest).
- **Side effect.** Without ledge lips, straight walls' feet no longer measure fuller than convex corners' feet (1.46 m against 1.54 m median).

## Rocks (`CliffSlopeRocks`)

- **Asset survey.** The only layered rocks like the reference are the Meadow pack's P_Rock 01-05 (the reference is one of them, with its summer grass top) and Farmlands' `Cliff_Flat_01`. Rejected:
  - Meadow rocks 06-12 and the rock groups (rounded boulders);
  - Farmlands medium rocks (river stones);
  - Raygeas stones (smooth cells).
- **Placement.** Clusters of one 3.2-5 m rock with two to four smaller ones, on 12 m world slots. They are sunk just over halfway and lean into the slope.
- **Shading.** Crisp grass on the upward ledges, and the slope's lawn growing over the buried base.

## Cliff pieces (trial style `slopes_cliffs`)

- **What.** Farmlands `Cliff_Large_01-03` rock masses, one per ~7 m slot on walls at least 3.5 m tall. They are scaled from below the base to just under the lip, with their fronts 2.3 m out from the foot line.
- **Result.** They read as dark blocks hanging below the lip: the crag rock and slope bury their lower half, and they do not take the wall's moss. Not convincing yet.

## Limits

- **Assets.** Pack assets load from the source packs, with no collision (rocks and cliff pieces).
- **Rock band.** Crag bulges in the rock band can overhang the slope top with a shadow line. Vertical creases between neighbouring formations remain in the rock above the slope.
- **Cost.** A site rebuild takes about 46 s with slopes, against 28 s for the default.

## Tests

- **September 23 file.** 14 tests pass, including the new slope-sheet tests:
  - smooth, tangent foot and curled lip;
  - rock stays inside the lower slope;
  - free and open ends taper;
  - collinear walls share one sheet;
  - chunk edges share vertices;
  - corner cones at full reach;
  - ledges off.
- **Cliff test batch.** Of 85 cliff test files, 9 ledge-generator files first failed with ledges off. With ledges pinned on they return to exactly their previous results. Three files that failed before now pass, and one fails fewer tests.
