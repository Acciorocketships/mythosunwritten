# Water tiles

**Status: IMPLEMENTED** (rivers, lakes, islands).

- `Helper.is_water(pos, world_seed)`: deterministic water field — ridged value
  noise forms winding river bands, a blob noise forms lakes, a finer noise
  carves islands inside water regions, and isolated single-tile ponds are
  eroded. Faded near the origin so the spawn stays dry.
- `WaterTile` rides the ground grid (lateral sockets at ground level keep the
  frontier flowing across water); animated shader surface at -1.5 with a dark
  floor below, plus a blocking `topcenter` so levels can never cantilever over
  open water. Walk-on-water collision for now.
- `WaterRule` swaps plain ground tiles on water-field positions for water
  tiles and retiles adjacent land to **bank** variants — the cliff scenes
  placed at ground depth, rotated so the rock wall faces the water (canonical
  rotation machinery mirrors CliffEdgeRule). Banks classify against
  ungenerated positions via the field, so silhouettes don't churn while the
  frontier advances.
- Only the plain ground tile carries the `ground-plain` sampling tag; water
  and banks carry `ground`/`side` so they satisfy neighbour requirements but
  are placed exclusively by the rule.

Follow-up: swimming/wading gameplay (the player can currently walk on the
water surface and cannot climb a bank from the water).
