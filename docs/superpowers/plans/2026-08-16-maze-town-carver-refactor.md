# Maze town carver refactor and iteration plan

> **SUPERSEDED (2026-08-21).** History only — do not execute. The single live plan is `docs/superpowers/plans/2026-08-21-maze-town-master-plan.md`.


Date: 2026-08-16

Source design: `../specs/2026-08-16-maze-town-carver-design.md`

Companion performance roadmap: `2026-08-16-terrain-optimisation-roadmap.md`

## Outcome

Replace the searched mass-first front end with one deterministic solid-first
transaction. Public circulation is carved through the town mass before any
building is partitioned, so paths connect the whole town and most path cells
are bounded by inhabited construction. Feature space (markets, courts,
tunnels, skywalks, landmarks, and large houses) is reserved in that same
source plan rather than discovered by a late joint beam.

The existing room composition, authored-asset construction, fabric compile,
and terrain placement stages remain the migration target. The new path stays
behind `MODE_MAZE` until record, timing, and visual gates pass; `route_first`
remains the production default during the migration.

## Decisions resolved from the design draft

1. Every town gets a market. Compact and standard towns may use an open or
   lightly covered market square; large and grand towns require the covered
   market chamber.
2. `WarrenVillageScaleProfile` gains a real `large_house_range`. Balcony
   quotas remain façade-detail quotas and are not reused as a massing proxy.
3. The loop probability is explicit per profile: compact 0.25, standard 0.35,
   large/grand 0.45.
4. The initial public-passage frontage floor is 0.90 for every profile and is
   a sealed source invariant, not a downstream ranking preference.
5. Version one has one road-aligned entrance. Multiple entrances are a later
   grammar extension because they alter route and path-network ownership.
6. Façade depth is structural. Bump-outs, bays, balconies, dormers, turrets,
   and roof steps consume typed exterior envelopes and sockets; they may not
   be cosmetic overlaps applied after a building has sealed.

## Architecture

```text
WarrenMassifBuilder
        |
        v
WarrenMazeSourcePlan
  spine -> alleys -> stamps -> air -> blocks -> parcels
        |                                      |
        +-------- invariant + local repair ----+
                                               |
                                               v
WarrenVolumePlan -> room composition -> fabric -> placement
```

`WarrenMazeSourcePlan` is the sealed, worker-safe authority for the new front
end. It owns only plain lattice data:

- the immutable source massif;
- the connected spine and alley passage graph;
- the market zone and summit arrival;
- `SOLID`, `PASSAGE`, and `AIR` classification;
- named feature stamps and their exact reservations;
- block ownership, frontage, retained-mass, and thickness audits.

No stage below this boundary may infer topology from render placements. The
adapter may translate a sealed source plan into the existing volume/parcel
contracts, but it may not repair or search it.

## Invariants

- Pure function of `(city_seed, scale_profile, ground_bands)`.
- One source construction pass. DFS backtracking and one bounded local repair
  are allowed; generating complete alternatives and ranking them is not.
- All public cells are connected to the entrance.
- The fine route is a lossless projection of the bore: every nominal passage
  cell retains at least two 1.5 m floor lanes; every floor/tread remains inside
  the carved passage column and slot; no downstream town stage may drop a
  source floor. Deliberate late market aisles may extend this set only when
  they are carved, floor-classified, and connected in the final spatial grid.
- A passage uses only level, 2-cell stair, or 3-cell ramp strides.
- No accidental same-datum 2x2 public square.
- Straight runs are at most six cells on the spine and four in alleys.
- At least 90% of public passage cells front inhabitable construction. The
  separate addressed-column ratio measures how widely the network reaches;
  deep columns intentionally attached as a building's back/upper mass are not
  mislabeled as independent unfronted façades.
- No unreserved retained solid is discarded during partition.
- At least 85% of the SOLID remaining after carving receives a parcel owner;
  this is a partition invariant. Raw source-solid survival is reported
  separately because passages and courtyard shafts are intentional removals.
- Stamp skip/shrink/move outcomes are reason-coded audit facts.
- The worker pipeline creates no Nodes, meshes, materials, or server-backed
  resources.

## Milestones

### M1 — sealed source plan and main spine

- Add `WarrenMazeSourcePlan` with explicit passage kinds, market zone, summit,
  source-state queries, deterministic signature, and a real seal.
- Add shared passage-lattice rules so the maze and legacy excavation adapters
  agree on stride/headroom geometry.
- Add `WarrenMazeCarver` main-spine DFS: one entrance, ground market approach,
  climb to the summit region, no alternative bore corpus.
- Unit tests: determinism, dictionary-order independence, market-zone
  ownership, route reachability, rise/run legality, summit arrival.

Acceptance: the compact/standard/large/grand synthetic massif corpus produces
one sealed source spine per seed without an attempt index.

### M2 — coverage-driven alley network and air

- Grow alleys from transition endpoints outside the market zone.
- Use the rim-to-core thickness field as a legality rule, not a score-only
  hint; loop joins are explicit graph edges.
- Stop on frontage target or the profile passage budget.
- Open non-core passages to sky; retain covered market/skywalk cells and core
  tunnels; carve courtyard shafts when stamps land.
- Extend `warren_density_probe.gd` with frontage, two-sided passage, retained
  mass, block thickness, and open/covered passage histograms.

Acceptance: passage frontage >= 0.90 on the source-plan corpus, with all
public cells connected, no plazas, a measured addressed-column reach, and a
reported (not gated) raw-solid survival ratio. Post-carve mass assignment is
gated in M4.

### M3 — stamps as source edits

Implement in fixed order with `fit -> shrink -> move -> skip`:

1. universal market square/chamber;
2. summit or core landmark hall;
3. courtyard shafts and gates;
4. occupied skywalk/bridge spans;
5. protected large-house blocks.

Each stamp records quota, selected reservation, adaptations, and skip reason.
There is no joint hero-feature beam in maze mode.

Acceptance: every town has a market; required feature quotas land on at least
90% of the nine-seed oracle corpus, and a skipped optional stamp never rejects
the town.

### M4 — block/facing partition

- Replace face-serving and eight partition variants with solid components,
  nearest-passage facing, 1-2 column frontage runs, and interior attachment.
- Preserve protected large-house/landmark blocks and courtyard rings.
- Add `large_house_range` to the scale profile and deterministic signature.
- Assert no unassigned retained solid, with only explicit bearing/plinth
  leftovers permitted and audited.

Acceptance: one partition per source plan, valid address threshold for every
parcel, post-carve solid ownership >= 0.98 (above the design's 0.85 floor),
and no partition variant index.

### M5 — direct downstream reservations

- Translate stamps to the existing market, courtyard, landmark, and skywalk
  reservation contracts.
- Bypass the market/landmark/skywalk beam in maze mode.
- Permit one reason-coded local footprint repair and one re-compose only.
- Add `MODE_MAZE`; keep `MODE_ROUTE_FIRST` as default.

Acceptance: the nine-seed oracle seals 9/9, deterministic signatures match
across processes, and complete solve time is <= 10 seconds per town.

### M6 — larger cohesive buildings and façade depth

- Group compatible adjacent room parcels into named building lineages before
  façade selection so a large building has one palette, roof family, bearing
  graph, and seam authority.
- Expand the authored building grammar with L, T, stepped, courtyard-ring,
  tower-with-wing, and bridge-house envelopes.
- Spend per-profile façade-detail quotas across typed bay windows, shallow
  bump-outs, balconies, dormers, turrets, corner overlaps, and roof steps.
- Require every detail to bind a semantic socket and measured clearance
  envelope. Party walls suppress complete authored façade modules only.
- Keep the existing district colour field, but assign one coherent family per
  lineage and use accents at deliberate wings/details rather than per module.

Acceptance: no repeated three-storey whole-plate extrusion, no open façade or
roof seam, materially more silhouette/depth variation in the visual corpus,
and no increase in exact overlap failures.

### M7 — production streaming and real-time integration

- Complete optimisation-roadmap A: solve settlements away from the terrain
  worker, expose a placeholder footprint, and integrate sealed records without
  blocking unrelated terrain.
- Apply B (priority hygiene) before broad live playtests.
- Profile the maze transaction before D (mesher throughput) so work is not
  optimized around the retired search pipeline.
- Keep source planning resource-free and split composition/commit work into
  bounded worker/main-thread budgets.

Acceptance: ordinary terrain streams while a settlement is unresolved; only a
spawn-adjacent town can hold the loading gate; entering a newly resolved town
does not produce a multi-frame main-thread hitch.

### M8 — visual falsification and mode switch

- Capture entrance, market, alley both directions, courtyard, tunnel, skywalk,
  roofline, and exterior orbit views for every corpus town.
- Require distinct raw route and construction signatures across the corpus.
- Review specifically for disconnected-looking paths, open-sided lawns,
  module-box repetition, palette confetti, floating outcroppings, roof/party
  seams, and path/building clearance.
- Flip production to `MODE_MAZE` only after record, timing, and visual gates
  pass; then delete the old mass-first search front end in a separate change.

## Verification ladder

1. Pure stage GUT suites after every stage change.
2. `warren_density_probe.gd` for cheap topology measurements.
3. `warren_search_oracle.gd` (renamed once search is removed) for seal/time/
   process determinism across nine seeds.
4. `production_warren_seed_corpus.gd` for record-level invariants.
5. Full visual review corpus and adversarial camera/overlap audit.
6. In-game streaming trace with one near and one distant unresolved town.

## Performance dependency order

The implementation order remains A1 -> B -> A -> D -> C, with E folded into
touched files. Maze source timings, composition timings, and commit timings are
reported separately; a lower total may not hide a terrain-worker stall or a
main-thread commit hitch.

## Current progress

- [x] Design and current pipeline reconciled.
- [x] Open decisions resolved.
- [x] M1 source plan and spine.
- [x] M2 alleys and air. Coverage carving, air/tunnel classification, and
  deterministic explicit loop joins are sealed source facts; the common
  volume adapter copies each closing seam without topology repair.
- [ ] M3 stamps (the universal typed market square is complete; landmark,
  courtyard, occupied-link, and large-house stamps remain).
- [ ] M4 one-pass partition (an experimental authored-envelope compatibility
  pass exists, but back/upper ownership and the 0.85 solid gate remain).
- [ ] M5 downstream integration.
- [ ] M6 building/facade iteration (the common spatial compiler now assigns
  three lineage-stable construction styles, each with exact flush/rich recipes
  for tower/slim/row/square/long segment footprints; all pitched shells share a
  measured wall-top datum. Exact 3 m cropped roof ends now meet at one open
  party seam instead of overlapping; dormers are seated into the pitch and a
  bilateral long-roof variant exists. Seven complete 5.9--9.0 m authored house
  prefabs participate in compact landmark replacement, and optional landmark
  ranges now discover positive candidates before falling back to zero. Exact
  structural duplicates share one topology state but choose a seed-varied
  complete-house exterior, preserving visual diversity without frontier cost. Facade
  relief uses complete framed roofed bays and searches all eligible lineages;
  actual shifted upper rooms remain explicit structural outcroppings. The common
  compiler now rejects partial or floating generated plinths from the exact
  assembler face set: a retained base must close all four perimeter directions,
  render every exposed stone face, and meet stamped terrain within the native
  3 m foundation height. It also rejects door-shaped generated facade modules
  without an exterior entrance/private feature portal, and exterior entrances
  without an exact public-surface landing. Ordinary shallow room jetties use
  compact bracket courses rather than repeated storey-height diagonal posts.
  L/T/ring/
  wing envelopes and the maze-direct quota pass remain).
- [ ] M7 real-time integration.
- [ ] M8 visual gate and mode switch.

Current M1/M2 plus universal-market measurements over the nine production
corpus seeds: 9/9 seal, 58.3 ms mean source time, 1.0 explicit loop joins,
0.932 mean passage frontage,
0.507 mean two-sided passage ratio, 0.673 mean addressed-column reach, and
0.477 mean covered-passage ratio. Every source owns one typed 6 m by 6 m
market square; a tight turning approach uses its missing diagonal instead of
discarding the whole source. These numbers stop before composition, asset
compilation, or rendering.

`WarrenMazeVolumeAdapter` carries the typed market into the common
`WarrenVolumePlan` contract without geometry repair. Its boundary now proves
the bore and exact two-lane surface match in both directions, including the
second tread band in vertical stride columns. `WarrenSpatialPlan` separately
proves no source route floor disappears when late market cells are added, and
the spatial fabric compiler emits collision-bearing geometry for every logical
vertical transition. The reviewed compact production seed retains all 140
source floor cells, adds 8 connected covered-market cells, seals one 148-cell
walk component, and emits all 7 transition meshes (1,200 triangles).
Seven of nine current
sources pass that older contract; its generic broad-floor audit correctly
rejects the other two and must be reconciled at the source rather than waived.
The new `WarrenMazeBlockPartitioner` then emits one deterministic set of real
`WarrenBuildingParcel` envelopes (no variant index): its current compatibility
corpus is 7/9, 23 parcels and 21.8 ms on average, but only 0.394 mean post-carve
solid ownership. This is an integration probe, not M4 acceptance. Interior
back/upper ownership must raise that to at least 0.85 before the downstream
mode can be considered. The earlier hostile old-partitioner probe was 8/9 and
0.340 ownership; neither result is an acceptable fallback.

The current compact rendered diagnostic is similarly a falsification fixture,
not a mode-switch candidate. Its exact hard audits now report three of three
retained foundations with closed shells, 23 of 23 exposed foundation faces,
zero floating foundation columns, 13 of 13 visible generated facade doors with
typed access, one connected 148-cell public surface, seven aligned vertical
transitions, and zero unsupported stairs/platforms. The same pass still reports
only 0.341 retained private mass, 0.248 bounded-walk ratio, zero composed-walk
enclosure, fourteen plain setback caps, one complete-prefab source family, and
no elevated court. Those are successful critic findings: M4 back/upper ownership
and M6 compound-envelope work remain the next architectural fixes, rather than
being hidden by additional facade props.
