# Sheet style: moss to the top, corners, rocks by kind, ridges and bumps (September 24)

Owner on `08-whole-wall-sheet`:
- moss all the way to the top;
- corners sometimes expose the bare native rock;
- corners have sharp edges and the slope does not wrap around them;
- more rocks sticking out of the wall, with ground rocks at the base and cliff rocks out of the side;
- gently rolling, variable ridges and valleys;
- then gentle bumps and divots, a subtle version of the rock dressing, on the slopes.

Images: last round | now, `sheet` style, seed 2697992464.

## Moss

- **Full cover.** `moss_full` (set for the sheet style) keeps moss cover complete to the lip.

## Corners (`CliffSlopeField`)

- **Stepped corners.** Diagnosis: at the amber corner the upper storey's outer-corner cone stood on the upper terrace, but around the corner the ground drops a storey. The cone's slope had no ground there, so it collapsed to a vertical edge and never wrapped. Under the sheet style every column now hangs from the lip and runs down to the lowest ground along its run (`_frame`, whole storeys only). The cone wraps down to the lower ground and meets the tall face's slope.
- **Inner corners.** Two slopes used to intersect in a hard V. Each column near an inner corner now bends into a round fillet with the crossing wall's slope (2.5 m, narrowing toward the lip), like a smooth union (`_round_inner_corners`).
- **Steps.** Where a crossing wall meets a line part-way along, the fillet fades in over 1.5 m; switched on at once, it left a blade.
- **Terraces.** The inner-corner kit platforms are off under the sheet style; the sheet buried them to a line.

## Rocks: one rule, two kinds

- **Ground rocks.** The Meadow layered rocks and Farmlands flat rock come in bunches of 4-7 at the foot (bottom 30% of the slope), on 10 m slots (60% of slots). They lean with the slope and are sunk 25% of their radius.
- **Cliff rocks.** The Farmlands stratified masses come one to three per 6 m slot (70%), 35-78% of the way up. They stand upright, sunk 60%.
- **Swell.** The slope swells to meet every rock with a smaller ellipsoid (45-50% of the rock's radius, 0.8 m blend), so rocks stand clearly out of their mounds. The earlier swell nearly swallowed small rocks.

## Ridges and bumps

- **Ridges.** Reach varies ±38% with two domain-warped noise octaves (6.5 m and 13 m, warped at 23 m), so ridges wander rather than repeat. Over a 60 m sample the largest reach is 1.34 times the smallest.
- **Bumps and divots.** Two octaves (2.4 m and 1.1 m, ±0.22 m and ±0.08 m) in a skewed (foot, height) plane, faded out at the ground and the lip.

## Limits

- **Lip teeth.** The native lip's rocky teeth still show at concave lips.
- **Rock looks.** Some small cliff rocks read as chips, and large ones as blocks stuck on.
- **Assets.** Rocks load from the source packs, with no collision.
- **Plants.** The sheet style has no plants yet.

## Tests

The September 23 file passes 19 tests, including:
- ground and cliff rock kinds and heights;
- irregular ridge spacing;
- inner-corner round;
- step fade-in: red without the fade (jumps of up to 2.6 m between columns), green with it.
