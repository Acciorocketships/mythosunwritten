# Maze town carver — solid-first mass-first warren (design)

Date: 2026-08-16 · Branch: `feat/async-settlement-resolution` (on `main` = warren tip)
Status: draft for review · Supersedes the mass-first *front-end* described in
`2026-08-09-warren-volumetric-city-design.md` (the route bore, lanes, ground
arcade, gallery variants, face-ownership partition and the hero-feature beam
search). Downstream stages (room composition, fabric compile, terrain
placement) are reused.

## 1. Why

Profiling and gate tracing (see `docs/superpowers/plans/2026-08-15-startup-terrain-profiling.md`
§8) showed that at the reviewed village scale the current front-end produces
a one-house-deep skin along a single canyon: ~34 % of the hill's mass becomes
buildings, the interior 66 % is discarded, lanes cannot grow (0–3 per town),
the infill pass places nothing, and every enclosure/size metric (sightlines,
overhead, alley ratio, room range) was hard to satisfy — they were removed as
gates and are now guidance. Even so, the pipeline still *searches*: 12
excavation attempts × 8 partition orderings × a joint market/landmark/skywalk
beam, each candidate fully composed (~5 s) and compiled (~2 s) before it can
be judged. Towns take 6–24 s when they seal and one seed still cannot compose.

Ryan's direction: make frontage, density, enclosure and the macro features
**properties of construction** — carve passages that reach the interior so
most buildings front a street, then remove *air* to shape skywalks, markets,
courtyards, large houses and a "mountain of houses" — and generate **once**
instead of generating variants and throwing them away.

## 2. Model

The hill is a lattice of macro columns (3 m) × bands (1.5 m), exactly the
`WarrenMassif` lattice used today. After carving, every cell is one of:

| state | meaning | becomes |
|---|---|---|
| **SOLID** | building mass | rooms / storeys (partition → compose) |
| **PASSAGE** | walkable public void with a floor: spine, alleys, market aisles, stairs, ramps | route / walk cells (`WarrenExcavation.route` + lanes contract) |
| **AIR** | void without a floor: sky over a terrace, an open alley's headroom, a courtyard shaft | nothing (exterior) |

**Stamps** are named edits of that lattice with a door on a passage: market
chamber, landmark hall, courtyard, bridge/skywalk, large house. Each records
what it reserved so composition can hand it its recipe directly.

## 3. Pipeline (one deterministic pass)

```
hill ─► spine ─► alleys ─► stamps ─► air ─► partition ─► compose ─► fabric ─► place
                     ▲                        │              │
                     └── invariant check + bounded local repair ──┘
```

1. **Hill** — `WarrenMassifBuilder` unchanged (terraced Gaussian, radius from
   the scale profile, real terrain bands at placement time as today).
2. **Spine** — one main street from the entrance to the summit.
3. **Alleys** — a maze of 1-wide passages off the spine, spaced by a
   block-thickness field, until frontage coverage is reached.
4. **Stamps** — market, landmark, courtyards, bridges, large houses: pure grid
   edits with quotas from the profile.
5. **Air** — open vs covered per passage cell; courtyard shafts.
6. **Partition** — every SOLID cell joins a block; blocks split into
   footprints along the passage they face; nothing discarded.
7. **Compose / fabric / place** — reused; stamps feed the composition's
   existing reservation inputs, so the beam search is bypassed.

No attempts, no partition variants. Failures at 6/7 that are local (a
footprint no recipe fits, a stamp that breaks connectivity) are repaired
locally once and the stage re-run once; anything else is a reported failure
of that seed, never a search.

## 4. Passages

### 4.1 Common rules (spine and alleys)

- One macro column wide. A passage cell carves the walk slot the current
  carver carves (floor band + `HEADROOM_BANDS`, stair/ramp swept volumes), so
  `WarrenExcavation`/adapter/`WarrenVolumePlan` contracts hold unchanged.
- **Borable**: the slot is solid to remove and the floor has bearing beneath
  (`_slot_is_borable`, reused).
- **Frontage**: every passage cell must front, on at least one side, a solid
  column with ≥ `MIN_HOUSE_BANDS` (4) of solid above the floor — the
  house-capable test the partitioner already uses. This is the frontage
  guarantee, applied cell by cell.
- **Level changes** are strides from the existing vocabulary only: stair
  (rise 1, run 2), ramp (rise 1, run 3); never a 1-cell rise.
- **No plaza**: a passage may not run beside another passage at its own
  level (`_completes_public_square`, reused).
- **Straight runs** ≤ 4 cells (spine ≤ 6).
- **Deterministic**: every choice is a total order with hash tie-breaks
  (`Helper._mix64` of world seed + cell); no wall-clock, no RNG.

### 4.2 Spine

- Entrance: the boundary column facing the settlement's road axis at ground
  level (today's portal choice, single entrance in v1).
- Growth: DFS with backtracking toward the summit region (`INNER_RADIUS`
  from the profile), scoring only *inward + upward progress* and *walled
  flanks*; backtracks a stride when stuck. Ends when the summit region is
  reached (or the route-cell maximum of the profile is spent — then the
  summit region is wherever it stopped, recorded).
- Records: `market_zone` = its first `K` ground-level cells past the
  entrance (K from the profile's market aisle length; alleys never branch
  there), `summit_block` = the solid block it arrives at.
- Replaces: `WarrenExcavationCarver.carve*` (256 bores × 12 attempts) and
  the topology-gate ranking. The `WarrenPublicRealmCarver.topology_gate`
  criteria that are structural (≥ 1 ramp, ≥ 4 elevation bands, minimum walk
  cells) become spine growth *targets* (keep climbing/adding until met) and a
  final invariant, not a post-hoc rejection.

### 4.3 Alleys

- **Anchors**: any spine or alley cell outside the market zone that is a
  stride endpoint (transition endpoints only, as today — an intermediate
  stride cell owns its ground's public surface).
- **Growth**: deterministic randomized DFS from anchors (order = hash). At
  each step choose among legal strides by: (1) block-thickness target unmet
  on that side (see field), (2) minimal rise (hug the contour), (3) hash.
  A branch ends when no legal stride remains, when its straight run must
  break and cannot, or when it **joins** another same-level passage it has
  come adjacent to (probability `p_loop` per profile, hash-decided; never
  where the join would form a plaza) — otherwise it ends as a cul-de-sac.
- **Block-thickness field**: `t(c) = round(lerp(T_RIM, T_CORE, w(c)))` with
  `w(c) = smoothstep` of the column's normalised distance to the summit
  (rim `w=0`, summit `w=1`); `T_RIM = 1.5`, `T_CORE = 3.5` (so 1–2 at the
  rim, 3–4 in the core). A stride is illegal if it would leave a solid
  block thinner than `t` between itself and another passage at that level.
- **Termination**: stop when every non-reserved house-capable solid column
  faces a passage (frontage coverage 100 % of the reachable set) or the
  profile's passage-cell budget is spent. **Frontage ratio** = house-capable
  solid columns adjacent to a passage cell at that column's street level ÷
  all house-capable solid columns; it is recorded and checked against the
  profile's floor by the invariant step.
- Replaces: the lane grower and its arcade reserve; the ground-arcade branch
  solver (its two ground branches are the spine's ground stretch + the
  market stamp); the elevated-frontage/gallery variants (courtyards are
  stamps).

## 5. Stamps

All stamps run after the alleys, in a fixed order, as pure edits with
`fit → shrink → move → skip` and an audit entry each. Quotas map onto the
existing `WarrenVillageScaleProfile` fields so no new profile data is needed:

| stamp | edit | door | quota (existing field) |
|---|---|---|---|
| **Market chamber** | widen the spine's market zone by 1–2 columns into the flanking block(s); the widened cells are PASSAGE (aisles); keep the solid above → roofed chamber | the spine | `requires_covered_market` (compact/standard: skip; large/grand: 1) — *or* 1 for every profile if Ryan wants a market in every town (decision, §11) |
| **Landmark hall** | protect the summit block (else the largest core block ≥ 3 thick) from splitting; mark it for the hall recipe family | the passage it faces | `landmark_range` |
| **Courtyard** | in a block ≥ 3 thick: remove an AIR shaft (2×2 or 3×3 columns) down to the block's mid floor; ring columns keep frontage onto the court; one passage cell becomes the court's gate | the gate cell | `cantilever_range` / `requires_elevated_courtyard` (large/grand); 0–1 for compact/standard |
| **Bridge / skywalk** | over an alley stretch where two blocks face at the same level: keep the solid above the passage (do not open it in the air stage) and mark the span for the bridge recipe | none (it is above a passage) | `skywalk_range` |
| **Large house** | protect a 2×2–2×3 block from splitting; mark for the large-house recipes | its passage | `balcony_range` used as a proxy count in v1 (or a new small field, §11) |
| **Mountain** | not a stamp: it is the core rule of the air stage (§6) plus the thick field |  |  |

Fit tests are the structural ones only (borable, bearing, no plaza, door
exists). A skipped stamp is an audit line, not a failure.

## 6. Air

For each PASSAGE cell, the mass above the walk slot is **open** (removed to
sky) by default, **covered** (kept) if: a bridge/skywalk or market stamp
covers it, **or** the cell lies inside a core block whose thickness field is
≥ 3 (alleys through the mountain are tunnels). Courtyard shafts remove AIR
down to their floor. Everything else keeps the massif's silhouette (its
terraces already give setbacks; no rim-setback rule in v1). `covered` is
recorded per cell exactly as `WarrenExcavation.covered` is today, so
overhead/cover metrics and the composition's bridge rooms see the same
facts.

## 7. Partition

Input: SOLID cells, passages, stamps. Output: `WarrenBuildingParcel`s in
today's contract (footprint columns, base band, top band, address walk cell,
threshold column, frontage direction), plus reservations.

1. **Blocks**: connected components of SOLID columns (4-connected in plan).
2. **Facing**: each solid column joins the nearest passage side (Manhattan,
   ties by hash); columns farther than the block's thickness from any
   passage (thick-core interiors) are *interior*.
3. **Footprints**: along each passage side, consecutive facing columns are
   grouped into houses 1 or 2 columns wide (hash-alternating, respecting
   terrace steps: a house never spans a terrace edge > 1 band); depth = the
   facing run to the block midline (or the far passage's midline).
4. **Interior columns** attach to the adjacent house on their side as its
   back/upper mass — this is what turns thick blocks into the mountain: the
   composition's existing "expand upper rooms into free massif cells" then
   fills them.
5. **Reserved blocks** (landmark, large house) become one parcel each with
   their recipe family flagged; courtyard rings become ordinary houses
   facing the court gate's passage *and* the court.
6. **Tops** follow the terraces exactly as today (`_top_band` rules reused:
   parity, storey minimum, no-straddle, plinth budget).
7. Nothing is discarded: `_discard_unassigned_mass` becomes an assert that
   the unassigned set is empty (or a small audited leftover of columns that
   fail the plinth/bearing rules).

Replaces: `WarrenSolidPartitioner`'s face-ownership + infill passes and the 8
partition variants. Reuses its per-parcel legality helpers.

## 8. Composition, fabric, placement (reused)

- `WarrenVolumetricSolver._partition_rooms` already takes reservations as
  inputs (`market_reservation`, `landmark_reservations`,
  `skywalk_reservations`, `courtyard_bridge_reservation`). Stamps are
  translated into those dictionaries; the joint market/landmark/skywalk
  **beam search is bypassed** (kept in the codebase behind the mode switch
  until removal).
- Room composition per building (storeys, authored room recipes, bearing
  graph, upper-room expansion) is reused unchanged. Residual backfill should
  find little to do; it stays.
- `WarrenSpatialFabricCompiler`, feature envelope checks, roofs/setbacks:
  unchanged. Their failures are *structural* and remain fatal for the seed
  after one local repair (§3).
- Terrain placement (`VillageWarrenFabricSolver` four-quarter placement,
  `solve_selected`) unchanged.
- Enclosure/size metrics stay guidance in the audit (already the case).

## 9. Determinism, pins, salt

- The pass is a pure function of (city seed, profile, ground bands). No
  attempts → the pin cache's `attempts_tried` is unused; success/failure
  pins remain useful as memo. `GENERATION_SALT` bumps when the carver lands.
- `WarrenTownSolver.GENERATION_MODE` gains `MODE_MAZE` (or the mass-first
  mode switches to the maze front-end once it passes §10); the old front-end
  stays selectable until then and is deleted afterwards.

## 10. Validation and measurement

- **Unit tests per stage** (GUT, pure lattice ops on small synthetic
  massifs): spine reaches the summit and records the market zone; alleys
  respect thickness/no-plaza/straight-run rules and reach the coverage
  target; each stamp's fit/shrink/move/skip; air covered set; partition
  covers every solid column and produces valid parcels.
- **Density probe** (`tests/harness/warren_density_probe.gd`, extended):
  frontage ratio, mass ratio, houses, block-thickness histogram, stamps
  placed vs quota, passage cells — per seed; targets: mass ratio ≥ 0.85,
  frontage ratio ≥ 0.9, stamps ≥ quota on ≥ 90 % of seeds.
- **Oracle** (`tests/harness/warren_search_oracle.gd`): seal / time /
  signature over the 9 seeds; target: 9/9 seal, ≤ 10 s each (one compose +
  one compile), determinism across runs and processes.
- **Corpus** (`production_warren_seed_corpus.gd`) for the record-level
  contract, and Ryan's visual review harness for the look before the mode
  switch flips.

## 11. Open decisions (need Ryan)

1. Market in every town, or only where the profile requires a covered market?
2. Large-house quota: reuse `balcony_range` as a proxy in v1, or add a field?
3. `p_loop` per profile (proposed 0.35 standard, 0.25 compact, 0.45 large/grand).
4. Frontage floor per profile for the invariant (proposed 0.90).
5. One entrance in v1 (proposed) — several later?

## 12. Risks

- The composition planner's assumptions about parcels being front-rank with
  discarded interiors: verified by running it on the new partition early
  (first milestone) before any stamp work.
- Composition time grows with room count (~2× rooms expected): measured by
  the oracle; acceptable if a town stays ≤ 10 s.
- The look is a generation change: visual review gates the mode switch.
