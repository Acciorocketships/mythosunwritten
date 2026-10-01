> September 30 dual-grid terrain tiles (branch `dual-grid-terrain`; spec
> `docs/superpowers/specs/2026-09-30-dual-grid-terrain-tiles-design.md`, plan
> `docs/superpowers/plans/2026-09-30-dual-grid-terrain-tiles.md`). Terrain heights
> now live on lattice POINTS 12 m apart (`HeightfieldPlan.POINT`; the 24 m `CELL`
> is only the route/settlement/tint/grass-tile lattice), and each 12 m tile is a
> function of its four corners (`TerrainTileField`, the one kernel): per-layer
> slope (smootherstep bilinear) or cliff (step at the tile midline), so every wall
> is vertical on a dual-cell border x|z = 12 i + 6, owned by `point_of`, and
> `wall_segments` is the exact outline the mesher skirts, cliff sheet foot lines,
> grass and water read. Rulings: E2 is the default cliff end (wall to the tile
> centre, then a ramp; E1 selectable via `TerrainTileField.cliff_end`);
> non-crossing tile edges count as slope ends inside a mixed layer; saddles take
> max(bump); the water fill lattice sits off wall lines (nodes 12 i ± 3); a 24 m
> route edge is walkable iff both its 12 m point edges are. World native KayKit
> pieces, the lip clip, aprons, the cell-keyed `TerrainSurfaceField` (and its
> facade), crags/terraces and their frozen study fixtures are gone; the cliff is
> the rock skirt under the `sheet_bedrock` sheet. `NativeTerrainGrade` writes
> per-point controls: a pad owns every corner of the tiles it touches, the lower
> datum wins a shared corner. New: `HeightfieldPlan.LOWPASS_M` (default 0, off),
> F9 kernel port (`terrain_tile_kernel.gdshaderinc`), F3 tile readout,
> `tests/harness/tile_gallery.tscn`, `tests/harness/dual_grid_side_by_side.py`,
> `mesher.water_blocks` (shared field cache). Measured: isolated suite failing
> tests 207 (baseline, 423 files) -> 117 (344 files; 123 -> 73 files with a failure or
> script error); every remaining failure also
> fails at baseline except the parked water pending test. 49-chunk profile
> (seed 3046246887): worker 1340 -> 1203 s, mesh payload 674 -> 668 s although the
> branch builds the full sheet for every chunk (baseline profiler built none);
> like-for-like 9 chunks in `sheet_bedrock`: 191 -> 174 s; peak 6878 -> 7610 MiB.
> Open: steep massifs read as a dome (12 m edges see half the rise of 24 m cells,
> so fewer walls; low-pass 12 m barely helps; owner decision); E2 ramp-top chord
> notch (up to 1.76 m) in the 2 m terrain mesh under the sheet (shows only on
> painted roads); a parked 0.032 m water step at (1225, -56.375) with a pending
> test; mixed-datum pads within one tile; the outskirts gate trusts the patch
> target. Earlier entries describing cell-keyed terrain, `TerrainSurfaceField`,
> native cliff pieces, lips, aprons and per-cell controls are superseded. Review:
> `docs/qa/2026-09-30-dual-grid-terrain/result.md` (`before-*`/`after-*`/
> `lowpass12-*`/`compare-*`/`gallery*` images on disk); ledger
> `.superpowers/sdd/2026-09-30-dual-grid-terrain-tiles/`.
> Production cliff style: `FieldTerrainStreamer.CLIFF_STYLE` defaults to `""` and `scenes/world.tscn`
> sets `"sheet_bedrock"` (= `CliffRockStyle.PRODUCTION`); plain `"sheet"` now selects the plain-sheet
> study, not production, and earlier entries saying world.tscn sets `CLIFF_STYLE = "sheet"` are superseded.

> September 29 town review (stabilize, after merging the six streams). A
> storey touching another building is never jetty-inset
> (`BuildingDesigner._touches_other`; the inset left a 1 m dead slot and put
> the neighbour's corner post in front of a window, 7/standard). A maze back
> room / passage cover is its parcel's own room: the stamp records
> `room.audit.back_room_parcel_id` and `KitVillageBuildings._houses` builds it
> into that parcel's kit house (it stood as a twin gable beside its host);
> parts on higher ground are `grounded` in every house. Squares beside the
> at-grade lane may cut one terrace deeper (`PLAZA_CUT_BUDGET_BANDS` 2 -> 3).
> Re-pinned with history in the tests: `BUILDABLE_COVERAGE_FLOOR` 0.89,
> stacking corpus `STACK_PLANNER_SEEDS` (+10/standard), roofline minority
> 0.34, Town A compound > 0. A stale `.godot` uid cache (missing entries)
> shows up as "invalid UID" test errors: delete
> `.godot/editor/filesystem_cache10` and re-run `--import`. Open: bridges and
> full stacks fell with the citadel and the lane (27 -> 5 bridges, 19 -> 6
> stacks on probes); the lane keeps the reported-seed hamlet's public realm to
> one storey (`test_village_plan` span 2 < 3, left red for an owner call). See
> `docs/qa/2026-09-29-town-review/final/result.md`.

> September 29 town review (tiers): multi-level towns. A seed-rolled share of
> towns (~1/3 at production sizes) raise a citadel district on a two-storey
> rock plinth: `WarrenTownPlatform` is a component of the town field
> (rounded rectangle on the crown lobe, >= 3 rings inside, slid clear of the
> mouth, >= 9 columns), and `WarrenMassif.bearing_at` = ground + plinth is the
> one datum downstream reads. The plinth is never bored; no natural tunnel on
> it or within two rings of it. Within two rings of the wall the lower town
> stays under the plinth top (`huddle_top`, ground-relative, composed with the
> edges envelope in `WarrenPlotPlanner._building_top`). One open `citadel_gate`
> flight climbs along the wall from the spine's summit through a stone gate;
> upper-town lanes serve every platform column; a wall street runs round the
> foot. The plinth renders as a fortification (`BuildingKitAssembler.
> _assemble_fortified`: plain stone `suntail.stone.stone_wall_plain`, baked
> with the new `exclude_materials` option; batter, parapet with merlons,
> turrets, gate piers/lintel; the parapet replaces timber rails). Non-platform
> towns are byte-identical. Tests: `test_september29_town_platform`. Probe:
> `tests/harness/suntail/town_platform_probe.gd`; views: `kit_town_review
> --views platform`. See `docs/qa/2026-09-29-town-review/tiers/result.md`.

> September 29 town review (materials; photos 3, 5, 7, Town A). Generated
> public timber belongs to the kit: `KitSubstitution.redraw_public_surface`
> draws flights, ramps, landings, gate approaches and the structural deck
> skin with the kit deck board's material (boards across flights, tangents),
> removes a flight's generated guard beams from the render (collision kept)
> and rails it with sheared kit railings from the builder's `guard_spans` /
> `guard_index_ranges`. The legacy plank shader stays for legacy renders only.
> Tunnel-mouth arches (`WarrenTunnelArches`, Sept 9) are removed. A house
> standing on the retained podium (`kit.retained`/`kit.tunnel-ceilings`) has
> no stone ground storey: the course is its plinth (no flush/deep masonry
> jog, no offset corner posts). Test `test_september29_town_materials`. See
> `docs/qa/2026-09-29-town-review/materials/result.md`.

> September 29 town review (skywalks; owner photos 4, 8, 9, seed 2697992464).
> A bridge-house spans between two building STOREYS: exterior spans landing on
> walk surfaces (decks, crowns, floors) are always the open timber bridge (two
> adjacent lanes = one 3 m bridge); enclosed spans come only from
> `SettlementFabricAssembler._maze_passage_house_candidates` (both ends are room
> cells of different units at the bridge floor, whole 3 m bays), and each
> endpoint house opens a door onto it (`KitVillageBuildings._passage_house_claims`)
> on a flush storey (`abutted`: never inset, so no gap and no post before a window).
> Every overhanging storey rim (including a datum storey over air, recorded as
> `soffit_cells`) carries the floor beam (no plaster/board z-fight); roof over free
> air (loggia, porch) closes the attic with boards at the eave
> (`BuildingKitAssembler._assemble_attic_ceiling`). Tests:
> `test_september29_skywalks`. See `docs/qa/2026-09-29-town-review/skywalks/result.md`.

> September 29 town review (floating): the owner's floating stone boxes and
> "L-shaped skywalk" (photos 1, 2, 6, 10) were CROWNS -- bored-tunnel ceilings
> and rock shoulders left over a lane with open sky above (the plot model never
> builds on a passage column). Rule: stone resting on public air exists only as
> the bearing of a building room or walked floor on its column
> (`WarrenVolumetricSolver.unborne_crown_cells`); uncarried crowns are released
> after composition (`WarrenSpatialTransaction.release`, owner-only) and not
> retained, so the lane opens to the sky. A carried tunnel ceiling is drawn as
> its whole stone run up to the room it bears, with no deck of its own. Corpus
> invariant: `KitFloatingMassAudit` == 0 (`test_september29_floating_masses`).
> Tunnel-roof rule (`WarrenPlotPlanner.cover_tunnels`, plot kind `PLOT_OVER`):
> a bore whose crown bears on two real jambs is covered by the adjacent house
> storey just above the crown, stamped as that house's back room and re-proved
> on the built town (`_over_passage_is_borne`); covers are whole or absent.
> It restores little (9 -> 9 covered bores on the 14-town survey): most bores
> have no standing jambs or no house storey over the crown; carving and
> partition must co-decide covered passages. See
> `docs/qa/2026-09-29-town-review/floating/result.md`.

> September 29 town review (variety, photo 11: same roofs, same level, same
> direction). Root cause in the kit layer: every planner lot (mostly 2x2
> modules) was built as its own house and every square crown ran its ridge
> along X. `KitVillageBuildings.merge_houses` now merges neighbouring lots into
> compound buildings (stacked lineages always; rectangular unions, the twin
> gable rows, always and first; L/T contacts at 0.5; <= 24 modules, 8 across;
> lots touching bridge-houses/landmarks/split levels stay separate); each
> member's own top is roofed (`storey.roofed`), higher-ground members get
> `storey.grounded`, notched crowns fall back to members' own packing.
> Square crowns choose gable- or eave-to-street per house
> (`BuildingDesigner._square_axis`); a deep crown whose tall roof would not
> fit becomes a double pile before a flat terrace. Metric
> `tests/fixtures/roofline_variety.gd`, survey
> `tests/harness/suntail/roofline_variety_survey.gd`; 17 towns: minority
> ridge axis 0.26 -> 0.45, twin gables 0.24 -> 0.15 of touching pairs,
> compound houses 2% -> 20%; roof audit unchanged. Test
> `test_september29_roofline_variety`. See
> `docs/qa/2026-09-29-town-review/variety/result.md`. Determinism: GDScript
> `Array.sort()` orders StringNames by interned pointer, not text; sort ids
> with `KitVillageBuildings.sorted_ids` (`test_september29_town_build_order`
> rebuilds a town after others and compares payloads).

> September 29 town review (edges): towns met the lawn with 3-4 storey walls
> (photo 7). The massif does descend to a one-storey rim, but houses were not
> held to it: `_outer_terrace_top` exempted any parcel whose deeper
> neighbour was its own column, skyline peaks stood on the rim, kit landmarks
> were always 2-3 storeys, and a shifted upper floorplate could overhang a rim
> house. Now (`WarrenPlotPlanner.EDGE_RINGS` = 2): every parcel rises at most
> one storey per massif ring above its floor, and on the two edge rings walls
> stand at most `ring + 1` storeys above the column's ground (the +1 is the
> rim terrace a house may stand on); columns that cannot host a storey leave
> the footprint; no skyline peak on an edge ring; kit landmarks take the same
> cap (`edge_storey_cap`, own reserved air kept for their roof);
> `WarrenSpatialGrid.profile_ceiling` stops composition projecting OUTSIDE
> cells above the profile. Metric: `tests/fixtures/town_perimeter_profile.gd`,
> harness `tests/harness/layout_judging/perimeter_profile.gd`, test
> `test_september29_town_edges`. Follow-up (the one-storey stone "rampart"
> under rim houses): a PERIMETER LANE at grade runs along the second massif
> ring (`WarrenMazeCarver._lay_perimeter_lanes`, laid after the spine and
> market, before loops/alleys, around the previewed plaza site), so cottages
> stand at grade on the rim with houses across the lane; optional streets
> (alleys, loops, descent) never rise above ground on the two edge rings
> (`WarrenPassageLatticeRules.raises_edge`, `WarrenMassif.ring_depth`); the
> covered market never displaces a walk leaf's only doorway; maze stone left
> standing on air carrying nothing is released after rock retention; tunnel
> covers sit on their crown (`TUNNEL_OVER_MAX_LIFT` 1). Corpus 38/38 vs
> f1e5f619: rampart edges 288 -> 91, multi-storey rim houses 26 -> 0, houses
> 765 -> 1165. Second follow-up (landmarks 58 -> 20: the lane took their
> flat edge band): `_preview_reserved_columns` holds the landmark sites the
> plot reservation would choose (profile's `landmark_range.x`, at grade on
> the edge rings) and their measured reach (also kept from bridge endpoints);
> the lane walks round them (`_perimeter_detour`, rings 1-5); the plaza is
> held only if a throwaway lane lay shows it strands no part of the ring
> (`_perimeter_ring_cover`) -- a raised rim square that does is the photo-7
> rampart. Composition's pair/participant records obey the edge profile
> too. Corpus: landmarks 52 (f1e5f619 58), rampart 34, decks 34 -> 20 (open).
> The plots-test asset oracle now tries every landing door, as the planner
> does (`WarrenPlotReservations.door_access_for`). See
> `docs/qa/2026-09-29-town-review/edges/result.md`.

> September 29 terrain review (owner photos 1-11, seed 2697992464). F9's
> "yellow" was never grading: a graded region carries its town grade only as
> `native_control_heights` (its `terrain_grades` list is empty), so the old
> bounds test never fired and the yellow was the overlay averaging orange
> (dying cliff) with green (slope). `_cell_snapshot` now flags exactly the
> cells whose native control a town moved (drawn as yellow STRIPES); the
> stronger edge owns a quadrant's colour. The deformed ground there was the
> September 27 "dying cliff" rule (a cliff ending in a hillside lowered its
> edge midpoint halfway toward that corner, denting the plateau beside it).
> Owner: standardize (supersedes the September 27 cliff-end rule). No special case: every edge is flat,
> a one-storey smootherstep slope, or a full-height cliff, and a cliff whose
> corner ring is slope-connected ends through the ordinary corner blend in
> its last half cell (`TerrainSurfaceField._edge_control`; F9 has no dying
> category). The envelope's low-wall widening and the mesher's turf skirt
> below `LOW_WALL` are general height rules and remain. Sheet colour is a
> function of steepness alone (`CliffRockCrags.SHEET_LAWN_STEEPNESS`, the
> steepest ordinary slope, 47.6 deg: lawn below, moss by 60 deg); the Sep 28
> lift gate made a cliff's end ramp lawn beside its mossy face.
> Seams: grass on the slope sheet must keep its root plane within
> `GrassSupportSurfaces.FOOTPRINT_FLOAT` (0.2 m, what terrain grass floats
> over the kernel's own bends; was 6 cm), so grass carries over a rounded
> crest instead of ending on a line at the wall line. Road divots: the town
> collar rounded a road cell a storey down and `_grade_roads` pushed the new
> wall one cell out; roads are now relaxed along accepted road EDGES, last,
> after pad support (lower to one storey above, then raise to one storey
> below; only free road cells in reach move). Corpus 5 -> 0 broken road
> edges. Off the road, the collar's rounded blend also made cliffs between
> free cells (stray mounds near towns): `NativeTerrainGrade._relax_free`
> pulls free cells back toward natural, never past it, until every natural
> slope between free cells is a slope again; pad owners, pad support and
> regraded roads are construction (`construction_cells`) and keep their
> retaining edges. Corpus (radius 2, 23 towns): 40 -> 0. Tests: `test_september29_terrain_review` (frozen towns
> `tests/fixtures/september29-road-divot-*`). See
> `docs/qa/2026-09-29-terrain-review/result.md`.

> September 28 ground seams, inner-corner cut-outs, water spikes (owner photos
> 1-5, seed 2697992464). SEAMS: the terrain sheet lights with the exact field
> gradient (`TerrainChunkMesher.field_normals`), not per-chunk facet averages
> (they broke at every 192 m chunk border and disagreed with the slope solid).
> The `sheet` solid lies ON the terrain's 2 m chords (+`CliffSlopeField.COVER`)
> where it does not raise the ground and hands over to the exact envelope as
> its lift grows, so it joins the terrain tangentially instead of emerging
> along a crease at RAISED; painted ground (`CliffSlopeEnvelope.excluded`)
> keeps the old sunk backing. Moss grade on the solid is scaled by its lift
> (`native_roots[3]`): ground it merely covers is lawn, like the terrain. Grass
> on slope supports standing < `GrassField.SUPPORT_MIN_LIFT` (0.1 m) over the
> terrain grows the terrain's own grass (the grass-less strip at every foot).
> Tints on both use the terrain's 24 m cell-centre lattice. The across-wall
> shoulder starts at the wall line (`_walls` `lead`), not half a grid step early.
> WATER: the water never cuts the envelope. Removed: WATER_REACH planar caps,
> receivers, bank dilation, the 2 m block wet mask (levels are per node at the
> shore and at level changes, `_levels`). Walls do not round from a wet crest
> (water pouring over it). A wall facing a corridor at least 2 `CHANNEL_CORE`
> wide is fitted: its analytic closed profile is squeezed across the wall
> (`_channel_scale`, smoothed along the wall) so the bank goes under the water
> a quarter core short of mid-channel; the crease fillet never rises above the
> water in fitted channels; no bedrock benches under water. Narrower pockets
> are absorbed by the bank (Sep 26 rule). DIAGNOSTIC VIEW: F9
> (`TerrainCategoryOverlay`, screen-space decal over every surface, from
> `FieldTerrainStreamer.loaded_cell_at` snapshots): grey plateau, green 1-storey
> slope edge, blue 1-3 m level edge, red cliff edge, orange dying cliff,
> magenta/cyan rendered above/below the slope kernel, yellow graded, 1 m / 4 m
> contours, cell grid, blue 192 m chunk borders. Harness: `cliff_site_review
> --categories`. Tests: `test_september28_ground_seams`,
> `test_september28_category_overlay`. P03 ledge count now counts dry ground
> only (the fixture's 11 m tarn held 19 benches the old envelope built in the
> water). The water mesh itself still follows the kernel (square cell falls).
> See `docs/qa/2026-09-28-ground-seams/result.md`.

> September 27 judging pass (owner photos 1-13, seed 2697992464; five parallel
> streams merged on branch `judging-2026-09-27`; per-stream write-ups under
> `docs/qa/2026-09-27-judging/<stream>/result.md`, evidence JPGs on disk only).
> SLOPES: slope vs cliff is decided per EDGE, not per tile. A cardinal side whose
> storeys differ by two or more is a cliff edge (`TerrainSurfaceField.is_cliff_edge`
> / `is_wall_edge`); every other side, including the one-storey side of a cell
> that walls elsewhere, is the ordinary smootherstep slope with no envelope
> dressing. Slope edges take the pairwise minimum, cliff edges keep each owner's
> height, corners take the minimum over their slope-connected component, so seams
> stay single-valued. A cliff whose corner ring is slope-connected dies there: its
> high side lowers the edge midpoint halfway toward that corner so the wall fades
> along the whole edge. The `sheet` envelope closes only the crests of real
> discontinuities (`CliffSlopeEnvelope._close_walls`, each wall across itself,
> convex corners isotropically, below 3 m the shoulder widens so a dying face ends
> in a round blob); closing the whole ground had lifted every slope 0.57 m and
> roads cut it back (photo-9 strips), and the photo-12 divot was a one-storey wall.
> `LOCAL_RELIEF` is gone. Supersedes "a one-storey notch is an inner corner", "a
> cliff top walls every drop" and "every storey cliff takes the envelope".
> ROCKS: one stone colour, `rock_style.MEADOW_STONE_TINT` (.52,.475,.40), for
> bedrock, Meadow rocks and native cliff stone. A slope rock matches its substrate
> (exposure, moss grade, tint) only in a soft 0.3 m band above its contact plane
> (`meadow_stone.gdshaderinc`, shared with `cliff_crag`); above it keeps stone
> sides and grass tops. The sheet no longer multiplies a second anchor tint.
> Bedrock facets keep only their fall-line tilt (no saw-tooth triangles). Rocks
> nestle: `DressingCompiler.nestle_distance(a,b) = max(a,b) + 0.25 min(a,b)` (bases
> overlap, smaller centre outside the larger rock; supersedes "bases never
> interpenetrate"); slope clusters are 3-4 rocks round the main rock.
> ROOFS (kit layer): `KitRoofJunctions` is the one branch rule, also within a
> house; perpendicular branches stop at the host ridge (`clip_min/max`). Gables are
> trimmed only by an enclosed attic or solid wall, never by padded skins or public
> headroom; walking clearance over public floors is `TraversalEnvelope.MIN_HEADROOM`.
> No roof wing is one module deep (`BuildingDesigner._absorb_slivers`); roof over
> free air is a posted porch (`_porch_posts`) or the merge is rejected. Corpus of
> 50 towns: open wing ends 563 -> 0, holed gables 258 -> 4, eaves cut 282 -> 0.
> DETAILS: stone storeys are baked 0.2 m deeper (`masonry_depth`,
> `suntail.stone.*_deep`) so openings sit in reveals (retaining courses stay
> flush); `KitSubstitution` only redraws `stall`-tagged, non-`support` stalls;
> `PathProgram.filleted_path_shapes` paints the outer corner of an unfilleted
> turn; balcony/projection braces bear on wall-module joints, not across windows;
> porch canopies are arbitrated town-wide.
> LAYOUT: destination-owned pruning peels every walk leaf without a real
> destination, and destinations are exactly the doors construction builds
> (bridges allocated after pruning, `BRIDGE_YIELDS_TO_DOORWAY`, blocked houses
> shortened not dropped); `PublicWalkAudit` ceiling is 0 dead ends (baseline 215
> corpus / 813 rolled). Town size is one continuous draw (`size = roll^4`) with
> interpolated budgets; no stage compares size labels. `WarrenTownField` = crown
> lobe + 1-5 satellites + 0-3 clearings. Loop joins are reserved during carving
> and tunnels may turn/climb: cycle rank 1.42 -> 4.12, tunnel cells 0.19 -> 2.65
> per town. Rolled towns 300/300 build (baseline 298/300). Open: walks under rooms
> 13.4% (Sep 10 had 24%); 32 cross-house one-module roofs; lot houses skip the
> roof mesh union; one-storey table islands become mounds in lakes.

> September 27 dead-end road, root fix (seed 2697992464, player
> 1177.8,24,527): the town at (51,22) flattened its perimeter/handoff street
> to its datum beside the country road, a storey below natural, so road cell
> (48,22) became a cliff top and the accepted edge (48,22)->(49,22) an 8 m
> wall. Towns now seal their accepted incident roads
> (`PathPlan.accepted_road_masks_for_node` -> `VillageFrame.road_masks` ->
> `TerrainGradePatch.road_masks`, kept by every grade extension).
> `NativeTerrainGrade._grade_roads` lowers an unclaimed road cell that became
> a new cliff top to one storey above its lowest neighbour (finite lowering
> fixpoint, within one tile of the grade bounds): the road is graded down
> into the town and its paint stays continuous. The envelope's road-crossing
> carry (`excluded_at` kind 2, `RAMP_REACH`) is removed. Invariant: every
> accepted road edge walkable on natural ground stays walkable after grading
> (`test_september27_road_grade.gd`; corpus probe
> `tests/harness/road_grade_walkability_probe.gd`). Raised towns (road below
> the pad) and sinks deeper than the ramp's reach are not handled. See
> `docs/qa/2026-09-27-slope-ledges/result.md` section E.

> September 27 slope ledges / slope versus cliff / dead-end road (owner
> review, seed 2697992464). Bedrock treads never rise outward: the jut is
> gone. Tread levels (n*step-phase) no longer depend on the riser share. A
> final `_level_outward` pass caps each carved node by the surface one grid
> line uphill on its backing's fall line, so treads may tilt side to side
> but never lip. Jaggedness came from sub-grid treads and creases: the bench
> is now a tent-filtered cell average with rounded corners, tread >=1.75 m
> and riser >=1 m, and all neighbouring blocks are blended over 3 m. Split
> grooves and the fin filter are removed; cut faces keep their stone colour
> but are not benched. Ridges, bumps and bedrock need a real cliff: they
> fade in with relief from 4.5 to 8 m (`VARIED`), measured to the water
> surface, so a one-storey drop (or bank) is one uniform narrow-shoulder
> slope. The dead-end road's envelope mitigation was later replaced by the
> town-grade root fix below. See `docs/qa/2026-09-27-slope-ledges/result.md`.

> September 27 rock placement (owner: rocks scattered evenly, too many on
> the mountaintop, stacked pairs, sitting on the ground like separate
> objects). Probed at seed 2697992464 chunk (1,4): 94 of the 105 rocks in the
> reported 1.1 ha were bedrock slope foot rocks (`CliffSlopeField._find_rocks`,
> 75% of 7 m slots, 104 base-overlapping pairs); the isolated boulders on the
> flat top were `ambient.rock_large`. Slope clusters now occupy 10 m slots only
> where one coherent colony field (`colony01`, 56 m) allows, companions lie
> beside the main rock, and clusters compete as units (Matern II on cluster
> keys; no singletons). Rock `DressingSet`s may be colonies (`colony_radius`,
> `colony_members`: one Neyman-Scott parent per 24 m cell); boulders need a
> 1.5 m rise within 9 m; embedded bases never interpenetrate (`BASE_NESTLE`).
> `embed_fraction` sinks the whole compiled base outline below the ground and
> `RockSkirt` raises a ground mound that meets the rock. The mound is the
> surface it covers, swollen: each vertex takes that surface's own normal,
> tint, moss grade and exposure (only height differs). Over terrain it uses
> the terrain material with cell-pinned mesher heights/normals; over the
> bedrock sheet its triangles join `solid(owned)[0]` itself (same mesh, moss
> scale and collision). A tilted-normal or separate-placement mound read as a
> pale pad with an outline (follow-up review). Owned with the rock (seam-free);
> mesh-backed grass supports (no blades under the rock). Slope ground rocks gained catalog hull
> collision. Chunk: slope 389 -> 99, ambient 30 -> 9 rocks. See
> `docs/qa/2026-09-27-rock-placement/result.md`.

> September 27 mountain water: a spring fires only if its raw contour walk
> (`WaterPlan._walk`) ends beyond `SUMMIT_REACH` (96 m). About 10% of summit
> sources circled a narrow peak and stopped at 11 samples; their flank lake
> dug up to 79 m, so the storey clamp cut 12 m steps and water ran out of the
> mountainside (reported site: super-cell (0,1)). All other traces are
> unchanged. The slope envelope treats water no deeper than `WATER_SINK` as a
> film: neither a shore nor a cut. Previously a river's 0.1 m sill film grew a
> rounded bank over its own cascade. `_water_level` now returns films too.
> Three red-first tests; water suite otherwise matches baseline. The live P03
> crater is gone. See `docs/qa/2026-09-27-mountain-water/result.md`.

> September 26 ledge restoration / slope-normal follow-up: the 0.25 m
> recess cap had erased the bench geometry. Bedrock now shifts its complete
> block profile outside the continuous backing (original 3.5–6.5 m spacing,
> occasional 15% taller blocks), bounded below the local crest. Faces take
> 60–75% of the fall-line run so they lean with the hill; treads stay level.
> Dry banks permit relief, while roads and submerged channels remain clear.
> Keep the 8 m wet-core rule, 3–7 m crown guard and 0.25 m inward limit.
> 37 tests / 615 assertions; nine native chunks, six player walks, 526 ledge
> contacts, 170 surface contacts and 175 grass roots checked with no misses.
> Median face-normal deviation from the hillside falls from 16.81° to 11.05°.
> Front/side/above and neutral-material before/after/pixel diffs inspected.
> See `docs/qa/2026-09-26-rock-ledge-restoration/result.md`.

> September 26 circled mountain cut-outs: the owner's latest image exposed
> two actual geometry regressions. Water receiver cuts now require an 8 m
> wet-core radius (narrow wet pockets are absorbed by the bank; the broad
> opposing-bank channel still passes). Bedrock may recess only 0.25 m into
> the uncarved hill, while keeping up to 1.25 m outward relief. Normal
> gradients use the complete height envelope, never sparse-band +/-1
> classification sentinels. Original moss colours/blend retained; the
> recolouring-only candidate was rejected. 34 tests / 613 assertions, six
> actual-player walks through the three large circled areas, nine rebuilt
> chunks and front/side/overhead pixel comparisons pass. 152 surface and
> 185 grass-root samples have no misses; 208 shared normals match exactly.
> See `docs/qa/2026-09-26-p03-crown-colour/result.md`.

> September 26 P03 continuity (second owner reopening): fixed water cuts
> that overrode rounded crowns. Tall banks use relief-dependent parabolic
> runout, with submerged receivers between opposing banks; 5 m is no longer
> a hard maximum for tall slopes. Bedrock protects 3–7 m around crowns,
> unbenched blocks follow the hill, neighboring phases blend, displacement
> is bounded to 1.25 m, and artificial single-cell reversals are removed.
> Fitted foot assets no longer add redundant terrain mounds. Grass coverage
> follows continuous normals, not triangle facets. 48 tests / 689 assertions,
> six actual crown walks, nine rebuilt chunks and four matched pixel-diff
> pairs checked. Additional front/side views expose the right-hand geometry.
> P03 itself is foreground-occluded; do not use it alone as art acceptance.
> Narrow lower rock risers remain steep; original global art scope stays open.
> See `docs/qa/2026-09-26-p03-continuity/result.md`.

> September 26 P03 follow-up: the owner reopened the restoration after
> marking a remaining void, sharp crest, steep slopes, floating grass and a
> pale ledge stripe. That newer request authorizes gentler rounded profiles
> and continuous moss grading while retaining the surface-net rock style.
> Canonical water domains keep adjacent envelopes identical; shallow films
> cannot cut away the shoulder, and water caps cannot excavate ground.
> Cut walls retain backing; the surface-net gradient needs a three-column
> halo. Grass uses rendered triangles plus whole-clump support. Rock treads
> inherit uncarved hillside moss grade. 40 tests pass; native P03 has 242
> identical shared normals, 1,449 matching height samples and no sampled
> grass/surface contact misses. Nine rebuilt chunks and five matched image /
> pixel-diff comparisons reviewed. This supersedes the narrow restoration;
> broader original issues remain open. See
> `docs/qa/2026-09-26-p03-followup/result.md`.

> September 26 owner correction: the manual-cliff pass was REJECTED,
> especially p03's disconnected flat tops and angular stone. Preserve the
> original surface-net slope/rock style, original radii, palette and grass.
> Do not replace it with a direct heightfield or recolour/widen it. The repair
> is limited to omitted bedrock columns, consistent triangle winding, and
> removal of covered old grass lips/buried skirt edges while retaining exposed
> wall backing. 23 tests / 381 assertions and 526 sampled surface contacts pass.
> Current review: `docs/qa/2026-09-26-cliff-style-restoration/result.md`.

> September 26 bedrock in game (owner chose it): `world.tscn` uses
> `sheet_bedrock`. The slope fades to the terrain where the 14 m local relief is
> under 2-3.2 m (level steps take no slope). Gentle slope uses the exact lawn
> colour. Keep-out edges are resolved per node. Solid MARGIN is 4 m (no lip
> slits). Steep slope claims its grass points (no blades poking through).
> Slopes run 5 m into water, then sink; road/water cut faces are bedrock.
> Only foot rocks. Lip options: `+underlip` rejected; default hides only
> covered lips. Review: `cliff_site_review --full --shot`,
> `FieldTerrainStreamer.rebuild_terrain`. See
> `docs/qa/2026-09-26-bedrock-fixes/result.md`.

> September 25 rock/slope rethink (study, production unchanged): four methods
> compared at the massif under `sheet_<variant>` styles
> (`CliffRockStyle.sheet_study`). Recommended: `sheet_bedrock`, rock exposed in
> the slope surface itself (`CliffSlopeEnvelope._bedrock`, contour-stretched
> Voronoi blocks with their own benches, splits and interior jut, fading to
> nothing at each patch edge), with Meadow stone and facet normals in
> `cliff_crag.gdshader`. Asset stamps (0.5 m solid melts the shape) and asset
> fillets (smooth union swallows rocks) fall short. Studio:
> `tests/harness/slope_study_review.gd`. See
> `docs/qa/2026-09-25-rock-slope-rethink/result.md`.

> September 25 outcrop direction: the owner rejected the new row-based procedural
> exposure prototype immediately. It is removed from production. Use the older
> `CliffRockCrags` broad masses and irregular ledges as the starting point (Git
> `fa8b2e8b`, `5eb17926`), informed by the latest cliff reference images. Large
> upright faces, uneven deep splits, intermittent horizontal shelves, chipped
> edges; no repeated courses or brick wall. Meadow boulders stay at the foot.
> Localized generated exposures, restored ledges and the reported dark green
> terrain seams remain open. See `docs/qa/2026-09-25-outcrop-direction/result.md`.

> September 25 Meadow implementation: all active landscape rock choices now use
> Meadow 01–12 (portable catalog visuals plus convex ground-rock collision).
> Mid-slope groups use distinct Meadow 01–05: large, compressed faces, recessed
> outer ends, maximum roughly 0.8 m exposed projection. A shear follows the slope
> while keeping authored grass ledges horizontal; bottom boulders remain upright.
> Rock grass and slope share `slope_green.gdshaderinc` (palette, detail texture,
> world mapping and grade); native warm stone stays separate. Broader envelope
> shoulder contrast makes rolling ridges visible. Owner permits falling back to
> dedicated cliff assets if the Meadow faces still look like ground boulders;
> this visual choice remains subject to review. See
> `docs/qa/2026-09-25-meadow-world/result.md`.

> September 25 owner selection: use Meadow rocks. The owner likes the pack
> store screenshot’s grass-topped summer rocks. Original Unity materials confirm
> `S_Props.shader` blends rock albedo/normal with `T_Terrain_Grass_01_A/N/S`
> on upward surfaces; autumn uses DryGrass, winter Snow. This shader layer
> was omitted by the GLB converter, so the catalog’s bare-rock materials are
> incomplete. The implementation above restores the layer with slope-matched green;
> the bent Farmlands inclusion pass below was rejected for dark faces, repeated
> shapes and green halos. The implementation above also adds rolling relief. See
> `docs/qa/2026-09-25-rock-catalog/meadow-material.md`.

> September 25 shallow-rock follow-up: the owner rejected the rectangular
> Farmlands cliff masses and exposed shelves. Face inclusions now use five
> irregular Farmlands RockMedium assets, 6–8.5 m primary widths (4.5 m at
> tight corners, with anchor-height retries), shallow depth and recessed ends.
> Distinct assets with substantial visible faces form each cluster (baked
> `CliffSlopeRockFronts.gd` samples reject buried companions). Cap triangles, including
> internal shelves, are fitted from worker-pure `CliffSlopeRockCaps.gd`
> (bake: `tests/harness/bake_slope_rock_caps.gd`). Face moss swells are off;
> join moss and inverse-transpose shading support the nonuniform scale.
> 36 focused tests pass. See
> `docs/qa/2026-09-25-shallow-rock-inclusions/result.md`.

> September 25 slope outcrops: face clusters now anchor near mid-height,
> with their long axes in the envelope tangent and tapered, buried ends;
> basal clusters are 25% larger. Clusters retain two or three rocks, never
> a failed singleton. The envelope is modestly wider (shoulder 1.8–4.8 m,
> foot 3.6 m); tall relief retains a 0.7–1.4 m shoulder blend / 1.5 m foot
> so rolling ridges survive. KayKit ambient/cliff-foot rocks are replaced
> with LPFV choices and terrace-cap rocks are retired. Native cap checks
> cover 4/8/16 m walls and corners. See
> `docs/qa/2026-09-25-slope-outcrops/result.md`.

> September 27 town scale, canopies and closures: the owner found towns too
> small. `VillageWorldScale` is 4/3 larger and still on the terrain grid:
> 4 m fine / 8 m macro cells (three per 24 m terrain cell), 3 m bands / 6 m
> storeys, Suntail at a uniform 2x (`KIT_WORLD_SCALE`); every consumer reads
> the frame constants (stairs add treads: `MAX_STAIR_RISE` divides by
> `VERTICAL_SCALE`). Warren record discovery covers the whole 192 m inset
> (`VillageProgram.WARREN_RECORD_REACH`); measured large/grand towns reach up
> to ~190 m including the grade collar, a measurement, not a proof. Porch
> canopies are one wall module wide (role anchor), back posts on the wall
> face, admitted only on level public floor at the storey band, clear of
> STAIR claims and raised gate flights (`KitVillageBuildings.flight_columns`)
> and of each other. Retained terrace walls, and facades whose lower band is
> backed by ground or another building, carry no windows. A court bears on
> the retained terrace beneath it (`SettlementFabricAssembler
> .effective_support_base`): one band above it the retaining skirt closes the
> gap and posts never pierce the lawn. Flight guards clip against inhabited
> room and retained cells (kit walls, grown by the wall face); a clipped rail
> end gets its end post seated in front of the face. Second pass: a storey
> hanging over public air closes its underside even at the house datum (the
> bridge-house over the lane was floorless); one-band retained courses are
> flush masonry (sunk storey panel on the ground, never the corner-piered
> Stone_Base plinth); every exposed convex kit wall corner gets one corner
> post (`BuildingKitAssembler._emit_corner_post`); player-sized props keep
> their pre-upscale world size (`VillageWorldScale.HUMAN_PROP_*`,
> `KitSubstitution.HUMAN_PREFIXES`, assembler `prop_scale`). Tests:
> `test_town_canopies`, `test_town_court_enclosure`, `test_town_closures`.
> See `docs/qa/2026-09-27-town-scale-gaps/result.md` (open items there).

> September 26 town depth/shared field: all production settlements use the
> same volumetric generator. `WarrenTownField` samples elliptical lobes,
> clearings and low connecting shoulders before boring; population labels
> no longer choose square hamlet versus warren architecture. Size budgets
> remain. Upper faces gain spaced bays; `KitLoggias` recesses L/U balconies
> into alternate storeys with real room floors/ceilings. Public platforms use
> short wall braces, including corner bearing. Native kit roof joining stays
> active. Source voids survive adapter envelopes; shared route air keeps its
> owner. 71 focused tests pass; the 48-town corpus compiles after one repaired
> row rerun, with 81 clear capsule probes and nine retained tunnel ceilings.
> Five adjacent legacy planner tests also fail on the base revision; no clean
> whole-suite or startup-speed claim. See
> `docs/qa/2026-09-26-town-depth-field/result.md`.

> September 24 building kits (Suntail migration, branch `suntail-towns`):
> village buildings are no longer drawn from the SFV/LPFV recipe art. A
> pack-agnostic layer in `scripts/terrain/features/villages/kit/` realizes
> the planner's buildings: `BuildingKit` (native metric + ROLE -> baked asset
> table; `SuntailBuildingKit` is the Raygeas Suntail pack), `BuildingMass`
> (architecture IR in module cells and planner bands), `BuildingDesigner`
> (stone/timber, per-edge jetties, bays, pent eaves, finishes, gable wings,
> dormers, chimneys, awnings, dressing; clearance-checked), and the pure
> `BuildingKitAssembler`. `KitVillageBuildings` adapts the sealed warren
> (lineage parts merged into houses, landmark reservations, balconies,
> overhang supports, skywalk bridge-houses, retained-terrace skin) and
> withdraws the legacy units/families it replaces; `KitSubstitution` redraws
> remaining legacy public pieces by measured bounds (tiled) and swaps props;
> `KitStandaloneHouse` draws hamlet lots. The world frame follows the kit
> metric: `VillageWorldScale` is anisotropic (x8/3 horizontal, x2 vertical
> on the 1.5 m lattice since September 27) so Suntail renders at a uniform
> 2x with 6 m storeys; ask `scale_of` (horizontal) or `vertical_scale_of`. New packs add
> a kit + bake manifest (`material_palette`/`material_roughness` restore
> vendor shader tints). Review: `tests/harness/suntail/kit_town_review.gd`
> (flat-ground towns by city seed), `building_gallery.gd`, and
> `village_site_capture.tscn --orbit R,H --ground-ring R` in-world. Pinned by
> `tests/test_building_kit.gd` (House_1 replica inventory). Spec/plan:
> `docs/superpowers/specs|plans/2026-09-24-suntail-building-kit*`.

> September 22 town review (photos 1-5, seed 2697992464): four issues, each
> red-first with matched native and fresh live photo-angle pairs and pixel
> differences. R1: same-datum compact crowns now join — a branch continues to
> its perpendicular host's ridge (flush end buried, explicit roof-junction
> partners), a square leaf beside a longer parallel crown turns into it, and a
> modular roof continues over the compact double pile tiling its end wall.
> R2: recessed LPFV half-roof gables are bake-fitted flush with their facade
> (bounds unchanged). L1: a prefab may take a raised datum only if that level
> keeps room for companion buildings; a withdrawn climb's floating headroom no
> longer creates phantom volume mass. W1: timber convex corners and deep-door
> return seams each own a slender timber post. 48/48 towns seal with 11,752
> clear positions / 16,898 crossings. See docs/qa/2026-09-22-manual/issues.md.

> September 23 cliff rock direction (owner selected): `CliffRockStyle`
> defaults to subtle projection (foot 0.26 of the old depth, 0.17 at convex
> corners, crown fifth untouched), ground-up moss in `cliff_crag.gdshader`
> (UV2 = height above terrain, vertex colour = lawn tint), and inner-corner
> terraces (`CliffKitDressing`): 9 m native-kit tops on storey bands whose
> wall rows join the ordinary rock pipeline. Outer-corner platforms and the
> `chunky` tier facets are rejected/optional. Shape tests written for the old
> full projection pin `CliffRockStyle.apply("current")`. Subtle narrows
> ledges (walls keep 58-76% turf; convex corners none). See
> docs/qa/2026-09-23-manual/02-subtle-moss-terraces/result.md. Follow-up:
> collinear panels of different heights abut (`left_abut`/`right_abut`,
> 1.2 m joint fade) instead of both fading to bare wall; convex corners stand
> on a measured lower-tier edge; subtle columns cannot undercut faster than
> 45 degrees; moss is darker, textured (`cliff_moss_detail.png`) and graded
> to 8 m. See docs/qa/2026-09-23-manual/03-moss-joints-overhangs/result.md.
> Second follow-up: a panel continues 3 m into a collinear neighbour at least
> as tall and cross-fades (no joint crack); stepped convex corners on a tier
> narrower than 2 m keep only a skin; moss is graded by relative cliff height
> (UV2.y) to every crest, blends into the lawn at the foot, and can use any
> pack's rock-moss layer (`CliffRockStyle.moss_texture`: raygeas | suntail |
> angry | polyart). See docs/qa/2026-09-23-manual/04-moss-textures/result.md.
> Owner picked `raygeas`; the lawn colour now fades into moss over 4 m with
> patches. A `slopes` trial (not default) turns the lower cliff into ridged
> mossy talus running into the terrain, with pack rocks (`CliffSlopeRocks`,
> source-loaded, no collision) set into it. See
> docs/qa/2026-09-23-manual/05-mossy-slopes/result.md. The owner rejected
> that pass (banded colour, seams, rock noise on the slope, sparse rocks). The
> second pass replaces it with `CliffRockCrags._slope_faces`: a smooth
> superellipse fillet (vertical at the wall, tangent to the ground), unioned
> smoothly with the finished rock. It tapers at every end and raises shared
> mounds under bunched, sunk pack-rock clusters. The shader grades lawn into
> moss with warped, patchy fbm gradients instead of bands. See
> docs/qa/2026-09-23-manual/06-smooth-slopes/result.md. Third pass
> (September 24): per-formation slopes left blades at every formation end,
> so `CliffSlopeField` now emits the slope as its own sheets. There is one
> sheet per merged foot line and one per outer-corner arc, on world-aligned
> columns with world-space parameters and 5 m ridges. Sheets taper wherever
> a foot line stops. Formations keep their rock but are pulled inside the
> sheet below the 2 m rock band. Ledges are off by default
> (`CliffRockStyle.ledges`; ledge-generator tests pin them on). Moss is
> thick up to 60% of the wall. Rocks are the layered Meadow P_Rock 01-05
> and Farmlands Cliff_Flat with grass tops. `slopes_cliffs` trials
> Farmlands cliff masses on walls. See
> docs/qa/2026-09-23-manual/07-slope-sheet/result.md. Checkpoint tag
> `checkpoint/cliff-slope-sheet-2026-09-24`. Fourth pass: the `sheet` style
> (`CliffRockStyle.sheet_only`) makes the slope sheet the whole wall. There
> are no crag meshes. The sheet runs from under the grass lip, near vertical
> (power 1.7), to the ground. All rocks follow one bunch rule
> (`CliffSlopeField._find_rocks`; cliff masses stand upright where steep).
> The sheet takes a smooth union with an ellipsoid per rock. See
> docs/qa/2026-09-23-manual/08-whole-wall-sheet/result.md. Fifth pass:
> - Sheet columns hang from the lip to the lowest ground along their run
>   (`_frame`), so stepped corners wrap.
> - Inner corners round with a fillet that fades in at steps.
> - Moss covers the full height (`moss_full`).
> - Ground rocks bunch at the foot; cliff rocks stand out higher up.
> - Ridges are warped two-octave noise; small bumps and divots are added.
> - Kit terraces are off under `sheet`.
> See docs/qa/2026-09-23-manual/09-sheet-ridges-rocks/result.md. Sixth
> and seventh passes: `sheet` is one implicit solid (`CliffSlopeField.solid`),
> a smooth union of per-line/arc slope heights (`slope_height`,
> `a*x^0.6` falling to real ground) and the sunk terrain, with no per-column
> base. It is meshed by surface nets with neighbour-union level ranges and
> gradient normals. Storeys merge; ridges lift the whole face; rocks form
> 7-11-rock outcrops on each merged line. See
> docs/qa/2026-09-23-manual/10-slope-solid/result.md. Eighth pass: the
> profile is a quarter circle plus a 0.35 tail, flush with the plateau
> grass. Plateau ground within 2 m in front of a lip is not a floor (the
> terrain cell overhangs the wall line). Face rocks sit on 4 m slots and
> outcrops are larger; placement is focused on the computed chunk. See
> docs/qa/2026-09-23-manual/11-rocky-face/result.md. In game: `world.tscn`
> sets `FieldTerrainStreamer.CLIFF_STYLE = "sheet"` (restored to `chosen` on
> exit), and the player spawns at the green massif (review spawn; F4 spot
> C1 returns there). A first visit to any area waits minutes on cold road
> planning, so spawning keeps that wait behind the loading screen. Under `sheet` the crag builders
> return outline formations (recipe, pose, box footprint) and skip surface
> lofts: nine massif chunks give byte-identical slope solids, with formation
> time 4-68 s down to under 0.1 s per chunk
> (`tests/harness/sheet_outline_compare.gd`). Ninth pass (September 25):
> the `sheet` slope is a rounded envelope of the terrain itself
> (`CliffSlopeEnvelope`: exact separable parabolic dilate/erode on a 0.5 m
> world grid, 56 m pad), not per-line slopes, so it cannot stop and drop
> anywhere. Ridges blend two shoulder widths by noise from each point's lip;
> roads, graded ground and water cap it with a steep cut. Covered native
> pieces and skirt quads are hidden; lawn/moss follows steepness and grass
> grows on it (`GrassSupportSurfaces.at_grid`). Follow-up: radii tightened
> (shoulder 1.5-4 m, foot 3 m) so slopes dress cliff sides only and flat
> ground stays flat; rocks are sunk until their whole base is under the
> surface; the character walks up 55 degrees. Rocks are 2-3-rock clusters on
> 7 m slots to line ends and at outer corners; tall relief blends the
> envelope to a tight profile so outer corners (diagonals drop two storeys
> more) reach about as far as their edges. See
> docs/qa/2026-09-23-manual/12-terrain-envelope/result.md.

> September 22 cliff rock review (owner photos, seed 2697992464): four fixes.
> (1) Water fronting a wall becomes its formation's support: waterline banks
> stand WATERLINE_DEPTH (1 m) under the surface, never on the channel bed, and
> lose submerged turf; `_wet_formation` now only rejects rock deeper than that.
> A warren's whole-town clearance rectangle is a `FeatureGroundShape.envelope`
> that terrain rock/vegetation ignore (`overlaps_clearance(...,false)`); real
> lots/paths still apply, and a reservation in front of a wall compresses the
> rock's reach (`_fit_reach`) instead of removing the panel. (2) Formations stop
> at their own terrace edge: `CliffRockCrags.supported_depth` + a smoothed
> per-column `support_scale`; floors ignore ground more than SUPPORT_DROP below
> the base, so no sheer curtain drops from a corner to the next level. (3) Baked
> Nature-rock sections are slope-limited (`_taper_section`) and nearby ledges
> merge by symmetric, order-independent transfer (`_merge_close_ledges`),
> removing sheer tread steps. (4) Convex corners compress their whole foot (arms included) and facet
> thick bodies into 2-3 chords instead of a round pool. Eight tests in
> `tests/test_september22_cliff_rock.gd` pass; the geometric three are red on the
> reconstructed baseline. Review loop: `tests/harness/cliff_site_review.tscn`
> (hot reload). See docs/qa/2026-09-22-manual/01-cliff-rock/result.md.

> September 19 bank traversal: all eight real-player swims through the two
> flagged bends pass, with identical before/after trajectories and no bank
> contacts. A 782-position capsule survey retains 747 clear positions; shallow
> bank-fringe contacts remain. This proves available routes, not every near-bank
> path or final bank art. Production integration and original scope stay open.
> See docs/qa/2026-09-19-manual/130-bank-traversal/result.md.

> September 19 water-query cost: WaterFieldContext reuses its evaluated level
> instead of evaluating wet points twice. All 18,820 mixed-bank results and timed
> arrays match exactly; the isolated median falls from 344.356 to 280.609 ms.
> The existing context/vegetation test passes 1,406 assertions. This is a query
> cost reduction; overall startup and original streaming reports remain open.
> See docs/qa/2026-09-19-manual/131-water-query-cost/result.md.

> September 19 sloping bank study: bounded receiving-corridor checks restore
> one flowing corner, retaining 40 banks and 57 native-supported plants. Five
> admission tests pass. Combined collision distinguishes 290 internal join probes
> from 14 unresolved exterior shallow-water probes; one exact backing-edge ray
> also remains red. Production bank integration and full original scope stay open.
> See docs/qa/2026-09-19-manual/129-bank-corridor/result.md.

> September 19 bank exposure repair: the pass-127 failed fern was occluded by
> a neighboring fitted wall. Canonical dry and fitted surface rays remove only
> that fern; 57 unchanged plants remain. Two tests / five assertions verify
> contact and split-owner identity; native collision verifies all 57 roots.
> Five N04 pairs and the local overlap pair retain identical rock and water.
> This is a study attachment repair; production bank integration stays open.
> See docs/qa/2026-09-19-manual/128-bank-exposure/result.md.

> September 19 shallow-relief study: preserving the first 1.4 m retains
> 63,257 exposed source vertices and improves independent upper-wall shapes.
> Two profile tests / six assertions pass. Fresh admission retains 39 of the
> 41 studied banks; two corners expose separate dry-bank and graded-water
> constraints. One exact native edge ray misses while all eight millimetre
> offsets hit; 57/58 mapped plants contact correctly, with one occlusion failure.
> These red integration gates remain open; no production bank promotion.
> See docs/qa/2026-09-19-manual/127-bank-preserved-relief/result.md.

> September 19 shoreline contact study: narrow compression no longer buries
> originally exposed faces. A red/green contact regression repairs 13,748 lost
> contacts; fresh water admission retains 41 banks and 55 mapped plants. Ten
> focused tests / 48 assertions and all 55 native plant contacts pass. The
> 36-formation native survey retains buried feet and clear sampled channels;
> five formations exceed the saved collision world. Upper repetition and smooth
> lower faces remain, so no production bank promotion or final art acceptance.
> See docs/qa/2026-09-19-manual/126-bank-relief/result.md.

> September 19 bank follow-up: wider compression is rejected; it adds no
> usable grass ledges. The narrow study passes 43,366 native backing probes and
> 5,544 buried-foot samples across 36 formations; five exceed the saved world.
> Independently built neighboring water domains retain identical geometry and
> admission for 28 shared forms (14 banks); seven shore-level metadata values
> differ by at most 3.553e-15 m, so strict record identity is not claimed.
> N04 opaque-water controls and 211 native hits show no sampled rise above
> its 13.7 m lake level. Production bank fitting remains experimental; original
> cliff, water and generation scope stays open. See
> docs/qa/2026-09-19-manual/124-bank-water/result.md and
> docs/qa/2026-09-19-manual/125-bank-domains/result.md.

> September 19 bank attachment study: source fern roots follow the exact fitted
> bank triangles while retaining canonical identities and conservative canopy
> reservations. Five tests / 36 assertions, 66 supported study roots and twenty
> native contacts verify the local mapping; five N04 angle pairs and a close pair
> show attached, ground-tinted plants. No production promotion: shared grass
> support, remaining joined recipes, independent hydraulic domains and swims
> remain open. See docs/qa/2026-09-19-manual/122-bank-attachments/result.md.

> September 19 shoreline study: a narrow, attached rock-bank trial continues
> through N04's visible underwater cliff. Four shape tests / six assertions,
> five native angle pairs, 15,581 backing samples and 2,368 buried feet support
> the local geometry; actual owned replay retains 17 nearby banks with clear
> channel probes. The integration audit exposed two pre-existing collapsed
> ledge-join triangles. Production now removes only exact collapsed triangles;
> eleven regression tests / 97 assertions and an identical native rendered pair
> verify that cleanup. A separate dry-halo control passes. Shoreline fitting
> itself remains experimental: bank vegetation, joined-surface recipes, broader
> water and generation remain open. See
> docs/qa/2026-09-19-manual/121-shoreline-rock/result.md.

> September 19 N03 corner repair: complete one-storey convex corners now receive
> the same closed dressing as their adjoining faces. Short radial shoulders retain
> thin native attachments while avoiding the rejected oversized pedestal; corners
> eight metres and taller keep identical faces, turf and attachment data. Five
> native matched angles, 98 buried foot probes, 15 matching physics contacts and
> the production-owned face payload verify the reported site; 21 tests / 116
> assertions pass. N03/N04 retain all
> 277 sampled native wall rows. Waterside diagnosis finds 20 of 27 formations
> rejected by wet footprints; channel-preserving geometry remains open, as do
> broader cliff art, bank water, path outlines and generation speed. See
> docs/qa/2026-09-19-manual/120-corner-shore/result.md.

> September 19 N02 town follow-up: native earth paths and retained streets now
> share a neutral atlas tint instead of the grass biome multiplier that turned
> them pink. Destination-owned pruning also withdraws an unused level tail past
> the final house entrance, retaining its stairs and adding the normal end guard.
> Sixteen focused tests / 295 assertions, native matched colour/geometry studies,
> 92 local clear positions / 138 crossings, 48/48 towns with 11,708 clear positions
> / 16,819 crossings, and the 95-assertion composition gate pass. The same 25
> conservative off-centre pillar candidates remain. Angular path outlines,
> broader small-town elevation design, water/corner dressing and generation speed
> remain open. See docs/qa/2026-09-19-manual/119-small-town/result.md.

> September 19 passes 117–118 add committed-ground frontier fog and remove a
> cliff commit stall. The boundary is fully opaque, with a smooth inward fade;
> five native GPU controls and three seeded replay angles verify the scoped view.
> Logs now report missing ground dependencies, meshing phases and slow commit parts.
> Sixteen actual cliff formations retain all 32 rendered surface arrays exactly,
> while main-thread mesh preparation/upload falls from 2.796 s to 20.3 ms by moving
> normal construction into detached worker arrays. Twenty-seven distinct focused
> tests / 90 assertions pass across the two passes. Fresh baseline startup was
> 759.255 s; total generation speed, moving-arrival acceptance, town issues,
> missing corner/waterside rock and bank water remain open. See
> docs/qa/2026-09-19-manual/117-loading-frontier/result.md and
> docs/qa/2026-09-19-manual/118-cliff-commit/result.md.

> September 19 pass 115 separates coarse/fine hillside-water errors. Wet
> diagonal grade constraints remove two native route rises; a confluence rise
> remains (0.027 m), so the full downhill gate stays red. Four tests / thirteen
> assertions, exact frozen replay, fresh P10/P21 meshes, unchanged terrain and
> wet/dry probes verify this isolated experiment. Production and original issue
> statuses remain unchanged. See docs/qa/2026-09-19-manual/115-hillside-fill-stages/result.md.

> September 19 pass 114 localizes hillside rises to the shared fill, before
> meshing. An isolated longitudinal-profile trial first loses bank constraints
> and is rejected; restored provenance passes five tests / twenty assertions.
> Final native terrain identities and 882 ground rays stay unchanged, and all
> 247 in-scene route probes retain water. Three mesh rises remain (max 0.141 m);
> the downhill gate stays red. No production promotion or original issue closure.
> See docs/qa/2026-09-19-manual/114-hillside-surface-joins/result.md.

> September 19 pass 113 isolates reach-based water on identical baseline
> terrain. Paired mesh/instance/collision hashes and 441 rays per site verify
> unchanged ground. Both P10/P21 lose the high sheet; all 247 in-scene route
> probes retain water. However, three local downstream surface rises reach
> 0.270 m, and the explicit downhill gate remains red. Production is unchanged;
> this is a controlled experiment, not acceptance. See
> docs/qa/2026-09-19-manual/113-hillside-stable-terrain/result.md.

> September 19 pass 112 completes native reach-network comparisons at P10/P21.
> Three adapter tests / fourteen assertions and 429 bounded routes pass, but
> the candidate changes 204/441 P10 ground samples (up to +40 m) and removes
> much of its adjacent channel. P21 has smaller terrain changes. Corrected
> double-sided water probes pass all 32 centroid controls; earlier one-sided
> zero-water results are invalid. Production water remains unchanged. Pass 113
> isolates routing on the exact original terrain; original issues stay open.
> See docs/qa/2026-09-19-manual/112-hillside-native-reaches/result.md.

> September 19 pass 111 corrects a terminal-lake bypass in the detached
> hillside-routing study. A valid red regression becomes green; three tests /
> twelve assertions pass. All 103 sources across three seeds reach existing
> basins, with identical forward/reverse station hashes over 14,885 stations.
> Large confluence drops, short channel switches, complete native discovery
> and actual terrain/water rendering remain unverified. Production water and
> pass-110 fixtures are unchanged. Original judging issues remain open. See
> docs/qa/2026-09-19-manual/111-hillside-reach-corpus/result.md.

> September 19 pass 110 investigates the hillside-water network without
> changing production water. Seven-source retained-contact diagnostics expose
> source-prefix ownership failures. A detached reach-based study preserves
> newly supplied downstream tails; forward/reverse paths match across 1,326
> stations with no rising beds, and two synthetic tests / 16 assertions pass.
> One route exceeds the old source radius, so shared discovery must change.
> Native geometry, filled water, source jumps and broader bounds remain
> unverified. See docs/qa/2026-09-19-manual/110-hillside-retained-network/result.md.

> September 19 pass 109 clips stair guards against the actual hanging house
> floor and supports newly cut handrail ends on their flight. Fifteen distinct
> tests / 133 assertions, complete collision contacts, six fresh actual stair
> walks and saved-pose native/game views verify P04. All 48 towns and the
> fingerprint gate / 95 assertions pass. Three occluded walk-end images are
> excluded as visual proof. Broader bridge traversal and original issues remain
> open. See docs/qa/2026-09-19-manual/109-rail-wall-joint/result.md.

> September 19 pass 108 clips prefab-adjacent stair guards against measured
> native placement bounds, restoring P15's lower roof-side rails and posts.
> Thirteen tests / 114 assertions, eleven complete physics contacts, six fresh
> actual stair walks, saved-pose visual review and all 48 towns pass; the
> fingerprint gate passes 95 assertions. The corrected complete-collision
> harness retains existing fixed-height floor contacts rather than calling
> them clear. P04's upper rail/house joint and the broader register remain open.
> See docs/qa/2026-09-19-manual/108-rail-roof-context/result.md.

> September 19 pass 107 retires only the replaced incoming world-road corridor,
> removing P02's square projection outside its curved town approach. Fourteen
> tests / 4,929 assertions, fresh production-grass views, both actual walking
> directions and 468 clear capsule samples verify the junction. All 48 towns
> retain 11,772 clear centres / 16,915 crossings; the fingerprint gate passes
> 95 assertions. Twenty-five conservative offset pillar candidates remain.
> Other external approaches and the broader original register remain open.
> See docs/qa/2026-09-19-manual/107-town-road-corner/result.md.

> September 19 pass 106 includes final retained town ground in external-road
> bounds, routing P02 around its raised garden. Nine tests / 409 assertions
> preserve construction, collision and town grade; actual player traversal fails
> both directions before and passes both after. Fresh source views and diagnostic
> route/garden views retain the prior board repair. The square approach corner
> remains open (T06), as do all-town road clearance and the broader register.
> The separate related run retains one obsolete outskirts-null fixture failure.
> See docs/qa/2026-09-19-manual/106-town-path-context/result.md.

> September 19 pass 105 connects the raised cliff run at the taller wall’s
> actual end, removing its upper blade without changing the lower receiver.
> Twenty-nine distinct tests / 186 assertions, 534 native contacts, 250 local
> ground probes, and fresh exact replay / collision coverage of 338,574 triangles
> pass; all 3,981 production foot probes remain buried. Eight grass-enabled detail
> views and three saved-reference views were inspected. Automatic inside-rock
> captures are excluded. Smaller angular shelf crossings and broader art remain
> open; concurrent 459.300 s startup is not performance acceptance. See
> docs/qa/2026-09-19-manual/105-stepped-end-profile/result.md.

> September 19 pass 104 rejects four implicit three-way cliff reconstructions.
> Ragged turf, coarse transitions and the retained upper blade fail art review;
> these remain isolated study fixtures. Production was unchanged at pass 102.
> See docs/qa/2026-09-19-manual/104-three-way-surface/result.md.

> September 19 pass 103 rejects five lower-junction art variants. Actual
> profiles isolate a three-way conflict between a tall wall, its raised-base
> collinear neighbor and the low perpendicular receiver. Pairwise lofts remove
> the upper blade but create strips or unsupported feet; widening the base adds
> another pointed shelf. Production remains exactly pass 102. The lower crossing
> and original register stay open. See
> docs/qa/2026-09-19-manual/103-receiver-crown-transition/result.md.

> September 19 pass 102 joins the short stepped inner corner through actual
> parent profiles and a supported sloping tread. Five pinned gap failures become
> zero; 28 distinct tests / 168 assertions pass. Fresh geometry replays exactly,
> all 327,717 inspected triangles have production collision, and 3,949 feet stay
> buried. All 211 native surface contacts and 130 ground probes pass. Eight fresh
> detail views retain the scoped repair. Lower shelf crossings, overall cliff art
> and the original judging register remain open. Startup is 430.072 s without a
> performance claim. See docs/qa/2026-09-19-manual/102-corner-surface-loft/result.md.

> September 19 pass 101 rejects the complete-run short-corner study. The low
> native three-metre panel belongs to an adjoining twelve-metre run, but combining
> them and extending the taller parent still creates a flat projection. Production
> remains exactly pass 100. The short seam and original register stay open. See
> docs/qa/2026-09-19-manual/101-short-corner-runs/result.md.

> September 19 pass 100 repairs closing triangles that crossed deformed cliff
> end outlines. Eight actual production failures become zero; 22 tests / 133
> assertions pass. Fresh native geometry replays exactly, all 320,237 inspected
> triangles have collision, and 3,917 roots remain buried. All 6,533 sampled
> contacts hit; all 4,387 inspected cap triangles stay inside their outlines.
> Shared-depth studies remain experimental. The short inner seam, lower shelf
> crossings and original judging register remain open. Startup is 429.485 s,
> without a performance claim. See
> docs/qa/2026-09-19-manual/100-corner-edge-profiles/result.md.

> September 19 pass 99: height-aware ends and connected narrow panels fill the
> short turn but expose mismatched closing faces, including a large diagonal slab
> at the neighboring lower corner. Candidate rejected; all five production/replay
> files restored exactly. Candidate checks pass 33 tests / 171 assertions, 4,683
> native contacts and complete 210,508-triangle collision/replay coverage. These
> do not constitute art acceptance. Restored suites pass 8 tests / 83 assertions.
> Short seam and original register remain open. See
> docs/qa/2026-09-19-manual/99-height-transition/result.md.

> September 19 pass 98: the remaining short inner turn omits two native 3 m
> transition panels. Supplying them passes the pinned connectivity test but creates
> a pointed slab; containing-parent and local remesh variants are also rejected.
> No production change is retained. Restored inner suites pass 8 tests / 83
> assertions. A crashed narrow-only capture is excluded. The short seam and original
> judging register remain open. See docs/qa/2026-09-19-manual/98-short-inner-join/result.md.

> September 19 pass 97: existing broad ledges share their height through admitted
> inner joins while preserving footprints, triangle topology, buried roots and flush
> crowns. The photographed 42 cm mismatch becomes less than a micrometre at all
> 34 shared tread probes. Twenty-nine tests / 204 assertions pass; 845 native
> contacts and 728 roots pass. Fresh production reconstructs exactly, retains all
> 110,741 inspected collision triangles and 1,218 buried foot probes. Native views
> confirm the continuous inner ledge. Lower shelf crossings, the short inner seam,
> broader cliff art and the original judging register remain open. Startup is
> 426.832 seconds without a performance claim. See
> docs/qa/2026-09-19-manual/97-inner-ledge-levels/result.md.

> September 19 pass 96: weak emerging shelves no longer interrupt established
> merges, and ordered tread correspondence stops hairlines stealing broad ledges.
> Thirty-two tests / 174 assertions pass. Native checks retain 845 contacts and
> 728 buried roots; fresh production contains all 110,745 inspected collision
> triangles and 1,218 buried foot probes. Matched views remove the reproduced fin
> while preserving the broad corner. Angular shelf intersections, the short inner
> seam, broader cliff art and original judging issues remain open. Startup is
> 427.614 seconds without a performance claim. See
> docs/qa/2026-09-19-manual/96-inner-shelf-tips/result.md.

> September 19 pass 95: curved turf shares connected lighting normals instead
> of per-triangle shading. All 1,142 measured gentle-edge discontinuities become
> zero; five tests / 25 assertions pass, retaining real sharp folds and tread
> geometry. Nine native pairs on pass-94's fresh scene verify the visual change;
> 106 replay meshes preserve all stone buffers and turf geometry/UV/material.
> Pointed inner shelf overlaps and broader cliff/original judging issues remain
> open. See docs/qa/2026-09-19-manual/95-ledge-lighting/result.md.

> September 19 pass 94: backed stepped inner joins continue the actual tall
> and low parents, withdrawing the separate corner only when the upper extension
> has complete existing wall backing. Two inspected joins now use four connected
> parents. Twenty-five distinct tests / 148 assertions are verified across the
> focused run and corrected reservation rerun. Native checks retain 856 contacts
> and 728 buried feet; fresh production has all 110,073 inspected collision
> triangles and 1,218 buried native foot probes. Startup is 425.042 seconds,
> without a performance claim. Pointed shelf ends, turf stripes, the remaining
> short junction, broader cliff art and original issues remain open. See
> docs/qa/2026-09-19-manual/94-stepped-inner-join/result.md.

> September 19 pass 93: fresh production confirms the connected inner walls
> and broad outer turn, but exposed an escaped halo water query. Connections
> now precede ordinary complete-owned-solid water admission; public/grade pair
> checks remain. This supersedes pass 92's production whole-pair wet callback.
> Escaped regression samples fall from 168,646 to zero. Twenty-four tests / 194
> assertions pass. Fresh native rock/turf recipes match exactly; 84,004 inspected
> triangles exist in production collision and 1,000 native foot probes stay buried.
> Startup is 422.643 seconds, without a controlled performance claim. Stepped
> inner intersections, broader cliff art and original judging issues remain open.
> See docs/qa/2026-09-19-manual/93-fresh-corner-review/result.md.

> September 19 pass 92: matching-height inner turns continue both actual wall
> formations instead of adding a third independent shelf family. Complete pair
> admission preserves public/wet/grade exclusions and canonical chunk ownership.
> Twenty-two tests / 184 assertions pass; seven old failed end bearings become
> zero, all 440 native collision contacts hit and 412 ground probes stay buried.
> Native paired views retain the scoped improvement. Unequal-height joins,
> broad/plain composition and generation cost remain open. Shared-depth remesh
> studies are rejected for fins. See
> docs/qa/2026-09-19-manual/92-inner-shared-surface/result.md.

> September 19 pass 91: pure retaining-wall joints use native district-tinted
> stone instead of exposed timber posts; inhabited-room contacts retain timber.
> Frozen P02 changes nine of 313 instances, with unchanged other instances,
> generated surfaces, walked cells and explicit boxes. Thirteen tests / 93
> assertions, 1,080 native collision rays and four matched native pairs pass.
> Surrounding terrain/path issues and broader acceptance remain open. Pass 90's
> inner shelf-union studies are rejected for pinched turf; production cliffs
> remain pass 89. See docs/qa/2026-09-19-manual/91-masonry-joints/result.md and
> docs/qa/2026-09-19-manual/90-inner-union/result.md.

> September 19 pass 89: inner attachment samples the actual native corner and
> adjoining walls continuously along its diagonal sweep. This removes the fixed
> sampler boundary and its false depth jump. Eighteen tests / 126 assertions,
> 4,169 physical contacts and 224 buried ground probes pass. Seven actual native
> wall pieces verify the backing; outer geometry is unchanged. Matched saved-world
> renders retain broad lower bearings, with plain faces and shelf intersections
> still open. No fresh-world or overall art acceptance. See
> docs/qa/2026-09-19-manual/89-inner-attachment/result.md.

> September 19 pass 88: outer rock turns retain physical formation scale instead
> of compressing twelve metres into the bend. Closed inner-corner dressing now
> covers short and tall joins, with native roots and fuller lower bearings.
> Twenty-eight tests / 98 assertions and 4,169 physical contacts pass. A fresh
> world contains four outer and three inner corners, all exactly matching the
> final generator; 224 native ground probes find no exposed feet. Startup is
> 432.075 seconds. Broader/plain cliff composition and original issues remain
> open. Pass 87 corrected a review bug that rebuilt saved corners as straight
> panels; prior pass-84–86 corner replay judgments are superseded. See
> docs/qa/2026-09-18-manual/88-cliff-corner-continuity/result.md and
> docs/qa/2026-09-18-manual/87-cliff-replay-fidelity/result.md.

> September 18 pass 86: embedded Nature-rock fronts rotate independently,
> with a restrained depth increase and closer physical ledge blending. Actual
> photo geometry gains 679 outward samples while retaining every turf vertex
> and the flush crown. Thirty-six tests / 118 assertions pass, with 311 supported
> grass roots and all 317 changed native collision contacts. Five matched game
> views and a tall study retain this scoped change; a stronger variant is rejected
> for busy dark ridges. Tall composition, plain areas and inherited panel ends
> remain open. No new full-world or broad performance acceptance. See
> docs/qa/2026-09-18-manual/86-cliff-oriented-stones/result.md.

> September 18 pass 85: wider/deeper irregular Nature-rock geometry replaces
> smaller face bumps. Ledge protection now uses physical 3D separation instead
> of projecting distant shelves and long supports onto unrelated wall faces.
> The new red-first check goes from 447 falsely flattened samples to zero.
> Thirty-five tests / 113 assertions pass, retaining 31 closed photo shells,
> 460 tread checks, nine corner checks and 311 supported grass roots. All 345
> changed native collision samples hit; one unchanged historical miss remains.
> Five matched game-context pairs and a tall study retain the scoped change;
> broad/tall composition and the original issue register remain open. No new
> full-world startup or traversal claim. See
> docs/qa/2026-09-18-manual/85-cliff-anchored-stones/result.md.

> September 18 pass 84: seven cliff geometry studies are rejected; production
> stays on pass 82. The original P02 T05 bottom-board defect is reproduced red
> and repaired by applying the existing buried-base rule to retained columns,
> not only their top turf cells. Thirty ground-level soffits withdraw; remaining
> instances, public surfaces, walked cells and explicit collision boxes match.
> Four native before/after pairs and 26 tests / 932 assertions pass; elevated
> garden undersides remain. The separate vertical stone-joint substitute is
> rejected for white end faces. Cliff art, vertical joints, full-world terrain/
> path review and the broader original register remain open. See
> docs/qa/2026-09-18-manual/84-cliff-curved-masses/result.md.

> September 18 fresh cliff verification retains pass-82 geometry. Fresh P12
> startup completes in 480.505 s; twelve actual ledge walks and 372 native-ground
> root probes pass. Three original photo-camera captures are rejected as embedded
> in widened rock; five clear context views retain plain/upright/angular art issues.
> Original P02 timber joints and soffits reproduce in a current native town payload;
> source diagnosis is recorded, with no town repair selected. No complete cliff-art,
> original-issue or global performance acceptance. See
> docs/qa/2026-09-18-manual/83-cliff-fresh-world/result.md.

> September 18 physical relief fin repair bounds differences in added depth
> across the connected front mesh, preserving original rock and protected treads.
> The alternate simplified stone-volume study is rejected for pronounced fins.
> Excessive short-edge incidences fall from 1,904 to zero in 191,364 samples;
> existing bump, crown and turf checks remain green. Thirty-four tests / 111
> assertions pass, with 341 supported grass roots and all 33 changed physical
> probes hitting. One known unchanged miss remains among 887 total contacts.
> Final native game and tall views retain broader upright/angular art issues.
> No complete cliff-art, fresh-world or original-issue acceptance. See
> docs/qa/2026-09-18-manual/82-cliff-stone-volumes/result.md.

> September 18 ledge-relief transition repair makes the spatial search cover
> the full 1.6 m blend radius. A truncated search had introduced a 0.6465 m
> relief step across a 0.25 m interval; the same sampled step is now 0.3943 m.
> Thirty-three tests / 109 assertions pass, including turf, corners and grass.
> All fourteen changed physical samples hit; one known baseline miss remains
> among 887 total probes. Final native game and tall views retain broader angular
> and upright composition issues. No full cliff-art, fresh-world or original-issue
> acceptance. See docs/qa/2026-09-18-manual/81-cliff-relief-transitions/result.md.

> September 18 upper cliff relief adds restrained physical variation below the
> crown by real distance, avoiding a blank upper quarter on tall walls. The upper
> 1.3 m remains unchanged; a full-strength study is rejected as too busy. Thirty-two
> distinct tests / 107 assertions pass across the integration run and targeted
> rerun after correcting the obsolete whole-upper-quarter invariant. All 64 changed
> collision samples hit; one known baseline miss remains among 887 total probes.
> Turf retains 57/57 cap samples, 460 treads and 341 supported grass roots.
> Frozen native game views and a tall study retain upright/angular art issues;
> no complete cliff, fresh-world, performance or original-issue acceptance.
> See docs/qa/2026-09-18-manual/80-cliff-upper-relief/result.md.

> September 18 exposed face variation keeps localized Nature-derived bumps at
> useful sizes on tall walls and shares their depth budget with larger shoulders.
> Broad tread transitions retain full turf without shelf-adjacent lips. Thirty-one
> focused/integration tests / 101 assertions and 347 grass roots pass; all 266
> changed-face collision samples hit. One of 887 total probes retains its known
> baseline miss. Seventeen frozen-world views and a tall study record the change.
> Tall upper smoothness and overall cliff composition remain open; no fresh-world,
> traversal or performance acceptance. See
> docs/qa/2026-09-18-manual/79-cliff-formation-ledges/result.md.

> September 18 source-profile and carved-body studies remain rejected. Stronger
> physical bumps retain smooth supports; a carved alternative gains forms but
> creates undercuts. A monotone support correction passes nine geometry tests
> yet erases 42% / 66% of short/tall ledge area and restores upright columns.
> Two new area regressions reproduce that loss and pass on unchanged pass-77
> production. No new art, traversal, performance or original-issue acceptance.
> See docs/qa/2026-09-18-manual/78-cliff-angular-bumps/result.md.

> September 18 physical face variation samples varied Nature-rock body profiles
> into the completed closed cliff shell. Actual bumps share render/collision
> vertices; finished turf, tread supports, crown and roots remain protected.
> Twenty-eight tests / 92 assertions and 347 worker grass roots pass. All 201
> changed-face physics samples hit; one of 887 total contacts misses identically
> on baseline. Seventeen frozen-world captures and a tall study record the change.
> Broad smooth faces and upright composition remain open; no complete cliff-art,
> fresh-world traversal or performance acceptance. See
> docs/qa/2026-09-18-manual/77-cliff-shape-envelope/result.md.

> September 18 connected rock bumps add sparse asymmetric compound shoulders
> to actual cliff vertices and collision. Variable width, depth, lean and height
> break up lower faces; the upper quarter retains its existing attachment.
> Final foot sampling includes the extra depth. Twenty-four tests / 78 assertions,
> 385 supported grass patches and 334 native physics contacts pass. Seventeen
> frozen game views and a tall study verify the scoped change. Broad smooth faces,
> inherited uprights and thin ledges remain under art review; no fresh-world,
> global performance or complete cliff-art acceptance is claimed. See
> docs/qa/2026-09-18-manual/76-cliff-connected-relief/result.md.

> September 18 tread projection repair rescales a curved ledge's drop when
> final body shaping shortens its width. Actual physical endpoints improve from
> 181 steepened caps to zero across 461 samples. Twenty-three tests / 72 assertions,
> 332 supported grass patches and 333 Godot physical contacts pass. Native frozen
> game views and matched tall/overhead studies preserve the scoped correction;
> plain upper faces and upright smooth supports remain. Larger formation studies
> are rejected; no full cliff-art, fresh-world traversal or performance acceptance.
> See docs/qa/2026-09-18-manual/74-cliff-formation-sampling/result.md.

> September 18 physical outcrop revision adds deterministic Nature-rock shapes
> to the closed cliff mesh and its actual collision. Local overlapping shoulders
> widen toward the base; added projection obeys the rooted crown-to-foot envelope.
> No material or crack-network change. Thirty tests / 95 assertions, 345 supported
> grass patches, twelve fresh-world walks and 370 native foot probes pass. Seventeen
> frozen game views, a tall study and fresh P12 show stronger lower formations;
> smooth upper faces and upright composition remain open. An upper-projection
> candidate is rejected before final generation. Startup is 480.953 s without a
> performance claim. See docs/qa/2026-09-18-manual/69-cliff-weathered-shapes/result.md.

> September 18 no-crags revision follows the owner's explicit direction change:
> remove narrow geological joints and chipped-cell relief; retain broad continuous
> shape variation, with modestly increased shoulder-width and lateral variation.
> Twenty-five distinct focused/integration tests / 76 assertions, 410 supported
> grass patches, twelve fresh-world character walks and 368 native foot contacts
> pass. The basal test isolates actual basal growth from filling deleted crack
> valleys; an over-tall basal control reproduces its failure. Fresh P12 loads in
> 499.007 s, without a performance claim. Tall upright forms and angular lower
> turf boundaries remain open. Pass-64 body studies stay unselected; pass 65 only
> removes unused computation with 68 identical geometry comparisons. See
> docs/qa/2026-09-18-manual/66-cliff-no-crags/result.md.

> September 18 shelf/profile studies: no production change. Explicit ownership
> of adjoining shallow shoulders closes 57/57 turf probes, but native faces stay
> plain; boundary filtering opens three mesh edges and is rejected. Curving the
> full-height projection more strongly removes upper ledges. A gentler curve
> passes the existing nine-test gate but moves the upper quarter inward by only
> 0.008931 m on average and makes the tall face flatter; it is also rejected.
> Production remains pass 60. See
> docs/qa/2026-09-18-manual/62-cliff-shelf-boundary/result.md and
> docs/qa/2026-09-18-manual/63-cliff-curved-descent/result.md.

> September 18 projection investigation: no new production change. Global
> depth blending shrinks shelves; broadened support and finite Nature bodies
> retain poor composition. Carved/inset shelves reduce outline repetition and
> retain 42.5 m spans, but their turf classification regresses. A connected-turf
> repair passes nine tests / seventeen assertions yet creates jagged native
> grass patches and is rejected. Production stays pass 60. The cap diagnostic
> identifies shallow adjoining riser triangles; final tread grade must also
> account for depth compression. No fresh-world or traversal acceptance. See
> docs/qa/2026-09-18-manual/61-cliff-projection-blend/result.md.

> September 18 attachment relief: larger geological divisions retain their
> layout while the thin covering skin halves its displacement and recesses its
> base by 7 cm. Upper envelope excess falls from 0.231739 to 0.068267 m;
> long ledges retain 6.25–40.25 m spans. Twenty-three production tests / 71
> assertions pass, with 416 supported grass patches. Fresh P12 with grass,
> twelve actual-player ledge walks and 368 rooted-foot probes pass. Rejected
> lateral-support, layered-body and detail-fade variants remain separate.
> Startup is 425.430 s, without a performance claim. Tall upright organization,
> broad plain faces and the original judging register remain open. See
> docs/qa/2026-09-18-manual/60-cliff-local-bearing/result.md.

> September 18 riser triangulation: local curvature chooses the diagonal of
> regular rock-face quads, removing three avoidable hard creases in 41,022
> photographed quads. Production keeps the pass-55 sampled shape, all turf
> triangles and triangle count. Twenty-two tests / 69 assertions plus one
> preservation test / three assertions pass; 407 grass roots and 40.75 m ledges
> remain. Native game, tall and matched corner views retain the composition.
> Strong-body and finer-sampling trials remain rejected. Overall cliff art and
> the original register stay open. See
> docs/qa/2026-09-18-manual/59-cliff-tread-correspondence/result.md.

> September 18 layered-body study: staggered Nature bodies and released lower
> relief retain upright composition. Stronger relief introduces folds and reduces
> the longest upper shelf to 17.75 m. A new lip-bearing guard reproduces 44 abrupt
> prototype recessions and verifies their experimental repair; unchanged production
> passes one test / two assertions. Twenty-five tall, eighty-five frozen game and
> seven lighting controls are retained. No candidate is promoted; production stays
> pass 55, and overall cliff art remains open. See
> docs/qa/2026-09-18-manual/58-cliff-layered-bodies/result.md.

> September 18 support-volume investigation: independent body/support removals
> retain fluting. A shared-bearing union passes its proposed red test but loses
> the reported cap and upper ledges. Whole-column bending retains closed shells
> while exposing attachment artifacts and bent-column composition; fixed-x
> diagnostics are not valid for it. Continuous shallow relief passes five tests /
> ten assertions but leaves broad blank faces. Thirty-two tall and thirty-four
> frozen game captures support rejection. Nothing is promoted; production stays
> pass 55 and overall cliff art remains open. See
> docs/qa/2026-09-18-manual/57-cliff-support-volumes/result.md.

> September 18 exterior-relief follow-up: post-envelope shallow relief produces
> jagged creases and is rejected. Shape-preserving supports retain 42.5 m ledges
> and the upper envelope, but six cap probes lose turf and tall faces still flute.
> Connected-shoulder turf passes six tests / twelve assertions but looks ragged;
> contour subdivision softens it while failing shell closure. The initial plane-fit
> diagnostic is invalidated by its changing sample selection. Native frozen and
> tall comparisons are retained; nothing is promoted. Production remains pass 55.
> See docs/qa/2026-09-18-manual/56-cliff-face-relief/result.md.

> September 18 local lower-rock revision: production retains the larger shallow
> divisions and restrained upper profile, adding locally wider rooted Nature
> shoulders. Of 356 foot samples, 228 widen and 102 stay unchanged; maximum added
> reach is 3.008 m. Close ledge channels and quantized corner-tip degeneracy are
> repaired. Twenty production tests / 65 assertions pass, with 407 supported grass
> roots (450 in the preceding control). Fresh P12 geometry, twelve actual ledge
> walks and 368 native-ground root probes pass. The fresh capture omitted grass;
> startup is 419.473 s without a performance claim. Broad plain faces and overall
> cliff art remain open, as does the original issue register. See
> docs/qa/2026-09-18-manual/55-cliff-basal-rocks/result.md.

> September 18 lateral shelf-bearing study: supports fan toward the base;
> a prototype ledge discontinuity drops from 1.599431 to 0.000565 m. The final
> outline metric improves to 0.462818, with long treads and upper-profile checks
> retained. Intermediate integration passes eighteen tests / 96 assertions.
> Native views still have upright faces and a flattened foot; ordinary-height
> yellow cliffs barely change. The combined bounded-boulder variant also fails
> art judgment. Nothing is promoted; production stays pass 51. See
> docs/qa/2026-09-18-manual/54-cliff-fanning-feet/result.md.

> September 18 follow-up investigations: bounded Nature boulder height passes
> four tests / thirteen assertions but worsens the tall outline and is rejected.
> The existing source-head water-order experiment is also unpromoted: native P21
> comparison changes the actor's ground from 20 to 32 m, while two prior river
> joins disappear. Five lit diagnostic pairs use fresh saved native worlds;
> initial black-water optical captures are excluded. Production cliffs remain
> pass 51 and production water is unchanged. See
> docs/qa/2026-09-18-manual/52-cliff-root-scale/result.md and
> docs/qa/2026-09-18-manual/53-hillside-native/result.md.

> September 18 larger-section cliff revision: production now uses larger shallow
> shape-linked stone divisions and a root-derived full-height projection envelope.
> The old collar’s silhouette excess falls from 2.687962 m to zero; independent
> faces no longer borrow native tile normals (49.304554 to 0.001237 degrees).
> Sparse major curved shelves retain 4.75–40.75 m connected upper spans, and the
> outline correlation gate passes at 0.527707. Random fine wear and the independent
> shader crease overlay are removed; native/added stone keep a common grey palette.
> Nineteen production tests / 42 assertions pass after correcting a test default;
> fourteen integration tests / 89 assertions retain 450 supported grass patches,
> closed corners and halo ownership. Two tall tests / six assertions and one native
> GPU test / twelve assertions pass. Fresh P12 startup is 428.045 s; three final
> material replays of that new world retain the exact saved cameras. A wrong camera
> root in the first capture is corrected without regenerating the saved world.
> Some tall elongated faces remain; overall art, traversal and the original issue
> register are not complete. See docs/qa/2026-09-18-manual/51-cliff-native-blend/result.md.

> September 18 crown and shelf follow-up: production now includes only the
> scoped upper-metre native attachment repair (face excess 2.692877 to 0.035050 m;
> convex excess 1.191476 to 0.025561 m). Twenty-six distinct focused tests / 118
> assertions pass across corrected runs, with 17 frozen pairs and three fresh P12
> views; fresh startup is 437.945 s, not a performance improvement. The owner
> confirms the top correction but rejects the rapid widening below its collar.
> Small randomly patched crags are now rejected; pursue larger, shallower details
> tied to actual rock joins and shelf risers. Long-shelf/full-height studies reach
> 37.25 m connected upper ledges and pass 11 tests / 25 assertions, but native tall
> views expose repeated backing and plain upright faces; no such study is promoted.
> See docs/qa/2026-09-18-manual/49-cliff-crown-collar/result.md and
> docs/qa/2026-09-18-manual/50-cliff-long-shelves/result.md. Overall cliff composition
> and the original judging register remain open.

> September 18 recovered cliff studies: owner-selected yellow-world pass 34 and
> tall rooted-joints pass 45 references are identified by exact image hashes.
> The combined experiment localizes smaller geometric fractures and adds sparse
> long curved shelves (2.5–41.75 m measured connected upper spans). A short-wall
> crown collar repair reduces upper-metre excess from 2.695677 to 0.035050 m.
> Eight of nine final geometry tests pass (17/18 assertions); the unchanged
> large-outline repetition check still fails. Two tall support tests / six
> assertions pass. Native views retain upright forms and serrated crack edges;
> wider normal smoothing adds seams and is rejected. No production promotion:
> production remains the exact recovered pass-34 source. See
> docs/qa/2026-09-18-manual/47-cliff-recovered-composition/result.md.

> September 18 widening-support study: a hard crown eligibility cutoff in the
> pass-44 prototype caused a 1.877900 m interior depth jump. A red-first actual-mesh
> regression verifies the continuous repair (0.076100 m in the final study).
> Curved shoulder centres, broader descending roots and three geometry-linked
> joint controls each retain nine tests / seventeen assertions. Native game views
> still show plain faces and thin shelves, so none is promoted. Production remains
> exactly pre-trial pass 34; overall cliff art and the broader issue register stay
> open. See docs/qa/2026-09-18-manual/45-cliff-widening-shoulders/result.md.

> September 18 cliff art review: the owner rejects the earlier tall columns and
> independent scratches. Connected-stone studies and no/subtle/strong small-relief
> controls remain experimental. Narrower sampling and a quieter near-cap zone
> restore 57/57 turf contacts; the final upper-join study passes nine geometry
> tests / seventeen assertions, but ordinary-height game views still look too
> slab-like. No art promotion; production remains exactly pre-trial pass 34.
> See docs/qa/2026-09-17-manual/43-cliff-connected-stone/result.md and
> docs/qa/2026-09-18-manual/44-cliff-scale-study/result.md.
>
> The pass-41 grass uncertainty is resolved separately: sixteen paired grass
> placement seeds on fixed geometry yield 176 old / 170 groove roots, all fully
> supported. The expanded four-test grass gate passes on each; precise groove
> corners pass nine tests / 37 assertions. This does not adopt the owner-rejected
> grooves. See docs/qa/2026-09-17-manual/42-cliff-groove-grass/result.md.

> September 17 groove integration review: the preferred sparse-groove study
> remains experimental. A provisional integration passes 36/38 tests but loses
> grass coverage (five roots versus eight) and collapses two tall-corner triangles.
> A fixture-only precision repair fixes the corner; the grass regression remains.
> All three production files are restored exactly to pre-trial pass 34. Four more
> large-form trials are rejected for columnar composition or unsupported undercuts.
> Seventeen groove and 83 shape-study native views are retained. Overall cliff art
> remains open. See docs/qa/2026-09-17-manual/41-cliff-selected-grooves/result.md and
> docs/qa/2026-09-17-manual/40-cliff-rooted-fans/result.md.

> September 17 groove sampling follow-up: a quieter narrow-groove study uses
> half the dense study's lateral sampling, retaining the judged detail direction.
> Seven focused tests / fourteen assertions pass; 22 native context/studio views
> are retained. Three photo formations use 90,356 triangles versus dense 179,580
> and production 48,252, so there is no performance acceptance. A separate broad
> upper-terrace study passes 22 tests / 120 assertions but remains too columnar
> visually; neither study is promoted. Production remains pass 34 and overall
> cliff art stays open. See docs/qa/2026-09-17-manual/39-cliff-groove-sampling/result.md
> and docs/qa/2026-09-17-manual/38-cliff-terrace-composition/result.md.

> September 17 small-crag comparison: the owner rejects pass 34 detail as
> wrinkled fabric. Clean surfaces, extra grounded outcrops and narrow deeper
> grooves now have matched native game/studio studies. Shorter grooves are the
> preferred detail direction, but none is promoted: broad faces and tall vertical
> composition remain unresolved. Each alternative passes six focused tests /
> twelve assertions; the refined groove also passes the duplicate-fracture
> erosion regression. Production remains unchanged, not artistically accepted.
> The separate tall-terrace investigation retains red production checks. See
> docs/qa/2026-09-17-manual/37-cliff-detail-options/result.md and
> docs/qa/2026-09-17-manual/36-cliff-local-terraces/result.md.

> September 17 tall composition review: separate height, reach and wider-terrace
> studies remain unselected. Wider tall shelves erase quieter intervals (three
> small-crag columns versus eight required), and the native oblique view becomes
> large upright slabs. Production retains pass 34. Its shared warm/cool gray colour
> passes a fresh native GPU run / twelve assertions; seventeen current replay
> captures retain the material and pointed turf. No fresh-world or overall art
> acceptance. See docs/qa/2026-09-17-manual/35-cliff-height-composition/result.md
> and docs/qa/2026-09-17-manual/29-cliff-stone-colour/result.md.

> September 17 patchy rock detail: oblique chipped planes occupy irregular parts
> of the physical cliff skin, with quiet weathering between them. Full-coverage
> planes are rejected for a cobbled tall-wall pattern. Thirty-eight tests / 192
> assertions pass, including 57/57 reported turf contacts and eight supported
> worker grass roots. Per-formation seed caching preserves exact geometry on
> 31 photo and two tall controls. Native views retain open vertical-composition
> concerns; local three-formation generation costs about 15% more, with no global
> performance or art acceptance. See
> docs/qa/2026-09-17-manual/34-cliff-oblique-relief/result.md.

> September 17 hybrid cliff relief: wider Nature-derived lower profiles combine
> with retained curved terraces and restored tall upper coverage. Twelve authored
> profiles widen toward their feet; closure, rooting and eleven worker grass roots
> pass. The combined run passes 36/37 tests; its stale triangle-width measurement
> also fails on baseline, and the corrected physical-width/ribbon controls pass
> two tests / six assertions. Three fresh P20 views retain pointed turf and shared
> stone colour; soft upright faces and repeated backing remain open. Startup is
> 421.852 seconds under concurrent work, not a performance comparison. See
> docs/qa/2026-09-17-manual/33-cliff-hybrid-relief/result.md.

> September 17 neutral rock-profile joins: the smooth-union radius now vanishes
> with an incoming zero-depth profile, removing a reproduced 0.113713 m raised
> edge. Empty profiles are neutral; deep overlaps retain their original blend.
> Eighteen geometry tests / 54 assertions and eight support tests / 53 assertions
> pass, with thirteen fully supported grass roots. Native saved/alternate views
> preserve ledges and turf. Two authored-shoulder art studies are rejected; broad
> cliff composition remains open. See
> docs/qa/2026-09-17-manual/32-cliff-authored-shoulders/result.md.

> September 17 authored-foot study: widening Nature-derived lower profiles alone
> loses photographed corner coverage, tall-wall relief and distinct projections.
> The taller follow-up also misses continuity. Neither is selected; production
> retains pass 30 geometry and shared gray variation. P05 turf verification now
> follows actual tread bounds: historical 30/57 versus retained 57/57 contacts.
> Fourteen geometry tests / 45 assertions and one native GPU colour test / twelve
> assertions pass. Broad cliff art remains open. See
> docs/qa/2026-09-17-manual/31-cliff-fan-bearing/result.md.

> September 17 upper shelf grades: generic finite ledges now share the existing
> resting/sloped curved tread family. Inclined upper turf rises from 23.88% to
> 59.42%; broader body/depth experiments are rejected. The initial run passes
> 50/51 tests; a half-mesh-step prominence sampling correction retains the same
> thresholds and passes its two-test follow-up. Fresh P12 and native tall/context
> views retain supported terrain but coarse faces and repeated backing remain.
> Fresh startup is 487.436 s under concurrent work, not a performance comparison.
> Shared stone colour is unchanged. See docs/qa/2026-09-17-manual/30-cliff-broad-shoulders/result.md.

> September 17 ledge channels and stone colour: active-height cap matching and
> merged nearby cuts remove the reported P05 notch; connected turf follows broad
> treads through their pointed ends. All 31 photo shells are closed and nondegenerate,
> all nine notch probes have turf, and seventeen worker grass roots remain supported.
> Shared world-space warm/cool gray variation retains matching native/outcrop join
> colours. Fifty focused tests / 1,988 assertions and one native GPU test / twelve
> assertions pass. Native alternate views verify these scoped changes; vertical
> organization, backing repetition and overall cliff art remain open. No fresh-world,
> traversal or performance acceptance. See docs/qa/2026-09-17-manual/28-cliff-ledge-channels/result.md
> and docs/qa/2026-09-17-manual/29-cliff-stone-colour/result.md.

> September 17 curved tread follow-up: selected broad shelves now have stronger
> grades and concave/convex depth profiles, retaining lower bearing and crown
> retreat. Support-only finer grass sampling yields twelve safe roots; ordinary
> ground buffers stay identical. A spatial index preserves exact queries and
> removes the measured support-sampling cost increase. The main 63-test / 1,062-
> assertion run and post-index 30-test / 365-assertion run pass. Physical tread
> width checks account for subdivision without relaxing thresholds. Inspected
> native context, tall and grass views retain open backing repetition and overall
> cliff art. No fresh-world or global performance acceptance. See
> docs/qa/2026-09-17-manual/26-cliff-curved-treads/result.md.

> September 17 continuous rock feet: complete widened-foot admission removes
> upper-radius cutoffs; a fixed per-mass seed removes tilted-crest noise jumps.
> The 76,599-sample maximum 2 cm depth jump falls from 0.609898 to 0.074629 m.
> Grass borders now prove whole-component plane fit, repairing a false internal
> edge without accepting accumulated curvature. Thirty-six tests / 610 assertions
> pass; seven grass roots retain full support. Native game/tall views retain open
> vertical organization and overall cliff art. Two curved-tread retries still lose
> planting and are rejected. No fresh-world or performance acceptance. See
> docs/qa/2026-09-17-manual/24-cliff-mass-support/result.md and
> docs/qa/2026-09-17-manual/25-cliff-curved-support/result.md.

> September 17 curvature investigations: depthwise curved treads pass their
> geometry probe but lose supported grass, including variants that preserve
> the original inner triangle planes. Bent inherited relief breaks numerical
> repetition but still renders as softened vertical sections. Both are rejected;
> production remains the inclined broad terraces. The hillside terminal control
> is already wet/descending without its experimental added connector, which
> raises the filled surface unnecessarily and is not selected. See
> docs/qa/2026-09-17-manual/22-cliff-tread-curvature/result.md,
> docs/qa/2026-09-17-manual/23-cliff-relief-curves/result.md and
> docs/qa/2026-09-17-manual/10-hillside-order/result.md.

> September 17 inclined broad terraces: selected wider Nature-profile treads
> gain shallow depthwise grades while their paths retain along-wall curves.
> Inclining every shelf lost an independent projection and was rejected; broad
> terraces retain the original seven prominence samples. Thirty-two focused
> tests / 594 assertions pass, including closed collision and six fully rooted
> grass patches. Four selected game views and two tall controls were inspected.
> Angular endpoints, native backing repetition and overall cliff art remain open.
> No fresh-world, traversal or performance acceptance. See
> docs/qa/2026-09-17-manual/20-cliff-shelf-edges/result.md.

> September 17 curved cliff ledges: rounded asymmetric mass sections replace
> box-like fronts; finite shelf paths slope and bend along the wall. Whole Nature
> rock profiles retain lower bearing, while the crown retreats under native turf.
> Low curves remain above the closed floor. Tall upper-corner coverage retains
> independent relief. Forty-five focused tests / 674 assertions pass across scoped
> runs; production matches all 31 rendered short photo formations. Seven matched
> game views and three final tall controls were inspected. Depthwise tread slopes
> were rejected for losing grass support. Native backing repetition, some angular
> endpoints, sparse grass on curved caps and broader cliff art remain open. No
> fresh-world, hydraulic, streaming or overall art acceptance is claimed. See
> docs/qa/2026-09-17-manual/19-cliff-shelves-rocks/result.md.

> September 17 quieter cliff faces: sparse shallow cuts replace the rejected
> dense gouges; fine shader relief is restrained. Baked CC0 Nature Pack horizontal
> profiles add finite lower terraces to the same closed skin. Removing the old
> aggregate shoulder clamp restores shelf depth; the final projection bound stays.
> Half-metre tread eligibility removes narrow turf streaks. The focused 45-test /
> 1,163-assertion set passes across the main run and historical-art-control rerun;
> 17 frozen game views and five tall controls were judged. Deep-cleft/exact-old-cap
> pins are explicitly archival after owner rejection. Native repetition, soft
> faces and overall art remain open; no fresh-world, traversal, streaming or
> hydraulic acceptance. See docs/qa/2026-09-17-manual/18-cliff-terraced-base/result.md.

> September 17 shoulder-detail repair: crag exposure includes ledge support,
> while a short cap transition preserves the original usable shelves. The first
> exposure correction failed broad-turf-area coverage and was rejected. Nine
> actual face pins now retain their clefts; three cap arrays remain identical.
> Forty-four tests / 1,063 assertions and 22 judged final context/tall views verify
> the scoped repair. Broad soft faces, angular cuts and overall art remain open;
> no fresh-world, traversal or performance acceptance. See
> docs/qa/2026-09-17-manual/16-cliff-shoulder-union/result.md.

> September 17 cut-depth repair: deep erosion retains the native attachment
> through a smooth depth budget, repairing five reproduced cut-through samples.
> Forty-two tests / 1,042 assertions pass. Seventeen selected frozen views, four
> close before/after views, and three fresh P20 views were judged. Broader plane,
> erosion and shading studies were rejected; soft faces and overall art remain
> open. Fresh startup is 421.173 s under concurrent work; the snapshot parameter
> introspection diagnostic remains. No traversal or performance acceptance. See
> docs/qa/2026-09-17-manual/15-cliff-planes/result.md.

> September 17 close-face investigation: six isolated scar, weathering, bevel,
> facet and native-blend studies were rejected in matched photo views. A pocket
> count already passes baseline; a narrower shading cutoff passes its diagnostic
> but exposes angular patches. Both probes remain experimental fixtures, not new
> production gates. Production geometry/material stay at the prior selected
> version. Broad face structure needs further work. See
> docs/qa/2026-09-17-manual/14-cliff-spalls/result.md.

> September 17 tall cliff composition: occasional larger upper formations and
> scattered fracture heights replace uniform tall courses. Regional depth variation
> retains smaller crags; the change blends in above 16 m, preserving short geometry.
> Over-enlarged and short-wall-smoothing candidates were rejected. Forty distinct
> tests / 1,008 assertions pass across focused and corrected targeted runs; a live
> historical dependency is now frozen. Thirty final views were judged, including
> 32/64 m constructions and short amber/highland replays. Broad soft faces and
> native repetition remain open; no overall art, fresh-world, traversal or performance
> acceptance. See docs/qa/2026-09-17-manual/13-cliff-scale/result.md.

> September 17 local cliff follow-up: physical root easing removes the full-slope
> crossing hidden by normal blending. Short oblique cuts, another finite lower
> ledge family and fuller lower corner shoulders add localized relief. A sharper
> normal variant was rejected for triangular artifacts; reduced bumps and narrowed
> foot eligibility were also withdrawn. Thirty-seven tests / 981 assertions pass,
> with seventeen matched frozen views, five tall native controls and three fresh
> P12 views judged. Cold startup is 426.087 s under concurrent work. Broad soft
> faces and tall mass regularity remain open; no overall art, traversal or global
> performance acceptance. See docs/qa/2026-09-17-manual/12-cliff-local-crags/result.md.

> September 17 geometric crags: deeper finite horizontal clefts and vertical
> splits break broad stone faces without enlarging the masses. Stronger bump
> noise was rejected as swollen. Thirty-six tests / 892 assertions retain native
> joins, upper coverage, wider feet, closed collision, turf and crevice support.
> Seventeen native replays, five tall construction views and three fresh P17
> production views are judged. Cold startup is 418.338 s under concurrent work;
> broad soft faces, native repetition and overall art remain open. See
> docs/qa/2026-09-17-manual/11-cliff-body-crags/result.md. The separate W01 ordering
> experiments remain fixtures: stable confluence prefixes still leave a 12.2835 m
> incoming/receiver hydraulic gap. See 10-hillside-order/result.md beside it.

> September 17 cliff turf cleanup: actual ledge depth excludes vanishing green
> strips; connected-area filtering removes isolated paint dashes while preserving
> open owner-cut continuations. Thirty-one photo formations retain identical stone
> vertices, zero thin turf triangles and 96.18% of broad ledge area. Eighteen tests /
> 801 assertions pass, with seventeen native replay views. The width-only candidate
> was rejected for residual dashes. Full-height joins and wider lower shoulders
> remain; broad soft faces and overall cliff art are still open. See
> docs/qa/2026-09-17-manual/09-cliff-turf-width/result.md.

> September 17 convex corner integration: actual native corner samples blend thin
> attachments into independently varying crags around exposed outer columns. A
> longer source composition breaks ring-like ledges; broader lower shoulders and
> restored upper body depth follow the available native height. Closed triangles,
> four rooted orientations, native normals, worker determinism, complete wet/public
> exclusions and chunk ownership pass nine tests / 37 assertions. Seventeen final
> frozen context views and five fresh 64 m construction views were captured. The
> shallow tall-body candidate and misoriented first studio arm are rejected.
> Overall cliff art, fresh photo-site traversal and performance remain open. See
> docs/qa/2026-09-17-manual/08-cliff-corner-joints/result.md.

> September 17 cliff material: sparse vertically elongated fracture patches replace
> soft mottling alone, fading out through the existing native-root weight. Exact
> nearest dividing-plane distances remove dotted normal spikes; closed-cell and
> directional-weighted candidates were rejected. Fifteen focused tests / 110
> assertions pass, including nine native GPU location/orientation controls and
> unchanged attachment normals. Seventeen final context views and five fresh
> 64 m study views were captured. Local uncapped frame means add 2–3 ms; no global
> performance acceptance. Geometry remains byte-identical to the connected-normal
> correction. Convex wraps were rejected for cylindrical ledge stacking; broad
> forms, corner joins and overall cliff art remain open. See
> docs/qa/2026-09-17-manual/07-cliff-weathering/result.md and 06-cliff-corners/result.md.

> September 17 connected cliff normals: shared-edge smooth fans replace per-face
> incident weighting, removing 162 unintended normal discontinuities on the first
> photographed formation. Three nearby thick-face controls also have zero; sharp
> folds and native thin-root blending remain. Eleven focused tests / 31 assertions
> pass, with 17 frozen context and five fresh tall native views. Geometry, turf and
> collision stay unchanged. Two further cut studies are rejected; broad soft forms
> and native corner repetition remain. No full art/traversal/performance acceptance.
> See docs/qa/2026-09-17-manual/05-cliff-normal-fans/result.md.

> September 17 crevice canopy spacing: actual transformed canopy overlap and stable
> canonical-halo priority remove 24 heavily overlapping pairs from the photographed
> 31 formations (186 to 165 plants). Surviving roots, poses, sizes and grass tint
> remain. Eleven distinct focused tests / 50 assertions pass, including independent
> chunk halos; 17 frozen native context views were captured. Native-wall foliage is
> a separate unchanged pass. Uneven coverage and broad soft stone remain; no global
> art, fresh traversal or performance acceptance. See
> docs/qa/2026-09-17-manual/03-cliff-plant-spacing/result.md.

> September 17 cliff triangulation: shared physical height samples and elevation-
> ordered neighboring connections remove the tall study's diagonal mesh hatching.
> Lighting/bump/SSAO controls rejected a lighting cause. Exact ledge boundaries and
> closed physical topology remain. Twenty-eight distinct focused tests / 1,317
> assertions pass; five fresh tall study views and 17 frozen context views were
> captured. Native corner repetition, broad soft faces and uneven close planting
> remain; no full art, traversal or performance acceptance. See
> docs/qa/2026-09-17-manual/01-cliff-lighting/result.md.

> September 17 crag attachment follow-up: physical-scale fractures vary in span,
> slope and horizontal position; independent cuts fade out at thin native-wall
> roots. The native depth/normal blend, full-height relief and varied wider feet
> remain. Tightened mass bevels were rejected as flat panels. Twenty-six focused
> tests / 1,315 assertions pass; 17 frozen context views and five fresh 64 m study
> views were captured. Corner repetition, soft faces, close fern overlap and tall
> study hatching remain; no gold-standard art, fresh traversal or performance
> acceptance. See docs/qa/2026-09-16-manual/18-cliff-crags/result.md.

> September 17 cliff shading follow-up: neighboring-face normal averaging retains
> carved fractures while preserving rounded faces and the native thin-attachment
> blend. Direct per-triangle sharpening was rejected in native renders. Fourteen
> distinct focused tests / 59 assertions pass; 17 matched frozen camera pairs were
> captured. Native corner repetition, soft broad faces and close fern overlap remain;
> no gold-standard art, fresh traversal or performance acceptance is claimed. See
> docs/qa/2026-09-16-manual/16-cliff-fracture-shading/result.md.

> September 17 bridge/post follow-up: complete enclosed shell footprints reject
> overlapping neighboring bridges. Two obstructed side spans withdraw in P04;
> original gallery alignment stays and the vacated lane regains its end guard.
> A paired-gallery candidate was rejected for poor native facade joins. Clipped
> stair posts now require contact with an exposed rail, removing P15's orphan
> cap and two other fragments. Native/game pairs, focused guard tests and a
> native GPU material test pass. The final 48-town sweep seals 48/48 with 11,772
> clear centres / 16,915 crossings; the fingerprint gate passes 95 assertions.
> Twenty-five conservative offset pillar candidates remain. Longer bridge casts
> retain baseline endpoint contacts; full traversal and other T08 junctions stay
> open. No fresh streaming/full-suite acceptance. See
> docs/qa/2026-09-16-manual/13-bridge-overlap/result.md and
> docs/qa/2026-09-16-manual/14-rail-fragments/result.md.

> September 17 doorway-rail follow-up: accepted exterior bridge walking lanes
> reopen their exact terminal public guards before final fabric construction.
> P04 loses two rails; all other instances and 101 generated meshes remain.
> Nine tests / 498 assertions and six native collision sweeps verify the doorway;
> 312 public stance and 444 crossing results remain identical. Twelve native/game
> pairs retain adjacent guards. The prior exact-3D test missed the guard floor
> lift and is corrected red-first. P15's stray cap/roof junction and an adjacent
> bridge side-wall collision remain open; no fresh streaming/full-suite approval.
> See docs/qa/2026-09-16-manual/05-town-rails/result.md.

> September 16–17 cliff attachment follow-up: thin added stone now borrows the
> actual native wall depth/normals, fading to independent crags as projection grows.
> The native mesh is sampled once on the main thread; workers use detached arrays.
> Most relief reaches near each wall's full crown, with local recesses; tall walls
> gain enough vertical samples to avoid stretched details. Selected wider feet and
> finite low terraces retain the sub-8 m projection bound. The old <90% coverage
> ceiling is superseded by the owner's full-height request. Twenty-six focused tests
> / 1,581 assertions pass; 17 matched frozen-context pairs plus a corrected 64 m
> native study document the result. Replay reuses saved anchors/terrain/collision;
> no fresh world/traversal or global performance acceptance. Native corner pattern,
> soft broad faces and a close fern overlap remain. See
> docs/qa/2026-09-16-manual/12-cliff-transition/result.md.

> September 16 cliff texture/variability follow-up supersedes the rejected smooth
> rounded candidate. Independent weathered block masses and finite offset ledges
> add mixed widths/heights/depths; smaller crags interrupt broader lower shoulders.
> Shallow fractures and a restrained world-space stone bump material replace blank
> smooth faces without copying native wall courses. Final focused tests pass 22/22
> with 1,167 assertions; the actual protrusion control rises from 2 to 7 sampled
> projections. Seventeen matched frozen-context pairs are captured. This is art-only
> replay at saved anchors, not fresh hydraulic/seating/collision/traversal acceptance.
> Native upper-wall repetition and a close P12 fern overlap remain. No owner or
> gold-standard art approval is claimed. See
> docs/qa/2026-09-16-manual/11-fractured-outcrops/result.md.

> September 16 evening cliff art remains OPEN. The owner rejected the 09
> jagged shelf direction and reaffirmed the rounded reference as the gold standard.
> `download-1.png` is the closest previous game direction, but its two continuous
> bands and lack of lower boulder variation remain rejected. Current requirements:
> rounded worn faces with sharp carved ledges, irregular composition, broader
> supporting masses toward the ground, restrained protrusion, and gray wall joins.
> Current `CliffRockCrags.gd` is an unaccepted native-render candidate. Five studio
> views and 21 focused tests pass, but the fresh game capture did not finish
> after 2,092 s startup and Metal waits; production visual/traversal checks remain
> open (docs/qa/2026-09-16-manual/10-rounded-ledges/result.md). Ferns/ivy
> retain grass colour and actual crevice contacts. Older geometry/test passes do
> not establish acceptance. See docs/qa/2026-09-16-manual/10-rounded-ledges/iteration.md.

> September 16 latest owner follow-up reopens Production04 art: shelves remain too
> flat, a side curls inward, and exposed wall coverage is insufficient. Increase
> connected coverage, remove pinched/undercut ends and vary ledge grade. Repetitive
> vines and scaled spherical bushes are also rejected; inspect existing fern/plant
> stock. The earlier technical checks remain scoped evidence, not art acceptance.
> See docs/qa/2026-09-16-manual/07-cliff-planting/reference/owner-shelf.png.

> September 16 manual cliff follow-up supersedes the rejected separate mounds.
> Six original closed connected shoulders replace those sources under the existing
> outcrop IDs. Gray buried wall junctions, intrinsic lower benches and turf only on
> flatter faces preserve native wall relief. Actual bench triangles feed ordinary
> grass; horizontal rock sections exclude buried roots. Rounded shrubs own ledge
> planting, avoiding a duplicate fern pass. Multiple studies and three production
> revisions were rejected before Production04. Seventeen matched camera pairs,
> fresh Amber/Highland views and twelve actual ledge walks verify inspected sites.
> Twenty focused tests / 677 assertions and a grass follow-up / 8 assertions pass.
> The wider terrace run retains one historical UID-warning failure (22/23 tests).
> No owner approval, perfect landscape art, full-suite or performance acceptance
> is claimed. Native terrain repetition and other manual issues remain open. See
> docs/qa/2026-09-16-manual/06-cliff-rework/result.md.


> September 16 cliff revision supersedes the dense September 15 facade: six
> weathered Ultimate Nature outcrop solids replace all backing ribs/panels.
> Wider lower shoulders retain actual rooted collision; original wall relief
> stays visible (31–67% sampled outcrop coverage). Native cliff, ambient stones
> and outcrops share one restrained gray-brown palette. Moss uses the native turf
> UV/material and biome ground tint. Rounded KayKit shrubs replace fine-leaf
> bushes; trailing vines retain alpha cutouts and biome foliage tint. Owned rock
> footprints reject wet channel intersections; dry halo reservations stay
> conservative. Fresh Q01/Q02 geometry plus final material replays and a frozen
> amber art control produce nine judged views/differences. Seventy-four focused
> tests / 7,387 assertions and one native GPU test / four assertions pass.
> The broader catalog run is 90/93, with three stale village material UID-warning
> failures. Q02 startup remains 334.949 seconds. No general hydraulic, streaming
> or full-suite acceptance is claimed. See docs/qa/2026-09-16-cliffs/result.md.

> September 15 moss-rock cliff dressing: the owner rejected both replacement
> cliff textures and stacks of smaller ordinary cliff tiles. Production now uses
> `CliffRockDressing.gd`: four adapted CC0 Ultimate Nature moss rocks plus eight
> original closed ledged ribs, overlapping outside the unchanged native wall/cap
> family. Canonical face panels follow the native -12 + 24n cell phase; a one-cell
> halo supplies shared root, plant-occlusion and ground reservations before owner
> projection. Complete grade/public footprints veto rocks. Roots sample the real
> neighboring surface; exposed moss shelves support baked green bushes above water.
> Resources prepare on the main thread; worker placement uses detached arrays.
> Collision uses the actual rock triangles. The old `CliffTerraces.gd` library
> remains available to historical tests but no longer dresses production cliffs.
> P04/P06 production captures, oblique views and matched differences review the
> new style. This is not universal camera, hydraulic or streaming acceptance;
> cold startup remains expensive. See docs/qa/2026-09-15-manual/08-cliff-siding/result.md.

> September 15 study grounding: intrinsic rooted terraces replace all three
> separate elevated slabs. Full-footprint seating replaces centre-only sampling
> on the study floor. Sixteen formerly exposed bases reproduce red; actual native
> foot samples now remain buried on all fifteen formations. Fourteen planted/bare
> pairs, three native tests / 215 assertions, 41 clear capsules and 15 matching
> contacts verify the study. Production grid integration remains open. See
> docs/qa/2026-09-15-manual/07-grounded-study/result.md.

> September 15 mountain terrace assets: shared post-fracture shoulder profiles
> add intermediate green ledges and broaden the bases of all five tall original
> assets. Joints open after shaping; tiny slivers collapse without opening solids.
> Four source tests and two native tests / 184 assertions pass, with fourteen
> matched planted/bare pairs, 41 clear study capsules and 18 matching contacts.
> Source-to-catalogue checks reject stale editor imports; the mountain bake wrapper
> feeds fresh GLBs to the ordinary baker. The separate study shelves and production
> grid-cliff integration remain open. See docs/qa/2026-09-15-manual/06-terraces/result.md.

> September 15 cliff-spill review: supplied upper water reaches the actual
> native crown before descending to existing receiving water. Coarse and fine
> support share the same bounded rule, using one-sided native extrema at
> multi-height corners. Dry banks, ridges and missing receivers remain protected.
> Both P10 strips pass 200 field probes and 186 detached physics samples;
> fifteen matched static/timed pairs verify the production view. Sixty distinct
> tests / 3,847 assertions pass across the broad and focused runs. The older
> photo-16 inland shoreline becomes a connected outlet; its original free-shore
> inputs retain every old threshold under current interpolation. Cold loading
> and broader water acceptance remain open. See
> docs/qa/2026-09-15-manual/05-water-drops/result.md.

> September 15 water-motion review: current wavelets use a separate 192 m
> field with a continuous circular 48–90 m envelope. The 96 m contact domain,
> 0.375 m ripple texels and 3 m current grid remain unchanged. Expanded packet
> capacity retains area density and bounds local admissions/rejected retries.
> CPU buoyancy shares the displayed envelope. Twenty-six tests / 150 assertions,
> fifteen matched timed P12 pairs and six identical GPU contact-ripple fields
> pass; 4,761 GPU/CPU envelope samples agree within 0.000489. Simulation CPU
> mean adds about 1 ms in the replay; Metal GPU timings are unavailable. Other
> water geometry and global performance remain open. See
> docs/qa/2026-09-15-manual/04-water-motion/result.md.

> September 15 spawn water review: actual river/pond seeds retain provenance
> through spill containment. A finite wet-component traversal removes pools
> whose supplying sill dried; subsequent fine rescue can restore real narrow
> passages. The photographed 12,561-sample source-free pool is removed without
> a spawn exception, terrain change or renderer mask. Fifty-one tests / 3,629
> assertions, 81 positions through four chunk owners and nine judged matched
> view pairs verify P11. Other water reports and universal source-domain
> independence remain open; startup timings are not controlled comparisons.
> See docs/qa/2026-09-15-manual/03-spawn-water/result.md.

> September 15 streaming review: active background jobs yield at completed
> planning boundaries to strictly more urgent work, preserving generation and
> completed caches without publishing partial terrain. Upcoming crossings precede
> lateral prefetch while moving; actual feature parents lend their urgency.
> A 180-second 10 m/s survey improves from 1,440 m / 36.219 s frozen to 1,803 m /
> zero frozen, with six yields and no unexpected duplicate starts. The first
> candidate's 11.209 s freeze is rejected. Forty-six tests / 479 assertions,
> 76 exact water hashes and three matched loaded P05 views pass. P05's original
> foreground void is not temporally recreated; the reproduced stall is farther
> south. Startup remains roughly seven minutes and frame p95 is unchanged.
> No universal streaming or startup acceptance. See
> docs/qa/2026-09-15-manual/02-streaming/result.md.

> September 15 grass topology follow-up: candidate 07 only repaired hanging
> sheets and was rejected by the owner. Sealed village datums now select native
> world controls before ordinary slope/cliff/corner classification. Complete
> fixed pads and bounded support closure share one lattice with ground, rock,
> grass and collision; continuous road samples retain their lineage. Canonical
> domains and two-cell record discovery preserve query-order independence.
> P08 retains a flat native cliff crown and rounded corner; P07/P09 retile their
> partly graded cliffs to ordinary ground. Nine judged game pairs/differences,
> 5,325 supported foundation rays and six topology tests / 20 assertions verify
> these sites. The terrain run is 139/145 with five historical failures and one
> pending. A separate house/path failure reproduces on baseline. No global
> mixed-pad, water, streaming or full-suite acceptance is claimed. See
> docs/qa/2026-09-15-manual/01-grass/result.md.

> September 14 ledge seating: actual native wall recess and usable walking
> depth govern stock selection. Face caps share an exposed edge; shallow stock
> turns when it can provide full bearing, otherwise it is ineligible. Both
> corner types seat against their real walls. Seventeen original contacts fail;
> 216 candidate placements in four orientations pass five-height probes. Fifteen
> native pairs, nine fresh game views and three jumps pass; 15 tests / 351
> assertions remain green. Concurrent load timings are not compared. See
> docs/qa/2026-09-13-manual/24-cliff-layout/result.md.

> September 14 terrace collision: nine native columns share their actual flat
> caps and rounded outlines between grass and closed vertical ground collision.
> Decorative undersides no longer catch jumps; rock collision stays native.
> Sixteen original failed approaches now pass, as do three frozen and three
> fresh game jumps, all without underside contacts. Six matched views retain
> appearance; 31 tests / 649 assertions pass. Physical columns use 64–188
> triangles instead of 336–1,026. Isolated character timings improve; no global
> performance claim. Fresh startup is 359.170 s. See
> docs/qa/2026-09-13-manual/23-terraces/collision-result.md.

> September 14 terrace grass: accepted native flat cap triangles join the
> ordinary detached grass worker sampler. Native borders contain whole patches;
> rock footprints and higher ground exclude buried roots. Shared halo caps retain
> identical chunk ownership. Five native pairs, three fresh game views, 29 tests /
> 594 assertions and 140 actual worker roots across fifteen local tiles verify
> P18. Startup remains 357.842 s. The zero-shore-limit initial control is excluded.
> Ledge layout, cliff composition and native underside jump collision remain open.
> See docs/qa/2026-09-13-manual/23-terraces/grass-result.md.

> September 14 water wave clearance: complete swept native terrain footprints
> and the turf lift constrain displacement. Shared world-lattice budgets blend
> continuously; shoreline joining faces stay anchored, with full waves returning
> in deeper water. P39 retains 1,053 covered native samples through maximum and
> moderate troughs, fifteen diagnostic phase pairs, six game pairs, and twelve
> tests / 2,042 assertions. Startup is 339.914 s. Static domain cutoffs, mountain
> pools and distant animation remain open. See
> docs/qa/2026-09-13-manual/22-water/turf-result.md.

> September 14 water-corner follow-up: an existing fine water channel owns
> its actual dry edges; missing fine corners use bounded coarse interpolation.
> A phantom coarse dry edge no longer pulls P12 below its receiving reach.
> The first candidate was rejected for an older shoreline discontinuity.
> Final verification passes 33 tests / 2,929 assertions, three frozen and three
> fresh game pairs. Startup remains about 309 s. Other water reports, broad
> water acceptance and general performance remain open. See
> docs/qa/2026-09-13-manual/22-water/corner-result.md.

> September 14 civic review: native wells scale uniformly to 1.5 and reserve
> their complete transformed footprint before shared frontage allocation.
> Campfire variants retain natural ground across the civic clearing and internal
> routes; actual world-road handoffs keep paving. Five-house photo allocation
> stays fixed. Eighteen native/grass pairs and six clear game comparisons,
> eight tests / 997 assertions, four 1,224-position native collision surveys,
> 48/48 towns and the 95/95 fingerprinted gate verify the scoped repair.
> Twenty-five off-centre pillar contacts and expensive startup remain. Campfire
> grass is checked in the controlled production fixture, not a full-world run.
> See docs/qa/2026-09-13-manual/20-civic/result.md.

> September 14 street-footprint review: unused ground parcels enclosed by four
> level streets join the public graph after actual plot allocation. Intentional
> plots/features and open courts remain protected; a single pass cannot flood lawns.
> Level exit paint follows actual road selection, while raised approaches retain
> their built stairs. Six matched native/game pairs, 13 focused tests / 172 assertions,
> unchanged 92/132 old physical samples plus 4/12 clear additions, 48/48 towns and
> 95/95 composition verify P23. The corpus has 11,772 clear positions / 16,915
> crossings and the same 25 conservative off-centre pillar contacts. Two historical
> road-coordinate pins fail identically with original paint. Startup is 305.349 s;
> no performance or full road-suite acceptance is claimed. See
> docs/qa/2026-09-13-manual/19-streets/result.md.

> September 14 village approach: construction collars blend maximal-pad
> distances before applying the common slope profile once. Their complete
> finite extent and interval bounds share that distance; fixed foundation
> heights and single-pad 12 m profiles remain. Photo P11 falls from 48.45 to
> 36.02 degrees, and all six actual-player uphill/downhill runs pass without
> changing controller limits. Six matched native/game pairs, 20 tests /
> 19,240 assertions, 48/48 towns with unchanged 11,764 clear positions /
> 16,891 crossings and 95/95 composition verify the approach. The same 25
> conservative pillar contacts remain. Loaded startup is 373.793 s; P24's
> rock slivers remain separately open. See
> docs/qa/2026-09-13-manual/17-village-grade/approach-result.md.

> September 14 destination-owned stairs: actual plot allocation precedes pruning
> of terminal climbs above all useful destinations. Complete flights and optional
> empty lookouts withdraw together; entrances, civic decks, gates, ordinary lanes,
> loop connections and occupied spans retain their approaches. P14/P22 keep their
> native house plots and addresses. Twenty-four matched native/game pairs, eight
> tests / 99 assertions, 48/48 towns with 11,764 clear positions / 16,891 crossings,
> and 95/95 composition pass. The same 25 conservative pillar contacts and three
> baseline carver failures remain. Cold loading stays expensive; no performance
> acceptance. See docs/qa/2026-09-13-manual/14-deck-purpose/result.md.

> September 14 floating lawn: retained tunnel crowns no longer borrow a jamb
> from a prefab occupied box or PRIVATE_VOLUME reservation. Actual retained,
> modular solid and plinth bearings remain eligible; prefab foundations keep
> their original contract. P14 loses all eight unsupported bed cells and their
> turf, timber underside and furnishings, gaining two native landing guards.
> Three houses remain. Twelve judged pairs, six tests / 92 assertions, identical
> 76-position / 108-crossing clearance, 48/48 towns and 95/95 composition pass.
> Twenty-five conservative pillar contacts remain. Upper-deck purpose is still
> under review. See docs/qa/2026-09-13-manual/13-floating-lawn/result.md.

> September 14 centred oriel review: small native bays align to actual two-cell
> facade panels, with four rear contacts and both attachment sockets. A finite
> plain parent facade phase replaces the shutter and stays inside the previously
> reserved room envelope; final compilation verifies its unsuppressed backing.
> The photo retains eight bays. A shutter-visible candidate and a balcony-conflicting
> phase candidate were rejected. Nine judged pairs, four tests / 215 assertions,
> identical 356-position / 502-crossing clearance, 48/48 towns and 95/95 composition
> pass. The related 15/16 result retains the original full-gabled-bay count failure.
> Twenty-five conservative off-centre pillar contacts remain. No broad performance
> acceptance. See docs/qa/2026-09-13-manual/12-bay-spacing/result.md.

> September 14 compact roof junctions: complete square leaves at exposed slim/row
> ends select paired native valley alternatives against the completed allocation.
> Prepared cuts retain native bearing/phase and the original chimney pose; continuous
> runs stage complete replacements and preserve existing run membership. Two-sided,
> partial, occupied and dormered candidates retain their complete roofs. P09 changes
> only four of 2,000 native placements; all 111 rooms and 356/502 public samples remain.
> Seven clear native pairs, three fresh game pairs, 26 focused tests / 520 assertions,
> 48/48 towns and 95/95 composition pass. The shared 52/53 test result retains the
> historical prefab circulation bound. P31 retains its native two-sided dormer.
> Cold startup is 192.620 s; no performance/full-suite acceptance is claimed. See
> docs/qa/2026-09-13-manual/11-roof-joins/result.md.

> September 14 review capture correction: collision readiness and an idle worker
> can precede feature visual commits. Village reported captures now wait for the
> feature queue to drain before freezing/saving the world. Eight tests / 40
> assertions pass; a fresh P10 capture and replay retain all 345 expected current
> wall/window pieces. Older issue-09 snapshots lacked 70 wall pieces and must not
> serve as complete-world references. Production streaming is unchanged; grass,
> lighting and general performance are not accepted by this correction. See
> docs/qa/2026-09-13-manual/45-live-panels/result.md.

> September 14 lawn borders: suspended cells use the complete same-height turf
> footprint for exposed frames and grass insets. Two photographed internal L strips
> disappear while exterior frames, supports and guards remain. Six matched pairs,
> fifteen tests / 4,635 assertions, identical 356-stance / 502-crossing clearance,
> 48/48 towns and the 95-assertion composition gate pass. Fresh startup is 188.871 s;
> no performance acceptance is claimed. See docs/qa/2026-09-13-manual/42-lawn-strips/result.md.

> September 14 doorway panels: closed native doorway returns use plain
> horizontal wall stock at its full normal relief. Manifest-owned left handing
> places both native jambs toward the front, preserving winding, source-centre
> bounds and central doorwork. Baker 37 updates ten variants; other recipes
> retain the default operation. Eleven judged pairs, 96 native depth samples,
> 2,715 room sightlines, identical 164/235 local clearance and 48/48 towns with
> 11,868 clear stances / 17,035 crossings verify P37. Composition is 95/95.
> The 32 focused tests retain two original-asset historical failures (1,896/1,898
> assertions). Six visual floor caps adapt; their collision stays identical.
> Startup is 367.264 s, without performance or full-suite acceptance. See
> docs/qa/2026-09-13-manual/39-door-panels/result.md.

> September 14 garden/stair guards: rounded stair occupancy does not open a
> lateral garden exit. Raised courts own their level guards and clip diagonal
> rail fragments above the retaining wall; end landings remain open. P40 has
> ten matched native/game pairs, six actual bidirectional stair/landing walks,
> 14 tests / 428 assertions and 48 towns with 11,868 / 17,035 clear positions /
> crossings. One local unsafe lateral exit deliberately closes; all 164 stances
> and the other 234 crossings remain unchanged. The roof-side guard was present,
> partially occluded by the gable. Composition passes 95 assertions. Startup is
> 366.166 s; no performance claim. See docs/qa/2026-09-13-manual/40-rail-ends/result.md.

> September 14 dormer fitting: two finite native shed variants extend their rear
> stock through the existing editor fitting operation while preserving front geometry,
> UVs and complete native collision. Compact/wide registrations and native-repeat
> paired spacing close both P41 junctions without burying glazing. Four native tests /
> 12,018 assertions, matched game/native controls, unchanged 164/235 local clearance,
> all 48 towns and the 95-assertion gate pass. The related 70/71 result retains one
> circulation assertion reproduced with the saved original program. Cold startup is
> 367.801 s; no general performance acceptance. See
> docs/qa/2026-09-13-manual/41-dormers/result.md.

> September 14 facade-prop review: shared facade recipes leave rejected white
> ivy and mug-sign phases empty while retaining laundry and planted window boxes.
> Released envelopes allow normal optional-detail/roof reselection. Twenty-one
> native/game/wide pairs, 28 tests / 49,707 assertions, unchanged 164/235 photo
> clearance, 48/48 towns with 11,868 clear centers / 17,035 crossings and 95/95
> composition assertions pass. Twenty-five conservative pillar AABB candidates
> have zero measured blocks/intrusion; these are not demonstrated contacts.
> Cold photo startup is 191.744 s; no general performance/full-suite claim.
> See docs/qa/2026-09-13-manual/16-facade-props/result.md.

> September 14 public floor finish: production and review share one cached
> transition plank material. Face-metric ramp/stair UVs retain full-width boards
> in all four directions. A square-grid candidate was rejected visually.
> Six matched native/live pairs, eight GPU controls and 19 tests / 187 assertions
> pass. Native placements and all collision stay identical; seven of 52 surface
> payloads change only UVs. The 48-town matrix retains 11,868 clear centers /
> 17,035 crossings and 24 off-center pillar contacts; composition passes 95/95.
> Startup remains expensive. See docs/qa/2026-09-13-manual/38-floor/result.md.

> September 14 barrel review: optional dressing checks actual sealed public
> triangles as well as native modules. P36 loses only its ramp-embedded barrel;
> other placements, 52 public surface payloads and collision remain identical.
> Six matched pairs, 15 tests / 2,067 assertions, identical 164/235 local clearance
> and 48/48 towns with 11,868 centers / 17,035 crossings verify the repair.
> The same 24 offset-only pillar contacts remain; the 95-assertion gate passes.
> See docs/qa/2026-09-13-manual/37-barrel/result.md.

> September 14 road follow-up: actual-width edge eligibility, bounded four-direction
> routing and endpoint-derived town gates restore two reviewed neighboring links.
> Lazy exact-cost search preserves the rendered route records. Two 672 m streamed
> walks and six native entrance traversals pass; 48/48 towns retain 11,868 centers /
> 17,035 crossings and 24 offset-only pillar contacts. The unchanged 60 s timing
> bound fails on original (87.748 s) and final (95.012 s); performance remains open.
> See docs/qa/2026-09-13-manual/36-world-paths/result.md.

> September 13 partial retaining courses: an incomplete exposed storey uses
> the existing fitted masonry treatment, keeping complete facade courses intact.
> The photographed low plaster patch becomes a continuous stone column. Six
> matched native/game pairs, four tests / 44 assertions and identical 356-position /
> 502-crossing surveys verify the site. All 48 towns retain 11,868 clear centers /
> 17,035 crossings and the same 24 off-center pillar contacts; the fingerprinted
> gate passes 95 assertions. Two older fixture failures reproduce unchanged;
> no full-suite or performance acceptance is claimed. See
> docs/qa/2026-09-13-manual/10-low-wall/result.md.

> September 13 upper-bay review: native open backs declare complete parent-wall
> contact cells. Centred facade placement retains exact room/bearing sockets
> across both columns, with all original bearing/roof/public clearance checks.
> P10's half-backed bay becomes a closed projection on a compatible facade.
> Ten focused tests / 475 assertions, six judged pairs, identical 164-cell /
> 235-crossing clearance and 48/48 towns (11,868 centres / 17,035 crossings)
> pass. The same 24 off-centre pillar contacts remain. The first candidate's
> 20 socket-match failures were rejected. Separate live-panel omissions remain
> open; no general renderer or full-suite acceptance. See
> docs/qa/2026-09-13-manual/09-upper-wall/result.md.

> September 13 half-roof review: a complete actual upper room backs the open
> party cut, leaving the native finished gable toward the street. Early/final
> admission share the rule; partial/lower walls cannot choose the hand. P07
> changes only two of 2,001 placements with identical bounds, generated surfaces
> and support boxes. Six native closure rays, 48 rotated native cases, three
> matched game and four useful native pairs verify the reported ends. The
> 48-town sweep retains 11,868 clear centers / 17,035 crossings and the same
> 24 off-center pillar contacts; the corpus gate passes 95 assertions. The
> full composition file retains 21 baseline failing tests. Local clearance
> remains 356 clear centers and 498 clear / four offset-only crossings. No
> universal roof, performance or full-suite acceptance is claimed. See
> docs/qa/2026-09-13-manual/08-roofs/result.md.

> September 13 evening visibility: complete native foliage owners share one
> cutaway plane; upward leaves no longer masquerade as ground. Actual cliffs
> may receive foliage reveals, while houses retain their ground/enclosure rule.
> Background earth stays opaque, and foreground terrain only peels when actual
> depth obstructs the actor. Receiver peeling shares that decision with grass.
> Existing complete physical heightfield triangles prove native-cap burial;
> cached private proof meshes release with their owners. WaterSheet keeps its
> native material outside camera adaptation. Twenty-four evening pairs and twelve
> prior-site controls, 40 tests / 328 assertions and a 60-frame bank sweep pass.
> Invalid black captures are replaced; an intermittent shutdown report remains
> documented beside the clean isolated test run. No general renderer, streaming
> or performance acceptance. See docs/qa/2026-09-13-manual/01-near/evening-review.md.

> September 13 platform access: ordinary full-width perpendicular stairs are
> reserved before house allocation and share the existing upper landing. The
> whole route footprint leaves flat deck/plaza ownership; occupied or short
> courts cannot shrink the flight. The half-width candidate is withdrawn.
> Three matched game pairs, native detail/collateral views, 22/22 real traversals,
> nine tests / 137 assertions and 48/48 towns pass. Surveys retain 11,868 clear
> centers, now 17,035 crossings and the same 24 off-center pillar contacts;
> the fingerprinted gate passes 95/95. No relocation fallback, broad-suite or
> general performance acceptance. See docs/qa/2026-09-13-manual/07-platform/result.md.

> September 13 P08 rail review: deferred ramp/stair guards consume the same
> finished native wall envelope as landing guards, removing detached timber
> across upper rooms. Coarse masonry alone was insufficient. Exposed spans and
> low parapets retain guards and collision. Three photo pairs, native detail/wide
> controls, ten unchanged traversals, 12 tests / 368 assertions and 48/48 towns
> with 11,868 clear centres / 17,038 crossings pass; the gate passes 95/95.
> The same 24 off-centre pillar contacts remain. No broad-suite or performance
> acceptance is claimed. See docs/qa/2026-09-13-manual/06-rails/result.md.

> September 13 stone-path review: the complete-flight reservation also removes
> P05's six U-shaped retained masonry panels. No extra production change. Three
> native photo pairs/differences, 125 clear capsule stances and ten actual traversals
> verify the repair; the original has 53 blocked stances and one blocked traversal.
> Issue-04 corpus and broader-suite limitations apply unchanged. See
> docs/qa/2026-09-13-manual/05-stone/result.md.

> September 13 path barrier: continuous native ramp/stair air is reserved before
> room and prefab allocation, preserving the canonical route. P04 removes its
> transverse timber/plaster barrier; all six real traversals and 99 capsule stances
> clear. Retained-stone support closes to a fixed point after jamb withdrawals,
> repairing a discovered six-cell regression in seed 9/standard. Three matched photo
> poses and native context/support views, 51 tests / 511 assertions, 48/48 towns and
> the 95-assertion fingerprinted gate pass. The same 19 broad composition test names
> fail as baseline; no full-suite or performance acceptance. See
> docs/qa/2026-09-13-manual/04-path/result.md.

> September 13 ground cutaway review: actual first-surface depth gives every
> intervening earth skin one screen-ray feather; full-frustum ground selection
> includes reverse skins beyond the original actor corridor. Raised grass follows
> its root's actual receiver depth. No substitute fill or collision change.
> Fifteen photo-angle pairs, six motion pairs and 42 tests / 346 assertions pass.
> Rejected candidates exposed reverse skins or shaved raised ground cover. Native
> frame medians rise from about 27 to 38 ms; no performance acceptance is claimed.
> See docs/qa/2026-09-13-manual/03-ground/result.md.

> September 13 background visibility: native instances carry construction-owned
> enclosure footprints through payload/chunk projection. Separate roofs inherit
> their bearing rooms; stepped rooms share their inhabited-volume identity.
> Background buildings stay opaque while a foreground enclosure uses one screen-ray
> feather mask across all depths. P33/P06 and four neighboring views, independent
> native background controls, and 41 tests / 333 assertions verify the scoped repair.
> Existing P06 orange roof geometry remains under the roof review; broader ground,
> interior, traversal and performance acceptance is not claimed. See
> docs/qa/2026-09-13-manual/02-background/result.md.

> September 13 near-camera visibility: foreground coverage retains its world
> radius up to the eye, expanding its projected area for nearby obstacles.
> The camera defaults to full transparency inside the feathered reveal;
> real-ground mask taps clamp at viewport borders without relaxing the mandatory
> center receiver. P03/P32 and four nearby native pairs/differences pass; 37
> focused tests / 285 assertions pass. Background building preservation (P33)
> remains open. See docs/qa/2026-09-13-manual/01-near/result.md.

> September 12 current manual visibility review: the owner rejected both the
> actor silhouette and brown earth-cap approaches. The requirement is bubble
> intersection with real visible ground behind the obstacle. Where no genuine
> receiver exists, preserve the original foreground, with an inward soft edge.
> The receiver pass shares actual ground meshes and live native buffers; no fake
> cap is emitted. One inward-feathered mask clears intervening front/rear shells
> up to genuine terrain or public ground. Turf swatches reject sloping rock;
> building interiors never qualify. Fifteen matched photo views and six motion
> pairs, plus 36 camera tests / 275 assertions, verify these reported sites.
> The baseline produces 8,120 synthetic void pixels and 210 reverse-skin pixels;
> both become zero. Two black three-phase capture sets are excluded; the same
> town angle passes when captured first in a fresh process. This does not resolve
> general renderer stability. Warm frame medians are 32.304 versus 26.491 ms.
> Cameras use rounded overlay reconstruction; no physical walk, global performance
> or remaining manual-issue acceptance is claimed. See
> docs/qa/2026-09-12-manual/01-ground/result.md.

> September 12 biome terrain review: seven continuous geological profiles use
> a 128 m range / 32 storeys while retaining the native 4 m / three-storey step.
> Physical water source thresholds survive that range change. Wide gentle reaches
> retain low bars; receiving rivers share fitted lake island/peninsula ownership.
> Natural overhead arches reserve complete bearings and use closed visual/physical
> triangles. Exact float32 queue comparisons end the reproduced water requeue stall;
> buried rim intervals cannot create inverted swim volumes. Complete native-only
> neighborhoods use the common owned parcel/support pipeline without dummy rooms.
> Steep moving water uses bounded hydraulic-power scattering along its actual face;
> shoreline, stationary, transverse and flat controls stay unchanged on both sides.
> Ninety landmark pairs, final lake/gorge/arch/bar and native-town views, six actual
> arch swims, six bar and six lake surveys, 39 dry peninsula samples, 64 tests /
> 10,009 assertions, seven material tests / 47 assertions and ten GPU controls pass.
> The mandatory corpus remains 48/48 with 11,868 clear centers / 17,038 crossings;
> 24 off-center pillar contacts remain, and the fingerprinted gate passes 95/95.
> Coarse contours, restrained forest bowls, clear broad cascades and unwired plunge
> spray remain. Cold arrivals still take minutes (final island 327.947 s); no global
> streaming, water, renderer or full-suite acceptance is claimed. See
> docs/qa/2026-09-11-manual/12-landforms/result.md.

> September 12 cliff terraces: nine catalogued native KayKit hill columns keep
> their full proportions and collision, rooted in lower ground and embedded in
> exposed faces and both corner types. One-cell halo arbitration preserves chunk
> ownership; complete public/graded footprints and wet feet veto placement.
> Sparse native rocks sit on wider caps; CPU workers use detached prepared values.
> Sixty-six matched pairs, eighteen detail views, eight tests / 283 assertions and
> 128 orientation/seed cases verify inspected sites. Original ground/cliff arrays
> remain identical. The broader 100/103 result retains three historical carved
> corner failures. Startup is 132.281 s; no new long-walk or general performance
> acceptance is claimed. See docs/qa/2026-09-11-manual/11-cliffs/result.md.

> September 12 unified city and follow-ups: low native neighborhoods and upper
> rooms share one massif/route/plot allocation. The separate ground-house ring is
> removed; real external roads hand off to source gates. Retained earth over public
> air requires a continuous crown between opposing actual jambs, removing the entire
> photographed floating grass/stone/timber bed. Optional skywalks require a complete
> neighboring wall storey beside both endpoint groups, outside their own compound
> and future public openings. The photo keeps one interior span and three low
> prefabs. Complete exposed crowns share early/final native roof alternatives despite
> stale flat topology markers, repairing seed 8 grand without retries or seam changes.
> Matched photo/wide/native comparisons, 42 tests / 9,081 assertions, 48/48 towns,
> 11,868 clear public positions / 17,038 crossings and 95/95 composition pass.
> Twenty-four off-center pillar contacts remain. Four black live captures are excluded;
> clean persistent-camera/GPU replays do not explain those readbacks. Camera matching
> uses rounded original overlays. See docs/qa/2026-09-11-manual/10-unified-city/result.md.

> September 12 prefab integration: all 32 complete native recipes survive the
> 17 measured doorway-relative reservation families. Source selection chooses the
> actual native variant before modular partitioning, and its signature records
> that choice independently of audit order. Each tier requests one extra supported
> prefab site; existing bearing, visual/public air and frontage checks remain.
> The photo town retains all 28 room records and two prefabs; seed 11 compact
> gains a second prefab (27 to 18 modular rooms), retaining identical 76/108 public
> clearance. Photo clearance remains 88/124. Fifty-four credited visual pairs plus
> ten obscured context views, 48/48 constructed towns, 11,112 clear positions and
> 15,923 clear crossings pass. The same 27 off-centre pillar contacts remain.
> Composition passes 95/95; raw host calibration 2.810x is still invalid for a
> performance bound. An isolated grand-town pair totals 57,197/55,976 ms; no general
> speedup is claimed. Source-plot historical failures are identical to baseline;
> two older scale pins remain. Native floors/ground/street interfaces are shared,
> without new interior openings. See docs/qa/2026-09-11-manual/09-prefabs/result.md.

> September 12 skywalk integration review: two completely borne half-storey
> endpoint gaps use full-width native masonry with ordinary native corner miters
> and continuous timber quoins. Early reservations remove the inaccessible crown
> planter; final foundation connectivity proves every lower bearing before emission.
> Public/daylight/protected air veto infill. Both occupied spans and 27 warren rooms
> join one constructed mass; the small roofed house remains separate. All 28 room
> records and unrelated recipe choices stay fixed. Three candidates were rejected,
> including narrow-panel gaps missed by centre rays. Final evidence: 38 judged
> pairs, 23,850 native shell segments, 10 tests / 266 assertions, identical local
> 88-cell / 124-crossing clearance, 48/48 towns and 11,112 / 15,923 clear positions /
> crossings. The 27 off-centre pillar contacts remain. Composition is 94/95: only
> 3/standard timing fails, 17,856 vs 16,200 ms at invalid host factor 3.35x.
> Timing stays unresolved, pins unchanged. Closed rooms gain construction
> connectivity, not playable interiors. See docs/qa/2026-09-11-manual/08-skywalk/result.md.

> September 11 roofless-cell review: the issue-5 removal also resolves the
> blue-circled unused roof slab. Four remaining columns have actual rooms above
> and below; 25 native triangle samples prove the smaller ceiling is closed.
> Original payload reproduces eight failed bearing/use assertions, current code
> passes all six related tests / 157 assertions. Sixteen fresh native pairs and
> twelve live comparisons retain the issue-6 details. No new production change;
> same 48-town matrix and timing limits. See docs/qa/2026-09-11-manual/07-roofless/result.md.

> September 11 architectural-variety review: supported bay opportunities follow
> upper-room lineages. Native private corner walkouts reserve two real bearing
> walls, complete L decks and guards, and measured lower knee contacts. Compact
> dormer requests survive compatible roof selection with unchanged native seams.
> The photographed town retains all 28 rooms, adding one bay, two corner balconies
> and one dormered roof. Twelve live pairs, sixteen native pairs, eight clear
> detail pairs, 116 new assertions and 48 constructed towns retain 11,112 clear
> public positions / 15,923 crossings. The composition gate retains timing
> failures; no timing pin is changed. See docs/qa/2026-09-11-manual/06-variety/result.md.

> September 11 floating-block review: ordinary room composition limits timber
> projections to one fine cell, retaining the deeper complete public arcade.
> The photographed slim room becomes its fully borne rear tower under the same
> skywalk endpoint; all 28 rooms remain. Compact native timber knees replace
> empty bracket recipes. Twelve live pairs, sixteen native pairs, 46 focused
> tests / 357 assertions, unchanged 88-cell / 124-crossing local clearance and
> all 48 corpus towns with 11,112 clear positions / 15,923 crossings verify the
> reported repair. Loaded timing gates remain red on original and candidate;
> no timing pin or full-suite acceptance is claimed. See
> docs/qa/2026-09-11-manual/05-floating/result.md.

> September 11 black-screen review: the original material adapter reproduces
> fresh black/nonfinite GPU frames in the embedded Game view. The issue-1 live
> buffer/native mesh ownership repair passes 4,682 marked embedded frames, both
> exact failure poses, twelve photo-angle pairs and 13 native tests / 143
> assertions. No renderer/effect change is added. Intermittent original clean
> runs and stale diagnostic exclusions remain documented; acceptance is scoped
> to the measured failure, not universal Metal stability. Temporary editor
> settings are restored. See docs/qa/2026-09-11-manual/04-black/result.md.

> September 11 camera roles: tactical left/right travel uses the old close
> camera's angular follow response at a fixed elevated boom. The close view
> instead uses bounded mouse yaw/pitch and a center crosshair above the mage
> hat, with position following independent of heading. F7 preserves heading;
> Escape, focus loss and pause release capture, and a game click reacquires it.
> Twenty-four native tests / 166 assertions and sixteen judged image pairs with
> camera trajectories verify the roles. Native capture is tested separately
> from deterministic image motion replay. Enclosed close views retain real wall
> obstruction. See docs/qa/2026-09-11-manual/03-controls/result.md.

> September 11 larger visibility bubble: tactical coverage spans half the
> viewport width, with no projected/world-height half-plane cutoff. Nearby
> upward support surfaces remain opaque around the physical feet, including
> lower ground during a jump/fall. Twelve frozen pairs and ten valid live pairs
> with differences, 31 native tests / 289 assertions and a 720-tick orbit verify
> the reported shape. Two wholly black live nearby pairs are excluded; all four
> original reconstructed angles pass. Camera CPU p95 is 4.260 ms under a 30 FPS
> cap. The separate manual black-screen issue remains open. See
> docs/qa/2026-09-11-manual/02-bubble/result.md.

> September 10 city-form review: default tiers now favor 3–6-house ground
> hamlets (50%), then villages (40%) and towns (10%). Tiny settlements own a
> shared square and measured well/fire/tree reservation before native frontage
> allocation, without a second warren/outskirts pass. Real nearby road handoffs
> may enlarge that square; distant roads do not. Native height eligibility keeps
> civic towers out of tiny settlements. Hill, ridge, courtyard and crescent
> warren sources reserve their open ground before routes and plots. One-storey
> rims, at-grade streets, supported interior prefabs and inner/outer shared
> frontage replace the universal tall core plus detached house ring.
> Mixed crowns use bounded exact native tiling and preserve measured approved
> roof seams. Optional bay supports clear the whole swept public crossing.
> S002-derived native valley pieces share the normal roof pitch; twelve legal
> T-junction signatures pass 20,532 actual triangle coverage samples.
> Final evidence: 48/48 constructed towns, 11,112 clear public positions and
> 15,923 clear crossings; 50 hamlet walks; 44 judged image pairs plus ten compact
> views; 18 final tests / 7,560 assertions and 22 earlier architecture tests.
> Exact cap memoization and proposal-local closure reuse retain geometry and all
> corpus counts. The changed standard crescent remains costlier than its old
> round counterpart (three solves 5397/5501/5284 ms); its timing pin is explicitly
> recalibrated using the existing median x1.5 rule. Thirty off-centre pillar
> contacts remain, without blocked centres/crossings. Windmills, island hamlets,
> watermills and paired villages remain proposals. Cold-start and historical
> water/contour limitations remain. See docs/qa/2026-09-10-manual/15-city-form/result.md.

> September 10 grass-loading review: nearby grass uses one dedicated visual
> worker with detached completed ground/water sampling data. Canonical terrain,
> road and water plans remain confined to their original worker; private grade
> caches retain exact samples. Only committed terrain supplies grass inputs.
> The existing visual radius, placement field and upload budget are unchanged.
> Teleports cancel distant queued tiles; completion and terrain eviction release
> sampling owners, including the last local held across an idle semaphore wait.
> Forty-five tests / 452 assertions, 32 judged render pairs and four real walks
> verify the reported delay. The 775 m route has zero missing grass and zero
> frozen time, versus 6.706 s missing nonempty underfoot grass before. The heath
> also removes its 15.689 s unprepared-underfoot interval. Startup and teleport
> waits remain expensive and variable; no startup speedup or global acceptance
> is claimed. See `docs/qa/2026-09-10-manual/14-grass/result.md`.

> September 10 repeated streaming review: exact early road-selection proofs
> skip irrelevant alternatives while preserving seven complete production road
> contexts and settlement entrance masks. Obsolete jobs cancel between complete
> cached operations; partial contexts never publish. Follow-up terrain rebases
> urgency, and bounded caches evict one completed entry only after replacement.
> Discontinuous relocations prepare the existing travel buffer; ordinary motion
> retains its existing collision/feature dependency gate. Water relaxation queues
> violated edges and retains all 6,724 accepted photo-field samples exactly.
> Sixteen teleports eliminate both reproduced walking freezes; an additional
> 120-second walk travels 824 m and a separate retry travels 800 m without freezing.
> Startup is 168.671 s; cold arrival waits remain expensive and some increase with
> the buffer. Six matched render pairs/differences show loaded surroundings but
> do not recreate the original foreground void. The documented cold-start timeout
> remains. Acceptance is limited to the measured routes, not universal streaming.
> See `docs/qa/2026-09-10-manual/13-streaming/result.md`.

> September 10 manual water review: touching wet river heads reconcile downward
> over their complete coarse and fine support, at a 0.30 grade with actual wet
> bed floors. Dry barriers and enclosed lakes remain separate. Shore interpolation
> removes only excess virtual dry-edge height above the physical dry-depth plane;
> real fine water anchors contribute to that support. The same continuous bound
> survives fine interpolation. No mesh-only shelf patch or terrain change is used.
> Photos 15/16/18/19 and all 24 matched views/differences pass. A 73,322-point ledge
> scan finds at most 5.4 cm wet entry depth and 5.8 mm height change per centimetre.
> Four live water routes pass with zero frozen ticks; two chunk seams agree exactly.
> The 93-test run retains eight identical historical failures (24,605/24,617
> assertions). Initial loading remains expensive and is reviewed separately.
> See `docs/qa/2026-09-10-manual/12-water/result.md` for scope and evidence.

> September 11 manual entrance overhang: optional occupied facade bays require
> a complete immediately borne parent wall edge. Already cantilevered faces and
> empty roof reservations cannot extend again. Photo 10 loses its doubled,
> offset projection while its parent room and entrance remain fixed. Six game
> pairs, five native pairs/differences, 20 tests / 700 assertions and identical
> 112-cell / 164-crossing clearance verify the repair. The older three-bay census
> contained two newly rejected unborne faces. See docs/qa/2026-09-10-manual/11-overhang/result.md.

> September 11 manual railing review: generated transition boxes use outward
> lighting normals and Godot front winding; their original corner-based UVs,
> vertices and collision stay identical. Suspended lawn borders remove their
> former compensating reversal. Photos 1/12 and twelve matched game pairs plus
> two native pairs pass after rejecting a first border regression. Seventeen
> focused tests pass 4,490 assertions; eleven transition collision streams remain
> identical. See docs/qa/2026-09-10-manual/10-railings/result.md.

> September 11 manual roof review: bounded terminal roofs fit their measured
> native gable above the supporting wall while preserving outer stock and party
> seams. Joined partial crowns keep their original longitudinal end boundaries.
> Baker version 35 retains every triangle, X/Y, UV and native height across twelve
> finite alternatives. Photo 14 and five matched game views/differences, five
> native pairs, 30 tests / 55,338 assertions and identical 132-cell / 188-crossing
> clearance verify both circled roofs. See docs/qa/2026-09-10-manual/09-roofs/result.md.

> September 10 manual ceiling review: a singleton exposed masonry face fits
> its complete native stock into its owned band. Clearance and facade miters
> share that fact. City garden retaining walls use city masonry and palette,
> with shared rounded corner coordinates contained by the actual native grass
> cap. Source faces and UVs remain complete; ordinary terrain rock is unchanged.
> Photos 4/8/9 and all 18 matched game pairs plus ten native comparisons pass.
> The 57 distinct related tests pass 6,021 assertions with clean exits. Both
> photographed towns retain identical clearance: 120 cells / 175 crossings and
> 297 cells / 424 crossings. See docs/qa/2026-09-10-manual/08-ceilings/result.md.

> September 11 manual skywalk review: a two-ended span consumes bearing from
> both endpoint buildings and cannot return one end's bearing to its other end.
> The final ground graph excludes those spans and empty roof reservations.
> Disconnected endpoint rooms receive the existing native corner frame, seated
> on their lower building and joined to the upper floor underside. Photo 3 and
> five nearby game pairs, four native pairs, 47 tests / 1,069 assertions and
> identical 132-cell / 188-crossing clearance verify the photographed repair.
> See `docs/qa/2026-09-10-manual/07-skywalk/result.md`.

> September 10 garden-underside review: raised garden cells retain exposed
> lower shell faces and close them with the ordinary fitted native timber
> soffit. Ground-level gardens retain their buried terrain interface. Native
> turf lips and the existing suspended lawn's soil/frame/deck remain unchanged.
> Thirty-six matched game pairs, two direct underside comparisons, 74 native
> depth samples and unchanged 112-cell / 164-crossing clearance verify the
> inspected sites. Forty-two focused tests pass with 5,652 assertions. The
> broad initial restoration was rejected for a new low timber strip; the final
> ground-interface regression prevents it. See docs/qa/2026-09-10-manual/06-turf/result.md.

> September 11 platform guard review: roof reservation cells keep construction
> clearance but do not substitute for full walls at an exposed public edge.
> Four native railing sections close photo 5's platform beside its sloping roof.
> Six matched render pairs/differences, sixteen physical probes in four
> orientations, 30 tests / 1,076 assertions and identical 112-cell / 164-crossing
> clearance verify the photographed platform. See
> `docs/qa/2026-09-10-manual/05-guards/result.md`.

> September 11 bench review: both native bench variants retain their visual
> meshes and placements and now carry their complete 96/162-triangle collision.
> Baker 34 supports a manifest-owned native_trimesh profile. Eight seat probes,
> both capsule approaches and six matched real-player before/after approaches
> pass; six render pairs retain the furnishing shape. Six focused tests / 399
> assertions and unchanged 112-cell / 164-crossing clearance verify photo 7.
> See `docs/qa/2026-09-10-manual/04-bench/result.md`.

> September 11 prefab foundation review: complete prefab recipes own native
> timber floors across their declared footprints, correcting the measured board
> pivot once and reserving every lower bearing before admission. Catalog-derived
> source templates retain the same complete support contract. Private floors and
> exposed timber shoulders recess their retaining stone beneath the board.
> Photos 2/17 and ten additional matched views/differences pass, alongside
> 18 tests / 1,295 assertions and the independent 207-assertion template check.
> Physical surveys remain identical at 112 cells / 164 crossings and 297 / 424;
> the latter retains two baseline blocked crossings and one offset-only stance.
> Evidence: `docs/qa/2026-09-10-manual/03-prefab/result.md`.

> September 11 spirit-orb review: both sizes use real spherical cores, a shared
> restrained halo and bounded analytic drift. Small canonical firefly anchors
> render in two MultiMeshes with at most sixteen nearby shadow-free lights per
> chunk; distant chunks release the pool. Six production pairs, sixteen timed
> pairs, rendered centroids and ground-light differences verify photo 11.
> Eleven native tests pass 2,606 assertions. Three uncapped views add 0.36–0.84
> ms/frame for the new illumination. Streaming remains separately pending.
> See `docs/qa/2026-09-10-manual/02-orbs/result.md`.

> September 11 manual wall review (September 10 photos 6/13): the native closed
> wooden doorway has full side housing made from authored timber/plaster stock
> within its original envelope. Its central leaf, hinges and arch remain intact.
> Baker 33 fits the actual source minimum and full height, including door feet.
> Return planes and their vocabulary remain unchanged. Concave facade ends share
> a plain native timber return across their rear reveals. Twelve matched render
> pairs and differences, 16 tests / 1,486 assertions and identical 124-cell /
> 179-crossing clearance verify the reported seams. A rear-slab-only candidate
> was rejected after its oblique through-view remained visible. See
> `docs/qa/2026-09-10-manual/01-walls/result.md`.

> September 9 tunnel arches (accepted): native timber frames belong to the
> transition from open public air into a complete three-band warren bore.
> Two walking cells, two solid jamb columns and real lower bearings precede
> placement. The native-scale 540-triangle asset retains full mesh collision
> and fits below the bore ceiling without blocking the walking aperture.
> Fabric asset preparation, payload and construction signature own the frame.
> Detached road gateways and their clearance footprints are removed; this can
> change deterministic outskirts lot allocation. Biome markers remain separate.
> Six live traversals, unchanged 100-cell / 140-crossing clearance, sixteen
> matched visual pairs and frontage regressions verify the photographed town.
> The full September 9 focused run passes 95 tests / 78,973 assertions; six
> additional frontage tests pass. Documented broad baseline failures remain.

> September 9 city furnishings (accepted): private garden
> edges may reserve compact crate/sack stores or a two-cell bench/bucket group
> after lamp stations and before incidental planting. Complete native bounds
> remain inside their supported cells and clear the final wall envelope. The
> sack uses a measured lid/base contact; public turf and entrances stay empty.
> Eleven matched render pairs/differences, 543 focused assertions, six-town
> decor clearance and unchanged physical walking samples verify these groups.

> September 9 city lantern placement (accepted): realized
> closed door panels carry one native wall bracket at a measured surface point,
> contained in the panel's original envelope and withdrawn with its owner.
> Supported garden edges beside walks reserve at most four spaced two-cell
> lamp stations before incidental planting. Public turf, entrances and occupied
> air remain excluded. Expansion uses resource-free attachment coordinates.
> Nine matched render pairs, actual native triangle contacts, 582 focused
> assertions and unchanged 124-cell / 179-crossing clearance verify placement.

> September 9 atmosphere review: the owner's
> request for biome lighting and twilight supersedes the earlier fixed-world
> lighting policy. Seven profiles blend sky, sun colour/energy, ambient and
> restrained bloom through a three-second exponential response; the sun angle
> stays fixed. Ground-following mist retains spatial biome ownership. Native
> lantern batches emit one shadow-free, distance-faded warm point per placement
> at the measured pane centre; only the LPFV atlas's private glass swatch emits.
> Wider spirit-light ranges keep the existing light count. Camera blur stays off.

> September 9 camera review: AtmosphereDirector leaves camera attributes null.
> Near and far depth-of-field blur are removed pending the camera redesign;
> bloom remains enabled. Three matched game comparisons verify sharp foreground
> and distant edges, with the existing director regressions passing.

> September 9 spirit-orb review: unshaded additive orb sprites output glow
> radiance through ALBEDO; the former emission-only shader was invisible.
> The larger 3.2m halo, 1.5m slow horizontal amplitudes and gentle 0.4m bob share
> one parent with the light. Twelve timed real-world replay comparisons and
> rendered-centroid checks verify the visible motion; 17 related tests pass.

> September 9 broadleaf habitat: the four LPFV broadleaf plant variants belong
> to Jade Estuary and its continuous biome blend. Their pure-Jade distribution
> is unchanged; other biomes select the existing flowers. Restricting only the
> photographed variant was visually insufficient because a similar variant
> replaced it. Photo 11 and five nearby/camera comparisons pass after the
> family restriction, alongside 16 habitat/dressing tests with 660 assertions.

> September 9 doorway-return closure: baker version 32 uses the
> declared native timber cut stock for nonzero doorway-return cuts as well as
> miters. The wall's return plane, relief, UVs and surviving source faces stay
> fixed; its exposed end thickness is closed before floor-cap subtraction.
> Both window hands and floor-owned variants pass native-triangle checks in
> four orientations. Photo 13 and five matched views/differences pass, alongside
> identical 132-cell / 188-crossing clearance. All 674 variants retain actual
> vertices inside their native stock and declared return planes.

> September 9 roof-end review: flush continuous-roof ends fit
> the complete authored end section longitudinally into their declared short
> interval. Clipping at that boundary had removed the native plaster gable.
> The inner seam, transverse section, full native height and UVs are preserved.
> Eight finite color/end/width alternatives bake through the existing fitting
> operation. Photo 10 and five matched views/differences pass. All 72 native
> gable samples now close; 25 related tests and identical 132-cell / 188-crossing
> public clearance verify the repair.

> September 9 covered-crown review: a house whose complete
> footprint meets all exact projected public-floor cells at its even top band declares
> that public ceiling before parcel sealing. Its rooms may use the whole height
> below the shared interface. The parcel identity, storey count and roof-band
> ownership carry the same fact; uncovered or partly covered plots retain the
> ordinary roof reservation. Photo 14 and five matched nearby/jitter/gameplay
> views and differences pass. Twenty-one tests / 110 assertions and identical
> 132-cell / 188-crossing central clearance verify the added reserved storey.

> September 9 suspended-lawn review: raised turf has a closed soil bed seated
> in the actual native deck and a timber retaining frame inside its footprint.
> Its flat visual grass ends at the frame; ordinary grounded gardens retain
> their native rounded lips. Public collision is unchanged. Concave corners
> have one frame owner and outward faces. Photo 9's clear nearby views and all
> six matched differences pass; its reconstructed exact camera remains behind
> a merged-world awning. Sixteen tests / 7,654 assertions and identical actual
> collision hashes verify the photographed 16-cell lawn.

> September 9 road-end review: town gates connect to the shared perimeter.
> Only actual canonical world-road crossings extend beyond it; the primary
> gate no longer invents a house-size-dependent country spur. Handoffs reserve
> frontage before house allocation. Photo 4 and five nearby/jitter/gameplay
> views verify the removed north spur; the recorded south connection and
> four-orientation topology regressions pass.

> September 9 manual bay review: projecting facade bays and shallow jetties
> have two plain native timber knees between their parent wall and bottom
> plate. Selection checks the same complete support transforms before emission;
> they stay in the reserved lower band. Ribbed corbels remain absent. Matched
> photo 12 and nearby differences pass; 25 related tests (3,725 assertions)
> and identical clearance at 100 walk cells / 140 crossings verify the change.

> September 9 manual rail review: exterior stair beams attach inside the
> measured native landing-post profile, including its inset and floor lift,
> before reaching the ordinary guard height down the flight. The landing keeps
> sole ownership of the shared posts; tread geometry and free-end posts remain
> unchanged. Actual native-triangle sockets pass in four orientations. Matched
> photo 6 and nearby differences show the joined ends; six live gate traversals
> and 18 related tests (1,507 assertions) pass.

> September 9 manual door review: coplanar room fronts at the same floor share
> one entrance only through mutually open complete native party-wall modules.
> Partial walls, gaps and staggered floors retain independent access. The median
> usable doorway owns the joined frontage; other bays use complete window panels.
> The compiler publishes that ownership without moving rooms or public routes.
> Inline native timber joins accommodate masonry/door overhangs and continue to
> both rear reveals inside the facade envelope. Photo 3 and five nearby views/
> pixel differences pass, as do four new tests and unchanged public clearance.
> The related 45/46 test result retains the documented landmark/course failure.

> September 9 manual grass-lip review: opposing native lips on a narrow lawn
> divide their flat backs at the shared cell center. The rounded source perimeter,
> UVs and biome tint remain intact, including paired outer and inner corners.
> Main-thread preparation exports resource-free triangles; workers apply exact
> ownership. The turf field and collision are unchanged. Photo 2 and five nearby
> views/pixel differences pass; 29 tests / 12,984 assertions and identical
> 124-cell / 179-crossing surveys verify the photographed town.

> September 10 water review: standing water is limited by complete-domain
> terrain spill routes; unfilled neighbors are not outlets. Flow may occupy
> excavated ground only below both the original rendered surface and the local
> river's projected continuous profile. A distant high source cannot fill a
> lower river's excavation. Unchanged plateaus receive no excavation allowance.
> Smoothing respects physical containment while preserving flowing channel
> joins. Coarse and fine water solve the complete rectangular source domain,
> with all intersecting contributors, before chunk projection. Fine expansion
> cannot cross a point that must remain dry and seed a disconnected pocket.
> Reverse minimax queries memoize proven escape heights; the frozen full-domain
> heap and dense outlet initialization remain independent test references.
> Fine spill initialization reuses its already enumerated real anchors plus
> the outer domain boundary. Ground uses ordinary baked cell controls locally.
> The bounded terrain sample cache retains the exact original input beside
> its carved value; the uncarved compiler reuses it without recomputing noise
> or adding back a rounded subtraction. No extra terrain region is retained.
> Graphical startup temporarily limits redraws to 30 FPS, preserving a lower
> existing limit and restoring the previous setting on completion or exit.
> A later explicit frame limit takes precedence; headless limits are unchanged.
> Photos 5/7/8 and six nearby comparisons remove the reported shelves, mound
> and folded water edge while retaining lower lakes. All 26 final focused
> tests pass with 1,337 assertions. The final 120-second walk travels 822 m
> with zero frozen time; startup takes 298.923 s and remains expensive. Eight
> historical contour/skin failures remain identical to baseline. Acceptance
> is limited to the reported sites and measured route, not a green water suite.
> See `docs/qa/2026-09-09-manual/03-water/result.md`.

> September 9 manual review (in progress September 10): terrain requests retain
> ownership for an unchanged desired chunk footprint; movement rebases priorities
> without resubmitting every halo each frame. Startup handoff and chunk crossings
> publish new footprints. WaterPlan's regional carve buckets store only the
> half-open super-cell's owned terrain cells; complete river/pond discovery and
> hydraulic solve extents are unchanged. Focused red/green regressions pass;
> reported-route acceptance is limited as recorded below. See
> `docs/qa/2026-09-09-manual/review.md`.
> The rectangular heightfield compiler now uses contiguous integer arrays and
> separable cardinal clamps, checked against the original complete maps. River
> bank ownership skips detailed pond shapes outside their conservative bounds.
> Flat graded squares use two collision triangles only when every fine-grid
> height is identical; curved collision and all visual vertices remain intact.
> Requested character motion supplies bounded forward streaming deadlines before
> acceleration and while waiting; every intervening chunk participates. Exact
> noise corners use a bounded synchronized cache. Height samples evict one oldest
> entry at capacity instead of dropping the entire warm field. Source changes
> still invalidate the sample cache. Constant hydraulic targets skip redundant
> shaping; real terminal drops retain their canonical terrain region.
> Complete water solves share cache entries by their actual aligned domain and
> terrain/water owners, independent of the initiating local source subset.
> Initial loading now prepares the surrounding terrain ring, supplying at least
> one full chunk of travel in every direction. Startup duration and subsequent
> frozen time are reported separately. The reported 120-second walk now travels
> 820.5 m with zero frozen time; matched inferred-camera images show loaded ground.
> All 105 related tests pass their assertions, followed by the documented native
> shutdown failure. This accepts the reported route, not universal streaming or
> full-suite health. Long-session performance is summarized below.
> During that review, completed hydraulic profiles now release their canonical
> construction regions and retain bounded compact arrays (1,024 individually
> evicted entries). Terrain remains canonical when a profile is recomputed.
> Weak-reference, eviction and river regressions pass; production performance
> and visual acceptance are recorded below.
> Water planning also bounds individual region, source and trace memo entries;
> eviction preserves deterministic recomputation and never clears a whole cache.
> Dense grass skips deformation for dropped patches and untrampled far blades
> whose detail is exactly zero. The sun uses widened PCF contact shadows instead
> of angular PCSS; fixed-scene timing and image comparisons accompany the change.
> The 2.4 km out-and-back residency comparison ends with identical 56 terrain
> chunks and 11,541 nodes: static memory falls by 186 MB and peak by 212 MB.
> Three matched render views improve from 33.7–34.9 to 18.9–19.9 ms/frame.
> The 40 related tests pass with a clean exit. This accepts the measured retention
> and rendering fixes; progressive headless CPU slowdown was not reproduced.

> September 10 tactical-camera feature (merged, testing follow-up): the player uses a
> fixed elevated orbit (26 m horizontal, 16 m high, 50-degree FOV), independent
> of movement. Mouse rotation starts at the actual left/right viewport edge;
> only outward overflow contributes, at one horizontal FOV per viewport-width
> of drag. Returning inward and dwelling never rotate. Edge-only raw capture
> preserves the visible cursor and aim; inward motion, clicks, view switches,
> focus loss and pause release capture. Escape releases it until the next click.
> F7 switches to the original 8 m / 5 m follow/collision camera and back,
> preserving yaw and keeping the new controls in both views. Q/E remains available.
> Mouse aim projects onto the player's foot-height plane;
> camera-relative WASD and world-space facing are independent. AI controllers
> keep movement-facing unless they publish a separate aim vector.
>
> DirectionalLocomotion installs the editor-authored DirectionalAnimationTree
> with its synchronized 2D directional blend and separate idle transition. Forward walking offsets its normalized phase by 1/6 cycle;
> backward walking offsets by 3/4. Strafe/run phases already agree. Private
> animation-library copies enable actual loop interpolation. Measured stride
> lengths set directional weights and cadence. Player travel again reaches the
> original 10 m/s in all directions; short backward strides may slide at that speed.
> The character and camera share step smoothing.
>
> CameraVisibilityBubble queries rendered bounds on the main thread and adds
> a reversible material fade across a 3.8 m foreground corridor. Coverage is
> per fragment, so separate components and large MultiMesh batches share the
> same bubble without fading distant instances. It preserves the ground below
> the physical character floor independently of visual step smoothing, and
> preserves shadow rendering. Live source material uniforms remain synchronized.
> It uses dithered pixel coverage to retain
> opaque depth ordering. Custom spatial shaders retain their code; native PBR
> materials use the shared adapter. Physics and source assets are unchanged.
> CameraObstructionSolver also supplies the F7 original view and review fixtures;
> the tactical camera does not shorten its boom when a roof intervenes.
> Evidence and validation limits: docs/qa/2026-09-10-tactical/README.md.

> September 10 repository consolidation: `main` continues the September 5 evening
> village-review branch and its September 5–9 working implementation. The atmosphere
> and water/travel histories are integrated without replacing that later work.
> Bulk manual render sequences remain ignored local QA artifacts; reports, numeric
> evidence, fixtures and harnesses are versioned. See
> `docs/branch-consolidation-2026-09-10.md` for branch decisions, recovery paths and
> validation limits. Consolidation does not resolve the documented baseline
> cliff, cold-start, composition and historical-water failures.

> September 8 night manual review (completed September 9): all 18 reported
> issues plus photo 19's window/pillar detail were handled individually with
> before/after game renders, nearby views, pixel differences and relevant
> physical/field regressions. Evidence is indexed at
> `/Users/ryko/Documents/Codex/2026-09-08/i-did-a-manual-judging-pass/outputs/verification-index.md`.
> The source overlays round coordinates to 0.1 m: replay cameras match each
> other, but the original full-precision camera cannot be recovered. These
> reports establish the photographed fixes, not a globally green test suite;
> known baseline cliff, cold-start, composition and water failures are recorded
> separately in the final validation report.
>
> Native facade end ownership now distinguishes a measured retaining miter
> from a room miter. The offline baker handles unindexed source triangles,
> closes the referenced cut faces and removes only explicitly shared jetty
> ends. Floor subtraction assigns coincident boundaries to one owner using a
> 1 micrometre classification tolerance without moving source vertices. A cap
> wholly owned by a room floor emits no remainder; test censuses must verify
> the real floor triangles before crediting that logical boundary. Window 010
> explicitly opts into fitting its complete panel into a deep doorway return;
> bake version 31 preserves its height, relief and UVs before ordinary joints.
>
> Shallow outcrops use their actual supported projection. Flower anchors sit
> above the soil inside their reserved planter. Stair guards subtract the
> completed wall envelope, including hanging courses; exposed portions retain
> collision. Ends receive taller posts and each face has nondegenerate UVs.
> Terminal rising flights reserve a supported 2-by-2-cell overlook, including
> its headroom, before later construction. Raised exterior entrances reserve
> the complete flight and clear approach before selecting their direction.
>
> The long bridge's authored collision follows its arch and preserves the
> bank handoff under longitudinal scaling. Swimming aborts an active jump
> one-shot so the underlying animation continues. Roadside lamps sample the
> final graded ground at their declared contact. Complete-house path contacts
> distinguish the real porch toe from the entrance and support rectangle.
> House 001 keeps its native door leaf posed open around its authored hinge;
> its baked collision leaves the doorway traversable.
>
> Streaming rebases urgency from physical proximity and bounded velocity
> lookahead. Terrain requests publish feature-halo dependencies immediately;
> those dependencies inherit their waiting terrain's urgency and can finish
> separately from distant terrain work. Fine-grid vertex reuse and conservative
> local path samplers preserve geometry and collision. Both reported running
> approaches cross with zero frozen frames; the unrelated 60-second cold-start
> test still fails in the preserved baseline.
>
> Sub-lattice water rescue uses untapered hydraulic levels and a fixed one-ring
> witness from originally wet coarse nodes. Complete source-fill extents obtain
> every intersecting river/pond through `WaterPlan.bodies_in_rect`; a larger
> solve must not use only the initiating chunk's river inventory. This prevents
> a missing distant river constraint from sending high water onto lower land.
> Ground-grade collars compose smooth compact influences from maximal
> rectangles of the exact claimed-cell union. They preserve the ordinary 12 m
> straight-pad profile and fixed pad heights while removing nearest-edge cusps.
>
> Non-collidable bushes explicitly request `visual_ground_support`; the compiler
> prepares their native base stencil on the main thread and the ordinary tree
> support checks reject cliff/slope overhangs. All six bush assets use the existing
> biome-canopy hue replacement. Bush palette colors blend absolute tree and
> substrate colors, never the ground texture's relative color multipliers.

> September 8 independent porch review: an authored ground entrance may
> declare the measured toe of its native porch separately from its placement
> datum and conservative foundation rectangle. The SFV 006 approach now ends
> at that real tread. Physical tests cover both themes in four orientations;
> seven related tests pass with 6,231 assertions. Matched photo 9, nearby
> pixel differences and six strict live porch traversals verify the cleanup.

> September 8 river-bank review: gentle reaches
> widen the terrain carve through the ordinary ground kernel; steep descents
> and their abutments retain the established narrow profile. A bounded cache
> holds deterministic bank strengths. Banks constrain water without becoming
> water seeds; terminal lakes retain their connected shore domain. Fine water
> topology uses the same dry-bank constraints and 64-bit queue labels. Adjacent
> water trigger boxes overlap by 1 mm per side, while the frozen sampler still
> owns exact wetness. Matched photo 10 and nearby pixel differences pass;
> four shoreline traversals stay grounded, and six neighboring-town entrance
> traversals pass. The 95 related tests pass with 18,896 assertions.

> September 8 garden-border review: a connected facade bank chooses one
> shared outcrop profile from its reserved clearance. Shallow caps fit the
> actual projection instead of borrowing the full gallery depth. Photo 1,
> nearby angles and pixel differences pass; all 140 west-town walk cells and
> 205 crossings retain identical clearance. Photos 11/12 remain clean.

> September 8 gate-paint review: the ground handoff shares the exterior road's
> 4 m painted width. The two-cell structural aperture retains its complete
> stair, walk and headroom reservation. Photo 5 and nearby pixel comparisons
> verify removal of the intermediate wide tabs; rotated and connected-gate
> regressions pass.

> September 8 door-path review: complete prefab houses address the measured
> doorway center. Their closed-leaf attachment keeps its authored hinge origin;
> those are distinct coordinates. Photo 6, nearby views and pixel differences
> verify the centered approaches; all seven houses in four orientations retain
> physical jamb clearance.

> September 8 destination review: a terminal rising stair reserves an available
> neighboring platform and its open sky before bridge compounds and house plots.
> The unchanged climb meets a larger guarded overlook where adjacent room floors
> cannot supply a real doorway. Source reservations survive final construction;
> photo 8 and nearby renders, 12 walking traversals and 128 clear walk cells /
> 185 clear crossings verify the photographed town.

> September 8 stair motion: step-up samples the actual horizontal destination.
> A short ray at an ambiguous capsule contact verifies the tread's real top;
> it never supplies a future tread height. The normal step-limited floor snap
> retains an 80 ms witness across rounded tread noses. Character presentation
> and camera share one critically damped height response; animation uses the
> same grounded witness, while jumps and real ledges remain airborne. All five
> photographed flights pass streamed ascent/descent; normal and slow side-lane
> runs pass, alongside jump, ceiling, obstacle and animation regressions.

> September 8 exterior finishing: closed doorway return cuts survive shared
> corner ownership. Native timber closes miter cuts; authored stone relief
> finishes deep rock-door ends inside the original envelope. Retaining banks
> use stone-only stock fitted to their declared joining bounds; isolated free
> shoulders continue masonry. Ledge caps use horizontal boards with exact
> private-floor ownership and main-thread source preparation. Matched photos
> 3/4/9 and nearby pixel comparisons pass; photos 7/11 retain their earlier
> repairs. Physical clearance is unchanged across 124 cells and 179 crossings.

> September 8 inline facade joins: adjacent room runs with different authored
> depths declare one recessed timber seam member inside the existing room
> envelope. The native mesh closes the full course in all four orientations.
> Photo 7 and nearby pixel comparisons pass; physical clearance is identical
> across 124 walk cells and 179 crossings. Perpendicular ends remain under review.

> September 8 doorway caps: full-height door panels publish the same exact
> floor-cap ownership as other facades. A 5 mm base-datum allowance includes
> imported door feet; top-face clipping retains its 1 mm tolerance. Photo 11
> and the actual shared-triangle regression verify the balcony overlap.

> September 8 floor placement: single-cell authored boards receive the logical
> cell center; their asset pivot is corrected exactly once. Larger board unions
> retain their union centers. Courtyard paving uses the same convention, matching
> the existing collision boundary. Photo 12 and nearby matched pixel comparisons
> verify the overlapping floor strips; exterior trim remains under review.

> September 8 morning review (in progress): raised exterior portals now declare
> an architectural flight and a full lower landing before outskirts frontage
> allocation. The same gate geometry supplies its street contact and occupancy;
> the public surface compiler opens the declared landing seam. A raised platform
> does not force its height into adjacent fine-grid ground controls. Gate flights
> reuse the ordinary stair builder and assign shared posts once. The new frozen
> west-town regression fails before and passes after in four orientations.
> Matched photos 2/13 and nearby views remove the ground spikes; both approaches
> pass six streamed ascent/descent checks each, and 64 perimeter cases pass.
> Stair motion and other surface joins remain separate open issues. Do not treat
> the rest of the September 8 morning issue list as fixed.

> September 8 manual slope review: extending streets preserves the existing
> continuous TerrainGradePatch field instead of sampling a second conical ramp
> into 3 m plateau controls. Foundation additions retain fixed pad heights and
> inherited street fields; bounds compose those same fields. The ordinary
> terrain kernel and 12 m collar remain the only slope authority. A bounded
> 64-bit target/weight cache preserves exact cold samples and natural inputs.
> The September 7 sixth-photo views, normal-profile regressions and streamed
> ascent/descent pass; all five public stair flights remain walkable.

> September 8 manual garden-wall review: roof solid cells reserve clearance,
> but do not occlude neighboring vertical retaining skins. Room mass still
> closes those seams. Retaining course style follows the complete bank even
> when a neighboring room hides its lower portion. Payload and panel clearance
> share the final shell. The September 7 fourth photo, nearby views, actual
> wall meshes and unchanged public clearance verify the reported garden wall.

> September 7 manual stair review: transition tread count respects the planned
> world-space step limit after scale and the shared ground-datum guard. A 3 m
> flight now has eight 37.5 cm risers; the first ground approach totals 45.5 cm.
> Landings, flight footprint and player step limits are unchanged. The frozen
> ground-handoff walking regression fails before and passes after; matched
> streamed walking verifies all five public flights without jumping, alongside
> all original photo angles in `04-stairs-after` and their pixel differences.

> September 7 manual street review: the exterior circuit owns the town's
> ground street domain. Independent country-road paint yields inside it;
> incoming lattice arms publish boundary handoffs before frontage allocation.
> Town streets retain priority and outside country roads remain unchanged.
> The frozen photographed frontage has one 4 m street, unchanged house access
> points, and three connected world-road handoffs. Four-orientation tests and
> matched `03-path-candidate` views/pixel differences pass.

> September 7 manual floor review: private room floors participate in retained
> ground-cap ownership. Partial caps and upright wall tops use the existing
> exact triangle ownership, retaining uncovered source coordinates, UVs and
> collision. The offline wall-interface manifest declares a 1 mm imported-face
> tolerance; construction matches the declared course plane. Resource-free
> interface arrays are prepared on the main thread. The photographed floor
> overlap regression and matched `02-floor-candidate` views pass; cell/crossing
> clearance remains identical. Other manual issues remain under review.

> September 7 manual wall review: neighboring generated room shells own their
> shared corner. Diagonal contacts retain square ends into one timber joint;
> inside corners use a native wall return between the rear reveals, with both
> slab thicknesses projected along the meeting angle. Masonry corners include
> inhabited room volume. A low retained shoulder can carry a one-band return
> between taller masonry and a diagonal house; it requires its existing bearing
> and cannot consume an owned walking surface. `test_september7_wall_enclosure.gd`
> covers the photographed source, four orientations and absent-bearing cases.
> The matched `docs/qa/2026-09-07-manual/01-gaps-after` views and pixel differences
> verify the reported gaps. The full photographed town retains identical
> clearance across 124 walk cells and 179 crossings. Photo 2's reconstructed
> camera is behind the closed return; separately matched side views and the
> production collision-resolved camera record that distinction. Other issues
> from this manual pass remain under review.

> September 7 entrance construction: each exterior portal keeps its own transverse
> coordinate until it meets the shared perimeter. Secondary entrances must not snap
> to the primary entrance's lattice phase, which creates diagonal paint notches.
> Completed physical clearance is inspected by `perimeter_gate_corpus.gd` (four
> seeds, four scales, four orientations; 64 completed cases). The matched `perimeter-straight-gates-after` views
> confirm the reported junction and entrance edges. Roof gardens, as well as pitched
> roofs, use the remaining space after fixed ground-frame columns are reserved.
>
> September 7 column construction: provisional upper bands continue their declared
> bearing column and end at its available height. Lateral packing retries are removed;
> the room grammar owns explicit supported changes of floorplate. The (16,-201) roof
> regression and the production corpus verify this independently.

# Project Instructions (AGENTS.md)

> September 26 town architecture: lot houses use reserved-footprint L/T plans,
> independently stepped upper floors, railed crown terraces with doors, and
> multi-cell projections with corner posts (`KitStandaloneHouse`). Twelve lot
> variants mix cottages, medium/tall houses, varied widths/depths, rear setbacks
> and narrow upper floors. Exposed overhang edges have continuous timber beams;
> sheltered canopies are frequent, with entrance priority and footprint spacing.
> Each separate terrace gets a doorway and rail-side pots. Their street-facing
> main roof wing is selected before rear wings so cross gables cannot pierce
> a lower host ridge. Sealed warren floor ownership stays planner-authored.
> `BuildingDesigner` adds more canopies, flowers, ivy and roof details.
> Suntail's historical red/blue roof IDs now bake warm/weathered wood board
> albedo and normals through manifest `material_textures`; do not restore
> coloured tile textures during a rebake. Review and validation are recorded
> in `docs/qa/2026-09-26-town-architecture/result.md`; larger projections:
> `docs/qa/2026-09-26-town-projections/result.md`; size/beam/canopy follow-up:
> `docs/qa/2026-09-26-town-silhouettes/result.md`.

> September 26 city junctions: `KitRoofJunctions` reconciles compatible roofs
> across house ownership; `KitRoofMeshUnion` trims native triangles at roof,
> wall and public-headroom intersections with matching collision. Unchanged
> pieces remain instanced. Rebuild its worker data with
> `tests/harness/suntail/bake_roof_geometry.gd` after kit geometry changes.
> Boring retains short supported ground tunnels; owned ceiling slabs survive
> composition and receive timber closures. Bridge-house quotas allow two more
> supported spans per scale. These are geometry/seed rules, not site exceptions.
> Review: `docs/qa/2026-09-26-town-junctions/result.md`.


> September 7 support construction: cantilever courses select one authored
> profile from previously reserved feature envelopes. They share one timber
> frame and no longer enumerate 2^N course combinations or backtrack across
> the town. The frozen exhaustive solver is test-only; all 16 mixed-course
> cases match it, and the 48-town physical clearance corpus remains clear.
> Compact bracket clearance is independently audited by tests.
>
> Graded streets own their full width before house pads. Graded cliff backing
> and authored rock vertices use the same final height field; fully collapsed
> rock triangles are omitted. Main-thread preparation extracts resource-free
> source arrays for worker deformation. Immutable regions memoize repeated
> grade-influence queries for authored piece bounds.
>
> September 7 perimeter follow-up: the owner requests one constant-width
> exterior circuit and a shared approach junction. `VillageOutskirtsConstruction`
> derives four straight frontage sides from the finished town envelope and
> places houses directly along them. Reserve the incoming approach before
> consuming frontage intervals. `FeatureGroundField.construction_clearance_bounds`
> includes the canonical road lattice as well as explicit shapes. Every street
> has the same 4 m painted/headroom width; conservative final-ground extrema
> bound its headroom. Old cliff aprons disappear wherever grading closes the
> discontinuity. The matched `perimeter-clean-after` overhead and ground views
> pass visual review for the reported spurs, width and staggered junctions;
> broader validation remains in progress.

> September 7 water/travel follow-up: a terminal `PondStamp` caps its natural
> bank datum at the incoming river's hydraulic surface; its carved bed follows
> that same datum. Never reconcile a new lake by raising kilometres of an
> already-descended river. `WaterField` solves complete in-context source
> extents before projecting the normal 42m chunk halo; a bounded CPU cache
> shares those solves. Current-geography seam regressions are separate from
> historical screenshot fixtures. Fully flooded chunks emit water even when
> no shoreline crosses the chunk. The source solve remains finite; the border
> survey reports wet domain edges as well as shared-chunk disagreement.
> Streaming requests retain ownership through
> the worker-to-main hand-off, skip unchanged queue mutations, and rebase
> priorities as the player travels. Urgent feature dependencies can publish
> before their distant terrain component. `PROFILE_STREAMING` enables bounded
> queue/phase diagnostics; `tests/harness/travel_profile.tscn` provides real
> walking, separately labelled obstacle-bypassing traversal, and fixed-camera
> graphics ablations. The 49-chunk profiler now includes production grading.
> These measurements identify expensive graded/path subdivision and collision
> commits; they do not establish that construction or rendering is fully optimized.

> September 7 room-band follow-up: paired rooms are constructed by ascending
> absolute floor band from current lower plates. Existing upper contacts bound
> their room domain. When an upper plate moves, its newly exposed lower roof
> immediately reserves its air before another lineage can use it. Frozen source
> regression fixtures include bridge-span ownership and frontage reservations,
> as those are construction facts even where old field names say `audit`.
> Ground-frame posts explicitly publish their single `post` flashing placement;
> only the measured narrow member and a named supporting-room roof can join.


> September 7 shallow-roof follow-up: one-sided roof skins publish an explicit
> `FabricRecipe.roof_high_edge` and use their occluder cells as the construction
> footprint. Their measured high edge meets the wall, transverse centre matches
> the cell run, and underside meets its bearing datum. Complete crowns retain
> their symmetric solid-volume contract. Two-cell runs centre at 0.75 m, not
> 1.5 m; all lengths/materials and deliberately shifted negative fixtures are
> covered by `test_shallow_roof_contract.gd`.


> September 7 frontage follow-up: finite house intervals are consumed from
> one end, preserving contiguous space for the next house without trial
> placement or repacking. Door paths meet their house's support boundary;
> test positive overlap separately from inclusive boundary contact.
> Historical building regressions keep frozen CPU source facts in
> `tests/fixtures/*source.txt` and run those through the current compiler;
> production does not read those fixtures.


> September 7 atmosphere rebuild: seven art-directed biomes retain the five
> historical content IDs and add `amber_heath` and `jade_wetlands`; display names
> are Sunwash Meadows, Lanternwood, Opal Highlands, Cherryveil, Moonfen, Amber
> Heath and Jade Estuary. `Helper.biome_weights5` is a compatibility name for
> seven normalized weights. Mood never changes the global sky, sun, fog or
> ambient light at the player's position. `BiomeAtmosphereField` samples the
> actual ground and continuous biome blend into CPU arrays; `BiomeChunkFx`
> commits world-space mist, grounded particles, exact-water fall spray and
> moving spirit lights on the main thread. Adjacent mist chunks share boundary
> samples. `BiomeGroundMap` projects the same field onto a canonical 48m grid
> in a bounded 3072m render window; 768m scrolls preserve overlapping samples
> exactly. Terrain, lips and grass share `ground_style.gdshaderinc` and the
> palette's real texture; paths and rock retain their distinct atlas texels.
> Canonical substrate colours live in `BiomeRegistry.SUBSTRATES`, with moss,
> chalk, silt, petal litter and amber earth detail resolved in world space.
> Tree materials use a manifest-declared `biome_canopy` hue replacement that
> preserves bark, including at bake time. Ground-cover grass remains beneath
> woodland canopy; the separate ecology/feature fields still own empty paths.
> `LandformField` contributes deterministic 768m geological provinces to BOTH
> natural ground and river descent (scarps, amphitheatres, terraces, mesas,
> ridges/passes, hollows and clefts). Production amplitude is 32m. Large lake
> stamps may preserve natural islands or peninsulas through their shared carve;
> no water-only decoration or second terrain authority is added. This changes
> seed geography. Construction must retain the owner's single-town policy.
> F6 cycles the biome review locations; F4 retains the existing review list.

> September 6 construction policy (owner instruction): a settlement generates
> one deterministic town and one world placement. Do not use audits to erase
> towns, retry terrain placements, or rebuild an optional alternate town.
> Construction defects belong in regression/corpus tests and must be corrected
> in the generator's space reservations and ownership rules. The production
> adapter now aligns its single primary gate and publishes the sealed grade
> patch; it no longer re-solves a flat preview against trial terrain quarters.
> Road connectivity does not control whether a settlement exists. The compiler
> now exposes `generate()` separately from the explicitly checked `solve()` and
> `validation_errors()` used by tests. `WarrenVolumetricSolver.generate()` is
> the production entry; its diagnostic `solve()` additionally collects the
> full-town module, foundation, masonry, terrace, and material audits. Payload
> assembly no longer revalidates a complete town or each generated payload.
> Unassigned-mass, route-overhead-supply and plot-mass scans run only when
> diagnostics are requested. Their pre-discard inspection does not supply
> construction facts. A parity regression requires identical construction with diagnostics enabled
> and disabled. The remaining lower-level construction
> searches and mixed seal/audit methods are still being migrated; this work is
> not yet accepted as a complete removal of runtime checks or retries.

> September 7 construction follow-up: production outskirts now use
> `VillageOutskirtsConstruction` and `VillageFrontageDomain`. Measured house
> envelopes subtract occupied space from continuous frontage intervals before
> a lot is selected; each selected lot emits one house and a flat grade pad.
> Different pad datums reserve disjoint footprints. The substantial-house
> cohort precedes smaller infill, and every final lane samples the completed
> grade. Inset porches own the walk from the outer base to the door; terrain
> paint stops at that base. Shared T/X junctions derive both inner curves from
> all declared street arms. Landings shorter than a path half-width stay square
> so capsule ends cannot overrun a doorway. The old outskirts trial solver is
> retained for legacy tests but is no longer called by `VillagePlan`.
> Deep door panels now keep whole ends, while perpendicular returns terminate
> at the measured doorway back plane. `export_door_return_manifest.gd` discovers
> the finite square/miter/back-plane alternatives offline; ordinary asset bake
> produces their visuals and collision. Suppressing an end owner withdraws its
> return cut. These choices retain the original conservative envelope. Matched
> doorway/facade review is still in progress; do not report it accepted yet.
> Terrain screenshot regressions additionally pin the original reported field
> in `tests/fixtures/september6_reported_terrain.json`, because the atmosphere
> rebuild intentionally changes seed geography. Exact historical screenshots
> use the original-world review copy; current-world tests remain separate.


> September 7 roof/support follow-up: actual unsuppressed placement bounds
> resolve connected-component clearance; broad boxes alone cannot create a
> false collision across empty space. Joined crowns choose the existing tight
> transverse profile when their eave belt contains allocated construction.
> Fixed ground-frame columns reserve their space before roof choice. Frames
> are built from low bearings upward and publish bearing through connected
> private mass; thin posts never pretend to fill a complete structural cell.
> Posts stop at private ceilings. A post may cross only its named bearing
> room's roof skin through the existing measured shallow seam contract.
> Canopies and roof trims explicitly name their flashing placements; furniture
> in the same recipe does not inherit that joint. Native compound L-shaped
> roof partitions retain complete return stamps. Interstitial infill consumes
> only cells outside mandatory roof space. `construction_diagnostics()` inspects
> existing construction without changing its audit, signature, or placements.
> The final court retry/rejection loop and court-selection room preflight are
> removed. Bridge endpoint crowns retain their explicit party-seam role ahead
> of neighborhood silhouette choices; even-cell roofs retain the phase-aligned
> floorplate center in both source reservations and final placement. Prospective
> party contacts derive from canonical room cells, independent of emitted faces.
> The 46-site regional corpus passed after those changes. Subsequent bearing
> work is under regression review: occupied contacts above a room constrain
> its floorplate domain. Exposed tops and undersides reserve their vertical
> interfaces before neighboring room variants are selected. The eight-sweep
> support repair/building-deletion routine is removed; production also no longer
> invokes repeated silhouette relief, crown truncation, or global roof repair.
> The six unused silhouette/crown repair helpers now live exclusively in
> `tests/fixtures/legacy_room_repair.gd`; their five regression tests remain.
> Source reservations and final roof construction share one canonical roof
> domain. Ordinary terminal rooms start with their complete house crown;
> bridge endpoints retain only their explicit party-seam profile. The duplicate
> second full-roof fallback pass is removed. The current 48-town scale corpus
> builds every town with 10,672 clear walk cells and 15,216 clear route gates.
> Roof asset selection and earlier construction searches still contain retries; do not report the
> owner's no-retry requirement complete yet.

> The maze carver now freezes its completed excavation and source directly.
> `WarrenExcavation.validate_construction()` retains the independent route,
> headroom, portal, loop and bridge checks for tests; it cannot withdraw a
> published walk. Source diagnostics are optional and preserve the same
> deterministic signature. Earlier alley/loop preview checks remain to migrate.
> Maze-to-volume projection similarly derives its exact walk surface and mass
> subtraction without a final validation gate. `WarrenVolumePlan` retains a
> separate diagnostic validator; optional diagnostics cannot alter the bore,
> mass or deterministic signature. Legacy checked volume callers still exist.

> Court corner closure derives its available cells from both structural solids
> and inhabited room volume. A supported gap beside a court is not public
> floor when a room owns either of its two headroom bands. The seed 2 grand
> town regression covers the former accidental paving beneath a room chimney.

> Wall-course surface ownership is under visual review. Full-height generated
> room facades select finite `.course_open` assets only when an actual upper
> floor overlaps their cap. The floor owns its exact rectangle; pure
> `FabricSurfaceOwnership` partitions the original baked cap triangles and
> retains every uncovered portion, including millimetre-wide ends, with its
> original material and interpolated UVs. An exposed roof shoulder retains
> the original complete wall. `export_wall_interface_manifest.gd` discovers
> the finite alternatives; the offline bake also publishes the omitted source
> triangles as resource-free data. Perpendicular end ownership remains independent. Do not accept
> this change until the pinned stacked-facade overlap tests and matched gallery
> renders pass and nearby roof shoulders remain closed.

> Alley and loop construction now publishes each chosen connection once.
> `WarrenExcavation.frontage_reservations` preserves housing beside existing
> streets before later excavation; the size profile supplies the lane budget.
> The former completed-lane frontage audit, whole-volume preview, rollback,
> and next-candidate retry are removed. Source tests and the sloped frontage
> regression pass; full composition review is still required. Other source,
> roof, and room selection searches have not yet all been migrated.


> September 5 evening facade follow-up: generated-room miter choices carry
> explicit perpendicular end-owner placement IDs in `FabricRecipe`. Final
> placement expansion withdraws a cut when its owner is suppressed as a party
> wall; demand discovery includes the finite square/single/double-end choices.
> These choices remain inside the original uncut conservative envelope. This
> change is under visual review; it must not be reported as accepted before
> the matched doorway screenshots pass.

> September 6 facade follow-up: timber plain/window/door families now bake the
> same finite corner choices as masonry. Full framed panels own their joins;
> the renderer no longer adds coplanar room stitch posts or extra portal jambs.
> Unrelated combined clearance boxes use the actual module-bound union as a
> narrow phase, so empty space between a floor and an ornament is not treated
> as a solid room corner. The matched evening captures remain under review;
> street handoffs and some facade joins are still open issues.

> Keep this file current. When the architecture, conventions, or core invariants
> change, update it in the same change.

## What this project is

**MythosUnwritten** (Godot project name "Story"; repo `Acciorocketships/mythosunwritten`).
An open-ended, turn-based fantasy RPG conceived as an LLM-driven **world simulator** —
every non-player character and the world itself are meant to be agent-driven, with
narrative emerging rather than scripted. See **`docs/mythosunwritten-master-design.md`**
for the full vision; that document is the design north star.

- **Engine/language**: Godot 4.5, typed GDScript.
- **What exists today**: an infinite procedural terrain world plus a controllable,
  physics-driven character (walk, jump, step-up, swim) with an orbit camera. The RPG /
  combat / agent layers in the master design are not built yet.

## Quick commands

- **Run the game (windowed)**: `godot --path /Users/ryko/story`
  The terrain streams forever around the player, so a run does **not** self-exit — stop
  it with Ctrl-C / closing the window. For automated verification prefer the tests and
  the harness scenes below over a bare headless run.
- **Run all tests (GUT)**: `godot-test` (a shell alias for
  `godot -d --path /Users/ryko/story -s res://addons/gut/gut_cmdln.gd -gconfig=res://tests/gutconfig.json`).
  Tests live in `tests/`, are named `test_*.gd`, and `extends GutTest`.
- **After moving/renaming a `class_name` script**: run
  `godot --headless --path /Users/ryko/story --import` once so Godot rebuilds the global
  script class cache; otherwise headless runs fail with "Could not find type X".
- **Profile terrain generation**: `godot --headless --path /Users/ryko/story -s res://tests/harness/profile_terrain.gd`
  prints per-phase build timings (49-chunk startup sweep + phase attribution). Paste the summary
  into perf-related commit messages.

## The core invariant: field-driven, deterministic, churn-free

Terrain is a **pure function of `(world_seed, point)`**: a 12 m lattice point's final height
is decided before any geometry is instantiated, and every 12 m tile is a function of its four
corner points alone, so tiles never retile, morph, or pop as neighbours stream in. This is the whole point of the current architecture — it replaced an older
socket / module-catalog engine that grew terrain reactively and needed reveal margins and
churn suppression to hide the settling. **That socket engine is gone.** If you find docs
referring to `TerrainGenerator`, `TerrainModule*`, sockets, `WaterRule`, `PositionIndex`,
or generation "rules", they describe the retired system (see "Historical docs" below).

Keep the worker pipeline pure: plan, field, mesher/dressing `compute*` methods return
plain CPU-side data and are headless-unit-testable. Render/physics resources and nodes are
created only by the explicit main-thread `commit*` adapters; only `FieldTerrainStreamer`
attaches those nodes to the active scene tree. Never create `MeshInstance3D`, `MultiMesh`,
`ArrayMesh`, collision shapes, or other server-backed resources in the streamer worker.

## Terrain pipeline (`scripts/terrain/`)

Data flows: **HeightfieldPlan → HeightfieldRegion → TerrainTileField → TerrainChunkMesher**
(with the cliff sheet from **CliffRockDressing / CliffSlopeField / CliffSlopeEnvelope**), plus
sibling **WaterSkin** and **DressingField** payloads, driven per-chunk by **FieldTerrainStreamer**.
Two lattices coexist and must not be confused: terrain heights live on **POINTS 12 m apart**
(`HeightfieldPlan.POINT`; a 192 m chunk owns points `16k .. 16k+15` per axis); the **24 m CELL**
(`HeightfieldPlan.CELL`, `TerrainChunkMesher.CELL`, `PathProgram.ROUTE_CELL`) is only the route,
settlement, biome-tint and grass-tile lattice (2 x 2 tiles). The spec is
`docs/superpowers/specs/2026-09-30-dual-grid-terrain-tiles-design.md`.

- **`heightfield/HeightfieldPlan.gd`** — the deterministic plan. A continuous height field
  `H(x, z)` (layered value noise + rocky-biome mountain spines + `LandformField`, faded flat near
  spawn, minus the river carve) is sampled at every lattice point `(i, j)` = world `(12 i, 12 j)`
  and quantized into integer **storeys** (4 m each) and sub-storey **levels** (1 m, 0..3). A
  monotone trickle-down **clamp** lowers each point to at most `max_step` storeys above its lowest
  cardinal neighbour point; levels clamp to one level above the lowest same-storey neighbour. The
  clamp has a unique, order-independent fixpoint, so results are seed-stable.
  `compute_region(ci, cj, radius)` / `compute_rect_region` take POINT indices and return a
  `HeightfieldRegion`. Per-point noise+carve samples are **memoized on the plan instance**
  (`_sample`, cleared by `set_raw_height_override`/`set_water_plan`) — a pure-performance cache,
  output-identical. `raw_height` / overrides are keyed by points (multiply by `POINT`, never 24).
  `static var LOWPASS_M` (default 0 = off, byte-identical) is the spec's low-pass knob: when set
  before any plan samples, `natural01` is a separable (1,2,1)/4 tent over offsets {-r, 0, +r} of
  the natural height (the carve is never filtered; `WaterPlan.noise_h` and `SettlementPlan` site
  scoring follow it, river routing `smooth01` does not). This remains the immutable natural
  planning input. A sealed village publishes a finite `TerrainGradePatch` on its 3 m
  construction lattice; `WorldFeaturePlan` supplies it before final terrain sampling; it never
  mutates the natural plan or changes a loaded point in response to streaming neighbours.
  - **Levels are rendered** (`RENDER_LEVELS = true`): a 1-3 m step between same-storey points is
    a LEVEL edge and uses the same smootherstep tile profile as a one-storey slope. Levels never
    make walls.
- **`heightfield/HeightfieldRegion.gd`** — precomputed per-point storey/level dictionaries with
  O(1) `storey_at(i, j)` / `level_at` / `surface_height` / `has_surface_point` (point indices). Its
  final graded view (`FeatureContext.graded_region`) resolves sealed village grades through
  `NativeTerrainGrade` into **per-point controls** (`native_control_heights`, keyed by point):
  every corner of every 12 m tile a fixed pad claim touches is a pad owner at the pad datum (the
  lowest datum wins a corner two pads share, so a higher pad within one tile of a lower one is
  not flat — accepted and pinned by a contract test), which makes every isolated pad flat at
  every point inside it (a tile stays within its corners; the old support fixpoint is gone).
  Accepted road edges expand to their two point edges (the middle point of a 24 m route edge is a
  free road point); roads are relaxed last (lowered to one storey above, then raised to one
  storey below a neighbour) and `_relax_free` pulls free points back toward natural until no new
  cliff edge separates free points. Relax/road reach is one 24 m cell (`REACH`) inside the 48 m
  `NATIVE_CONTROL_MARGIN`. `TerrainGradePatch` itself samples targets through `TerrainTileField`
  on a half-claim-pitch minimum lattice (claim centres + edge minima), so the lower claim stays
  flat and owns no transition. Terrain, collision, grass and the cliff sheet all read the same
  final controls through the kernel. Natural maps remain available for site and parcel
  selection.
- **`field/TerrainTileField.gd`** — THE terrain kernel (static, worker-pure). Each 12 m tile
  between four points is a function of its four corner heights alone: `height = t0 + Σ gap_n *
  layer_n(u, v)` over the corners' distinct heights, where layer n sees a BINARY tile (corner >=
  t_n). Edge categories (`edge_category`): FLAT, LEVEL (same storey), SLOPE (one storey), CLIFF
  (two or more storeys; `is_cliff_edge`, high side `is_wall_edge`); `is_walkable_edge` is exactly
  "not a cliff edge". Slope layers are `bilinear(corners, S(u), S(v))` with `S` = smootherstep, so
  a one-storey step spans one whole 12 m tile. Cliff layers step at the tile MIDLINES, so every
  wall is vertical and lies on a dual-cell border `x|z = 12 i + 6`; a three-storey cliff is one
  12 m wall. Saddles keep the two high corners as separate bumps (`max(bump_a, bump_c)`; cliff:
  two 6 x 6 m squares meeting at the centre). A layer mixing cliff and slope crossings is a cliff
  END: `static var cliff_end` selects **E2 (default: wall to the tile centre, then a compact ramp
  fanning out to the slope profile; the high side never dips)** or E1 (Coons-blended inside the
  tile; selectable for the gallery). Non-crossing tile edges count as slope ends inside a mixed
  layer (ruling). Along any tile edge the surface depends only on that edge's two endpoints, so
  neighbouring tiles agree by construction; walls are the only double-valued places. Ownership:
  `point_of(v)` = `floori(v / spacing + 0.5)` (the midline belongs to the + side);
  `surface_y_on_side(region, x, z, owner)` resolves a wall to the owner's side; `bake_point` /
  `sample_baked` are the mesher's per-point hot path. `wall_segments(region, rect)` is the exact
  wall outline: one entry per 6 m half-segment of a border where the owners differ (ends `a`/`b`,
  owners `high`/`low`, `top`/`bottom`, unit `normal` high -> low); the mesher skirts, the cliff
  sheet's foot lines, grass and water all read walls from it. `height_bounds` /
  `height_bounds_on_side` are conservative extrema (exact on flat, slope-only and pure-cliff
  tiles; a mixed layer contributes its whole corner range). Village helpers: `edge_profile` /
  `own_edge_profile` / `is_exposed_edge` (`EXPOSE_EPS` 0.25) sample one dual-cell border;
  `transition_weight` is the one smootherstep profile over a width (default 12 m).
  `spacing(region)` lets a region expose another lattice (`terrain_tile_size()`, village benches
  at 1.5 m). Properties pinned by `test_terrain_tile_field`: single-valued off walls, edge
  profiles from endpoints only, all-slope tiles equal the bilinear formula (saddles excepted),
  each tile stays within its corners.
- **`field/TerrainChunkMesher.gd`** — builds one chunk (192 m, 16 x 16 points, sampled on a 2 m
  grid that has a line on every wall). `compute_chunk()` produces CPU-side mesh arrays, collision
  faces and the cliff/rock payload on the worker; `commit_chunk()` turns it into the chunk
  `Node3D` on the main thread. Every 2 m quad is pinned to the point owning its centre
  (`bake_point`/`sample_baked`), so no quad straddles a wall. **Skirts** come from
  `wall_segments` over the chunk's owned dual-cell rect, emitted only by the chunk owning the
  wall's HIGH point (exactly once across chunks), sampled at the sheet's own 2 m vertices: a
  vertical quad from `surface_y_on_side(high)` down to `surface_y_on_side(low)`, doubling as wall
  collision. There is no lip clip, inner-corner tuck, apron or native KayKit piece on world
  terrain. The walkable collision sheet is a raw `PackedVector3Array` fed to
  `ConcavePolygonShape3D.set_faces`. `field_normals` light the sheet with the exact field
  gradient, continuing across seamless dual borders and one-sided at walls. Path paint keeps the
  24 m road cell (`roundi(c / CELL)`) for `features.surface_at_cell`. `mesher.water_blocks` is
  set by `FieldTerrainStreamer` to the worker's `WorldFieldBlockCache` (when it `serves` the same
  plans), so the cliff sheet reads neighbouring water from the shared field cache instead of
  rebuilding it per chunk. Its scale-independent `field_ground_surface()` adapter runs the same
  kernel over any sealed lattice region: village turf and plaza caps use it through
  `LatticeTerrainSurfaceRegion` (1.5 m columns exposed as points; walls on column faces), with
  the same ground-palette UV, biome tint and collision authority as streamed terrain; its
  cache-only lip helpers (`_clip_vert`, `_cell_clip_info`, `LIP_INSET`) exist for village rims
  only. Village code must not rebuild grass panels or infer logical owners from slope sub-quads.
- **`field/CliffRockDressing.gd` + `CliffSlopeField.gd` + `CliffSlopeEnvelope.gd`** — the only
  world cliff dressing (`CliffRockStyle.PRODUCTION = "sheet_bedrock"`; retired style names fall
  back to it). `CliffRockDressing.compute(region, chunk, seed, features, water, water_blocks)` (`water_blocks`
  is the worker's shared `WorldFieldBlockCache` used for neighbour water, a pure perf wiring
  `FieldTerrainStreamer` sets as `mesher.water_blocks = _fields`) takes the foot
  lines from `wall_segments(owned.grow(24))`; `CliffSlopeField` splits each segment where its
  top/bottom change and adds outer-corner arcs. `CliffSlopeEnvelope` is a rounded envelope of
  the terrain itself on a 0.5 m world grid (crest scan lines at `12 b + 6`), with ridges,
  bedrock, the foot fillet and its gate (each wall's lift carried along its own wall, so the
  fillet continues past a cliff end without reaching across a wall), moss by steepness, and
  keep-out cuts for roads, grades and water. A grid with no wall crest returns the ground
  itself. Output: the slope solid + collision, ground reservations, grass supports and slope
  rocks.
- **`field/CliffDressing.gd`** — no longer places anything on world terrain. It owns the KayKit
  cliff piece vocabulary (`VISUALS`/`ASSETS`/`TERRAIN_SKIN_ASSETS`, `PROFILE_SAMPLES`), THE shared
  terrain material, ground texel (`ground_uv`) and biome tint (`tint_at`, `compute_tints`) used by
  every terrain surface; village retaining rims still dress their own lattice with the pieces.
- **`dressing/DressingField.gd`** — the pure deterministic ambient-nature field. Sets author
  direct per-biome fill rates, then shared `DressingHabitatLayer` fields form correlated groves,
  clearings, ecotones, rock exposures, and small colonies with true negative space. Optional
  jittered-Voronoi community fields keep nearby visual choices related instead of confetti-like.
  A separate world-wide `DressingEcology.land_occupancy01` mask is multiplied into every
  ground population, so broad clearings and the connected edges of a jittered-Voronoi graph form
  paths that no independent set can sprinkle back into. Mushrooms deliberately use a dense
  colony set plus a rare singleton set. Reeds are `EMERGENT` content: wet, inside the shoreline,
  and never scattered over dry land.
  Final jittered anchors are qualified against terrain and the shared `WaterFieldContext`, then
  bounded Matérn-II arbitration supplies local and cross-population spacing. Chunk ownership is
  half-open, so overlapping queries agree and seams cannot duplicate or omit an anchor. Worker
  payloads contain only asset IDs, transforms, and colours. At compile time every collidable
  choice is reduced to a resource-free radial stencil of its actual near-ground visual vertices;
  qualification rotates/scales that stencil and rejects roots, rock bases, or deadwood whose
  visible footprint would overhang a cliff, span excessive height, or cross water. That ordered
  compiled outline is transformed into a persistent static layer of the live grass deformation
  field around loaded structural dressing. It follows each asset's rotated/non-uniformly-scaled
  base instead of an oversized circular radius, keeping blades from passing through its mesh
  without coupling the worker fields. Authored-feature clearance is intentionally broader:
  every choice compiles its complete visual XZ bounds, then exact oriented-rectangle overlap
  rejects any tree crown, bush, rock, or future visual whose projection would enter a road or
  village reservation even when its anchor and grounded collision remain outside. The resulting
  `feature_query_margin` sizes only the feature-reservation lookup; it is intentionally separate
  from the finite terrain/water `query_margin`, so tall crowns cannot inflate water computation.
  `EnvironmentCollisionBuilder` commits
  baked static physics for structural nature before chunk readiness; `EnvironmentCommitQueue`
  creates one visual `MultiMesh` per `(asset_id, visual piece)` under a separate per-frame budget,
  and discards stale chunk generations. Dressing still owns no gameplay identity, interaction,
  persistence, navigation, or world-feature planning. Dense grass is intentionally separate;
  the former sparse `ambient_grass` dressing set is retired.
- **`grass/GrassField.gd` / `grass/GrassStreamer.gd`** — the deterministic, visual-only dense
  ground-cover pipeline. The pure worker field places a primary 17×17 jittered candidate lattice
  per 24 m tile, plus a deterministic supplemental lattice admitted in exact proportion to a
  slope's additional surface area. Instances use the sampled terrain normal as local up, so hills
  retain the flat-ground carpet density instead of exposing stretched XZ gaps. The field projects
  the slow biome/canopy/tint owners from a canonical world-aligned 3 m lattice,
  converts viable habitat through a narrow 0.20–0.42 monotone carpet curve while preserving
  exact-zero shared clearings. Open marsh and stronger habitat saturate, while weak margins reach
  zero quickly instead of exposing isolated repeated patches. It qualifies exact jittered anchors
  against paths, water, grade, and terrain.
  Path rejection covers the selected patch's full baked footprint, not just its centre. One
  generalized edge scale uniformly shrinks patches toward every ecological grass-bed margin and
  exposed upper cliff lip (both to 55% over the final 3 m), preserving blade proportions. Wall
  facts come from one `TerrainTileField.wall_segments` call per 24 m grass tile (+8 m margin),
  cached per owning point as high (lip) and low (foot) segments; the taper reads the distance to
  the owner's own high-side walls only. Additional
  hashed layers are visited only by tiles containing such an edge. Moderate edges use
  `(1 + slope_area_extra) / edge_scale²`; total density is capped at four layers. The surface
  gradient is one-sided wherever its stencil meets one of the owner's wall segments, so the
  vertical discontinuity cannot falsely reject a strip as over-grade. The lower side is ordinary full-size carpet meeting
  an opaque rock wall; only upper-lip candidates taper, and their final shrunken footprint must
  stay on the walkable sheet. This prevents both a bare perimeter band and overhanging blades.
  Each tile selects one compiled asset variant and returns at most one packed CPU buffer. The
  current `stylized_grass.collection_05` source patch is bake-selected from a multi-variant FBX.
  All 311 blade silhouettes remain, but each indexed 18-triangle ribbon is reduced to a four-
  triangle root/bend/tip strip. The bake also moves complete blades 25% radially from the patch
  centre, producing one self-contained 1,244-triangle, roughly 3.11 m-wide mesh. Its large
  overlapping footprint closes the bed at far fewer instances than the former tuft grid. The main-thread
  service streams a 60 m full-density / 84 m fade / 108 m eviction ring and commits one shadowless
  MultiMesh per tile under an elapsed-time budget. Player distance owns deterministic population
  dropout and conservative CPU prefix caps; camera distance independently removes unreadable
  wind detail over 32–48 m, so an orbit camera cannot leave screen-distant blades
  sparkling. One double-sided shader also owns gentle height-relative sway, broad rolling gusts,
  and `TrampleField`'s world-anchored deformation. The bake stores each authored
  ribbon's local root in UV2, so trampling resolves blade groups instead of moving a whole 3.11 m
  patch as one tuft. A 1.1 m actor wake bends/drops grass strongly, retains at least 72% strength
  while moving, and recovers over 10 s. A separate persistent texture presses grass mostly
  vertically under loaded structural assets with a small radial outward spread. A fresh player
  trail owns the lateral direction and continuously blends back to that static crush as it
  recovers; no periodic obstacle stamp can snap it back. Both textures and their shared scrolled
  world origin publish atomically. Its base albedo directly samples
  the live texture object and grass-island UV owned by `terrain/materials/ground_palette.tres`,
  exactly like the terrain sheet. Collection 5 has no albedo
  texture; its relative light/dark structure comes from retained blade normals plus a nonlinear
  ground-matched contact/shaded-lower-growth/warm-tip ramp. Subtle root-group value variation fades out with camera
  detail, and the far field converges to the exact terrain value instead of retaining tiny tip
  marks or drawing a dark ring before the population cutoff. An 82% up-normal bias preserves nearby
  blade shading, then converges to the terrain normal with the same camera-detail fade; full
  roughness and zero specular bring the base colour into
  the terrain's lighting family. Back-facing ribbon cards flip their fragment normal into the
  same lighting hemisphere, avoiding dark double-sided stipple. The same projected
  `BiomeRegistry.ground_tint_at` field makes blades follow every biome transition and the shared
  broad 108/156 m intra-biome value/warmth patches.
  Grass has no
  collision, navigation, gameplay identity, persistence, or separate worker.
- **Paths and man-made features** (`scripts/terrain/features/`) — pure `SettlementPlan` owns only
  deterministic 768m future-village site identities and cells; it has no terrain API. `PathPlan`
  validates those sites against the untouched final fields, then owns canonical dry-landing bridge
  sites, monotone bounded route
  solves, local backbone/loop selection, and bridge/arch/lamp identities. `PathProgram` compiles
  the five demand-warmed assets and their primitive placement metrics; it contains no resources.
  Resource-free `FeatureProgram` composes path and village programs into the one canonical query
  margin, clearance, record-discovery reach, geometry halo, surface-priority table, field-cache
  budget, and sorted demanded-asset set. Streamer sizing therefore never reads a producer-specific
  limit. `WorldFeaturePlan` is the worker-facing owner and projects both canonical paths and
  complete village records; projection only selects already-decided ground shapes and half-open-
  owned placements.
  `FeatureContext` is the immutable per-block projection: `FeatureGroundField` always unions the
  O(1) path-grid layer with bucketed immutable circle/capsule/oriented-rectangle shapes, resolves
  surface paint by priority, and derives signed clearance from independent clearance shapes.
  Terrain, dressing, and grass consume only this general context; no path-only fallback remains.
  Future-village nodes validate a compact dry, supported footprint; their path-width square
  junction surface provides a gathering place without mutating terrain or stamping a circular
  plaza over the route. A node is a built junction: its square and arms meet at right angles and
  never take the open-country bend fillet, so a town's street and gate ramp butt against straight
  edges. Hot predicates use the same
  connection masks plus local shape buckets, so queries are O(1) in route length; lattice callers
  pass their already-known terrain cell to avoid repeating coordinate division. Each perpendicular
  arm pair adds a bounded quarter-annulus fillet, so both inner and outer path edges curve through
  turns and branches without a circle stamped over the junction. Path
  triangles keep the original tan; sparse varied-size world-hashed circular decals use one
  slightly darker tan from the same atlas island. The circles conform to the sheet and share its
  mesh, material, and draw call. Path colour replaces the
  local 0.25m ground triangles in-place rather than riding on a second depth-fighting sheet.
  Mixed triangles partition at the existing feature field's continuous boundary; both paint
  owners share canonical crossing vertices, so curved corners are not whole-tile staircases;
  transition fans give adjacent coarse grass quads the same boundary vertices, so adaptive path
  edges cannot open T-junction hairlines. Bridges are
  exact-water-validated before becoming atomic route macro-edges; ordinary routes use cheap
  planning water, then validate only the selected corridor against exact water. Routes run on
  the 24 m `PathProgram.ROUTE_CELL` lattice (= 2 points); a route edge is walkable iff BOTH of its
  12 m point edges are (`PathProgram.is_route_edge_walkable` over
  `TerrainTileField.is_walkable_edge`), so a hill may be climbed over the same continuous
  sub-storey/storey slopes the mesher renders, but a route can never cut through a wall, even one
  on the odd point between two route cells. Existing cliffs beside an approach remain natural and optional; no shelf,
  ridge, cutting, or flanking cliff is manufactured for a village. Lamps face inward over the road.
  Large arches walk every accepted route from both village endpoints: the first attempt is centred
  84 m from the node, later segments supply bounded support fallback, and shared segments deduplicate
  while routes that split early each retain a gate. Small arches mark refined dominant-biome
  crossings, stay at least 144 m from a village and 96 m from another arch, so ecotone oscillation
  cannot make a gate stack. Precedence is
  bridge → village gate → biome gate → lamp. Stable feature
  IDs never include a streaming chunk or contributing route.
  The sectional warren system lives under `features/villages/fabric/`, with its diagnostic
  review scene in `tests/harness/warren_phase0_review.tscn`. The default production
  `VillagePlan` invokes `VillageWarrenFabricSolver`, which converts one sealed sectional
  plan into the canonical `VillageUrbanFabricPlan` and `VillageRecord`; topology is never
  re-inferred from render placements. Its production adapter coalesces the same canonical
  solid, walk, headroom, and guard cells into typed `VillageOccupancyVolume` cuboids; the
  broad district exclusion is supplementary, not a prefab-box replacement for those facts.
  `SectionalPublicRealmPlan` seals only typed exterior
  street, stair-canyon, undercroft, court, gallery, and short-bridge episodes plus their
  player-width seams, primary itinerary, loops, cover policies, and required interval
  classifications. A sealed maze source names two or three separated, at-grade exterior portals
  (the primary mouth first); production projects every one to an exact two-lane terrain street and
  heightfield-painted handoff rather than inferring exits from cul-de-sac degree. Each episode carries
  explicit exterior-air cells above its walk surface.
  `FabricVolumeClassifier` unions those claims with structural solids and inhabited volume,
  rejects every public-air/occupied-volume overlap, and flood-proves all public air back to the
  route landing. Passage rooms and occupied skywalks remain private building mass; building
  interiors and interior stairs are deferred and cannot satisfy public circulation. Ordinary
  `FabricUnit` records bind modular rooms, prefabs, markets, outcroppings, exterior facade
  stairs, roofs, and occupied overhead links through semantic sockets and a parent-before-child
  bearing DAG. `FabricModuleProgram` compiles each authored asset into a typed construction
  contract: even-cell footprints retain their half-cell phase, walk-surface visuals snap their
  authored top plane to the logical route plane, and roofs are sealed repeat runs with explicit
  pitch, profile, material family, and end seams. Every rotatable full crown preserves the exact
  world-space centre of its parent's finished floorplate; an even-cell quarter turn may change the
  roof's lattice origin, but can never shift the crown onto the adjacent 1.5 m phase. At final fabric sealing,
  `FabricContinuousRoofPlan` derives maximal straight roof chains only from exact matching run
  endpoints, bearing planes, transverse profiles, pitches, and seam profiles. Rooms retain their
  complete structural roof volumes, while realized construction removes the two internal gable
  caps at every proved join and selects one compatible repeat material for the entire chain.
  Compact-house crowns publish pre-aligned start, middle, and end alternatives for every reviewed
  material family. All three roles are clipped from one source crown around the same symmetric 3 m
  party-seam profile: each semantic 6 m construction bay emits two exact 3 m sections, while only
  the two exterior sections retain the
  source roof's measured outer eave. Provisional layout reserves the exact party span plus the
  complete transverse eaves and height; after component topology is known, the final plan proves
  the two actual exterior eaves against every unsuppressed placement. An explicitly socket-bound
  neighboring pitched roof may meet that realized skin only when the existing finite seam contract
  also proves the final world-space boxes; this preserves a real flashing junction without granting
  any exemption to undeclared roofs, walls, or retained stone. The only other exception is the
  named roof of a socket-bound facade bay on that same component, whose typed flashing joint is
  allowed while its walls and supports remain collision-checked. A joined chain is rebuilt as two
  exterior ends plus true middle bays on the one bearing plane,
  so adjacent complete houses cannot leave nested end caps, mismatched cut profiles, or change
  colour mid-ridge. Exterior end sections keep their complete source eave by default. When that
  finite eave would enter unrelated finished construction, the final transaction may select the
  corresponding pre-baked flush end whose bounds are a strict subset of the full end; the flush
  alternative is accepted only after it clears the same finished-fabric proof, so roof junctions
  are resolved by a valid authored construction choice rather than an overlap exception.
  Ambiguous branches and non-matching roofs remain separate; the renderer performs no proximity
  search, snapping, or per-mesh offset repair. A one-bay occupied bridge-house crown is two finite
  party-seam end halves: it terminates exactly at both endpoint planes while retaining its ordinary
  transverse eaves. Integrated crowns participate in the same roof alignment and connected-envelope
  rules as standalone roof units; lateral bearing parents never authorize a crown to continue inside
  endpoint stone or another roof. One-sided shed roofs additionally declare their authored high
  edge; the program aligns that edge to the parent wall before a recipe can seal. A paired shallow
  gable derives both inward-facing high edges from one shared ridge plane, so it cannot become an
  inverted valley through independent yaw choices. Measured
  visual-clearance envelopes reject
  unrelated mesh intersections, while explicit semantic visual seams are the only exception;
  those envelopes also feed the bounded filler search so invalid proposals are avoided before
  assembly. Layout code never repairs individual meshes with visual offsets.
  Rare reviewed palette variants reuse the exact source mesh and collision only through an
  explicit `EnvironmentVisualPiece.material_override`; variants that need the authored colour
  channel opt out of MultiMesh instance colour so the renderer cannot erase the remap input.
  `PublicRealmSurfaceSolver` unions only exterior terrain-street, structural-court,
  stair, gallery, and bridge claims; the assembler commits visual and collision faces from the
  same payload. Every rendered surface kind is also the sole owner of its horizontal boundary,
  so retained masonry cannot reappear as a rock cap in a street, stair, court, or bridge. A
  floor-facing retained boundary is sealed with an exact one/two-cell authored timber soffit,
  never an upright rock-wall module rotated into a horizontal shelf. Side masonry maps its
  measured 1.7701733 m face to the exact 1.5 m fine-grid claim and is inset by its measured half
  depth; perpendicular walls therefore meet at the lattice corner without protruding panels.
  A single occupancy-vertex rule seals concave and diagonal retained joints with one timber
  member per band; straight and buried vertices emit none. Facade alignment always presents
  the authored +Z exterior toward its declared normal. Full-width facade slots use full-width
  panels; proved perpendicular plain/window/door joins select baked finite miter ends (including
  handed variants), while straight repeats keep square ends. These clipped choices remain
  subsets of the original measured clearance envelope rather than adding overlap exemptions.
  Village turf is evaluated by the same `TerrainTileField` kernel as streamed ground (its 1.5 m
  columns are the kernel's points; a one-band step slopes centre-to-centre). Every
  capped yard and planned-green cell is emitted in one logical-cell union, with the complete
  public-surface union supplying its real neighboring height controls; invented equal-height
  rings are forbidden because they suppress exposed lawn edges. Only finished turf and public
  surfaces supply height controls; hidden retained blocks are structural occupancy, never a
  second ground-height authority that can pull a lawn through its timber substrate. Separate decorative panels
  may never own or omit a centre cell. Straight lips and corner lips use the same uniform
  lattice/module scale. Turf's top retaining course uses the matching terrain rock family,
  not square masonry protruding through its recessed rolled edge. A paired corner covers
  two named logical faces; every face retains its own exact inset wall collider, since
  terrain dressing meshes are visual-only. Rim audits count inner as well as outer corners.
  Rolled grass lips occur only on true exposed field edges, never at an
  equal-height turf/plank material seam. Like `CliffDressing`, a concave turn of an L-shaped lawn
  receives the authored inner-corner lip (rotated the extra half turn the kit needs) so the two
  straight lips round into each other instead of leaving a notch over the wall's corner block. A
  planted public deck over air uses a connected timber substrate instead of expanding
  one-band support markers into hanging stone courses. Grounded retained mass is preserved.
  Decorative facade caps bear with their authored underside on the wall-top plane, unlike
  walk-aligned public floors. Their visible tops cannot share the wall's horizontal faces.
  Its shared terrain clip kernel suppresses unbacked run-end drapes: grass cannot form
  a vertical curtain through the public air below a structural deck. A
  supported missing fourth cell in an otherwise complete 2 x 2 structural court is sealed as an
  explicit derived claim before surfaces, guards, or audits are built; closure cannot cascade
  across arbitrary empty space. When one sealed transition mesh owns both the upper and lower
  tread across a retained riser, it also owns that vertical seam and the generic stone skin is
  suppressed there; adjacent unrelated stair claims cannot open the massif. Every structural court, gallery, and bridge cell also carries the exact local
  envelope-ground support datum; renderer posts descend to that datum rather than an implicit
  global band zero, so a support cannot stop in air or continue through unrelated terrain. All
  low and tall post candidates derive from the complete final structural-surface outline vertices,
  repeat at the authored 3 m pitch, and are rejected when their thickness would enter any public
  lane below; internal surface seams can never manufacture posts in a plaza. The route entry also
  publishes ground-height constraints and path paint at each boundary. Production no longer
  emits separate town-street or handoff-ramp meshes: the ordinary terrain surface owns
  both their appearance and collision. Nearby accepted house pads join the same sealed grading
  transaction, which selects native controls before the normal terrain joins are reconstructed.
  Outskirts survey the finished field and propose pads on that same construction datum/grid
  before their entrance and route proofs. A later pad cannot overwrite a sealed ground band.
  After retained masonry is finalized, root rooms are re-proved against the actual
  six-neighbour ground-connected mass, not temporary source stone. Edge-only contact
  and pitched-roof bounding boxes cannot establish bearing. An otherwise unborne room
  requires four finite timber corner courses reaching the local support datum; every
  member passes the existing public-air and measured visual-clearance transaction.
  Every rendered exterior door
  requires both its exact threshold landing and a clear direct approach tile beyond every open
  facade half; a proposal that cannot provide that two-cell-deep approach is rejected before
  guards or facade assets are derived. Stair-span claims are not flat doorsteps: construction
  selects the existing closed facade when its doorstep lies on a flight or its approach
  crosses a flight's side rail, records the suppressed door IDs, and preserves the room
  envelope and stair guards. An aligned flight may lead through its open end to a flat
  doorstep. Prefab admission applies the same proof before reserving its mass, and surface
  sealing independently rejects any surviving unserved entrance. Courtyard planters have
  no minimum quota; only genuine outside corners qualify, with adjoining stair bands counted
  as route neighbours so furniture cannot occupy a flight's approach.
  Reviewed fixed-size floor/gallery meshes tile structural claims as authored plank
  visuals without replacing the union's collision authority or scaling assets. Production also
  emits the exact sealed structural union as a minimally recessed skin beneath those boards, so
  authored border insets cannot expose gaps while the authored planks retain their detail. The
  former short floor-bearer/corbel modules are not emitted: they read as unsupported stairs beneath
  overhangs, while boundary-derived posts and structural skins own the actual bearing. The same
  ruling (2026-09-04) removed the ribbed `sfv.fabric.brace.wood.002` corbel from every overhang:
  facade bays and bump-outs, skywalk ends, balconies, oriels, dormers, corner wraps, and the
  integrated room-jetty support courses. Those `outcrop.support.bracketed.*` recipes still seal and
  are audited once per bearing edge, but they carry no placements: they declare the exact envelope
  the corbels occupied (`FabricRecipe.set_local_clearance_bounds`) so every clearance proof keeps
  the same input while nothing is drawn. The diagonal-strut variants remain visible supports.
  Exposed court
  guards derive from that union and structural occupancy, so graph
  transitions stay open and arbitrary leftover gaps never become platforms. The proof first
  compiles a diagnostic seed, then `FabricSolidVoidPlan` turns every exposed route side into a
  boundary obligation. `StaggeredFabricEmbedder` runs a deterministic bounded beam over complete
  roof-closed one/two-storey envelopes at route, half-level-lower, and full-level-lower bases.
  `StaggeredFabricCompiler` turns proposals into ordinary terrain-perched room/roof DAGs; low
  edges that cannot fit a room may receive a complete baked market-stall envelope. The common
  transaction recomputes surfaces, exterior air, occupancy, and boundaries from the compiled
  units. It currently proves a connected exterior route with several rises and descents, a high court,
  private occupied skywalk mass above public space, zero public-interior episodes, zero
  public-air/occupied overlap, zero tents, and zero unclassified required intervals. Its
  adversarial capture harness validates both camera collision clearance and target line of sight;
  every full-resolution image receives one falsification disposition, and finding a real issue is
  explicitly a successful review. Sectional capture manifests carry raw and rotation-normalized
  maze signatures, construction signatures, and the hard stair/platform/entrance/support/overlap
  audit beside every image target; corpus coverage rejects repeated maze or construction geometry.
  The former v14 proof folded its upper journey and
  descent back through one denser mass, places the second occupied bridge-house directly over the
  lower route, renders structural surfaces with reviewed plank meshes, and shrinks the classified
  core from 40 x 50 to 30 x 36 lattice cells. It failed the 24 x 24 compactness budget,
  reconnecting-loop, frontage (53 of 138 exact boundary obligations closed), overhead, and
  sightline gates; these failures are intentionally
  preserved by the critical review harness rather than hidden by props or detached platforms. Its
  alignment revision treats exterior doors and deliberate floor openings as typed plan facts:
  an addressed room is selected only when its exact handed 1.5 m threshold has an adjacent public
  landing, and every real companion landing opens the remainder of the authored 3 m facade. Derived
  guards and endpoint posts open only across those actually claimed landing halves; an absent
  companion remains guarded exterior air rather than becoming an invented forecourt. Only an actual
  claimed landing proves the door reachable; otherwise the facade is closed/windowed. Collinear
  short guards along its shallow forecourt coalesce into one authored
  3 m rail with posts only at its outer ends, but only when the finished public surface owns both
  sections. The final
  `PublicRealmSurfacePlan` transaction hard-rejects every remaining unserved exterior threshold,
  so a visible door can never survive as a later diagnostic over empty air. Stair audits
  require both player-width lanes at their exact low/high graph seams. Structural courts satisfy
  bearing ancestry before surface compilation, while every reserved `DAYLIGHT_VOID` remains
  exterior headroom and receives derived guards. Guard openings are never inferred from arbitrary
  vertically adjacent walk cells, and missing geometry is never promoted to a platform implicitly.
  Fixed authored route seeds remain diagnostic fixtures only. Production runs the bounded
  procedural fabric search. Four orthogonal motifs, two turn phases, and four balanced vertical
  profiles form 32 seed-selected sectional grammar families before hashed construction choices;
  the exact and production corpora require different raw routes, rotation-normalized routes, and
  construction signatures. Exact visual selection compares two sealed survivors normally and the
  complete fixed eight-plan frontier only when the current best still has under 25% overhead route
  coverage or over 50 through-core sightlines. That vertical-coverage metric counts inhabited mass
  or a connected upper public surface crossing a lower route column; detached decoration never
  counts. Both
  compact-house families use true 3 m by 6 m narrow/deep envelopes
  with pitched roofs. Every rectangular generated house names local Z as both parcel depth and
  ridge axis, requires the measured roof to be longer on Z than its X eave span, and rotates the
  parcel/roof contract together; production cannot admit a sideways wide house. Complete authored
  3 m facade modules tile every side span with their source UVs. Timber panels own one edge post,
  so east/west faces use bake-time X-mirrored variants with corrected winding, normals, tangents,
  collision, and material surfaces. Runtime transforms remain proper rotations; rectangular shells
  must resolve to exactly one post at every corner, never doubled diagonal corners and empty opposite
  corners. Modular room stitches use the solid timber jamb fitted to a 0.28 m square,
  not the kit's plaster-bearing corner-wall panel. Every authored 3 m facade-bay
  endpoint is framed, including intermediate T-joints on long rooms; party-wall
  suppression must not leave an unstitched slot halfway along a room side.
  Every compact 3 m by 3 m modular room is also classified at the final fabric boundary:
  it must be a fully borne stack/foundation course, a two-ended occupied skywalk, or the roofed top
  of a compact house. Partial-bearing tower rooms, roofless compact houses, and unclassified
  micro-boxes reject the transaction; larger jetties remain governed by their separate exact
  bracket/support proof. The stackable townhouse may fill
  upper-route pockets without admitting sideways buildings. A greedy three-or-more-storey stack is
  admitted only after a lower complete roof-step neighbor already exists, and exact selection rejects
  every remaining unstepped tall stack. A narrow tall lineage is accepted only when it has a real
  world-space floorplate break releasing two or more facade planes and no identical plate runs
  for three storeys, so a deliberate 2+2 whole-room step is not mislabeled as a vertical extrusion;
  central height descends through occupied neighbors.
  Exterior stair-facade doors use the same cardinal threshold contract as
  other addressed rooms. A generated facade may render a door-shaped module only for a sealed
  exterior entrance or typed private feature portal, and every exterior entrance must have an
  exact public-surface claim at its threshold; decorative or midair facade doors invalidate the
  town. Finished static entrances always select reviewed closed-leaf assemblies. The stone assembly
  bakes the standalone arched leaf into the authored rock surround, so closing a threshold never
  replaces its masonry family with a plaster/timber wall; empty door frames remain catalogued only
  for a future interactive-door transaction. Outcropping vocabulary retains three exact scales.
  Production facade relief first tries a complete native-width 3 m gabled bay and falls back to the
  partial-height embedded oriel only where the larger measured envelope cannot preserve every
  unrelated room and finite roof closure. The assembler walks eligible facade courses in one
  canonical order and commits a maximal non-overlapping set, alternating full gabled bays and
  shallow bump-outs across accepted courses instead of independently rolling each feature. Failed
  measured-clearance proposals try the other relief family before yielding, so a seed cannot
  silently lose all of one vocabulary through presentation odds. The full-scale same-storey
  bump-out remains disabled: it is a
  3 m room plate shifted diagonally across a 3 m tower room: their shared 1.5 m quadrant remains the
  parent's authored shell, while only the exposed L-shaped union shell, floor, braces, and roof are
  emitted. It therefore reads as one compound building with no duplicate wall or texture in the
  overlap. A small facade bay is instead a 1.5 m-wide embedded oriel with 0.9 m return cheeks and a
  1.38 m partial-height face assembled from one normally proportioned authored S window. Identical
  centered timber jambs overlap the scaled centreline of the source panel's authored terminal post
  and its exact reflection rather than widening either edge; glazed return cheeks meet that same
  scaled face envelope at the parent seam. Its centered complete sill and shallow tiled canopy cover
  the complete narrowed face and both returns, the sill and
  canopy carry it visually (no corbel hangs below), and the parent remains a closed facade rather than opening a full doorway-sized
  hole behind the small bay. A straight room pasted beyond a facade,
  dormer, flue, or trim can satisfy neither massing contract. Its diagonal/corner-union recipes remain testable but
  their scale quotas are zero and production rejects any survivor which still requires a tower
  annex; they must not reappear through an implicit relief obligation. The optional bay search ranges across every eligible
  lineage and caps successful commits, so two initially cramped lineages cannot suppress relief
  elsewhere. Integrated upper-floorplate shifts still emit a `room_outcropping` fact, including
  directly borne shifts that need no brackets. A tower-to-slim/row size change computes its real
  bearing and extension before that outcropping classification: when exactly half of the upper
  plate crosses a two-band public-route bay, the solver seals an `arcade_overhang_support` as a
  four-corner frame of measured deck pillars, with explicit seams to both room plates. The frame
  occupies only the plate corners, so both 1.5 m public lanes remain open; a full 3 m stone arch is
  not used because its jambs stand on those lane centrelines. The shift may never pass as a
  zero-extension setback or receive loose decorative stone fragments. Ordinary
  shallow room jetties use compact wall-bracket courses; the full-storey diagonal asset is reserved
  for deliberately deep authored features because its long upright reads as a dangling pole when
  repeated below a shallow projection. Side panels sit on the actual one-module shell planes rather
  than leaving untextured gaps, never unroofed cubes, and markets draw only from the seven reviewed
  `stocked_market` prefabs;
  empty tent families are ineligible. The old terrain-massing planner and its compatibility entry
  point are removed; runtime village construction has one topology producer and one atomic
  transaction. The volumetric source-plan pipeline is the production path: the plot-model maze
  source described below. Before the town is built, `WarrenVillageScaleProfile.select()` deterministically chooses one
  of four size contracts: compact 65%, standard 25%, large 8%, grand 2%. **Task I8 (2026-08-30)
  set `radius_cells` to 5/6/7/8 after fixed-camera/player review showed that the restored
  7/8/9/11 footprints again dominated the character and surrounding world. Planning diameters are
  51/57/63/69 m in the production frame. The source macro lattice remains the authored 3 m
  module and its 1.5 m two-lane proof grid; `VillageWorldScale` maps the entire sealed transaction
  to an 8 m world macro / 4 m world fine lattice with 3 m bands (September 27; formerly 6 / 3 m).
  One immutable 24 m terrain-field cell therefore contains exactly three town macro cells. The frame scales meshes, collision, semantic
  occupancy, route widths, supports, and terrain samples together; individual assets are never
  resized to repair a fit. Town extent changes only by admitting more procedural massif, street,
  plot, and outskirts opportunities.** Total
  inhabited-room budgets are 10--30/12--35/18--50/25--75; residual
  infill is capped separately at 6/6/8/12 rooms. Those totals include the late residual pass,
  which may never disappear from size accounting. Complete authored-building ranges are
  4 for compact, 3--4 for standard, 4--5 for large, and 5--6 for grand. A bounded deterministic compatible-set beam
  replaces the former hard-coded pair/triple enumeration, so the richer sets do not make generation
  exponential. The reviewed catalog contains 32 distinct complete meshes: twelve Stylized
  Fantasy Village interiors, seven tavern buildings, three alchemy buildings, two forges, seven
  Low Poly Fantasy Village houses, and its church. They compile as indivisible measured prefabs.
  The seven LPFV houses ship with an empty front aperture and a centred `_01` jamb frame, so each
  prefab recipe also owns one of the pack's two hinged `_02` closed leaves at the exact authored
  jamb/hinge transform; the leaf carries
  both visual and collision, while a retained clearance-only halo preserves the previously reviewed
  prefab envelope and keeps this visual correction from reshuffling bounded town search.
  Prefab admission uses unscaled 21/24/30/36 m maximum spans for compact/standard/large/grand,
  so a giant authored building cannot consume a compact town but the broadest silhouettes remain
  reachable in the larger profiles instead of being globally excluded.
  Buildings with the same occupancy,
  clearance, and socket signature share one topology proof but select a seed-varied visual
  representative afterward, so deduplication cannot freeze a footprint family to one mesh. The
  solver ranks compatible sets across the whole catalog before room composition. Source skywalk
  ranges are 2/2--2--3/3--4/4--5: larger towns request richer occupied-link sets and the sealed
  hero-feature ranking (exact composed recipe occluder route coverage, the same test as the final
  enclosure audit) keeps three only when the fourth provably adds no distinct inhabited route
  cover — that redundancy is recorded as an exact diagnostic fact. Balcony ranges are
  0--2/1--3/3--4/4--6; production full-scale diagonal-outcropping ranges are temporarily zero for
  every size. Compact and standard towns take a covered market only when their ground street
  holds the complete measured transaction; large and grand require it and the elevated
  third-storey court. Stable source signatures and
  terrain-relative rebuilds carry the exact selected profile; a small town is never a cropped or
  mesh-scaled large one. The smaller footprint is produced at source-plan time, before streets,
  plots, or buildings exist; it is not a camera accommodation or a crop of a finished result.
  **THE PRODUCTION PIPELINE IS ONE PASS.** There is no generation mode, no attempt rotation, no
  ranked candidate frontier and no solution pin: task F1 deleted the searched pipeline outright
  (`WarrenTownSolver.GENERATION_MODE`, `WarrenPublicRealmCarver`, `WarrenGroundArcadeSolver`,
  `WarrenExcavationCarver`, `WarrenParcelizer`, `WarrenParcelHeightSolver`,
  `WarrenSolidPartitioner`, `WarrenBuiltTownSolver`/`WarrenBuiltTownPlan`, `WarrenTownPlan`,
  `WarrenAssetPlan`, `WarrenFabricCompiler`, `WarrenMassPruner`, `WarrenVolumeSurfaceCompiler`,
  `WarrenSolutionPinCache`, and the hero-feature beam inside `WarrenVolumetricSolver`). A settlement
  is built exactly once per (city seed, scale profile), and if it is rejected there is no second
  candidate -- which is why every richness quota below is an audit fact rather than a refusal.
  The call graph is: `VillagePlan` -> `VillageWarrenFabricSolver.solve` (terrain sampling, yaw
  placement, materialization) -> `WarrenVolumetricSolver.solve` -> `WarrenMazeSitePlanner.plan`
  (massif -> carve -> reserve -> partition -> seal) -> `WarrenMazeVolumeAdapter.to_volume_plan` ->
  `WarrenVolumetricSolver.from_volume` (public volume, parcels, rooms, one-pass feature selection,
  residual backfill) -> `WarrenSpatialFabricCompiler.solve` -> `SettlementFabricAssembler`. The
  terrain rebuild after placement (`solve_selected`) is the identical one-pass solve with the
  placement's real ground bands.
  The corpus sweep is `tests/harness/warren_maze_mode_sweep.gd`, run as
  `Godot --headless --path . -s res://tests/harness/warren_maze_mode_sweep.gd -- --seeds
  1,2,3,4,5,6,7,8,9,10,11,12 --scale compact,standard,large,grand`. It writes its matrix to
  `res://.godot/warren_maze_mode_sweep.json` with a fingerprint of the fabric script directory, and
  `tests/test_warren_maze_composition.gd::test_corpus_composes` scores itself against that file
  and refuses a matrix measured against a different tree. `--mode` and `--constructive` are
  retired and now exit 2 rather than silently no-opping. The full four-scale run is MANDATORY:
  `--seeds` is global, so a per-scale reduction cannot be expressed and a short matrix
  hard-fails the corpus gate. Corpus figures are regression measurements, never generation inputs;
  refusals remain named composition, public-air, roof, or bearing gates rather than seed exceptions.
  The focused five-town life corpus after the scale/connectivity revision realizes ten occupied
  skywalks and zero unsupported/floating modular rooms. Source spans are selected with two complete
  ground-reaching endpoint-house proofs; exact roof or envelope conflicts release the whole span
  rather than leaving a floating body or intersecting textures.
  Per-stage wall clock for one town is on the
  sealed plan's `maze_stage_ms` audit
  key; `tests/harness/warren_maze_stage_probe.gd` and `warren_solve_profile.gd` print it.
  `WarrenMazeCarver` builds one deterministic entrance-to-summit spine,
  coverage-driven alley network, a universal typed 6 m by 6 m market square, and open-air/tunnel
  classification from the same `WarrenMassif`,
  using the shared resource-free stride geometry in `WarrenPassageLatticeRules`. Its sealed
  `WarrenMazeSourcePlan` is the prospective pre-`WarrenVolumePlan` authority: every public cell has a
  typed spine/alley/market owner, one universal market-zone prefix, a block-thickness classification, and a
  deterministic signature covering graph, air, and thickness state. The source seal requires one
  exterior entrance, connected valid passage strides, capped straight runs, and at least 90% of
  public cells retaining an inhabitable facade. It reports addressed-column reach and raw-solid
  survival separately; the design's mass ratio is the later partition's share of post-carve SOLID,
  not the fraction of the original massif left after intentional passage/shaft excavation. The
  `WarrenMazeVolumeAdapter` seals a bidirectional bore/surface alignment audit before exposing the
  common volume: every nominal passage cell retains at least two fine floor lanes, every emitted
  floor remains inside the actually carved passage column/slot, and the second tread band of a
  stair is recorded separately rather than misclassified as an invented path.
  market widens a straight approach by two cells when possible and otherwise fills the missing
  diagonal of a tight approach turn; alley growth treats that square as immutable topology and
  restores the source frontage margin around it. `WarrenMazeBlockPartitioner` is the town's only
  parcel stage, reached through `WarrenTownSolver.partition_parcels`. It translates the sealed
  source's plots into the existing authored tower/slim/row/building/long parcel contracts in one
  deterministic pass and generates no partition variants: the leftover solid already IS the
  buildings, so nothing has to be fitted around the route.
  `WarrenMassifBuilder` authors the one bounded 2--18-band **inhabited** mountain directly above
  immutable terrain; `WarrenMassif.bearing_at()` is the terrain base, never a hidden stone
  substrate. Its height law uses the footprint's continuous Gaussian value plus
  two coherent integer-hash noise octaves, quantized to whole storeys under a
  monotone riser clamp. Finite terrace regions are bounded before columns are
  emitted, then small regions coalesce once without erasing a height level.
  `WarrenMassifBuilder.build()` constructs one field and freezes it; the former
  128 seed phases, preferred/fallback candidates and completed-field quality
  gate are removed. `WarrenMassif.validate_construction()` inspects connectivity
  separately for tests. The 10,000-field inspection harness checks core height,
  five-level minimum, riser bounds, clustering and plateau limits independently.
  Before residual massif becomes renderable stone, a deterministic macro-lattice erosion lowers
  every complete top course of unclassified retained rock which has no cardinal structural
  neighbour and nothing borne above it. Both derived hillside and plot mass which became no
  building participate; rooms, roofs, features, public surfaces, prefab envelopes, and structural
  bearing are already claimed and therefore cannot be removed. The pass iterates to a local
  fixpoint, so an isolated raw 3 m cube cannot survive while a two-column ridge or a complete,
  supported, roofed one-cell building remains legal.
  When a complete source-rock course is the terrain-bearing endpoint of an occupied bridge-house,
  it is promoted into the authored lower storey of that same building lineage; it never survives
  as an undecorated stone cube immediately below the upper room and roof.
  Within a partition, macro room bearing is repaired and hard-rejected before the more expensive
  registration/silhouette relief; a source macro preflight performs that proof before the hero
  feature beam, and the final transaction repeats it afterward. A merged room may carry a source
  lineage upward only when the resumed authored floorplate is fully borne or has one exact
  bracketable bay--a one-cell incidental overlap is never a support seam. Registration relief
  scores the exact exposed shoulder before facade variation and may never replace a roofable seam
  with an arbitrary voxel shelf; complete room crowns, compound gables, and bound lean-to runs are
  the only admitted shoulder vocabulary.
  After every required feature campaign and before optional facade bays, every one-cell residual
  course trapped between occupied party walls must compile as exactly one typed
  `interstitial_join` construction — a stepped-shoulder lean-to (bearing bond into the room
  below's exact top socket, ridge on the single continuing wall) or a measured
  `interstitial.seal` strip (flush-capped to the sky, timber-blocked under bridging mass) — or
  the town is rejected with a reason-coded refusal. Coincidental mesh adjacency is never a seam,
  a shoulder may never bear on another strip, and the final audit proves
  `one_cell_interstitial_gap_cell_count == 0` on every sealed plan.
  A successful exact hero-feature room composition is carried into final partitioning instead of
  recomputing the same deterministic result, unless feature-envelope displacement changed its
  input parcel set. Exact construction
  assigns blue/orange/amber timber families through deterministic jittered-Voronoi architectural
  districts about 18 m across, so neighbouring houses and vertical lineages read as related quarters
  instead of per-room colour confetti. Blue and amber quarters take cool slate roofs; orange quarters
  retain warm roofs, deliberately counterbalancing the two compact authored tower roofs whose honest
  source textures are both orange. Storey phase still changes complete authored wall modules and
  measured facade details. Construction admits only explicit compatible party-wall seams. A sealed
  `PARTY_WALL` may suppress a facade placement only when all four fine-grid faces behind that one
  complete 3 m authored wall module meet private volume; partial contacts retain the whole module.
  Suppression is stored on `FabricUnit`, validated against its recipe, enters the construction
  signature, and is applied before asset demand/placement expansion, so the renderer never guesses
  proximity or draws coincident timber/stone skins. Touching equal-height room roofs are solved as
  one atomic neighborhood transaction: continuous ridges, measured valleys, and stepped wall joins
  are legal only when the complete authored neighborhood fits. A collision cannot rewrite that
  neighborhood into flat architecture; it rejects construction while proposal selection can still
  choose different massing. Complete terminal house plates therefore receive pitched roofs.
  Only a complete `roof.terminal.tight.*` gable may satisfy that terminal obligation;
  `roof.terminal.step.*` and `roof.terminal.profile.*` remain facade/junction seam vocabulary and
  can never masquerade as a whole-room roof. The reversible source-plan gate derives every
  complete candidate with the same phase-aligned origin and exact public-air test as final roof
  assembly. Every roof obligation enters the layout transaction even when that candidate list is
  empty, so an impossible optional parcel is displaced (or the layout rejects) before commit rather
  than losing the obligation and reaching the renderer roofless or embedded in retained stone.
  Flat/cap vocabulary is reserved for typed public terraces, circulation backing, and partial
  setback closure whose finished topology already requires a level surface; it is never a collision
  repair or an exposed plank weather roof.
  Partial setback strips prefer an honest exposed-edge rail; enclosed strips may receive a measured
  planter-only roof garden, and every dressed form has the exact plain cap as its transactional
  fallback. A changed upper floorplate is accepted only when every exposed shoulder is either one
  complete standard room footprint, an exact wall-bound lean-to row, or a lossless compound
  partition of complete house crowns plus native terminal strips. The roof compiler consumes that
  same partition largest-first with at most one recognizable gable crown per parent shoulder;
  arbitrary branching voxel shelves are rejected or an optional
  crown is truncated. A compound gable does not exempt neighboring rooms from measured visual
  clearance, so a valley collision selects the matching plain shell or one coherent flat service
  closure instead of overlapping roofs. True one-storey tower/slim closers preferentially use their integrated chimney roofs.
  Adjacent compact roof ends are editor-baked to exact 3 m runs: each keeps its authored exterior
  gable and terminates at the shared open party seam, so equal-datum neighbours touch without
  overlap or runtime scaling. Compatible one-valley building/long T-neighbourhoods use the existing
  atomic bisected-host/open-branch construction; a compact crossing which has no authored watertight
  junction rejects the atomic construction instead of overhanging or flattening its 3 m house.
  Pitched compact and slim roofs may receive measured dormers. Each uses one complete authored
  attic-window shell, retaining its window, cheeks, sill, supports, and closed gabled or shed crown
  as one coherent asset. The reviewed steep gable stays at 56% scale; the broader shed uses 50%,
  0.22 m compact / 0.74 m wide registration, and a 0.12 m downslope shift. Two finite native
  rear-stock variants close the host contact without moving the authored glazing.
  The blue compact tower retains the reviewed steep
  gable; the warm compact tower uses the lower-profile shed instead of the weaker shallow gable.
  Gabled and lower-profile shed families use separate registrations so their feet and open backs remain buried in the host slope without
  hiding the glazing or exposing a roof hatch. Compact/wide eave offsets are 1.15/2.15 m.
  Long roofs may select a bilateral recipe with one dormer on each opposing pitch. True wraparound
  balcony recipes own two continuous 3 m deck rows, a native half-width third cell on the direct
  doorway circulation line, a 1.5 m side return, nine exposed-boundary guard sections, two
  complete one-storey timber pillars beneath real outer deck cells, and a planted corner. The
  doorway seam and both of its guard endpoints are keep-clear zones, so neither the direct rail
  nor an adjacent repeat's terminal post can block the aperture; structural supports sit off the
  doorway axis. Their complete authored stair is a
  switchback, not a two-lane straight flight: one measured low tread lands on an existing
  `PUBLIC_FLOOR`, the opposite high tread meets the deck through one exact guard opening, and the
  module contract aligns the high tread plane rather than the taller handrail AABB. Compact and
  deep walk-out balconies use a four-cell-wide platform with the doorway in an inner bay, at least
  one full cell of lateral clearance to each side guard, one complete 3 m centre guard plus two
  complete 1.5 m end guards, and four measured supports. The nearest side-railing terminal post
  therefore cannot sit on the threshold, and both front-guard joins sit at the outer quarter points
  rather than on either handed doorway axis. Balconies are never
  inferred from an accidentally exposed lower roof. None of these private visual treatments invents
  public walkability. Every candidate's
  complete transformed semantic solid volume is checked against the sealed 3D public-air grid—not
  just its first band—and every collidable authored placement is checked against the player-width
  protected lane inside that air. Shallow eaves may still brush a route cell's outer corner, but a
  gable or eave entering the walkable body lane rejects that roof candidate.
  An unsupported or unresolved multi-valley result rejects the construction before materialization;
  no late pass flattens roofs or emits a fictional pitched-junction module. Stone is concentrated
  at real terrain bearing and retaining work; a sparse building-level rule may continue that masonry
  through the first upper storey as a coherent plinth, but never as arbitrary high cladding or a
  hidden podium. The sparse rule now offers one in three complete low lineages, in deterministic
  hash order, but admits them only while their exact exterior-face contribution stays at or below
  22% town-wide; the bound is computed before material selection, so a compact town with one large
  candidate cannot turn into a fortress and masonry never fragments panel by panel. When any column of a generated building needs that plinth, the complete building
  footprint receives one shared bottom course with a closed four-sided perimeter; every module is
  source-mass-backed and its lowest edge meets terrain or an authored path surface. Individual
  facade patches and floating partial courses are invalid. A house footprint may span at most the
  explicit one-storey plinth budget in sampled terrain height; larger risers must split into
  narrower terrain-rooted buildings rather than becoming masonry podiums. The buildable frontier
  is the tapered 3D envelope's real capacity boundary, never a radial outskirts ring. An outer
  parcel whose shallowest boundary column has deeper massif immediately behind it is capped to one
  storey plus roof at that edge, then gains one storey per inward boundary-depth ring. An isolated
  edge house with no deeper neighbour is not shortened. This puts occupied foreground roofs in
  front of taller mass instead of leaving one flat vertical city face. Every
  frontier parcel must either reach terrain directly or be the one typed 3 x 6 m covered gateway;
  optional terrain-level residual houses require a multi-face connection to already established
  circulation, preventing unsupported one-cell tails around the edge. The gateway's
  one bay is terrain-borne while the other crosses an already-authored lower route and its exact
  headroom, with a measured bracket/diagonal support reserved in the same transaction. An
  unsupported frontier parcel invalidates the whole parcel plan. Large and grand
  topologies must also contain one typed 6 x 6 m third-storey courtyard: its floor is four bands
  above the local terrain, supported by complete mass or a lower route, and addressed by buildings
  on at least three sides. The court additionally reserves explicit open-sky columns and proves
  actual public walk surfaces both below and above its XZ projection; swept headroom alone never
  counts as the over-court route. The
  final exact selector also recognizes broad irregular roof courts assembled by the ordinary room
  transaction. A court must contain at least twenty connected 1.5 m floor cells, meet the canonical
  upper route through a player-width seam, remain irregular rather than a narrow strip, and bear on
  multiple occupied buildings. The courtless-fallback rule that used to sit here -- retain the
  first valid courtless candidate while compiling the next three ranked partition variants -- was
  a property of the searched frontier and died with it in task F1. There is one partition and one
  composition, so a compact or standard town either forms its route-connected roof court or ships
  without one, and the shortfall is published.
  The
  fine-grid volumetric front end selects exactly one covered market and its measured
  skywalk set before room composition, in one pass and without a search
  (`WarrenVolumetricSolver._maze_feature_pass`). Straight and corner skywalk recipes share an explicit blue
  or orange roof campaign; an L-link chooses the corner matching its arms (mixed arms resolve to
  slate), so the turn cannot expose a one-piece warm patch inside an otherwise cool roof. The market attaches the atomic 6 x 3 m reviewed canopy plus
  authored stocked-table recipe to one exact terrain-rooted room `MARKET` socket. Four central
  public cells remain negative space beneath the canopy; when their lattice phase does not already
  meet one route episode, a bounded two-cell-wide aisle throat is carved to a two-lane seam. Every
  aisle cell is newly carved canonical `PUBLIC_AIR`, carries its public floor and named construction
  seam, and is projected by `WarrenSpatialPublicRealmAdapter` as one supplemental covered route
  node. The market body, aisle, terrain bearing, visual clearance, backing room, and construction
  record commit atomically; its decorated variant keeps a measured leafy plant in one post bay and a
  barrel with tabletop lantern in the other, outside the four-cell aisle. Room/roof packing and the
  skywalk beam must yield to that reservation. The final room transaction recomputes support from
  the complete surviving partition. An unsupported ordinary elevated building may yield only as one
  complete lineage/dependent closure; market, court, skywalk, and other exact feature sockets veto
  that fallback, so neither a doorway nor an upper-room fragment can remain floating.
  Candidate order measures bounded sight rays from every aisle edge and prefers the arcade whose
  views terminate in inhabited mass soonest, before considering room displacement, so cheap empty
  perimeter space cannot pull the bazaar out of the city. A canopy may meet the underside of an
  existing upper public route: that already-sealed `PUBLIC_FLOOR` is the single shared interface,
  rather than being overwritten with a duplicate roof claim. All other market face conflicts still
  reject the transaction. The exact market/court/landmark/skywalk preflight also recomposes the
  rooms and rejects any survivor that still contains more than two consecutive storeys with an
  identical tower floorplate unless that exact lineage carries the hard quota of two occupied,
  roofed room annexes. The feature transaction rejects the entire town when even one required annex
  cannot seal, so the exception changes the building silhouette rather than disguising it with props.
  Three-storey narrow houses receive one such occupied annex. The composition records are one storey
  each, so a forced second storey does not
  accidentally protect an optional third-storey crown from truncation. That check runs inside the
  bounded hero-feature loops, while another court or market candidate can still be selected, rather
  than after the first superficially compatible set has become irreversible. Tower-risk ordering uses
  that same three-storey repetition threshold rather than the separate four-storey annex threshold.
  Exact room-preflight failures are cached within one market candidate by the complete court body,
  clearance and forced offsets; landmark protected cells; skywalk components, owners, clearance,
  priority and forced offsets; and required transition owners. Authored palette recipe names are
  deliberately absent, so visually different prefabs reuse a proof only when every consumed 3D
  composition fact is identical.
  When exact composition proves that the selected court's forced parcel/block/offset obligation
  creates even one repeated shaft, the remaining visual variants of only that identical obligation
  reuse the failure, even when the same composition reports additional unrelated bad lineages. Other
  court geometry and other market sites remain searchable. A failure owned only by unrelated rooms
  is never promoted into a court-wide shortcut.
  The four typed third-storey court nodes
  retain explicit owner identities through public-realm projection; the visual adapter tiles only
  their exact 6 x 6 m union with alternating reviewed 1.5 m boards. Collision still comes from the
  common sealed surface union, and no court is inferred from the shape of an arbitrary platform.
  The one-pass feature selection (`WarrenVolumetricSolver._maze_feature_pass`) stamps the
  scale-selected zero, one, two, or three reviewed prefab landmarks before generic rooms, from the
  asset plots the source placed -- it does not search for them. Compact towns keep identity inside the connected room
  mountain instead of appending a detached manor. Each anchor is a complete measured terrain-rooted recipe with its real baked
  entrance aligned to a canonical ground-street landing, conservative shell/private volume,
  visual envelope, exact contact-point bearing cells, doorway face, and construction transform.
  Its source siting transaction publishes every massif column touched by that measured body/eave
  reach plus a street-side future-house buffer. Generic parcel partitioning may reuse those columns
  only above the prefab's top, so a selected complete asset cannot be displaced by a later low house
  while higher terrace mass remains legal. The exact terrain-bearing columns are separately carried
  through the final shoulder rebuild. An asset source plot is only this coarse measured search and
  clearance reservation: after the prefab claims its real body, every unused cell in that plot
  envelope is released to exterior air rather than retained as a full-height stone box. Support
  below the prefab floor remains typed rock, so the landmark stays grounded without a quarry block
  wrapping its walls.
  Candidate pairs may touch across a canonical face only through the joint transaction's explicit
  deterministic `PARTY_WALL` (horizontal) or `CONSTRUCTION_JOINT` (vertical) claim. Both landmark
  transactions reuse that one canonical joint owner, so measured anchors can form coherent dense
  fabric without double-claiming exterior facades or accepting a mesh overlap. Candidate
  pairs rank by their measured contact
  with surviving ordinary room mass on multiple sides before parcel displacement, surplus corridors,
  separation, and visual variety. Blocked parcels and other hero features never count as that contact,
  and the exact terrain-rooted transition houses which do count become required members of the final
  room transaction. Ranking precomputes the
  exact blocked-skywalk index set for each individual landmark and unions those sets per pair; this is
  an exact factorization of the former pair-by-skywalk collision loop, not a shortlist. Identical
  ordered candidate corpora reuse their complete pair frontier across court variants, while every
  court-specific skywalk score is recomputed. This keeps a landmark
  from winning merely because it preserves dozens of links when production needs the selected count;
  arbitrary detached prefabs are never added after packing. Large/grand landmark groups require at
  least one enclosed skywalk to terminate in a real landmark
  ROOM/BEARING socket. That intentional two-cell interface is the only deferred landmark shell
  seam, and the skywalk owns both the open face and its persistent clearance halo so later balconies
  and roofs cannot pierce it. Landmark-owned private cells are feature volume rather than synthetic
  `WarrenBuildingVolume` stacks, and their terrain bearing replaces any hidden support podium.
  The exact hero preflight also mirrors final phase-A/phase-B room-envelope selection for every
  unrelated room pair. If both measured facade phases collide, it may drop one complete optional
  parcel and re-run the transaction; it may never drop an addressed/court/market/skywalk parcel or a
  selected landmark-transition house. Room overhangs are preflighted together with the exact
  measured bracket or arcade course that will bear them. When that support envelope intersects a
  fixed market/court/skywalk feature, an ordinary optional parcel may still yield as a whole. A
  required lineage instead feeds the exact upper-room cells back through the semantic
  `ROOM_SUPPORT_CLEARANCE_OWNER_ID`: because composition records are one storey each, the planner
  can terminate only an unforced crown above the last required room even when the earlier offset
  packer grouped both storeys in one coarse band. This is a structural load-path transaction, not a
  mesh offset or visual repair; a collision at or below a required socket rejects the candidate.
  The covered-market backing phase is selected by one helper shared by candidate validation, exact
  preflight, and final composition, and the recomposed room probe must still contain its exact typed
  backing cell after every crown retry. The audit separates feature-clearance displacement,
  room-pair displacement, support-clearance crown termination, and the persisted exact exclusion
  cells.
  `WarrenRoomCompositionPlanner` then treats every remaining upper band as a mutable 3D room field,
  never as a 2D parcel to extrude. Its deterministic band tiler may replace adjacent source-lineage
  blocks with one measured long/slim/square room when the exact occupied-cell union, support overlap,
  protected reservations, and later lineage handoffs all remain valid. A second residual-mass pass
  can grow a room into genuinely unclaimed inhabited massif cells beyond its source footprint; an
  addressed upper room is eligible only when the transformed authored door and exact public frontage
  remain unchanged. If an unforced crown can no longer fit around a hero reservation, composition
  may terminate the lineage after its last required storey, subject to the two-storey tower cap; it may never discard or truncate
  through a later door, court wall, market socket, or bridge endpoint. The selected court's occupied
  bridge-house body and final recomposed room cells must still address three distinct sides before
  any building is committed—source parcel silhouettes do not count. Cardinal adjacency is deliberately not rejected by a blanket fine-cell moat:
  exact cell ownership protects topology, compatible contact becomes a typed party wall, and the
  selected recipes' measured envelopes decide sub-cell eave/facade clearance. A recomposed addressed
  room derives its authored door phase from the final world origin, yaw, frontage, and threshold;
  inheriting the source parcel's half-cell phase is forbidden because it can move a door 1.5 m away
  from topology. Stone upper storeys participate in the same finite balcony/skywalk portal variants
  as timber families. Skywalk constraints
  preserve the exact authored centre-facade room socket rather than accepting any perimeter cell.
  After hero composition, a bounded residual 3D backfill stamps complete one-storey rooms into
  remaining inhabited cells. It ranks genuinely new occupied cover over public route cells first,
  accepts either the selected room recipe's exact transformed public threshold or a private parent
  edge (mere adjacency to a street is not a doorway), and requires terrain or an
  existing building for physical bearing. The selected scale caps both its total and per-kind room
  count, and those rooms are added to the final inhabited-room budget. Exact roof clearance remains the construction contract;
  an additional symmetric eave halo prevents a later facade or roof from rising through an earlier
  pitched eave without forbidding legal same-height roof meetings. The residual pass is ordinary
  building volume, never decorative mass, and its audit reports newly covered route cells and newly
  closed street-frontage sides independently.
  Storey diversity is audited from world-space floorplate columns rather than room
  kind or local origin, because even-cell rotations and origin changes can describe the same visible
  shaft. No accepted lineage may retain more than two consecutive identical tower floorplates, and
  no accepted tall lineage may remain a repeated world-space extrusion. Every occupied
  composition feature owns private volume through the same sealed exact-reservation contract; final
  ownership validation is intentionally feature-kind-agnostic. Full-scale annex/corner-union recipes
  remain diagnostic-only and have zero production quota; no dormer, straight pasted-on room, flue bay,
  or other decoration may silently substitute for them.
  After exact room composition, the same fine grid admits the scale-selected number of usable
  balconies across multiple building owners. Each is one measured L-shaped private occupied-floor recipe with
  two full-width deck rows, a third doorway-throat cell, a half-depth return, full two-band headroom, a
  reviewed door facade, nine exposed-boundary railing sections, two full-storey diagonal supports, one
  exact authored switchback stair, one exact room/bearing socket, and a named visual seam to only its
  source parcel stack. Selection permits at most two per building and forbids equal XZ/facing
  facade coordinates at different heights, so balconies cannot recreate a vertically repeated
  tower pattern. Their body, visual clearance, room endpoint, guard/open-seam/soffit faces, support,
  and construction transform commit atomically before roof selection. Candidate admission compares
  the balcony's authored AABB with both possible facade phases of every unrelated final room, so a
  lattice-clear bracket or eave cannot clip neighbouring construction. It also compares that exact
  AABB with every earlier feature construction record—especially the diagonal and shallow support
  courses owned by room-scale outcroppings—because those oblique meshes are not represented by the
  private-volume raster alone. Complete terminal room crowns also publish their finite measured
  gable alternatives into this admission pass; an optional balcony is rejected when it would block
  every valid roof for any house, rather than being discovered after reservation. Measured brace clearance may
  enter lower public air only as an explicit covered-street construction seam, and a brace foot may
  pass below the grid only within its horizontal bounds so it visibly embeds in immutable terrain.
  Flowered balconies
  are separate measured recipes rather than props stamped onto the plain structural form; the same
  transactional rule owns the garden versions of stocked markets and the planter/flower variants
  of roof terraces and setback gardens. Their five reviewed flower families remain inside each
  recipe's visual-clearance and fallback contract.
  Diagnostic whole-room outcroppings are either shifted final upper-room floorplates or same-storey
  diagonal corner unions, never small houses pasted beyond a facade. Production currently selects
  neither form. Each diagnostic recipe owns roof, floor, exposed side shells, and support while the
  corner union deliberately omits its shared parent quadrant. Small embedded
  oriels use an authored shallow tiled eave rather than a bare deck cap. A diagonal corner union uses
  two opposed, end-trimmed authored low pitches whose measured high edges meet exactly as one convex
  gable; the clipped runs preserve the exterior eaves while removing the decorative curls that used
  to overlap at the seam. It therefore avoids the old wooden tabletop, a concave valley, and two
  complete roofs crossing as a pinwheel. The preferred support is a measured
  diagonal timber course whose full 3D sweep must avoid public/daylight/service air, unrelated rooms,
  and feature clearance; a shallow bracket course is the explicit fallback, never horizontal trim
  masquerading as structure. Every accepted cantilever is either directly terrain/building-borne or
  owns one of those exact support courses; odd 4.5/7.5 m bearing edges close with an authored
  one-brace terminal after their complete 3 m courses, never a scaled brace. A room with no direct
  bearing remains invalid. After every room has been composed, the planner re-audits the final 3D
  solid claims rather than trusting proposal-time ancestry: it may relocate an unsupported
  floorplate, hand the load to a lower parent floorplate, or omit an optional terminal crown, while
  exact door and skywalk interface rooms remain fixed. The final audit permits zero unsupported
  room transitions, unresolved cantilevers, or irregular projections.
  The assembler recognizes disjoint upper walk surfaces across existing exterior air. It claims
  every disjoint lower-public-street crossing first, then may add separately valid upper open-air
  lanes; every supplement obeys the same two walkable end bearings, gap, and headroom proof and
  never replaces a real street crossing. Even runs of complete 3 m bays, up to three bays long,
  become 3 m-wide enclosed pitched-roof bridge-houses: complete tiled floors, complete windowed
  side walls, and one compact roof repeat per bay. The source span, its two endpoint rooms, occupied
  bridge room, lower public-air tunnel, and support ancestry are one topology compound before public
  air is carved. The source transaction reserves the complete inhabited body, both endpoint shell
  interfaces, and the complete repeated roof envelope before ordinary room composition; later
  feature reservations merge with those claims and may not replace them by priority. The bridge
  room's exact recipe integrates its two-ended supports, inhabited body, and one full compact roof
  repeat per source bay, including both authored eaves. The source endpoint-to-roof seam identity is
  carried through room recomposition into the final unit IDs, and each endpoint receives a
  seam-clipped party gable whose ridge follows the source span. Both sockets must be opposite and terminate on distinct terrain-borne building lineages;
  perpendicular contacts and same-building returns are cantilevers, never skywalks. A bridge cannot
  survive as a floating roof, independent room, or post-hoc visual link. Two parallel public lanes use full end portals.
  A single public lane may instead carry a typed 1.5 m lateral half-bay: the public lane bears at
  both ends and the
  unused companion lane is reserved as air. That form does not draw a full doorway into the empty
  half-landing. No corbel is rendered under either end of any span (they read as hanging stair
  flights); `SKYWALK_BEARER_DROP` still reserves the same headroom beneath the deck; they
  may not spill sideways into an unrelated lower street. Each compact roof is rotated about its bay centre so its authored ridge follows the
  crossing and its bearing plane stays exactly on the wall tops; no detached entrance posts or magic
  roof offset remain. The floor, wall, and ceiling visuals opt out of their source assets' overbroad
  baked hulls and use exact worker-side box claims committed on the main thread instead. The
  side/ceiling boxes are inset at both landings, and enclosure admission checks lower public headroom
  under every occupied lane plus public surfaces throughout the complete two-band roof volume, so
  the real player capsule retains every open endpoint gate, lower lane, and stacked upper walk
  without making the walls nonphysical. Every walked lane has structural end surfaces with
  continuing support; the passage may be open below, but its occupied upper shell can never be
  detached from a terrain-reaching building/public-surface chain. An open timber link reserves the
  one band above its deck required by the player capsule; the optional enclosed shell separately
  reserves two complete bands over every shell lane. A separate public walk in either occupied head
  band rejects the structural span because its player lane has priority. The conservative surrounding
  shell must also remain free of solid/occluding mass. Failing the enclosure-only check changes the
  presentation to the open timber bridge when that bridge's own player headroom remains valid; it
  never weakens the structural clearance. A one-cell gap remains the smaller railed timber bridge
  because the authored house shell cannot fit it without narrowing the player lane.
  Separately, already-clad massif faces may receive non-occupying facade bays or half-cell bump-outs
  only after the exact lower-course, route-headroom, built-mass, and blocked-feature tests pass.
  Their combined deterministic rate is 67%, capped at one projection per facade column, and every
  accepted projection is gated on the two measured corbel stations as a clearance proof only --
  nothing is rendered beneath it; this visual channel never invents a room or
  support fact. Ordinary two-column room jetties use the same rule structurally: one invisible
  support course per bearing column, sealed with the corbel's declared envelope. A broad
  attachment bracket or loose horizontal plank is not an eligible shallow
  jetty support. Green massif tops and the planned village green are generated by
  `TerrainChunkMesher.flat_ground_surface` as one exact union of their logical cells, not by scaled
  or overlapping KayKit grass panels. The production adapter binds that union to the same
  `ground_palette.tres` UV/material and fills its vertices from the same world-space
  `BiomeRegistry.ground_tint_at` field as streamed terrain. Exposed rims use
  `CliffDressing.TERRAIN_SKIN_ASSETS` and `CliffDressing.tint_at`, so their wall/lip assets and biome
  colour follow the terrain authority too. Shared cell boundaries and a rim derived from the final
  union make grass gaps, duplicate coplanar panels, and misaligned lips impossible by construction.
  Retained source stone is finalized only after measured roofs and structural cells are accepted:
  exact roof-placement volumes are subtracted, then the completed fine-lattice solid union is
  flood-solved from the sampled terrain bearing. A face-disconnected source component is discarded
  before skinning even when its obsolete envelope happens to touch finished structure; the sealed
  room/foundation bearing DAG, not incidental source stone, is the authority for building support.
  Detached construction-envelope scaffolding can therefore never appear as a rock cube around a
  roof or silently carry a floating building. Transition-owned and buried raw faces are removed
  before adjacent stone cells are paired, then face pairs and their treatments are rebuilt from the
  final exposed set; suppressing one surface can therefore never leave its former partner missing.
  Masonry panels are inset by their
  measured half-depth so their visible outer faces share the timber facade's lattice plane, keeping
  the grass lip continuous through material transitions. Tall retained faces alternate complete
  authored facade and coursed-stone storeys from the top down, so no pair of white/timber courses
  can form one uninterrupted multi-storey wall. Both upright courses and horizontal retained caps
  inherit one blue/orange/amber district stone wash; the near-white facets of the authored rock
  atlas can therefore never reappear as detached polygon scraps where a wall turns into its cap.
  Retained faces are capped at two storeys in the
  production audit, while the outer parcel profile steps to one-storey pitched-roof houses before
  the central mass rises. One deterministic narrow building on the lowest occupied datum may retain
  its seeded tower height as a vertical accent, but it still commits as one complete floor-to-roof
  house plot through the ordinary carved-volume, street-stranding, and terrain-bearing gates. More
  generally, a storey may be a public walkway/undercroft or a building may cantilever across it only
  when the occupied mass above owns an explicit endpoint, stack, bracket, or foundation ancestry that
  reaches terrain; elevated circulation is encouraged, unsupported upper architecture is invalid.
  The source's plaza deck is also a typed plan fact, not whichever decorative lawn happens to be
  largest: reservation grows one complete aspect-bounded macro rectangle, the public surface solver
  proves its entries and support, and `SettlementFabricPlan.planned_plaza_cells` carries that exact
  reachable square into the terrain-parity turf and threshold pass. Because those turf cells remain
  sealed public floor, late centre features and boundary planting are ineligible there; unwalked
  roof greens may still receive measured furniture. Tiny 1x1 leftover caps never become public
  plazas. Optional facade, roof, and garden decor is accepted only when its measured authored
  AABB misses the exact player-width swept prism over every exterior walk surface; suppression may
  remove an optional prop but cannot move a route, wall, roof, or seed-specific coordinate.
  Exact third-storey court frontage freezes only the contacted facade columns, not an entire room;
  half-storey paired relief indexes every occupied fine-Y slice and may atomically repartition two
  neighboring rooms before either is rejected in isolation. Addressed replacement rooms use the
  same two measured door phases as ordinary construction, and a load-bearing room below that
  threshold may still reshape while preserving the exact support column. The global support
  allocator may join collinear measured cantilever courses into one explicit timber frame; the
  compiler records those structural joins as semantic visual seams, while every unrelated room,
  feature, and support overlap remains forbidden.
  Lived-in roof, market, balcony, and facade dressing draws from measured collisionless plants,
  benches, chairs, bags, buckets, crates, barrels, lanterns, and firewood. Those props participate
  with their full authored AABBs in the same construction transaction as the room or structural
  surface that bears them; they are not a post-pass scatter that may clip walls or circulation.
  The fast diagnostic
  `tests/harness/warren_spatial_review.tscn` renders the already-sealed fine-grid candidate directly
  and adds route-transition, authored-facing dormer, outcrop-oblique, and front/underside balcony
  falsification views. `tests/harness/dormer_recipe_review.gd` separately renders the exact compiled
  dormer recipes from catalog meshes to verify their roof intersection without town occlusion. It deliberately bypasses corpus
  selection and is not evidence that the production selector accepted a seed. Its
  `--production-terrain-site` mode instead runs the real selected settlement transaction, commits
  the exact production entry list (including terrain-derived support posts), renders surrounding
  `TerrainChunkMesher` chunks in the town's local frame, and omits the diagnostic road skin so paths
  remain the actual terrain or structural surfaces production owns. The spatial fabric
  compiler assigns every segmented building lineage one of three deterministic authored
  construction styles, independently of streaming. Each exact tower/slim/row/square/long footprint
  has a flush and rich recipe in that style with identical solids, inhabited volume, sockets, and
  entrances; storeys alternate only within the lineage's pair. Theme/form/style-selected ivy,
  clothes, signs, or planter-and-flower windowboxes form the measured rich phase, which retries its
  paired flush recipe when the projection conflicts with already accepted construction. Before that
  choice it derives a finite mandatory weather-closure domain from the sealed occupancy/roof faces:
  complete terminal plates reserve an exact tiled gable profile, private partial rows reserve their
  handed clipped-gable alternatives, and plank backing is eligible only when that row already owns
  a sealed public floor. The same closure groups are preserved against optional features before
  final face regions exist, then rechecked semantically and by measured AABB after each roof choice,
  so a facade, balcony, or earlier crown cannot consume every valid roof of a later house. A
  bay/laundry/sign phase may fall back, but cannot make the later roof pass impossible. Every pitched roof placement is aligned from its measured visual
  lower bound to the logical wall-top bearing plane; composite row/slim crowns may vary horizontally
  but may not raise one neighboring shell above another. `SettlementFabricPlan.add_unit()` also
  rejects every complete pitched roof whose measured visual XZ centre or wall-top bearing differs
  from its logical solid footprint, so an offset crown cannot enter the sealed transaction. It stages
  semantic occupancy and publishes
  it only after visual-envelope validation, so a rejected rich phase cannot leave ghost claims that
  poison that exact fallback transaction.
  Production then compiles the sealed spatial plan and rejects it unless inhabited/structural mass
  covers at least 38% of public route cells, all-height through-core sightlines are at most 48, and
  ground through-core sightlines are at most 20. These are screenshot-backed acceptance gates, not
  decorative scores: a feature-complete town with an open plaza or horizon-length street is not a
  production result. Diagnostic review disables no visual-overlap rule; every captured candidate
  must pass the same strict measured-envelope transaction as production.
  Skywalk reservations are solved against the fixed exact parcel partition and preserved through
  asset compilation; do not fake extra links when no independent measured corridor exists. Rules
  that read a plot-model fact are guarded by `mass_context.has(&"maze_source_plan")` so a
  hand-built fixture volume cannot trip them.
  `WarrenVolumeEnvelope` is the shared height/address envelope the sealed `WarrenVolumePlan`
  carries; `WarrenMazeVolumeAdapter` builds one for every town through
  `WarrenExcavationVolumeAdapter.envelope_from_massif`, and `VillageWarrenFabricSolver` samples
  real terrain against it. That plan distinguishes remaining building `MASS`, abstract `WALK`
  floor planes, swept `PUBLIC_AIR`, and deliberate `DAYLIGHT_VOID`. `WarrenVolumeTransition` owns both endpoints and complete swept air;
  every edge changes by at most one 1.5 m circulation band. Vertical edges always reserve a physical
  span between two square landings: a two-macro-cell edge owns a complete 3 m stair, while a
  three-or-more-cell edge owns at least 6 m and becomes a sloped walkway. Perpendicular vertical
  turns require square landings; adjacent full platform squares are never accepted as a zero-length
  stair. The parcel contract itself is unchanged by who produces it: only roofable 1x1,
  narrow/deep 1x2, and 2x2 macro footprints, never a frontage wider than its depth, and only
  complete 3 m inhabited storeys on arbitrary 1.5 m base phases. The parcel's real transformed
  authored door must land inside its addressed public square; a facade-wide proxy address is
  invalid.
  `WarrenVolumePublicRealmAdapter` expands the route losslessly into the common two-lane lattice.
  Its only added surfaces are small one/two-ring courts owned by existing elevated route nodes;
  optional one-cell galleries preferentially cross a lower public route or terminate in a pocket
  bounded by two inhabited facades. Both remain short route-fused strips with exact support,
  headroom, guard, and connectivity proofs; neither can become a detached suspended platform.
  Ground-street cells without inhabited or structural overhead are flood-audited as same-level
  components; no accepted component may exceed twelve 1.5 m cells. After hard raw-core closure,
  optional galleries are chosen by the reduction they make to the largest such component before
  aesthetic scores break ties. `WarrenPrunedMassPlan` owns whether provisional Gaussian mass is
  real structure: only `BUILDING` and `BEARING_OPPORTUNITY` block headroom. An `OUTSIDE_CORE` cell
  may support an upper-gallery extension only when that cell directly shelters an already sealed
  lower public route, so tapered-envelope air cannot act like an invisible ceiling or authorize
  arbitrary suspended terraces. `WarrenVolumeTransition.surface_cells()` is the shared exact
  two-lane stair/ramp footprint; platform discovery reserves that surface plus its full headroom
  before admitting any gallery.
  Lightwells are subtracted after the full union is known only when every cardinal side is public
  surface or inhabited wall and a flood proves every surviving extension cell still reaches its
  owning route square; an explicit unbounded hole is rejected. Raw
  parcel-stage openings are audited before infill and no cardinal component may exceed
  four macro columns; post-infill permits no unclassified 3 m core aperture at all. Only
  isolated, bounded, guarded 1.5 m lightwells may then be subtracted, with at least three
  fine cells between their XZ projections even across different levels. This prevents a broad
  failed cavity from being hidden beneath one low deck. Incidental court contact beside a
  transition is reduced to a deterministic non-overlapping seam subset rather than duplicating
  stair lanes.
  The compiler derives facade openings, guards, and collision-bearing ramp/stair meshes from
  those same facts; each vertical transition covers every logical stair cell, owns two side rails,
  and meets both landings across exact two-lane seams. Horizontal courts render reviewed fixed
  board assets while the generated union remains collision-only, avoiding the duplicate dark skin.
  The fine spatial plan additionally proves the source volume's exact route surface is a subset of
  the final connected route (late market aisles may only extend it), and the common spatial surface
  compiler must receive that immutable volume lineage so every logical vertical edge has matching
  render and collision geometry. The review harness includes low-landing transition captures; a
  connected graph without a visible/collidable climb is a failure.
  stair/ramp meshes use a stable plank shader. Sparse timber supports derive from exposed court
  cells down to an explicit datum, while a court only one half-level above terrain is enclosed by
  fixed retaining-wall modules instead of becoming a crawl-height undercroft. The production
  terrain adapter likewise derives posts from exposed public-surface boundary corners and repeats
  them at the authored 3 m structural rhythm; fully enclosed interior cells are omitted so a broad
  deck gains a legible perimeter load path without becoming a forest of posts.
  `WarrenSpatialFabricCompiler` compiles the measured terrain-rooted stacks, complete roofs,
  occupied skywalks, and roofed outcroppings through one common fabric/air/solid-void transaction;
  `WarrenAssetCompiler` survives as its vocabulary helper (facade-family selection, room and parcel
  socket endpoints, skywalk compatibility, the partition asset cache) after task F1 deleted its own
  `solve` entry along with the searched town it compiled. Visually one-storey proposals and every
  frontage-wider-than-depth orientation are ineligible. Equal-height, equal-family neighbours may
  meet only through an exact collinear-eave party-wall seam; unequal, gable, corner, and overlapping
  contacts remain conflicts. Occupied straight skywalks use a measured pitched repeat-and-gable
  roof run; a floor module is never reused as their ceiling. Complete stocked-market candidates
  prefer residual open-core columns before their stable hashed tie-break. Exact frontage, overhead,
  occupied-link, and sightline audits own the final no-through-street decision -- as GUIDANCE
  carried in the audit, not as gates: there is one candidate, so a metric a town misses is a
  recorded fact rather than a rejection. The composed-enclosure viability floor, the ranked
  eight-plan frontier and its rescue-plan tier were properties of the searched frontier and died
  with it in task F1, together with the terrain-level arcade branch grammar
  (`WarrenGroundArcadeSolver`) that ran before parcel packing.
  HISTORICAL, and kept only because the invariants it names are still enforced: the four-seed
  measured gate and the 44-image cleanup review above were measured on the SEARCHED pipeline that
  task F1 deleted, so their per-seed counts describe towns nothing builds any more. The structural
  facts they pinned do survive as gates in the compiler and the plan seals -- distinct
  maze/construction signatures, connected roofed buildings, zero visually short parcels, no stair
  endpoint gap, isolated guarded lightwells, no unclassified 3 m core aperture, a bounded largest
  uncovered lower-route component, and zero public-air/occupied or visual-envelope overlap -- and
  the falsification findings behind them still hold: four lightwells could leave one broad opaque
  upper court where six bounded fine-cell wells break that surface without reopening a
  top-to-ground shaft, and cardinally bounded subtraction could still sever a one-cell route neck
  until route-connectivity validation was added. The CURRENT corpus measurement is the sweep's:
  24 of 24 towns seal, and the four planner seeds (12/4 compact, 3/9 standard) are solved
  end to end by `tests/test_warren_maze_composition.gd`. Visual review is Phase G's battery.
  `VillageWarrenFabricSolver` aligns the selected volumetric landing to the production road,
  resamples immutable terrain bands, and materializes that sealed fabric through `VillagePlan`.
  The route node is where the arriving road ends, so the entry's terrain contact -- the foot of the
  handoff ramp plus the road's half width -- is anchored on that node: a gate that faces the road
  meets it head-on, and a gate the terrain forced sideways meets it as a right-angled T instead of
  swallowing the road's last metres under its edge houses. Every quarter is also tried with the
  older entry-cell anchoring, ordered after the contact-anchored frames of the same alignment, so a
  seed whose secondary gate loses its projection at the shifted frame still builds. Each gate
  handoff quad chooses its winding per contact (the lateral tangent is a cell-order convention, not
  a handedness), so no ramp is back-face culled from above.
  Missing common fabric vocabulary is a construction error, never a request to invoke an older
  terrain-led fallback.
  Village contracts live under `features/villages/`: `VillageProgram` caps anchors at
  144 m and records at the settlement's 192 m inset; `VillageFrame` freezes the accepted route
  signature; `VillageRecord` seals sorted semantic output; `VillageOccupancy` is a bucketed typed
  3D index (`SOLID`, `WALK_SURFACE`, `HEADROOM`, `GROUND_EXCLUSIVE`, `WALK_GUARD`). Public
  `WALK_GUARD` rails may meet only walk surfaces or sibling guards in their explicitly declared
  walk network; generic solids never inherit that seam permission. `FoundationSolver` proves
  enterable floors above natural terrain and tiles fixed perimeter modules; `SupportSolver`
  composes fixed-height stacks with bounded burial and atomic occupancy. `VillagePlan` solves one
  atomic `VillageUrbanFabricPlan`; its furnishing belongs to that same transaction and there is no
  legacy post-pass for standalone props. A rejected urban solve emits no village payload, so a tent or campfire can never
  masquerade as a settlement. `VillageRecord.urban_fabric` is the canonical typed structural
  record; the older fixed `VillageElevatedDistrict` and its isolated regression test have been
  removed. Production rolls only
  village/town; the compiled hamlet vocabulary stays dormant until it can satisfy the same
  inhabited multi-level contract.
  `VillageOutskirtsSolver` runs only after an accepted urban transaction. Every painted outskirts
  lane, including the final spur to a prefab doorstep, is the ordinary `PathProgram.PATH_WIDTH`;
  only the spur's reserved headroom narrows to the measured doorway. The edge district is meant to
  RING the dense core (2026-09-04): each exit's neighbourhood reaches sixteen grid steps so the
  flanking runs of two or three gates wrap most of a silhouette, six roots per side are ranked,
  and `VillageOutskirtsProgram.target_houses` asks for 6/9 houses or three per sealed exit. The
  town's terrain-qualified perimeter stalls are published on `VillageUrbanFabricPlan.frontage_sites`;
  the perimeter grid blocks them like mass so the lane runs in FRONT of the stalls, and a root
  facing a stall row is a MARKET lot: its house stands one `MARKET_STALL_BAND` (three cells) back
  from the lane's outer edge, and every town stall fronting that lane gets a TWIN of the same
  reviewed asset directly across it (slid sideways past the door spur when the house is centred
  on it), standing as close to the lane as the lane clearance allows and under the prefab's
  eave, its occupancy clipped at the headroom line exactly as the house's own eave is; each twin
  is proved on level dry ground and against district occupancy, keyed by the town stall it
  mirrors so two market lots cannot double it. The street then has market fronts on both sides
  and a building behind. For production volumetric
  warrens every sealed terrain exit seeds one bounded entrance-neighbourhood street graph. The
  solver rasterizes the exact union of `SOLID`, `WALK_SURFACE`, and `WALK_GUARD` volumes on the
  shared 3 m world/village lattice. Lots stay on its nearby one-cell exterior contour, from
  one through sixteen grid steps from their nearest exit; street routing may use the bounded
  three-cell exterior band to avoid copying every facade notch. Direction-aware search minimizes
  turns first and length second. Each demanded route roots back to the primary road contact,
  rather than ending in an isolated secondary-exit fragment. It never draws a belt road around the bounding
  box or offers parcels no exit neighbourhood reaches. A local street occupies the single grid cell between the urban fabric
  and the prefab frontage; district/ecology clearances and the union's bounding rectangle cannot
  create a vacant moat. Candidate perches are qualified inside that bounded corridor *before*
  terrain ranking is capped, and alternate roots remain at least one compact-house frontage apart.
  The corridor derives each candidate centre from the exact oriented support radius, so even- and
  odd-cell footprints both put their wall immediately beyond the lane without a later offset. A
  broad prefab's authored off-centre door projects onto that same continuous contour lane, but its
  bearing remains cardinal and its measured support footprint must remain immediately outside the
  lane. The complete house is transformed in the same uniform 2x authored-to-world frame as the
  dense warren; visual meshes, attachments, collision, support, doorway, and occupancy all share
  that transform. The full upper/eave envelope is still reserved above public headroom, while
  ground-route collision uses the borne support footprint below headroom and the broader visual
  envelope above it, so an eave cannot masquerade as a wall. Its door
  faces a short connected doorstep spur; its reservation may taper to the authored threshold,
  while all painted paths retain the normal 4 m width. Complete polylines remove collinear
  segmentation and use `PathProgram.filleted_path_shapes`: the normal road's 4 m centreline
  radius (limited by short runs), with 32 capsule chords per quarter turn. Both producers paint
  through the same terrain path/spot surface, not a second road material or overlay. Finished
  curved paint is checked against ground-level solids, without rejecting valid overhead roofs.
  One exit may serve multiple nearby houses, but
  every sealed exit must retain a proved neighbourhood connection. The production entry comes from
  the sealed source volume's exact world transform; local frontage selection remains separate from
  its connection to the shared primary-root street tree. Repeated reservation edges deduplicate
  by stable identity, and coincident paint is a field union rather than overlapping mesh sheets on shared
  paths. Houses are complete enterable authored assets placed once at ground level, with attachments, a measured
  perimeter foundation, a proved public lane, and the same typed occupancy transaction as the
  dense core; tents and detached prop shelters are ineligible. Failure remains optional and leaves
  no partial edge payload. This makes the settlement taper into an immediate inhabited ground-level
  entrance district without growing a disconnected radial camp or a gratuitous full-town ring.
  `VillageTerrainView` is the only cross-block terrain/water query adapter;
  `VillageTerrainSurvey` discovers and spatially buckets guarded-source-dry buildable perches
  without mutating the heightfield (exact water remains a final-transaction check); and
  `VillageMassingSolver` uses a bounded, composition-diverse beam plus a ranked complete-plan
  frontier to pack 7–15 inhabited buildings into a 42 m core (10/15 authored targets for
  village/town). It tries comparable ranks
  across building counts instead of exhausting near-duplicate dense failures first. The massing
  contract requires at least three irregular elevation bands, short neighbours, and real
  half-rises while preferring direct terrain contact over bounded retaining-terrace variants.
  `VillageVerticalProfile` derives its 12 m full / 6 m half-level cadence from the tallest
  stackable furnished house plus roof clearance; terrain storeys remain an unrelated landform
  unit. The route landing and already-solved ground market are hard reservations, each accepted
  footprint expands into both legitimate facade directions, and reviewed door/stair access is
  qualified before beam search. Larger furnished houses are ground-only accents, so adding asset
  variety cannot silently increase the vertical cadence or erase the compact-house vocabulary.
  `VillageMarketSolver` runs first and selects one connected orthogonal alley topology before any
  building is admitted; reviewed stalls line both sides where terrain and exact 3D occupancy
  permit. The market's street/headroom volumes participate in the same massing transaction rather
  than being optional decoration added after the town exists.
  `VillageCirculationSolver` owns topology only. It first builds all cheap direct right-angle
  terrain edges, then asks `VillageGroundRouter` for bounded A* detours solely between remaining
  disconnected components. Ground routes may cross natural height bands only through frozen
  fixed-module `VillageStairTransition`s. `VillageRouteStairFabricSolver` materializes each flight
  on the exact requesting terrain edge, keeps the worn street continuous beneath it, derives two
  slope-aligned collision-bearing side rails per stair module, and treats intersecting ground
  flights as one public-circulation compound. `VillageAerialRouter` derives a
  bounded acyclic set of short rounded links and one-module-deep public forecourts that exist only
  at inhabited facade seams. There is no long-span or empty suspended-platform fallback.
  `VillageRouteGeometry` owns the shared swept-headroom facts. The graph must connect every door to
  the route landing, contain a useful ground-street fabric, at least two local aerial links, and at
  least one inhabited shared platform; aerial links remain at most 24 m.
  The support compiler freezes each massed floor and chooses one typed atomic mode from terrain
  opportunity: naturally supported perches receive the ordinary fixed perimeter foundation,
  while retained perches receive the compact rock core. Exact 1.5 m timber cells
  exist only outside that core under the unsupported part of the building (plus one skirt-apron
  row), or on a thin route; a whole tile is removed when its OBB overlaps any core. There are no
  substantial uninhabited suspended platforms. Exposed timber edges derive exact compound
  railings, with graph openings at doors and stairs. Sparse fixed timber support stacks sample
  exposed boundary corners at roughly one stack per three modules and never use non-uniform scale;
  individual candidates are
  omitted if they hit a core, stair, water, unsupported ground span, terrain above the deck, or a
  lower walk surface. Required rock stacks reference the lowest ground under their broad stencil,
  may bury by less than two storeys on the high side, and use at most eight fixed modules, so they
  seal natural slopes without stretching or floating. Rock cores, buildings, skirts, routes,
  stairs, railings, and protected undercroft headroom beneath the lowest viable inhabited overhang
  all validate before the district materializes. Bound ground activity is optional and cannot
  veto a complete inhabited district; any required-structure failure omits the whole transaction.
  `VillageOutskirtsSolver` may then place sparse houses immediately outside the exact occupied-volume
  contour. Every sealed terrain exit feeds its bounded local entrance-neighbourhood street graph;
  no street is extended around unrelated sides of the settlement. Each complete prefab sits one
  shared 3 m lane outside the core, remains aligned to the town lattice, faces its doorstep connection, and is shown in
  corpus review together with the dense city rather than as an isolated facade. Sparse ground houses never
  substitute for the required dense urban transaction. Production outskirts use complete
  enterable furnished houses across blue/orange runtime variants, including the larger SFV homes
  that remain awkward inside the sectional grammar. Selection is a bounded measured construction
  search: each lot tries the upper support-area cohort first, then independently surveys progressively
  smaller complete prefabs only when the exact terrain contour, doorway, or neighboring mass cannot
  carry a larger candidate. Tents and closed-front shelters remain catalogued but are excluded from
  this inhabited taper. Freestanding tables are never facade-gap filler; table dressing appears only
  inside a complete reviewed market envelope whose support and clearance were admitted together.
- **`field/WorldFieldBlockCache.gd`** — the worker-confined canonical owner of independently lazy
  terrain regions and exact water contexts. Half-open 192 m keys and deterministic bounded LRU
  make planning, meshing, water, and dressing share the same live field objects without locks or
  output dependence on query order. A block region is `compute_region(key*16+8, key*16+8, 16)`
  in points (certified interior `key*16-8 .. key*16+24`); coverage checks the tile corners a
  rectangle touches (`floor(x0/12) .. floor(x1/12)+1`). `serves(plan, water_plan)` tells the
  mesher whether it may share the cache (`mesher.water_blocks`). `TerrainTileField.is_walkable_edge`
  is likewise the one symmetric wall fact shared by path traversal and the rendered mesh.
- **Environment assets** (`scripts/terrain/environment/`, `terrain/environment/`) — source-pack
  scenes are editor-baked into lightweight descriptors plus self-contained meshes, materials,
  textures, typed visual pieces, and optional typed collision pieces. Manifest scale is applied
  exactly once at bake time: KayKit retains its legacy wrapper scales and LPFV nature uses a 3.25×
  pack correction. Reviewed KayKit primitives are preserved from bake-only collision templates
  where they fit: the owner's original three-cylinder proxy remains on KayKit rock 1, while
  rock 2's oversized sphere is replaced by a mesh-derived flat-topped hull. KayKit trees 2 and 4
  are intentionally absent from the catalogue.
  LPFV rigid assets normally use one snag-free primitive per disconnected hard component. Trees use
  a rotated capsule around only the grounded lower trunk, fitted from true mesh cross-sections so
  sparse/leaning low-poly vertices cannot pull it off-centre. The strongly curved LPFV tree 2 uses
  an explicit four-capsule chain instead: short capsules follow successive cross-sections and
  adjacent capsule axis endpoints are the exact same point, making their hemispherical caps
  concentric at each rounded joint; one global chord can no longer protrude from the bend. Logs use
  flat-ended rotated cylinders, the
  fallen branch uses a rotated capsule, stumps use flat-topped cylinders, and rocks use an inset
  box or a convex hull whose top is flattened into a face. Multi-rock source clusters declare their
  hard-component count in the manifest, so each visible stone receives its own disjoint hull rather
  than one collider bridging the empty space between them. Decorative foliage and mushrooms never
  enlarge physics. This deliberately avoids overlapping compound-shape lips, point-topped walkable
  objects, and collision that bridges empty space. Low rocks tagged `walkover` cap their collision
  height so their largest authored dressing scale remains below the character's step height; a
  catalogue test couples those values and prevents later tuning from breaking traversal. Assets
  tagged `tree`, `rock`, or `deadwood` are rejected by
  the bake unless they declare collision, so rigid dressing cannot silently become non-blocking.
  Runtime consumers use
  stable asset IDs through the
  lightweight `EnvironmentCatalog`; the main-thread `EnvironmentRenderCache` selectively loads
  only active visuals. `EnvironmentInstancePayload` may mask collision on an individual visual
  placement and carry resource-free box transforms/sizes when a generated construction has a
  tighter reviewed traversal contract than the reusable asset's baked hull; only
  `EnvironmentCollisionBuilder` and `FeatureCommitQueue` create those `BoxShape3D` resources on
  the main thread. Both adapters must honor the per-placement collision mask; visual-only bridge
  shells may never silently regain their broad baked hulls while crossing the village record.
  Environment runtime resources never depend on the source packs under
  `assets/`. `tools/environment_bake/` is the only owner of those source paths. Generated palette
  variants may selectively recolour foliage texels. The dense-grass bake may select an authored
  subtree and merge/simplify either separate or indexed-component ribbon leaves, optionally
  spreading whole components radially and retaining per-component root XZ in UV2 for local
  deformation; the current
  collision-free Collection 5 patch is about 1.10–1.27 m tall after authored variation and does
  not participate in ordinary dressing. The
  Fantasy Village man-made feature pack uses
  a reviewed 2× human-scale bake correction for its freestanding arches and lamp. A manifest
  fallback supplies the orange atlas missing from the second large arch's source material, so the
  correction is baked into the self-contained runtime asset. Its bridge
  retains the independently calibrated `[1.2, 1.0, 6.0]` vector scale that supplies a human-scale
  deck and rails plus the required crossing span. Large arches use compound collision following
  four posts, upper beams, diagonal braces, and both roof slopes; the character-height opening
  stays clear while collision reaches the visual top and depth.
  The reviewed village-structure bake likewise treats collision as structural geometry, never a
  prefab-wide box. The campfire/spit uses six cylinders (ring, crossbar, and four stands); the
  walk-in tent uses one two-sided triangular roof shell, four rectangular posts, a rectangular ridge, and a
  triangular back prism; stalls use four posts plus three canopy panels; stocked tables use a top
  and four legs; the well uses eight disjoint ring segments, two posts, and two roof slopes; fence,
  railing, and quest-board assets preserve their separate rails/posts/boards. Catalog tests pin
  these primitive mixes and piece counts. `environment_lineup.tscn -- --asset ID
  --show-collision --collision-closeup` is the required visual check; add
  `--depth-test-collision` to expose only proxy material outside the rendered mesh.
  Every active material still multiplies
  the independent per-instance biome tint. `terrain/materials/forest.tres` is a self-contained
  bake-compatibility path for Godot's imported KayKit scene UID, not a runtime material owner.
- **`field/FieldTerrainStreamer.gd`** — the only scene-tree node (`Node3D` in `world.tscn`,
  wired to the player). Builds field chunks within `CHUNK_RADIUS` of the player on **one
  background worker thread**. It compiles dressing, grass, and the composed `FeatureProgram`,
  then warms terrain, nature, and grass resources on the main thread before starting the worker.
  Man-made feature assets are deliberately excluded from eager warm-up and demand-loaded by the
  commit queue.
  The worker returns only arrays/transforms/sampler payloads. Terrain and feature generations are
  independent, but queued requests for one block widen into one job. `GrassSamplingContext`
  detaches completed field inputs from their canonical owners and mutable caches. One separate
  `GrassWorkQueue` computes nearby ordinary grass tiles only after their terrain is committed,
  cancelling distant queued work on movement. It never enters the canonical planners. Grass
  never gates terrain readiness. A completed terrain payload waits in one nearest-first
  list until every key in its footprint-derived feature halo is ready; v1's maximum footprint
  yields exactly the lexicographically sorted 3×3 square. Empty feature blocks are explicit ready
  records and allocate no node/resource. `FeatureCommitQueue` demand-loads sorted assets and
  incrementally creates collision under count + elapsed-time budgets; only a collision-complete
  block attaches under `ManmadeFeatures` and becomes ready, while visuals remain independently
  budgeted. Terrain then
  commits in terrain → water → dressing collision → `add_child` → FX → dressing visual order,
  `MAX_BUILD_PER_FRAME` per frame, nearest-first, evicting beyond
  `KEEP_RADIUS` (features use `KEEP_RADIUS + feature_halo`). The worker exclusively owns its
  `_settlements`/`_features`/`_water`/field/mesher instances, so their
  caches need no locks. `FieldTerrainStreamer` also remains the only owner allowed to attach the
  grass and trample roots to the scene tree; grass runtime is skipped in headless terrain runs.
  Each sealed village's complete instance/collision payload belongs to the feature block that
  contains its canonical centre. Its ground and clearance shapes remain query-projected. Because
  the compiled record reach is less than one block, the existing one-block feature halo keeps that
  owner resident anywhere the village can intersect terrain while avoiding duplicate per-asset
  MultiMesh and physics batches across several blocks.
  At startup the player is frozen until every chunk within one 192 m chunk of spawn
  (`STARTUP_SUPPORT_HALF_EXTENT`) and its feature square is ready. The production spawn is inset 0.5 m into chunk `(0, 0)` so its
  capsule has one collision owner, but the camera-visible startup boundary still covers all four
  origin quadrants; later, a missing current
  chunk freezes them during teleports or when outrunning the worker. Collision therefore cannot
  pop in after movement starts. Ordinary radius terrain is not queued until this startup set and
  its feature dependencies finish, preventing unrelated mesh work from extending the loading
  screen; the cold river/path spike stays off the main thread. Owns the
  `world_seed` (random per run). `TerrainWorldTuning` is the single owner of
  `HEIGHTFIELD_AMPLITUDE`, `HEIGHTFIELD_MAX_STOREYS`, and `MAX_CLIFF_STEP`; the streamer has no
  inert inspector mirrors whose values look editable but are ignored. The worker publishes
  per-point `storeys` and `points` (height, graded) snapshots for its chunk's 16 x 16 points;
  main-thread debug queries are `loaded_storey_at(point)` / `loaded_point_at(point)`, never the
  worker's plan. It sets `mesher.water_blocks` to its own `WorldFieldBlockCache`.

## Shared fields & utilities (`scripts/core/`)

- **`TraversalEnvelope.gd`** — resource-free canonical player capsule, aperture, headroom, and
  finished/planning step limits. Village solvers consume it and a scene contract test pins it to
  the live character collision and controller constants.

- **`Helper.gd`** — deterministic, infinite-terrain-safe noise fields, all pure functions of
  `(pos, world_seed)`: `macro_density01`, biome fields `biome_forest01` / `biome_rocky01` /
  `biome_foliage_density` / `biome_weights5`, value-noise
  (`_value_noise01`), and hashing helpers (`_cell_hash01`, splitmix64 `_mix64`). Also
  transform/AABB/collision helpers. `HeightfieldPlan._height01` samples these for landform shape.
  (Some doc comments here still name the retired `TerrainGenerator` — ignore those references.)
- **`Distribution.gd` / `PriorityQueue.gd`** — small generic helpers.

## Terrain tools & water

- **`terrain/tools/CoordOverlay.gd`** — the F3 debug HUD (in `world.tscn`): a crosshair plus a
  readout of the seed, the player's and the crosshair's lattice point (`point_of`), and
  (`tile_lines`) the tile under the crosshair with its 2 x 2 corner storey/levels and its four
  edge categories. A screenshot alone then pins down exactly where a terrain issue is — use it to
  reproduce a reported bug by its seed and coordinates. It reads only committed per-point
  snapshots; the main-thread HUD never reads the worker-owned plan or caches.
- **`terrain/tools/TerrainCategoryOverlay.gd`** — the F9 view: a screen-space decal over every
  surface fed by a 128-point snapshot window. Each lattice edge colours the diamond around its
  midpoint (grey flat, blue level, green slope, red cliff); magenta/cyan mark rendered surface
  above/below the kernel, which the shader evaluates through
  `terrain/materials/debug/terrain_tile_kernel.gdshaderinc`, a line-for-line port of
  `TerrainTileField` (cliff end pushed from `TerrainTileField.cliff_end`). Tile grid at 12 i, faint
  wall lines at 12 i + 6, chunk borders every 16 points, yellow stripes on graded points.
  Harness: `cliff_site_review --categories`.
- **`terrain/tools/SlopeProfile.gd` / `SlopeAtlas.gd`** — the `smootherstep` slope profile math
  and grass/rock UV sampling from KayKit pieces, shared by the field and mesher.
- **Water** (`scripts/terrain/water/`): a deterministic **river network carved into the
  heightfield** — `WaterPlan` surveys four stratified candidates per 768 m district,
  climbs the highest to a prominent summit, and uses an 85% source roll. Its bounded
  2D contour walk prefers modest descent, keeps a winding handedness and clearance from
  old reaches, and drifts outward so it cannot close a loop around itself. Natural terrain
  can rise along a proposed open cutting, but the bank-contained hydraulic bed never rises.
  Raw routes allow 4.32 km of arc inside a 2.4 km displacement bound; basin termination
  starts at 2.64 km. The finite discovery halo includes summit ascent and the lake bound.
  Junction resolution selects a prefix of the cached raw route, never retraces the mountain.
  Odd-depth dependency prefixes remain contained in the realized depth-two network, so a
  tributary cannot join a part of another river that subsequently disappears.
  Raw bounds reject distant sources before expanding junction dependencies; neighbour queries
  use an immutable spatial index with canonical precedence. Terminal `PondStamp` bowls vary
  in size, axis and elongation within the same conservative radius bound. Carve applies
  inside `HeightfieldPlan.raw_height`. The 20–26 m channel half-width exceeds half a terrain
  cell's diagonal: diagonal centreline crossings fully excavate both intermediate cells,
  preserving a finite cardinal passage rather than corner-only contact. Channel carving
  projects each terrain sample onto the same
  variable-width trace **segment capsule** used by `WaterField` (not isolated trace-point
  discs), so bathymetry cannot leave uncarved 12m gaps beneath continuous rendered water.
  `WaterPlan.planning_signed_distance` / `planning_intervals` expose that same source geometry
  with one fixed guard for cheap route planning; they never build hydrostatic water.
  `WaterFieldContext.wet_intervals` is the exact, lazily contour-cached counterpart for final
  route and bridge validation, so feature consumers never reproduce water geometry.
  Beds obey **containment** (`CONTAIN_DROP`): every bed is
  capped a full storey below the lowest flanking bank's natural storey, so channels always
  quantize bounded by ground on both sides — never a sheet hanging off a hillside. The
  hydraulic trace bed and rendered bathymetry are intentionally separate: ordinary reaches
  excavate another `CARVE_BED_EXTRA` below the trace bed so 4m storey quantization cannot
  leave only centimetres of cover, while reaches whose trace-bed grade is already a fall face
  keep the original shallow carve (never turn a vertical film into a deep swim volume).
  **On the dual grid (September 30)** water reads ground only through `TerrainTileField` (12 m
  points; `WaterField._point_domain` sizes trace/source regions in points, the ground lattice bakes
  per `point_of` owner). The coarse fill lattice sits off every discontinuity: nodes at 12 i ± 3
  (`WaterField.FILL_OFFSET`) in chunk windows (one extra cell keeps the 42 m margin) and source
  solves. The 3 m rescue lattice (same origin) still has nodes and cell edges on wall lines:
  `_shore_support_level` reads a rescue edge's ground 1 mm off the line on its `point_of` (+x/+z)
  side. Parked: an unrescued rescue corner on a wall line is judged against its `point_of` ground,
  so a rescued cell can meet an untouched coarse cell up to ~0.03 m off (pending test
  `test_september13_water_corner::test_rescued_cell_meets_the_coarse_surface_beside_a_wall_corner`,
  (1225, -56.375); follow-up: per-side ground for border rescue nodes). One fill evaluator,
  `WaterField._fill_bilinear`, serves the field and the frozen `WaterSampler` (which keeps the fill
  arrays and a `WaterGroundSnapshot` of the window's point heights), so the swim sampler matches
  the rendered field exactly, shoreline support included. It is wall-aware: a cell straddling a
  real cliff is evaluated per side, probed at the query's own coordinates — a spill runs to a
  crest held on the wall at crown + `DESCENT_CLAMP`, a wet/dry pair keeps each side's own value,
  a submerged wall stays linear — and `_wall_span` switches by smooth weights (cliff from
  `FALL_DROP_MIN`/2 to `FALL_DROP_MIN`, spill over `DESCENT_CLAMP` around the crown), so water
  stays continuous where an E2 wall tapers. Node grounds are memoized (`node_ground`); cells whose
  nodes differ by < 1 m skip wall probes. Walls are vertical skirts exactly on the dual border, so
  `WaterSkin.RIM_WALL_REACH` is 0 (a wall only ever extends rim rows) and the rim end cap fans
  from the buried outer row. The swell trough reserves `WaterSkin.SHEET_COVER` = 0.05 m (cliff
  sheet cover over the 2 m chords). Contours are cut at every world chunk line (canonical
  crossings, even division, arcs <= 2 m) so neighbouring chunks weld exactly. A chunk's swim
  triggers cover only its own tiles. `WaterPlan.CARVE_FEATHER` (4 m) is the narrow-profile carve
  band; `FEATHER` (8 m) stays for the containment survey and route spacing. Pond banks
  (`_pond_level`) are the minimum over every 12 m point within the max-wobble radius + 24 m.
  Tests: `test_water_dual_grid`, `test_water_wave_clearance`.
  Pure data flows `WaterField → WaterContour → WaterSkin`, turned into nodes by
  `WaterSurfaceBuilder`; one shader renders it all:
  - `WaterField` — profile and canonical-region caches identify both the immutable trace
    and its terrain-plan owner, preventing different worlds or junction prefixes with the
    same source cell from sharing stale levels. The continuous water surface is ONE height field `level_at(x,z)`, with
    **no cuts anywhere**: `profile()` is a single monotone, continuous curve per river.
    Ordinary reaches ride a smooth trend between anchors or hug a nearby steep face
    (unchanged in spirit); but a genuine multi-segment descent — several storeys down a
    real slope — is instead reshaped as ONE smooth **sill-riding envelope**: monotone C1
    cubic-Hermite, knots at the two span anchors plus any sill the naive curve would
    otherwise duck under, fit THROUGH the knots rather than clamped-then-corrected — so the
    water rides OVER intervening terrain instead of staircasing down it (the owner's
    round-4 reversal of run-2's terrain-hugging descent). Every floor-pinned point sits at
    `ground + DESCENT_CLAMP` (0.10m), a UNIFORM floor that must strictly clear the
    hydrostatic fill's own wetness epsilon `EPS` (0.05m) — at `DESCENT_CLAMP == EPS` the
    fill dries the exact band the envelope shaped to keep wet (r3 Task 12b). `steep_spans()`
    separately reports where the RENDERED terrain (not the level curve) drops more than
    `FALL_DROP_MIN` == 4m inside a 24m sliding window — purely a shader/mesh attribute bake,
    never geometry-forking. Static wetness beyond the channel/pond seeds themselves comes
    from a **hydrostatic fill**: river seeds are variable-width **segment capsules** whose
    levels interpolate at each lattice point's own longitudinal projection (not overlapping
    constant-level sample discs, which rebuilt terraces after the smooth profile); those
    flowing-channel lattice values are authoritative against a lower downstream flood. Seeds
    placed in channels and ponds spread outward only
    DOWNHILL-OR-LEVEL over connected ground sitting below the seed's own level (never
    uphill), with the LOWER level winning wherever two spreads meet. Those flood labels decide
    the deterministic **wet mask**, not the final flowing surface: five fixed Jacobi passes,
    anchored by the continuous river profile, relax the wet labels across river/pond joins so a
    lower flood cannot leave a one-cell sideways water cliff. Complete source extents are solved before the labels are projected into
    each 42m chunk margin; the five local passes then have a 30m radius. The canonical surface stays
    on a 6m world-space lattice; mixed coarse cells seed a sparse, topology-only 3m rescue where
    real terrain exposes a submerged passage between dry 6m endpoints. The rescue walks only
    downhill-or-level through points the coarse continuous field calls dry, lower level still wins,
    and untouched samples remain bit-identical to the 6m field. Across a mixed wet/dry lattice
    cell the field interpolates **signed depth**: dry corners contribute a small negative
    depth, capped so a high bank never pulls the surface uphill. Water therefore thins to
    zero depth on a contour inside the cell instead of ending as a square fill-grid edge —
    the field source of the rounded/blob-like shoreline. Pure and deterministic — no
    rendering, no nodes.
  - `WaterContour` — waterline → smooth, chunk-welded G1 polylines. Six-step pipeline:
    presence grid → per-edge crossing refinement → chain into polylines → two Chaikin
    passes + uniform 1.5m resample → clip to rect LAST → per-point level/normal/wall
    attributes from the curve's own frame. One dry-side orientation is chosen for the whole
    G1 curve, so a zero-gradient saddle cannot reverse adjacent outward normals and fold the
    rim into a bow tie. Wall detection probes that outward normal plus ±45° corner guards, so
    a tangent that bisects two cliff faces cannot look through their diagonal notch and
    misclassify the corner as a gentle blob shore; a 1–3-sample gap bracketed
    by real walls is closed only when their normals form a turn. Clipping LAST (after smoothing) is what makes
    the chunk weld: two neighbouring chunks both smooth the SAME margin-grown polyline
    before either clips it, so they land on bit-identical border-crossing points. SADDLE
    cells (marching-squares' standard ambiguous case: two diagonally-opposite corners wet)
    are resolved by sampling the field at the cell's own CENTRE (world-grid-aligned, so
    neighbouring chunks agree) rather than falling through a generic two-crossing path that
    used to silently drop the diagonal wedge (r3 Task 15). CLOSED curves resample by EVEN
    DIVISION of the circumference (`cnt = round(circ/spacing)` equal arcs, no remainder)
    instead of a fixed-spacing walk that left an arbitrary leftover segment.
  - `WaterCurrentField` — pure deterministic horizontal current constraints. `WaterSkin`
    seeds a world-aligned 3m lattice from downstream trace tangents; width/depth provide a
    readable base current even on flat reaches (about 2.3m/s at the pinned representative
    reach, clamped 1.4–6.5m/s) and grade only adds speed. A finite two-cell
    signed-distance bank field zeros dry samples and removes bank-entering velocity, then
    finite differences derive vorticity and compression for turning packets and generated
    foam. Production chunks solve with a two-cell halo, so adjacent chunks bake bit-identical
    retained border values. The velocity/diagnostics live in mesh `CUSTOM1` and the frozen
    `WaterSampler`; GPU and CPU consumers never reconstruct separate flow fields.
  - `WaterForces` — pure, scene-free force laws shared by water consumers: displaced-column
    buoyancy, horizontal drag toward `WaterSampler.velocity_at()`, and vertical water drag.
    Bodies keep their own volume-to-mass/drag tuning and integration adapter; never copy a
    separate approximation of the current or character-only buoyancy math into future props.
  - `WaterSkin` — the ONE mesh builder (the old marching-squares mesher is retired, r3 Task
    7; its own boundary was raw ~45-90° grid corners). Welds a 2m world-aligned render
    lattice to a boundary strip that sits directly ON `WaterContour`'s curves (zip-stitched
    via nearest-curve ring ownership — narrow-channel safe), plus a **meniscus rim** that
    curls the strip's own outer edge. Rising banks receive a compact overshoot; a wall-flagged
    point meets the wall skirt on the dual border directly (`RIM_WALL_REACH` 0; the retired KayKit
    pieces sat 1.5 m inside the high cell) only when its own outward column confirms high ground
    there. A short sustained-high witness handles
    diagonal cliff arms that leave the normal column before the long probe. Because contour
    smoothing can move the visual curve inside the final signed-depth wet region, every column
    first stays level through its initial continuous wet run; this closes inner-corner and saddle
    gaps without bridging a dry cliff arm to water on its far side. A confirmed wall column then
    measures any remaining contact distance,
    then stays at water level to the face and `RIM_WALL_SHELF_BURY` behind it before curling
    down. Adjacent confirmed columns whose wall normals turn use the intersection of their
    wall tangents as a bounded miter, so their outer edge follows the actual L-shaped cliff corner
    instead of cutting it off with a diagonal chord. The visible surface therefore meets rounded
    cliff corners flat instead of using the lower curl to fill them. That direct-contact
    gate stops a flanking wall from stretching a genuinely unbounded edge into a skirt. Free/drop
    edges instead form a finite convex lobe: a +4cm crest followed by -6/-28/-55/-65cm rows over
    only 0.64m, with monotonically outward/downward-turning tangents. Every
    free edge is accounted for (a chunk border, a bank-buried outer row, or that compact lobe),
    so no zero-thickness plane ends sharply in open air. The first rim row also advances
    outward (no vertical repair-skirt seam). Open contours may border several disconnected
    interior-lattice rings where a narrow channel falls below the render grid; the boundary zipper
    splits those into local components and partitions the contour among them instead of joining
    them with non-local fan triangles. Remaining over-scale faces are adaptively subdivided, and
    only tiny local closed surface holes are triangulated. Level shelves also use level normals, including still-wet columns between diagonal banks;
    a free-edge curl normal on such a shelf creates a false reflective crease.
    Per-vertex CUSTOM0 bakes `(s, d,
    slope, shore_dist)` — arc length / signed cross-channel distance / continuous profile
    slope along the nearest river trace, plus shore distance. `CUSTOM1` bakes `(velocity.x,
    velocity.z, vorticity, compression)` from the shared `WaterCurrentField`. Vertex normals are real
    (heightfield-derived interior, rim-curl frame on the meniscus), not a blanket up vector.
    `ARRAY_COLOR.r` bakes a displacement scale from BOTH shore distance and actual static
    bed clearance; it covers the ambient spectrum plus packet-field trough bound. The shader,
    `WaterSampler.wave_scale_at()`, and character buoyancy use the same scale, so dynamic
    geometry cannot uncover a shallow bed while the CPU float height claims otherwise.
    `WaterSkin.build()` also returns `triggers`: one box per 24m wet tile, footprint from
    the mesh's own built vertices. r3 Task 12b RETIRED the whole-tile/sub-tile level-SPREAD
    suppression Tasks 7/9 had layered on top (`_tile_level_spread`,
    `TRIGGER_LEVEL_SPREAD_MAX`, `TRIGGER_SUB_TILE_SPREAD_MAX`) once the phantom-depth class
    it guarded against was proven dead by construction under the smooth descent envelope —
    triggers are simple wet-tile coverage again. `STEEP_UNSWIMMABLE` stays: a tile whose own
    max grade exceeds it gets **no trigger at all** — a steep fall face is not swimmable
    water, so a character falls/slides through it rather than floats. A single frozen
    `WaterSampler` snapshot of the water FIELD across the chunk (full wet footprint,
    shoreline band included; NaN only where the field itself says dry) backs every trigger
    for swim-depth queries.
  `WaterSurfaceBuilder` is a thin adapter: worker-safe `compute_chunk` calls `WaterSkin.build`;
  main-thread `commit_chunk` calls `WaterSkin.commit` and emits one `Area3D` swim trigger per
  `triggers` entry (never more than one per tile —
  the steep gate above means a tile either has one trigger or none), each carrying
  `set_meta("sampler", sampler)` so a probe anywhere inside reads its exact water height
  from that one shared, chunk-frozen sampler instead of a per-cell plane. The sampler freezes
  the field's 6m fill lattice, sparse 3m topology rescue, and a `WaterGroundSnapshot` of the
  window's point heights, then calls the field's own `_fill_bilinear`; do not resample
  levels through the render mesh grid, which
  double-interpolates steep shorelines and can turn dry/wade probes into false swimming. It also still owns
  the shared `ShaderMaterial` and the river-trace `surface_profile`/`steepness_profile`
  helpers.
  `water_unified.gdshader` is the ONLY water shader and renders the whole continuous network;
  no river/pond material fork or separate swept waterfall mesh exists. Its one
  `water_dynamic_height()` combines the slow ambient spectrum, persistent compact asymmetric
  wavelets, and interactive ripple height. Both vertex and fragment stages sample that SAME
  height: it displaces the 2m mesh and derives normals, refraction, curvature caustics, and
  reflection tilt, so a moving feature cannot become a detached albedo scroll. The old
  repeated river trains and fragment-only `water_distort_wobble` are deleted. Water is
  spectrally manual-composited: Beer–Lambert transmission
  (`absorption=(0.003,0.001,0.0005)`) stays in `EMISSION` because the refracted scene is
  already lit, while the real displaced normal uses Godot's PBR specular response. That split
  keeps the bottom dominant without losing the old clear swim-ripple highlight. Weak depth
  scattering and a broad Fresnel sky sheen supply the remaining body read. A short screen-space reflection
  ray march was actively rejected in the exact review view because its finite hit iterations
  formed concentric far-bank bands. White is legal only from generated energy:
  packet breaking or local flow compression. Swim/entry/ambient ripple impulses stay clear;
  their narrow height gradients refract and reflect the sky, and there is no foam/streak texture.
  `WaterRippleSim` owns two player-centred GPU fields. Its ping-pong wave equation carries
  swim wakes, entry splashes, and ambient clear rings; semi-Lagrangian backtracing advects it
  through a 32×32 current texture over the restored 96m interaction domain. Its second pass
  rasterizes at most 64 persistent world-space Morlet-style wavelets over 192 m,
  with a local admission limit and a continuous 48–90 m circular fade (compact, Gaussian-
  windowed 6–10m oscillating crests, not closed blur bubbles or repeated trains). Their CPU
  centres/lifetimes/directions/phases are transported through the same
  `WaterSampler.velocity_at()` field and turn with the shared vorticity as that field bends.
  The packet height is
  CPU-mirrored to character buoyancy. Plunge mist (particle spray at fall landings) is currently
  unwired — a follow-up; the shared particle resources it needs are no longer warmed on
  startup. `tests/tools/water_review_spots.gd` emits F4 review teleports
  (`ReviewTeleporter.gd` reads `review_teleports.json` and lifts the player onto streamed
  ground if a stale spot height would bury them).
  **Character depth gate** (`characters/character.gd`): classification is **static-field
  depth**, full stop — `depth = sampler.level_at(xz) - global_position.y`, read from the
  overlapping trigger's frozen `WaterSampler` snapshot (the knee-height probe only finds
  which triggers overlap; it plays no part in the depth number itself). Swim and wade are
  each hysteretic against that static number — swim ENTER at depth > 0.8m, EXIT at < 0.6m;
  wade ENTER at depth > 0.05m, EXIT at < 0.03m — so a reading sitting right on one boundary
  can't dither the state every frame. `wading = in_water or (deepest static depth clears the
  wade gate)` (since h-task-4): swimming is a DEEPER case of being in water at all, so a
  swimming character always reads wading too — never independently false while `in_water` is
  true. The **dynamic height** (ambient `_swell_offset` plus `WaterRippleSim`'s exact CPU
  packet mirror) feeds ONLY `water_surface_y`, the float-height buoyancy chase — NEVER the depth gate: letting the
  swell's own crest nudge the gate used to be able to latch a false swim state on a single
  crest-timed frame at a knife-edge shoreline depth, which is why classification reads the
  static field alone.
- **One ground appearance field**: the shared `ground_palette.tres` atlas and
  `BiomeRegistry.ground_tint_at` still identify turf, rock and path. Terrain,
  rolled turf lips and dense grass all apply `ground_style.gdshaderinc` to turf,
  sampling `BiomeGroundMap`'s seven weights and canonical linear substrate
  colours. Broad moss, chalk, silt, petal and earth patterns remain world-aligned.
  Rock and path texels retain their authored palette. Change the shared field
  once; never give a ground consumer its own copied colour.
- **Global lighting and local atmosphere**: `AtmosphereDirector` blends seven
  lighting profiles from the player's continuous biome weights with a three-second
  exponential response. The owner requested this on September 9, superseding the
  former fixed-global-lighting policy. Sun direction and shadow opacity stay fixed;
  sky, sun colour/energy, ambient and bloom vary. World-space terrain-following
  mist still supplies local depth and colour. Camera attributes remain null.
  `EnvironmentLanternLights` supplies one shadow-free warm light per native lamp,
  attached once to the first mesh batch and freed with that batch's container.
  The two LPFV lamp families use their private atlas pane swatch for emission;
  timber, chains and metal retain their native shading.

## Character & camera

- **`characters/character.gd`** (`CharacterBody3D`) — movement (accel / friction / turn),
  `_try_step_up` (climb ≤ `MAX_STEP_HEIGHT` ledges), jump, and **force-based swimming**: water
  tiles expose an `Area3D` on collision layer 8; while a knee-height probe is inside it,
  `WaterForces` supplies buoyancy proportional to submerged fraction and enough full-submersion
  lift for a stable passive float. Horizontal drag carries the character toward the exact
  `WaterSampler` current while player steering remains relative to that moving water. Holding
  jump adds thrust, and pressing toward a nearby bank wall launches the character out. Verified
  by `tests/harness/swim_harness.tscn`.
- **`scripts/controllers/`** — a pluggable `CharacterController` resource: `PlayerController`
  (keyboard, camera-relative) and `TestController` (steers toward a target node, for harnesses).
- **`scripts/camera/camera.gd`** — elevated tactical camera with a fixed world yaw,
  mouse-edge drag and Q/E orbit. `CameraVisibilityBubble` reveals foreground surfaces
  around the player through a material corridor; it never contracts the boom.
  F7 switches to the original follow camera with `CameraObstructionSolver` collision.
- **`DirectionalLocomotion`** — synchronized, phase-aligned forward/backward/strafe
  blending, independent of facing. PlayerController retains the original 10 m/s speed;
  the base CharacterController can publish a separate facing vector for other actors.

## Startup loading screen

- **`ui/loading_screens/mythos_loading_screen.tscn`** is the project main scene. It loads
  `world.tscn` on Godot's threaded resource loader, installs the live world behind a high
  `CanvasLayer`, and keeps its animated atlas visible until `FieldTerrainStreamer` reports
  every chunk within one terrain cell of the player's spawn integrated. The production spawn sits
  0.5 m inside the origin chunk, avoiding a four-way collision seam, while the readiness gate still
  includes every nearby quadrant the camera can reveal. Startup progress is real weighted
  work: threaded scene-resource loading, worker
  FeatureContext/heightfield/mesh/water/dressing milestones for those support jobs and
  their required feature halo, then main-thread integration. Never replace it with elapsed-time
  progress. `MythosLoadingScreen.gd` owns the handoff,
  `MythosTaperedProgressBar.gd` draws the hairline/tapered fill, and
  `mythos_loading_screen.gdshader` composites transparent city/cloud/chart textures from
  `ui/loading_screens/layers/` over the genuinely cloud-free
  `mythos_mythic_atlas_background_cloudless.png` plate; never restore the older plate's static
  corner-cloud duplicates. Only the chart texture rotates; four cloud groups translate
  independently. The stationary river is the actual original atlas painting, with a second atlas
  sample travelling downstream along a hand-fitted river spine for most of each cycle and
  cross-fading only at wrap. Its moving mask is the narrower inner channel, never the full painted
  bank width. Fine distant wavelets are low-contrast and screen-horizontal for perspective even
  though the underlying texture advection follows the spline. The title/progress Control remains
  outside every rotation.

## Conventions & code style

- **Typed GDScript.** Annotate function signatures, exported vars, and members. Inline `:=`
  type inference is used freely for locals — match the surrounding code.
- **Purity boundary.** Terrain computation (plan / field / mesher / dressing) stays
  scene-free and deterministic so it can be unit-tested headless. Push scene-tree work into the
  streamer or scene glue.
- **Simplify — the owner strongly prefers root-cause re-architecture over band-aids.** If the
  same logic appears in several places, consolidate it. If you're adding retries, attempt loops,
  or a special case for "only when tag/config X", step back and redesign so the normal path just
  works. Prefer shorter code. (This is why the socket engine was replaced wholesale rather than
  patched.)

## Tests & harnesses (`tests/`)

- Unit tests mirror the pipeline: `test_heightfield_plan`, `test_heightfield_region`,
  `test_heightfield_clamp_step`, `test_heightfield_lowpass`, `test_terrain_tile_field` (case
  table, properties, wall segments, bounds), `test_terrain_chunk_mesher` (seams, welds, no quad
  straddles a wall, skirt collision), `test_cliff_sheet_ends`, `test_cliff_rock_foot_lines`,
  `test_cliff_envelope_shortcuts`, `test_cliff_sheet_normals`, `test_water_dual_grid`,
  `test_dressing_field`, `test_dressing_ecology`,
  `test_dressing_collision_builder`, `test_dressing_commit_queue`,
  `test_environment_catalog`, `test_water_field_context`, `test_field_streamer`, `test_biomes`,
  `test_helper`, `test_world_field_block_cache`, `test_water_path_queries`, `test_settlement_plan`, `test_path_program`,
  `test_path_plan_nodes`, `test_path_bridge_sites`, `test_path_route_solver`,
  `test_path_context`, `test_path_features`, and the `test_slope_*` profile guards.
- **`tests/harness/`** — visual/screenshot scenes for eyeballing behavior a unit test can't
  (`heightfield_shot.tscn`, `hf_shapes.tscn`, `swim_harness.tscn`,
  `environment_lineup.tscn`, `teleport_deco_harness.tscn`, `debug_water.tscn`, …). The lineup
  pages the full generated catalogue with stable IDs, provenance, measured AABBs, a one-metre
  scale marker, and optional collision overlays (`--show-collision`). The teleport harness streams
  a fixed nine-chunk site through the real world pipeline, requires structural collision, and
  waits for both terrain integration and the independent dressing commit queue before capturing it.
  `path_review.tscn` renders straight/L/T/X/logical-node masks through the real terrain mesher beside the
  rejected offset-width alternative; `path_corpus.gd` is the deterministic smoke/full path gate.
  `tile_gallery.tscn` (windowed; `-- --output DIR [--only case,...]`) renders every tile case
  (flat, slope straight/outer/inner/saddle, level steps, cliff straight/outer/inner/saddle/
  3-storey/stacked, mixed cliff ends E2 and E1 side by side, a terrace hill) through the real
  mesher + sheet, each with a `_lines` (points, edges, `wall_segments`) and an `_f9` variant.
  `cliff_site_review.tscn` (`--shot`, `--categories`, `--lowpass M`) captures photo sites;
  `dual_grid_side_by_side.py OUT LABEL=DIR ...` composes labelled before/after panels.
  `profile_terrain.gd` (49 chunks) and `profile_mesh_phases.gd` (`--style`, `--detail`,
  `--hash-out/--hash-check` payload identity) profile the worker.

## Adding terrain content

- **New environment visual**: add a stable-ID entry to the relevant manifest under
  `tools/environment_bake/manifests/`, including its canonical bake scale and either
  `collision_source`, a supported `collision_profile`, or intentionally neither. `tree`, `rock`,
  and `deadwood` tags require collision by construction. Prefer one close-fitting simple shape:
  `trunk_capsule` for a straight grounded lower trunk or `trunk_capsule_chain` for a reviewed
  curved trunk. A forked or root-heavy silhouette can explicitly provide
  `collision_joint_points_m` and `collision_segment_radii_m` in corrected asset-local metres,
  keeping asset-specific art direction in the manifest rather than the generic baker.
  Use `oriented_cylinder` for a log,
  `stump_cylinder` for a flat cut, `flat_box`/`flat_rock` for a walkable rock, and set
  `collision_component_count` when one source visual contains several disconnected stones; use
  `collision_max_height` plus the `walkover` tag for a low obstacle that must remain below the
  character step at every active population scale; use `oriented_capsule` for a branch. Use
  `collision_source` only for reviewed authored primitives.
  Run the bake tool and review every rigid asset beside its mesh in
  `environment_lineup.tscn -- --show-collision`; a proxy must not stray materially outside the
  mesh or collapse to an unusably thin line. Never add a runtime wrapper scene or a source-pack
  path.
- **New ambient population or variant**: author a `DressingSet`/`DressingChoice` under
  `terrain/dressing/` and add it to `terrain/dressing/index.tres`. The set owns direct per-biome
  fill and may share habitat/community channels with related sets; visual choices affect mix,
  never population. Structural sets must share the appropriate spacing group so their collision
  cannot overlap. The compiler derives proposal slots and margins and rejects illegal
  water/support/radius combinations. Author `feature_clearance` explicitly (`2.0` m for rigid
  structure, `0.3` m for small ground cover, `0.0` for floating lilies); the compiler rejects a
  margin outside `PathProgram`'s saturated clearance coverage.
- **New man-made path feature**: add its self-contained visual/collision through the environment
  manifest, then add only primitive footprint/support/opening semantics to `PathProgram`. Keep the
  decision inside `PathPlan` after final route-mask merge, add its footprint to the shared
  reservation union, derive its stable ID from the canonical world site, and let the existing
  environment payload/builder/queue and derived feature halo handle streaming. Do not add a
  sibling planner, scene wrapper, feature-specific streamer dependency list, or alternate water/
  terrain classifier. Review paths in `tests/harness/path_review.tscn`, assets in
  `environment_lineup.tscn -- --show-collision`, and deterministic statistics with
  `tests/harness/path_corpus.gd`.
- **Different cliff look**: world cliffs are the rock skirt under the `sheet_bedrock` slope sheet
  (`CliffRockStyle`, `CliffSlopeEnvelope` radii/relief, `CliffSlopeField` rocks); change those,
  never re-add pieces on world walls. Village rims keep the KayKit pieces in `CliffDressing.ASSETS`.
- **Tuning terrain shape**: `TerrainWorldTuning` (amplitude, storey cap, cliff step),
  `HeightfieldPlan` constants (`STOREY_HEIGHT`, `LEVELS_PER_STOREY`, aggregation) and
  `LOWPASS_M`, `TerrainTileField.cliff_end` (E2/E1), and `Helper` field scales (`MACRO_SCALE`,
  biome/water scales). Changing the plan re-rolls geography: re-pin geography tests to an
  equivalent current site (found programmatically), never loosen them.

## Before finishing

- **Run the tests** (`godot-test`) and fix regressions before considering a change done. For
  anything visual, also open a relevant `tests/harness/` scene (or the game) and look.
- **For a reported visual defect, use red-first TDD plus active falsification.** Pin the exact
  seed/world coordinates and camera pose, write the smallest failing invariant before the fix,
  then rerun it green. When an F3 screenshot supplies `player world` + `crosshair world`, use
  `ReviewCam.solve_cam`/`ReviewCam.shoot`; never substitute a hand-authored camera transform.
  Capture the same-angle before/after view and deliberately
  try to prove the defect still exists: inspect alternate times/nearby angles, paired animation
  frames, seams, and likely collateral regressions. Reject a change if the unit test passes but
  the matched render exposes the original problem or a new artifact. Keep a deterministic
  self-driving harness for recurring review sites; `tests/harness/water_reported_qa.tscn` is the
  water example and accepts `-- --spot <name>` for a focused run.
- If you rename/move a `class_name` script, run the `--import` step above.

## Historical docs (stale — do not follow as current)

These predate or partially describe the retired socket engine and are kept only for history:
`terrain/TERRAIN_README.md`, `docs/known-issues/*`, most of `docs/future-work/*`, the older
`docs/superpowers/plans|specs/*`, and `docs/superpowers/terrain-status-2026-06-24.md`. When they
conflict with the code, the code and this file win. The living design reference is
`docs/mythosunwritten-master-design.md`.
# September 8 garden border follow-up

Continuous horizontal facade runs select one shared available outcrop depth
before emitting their paired panels. They do not alternate deep and shallow
projections along one garden edge. Shallow covering boards fit their own
projection depth and retain the wall-top bearing plane. The matched September 8
photo 1 and nearby views, actual board bounds, and identical west-town clearance
across 140 cells and 205 crossings verify the change.

> September 10 tactical follow-up: visibility uses a finite camera-apex cone
> and projected-foot protection, preserving the reported rising foreground.
> Strafe copies retarget leg branches into a shared root frame while preserving
> the authored head pose; measured contact sweeps calibrate diagonal weights.
> AnimationTree rebinds after its private library changes. Mouse rightward edge
> drag turns the viewing direction right. See `docs/qa/2026-09-10-tactical/follow-up.md`
> for matched terrain renders, gait checks and validation limits.

> September 10 embedded input follow-up: native visible confinement supplies
> the final side-edge mouse sample before switching to raw capture. Do not infer
> an embedded window's screen origin from buffered input events and a current OS
> cursor query; the reported origin drifts during fast motion. Escape releases
> centre confinement as well as edge capture. Previous locomotion blend weights
> are carried into the new body-facing frame before smoothing travel changes.
> The focused 31-test / 402-assertion run and native 9-test / 113-assertion run
> pass. Button-free embedded acceptance remains pending the owner's live check;
> earlier demo and exit-handler passes did not establish it. See
> `docs/qa/2026-09-10-tactical/embedded-input.md`.

> September 10 continuous-input correction: the owner rejected the confinement
> attempt above. Tactical input now keeps raw capture throughout focused play,
> draws a freely moving virtual cursor and turns only on side overflow. Returning
> inward never changes native capture. Escape, clicks, focus loss and F7 retain
> their tested release behavior. The owner confirms rotation and WASD in both
> separate and embedded cube tests loaded through the production transition.
> Full foot trajectories exposed 31–33° errors missed by contact-only checks.
> A post-animation two-bone correction constrains each foot's horizontal swing
> to its travel plane, preserving height, leg lengths and head pose. The owner
> confirms the reported diagonal-aim/backward case in the embedded test. Focused
> checks pass 33 tests / 399 assertions; corrected-pose locomotion passes 10 /
> 147 and native input passes 9 / 96. Normal-game acceptance is recorded in
> `docs/qa/2026-09-10-tactical/continuous-input-and-stride.md`.
> September 11 village camera work: visibility keeps live MultiMesh buffers and
> native geometry, with reversible render-surface bindings for multi-material
> batches. Source materials share one adapter; per-instance strength retains
> independent fades. Last-owner restoration includes freed nodes. A 32-program
> history retains shaders without retaining unselected source textures. Four
> pinned views and twelve frozen plus three live pairs preserve appearance.
> The live held-input/orbit replay reduces camera CPU p95 12.531 to 2.594 ms;
> original/fixed/disabled travel and collision stops agree, with no streaming
> freezes. Twenty-nine native tests / 263 assertions pass with a clean exit.
> This verifies reproduced camera work, not universal streaming, whole-frame
> speed or unrecorded native focus loss. See docs/qa/2026-09-11-manual/01-movement/result.md.
