# The whole wall as one slope (`sheet` style, September 24)

Owner on `07-slope-sheet`: save a checkpoint and try something else.
- The slope was an extra skirt below the bumpy crag dressing; it should be one and the same.
- Replace the wall dressing with one continuous slope: vertical toward the top of the cliff, horizontal at the bottom, very clean.
- Then add the rocks on top: bigger, in bunches.
- The "cliff pieces" were repetitive, did a different job from the lower rocks, stuck out too far and broke the wall. Treat all rocks the same, and curve the slope to meet them seamlessly.

Checkpoint: git tag `checkpoint/cliff-slope-sheet-2026-09-24`. It is a commit object of every tracked change plus about 8,600 untracked source files, on no branch. Every image is slopes (checkpoint) | sheet, seed 2697992464.

## `sheet` style (`CliffRockStyle.sheet_only`)

- **No crag dressing.** Crag formations are still computed, but only to locate the foot lines (walls, corner arcs, inner-corner arms). They are not rendered.
- **One sheet per foot line.** The slope sheets from `07` (`CliffSlopeField`) are the whole wall.
  - They start 1.0 m out from the foot line, 0.3 m under the crest, and curl back under the native grass lip. That covers the lip's rocky teeth, which hung like icicles when the sheet stopped lower.
  - Profile power 1.7: a near-vertical band under the lip that swings out to horizontal at the ground.
  - Reach is `0.85 x top + 1.6` m, rippled ±15% along the wall at about 5 m and capped at 9 m. Tall walls stay steep rather than spreading out.
- **Unchanged from `07`.** Outer corners are cones at the full reach; ends taper where a foot line stops; terrace edges steepen or remove the slope; the moss grading applies.
- **No plants.** The sheet style plants nothing yet (no crevices; the native wall plants would sit behind the sheet).

## Rocks: one rule (`CliffSlopeField._find_rocks`)

- **Bunches.** On 10 m world slots along each foot line, about 60% hold a bunch of 4-7 rocks. There is one 4-6.5 m rock (scaled with the slope height) and smaller ones (30-72% of it) within about a metre of its width either side. All sit in the lower half of the slope; small ones stay in its lower quarter.
- **One pool, chosen by local slope.** The Meadow P_Rock 01-05, Farmlands Cliff_Flat and the Farmlands cliff masses share one pool. Where the slope is steeper than 45°, the tall stratified masses stand upright, sunk 55% of their radius. On the gentle slope the flat layered rocks lean halfway with it, sunk 35%.
- **The slope meets each rock.** For every rock the sheet takes a smooth union (radius 1.2 m) with an ellipsoid a little smaller than the rock. The slope swells into a mound that curves into the rock, so the rock stands just proud of it instead of breaking it.
- **Shading.** Crisp grass tops, with the slope's lawn over the buried base. There is no separate wall-piece placement; the `slopes_cliffs` trial is removed (it is in the checkpoint).

## Limits

- **Assets.** Rocks load from the source packs, with no collision.
- **Collision.** The sheet collides as a slope, so the lower wall is now walkable up to its steep part.
- **Rock silhouettes.** A few upright masses still read as blocks stuck on the steep part.
- **Cost.** A site rebuild takes about 27 s, the same as the default (the crag geometry is computed and discarded).

## Tests

The September 23 file passes 16 tests, including:
- the sheet reaches up under the lip and is near vertical over its top 2 m;
- rocks come in bunches of at least three and the slope swells to meet each one.
