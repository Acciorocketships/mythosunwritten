# Follow-up: native fine water rescue (Phase 3 exit check)

After Task 9 of `2026-10-07-native-terrain-water-ports.md`, the fine rescue
(`WaterField` sub-lattice rescue, 3 m lattice, side 1393 on chunk (-4,-5)) is
the largest cost of a cold water block: `fine_ms` 8.0-9.2 s of `water_ms`
17.4 s (spill 1.9-3.5 s, source region 3.7 s, profiles 1.8 s).

`WATER_FINE_COST` split (Task 9 run): seed 3.2 s, anchors 3.0 s, flood and
spill 2.4 s, finish 0.6 s.

## Step 1: measure inside each stage (no port yet)

Add `PROFILE_WATER_COST` counters (calls and time) for the query helpers the
stages call per lattice node: `_fill_bilinear_coarse` / `_rescue_coarse_level`
/ `_fill_untapered_level` (coarse field queries), `_wall_span` and the shore
support (`_shore_support_level`), `_ground_at` (lazy sub ground), and
`SpillSearch.height_at`. Record which of them carry the seed and anchor
stages and how many nodes each stage visits.

## Step 2: port by the same rules as Tasks 6-9

- Prefer one dense ground array (the 3 m sub ground via `sample_grid32`) over
  lazy `_ground_at` when the stage visits most nodes; keep lazy where it does
  not (measure the visited share first).
- Coarse queries read the frozen coarse fill arrays, which C# can take once
  per solve; mirror `_fill_bilinear`'s wall-aware branches exactly (float32
  storage, double arithmetic) and gate them on random lattices with walls,
  wet/dry pairs and submerged walls, compared with `!=`.
- The flood is a `PriorityQueue` over `[idx, level]`: reuse `GdPriorityQueue`
  and `SpillSearch`'s C# port (`CapHydrostatic`).
- Identity: `water_block_cost --no-disk` digest `b6c965def22e7e93`
  (and `--serial`), `parallel_tail_check --rounds=2`.

Port only the stages Step 1 shows to dominate; leave the rest GDScript.
