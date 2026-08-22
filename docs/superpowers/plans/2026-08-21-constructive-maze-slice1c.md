# Constructive Maze — Slice 1c: Tier-Driven Heights, Street-Level Courtyards, Bridge Spans, Readable Tunnels

> **SUPERSEDED (2026-08-21).** History only — do not execute. The single live plan is `docs/superpowers/plans/2026-08-21-maze-town-master-plan.md`.


> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Approved in chat 2026-08-21.

**Goal:** The town's exterior reads as construction, not rock: houses under upper streets rise to meet them (tiers), courtyards are flat plots at street level, the carver deliberately leaves bridge spans over open streets so skywalks exist, and the debug view distinguishes tunnels, bridges, and plots.

**Architecture:** Source-level only (no composition). (1) Stamp pass: claim height is tier-driven — a house fronting a lower street rises to the next street level above it; the seeded storey roll applies only where no street is above. (2) Reservation pass: courtyard/garden level to the adjoining street datum (sink to terrain only at the rim); skywalk_span becomes non-optional and consumes carver-marked bridge spans. (3) Carver: the air pass retains seeded bridge spans (1–2 cells) over open streets where both flanks are solid, recorded as `excavation.bridge_spans`. (4) Ledger: edits on passage-hosting columns are legal above the passage's headroom (streets stay immutable; mass above them is buildable), so bridge claims are ordinary claims. (5) View: tunnels, bridges, and flat plots drawn distinctly in the final state.

**Spec:** `docs/superpowers/specs/2026-08-20-constructive-maze-town-design.md` — Task 1 appends "Tiers, courtyards, bridges" recording rules 1–4.

## Global Constraints

- As slice 1/1b: plain lattice data, terrain immutable, determinism, TABS, named files only, carver suite 7/7 and constructive suite green, never weaken an assertion silently.
- Streets stay immutable: the cells `[passage.y, passage.y + HEADROOM_BANDS)` of every passage are never edited; mass ABOVE that headroom in a passage column is ordinary buildable mass (this generalizes the 1b tunnel-roof rule to edits, not only trims).
- A carved bridge span must keep its two perpendicular flank columns solid at the passage band and above (it spans between two blocks); it may not be the portal cell, a market cell, or a stair/ramp cell.

---

### Task 1: Tier-driven heights, street-level courtyards, bridge-capable ledger

**Files:**
- Modify: `scripts/terrain/features/villages/fabric/WarrenMazeStampPass.gd`
- Modify: `scripts/terrain/features/villages/fabric/WarrenMazeReservationPass.gd`
- Modify: `scripts/terrain/features/villages/fabric/WarrenMazeSourcePlan.gd`
- Modify: `docs/superpowers/specs/2026-08-20-constructive-maze-town-design.md`
- Test: `tests/test_warren_maze_constructive.gd`

**Rules (binding):**
1. **Tier-driven height.** For a candidate (footprint, floor): `tier_top` = the lowest passage cell y such that `y ≥ floor + MIN_HOUSE_BANDS` and the passage cell lies in a footprint column OR in the footprint's 1-column apron (an upper street beside or over the block). If found: `top = tier_top` (roof = the upper street's floor), clamped to the existing ceiling logic and to `MAX_TIER_STOREYS := 6`; else `top` = the 1b seeded roll. The 1×1 clamp stays. Record `tiered: true` on claims whose top came from a street. Lineage grouping is unchanged.
2. **Street-level courtyards/gardens.** `courtyard` and `garden_terrace` use a new edit op `&"level_to_walk"`: datum = the adjoining walk cell's y (the anchor passage the patch was enumerated from); every patch column edited to `{floor: datum, top: datum}` (flat open plot); if `massif.base_at(column) > datum` for any column, that candidate fails fit (try shrink/move). `sink_to_terrain` survives only as the rim variant: used automatically when every patch column's terrain is within 2 bands of the datum. Reservation dict gains `plot_kind: &"flat"` for these.
3. **Skywalk spans non-optional.** `skywalk_span` quota → compact (1,1), standard (1,2), large (2,3), grand (3,4), `optional: false`. `claim_overhead` consumes `plan.excavation.bridge_spans` (Task 2) FIRST, in order, before falling back to its current search; a consumed span's reservation gets `cells` = the span's passage columns, `walk_cells` = the span cells, `datum_band` = span passage y + HEADROOM_BANDS, `plot_top` = datum + 1 storey, and it EDITS those columns via `record_edit(column, datum, plot_top, &"reserve")` (legal under rule 4).
4. **Bridge-capable ledger.** `record_edit`/`can_record_edit` on a passage-hosting column are legal iff `floor_band ≥ max passage y in that column + HEADROOM_BANDS` (mirrors `record_trim`'s 1b headroom rule); seal validates the same. A claim whose footprint includes passage columns is therefore legal when its floor clears their headroom — a bridge house. `_footprint_available`/`_column_bears` treat a passage column as bearing at floor `F` iff `F == passage y + HEADROOM_BANDS + TUNNEL_ROOF_BANDS` or the plinth rule holds above that.

- [ ] **Tests (red first):**
  - `test_houses_under_upper_streets_rise_to_meet_them`: seeds 1,3,4,12 compact — for every passage cell `p` with `p.y ≥ portal.y + 4`, count flank columns (perpendicular neighbours) whose solid mass at `[p.y − 2, p.y)` belongs to a CLAIM vs to unclaimed rock; assert the claim share across the four seeds ≥ a floor you pin at measured-minus-guard, and report the raw number; assert every `tiered` claim's top equals a passage y adjacent to its footprint/apron.
  - `test_courtyards_are_flat_plots_at_street_level`: seeds 3 and 9 (standard) — every courtyard/garden reservation has `plot_kind == &"flat"`, every cell `effective_base == effective_top == datum_band`, and `datum_band` equals the y of some passage cell adjacent to the patch.
  - `test_bridge_claims_clear_street_headroom`: after Task 2 lands (write now, expect it to fail until then): every claim with a footprint column hosting a passage has `floor_band ≥ that passage's y + HEADROOM_BANDS`; seal rejects a doctored claim that violates it (reason names "headroom").
  - Existing suites green; re-pin ownership/upper-tier floors upward if they rise; report if anything drops.
- [ ] **Commit** — `feat(villages): tier-driven heights, street-level courtyards, bridge-capable ledger`.

---

### Task 2: Carver bridge spans

**Files:**
- Modify: `scripts/terrain/features/villages/fabric/WarrenMazeCarver.gd` (`_open_passages_to_air`, `_finalize_excavation`)
- Modify: `scripts/terrain/features/villages/fabric/WarrenExcavation.gd` (`var bridge_spans: Array[Array] = []`, sealed with the excavation, covered by its signature if it has one — otherwise covered by `WarrenMazeSourcePlan.deterministic_signature`)
- Test: `tests/test_warren_maze_carver.gd` (existing 7 stay; add 2)

**Rule (binding):** In `_open_passages_to_air`, before opening: walk the spine (`excavation.route`) and each lane in order; for each maximal run of would-be-OPEN, non-market, non-portal, level-stride cells, select seeded bridge spans — every `BRIDGE_SPAN_PERIOD := 5` cells of run (seeded phase via `WarrenPassageLatticeRules.hash_key(world_seed, 0xB21D6E, first_cell, 0)`), a span of `1 + (hash mod 2)` consecutive cells — accepted only if each span cell's two perpendicular flank columns are solid at `cell.y` and at `cell.y + HEADROOM_BANDS` (the span connects two blocks) and the column has `≥ HEADROOM_BANDS + 2` bands of mass above `cell.y`. Accepted span cells are NOT opened (their overhead mass is retained) and are appended to `excavation.bridge_spans` as `Array[Vector3i]`. Profile quota: stop selecting once `skywalk_range.y` spans exist (skywalk_range from `WarrenVillageScaleProfile`). `_finalize_excavation` already marks such cells covered. Carver invariants (frontage, connectivity, stride legality) are unaffected because passage cells do not change.

- [ ] **Tests:** (a) `test_bridge_spans_are_retained_over_open_streets`: seeds 1–6 standard — `excavation.bridge_spans` non-empty on at least 4 of 6; every span cell is covered, has solid flanks at its band, is not a portal/market cell, and its run neighbours outside the span are OPEN (it is a bridge, not a tunnel end); (b) determinism — two carves yield identical spans. Existing 7 carver tests green.
- [ ] **Commit** — `feat(villages): carver retains seeded bridge spans over open streets`.

---

### Task 3: View — tunnels, bridges, plots

**Files:**
- Modify: `tests/harness/maze_source_review.gd`

- Final state: covered passage cells draw a dark roof slab (1 band thick at `y + HEADROOM_BANDS`) in a distinct tunnel colour and the line in that segment is dashed-looking (alternate segment colour) so tunnels read; **bridge spans** draw the retained span as a house-coloured block if claimed, else as the skywalk reservation block (blue, `datum..plot_top`), never a thin bar; **flat plots** (courtyard/garden) draw as a 0.3 m slab at the datum in their colour with the outline; the through-wall line is drawn only for segments not inside a visible corridor voxel (keep the voxels).
- Legend: add tunnel roof, bridge (claimed / reserved), flat plot.
- Render seeds 4, 3, 9 `--phases all` to `.../scratchpad/slice1c-view`; read final iso/street/top for seeds 4 and 3; honest verdict in the report.
- [ ] **Commit** — `feat(villages): debug view shows tunnels, bridges, and plots`.

## Exit (measured, pinned at measured-minus-guard; report honestly)

- Claim share of upper-street flanks (Task 1 metric) on seeds 1/3/4/12 compact.
- Bridge spans present on ≥ 4/6 standard seeds; ≥ 1 bridge claim or skywalk reservation on every seed that has a span.
- Courtyards flat at street datum wherever placed.
- Constructive suite and carver suite green; sweep table appended to this plan under "Measured results".
