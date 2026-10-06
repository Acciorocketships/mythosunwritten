# Town generator rule audit — October 7, 2026

Read-only audit of the production town generator at tag `astra-town-redesign-2026-10-07`
(branch `town-redesign`). Purpose: separate **guardrails** (stop things that look broken;
stay hard) from **aesthetic rules** (should become tunable odds/ranges drawn per town),
before designing the shared "town odds" layer.

Owner principle (October 7): hard rules only as guardrails against things that look bad
and must never happen. Everything that would "look cool" or "look better" should be a
parameter with tunable odds, shifting behaviour rather than forcing it.

Paths are relative to `scripts/terrain/features/villages/` unless noted. Line numbers
are approximate (± a few lines). Seven parallel read-only passes covered ~110k lines;
the headline claims were re-checked by hand (tunnel chance 1.0, outcropping range zero,
fixed gate heading, every super-cell gets a town, dressing rolls default the seed to 0).

## How to mark this up

Each aesthetic item has an ID. Put one of these after it (or just strike/annotate):

- **odds** — turn into a tunable knob (my suggested range is a starting point)
- **keep** — fine as a fixed rule
- **later** — worth doing, not now
- **drop** — remove the behaviour entirely

Guardrails (section 6) default to **keep**; flag any you disagree with.

---

## 1. Headline findings

1. **Most of a town's look is fixed for every town.** Variety today comes almost only
   from one continuous size roll (`size = roll^4`), the town-field blob shape, and
   per-house rolls with the same odds everywhere. Nothing gives a town its own
   character (a "stone town", a "flat-roofed town", a "sparse leafy town").
2. **Fake or dead random rolls.** Tunnel chance is 1.0 (every eligible stretch bores);
   the hamlet/village/town tier and the town colour theme are rolled but never read;
   the plinth-height "choice" has one option; the roof-turret proposer is never called.
3. **Most dressing ignores the world seed.** `SettlementFabricAssembler._face_noise`
   defaults `world_seed = 0`; planting, plaza centrepieces, yaw, stall goods, skywalk
   order depend only on local lattice coordinates, so similar shapes get identical
   dressing. Lamps and furniture are placed in sorted order and bunch in one corner.
4. **Solid blocks come from three always-rules**, not from the street pattern alone:
   every street frontage gets a house, the orphan sweep ignores the house size cap,
   and the largest building always grows first (E1–E3). This is the "apartment block"
   source, and the place courtyard clearings would act.
5. **Every town has the same silhouette**: one storey per ring from the rim at every
   depth (wedding-cake cone), ground-level outer two rings, always a perimeter ring
   road, gates diametrically opposite, a 2×2 market square on a level approach.
6. **Upper storeys are always maximally jumbled**: every unforced upper storey is
   re-shaped toward "anti-tower" and anti-alignment; merges are greedy. Calm,
   stacked towns cannot be generated.
7. **Facade relief is forced on every eligible house** (oriels from two separate
   passes, upper projections, loggias, stepped wings), so every street has the same
   busy rhythm.
8. **Some aesthetic quotas reject whole towns** (market square, straight-run caps,
   loop requirement, tower-annex seal). These should become shortfalls, not failures.
9. **Small towns can never have a courtyard**: the court is gated by a hard size
   threshold (DECK_MAX ≥ 9, `size ≥ 0.5`) plus a hard ceiling `court_count ≤ flag`.
   About 84% of towns are below it.
10. **Outcroppings are forced off everywhere** (`cantilever_range = 0` at every size);
    skywalk counts are set entirely upstream by geometry, never drawn.

---

## 2. Aesthetic hard rules → proposed knobs

### A. World placement and town presence

| ID | Rule today | Proposed knob | Where |
|---|---|---|---|
| A1 | Every 768 m super-cell gets a town (chance 1.0) → strict town grid | `settlement_density` 0.5..1.0 | `../SettlementPlan.gd:12` |
| A2 | Site = flattest meadow candidate, always (no towns on ridges/hillsides by choice) | `site_preference` weights (flat / meadow / ridge) or softmax temperature | `../SettlementPlan.gd:85-97` |
| A3 | Primary gate always faces north | `gate_heading` (4 quarters, or toward strongest road) | `VillagePlan.gd:136` |
| A4 | Each world road joins the nearest gate; approach hugs the town's bounding box (reads as a box ring) | `road_gate_choice` (nearest / weighted), `approach_style` (hug / direct curve) | `VillageWarrenRoadConnections.gd:18-95` |
| A5 | Town size skew fixed (`roll^4`) | `size_exponent` 2..6, per-world size bias | `fabric/WarrenVillageScaleProfile.gd:21-24,152-160` |
| A6 | No waterside towns (108 m from water is a guardrail, but there's no waterside variant) | later: `waterside_chance` with its own guardrail | `../SettlementPlan.gd:17,63` |

### B. Town shape and silhouette

| ID | Rule today | Proposed knob | Where |
|---|---|---|---|
| B1 | **Terrace cone**: every house ≤ 1 storey per ring from the rim at every depth | `terrace_storeys_per_ring` 0.5..2, `terrace_profile_chance` | `fabric/WarrenPlotPlanner.gd:892-905,593-595,680` |
| B2 | Outer 2 rings stay at grade; walls ≤ ring+1 storeys there | `grade_rings` 1..3, `edge_rings` 1..3, `edge_plinth_storeys` 0..2 | `fabric/WarrenMassif.gd:88`, `WarrenPlotPlanner.gd:98-99` |
| B3 | Ridge massif forces every house to 1..2 storeys | `ridge_storey_budget` range | `WarrenPlotPlanner.gd:762-763` |
| B4 | Storey ranges per size (1..3 … 2..5), no town bias | `storey_bias` (squat ↔ tall town) | `WarrenPlotPlanner.gd:70-73` |
| B5 | Skyline peaks: ≤2-column footprint, interior only, cap 4 storeys | `peak_chance`, `peak_storeys` 3..6, `peak_max_cells` 1..3 | `WarrenPlotPlanner.gd:833-889` |
| B6 | Citadel plinth always 2 storeys (one-option "choice") | `plinth_storeys` {2: 0.7, 3: 0.3} | `fabric/WarrenTownPlatform.gd:37` |
| B7 | Platform chance 0.6, not size-scaled; tiers up to 2 at 0.6 | expose `platform_chance`, `tier_chance`, `tier_count_max` (already random) | `WarrenTownPlatform.gd:32,166-174` |
| B8 | Crown nearly always central (offset ≤ 0.25 r) | `crown_offset_max` 0.1..0.6 | `fabric/WarrenTownField.gd:23-24,51-53` |
| B9 | Satellite count not size-scaled; gap greens 1..3 (header says 0..2) | size-scale counts; fix header | `WarrenTownField.gd:56,85-93` |
| B10 | Terrace relief, plateau caps, edge roughness fixed | `terrace_relief`, `plateau_cap_share`, `edge_roughness` | `fabric/WarrenMassifBuilder.gd:22-28`, `WarrenTownField.gd:126` |
| B11 | Per-size budgets (radius, core bands, lanes, overhead ratio…) interpolated with no per-town jitter | jitter each budget ±15% from the seed | `fabric/WarrenVillageScaleProfile.gd:36-49` |

### C. Streets and gates

| ID | Rule today | Proposed knob | Where |
|---|---|---|---|
| C1 | **Perimeter ring road always laid** on ring 2 (owner-flagged) | `perimeter_lane_chance` 0.4..0.9, `perimeter_coverage` 0.3..1.0 | `fabric/WarrenMazeCarver.gd:247,2721-2733,2899-3057` |
| C2 | Main gate = boundary column nearest the town origin | `portal_pick` weighted over top-K | `WarrenMazeCarver.gd:110,3233-3242` |
| C3 | Gate count 2..3 fixed by size; extra gates placed farthest-first (always opposite) | `gate_count` 1..4, `gate_spread` weight | `WarrenMazeCarver.gd:23-24,2629-2733`, `fabric/WarrenMazeSourcePlan.gd:193-195` |
| C4 | Main street must climb ≥ span floor to a summit ("every town is a climb") | `spine_span` drawn in range | `WarrenMazeCarver.gd:755,819` |
| C5 | Spine search weights fixed (momentum, crown pull…) | `spine_momentum` 0.5..1.5×, `spine_crown_pull` 0.7..1.3× (scale as a group) | `WarrenMazeCarver.gd:846-854` |
| C6 | Post-summit descent always attempted | `descent_chance` 0.5..1.0, `descent_target_storeys` 0..2 | `WarrenMazeCarver.gd:61,922-994` |
| C7 | Alley count/cell budget fixed by size | `street_density` × 0.7..1.3 | `WarrenMazeCarver.gd:1075-1112` |
| C8 | Alleys grow from the lowest band first (upper town always sparser) | `alley_anchor_bias` {low, high, random} | `WarrenMazeCarver.gd:1119-1131` |
| C9 | Alley rise penalty 5200 → alleys almost always level | `alley_rise_penalty` 1500..6000, `alley_join_bonus` 3000..10000 | `WarrenMazeCarver.gd:1672-1674` |
| C10 | Straight-run caps spine 6 / alley 4 — a **seal rejection** | `max_straight_*` ranges; make it a soft preference | `WarrenMazeSourcePlan.gd:26-27,238-243` |
| C11 | ≥ 1 loop required — a **seal rejection** (reachability holds without it) | `loop_join_target` = scaled ± 1, allow 0 | `WarrenMazeSourcePlan.gd:226-227`, `WarrenMazeCarver.gd:21-22` |
| C12 | Block thickness (street spacing) ramp fixed 1.5→3.5 | `block_thickness_core/rim` ranges | `WarrenMazeCarver.gd:3373-3383` |
| C13 | No 2×2 public paving anywhere (forbids informal widenings) | `allow_street_widenings` chance (keep seam/z-fight checks) | `fabric/WarrenPassageLatticeRules.gd:183-196` |
| C14 | Terminal lookout square whenever the spine ends on a stair | `lookout_chance` 0.3..0.8 | `WarrenMazeCarver.gd:410-476` |
| C15 | Platform streets front every citadel column; wall street always rings the plinth; one under-platform tunnel always tried | `citadel_street_coverage`, `wall_street_chance`, `platform_tunnel_chance` | `fabric/WarrenPlatformStreets.gd:12-63,321-379,488-546` |
| C16 | Market approach length fixed by size | `market_approach_cells` 3..7 | `WarrenMazeCarver.gd:342` |

### D. Open space: squares, courtyards, greens, market

| ID | Rule today | Proposed knob | Where |
|---|---|---|---|
| D1 | **2×2 market square required** — town rejected if none fits | `market_square_chance` 0.6..1.0, `market_size` 2×2..3×3 | `WarrenMazeCarver.gd:184-190,741-745`, `WarrenMazeSourcePlan.gd:191` |
| D2 | Interior elevated court: always tried for large+, never below (DECK_MAX ≥ 9); prefers lowest floor | `interior_court_chance(size)` at all sizes; random among top-k sites | `fabric/WarrenInteriorCourt.gd:17-18,95-104` |
| D3 | `requires_elevated_courtyard` / `requires_covered_market` = hard step at size 0.5; court count hard-capped by the flag | `court_chance` = lerp(0.1, 0.8, size), `market_hall_chance` likewise; ceiling → tunable maximum | `fabric/WarrenVillageScaleProfile.gd:182-187`, `VillageUrbanFabricPlan.gd:206` |
| D4 | Plaza: one always attempted; ranked enclosure → cut cost → near summit → largest | `plaza_chance` 0.6..1.0; weighted/top-k pick | `fabric/WarrenPlotReservations.gd:322-347,1294-1320` |
| D5 | Plaza/deck shape: rectangles only, short side ≥ 2, aspect ≤ 2 | `deck_shape` {rect, grown region}, aspect 1.5..3 | `WarrenPlotReservations.gd:248-249,1329-1364` |
| D6 | Deck quota compact always exactly 1; DECK_MAX area fixed by size | widen quota (compact 0..2), `deck_max_area` range | `WarrenPlotReservations.gd:164-172` |
| D7 | Rooftop court tried in every town; biggest-scoring always wins | `rooftop_court_chance`, count 0..2, top-k pick | `fabric/WarrenVolumetricSolver.gd:476-491,10834` |
| D8 | Market site: fixed ranking (undercroft first…) → same kind of spot every town | `market_site_style` weights / top-k | `WarrenVolumetricSolver.gd:3929-3938,4853-4873` |
| D9 | Exactly one village green; always the largest entered run; always a centrepiece | `plaza_count` 0..2, `plaza_centre_weights` {well, stall, tree, none} | `fabric/SettlementFabricAssembler.gd:5575-5800` |
| D10 | Court trees: tallest that fits, most central cell | `court_tree_height` range; seeded cell order | `TownCourtTrees.gd:79-105`, `SettlementFabricAssembler.gd:5784` |
| D11 | Every interior unbuilt pocket becomes a plant-only grove | `interstitial_planting_chance` | `TownGroundDressing.gd:141-165` |
| D12 | **New (owner proposal)**: courtyard clearings reserved during carving, biased toward thick blocks; any height (ground moderately favoured); 1+ connections to nearest streets; covered/open mix | `clearing_*` knobs — the first consumer of the odds layer | (to be designed) |

### E. Blocks, plots and massing

| ID | Rule today | Proposed knob | Where |
|---|---|---|---|
| E1 | **Every free street frontage gets a house seed** — no yards or gaps by choice | `house_seed_skip_chance` 0..0.15 (more at rim) | `WarrenPlotPlanner.gd:244-266` |
| E2 | **Orphan sweep joins every leftover column, ignoring the size cap** | `orphan_sweep_chance` 0.6..1.0 / `allow_cap_overflow` | `WarrenPlotPlanner.gd:360-427` |
| E3 | Largest building always grows next | `growth_order` {largest, smallest, shuffled} | `WarrenPlotPlanner.gd:286-298` |
| E4 | House footprint cap 2..N by size, no town skew | `plot_size_bias` (small-lot ↔ big-lot towns), `building_cap_min` 1..3 | `WarrenPlotPlanner.gd:19-21,281-284` |
| E5 | Houses never under/over a deck or asset column (whole column blocked) | re-measure, then `allow_house_under_reserved` | `WarrenPlotPlanner.gd:1452-1467` |
| E6 | Residual infill unlimited (profile budget ignored); fixed scoring weights | `residual_fill_ratio` 0.6..1.0, weight knobs | `WarrenVolumetricSolver.gd:9070-9078,16-23` |
| E7 | Back rooms cut largest-kind first | `back_room_kind_weights` | `WarrenVolumetricSolver.gd:116-122,8796-8831` |
| E8 | Lot merging: pair 0.85, rectangle 1.0, max 24 cells/8 span; rectangle-filling pairs first | `merge_chance` 0.5..0.95, `range_merge_chance`, size caps, ordering jitter | `kit/KitVillageBuildings.gd:888-977` |
| E9 | Landmark count range span of 1 (compact 5..6); carver preselects the minimum | widen (e.g. compact 2..6), draw in range | `WarrenPlotReservations.gd:433-434`, `WarrenMazeCarver.gd:2757` |
| E10 | Landmark ranking fixed (held first, corner-turret…); every listed asset placed in record order | top-k pick; `landmark_count` drawn | `WarrenPlotReservations.gd:1075-1090`, `WarrenVolumetricSolver.gd:4034-4053` |
| E11 | Native landmark designs: a frozen set of 40 configurations (seeds 0..7), same in every town; only 4 footprint templates | per-town sampled seeds / family weights; widen templates | `grammar/NativeHouseVocabulary.gd` |

### F. Skywalks, tunnels, bridges

| ID | Rule today | Proposed knob | Where |
|---|---|---|---|
| F1 | **Tunnel chance = 1.0** — every eligible stretch bores (comment claims "seeded choice") | `tunnel_start_chance` 0.2..0.9, `max_tunnel_run` 2..4 | `WarrenMazeCarver.gd:1807,1859` |
| F2 | All other passages opened to the sky (open by default) | `covered_lane_share` | `WarrenMazeCarver.gd:1738-1796` |
| F3 | Skywalk quota always targets the range max; ranking prefers near the rim | `skywalk_count` drawn in range, `bridge_rim_bias` | `WarrenMazeCarver.gd:2025,2146-2240` |
| F4 | Tunnel cover: every eligible bore gets an over-plot | `tunnel_cover_chance` 0.5..1.0 | `WarrenPlotPlanner.gd:1138-1194` |
| F5 | Bridge plot always exactly 1 storey | `bridge_storeys` 1..2 (needs endpoint work) | `WarrenPlotPlanner.gd:1055` |
| F6 | Assembler: every valid cycle span accepted; private bridge-houses capped at 2 | `skywalk_cycle_odds`, `bridge_house_target` by size | `SettlementFabricAssembler.gd:1184,7378-7417` |
| F7 | Longest skywalk 4 bays | `skywalk_max_bays` 2..4 | `SettlementFabricAssembler.gd:1180-1182` |

### G. Upper storeys and roofs

| ID | Rule today | Proposed knob | Where |
|---|---|---|---|
| G1 | **Every free crown is a pitched gable** (flat only as fallback/construction) | `free_crown_flat_share` 0..0.3 per town (keep the no-tiny-lid guardrail) | `fabric/WarrenSpatialFabricCompiler.gd:5198-5225`, `WarrenMazeBlockPartitioner.gd:350-357` |
| G2 | **Every unforced upper storey re-shaped**, ranked tower-relief → anti-alignment | `upper_recompose_chance` 0.4..1.0, `silhouette_jitter` | `fabric/WarrenRoomCompositionPlanner.gd:2832-2933,3318-3331` |
| G3 | Upper-plate and ground tower-pair merges always greedy | `upper_merge_chance`, `base_tower_pair_merge_chance` | `WarrenRoomCompositionPlanner.gd:261-475,1362-1666` |
| G4 | Cap-kind preference slim > building > long, fixed | `cap_kind_weights` | `WarrenRoomCompositionPlanner.gd:3281-3293` |
| G5 | Vertical repetition penalties fixed | `vertical_repetition_cost_scale` 0..1.5 (0 allows stacked towers) | `WarrenRoomCompositionPlanner.gd:40-43,4190-4205` |
| G6 | Tall-tower annex quota 1/2 — failure **rejects the town** | `tower_annex_count` 0..2; convert to shortfall | `WarrenRoomCompositionPlanner.gd:26-27,3957-3996` |
| G7 | Ground tower/slim/row always gets the short roof unless dormered | `short_roof_chance_ground` 0.5..1 | `WarrenSpatialFabricCompiler.gd:7712-7735` |
| G8 | Ground lid ≥ 16 faces always tries the railed terrace first | `ground_lid_terrace_chance` | `WarrenSpatialFabricCompiler.gd:5765-5790` |
| G9 | Adjacent short parallel roofs always fuse (drops dormers) | `parallel_roof_fuse_chance` 0.5..1.0 | `kit/KitRoofJunctions.gd:58-96` |
| G10 | Elongated ranges always seek a cross-gable | `range_cross_gable_chance` | `kit/BuildingDesigner.gd:666-671` |
| G11 | Square-crown ridge axis balanced toward 50/50 in every town | `gable_front_bias` 0..1 per town | `BuildingDesigner.gd:583-587` |
| G12 | Chimney/ridge-peak only on main wing; fixed odds; dormers fixed patterns | `chimney_chance`, `ridge_peak_chance`, `dormer_*` weights | `BuildingDesigner.gd:454-456,1079-1095` |
| G13 | Joined roof group always recoloured to the majority material | `junction_unify_odds` 0.7..1 | `fabric/FabricContinuousRoofPlan.gd:1214-1253` |
| G14 | Roof turrets: 0.45 chance but proposer never called | wire in `roof_turret_chance` or delete | `kit/KitRoofTurrets.gd:9,36` |

### H. Facade relief and building features

| ID | Rule today | Proposed knob | Where |
|---|---|---|---|
| H1 | Oriel bays on every long upper timber face (every 3rd slot) | `oriel_face_chance`, `oriel_spacing` | `kit/BuildingDesigner.gd:187-205` |
| H2 | Second bay pass, no chance roll (overlaps H1 visually) | `facade_bay_chance`; consider merging with H1 | `kit/KitTownFacadeBays.gd:22-30` |
| H3 | Fabric facade bay on every upper lineage | `facade_bay_chance` per lineage | `fabric/WarrenSpatialFeatureSolver.gd:436-443,2108-2141` |
| H4 | Upper front projection on every ≥3-storey house; second on ≥4 | `upper_front_chance`, `second_front_chance` | `kit/KitRoomProjections.gd:66,228,241` |
| H5 | Loggias tried on every eligible run | `loggia_chance`, `loggia_width` | `kit/KitLoggias.gd:13-29` |
| H6 | Stepped lower wing on every ≥2-storey house with crown ≥4×2 | `stepped_wing_chance`, width | `kit/KitSteppedWings.gd:12-19` |
| H7 | Attached towers 0.9; corner → eave → gable fixed order | `tower_proposal_share` 0.2..0.9, `tower_kind_weights` | `kit/KitTownTowers.gd:10-40` |
| H8 | Jetties 0.55/0.25; never two in a row | `jetty_*_chance`, `allow_stacked_jetties` | `BuildingDesigner.gd:146-149` |
| H9 | Balconies ≥ 50% of upper houses (overrides profile ceiling); ranking fixed | `balcony_density` 0.2..0.7, style weights | `WarrenSpatialFeatureSolver.gd:120-131,2942-2954` |
| H10 | Outcroppings forced off at every size (`cantilever_range = 0`) | `outcrop_count`; needs geometry work + shortfall conversion first | `fabric/WarrenVillageScaleProfile.gd:36-49`, `WarrenSpatialFeatureSolver.gd:62-71,348-388` |
| H11 | Fabric facade outcrops on every qualifying run; bay vs bump by coordinate parity | `outcrop_odds`, `bay_vs_bump` weight | `SettlementFabricAssembler.gd:1243-1250,8190-8222` |
| H12 | Porch canopy 0.9, awning 0.85 (near-forced) | `porch_canopy_chance`, `awning_chance` | `BuildingDesigner.gd:1130,1141` |
| H13 | Every closed door gets a wall lantern | `door_lantern_odds` | `fabric/SettlementFabricPlan.gd:1232-1237` |

### I. Materials and palette (town identity)

| ID | Rule today | Proposed knob | Where |
|---|---|---|---|
| I1 | Base kit always Suntail; Pure Village share 0.2..0.8 per town | `base_kit_family` weights (keep `pure_kit_share`) | `VillageWarrenFabricSolver.gd:122`, `kit/TownBuildingStyles.gd:9-10` |
| I2 | Stone ground storey: 1 in 3 lineages, capped at 22% of faces; kit layer 0.4 per house | `stone_ground_chance` / `stone_base_face_share` per town ("stone town" ↔ "timber town") | `WarrenSpatialFabricCompiler.gd:97-98,7626-7670`, `BuildingDesigner.gd:87` |
| I3 | Upper storeys never stone | `upper_stone_chance` 0..0.1 per lineage | `WarrenSpatialFabricCompiler.gd:7532-7545` |
| I4 | Facade palette 4:2:2 and roof 50/50 per district, fixed | `facade_palette_weights`, `roof_orange_share` per town | `WarrenSpatialFabricCompiler.gd:7791-7812` |
| I5 | Pure roof family 40/20/20/20 per house, no town bias | `roof_family_weights` (Dirichlet per town) | `kit/TownRoofPalette.gd:8-9` |
| I6 | Frame finish, plaster tint: uniform per house | `frame_finish_weights`, `plaster_palette` per town | `TownBuildingStyles.gd:16`, `BuildingDesigner.gd:246-252` |
| I7 | Colour district size fixed (12 cells / 7-cell patches) | `district_cells` 8..20, flip rate | `WarrenSpatialFabricCompiler.gd:25-26`, `KitVillageBuildings.gd:1580-1586` |
| I8 | Construction style uniform over 3 | `style_weights` per town (favour 1–2) | `WarrenSpatialFabricCompiler.gd:7695-7703` |
| I9 | Masonry tints: 3 fixed colours by district; stone courses alternate by parity | tint jitter; `facade_course_odds` | `SettlementFabricAssembler.gd:463-465,2592-2606` |
| I10 | Town colour theme rolled but never read | wire into roof theme or delete | `VillagePlan.gd:63` |

### J. Dressing and props

| ID | Rule today | Proposed knob | Where |
|---|---|---|---|
| J1 | Garden lamps: every free station, cap 4, sorted order (bunch in one corner) | `garden_lamp_odds`, `lamp_cap` by size, seed-shuffled order | `SettlementFabricAssembler.gd:6657-6700` |
| J2 | Garden furniture: every free edge cell, cap 4, 2 fixed kits | `furniture_station_odds`, cap, kit weights | `SettlementFabricAssembler.gd:6703-6763` |
| J3 | Roof terrace dressing fully determined by guarded side/size (same shape ⇒ identical) | per-element odds | `fabric/SettlementFabricProgram.gd:3230-3369` |
| J4 | Upper facade detail fixed table by theme × form | `facade_detail_weights` | `SettlementFabricProgram.gd:5698-5735` |
| J5 | Balcony decorated variant always preferred | `balcony_decorated_odds` | `SettlementFabricProgram.gd:4969-5050` |
| J6 | Perimeter frontage 0.66; 2-cell runs never dressed | `perimeter_frontage_odds`, narrow pool | `SettlementFabricAssembler.gd:963-1063` |
| J7 | Garden planting 0.34; plaza interior always bare | `garden_planting_odds`, `plaza_interior_odds` | `SettlementFabricAssembler.gd:568,584` |
| J8 | Activity groups ≥ 1 per open space; fixed spacing; woodland 20% zero | `group_density`, `group_spacing_m` (woodland already random) | `TownGroundDressing.gd:33-105` |
| J9 | Market stall always counter + hanging; always "garden" flavour | `stall_hanging_odds`, `market_flavour` | `SettlementFabricAssembler.gd:5052-5072`, `WarrenVolumetricSolver.gd:4762-4766` |

---

## 3. Fake, dead or no-op random rolls

| Item | Problem | Where |
|---|---|---|
| Tunnel start chance | 1.0 — the roll can never fail | `fabric/WarrenMazeCarver.gd:1807` |
| Hamlet/village/town tier (50/40/10) | Rolled, written to the record, never read | `VillagePlan.gd:62`, `VillageProgram.gd:20-21` |
| Town colour theme | Rolled, never read | `VillagePlan.gd:63` |
| Plinth storeys | One-option list `[2]` | `fabric/WarrenTownPlatform.gd:37` |
| Roof turret proposer (0.45) | `propose()` never called | `kit/KitRoofTurrets.gd` |
| Dressing seed | `_face_noise(..., world_seed = 0)`; most calls omit the seed | `fabric/SettlementFabricAssembler.gd:6961` |
| Outcrop kind salt | Constant never read; kind decided by coordinate parity | `SettlementFabricAssembler.gd:1281` |
| Facade module pick | Linear sum `x+z+y+w+seed` → diagonal stripes | `SettlementFabricAssembler.gd:3716` |
| Loop-join score | Uses distance from world origin, not the crown | `WarrenMazeCarver.gd:1188-1191` |
| Paired-relief flag | Passed in, never read | `fabric/WarrenRoomCompositionPlanner.gd:30-32,74` |
| Profile residual budgets | Ignored in maze mode | `WarrenVolumetricSolver.gd:9070-9078` |
| Profile skywalk/landmark targets | Feature pass sets them to 0; only shortfalls published | `WarrenVolumetricSolver.gd:2733-2734,3946-3951` |

## 4. Aesthetic rules that reject whole towns (convert to shortfalls first)

- D1 universal market square (no fit ⇒ no town).
- C10 straight-run caps (seal rejection).
- C11 at-least-one-loop (seal rejection; reachability holds without it).
- G6 tall-tower annex quota (one annex failing to seal rejects the town).
- H10 dormant "only N of M outcroppings" checks — fatal as soon as `cantilever_range > 0`.
- Hard ceilings in `VillageUrbanFabricPlan.gd:206,217-226` (market ≤ 1, court ≤ flag,
  landmarks/skywalks ≤ range.y) — make them tunable maxima.

## 5. Rules dressed as guardrails that are really aesthetic

- 22% stone face cap and 1-band "low stone base" rule (anti-fortress taste).
- Plaza dropped if it would cut the perimeter lane (protects C1, not safety).
- Column-wide block of houses under decks/assets (a seal-cost hedge).
- No-2×2 public paving (the real guardrail underneath is surface ownership/z-fighting).
- Market sight-horizon cap ("enclosed bazaar" preference; only aisle width ≥ 2 is a guardrail).
- "Never stack jetties", "elongated ranges always cross-gable", tower kind order.
- Guard rail *style* welded to the guard rule (procedural 1.15 m rail everywhere).
- Village-green 2-cell width preference living inside the street-entry check.

## 6. Guardrails to keep (condensed)

Default **keep** — all are "looks broken / must never happen":

- **Support and floating**: plot support rule (solid below, clearance above, not buried);
  stacking only with full parent cover; storey rests on ≥ 2 columns / 25% of plate;
  bridge endpoints ground-borne with flank rooms; no unborne crowns; datum ≤ 2 bands
  above ground; massif neighbour step ≤ 4 bands; residual rooms ≥ 50% bearing.
- **Walking space**: skywalk/outcrop headroom over streets; no plot in a street's
  headroom; modules intruding into walked surfaces dropped; market aisle/entrance ≥ 2
  wide; roof/public-air clearance; stair runs and planned-step limits; posts never in lanes.
- **Reachability**: door lane must land on a route surface; stranding refusal; district
  and house-site access lanes; gate flight required; reserved stair for decks with no
  level access; destination pruning of dead-end walks; frontage props need a clear approach.
- **Closure**: no flat lid smaller than a full plate; canopies/terminal steps never act
  as a roof; roofs join only on exact gapless chains; gable never faces an abutting wall;
  interstitial 1-cell slots must seal; fall-edge guards on open terraces/courts.
- **Fit**: native prefabs only on flat datum ground; eave halos; prefab body clear of
  public air; town relief ≤ 9 m; dry ground away from water; total re-grading.

## 7. Possibly missing guardrails (worth a test)

1. Deck support posts silently skipped (drop = 1 band, occupied column below, would
   cross a lane) with no substitute bracket — exposed deck corners may look unsupported.
   `SettlementFabricAssembler.gd:1386-1390`.
2. Rooftop court perimeter guard/parapet not checked in the court selector.
3. No check that a town with no road node still connects to a world road
   (`WorldFeaturePlan.gd:123-125` fallback).
4. Projection vs. designer oriel on the same storey: only a 1.5-module distance check
   between the two bay passes.
5. Public-court guards have no drop-height test (over-guards shallow edges).
6. Plaza/deck reachability from a gate relies on the access-stair rule; confirm the
   downstream route validator covers it.
7. `_append_terrain_bearing_foundations` (a gap-closing guard) is never called — confirm
   the gaps it closed no longer occur.

## 8. Dead or legacy code (not reached by production)

`VillageHamletConstruction`, `VillageMassingSolver`, `VillageMarketSolver`,
`VillageCirculationSolver`, `VillageTimberFabricSolver`, `VillageSkirtDeckSolver`;
outskirts solver/program except four helpers (outskirts are off: `VillagePlan.gd:103`);
`WarrenRisingRingPlanner`, `WarrenOverheadSolver` (solver part),
`WarrenElevatedFrontageSolver` (except two constants and two helpers);
the elevated-courtyard family in the feature solver; maze skywalk planners
(`_maze_connectivity_*`); `_variant_stamp`; `KitRoofTurrets.propose`;
`BuildingDesigner.design_standalone`; `grammar/PureVillageNativeHouse.gd`;
NATURAL_ROCK cliff machinery; constants `MIN/MAX_LOOP_JOINS`, `DECK_MIN`,
`FACADE_OUTCROP_KIND_SALT`, `TARGET_*` in the feature solver; `_is_structural_support_anchor`.

Removing these would make the odds layer easier to reason about; it is a separate cleanup.

---

## 9. Implications for the odds layer design

- **Two levels of draw.** Per-town *character* draws (e.g. `stone_share`, `roof_family_weights`,
  `storey_bias`, `street_density`, `flat_roof_share`) and per-instance rolls that read them.
  Town character is what's missing today; per-instance rolls mostly exist already.
- **Independent streams per knob**, keyed by knob name + town seed, so tuning one knob
  doesn't reshuffle the rest of the town (fair before/after comparisons).
- **Size scaling as part of the knob definition** (value or curve over `size`), replacing
  the step thresholds at size 0.5.
- **Shortfalls, not rejections.** Aesthetic quotas must never reject a town (section 4).
- **Pass the world seed** into every dressing roll and shuffle placement order (section 3).
- **One tunable table** (a resource file) with the defaults equal to today's behaviour,
  so turning the layer on changes nothing until a knob is moved. Each migration then
  moves one knob with a before/after on fixed seeds.
- Seal-cost comments in the plot planner carry stale measurements; re-measure before
  widening any range.
