# Subtle rock, moss grading, inner-corner terraces (owner review, September 23)

Owner choices after `01-cliff-directions`: subtle rock; drop outer-corner
platforms; larger inner-corner terraces with rock dressing on their faces,
quantised to the cliff's storey bands (none on a one-storey corner); fuller
feet on straight faces and inner corners but not outer corners; ground-up moss
like the reference mountain; and a separate trial of the reference chunky rocks.
Seed 2697992464; same harness cameras. Images show current / chosen / chunky.

## Production default (`CliffRockStyle`: subtle + terraces + moss)

- Subtle projection: `CliffRockCrags._subtle` scales depth beyond the 0.6 m
  attachment from `SUBTLE_FOOT` 0.26 at the foot to 1.0 by 80% height (the
  upper fifth keeps its crown exactly). Convex corners use
  `SUBTLE_CORNER_FOOT` 0.17. Median foot: 2.1 m (4 m wall), 2.6 m (8 m),
  was 6.3 / 7.7 m.
- Moss: `cliff_crag.gdshader` blends the lawn colour (same palette texel,
  biome tint in vertex colour, `ground_style`) from full cover at the ground
  into noise patches up to 4.5 m; upward faces hold a little more. UV2.x is each
  vertex's height above the actual terrain 2 m outside the rock.
- Inner-corner terraces (`CliffKitDressing.terraces`): a 9 m (three 3 m grid
  squares) terrace in the pocket of a concave corner. Turf sits whole storeys
  below the crest and at least one storey above the pocket
  (`terrace_cap`); one-storey corners and uneven pockets get none. It is built
  like a natural cliff top from native pieces: wall rows and lips along both
  exposed faces, an outer lip on its convex corner and flat 3 m ground tiles
  inside. Its wall rows join the ordinary wall lists, so the normal rock
  pipeline dresses its faces. Collision covers its top and faces; its
  footprint is a ground reservation. A first hill-piece version left seams
  between its turf and the rock crest and was replaced.
- `CliffRockEndCaps.rebuild` keeps an end's existing cap when a ledge warp
  across a narrow tread leaves an outline the triangulator rejects (it
  previously asserted, stopping the streaming worker).

## Option: `chunky` (not default)

Low-poly facets in 3 m tiers: each tier's face is vertical and the relief's
recession collects in a thin band between tiers, forming mossy upward ledges.
Reads as stacked blocks from a distance; close up the tiers cross the existing
turf ledges with jagged steps. Not accepted.

## Evidence and limits

- `tests/test_september23_cliff_directions.gd` (5 tests): foot envelope,
  tighter corner foot, crown kept exactly, straight faces keep >= 50% ledge
  turf, moss channels, storey-band terrace caps.
- 81-file cliff sweep vs the September 22 baseline: identical except nine files
  pinning the old full-projection shape (ledge area, turf coverage, shoulder
  volume, projection profile, corner radius, normal-fan sample, inner-join
  ledges). They now pin `current` explicitly; the render-array identity test
  ignores only the new UV2 channel. All nine pass.
- Trade-off: subtle narrows ledges. Straight faces keep 58-76% of ledge turf;
  convex corners keep none; inner joins keep less.
- Terrace tops have no dense grass blades or grass support yet.
