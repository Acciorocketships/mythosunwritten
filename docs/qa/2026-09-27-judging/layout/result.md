# Town layout — September 27 judging pass (stream `layout`)

## Proposed AGENTS.md paragraph

> September 27 town layout (owner review, seed 2697992464, photos 5/11:
> pathways ending in a railed one-cell deck; towns too uniform; size classes;
> lost maze intricacy). (1) Destination-owned pruning is general and exact:
> `WarrenMazeSitePlanner.finish_public_destinations` peels every leaf of the
> source walk graph (`WarrenExcavation.walk_edges`; a flight's treads travel
> with it, an empty lookout square is one node) that has no destination
> (doorway on a landing, portal, market, deck address), whatever its height.
> The destinations are exactly the doors construction builds: nothing is
> addressed to a flight's treads; bridges are allocated after the pruning
> (`WarrenPlotPlanner.allocate_bridges`), so no street survives only for a
> bridge-house and a span over a withdrawn street is withdrawn with it; a
> bridge compound may not take a planned house's doorway storey or a prefab's
> clearance (`_bridge_compound_taken`; at fine scale the solver releases it as
> `BRIDGE_YIELDS_TO_DOORWAY`); a base-tower merge may not swallow a door that
> opens onto a different landing; a house blocked above its doorway storey is
> shortened, not dropped. `PublicWalkAudit` censuses the finished realm:
> 0 dead-end nodes over the 48-town corpus and 300 rolled towns (baseline 215
> and 813); ceilings are 0. (2) One size distribution: `WarrenVillageScaleProfile`
> draws a continuous `size = roll^4` and interpolates every budget between the
> four reference points; no stage compares labels. (3) `WarrenTownField`: a
> crown lobe (its core always the summit), 1-5 satellites, 0-3 clearings, low
> spanning-tree shoulders; height is the max over lobes, so satellites step up
> to their own peaks. (4) Intricacy: loop connections are reserved during
> carving (loop joins before and after alleys; an alley that reaches another
> street's landing joins it; climbing connectors through the massif), natural
> tunnels at any height. Corpus cycle rank 1.42 -> 4.12, tunnel cells
> 0.19 -> 2.65 per town, walks under rooms +21% (12.4% -> 13.4%; Sep 10's 24%
> is not reached: most covered street columns carry no house because their
> roof floor matches no neighbouring street band). Every town that built on
> the baseline builds (48/48 corpus, 300/300 rolled; baseline 298/300). See
> `docs/qa/2026-09-27-judging/layout/result.md`.

## Summary

| Issue | Status |
| --- | --- |
| 1. Dead-end single-cell decks | Fixed by root cause: 0 dead-end nodes over the 48-town corpus and 300 production-rolled towns (baseline 215 / 813). Test and sweep ceilings are 0. |
| 2. One size distribution | Implemented (continuous size, interpolated budgets, court type by data). |
| 3. More open areas / variability | Improved (open fraction, enclosed clearings, distinct massifs up); satellites stepped and roofed. |
| 4. Restore intricacy | Partly: loops x2.9, tunnels x14, bridge-houses +10%, walks under rooms +21%; Sep 10's 24% share not reached (cause below). |
| Robustness (second pass) | Every town that built on the baseline builds: corpus 48/48, rolled 300/300 (baseline 298/300); source carve 3000/3000 rolled. |

The first-pass summary (27 residual dead ends, seed 123 and one carve failure open) is superseded
by the second pass below.

## Integration fixes (branch `judging-2026-09-27`)

Five tests that passed on their own stream failed once the new layouts met the roofs/details work:

| test | cause | fix |
| --- | --- | --- |
| `test_town_court_enclosure` posts | a court post stands on an outline vertex shared by four columns, but its bearing was computed only under the court cells owning the vertex; a retained lawn in a neighbouring column (common where a court meets a terrace step) was pierced | `SettlementFabricAssembler._anchor_retained_base`: a post bears on the highest retained terrace in any of the four columns (the `effective_support_base` rule extended to the post's full thickness) |
| `test_town_court_enclosure` skirt | the reported town's court now stands on its own terrace, not one band over a lawn | the invariant runs on the reported town plus two compact towns that do carry courts over a retained lawn (photo-11 town, seed 2) |
| `test_september27_town_details` supports | room-overhang posts stood at corner-cell points pushed diagonally outward, in front of neighbouring windows; balcony.04 (7/standard) raked onto a storey the designer then jettied, whose inset lattice puts windows where the upper storey's joints are | overhang posts stand on the overhang's outer corner vertices (wall-module joints, like balcony rakers); a storey whose upper neighbour bears a balcony door is never inset (`bears_balcony`) |
| `test_town_canopies` flights | the test took the highest stair in each column; the 7/standard canopy (band 0, 2.8 m tall) stands under a flight passing at band 5 | the test now flags only stair bands within the canopy's own height; admission (`crosses_flight`, band-1..band+2) was already right |
| `test_september27_roofs` tiny roof | a one-module-wide bridge-house ran its ridge along the span: a roof one module deep | a one-module-wide bridge-house turns its ridge across the span: `gap` modules deep, slopes into the endpoint houses (trimmed inside their walls), gables facing the lane like a gatehouse; two-wide spans keep the ridge along the span |
| `test_kit_roof_junctions` tunnels | the pin wanted more daylight than tunnel on a fully tall fixture; tunnels now bore wherever a storey fits, with one daylit cell between runs (owner request) | re-pinned to the actual short-tunnel rule: daylight breaks exist and no bored run exceeds `MAX_TUNNEL_RUN` (3); the run cap holds (not a regression) |

After the fixes: test_building_kit 8/8, test_town_architecture 11/11, test_town_closures 4/4,
test_town_court_enclosure 2/2, test_town_canopies 2/2, test_kit_roof_junctions 8/8,
test_september27_roofs 5/5, test_september27_town_details 4/4, test_september27_road_grade 5/5,
test_town_public_walk_dead_ends 3/3, test_town_destination_agreement 3/3; test_warren_maze_carver
12/13, test_warren_maze_plots 38/42 (unchanged baseline failures); test_warren_maze_composition
70/88: the same 17 failures as the merged run plus `test_corpus_composes`, whose 3/standard solve
timing (8.7 s vs 8.28 s scaled ceiling) was measured with four other Godot processes running; the
merged run measured 7.8 s and the solve path is untouched by these fixes. Mandatory sweep: 48/48
sealed, `dead_ends nodes=0 ceiling=0`, 13,044 walked cells centre-free, 0 blocked crossings.
Render: the 1260018864828801968/compact bridge-house now reads as a gabled gatehouse over the lane
(`scratchpad/int_layout/renders/sky/…_skywalk1_side.png`).

## Second pass (coordinator review)

### Robustness — every baseline town builds

Production path (`WarrenVolumetricSolver.generate`, rolled size) on the 48-town corpus (12 seeds x
four reference sizes) and 300 rolled city seeds 101-400:

| sample | baseline refused | after refused |
| --- | --- | --- |
| 48-town corpus | 0 | 0 |
| rolled seeds 101-400 | 2 (211, 387) | 0 |
| rolled source carve (`carve_rate.gd`, i=1..3000) | 0 of 1,000 measured | 0 of 3,000 (first pass: 1 of 1,400, i=1290) |

Root causes fixed (each in the generator's reservations/ownership, no retries):

- **Seed 123 (terrain foundations).** The route-connected rooftop court opened public air on a crown
  whose slab bears a composed house one storey up; the house then had no bearing. The court now
  skips crown cells whose headroom (or the band above it) is a composed room
  (`_carve_route_connected_rooftop_court`).
- **1/1,400 carve failure (spine DFS exhaustion, i=1290).** The field could leave the designed crown
  as a narrow isolated top. The crown lobe is wider (0.65-0.9 R) and its core is kept as the summit
  (`WarrenTownField.CROWN_CORE`: height = max(lobe heights, sharpened crown core)); spine targets the
  crown column; portals must front at least one addressable side.
- **Rolled 174 / 187 (roof gate).** A maze plot's flat crown that cannot take a joined gable now falls
  back to its slab like any refused preferred gable instead of rejecting the town, and a crown face
  whose gable band is public air takes the one-band plank cap (`WarrenSpatialFabricCompiler`).
- **Rolled 399 (found by the sweep).** An irregular rooftop court's one-lane opening was accepted
  onto a stair; the realm adapter folds a one-lane court only into a level walk node, so the opening
  must meet a level street square.
- **Rolled 182** built again once the above were in.

### Zero dead ends — the planner's destination facts equal construction's doors

Single rule: a street is kept only for a door construction will build. Every class the previous 27
residual dead ends (and 27 more over 300 rolled towns) came from is closed at its source:

| class (example) | cause | rule |
| --- | --- | --- |
| bridge over a flight (132, 141, 212, 258, 281, 301, 324) | a street was kept for the bridge-house over it, whose endpoint door on the tread construction closes | bridges are allocated after pruning (`WarrenPlotPlanner.allocate_bridges`); a bridge span is never a destination; a span over a withdrawn street is withdrawn with it (proof ledger kept index-aligned) |
| bridge reserve over a house (358) / prefab clearance (184, 330) | the bridge compound (span + both endpoint rooms, eaves) reserved a planned house's doorway storey or a prefab's roof clearance | source: `_bridge_compound_taken` refuses such a bridge (doorway storey and below; prefab body + roof band, one-column eave halo); fine scale: the solver releases a compound whose raster takes a doorway storey (`BRIDGE_YIELDS_TO_DOORWAY`) |
| base-tower merge (372) | two coplanar ground towers merged; the secondary's door, on a different landing, vanished | the merge requires the secondary's doorway to open onto the primary's landing |
| stacked upper storey blocked (12/large house.008) | the whole parcel dropped when an upper storey met a reservation | the parcel keeps the tallest prefix that still holds its doorway storey (`shortened_parcel_count`) |
| shared facade (1/compact house.008) | one median door per joined front even across street squares | one entrance per street square the front faces |
| court/deck leaf | small courts counted as destinations by the pruner but not by the audit | courts must reach `OVERLOOK_MIN_CELLS` (16) |

Result: 0 dead-end nodes on the corpus and on 300 rolled towns. `DEAD_END_CORPUS_CEILING` and
`CORPUS_SUBSET_DEAD_END_CEILING` are 0; the mandatory sweep prints
`dead_ends towns=48 nodes=0 worst_town=0 ceiling=0`. New `tests/test_town_destination_agreement.gd`
pins the eleven seeds (red on the previous tree: each had a dead end in `rolled_r2b`).

### Intricacy

Loop connections are reserved during carving, before frontage/plots consume the cells: loop joins run
before and after alleys; an alley whose next stride reaches another street's landing at its own level
joins it (`_alley_join_target`, recorded as a loop edge); when no straight connector exists a bounded
BFS finds a climbing connector through the massif (`_climbing_loop_candidates`). Tunnels bore at any
height with >= 1 daylight cell between runs.

| metric (mean per town) | baseline 48 | after 48 | baseline rolled 300 | after rolled 300 |
| --- | --- | --- | --- | --- |
| refused towns | 0 | 0 | 2 | 0 |
| dead-end nodes (total) | 215 | 0 | 813 | 0 |
| loops (realm cycle rank) | 1.42 | 4.12 | 1.20 | 2.64 |
| tunnel cells (source) | 0.19 | 2.65 | 0.15 | 1.26 |
| covered source walk cells | 14.6 | 19.8 | 8.76 | 10.8 |
| bridge spans (source) | 3.00 | 3.44 | 1.43 | 1.99 |
| bridge-houses built | 2.02 | 2.23 | – | 1.34 |
| walked cells under rooms | 34.5 | 41.8 | 16.3 | 21.0 |
| share of walks under rooms | 0.124 | 0.134 | 0.080 | 0.098 |
| open fraction inside bbox | 0.357 | 0.421 | 0.409 | 0.438 |
| enclosed clearings | 0.02 | 0.15 | 0.06 | 0.14 |
| distinct high massifs | 1.71 | 1.94 | 1.82 | 2.32 |
| turns / 10 cells | 2.86 | 2.90 | 2.97 | 2.91 |
| walked cells | 252 | 272 | 159 | 181 |
| buildings | 88.7 | 90.1 | 51.6 | 58.7 |

The Sep 10 share (24.3%) is not reached. Diagnosis over eight corpus towns: of 146 covered source
street cells, 88 carry no house and no room above — the columns' retained roof sits at a band that no
neighbouring street addresses, so no plot grows onto it (houses are seeded from street landings at
their own band). Houses over covered streets need an addressable "tunnel-roof" plot rule (a back room
of the neighbouring house, or seeds from upper streets at the roof band); not done here.

Street-level renders (session scratchpad `…/scratchpad/layout/renders/r5_corpus/`, not committed):
`12_grand_passage0.png` (a narrow boarded lane under overhanging floors and a covered bay),
`12_grand_passage5.png` (a stair climbing through a passage under a bridge-house, gabled house
beyond), `4_standard_passage1.png` (a lane under a roofed overhead), `3_large_skywalk0_below.png`
(under a bridge-house ceiling), and `12_grand_overview.png`. Contact sheet:
`renders/r5_passages_sheet.png`. Several automatic passage cameras land inside enclosed yards or
clip a wall (sheet cells 4, 8, 9); they are harness framing, not geometry.

### Composition pins

| pin | status |
| --- | --- |
| `test_a_street_borne_crown_stays_in_the_flat_vocabulary` | passes again (the plank cap on low-air faces removed the derived/published disagreement) |
| `test_optional_facade_projections_yield_to_mandatory_shells` | passes again |
| `test_bridges_become_rooms_decks_or_audited_releases` | re-accounted: a bridge that yields to a planned doorway storey is a named release (`BRIDGE_YIELDS_TO_DOORWAY`, added to the vocabulary) and leaves the share's denominator; the owner's request (every walk leads to a real door) decides that outcome, it is neither silent loss nor blind stamping. 6357506428441529412/standard: 3 stamped, 2 yielded, share 1.0 |
| `CARVE_FRONTAGE_FLOOR` (carver) | re-pinned 0.60 -> 0.40: the requested open ground leaves compact towns with narrow arms whose streets pass a clearing on one side (worst 0.4286); frontage is advisory in production, destination pruning guarantees destinations |
| deck shortfall audit (plots) | the planner now publishes the quota's roll cell (`deck_quota_cell`), because pruning may withdraw the summit climb the quota was rolled at |

Newly exposed by layout drift, left failing and listed as open: `test_exterior_walls_are_plank_and_plaster_over_coherent_bases`
(9/compact 0.0484 high ashlar vs 0.04), `test_unroomed_plot_mass_is_bounded` (9/compact 0.525 vs 0.36: a
472-cell town whose two prefab clearance envelopes are 248 unroomed cells),
`test_the_town_s_decor_is_not_one_repeated_piece` (compile-time decor audit 5/10 types vs final payload
3/11 on 9/standard, 3/standard; 1/large plants 3 distinct pieces of 5).

### Satellite massifs

The first-pass field let a satellite read as one broad even plateau (the flat boxy block in the
first-pass 12/grand overview). Height is now the maximum over lobes (each a Gaussian peak) plus the
crown core, so a satellite steps up to its own summit and its houses get ordinary pitched crowns; a flat crown that
cannot take a joined gable falls back per plot, not per town. The second-pass 12/grand overview shows
the detached west satellite as stepped, pitched-roof houses.

## Method and tools (all under `tests/harness/layout_judging/`)

- `layout_corpus.gd -- --seeds 1-12 --scale compact,standard,large,grand|select --out FILE`
  solves each town with the production entry (`WarrenVolumetricSolver.generate`) and measures:
  dead-end public nodes (`PublicWalkAudit`), massif shape (open fraction inside the bounding box,
  enclosed clearings, distinct high massifs, low fraction), route intricacy (tunnel cells, covered
  source cells, bridge spans, lanes, loops/cycle rank, vertical transitions, walk levels, turns per
  10 route cells) and walked cells under inhabited rooms.
- `public_walk_probe.gd -- --city SEED:PROFILE [--at wx,wz --centre cx,cz]` lists dead ends, the
  source route/lanes/plots and maps a photo position to the town's local fine cell.
- `field_stats.gd` (field-level statistics and carve success over 150 hashed seeds per reference size),
  `carve_rate.gd -- N` (share of production-rolled towns whose source carves), `massif_map.gd`,
  `town_frame.gd` (production frame for `kit_town_review --frame`), `site_seeds.gd` (city seed of a
  super cell).
- Photo towns: photo 5 = super cell (0,1), city 1260018864828801968 (compact, centre 312,1056);
  photo 11 = super cell (-1,1), city 85830433957479026 (compact, centre -216,1152). The planner runs
  on empty ground bands, so each town is a pure function of city seed and profile.
- Before = baseline `db59f0c8` (a git-free copy with the audit added for measurement only).

## Issue 1 — pathways to nowhere

### Root cause

Both photographed decks are the same failure. Photo 5: the spine's last flight
(3,2,-1)->(1,3,-1) ends at a one-macro-cell landing with no door; photo 11: the
spine's last flight (0,1,-2)->(-2,2,-2) likewise. The old
`finish_public_destinations` only withdrew a terminal climb whose top was *above
every doorway in the town*, and only on the spine; lanes were never pruned.
In photo 5 a plaza deck was addressed to the flight's tread (a mid-flight
address), which also protected the flight. Corpus-wide the census found 215
dead-end nodes in 48 towns: spine tails after the post-summit descent, alley
tails beyond their last doorway, flights to empty lookouts.

### Change

- `WarrenExcavation.walk_edges()` / `flight_cells()`: one description of the
  public graph (route, lane and loop transitions; a flight's swept cells).
- `WarrenMazeSitePlanner.finish_public_destinations`: peel leaves without a
  destination repeatedly (terminal climbs, lane and descent tails, empty
  lookouts at any height). Destinations: plot doorways, portals, the market,
  bridge spans, deck addresses (a deck addressed beside a flight is entered
  from its access flight or a level landing). A withdrawn bore that lay under a
  house or rock returns to rock (nothing loses bearing); one open to the sky
  stays open ground (it reads as a small square).
- `WarrenPlotPlanner._seed_buildings` and the asset/plaza sites
  (`WarrenPlotReservations`) never address a doorway to a flight's treads —
  construction closes such doors, so those houses had no entrance at all.
- `PublicWalkAudit`: pure census of the finished `SectionalPublicRealmPlan`.

### Tests (red -> green)

`tests/test_town_public_walk_dead_ends.gd`
- `test_photographed_decks_lead_somewhere`: red at baseline (3 dead-end nodes in
  each photo town, including `volume.walk.07` = the photographed deck and
  `volume.transition.06` = its flight), green now.
- `test_corpus_pathways_to_nowhere_stay_within_the_measured_residual`: seeds 1-6 x
  four reference sizes; baseline had 102 nodes; ceiling 19.
- `test_audit_peels_a_railed_leaf_deck`: the audit itself.
- The sweep prints `SWEEP RESULT dead_ends` and errors above `DEAD_END_CORPUS_CEILING`.

### Visual evidence (renders in the session scratchpad, not committed)

`kit_town_review.gd` with the production frame and a camera behind the photo player:
- Photo 5, before: `renders/before_p5/…_photo5.png` reproduces the photo (stair to a railed deck).
  Dead-end fix alone (old field): `renders/fix_p5/…_photo5.png` and `…_photo5side.png` — the
  right-hand flight and its deck are gone; the remaining plank terrace joins the green and a doorway.
- Photo 11, before: `renders/before_p11/…_photo11.png` (flight up to a railed deck). Fix:
  `renders/fix_p11/…_photo11.png`, `…_photo11side.png` — flight and deck withdrawn; the stone
  block under them was open-sky bore and became a ground-level square joined to the street.
- Final state (new field etc.): `renders/final_p5`, `renders/final_p11` — different towns at the same
  sites (the field changed), 0 dead ends in both.

### Falsification

- Side views of both sites (above) instead of only the photo angle; the lower-left gap in photo 11
  is open terrain, not a pit (joined to the sandy street).
- 48-town corpus and 48 production-rolled towns audited; the remaining dead ends were classified by
  tracing their source plots: dropped by `exact_composition_unsolved` (a stacked plot whose parent
  storey claims the child's floor band — e.g. 12/large house.008 over house.002 top 5), closed
  facade (`room.*.closed`, e.g. 1/compact house.008), or a deck plot not joined through the address.
  These are composition-layer drops after the source counted the doorway.

## Issue 2 — one size distribution

- `WarrenVillageScaleProfile.from_size(s)`: every budget is piecewise-linear in `s` between the four
  reference points; ranges widen between them (floor down, ceiling up) so no in-between town is asked
  for more than a neighbour builds. `select()` draws `s = roll^4` (about 64% nearest the compact
  reference, 4.5% nearest grand; mean radius 5.6 cells vs 5.5 before).
- `for_id()` returns the reference points (identical budgets), so the 48-town corpus measures the same
  sizes; `from_record()` rebuilds the exact profile from `scale_profile_size` in audits and volumes.
- Consumers switched from label branches to `scaled()` tables: carver loop joins and secondary
  gates, plot building caps and storey budgets, deck caps and quotas, market horizon and aisle
  extension, overhead/alley guidance.
- Court type: the rooftop court previously ran only for compact/standard and the elevated courtyard
  only for large/grand (which in the maze pipeline never had authored courtyard cells, so large and
  grand towns never got a court). Both are now decided by data.
- Tests: `test_warren_village_scale_profile.gd` rewritten for the continuous contract (validity and
  monotone budgets at 100 sizes, anchor identity, label distribution) plus
  `test_no_generation_stage_branches_on_the_size_label`.

## Issue 3 — open areas and variability

`WarrenTownField` (field level, 150 hashed seeds per reference size, `field_stats.gd`):

| reference size | field | columns | open fraction | enclosed open / column | largest enclosed court | distinct high massifs | low share |
| --- | --- | --- | --- | --- | --- | --- | --- |
| compact | before | 95.793±23.741 | 0.401±0.090 | 0.070±0.071 | 4.040±3.907 | 1.807±1.170 | 0.443±0.055 |
| compact | after | 104.747±28.653 | 0.453±0.094 | 0.087±0.082 | 5.727±5.497 | 2.140±1.058 | 0.457±0.064 |
| standard | before | 140.887±36.095 | 0.394±0.092 | 0.058±0.069 | 4.847±5.323 | 1.640±0.911 | 0.364±0.047 |
| standard | after | 146.647±38.972 | 0.452±0.094 | 0.081±0.075 | 7.587±7.266 | 2.167±1.055 | 0.385±0.055 |
| large | before | 191.113±51.022 | 0.394±0.094 | 0.059±0.072 | 6.587±7.256 | 1.760±0.943 | 0.322±0.045 |
| large | after | 193.440±53.044 | 0.453±0.096 | 0.084±0.080 | 10.093±9.812 | 2.407±1.172 | 0.347±0.052 |
| grand | before | 248.687±67.536 | 0.398±0.095 | 0.059±0.074 | 8.540±9.475 | 1.960±1.058 | 0.292±0.041 |
| grand | after | 247.807±69.542 | 0.457±0.097 | 0.082±0.080 | 12.940±12.807 | 2.513±1.159 | 0.315±0.048 |

Corpus (48 towns, final state vs baseline): see the metric table below. The spine's
target is the field's designed crown (`WarrenMassif.crown_column`) instead of the
origin; portals must front houses (`_portal_cells`), which removed a class of
towns whose nearest boundary cell was a bare shoulder ridge.

## Issue 4 — intricacy

Regression analysis (same corpus metrics on older trees, read-only worktrees):

| tree | covered source cells / walk macros | walked cells under inhabited rooms | tunnel cells | turns/10 |
| --- | --- | --- | --- | --- |
| Sep 10 (`c98379f7`) | 19.8 / 31.0 | 24.3% | 0 (all covered by retained mass) | 3.20 |
| Sep 26 pre-field (`7977b85d`) | 16.5 / 40.6 | 12.5% | 0.31 | 2.82 |
| baseline (`db59f0c8`) | 14.6 / 39.1 | 12.4% | 0.19 | 2.86 |
| final | 16.6 / 34.4 | 12.9% | 2.19 | 2.78 |

Causes: the August 22 "streets open to sky by default" ruling removed covered
passages; the September 22 profile retune shortened compact spines/spans and the
shared low/high field added many flat ground lanes; the September 26 natural
tunnels were limited to straight, ground-level runs on a fixed 3-in-9 phase
(9 tunnel cells in 48 towns). Fix: tunnels anywhere the massif carries a storey
above the headroom slot, straight or turning, at any height, rock jambs on the
open sides, runs <= 3 with >= 2 daylight cells, seeded starts, never beside a
bridge-house. Loops (1-2 joins) and turn rate are unchanged: a leaf-closing loop
pass was tried and found no legal connectors (removed).

## Corpus metrics (48 towns, same audit; mean (sd) and total)

| metric | baseline mean (sd) | final mean (sd) | baseline total | final total |
| --- | --- | --- | --- | --- |
| dead-end public nodes | 4.479 (3.979) | 0.562 (1.135) | 215 | 27 |
| dead-end fine cells | 19.167 (17.126) | 2.750 (5.666) | 920 | 132 |
| open ground inside bbox | 0.357 (0.077) | 0.436 (0.069) | 17 | 21 |
| enclosed clearings | 0.021 (0.143) | 0.167 (0.373) | 1 | 8 |
| largest enclosed clearing (cols) | 0.021 (0.143) | 0.458 (1.670) | 1 | 22 |
| distinct high massifs | 1.708 (1.190) | 2.125 (0.992) | 82 | 102 |
| low columns share | 0.348 (0.067) | 0.374 (0.073) | 17 | 18 |
| tunnel cells | 0.188 (0.440) | 2.188 (1.996) | 9 | 105 |
| covered source walk cells | 14.625 (6.915) | 16.604 (8.423) | 702 | 797 |
| bridge spans | 3.000 (2.179) | 2.958 (2.245) | 144 | 142 |
| walked cells under rooms | 34.500 (21.593) | 32.625 (21.214) | 1656 | 1566 |
| share walked under rooms | 0.124 (0.067) | 0.129 (0.069) | 6 | 6 |
| turns / 10 route cells | 2.859 (0.462) | 2.783 (0.389) | 137 | 134 |
| loops (cycle rank) | 1.417 (0.702) | 1.312 (0.506) | 68 | 63 |
| vertical transitions | 10.312 (4.805) | 9.604 (4.531) | 495 | 461 |
| walk levels | 6.271 (1.604) | 6.271 (1.551) | 301 | 301 |
| walked cells | 252.417 (97.236) | 226.500 (88.914) | 12116 | 10872 |
| buildings | 88.708 (48.445) | 86.167 (48.907) | 4258 | 4136 |
| massif columns | 177.417 (79.564) | 182.250 (66.980) | 8516 | 8748 |

Older-tree rows (Sep 10, Sep 26) in `evidence/` were measured with the first audit version,
which also counted the covered-market floor as a dead end; their intricacy columns are comparable,
their dead-end column is not.

Renders (session scratchpad `…/scratchpad/layout/renders/`, not committed): `before_p5`, `fix_p5`,
`final_p5`, `before_p11`, `fix_p11`, `final_p11` (photo and side views, overview, orbit, top);
`base_corpus` vs `final_corpus` for 4/standard, 12/grand, 3/large (overview, top, street, tunnel).
Inspected: 4/standard now has two separate massifs with open ground between them and two large
greens (baseline: one square blob); 12/grand has a detached north-east massif and a court gap
(baseline: one rectangle); 4/standard `tunnel1`/`tunnel2` show timber-roofed passages under
houses opening onto a green. Kit tunnel cameras placed inside walls for some cells (harness
camera limitation; those frames are excluded).

## Tests run (second pass, final tree vs the baseline copy)

| file | final | baseline | notes |
| --- | --- | --- | --- |
| test_town_public_walk_dead_ends | 3/3 | red | corpus subset ceiling now 0 |
| test_town_destination_agreement (new) | 3/3 | red (each seed had a dead end on the previous tree) | eleven rolled seeds, one per dropped-door class |
| test_warren_village_scale_profile | 10/10 | 9/9 (old contract) | |
| test_town_layout_field, test_warren_massif, test_warren_inhabited_massif, test_september13_shared_stair_landing | all pass | – | |
| test_warren_maze_carver | 12/13 | 11/13 | frontage floor re-pinned (above); remaining failure is baseline's |
| test_warren_maze_plots | 38/42 | 38/42 | same baseline failures; deck audit reads `deck_quota_cell` |
| test_september8_night_destinations, test_september8_walkway_destination | 3/4, 1/2 | 3/4, 1/2 | identical baseline failures |
| test_warren_maze_composition | 70/88 | 70/88 | now pass: roof-inside-wall, canopy stocked, town gets its life (and the three first-pass drift pins); newly red: exterior high ashlar, unroomed plot mass, decor audit (all 9/compact / 9/standard / 3/standard / 1/large layout drift, listed as open) |

Mandatory sweep (`warren_maze_mode_sweep.gd`, 12 seeds x four sizes): 48/48 sealed;
`dead_ends nodes=0 ceiling=0`; clearance 13,044 walked cells all centre-free, 18,717 crossings, 0
blocked (baseline 12,116 / 17,448). Evidence: `evidence/sweep_second_pass_results.txt`,
`corpus48_second_pass.json`, `corpus48_baseline_v2.json`, `rolled300_second_pass.json`,
`rolled300_baseline.json`, `carve_rate_second_pass.txt`.

## First-pass tests (superseded)


Headless GUT, final tree vs the baseline copy (same test files where unchanged):

| file | final | baseline | notes |
| --- | --- | --- | --- |
| test_town_public_walk_dead_ends (new) | 3/3 | red (3 dead ends per photo town) | |
| test_warren_village_scale_profile (rewritten) | 10/10 | 9/9 (old contract) | continuous-size contract, label-branch guard |
| test_town_layout_field | 6/6 | – | |
| test_warren_massif, test_warren_inhabited_massif, test_september13_shared_stair_landing | all pass | – | |
| test_warren_maze_carver | 13/13 | 12/13 | fixture copies `crown_column`; the baseline momentum failure also passes now |
| test_warren_maze_plots | 38/42 | 38/42 | same four baseline failures; demand now excludes flight treads (no doorstep there) |
| test_september10_hamlets | 2/5 | 2/5 | same three baseline failures (legacy hamlet constructor) |
| test_warren_maze_composition | 67/88 (66/88 before the courtyard-pin update; `test_large_and_grand_towns_exist` re-run green) | 70/88 | 18 shared baseline failures; 4 new: `test_large_and_grand_towns_exist` (pinned the retired large/grand courtyard obligation; updated to assert no courtyard shortfall is owed), and three layout-drift pins left failing: `test_bridges_become_rooms_decks_or_audited_releases` (one standard town stamps 3/4 bridge plots), `test_optional_facade_projections_yield_to_mandatory_shells` (no planner seed exercises the yield path any more), `test_a_street_borne_crown_stays_in_the_flat_vocabulary` (derived 0 vs published 1 street-borne plate on 9/standard) |

The mandatory sweep (`warren_maze_mode_sweep.gd`, 12 seeds x four reference sizes) seals 48/48
(baseline 48/48), clearance: 10,872 walked cells all centre-free, 15,574 crossings, 0 blocked, 0 offset,
0 splits (baseline 12,116 / 17,448, fewer walked cells because dead-end walks were withdrawn). Street
pinch 31 non-blocking pillar contacts (baseline 28). New row `SWEEP RESULT dead_ends towns=48 nodes=27 worst_town=6` (ceiling now 27; the run above still printed the old ceiling 16).

## Open items

- **Walks under rooms**: 13.4% corpus (Sep 10: 24.3%). Needs a plot rule for houses on covered street
  roofs whose band no neighbouring street addresses (diagnosis above).
- **Three composition tests newly red from layout drift** (listed above); the decor one is an
  audit-versus-payload disagreement that the new layouts expose.
- Automatic passage cameras sometimes land inside yards; pick views by hand.
- Photo-angle renders use `kit_town_review` on flat ground with the production frame and an
  approximate camera (the F7 close camera cannot be solved from the overlay); not the live world.

## First-pass open items (superseded)


- **Dead ends are not zero.** 27 nodes remain over the 48-town corpus (3 over 48 production-rolled
  towns). Every one traced so far is a doorway the source counted that the composition later
  removed: a stacked plot whose floor band the parent storey claims (`exact_composition_unsolved`,
  e.g. 12/large house.008), a plot colliding with a skywalk reservation (1/standard house.003 — a
  three-flight climb to it survives), a facade the compiler closes (`room.*.closed`, 1/compact
  house.008), a deck plot not joined through its address. The exact fix is to prune on the
  composition's realised doorways (or keep those parcels); a realm-level withdrawal after composition
  was judged too risky (under-roof crowns would lose their roof). Pinned as a ceiling (sweep 27,
  test subset 19) so it cannot grow.
- **Town existence.** Production-rolled sample (seeds 101-148): 47/48 seal (baseline 48/48); seed 123
  is refused by the terrain-foundations gate ("terrain-bearing room … 4/16 exact source-bearing
  columns and no grounded tunnel portal"), independent of the tunnel and pruning changes (reproduced
  with both disabled) — a composition limitation exposed by the new field layout. Source carve
  success on 1,400 production-rolled seeds: 1399/1400 (baseline 1400/1400; the failure, i=1290,
  is a spine-DFS exhaustion). Both mean a settlement site can lose its town; they need a
  composition/spine robustness pass.
- **Intricacy (issue 4) only partly restored.** Tunnels are back (9 -> 105 cells) and covered source
  cells +14%, but loops (1-2 joins), turn rate and the Sep-10 share of walks under rooms (24% vs 13%)
  are not. A leaf-closing loop pass found no legal connectors under the current connector rules
  (removed). Next levers: longer/winding loop connectors across levels, bridge-house quotas, and the
  compact route-span budget the Sep 22 retune reduced.
- **Open areas (issue 3).** Clearings are open terrain; streets reach them only where a ground lane
  borders them. Enclosed clearings are still rare in absolute terms (8 of 48 towns).
- Three layout-drift composition pins listed above are failing and need re-measurement.
- Photo-angle renders use `kit_town_review` on flat ground with the production frame and an
  approximate camera (the F7 close camera cannot be solved from the overlay); not the live world.
