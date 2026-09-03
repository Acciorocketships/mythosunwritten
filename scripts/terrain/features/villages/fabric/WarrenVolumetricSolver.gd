class_name WarrenVolumetricSolver
extends RefCounted

## First production front end for the fine-grid volumetric architecture.  It
## reuses the proven terrain-grounded massif and bore as topology input, then
## abandons the old extrusion interpretation: remaining mass is assigned to
## offset 3D room volumes, exact interfaces, and an explicit support DAG.
## Village-scale floor: a rescaled compact hamlet legitimately forms six to
## eight buildings; anything below this still reads as a farmstead, not a town.
## The value the sealed audit's `production_generation_mode` carries. One
## pipeline builds every town, so this is a label rather than a selector.
const PRODUCTION_PIPELINE_ID := "maze"
const MIN_BUILDINGS := 6
const GRID_PADDING_CELLS := 2
const ROOF_CLEARANCE_CELLS := 2
const RESIDUAL_OVERHEAD_ROUTE_CELL_SCORE := 50000
const RESIDUAL_FRONTAGE_SIDE_SCORE := 15000
const RESIDUAL_TERRAIN_ROOT_SCORE := 35000
## Formerly 8000: rewarding massif-edge contact scattered freestanding rim
## houses around the village. Edge taper is welcome only when a candidate
## also leans on the town, which the mandatory established-contact rule now
## enforces, so the edge itself earns nothing.
const RESIDUAL_MASSIF_EDGE_COLUMN_SCORE := 0
## A roof court is selected from already-inhabited, coplanar room crowns before
## composed features or roofs spend the same air.  These are deliberately broad
## rectangles: a two-cell strip is a gallery, not the elevated civic space this
## pass is meant to create.  Larger shapes rank first, with the two orientations
## kept explicit so the deterministic search can fit either street bearing.
const ROOFTOP_COURT_SHAPES: Array[Vector2i] = [
	Vector2i(5, 4), Vector2i(4, 5), Vector2i(4, 4),
	Vector2i(4, 3), Vector2i(3, 4),
]
const MIN_ROOFTOP_COURT_LIFT_CELLS := WarrenSpatialGrid.STOREY_CELLS
## Screenshot-backed production gates. A town with every requested feature can
## still read as isolated facades around an open plaza; require the compiled
## exterior realm to keep most long views broken and a substantial fraction of
## the route physically under inhabited mass.
const MIN_PRODUCTION_OVERHEAD_ROUTE_RATIO := 0.38
## Enclosure GUIDANCE, not a production gate (2026-08-16). These are the
## through/ground sightline counts a town should read with; the precomposition
## ranking already penalises the proxy counts (_precomposition_quality_score),
## and reviewed enclosure comes from housing density (lanes reaching the
## interior), not from discarding a composed town after the fact. Profiling
## showed ~200 s of a 365 s search spent on towns rejected by this check at
## the very end. Kept as the reference values tests and audits compare against.
const MAX_PRODUCTION_THROUGH_SIGHTLINES := 48
const MAX_PRODUCTION_GROUND_THROUGH_SIGHTLINES := 20
## A bazaar must read as a chamber in the inhabited maze, not a canopy beside
## the town. Every aisle sight ray must meet market body or future building mass
## within this many 1.5 m cells.
##
## TASK F3 MEMBER 3 -- MEASURED, AND DELIBERATELY NOT RETUNED. The brief asked
## whether 4 is a searched-town number that misjudges every maze plaza now that
## E2's momentum work made streets longer and straighter. Measured over the
## 24-town corpus plus the production settlement, it is not.
##
## Those 25 towns form ELEVEN complete canopy candidates between them, and
## their open horizons are 2 (once), 4 (four times), 8 (once) and 10 (five
## times). Ten IS `MARKET_SHELTER_HORIZON_LIMIT_CELLS`, the sight ray's own
## bound: those five are not near misses at the cap, they are mouths with no
## termination anywhere in the ray's reach, which is the single failure mode
## `_market_shelter_audit` exists to catch. The one candidate at 8 belongs to
## 2/standard, which already builds its bazaar from a 4-cell candidate that
## outranks it. So raising this constant anywhere from 5 to 9 gives NO town a
## market it does not already have, and raising it to 10 buys four marketless
## towns a bazaar looking straight out of the hill.
##
## The cap is also not what makes 19 of the 24 corpus towns marketless.
## `_market_public_aisle` is: the funnel runs 84-200 sockets to 16-56 ground
## fits to 1-22 body fits and then to 0-2 aisle fits, and SIXTEEN of the 24
## corpus towns arrive at the aisle test with bodies that fit and leave it with
## nothing (3/standard loses 22 of them there). Widening the aisle rule is a
## real design question and belongs to Phase G, not to a constant here.
const MAX_MARKET_OPEN_HORIZON_CELLS := 4
const LARGE_MARKET_OPEN_HORIZON_CELLS := 8
const GRAND_MARKET_OPEN_HORIZON_CELLS := 10
## How far one aisle sight ray walks before it gives up. A candidate measuring
## exactly this is not a near miss at the cap above: it is a mouth with no
## termination inside the ray's whole reach. Named rather than inlined so a
## test can say "the ray saturated" instead of comparing against a 10 whose
## provenance it would have to guess (task F3 member 3). Note that
## `GRAND_MARKET_OPEN_HORIZON_CELLS` equals it, so a grand town's bazaar is
## under no horizon constraint at all -- unexercised today, since no grand town
## seals.
const MARKET_SHELTER_HORIZON_LIMIT_CELLS := 10
## Landmark halls are allowed to replace ordinary parcels, but they must still
## read as part of the inhabited mountain. Measure surviving private mass just
## beyond the landmark's authored visual envelope; the exact gap remains a
## ranking fact while the later typed public-realm transaction decides whether
## the space is a street rather than rejecting complete buildings prematurely.
const LANDMARK_CITY_CONTACT_RADIUS_CELLS := 4
const COURTYARD_BRIDGE_FEATURE_ID := \
	&"spatial.feature.courtyard_bridge_house.00"
## A measured bracket/arcade course is part of the room whose overhang it
## bears. When that complete envelope meets an already-selected hero feature,
## this semantic owner feeds the exact conflicting room cells back into the
## composition solve. `_composition_offsets` can then shorten or move only an
## optional upper crown; no seed, parcel, coordinate, or mesh gets a special
## case.
## The third courtyard side may be a real occupied bridge-house selected by the
## joint 3D feature transaction.  The parcel partition must still supply two
## independent room walls; the complete spatial proof below requires all three.
const MIN_COURT_PARCEL_SIDE_COUNT := 2
## Macro composition may grow the court's own endpoint room across the authored
## attachment socket.  The joint exact solve is allowed to recompose only that
## one fine-grid (3 m x 1.5 m) socket strip; unrelated room mass remains a hard
## conflict and larger self-conflicts are not waved through.
const MAX_COURT_OWNER_SOCKET_RECOMPOSITION_CELLS := 2
## The five authored room shells as MACRO footprints, largest first. `width`
## runs across the parcel's frontage and `depth` along it, which is exactly the
## reading `WarrenBuildingParcel.seal` and `WarrenParcelConstruction`'s own
## `profile_for` give a parcel's rectangle -- so a back room's kind means the
## same thing as the kind of the house standing in front of it. Used only by
## the directed maze back-room pass; the greedy residual scan enumerates
## `WarrenRoomStamp.KINDS` directly because it has no frontage to reckon from.
const MAZE_BACK_ROOM_KINDS: Array[Dictionary] = [
	{"kind": &"long", "width": 2, "depth": 3},
	{"kind": &"building", "width": 2, "depth": 2},
	{"kind": &"slim", "width": 1, "depth": 2},
	{"kind": &"row", "width": 2, "depth": 1},
	{"kind": &"tower", "width": 1, "depth": 1},
]

static var last_failure := ""
static var last_diagnostic: Dictionary = {}
static var last_preplan_skywalk_diagnostic: Dictionary = {}
static var last_preplan_market_diagnostic: Dictionary = {}
static var last_preplan_landmark_diagnostic: Dictionary = {}
## Richness quotas a one-pass solve fell short of but shipped anyway. Merged
## into the sealed plan's audit so a plain town is a visible, reviewable fact
## rather than a silent one.
static var last_advisory_shortfalls: Dictionary = {}
## TASK C6 RULING 4. Wall clock per composition sub-stage, in ms, for the ONE
## maze town currently being solved. Reset by `_solve_maze` and merged into the
## sealed plan's audit, so the stage probe can print a table per planner seed
## without a second solve and without parsing trace lines.
static var last_maze_stage_ms: Dictionary = {}
static var diagnostic_trace_skywalk_timing := false
static var diagnostic_trace_room_gate := false
static var diagnostic_feature_market_limit := -1
## Bridge-room admission telemetry for the residual backfill pass; reset per
## backfill run and surfaced through the residual audit keys.
static var _residual_bridge_counts: Dictionary = {}


static func solve(world_seed: int,
		ground_bands: Dictionary = {},
		construction_program: SettlementFabricProgram = null,
		scale_profile: WarrenVillageScaleProfile = null) -> WarrenSpatialPlan:
	## The production entry. Solid-first: one deterministic carve, no attempt
	## rotation and no ranked candidate corpus.
	last_failure = ""
	last_diagnostic = {}
	last_preplan_skywalk_diagnostic = {}
	last_preplan_market_diagnostic = {}
	last_preplan_landmark_diagnostic = {}
	if construction_program == null:
		last_failure = "volumetric composition requires measured construction vocabulary"
		return null
	var profile := scale_profile if scale_profile != null \
		else WarrenVillageScaleProfile.review_fixture()
	return _solve_maze(world_seed, ground_bands, construction_program, profile)


static func _stamp_maze_stage(volume: WarrenVolumePlan, stage: StringName,
		started_ms: int) -> void:
	## One stage's elapsed ms, accumulated so a stage entered twice reads as its
	## total rather than as its last visit. Maze only; a millisecond clock is
	## the cheapest thing in this file and the branch costs a dictionary probe.
	if volume == null or not volume.mass_context.has(&"maze_source_plan"):
		return
	last_maze_stage_ms[stage] = int(last_maze_stage_ms.get(stage, 0)) \
		+ Time.get_ticks_msec() - started_ms


static func _solve_maze(world_seed: int, ground_bands: Dictionary,
		construction_program: SettlementFabricProgram,
		profile: WarrenVillageScaleProfile) -> WarrenSpatialPlan:
	## The production entry. The whole point of the solid-first front end
	## is that the source is correct by construction, so there is exactly one
	## source, one partition, and one composition. A rejection here is a real
	## defect in the site plan or a gate it has not yet learned to satisfy — it
	## is never retried with a different bore.
	##
	## The source is the site planner's whole one-pass pipeline (massif ->
	## carve -> reserve -> partition -> seal), never the bare bore: a plan
	## without plots carries no town to translate, and the block partitioner
	## rightly refuses one.
	var started_ms := Time.get_ticks_msec()
	last_advisory_shortfalls = {}
	last_maze_stage_ms = {}
	var maze := WarrenMazeSitePlanner.plan(world_seed, ground_bands, profile)
	if maze == null:
		last_failure = "maze source rejected: %s" \
			% WarrenMazeSitePlanner.last_failure
		return null
	# TASK D1 FIX 1, controller ruling. The source's addressed-frontage bar
	# is advisory: `WarrenMazeCarver`'s ratchets still steer growth by it,
	# and a town that cannot reach it on real ground ships and says so.
	# Recorded here rather than in the carver because this dictionary is
	# the one place a maze town's shortfalls are collected, and it is what
	# reaches the sealed plan's audit.
	var frontage := float(maze.audit.get("frontage_ratio", 1.0))
	if frontage < WarrenMazeSourcePlan.FRONTAGE_FLOOR:
		last_advisory_shortfalls["frontage"] = frontage
		last_advisory_shortfalls["frontage_target"] = \
			WarrenMazeSourcePlan.FRONTAGE_FLOOR
	var volume := WarrenMazeVolumeAdapter.to_volume_plan(maze)
	if volume == null:
		last_failure = "maze volume adapter rejected: %s" \
			% WarrenMazeVolumeAdapter.last_failure
		return null
	var source_ms := Time.get_ticks_msec() - started_ms
	var spatial_started_ms := Time.get_ticks_msec()
	# The maze partitioner is deterministic and ignores the variant index, so
	# the eight-variant rotation is meaningless here: pass -1 for "the one".
	# Prove the serial construction once. Large/grand may then try the optional
	# paired silhouette refinement in `_finalize_candidate`; passing `true` here
	# as well ran that identical expensive composition twice and left no serial
	# survivor to fall back to, contrary to the finalizer's transaction contract.
	# Compact/standard already skipped the second pass, so their output remains
	# exactly the same. A successful large/grand refinement is still the selected
	# result; a failed refinement now retains this independently proven baseline.
	var plan := from_volume(volume, -1, construction_program, false)
	var spatial_ms := Time.get_ticks_msec() - spatial_started_ms
	if plan == null:
		last_failure = "maze composition rejected: %s" % last_failure
		return null
	var fabric_started_ms := Time.get_ticks_msec()
	var fabric := WarrenSpatialFabricCompiler.solve(plan, construction_program)
	var fabric_ms := Time.get_ticks_msec() - fabric_started_ms
	if fabric == null:
		last_failure = "maze fabric gate failed: %s" \
			% WarrenSpatialFabricCompiler.last_failure
		return null
	if diagnostic_trace_skywalk_timing:
		print("SKYWALK_TIMING maze_source ms=", source_ms)
		print("SKYWALK_TIMING partition_spatial source=", volume.stable_id,
			" variant=-1 ms=", spatial_ms, " accepted=", true)
		print("SKYWALK_TIMING partition_fabric source=", volume.stable_id,
			" variant=-1 ms=", fabric_ms, " accepted=", true)
	var finalized := _finalize_candidate(volume, -1,
		construction_program, {}, plan, fabric)
	if finalized == null:
		last_failure = "maze finalization rejected: %s" % last_failure
		return null
	# The pipeline label, and the four counters the searched pipeline used to
	# vary, kept at the constants a one-pass solve makes them so a sealed audit
	# keeps the same shape for every reader that already knows it.
	finalized.audit["production_generation_mode"] = PRODUCTION_PIPELINE_ID
	finalized.audit["production_excavation_attempt_count"] = 1
	finalized.audit["production_frontier_batch_count"] = 1
	finalized.audit["production_staged_frontier_count"] = 1
	finalized.audit["production_selected_attempt"] = 0
	finalized.audit["route_court_variant_probe_count"] = 1
	finalized.audit["route_court_variant_fallback_used"] = false
	finalized.audit["maze_source_ms"] = source_ms
	finalized.audit["maze_spatial_ms"] = spatial_ms
	finalized.audit["maze_fabric_ms"] = fabric_ms
	finalized.audit["maze_stage_ms"] = last_maze_stage_ms.duplicate()
	finalized.audit["advisory_shortfalls"] = last_advisory_shortfalls.duplicate()
	finalized.audit["advisory_shortfall_count"] = last_advisory_shortfalls.size()
	return finalized


static func _finalize_candidate(volume: WarrenVolumePlan,
		variant: int, construction_program: SettlementFabricProgram,
		precomposition_audit: Dictionary, proven_serial: WarrenSpatialPlan,
		proven_serial_fabric: SettlementFabricPlan) -> WarrenSpatialPlan:
	## The last step of a solve: the composition has already been proved with
	## the serial room fixed point and compiled through the exact fabric gate.
	## Compact and standard stop there. Large and grand additionally try one
	## bounded paired silhouette cleanup and rerun every authored-envelope and
	## compiled quality gate; that exchange is optional construction refinement,
	## so if it makes a previously borne exact interface unrepairable the
	## already-proven serial composition is retained rather than the whole town
	## thrown away. Both alternatives pass the same support, overlap, feature,
	## and production-quality gates.
	##
	## TASK F1 FIX 1 folded `_finalize_ranked_candidate` in here: it was the
	## searched pipeline's per-rank wrapper and, with one candidate per town,
	## its three lines are simply part of finalizing.
	var profile := _scale_profile_for_volume(volume)
	if profile != null and not profile.requires_elevated_courtyard:
		# Compact/standard composition already ran merge, coupling, volumetric
		# variation, tower relief, and the complete exact fabric gate. The paired
		# pass changes at most a bounded optional pair, but previously rebuilt the
		# whole market/skywalk/room transaction and doubled first-load time. Keep it
		# for the large court silhouettes it was introduced to repair.
		for key: StringName in [&"frontage_ratio", &"overhead_route_ratio",
				&"through_sightline_count", &"ground_through_sightline_count"]:
			proven_serial.audit[key] = proven_serial_fabric.audit.get(key, 0)
		proven_serial.audit["paired_registration_finalization_count"] = 0
		proven_serial.audit[
			"paired_registration_scale_skip_count"] = 1
		proven_serial.audit["serial_finalization_reuse_count"] = 1
		proven_serial.cache_compiled_fabric(proven_serial_fabric)
		return _stamp_selection(proven_serial, volume, variant)
	var failures := PackedStringArray()
	var finalized := from_volume(volume, variant, construction_program, true)
	if finalized == null:
		failures.append("paired room seal: %s" % last_failure)
	else:
		for key: Variant in precomposition_audit.keys():
			finalized.audit["precomposition_%s" % String(key)] = \
				precomposition_audit[key]
		var fabric := WarrenSpatialFabricCompiler.solve(finalized,
			construction_program)
		if fabric == null:
			failures.append("paired fabric gate: %s" % \
				WarrenSpatialFabricCompiler.last_failure)
		else:
			for key: StringName in [&"frontage_ratio", &"overhead_route_ratio",
					&"through_sightline_count",
					&"ground_through_sightline_count"]:
				finalized.audit[key] = fabric.audit.get(key, 0)
			finalized.audit[
				"paired_registration_finalization_count"] = 1
			finalized.audit["serial_finalization_fallback_count"] = 0
			finalized.audit["paired_registration_scale_skip_count"] = 0
			finalized.cache_compiled_fabric(fabric)
			return _stamp_selection(finalized, volume, variant)
	# The serial candidate passed the exact fabric gate
	# immediately before this call. Rebuilding it after an optional paired pass
	# fails is output-identical but was one of the largest first-load costs.
	if proven_serial != null and proven_serial_fabric != null:
		for key: StringName in [&"frontage_ratio", &"overhead_route_ratio",
				&"through_sightline_count", &"ground_through_sightline_count"]:
			proven_serial.audit[key] = proven_serial_fabric.audit.get(key, 0)
		proven_serial.audit["paired_registration_finalization_count"] = 0
		proven_serial.audit["serial_finalization_fallback_count"] = 1
		proven_serial.audit["paired_registration_scale_skip_count"] = 0
		proven_serial.audit["serial_finalization_reuse_count"] = 1
		proven_serial.cache_compiled_fabric(proven_serial_fabric)
		return _stamp_selection(proven_serial, volume, variant)
	last_failure = "final room cleanup rejected: %s" % " | ".join(failures)
	return null


static func _stamp_selection(finalized: WarrenSpatialPlan,
		volume: WarrenVolumePlan, variant: int) -> WarrenSpatialPlan:
	## The two identity keys a sealed plan carries about the source it came
	## from, and the cleared failure that says the solve succeeded.
	last_failure = ""
	finalized.audit["production_selected_source_id"] = String(volume.stable_id)
	finalized.audit["production_selected_variant"] = variant
	return finalized


## Guidance values (never gates — see the note above
## MAX_PRODUCTION_THROUGH_SIGHTLINES): the reviewed alley-bounded walk ratio a
## scale's towns should read with, for ranking and audits.
static func minimum_production_alley_ratio(audit: Dictionary) -> float:
	## The reviewed street character: walk cells inside an alley at most
	## three cells wide with real built edges on both flanks. Floors are
	## corpus-measured, never aspirational: standard villages measured
	## 0.30-0.53 at precomposition across six seeds and 0.33 sealed on the
	## pinned fixture, so 0.30 gates regressions without rejecting any
	## measured survivor. Other scales stay ungated until their corpus is
	## measured.
	var profile := WarrenVillageScaleProfile.for_id(StringName(
		audit.get("scale_profile_id", "")))
	if profile == null:
		return 0.0
	return 0.30 if profile.scale_id == WarrenVillageScaleProfile.STANDARD \
		else 0.0


static func minimum_production_overhead_ratio(audit: Dictionary) -> float:
	## One occupied skywalk covers a nearly fixed number of fine route cells,
	## while route length and the required feature count scale independently.
	## Treating the large showcase's 38% target as a compact-town invariant made
	## an otherwise tight 45-cell covered alley fail solely because it did not own
	## the large profile's third bridge and elevated court. Long/ground sightline
	## gates remain identical at every scale, so this changes town extent rather
	## than allowing open streets or decorative overhead to masquerade as mass.
	var profile_id := StringName(audit.get("scale_profile_id", &""))
	var profile := WarrenVillageScaleProfile.for_id(profile_id)
	return profile.minimum_inhabited_overhead_ratio if profile != null \
		else MIN_PRODUCTION_OVERHEAD_ROUTE_RATIO


static func solve_selected(world_seed: int, selected: WarrenSpatialPlan,
		ground_bands: Dictionary = {},
		construction_program: SettlementFabricProgram = null) -> WarrenSpatialPlan:
	## Rebuild the flat preview's town against local terrain.
	##
	## TASK D1, controller ruling 1. Solid-first generation has ONE source per
	## (seed, bands): no bore attempt to look up, no ranked frontier to search
	## the preview's topology inside, and no partition variant to carry across.
	## The terrain rebuild is therefore the identical one-pass solve the preview
	## itself came from, with the placement's real bands instead of the flat
	## frame.
	##
	## The rebuilt entrance is deliberately NOT compared to the preview's here.
	## On real ground the entry cell's BAND is the terrain the portal stands on,
	## so an exact Vector3i comparison would refuse every sloped placement by
	## construction. The road was aligned to where the mouth LANDS, and
	## `VillageWarrenFabricSolver.solve` compares exactly that -- the entry's
	## (x, z) -- immediately after this call.
	last_failure = ""
	if selected == null or not selected.is_sealed() \
			or selected.source_volume == null or construction_program == null:
		last_failure = "selected volumetric preview is missing or unsealed"
		return null
	var profile_id := StringName(selected.source_volume.mass_context.get(
		&"scale_profile_id", WarrenVillageScaleProfile.LARGE))
	var profile := WarrenVillageScaleProfile.for_id(profile_id)
	if profile == null:
		last_failure = "selected preview has an invalid scale profile"
		return null
	return _solve_maze(world_seed, ground_bands, construction_program, profile)


static func from_volume(volume: WarrenVolumePlan,
		partition_variant: int = 0,
		construction_program: SettlementFabricProgram = null,
		enable_paired_registration_relief: bool = true) -> WarrenSpatialPlan:
	last_failure = ""
	if volume == null or not volume.is_sealed() or construction_program == null:
		last_failure = "missing sealed macro volume or measured vocabulary"
		return null
	var massif := volume.mass_context.get(&"massif") as WarrenMassif
	if massif == null or not massif.is_sealed():
		last_failure = "macro volume carries no sealed inhabited massif"
		return null
	var bounds := _grid_bounds(massif)
	var grid := WarrenSpatialGrid.new(bounds.minimum, bounds.size)
	if not grid.is_valid() or not _project_massif(grid, massif):
		last_failure = "spatial grid invalid or massif projection failed"
		return null
	# Maze skywalks are topology, not late decoration. Resolve their complete
	# body + two endpoint footprints against the exact fine route surfaces before
	# open-to-sky air is committed, then withhold those occupied cells from the
	# carve while still opening every required public-headroom band below them.
	var bridge_compounds := _maze_bridge_compound_plans(volume)
	volume.mass_context[&"maze_bridge_compounds"] = bridge_compounds
	var projected_mass_cell_count := grid.cells_with_use(
		WarrenSpatialGrid.Use.ALLOCATABLE).size()
	var route_floors := _carve_public_volume(grid, volume,
		bridge_compounds.get("private_cells", {}) as Dictionary,
		bridge_compounds.get("additional_air", {}) as Dictionary)
	if route_floors.is_empty():
		last_failure = "public volume carve produced no route floor"
		return null
	# Maze mode: a DECK plot is a PLAZA, and a plaza is paved public floor.
	# Carved here, beside the bore's own streets and before any parcel or room
	# is composed, so a deck can never be mass some later pass claims. Empty on
	# every searched volume, which is what keeps legacy composition identical.
	var deck_cell_count := _pave_maze_decks(grid, volume, route_floors)
	if deck_cell_count < 0:
		return null
	# Maze mode: a flat-roofed plot's SLAB is construction, not leftover mass.
	# Retained before composition because a house stacked on that plot proves
	# its bearing against the grid, and the band under it has to be structure
	# by then (Task C5 ruling 2). Zero on every searched volume.
	var slab_courses := _retain_maze_slab_courses(grid, volume)
	if bool(slab_courses.failed):
		return null
	var parcels_started_ms := Time.get_ticks_msec()
	var parcel_plan := WarrenTownSolver.partition_parcels(volume)
	_stamp_maze_stage(volume, &"parcels", parcels_started_ms)
	if parcel_plan == null:
		last_failure = WarrenTownSolver.last_partition_failure
		return null
	var courtyard_parcel_sides := _parcel_courtyard_address_side_count(grid,
		volume, parcel_plan)
	var scale_profile := _scale_profile_for_volume(volume)
	if scale_profile == null:
		last_failure = "macro volume carries an invalid scale profile"
		return null
	if scale_profile.requires_elevated_courtyard \
			and courtyard_parcel_sides < MIN_COURT_PARCEL_SIDE_COUNT:
		# A court the partition cannot form is richness, not structure: the
		# shortfall is published and the town ships plainer.
		last_advisory_shortfalls["courtyard_parcel_sides"] = \
			courtyard_parcel_sides
	var partition_started_ms := Time.get_ticks_msec()
	var partition := _partition_rooms(grid, volume, parcel_plan,
		construction_program, enable_paired_registration_relief)
	_stamp_maze_stage(volume, &"partition_rooms", partition_started_ms)
	if partition.is_empty():
		if last_failure.is_empty():
			last_failure = "room partition produced no result"
		return null
	# room_volume_budget is guidance recorded in the audit below, not a gate:
	# village-scale massifs compose 31-48 (compact) / 61-66 (standard) rooms,
	# and the massif radius already bounds the town's size (docs §8.8).
	var room_count := int(partition.room_count)
	for cell_value: Variant in (partition.market_reservation.get(
			"public_cells", {}) as Dictionary).keys():
		var market_floor := cell_value as Vector3i
		if not route_floors.has(market_floor):
			route_floors.append(market_floor)
	# Maze mode: an OPEN BRIDGE DECK is paving, and paving reaches the surface
	# solver through `route_floors` exactly as a deck plot's does (ruling 5).
	# Empty on every searched volume.
	for deck_floor: Vector3i in partition.get(
			"open_bridge_deck_floor_cells", []) as Array[Vector3i]:
		if not route_floors.has(deck_floor):
			route_floors.append(deck_floor)
	route_floors.sort_custom(_cell_less)
	var buildings := partition.buildings as Array[WarrenBuildingVolume]
	var supports := partition.supports as WarrenSupportGraph
	if buildings.size() < MIN_BUILDINGS:
		last_failure = "only %d volumetric buildings formed" % buildings.size()
		return null
	# A common roof court is a path decision, not a decorative roof prop. Carve
	# its walk and full headroom now, while the final room crowns are known but
	# before balconies, outcroppings, and roofs reserve the same volume. Large and
	# grand profiles already carry their stricter authored third-storey court;
	# compact and standard towns receive one route-connected roof court whenever
	# their actual supported mass can form a broad, coplanar patch.
	var rooftop_court := {"failed": false, "court_count": 0,
		"floor_cells": [] as Array[Vector3i], "audit": {}}
	if not scale_profile.requires_elevated_courtyard:
		rooftop_court = _carve_route_connected_rooftop_court(grid, volume,
			route_floors, buildings)
		if bool(rooftop_court.get("failed", false)):
			last_failure = "route-connected rooftop court carve failed: %s" \
				% JSON.stringify(rooftop_court.get("audit", {}))
			return null
		for court_cell: Vector3i in rooftop_court.floor_cells \
				as Array[Vector3i]:
			if not route_floors.has(court_cell):
				route_floors.append(court_cell)
		route_floors.sort_custom(_cell_less)
	var features_started_ms := Time.get_ticks_msec()
	var features := WarrenSpatialFeatureSolver.solve(grid, volume, buildings,
		supports, partition.skywalk_reservations as Array[Dictionary],
		partition.courtyard_bridge_reservation as Dictionary,
		partition.market_reservation as Dictionary,
		partition.landmark_reservations as Array[Dictionary],
		construction_program, partition.composition_audit as Dictionary)
	_stamp_maze_stage(volume, &"feature_solver", features_started_ms)
	if features.is_empty():
		last_failure = WarrenSpatialFeatureSolver.last_failure
		return null
	var unassigned_mass_cell_count := grid.cells_with_use(
		WarrenSpatialGrid.Use.ALLOCATABLE).size()
	var trim_audit := _unassigned_mass_audit(grid)
	trim_audit.merge(_uncovered_route_overhead_supply_audit(grid, volume),
		true)
	var retained_private_cell_count := grid.cells_with_use(
		WarrenSpatialGrid.Use.PRIVATE_VOLUME).size()
	if not _discard_unassigned_mass(grid) or not _derive_shell(grid, buildings):
		last_failure = "unassigned-mass discard or shell derivation failed: %s" \
			% grid.last_rejection
		return null
	# Maze mode: what the discard above just threw away is the MOUNTAIN. Take
	# back every cell of it the source calls solid (Task C5 ruling 3), after
	# the shell so no room's facade changes, and give it one sealed feature
	# owner so the sealed plan can carry it as structure.
	var retained_rock := _retain_maze_rock(grid, volume, route_floors,
		buildings, construction_program)
	if bool(retained_rock.failed):
		return null
	# Ruling 1: with every use settled, ask the plot mass what became of it.
	var plot_mass_audit := _maze_plot_mass_audit(grid, volume)
	var stone_result := _maze_stone_reservation(grid, supports)
	if bool(stone_result.failed):
		return null
	var retained_stone := stone_result.feature as WarrenFeatureReservation
	var plan := WarrenSpatialPlan.new(
		StringName("warren.spatial.%d.v%d" % [volume.world_seed,
			partition_variant]), volume.world_seed, grid)
	plan.source_volume = volume
	for cell: Vector3i in route_floors:
		if not plan.add_route_floor(cell):
			last_failure = "duplicate or invalid fine route floor %s" % cell
			return null
	for building: WarrenBuildingVolume in buildings:
		if not plan.add_building(building):
			last_failure = "could not add volumetric building %s" % building.stable_id
			return null
	for feature: WarrenFeatureReservation in features:
		if not plan.add_feature(feature):
			last_failure = "could not add composed feature %s" % feature.stable_id
			return null
	if retained_stone != null and not plan.add_feature(retained_stone):
		last_failure = "could not add retained maze stone"
		return null
	if not plan.set_support_graph(supports):
		last_failure = "could not attach sealed support DAG"
		return null
	var entry := _fine_square(volume.entry_cell)[0]
	if not plan.seal(entry):
		last_failure = plan.last_rejection
		return null
	var minimum_route_y := 2147483647
	var maximum_route_y := -2147483648
	for cell: Vector3i in route_floors:
		minimum_route_y = mini(minimum_route_y, cell.y)
		maximum_route_y = maxi(maximum_route_y, cell.y)
	plan.audit["route_vertical_span_bands"] = maximum_route_y - minimum_route_y
	plan.audit["source_macro_walk_count"] = volume.walk_cells.size()
	plan.audit["source_courtyard_macro_cell_count"] = \
		volume.courtyard_cells.size()
	plan.audit["source_courtyard_parcel_side_count"] = courtyard_parcel_sides
	plan.audit["scale_profile_id"] = StringName(volume.mass_context.get(
		&"scale_profile_id", WarrenVillageScaleProfile.LARGE))
	plan.audit["scale_profile_signature"] = String(volume.mass_context.get(
		&"scale_profile_signature", ""))
	plan.audit["projected_mass_cell_count"] = projected_mass_cell_count
	plan.audit["unassigned_mass_cell_count"] = unassigned_mass_cell_count
	plan.audit["retained_private_mass_cell_count"] = retained_private_cell_count
	plan.audit["retained_private_mass_ratio"] = \
		float(retained_private_cell_count) \
		/ float(maxi(1, projected_mass_cell_count))
	plan.audit.merge(trim_audit, true)
	plan.audit["partition_variant"] = partition_variant
	plan.audit["room_stamp_count"] = room_count
	plan.audit["room_volume_budget_min"] = scale_profile.room_volume_budget.x
	plan.audit["room_volume_budget_max"] = scale_profile.room_volume_budget.y
	plan.audit["route_connected_rooftop_court_count"] = int(
		rooftop_court.get("court_count", 0))
	plan.audit["route_connected_rooftop_court_floor_cell_count"] = (
		rooftop_court.floor_cells as Array).size()
	plan.audit["route_connected_rooftop_court_audit"] = (
		rooftop_court.audit as Dictionary).duplicate(true)
	for key: StringName in [&"perimeter_parcel_count",
			&"grounded_perimeter_parcel_count",
			&"gateway_supported_perimeter_parcel_count",
			&"ungrounded_perimeter_parcel_count",
			&"unsupported_perimeter_parcel_count",
			&"grounded_perimeter_parcel_ratio",
			&"perimeter_load_path_ratio"]:
		plan.audit[key] = parcel_plan.audit.get(key, 0)
	plan.audit["offset_composition_block_count"] = int(partition.offset_blocks)
	plan.audit["ownership_handoff_count"] = int(partition.handoffs)
	plan.audit["rejected_unfloored_address_count"] = int(
		partition.rejected_unfloored_address_count)
	plan.audit.merge(partition.composition_audit as Dictionary, true)
	plan.audit["preplanned_skywalk_count"] = int(
		partition.preplanned_skywalk_count)
	plan.audit["preplanned_landmark_count"] = (
		partition.landmark_reservations as Array).size()
	plan.audit.merge(WarrenSpatialFeatureSolver.last_audit, true)
	if volume.mass_context.has(&"maze_source_plan"):
		plan.audit["maze_deck_cell_count"] = deck_cell_count
		# TASK I4 ROUND 3. The plaza deck, counted where the corpus sweep can
		# see it: the macro columns `WarrenPlotReservations._place_plaza`
		# claimed, or 0 on a town where no aspect-legal site fitted and the
		# corridor fallback stands. It is the source's own record rather than a
		# re-derivation, so "the town got its square" is asserted against the
		# rule that placed it.
		var maze_source := volume.mass_context.get(&"maze_source_plan") \
			as WarrenMazeSourcePlan
		plan.audit["maze_plaza_deck_column_count"] = int(((maze_source.audit.get(
			"plot_outcomes", {}) as Dictionary).get("plaza", {}) \
			as Dictionary).get("size", 0))
		plan.audit["maze_slab_course_cell_count"] = int(slab_courses.cells)
		plan.audit["maze_retained_rock_cell_count"] = int(retained_rock.cells)
		plan.audit["maze_retained_rock_skipped_reserved"] = \
			int(slab_courses.skipped) + int(retained_rock.skipped)
		# Ruling 1: the same stone, told apart. `maze_retained_rock_cells` is
		# DERIVED rock -- solid the plot planner gave to nobody, which the plot
		# model wants as a modest base. `maze_unroomed_plot_cells` is plot mass
		# the composition never built in, which is the quarry block, and
		# `maze_unroomed_plot_share` is its share of the whole plot mass.
		plan.audit["maze_retained_rock_cells"] = int(retained_rock.rock_cells)
		plan.audit["maze_retained_rock_stone_roof_cells"] = int(
			retained_rock.roof_cells)
		plan.audit["maze_retained_unroomed_plot_stone_cells"] = int(
			retained_rock.unroomed_plot_cells)
		# Raw massif residue is terrain, not a miniature building. Its final
		# column transaction repeatedly lowers a lone 3 m crown course until it
		# joins another terrace. Actual compact buildings never enter that pass:
		# their roof/skywalk classification was sealed before rock retention.
		plan.audit["maze_released_singleton_rock_crown_cells"] = int(
			retained_rock.released_singleton_crown_cells)
		plan.audit["maze_released_singleton_derived_rock_cells"] = int(
			retained_rock.released_singleton_derived_rock_cells)
		plan.audit["maze_released_singleton_unroomed_plot_cells"] = int(
			retained_rock.released_singleton_unroomed_plot_cells)
		plan.audit["maze_released_singleton_roof_band_cells"] = int(
			retained_rock.released_singleton_roof_band_cells)
		plan.audit["maze_remaining_singleton_rock_crown_count"] = int(
			retained_rock.remaining_singleton_crown_count)
		# TASK E4 FIX 1. The plot mass this town would have retained as stone
		# and cut off instead, two storeys above the plot's own public floor,
		# and the plots that refused the cut because something would have been
		# left standing over the released air. The THIRD term of the retention
		# identity: `unroomed - retained_unroomed` is now `trimmed` plus, at
		# most, the cells another feature had reserved.
		plan.audit["maze_trimmed_unroomed_plot_stone_cells"] = int(
			retained_rock.trimmed_unroomed_plot_cells)
		plan.audit["maze_trimmed_roof_band_stone_cells"] = int(
			retained_rock.trimmed_roof_band_cells)
		# An asset plot is a measured construction reservation, not a coarse
		# rectangular building. Once the authored prefab has claimed its exact
		# body, every unused cell in the plot envelope remains exterior air. This
		# count makes that semantic release part of the retention identity instead
		# of hiding it in a smaller stone total.
		plan.audit["maze_released_asset_envelope_cells"] = int(
			retained_rock.released_asset_envelope_cells)
		plan.audit["maze_released_required_roof_envelope_cells"] = int(
			retained_rock.released_required_roof_envelope_cells)
		plan.audit["maze_released_required_roof_derived_cells"] = int(
			retained_rock.released_required_roof_derived_cells)
		plan.audit["maze_released_required_roof_unroomed_plot_cells"] = int(
			retained_rock.released_required_roof_unroomed_plot_cells)
		plan.audit["maze_released_required_roof_band_cells"] = int(
			retained_rock.released_required_roof_band_cells)
		plan.audit["maze_refused_unroomed_plot_trims"] = int(
			retained_rock.refused_plot_trims)
		# TASK C5e RULING 2, widened by TASK H2. The crown bands left as AIR
		# instead of retained as stone, so a crown is an open plank terrace
		# rather than a masonry block with a timber sill. Counted here rather
		# than inferred from the drop in the stone total, because a crown
		# something stands on deliberately KEEPS its course -- see
		# `_maze_released_parapet_cells`.
		#
		# `maze_stranded_release_repair_count` is what the release TOOK BACK
		# (`_repair_stranded_release`): crown cells another plot's unroomed mass
		# turned out to be standing on. Published rather than folded into the
		# release total, because a rising number there means the composition is
		# leaving more quarry blocks on other houses' roofs, which is a
		# composition fact worth watching on its own.
		plan.audit["maze_released_parapet_cell_count"] = int(
			retained_rock.released_parapet_cells)
		plan.audit["maze_stranded_release_repair_count"] = int(
			retained_rock.stranded_release_repairs)
		plan.audit["maze_plot_mass_cell_count"] = int(
			plot_mass_audit.plot_cells)
		plan.audit["maze_plot_roomed_cell_count"] = int(plot_mass_audit.roomed)
		plan.audit["maze_plot_roofed_cell_count"] = int(plot_mass_audit.roofed)
		plan.audit["maze_plot_public_cell_count"] = int(plot_mass_audit.public)
		plan.audit["maze_plot_feature_cell_count"] = int(
			plot_mass_audit.feature)
		plan.audit["maze_plot_unbuildable_cell_count"] = int(
			plot_mass_audit.unbuildable)
		plan.audit["maze_unroomed_plot_cells"] = int(plot_mass_audit.unroomed)
		plan.audit["maze_unroomed_plot_uses"] = (
			plot_mass_audit.unroomed_uses as Dictionary).duplicate()
		plan.audit["maze_unroomed_plot_share"] = float(plot_mass_audit.share)
		plan.audit["maze_retained_stone_cell_count"] = 0 \
			if retained_stone == null \
			else retained_stone.reserved_cells.size()
		for key: StringName in [&"maze_stacked_plot_count",
				&"maze_declared_stack_count", &"maze_stack_refusal_count",
				&"maze_stack_slab_gap_count", &"maze_partial_stack_count",
				&"maze_stack_parents", &"maze_stack_refusals",
				# TASK C5d -- how many houses ASKED for a pitched roof, which
				# is the denominator the fabric's own
				# `maze_pitched_roof_count` is read against.
				&"maze_pitched_preference_count",
				&"maze_pitched_preference_parcels"]:
			plan.audit[key] = parcel_plan.audit.get(key, -1)
	# A spatial topology is not production-valid until the authored construction
	# shells for its final recomposed rooms clear every unrelated hero feature.
	# This exact, bounded gate runs once per complete partition survivor.  It lets
	# the existing topology/partition frontier advance past a courtyard placement
	# whose measured eaves collide, without inflating every 3D search cell with a
	# conservative halo or teaching the renderer to forgive the intersection.
	var room_gate_started_ms := Time.get_ticks_msec()
	var room_units := WarrenSpatialFabricCompiler.compile_room_units(plan,
		construction_program)
	_stamp_maze_stage(volume, &"room_gate", room_gate_started_ms)
	if room_units.is_empty():
		last_failure = "authored room envelope gate failed: %s" \
			% WarrenSpatialFabricCompiler.last_failure
		if diagnostic_trace_room_gate:
			print("SKYWALK_TIMING authored_room_gate source=",
				volume.stable_id, " variant=", partition_variant, " failure=",
				last_failure, " audit=", WarrenSpatialFabricCompiler.last_audit)
		return null
	plan.cache_compiled_room_units(room_units,
		WarrenSpatialFabricCompiler.last_audit)
	plan.audit["authored_room_envelope_gate_count"] = room_units.size()
	last_diagnostic = plan.audit.duplicate(true)
	return plan


static func _parcel_courtyard_address_side_count(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan, parcels: WarrenParcelPlan) -> int:
	var floors: Dictionary = {}
	for macro: Vector3i in volume.courtyard_cells:
		for floor: Vector3i in _fine_square(macro):
			floors[floor] = true
	var occupied: Dictionary = {}
	for parcel: WarrenBuildingParcel in parcels.parcels:
		if not _parcel_address_has_public_floor(grid, parcel):
			continue
		var proposal := WarrenParcelConstruction.proposal(parcel)
		if proposal.is_empty():
			continue
		for cell: Vector3i in _proposal_private_cells(proposal):
			occupied[cell] = parcel.stable_id
	var side_count := 0
	for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
			Vector3i.FORWARD, Vector3i.BACK]:
		var addressed := false
		for floor_value: Variant in floors.keys():
			var floor := floor_value as Vector3i
			if floors.has(floor + direction):
				continue
			for y_offset in WarrenSpatialGrid.STOREY_CELLS:
				if occupied.has(floor + direction + Vector3i.UP * y_offset):
					addressed = true
					break
			if addressed:
				break
		side_count += int(addressed)
	return side_count


static func _grid_bounds(massif: WarrenMassif) -> Dictionary:
	var minimum_x := 2147483647
	var maximum_x := -2147483648
	var minimum_z := 2147483647
	var maximum_z := -2147483648
	var minimum_y := 2147483647
	var maximum_y := -2147483648
	for column: Vector2i in massif.columns:
		minimum_x = mini(minimum_x, column.x * 2)
		maximum_x = maxi(maximum_x, column.x * 2 + 1)
		minimum_z = mini(minimum_z, column.y * 2)
		maximum_z = maxi(maximum_z, column.y * 2 + 1)
		minimum_y = mini(minimum_y, massif.base_at(column))
		maximum_y = maxi(maximum_y, massif.top_at(column))
	var minimum := Vector3i(minimum_x - GRID_PADDING_CELLS, minimum_y,
		minimum_z - GRID_PADDING_CELLS)
	var maximum := Vector3i(maximum_x + GRID_PADDING_CELLS,
		maximum_y + ROOF_CLEARANCE_CELLS,
		maximum_z + GRID_PADDING_CELLS)
	return {"minimum": minimum, "size": maximum - minimum + Vector3i.ONE}


static func _project_massif(grid: WarrenSpatialGrid,
		massif: WarrenMassif) -> bool:
	var cells: Array[Vector3i] = []
	for column: Vector2i in massif.columns:
		for y in range(massif.base_at(column), massif.top_at(column)):
			cells.append_array(_fine_square(Vector3i(column.x, y, column.y)))
	var tx := grid.begin_transaction(&"massif.allocation")
	if not tx.assign_use(cells, WarrenSpatialGrid.Use.ALLOCATABLE,
			&"massif.allocation") or not tx.commit():
		last_failure = "could not project allocation massif: %s" % tx.last_rejection
		return false
	return true


static func _maze_bridge_compound_plans(volume: WarrenVolumePlan) \
		-> Dictionary:
	## Compile every source bridge span into one fine-grid occupied compound
	## before the public-air transaction. The exact route surfaces decide the
	## lowest legal occupied floor; the source proof decides the two lateral
	## endpoint footprints. This is the single topology authority later bridge
	## composition reads back -- no phase re-infers a different span or datum.
	var empty := {"plans": [] as Array[Dictionary], "private_cells": {},
		"additional_air": {}}
	var source := volume.mass_context.get(&"maze_source_plan") \
		as WarrenMazeSourcePlan
	if source == null or source.excavation == null:
		return empty
	var route_floors: Dictionary = {}
	for macro_floor: Vector3i in volume.walk_cells:
		for fine_floor: Vector3i in _fine_square(macro_floor):
			route_floors[fine_floor] = true
	for transition: WarrenVolumeTransition in volume.transitions:
		for fine_floor: Vector3i in transition.surface_cells():
			route_floors[fine_floor] = true
	for deck_floor_value: Variant in _maze_deck_floor_cells(volume).keys():
		route_floors[deck_floor_value as Vector3i] = true
	var seeded := source.excavation.bridge_span_audit.get("seeded", []) as Array
	var plans: Array[Dictionary] = []
	var protected: Dictionary = {}
	var additional_air: Dictionary = {}
	for span_index in source.excavation.bridge_spans.size():
		var span := source.excavation.bridge_spans[span_index] \
			as Array[Vector3i]
		var proof := seeded[span_index] as Dictionary \
			if span_index < seeded.size() else {}
		var columns: Array[Vector2i] = []
		for cell: Vector3i in span:
			var column := Vector2i(cell.x, cell.z)
			if not columns.has(column):
				columns.append(column)
		# Endpoint topology was sealed by the source selector together with the
		# span. Consuming that exact partition keeps the air carve, endpoint room
		# completion, and final socket proof on one fact; reconstructing it here
		# from nearby mass let a later phase disagree about which side existed.
		var endpoint_groups: Array = proof.get("endpoint_groups", []) as Array
		if endpoint_groups.size() != 2:
			continue
		var source_floor := int(proof.get("floor", 0))
		var occupied_columns: Dictionary = {}
		for column: Vector2i in columns:
			occupied_columns[column] = true
		for group_value: Variant in endpoint_groups:
			for column_value: Variant in group_value as Array:
				occupied_columns[column_value as Vector2i] = true
		var fine_columns: Dictionary = {}
		for column_value: Variant in occupied_columns.keys():
			var column := column_value as Vector2i
			for fine: Vector3i in _fine_square(Vector3i(column.x, 0,
					column.y)):
				fine_columns[Vector2i(fine.x, fine.z)] = true
		var floor_band := source_floor
		for floor_value: Variant in route_floors.keys():
			var floor := floor_value as Vector3i
			if fine_columns.has(Vector2i(floor.x, floor.z)):
				floor_band = maxi(floor_band,
					floor.y + WarrenVolumePlan.HEADROOM_BANDS)
		var top_band := floor_band + WarrenSpatialGrid.STOREY_CELLS
		var private_cells: Dictionary = {}
		for column_value: Variant in occupied_columns.keys():
			var column := column_value as Vector2i
			for band in range(floor_band, top_band):
				for fine: Vector3i in _fine_square(Vector3i(column.x, band,
						column.y)):
					private_cells[fine] = true
		var overlaps_prior := false
		for cell_value: Variant in private_cells.keys():
			if protected.has(cell_value):
				overlaps_prior = true
				break
		if overlaps_prior:
			continue
		for cell_value: Variant in private_cells.keys():
			protected[cell_value as Vector3i] = span_index
		# Raise the tunnel headroom from the ACTUAL route floor in each span
		# column. Starting at the source proof's nominal band could carve below an
		# elevated walkway, creating a sealed air pocket under its floor. Every
		# supplemental cell now grows directly from node-owned route air and is
		# connected by construction.
		for column: Vector2i in columns:
			for fine_column: Vector3i in _fine_square(Vector3i(column.x, 0,
					column.y)):
				for route_floor_value: Variant in route_floors.keys():
					var route_floor := route_floor_value as Vector3i
					if route_floor.x != fine_column.x \
							or route_floor.z != fine_column.z:
						continue
					for band in range(route_floor.y, floor_band):
						var air_cell := Vector3i(fine_column.x, band,
							fine_column.z)
						if not private_cells.has(air_cell):
							additional_air[air_cell] = true
		plans.append({"span_index": span_index,
			"columns": columns.duplicate(), "floor": floor_band,
			"top": top_band, "source_floor": source_floor,
			"endpoint_groups": endpoint_groups.duplicate(true),
			"private_cells": private_cells})
	return {"plans": plans, "private_cells": protected,
		"additional_air": additional_air}


static func _carve_public_volume(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan, protected_private: Dictionary = {},
		additional_air: Dictionary = {}) -> Array[Vector3i]:
	var air: Dictionary = {}
	for macro_cell: Vector3i in volume.public_air_cells:
		for fine_cell: Vector3i in _fine_square(macro_cell):
			air[fine_cell] = true
	for cell_value: Variant in additional_air.keys():
		air[cell_value as Vector3i] = true
	var route: Dictionary = {}
	for macro_floor: Vector3i in volume.walk_cells:
		for fine_floor: Vector3i in _fine_square(macro_floor):
			route[fine_floor] = true
	for transition: WarrenVolumeTransition in volume.transitions:
		for fine_floor: Vector3i in transition.surface_cells():
			route[fine_floor] = true
	for floor_value: Variant in route.keys():
		var floor_cell := floor_value as Vector3i
		for y_offset in WarrenVolumePlan.HEADROOM_BANDS:
			air[floor_cell + Vector3i.UP * y_offset] = true
	# The bridge plan was derived from these exact route floors and chose its
	# occupied datum at or above every required headroom interval. Removing only
	# those sealed private cells turns the formerly open-to-sky column into a
	# tunnel with an inhabited roof; it never shortens walk clearance.
	for cell_value: Variant in protected_private.keys():
		air.erase(cell_value as Vector3i)
	# The occupied bridge compound can split tall source sweep volume above or
	# below the canonical street. Public air is the connected exterior realm,
	# seeded by exact route surfaces—not every historical bore voxel left after
	# subtraction. Keep only that component so a sealed pocket can never survive
	# as unreachable PUBLIC_AIR, while every real street/stair seed is mandatory.
	var reached_air: Dictionary = {}
	var pending_air: Array[Vector3i] = []
	for floor_value: Variant in route.keys():
		var route_floor := floor_value as Vector3i
		if not air.has(route_floor):
			last_failure = "bridge compound consumes route floor %s" % route_floor
			return [] as Array[Vector3i]
		if not reached_air.has(route_floor):
			reached_air[route_floor] = true
			pending_air.append(route_floor)
	while not pending_air.is_empty():
		var cell: Vector3i = pending_air.pop_back()
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD, Vector3i.BACK]:
			var neighbor := cell + direction
			if air.has(neighbor) and not reached_air.has(neighbor):
				reached_air[neighbor] = true
				pending_air.append(neighbor)
	air = reached_air
	var air_cells: Array[Vector3i] = []
	air_cells.assign(air.keys())
	var carve := grid.begin_transaction(&"public.route")
	if not carve.require_use(air_cells, [WarrenSpatialGrid.Use.OUTSIDE,
			WarrenSpatialGrid.Use.ALLOCATABLE] as Array[int]) \
			or not carve.reserve(air_cells,
				WarrenSpatialGrid.Reservation.PUBLIC_CLEARANCE,
				&"public.route") \
			or not carve.assign_use(air_cells, WarrenSpatialGrid.Use.PUBLIC_AIR,
				&"public.route"):
		last_failure = "could not stage public-air carve"
		return [] as Array[Vector3i]
	for floor_value: Variant in route.keys():
		if not carve.claim_face(floor_value as Vector3i, Vector3i.DOWN,
				WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR, &"public.route"):
			last_failure = "could not stage public floor"
			return [] as Array[Vector3i]
	if not carve.commit():
		last_failure = "public-air carve rejected: %s" % carve.last_rejection
		return [] as Array[Vector3i]
	var daylight: Dictionary = {}
	for macro_cell: Vector3i in volume.daylight_void_cells:
		for fine_cell: Vector3i in _fine_square(macro_cell):
			daylight[fine_cell] = true
	if not daylight.is_empty():
		var daylight_cells: Array[Vector3i] = []
		daylight_cells.assign(daylight.keys())
		var subtract := grid.begin_transaction(&"public.daylight")
		if not subtract.require_use(daylight_cells,
				[WarrenSpatialGrid.Use.OUTSIDE,
					WarrenSpatialGrid.Use.ALLOCATABLE] as Array[int]) \
				or not subtract.reserve(daylight_cells,
					WarrenSpatialGrid.Reservation.DAYLIGHT,
					&"public.daylight") \
				or not subtract.assign_use(daylight_cells,
					WarrenSpatialGrid.Use.DAYLIGHT_AIR, &"public.daylight") \
				or not subtract.commit():
			last_failure = "daylight subtraction rejected: %s" \
				% subtract.last_rejection
			return [] as Array[Vector3i]
	var out: Array[Vector3i] = []
	out.assign(route.keys())
	out.sort_custom(_cell_less)
	return out


static func _pave_maze_decks(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan, route_floors: Array[Vector3i]) -> int:
	## Maze mode's deck plots, paved. Returns the fine floor cells paved, or
	## -1 with `last_failure` set.
	##
	## A deck is the one plot kind with no height (`top == floor`): a
	## courtyard, plaza or terrace the plot planner grew off a street at that
	## street's own datum. Its surface is the top of whatever is solid at
	## `floor - 1` -- rock, or a house roof -- so paving it is exactly what
	## `_carve_public_volume` does for a bored street: the band itself and the
	## headroom above it become PUBLIC_AIR, and the floor band claims a
	## PUBLIC_FLOOR face. Folding the result into `route_floors` is what
	## carries it to `WarrenSpatialPlan`, and from there to the public-realm
	## adapter and the surface solver that actually lay the paving.
	##
	## The carve is deliberately STRICT about what it may take: a deck column
	## is refused upstream unless `plot_support_ok` finds solid at `floor - 1`
	## and no carved band in the MIN_HOUSE_BANDS above it, so a deck can never
	## overlap a street's own air, and a collision here is a generator defect
	## that must be loud rather than silently absorbed.
	##
	## DECK COUPLINGS. A deck cell is indistinguishable from a bored street
	## cell to everything that reads the grid, which is the point -- it is a
	## public floor -- but three later stages change their answer because of
	## it, and each is a real behaviour change rather than a formality:
	##
	## (a) `_parcel_address_has_public_floor` accepts a parcel whose door
	##     landing is a deck cell, so a parcel that used to be counted in
	##     `rejected_unfloored_address_count` can now enter composition. Decks
	##     ADD parcels, and an empty proposal list is a hard rejection, so this
	##     coupling can only help a town -- but it does move the room set.
	##     Counted as `maze_deck_addressed_parcel_count`.
	## (b) `_carve_route_connected_rooftop_court` skips any crown that already
	##     carries a face claim or a reservation, so a deck lying on a house
	##     roof removes that crown from the roof-court candidates. (Its seam
	##     set is separately restricted to cells owned by `public.route`, so a
	##     deck can never SUPPLY the seam either.)
	## (c) `_backfill_residual_rooms` builds its route set from every
	##     PUBLIC_AIR cell carrying a PUBLIC_FLOOR face, ignoring owner, so
	##     deck cells count as uncovered route floors and as frontage sides.
	##     The greedy scan is therefore biased toward roofing and fronting the
	##     plazas, exactly as it is toward streets.
	var floors := _maze_deck_floor_cells(volume)
	if floors.is_empty():
		return 0
	var air: Dictionary = {}
	for floor_value: Variant in floors.keys():
		var floor_cell := floor_value as Vector3i
		for y_offset in WarrenVolumePlan.HEADROOM_BANDS:
			air[floor_cell + Vector3i.UP * y_offset] = true
	var air_cells: Array[Vector3i] = []
	air_cells.assign(air.keys())
	var carve := grid.begin_transaction(&"public.maze_deck")
	if not carve.require_use(air_cells, [WarrenSpatialGrid.Use.OUTSIDE,
			WarrenSpatialGrid.Use.ALLOCATABLE] as Array[int]) \
			or not carve.reserve(air_cells,
				WarrenSpatialGrid.Reservation.PUBLIC_CLEARANCE,
				&"public.maze_deck") \
			or not carve.assign_use(air_cells,
				WarrenSpatialGrid.Use.PUBLIC_AIR, &"public.maze_deck"):
		last_failure = "could not stage maze deck carve"
		return -1
	for floor_value: Variant in floors.keys():
		if not carve.claim_face(floor_value as Vector3i, Vector3i.DOWN,
				WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR, &"public.maze_deck"):
			last_failure = "could not stage maze deck floor"
			return -1
	if not carve.commit():
		last_failure = "maze deck carve rejected: %s" % carve.last_rejection
		return -1
	for floor_value: Variant in floors.keys():
		route_floors.append(floor_value as Vector3i)
	route_floors.sort_custom(_cell_less)
	return floors.size()


## Owner of every fine cell maze mode keeps as STONE: the flat-roof slab
## courses a stacked house bears on (Task C5 ruling 2) and the leftover rock
## the town was cut out of (ruling 3). One owner because they are one fact --
## mass the plot model kept, which is neither room nor public air -- and one
## material, the assembler's `sfv.foundation.rock.001` course.
##
## It is a FEATURE owner because `WarrenSpatialPlan._validate_building_ownership`
## requires every STRUCTURAL_VOLUME cell to name a sealed feature reservation.
## The reservation carries NO construction record, so
## `WarrenSpatialFabricCompiler.compile_feature_units` skips it and
## `_constructed_feature_count` does not count it: nothing new is compiled and
## the existing retained-terrace channel is what renders the stone.
##
## The name itself lives on the compiler, which is what CONSUMES it.
const MAZE_STONE_FEATURE_ID := WarrenSpatialFabricCompiler \
	.MAZE_RETAINED_STONE_ID
## Column-space cardinals, for the maze passes that ask what is beside a plot.
const CARDINAL_COLUMNS: Array[Vector2i] = [
	Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP,
]


static func _maze_flat_slab_cells(volume: WarrenVolumePlan) -> Dictionary:
	## Every FINE cell of a flat-roofed STACK PARENT's crown span
	## `[flat_roof_base_band, top_band)`: the bands between the storeys its
	## rooms fill and its own `top_band`.
	##
	## A flat parcel's `storey_count()` is `(height - 1) / STOREY_BANDS`, so
	## its rooms stop at `roof_base_band()` and one or two bands are left over.
	## The FIRST of them carries the authored one-band `roof.flat.*` unit the
	## roof compiler places (ruling 1); a second, where the plot's height is
	## even, is a stone parapet course. Both are claimed, because what a child
	## at `top_band` stands on is the whole slab and
	## `WarrenRoomCompositionPlanner` proves that bearing by asking the grid
	## whether the band below the child is STRUCTURAL_VOLUME.
	##
	## THE WHOLE PLATE, NOT THE CHILD'S FOOTPRINT, and Task H2 measured why --
	## see `_retain_maze_slab_courses`, which carries the evidence and the
	## cost.
	##
	## ONLY A PARENT'S SLAB, and the restriction is deliberate. Claiming mass
	## before composition takes it away from the greedy residual scan, and a
	## flat plot nobody stands on has no bearing to prove: its slab is retained
	## by `_retain_maze_rock` AFTER composition instead, or -- since Task H2 --
	## RELEASED there with the rest of its crown. Retaining early where nothing
	## needs it cost seed 4/compact its whole town (measured: the scan lost the
	## rooms whose crowns closed a neighbouring roof remainder).
	##
	## The stacking rule itself is asked of `WarrenMazeBlockPartitioner`, which
	## owns it; restating it here is how a translator and a solver come to
	## disagree about which plot is a parent.
	##
	## Empty for a searched volume, which is what keeps every reader maze-only.
	var out: Dictionary = {}
	var source := volume.mass_context.get(&"maze_source_plan") \
		as WarrenMazeSourcePlan
	if source == null:
		return out
	var parents: Dictionary = {}
	for parent_value: Variant in (WarrenMazeBlockPartitioner.stack_parents(
			source)["parents"] as Dictionary).values():
		parents[StringName(parent_value)] = true
	if parents.is_empty():
		return out
	for plot: Dictionary in source.plots:
		if StringName(plot["kind"]) != WarrenMazeSourcePlan.PLOT_HOUSE \
				or not parents.has(StringName(plot["id"])):
			continue
		if not WarrenMazeBlockPartitioner.plot_is_flat_roofed(source, plot):
			continue
		var top_band := int(plot["top"])
		var roof_base := WarrenBuildingParcel.flat_roof_base_band(
			int(plot["floor"]), top_band)
		for band in range(roof_base, top_band):
			for cell_value: Variant in plot["cells"] as Array:
				var column := cell_value as Vector2i
				for fine: Vector3i in _fine_square(Vector3i(column.x, band,
						column.y)):
					out[fine] = true
	return out


static func _retain_maze_slab_courses(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan) -> Dictionary:
	## Ruling 2, and the reason it runs HERE -- before any parcel or room is
	## composed. A stacked child's bearing is proved by
	## `WarrenRoomCompositionPlanner._floorplate_transition_is_structurally_legible`,
	## which reads the grid, so the slab has to be structure before the
	## composition asks. The mass it takes is mass a flat parcel's own rooms
	## can never reach (they stop at `roof_base_band()`), so claiming it early
	## costs the composition nothing it could otherwise have built.
	##
	## TASK H2 TRIED TO NARROW THIS TO THE CHILD'S FOOTPRINT AND PUT IT BACK.
	## Part 1 wanted the parent's UNCOVERED plate released like every other
	## free crown, so a stack parent would stop wearing a masonry lid beside
	## its child. Both admissible narrowings were built and measured, and both
	## cost 12/large its town at
	## `composition support parent parcel.maze.house.029/0 missing for
	## spatial.parcel.maze.house.075.part00` -- leaving the remainder
	## ALLOCATABLE (the composition takes the extra mass and moves the lineage
	## a declared child was standing on) and discarding it to `OUTSIDE` (same
	## gate, same seed). The reason is the one C5 wrote this restriction for:
	## a child's COMPOSED room is not its plot. The composition merges,
	## couples and expands lineages, so a one-column child plot can end up
	## with a `row` or `slim` room reaching across the parent's other columns,
	## and the bearing it proves against the grid is under cells the plot
	## model cannot name in advance. THE WHOLE PLATE IS THE ONLY CONSERVATIVE
	## ANSWER before composition, and narrowing it is a composition-side
	## change this task's scope fence forbids.
	##
	## What that costs is measured and published rather than hidden:
	## `maze_bearing_crown_cap_count` is the masonry lid that survives on a
	## stack parent's own plate, and `WarrenSpatialFabricCompiler
	## .maze_stone_band_profile` counts it apart from the rubble caps H2 did
	## retire.
	##
	## Returns `{failed, cells, skipped}`; `skipped` counts cells another
	## feature already holds the non-shareable FEATURE bit on -- see
	## `_feature_bit_is_taken`.
	var slab := _maze_flat_slab_cells(volume)
	if slab.is_empty():
		return {"failed": false, "cells": 0, "skipped": 0}
	var cells: Array[Vector3i] = []
	var skipped := 0
	for cell_value: Variant in slab.keys():
		var cell := cell_value as Vector3i
		if not grid.contains(cell) or grid.use_at(cell) \
				!= WarrenSpatialGrid.Use.ALLOCATABLE:
			continue
		if _feature_bit_is_taken(grid, cell):
			skipped += 1
			continue
		cells.append(cell)
	if cells.is_empty():
		return {"failed": false, "cells": 0, "skipped": skipped}
	cells.sort_custom(_cell_less)
	if not _claim_maze_stone(grid, cells):
		return {"failed": true, "cells": 0, "skipped": skipped}
	return {"failed": false, "cells": cells.size(), "skipped": skipped}


static func _retain_maze_rock(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan,
		route_floors: Array[Vector3i] = [] as Array[Vector3i],
		buildings: Array[WarrenBuildingVolume] = [] as Array[WarrenBuildingVolume],
		program: SettlementFabricProgram = null) -> Dictionary:
	## Ruling 3. Every fine cell the SOURCE calls solid at or above its own
	## column's terrain datum that the composed town did not build in is
	## retained as stone instead of being thrown away: shoulders, tunnel roofs,
	## street-floor slabs, the interior nobody roofed, and the span mass a
	## released bridge left behind. Terrain BELOW `base_at` is excluded -- that
	## is the heightfield's ground, and drawing masonry inside it is the
	## monument two review rounds already rejected.
	##
	## It runs AFTER `_discard_unassigned_mass` and after `_derive_shell`, so
	## every shell face this town classifies is byte-identical to the one it
	## classified before rock became stone: a room wall facing rock is still
	## the FACADE it has always been, and deciding otherwise is a visual
	## question this task does not own.
	##
	## Returns SIX keys:
	##
	## - `failed` -- the grid transaction was rejected; the town is lost.
	## - `cells` -- how many cells this pass claimed, all tags together. It is
	##   `rock_cells + roof_cells + unroomed_plot_cells`.
	## - `skipped` -- cells another feature already holds the non-shareable
	##   FEATURE bit on, which this pass steps around rather than fighting for;
	##   see `_feature_bit_is_taken`.
	## - `rock_cells` -- DERIVED ROCK: claimed cells inside no plot at all. The
	##   modest stone base the plot model asks for.
	## - `roof_cells` -- claimed cells inside a plot's own roof band span
	##   (`_maze_plot_roof_cells`). Roof by the height contract, so stone here
	##   is the parapet course rather than a shortfall.
	## - `unroomed_plot_cells` -- the rest: plot mass the composition made
	##   neither room nor roof. The quarry block, and the number Task C5c
	##   exists to move.
	##
	## TASK E4 FIX 1 ADDS TWO MORE, and one rule with them: a plot's retained
	## mass is cut off two storeys above the public floor the plot itself
	## stands on. See `_maze_trimmed_plot_stone`. A trimmed cell is released
	## rather than claimed and is counted in NEITHER `unroomed_plot_cells` nor
	## `roof_cells`, so `cells == rock_cells + roof_cells +
	## unroomed_plot_cells` still holds and the trim shows up as a term of its
	## own instead of as an unexplained fall in the residue.
	##
	## The three are `trimmed_unroomed_plot_cells`, `trimmed_roof_band_cells`,
	## and `released_asset_envelope_cells`,
	## split by the same rule that tells `unroomed_plot_cells` from
	## `roof_cells` (fix 1, IMPORTANT 1). They cannot be one number: only the
	## unroomed half comes out of the residue `_maze_plot_mass_audit` calls
	## `unroomed`, so only that half belongs in the retention identity. Seed
	## 4/compact trims 80 cells of which every one is a roof band, and its
	## unroomed total does not move at all.
	var source := volume.mass_context.get(&"maze_source_plan") \
		as WarrenMazeSourcePlan
	if source == null or source.massif == null:
		return {"failed": false, "cells": 0, "skipped": 0, "rock_cells": 0,
			"unroomed_plot_cells": 0, "roof_cells": 0,
			"trimmed_unroomed_plot_cells": 0, "trimmed_roof_band_cells": 0,
			"released_asset_envelope_cells": 0,
			"released_required_roof_envelope_cells": 0,
			"released_required_roof_derived_cells": 0,
			"released_required_roof_unroomed_plot_cells": 0,
			"released_required_roof_band_cells": 0,
			"released_singleton_crown_cells": 0,
			"released_singleton_derived_rock_cells": 0,
			"released_singleton_unroomed_plot_cells": 0,
			"released_singleton_roof_band_cells": 0,
			"remaining_singleton_crown_count": 0,
			"refused_plot_trims": 0, "stranded_release_repairs": 0}
	# TASK C5c RULING 1 -- the TAG. Retained stone is one material and one
	# owner, but it is two different facts about the town: `rock` is derived
	# stone the plot planner never gave to anybody, and `unroomed_plot_mass`
	# is a building the composition failed to build. The first is the modest
	# base the plot model asks for; the second is the quarry block. Counting
	# them apart is what makes the difference measurable.
	var plot_mass := _maze_plot_mass_cells(volume)
	var plot_roof := _maze_plot_roof_cells(volume)
	var released := _maze_released_parapet_cells(grid, volume, route_floors)
	var released_asset_envelope := _maze_released_asset_envelope_cells(source)
	var released_required_roof_envelope := \
		_maze_released_required_roof_envelope_cells(grid, buildings, program,
			volume.world_seed)
	var trim := _maze_trimmed_plot_stone(source, route_floors)
	var trim_cells := trim.cells as Dictionary
	var stranded := _repair_stranded_release(grid, source, released,
		trim_cells)
	var cells: Array[Vector3i] = []
	var skipped := 0
	var rock_cells := 0
	var unroomed_plot_cells := 0
	var roof_cells := 0
	var released_cells := 0
	var trimmed_cells := 0
	var trimmed_roof_cells := 0
	var released_asset_cells := 0
	var released_required_roof_cells := 0
	var released_required_roof_derived_cells := 0
	var released_required_roof_unroomed_cells := 0
	var released_required_roof_band_cells := 0
	# Every cell admitted here is unclassified retained massif: either raw
	# derived hillside or plot volume for which composition built no room. A real
	# room, roof, public surface, feature, prefab envelope or structural bearing
	# has already left this branch. Keeping the two tags lets the final accounting
	# say which kind of residue was lowered without giving the erosion rule two
	# subtly different definitions of an isolated crown.
	var erodible_rock_candidates: Dictionary = {}
	var lowest := grid.minimum.y
	var highest := grid.minimum.y + grid.size.y
	for column_value: Variant in source.massif.columns.keys():
		var column := column_value as Vector2i
		for band in range(maxi(lowest, source.massif.base_at(column)),
				highest):
			if not source.solid_at(Vector3i(column.x, band, column.y)):
				continue
			for fine: Vector3i in _fine_square(Vector3i(column.x, band,
					column.y)):
				if not grid.contains(fine) or grid.use_at(fine) \
						!= WarrenSpatialGrid.Use.OUTSIDE:
					continue
				if released.has(fine):
					released_cells += 1
					continue
				if _feature_bit_is_taken(grid, fine):
					skipped += 1
					continue
				# Roof closure is a mandatory measured construction domain even
				# though its mesh is selected after this retained-mass pass. Source
				# rock may never reclaim any OUTSIDE cell intersecting one of the
				# finite legal closures; doing so made the final roof appear embedded
				# in a solid stone cube. The union is deliberate: every option the
				# compiler may legally choose must remain constructible.
				if released_required_roof_envelope.has(fine):
					released_required_roof_cells += 1
					if not plot_mass.has(fine):
						released_required_roof_derived_cells += 1
					elif plot_roof.has(fine):
						released_required_roof_band_cells += 1
					else:
						released_required_roof_unroomed_cells += 1
					continue
				# A prefab's source plot is only a coarse search/reservation box.
				# Its exact authored body has already changed its cells away from
				# OUTSIDE, so anything from that box still reaching this branch is
				# provably unused envelope. Retaining it would turn the empty margin
				# around the prefab into a full-height quarry block and visually fuse
				# its foundation to its roof.
				if released_asset_envelope.has(fine):
					released_asset_cells += 1
					continue
				# TASK E4 FIX 1. AFTER the reservation skip, so a cell can
				# never be counted as both trimmed and skipped and the two
				# terms of the retention identity stay disjoint. Split by the
				# same rule the classification below uses, because a trimmed
				# ROOF band never was part of `unroomed_plot_cells` and
				# subtracting it from that total would be an identity that
				# does not hold (measured: seed 4/compact trims 80 cells of
				# which 80 are roof, so its unroomed total does not move at
				# all).
				if trim_cells.has(fine):
					if plot_roof.has(fine):
						trimmed_roof_cells += 1
					else:
						trimmed_cells += 1
					continue
				if not plot_mass.has(fine):
					rock_cells += 1
					erodible_rock_candidates[fine] = &"derived"
				elif plot_roof.has(fine):
					roof_cells += 1
					erodible_rock_candidates[fine] = &"stone_roof"
				else:
					unroomed_plot_cells += 1
					erodible_rock_candidates[fine] = &"unroomed_plot"
				cells.append(fine)
	# A whole 3 m source column is the visual unit the player reads as a
	# "one-by-one rock cube". Repeatedly release a top course made entirely of
	# unclassified retained rock when it touches no other occupied column at that
	# height. The operation is a heightfield erosion over the candidate set: a
	# lower neighbour automatically becomes the stopping datum, while building,
	# route, feature, roof and bearing cells are never candidates and can only
	# protect a course. No seed, coordinate, or target count enters the rule.
	var crown_trim := _release_singleton_unclassified_rock_crowns(grid, cells,
		erodible_rock_candidates)
	cells = crown_trim.cells as Array[Vector3i]
	rock_cells -= int(crown_trim.released_derived_cells)
	unroomed_plot_cells -= int(crown_trim.released_unroomed_plot_cells)
	roof_cells -= int(crown_trim.released_roof_band_cells)
	var released_singleton_crown_cells := int(crown_trim.released_cells)
	var released_singleton_derived_rock_cells := int(
		crown_trim.released_derived_cells)
	var released_singleton_unroomed_plot_cells := int(
		crown_trim.released_unroomed_plot_cells)
	var released_singleton_roof_band_cells := int(
		crown_trim.released_roof_band_cells)
	var remaining_singleton_crowns := int(crown_trim.remaining_crowns)
	if cells.is_empty():
		return {"failed": false, "cells": 0, "skipped": skipped,
			"rock_cells": 0, "unroomed_plot_cells": 0, "roof_cells": 0,
			"released_parapet_cells": released_cells,
			"trimmed_unroomed_plot_cells": trimmed_cells,
			"trimmed_roof_band_cells": trimmed_roof_cells,
			"released_asset_envelope_cells": released_asset_cells,
			"released_required_roof_envelope_cells": \
				released_required_roof_cells,
			"released_required_roof_derived_cells": \
				released_required_roof_derived_cells,
			"released_required_roof_unroomed_plot_cells": \
				released_required_roof_unroomed_cells,
			"released_required_roof_band_cells": \
				released_required_roof_band_cells,
			"released_singleton_crown_cells": released_singleton_crown_cells,
			"released_singleton_derived_rock_cells": \
				released_singleton_derived_rock_cells,
			"released_singleton_unroomed_plot_cells": \
				released_singleton_unroomed_plot_cells,
			"released_singleton_roof_band_cells": \
				released_singleton_roof_band_cells,
			"remaining_singleton_crown_count": remaining_singleton_crowns,
			"refused_plot_trims": int(trim.refused),
			"stranded_release_repairs": stranded}
	cells.sort_custom(_cell_less)
	if not _claim_maze_stone(grid, cells):
		return {"failed": true, "cells": 0, "skipped": skipped,
			"rock_cells": 0, "unroomed_plot_cells": 0, "roof_cells": 0,
			"released_parapet_cells": released_cells,
			"trimmed_unroomed_plot_cells": trimmed_cells,
			"trimmed_roof_band_cells": trimmed_roof_cells,
			"released_asset_envelope_cells": released_asset_cells,
			"released_required_roof_envelope_cells": \
				released_required_roof_cells,
			"released_required_roof_derived_cells": \
				released_required_roof_derived_cells,
			"released_required_roof_unroomed_plot_cells": \
				released_required_roof_unroomed_cells,
			"released_required_roof_band_cells": \
				released_required_roof_band_cells,
			"released_singleton_crown_cells": released_singleton_crown_cells,
			"released_singleton_derived_rock_cells": \
				released_singleton_derived_rock_cells,
			"released_singleton_unroomed_plot_cells": \
				released_singleton_unroomed_plot_cells,
			"released_singleton_roof_band_cells": \
				released_singleton_roof_band_cells,
			"remaining_singleton_crown_count": remaining_singleton_crowns,
			"refused_plot_trims": int(trim.refused),
			"stranded_release_repairs": stranded}
	return {"failed": false, "cells": cells.size(), "skipped": skipped,
		"rock_cells": rock_cells,
		"unroomed_plot_cells": unroomed_plot_cells, "roof_cells": roof_cells,
		"released_parapet_cells": released_cells,
		"trimmed_unroomed_plot_cells": trimmed_cells,
		"trimmed_roof_band_cells": trimmed_roof_cells,
		"released_asset_envelope_cells": released_asset_cells,
		"released_required_roof_envelope_cells": \
			released_required_roof_cells,
		"released_required_roof_derived_cells": \
			released_required_roof_derived_cells,
		"released_required_roof_unroomed_plot_cells": \
			released_required_roof_unroomed_cells,
		"released_required_roof_band_cells": \
			released_required_roof_band_cells,
		"released_singleton_crown_cells": released_singleton_crown_cells,
		"released_singleton_derived_rock_cells": \
			released_singleton_derived_rock_cells,
		"released_singleton_unroomed_plot_cells": \
			released_singleton_unroomed_plot_cells,
		"released_singleton_roof_band_cells": \
			released_singleton_roof_band_cells,
		"remaining_singleton_crown_count": remaining_singleton_crowns,
		"refused_plot_trims": int(trim.refused),
		"stranded_release_repairs": stranded}


static func _release_singleton_unclassified_rock_crowns(
		grid: WarrenSpatialGrid, candidate_cells: Array[Vector3i],
		erodible_rock: Dictionary) -> Dictionary:
	## Morphological close-down of unclassified retained crowns on the authored
	## 3 m macro lattice. A removable course is exactly four fine cells, is the
	## top of its column, and has no cardinal neighbour occupied at that band.
	## Derived hillside and plot mass which became no building participate,
	## including an unused source plot's nominal roof band: all three render as
	## the same raw stone cube. Actual rooms and typed roofs were claimed before
	## this transaction and can never enter the candidate set.
	## Removing one course can expose another, so the pass iterates to its unique
	## local fixpoint. A two-column retained-terrain ridge or any course bearing
	## occupied volume above is preserved by construction. Mere side contact with
	## a facade does not turn a lone raw cube into a terrace; it is still lowered
	## until it joins the retained terrain field beneath the building.
	var candidates: Dictionary = {}
	for cell: Vector3i in candidate_cells:
		candidates[cell] = true
	var released := 0
	var released_derived := 0
	var released_unroomed := 0
	var released_roof_band := 0
	while true:
		var macros: Dictionary = {}
		for cell_value: Variant in erodible_rock.keys():
			var cell := cell_value as Vector3i
			if not candidates.has(cell):
				continue
			var macro := Vector3i(floori(float(cell.x) * 0.5), cell.y,
				floori(float(cell.z) * 0.5))
			macros[macro] = true
		var ordered: Array[Vector3i] = []
		ordered.assign(macros.keys())
		ordered.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
			return _cell_less(b, a))
		var changed := false
		for macro: Vector3i in ordered:
			if not _erodible_macro_course_is_complete(macro, candidates,
					erodible_rock):
				continue
			if _macro_course_has_occupied_above(grid, macro, candidates):
				continue
			var joined := false
			for d: Vector2i in CARDINAL_COLUMNS:
				var neighbour := Vector3i(macro.x + d.x, macro.y,
					macro.z + d.y)
				if _macro_course_has_retained_terrain(neighbour, candidates):
					joined = true
					break
			if joined:
				continue
			for fine: Vector3i in _fine_square(macro):
				var kind := StringName(erodible_rock[fine])
				if kind == &"unroomed_plot":
					released_unroomed += 1
				elif kind == &"stone_roof":
					released_roof_band += 1
				else:
					released_derived += 1
				candidates.erase(fine)
			released += 4
			changed = true
		if not changed:
			break
	var remaining := 0
	var seen_macros: Dictionary = {}
	for cell_value: Variant in erodible_rock.keys():
		var cell := cell_value as Vector3i
		if not candidates.has(cell):
			continue
		var macro := Vector3i(floori(float(cell.x) * 0.5), cell.y,
			floori(float(cell.z) * 0.5))
		if seen_macros.has(macro):
			continue
		seen_macros[macro] = true
		if _erodible_macro_course_is_complete(macro, candidates, erodible_rock) \
				and not _macro_course_has_occupied_above(grid, macro, candidates):
			var joined := false
			for d: Vector2i in CARDINAL_COLUMNS:
				if _macro_course_has_retained_terrain(
						Vector3i(macro.x + d.x, macro.y, macro.z + d.y),
						candidates):
					joined = true
					break
			if not joined:
				remaining += 1
	var kept: Array[Vector3i] = []
	kept.assign(candidates.keys())
	kept.sort_custom(_cell_less)
	return {"cells": kept, "released_cells": released,
		"released_derived_cells": released_derived,
		"released_unroomed_plot_cells": released_unroomed,
		"released_roof_band_cells": released_roof_band,
		"remaining_crowns": remaining}


static func _erodible_macro_course_is_complete(macro: Vector3i,
		candidates: Dictionary, erodible_rock: Dictionary) -> bool:
	for fine: Vector3i in _fine_square(macro):
		if not candidates.has(fine) or not erodible_rock.has(fine):
			return false
	return true


static func _macro_course_has_occupied_above(grid: WarrenSpatialGrid,
		macro: Vector3i, candidates: Dictionary) -> bool:
	for fine: Vector3i in _fine_square(macro + Vector3i.UP):
		if candidates.has(fine):
			return true
		if grid.contains(fine) and grid.use_at(fine) in [
				WarrenSpatialGrid.Use.PRIVATE_VOLUME,
				WarrenSpatialGrid.Use.STRUCTURAL_VOLUME]:
			return true
	return false


static func _macro_course_has_retained_terrain(macro: Vector3i,
		candidates: Dictionary) -> bool:
	for fine: Vector3i in _fine_square(macro):
		if candidates.has(fine):
			return true
	return false


## TASK E4 FIX 2 -- THE TRIM'S "NO FOOTPRINT COLUMN ANSWERED" SENTINEL, and it
## is INT_MIN rather than -1 because a datum is legally NEGATIVE.
##
## Round 1 started `_maze_trimmed_plot_stone`'s per-plot datum at -1, took the
## highest with `maxi`, and skipped the plot while the answer was still below
## zero. Both halves were wrong on real ground, and wrong in the same place:
## `VillageWarrenFabricSolver._sample_ground_bands` writes each column's band as
## `ceili((surface_y - world_frame.origin.y) / VERTICAL_BAND_SIZE_M)`, so every
## column whose terrain falls below the placement's own origin hands
## `WarrenMassifBuilder` a negative base -- and `local_public_datum`'s terrain
## fallback, plus any street standing on that terrain, is negative with it.
## `maxi(-1, d)` clamped the real ground away and the `datum < 0` guard then
## disabled the trim on the whole town, exactly where the terrain is real.
##
## Nothing in the flat corpus or the sloped fixtures can reach that town (every
## `StampedGround` frame is non-negative by construction), which is why 24 towns
## and four sloped rows never saw it; `test_the_stone_trim_reads_a_datum_below
## _the_frame_origin` builds it directly.
const UNANSWERED_PLOT_DATUM := -2147483648


static func _maze_released_asset_envelope_cells(
		source: WarrenMazeSourcePlan) -> Dictionary:
	## Asset plots are coarse macro reservations used to find room for an
	## authored prefab and its measured clearance. They are not a second, solid
	## rectangular building surrounding that prefab. The exact prefab body is
	## claimed before retained stone; consequently every cell from an asset
	## plot still wearing OUTSIDE in `_retain_maze_rock` is unused reservation
	## envelope and must stay air.
	##
	## Deriving the complete source interval here keeps the rule independent of
	## any one recipe, footprint, seed, or landmark position. Cells actually
	## occupied by the prefab never reach the release branch because their grid
	## use is already PRIVATE_VOLUME; support below `floor` is deliberately not
	## in this set and remains the terrain-rooted foundation.
	var out: Dictionary = {}
	if source == null:
		return out
	for plot: Dictionary in source.plots:
		if StringName(plot.get("kind", &"")) != WarrenMazeSourcePlan.PLOT_ASSET:
			continue
		for band in range(int(plot.get("floor", 0)), int(plot.get("top", 0))):
			for column_value: Variant in plot.get("cells", []) as Array:
				var column := column_value as Vector2i
				for fine: Vector3i in _fine_square(Vector3i(column.x, band,
						column.y)):
					out[fine] = true
	return out


static func _maze_released_required_roof_envelope_cells(
		grid: WarrenSpatialGrid, buildings: Array[WarrenBuildingVolume],
		program: SettlementFabricProgram, world_seed: int) -> Dictionary:
	## Roofs are selected after retained source mass is classified, but they are
	## not optional decoration: every exposed inhabited top owns a finite closure
	## domain compiled from measured authored envelopes. Raster the union of that
	## exact domain before stone retention so a later-selected roof can never be
	## encased by source rock. This is construction authority, not a visual repair:
	## it uses the same closure records and AABB/cell intersection predicate as the
	## final fabric compiler and contains no asset, seed, or coordinate exception.
	if grid == null or program == null or buildings.is_empty():
		return {}
	var closures := WarrenSpatialFabricCompiler.required_roof_closure_options(
		grid, buildings, program, world_seed)
	var bounds: Array[AABB] = []
	for closure: Dictionary in closures:
		for option: Dictionary in closure.get("options", []) as Array[Dictionary]:
			var option_bounds := option.get("bounds", AABB()) as AABB
			if option_bounds.size.length_squared() > 0.0:
				bounds.append(option_bounds)
	return _visual_clearance_bounds_cells(bounds)


## TASK E4 FIX 1 -- THE TRIM. The user's first binding direction, applied
## rather than only measured: a plot's retained stone is cut off two storeys
## above the public floor the plot itself stands on, so the quarry block a
## composition failure leaves behind stops being a masonry cliff and becomes a
## low stump. Maze-only: every reader below is empty for a searched volume.
##
## ONE HEIGHT PER PLOT, never per cell. `trim_top = datum +
## LOW_STONE_BANDS + 1`, where `datum` is the HIGHEST
## `WarrenMazeSourcePlan.local_public_datum` any of the plot's own footprint
## columns answers at that column's `lowest_plot_floor` -- the ground the town
## really starts from there, and the street it belongs to. Highest rather than
## lowest, deliberately: a plot fronting an upper terrace may not be trimmed
## down to the street at the bottom of the hill, and the conservative reduction
## is the one that trims LESS. The `+ 1` is the ruling's own: two storeys of
## stone plus the band that caps them.
##
## TWO REFUSALS, one principle -- NOTHING MAY BE LEFT STANDING OVER RELEASED
## AIR. A plot refuses to trim, and is counted in `refused`, when either:
##
##   1. another plot stands at or above its own `top` on any footprint column
##      (releasing its head would strand that plot's mass, whether the
##      composition roomed it or retained it), or
##   2. a route floor walks on a band the release would take -- inside the
##      released span, or directly on top of it. The ruling asks for
##      `route_on_stone` and `holes[OUTSIDE]` to be RE-MEASURED, and the C5e
##      precedent is exactly this failure: releasing a flat crown's parapet
##      took away the band a tiered house's street floor stood on and left
##      walk cells over `Use.OUTSIDE`. Refusing by construction is cheaper
##      than measuring the same defect a second time, and it is the same
##      sentence as refusal 1 with "a street" in place of "a plot".
##
## `{cells: {fine cell: true}, refused: int, trimmed_plots: int}`.
##
## The datum a plot cannot answer is `UNANSWERED_PLOT_DATUM` above, never -1 --
## see there for why a real one is negative.
static func _maze_trimmed_plot_stone(source: WarrenMazeSourcePlan,
		route_floors: Array[Vector3i]) -> Dictionary:
	var out: Dictionary = {}
	var refused := 0
	var trimmed_plots := 0
	if source == null or source.massif == null:
		return {"cells": out, "refused": refused,
			"trimmed_plots": trimmed_plots}
	var walked: Dictionary = {}
	for cell: Vector3i in route_floors:
		var lane: Dictionary = walked.get(Vector2i(cell.x, cell.z), {})
		lane[cell.y] = true
		walked[Vector2i(cell.x, cell.z)] = lane
	for plot: Dictionary in source.plots:
		var top_band := int(plot["top"])
		var floor_band := int(plot["floor"])
		var footprint: Array = plot["cells"]
		var datum := UNANSWERED_PLOT_DATUM
		for cell_value: Variant in footprint:
			var column := cell_value as Vector2i
			datum = maxi(datum, source.local_public_datum(column,
				source.lowest_plot_floor(column)))
		if datum == UNANSWERED_PLOT_DATUM:
			continue
		var release_low := maxi(floor_band,
			datum + WarrenMazeSourcePlan.LOW_STONE_BANDS + 2)
		if release_low >= top_band:
			continue
		if _plot_trim_is_refused(source, plot, walked, release_low):
			refused += 1
			continue
		trimmed_plots += 1
		for band in range(release_low, top_band):
			for cell_value: Variant in footprint:
				var column := cell_value as Vector2i
				for fine: Vector3i in _fine_square(Vector3i(column.x, band,
						column.y)):
					out[fine] = true
	return {"cells": out, "refused": refused, "trimmed_plots": trimmed_plots}


static func _plot_trim_is_refused(source: WarrenMazeSourcePlan,
		plot: Dictionary, walked: Dictionary, release_low: int) -> bool:
	## The two refusals of `_maze_trimmed_plot_stone`, in that order. `walked`
	## is `{fine column: {band: true}}` over the town's route floors.
	var id := StringName(plot["id"])
	var top_band := int(plot["top"])
	for cell_value: Variant in plot["cells"] as Array:
		var column := cell_value as Vector2i
		for other: Dictionary in source.plots:
			if StringName(other["id"]) == id \
					or int(other["floor"]) < top_band \
					or not (other["cells"] as Array).has(column):
				continue
			return true
		for fine: Vector3i in _fine_square(Vector3i(column.x, 0, column.y)):
			var lane: Dictionary = walked.get(Vector2i(fine.x, fine.z), {})
			for band in range(release_low, top_band + 1):
				if lane.has(band):
					return true
	return false


static func _maze_released_parapet_cells(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan,
		route_floors: Array[Vector3i] = [] as Array[Vector3i]) -> Dictionary:
	## TASK C5e RULING 2, WIDENED BY TASK H2 -- THE WHOLE CROWN IS RELEASED TO
	## AIR WHEREVER NOTHING STANDS ON IT.
	##
	## A flat-roofed plot's crown is `[flat_roof_base_band, top)`: the first
	## band carries the authored one-band `roof.flat.*` slab the roof compiler
	## builds, and on the EVEN heights the planner produces one more band is
	## left over. Both used to end up retained STONE, and that is why every
	## crown in the C5d captures reads from above as a stone block with a
	## timber sill: the slab is INSIDE a solid course of masonry, and
	## `SettlementFabricAssembler.maze_stone_walls` caps its sky-facing
	## boundary with a rock panel laid flat.
	##
	## C5e released `[roof_base + 1, top)` on non-parents only, which left two
	## rubble populations the H2 renders are about: the slab band itself
	## (retained on every column the composition did not put a room under, and
	## even under the plank slab, because `_retain_maze_rock` claims any solid
	## `OUTSIDE` cell), and the WHOLE plate of every stack parent
	## (`_maze_flat_slab_cells` claimed it before composition, so this function
	## could not reach it at all). Measured on the six-town identity corpus,
	## 9 to 58 stone caps per town stood inside a plot's own roof band span.
	##
	## THE RULE IS NOW ONE SENTENCE, AND THE GRID ANSWERS IT. Walking each fine
	## column of the span from the top down, a band is KEPT as soon as
	## something the town built stands on it -- a room (`PRIVATE_VOLUME`, which
	## is how a stacked child announces itself), structure another pass already
	## claimed (`STRUCTURAL_VOLUME`: the child's own bearing course, a feature's
	## reservation), or a public floor that walks there (`route_floors`, the
	## same set the composition test measures `ROUTE_ON_STONE_FLOOR` against).
	## Everything ABOVE the highest kept band is released; everything at or
	## below it stays, so no retained cell of a crown is ever left standing
	## over released air, and the C5e CRITICAL -- a tiered house's street floor
	## losing the band it stands on -- cannot come back through the wider rule.
	##
	## Asking the GRID rather than the plot model is what makes the widening
	## safe. The plot layer knows a stack parent by name but not which of its
	## columns the child's composed rooms really occupy, nor which crowns a
	## rooftop court, a bridge deck or a market floor ended up walking; every
	## one of those is a `PRIVATE_VOLUME`, `STRUCTURAL_VOLUME` or route-floor
	## fact by the time this runs, which is after `_discard_unassigned_mass`
	## and `_derive_shell`. The plot model still owns the one question the grid
	## cannot answer yet -- see `_maze_flat_slab_cells`, which reserves the
	## child's bearing BEFORE composition so the composition can prove it.
	##
	## A STACK PARENT'S CROWN APPEARS IN THIS SET AND IS NEVER ACTUALLY
	## RELEASED, and that is worth saying rather than filtering. Its whole
	## plate is already `STRUCTURAL_VOLUME` by the time this runs
	## (`_retain_maze_slab_courses` claims it before composition), and
	## `_retain_maze_rock` only ever claims or releases cells that are still
	## `OUTSIDE` -- so a parent crown listed here is inert. Filtering it out
	## would not be free: `_repair_stranded_release` reads membership of this
	## set as "will not be stone", so removing those entries would make the
	## repair take MORE cells back. The set is left as the plain statement of
	## which crowns are free, and the grid decides what that costs.
	##
	## Nothing about the massing moves: `WarrenParcelPlan
	## .building_support_is_valid`, `WarrenBuildingParcel.top_band` and every
	## deterministic signature are untouched, so a plot's `top` remains the
	## envelope it always was while the BUILT crown stops at its plank plate.
	##
	## Empty for a searched volume, which is what keeps every reader maze-only.
	var out: Dictionary = {}
	var source := volume.mass_context.get(&"maze_source_plan") \
		as WarrenMazeSourcePlan
	if source == null or grid == null:
		return out
	var floors: Dictionary = {}
	for cell: Vector3i in route_floors:
		floors[cell] = true
	for plot: Dictionary in source.plots:
		if StringName(plot["kind"]) != WarrenMazeSourcePlan.PLOT_HOUSE \
				or not WarrenMazeBlockPartitioner.plot_is_flat_roofed(source,
					plot):
			continue
		var top_band := int(plot["top"])
		var roof_base := WarrenBuildingParcel.flat_roof_base_band(
			int(plot["floor"]), top_band)
		if roof_base >= top_band:
			continue
		for cell_value: Variant in plot["cells"] as Array:
			var column := cell_value as Vector2i
			for fine_column: Vector3i in _fine_square(Vector3i(column.x,
					top_band - 1, column.y)):
				for band in range(top_band - 1, roof_base - 1, -1):
					var fine := Vector3i(fine_column.x, band, fine_column.z)
					if _maze_crown_band_bears(grid, floors, fine):
						break
					out[fine] = true
	return out


static func _repair_stranded_release(grid: WarrenSpatialGrid,
		source: WarrenMazeSourcePlan, released: Dictionary,
		trim_cells: Dictionary) -> int:
	## TASK H2 -- NOTHING RETAINED MAY BE LEFT STANDING ON WHAT THIS PASS
	## RELEASED. Mutates `released`, returns how many cells it took back.
	##
	## `_maze_released_parapet_cells` walks each crown TOP DOWN and stops at
	## the first band something built stands on, so within one plot's own span
	## the release can never strand its own mass. What it cannot see is the
	## band ABOVE the span: another plot's mass sitting on this crown that the
	## composition never roomed, which `_retain_maze_rock` is about to retain
	## as stone in the very same pass. Releasing the crown under it leaves a
	## quarry block hanging in the air -- measured on the first pass of this
	## task as 12 cells on 4/compact and 24 on 3/standard, red against
	## `test_retained_stone_never_stands_over_released_air`.
	##
	## The repair is one descending walk per fine column, and descending is
	## what makes it a single pass: taking a cell back makes it stone, so the
	## cell beneath it is re-asked with that answer already in place and the
	## take-back propagates down the column by itself.
	##
	## The predicate is `_retain_maze_rock`'s own retention test, restated in
	## one place rather than inferred: solid to the source, at or above its
	## column's terrain datum, still `OUTSIDE`, not trimmed by
	## `_maze_trimmed_plot_stone`, not held by another feature. Any answer but
	## "this will be stone" leaves the release alone -- a room, a street, the
	## sky and the heightfield's own ground are all either real support or no
	## support to strand.
	##
	## FIX ROUND 1, IMPORTANT 2 -- THE TAKE-BACK IS ASKED THE SAME QUESTION IT
	## ASKS OF THE CELL ABOVE. Round 1 tested only the cell ABOVE and then
	## erased this one, which quietly assumed that un-releasing a cell makes it
	## stone. It does not: `_retain_maze_rock` claims a cell only when the SAME
	## predicate holds of the cell itself, so a take-back on a cell the trim
	## already took, on one another feature reserved, on a carved street or on
	## a band the source calls empty restored no support at all -- it only
	## moved the cell out of `released_parapet_cells` and inflated the repair
	## count with a repair that never happened. So the cell is taken back, the
	## predicate is asked of it, and it is PUT BACK when the answer is no.
	##
	## The take-back is geometry-neutral by construction either way -- a cell
	## that fails the predicate is one `_retain_maze_rock` would skip whether
	## or not it sits in `released` -- so what this fix corrects is the
	## HONESTY of the count and of the release total, and the descent below
	## still stops for the right reason: the cell stays released, the cell
	## under it therefore reads "not stone" above itself, and nothing further
	## down is taken back for a support that will not be there.
	##
	## A stone cell left over a futile take-back is a strand this pass CANNOT
	## repair, and it is measured rather than assumed away:
	## `test_retained_stone_never_stands_over_released_air` reads 0 on all four
	## planner towns and its ceiling is pinned at 0.
	if released.is_empty() or source == null or source.massif == null:
		return 0
	var bands_by_column: Dictionary = {}
	for cell_value: Variant in released.keys():
		var cell := cell_value as Vector3i
		var column := Vector2i(cell.x, cell.z)
		if not bands_by_column.has(column):
			bands_by_column[column] = [] as Array[int]
		(bands_by_column[column] as Array[int]).append(cell.y)
	var repaired := 0
	var columns: Array[Vector2i] = []
	columns.assign(bands_by_column.keys())
	columns.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x)
	for column: Vector2i in columns:
		var bands := bands_by_column[column] as Array[int]
		bands.sort()
		bands.reverse()
		for band: int in bands:
			var cell := Vector3i(column.x, band, column.y)
			if not _maze_cell_becomes_stone(grid, source, released, trim_cells,
					cell + Vector3i.UP):
				continue
			released.erase(cell)
			if not _maze_cell_becomes_stone(grid, source, released, trim_cells,
					cell):
				released[cell] = true
				continue
			repaired += 1
	return repaired


static func _maze_cell_becomes_stone(grid: WarrenSpatialGrid,
		source: WarrenMazeSourcePlan, released: Dictionary,
		trim_cells: Dictionary, cell: Vector3i) -> bool:
	## Will this fine cell be retained maze stone once this pass commits?
	## `_retain_maze_rock`'s loop condition, asked one cell at a time.
	if not grid.contains(cell) or released.has(cell) or trim_cells.has(cell):
		return false
	var use := grid.use_at(cell)
	# Stone another pass already claimed -- `_retain_maze_slab_courses`' bearing
	# course under a stacked child. It is in the retained channel too, so it
	# strands just as surely as this pass's own.
	if use == WarrenSpatialGrid.Use.STRUCTURAL_VOLUME:
		return grid.owner_name_at(cell) == MAZE_STONE_FEATURE_ID
	if use != WarrenSpatialGrid.Use.OUTSIDE \
			or _feature_bit_is_taken(grid, cell):
		return false
	var column := Vector2i(_macro_of_fine(cell.x), _macro_of_fine(cell.z))
	if not source.massif.has_column(column) \
			or cell.y < source.massif.base_at(column):
		return false
	return source.solid_at(Vector3i(column.x, cell.y, column.y))


static func _macro_of_fine(fine: int) -> int:
	## The macro coordinate a fine x or z belongs to. FLOOR division, because
	## `_fine_square` maps macro -3 onto fine -6 and -5 while GDScript's
	## `-5 / 2` truncates to -2.
	return (fine - posmod(fine, 2)) / 2


static func _maze_crown_band_bears(grid: WarrenSpatialGrid,
		floors: Dictionary, fine: Vector3i) -> bool:
	## Does anything the town BUILT stand on this crown cell?  The three
	## answers, and each is a fact rather than an inference:
	##
	## - a public floor walks the band above it (`floors`, which by then holds
	##   the bore's streets, a deck plot's paving, an open bridge deck, the
	##   market floor and the rooftop court);
	## - a room stands there (`PRIVATE_VOLUME` -- a stacked child, or any
	##   lineage the composition put on this plate);
	## - structure another pass already claimed stands there
	##   (`STRUCTURAL_VOLUME`: `_retain_maze_slab_courses`' bearing course
	##   under a stacked child, or a sealed feature's own mass).
	##
	## `OUTSIDE`, `ALLOCATABLE`, `PUBLIC_AIR` and `DAYLIGHT_AIR` above a crown
	## are all sky as far as this question goes: a street's HEADROOM is not
	## something that stands on a roof, only its floor is, and the floor is the
	## first clause.
	var above := fine + Vector3i.UP
	if floors.has(above):
		return true
	if not grid.contains(above):
		return false
	var use := grid.use_at(above)
	return use == WarrenSpatialGrid.Use.PRIVATE_VOLUME \
		or use == WarrenSpatialGrid.Use.STRUCTURAL_VOLUME


static func _maze_plot_roof_cells(volume: WarrenVolumePlan) -> Dictionary:
	## Every FINE cell of a house plot's own ROOF band span. A flat-roofed plot
	## keeps `[flat_roof_base_band, top)` -- the authored one-band `roof.flat.*`
	## unit Task C5 compiles plus, on an even height, its stone parapet course.
	## Every other house plot keeps the authored pitched reservation,
	## `[top - ROOF_RESERVATION_BANDS, top)`. Both spans are roof BY THE HEIGHT
	## CONTRACT `WarrenBuildingParcel._height_is_legal` states, so no room may
	## ever stand there and this mass must not count against the unroomed
	## share.
	##
	## House plots only: an asset plot is a prefab that carries its own crown,
	## a bridge is one storey of deck, and a deck has no height at all.
	##
	## Empty for a searched volume, which is what keeps every reader maze-only.
	var out: Dictionary = {}
	var source := volume.mass_context.get(&"maze_source_plan") \
		as WarrenMazeSourcePlan
	if source == null:
		return out
	## TASK E4 FIX 1, IMPORTANT 1: the SPAN itself moved to
	## `WarrenMazeBlockPartitioner.plot_roof_band_span`, unchanged, because the
	## stone trim below and the fabric layer's own band profile both have to
	## agree with this pass about which bands are roof by the height contract.
	## The span is empty for every non-house plot, so the kind filter that used
	## to stand here now lives inside it.
	for plot: Dictionary in source.plots:
		var span := WarrenMazeBlockPartitioner.plot_roof_band_span(source,
			plot)
		for band in range(span.x, span.y):
			for cell_value: Variant in plot["cells"] as Array:
				var column := cell_value as Vector2i
				for fine: Vector3i in _fine_square(Vector3i(column.x, band,
						column.y)):
					out[fine] = true
	return out


static func _maze_plot_mass_audit(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan) -> Dictionary:
	## TASK C5c RULING 1 -- the measurement this whole task is judged on.
	##
	## Every fine cell of every plot's own `[floor, top)` is classified exactly
	## once, so `roomed + roofed + public + unroomed == plot_cells` is an
	## identity and nothing hides in a rounding:
	##
	## - ROOMED: `PRIVATE_VOLUME` -- a room, a back room, a bridge room, a
	##   landmark body. What the town actually built.
	## - ROOFED: inside `_maze_plot_roof_cells`. Roof is not a room, and the
	##   plot model asked for it (Task C5 built these bands), so it never
	##   counts against the share.
	## - PUBLIC: a street, a deck or a daylight void the carve bored back out
	##   of the plot. The realm's, not a shortfall.
	## - FEATURE: structure some OTHER feature built inside the plot -- a
	##   market post, a link's bearing. Built, and not this pass's stone.
	## - UNBUILDABLE: mass the SOURCE itself does not offer -- a bore ran
	##   through it, or it lies below its own column's `massif.base_at`, where
	##   the heightfield draws the ground and `_retain_maze_rock` deliberately
	##   draws nothing. Exactly the complement of the retention pass's own
	##   candidate domain, which is what makes UNROOMED and the stone that pass
	##   claims the same number.
	## - UNROOMED: the residue -- the quarry block. Plot mass composition made
	##   neither room nor roof, which `_retain_maze_rock` then ships as stone.
	##
	## Empty for a searched volume.
	var out: Dictionary = {"plot_cells": 0, "roomed": 0, "roofed": 0,
		"public": 0, "feature": 0, "unbuildable": 0, "unroomed": 0,
		"share": 0.0, "unroomed_uses": {}}
	var source := volume.mass_context.get(&"maze_source_plan") \
		as WarrenMazeSourcePlan
	if source == null or source.massif == null:
		return out
	var roof := _maze_plot_roof_cells(volume)
	var plot_cells := 0
	var roomed := 0
	var roofed := 0
	var public := 0
	var feature := 0
	var unbuildable := 0
	var unroomed := 0
	var unroomed_uses: Dictionary = {}
	for cell_value: Variant in _maze_plot_mass_cells(volume).keys():
		var cell := cell_value as Vector3i
		plot_cells += 1
		var use := grid.use_at(cell) if grid.contains(cell) \
			else WarrenSpatialGrid.Use.OUTSIDE
		var macro := Vector2i(floori(float(cell.x) / 2.0),
			floori(float(cell.z) / 2.0))
		if use == WarrenSpatialGrid.Use.PRIVATE_VOLUME:
			roomed += 1
		elif use in [WarrenSpatialGrid.Use.PUBLIC_AIR,
				WarrenSpatialGrid.Use.DAYLIGHT_AIR]:
			public += 1
		elif use == WarrenSpatialGrid.Use.STRUCTURAL_VOLUME \
				and grid.owner_name_at(cell) != MAZE_STONE_FEATURE_ID:
			feature += 1
		elif roof.has(cell):
			roofed += 1
		elif not grid.contains(cell) \
				or cell.y < source.massif.base_at(macro) \
				or not source.solid_at(Vector3i(macro.x, cell.y, macro.y)):
			unbuildable += 1
		else:
			unroomed += 1
			# Which USE the residue wears. Every cell here should be the
			# retained stone `_retain_maze_rock` claimed OR one of the two
			# things that pass releases instead: a cell whose FEATURE bit
			# another owner already held
			# (`maze_retained_rock_skipped_reserved`), and -- since task E4
			# fix 1 -- a cell the stone TRIM cut off two storeys above the
			# plot's own public floor
			# (`maze_trimmed_unroomed_plot_stone_cells`). Both wear
			# `Use.OUTSIDE` here, so this histogram no longer reads as
			# "STRUCTURAL_VOLUME or a bug"; naming the use is still cheaper
			# than guessing at it later, and the retention identity in
			# `test_warren_maze_composition` is what holds the three terms to
			# their sum.
			unroomed_uses[use] = int(unroomed_uses.get(use, 0)) + 1
	out["plot_cells"] = plot_cells
	out["roomed"] = roomed
	out["roofed"] = roofed
	out["public"] = public
	out["feature"] = feature
	out["unbuildable"] = unbuildable
	out["unroomed"] = unroomed
	out["unroomed_uses"] = unroomed_uses
	out["share"] = float(unroomed) / float(maxi(1, plot_cells))
	return out


static func _feature_bit_is_taken(grid: WarrenSpatialGrid,
		cell: Vector3i) -> bool:
	## Does some OTHER owner already hold this cell's non-shareable FEATURE
	## reservation bit?
	##
	## Retained stone is the only claim in this pipeline that sweeps a whole
	## volume rather than placing one authored shape, so it is the only one
	## that can meet a reservation somebody else made for a cell they never
	## assigned a use to -- `WarrenSpatialFeatureSolver`'s elevated-court
	## protection is exactly that, and `_discard_unassigned_mass` then turns
	## those cells OUTSIDE, straight into this pass's candidate set. Reserving
	## one of them fails the whole grid transaction, which would kill the town
	## for a cell nobody was going to see. Skipping it is the answer, and it is
	## COUNTED (`maze_retained_rock_skipped_reserved`) rather than silent.
	return (grid.reservation_bits_at(cell)
		& WarrenSpatialGrid.Reservation.FEATURE) != 0 \
		and not grid.reservation_owned_by(cell,
			WarrenSpatialGrid.Reservation.FEATURE, MAZE_STONE_FEATURE_ID)


static func _claim_maze_stone(grid: WarrenSpatialGrid,
		cells: Array[Vector3i]) -> bool:
	## One transaction claims the use AND the reservation together, so a cell
	## is never ours-by-use and unreserved: the sealed plan requires every
	## STRUCTURAL_VOLUME cell to name a feature that really reserved it, and
	## reserving in a second pass would leave a window in which another feature
	## could take the bit out from under a cell we already own.
	var retain := grid.begin_transaction(MAZE_STONE_FEATURE_ID)
	if not retain.assign_use(cells, WarrenSpatialGrid.Use.STRUCTURAL_VOLUME,
			MAZE_STONE_FEATURE_ID) \
			or not retain.reserve(cells,
				WarrenSpatialGrid.Reservation.FEATURE,
				MAZE_STONE_FEATURE_ID) \
			or not retain.commit():
		last_failure = "could not retain maze stone: %s" % retain.last_rejection
		return false
	return true


static func _maze_stone_reservation(grid: WarrenSpatialGrid,
		supports: WarrenSupportGraph) -> Dictionary:
	## One sealed reservation over every retained stone cell, which is what
	## lets `WarrenSpatialPlan.seal` accept them as STRUCTURAL_VOLUME. The two
	## retention passes already hold the FEATURE bit on every cell here (see
	## `_claim_maze_stone`), so this only gathers and seals.
	##
	## Returns `{feature, failed}`: a town that retained NOTHING is
	## `{null, false}`, which is a legitimate answer and not a failure.
	var cells: Array[Vector3i] = []
	for cell: Vector3i in grid.cells_with_use(
			WarrenSpatialGrid.Use.STRUCTURAL_VOLUME):
		if grid.owner_name_at(cell) == MAZE_STONE_FEATURE_ID:
			cells.append(cell)
	if cells.is_empty():
		return {"feature": null, "failed": false}
	var feature := WarrenFeatureReservation.new(MAZE_STONE_FEATURE_ID,
		&"maze_retained_stone")
	if not feature.add_reserved_cells(cells) or not feature.seal(grid,
			supports):
		last_failure = "retained maze stone did not seal: %s" \
			% feature.last_rejection
		return {"feature": null, "failed": true}
	return {"feature": feature, "failed": false}


static func _maze_deck_floor_cells(volume: WarrenVolumePlan) -> Dictionary:
	## Every FINE cell a deck plot's own floor band covers, as a set. A deck
	## has no height (`top == floor`), so this one band is the whole of it.
	## Empty for a searched volume, which is what keeps every reader of it
	## maze-only.
	var out: Dictionary = {}
	var source := volume.mass_context.get(&"maze_source_plan") \
		as WarrenMazeSourcePlan
	if source == null:
		return out
	for plot: Dictionary in source.plots:
		if StringName(plot["kind"]) != WarrenMazeSourcePlan.PLOT_DECK:
			continue
		var band := int(plot["floor"])
		for cell_value: Variant in plot["cells"] as Array:
			var column := cell_value as Vector2i
			for fine: Vector3i in _fine_square(Vector3i(column.x, band,
					column.y)):
				out[fine] = true
	return out


static func _maze_open_bridge_flanks(source: WarrenMazeSourcePlan,
		span: Array[Vector2i], floor_band: int) -> Dictionary:
	## The columns beside a bridge span that present a FLAT WALKABLE SURFACE at
	## the span's own floor band -- a flat-roofed house whose `top_band` IS that
	## band (its slab is the roof the walkway continues across) or a deck plot
	## paved at it -- and whether two of them face each other.
	##
	## `{columns: int, sides: int, opposite: bool}`.
	##
	## OPPOSITE SIDES, not merely two columns. Two flat columns on the SAME
	## side of a span are one roof, and a walkway needs a roof at each end.
	## `WarrenExcavation.seal` derives a bridge's flanks the same way -- the
	## span's own cells run ALONG the passage it covers, so the flanks are the
	## perpendicular pair -- and a one-column span, having no axis of its own,
	## may be crossed on either axis.
	var span_set: Dictionary = {}
	for column: Vector2i in span:
		span_set[column] = true
	var flat_by_side: Dictionary = {}
	var seen: Dictionary = {}
	for column: Vector2i in span:
		for direction: Vector2i in CARDINAL_COLUMNS:
			var neighbor := column + direction
			if span_set.has(neighbor) or seen.has(neighbor):
				continue
			if not _maze_column_is_flat_at(source, neighbor, floor_band):
				continue
			seen[neighbor] = true
			flat_by_side[direction] = int(
				flat_by_side.get(direction, 0)) + 1
	var axes: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN]
	if span.size() == 2:
		var travel := span[1] - span[0]
		axes = [Vector2i(-travel.y, travel.x)]
	var opposite := false
	for axis: Vector2i in axes:
		opposite = opposite or flat_by_side.has(axis) \
			and flat_by_side.has(-axis)
	return {"columns": seen.size(), "sides": flat_by_side.size(),
		"opposite": opposite}


static func _maze_column_is_flat_at(source: WarrenMazeSourcePlan,
		column: Vector2i, band: int) -> bool:
	for plot: Dictionary in source.plots:
		if not (plot["cells"] as Array).has(column):
			continue
		var kind := StringName(plot["kind"])
		if kind == WarrenMazeSourcePlan.PLOT_DECK:
			if int(plot["floor"]) == band:
				return true
		elif kind == WarrenMazeSourcePlan.PLOT_HOUSE \
				and int(plot["top"]) == band \
				and WarrenMazeBlockPartitioner \
					.plot_crown_carries_public_realm(source, plot):
			return true
	return false


static func _pave_open_bridge_decks(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan, records: Array,
		unstamped_ids: Dictionary) -> Dictionary:
	## Ruling 5, beside `_pave_maze_decks` because it is the same act: a span
	## nobody could stand a ROOM on, between two flat roofs at its own floor,
	## is an OPEN BRIDGE DECK -- a walkway across the rooftops rather than a
	## record released back to rock. The plot's own `[floor, top)` becomes
	## PUBLIC_AIR with a PUBLIC_FLOOR face at `floor`, exactly as a deck plot
	## does, and the retained slab at `floor - 1` stays stone.
	##
	## Returns `{failed, paved_ids, floor_cells}`. A span whose mass is no
	## longer free, or whose flanks are not both flat, is left to its release.
	var out := {"failed": false, "paved_ids": {} as Dictionary,
		"flanks": {} as Dictionary,
		"floor_cells": [] as Array[Vector3i]}
	var source := volume.mass_context.get(&"maze_source_plan") \
		as WarrenMazeSourcePlan
	if source == null or records.is_empty() or unstamped_ids.is_empty():
		return out
	var floors: Array[Vector3i] = []
	var air: Array[Vector3i] = []
	var paved: Dictionary = {}
	for record_value: Variant in records:
		var record := record_value as Dictionary
		var id := StringName(record["id"])
		if not unstamped_ids.has(id):
			continue
		var columns: Array[Vector2i] = []
		columns.assign(record["cells"] as Array)
		var floor_band := int(record["floor"])
		var flanks := _maze_open_bridge_flanks(source, columns, floor_band)
		(out["flanks"] as Dictionary)[id] = flanks
		if not bool(flanks.opposite):
			continue
		var record_floors: Array[Vector3i] = []
		var record_air: Array[Vector3i] = []
		var free := true
		for column: Vector2i in columns:
			for band in range(floor_band, int(record["top"])):
				for fine: Vector3i in _fine_square(Vector3i(column.x, band,
						column.y)):
					if not grid.contains(fine) or grid.use_at(fine) \
							!= WarrenSpatialGrid.Use.ALLOCATABLE:
						free = false
						break
					record_air.append(fine)
					if band == floor_band:
						record_floors.append(fine)
				if not free:
					break
			if not free:
				break
		if not free:
			continue
		paved[id] = true
		floors.append_array(record_floors)
		air.append_array(record_air)
	if paved.is_empty():
		return out
	var carve := grid.begin_transaction(&"public.maze_bridge_deck")
	if not carve.require_use(air,
			[WarrenSpatialGrid.Use.ALLOCATABLE] as Array[int]) \
			or not carve.reserve(air,
				WarrenSpatialGrid.Reservation.PUBLIC_CLEARANCE,
				&"public.maze_bridge_deck") \
			or not carve.assign_use(air, WarrenSpatialGrid.Use.PUBLIC_AIR,
				&"public.maze_bridge_deck"):
		last_failure = "could not stage open bridge deck carve"
		out["failed"] = true
		return out
	for floor_cell: Vector3i in floors:
		if not carve.claim_face(floor_cell, Vector3i.DOWN,
				WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR,
				&"public.maze_bridge_deck"):
			last_failure = "could not stage open bridge deck floor"
			out["failed"] = true
			return out
	if not carve.commit():
		last_failure = "open bridge deck carve rejected: %s" \
			% carve.last_rejection
		out["failed"] = true
		return out
	floors.sort_custom(_cell_less)
	out["paved_ids"] = paved
	out["floor_cells"] = floors
	return out


static func _partition_rooms(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan, parcels: WarrenParcelPlan,
		construction_program: SettlementFabricProgram,
		enable_paired_registration_relief: bool = true) -> Dictionary:
	# Breadcrumb: several stages below call helpers that reset last_failure on
	# entry, so a real rejection reason could be cleared before it reached the
	# caller and surfaced as a bare "no result". Any path that returns {} without
	# writing its own reason now carries this instead of nothing.
	last_failure = "room partition: no stage reported a reason"
	var partition_rooms_started_ms := Time.get_ticks_msec()
	var scale_profile := _scale_profile_for_volume(volume)
	if scale_profile == null:
		last_failure = "room partition has an invalid scale profile"
		return {}
	var requires_courtyard := scale_profile.requires_elevated_courtyard
	# Request the richest end of the profile's skywalk range; the sealed
	# occluder ranking may keep a reduced plan only when it proves the extra
	# link adds no distinct inhabited route coverage, and the profile minimum
	# (skywalk_range.x) still gates every accepted plan.
	# A quota the carver cannot yet supply must not become a constraint the
	# feature selection then fails to satisfy. Ask for zero so it commits
	# through its ORDINARY success branch — every downstream stage then sees a
	# properly committed (if empty) feature set instead of a bypassed one.
	# What the town lacks is recorded, not enforced. The profile's own
	# `skywalk_range`/`landmark_range` still ride into the shortfall record
	# below, so what the town OWED is never lost.
	var target_skywalks := 0
	var target_landmarks := 0
	var proposals: Array[Dictionary] = []
	var rejected_unfloored_addresses := 0
	# Coupling (a) of `_pave_maze_decks`: a paved deck is a legal address
	# landing, so a maze parcel can enter composition on a plaza that no bore
	# reaches. Empty in every searched mode, and counted rather than assumed.
	var deck_floors := _maze_deck_floor_cells(volume)
	var deck_addressed_parcels := 0
	# TASK C5c RULING 4. Parcel id -> the gate that dropped it, written at
	# every point a parcel can leave the composition, so a plot that composes
	# no lineage says WHY instead of vanishing. Recorded for every mode and
	# published for a maze town only, where a dropped parcel is a whole
	# building's worth of stone the town then has to carry.
	var parcel_gate_by_id: Dictionary = {}
	var parcel_gate_detail_by_id: Dictionary = {}
	for parcel: WarrenBuildingParcel in parcels.parcels:
		var proposal := WarrenParcelConstruction.proposal(parcel)
		if proposal.is_empty():
			parcel_gate_by_id[parcel.stable_id] = &"proposal_rejected"
			continue
		# Mass-first frontage includes intermediate stair/ramp macro cells. Only
		# two fine lanes inside such a square carry the actual transition surface;
		# a door aimed at either unused half opens into swept public air with no
		# floor. Reject that parcel before it can reserve hero features or enter the
		# room composition, and keep the same fact as a final room/building seal.
		if not _parcel_address_has_public_floor(grid, parcel):
			rejected_unfloored_addresses += 1
			parcel_gate_by_id[parcel.stable_id] = \
				&"rejected_unfloored_address"
			if volume.mass_context.has(&"maze_source_plan"):
				parcel_gate_detail_by_id[parcel.stable_id] = \
					_maze_unfloored_address_detail(grid, volume, parcel)
			continue
		if not deck_floors.is_empty():
			deck_addressed_parcels += int(deck_floors.has(
				WarrenParcelConstruction.threshold_cell(parcel) \
					+ Vector3i(parcel.frontage_direction.x, 0,
						parcel.frontage_direction.y)))
		proposal["parcel"] = parcel
		proposals.append(proposal)
	if proposals.is_empty():
		last_failure = "parcel seed produced no complete room proposals"
		return {}
	proposals.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.stable_id) < String(b.stable_id))
	var court_floors := _courtyard_floor_cells(volume)
	var court_neighbor_cells := _courtyard_neighbor_cells(court_floors)
	var court_fixed_blocks_by_parcel: Dictionary = {}
	for proposal: Dictionary in proposals:
		var parcel := proposal.parcel as WarrenBuildingParcel
		var fixed := _proposal_court_fixed_blocks(proposal,
			court_neighbor_cells)
		if not fixed.is_empty():
			court_fixed_blocks_by_parcel[parcel.stable_id] = fixed
	# Conservative source envelopes may intentionally share authored roof seams.
	# Retain every claimant: a last-writer map made residual shift legality depend
	# on the parcel array's incidental construction order.
	var protected_owners: Dictionary = {}
	for proposal: Dictionary in proposals:
		var parcel := proposal.parcel as WarrenBuildingParcel
		for cell: Vector3i in StaggeredFabricCompiler.proposal_occupied_cells(
				proposal):
			if not protected_owners.has(cell):
				protected_owners[cell] = {}
			(protected_owners[cell] as Dictionary)[parcel.stable_id] = true
	# Source bridges reserve their body and endpoint storey before generic room
	# composition. They deliberately remain ALLOCATABLE in the grid until the
	# all-or-nothing bridge transaction stamps them, but no unrelated lineage or
	# roof may consume them in the meantime. This closes the ordering hole where
	# the lower endpoint house's optional crown occupied its own planned upper
	# bridge room and forced a structurally valid source link to release later.
	var bridge_compounds := volume.mass_context.get(&"maze_bridge_compounds", {}) \
		as Dictionary
	for compound_value: Variant in bridge_compounds.get("plans", []) as Array:
		var compound := compound_value as Dictionary
		# Use the shared skywalk-reservation namespace so every later room producer
		# (macro composition, back rooms, and residual packing) recognizes this as
		# feature clearance. A private ad-hoc owner string was seen by the first
		# solver only; back rooms then occupied the reserved eave band anyway.
		var bridge_owner := StringName("spatial.skywalk.reserve.maze_bridge.%02d" \
			% int(compound.get("span_index", 0)))
		for cell_value: Variant in (compound.get("private_cells", {}) \
				as Dictionary).keys():
			var cell := cell_value as Vector3i
			if not protected_owners.has(cell):
				protected_owners[cell] = {}
			(protected_owners[cell] as Dictionary)[bridge_owner] = true
		# The endpoint's seam-clipped gable is as structural as its room cells.
		# Reserve the raster of the measured authored envelope now, while ordinary
		# upper-room composition can still choose another legal plate. Waiting until
		# bridge stamping let an unrelated terminal roof consume this exact crown and
		# forced a source-proved bridge to disappear after the town was packed.
		for clearance_value: Variant in _maze_bridge_endpoint_roof_clearance_cells(
				grid, volume, compound, construction_program).keys():
			var clearance_cell := clearance_value as Vector3i
			if not protected_owners.has(clearance_cell):
				protected_owners[clearance_cell] = {}
			(protected_owners[clearance_cell] as Dictionary)[bridge_owner] = true
	# The room vocabulary is the primary structure. Prove that the unadorned
	# parcel mass can be decomposed into supported long/building/slim/tower stamps
	# before markets, landmark pairs, and connector beams spend their much larger
	# search budgets. Hero features may constrain a viable macro plan; they may not
	# be relied on to accidentally rescue an unsupported micro-box arrangement.
	var macro_preflight: Dictionary = {}
	if requires_courtyard:
		# The large/grand court search needs an already-sealed composition to rank
		# candidate sides. Smaller profiles have no court consumer, and the final
		# post-skywalk composition below proves the identical macro/support/roof
		# contract. Running it twice added several seconds to every compact trial
		# without changing a single accepted room.
		macro_preflight = _macro_composition_preflight(grid, volume, proposals,
			protected_owners, court_fixed_blocks_by_parcel)
		if macro_preflight.is_empty():
			last_failure = "macro room decomposition rejected before hero search: %s" \
				% WarrenRoomCompositionPlanner.last_failure
			return {}
	# The covered bazaar is town topology, not a late prop pass. Select and
	# reserve its exact canopy/posts, under-canopy public aisle, measured visual
	# envelope, and backing-room socket before generic composition blocks move.
	var market_plan := _preplan_spatial_market(grid, volume, proposals,
		construction_program, protected_owners)
	var market_candidates: Array[Dictionary] = []
	market_candidates.assign(market_plan.get("candidates", []) as Array)
	if market_candidates.is_empty():
		# TASK F1 FIX 1, finding I2. The covered bazaar is a city feature. A
		# village takes one whenever its ground street can actually hold the
		# measured canopy, aisle, and backing; when none fits, feature
		# selection runs with the market deliberately absent instead of
		# rejecting the whole town. The sentinel is non-empty so a committed
		# selection still reads as one; it is normalized back to a truly
		# absent market below.
		#
		# THIS NOW APPLIES TO EVERY PROFILE, INCLUDING ONE THAT REQUIRES THE
		# MARKET. The `requires_covered_market` rejection that used to stand
		# here was guarded on the quotas being non-advisory, which they no
		# longer are, so it could not fire; it is deleted rather than left as
		# a promise the pipeline does not keep. A required market that never
		# preplans now ships as a published `covered_market` shortfall.
		# TASK F3 owns getting the market built.
		if scale_profile.requires_covered_market:
			last_advisory_shortfalls["covered_market"] = 0
		market_candidates = [{"optional_absent": true}]
	# Select three measured straight links *before* upper composition blocks are
	# frozen. Each candidate shifts both endpoint blocks together by one fine
	# cell, creating a genuine floorplate break while preserving exact sockets.
	# Unrelated generic blocks must move around the reserved connector volume.
	# Market and skywalks are one bounded compatible feature-set search. A valid
	# bazaar in isolation may consume the only measured bridge endpoint; try the
	# finite ranked market corpus until the complete hero-feature set survives.
	var market_reservation: Dictionary = {}
	var courtyard_bridge_candidate: Dictionary = {}
	var courtyard_bridge_reservation: Dictionary = {}
	var skywalk_plan: Dictionary = {}
	var landmark_reservations: Array[Dictionary] = []
	var selected_exact_composition: Dictionary = {}
	var selected_occluder_rank: Dictionary = {}
	var realm := WarrenVolumePublicRealmAdapter.from_volume(volume)
	if realm == null:
		last_failure = "could not recover exact public air for joint hero features"
		return {}
	var public_air := realm.air_claims()
	var selected_court_alternatives: Array[Dictionary] = []
	var selected_market_landmark_owners: Dictionary = {}
	var maze_asset_outcomes: Array[Dictionary] = []
	# One pass, no search. The plot planner already decided this town's
	# features, so there is nothing left to choose: `_maze_feature_pass` fills
	# exactly the locals the retired four-loop market/court/landmark/skywalk
	# beam used to commit, and control rejoins the shared code below it.
	var maze_features := _maze_feature_pass(grid, volume, parcels,
		proposals, construction_program, protected_owners,
		court_fixed_blocks_by_parcel, public_air, market_candidates,
		enable_paired_registration_relief)
	market_reservation = maze_features.market_reservation as Dictionary
	courtyard_bridge_candidate = \
		maze_features.courtyard_bridge_candidate as Dictionary
	courtyard_bridge_reservation = \
		maze_features.courtyard_bridge_reservation as Dictionary
	skywalk_plan = maze_features.skywalk_plan as Dictionary
	landmark_reservations.assign(
		maze_features.landmark_reservations as Array)
	selected_exact_composition = \
		maze_features.selected_exact_composition as Dictionary
	selected_occluder_rank = \
		maze_features.selected_occluder_rank as Dictionary
	selected_court_alternatives.assign(
		maze_features.selected_court_alternatives as Array)
	selected_market_landmark_owners = \
		maze_features.selected_market_landmark_owners as Dictionary
	maze_asset_outcomes.assign(maze_features.asset_outcomes as Array)
	_stamp_maze_stage(volume, &"hero_beam", partition_rooms_started_ms)
	var skywalk_reservations: Array[Dictionary] = []
	skywalk_reservations.assign(skywalk_plan.get("reservations", []) as Array)
	# TASK F1 FIX 1, finding I2 -- READ THIS BEFORE TRUSTING THE GATE BELOW.
	# It used to say "the market is structural, so its absence stays fatal".
	# That is NOT what this code does. `_maze_feature_pass` returns
	# `market_candidates[0]`, and that array is either real candidates or the
	# one-element absent SENTINEL, so `market_reservation` is never the empty
	# dictionary here and the rejection below is unreachable. What really
	# happens to a marketless town is the sentinel normalization twenty lines
	# down: it becomes a genuinely absent market for every downstream
	# consumer, and the town ships.
	#
	# MEASURED on the production seed (166029932451774690, compact,
	# 2026-08-25): `_preplan_spatial_market` finds 132 sockets, 40 ground
	# fits, 2 body fits, 1 aisle fit, 1 clearance fit and forms exactly ONE
	# complete canopy candidate -- which its own viability filter then drops
	# because the candidate's open horizon is 10 cells against a compact limit
	# of MAX_MARKET_OPEN_HORIZON_CELLS = 4. So no reservation is ever made:
	# market-ness stops at preplan, not at construction, and the town's
	# `advisory_shortfalls.covered_market = 0` is an honest record of that.
	# The gate is kept as a cheap invariant guard on a state nothing produces
	# today.
	#
	# TASK F3 MEMBER 3 -- CLASSIFIED HONEST, no repair made, and here is why
	# the three candidate repairs were each declined on a measurement.
	#
	# (a) The horizon cap is not miscalibrated. That 10 is exactly
	# `MARKET_SHELTER_HORIZON_LIMIT_CELLS`: the sight ray walked its whole
	# reach without meeting mass, so this candidate's aisle mouth looks
	# straight out of the hill. Over the 24-town corpus plus this settlement
	# only eleven candidates exist at all, at horizons 2, 4 (x4), 8 and 10
	# (x5); every cap from 5 to 9 leaves every town exactly as it is. The
	# constant carries the numbers.
	#
	# (b) Candidate generation is narrow, but not at the market's own filter.
	# The funnel loses towns at `_market_public_aisle`: sixteen of the 24
	# corpus towns arrive there with bodies that fit and leave with nothing,
	# and every candidate that survives it also survives
	# `_market_backing_composition_survives` -- the backing check has never
	# rejected one. Widening the aisle rule would change towns and is a design
	# question, not a defect: Phase G.
	#
	# (c) A marketless compact town is honest. `WarrenVillageScaleProfile`
	# gives compact and standard `requires_covered_market = false`; only large
	# and grand require a bazaar. Five of the 24 corpus towns do build one
	# (2/standard, 6/compact, 6/standard, 7/standard, 8/compact), so
	# market-ness is reachable rather than dead -- this settlement is one of the
	# nineteen that ship without, and it says so.
	#
	# TASK F4 corrected "and neither scale seals a single town of the 12-seed
	# corpus", which was true when it was written and is not now: large seals 3
	# of 12 and grand 1 of 12, and ALL FOUR build the bazaar their profile
	# requires. The `covered_market = 0` shortfall published at :1863 is
	# consequently still unreachable in practice at those scales -- not because
	# the market always fits, but because a large or grand town whose market
	# never preplans is rejected by `WarrenSpatialFeatureSolver.solve`'s
	# `requires_covered_market` arm before it can ship the shortfall. That
	# contradiction costs 7 of the 12 large seeds and is task F4's handoff.
	#
	# Court/landmark/skywalk counts are richness — a shortfall is recorded and
	# the town ships plainer rather than not at all.
	#
	# TASK F4 FIX 1. `courtyard_bridge_reservation.is_empty()` was the wrong test
	# and always had been. `_maze_dressed_court_candidate` stamps the courtyard
	# feature id onto EVERY court reservation, the absent sentinel included, so
	# the absent record is never empty and every sealed town in the corpus
	# published `hero_courtyard_bridges = 1` next to its own
	# `courtyard_bridges = 0` — the two keys are the same fact from two emitters
	# and they disagreed. The predicate below is the one the feature solver's
	# bridge-house reservation uses: a court the beam really selected has exactly
	# one owner parcel, the sentinel has none.
	#
	# This changes ONE advisory integer, 1 -> 0, in the audit of every town that
	# has no court, which today is all of them. It also makes the first term of
	# `short_hero_features` live for the first time — with no consequence, and
	# that is measured rather than argued: `skywalks` is 0 against a profile
	# minimum of 1..3 on all 24 corpus towns, so the disjunction was already true
	# everywhere by its third term and stays true. The identity probe over all 24
	# records is what proves the diff is that one integer and nothing else.
	var has_courtyard_bridge := not (courtyard_bridge_reservation.get(
		"owner_parcel_ids", []) as Array).is_empty()
	var short_hero_features := not has_courtyard_bridge \
		or landmark_reservations.size() < target_landmarks \
		or skywalk_reservations.size() < scale_profile.skywalk_range.x
	if market_reservation.is_empty():
		last_failure = ("one-pass feature selection produced no market " \
			+ "(court=%d, %d landmarks, %d skywalks; %s; %s)") \
			% [int(has_courtyard_bridge),
				landmark_reservations.size(), skywalk_reservations.size(),
				last_preplan_landmark_diagnostic,
				last_preplan_skywalk_diagnostic]
		return {}
	if short_hero_features:
		last_advisory_shortfalls["hero_courtyard_bridges"] = int(
			has_courtyard_bridge)
		last_advisory_shortfalls["hero_landmarks"] = \
			landmark_reservations.size()
		last_advisory_shortfalls["hero_landmarks_target"] = target_landmarks
		last_advisory_shortfalls["hero_skywalks"] = skywalk_reservations.size()
		last_advisory_shortfalls["hero_skywalks_target"] = \
			scale_profile.skywalk_range.x
	# A committed absent-market sentinel becomes a genuinely absent market for
	# every downstream consumer (composition, features, audits) — mirroring
	# how optional-absent courts already flow through this beam.
	if bool(market_reservation.get("optional_absent", false)):
		market_reservation = {}
	# Landmark and three-skywalk selection is the expensive part of this beam.
	# Keep that complete feature set fixed while trying the tiny court frontier
	# against the *final* room grammar it induces. A failed cantilever may be
	# swapped without regenerating paths, landmarks, or connector triples.
	var ordered_court_alternatives: Array[Dictionary] = [
		courtyard_bridge_candidate]
	var selected_court_key := _skywalk_construction_key(
		courtyard_bridge_reservation)
	for raw_alternative: Dictionary in selected_court_alternatives:
		var raw_reservation := raw_alternative.reservation as Dictionary
		if _skywalk_construction_key(raw_reservation) == selected_court_key:
			continue
		ordered_court_alternatives.append(raw_alternative)
	var exact_court_attempt_count := 0
	var exact_court_rejection_count := 0
	var exact_court_selected := false
	var selected_skywalk_candidates := skywalk_plan.get(
		"selected_candidates", []) as Array
	for raw_alternative: Dictionary in ordered_court_alternatives:
		var alternative := raw_alternative.duplicate(true)
		var alternative_reservation := (raw_alternative.reservation \
			as Dictionary).duplicate(true)
		alternative_reservation["feature_id"] = COURTYARD_BRIDGE_FEATURE_ID
		alternative["reservation"] = alternative_reservation
		var is_selected_court := _skywalk_construction_key(
			alternative_reservation) == selected_court_key
		if not is_selected_court and not _skywalk_clearance_fits_protected(
				alternative.clearance as Dictionary,
				selected_market_landmark_owners):
			continue
		var compatible := true
		if not is_selected_court:
			for skywalk_value: Variant in selected_skywalk_candidates:
				if not _skywalk_candidates_compatible(alternative,
						skywalk_value as Dictionary):
					compatible = false
					break
		if not compatible:
			continue
		exact_court_attempt_count += 1
		var exact_started := Time.get_ticks_msec()
		var exact_court_result: Dictionary = {}
		# Room shells and their finite roof domains are construction invariants,
		# not large-town courtyard policy.  Compact/standard profiles used to skip
		# this transaction because they do not require a court, which allowed an
		# otherwise optional one-cell house to survive under retained plot mass and
		# reach the final modular-box audit without a roof.  Run the same exact
		# feature/room/roof preflight for every scale; a selected composition may be
		# reused only when that very state already came through this transaction.
		var exact_fit := is_selected_court \
			and not selected_exact_composition.is_empty()
		if not exact_fit:
			exact_fit = _court_candidate_preserves_exact_room_envelopes(
				grid, volume, proposals, construction_program, market_reservation,
				alternative, selected_market_landmark_owners,
				court_fixed_blocks_by_parcel, skywalk_plan,
				enable_paired_registration_relief, exact_court_result)
		if diagnostic_trace_skywalk_timing:
			print("SKYWALK_TIMING final_court_envelope attempt=",
				exact_court_attempt_count, " fit=", exact_fit, " ms=",
				Time.get_ticks_msec() - exact_started,
				" room_failure=", WarrenRoomCompositionPlanner.last_failure,
				" exact_failure=", last_preplan_market_diagnostic.get(
					"last_exact_room_pair_failure", ""))
		if not exact_fit:
			exact_court_rejection_count += 1
			continue
		courtyard_bridge_candidate = alternative
		courtyard_bridge_reservation = alternative_reservation
		if exact_court_result.has("composition") and not bool(
				exact_court_result.get("recomposition_required", false)):
			selected_exact_composition = exact_court_result.composition \
				as Dictionary
		elif not exact_court_result.is_empty():
			selected_exact_composition = {}
		exact_court_selected = true
		break
	last_preplan_market_diagnostic["exact_court_attempt_count"] = \
		exact_court_attempt_count
	last_preplan_market_diagnostic["exact_court_rejection_count"] = \
		exact_court_rejection_count
	if not exact_court_selected:
		last_failure = ("no court cantilever clears the final authored room " \
			+ "envelopes: %s") % JSON.stringify(
				last_preplan_market_diagnostic.get(
					"last_exact_court_required_conflict", {}))
		return {}
	protected_owners = _protected_owners_with_courtyard_bridge(
		selected_market_landmark_owners, courtyard_bridge_candidate)
	# These feature envelopes are fixed by the joint preflight above. Commit them
	# before room composition so the exact solver searches the real residual 3D
	# mass instead of a much larger proxy volume. `protected_owners` remains the
	# lineage-level exception map, while the grid is the authoritative occupancy.
	if not market_reservation.is_empty() \
			and not _reserve_market_preplan(grid, market_reservation):
		last_failure = "covered-market reservation changed before joint commit: %s" \
			% grid.last_rejection
		return {}
	_annotate_landmark_skywalk_connections(landmark_reservations,
		skywalk_reservations)
	if not _reserve_landmark_preplans(grid, landmark_reservations):
		last_failure = "prefab-landmark reservation changed before joint commit: %s" \
			% grid.last_rejection
		return {}
	last_preplan_market_diagnostic["selected"] = {
		"parcel": market_reservation.get("backing_parcel_id", &""),
		"origin": market_reservation.get("origin", Vector3i.ZERO),
		"yaw": market_reservation.get("yaw_quarters", 0),
		"recipe": market_reservation.get("recipe_id", &""),
		"open_horizon_max_cells": int(market_reservation.get(
			"open_horizon_max_cells", -1)),
		"open_horizon_total_cells": int(market_reservation.get(
			"open_horizon_total_cells", -1)),
		"core_radius_squared": float(market_reservation.get(
			"core_radius_squared", -1.0))}
	var market_feature_id := StringName(market_reservation.get("feature_id",
		&""))
	# Selected hero-feature endpoint blocks outrank generic room proposals. Make
	# that priority explicit in the provisional-owner field so every displaced
	# parcel either finds another legal block offset or drops transactionally.
	for cell_value: Variant in (skywalk_plan.priority_cells as Dictionary).keys():
		# Reservations from independent topology features compose as a union. A
		# last-writer assignment here erased an earlier source-bridge envelope when
		# a searched hero connector happened to prioritize the same cell, allowing
		# ordinary roof mass back into geometry already promised to the bridge.
		if not protected_owners.has(cell_value):
			protected_owners[cell_value] = {}
		(protected_owners[cell_value] as Dictionary)[StringName(
			(skywalk_plan.priority_cells as Dictionary)[cell_value])] = true
	for reservation_index in skywalk_reservations.size():
		var reservation := skywalk_reservations[reservation_index]
		var reservation_owner := StringName("spatial.skywalk.reserve.%02d" \
			% reservation_index)
		var body := reservation.reserved_cells as Dictionary
		for cell_value: Variant in body.keys():
			var cell := cell_value as Vector3i
			if not protected_owners.has(cell):
				protected_owners[cell] = {}
			(protected_owners[cell] as Dictionary)[reservation_owner] = true
		var allowed_endpoint_owners := _skywalk_endpoint_owner_set(reservation)
		for cell_value: Variant in (reservation.get("visual_clearance_cells", {}) \
				as Dictionary).keys():
			if body.has(cell_value):
				continue
			if not protected_owners.has(cell_value):
				protected_owners[cell_value] = {}
			(protected_owners[cell_value] as Dictionary)[reservation_owner] = \
				allowed_endpoint_owners
	var forced_offsets_by_parcel := (skywalk_plan.forced_offsets \
		as Dictionary).duplicate(true)
	for parcel_value: Variant in (courtyard_bridge_candidate.forced_offsets \
			as Dictionary).keys():
		var parcel_id := StringName(parcel_value)
		if not forced_offsets_by_parcel.has(parcel_id):
			forced_offsets_by_parcel[parcel_id] = {}
		for block_value: Variant in ((courtyard_bridge_candidate.forced_offsets \
				as Dictionary)[parcel_id] as Dictionary).keys():
			var block := int(block_value)
			var wanted := ((courtyard_bridge_candidate.forced_offsets as Dictionary)[
				parcel_id] as Dictionary)[block_value] as Vector2i
			var existing := (forced_offsets_by_parcel[parcel_id] \
				as Dictionary).get(block, wanted) as Vector2i
			if existing != wanted:
				last_failure = "courtyard bridge and skywalk force incompatible block %s/%d" \
					% [parcel_id, block]
				return {}
			(forced_offsets_by_parcel[parcel_id] as Dictionary)[block] = wanted
	# First solve every exact interface block against the unchanged residual
	# mass. The volumetric composition planner then re-partitions only those
	# upper bands that are not doors, court edges, market sockets, or skywalk
	# endpoints. This separates immutable topology from mutable construction
	# form and prevents proposal iteration order from deciding who survives.
	var room_composition_started_ms := Time.get_ticks_msec()
	var solved_offsets_by_parcel: Dictionary = {}
	var exact_forced_offsets_by_parcel: Dictionary = {}
	var court_displaced_parcels: Dictionary = {}
	for parcel_value: Variant in courtyard_bridge_candidate.get(
			"excluded_parcel_ids", []):
		court_displaced_parcels[StringName(parcel_value)] = true
	for proposal: Dictionary in proposals:
		var parcel := proposal.parcel as WarrenBuildingParcel
		# The exact room-pair preflight removes only a complete optional parcel.
		# Honor that sealed disposition when rebuilding the final composition;
		# merely counting it in the audit would recreate the collision that the
		# preflight explicitly resolved.
		if court_displaced_parcels.has(parcel.stable_id):
			parcel_gate_by_id[parcel.stable_id] = &"court_displaced"
			continue
		var storeys := int(proposal.storeys)
		var origin := proposal.origin as Vector3i
		var base_plate := _proposal_base_plate(proposal)
		if storeys <= 0 or base_plate.is_empty():
			parcel_gate_by_id[parcel.stable_id] = &"proposal_has_no_storeys"
			continue
		var threshold := WarrenParcelConstruction.threshold_cell(parcel)
		var addressed_storey := clampi(floori(float(threshold.y - origin.y) \
			/ float(WarrenSpatialGrid.STOREY_CELLS)), 0, storeys - 1)
		var forced_offsets: Dictionary = {0: Vector2i.ZERO,
			floori(float(addressed_storey) / 2.0): Vector2i.ZERO}
		if not _force_market_backing_offset(forced_offsets,
				market_reservation, parcel.stable_id, origin.y, storeys):
			parcel_gate_by_id[parcel.stable_id] = \
				&"market_backing_offset_conflict"
			continue
		for court_block_value: Variant in (court_fixed_blocks_by_parcel.get(
				parcel.stable_id, {}) as Dictionary).keys():
			forced_offsets[int(court_block_value)] = Vector2i.ZERO
		for block_value: Variant in (forced_offsets_by_parcel.get(
				parcel.stable_id, {}) as Dictionary).keys():
			var block := int(block_value)
			var wanted := (forced_offsets_by_parcel[parcel.stable_id] \
				as Dictionary)[block] as Vector2i
			if forced_offsets.has(block) and forced_offsets[block] != wanted:
				forced_offsets.clear()
				break
			forced_offsets[block] = wanted
		if forced_offsets.is_empty():
			parcel_gate_by_id[parcel.stable_id] = &"forced_offsets_conflict"
			continue
		var offsets := _composition_offsets(grid, base_plate, origin.y,
			storeys, protected_owners, parcel.stable_id, volume.world_seed,
			forced_offsets)
		if offsets.is_empty():
			parcel_gate_by_id[parcel.stable_id] = \
				&"exact_composition_unsolved"
			if volume.mass_context.has(&"maze_source_plan"):
				parcel_gate_detail_by_id[parcel.stable_id] = \
					_maze_exact_composition_conflict(grid, base_plate,
						origin.y, storeys, protected_owners,
						parcel.stable_id)
			continue
		solved_offsets_by_parcel[parcel.stable_id] = offsets
		exact_forced_offsets_by_parcel[parcel.stable_id] = forced_offsets
		# A solved block set is a provisional 3D reservation for the remaining
		# source passes. Without this lock, two individually legal lateral moves
		# can converge on the same residual cell even though neither overlaps the
		# original parcel envelopes. The later room grammar may merge or shrink
		# these reservations, but it starts from a non-overlapping partition.
		for cell: Vector3i in _segment_cells(base_plate, origin.y, offsets, 0,
				storeys):
			if not protected_owners.has(cell):
				protected_owners[cell] = {}
			(protected_owners[cell] as Dictionary)[parcel.stable_id] = true
	# The exact feature/room transaction can discover that an optional upper
	# room's complete bracket or arcade envelope occupies the same air as a
	# required market/court/skywalk. Add those measured room cells after the
	# coarse two-storey phase solve: WarrenRoomCompositionPlanner owns the finer
	# one-storey crown transaction and can preserve a required lower socket while
	# shortening only the optional room above it.
	for cell_value: Variant in courtyard_bridge_candidate.get(
			"room_support_exclusion_cells", []) as Array:
		var support_cell := cell_value as Vector3i
		if not protected_owners.has(support_cell):
			protected_owners[support_cell] = {}
		(protected_owners[support_cell] as Dictionary)[
			WarrenRoomCompositionPlanner.ROOM_SUPPORT_CLEARANCE_OWNER_ID] = true
	if diagnostic_trace_skywalk_timing:
		print("SKYWALK_TIMING final_composition_inputs displaced=",
			court_displaced_parcels.keys(), " solved_has_displaced=",
			_any_key_overlap(solved_offsets_by_parcel,
				court_displaced_parcels), " selected_exact=",
			not selected_exact_composition.is_empty())
	var composition := selected_exact_composition
	if composition.is_empty():
		composition = WarrenRoomCompositionPlanner.solve(grid, volume,
			proposals, solved_offsets_by_parcel, exact_forced_offsets_by_parcel,
			market_reservation, protected_owners, forced_offsets_by_parcel,
			skywalk_reservations, volume.world_seed,
			enable_paired_registration_relief)
	if diagnostic_trace_skywalk_timing:
		print("SKYWALK_TIMING final_composition_lineages displaced_present=",
			_any_key_overlap(composition.get("lineages", {}) as Dictionary,
				court_displaced_parcels), " lineage_count=",
			(composition.get("lineages", {}) as Dictionary).size())
	if composition.is_empty():
		last_failure = "3D room composition failed: %s" \
			% WarrenRoomCompositionPlanner.last_failure
		return {}
	if not WarrenRoomCompositionPlanner.lineages_are_supported(
			composition.lineages as Dictionary, grid):
		last_failure = "final 3D room composition lost structural bearing"
		return {}
	_stamp_maze_stage(volume, &"room_composition", room_composition_started_ms)
	var composed_court_side_mask := _composition_courtyard_side_mask(
		court_floors, composition, courtyard_bridge_candidate.body as Dictionary)
	var composed_court_side_count := _side_mask_count(composed_court_side_mask)
	if requires_courtyard and composed_court_side_count \
			< WarrenSpatialFeatureSolver.MIN_COURT_SIDE_COUNT:
		# TASK F4. The last HARD richness floor in the pipeline, and the one that
		# refused 14 of the 24 large/grand corpus solves — every one of them at
		# `mask=0`, which is not a court that composed too small but a town the
		# hero beam gave no court at all (that case already publishes
		# `courtyard_bridges`). A rejection here buys no other candidate:
		# one-pass generation has nothing else to try, so refusing yields no town
		# rather than a better one. The composed side count becomes the audit
		# fact a plainer town ships with, exactly as every other richness quota
		# already does, and the two counts below stay in the audit for a reader
		# who wants the shape as well as the shortfall.
		#
		# STATED PLAINLY (task F4 fix 1): this is not only the absent-court case.
		# It is also the FINAL RE-VERIFICATION of a court the beam really did
		# select, on the path where the composition had to be rebuilt after
		# selection — a real cantilever whose court the recomposition then
		# narrowed below three sides now ships with the narrowed count published
		# instead of losing the town. The SELECTION-time check is untouched and
		# still hard (`_court_candidate_preserves_exact_room_envelopes`, :4232):
		# no candidate is ever CHOSEN on fewer than three sides. Zero corpus
		# towns take this path today — all 14 refusals were `mask=0` — so the
		# relaxation is unexercised rather than merely unmeasured, and it is
		# written down here because an unexercised relaxation is exactly the kind
		# that surprises someone later.
		last_advisory_shortfalls["composed_courtyard_sides"] = \
			composed_court_side_count
		last_advisory_shortfalls["composed_courtyard_sides_target"] = \
			WarrenSpatialFeatureSolver.MIN_COURT_SIDE_COUNT
	var composition_audit := composition.audit as Dictionary
	# What became of every asset plot the one-pass source placed: a prefab
	# landmark, or a named reason it could not be one. Maze mode only; a
	# searched town has no asset plots to account for.
	if volume.mass_context.has(&"maze_source_plan"):
		composition_audit["maze_asset_outcomes"] = maze_asset_outcomes
	composition_audit["macro_preflight_deferred_to_final_count"] = int(
		not requires_courtyard)
	composition_audit["court_displaced_parcel_count"] = \
		court_displaced_parcels.size()
	composition_audit["feature_clearance_displaced_parcel_count"] = (
		courtyard_bridge_candidate.get(
			"feature_clearance_displaced_parcel_ids", []) as Array).size()
	composition_audit["room_pair_displaced_parcel_count"] = (
		courtyard_bridge_candidate.get(
			"room_pair_displaced_parcel_ids", []) as Array).size()
	composition_audit["room_support_crown_exclusion_cell_count"] = (
		courtyard_bridge_candidate.get(
			"room_support_exclusion_cells", []) as Array).size()
	composition_audit["composed_courtyard_side_mask"] = \
		composed_court_side_mask
	composition_audit["composed_courtyard_side_count"] = \
		composed_court_side_count
	composition_audit.merge(selected_occluder_rank, true)
	composition_audit["landmark_skywalk_connected_count"] = int(
		skywalk_plan.get("landmark_coverage_count", 0))
	composition_audit["landmark_skywalk_connection_ratio"] = 1.0 \
		if landmark_reservations.is_empty() else float(
			composition_audit.landmark_skywalk_connected_count) \
			/ float(landmark_reservations.size())
	# Preserve the parcelizer's exact 3D frontier-bearing seams through room
	# recomposition. The feature solver realizes them as measured construction
	# before optional facade details can spend the same clearance.
	composition_audit["perimeter_gateway_support_records"] = (
		parcels.audit.get("perimeter_gateway_support_records", []) \
		as Array).duplicate(true)
	var lineages := composition.lineages as Dictionary
	var building_id_by_block_key: Dictionary = {}
	for proposal: Dictionary in proposals:
		var source_parcel := proposal.parcel as WarrenBuildingParcel
		var source_lineage := lineages.get(source_parcel.stable_id, {}) \
			as Dictionary
		if source_lineage.is_empty():
			continue
		var source_blocks := source_lineage.blocks as Array[Dictionary]
		for segment_index in source_blocks.size():
			var source_block := source_blocks[segment_index] as Dictionary
			building_id_by_block_key["%s/%d" % [source_parcel.stable_id,
				int(source_block.source_block_index)]] = StringName(
				"spatial.%s.part%02d" % [source_parcel.stable_id, segment_index])
	var buildings: Array[WarrenBuildingVolume] = []
	var supports := WarrenSupportGraph.new()
	var required_supports: Array[StringName] = []
	var terrain_support_ids: Array[StringName] = []
	var support_edges: Array[Dictionary] = []
	var room_count := 0
	var offset_blocks := 0
	var handoffs := 0
	# TASK C5 RULING 4. The plot model already decided which houses stand on
	# rock; empty on every legacy plan, so the check below is maze-only.
	var bears_on_rock_by_parcel := parcels.audit.get(
		"maze_parcel_bears_on_rock", {}) as Dictionary
	var unrooted_bearing: Array[Dictionary] = []
	for proposal: Dictionary in proposals:
		var parcel := proposal.parcel as WarrenBuildingParcel
		var lineage := lineages.get(parcel.stable_id, {}) as Dictionary
		if lineage.is_empty():
			continue
		var blocks := lineage.blocks as Array[Dictionary]
		if blocks.is_empty():
			continue
		var origin := proposal.origin as Vector3i
		var threshold := WarrenParcelConstruction.threshold_cell(parcel)
		for block: Dictionary in blocks:
			offset_blocks += int(StringName(block.kind) \
				!= StringName(block.original_kind) \
				or block.origin != block.original_origin \
				or int(block.yaw_quarters) \
					!= int(block.original_yaw_quarters))
		handoffs += maxi(0, blocks.size() - 1)
		var segment_ids: Array[StringName] = []
		for segment_index in blocks.size():
			segment_ids.append(StringName("spatial.%s.part%02d" % [
				StringName(parcel.stable_id), segment_index]))
		var threshold_segment := -1
		var transferred_address_parent := StringName(lineage.get(
			"address_parent_lineage_id", &""))
		var transferred_address_parent_block := int(lineage.get(
			"address_parent_source_block_index", -1))
		for segment_index in blocks.size():
			var block := blocks[segment_index] as Dictionary
			if threshold.y >= origin.y + int(block.start_storey) \
					* WarrenSpatialGrid.STOREY_CELLS \
					and threshold.y < origin.y + int(block.end_storey) \
						* WarrenSpatialGrid.STOREY_CELLS:
				threshold_segment = segment_index
				break
		if threshold_segment < 0 and transferred_address_parent.is_empty():
			last_failure = "3D composition removed addressed block for %s" \
				% parcel.stable_id
			return {}
		for segment_index in blocks.size():
			var block := blocks[segment_index] as Dictionary
			var building_id := segment_ids[segment_index]
			var cells := block.cells as Array[Vector3i]
			var assign := grid.begin_transaction(building_id)
			if not assign.require_use(cells,
					[WarrenSpatialGrid.Use.ALLOCATABLE,
						WarrenSpatialGrid.Use.OUTSIDE] as Array[int]) \
					or not assign.assign_use(cells,
						WarrenSpatialGrid.Use.PRIVATE_VOLUME, building_id) \
					or not assign.commit():
				var conflict_parts := PackedStringArray()
				for conflict_cell: Vector3i in cells:
					if grid.use_at(conflict_cell) \
							!= WarrenSpatialGrid.Use.ALLOCATABLE:
						conflict_parts.append("%s=%d/%s" % [conflict_cell,
							grid.use_at(conflict_cell),
							String(grid.owner_name_at(conflict_cell))])
						if conflict_parts.size() >= 8:
							break
				last_failure = "room segment %s rejected: %s conflicts=%s" % [
					building_id, assign.last_rejection,
					",".join(conflict_parts)]
				return {}
			var building := WarrenBuildingVolume.new(building_id,
				origin.y + int(block.start_storey) \
					* WarrenSpatialGrid.STOREY_CELLS)
			if not building.add_private_cells(cells):
				last_failure = "could not assign private cells to %s" % building_id
				return {}
			for storey in range(int(block.start_storey), int(block.end_storey)):
				var room_origin := Vector3i((block.origin as Vector3i).x,
					origin.y + storey * WarrenSpatialGrid.STOREY_CELLS,
					(block.origin as Vector3i).z)
				var room_cells := WarrenRoomStamp.expected_private_cells(
					StringName(block.kind), room_origin,
					int(block.yaw_quarters))
				var addressed := threshold_segment >= 0 \
					and threshold.y >= origin.y \
					+ storey * WarrenSpatialGrid.STOREY_CELLS \
					and threshold.y < origin.y \
						+ (storey + 1) * WarrenSpatialGrid.STOREY_CELLS
				var room_door_phase := WarrenParcelConstruction \
					.address_door_phase_for_room(StringName(block.kind), room_origin,
						int(block.yaw_quarters), threshold,
						Vector3i(parcel.frontage_direction.x, 0,
							parcel.frontage_direction.y)) if addressed else 0
				if addressed and room_door_phase < 0:
					last_failure = "recomposed room %s/%d lost exact threshold %s" % [
						parcel.stable_id, storey, threshold]
					return {}
				var support_parent_parcel_id := &""
				var support_parent_storey_index := -1
				if storey == int(block.start_storey) \
						and block.has("support_parent_lineage_id"):
					support_parent_parcel_id = StringName(
						block.support_parent_lineage_id)
					support_parent_storey_index = int(
						block.support_parent_source_storey)
				var terrain_bearing := bool(block.get("retained_support", false)) \
					or storey == 0 and not block.has(
						"support_parent_lineage_id")
				if terrain_bearing and room_origin.y >= parcel.base_band \
						and bears_on_rock_by_parcel.has(parcel.stable_id) \
						and not bool(bears_on_rock_by_parcel[
							parcel.stable_id]):
					# Task C3 ruling 4's disagreement, published rather than
					# flipped. The plot says this house stands on ANOTHER PLOT,
					# and the composition rooted it in the mountain at its own
					# floor band -- so it wears a `base.rock` shell it has not
					# earned. It cannot simply be set false: an unrooted stamp
					# with no support parent does not seal, so the honest
					# answer is to name it.
					#
					# TASK C5c: THIS IS NO LONGER ZERO, and the old note here
					# ("zero once the stacked-house seam declares") was true
					# for the wrong reason. It read zero because a maze parcel
					# DESCENDED through the plot below and swallowed it, so no
					# room was ever left standing on another plot's roof. Fix 1
					# stopped that descent (`WarrenParcelConstruction
					# ._support_base_band`) and the disagreement it was hiding
					# is now visible and bounded: 3 / 4 / 1 on the three
					# sealing seeds, every one of them a plot whose seam
					# `WarrenMazeBlockPartitioner.stack_parents` could not
					# declare because its columns are covered by more than one
					# plot below (a PARTIAL stack).
					#
					# What such a house loses is its base PALETTE, not its
					# structure: `WarrenSpatialFabricCompiler
					# ._retained_foundation_cells` already refuses to lay a
					# masonry course on another house's roof. Closing it is the
					# partial-stack seam, a planner-side contract Phase E/F
					# owns. `UNROOTED_TERRAIN_BEARING_CEILING` pins the count
					# against the same derivation, so a NEW cause cannot hide
					# inside the tolerated one.
					unrooted_bearing.append({
						"parcel_id": parcel.stable_id,
						"origin": room_origin,
						"base_band": parcel.base_band})
				var room := WarrenRoomStamp.new(
					StringName("%s.room%02d" % [building_id,
						storey - int(block.start_storey)]), parcel.stable_id,
					StringName(block.kind), room_origin,
					int(block.yaw_quarters), storey, terrain_bearing,
					addressed, threshold if addressed else Vector3i(2147483647,
						2147483647, 2147483647),
					Vector3i(parcel.frontage_direction.x, 0,
						parcel.frontage_direction.y), int(proposal.roof_feature),
					support_parent_parcel_id, support_parent_storey_index,
					room_door_phase,
					# The parcel's own roof contract reaches the stamp here
					# (Task C5 ruling 1). False on every legacy proposal.
					bool(proposal.get("flat_roof", false)),
					# ... and its roof PREFERENCE beside it (Task C5d ruling
					# 2). Empty on every legacy proposal.
					StringName(proposal.get("roof_preference", &"")))
				if not room.add_private_cells(room_cells) \
						or not room.seal(grid, building_id) \
						or not building.add_room(room):
					last_failure = "could not record room stamp for %s" % building_id
					return {}
				room_count += 1
			if segment_index == threshold_segment:
				var public_cell := threshold + Vector3i(
					parcel.frontage_direction.x, 0,
					parcel.frontage_direction.y)
				if not building.add_threshold(threshold, public_cell):
					last_failure = "real threshold left room segment %s" % building_id
					return {}
			elif threshold_segment >= 0:
				var access_index := clampi(threshold_segment, 0,
					segment_ids.size() - 1)
				if not building.add_private_parent(segment_ids[access_index]):
					last_failure = "could not attach private segment %s" % building_id
					return {}
			elif segment_index == 0:
				var address_parent_key := "%s/%d" % [
					transferred_address_parent,
					transferred_address_parent_block]
				var address_parent_id := StringName(
					building_id_by_block_key.get(address_parent_key, &""))
				if address_parent_id.is_empty() \
						or not building.add_private_parent(address_parent_id):
					last_failure = "transferred address parent %s missing for %s" % [
						address_parent_key, building_id]
					return {}
			else:
				if not building.add_private_parent(segment_ids[0]):
					last_failure = "could not attach transferred private segment %s" \
						% building_id
					return {}
			for reservation_index in skywalk_reservations.size():
				var reservation := skywalk_reservations[reservation_index]
				var owner_ids := reservation.get("owner_parcel_ids", []) as Array
				var endpoints := reservation.get("owner_endpoints", []) as Array
				for endpoint_index in mini(owner_ids.size(), endpoints.size()):
					if StringName(owner_ids[endpoint_index]) != parcel.stable_id:
						continue
					var endpoint := endpoints[endpoint_index] as Dictionary
					if not building.has_private_cell(endpoint.cell as Vector3i):
						continue
					var feature_id := StringName("spatial.feature.skywalk.%02d" \
						% reservation_index)
					if not building.add_feature(feature_id):
						last_failure = "could not attach %s to %s" % [feature_id,
							building_id]
						return {}
			if StringName(market_reservation.get("backing_parcel_id", &"")) \
					== parcel.stable_id \
					and building.has_private_cell(
						market_reservation.get("backing_cell",
						Vector3i(2147483647, 2147483647, 2147483647)) as Vector3i):
				if not building.add_feature(market_feature_id):
					last_failure = "could not attach covered market to %s" % building_id
					return {}
			var court_owner_ids := courtyard_bridge_reservation.get(
				"owner_parcel_ids", []) as Array
			var court_endpoints := courtyard_bridge_reservation.get(
				"owner_endpoints", []) as Array
			for endpoint_index in mini(court_owner_ids.size(),
					court_endpoints.size()):
				if StringName(court_owner_ids[endpoint_index]) != parcel.stable_id:
					continue
				var court_endpoint := court_endpoints[endpoint_index] as Dictionary
				if building.has_private_cell(court_endpoint.cell as Vector3i) \
						and not building.add_feature(
							COURTYARD_BRIDGE_FEATURE_ID):
					last_failure = "could not attach courtyard bridge house to %s" \
						% building_id
					return {}
			if not building.seal(grid):
				last_failure = "building %s rejected: %s" % [building_id,
					building.last_rejection]
				return {}
			buildings.append(building)
			if not supports.add_node(building_id):
				last_failure = "duplicate support node %s" % building_id
				return {}
			required_supports.append(building_id)
		for segment_index in segment_ids.size():
			var block := blocks[segment_index] as Dictionary
			var parent_key := ""
			if bool(block.get("retained_support", false)):
				terrain_support_ids.append(segment_ids[segment_index])
				continue
			if block.has("support_parent_lineage_id"):
				parent_key = "%s/%d" % [StringName(
					block.support_parent_lineage_id),
					int(block.support_parent_source_block_index)]
			elif segment_index > 0:
				var lower_block := blocks[segment_index - 1] as Dictionary
				parent_key = "%s/%d" % [parcel.stable_id,
					int(lower_block.source_block_index)]
			elif int(block.source_block_index) == 0:
				terrain_support_ids.append(segment_ids[segment_index])
				continue
			var parent_id := StringName(building_id_by_block_key.get(parent_key,
				&""))
			if parent_id.is_empty():
				last_failure = "composition support parent %s missing for %s" % [
					parent_key, segment_ids[segment_index]]
				return {}
			support_edges.append({"child": segment_ids[segment_index],
				"parent": parent_id})
	# The route-frontage parcelizer deliberately owns doors and hero sockets, but
	# it covers only about 22% of the inhabited source massif on the reviewed
	# seed. Do not erase the remaining mountain wholesale. Pack a bounded set of
	# complete roofable rooms into residual allocation, requiring real terrain or
	# inhabited bearing plus a face-adjacent private access parent. These are
	# ordinary WarrenBuildingVolume records and enter the same support, shell,
	# authored-envelope, and construction transactions as frontage buildings.
	# Source-selected bridge compounds are mandatory topology. Commit their two
	# terrain-reaching endpoints and occupied span before optional back-room
	# infill can spend either the room cells or their exact roof envelopes. The
	# source proof already owns the complete endpoint/load-path contract, so a
	# bridge no longer depends on a later generic room happening to become its
	# flank. Existing primary rooms can still satisfy those sockets; otherwise
	# `_stamp_maze_bridges` constructs the sealed endpoint pair atomically.
	var bridges := _stamp_maze_bridges(grid, volume, parcels, buildings,
		supports, required_supports, terrain_support_ids, support_edges,
		protected_owners, construction_program)
	if bool(bridges.get("failed", false)):
		last_failure = "maze bridge stamping failed: %s" % last_failure
		return {}
	# Before the greedy scan: the DIRECTED infill pass. A maze town's leftover
	# plot mass is not something to discover -- the plot planner assigned it to a
	# building already -- so it is stamped from the record rather than searched
	# for. It now composes around the already-sealed bridge network.
	var back_rooms := _stamp_maze_back_rooms(grid, volume, parcels, proposals,
		buildings, supports, required_supports, terrain_support_ids,
		support_edges, protected_owners, construction_program)
	if bool(back_rooms.get("failed", false)):
		last_failure = "maze back-room stamping failed: %s" % last_failure
		return {}
	composition_audit["maze_back_room_record_count"] = int(
		back_rooms.get("record_count", 0))
	composition_audit["maze_back_room_rectangle_count"] = int(
		back_rooms.get("rectangle_count", 0))
	composition_audit["maze_back_room_building_count"] = int(
		back_rooms.get("building_count", 0))
	# RULING 3: a back room that found a street of its own, versus one reached
	# through the house in front of it.
	composition_audit["maze_back_rooms_addressed"] = int(
		back_rooms.get("addressed_count", 0))
	composition_audit["maze_back_rooms_private"] = int(
		back_rooms.get("private_count", 0))
	composition_audit["maze_back_rooms_unstamped_cells"] = (
		back_rooms.get("unstamped_cells", {}) as Dictionary).get("count", 0)
	composition_audit["maze_back_room_cell_count"] = int(
		back_rooms.get("cell_count", 0))
	composition_audit["maze_back_room_stamped_cell_count"] = int(
		back_rooms.get("stamped_cell_count", 0))
	composition_audit["maze_back_room_unstamped_cells"] = (
		back_rooms.get("unstamped_cells", {}) as Dictionary).duplicate(true)
	composition_audit["maze_back_room_refusals"] = (
		back_rooms.get("refusals", {}) as Dictionary).duplicate()
	# Ruling 5, and before the greedy scan can claim the mass: a span no room
	# could stand on, whose two flanks both present a FLAT roof at its own
	# floor, is paved as an OPEN BRIDGE DECK -- a rooftop walkway -- instead
	# of shipping as rock.
	var bridge_outcomes := (bridges.get("outcomes",
		[]) as Array).duplicate(true)
	var unstamped_bridges: Dictionary = {}
	for outcome_value: Variant in bridge_outcomes:
		var bridge_outcome := outcome_value as Dictionary
		if String(bridge_outcome.get("outcome", "")) != "stamped":
			unstamped_bridges[StringName(bridge_outcome["id"])] = true
	var open_decks := _pave_open_bridge_decks(grid, volume,
		parcels.audit.get("maze_bridges", []) as Array, unstamped_bridges)
	if bool(open_decks.get("failed", false)):
		last_failure = "maze open bridge deck paving failed: %s" % last_failure
		return {}
	var paved_bridges := open_decks.get("paved_ids", {}) as Dictionary
	for outcome_value: Variant in bridge_outcomes:
		var bridge_outcome := outcome_value as Dictionary
		var flanks := (open_decks.get("flanks", {}) as Dictionary).get(
			StringName(bridge_outcome["id"]), {}) as Dictionary
		bridge_outcome["flat_flank_columns"] = int(flanks.get("columns", -1))
		bridge_outcome["flat_flank_sides"] = int(flanks.get("sides", -1))
		if paved_bridges.has(StringName(bridge_outcome["id"])):
			bridge_outcome["outcome"] = "open_deck"
			bridge_outcome["reason"] = ""
	# Published for a maze town and only for one: a legacy plan's audit gains
	# no zeroed key it has no records behind.
	if volume.mass_context.has(&"maze_source_plan"):
		var maze_source := volume.mass_context.get(&"maze_source_plan") \
			as WarrenMazeSourcePlan
		if maze_source != null and maze_source.excavation != null:
			var bridge_ledger := maze_source.excavation.bridge_span_audit
			var source_plot_outcomes := maze_source.audit.get("plot_outcomes", {}) \
				as Dictionary
			composition_audit["maze_source_bridge_span_count"] = \
				maze_source.excavation.bridge_spans.size()
			composition_audit["maze_source_bridge_seeded_count"] = (
				bridge_ledger.get("seeded", []) as Array).size()
			composition_audit["maze_source_bridge_seeds"] = (
				bridge_ledger.get("seeded", []) as Array).duplicate(true)
			composition_audit["maze_source_bridge_refused_count"] = (
				bridge_ledger.get("refused", []) as Array).size()
			composition_audit["maze_source_bridge_refusals"] = (
				bridge_ledger.get("refused", []) as Array).duplicate(true)
			composition_audit["maze_source_bridge_plot_outcomes"] = (
				source_plot_outcomes.get(
					"bridges", []) as Array).duplicate(true)
			composition_audit["maze_asset_clearance_reservations"] = (
				source_plot_outcomes.get("asset_clearance_reservations", []) \
					as Array).duplicate(true)
			var source_asset_plots: Array[Dictionary] = []
			for source_plot_value: Variant in maze_source.plots:
				var source_plot := source_plot_value as Dictionary
				if StringName(source_plot.get("kind", &"")) \
						== WarrenMazeSourcePlan.PLOT_ASSET:
					source_asset_plots.append(source_plot.duplicate(true))
			composition_audit["maze_asset_source_plots"] = source_asset_plots
		var composed_parcels: Dictionary = {}
		for composed: WarrenBuildingVolume in buildings:
			for composed_room: WarrenRoomStamp in composed.room_records:
				composed_parcels[composed_room.source_parcel_id] = true
		var uncomposed_stacks := 0
		for child_value: Variant in (parcels.audit.get("maze_stack_parents",
				{}) as Dictionary).keys():
			uncomposed_stacks += int(not composed_parcels.has(
				StringName(child_value)))
		# A declared seam the composition never built on: the child parcel's
		# whole lineage was dropped, so the stack is a plan fact with no
		# building behind it. Published beside the declared count because
		# "declared 3" and "declared 3, built 0" are different towns.
		composition_audit["maze_uncomposed_stack_count"] = uncomposed_stacks
		# RULING 4. Every parcel that composed no lineage, with the gate that
		# dropped it. A parcel is a whole building's worth of plot mass, so an
		# uncomposed one is the single largest contribution a town can make to
		# its own quarry block; naming the gate is what lets the next pass fix
		# the fixable ones instead of guessing.
		var uncomposed_parcels: Array[Dictionary] = []
		var uncomposed_gates: Dictionary = {}
		for parcel: WarrenBuildingParcel in parcels.parcels:
			if composed_parcels.has(parcel.stable_id):
				continue
			var gate := StringName(parcel_gate_by_id.get(parcel.stable_id,
				&"structural_yielded_lineage"))
			uncomposed_parcels.append({"parcel_id": parcel.stable_id,
				"gate": gate, "floor": parcel.base_band,
				"top": parcel.top_band, "area": parcel.area_cells(),
				"detail": String(parcel_gate_detail_by_id.get(
					parcel.stable_id, ""))})
			uncomposed_gates[gate] = int(uncomposed_gates.get(gate, 0)) + 1
		uncomposed_parcels.sort_custom(func(a: Dictionary,
				b: Dictionary) -> bool:
			return String(a.parcel_id) < String(b.parcel_id))
		composition_audit["maze_uncomposed_parcels"] = uncomposed_parcels
		composition_audit["maze_uncomposed_parcel_count"] = \
			uncomposed_parcels.size()
		composition_audit["maze_uncomposed_parcel_gates"] = uncomposed_gates
		composition_audit["maze_parcel_count"] = parcels.parcels.size()
		composition_audit["maze_unrooted_terrain_bearing_count"] = \
			unrooted_bearing.size()
		composition_audit["maze_unrooted_terrain_bearing_details"] = \
			unrooted_bearing.duplicate(true)
		composition_audit["maze_deck_addressed_parcel_count"] = \
			deck_addressed_parcels
		composition_audit["maze_bridge_rooms"] = int(bridges.get("stamped", 0))
		composition_audit["maze_bridge_open_decks"] = paved_bridges.size()
		composition_audit["maze_bridge_open_deck_cell_count"] = (
			open_decks.get("floor_cells", []) as Array).size()
		composition_audit["maze_bridge_outcomes"] = bridge_outcomes
	if int(bridges.get("record_count", 0)) > 0:
		# Never a rejection: a span the flanks cannot carry ships as rock. An
		# open deck is not a shortfall -- the walkway is what the two flat
		# roofs beside it asked for -- so it leaves the count.
		last_advisory_shortfalls["bridges"] = int(bridges.get("released", 0)) \
			- paved_bridges.size()
	# Residual rooms are ordinary building shells, never feature endpoints. Give
	# their reversible packing pass the exact measured envelopes of every fixed
	# hero asset so an apparently free raster cell cannot admit a wall through a
	# landmark eave, market canopy, or occupied-link roof.
	var fixed_feature_reservations: Array[Dictionary] = []
	if not market_reservation.is_empty():
		fixed_feature_reservations.append(market_reservation)
	if not courtyard_bridge_reservation.is_empty() \
			and not bool(courtyard_bridge_reservation.get(
				"optional_absent", false)):
		fixed_feature_reservations.append(courtyard_bridge_reservation)
	fixed_feature_reservations.append_array(landmark_reservations)
	fixed_feature_reservations.append_array(skywalk_reservations)
	var feature_bounds_result := _feature_visual_bounds(
		fixed_feature_reservations, construction_program)
	if not bool(feature_bounds_result.get("valid", false)):
		last_failure = "fixed feature has no measured visual envelope"
		return {}
	var fixed_feature_bounds: Array[AABB] = []
	fixed_feature_bounds.assign(feature_bounds_result.get(
		"bounds", []) as Array)
	var residual_started_ms := Time.get_ticks_msec()
	var backfill := _backfill_residual_rooms(grid, volume, buildings, supports,
		required_supports, terrain_support_ids, support_edges, protected_owners,
		scale_profile.residual_room_budget,
		scale_profile.residual_kind_budget, construction_program,
		fixed_feature_bounds)
	_stamp_maze_stage(volume, &"residual_rooms", residual_started_ms)
	if bool(backfill.get("failed", false)):
		last_failure = "residual room backfill failed: %s" % JSON.stringify(
			backfill.get("failure", backfill))
		return {}
	composition_audit["residual_backfill_building_count"] = int(
		backfill.get("building_count", 0))
	composition_audit["residual_backfill_private_cell_count"] = int(
		backfill.get("private_cell_count", 0))
	composition_audit["residual_backfill_kind_counts"] = (
		backfill.get("kind_counts", {}) as Dictionary).duplicate()
	composition_audit["residual_backfill_overhead_route_cell_count"] = int(
		backfill.get("overhead_route_cell_count", 0))
	composition_audit["residual_backfill_frontage_side_count"] = int(
		backfill.get("frontage_side_count", 0))
	composition_audit["residual_backfill_terrain_root_count"] = int(
		backfill.get("terrain_root_count", 0))
	composition_audit["residual_backfill_massif_edge_room_count"] = int(
		backfill.get("massif_edge_room_count", 0))
	composition_audit["residual_backfill_massif_edge_contact_count"] = int(
		backfill.get("massif_edge_contact_count", 0))
	composition_audit["residual_backfill_terrain_rooted_established_access_count"] = int(
		backfill.get("terrain_rooted_established_access_count", 0))
	composition_audit["residual_backfill_bridge_counts"] = (
		backfill.get("bridge_counts", {}) as Dictionary).duplicate()
	composition_audit["preplanned_skywalk_unique_route_cover_count"] = int(
		skywalk_plan.get("unique_route_cover_count", 0))
	composition_audit["preplanned_skywalk_marginal_route_cover_count"] = int(
		skywalk_plan.get("marginal_route_cover_count", 0))
	# Every stamped back room is one WarrenRoomStamp in the sealed plan, so it
	# belongs in the same count the greedy backfill's rooms do; leaving it out
	# made `room_stamp_count` understate a maze town by its whole directed pass.
	room_count += int(back_rooms.get("building_count", 0)) \
		+ int(backfill.get("building_count", 0))
	if buildings.size() < MIN_BUILDINGS:
		last_failure = "room partition formed only %d buildings" % buildings.size()
		return {}
	for root_id: StringName in terrain_support_ids:
		if not supports.mark_terrain_root(root_id):
			last_failure = "could not root %s" % root_id
			return {}
	for edge: Dictionary in support_edges:
		if not supports.add_edge(StringName(edge.child), StringName(edge.parent)):
			last_failure = "could not support %s from %s" % [edge.child,
				edge.parent]
			return {}
	if not supports.seal(required_supports):
		last_failure = "support DAG rejected: %s" % supports.last_rejection
		return {}
	last_failure = ""
	return {"open_bridge_deck_floor_cells": open_decks.get("floor_cells",
			[] as Array[Vector3i]) as Array[Vector3i],
		"buildings": buildings, "supports": supports,
		"room_count": room_count, "offset_blocks": offset_blocks,
		"handoffs": handoffs,
		"composition_audit": composition_audit,
		"rejected_unfloored_address_count": rejected_unfloored_addresses,
		"preplanned_skywalk_count": skywalk_reservations.size(),
		"skywalk_reservations": skywalk_reservations,
		"courtyard_bridge_reservation": courtyard_bridge_reservation,
		"landmark_reservations": landmark_reservations,
		"market_reservation": market_reservation}


static func _maze_feature_pass(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan, parcels: WarrenParcelPlan,
		proposals: Array[Dictionary], program: SettlementFabricProgram,
		protected_owners: Dictionary,
		court_fixed_blocks_by_parcel: Dictionary, public_air: Dictionary,
		market_candidates: Array[Dictionary],
		enable_paired_registration_relief: bool) -> Dictionary:
	## The one-pass replacement for the joint hero-feature beam.
	##
	## A maze town's features are not something composition discovers: the plot
	## planner chose them, so there is nothing to search over and nothing a
	## richer trial could improve. Market, court, landmarks and links are
	## selected once, in that order, and every quota the source could not
	## supply becomes an entry in `last_advisory_shortfalls` rather than a
	## rejection. The dictionary returned is exactly what the beam's commit
	## writes into its own locals, so control rejoins the shared post-beam
	## code unchanged.
	##
	## Skywalks are deliberately absent here: the source's `maze_bridges` are
	## a later task's contract, and an empty link plan is an audit fact.
	var scale_profile := _scale_profile_for_volume(volume)
	# The bazaar: the first candidate of the corpus `_preplan_spatial_market`
	# already ranked. The beam retried the corpus only because a later hero
	# feature could consume the socket this one wanted; with no such feature
	# left to search for, the ranking's own first choice is the choice.
	# `_partition_rooms` owns the absent sentinel and substitutes it for an
	# empty market plan before this branch is reached, so there is exactly one
	# place a sentinel is born and the corpus here is never empty.
	assert(not market_candidates.is_empty())
	var market_reservation: Dictionary = market_candidates[0]
	if bool(market_reservation.get("optional_absent", false)):
		# Recorded whether or not the profile REQUIRES a market: a village
		# whose street could hold no measured canopy shipped without one, and
		# that is a fact about the town either way.
		last_advisory_shortfalls["covered_market"] = 0
	var market_owners := _protected_owners_with_market(protected_owners,
		market_reservation)
	var skywalk_plan: Dictionary = {
		"reservations": [] as Array[Dictionary],
		"selected_candidates": [] as Array[Dictionary],
		"forced_offsets": {}, "priority_cells": {},
		"candidate_count": 0,
	}
	# The threaded upper court is a size invariant of large and grand towns
	# only. Elsewhere the absent sentinel is the honest selection: it reserves
	# no cells, moves no rooms, and compiles no feature.
	var court := _maze_court_candidate(grid, volume, proposals, program,
		scale_profile, market_reservation, market_owners,
		court_fixed_blocks_by_parcel, public_air, skywalk_plan,
		enable_paired_registration_relief)
	var court_candidate := court.candidate as Dictionary
	var court_owners := _protected_owners_with_courtyard_bridge(market_owners,
		court_candidate)
	var assets := _maze_asset_landmarks(grid, volume, parcels, program,
		court_owners)
	var landmarks: Array[Dictionary] = []
	landmarks.assign(assets.reservations as Array)
	if int(assets.shortfall_count) > 0:
		last_advisory_shortfalls["assets"] = int(assets.shortfall_count)
	last_preplan_landmark_diagnostic = {
		"maze_asset_record_count": (assets.outcomes as Array).size(),
		"maze_asset_landmark_count": landmarks.size(),
		"maze_asset_outcomes": assets.outcomes,
	}
	last_preplan_skywalk_diagnostic = {"maze_skywalk_count": 0}
	return {
		"market_reservation": market_reservation,
		"courtyard_bridge_candidate": court_candidate,
		"courtyard_bridge_reservation": court_candidate.reservation \
			as Dictionary,
		"landmark_reservations": landmarks,
		"skywalk_plan": skywalk_plan,
		"selected_exact_composition": court.exact_composition as Dictionary,
		"selected_occluder_rank": {},
		"selected_court_alternatives": [court_candidate] as Array[Dictionary],
		"selected_market_landmark_owners": _protected_owners_with_landmarks(
			market_owners, landmarks),
		"asset_outcomes": assets.outcomes,
	}


static func _maze_court_candidate(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan, proposals: Array[Dictionary],
		program: SettlementFabricProgram,
		scale_profile: WarrenVillageScaleProfile,
		market_reservation: Dictionary, market_owners: Dictionary,
		court_fixed_blocks_by_parcel: Dictionary, public_air: Dictionary,
		skywalk_plan: Dictionary,
		enable_paired_registration_relief: bool) -> Dictionary:
	## The court half of the one-pass feature selection. Profiles without an
	## elevated-court invariant take the absent sentinel outright; the ones
	## that have it take the FIRST cantilever whose exact room envelopes
	## survive, in the order `_courtyard_cantilever_room_candidates` produced
	## them. There is no ranking loop: a court the source cannot host is a
	## shortfall, exactly like a market it cannot host.
	var absent := _maze_dressed_court_candidate(
		_absent_courtyard_bridge_candidate())
	if not scale_profile.requires_elevated_courtyard:
		return {"candidate": absent, "exact_composition": {}}
	var raw_candidates := _courtyard_cantilever_room_candidates(grid, volume,
		proposals, program, market_owners, public_air)
	for raw_candidate: Dictionary in raw_candidates:
		var candidate := _maze_dressed_court_candidate(raw_candidate)
		var exact_result: Dictionary = {}
		if not _court_candidate_preserves_exact_room_envelopes(grid, volume,
				proposals, program, market_reservation, candidate,
				market_owners, court_fixed_blocks_by_parcel, skywalk_plan,
				enable_paired_registration_relief, exact_result):
			continue
		var composition := exact_result.get("composition", {}) as Dictionary \
			if not bool(exact_result.get("recomposition_required", false)) \
			else {}
		return {"candidate": candidate, "exact_composition": composition}
	last_advisory_shortfalls["courtyard_bridges"] = 0
	return {"candidate": absent, "exact_composition": {}}


static func _maze_dressed_court_candidate(
		raw_candidate: Dictionary) -> Dictionary:
	## The beam's own two lines of court bookkeeping: a deep copy carrying its
	## own reservation, stamped with the courtyard feature id so the post-beam
	## construction key matches the one it later searches alternatives by.
	var candidate := raw_candidate.duplicate(true)
	var reservation := (raw_candidate.reservation as Dictionary).duplicate(true)
	reservation["feature_id"] = COURTYARD_BRIDGE_FEATURE_ID
	candidate["reservation"] = reservation
	return candidate


static func _maze_asset_landmarks(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan, parcels: WarrenParcelPlan,
		program: SettlementFabricProgram,
		protected_owners: Dictionary) -> Dictionary:
	## Every `maze_assets` record becomes a prefab-landmark reservation at the
	## site the planner costed for it, or a counted outcome saying why it could
	## not. An asset is never a rejection: its mass is already the plot
	## planner's, and a recipe that will not sit on it leaves that mass as the
	## derived rock it was, one landmark poorer and one audit line richer.
	##
	## Each accepted landmark joins the protected-owner map before the next
	## record is tried, which is how two assets whose measured clearance
	## envelopes overlap resolve deterministically instead of both committing.
	var reservations: Array[Dictionary] = []
	var outcomes: Array[Dictionary] = []
	var shortfall_count := 0
	var owners := protected_owners
	for record: Dictionary in parcels.audit.get("maze_assets", []) as Array:
		var attempt := _maze_asset_landmark(grid, volume, program, owners,
			record, reservations.size())
		var reservation := attempt.get("reservation", {}) as Dictionary
		outcomes.append({
			"id": StringName(record["id"]),
			"kind_id": StringName(record["kind_id"]),
			"cells": (record.get("cells", []) as Array).duplicate(),
			"floor": int(record.get("floor", 0)),
			"door_walk": record.get("door_walk", Vector3i.ZERO),
			"placed": not reservation.is_empty(),
			"reason": String(attempt.get("reason", "")),
		})
		if reservation.is_empty():
			shortfall_count += 1
			continue
		reservations.append(reservation)
		owners = _protected_owners_with_landmarks(owners,
			[reservation] as Array[Dictionary])
	return {"reservations": reservations, "outcomes": outcomes,
		"shortfall_count": shortfall_count}


static func _maze_asset_landmark(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan, program: SettlementFabricProgram,
		protected_owners: Dictionary, record: Dictionary,
		index: int) -> Dictionary:
	## One asset record against one catalog recipe at one site. This is the
	## per-candidate half of the retired landmark preplanner with the search
	## removed: there the landing, recipe and yaw are enumerated over the whole
	## town; here the plot fixes the site, the planner fixed the recipe, and
	## the door fixes the facing, so the only remaining freedom is which fine
	## lane of the 3 m street cell the doorway opens onto.
	##
	## Returns `{reservation}` on success or `{reason}` on refusal; the same
	## measured facts the searched path admits a candidate on are what refuse
	## it here, so an asset that becomes a shortfall is one the fine grid
	## genuinely could not host.
	var kind_id := StringName(record["kind_id"])
	var recipe := program.recipe(kind_id)
	if recipe == null or not recipe.has_tag(&"prefab_anchor") \
			or not recipe.has_tag(&"terrain_bearing") \
			or recipe.bearing_parent_count != 0 \
			or recipe.entrances.is_empty():
		return {"reason": "%s is not an entranced terrain-rooted anchor" \
			% kind_id}
	var frontage := _maze_asset_frontage(record)
	if frontage == Vector2i.ZERO:
		return {"reason": "no footprint column fronts the plot's own door"}
	# From the doorway into the mass: the inverse of the frontage the plot
	# addressed its street across.
	var side := Vector3i(-frontage.x, 0, -frontage.y)
	var footprint := _maze_asset_fine_footprint(record)
	var entrance := recipe.entrances[0] as Dictionary
	var yaw := _yaw_for_direction(entrance.facing as Vector3i, -side)
	if yaw < 0:
		return {"reason": "%s has no yaw that opens its entrance onto %s" \
			% [kind_id, frontage]}
	var reasons := PackedStringArray()
	for landing: Vector3i in _maze_asset_landings(record, side, footprint):
		var origin := landing + side - FabricRecipe.transform_cell(
			entrance.cell as Vector3i, Vector3i.ZERO, yaw)
		var refusal := _maze_landmark_refusal(grid, volume, program, recipe,
			protected_owners, origin, yaw, landing, side, index)
		if refusal.has("reservation"):
			return refusal
		# Every lane is reported, not just the first: which of the two fine
		# doorways a 3 m street cell offers a prefab failed on, and how, is
		# the fact a template revision needs.
		reasons.append("lane %s: %s" % [landing, refusal.reason])
	if reasons.is_empty():
		return {"reason": "the plot's door cell offers no public landing"}
	return {"reason": "; ".join(reasons)}


static func _maze_landmark_refusal(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan, program: SettlementFabricProgram,
		recipe: FabricRecipe, protected_owners: Dictionary,
		origin: Vector3i, yaw: int, landing: Vector3i, side: Vector3i,
		index: int) -> Dictionary:
	## The measured admission test, in the order the retired landmark preplanner
	## applies it, each failure naming itself. Returns `{reservation}` or
	## `{reason}`.
	var entrance_cell := landing + side
	if not grid.contains(landing):
		return {"reason": "landing %s is outside the grid" % landing}
	var floor_claim := grid.face_claim(landing, Vector3i.DOWN)
	if grid.use_at(landing) != WarrenSpatialGrid.Use.PUBLIC_AIR \
			or floor_claim.is_empty() \
			or int(floor_claim.get("kind", -1)) \
				!= WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR:
		return {"reason": "landing %s is not canonical public floor" % landing}
	if not grid.contains(entrance_cell) \
			or grid.use_at(entrance_cell) not in [
				WarrenSpatialGrid.Use.OUTSIDE,
				WarrenSpatialGrid.Use.ALLOCATABLE]:
		return {"reason": "doorway cell %s is already spoken for" \
			% entrance_cell}
	var body: Dictionary = {}
	for cells: Array[Vector3i] in [recipe.solid_cells, recipe.headroom_cells,
			recipe.walk_cells]:
		for local_cell: Vector3i in cells:
			body[FabricRecipe.transform_cell(local_cell, origin, yaw)] = true
	if body.is_empty() or not _skywalk_body_fits_grid(grid, body):
		return {"reason": "body at %s/r%d does not fit the residual mass%s" \
			% [origin, yaw, _maze_body_conflict_text(grid, body)]}
	var bearing: Dictionary = {}
	for local_cell: Vector3i in recipe.terrain_bearing_cells:
		bearing[FabricRecipe.transform_cell(local_cell, origin, yaw)] = true
	if bearing.is_empty() or not _landmark_bearing_follows_terrain(bearing,
			volume):
		return {"reason": "bearing at band %d does not follow terrain: %s" \
			% [origin.y, _landmark_bearing_failure(bearing, volume)]}
	var components: Array[Dictionary] = [{"recipe_id": recipe.recipe_id,
		"origin": origin, "yaw_quarters": yaw}]
	var clearance := _skywalk_visual_clearance_cells(components, program)
	var protected_cells := clearance.duplicate()
	protected_cells.merge(body, true)
	protected_cells.merge(bearing, true)
	if clearance.is_empty() or not _cells_fit_grid(grid, clearance) \
			or not _skywalk_clearance_fits_grid(grid, clearance) \
			or not _skywalk_clearance_fits_protected(protected_cells,
				protected_owners):
		return {"reason": ("measured clearance at %s leaves the grid or " \
			+ "meets another feature") % origin}
	# TASK C5c RULING 5, the other half of letting a prefab commit. A house's
	# AUTHORED SHELL is wider than its footprint -- native eaves overhang by a
	# fraction of a fine cell, which is why the residual scan carries a
	# one-cell `roof_eave_halo` -- so a prefab whose measured envelope stops
	# exactly at a neighbour's cells still meets that neighbour's roof in
	# `compile_room_units`, and there the verdict is the whole town rather than
	# one asset. Ask for the cell of air here instead.
	#
	# FIX 1, IMPORTANT 3: at the ROOF BAND ONLY, which is where the precedent
	# puts it. `_backfill_residual_rooms` halos `roof_clearance` cells -- the
	# band above a room -- and nothing else; halo every band of a prefab's
	# envelope and the rule stops being an eave rule and becomes a one-cell
	# setback from every wall, which refuses exactly the embedded siting
	# `_landmark_embeddedness` is asking for. Walls may meet; eaves may not.
	var envelope_top := -2147483648
	for cell_value: Variant in protected_cells.keys():
		envelope_top = maxi(envelope_top, (cell_value as Vector3i).y)
	var halo: Dictionary = {}
	for cell_value: Variant in protected_cells.keys():
		var cell := cell_value as Vector3i
		if cell.y != envelope_top:
			halo[cell] = true
			continue
		for z_offset in range(-1, 2):
			for x_offset in range(-1, 2):
				halo[cell + Vector3i(x_offset, 0, z_offset)] = true
	var blockers: Dictionary = {}
	for cell_value: Variant in halo.keys():
		for owner_value: Variant in (protected_owners.get(cell_value, {}) \
				as Dictionary).keys():
			blockers[StringName(owner_value)] = true
	if not blockers.is_empty():
		# The searched path DISPLACES the parcels a landmark overlaps. A maze
		# town may not: the plot planner already partitioned this mass and a
		# prefab is not entitled to delete a neighbour's house.
		#
		# Sorted, like every other landmark id list that reaches an audit:
		# a Dictionary's key order is cell iteration order, which would make
		# the published reason depend on where the overlap was noticed first.
		var blocker_ids: Array[StringName] = []
		blocker_ids.assign(blockers.keys())
		blocker_ids.sort_custom(func(a: StringName, b: StringName) -> bool:
			return String(a) < String(b))
		return {"reason": "clearance overlaps %d plot(s): %s" % [
			blocker_ids.size(), blocker_ids]}
	var assets := recipe.asset_ids()
	var source_family := &"unknown" if assets.is_empty() else \
		StringName(String(assets[0]).get_slice(".", 0))
	var embeddedness := _landmark_embeddedness(protected_cells,
		protected_owners, blockers, grid)
	var socket_signature := _landmark_recipe_socket_signature(recipe, origin,
		yaw)
	return {"reservation": {
		"feature_id": StringName("spatial.feature.landmark.%02d" % index),
		"recipe_id": recipe.recipe_id, "source_family": source_family,
		# RULING 5: this reservation, and only this one, lets the commit skip
		# a ROOF face the public realm already owns -- see
		# `_reserve_landmark_preplan`.
		"route_roof_is_shared": true,
		"origin": origin, "yaw_quarters": yaw, "landing_cell": landing,
		"entrance_cell": entrance_cell, "entrance_facing": -side,
		"body": body, "bearing_cells": bearing, "clearance": clearance,
		"protected_cells": protected_cells,
		"blocker_parcels": blockers, "blocker_count": blockers.size(),
		"city_contact_side_count": embeddedness.side_count,
		"city_contact_edge_count": embeddedness.edge_count,
		"city_contact_score": embeddedness.score,
		"nearest_city_gap": embeddedness.nearest_gap,
		"transition_owner_ids": embeddedness.owner_ids,
		"height_cell_count": ceili(recipe.local_clearance_bounds.size.y \
			/ FabricRecipe.CELL_SIZE),
		"skywalk_socket_signature": socket_signature,
		"structural_signature": ("%s/body=%s/protected=%s/sockets=%s" % [
			source_family, _cell_set_signature(body),
			_cell_set_signature(protected_cells),
			socket_signature]).sha256_text(),
		"footprint_area": recipe.local_clearance_bounds.size.x \
			* recipe.local_clearance_bounds.size.z,
		# The searched path breaks ranking ties with a seeded hash. Nothing
		# ranks these, so the field is present for shape and constant.
		"tie": 0,
	}}


static func _maze_body_conflict_text(grid: WarrenSpatialGrid,
		body: Dictionary) -> String:
	## The first few cells of a refused prefab body that are not free mass, so
	## an audited shortfall says WHERE the template and the recipe disagree
	## instead of only that they did.
	var parts := PackedStringArray()
	var ordered: Array[Vector3i] = []
	ordered.assign(body.keys())
	ordered.sort_custom(_cell_less)
	for cell: Vector3i in ordered:
		if grid.contains(cell) and grid.use_at(cell) in [
				WarrenSpatialGrid.Use.OUTSIDE,
				WarrenSpatialGrid.Use.ALLOCATABLE]:
			continue
		parts.append("%s=%d" % [cell, grid.use_at(cell) \
			if grid.contains(cell) else -1])
		if parts.size() >= 4:
			break
	return "" if parts.is_empty() else " at %s" % ",".join(parts)


static func _maze_asset_frontage(record: Dictionary) -> Vector2i:
	## The cardinal from the asset's own footprint toward the street cell the
	## planner addressed it across. Scanned in one fixed order so the answer is
	## a pure function of the record.
	var columns: Dictionary = {}
	for cell_value: Variant in record["cells"] as Array:
		columns[cell_value as Vector2i] = true
	var door_walk := record["door_walk"] as Vector3i
	var door_column := Vector2i(door_walk.x, door_walk.z)
	for direction: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT,
			Vector2i.UP]:
		if columns.has(door_column - direction):
			return direction
	return Vector2i.ZERO


static func _maze_asset_fine_footprint(record: Dictionary) -> Dictionary:
	## The plot's macro columns at construction resolution: four fine cells per
	## column, all at the plot's own floor band.
	var out: Dictionary = {}
	var floor_band := int(record["floor"])
	for cell_value: Variant in record["cells"] as Array:
		var column := cell_value as Vector2i
		for x_offset in 2:
			for z_offset in 2:
				out[Vector3i(column.x * 2 + x_offset, floor_band,
					column.y * 2 + z_offset)] = true
	return out


static func _maze_asset_landings(record: Dictionary, side: Vector3i,
		footprint: Dictionary) -> Array[Vector3i]:
	## The fine public lanes of the plot's own 3 m door cell that actually face
	## its footprint. A macro street cell carries two lanes across and two
	## along; only the ones whose inward neighbour is plot mass can be this
	## landmark's doorway, which leaves at most two, in sorted order.
	var door_walk := record["door_walk"] as Vector3i
	var out: Array[Vector3i] = []
	for x_offset in 2:
		for z_offset in 2:
			var landing := Vector3i(door_walk.x * 2 + x_offset, door_walk.y,
				door_walk.z * 2 + z_offset)
			if footprint.has(landing + side):
				out.append(landing)
	out.sort_custom(_cell_less)
	return out


static func _parcel_address_has_public_floor(grid: WarrenSpatialGrid,
		parcel: WarrenBuildingParcel) -> bool:
	if grid == null or parcel == null:
		return false
	var threshold := WarrenParcelConstruction.threshold_cell(parcel)
	if threshold.x == 2147483647:
		return false
	var landing := threshold + Vector3i(parcel.frontage_direction.x, 0,
		parcel.frontage_direction.y)
	var floor_claim := grid.face_claim(landing, Vector3i.DOWN)
	return grid.use_at(landing) == WarrenSpatialGrid.Use.PUBLIC_AIR \
		and not floor_claim.is_empty() \
		and int(floor_claim.get("kind", -1)) \
			== WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR


static func _landmark_embeddedness(protected_cells: Dictionary,
		protected_owners: Dictionary, blocker_parcels: Dictionary,
		grid: WarrenSpatialGrid = null) -> Dictionary:
	## Collapse the authored 3D envelope to its horizontal silhouette, then look
	## outward from every boundary face for surviving room envelopes.  Blocked
	## parcels do not count: they will be removed by the landmark transaction and
	## cannot visually bridge it back into the town.  Feature owners likewise do
	## not count; a market canopy or another hero reservation is not a terrain-
	## rooted transition house.
	var footprint: Dictionary = {}
	var minimum_y := 2147483647
	var maximum_y := -2147483648
	for cell_value: Variant in protected_cells.keys():
		var cell := cell_value as Vector3i
		footprint[Vector2i(cell.x, cell.z)] = true
		minimum_y = mini(minimum_y, cell.y)
		maximum_y = maxi(maximum_y, cell.y)
	if footprint.is_empty():
		return {"side_count": 0, "edge_count": 0, "score": 0,
			"nearest_gap": LANDMARK_CITY_CONTACT_RADIUS_CELLS + 1,
			"owner_ids": [] as Array[StringName]}
	var touched_sides: Dictionary = {}
	var touched_owners: Dictionary = {}
	var edge_count := 0
	var score := 0
	var nearest_gap := LANDMARK_CITY_CONTACT_RADIUS_CELLS + 1
	for column_value: Variant in footprint.keys():
		var column := column_value as Vector2i
		for direction_3d: Vector3i in WarrenSpatialFeatureSolver.SKY_DIRECTIONS:
			var direction := Vector2i(direction_3d.x, direction_3d.z)
			if footprint.has(column + direction):
				continue
			var boundary_hit := false
			for distance in range(1, LANDMARK_CITY_CONTACT_RADIUS_CELLS + 1):
				var target := column + direction * distance
				if footprint.has(target):
					break
				# Distance two is admitted only when its one intervening column is
				# an exact public lane. Without this check, the same metric treats a
				# strip of open lawn as urban integration.
				if distance > 1 and grid != null \
						and not _landmark_gap_is_public_lane(grid, column,
							direction, distance, minimum_y, maximum_y):
					continue
				var distance_owners: Dictionary = {}
				for y in range(minimum_y - 1, maximum_y + 2):
					for owner_value: Variant in (protected_owners.get(
							Vector3i(target.x, y, target.y), {}) as Dictionary).keys():
						var owner_id := StringName(owner_value)
						if blocker_parcels.has(owner_id) \
								or _protected_owner_is_feature(owner_id):
							continue
						distance_owners[owner_id] = true
				if distance_owners.is_empty():
					continue
				boundary_hit = true
				edge_count += 1
				score += LANDMARK_CITY_CONTACT_RADIUS_CELLS + 1 - distance
				nearest_gap = mini(nearest_gap, distance)
				touched_sides[direction] = true
				touched_owners.merge(distance_owners, true)
				break
			if boundary_hit:
				continue
	var owner_ids: Array[StringName] = []
	owner_ids.assign(touched_owners.keys())
	owner_ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	return {"side_count": touched_sides.size(), "edge_count": edge_count,
		"score": score, "nearest_gap": nearest_gap, "owner_ids": owner_ids}


static func _landmark_gap_is_public_lane(grid: WarrenSpatialGrid,
		boundary_column: Vector2i, direction: Vector2i, distance: int,
		minimum_y: int, maximum_y: int) -> bool:
	if grid == null or distance <= 1:
		return distance <= 1
	for step in range(1, distance):
		var column := boundary_column + direction * step
		var has_public_floor := false
		for y in range(minimum_y - 1, maximum_y + 2):
			var cell := Vector3i(column.x, y, column.y)
			if grid.use_at(cell) != WarrenSpatialGrid.Use.PUBLIC_AIR:
				continue
			var floor_claim := grid.face_claim(cell, Vector3i.DOWN)
			if not floor_claim.is_empty() and int(floor_claim.get("kind", -1)) \
					== WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR:
				has_public_floor = true
				break
		if not has_public_floor:
			return false
	return true


static func _landmark_recipe_socket_signature(recipe: FabricRecipe,
		origin: Vector3i, yaw: int) -> String:
	var parts := PackedStringArray()
	for socket: Dictionary in recipe.sockets:
		if int(socket.kind) != FabricRecipe.SocketKind.ROOM \
				or String(StringName(socket.id)).contains(".corner."):
			continue
		var cell := FabricRecipe.transform_cell(socket.cell as Vector3i,
			origin, yaw)
		var facing := FabricRecipe.transform_direction(socket.facing as Vector3i,
			yaw)
		parts.append("%d:%d:%d/%d:%d:%d" % [cell.x, cell.y, cell.z,
			facing.x, facing.y, facing.z])
	parts.sort()
	return ",".join(parts)


static func _cell_set_signature(cells_value: Variant) -> String:
	var cells := cells_value as Dictionary
	var ordered: Array[Vector3i] = []
	ordered.assign(cells.keys())
	ordered.sort_custom(_cell_less)
	var parts := PackedStringArray()
	for cell: Vector3i in ordered:
		parts.append("%d:%d:%d" % [cell.x, cell.y, cell.z])
	return ",".join(parts)


static func _annotate_landmark_party_walls(
		landmarks: Array[Dictionary]) -> void:
	## Measured prefab bodies may meet at one exact cell face. That contact is an
	## authored city seam, not two exterior facades occupying the same plane. Both
	## transactions claim the same deterministic joint owner and face kind, so the
	## grid stores one canonical party wall (or vertical construction joint) while
	## each landmark retains independent volume and feature ownership.
	for landmark: Dictionary in landmarks:
		landmark["party_wall_faces"] = {}
	for left_index in landmarks.size():
		var left := landmarks[left_index]
		var left_body := left.get("body", {}) as Dictionary
		for right_index in range(left_index + 1, landmarks.size()):
			var right := landmarks[right_index]
			var right_body := right.get("body", {}) as Dictionary
			var ids: Array[StringName] = [StringName(left.feature_id),
				StringName(right.feature_id)]
			ids.sort_custom(func(a: StringName, b: StringName) -> bool:
				return String(a) < String(b))
			var joint_owner := StringName("%s+%s" % [ids[0], ids[1]])
			for cell_value: Variant in left_body.keys():
				var cell := cell_value as Vector3i
				for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
						Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD,
						Vector3i.BACK]:
					var neighbor := cell + direction
					if not right_body.has(neighbor):
						continue
					if not (left.party_wall_faces as Dictionary).has(cell):
						(left.party_wall_faces as Dictionary)[cell] = {}
					((left.party_wall_faces as Dictionary)[cell] \
						as Dictionary)[direction] = joint_owner
					if not (right.party_wall_faces as Dictionary).has(neighbor):
						(right.party_wall_faces as Dictionary)[neighbor] = {}
					((right.party_wall_faces as Dictionary)[neighbor] \
						as Dictionary)[-direction] = joint_owner


static func _protected_owners_with_landmarks(protected_owners: Dictionary,
		landmarks: Array[Dictionary]) -> Dictionary:
	var trial := protected_owners.duplicate(true)
	for landmark: Dictionary in landmarks:
		var feature_id := StringName(landmark.feature_id)
		for cell_value: Variant in (landmark.protected_cells as Dictionary).keys():
			if not trial.has(cell_value):
				trial[cell_value] = {}
			(trial[cell_value] as Dictionary)[feature_id] = true
	return trial


static func _reserve_landmark_preplans(grid: WarrenSpatialGrid,
		landmarks: Array[Dictionary]) -> bool:
	_annotate_landmark_party_walls(landmarks)
	for landmark_index in landmarks.size():
		var landmark := landmarks[landmark_index]
		if not _reserve_landmark_preplan(grid, landmark):
			last_preplan_landmark_diagnostic["reservation_failure"] = {
				"index": landmark_index,
				"feature_id": landmark.get("feature_id", &""),
				"recipe_id": landmark.get("recipe_id", &""),
				"origin": landmark.get("origin", Vector3i.ZERO),
				"rejection": grid.last_rejection,
			}
			return false
	var selected: Array[Dictionary] = []
	for landmark: Dictionary in landmarks:
		selected.append({"feature_id": landmark.feature_id,
			"recipe_id": landmark.recipe_id,
			"source_family": landmark.source_family,
			"origin": landmark.origin,
			"yaw_quarters": landmark.yaw_quarters,
			"landing_cell": landmark.landing_cell,
			"entrance_cell": landmark.entrance_cell,
			"body_cell_count": (landmark.body as Dictionary).size(),
			"clearance_cell_count": (landmark.clearance as Dictionary).size(),
			"displaced_parcel_count": (landmark.blocker_parcels \
				as Dictionary).size()})
	last_preplan_landmark_diagnostic["selected"] = selected
	return true


static func _annotate_landmark_skywalk_connections(
		landmarks: Array[Dictionary], skywalks: Array[Dictionary]) -> void:
	var landmark_by_id: Dictionary = {}
	for landmark: Dictionary in landmarks:
		landmark["skywalk_socket_faces"] = {}
		landmark_by_id[StringName(landmark.feature_id)] = landmark
	for skywalk: Dictionary in skywalks:
		var owner_ids := skywalk.get("owner_parcel_ids", []) as Array
		var endpoints := skywalk.get("owner_endpoints", []) as Array
		for endpoint_index in mini(owner_ids.size(), endpoints.size()):
			var owner_id := StringName(owner_ids[endpoint_index])
			if not landmark_by_id.has(owner_id):
				continue
			var endpoint := endpoints[endpoint_index] as Dictionary
			var landmark := landmark_by_id[owner_id] as Dictionary
			(landmark.skywalk_socket_faces as Dictionary)[
				endpoint.cell as Vector3i] = endpoint.facing as Vector3i
			var skywalk_body := skywalk.get("reserved_cells", {}) as Dictionary
			for cell_value: Variant in (landmark.body as Dictionary).keys():
				var cell := cell_value as Vector3i
				for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
						Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD,
						Vector3i.BACK]:
					if skywalk_body.has(cell + direction):
						(landmark.skywalk_socket_faces as Dictionary)[cell] = \
							direction


static func _reserve_landmark_preplan(grid: WarrenSpatialGrid,
		landmark: Dictionary) -> bool:
	var feature_id := StringName(landmark.feature_id)
	var body_set := landmark.body as Dictionary
	var body: Array[Vector3i] = []
	body.assign(body_set.keys())
	body.sort_custom(_cell_less)
	var clearance_only: Array[Vector3i] = []
	for cell_value: Variant in (landmark.clearance as Dictionary).keys():
		if not body_set.has(cell_value):
			clearance_only.append(cell_value as Vector3i)
	var bearing: Array[Vector3i] = []
	bearing.assign((landmark.bearing_cells as Dictionary).keys())
	var entrance_cell := landmark.entrance_cell as Vector3i
	var landing_cell := landmark.landing_cell as Vector3i
	var skywalk_socket_faces := landmark.get("skywalk_socket_faces", {}) \
		as Dictionary
	var party_wall_faces := landmark.get("party_wall_faces", {}) as Dictionary
	var route_roof_is_shared := bool(landmark.get("route_roof_is_shared",
		false))
	var tx := grid.begin_transaction(feature_id)
	if body.is_empty() or bearing.is_empty() \
			or not tx.require_use(body, [WarrenSpatialGrid.Use.OUTSIDE,
				WarrenSpatialGrid.Use.ALLOCATABLE] as Array[int]) \
			or not tx.reserve(body, WarrenSpatialGrid.Reservation.FEATURE \
				| WarrenSpatialGrid.Reservation.VISUAL_CLEARANCE, feature_id) \
			or not clearance_only.is_empty() and not tx.reserve(clearance_only,
				WarrenSpatialGrid.Reservation.VISUAL_CLEARANCE, feature_id) \
			or not tx.reserve(bearing,
				WarrenSpatialGrid.Reservation.TERRAIN_BEARING, feature_id) \
			or not tx.assign_use(body, WarrenSpatialGrid.Use.PRIVATE_VOLUME,
				feature_id):
		return false
	for cell: Vector3i in body:
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD, Vector3i.BACK]:
			var neighbor := cell + direction
			if body_set.has(neighbor):
				continue
			var cell_joints := party_wall_faces.get(cell, {}) as Dictionary
			if cell_joints.has(direction):
				var joint_kind := WarrenSpatialGrid.FaceKind.PARTY_WALL \
					if direction.y == 0 \
					else WarrenSpatialGrid.FaceKind.CONSTRUCTION_JOINT
				if not tx.claim_face(cell, direction, joint_kind,
						StringName(cell_joints[direction])):
					return false
				continue
			if skywalk_socket_faces.get(cell, Vector3i.ZERO) == direction:
				continue
			var kind := WarrenSpatialGrid.FaceKind.FACADE
			if cell == entrance_cell and neighbor == landing_cell:
				kind = WarrenSpatialGrid.FaceKind.DOOR
			elif direction == Vector3i.UP:
				kind = WarrenSpatialGrid.FaceKind.ROOF
			elif direction == Vector3i.DOWN:
				kind = WarrenSpatialGrid.FaceKind.PRIVATE_FLOOR
			# TASK C5c RULING 5. A prefab under an upper street meets that
			# street's PUBLIC_FLOOR on its own top boundary, and the route
			# claimed that face first. Claiming ROOF there is not a better
			# answer than the one already on the grid -- it is the same
			# boundary described twice -- so the prefab takes no claim and the
			# street keeps its floor. `WarrenPlotPlanner._no_street_left
			# _hanging` allows the arrangement on purpose: the plot BEARS that
			# street. Maze-only, and carried on the reservation the maze asset
			# pass builds rather than on a mode global, so no searched landmark
			# can silently stop rejecting a conflict it is meant to reject.
			if route_roof_is_shared and direction == Vector3i.UP:
				var existing := grid.face_claim(cell, Vector3i.UP)
				if not existing.is_empty() and int(existing.get("kind", -1)) \
						== WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR:
					continue
			if not tx.claim_face(cell, direction, kind, feature_id):
				return false
	return tx.commit()


static func _landmark_bearing_follows_terrain(bearing: Dictionary,
		volume: WarrenVolumePlan) -> bool:
	return _landmark_bearing_failure(bearing, volume).is_empty()


static func _landmark_bearing_failure(bearing: Dictionary,
		volume: WarrenVolumePlan) -> String:
	var massif := volume.mass_context.get("massif") as WarrenMassif
	if massif == null:
		return "no massif"
	# TASK C5c RULING 5. In a searched town the only thing under a prefab is
	# terrain, so "follows terrain" and "stands on something" are one test. In
	# MAZE mode they are two: the plot planner sited this asset on a plot whose
	# floor may be bands above natural ground, and what fills the gap is the
	# derived rock Task C5 retains and Task C5b skins as real stone. C2 kept
	# the rule strict because nothing drew that rock; it is drawn now, so the
	# honest test is that every bearing cell rests on SOLID the source names --
	# the plot's own flat floor at the datum, or the retained stone under it --
	# and never on air.
	var source := volume.mass_context.get(&"maze_source_plan") \
		as WarrenMazeSourcePlan
	for cell_value: Variant in bearing.keys():
		var cell := cell_value as Vector3i
		var macro_column := Vector2i(floori(float(cell.x) / 2.0),
			floori(float(cell.z) / 2.0))
		if not massif.has_column(macro_column):
			return "%s maps outside massif at %s" % [cell, macro_column]
		if massif.bearing_at(macro_column) == cell.y:
			continue
		if source == null or cell.y < massif.bearing_at(macro_column) \
				or not source.solid_at(Vector3i(macro_column.x, cell.y - 1,
					macro_column.y)):
			return "%s maps to %s (ground %d, supporting band %d solid=%s)" % [
				cell, macro_column, massif.bearing_at(macro_column), cell.y - 1,
				"no" if source == null else str(source.solid_at(Vector3i(
					macro_column.x, cell.y - 1, macro_column.y)))]
	return ""


static func _proposal_base_plate(proposal: Dictionary) -> Dictionary:
	var origin := proposal.origin as Vector3i
	var out: Dictionary = {}
	for cell: Vector3i in StaggeredFabricCompiler.proposal_occupied_cells(
			proposal):
		if cell.y == origin.y:
			out[Vector2i(cell.x, cell.z)] = true
	return out


static func _preplan_spatial_market(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan, proposals: Array[Dictionary],
		program: SettlementFabricProgram,
		protected_owners: Dictionary) -> Dictionary:
	## Attach the reviewed 6 x 3 m bazaar to one exact base-room MARKET socket.
	## Its central two-by-two aisle is already canonical route air; the corner
	## posts and continuous canopy surround/cover that negative space without
	## turning the market into a detached tent row or a late decoration pass.
	var candidates: Array[Dictionary] = []
	var socket_count := 0
	var ground_fit_count := 0
	var body_fit_count := 0
	var aisle_fit_count := 0
	var clearance_fit_count := 0
	var backing_fit_count := 0
	var aisle_failures: Array[Dictionary] = []
	var feature_id := &"spatial.feature.market.00"
	var aisle_local: Array[Vector3i] = [
		Vector3i(-1, 0, -1), Vector3i(0, 0, -1),
		Vector3i(-1, 0, 0), Vector3i(0, 0, 0),
	]
	for proposal: Dictionary in proposals:
		var parcel := proposal.parcel as WarrenBuildingParcel
		var profile := WarrenParcelConstruction.profile_for(parcel)
		if profile.is_empty():
			continue
		var proposal_origin := proposal.origin as Vector3i
		var proposal_yaw := int(proposal.yaw_quarters)
		var minimum := profile.minimum as Vector3i
		var size := profile.size as Vector3i
		var sockets: Array[Dictionary] = [
			{"cell": minimum + Vector3i(size.x - 1, 0,
				(size.z - 1) / 2), "facing": Vector3i.RIGHT},
			{"cell": minimum + Vector3i(0, 0, (size.z - 1) / 2),
				"facing": Vector3i.LEFT},
			{"cell": minimum + Vector3i((size.x - 1) / 2, 0, 0),
				"facing": Vector3i.FORWARD},
			{"cell": minimum + Vector3i((size.x - 1) / 2, 0,
				size.z - 1), "facing": Vector3i.BACK},
		]
		for socket: Dictionary in sockets:
			socket_count += 1
			var backing_cell := FabricRecipe.transform_cell(
				socket.cell as Vector3i, proposal_origin, proposal_yaw)
			var backing_facing := FabricRecipe.transform_direction(
				socket.facing as Vector3i, proposal_yaw)
			var market_yaw := _yaw_for_direction(Vector3i.FORWARD,
				-backing_facing)
			if market_yaw < 0:
				continue
			var market_socket_cell := backing_cell + backing_facing
			var market_origin := market_socket_cell - FabricRecipe.transform_cell(
				Vector3i(-1, 0, -1), Vector3i.ZERO, market_yaw)
			var family := posmod(Helper._mix64(volume.world_seed \
				^ String(parcel.stable_id).hash() ^ backing_cell.x * 73856093 \
				^ backing_cell.z * 19349663),
				SettlementFabricProgram.MARKET_STALLS.size())
			var recipe_id := StringName("market.covered.%02d.garden" % family)
			var recipe := program.recipe(recipe_id)
			if recipe == null or not recipe.has_tag(&"covered_market"):
				continue
			if not WarrenMarketSolver._bearing_follows_local_ground(market_origin,
					market_yaw, volume, WarrenMarketSolver.COVERED_MARKET_MINIMUM,
					WarrenMarketSolver.COVERED_MARKET_SIZE):
				continue
			ground_fit_count += 1
			var body: Dictionary = {}
			for cells: Array[Vector3i] in [recipe.solid_cells,
					recipe.headroom_cells, recipe.walk_cells]:
				for local_cell: Vector3i in cells:
					body[FabricRecipe.transform_cell(local_cell, market_origin,
						market_yaw)] = true
			if body.is_empty() or not _skywalk_body_fits_grid(grid, body):
				continue
			body_fit_count += 1
			# The named backing room may touch the visual envelope, but structural
			# market cells may never replace the room they claim to address.
			var overlaps_backing := false
			for body_value: Variant in body.keys():
				if (protected_owners.get(body_value, {}) as Dictionary).has(
						parcel.stable_id):
					overlaps_backing = true
					break
			if overlaps_backing:
				continue
			var aisle := _market_public_aisle(grid, volume, market_origin,
				market_yaw, aisle_local, body, protected_owners, parcel.stable_id)
			if aisle.is_empty():
				if aisle_failures.size() < 16:
					aisle_failures.append({"parcel": parcel.stable_id,
						"origin": market_origin, "yaw": market_yaw})
				continue
			var public_cells := aisle.cells as Dictionary
			var covered_aisle_cells := aisle.covered_cells as Dictionary
			var new_public_cell_count := int(aisle.new_public_cell_count)
			var entrance_edge_count := int(aisle.entrance_edge_count)
			var entrance_width := int(aisle.entrance_width)
			aisle_fit_count += 1
			var components: Array[Dictionary] = [{"recipe_id": recipe_id,
				"origin": market_origin, "yaw_quarters": market_yaw}]
			var clearance := _skywalk_visual_clearance_cells(components, program)
			if clearance.is_empty() or not _cells_fit_grid(grid, clearance):
				continue
			clearance_fit_count += 1
			var bearing_cells: Dictionary = {}
			for local_cell: Vector3i in FabricRecipe.box_cells(
					WarrenMarketSolver.COVERED_MARKET_MINIMUM,
					Vector3i(WarrenMarketSolver.COVERED_MARKET_SIZE.x, 1,
						WarrenMarketSolver.COVERED_MARKET_SIZE.z)):
				bearing_cells[FabricRecipe.transform_cell(local_cell,
					market_origin, market_yaw)] = true
			var blocker_count := _skywalk_blocker_count(clearance,
				protected_owners, {parcel.stable_id: true})
			var shelter := _market_shelter_audit(grid, public_cells, body,
				protected_owners)
			var overhead_public_floor_seam_count := \
				_market_overhead_public_floor_seam_count(grid, body, public_cells)
			candidates.append({"feature_id": feature_id,
				"kind": &"covered_market", "recipe_id": recipe_id,
				"origin": market_origin, "yaw_quarters": market_yaw,
				"components": components, "reserved_cells": body,
				"public_cells": public_cells,
				"covered_aisle_cells": covered_aisle_cells,
				"aisle_extension_cell_count": public_cells.size() \
					- covered_aisle_cells.size(),
				"aisle_extension_length": int(aisle.extension_length),
				"new_public_cell_count": new_public_cell_count,
				"street_entrance_edge_count": entrance_edge_count,
				"street_entrance_width": entrance_width,
				"visual_clearance_cells": clearance,
				"bearing_cells": bearing_cells,
				"owner_parcel_ids": [parcel.stable_id],
				"backing_parcel_id": parcel.stable_id,
				"backing_cell": backing_cell,
				"backing_facing": backing_facing,
				"blocker_count": blocker_count,
				"overhead_public_floor_seam_count":
					overhead_public_floor_seam_count,
				"open_horizon_max_cells": int(shelter.max_open_cells),
				"open_horizon_total_cells": int(shelter.total_open_cells),
				"core_radius_squared": float(shelter.core_radius_squared),
				"tie": posmod(Helper._mix64(volume.world_seed \
					^ String(recipe_id).hash() ^ market_origin.x * 31 \
					^ market_origin.z * 47 ^ market_yaw * 131), 1000003)})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		# A covered bazaar belongs inside the inhabited maze. Prefer the exact
		# candidate whose aisle views terminate in mass soonest; a low room-
		# displacement count may break ties, but may not drag the market back to
		# an empty perimeter merely because that space is cheap.
		if int(a.overhead_public_floor_seam_count) \
				!= int(b.overhead_public_floor_seam_count):
			return int(a.overhead_public_floor_seam_count) \
				> int(b.overhead_public_floor_seam_count)
		if int(a.open_horizon_max_cells) != int(b.open_horizon_max_cells):
			return int(a.open_horizon_max_cells) < int(b.open_horizon_max_cells)
		if int(a.open_horizon_total_cells) != int(b.open_horizon_total_cells):
			return int(a.open_horizon_total_cells) < int(b.open_horizon_total_cells)
		if not is_equal_approx(float(a.core_radius_squared),
				float(b.core_radius_squared)):
			return float(a.core_radius_squared) < float(b.core_radius_squared)
		if int(a.aisle_extension_length) != int(b.aisle_extension_length):
			return int(a.aisle_extension_length) < int(b.aisle_extension_length)
		if int(a.blocker_count) != int(b.blocker_count):
			return int(a.blocker_count) < int(b.blocker_count)
		return int(a.tie) < int(b.tie))
	var viable: Array[Dictionary] = []
	var open_horizon_limit := _market_open_horizon_limit(volume)
	for candidate: Dictionary in candidates:
		if int(candidate.open_horizon_max_cells) \
				> open_horizon_limit:
			continue
		if not _market_backing_composition_survives(grid, candidate, proposals,
				protected_owners, volume.world_seed):
			continue
		backing_fit_count += 1
		viable.append(candidate)
	var shelter_preview: Array[Dictionary] = []
	for index in mini(12, candidates.size()):
		var candidate := candidates[index]
		shelter_preview.append({"parcel": candidate.backing_parcel_id,
			"origin": candidate.origin,
			"overhead_public_floor_seams": int(
				candidate.overhead_public_floor_seam_count),
			"open_max": int(candidate.open_horizon_max_cells),
			"open_total": int(candidate.open_horizon_total_cells),
			"radius_squared": float(candidate.core_radius_squared),
			"aisle_extension_length": int(candidate.aisle_extension_length),
			"blockers": int(candidate.blocker_count)})
	last_preplan_market_diagnostic = {"socket_count": socket_count,
		"ground_fit_count": ground_fit_count, "body_fit_count": body_fit_count,
		"aisle_fit_count": aisle_fit_count,
		"clearance_fit_count": clearance_fit_count,
		"candidate_count": candidates.size(),
		"backing_fit_count": backing_fit_count,
		"open_horizon_limit_cells": open_horizon_limit,
		"shelter_preview": shelter_preview,
		"aisle_failures": aisle_failures}
	return {"candidates": viable}


static func _market_open_horizon_limit(volume: WarrenVolumePlan) -> int:
	## Shelter is measured in fixed 1.5 m lattice cells, while the authored town
	## radius deliberately varies by scale. Keep compact and standard bazaars
	## tucked into the tightest alleys. A large courtyard town may admit one
	## longer approach sightline, but it still has to terminate inside its own
	## inhabited mass; grand towns get only the review ray's finite upper bound.
	##
	## TASK F3 MEMBER 3 -- ALL FOUR SCALES, CHECKED. The compact and standard
	## branches are the measured ones; see `MAX_MARKET_OPEN_HORIZON_CELLS` for
	## why 4 stays. The other two arms were UNEXERCISED when F3 measured them,
	## because 0 of 12 seeds sealed at large and 0 of 12 at grand -- 14 of the 24
	## died at the elevated-courtyard gate those two profiles are the only ones
	## to require, 5 at the route-slab gate, 3 at the straight-run cap and 2 at
	## the court cantilever.
	##
	## TASK F4 made that gate advisory and re-measured on the same 12 seeds:
	## large seals 3 of 12 (4, 6, 7) and grand 1 of 12 (9), and all four build a
	## bazaar. So these two arms have now judged candidates -- four towns' worth,
	## which is a measurement but not yet a corpus, and still not enough to TUNE
	## either constant against. Note that `GRAND_MARKET_OPEN_HORIZON_CELLS`
	## equals the sight ray's own bound, which makes the grand arm no constraint
	## at all rather than a loose one. The 7 large seeds that now die at
	## `requires_covered_market` are the reason to look here again, and they die
	## in `WarrenSpatialFeatureSolver`, not at this horizon.
	var profile := _scale_profile_for_volume(volume)
	if profile == null:
		return MAX_MARKET_OPEN_HORIZON_CELLS
	match profile.scale_id:
		WarrenVillageScaleProfile.LARGE:
			return LARGE_MARKET_OPEN_HORIZON_CELLS
		WarrenVillageScaleProfile.GRAND:
			return GRAND_MARKET_OPEN_HORIZON_CELLS
		_:
			return MAX_MARKET_OPEN_HORIZON_CELLS


static func _market_overhead_public_floor_seam_count(
		grid: WarrenSpatialGrid, body: Dictionary,
		planned_public_cells: Dictionary = {}) -> int:
	## The canopy is part of the vertical public-realm composition: at least one
	## of its exposed upper faces must meet an already-sealed public floor. This
	## makes the bazaar a genuine inhabited undercroft instead of a tent inserted
	## into whichever ground-level void happened to remain cheapest.
	var count := 0
	for cell_value: Variant in body.keys():
		var cell := cell_value as Vector3i
		if body.has(cell + Vector3i.UP):
			continue
		var upper_cell := cell + Vector3i.UP
		var existing := grid.face_claim(cell, Vector3i.UP)
		if planned_public_cells.has(upper_cell) \
				or not existing.is_empty() and int(existing.kind) \
					== WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR:
			count += 1
	return count


static func _market_shelter_audit(grid: WarrenSpatialGrid,
		public_cells: Dictionary, body: Dictionary,
		proposed_private_cells: Dictionary) -> Dictionary:
	## Measure the negative-space experience rather than distance to a nominal
	## town centre. From every exposed aisle edge, walk a bounded sight ray until
	## it meets either the market construction or an actual proposed room cell.
	## Generic ALLOCATABLE massif is deliberately not shelter: most of it is
	## discarded after room composition, and counting it made edge markets look
	## enclosed in planning before opening directly onto empty terrain in the
	## render. PUBLIC_AIR and true empty OUTSIDE cells keep the ray open. The maximum is
	## the important failure mode visible in review: one market mouth looking
	## straight out of the town. The total distinguishes equally bounded arcades.
	const HORIZON_LIMIT_CELLS := MARKET_SHELTER_HORIZON_LIMIT_CELLS
	var maximum_open := 0
	var total_open := 0
	var centre := Vector2.ZERO
	for cell_value: Variant in public_cells.keys():
		var cell := cell_value as Vector3i
		centre += Vector2(cell.x + 0.5, cell.z + 0.5)
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.FORWARD, Vector3i.BACK]:
			if public_cells.has(cell + direction):
				continue
			var open_cells := 0
			for distance in range(1, HORIZON_LIMIT_CELLS + 1):
				var sample := cell + direction * distance
				if body.has(sample) or body.has(sample + Vector3i.UP) \
						or proposed_private_cells.has(sample) \
						or proposed_private_cells.has(sample + Vector3i.UP):
					break
				open_cells += 1
				if not grid.contains(sample):
					break
			maximum_open = maxi(maximum_open, open_cells)
			total_open += open_cells
	if not public_cells.is_empty():
		centre /= float(public_cells.size())
	return {"max_open_cells": maximum_open,
		"total_open_cells": total_open,
		"core_radius_squared": centre.length_squared()}


static func _market_backing_composition_survives(grid: WarrenSpatialGrid,
		market: Dictionary, proposals: Array[Dictionary],
		protected_owners: Dictionary, world_seed: int) -> bool:
	var backing_parcel_id := StringName(market.backing_parcel_id)
	var proposal: Dictionary = {}
	for candidate: Dictionary in proposals:
		if (candidate.parcel as WarrenBuildingParcel).stable_id \
				== backing_parcel_id:
			proposal = candidate
			break
	if proposal.is_empty():
		return false
	var trial := protected_owners.duplicate(true)
	var feature_id := StringName(market.feature_id)
	var endpoint_allowance: Dictionary = {backing_parcel_id: true}
	for cell_value: Variant in (market.reserved_cells as Dictionary).keys():
		if not trial.has(cell_value):
			trial[cell_value] = {}
		(trial[cell_value] as Dictionary)[feature_id] = true
	for cell_value: Variant in (market.visual_clearance_cells \
			as Dictionary).keys():
		if (market.reserved_cells as Dictionary).has(cell_value):
			continue
		if not trial.has(cell_value):
			trial[cell_value] = {}
		(trial[cell_value] as Dictionary)[feature_id] = endpoint_allowance
	_protect_market_public_air(trial, market, feature_id)
	var parcel := proposal.parcel as WarrenBuildingParcel
	var origin := proposal.origin as Vector3i
	var storeys := int(proposal.storeys)
	var threshold := WarrenParcelConstruction.threshold_cell(parcel)
	var addressed_storey := clampi(floori(float(threshold.y - origin.y) \
		/ float(WarrenSpatialGrid.STOREY_CELLS)), 0, storeys - 1)
	var forced: Dictionary = {0: Vector2i.ZERO,
		addressed_storey / 2: Vector2i.ZERO}
	if not _force_market_backing_offset(forced, market,
			backing_parcel_id, origin.y, storeys):
		return false
	return not _composition_offsets(grid, _proposal_base_plate(proposal),
		origin.y, storeys, trial, backing_parcel_id, world_seed, forced).is_empty()


static func _force_market_backing_offset(forced_offsets: Dictionary,
		market: Dictionary, parcel_id: StringName, origin_y: int,
		storeys: int) -> bool:
	## The covered market's backing cell is an exact room socket, so the
	## provisional two-storey offset band containing it is an immutable interface
	## just like a doorway or skywalk endpoint. Centralizing the rule keeps market
	## candidate validation, exact hero-feature preflight, and final composition
	## on the same phase contract.
	if market.is_empty() or StringName(market.get(
			"backing_parcel_id", &"")) != parcel_id:
		return true
	var backing_cell := market.get("backing_cell",
		Vector3i(2147483647, 2147483647, 2147483647)) as Vector3i
	var local_storey := floori(float(backing_cell.y - origin_y) \
		/ float(WarrenSpatialGrid.STOREY_CELLS))
	if local_storey < 0 or local_storey >= storeys:
		return false
	var offset_block := floori(float(local_storey) / 2.0)
	if forced_offsets.has(offset_block) \
			and forced_offsets[offset_block] != Vector2i.ZERO:
		return false
	forced_offsets[offset_block] = Vector2i.ZERO
	return true


static func _protected_owners_with_market(protected_owners: Dictionary,
		market: Dictionary) -> Dictionary:
	var trial := protected_owners.duplicate(true)
	if market.is_empty() or bool(market.get("optional_absent", false)):
		return trial
	var feature_id := StringName(market.feature_id)
	var endpoint_allowance: Dictionary = {
		StringName(market.backing_parcel_id): true}
	for cell_value: Variant in (market.reserved_cells as Dictionary).keys():
		if not trial.has(cell_value):
			trial[cell_value] = {}
		(trial[cell_value] as Dictionary)[feature_id] = true
	for cell_value: Variant in (market.visual_clearance_cells \
			as Dictionary).keys():
		if (market.reserved_cells as Dictionary).has(cell_value):
			continue
		if not trial.has(cell_value):
			trial[cell_value] = {}
		(trial[cell_value] as Dictionary)[feature_id] = endpoint_allowance
	_protect_market_public_air(trial, market, feature_id)
	return trial


static func _protect_market_public_air(protected_owners: Dictionary,
		market: Dictionary, feature_id: StringName) -> void:
	## The aisle floor is a logical surface; the occupied reservation is its full
	## swept player volume. Existing route air is already blocked by the grid,
	## but aisle extensions still read ALLOCATABLE during preflight. Protect both
	## headroom bands here so the exact room solve sees the same undercroft void
	## that `_reserve_market_preplan` later commits as PUBLIC_AIR.
	for floor_value: Variant in (market.get("public_cells", {}) \
			as Dictionary).keys():
		var floor := floor_value as Vector3i
		for y_offset in WarrenVolumePlan.HEADROOM_BANDS:
			var air := floor + Vector3i.UP * y_offset
			if not protected_owners.has(air):
				protected_owners[air] = {}
			(protected_owners[air] as Dictionary)[feature_id] = true


static func _protected_owners_with_courtyard_bridge(
		protected_owners: Dictionary, candidate: Dictionary) -> Dictionary:
	## The occupied court room yields only to its one exact endpoint lineage.
	## Its body remains unavailable to every room/landmark/skywalk, while the
	## measured eave envelope may overlap the parent building at the authored
	## socket and nowhere else.
	var trial := protected_owners.duplicate(true)
	var reservation := candidate.reservation as Dictionary
	var feature_id := StringName(reservation.feature_id)
	var endpoint_allowance := _skywalk_endpoint_owner_set(reservation)
	var body := candidate.body as Dictionary
	for cell_value: Variant in body.keys():
		if not trial.has(cell_value):
			trial[cell_value] = {}
		(trial[cell_value] as Dictionary)[feature_id] = true
	for cell_value: Variant in (candidate.clearance as Dictionary).keys():
		if body.has(cell_value):
			continue
		if not trial.has(cell_value):
			trial[cell_value] = {}
		(trial[cell_value] as Dictionary)[feature_id] = endpoint_allowance
	for cell_value: Variant in (candidate.priority_cells as Dictionary).keys():
		if not trial.has(cell_value):
			trial[cell_value] = {}
		(trial[cell_value] as Dictionary)[StringName(
			(candidate.priority_cells as Dictionary)[cell_value])] = true
	return trial


static func _absent_courtyard_bridge_candidate() -> Dictionary:
	## Sentinel for a town with no upper court. It lets the market/landmark/
	## skywalk joint beam retain one code path while reserving no cells, moving
	## no rooms, and compiling no feature.
	##
	## TASK F4 corrected the last sentence, which read "Large and grand profiles
	## never receive this candidate": `_maze_court_selection` falls back to
	## exactly this candidate for a large or grand town whose cantilever search
	## comes back empty, publishing `courtyard_bridges` as it does. That is the
	## normal outcome on the whole 12-seed corpus, not an impossible one.
	return {
		"optional_absent": true,
		"reservation": {
			"feature_id": &"spatial.feature.courtyard.absent",
			"origin": Vector3i.ZERO,
			"owner_parcel_ids": [] as Array[StringName],
			"owner_endpoints": [] as Array[Dictionary],
			"components": [] as Array[Dictionary],
		},
		"body": {},
		"clearance": {},
		"priority_cells": {},
		"forced_offsets": {},
		"excluded_parcel_ids": [] as Array[StringName],
	}


static func _macro_composition_preflight(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan, proposals: Array[Dictionary],
		base_protected_owners: Dictionary,
		court_fixed_blocks_by_parcel: Dictionary) -> Dictionary:
	var trial_owners := base_protected_owners.duplicate(true)
	var solved_offsets_by_parcel: Dictionary = {}
	var exact_forced_offsets_by_parcel: Dictionary = {}
	for proposal: Dictionary in proposals:
		var parcel := proposal.parcel as WarrenBuildingParcel
		var storeys := int(proposal.storeys)
		var origin := proposal.origin as Vector3i
		var base_plate := _proposal_base_plate(proposal)
		if storeys <= 0 or base_plate.is_empty():
			continue
		var threshold := WarrenParcelConstruction.threshold_cell(parcel)
		var addressed_storey := clampi(floori(float(threshold.y - origin.y) \
			/ float(WarrenSpatialGrid.STOREY_CELLS)), 0, storeys - 1)
		var forced: Dictionary = {0: Vector2i.ZERO,
			floori(float(addressed_storey) / 2.0): Vector2i.ZERO}
		for block_value: Variant in (court_fixed_blocks_by_parcel.get(
				parcel.stable_id, {}) as Dictionary).keys():
			forced[int(block_value)] = Vector2i.ZERO
		var offsets := _composition_offsets(grid, base_plate, origin.y,
			storeys, trial_owners, parcel.stable_id, volume.world_seed, forced)
		if offsets.is_empty():
			continue
		solved_offsets_by_parcel[parcel.stable_id] = offsets
		exact_forced_offsets_by_parcel[parcel.stable_id] = forced
		for cell: Vector3i in _segment_cells(base_plate, origin.y, offsets, 0,
				storeys):
			if not trial_owners.has(cell):
				trial_owners[cell] = {}
			(trial_owners[cell] as Dictionary)[parcel.stable_id] = true
	return WarrenRoomCompositionPlanner.solve(grid, volume, proposals,
		solved_offsets_by_parcel, exact_forced_offsets_by_parcel, {},
		trial_owners, {}, [] as Array[Dictionary], volume.world_seed, false, true)


static func _court_candidate_preserves_exact_room_envelopes(
		grid: WarrenSpatialGrid, volume: WarrenVolumePlan,
		proposals: Array[Dictionary], program: SettlementFabricProgram,
		market: Dictionary, court_candidate: Dictionary,
		base_protected_owners: Dictionary,
		court_fixed_blocks_by_parcel: Dictionary,
		skywalk_plan: Dictionary,
		enable_paired_registration_relief: bool,
		result: Dictionary,
		stop_after_macro_support: bool = false,
		support_exclusion_cells: Dictionary = {},
		support_exclusion_depth: int = 0) -> bool:
	## Exact post-feature preflight for the six-member court frontier. Solve the
	## actual room grammar with the already-fixed market, landmarks, three
	## skywalks, and this cantilever, then compare authored room envelopes against
	## its two measured components. This is deliberately not a raster halo: party
	## walls and narrow streets remain legal, while the exact eave collision that
	## final fabric compilation would reject removes only this court candidate.
	last_preplan_market_diagnostic.erase(
		"last_exact_court_tall_tower_failure")
	last_preplan_market_diagnostic.erase(
		"last_exact_room_composition_failure")
	last_preplan_market_diagnostic.erase(
		"last_exact_room_pair_failure")
	last_preplan_market_diagnostic.erase(
		"last_exact_court_composition_failure")
	last_preplan_market_diagnostic.erase(
		"last_exact_court_required_conflict")
	result.clear()
	var initial_excluded_ids: Array[StringName] = []
	initial_excluded_ids.assign(court_candidate.get(
		"excluded_parcel_ids", []) as Array)
	initial_excluded_ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	var initial_excluded_set: Dictionary = {}
	for excluded_id: StringName in initial_excluded_ids:
		initial_excluded_set[excluded_id] = true
	var initial_feature_excluded_set: Dictionary = {}
	for excluded_value: Variant in court_candidate.get(
			"feature_clearance_displaced_parcel_ids", []) as Array:
		initial_feature_excluded_set[StringName(excluded_value)] = true
	var forced_offsets_by_parcel := (skywalk_plan.forced_offsets \
		as Dictionary).duplicate(true)
	for parcel_value: Variant in (court_candidate.forced_offsets \
			as Dictionary).keys():
		var parcel_id := StringName(parcel_value)
		if not forced_offsets_by_parcel.has(parcel_id):
			forced_offsets_by_parcel[parcel_id] = {}
		for block_value: Variant in ((court_candidate.forced_offsets \
				as Dictionary)[parcel_id] as Dictionary).keys():
			var block := int(block_value)
			var wanted := ((court_candidate.forced_offsets as Dictionary)[
				parcel_id] as Dictionary)[block_value] as Vector2i
			var existing := (forced_offsets_by_parcel[parcel_id] \
				as Dictionary).get(block, wanted) as Vector2i
			if existing != wanted:
				return false
			(forced_offsets_by_parcel[parcel_id] as Dictionary)[block] = wanted
	var trial_owners := _protected_owners_with_courtyard_bridge(
		base_protected_owners, court_candidate)
	for cell_value: Variant in (skywalk_plan.priority_cells as Dictionary).keys():
		trial_owners[cell_value] = {StringName(
			(skywalk_plan.priority_cells as Dictionary)[cell_value]): true}
	var skywalk_reservations: Array[Dictionary] = []
	skywalk_reservations.assign(skywalk_plan.get("reservations", []) as Array)
	for reservation_index in skywalk_reservations.size():
		var skywalk := skywalk_reservations[reservation_index]
		var reservation_owner := StringName("spatial.skywalk.reserve.%02d" \
			% reservation_index)
		var body := skywalk.reserved_cells as Dictionary
		for cell_value: Variant in body.keys():
			if not trial_owners.has(cell_value):
				trial_owners[cell_value] = {}
			(trial_owners[cell_value] as Dictionary)[reservation_owner] = true
		var endpoint_allowance := _skywalk_endpoint_owner_set(skywalk)
		for cell_value: Variant in (skywalk.get("visual_clearance_cells", {}) \
				as Dictionary).keys():
			if body.has(cell_value):
				continue
			if not trial_owners.has(cell_value):
				trial_owners[cell_value] = {}
			(trial_owners[cell_value] as Dictionary)[reservation_owner] = \
				endpoint_allowance
	var solved_offsets_by_parcel: Dictionary = {}
	var exact_forced_offsets_by_parcel: Dictionary = {}
	for proposal: Dictionary in proposals:
		var parcel := proposal.parcel as WarrenBuildingParcel
		# A repeated exact pass starts from the prior pass's complete-parcel
		# dispositions. Reintroducing them here and merely comparing the same
		# exclusion list afterward would incorrectly label the stale composition
		# reusable.
		if initial_excluded_set.has(parcel.stable_id):
			continue
		var storeys := int(proposal.storeys)
		var proposal_origin := proposal.origin as Vector3i
		var base_plate := _proposal_base_plate(proposal)
		if storeys <= 0 or base_plate.is_empty():
			continue
		var threshold := WarrenParcelConstruction.threshold_cell(parcel)
		var addressed_storey := clampi(floori(float(
			threshold.y - proposal_origin.y) \
			/ float(WarrenSpatialGrid.STOREY_CELLS)), 0, storeys - 1)
		var forced: Dictionary = {0: Vector2i.ZERO,
			floori(float(addressed_storey) / 2.0): Vector2i.ZERO}
		if not _force_market_backing_offset(forced, market,
				parcel.stable_id, proposal_origin.y, storeys):
			continue
		for block_value: Variant in (court_fixed_blocks_by_parcel.get(
				parcel.stable_id, {}) as Dictionary).keys():
			forced[int(block_value)] = Vector2i.ZERO
		for block_value: Variant in (forced_offsets_by_parcel.get(
				parcel.stable_id, {}) as Dictionary).keys():
			var block := int(block_value)
			var wanted := (forced_offsets_by_parcel[parcel.stable_id] \
				as Dictionary)[block_value] as Vector2i
			if forced.has(block) and forced[block] != wanted:
				forced.clear()
				break
			forced[block] = wanted
		if forced.is_empty():
			continue
		var offsets := _composition_offsets(grid, base_plate,
			proposal_origin.y, storeys, trial_owners, parcel.stable_id,
			volume.world_seed, forced)
		if offsets.is_empty():
			continue
		solved_offsets_by_parcel[parcel.stable_id] = offsets
		exact_forced_offsets_by_parcel[parcel.stable_id] = forced
		for cell: Vector3i in _segment_cells(base_plate, proposal_origin.y,
				offsets, 0, storeys):
			if not trial_owners.has(cell):
				trial_owners[cell] = {}
			(trial_owners[cell] as Dictionary)[parcel.stable_id] = true
	# These are not guessed clearance halos. Each cell belongs to the exact upper
	# room whose measured support course intersected a fixed hero feature on the
	# preceding pass. Add them only after the provisional two-storey phase solve;
	# the room planner then resolves the optional one-storey crown without
	# sacrificing a required lower market/door/bridge socket in the same band.
	for cell_value: Variant in support_exclusion_cells.keys():
		var support_cell := cell_value as Vector3i
		if not trial_owners.has(support_cell):
			trial_owners[support_cell] = {}
		(trial_owners[support_cell] as Dictionary)[
			WarrenRoomCompositionPlanner.ROOM_SUPPORT_CLEARANCE_OWNER_ID] = true
	var composition := WarrenRoomCompositionPlanner.solve(grid, volume,
		proposals, solved_offsets_by_parcel, exact_forced_offsets_by_parcel,
		market, trial_owners, forced_offsets_by_parcel,
		skywalk_reservations, volume.world_seed,
		enable_paired_registration_relief, stop_after_macro_support)
	if composition.is_empty():
		# The room solver publishes its audit before rejecting a repeated tower.
		# Preserve that structured cause here: the enclosing hero-feature beam can
		# then advance to another market/court state instead of spending twelve
		# landmark palette permutations on the same forced floorplate geometry.
		# This is not a heuristic cutoff; every palette permutation inherits the
		# identical sealed room obligations that produced this failure.
		var failed_tall_tower_ids: Array = WarrenRoomCompositionPlanner.last_audit \
			.get("tall_tower_only_lineage_ids", []) as Array
		var annex_targets := WarrenRoomCompositionPlanner.last_audit.get(
			"tower_relief_annex_target_by_lineage", {}) as Dictionary
		for detail_value: Variant in WarrenRoomCompositionPlanner.last_audit.get(
			"overlong_tower_run_details", []) as Array:
			var detail := detail_value as Dictionary
			var lineage_id := StringName(detail.get("lineage_id", &""))
			if not lineage_id.is_empty() \
					and int(annex_targets.get(lineage_id, 0)) <= 0 \
					and lineage_id not in failed_tall_tower_ids:
				failed_tall_tower_ids.append(lineage_id)
		if not failed_tall_tower_ids.is_empty():
			last_preplan_market_diagnostic[
				"last_exact_court_tall_tower_failure"] = \
				failed_tall_tower_ids.duplicate()
		last_preplan_market_diagnostic[
			"last_exact_room_composition_failure"] = \
			WarrenRoomCompositionPlanner.last_failure
		return false
	if not WarrenRoomCompositionPlanner.lineages_are_supported(
			composition.lineages as Dictionary, grid):
		last_preplan_market_diagnostic[
			"last_exact_room_composition_failure"] = \
			"exact room preflight lost structural bearing"
		return false
	var tall_tower_ids := WarrenRoomCompositionPlanner.last_audit.get(
		"tall_tower_only_lineage_ids", []) as Array
	if not tall_tower_ids.is_empty():
		# This exact feature set has already determined the room composition.
		# The composition audit has discounted genuinely zig-zagging whole-room
		# steps; anything left here is still an unrelieved vertical extrusion.
		# Continue the bounded market/court frontier instead of hoping a late
		# decorative annex can disguise it.
		last_preplan_market_diagnostic[
			"last_exact_court_tall_tower_failure"] = tall_tower_ids.duplicate()
		return false
	# Even the explicit no-court alternative must pass the same exact room/roof
	# transaction. Returning here used to skip every composition preflight and
	# allowed the final compiler to discover an impossible gable only after the
	# bounded feature frontier had closed.
	var court_absent := bool(court_candidate.get("optional_absent", false))
	if not court_absent:
		var court_floors := _courtyard_floor_cells(volume)
		var court_side_mask := _composition_courtyard_side_mask(court_floors,
			composition, court_candidate.body as Dictionary)
		var court_side_count := _side_mask_count(court_side_mask)
		if court_side_count < WarrenSpatialFeatureSolver.MIN_COURT_SIDE_COUNT:
			last_preplan_market_diagnostic[
				"last_exact_court_composition_failure"] = {
					"side_count": court_side_count,
					"side_mask": court_side_mask,
				}
			return false
	var reservation := court_candidate.reservation as Dictionary
	var related_parcels := _skywalk_endpoint_owner_set(reservation)
	var feature_bounds: Array[AABB] = []
	if not court_absent:
		for component_value: Variant in reservation.get("components", []):
			var component := component_value as Dictionary
			var feature_recipe := program.recipe(StringName(component.recipe_id))
			if feature_recipe == null:
				return false
			feature_bounds.append(FabricRecipe.lattice_transform(
				component.origin as Vector3i, int(component.yaw_quarters)) \
				* feature_recipe.local_clearance_bounds)
	var fixed_feature_reservations: Array[Dictionary] = []
	if not market.is_empty():
		fixed_feature_reservations.append(market)
	if not court_absent:
		fixed_feature_reservations.append(reservation)
	for skywalk: Dictionary in skywalk_reservations:
		fixed_feature_reservations.append(skywalk)
	var fixed_feature_result := _feature_visual_bounds(
		fixed_feature_reservations, program)
	if not bool(fixed_feature_result.get("valid", false)):
		return false
	var fixed_feature_bounds: Array[AABB] = []
	fixed_feature_bounds.assign(fixed_feature_result.get("bounds", []) as Array)
	var required_parcels := related_parcels.duplicate()
	for parcel_value: Variant in court_candidate.get(
			"macro_required_parcel_ids", []) as Array:
		required_parcels[StringName(parcel_value)] = true
	var market_backing_id := StringName(market.get("backing_parcel_id", &""))
	if not market_backing_id.is_empty():
		required_parcels[market_backing_id] = true
	for parcel_value: Variant in court_fixed_blocks_by_parcel.keys():
		required_parcels[StringName(parcel_value)] = true
	for skywalk: Dictionary in skywalk_reservations:
		for owner_value: Variant in skywalk.get("owner_parcel_ids", []):
			var owner_id := StringName(owner_value)
			if not String(owner_id).begins_with("spatial.feature.landmark."):
				required_parcels[owner_id] = true
	for owner_value: Variant in skywalk_plan.get(
			"landmark_transition_owner_ids", []):
		required_parcels[StringName(owner_value)] = true
	var displaced_parcels: Dictionary = initial_excluded_set.duplicate()
	var feature_clearance_displaced: Dictionary = \
		initial_feature_excluded_set.duplicate()
	var probe_result := _exact_composition_room_probes(composition, proposals,
		program, volume.world_seed, court_candidate, skywalk_reservations)
	if not bool(probe_result.get("valid", false)):
		if bool(probe_result.get("portal_failure", false)):
			last_preplan_market_diagnostic["last_exact_room_pair_failure"] = \
				probe_result.get("failure", "feature portal binding failed")
		return false
	var room_probes: Array[Dictionary] = []
	room_probes.assign(probe_result.get("probes", []) as Array)
	# The market is not scenery placed beside whichever room survives. Its exact
	# backing cell is a typed portal on a required room. Keep that socket in this
	# same preflight transaction so an optional-crown retry can never shorten the
	# backing course and report a reusable composition.
	if not market.is_empty() and not bool(market.get("optional_absent", false)):
		var market_backing_cell := market.get("backing_cell",
			Vector3i(2147483647, 2147483647, 2147483647)) as Vector3i
		var market_backing_parcel := StringName(market.get(
			"backing_parcel_id", &""))
		var found_market_backing := false
		for record: Dictionary in room_probes:
			var market_room := record.room as WarrenRoomStamp
			if market_room.source_parcel_id == market_backing_parcel \
					and market_room.has_private_cell(market_backing_cell):
				found_market_backing = true
				break
		if not found_market_backing:
			last_preplan_market_diagnostic["last_exact_room_pair_failure"] = \
				"exact composition lost the covered-market backing socket"
			return false
	for record: Dictionary in room_probes:
		var room := record.room as WarrenRoomStamp
		var desired := record.desired as FabricRecipe
		var fallback := record.fallback as FabricRecipe
		# The court endpoint's own portal intentionally meets its authored bridge
		# component. All other rooms still prove clearance from both components.
		if not related_parcels.has(room.source_parcel_id) \
				and _room_recipe_overlaps_any_bounds(room.lattice_origin,
					room.yaw_quarters, desired, feature_bounds) \
				and _room_recipe_overlaps_any_bounds(room.lattice_origin,
					room.yaw_quarters, fallback, feature_bounds):
			if required_parcels.has(room.source_parcel_id):
				last_preplan_market_diagnostic[
					"last_exact_court_required_conflict"] = {
						"parcel": room.source_parcel_id,
						"storey": room.source_storey_index,
						"room_origin": room.lattice_origin,
						"desired_recipe": desired.recipe_id,
						"fallback_recipe": fallback.recipe_id,
					}
				return false
			displaced_parcels[room.source_parcel_id] = true
			feature_clearance_displaced[room.source_parcel_id] = true
	var room_pair_failure := _exact_room_pair_envelope_failure(grid, program,
		room_probes, displaced_parcels, required_parcels)
	if diagnostic_trace_skywalk_timing:
		print("SKYWALK_TIMING exact_room_pairs rooms=", room_probes.size(),
			" feature_displaced=", feature_clearance_displaced.keys(),
			" final_displaced=", displaced_parcels.keys(),
			" failure=", room_pair_failure)
	if not room_pair_failure.is_empty():
		last_preplan_market_diagnostic["last_exact_room_pair_failure"] = \
			room_pair_failure
		return false
	var displaced_before_roof := displaced_parcels.duplicate()
	var room_roof_failure := _exact_room_roof_envelope_failure(grid, program,
		room_probes, displaced_parcels, required_parcels, volume.world_seed)
	if not room_roof_failure.is_empty():
		last_preplan_market_diagnostic["last_exact_room_pair_failure"] = \
			room_roof_failure
		return false
	var displaced_before_support := displaced_parcels.duplicate()
	var room_support_result := _exact_room_support_envelope_result(grid,
		program, room_probes, displaced_parcels, required_parcels,
		fixed_feature_bounds, volume.world_seed)
	if bool(room_support_result.get("retry_optional_crown", false)):
		var next_support_exclusions := support_exclusion_cells.duplicate()
		var prior_exclusion_count := next_support_exclusions.size()
		for cell_value: Variant in room_support_result.get(
				"exclude_cells", []) as Array:
			next_support_exclusions[cell_value as Vector3i] = true
		# Every retry adds at least one exact room cell and there are no more
		# possible retry rooms than probes in this sealed composition. This is a
		# finite constraint-propagation loop, not an unbounded regenerate-until-
		# lucky search.
		if next_support_exclusions.size() == prior_exclusion_count \
				or support_exclusion_depth >= room_probes.size():
			last_preplan_market_diagnostic["last_exact_room_pair_failure"] = \
				"optional room-support crown exclusion did not converge"
			return false
		return _court_candidate_preserves_exact_room_envelopes(grid, volume,
			proposals, program, market, court_candidate,
			base_protected_owners, court_fixed_blocks_by_parcel, skywalk_plan,
			enable_paired_registration_relief, result, stop_after_macro_support,
			next_support_exclusions, support_exclusion_depth + 1)
	var room_support_failure := String(room_support_result.get("failure", ""))
	if not room_support_failure.is_empty():
		last_preplan_market_diagnostic["last_exact_room_pair_failure"] = \
			room_support_failure
		return false
	if displaced_parcels.size() != displaced_before_support.size():
		# Removing a complete optional lineage can expose a different crown on a
		# neighbor.  Re-run the finite roof-domain proof on that final active set;
		# support admission never relies on the pre-displacement verdict.
		room_roof_failure = _exact_room_roof_envelope_failure(grid, program,
			room_probes, displaced_parcels, required_parcels, volume.world_seed)
		if not room_roof_failure.is_empty():
			last_preplan_market_diagnostic["last_exact_room_pair_failure"] = \
				room_roof_failure
			return false
	var displaced_ids: Array[StringName] = []
	displaced_ids.assign(displaced_parcels.keys())
	displaced_ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	var feature_displaced_ids: Array[StringName] = []
	feature_displaced_ids.assign(feature_clearance_displaced.keys())
	feature_displaced_ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	var room_pair_displaced_ids: Array[StringName] = []
	var room_roof_displaced_ids: Array[StringName] = []
	var room_support_displaced_ids: Array[StringName] = []
	for displaced_id: StringName in displaced_ids:
		if not displaced_before_support.has(displaced_id):
			room_support_displaced_ids.append(displaced_id)
		elif not displaced_before_roof.has(displaced_id):
			room_roof_displaced_ids.append(displaced_id)
		elif not feature_clearance_displaced.has(displaced_id):
			room_pair_displaced_ids.append(displaced_id)
	court_candidate["excluded_parcel_ids"] = displaced_ids
	court_candidate["feature_clearance_displaced_parcel_ids"] = \
		feature_displaced_ids
	court_candidate["room_pair_displaced_parcel_ids"] = \
		room_pair_displaced_ids
	court_candidate["room_roof_displaced_parcel_ids"] = \
		room_roof_displaced_ids
	court_candidate["room_support_displaced_parcel_ids"] = \
		room_support_displaced_ids
	var support_exclusion_list: Array[Vector3i] = []
	support_exclusion_list.assign(support_exclusion_cells.keys())
	support_exclusion_list.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		if a.y != b.y:
			return a.y < b.y
		if a.z != b.z:
			return a.z < b.z
		return a.x < b.x)
	court_candidate["room_support_exclusion_cells"] = support_exclusion_list
	court_candidate["room_support_crown_recomposition_count"] = \
		support_exclusion_depth
	result["composition"] = composition
	result["recomposition_required"] = initial_excluded_ids != displaced_ids
	return true


static func _exact_composition_room_probes(composition: Dictionary,
		proposals: Array[Dictionary], program: SettlementFabricProgram,
		world_seed: int, court_candidate: Dictionary,
		skywalk_reservations: Array[Dictionary],
		skip_parcels: Dictionary = {}) -> Dictionary:
	## Rebuild the exact compile-time room stamps and their measured recipe
	## choices for a sealed composition. The exact court preflight and the sealed
	## hero-feature occluder ranking share this so both always see the same rooms
	## and recipes the final compiler will construct.
	var room_probes: Array[Dictionary] = []
	for proposal: Dictionary in proposals:
		var parcel := proposal.parcel as WarrenBuildingParcel
		if skip_parcels.has(parcel.stable_id):
			continue
		var lineage := (composition.lineages as Dictionary).get(
			parcel.stable_id, {}) as Dictionary
		if lineage.is_empty():
			continue
		var proposal_origin := proposal.origin as Vector3i
		var threshold := WarrenParcelConstruction.threshold_cell(parcel)
		var lineage_blocks := lineage.blocks as Array[Dictionary]
		var required_through_block := int(lineage.get(
			"required_through_block", -1))
		for block_index in lineage_blocks.size():
			var block := lineage_blocks[block_index]
			var source_block_index := int(block.get(
				"source_block_index", block_index))
			for storey in range(int(block.start_storey),
					int(block.end_storey)):
				var room_origin := Vector3i((block.origin as Vector3i).x,
					proposal_origin.y + storey \
						* WarrenSpatialGrid.STOREY_CELLS,
					(block.origin as Vector3i).z)
				var addressed := threshold.y >= proposal_origin.y \
					+ storey * WarrenSpatialGrid.STOREY_CELLS \
					and threshold.y < proposal_origin.y \
						+ (storey + 1) * WarrenSpatialGrid.STOREY_CELLS
				var room_door_phase := WarrenParcelConstruction \
					.address_door_phase_for_room(StringName(block.kind), room_origin,
						int(block.yaw_quarters), threshold,
						Vector3i(parcel.frontage_direction.x, 0,
							parcel.frontage_direction.y)) if addressed else 0
				if addressed and room_door_phase < 0:
					return {"valid": false, "portal_failure": false,
						"failure": "recomposed room lost its exact threshold"}
				var building_id := StringName("spatial.%s.part%02d" % [
					parcel.stable_id, block_index])
				var room := WarrenRoomStamp.new(StringName(
					"%s.room%02d" % [building_id,
						storey - int(block.start_storey)]),
					parcel.stable_id, StringName(block.kind), room_origin,
					int(block.yaw_quarters), storey,
					storey == 0 and not block.has(
						"support_parent_lineage_id"), addressed,
					threshold if addressed else Vector3i(2147483647,
						2147483647, 2147483647),
					Vector3i(parcel.frontage_direction.x, 0,
						parcel.frontage_direction.y), int(proposal.roof_feature),
					&"", -1, room_door_phase)
				if not room.add_private_cells(
						WarrenRoomStamp.expected_private_cells(
							StringName(block.kind), room_origin,
							int(block.yaw_quarters))):
					return {"valid": false, "portal_failure": false,
						"failure": "room stamp cells could not be recorded"}
				room_probes.append({"room": room, "building_id": building_id,
					"lineage_id": parcel.stable_id,
					"source_block_index": source_block_index,
					"optional_crown": source_block_index \
						> required_through_block})
	var portal_result := _exact_preflight_feature_portal_masks(room_probes,
		court_candidate, skywalk_reservations)
	if not bool(portal_result.get("valid", false)):
		return {"valid": false, "portal_failure": true,
			"failure": String(portal_result.get("failure",
				"feature portal binding failed"))}
	var portal_masks := portal_result.get("masks", {}) as Dictionary
	for record: Dictionary in room_probes:
		var room := record.room as WarrenRoomStamp
		var feature_portal_mask := int(portal_masks.get(room.stable_id, 0))
		var desired := program.recipe(
			WarrenSpatialFabricCompiler._room_recipe_id(room,
				world_seed, true, feature_portal_mask))
		var fallback := program.recipe(
			WarrenSpatialFabricCompiler._room_recipe_id(room,
				world_seed, false, feature_portal_mask))
		if desired == null or fallback == null:
			return {"valid": false, "portal_failure": false,
				"failure": "composed room has no measured recipe"}
		record["desired"] = desired
		record["fallback"] = fallback
	return {"valid": true, "portal_failure": false, "probes": room_probes}


static func _exact_preflight_feature_portal_masks(
		room_probes: Array[Dictionary], court_candidate: Dictionary,
		skywalk_reservations: Array[Dictionary]) -> Dictionary:
	## Resolve the same room-face portal masks that final feature commitment will
	## record. Measured portal shells can have a different clearance envelope from
	## their closed facade, so testing an ordinary recipe here would make the
	## feature beam accept a state that the final compiler must reject.
	var room_by_id: Dictionary = {}
	var rooms_by_parcel: Dictionary = {}
	for record: Dictionary in room_probes:
		var room := record.get("room") as WarrenRoomStamp
		if room == null:
			return {"valid": false, "failure": "room preflight lacks a stamp"}
		room_by_id[room.stable_id] = room
		if not rooms_by_parcel.has(room.source_parcel_id):
			rooms_by_parcel[room.source_parcel_id] = \
				[] as Array[WarrenRoomStamp]
		(rooms_by_parcel[room.source_parcel_id] \
			as Array[WarrenRoomStamp]).append(room)
	var reservations: Array[Dictionary] = []
	if not bool(court_candidate.get("optional_absent", false)):
		reservations.append(court_candidate.get("reservation", {}) as Dictionary)
	reservations.append_array(skywalk_reservations)
	var masks: Dictionary = {}
	for reservation: Dictionary in reservations:
		var owner_ids := reservation.get("owner_parcel_ids", []) as Array
		var endpoints := reservation.get("owner_endpoints", []) as Array
		if owner_ids.size() != endpoints.size() or owner_ids.is_empty():
			return {"valid": false,
				"failure": "feature endpoint owners differ from endpoint cells"}
		for endpoint_index in owner_ids.size():
			var owner_id := StringName(owner_ids[endpoint_index])
			if String(owner_id).begins_with("spatial.feature.landmark."):
				continue
			var endpoint := endpoints[endpoint_index] as Dictionary
			var endpoint_cell := endpoint.get("cell", Vector3i(2147483647,
				2147483647, 2147483647)) as Vector3i
			var endpoint_facing := endpoint.get("facing",
				Vector3i.ZERO) as Vector3i
			var matches: Array[WarrenRoomStamp] = []
			for room: WarrenRoomStamp in (rooms_by_parcel.get(owner_id,
					[] as Array[WarrenRoomStamp]) as Array[WarrenRoomStamp]):
				if room.has_private_cell(endpoint_cell):
					matches.append(room)
			if matches.size() != 1:
				return {"valid": false,
					"failure": "feature endpoint %s/%s resolves to %d rooms" % [
						owner_id, endpoint_cell, matches.size()]}
			var room := matches[0]
			if not WarrenSpatialFabricCompiler._record_feature_portal(masks,
					room_by_id, room.stable_id, endpoint_cell, endpoint_facing):
				return {"valid": false,
					"failure": WarrenSpatialFabricCompiler.last_failure}
	return {"valid": true, "masks": masks}


static func _exact_room_pair_envelope_failure(grid: WarrenSpatialGrid,
		program: SettlementFabricProgram, room_probes: Array[Dictionary],
		displaced_parcels: Dictionary,
		required_parcels: Dictionary = {}) -> String:
	## Mirror the room compiler's measured phase-A/phase-B transaction while the
	## landmark/court beam can still choose another candidate.  The older preflight
	## checked rooms only against the court components; an embedded landmark could
	## therefore force two unrelated upper shells into one another, pass the beam,
	## and fail only after every alternative had been discarded.
	var ordered := room_probes.duplicate(true) as Array[Dictionary]
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var left := a.room as WarrenRoomStamp
		var right := b.room as WarrenRoomStamp
		if left.lattice_origin.y != right.lattice_origin.y:
			return left.lattice_origin.y < right.lattice_origin.y
		if left.source_storey_index != right.source_storey_index:
			return left.source_storey_index < right.source_storey_index
		return String(left.stable_id) < String(right.stable_id))
	# `program` and `grid` remain explicit inputs because this preflight belongs to
	# the same measured construction transaction, but it must not call
	# SettlementFabricPlan.add_unit(): at this stage bearing parents have not yet
	# been committed. Support is proved by the sealed support DAG later; here we
	# compare only authored visual envelopes and exact room-to-room seam facts.
	if grid == null or program == null:
		return "missing exact room-pair construction context"
	var prior_unit_by_cell: Dictionary = {}
	var prior_records: Dictionary = {}
	for record: Dictionary in ordered:
		var room := record.room as WarrenRoomStamp
		if displaced_parcels.has(room.source_parcel_id):
			continue
		var desired := record.desired as FabricRecipe
		var fallback := record.fallback as FabricRecipe
		var desired_bounds := FabricRecipe.lattice_transform(
			room.lattice_origin, room.yaw_quarters) \
			* desired.local_clearance_bounds
		# This preflight runs before recomposed PRIVATE_VOLUME cells and their
		# PARTY_WALL faces are committed to the grid. Recover that future typed
		# seam losslessly from the exact room stamps: face-adjacent occupied cells
		# are a real shared wall/bearing plane. Diagonal or merely nearby rooms do
		# not enter this set, so the detached upper-shell collision that motivated
		# the gate remains unrelated and is still rejected.
		var seam_set: Dictionary = {}
		for cell: Vector3i in room.private_cells:
			for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
					Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD,
					Vector3i.BACK]:
				var prior_id := StringName(prior_unit_by_cell.get(
					cell + direction, &""))
				if not prior_id.is_empty():
					seam_set[prior_id] = true
		var edge_offsets: Array[Vector3i] = []
		for first_axis in 3:
			for second_axis in range(first_axis + 1, 3):
				for first_sign in [-1, 1]:
					for second_sign in [-1, 1]:
						var offset := Vector3i.ZERO
						offset[first_axis] = first_sign
						offset[second_axis] = second_sign
						edge_offsets.append(offset)
		for cell: Vector3i in room.private_cells:
			for offset: Vector3i in edge_offsets:
				var prior_id := StringName(prior_unit_by_cell.get(
					cell + offset, &""))
				if prior_id.is_empty() or seam_set.has(prior_id):
					continue
				var prior_record := prior_records.get(prior_id, {}) as Dictionary
				if not prior_record.is_empty() \
						and SettlementFabricPlan._aabb_overlaps_volume(
							desired_bounds, prior_record.bounds as AABB) \
						and SettlementFabricPlan._is_edge_nick(
							desired_bounds, prior_record.bounds as AABB):
					seam_set[prior_id] = true
		var unit_id := StringName("spatial.fabric.%s" % room.stable_id)
		var desired_rejection := _room_pair_bounds_rejection(unit_id,
			desired_bounds, seam_set, prior_records)
		var selected_recipe := desired
		var selected_bounds := desired_bounds
		if not desired_rejection.is_empty():
			if fallback.recipe_id == desired.recipe_id:
				var displaced := _displace_optional_room_pair_parcel(room,
					desired_rejection, prior_records, displaced_parcels,
					required_parcels)
				if displaced.is_empty():
					return "room %s: %s" % [room.stable_id,
						_room_pair_rejection_text(desired_rejection)]
				return _exact_room_pair_envelope_failure(grid, program,
					room_probes, displaced_parcels, required_parcels)
			selected_bounds = FabricRecipe.lattice_transform(
				room.lattice_origin, room.yaw_quarters) \
				* fallback.local_clearance_bounds
			var fallback_rejection := _room_pair_bounds_rejection(unit_id,
				selected_bounds, seam_set, prior_records)
			if not fallback_rejection.is_empty():
				var displaced := _displace_optional_room_pair_parcel(room,
					fallback_rejection, prior_records, displaced_parcels,
					required_parcels)
				if displaced.is_empty():
					return "room %s desired=%s fallback=%s" % [room.stable_id,
						_room_pair_rejection_text(desired_rejection),
						_room_pair_rejection_text(fallback_rejection)]
				return _exact_room_pair_envelope_failure(grid, program,
					room_probes, displaced_parcels, required_parcels)
			selected_recipe = fallback
		prior_records[unit_id] = {"recipe_id": selected_recipe.recipe_id,
			"bounds": selected_bounds,
			"source_parcel_id": room.source_parcel_id}
		for cell: Vector3i in room.private_cells:
			prior_unit_by_cell[cell] = unit_id
	return ""


static func _exact_room_roof_envelope_failure(grid: WarrenSpatialGrid,
		program: SettlementFabricProgram, room_probes: Array[Dictionary],
		displaced_parcels: Dictionary, required_parcels: Dictionary,
		world_seed: int) -> String:
	## Keep every future roof closure domain non-empty while the source-plan beam
	## can still yield a complete optional parcel. This is the same finite-domain
	## predicate the final compiler uses; no guessed gable halo or asset-specific
	## exception is introduced here. If a mandatory shell and mandatory roof have
	## no compatible authored phases, the feature state itself is rejected.
	if grid == null or program == null:
		return "missing exact room/roof construction context"
	for _pass in range(room_probes.size() + 1):
		var active_rooms: Array[WarrenRoomStamp] = []
		var parcel_by_room_id: Dictionary = {}
		for record: Dictionary in room_probes:
			var room := record.room as WarrenRoomStamp
			if room == null or displaced_parcels.has(room.source_parcel_id):
				continue
			active_rooms.append(room)
			parcel_by_room_id[room.stable_id] = room.source_parcel_id
		var closures := WarrenSpatialFabricCompiler \
			.required_roof_closure_options_for_rooms(grid, active_rooms,
				program, world_seed)
		if diagnostic_trace_skywalk_timing:
			print("SKYWALK_TIMING exact_room_roofs pass=", _pass,
				" rooms=", active_rooms.size(), " closures=", closures.size(),
				" displaced=", displaced_parcels.keys())
		var displaced_this_pass := false
		for record: Dictionary in room_probes:
			var room := record.room as WarrenRoomStamp
			if room == null or displaced_parcels.has(room.source_parcel_id):
				continue
			var desired := record.desired as FabricRecipe
			var fallback := record.fallback as FabricRecipe
			var own_domain_empty := false
			for closure: Dictionary in closures:
				if StringName(closure.owner_room_id) == room.stable_id \
						and (closure.options as Array).is_empty():
					own_domain_empty = true
					break
			var desired_conflict := StringName("%s/no-public-safe-roof" \
				% room.stable_id) if own_domain_empty else \
				WarrenSpatialFabricCompiler._room_required_roof_conflict(room,
					desired, closures, program)
			var fallback_conflict := StringName("%s/no-public-safe-roof" \
				% room.stable_id) if own_domain_empty else \
				WarrenSpatialFabricCompiler._room_required_roof_conflict(room,
					fallback, closures, program)
			if diagnostic_trace_skywalk_timing \
					and (not desired_conflict.is_empty() \
						or not fallback_conflict.is_empty()):
				print("SKYWALK_TIMING exact_room_roof_conflict room=",
					room.stable_id, " parcel=", room.source_parcel_id,
					" desired=", desired_conflict,
					" fallback=", fallback_conflict)
			if desired_conflict.is_empty() or fallback_conflict.is_empty():
				continue
			var chosen_parcel := &""
			if not required_parcels.has(room.source_parcel_id):
				chosen_parcel = room.source_parcel_id
			else:
				var conflict_owners: Array[StringName] = []
				for conflict: StringName in [desired_conflict,
						fallback_conflict]:
					var conflict_text := String(conflict)
					var separator := conflict_text.find("/")
					var owner_id := StringName(conflict_text.substr(0,
						separator if separator >= 0 else conflict_text.length()))
					if not owner_id.is_empty() and owner_id not in conflict_owners:
						conflict_owners.append(owner_id)
				conflict_owners.sort_custom(func(a: StringName,
						b: StringName) -> bool:
					return String(a) < String(b))
				for owner_id: StringName in conflict_owners:
					var owner_parcel := StringName(parcel_by_room_id.get(
						owner_id, &""))
					if not owner_parcel.is_empty() \
							and not required_parcels.has(owner_parcel):
						chosen_parcel = owner_parcel
						break
			if chosen_parcel.is_empty():
				return "room %s desired=%s fallback=%s" % [room.stable_id,
					desired_conflict, fallback_conflict]
			displaced_parcels[chosen_parcel] = true
			displaced_this_pass = true
			break
		if not displaced_this_pass:
			return ""
	return "room/roof clearance disposition did not converge"


static func _exact_room_support_envelope_result(grid: WarrenSpatialGrid,
		program: SettlementFabricProgram, room_probes: Array[Dictionary],
		displaced_parcels: Dictionary, required_parcels: Dictionary,
		fixed_feature_bounds: Array[AABB], world_seed: int) -> Dictionary:
	## A room overhang and its measured bracket/arcade course are one structural
	## proposal.  Prove that complete support envelope while the source-plan beam
	## can still yield an optional parcel; discovering the conflict after rooms
	## and a required market have both committed leaves no valid rollback.
	if grid == null or program == null:
		return {"failure": "missing exact room-support construction context"}
	var probe_by_room_id: Dictionary = {}
	for record: Dictionary in room_probes:
		var recorded_room := record.get("room") as WarrenRoomStamp
		if recorded_room != null:
			probe_by_room_id[recorded_room.stable_id] = record
	for _pass in range(room_probes.size() + 1):
		var rooms_by_source: Dictionary = {}
		for record: Dictionary in room_probes:
			var room := record.room as WarrenRoomStamp
			if room == null or displaced_parcels.has(room.source_parcel_id):
				continue
			if not rooms_by_source.has(room.source_parcel_id):
				rooms_by_source[room.source_parcel_id] = \
					[] as Array[WarrenRoomStamp]
			(rooms_by_source[room.source_parcel_id] \
				as Array[WarrenRoomStamp]).append(room)
		var source_ids: Array[StringName] = []
		source_ids.assign(rooms_by_source.keys())
		source_ids.sort_custom(func(a: StringName, b: StringName) -> bool:
			return String(a) < String(b))
		var displaced_this_pass := false
		for source_id: StringName in source_ids:
			var rooms := rooms_by_source[source_id] as Array[WarrenRoomStamp]
			rooms.sort_custom(func(a: WarrenRoomStamp,
					b: WarrenRoomStamp) -> bool:
				return a.source_storey_index < b.source_storey_index)
			for index in range(1, rooms.size()):
				var lower := rooms[index - 1]
				var upper := rooms[index]
				var geometry := WarrenSpatialFeatureSolver \
					._shallow_room_overhang_geometry(lower, upper, grid)
				if geometry.is_empty() or WarrenSpatialFeatureSolver \
						._cantilever_is_directly_borne(upper, geometry, grid):
					continue
				var records: Array[Dictionary] = []
				var public_arcade := WarrenSpatialFeatureSolver \
					._public_arcade_geometry(upper, geometry, grid)
				if not public_arcade.is_empty():
					for course_top_value: Variant in public_arcade.get(
							"support_course_top_cells", [upper.lattice_origin.y]):
						var course_geometry := public_arcade.duplicate(true)
						course_geometry["support_origin_y"] = int(
							course_top_value)
						var arcade_record := WarrenSpatialFeatureSolver \
							._arcade_overhang_support_record(upper,
								course_geometry)
						if arcade_record.is_empty():
							records.clear()
							break
						records.append(arcade_record)
				else:
					records = WarrenSpatialFeatureSolver \
						._shallow_cantilever_support_records(
							WarrenSpatialFeatureSolver._cantilever_support_records(
								upper, geometry, grid))
				var conflict := records.is_empty()
				for support_record: Dictionary in records:
					var support_recipe := program.recipe(StringName(
						support_record.recipe_id))
					if support_recipe == null:
						conflict = true
						break
					var support_bounds := FabricRecipe.lattice_transform(
						support_record.origin as Vector3i,
						int(support_record.yaw_quarters)) \
						* support_recipe.local_clearance_bounds
					for feature_bounds: AABB in fixed_feature_bounds:
						if SettlementFabricPlan._aabb_overlaps_volume(
								support_bounds, feature_bounds):
							conflict = true
							break
					if conflict:
						break
				if not conflict:
					continue
				if required_parcels.has(source_id):
					var upper_probe := probe_by_room_id.get(
						upper.stable_id, {}) as Dictionary
					if bool(upper_probe.get("optional_crown", false)):
						return {"failure": "", "retry_optional_crown": true,
							"room_id": upper.stable_id,
							"lineage_id": source_id,
							"source_block_index": int(upper_probe.get(
								"source_block_index", -1)),
							"exclude_cells": upper.private_cells.duplicate()}
					return {"failure": (
						"required room %s has no feature-clear support course" \
							% upper.stable_id)}
				displaced_parcels[source_id] = true
				displaced_this_pass = true
				break
			if displaced_this_pass:
				break
		if not displaced_this_pass:
			return {"failure": ""}
	return {"failure": "room-support clearance disposition did not converge"}


static func _room_pair_bounds_rejection(unit_id: StringName, bounds: AABB,
		seam_ids: Dictionary, prior_records: Dictionary) -> Dictionary:
	var prior_ids: Array[StringName] = []
	prior_ids.assign(prior_records.keys())
	prior_ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	for prior_id: StringName in prior_ids:
		if seam_ids.has(prior_id):
			continue
		var prior := prior_records[prior_id] as Dictionary
		var prior_bounds := prior.bounds as AABB
		if SettlementFabricPlan._aabb_overlaps_volume(bounds, prior_bounds):
			return {"unit_id": unit_id, "bounds": bounds,
				"prior_id": prior_id, "prior_bounds": prior_bounds}
	return {}


static func _room_pair_rejection_text(rejection: Dictionary) -> String:
	if rejection.is_empty():
		return ""
	return "visual envelope of %s %s intersects unrelated unit %s %s" % [
		rejection.unit_id, rejection.bounds, rejection.prior_id,
		rejection.prior_bounds]


static func _displace_optional_room_pair_parcel(room: WarrenRoomStamp,
		rejection: Dictionary, prior_records: Dictionary,
		displaced_parcels: Dictionary, required_parcels: Dictionary) -> StringName:
	## A full optional parcel may yield, never an individual storey or mesh. This
	## keeps the structural/support transaction coherent while allowing the dense
	## packer to reject one bad neighbor relation instead of abandoning an
	## otherwise valid embedded landmark district.
	var current_parcel := room.source_parcel_id
	var prior := prior_records.get(StringName(rejection.prior_id), {}) \
		as Dictionary
	var prior_parcel := StringName(prior.get("source_parcel_id", &""))
	var chosen := &""
	if not required_parcels.has(current_parcel):
		chosen = current_parcel
	elif not prior_parcel.is_empty() and not required_parcels.has(prior_parcel):
		chosen = prior_parcel
	if chosen.is_empty():
		return &""
	displaced_parcels[chosen] = true
	return chosen


static func _room_recipe_overlaps_any_bounds(origin: Vector3i, yaw: int,
		recipe: FabricRecipe, other_bounds: Array[AABB]) -> bool:
	var bounds := FabricRecipe.lattice_transform(origin, yaw) \
		* recipe.local_clearance_bounds
	for other: AABB in other_bounds:
		if SettlementFabricPlan._aabb_overlaps_volume(bounds, other):
			return true
	return false


static func _feature_visual_bounds(reservations: Array[Dictionary],
		program: SettlementFabricProgram) -> Dictionary:
	## Compile fixed feature envelopes from the same component records consumed
	## by final construction. Prefab landmarks predate the multi-component record
	## shape, so their top-level recipe/origin/yaw is the equivalent one-component
	## transaction. No clearance raster is converted back into approximate bounds.
	if program == null:
		return {"valid": false, "bounds": [] as Array[AABB]}
	var out: Array[AABB] = []
	for reservation: Dictionary in reservations:
		if reservation.is_empty() \
				or bool(reservation.get("optional_absent", false)):
			continue
		var components: Array[Dictionary] = []
		components.assign(reservation.get("components", []) as Array)
		if components.is_empty() and reservation.has("recipe_id"):
			components.append({
				"recipe_id": StringName(reservation.get("recipe_id", &"")),
				"origin": reservation.get("origin", Vector3i.ZERO),
				"yaw_quarters": int(reservation.get("yaw_quarters", 0)),
			})
		for component: Dictionary in components:
			var recipe := program.recipe(StringName(component.get(
				"recipe_id", &"")))
			if recipe == null:
				return {"valid": false, "bounds": [] as Array[AABB]}
			out.append(FabricRecipe.lattice_transform(component.get(
				"origin", Vector3i.ZERO) as Vector3i,
				int(component.get("yaw_quarters", 0))) \
				* recipe.local_clearance_bounds)
	return {"valid": true, "bounds": out}


static func _scale_profile_for_volume(volume: WarrenVolumePlan) \
		-> WarrenVillageScaleProfile:
	if volume == null:
		return null
	return WarrenVillageScaleProfile.for_id(StringName(volume.mass_context.get(
		&"scale_profile_id", WarrenVillageScaleProfile.LARGE)))


static func _reserve_market_preplan(grid: WarrenSpatialGrid,
		market: Dictionary) -> bool:
	var feature_id := StringName(market.feature_id)
	var body: Array[Vector3i] = []
	body.assign((market.reserved_cells as Dictionary).keys())
	var clearance_only: Array[Vector3i] = []
	for cell_value: Variant in (market.visual_clearance_cells \
			as Dictionary).keys():
		if not (market.reserved_cells as Dictionary).has(cell_value):
			clearance_only.append(cell_value as Vector3i)
	var public_cells: Array[Vector3i] = []
	public_cells.assign((market.public_cells as Dictionary).keys())
	var new_air: Dictionary = {}
	for floor: Vector3i in public_cells:
		for y_offset in WarrenVolumePlan.HEADROOM_BANDS:
			var air := floor + Vector3i.UP * y_offset
			if grid.use_at(air) != WarrenSpatialGrid.Use.PUBLIC_AIR:
				new_air[air] = true
	var new_air_cells: Array[Vector3i] = []
	new_air_cells.assign(new_air.keys())
	var bearing_cells: Array[Vector3i] = []
	bearing_cells.assign((market.bearing_cells as Dictionary).keys())
	var tx := grid.begin_transaction(feature_id)
	if not tx.reserve(body, WarrenSpatialGrid.Reservation.FEATURE \
			| WarrenSpatialGrid.Reservation.VISUAL_CLEARANCE, feature_id) \
			or not new_air_cells.is_empty() and (not tx.require_use(new_air_cells,
				[WarrenSpatialGrid.Use.OUTSIDE,
					WarrenSpatialGrid.Use.ALLOCATABLE] as Array[int]) \
				or not tx.reserve(new_air_cells,
					WarrenSpatialGrid.Reservation.PUBLIC_CLEARANCE, feature_id) \
				or not tx.assign_use(new_air_cells,
					WarrenSpatialGrid.Use.PUBLIC_AIR, feature_id)) \
			or not clearance_only.is_empty() and not tx.reserve(clearance_only,
				WarrenSpatialGrid.Reservation.VISUAL_CLEARANCE, feature_id) \
			or not tx.reserve(public_cells,
				WarrenSpatialGrid.Reservation.CONSTRUCTION_SEAM, feature_id) \
			or not tx.reserve(bearing_cells,
				WarrenSpatialGrid.Reservation.TERRAIN_BEARING, feature_id):
		return false
	for floor: Vector3i in public_cells:
		var existing := grid.face_claim(floor, Vector3i.DOWN)
		if existing.is_empty() and not tx.claim_face(floor, Vector3i.DOWN,
				WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR, feature_id):
			return false
	return tx.commit()


static func _yaw_for_direction(local_direction: Vector3i,
		target_direction: Vector3i) -> int:
	for yaw in 4:
		if FabricRecipe.transform_direction(local_direction, yaw) \
				== target_direction:
			return yaw
	return -1


static func _cells_fit_grid(grid: WarrenSpatialGrid, cells: Dictionary) -> bool:
	for cell_value: Variant in cells.keys():
		if not grid.contains(cell_value as Vector3i):
			return false
	return true


static func _market_public_aisle(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan, origin: Vector3i, yaw: int,
		covered_local_cells: Array[Vector3i], body: Dictionary,
		protected_owners: Dictionary,
		backing_parcel_id: StringName) -> Dictionary:
	## The four central cells are the browsable space beneath the canopy. When
	## that bay does not directly meet two lanes of one route episode, extend a
	## short two-cell-wide negative-space throat. This keeps the market atomic and
	## player-width without requiring the macro route to land on one exact phase.
	var covered: Dictionary = {}
	for local_cell: Vector3i in covered_local_cells:
		covered[FabricRecipe.transform_cell(local_cell, origin, yaw)] = true
	var directions: Array[Vector3i] = [Vector3i.BACK, Vector3i.RIGHT,
		Vector3i.LEFT, Vector3i.FORWARD]
	for extension_length in range(_market_aisle_extension_limit(volume) + 1):
		var direction_count := 1 if extension_length == 0 else directions.size()
		for direction_index in direction_count:
			var cells := covered.duplicate()
			if extension_length > 0:
				var local_direction := directions[direction_index]
				for step in range(1, extension_length + 1):
					var row: Array[Vector3i] = []
					if local_direction == Vector3i.BACK:
						row = [Vector3i(-1, 0, step), Vector3i(0, 0, step)]
					elif local_direction == Vector3i.FORWARD:
						row = [Vector3i(-1, 0, -1 - step),
							Vector3i(0, 0, -1 - step)]
					elif local_direction == Vector3i.RIGHT:
						row = [Vector3i(step, 0, -1), Vector3i(step, 0, 0)]
					else:
						row = [Vector3i(-1 - step, 0, -1),
							Vector3i(-1 - step, 0, 0)]
					for local_cell: Vector3i in row:
						cells[FabricRecipe.transform_cell(local_cell, origin,
							yaw)] = true
			if not _market_aisle_cells_fit(grid, volume, cells, body,
					protected_owners, backing_parcel_id):
				continue
			var entrance := _market_street_connection(volume, grid, cells)
			if int(entrance.max_episode_width) < 2:
				continue
			var new_public_count := 0
			for cell_value: Variant in cells.keys():
				new_public_count += int(grid.use_at(cell_value as Vector3i) \
					!= WarrenSpatialGrid.Use.PUBLIC_AIR)
			return {"cells": cells, "covered_cells": covered,
				"new_public_cell_count": new_public_count,
				"entrance_edge_count": int(entrance.edge_count),
				"entrance_width": int(entrance.max_episode_width),
				"extension_length": extension_length}
	return {}


static func _market_aisle_extension_limit(volume: WarrenVolumePlan) -> int:
	## A market remains one atomic covered chamber, but larger towns may reach it
	## through a longer two-lane alley cut from the inhabited mass. The extension
	## is still exact public floor/headroom and is evaluated by the same shelter
	## rays; it is not an open plaza or a decorative platform.
	var profile := _scale_profile_for_volume(volume)
	if profile == null:
		return 3
	match profile.scale_id:
		WarrenVillageScaleProfile.LARGE:
			return 5
		WarrenVillageScaleProfile.GRAND:
			return 6
		_:
			return 3


static func _market_aisle_cells_fit(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan, cells: Dictionary, body: Dictionary,
		protected_owners: Dictionary,
		backing_parcel_id: StringName) -> bool:
	for value: Variant in cells.keys():
		var cell := value as Vector3i
		var upper := cell + Vector3i.UP
		var use_value := grid.use_at(cell)
		var upper_use := grid.use_at(upper)
		if body.has(cell) or body.has(upper) or use_value not in [
				WarrenSpatialGrid.Use.OUTSIDE,
				WarrenSpatialGrid.Use.ALLOCATABLE] or upper_use not in [
				WarrenSpatialGrid.Use.OUTSIDE,
				WarrenSpatialGrid.Use.ALLOCATABLE] \
				or (protected_owners.get(cell, {}) as Dictionary).has(
					backing_parcel_id) \
				or (protected_owners.get(upper, {}) as Dictionary).has(
					backing_parcel_id) \
				or (grid.reservation_bits_at(cell) \
					| grid.reservation_bits_at(upper)) & (
						WarrenSpatialGrid.Reservation.FEATURE \
						| WarrenSpatialGrid.Reservation.VISUAL_CLEARANCE) != 0:
			return false
		var column := Vector2i(floori(float(cell.x) / 2.0),
			floori(float(cell.z) / 2.0))
		if not volume.envelope.contains_column(column) \
				or volume.envelope.ground_at(column) != cell.y:
			return false
	return true


static func _market_street_connection(volume: WarrenVolumePlan,
		grid: WarrenSpatialGrid, market_cells: Dictionary) -> Dictionary:
	var episode_owners: Dictionary = {}
	for index in volume.walk_cells.size():
		var owner_id := StringName("walk.%02d" % index)
		for cell: Vector3i in _fine_square(volume.walk_cells[index]):
			if not episode_owners.has(cell):
				episode_owners[cell] = [] as Array[StringName]
			(episode_owners[cell] as Array[StringName]).append(owner_id)
	for index in volume.transitions.size():
		var transition := volume.transitions[index]
		if not transition.is_vertical():
			continue
		var owner_id := StringName("transition.%02d" % index)
		for cell: Vector3i in transition.surface_cells():
			if not episode_owners.has(cell):
				episode_owners[cell] = [] as Array[StringName]
			(episode_owners[cell] as Array[StringName]).append(owner_id)
	var seams_by_episode: Dictionary = {}
	var edge_count := 0
	for cell_value: Variant in market_cells.keys():
		var cell := cell_value as Vector3i
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.FORWARD, Vector3i.BACK]:
			var neighbor := cell + direction
			if market_cells.has(neighbor) \
					or grid.use_at(neighbor) != WarrenSpatialGrid.Use.PUBLIC_AIR:
				continue
			var floor := grid.face_claim(neighbor, Vector3i.DOWN)
			if floor.is_empty() or int(floor.kind) \
					!= WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR:
				continue
			edge_count += 1
			for owner_id: StringName in episode_owners.get(neighbor,
					[] as Array[StringName]):
				if not seams_by_episode.has(owner_id):
					seams_by_episode[owner_id] = {}
				(seams_by_episode[owner_id] as Dictionary)["%s>%s" % [cell,
					neighbor]] = true
	var max_width := 0
	for seams_value: Variant in seams_by_episode.values():
		max_width = maxi(max_width, (seams_value as Dictionary).size())
	return {"edge_count": edge_count, "max_episode_width": max_width}


static func _maze_connectivity_skywalk_plan(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan, parcel_plan: WarrenParcelPlan,
		proposals: Array[Dictionary], program: SettlementFabricProgram,
		protected_owners: Dictionary, public_air: Dictionary,
		profile: WarrenVillageScaleProfile) -> Dictionary:
	## Topology-first occupied-link stage. Parcel dimensions, storeys and authored
	## construction recipes already exist, but generic room reservations have not
	## consumed the air between them. Every candidate is produced by the common
	## WarrenAssetCompiler from two semantic room sockets and is later committed
	## by WarrenSpatialFeatureSolver as PRIVATE_VOLUME with two independently
	## terrain-reaching building owners.
	var empty := {
		"reservations": [] as Array[Dictionary],
		"selected_candidates": [] as Array[Dictionary],
		"forced_offsets": {}, "priority_cells": {},
		"candidate_count": 0, "target_count": 2,
		"unique_route_cover_count": 0,
		"marginal_route_cover_count": 0,
		"landmark_coverage_count": 0,
		"endpoint_count": 0, "aligned_pair_count": 0,
		"component_count": 0, "body_fit_count": 0,
		"clearance_grid_fit_count": 0,
		"clearance_feature_fit_count": 0,
		"reservation_fit_count": 0, "route_fit_count": 0,
		"fit_rejection_samples": [] as Array[Dictionary],
	}
	if grid == null or volume == null or parcel_plan == null or program == null:
		return empty
	var target := 2 if profile == null else mini(3,
		maxi(2, profile.skywalk_range.x))
	empty["target_count"] = target
	var proposal_by_id: Dictionary = {}
	for proposal: Dictionary in proposals:
		var proposal_parcel := proposal.get("parcel") as WarrenBuildingParcel
		if proposal_parcel != null:
			proposal_by_id[proposal_parcel.stable_id] = proposal
	var cache: Dictionary = {}
	var candidates: Array[Dictionary] = []
	for left_index in parcel_plan.parcels.size():
		var left := parcel_plan.parcels[left_index]
		for right_index in range(left_index + 1, parcel_plan.parcels.size()):
			var right := parcel_plan.parcels[right_index]
			if not WarrenAssetCompiler.parcels_may_form_skywalk(left, right,
					program, cache):
				continue
			var reservation := WarrenAssetCompiler.skywalk_reservation(left,
				right, program, public_air, cache)
			if reservation.is_empty():
				continue
			reservation["owner_parcel_ids"] = [left.stable_id,
				right.stable_id] as Array[StringName]
			reservation["feature_id"] = StringName(
				"spatial.skywalk.plan.%s.%s" % [left.stable_id,
					right.stable_id])
			var body := reservation.reserved_cells as Dictionary
			var components: Array[Dictionary] = []
			components.assign(reservation.components as Array)
			var clearance := _skywalk_visual_clearance_cells(components,
				program)
			if body.is_empty() or clearance.is_empty() \
					or not _skywalk_body_fits_grid(grid, body) \
					or not _skywalk_clearance_fits_grid(grid, clearance) \
					or not _skywalk_clearance_fits_protected(clearance,
						protected_owners):
				continue
			var lower_cover := _lower_public_cover(body, public_air)
			if lower_cover < 2:
				continue
			var forced_offsets: Dictionary = {}
			var priority_cells: Dictionary = {}
			var endpoints := reservation.owner_endpoints as Array
			var owners := reservation.owner_parcel_ids as Array
			var endpoint_blocks_valid := endpoints.size() == 2 \
				and owners.size() == 2
			for endpoint_index in mini(endpoints.size(), owners.size()):
				var owner_id := StringName(owners[endpoint_index])
				var endpoint := endpoints[endpoint_index] as Dictionary
				endpoint["owner_id"] = owner_id
				var proposal := proposal_by_id.get(owner_id, {}) as Dictionary
				if proposal.is_empty():
					endpoint_blocks_valid = false
					break
				var block := _proposal_block_for_cell(proposal,
					endpoint.cell as Vector3i)
				if block < 0 or not _forced_block_fits(grid, proposal, block,
						Vector2i.ZERO):
					endpoint_blocks_valid = false
					break
				forced_offsets[owner_id] = {block: Vector2i.ZERO}
				for cell_value: Variant in _forced_block_cells(proposal, block,
						Vector2i.ZERO).keys():
					priority_cells[cell_value] = owner_id
			if not endpoint_blocks_valid:
				continue
			reservation["owner_endpoints"] = endpoints
			reservation["visual_clearance_cells"] = clearance
			var endpoint_owners := {left.stable_id: true,
				right.stable_id: true}
			var pair_key := "%s|%s" % [left.stable_id, right.stable_id]
			candidates.append({
				"reservation": reservation,
				"body": body,
				"clearance": clearance,
				"forced_offsets": forced_offsets,
				"priority_cells": priority_cells,
				"pair_key": pair_key,
				"endpoint_pair_key": _skywalk_endpoint_pair_key(reservation),
				"blocker_count": _skywalk_blocker_count(clearance,
					protected_owners, endpoint_owners),
				"lower_cover": lower_cover,
				"courtyard_bridge": false,
				"tie": posmod(Helper._mix64(volume.world_seed \
					^ pair_key.hash()), 1000003),
			})
	candidates.sort_custom(_skywalk_candidate_less)
	var selected: Array[Dictionary] = []
	var selected_owner_ids: Dictionary = {}
	# First spread links across distinct endpoint buildings. If the actual town
	# offers only a hub, a second pass may reuse one endpoint while every exact
	# occupancy and envelope compatibility rule remains unchanged.
	for require_fresh_owners: bool in [true, false]:
		for candidate: Dictionary in candidates:
			if selected.size() >= target or selected.has(candidate):
				continue
			var candidate_owners := _skywalk_endpoint_owner_set(
				candidate.reservation as Dictionary)
			var owner_conflict := _any_key_overlap(candidate_owners,
				selected_owner_ids)
			if require_fresh_owners and owner_conflict:
				continue
			var compatible := true
			for prior: Dictionary in selected:
				if not _skywalk_candidates_compatible(prior, candidate):
					compatible = false
					break
			if not compatible:
				continue
			selected.append(candidate)
			for owner_value: Variant in candidate_owners.keys():
				selected_owner_ids[owner_value] = true
		if selected.size() >= target:
			break
	var reservations: Array[Dictionary] = []
	var forced_offsets: Dictionary = {}
	var priority_cells: Dictionary = {}
	var unique_route_cover := 0
	for candidate: Dictionary in selected:
		reservations.append((candidate.reservation as Dictionary).duplicate(true))
		unique_route_cover += int(candidate.lower_cover)
		for owner_value: Variant in (candidate.forced_offsets as Dictionary).keys():
			var owner_id := StringName(owner_value)
			if not forced_offsets.has(owner_id):
				forced_offsets[owner_id] = {}
			(forced_offsets[owner_id] as Dictionary).merge(
				(candidate.forced_offsets as Dictionary)[owner_value] as Dictionary,
				true)
		priority_cells.merge(candidate.priority_cells as Dictionary, true)
	return {
		"reservations": reservations,
		"selected_candidates": selected,
		"forced_offsets": forced_offsets,
		"priority_cells": priority_cells,
		"candidate_count": candidates.size(),
		"target_count": target,
		"unique_route_cover_count": unique_route_cover,
		"marginal_route_cover_count": 0,
		"landmark_coverage_count": 0,
	}


static func _protected_owners_with_skywalk_plan(
		protected_owners: Dictionary, skywalk_plan: Dictionary) -> Dictionary:
	var trial := protected_owners.duplicate(true)
	var reservations := skywalk_plan.get("reservations", []) as Array
	for reservation_index in reservations.size():
		var reservation := reservations[reservation_index] as Dictionary
		var body := reservation.reserved_cells as Dictionary
		var feature_id := StringName("spatial.skywalk.reserve.%02d" \
			% reservation_index)
		for cell_value: Variant in body.keys():
			if not trial.has(cell_value):
				trial[cell_value] = {}
			(trial[cell_value] as Dictionary)[feature_id] = true
		var allowances := _skywalk_endpoint_owner_set(reservation)
		for cell_value: Variant in (reservation.get(
				"visual_clearance_cells", {}) as Dictionary).keys():
			if body.has(cell_value):
				continue
			if not trial.has(cell_value):
				trial[cell_value] = {}
			(trial[cell_value] as Dictionary)[feature_id] = allowances
	for cell_value: Variant in (skywalk_plan.get("priority_cells", {}) \
			as Dictionary).keys():
		trial[cell_value] = {StringName((skywalk_plan.priority_cells \
			as Dictionary)[cell_value]): true}
	return trial


static func _maze_connectivity_plan_from_composition(
		grid: WarrenSpatialGrid, volume: WarrenVolumePlan,
		composition: Dictionary, proposals: Array[Dictionary],
		program: SettlementFabricProgram, protected_owners: Dictionary,
		public_air: Dictionary, profile: WarrenVillageScaleProfile) -> Dictionary:
	## The first room composition is the town's geometric proposal. Derive the
	## occupied-link network from those actual shifted floorplates, then feed the
	## selected reservations back through the same composer. This is the explicit
	## post-geometry/pre-reservation pass: it can release an unrelated optional
	## micro-room from a bridge void, while the endpoint blocks are pinned to the
	## exact offsets that created their compatible sockets.
	var target := 2 if profile == null else mini(3,
		maxi(2, profile.skywalk_range.x))
	var empty := {
		"reservations": [] as Array[Dictionary],
		"selected_candidates": [] as Array[Dictionary],
		"forced_offsets": {}, "priority_cells": {},
		"candidate_count": 0, "target_count": target,
		"unique_route_cover_count": 0,
		"marginal_route_cover_count": 0,
		"landmark_coverage_count": 0,
	}
	var lineages := composition.get("lineages", {}) as Dictionary
	if lineages.is_empty():
		return empty
	var proposal_by_id: Dictionary = {}
	for proposal: Dictionary in proposals:
		var proposal_parcel := proposal.get("parcel") as WarrenBuildingParcel
		if proposal_parcel != null:
			proposal_by_id[proposal_parcel.stable_id] = proposal
	var endpoints: Array[Dictionary] = []
	var occupied_by_owner: Dictionary = {}
	var lineage_ids: Array[StringName] = []
	lineage_ids.assign(lineages.keys())
	lineage_ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	for lineage_id: StringName in lineage_ids:
		var lineage := lineages[lineage_id] as Dictionary
		var proposal := proposal_by_id.get(lineage_id, {}) as Dictionary
		if proposal.is_empty():
			continue
		var proposal_origin := proposal.origin as Vector3i
		for block_value: Variant in lineage.blocks as Array:
			var block := block_value as Dictionary
			var source_block_index := int(block.source_block_index)
			var block_origin := block.origin as Vector3i
			var original_origin := block.get("original_origin", block_origin) \
				as Vector3i
			var wanted_offset := Vector2i(block_origin.x - original_origin.x,
				block_origin.z - original_origin.z)
			for occupied_cell: Vector3i in block.cells as Array[Vector3i]:
				occupied_by_owner[occupied_cell] = lineage_id
			for storey in range(int(block.start_storey),
					int(block.end_storey)):
				var room_origin := Vector3i(block_origin.x,
					proposal_origin.y + storey \
						* WarrenSpatialGrid.STOREY_CELLS,
					block_origin.z)
				var stamp := WarrenRoomStamp.new(
					StringName("connectivity.%s.%d" % [lineage_id, storey]),
					lineage_id, StringName(block.kind), room_origin,
					int(block.yaw_quarters), storey, false, false)
				var recipe_id := WarrenSpatialFabricCompiler._room_recipe_id(
					stamp, volume.world_seed, false)
				var recipe := program.recipe(recipe_id)
				if recipe == null:
					continue
				for socket: Dictionary in recipe.sockets:
					if int(socket.kind) != FabricRecipe.SocketKind.ROOM:
						continue
					var socket_id := StringName(socket.id)
					if not String(socket_id).begins_with("room.") \
							or String(socket_id).contains(".corner."):
						continue
					var bearing_id := StringName(String(socket_id).replace(
						"room.", "bearing."))
					if recipe.socket(bearing_id).is_empty():
						continue
					endpoints.append({
						"owner_id": lineage_id,
						"cell": FabricRecipe.transform_cell(
							socket.cell as Vector3i, room_origin,
							int(block.yaw_quarters)),
						"facing": FabricRecipe.transform_direction(
							socket.facing as Vector3i,
							int(block.yaw_quarters)),
						"source_block_index": source_block_index,
						"wanted_offset": wanted_offset,
						"priority_cells": block.cells,
					})
	var candidates: Array[Dictionary] = []
	var seen: Dictionary = {}
	var aligned_pair_count := 0
	var component_count := 0
	var body_fit_count := 0
	var clearance_grid_fit_count := 0
	var clearance_feature_fit_count := 0
	var reservation_fit_count := 0
	var route_fit_count := 0
	var fit_rejection_samples: Array[Dictionary] = []
	for left_index in endpoints.size():
		var left := endpoints[left_index]
		for right_index in range(left_index + 1, endpoints.size()):
			var right := endpoints[right_index]
			if left.owner_id == right.owner_id \
					or (left.cell as Vector3i).y != (right.cell as Vector3i).y \
					or (left.facing as Vector3i) != -(right.facing as Vector3i):
				continue
			var forward := left.facing as Vector3i
			var delta := (right.cell as Vector3i) - (left.cell as Vector3i)
			var distance := delta.x * forward.x + delta.z * forward.z
			if distance not in [3, 5, 7] or delta != forward * distance:
				continue
			aligned_pair_count += 1
			var segments := (distance - 1) / 2
			var recipe_id := &"skywalk.3.blue" if segments == 1 \
				else &"skywalk.6.orange" if segments == 2 \
				else &"skywalk.9.blue"
			var recipe := program.recipe(recipe_id)
			var yaw := WarrenAssetCompiler._yaw_for_facing(Vector3i.LEFT,
				-forward)
			if recipe == null or yaw < 0:
				continue
			var own_socket := recipe.socket(&"room.west")
			if own_socket.is_empty():
				continue
			var origin := (left.cell as Vector3i) + forward \
				- FabricRecipe.transform_cell(own_socket.cell as Vector3i,
					Vector3i.ZERO, yaw)
			var components: Array[Dictionary] = [{"recipe_id": recipe_id,
				"origin": origin, "yaw_quarters": yaw}]
			var reservation := WarrenAssetCompiler._component_reservation(
				components, program, public_air)
			if reservation.is_empty():
				continue
			component_count += 1
			var owner_ids := [StringName(left.owner_id),
				StringName(right.owner_id)] as Array[StringName]
			reservation["kind"] = &"straight"
			reservation["recipe_id"] = recipe_id
			reservation["origin"] = origin
			reservation["yaw_quarters"] = yaw
			reservation["owner_parcel_ids"] = owner_ids
			reservation["owner_endpoints"] = [{"cell": left.cell,
				"facing": left.facing, "owner_id": left.owner_id},
				{"cell": right.cell, "facing": right.facing,
					"owner_id": right.owner_id}]
			var body := reservation.reserved_cells as Dictionary
			var clearance := _skywalk_visual_clearance_cells(components,
				program)
			var body_fits := _skywalk_body_fits_grid(grid, body)
			var clearance_grid_fits := _skywalk_clearance_fits_grid(grid,
				clearance)
			var clearance_feature_fits := _skywalk_clearance_fits_protected(
				clearance, protected_owners)
			body_fit_count += int(body_fits)
			clearance_grid_fit_count += int(body_fits and clearance_grid_fits)
			clearance_feature_fit_count += int(body_fits \
				and clearance_grid_fits and clearance_feature_fits)
			if not body_fits or not clearance_grid_fits \
					or not clearance_feature_fits:
				if fit_rejection_samples.size() < 3:
					fit_rejection_samples.append({"origin": origin,
						"recipe_id": recipe_id, "left": left.cell,
						"right": right.cell, "body_fits": body_fits,
						"clearance_grid_fits": clearance_grid_fits,
						"clearance_feature_fits": clearance_feature_fits,
						"body_conflicts": _skywalk_grid_conflicts(grid, body,
							true),
						"clearance_conflicts": _skywalk_grid_conflicts(grid,
							clearance, false)})
				continue
			reservation_fit_count += 1
			var lower_cover := _lower_public_cover(body, public_air)
			if lower_cover < 2:
				continue
			route_fit_count += 1
			var pair_key := _skywalk_endpoint_pair_key(reservation)
			if seen.has(pair_key):
				continue
			seen[pair_key] = true
			reservation["visual_clearance_cells"] = clearance
			var forced_offsets: Dictionary = {
				StringName(left.owner_id): {int(left.source_block_index):
					left.wanted_offset as Vector2i},
				StringName(right.owner_id): {int(right.source_block_index):
					right.wanted_offset as Vector2i},
			}
			var priority_cells: Dictionary = {}
			for endpoint: Dictionary in [left, right]:
				for cell_value: Variant in endpoint.priority_cells as Array:
					priority_cells[cell_value] = StringName(endpoint.owner_id)
			var endpoint_owners := {StringName(left.owner_id): true,
				StringName(right.owner_id): true}
			var blockers: Dictionary = {}
			for cell_value: Variant in clearance.keys():
				var owner := StringName(occupied_by_owner.get(cell_value, &""))
				if not owner.is_empty() and not endpoint_owners.has(owner):
					blockers[owner] = true
			candidates.append({
				"reservation": reservation, "body": body,
				"clearance": clearance, "forced_offsets": forced_offsets,
				"priority_cells": priority_cells, "pair_key": pair_key,
				"endpoint_pair_key": pair_key,
				"blocker_count": blockers.size(),
				"lower_cover": lower_cover, "courtyard_bridge": false,
				"tie": posmod(Helper._mix64(volume.world_seed \
					^ pair_key.hash()), 1000003),
			})
	candidates.sort_custom(_skywalk_candidate_less)
	var selected: Array[Dictionary] = []
	for candidate: Dictionary in candidates:
		if selected.size() >= target:
			break
		var compatible := true
		for prior: Dictionary in selected:
			compatible = compatible and _skywalk_candidates_compatible(prior,
				candidate)
		if compatible:
			selected.append(candidate)
	var reservations: Array[Dictionary] = []
	var forced_offsets: Dictionary = {}
	var priority_cells: Dictionary = {}
	var route_cover := 0
	for candidate: Dictionary in selected:
		reservations.append((candidate.reservation as Dictionary).duplicate(true))
		route_cover += int(candidate.lower_cover)
		for owner_value: Variant in (candidate.forced_offsets as Dictionary).keys():
			if not forced_offsets.has(owner_value):
				forced_offsets[owner_value] = {}
			(forced_offsets[owner_value] as Dictionary).merge(
				(candidate.forced_offsets as Dictionary)[owner_value] as Dictionary,
				true)
		priority_cells.merge(candidate.priority_cells as Dictionary, true)
	return {
		"reservations": reservations, "selected_candidates": selected,
		"forced_offsets": forced_offsets, "priority_cells": priority_cells,
		"candidate_count": candidates.size(), "target_count": target,
		"endpoint_count": endpoints.size(),
		"aligned_pair_count": aligned_pair_count,
		"component_count": component_count,
		"body_fit_count": body_fit_count,
		"clearance_grid_fit_count": clearance_grid_fit_count,
		"clearance_feature_fit_count": clearance_feature_fit_count,
		"reservation_fit_count": reservation_fit_count,
		"route_fit_count": route_fit_count,
		"fit_rejection_samples": fit_rejection_samples,
		"unique_route_cover_count": route_cover,
		"marginal_route_cover_count": 0, "landmark_coverage_count": 0,
	}


static func _skywalk_candidate_less(a: Dictionary, b: Dictionary) -> bool:
	if bool(a.get("courtyard_bridge", false)) \
			!= bool(b.get("courtyard_bridge", false)):
		return bool(a.get("courtyard_bridge", false))
	if int(a.blocker_count) != int(b.blocker_count):
		return int(a.blocker_count) < int(b.blocker_count)
	if int(a.lower_cover) != int(b.lower_cover):
		return int(a.lower_cover) > int(b.lower_cover)
	return int(a.tie) < int(b.tie)


static func _courtyard_cantilever_room_candidates(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan, proposals: Array[Dictionary],
		program: SettlementFabricProgram, protected_owners: Dictionary,
		public_air: Dictionary) -> Array[Dictionary]:
	## The court-side route may pierce the raw wall, so a full private U-link can
	## be physically impossible.  A corner knuckle plus one reviewed cantilever
	## bay forms an inhabited half-facade over the lower street while leaving the
	## crossing public gateway open.  It is a building feature, not one of the
	## three independent room-to-room skywalks.
	var out: Array[Dictionary] = []
	var floors := _courtyard_floor_cells(volume)
	var parcel_side_mask := _proposal_courtyard_side_mask(volume, proposals)
	var court_y := 2147483647
	for floor_value: Variant in floors.keys():
		court_y = mini(court_y, (floor_value as Vector3i).y)
	var corner_recipe := program.recipe(&"skywalk.corner.blue")
	var bay_recipe := program.recipe(&"skywalk.cantilever.3.blue")
	if corner_recipe == null or bay_recipe == null:
		return out
	var seen: Dictionary = {}
	var raw_count := 0
	var court_side_count := 0
	var body_fit_count := 0
	var clearance_grid_fit_count := 0
	var clearance_protected_fit_count := 0
	var grid_fit_count := 0
	var cover_count := 0
	var rejection_samples: Array[Dictionary] = []
	for proposal: Dictionary in proposals:
		var parcel := proposal.parcel as WarrenBuildingParcel
		for endpoint: Dictionary in _all_proposal_room_endpoints(proposal,
				parcel, program):
			if (endpoint.cell as Vector3i).y != court_y:
				continue
			var endpoint_cell := endpoint.cell as Vector3i
			var facing := endpoint.facing as Vector3i
			for corner_yaw in 4:
				var attach := WarrenAssetCompiler._socket_facing(corner_recipe,
					-facing, corner_yaw)
				if attach.is_empty():
					continue
				var corner_origin := WarrenAssetCompiler._attached_origin(
					corner_recipe, StringName(attach.id), corner_yaw,
					endpoint_cell, facing)
				for along: Vector3i in [Vector3i(-facing.z, 0, facing.x),
						Vector3i(facing.z, 0, -facing.x)]:
					var free := WarrenAssetCompiler._socket_facing(corner_recipe,
						along, corner_yaw)
					if free.is_empty() or free.id == attach.id:
						continue
					var free_cell := FabricRecipe.transform_cell(
						free.cell as Vector3i, corner_origin, corner_yaw)
					var bay_yaw := WarrenAssetCompiler._yaw_for_facing(
						Vector3i.LEFT, -along)
					if bay_yaw < 0:
						continue
					var bay_origin := WarrenAssetCompiler._attached_origin(bay_recipe,
						&"room.west", bay_yaw, free_cell, along)
					var components: Array[Dictionary] = [{
						"recipe_id": &"skywalk.corner.blue",
						"origin": corner_origin, "yaw_quarters": corner_yaw}, {
						"recipe_id": &"skywalk.cantilever.3.blue",
						"origin": bay_origin, "yaw_quarters": bay_yaw}]
					var reservation := WarrenAssetCompiler._component_reservation(
						components, program, public_air)
					if reservation.is_empty():
						continue
					raw_count += 1
					var body := reservation.reserved_cells as Dictionary
					var side_mask := _courtyard_address_side_mask_from_occupied(
						floors, body)
					if side_mask == 0 or not _skywalk_selection_addresses_courtyard(
							[{"courtyard_side_mask": side_mask}] \
								as Array[Dictionary], parcel_side_mask):
						continue
					court_side_count += 1
					var clearance := _skywalk_visual_clearance_cells(components,
						program)
					var body_fits := _skywalk_body_fits_grid(grid, body)
					var clearance_grid_fits := _skywalk_clearance_fits_grid(grid,
						clearance)
					var clearance_protected_fits := \
						_skywalk_clearance_fits_protected(clearance,
							protected_owners)
					body_fit_count += int(body_fits)
					clearance_grid_fit_count += int(body_fits \
						and clearance_grid_fits)
					clearance_protected_fit_count += int(body_fits \
						and clearance_grid_fits and clearance_protected_fits)
					if not body_fits or not clearance_grid_fits \
							or not clearance_protected_fits:
						if rejection_samples.size() < 8:
							rejection_samples.append({
								"endpoint": endpoint_cell,
								"facing": facing,
								"corner_origin": corner_origin,
								"corner_yaw": corner_yaw,
								"bay_origin": bay_origin,
								"bay_yaw": bay_yaw,
								"side_mask": side_mask,
								"body_fits": body_fits,
								"clearance_grid_fits": clearance_grid_fits,
								"clearance_protected_fits":
									clearance_protected_fits,
								"body_conflicts": _skywalk_grid_conflicts(grid,
									body, true),
								"clearance_conflicts": _skywalk_grid_conflicts(grid,
									clearance, false),
								"protected_conflicts":
									_skywalk_protected_conflicts(clearance,
										protected_owners),
							})
						continue
					grid_fit_count += 1
					var lower_cover := _lower_public_cover(body, public_air)
					if lower_cover < 2:
						continue
					cover_count += 1
					var block := _proposal_block_for_cell(proposal, endpoint_cell)
					if block < 0 or not _forced_block_fits(grid, proposal, block,
							Vector2i.ZERO):
						continue
					var plate := _forced_block_cells(proposal, block,
						Vector2i.ZERO)
					if _sets_overlap(body, plate):
						continue
					var key := _skywalk_construction_key({"components": components})
					if seen.has(key):
						continue
					seen[key] = true
					var priority_cells: Dictionary = {}
					for cell_value: Variant in plate.keys():
						priority_cells[cell_value] = parcel.stable_id
					var tower_risk := 0
					if StringName(proposal.kind) == &"tower" \
							and int(proposal.storeys) > WarrenRoomCompositionPlanner \
								.MAX_IDENTICAL_TOWER_FLOORPLATE_RUN_STOREYS:
						tower_risk = 100000 + block * 1000 \
							+ int(proposal.storeys)
					reservation["visual_clearance_cells"] = clearance
					reservation["kind"] = &"courtyard_bridge_house"
					reservation["recipe_id"] = &"skywalk.cantilever.3.blue"
					reservation["origin"] = bay_origin
					reservation["yaw_quarters"] = bay_yaw
					var owner_endpoint := endpoint.duplicate(true)
					owner_endpoint["owner_id"] = parcel.stable_id
					reservation["owner_endpoints"] = [owner_endpoint]
					reservation["owner_parcel_ids"] = [parcel.stable_id]
					reservation["courtyard_side_mask"] = side_mask
					out.append({"reservation": reservation, "body": body,
						"clearance": clearance,
						"forced_offsets": {parcel.stable_id: {
							block: Vector2i.ZERO}},
						"priority_cells": priority_cells,
						"pair_key": String(parcel.stable_id),
						"endpoint_pair_key": _skywalk_endpoint_pair_key(reservation),
						"blocker_count": _skywalk_blocker_count(clearance,
							protected_owners, {parcel.stable_id: true}),
						"lower_cover": lower_cover, "courtyard_bridge": true,
						"courtyard_side_mask": side_mask,
						"tower_risk": tower_risk,
						"tie": posmod(Helper._mix64(volume.world_seed \
							^ String(parcel.stable_id).hash() ^ key.hash()),
							1000003)})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("tower_risk", 0)) != int(b.get("tower_risk", 0)):
			return int(a.get("tower_risk", 0)) < int(b.get("tower_risk", 0))
		return _skywalk_candidate_less(a, b))
	if diagnostic_trace_skywalk_timing:
		print("SKYWALK_TIMING court_cantilever_gates ", {
			"raw": raw_count, "court_side": court_side_count,
			"body": body_fit_count,
			"clearance_grid": clearance_grid_fit_count,
			"clearance_protected": clearance_protected_fit_count,
			"grid": grid_fit_count, "cover": cover_count,
			"accepted": out.size(), "rejections": rejection_samples})
	return out


static func _any_key_overlap(left: Dictionary, right: Dictionary) -> bool:
	for key: Variant in left.keys():
		if right.has(key):
			return true
	return false


static func _all_proposal_room_endpoints(proposal: Dictionary,
		parcel: WarrenBuildingParcel,
		program: SettlementFabricProgram) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen: Dictionary = {}
	for component: Dictionary in StaggeredFabricCompiler.proposal_components(
			proposal):
		var recipe := program.recipe(StringName(component.recipe_id))
		if recipe == null or recipe.has_tag(&"roof"):
			continue
		for socket: Dictionary in recipe.sockets:
			if int(socket.kind) != FabricRecipe.SocketKind.ROOM \
					or not String(StringName(socket.id)).begins_with("room.") \
					or String(StringName(socket.id)).contains(".corner."):
				continue
			var cell := FabricRecipe.transform_cell(socket.cell as Vector3i,
				component.origin as Vector3i, int(component.yaw_quarters))
			var facing := FabricRecipe.transform_direction(
				socket.facing as Vector3i, int(component.yaw_quarters))
			var key := "%s/%s" % [cell, facing]
			if seen.has(key):
				continue
			seen[key] = true
			out.append({"cell": cell, "facing": facing,
				"owner_id": parcel.stable_id,
				"slot_signature": parcel.slot_signature()})
	return out


static func _skywalk_construction_key(reservation: Dictionary) -> String:
	var parts := PackedStringArray()
	for component_value: Variant in reservation.get("components", []):
		var component := component_value as Dictionary
		var origin := component.origin as Vector3i
		parts.append("%s@%d:%d:%d/r%d" % [StringName(component.recipe_id),
			origin.x, origin.y, origin.z, int(component.yaw_quarters)])
	parts.sort()
	return "|".join(parts)


static func _skywalk_visual_clearance_cells(components: Array[Dictionary],
		program: SettlementFabricProgram) -> Dictionary:
	## Convert the measured world-space envelopes into a conservative fine-cell
	## reservation. The exact AABB test uses the same tolerance as final fabric
	## assembly, so topology yields only where an unrelated mesh would really be
	## rejected later; the connector's own occupancy remains a separate fact.
	var all_bounds: Array[AABB] = []
	for component: Dictionary in components:
		var recipe := program.recipe(StringName(component.recipe_id))
		if recipe == null:
			return {}
		var lattice_transform := FabricRecipe.lattice_transform(
			component.origin as Vector3i, int(component.yaw_quarters))
		var bounds_to_raster: Array[AABB] = []
		var placement_prefix := String(component.get("placement_prefix", ""))
		if placement_prefix.is_empty():
			bounds_to_raster.append(lattice_transform \
				* recipe.local_clearance_bounds)
		else:
			for placement: Dictionary in recipe.placements:
				if not String(StringName(placement.id)).begins_with(
						placement_prefix):
					continue
				var contract_value := program.module_program.contract(
					StringName(placement.asset_id))
				if contract_value == null:
					return {}
				bounds_to_raster.append(lattice_transform \
					* (placement.transform as Transform3D) \
					* contract_value.clearance_bounds())
			if bounds_to_raster.is_empty():
				return {}
		all_bounds.append_array(bounds_to_raster)
	return _visual_clearance_bounds_cells(all_bounds)


static func _visual_clearance_bounds_cells(bounds_to_raster: Array[AABB]) \
		-> Dictionary:
	## One authoritative measured-envelope raster for every pre-construction
	## reservation: skywalks, source bridge compounds, and required roof closure.
	var out: Dictionary = {}
	var cell_size := FabricRecipe.CELL_SIZE
	var half := cell_size * 0.5
	for bounds: AABB in bounds_to_raster:
		var minimum := bounds.position
		var maximum := bounds.end
		var min_x := floori((minimum.x - half) / cell_size) - 1
		var max_x := ceili((maximum.x + half) / cell_size) + 1
		var min_y := floori(minimum.y / cell_size) - 1
		var max_y := ceili(maximum.y / cell_size) + 1
		var min_z := floori((minimum.z - half) / cell_size) - 1
		var max_z := ceili((maximum.z + half) / cell_size) + 1
		for y in range(min_y, max_y + 1):
			for z in range(min_z, max_z + 1):
				for x in range(min_x, max_x + 1):
					var cell := Vector3i(x, y, z)
					var cell_bounds := AABB(Vector3(cell) * cell_size \
						+ Vector3(-half, 0.0, -half), Vector3.ONE * cell_size)
					if SettlementFabricPlan._aabb_overlaps_volume(bounds,
							cell_bounds):
						out[cell] = true
	return out


static func _skywalk_endpoint_owner_set(reservation: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for owner_value: Variant in reservation.get("owner_parcel_ids", []):
		out[StringName(owner_value)] = true
	return out


static func _skywalk_endpoint_pair_key(reservation: Dictionary) -> String:
	var parts := PackedStringArray()
	for endpoint_value: Variant in reservation.get("owner_endpoints", []):
		var endpoint := endpoint_value as Dictionary
		var cell := endpoint.cell as Vector3i
		var facing := endpoint.facing as Vector3i
		parts.append("%d:%d:%d/%d:%d:%d" % [cell.x, cell.y, cell.z,
			facing.x, facing.y, facing.z])
	parts.sort()
	return "|".join(parts)


static func _proposal_block_for_cell(proposal: Dictionary,
		cell: Vector3i) -> int:
	return _proposal_storey_for_cell(proposal, cell) / 2


static func _proposal_storey_for_cell(proposal: Dictionary,
		cell: Vector3i) -> int:
	var origin := proposal.origin as Vector3i
	return floori(float(cell.y - origin.y) \
		/ float(WarrenSpatialGrid.STOREY_CELLS))


static func _forced_block_fits(grid: WarrenSpatialGrid, proposal: Dictionary,
		block: int, offset: Vector2i) -> bool:
	var storeys := int(proposal.storeys)
	var start_storey := block * 2
	if start_storey >= storeys:
		return false
	for value: Variant in _forced_block_cells(proposal, block, offset).keys():
		var cell := value as Vector3i
		if not grid.contains(cell) \
				or grid.use_at(cell) != WarrenSpatialGrid.Use.ALLOCATABLE:
			return false
	return true


static func _forced_block_cells(proposal: Dictionary, block: int,
		offset: Vector2i) -> Dictionary:
	var storeys := int(proposal.storeys)
	var origin := proposal.origin as Vector3i
	var base_plate := _proposal_base_plate(proposal)
	var out: Dictionary = {}
	for storey in range(block * 2, mini(storeys, block * 2 + 2)):
		for column_value: Variant in base_plate.keys():
			var column := column_value as Vector2i
			for y_offset in WarrenSpatialGrid.STOREY_CELLS:
				out[Vector3i(column.x + offset.x,
					origin.y + storey * WarrenSpatialGrid.STOREY_CELLS + y_offset,
					column.y + offset.y)] = true
	return out


static func _sets_overlap(left: Dictionary, right: Dictionary) -> bool:
	for value: Variant in left.keys():
		if right.has(value):
			return true
	return false


static func _skywalk_body_fits_grid(grid: WarrenSpatialGrid,
		body: Dictionary) -> bool:
	for value: Variant in body.keys():
		var cell := value as Vector3i
		if not grid.contains(cell) or grid.use_at(cell) not in [
				WarrenSpatialGrid.Use.OUTSIDE,
				WarrenSpatialGrid.Use.ALLOCATABLE] \
				or (grid.reservation_bits_at(cell) & (
					WarrenSpatialGrid.Reservation.FEATURE \
					| WarrenSpatialGrid.Reservation.VISUAL_CLEARANCE)) != 0:
			return false
	return true


static func _skywalk_grid_conflicts(grid: WarrenSpatialGrid,
		cells: Dictionary, require_open_mass: bool) -> Array[Dictionary]:
	## Harness diagnostic for the very small court-cantilever frontier. Keep the
	## exact reason visible instead of treating public air, daylight, bounds, and
	## an earlier feature reservation as one opaque "does not fit" result.
	var out: Array[Dictionary] = []
	for value: Variant in cells.keys():
		var cell := value as Vector3i
		var in_bounds := grid.contains(cell)
		var use := grid.use_at(cell)
		var bits := grid.reservation_bits_at(cell)
		var conflicts := not in_bounds or (bits & (
			WarrenSpatialGrid.Reservation.FEATURE \
			| WarrenSpatialGrid.Reservation.VISUAL_CLEARANCE)) != 0
		if require_open_mass:
			conflicts = conflicts or use not in [
				WarrenSpatialGrid.Use.OUTSIDE,
				WarrenSpatialGrid.Use.ALLOCATABLE]
		if not conflicts:
			continue
		out.append({"cell": cell, "in_bounds": in_bounds,
			"use": use, "reservation_bits": bits,
			"owner": grid.owner_name_at(cell)})
		if out.size() >= 12:
			break
	return out


static func _skywalk_protected_conflicts(clearance: Dictionary,
		protected_owners: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for value: Variant in clearance.keys():
		var owners := protected_owners.get(value, {}) as Dictionary
		for owner_value: Variant in owners.keys():
			var owner_id := StringName(owner_value)
			if not _protected_owner_is_feature(owner_id):
				continue
			out.append({"cell": value as Vector3i, "owner": owner_id})
			if out.size() >= 12:
				return out
	return out


static func _skywalk_clearance_fits_grid(grid: WarrenSpatialGrid,
		clearance: Dictionary) -> bool:
	for value: Variant in clearance.keys():
		var cell := value as Vector3i
		if not grid.contains(cell) or (grid.reservation_bits_at(cell) & (
				WarrenSpatialGrid.Reservation.FEATURE \
				| WarrenSpatialGrid.Reservation.VISUAL_CLEARANCE)) != 0:
			return false
	return true


static func _skywalk_clearance_fits_protected(clearance: Dictionary,
		protected_owners: Dictionary) -> bool:
	for value: Variant in clearance.keys():
		for owner_value: Variant in (protected_owners.get(value, {}) \
				as Dictionary).keys():
			if _protected_owner_is_feature(StringName(owner_value)):
				return false
	return true


static func _protected_owner_is_feature(owner_id: StringName) -> bool:
	var text := String(owner_id)
	return text.begins_with("spatial.feature.") \
		or text.begins_with("spatial.skywalk.reserve.") \
		or text.begins_with("spatial.skywalk.trial.")


static func _lower_public_cover(body: Dictionary,
		public_air: Dictionary) -> int:
	var minimum_y := 2147483647
	for value: Variant in body.keys():
		minimum_y = mini(minimum_y, (value as Vector3i).y)
	var columns: Dictionary = {}
	for value: Variant in body.keys():
		var cell := value as Vector3i
		if cell.y != minimum_y:
			continue
		for down in range(1, 9):
			if public_air.has(cell + Vector3i.DOWN * down):
				columns[Vector2i(cell.x, cell.z)] = true
				break
	return columns.size()


static func _enclosure_route_walk(
		realm: SectionalPublicRealmPlan) -> Dictionary:
	## Keep skywalk planning and final visual-quality measurement on one route
	## definition. Courts, terraces, the approach landing, and short bridges are
	## intentionally allowed open edges and therefore do not belong to the canyon
	## overhead denominator in `SettlementFabricSolver._audit_enclosure`.
	var out: Dictionary = {}
	if realm == null:
		return out
	for node_value: PublicRealmNode in realm.nodes:
		if node_value.is_landing \
				or node_value.episode_kind == PublicRealmNode.EpisodeKind.COURT \
				or node_value.episode_kind == PublicRealmNode.EpisodeKind.TERRACE \
				or node_value.episode_kind \
					== PublicRealmNode.EpisodeKind.SHORT_BRIDGE:
			continue
		for cell: Vector3i in node_value.surface_cells:
			out[cell] = node_value.stable_id
	return out


static func _uncovered_route_overhead_supply_audit(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan) -> Dictionary:
	## Phase B evidence, measured pre-discard: for every canonical route cell
	## lacking occupied overhead in the final 2-6 band window, distinguish
	## trimmed massif supply above it (a partition/selection failure the
	## source beam could still claim as rooms) from genuinely empty sky (a
	## massing failure only the carver or an authored street-spanning gallery
	## can add). A huge discarded source shell must not hide a visible
	## planning hole.
	var realm := WarrenVolumePublicRealmAdapter.from_volume(volume)
	if realm == null:
		return {}
	var route_walk := _enclosure_route_walk(realm)
	var covered := 0
	var trimmed_supply_cells: Array[Vector3i] = []
	var no_mass_cells: Array[Vector3i] = []
	for cell_value: Variant in route_walk:
		var cell := cell_value as Vector3i
		var has_private := false
		var has_trimmed := false
		for rise in range(2, 7):
			var above: Vector3i = cell + Vector3i.UP * rise
			var use := grid.use_at(above)
			if use == WarrenSpatialGrid.Use.PRIVATE_VOLUME:
				has_private = true
				break
			if use == WarrenSpatialGrid.Use.ALLOCATABLE:
				has_trimmed = true
		if has_private:
			covered += 1
		elif has_trimmed:
			trimmed_supply_cells.append(cell)
		else:
			no_mass_cells.append(cell)
	trimmed_supply_cells.sort_custom(_cell_less)
	no_mass_cells.sort_custom(_cell_less)
	var trimmed_preview := PackedStringArray()
	for cell: Vector3i in trimmed_supply_cells.slice(0, 48):
		trimmed_preview.append("%d:%d:%d" % [cell.x, cell.y, cell.z])
	var no_mass_preview := PackedStringArray()
	for cell: Vector3i in no_mass_cells.slice(0, 48):
		no_mass_preview.append("%d:%d:%d" % [cell.x, cell.y, cell.z])
	return {
		"route_overhead_supply_route_cell_count": route_walk.size(),
		"route_overhead_supply_covered_cell_count": covered,
		"uncovered_route_trimmed_supply_cell_count":
			trimmed_supply_cells.size(),
		"uncovered_route_no_mass_cell_count": no_mass_cells.size(),
		"uncovered_route_trimmed_supply_cells": trimmed_preview,
		"uncovered_route_no_mass_cells": no_mass_preview,
	}


static func _skywalk_blocker_count(body: Dictionary,
		protected_owners: Dictionary, endpoint_owners: Dictionary) -> int:
	var blockers: Dictionary = {}
	for value: Variant in body.keys():
		for owner_value: Variant in (protected_owners.get(value, {}) \
				as Dictionary).keys():
			var owner_id := StringName(owner_value)
			if not endpoint_owners.has(owner_id):
				blockers[owner_id] = true
	return blockers.size()


static func _skywalk_candidates_compatible(left: Dictionary,
		right: Dictionary) -> bool:
	if left.pair_key == right.pair_key:
		return false
	var left_clearance := left.get("clearance", left.body) as Dictionary
	var right_clearance := right.get("clearance", right.body) as Dictionary
	if _skywalk_visual_bounds_overlap(left.reservation as Dictionary,
			right.reservation as Dictionary):
		return false
	for value: Variant in left_clearance.keys():
		if (right.priority_cells as Dictionary).has(value):
			return false
	for value: Variant in right_clearance.keys():
		if (left.priority_cells as Dictionary).has(value):
			return false
	for value: Variant in (left.body as Dictionary).keys():
		if (right.body as Dictionary).has(value):
			return false
		if (right.priority_cells as Dictionary).has(value):
			return false
	for value: Variant in (right.body as Dictionary).keys():
		if (left.priority_cells as Dictionary).has(value):
			return false
	for value: Variant in (left.priority_cells as Dictionary).keys():
		if (right.priority_cells as Dictionary).has(value) \
				and StringName((left.priority_cells as Dictionary)[value]) \
					!= StringName((right.priority_cells as Dictionary)[value]):
			return false
	for parcel_value: Variant in (left.forced_offsets as Dictionary).keys():
		var parcel_id := StringName(parcel_value)
		if not (right.forced_offsets as Dictionary).has(parcel_id):
			continue
		var left_blocks := (left.forced_offsets as Dictionary)[parcel_id] \
			as Dictionary
		var right_blocks := (right.forced_offsets as Dictionary)[parcel_id] \
			as Dictionary
		for block_value: Variant in left_blocks.keys():
			if right_blocks.has(block_value) \
					and left_blocks[block_value] != right_blocks[block_value]:
				return false
	return true


static func _skywalk_visual_bounds_overlap(left: Dictionary,
		right: Dictionary) -> bool:
	for left_value: Variant in left.get("visual_bounds", []):
		var left_bounds := left_value as AABB
		for right_value: Variant in right.get("visual_bounds", []):
			if SettlementFabricPlan._aabb_overlaps_volume(left_bounds,
					right_value as AABB):
				return true
	return false


static func _courtyard_neighbor_cells(court_floors: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for floor_value: Variant in court_floors.keys():
		var floor_cell := floor_value as Vector3i
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.FORWARD, Vector3i.BACK]:
			if court_floors.has(floor_cell + direction):
				continue
			for y_offset in WarrenSpatialGrid.STOREY_CELLS:
				out[floor_cell + direction + Vector3i.UP * y_offset] = true
	return out


static func _courtyard_floor_cells(volume: WarrenVolumePlan) -> Dictionary:
	var out: Dictionary = {}
	if volume == null:
		return out
	for macro: Vector3i in volume.courtyard_cells:
		for floor: Vector3i in _fine_square(macro):
			out[floor] = true
	return out


static func _proposal_courtyard_side_mask(volume: WarrenVolumePlan,
		proposals: Array[Dictionary]) -> int:
	var occupied: Dictionary = {}
	for proposal: Dictionary in proposals:
		for cell: Vector3i in _proposal_private_cells(proposal):
			occupied[cell] = true
	return _courtyard_address_side_mask_from_occupied(
		_courtyard_floor_cells(volume), occupied)


static func _composition_courtyard_side_mask(court_floors: Dictionary,
		composition: Dictionary, extra_occupied: Dictionary = {}) -> int:
	## Court walls are an output property of the final 3D room tiling. Source
	## proposals do not count: a parcel whose exact block cannot survive a market,
	## landmark, or skywalk reservation must not leave behind a fictional facade.
	var occupied := extra_occupied.duplicate()
	for lineage_value: Variant in (composition.get("lineages", {}) \
			as Dictionary).values():
		var lineage := lineage_value as Dictionary
		for block_value: Variant in (lineage.get("blocks", []) as Array):
			var block := block_value as Dictionary
			for cell: Vector3i in block.get("cells", []) as Array[Vector3i]:
				occupied[cell] = true
	return _courtyard_address_side_mask_from_occupied(court_floors, occupied)


static func _side_mask_count(side_mask: int) -> int:
	var count := 0
	for bit in 4:
		count += int((side_mask & (1 << bit)) != 0)
	return count


static func _proposal_private_cells(proposal: Dictionary) -> Array[Vector3i]:
	if proposal.is_empty():
		return [] as Array[Vector3i]
	var storeys := int(proposal.storeys)
	var offsets: Array[Vector2i] = []
	for _block in ceili(float(storeys) / 2.0):
		offsets.append(Vector2i.ZERO)
	return _segment_cells(_proposal_base_plate(proposal),
		(proposal.origin as Vector3i).y, offsets, 0, storeys)


static func _skywalk_selection_addresses_courtyard(
		selected: Array[Dictionary], parcel_side_mask: int) -> bool:
	## Cheap topology gate used before the exact composition proof.  An occupied
	## connector is allowed to complete the courtyard enclosure only when its
	## measured PRIVATE_VOLUME body itself runs along the court edge; endpoints,
	## clearance boxes, and decorative meshes do not count.
	var side_mask := parcel_side_mask
	for candidate: Dictionary in selected:
		side_mask |= int(candidate.get("courtyard_side_mask", 0))
	var side_count := 0
	for bit in 4:
		side_count += int((side_mask & (1 << bit)) != 0)
	return side_count >= WarrenSpatialFeatureSolver.MIN_COURT_SIDE_COUNT


static func _courtyard_address_side_mask_from_occupied(
		court_floors: Dictionary, occupied: Dictionary) -> int:
	var side_mask := 0
	var directions: Array[Vector3i] = [Vector3i.LEFT, Vector3i.RIGHT,
		Vector3i.FORWARD, Vector3i.BACK]
	for direction_index in directions.size():
		var direction := directions[direction_index]
		for floor_value: Variant in court_floors.keys():
			var floor_cell := floor_value as Vector3i
			if court_floors.has(floor_cell + direction):
				continue
			for y_offset in WarrenSpatialGrid.STOREY_CELLS:
				if occupied.has(floor_cell + direction \
						+ Vector3i.UP * y_offset):
					side_mask |= 1 << direction_index
					break
			if (side_mask & (1 << direction_index)) != 0:
				break
	return side_mask


static func _proposal_court_fixed_blocks(proposal: Dictionary,
		court_neighbor_cells: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	if proposal.is_empty() or court_neighbor_cells.is_empty():
		return out
	var block_count := ceili(float(int(proposal.storeys)) / 2.0)
	for block in block_count:
		for cell_value: Variant in _forced_block_cells(proposal, block,
				Vector2i.ZERO).keys():
			if court_neighbor_cells.has(cell_value):
				out[block] = Vector2i.ZERO
				break
	return out


static func _composition_offsets(grid: WarrenSpatialGrid,
		base_plate: Dictionary, origin_y: int, storeys: int,
		protected_owners: Dictionary, parcel_id: StringName,
		world_seed: int, forced_offsets: Dictionary) -> Array[Vector2i]:
	var block_count := ceili(float(storeys) / 2.0)
	var out: Array[Vector2i] = []
	var directions: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN,
		Vector2i.LEFT, Vector2i.UP]
	var parcel_hash := String(parcel_id).hash()
	for block in block_count:
		var start_storey := block * 2
		var end_storey := mini(storeys, start_storey + 2)
		# The base block and the block carrying the addressed door retain the
		# authored parcel phase.  All other blocks may shift by one fine cell.
		if forced_offsets.has(block):
			var forced := forced_offsets[block] as Vector2i
			if not _plate_fits(grid, base_plate, forced, origin_y,
					start_storey, end_storey, protected_owners, parcel_id):
				return [] as Array[Vector2i]
			out.append(forced)
			continue
		var previous := out[block - 1]
		var chosen := Vector2i(2147483647, 2147483647)
		# Start the 3D room grammar from a coherent structural column. The former
		# one-cell lateral shift was only a provisional anti-tower heuristic, but it
		# left a one-cell strip of every lower room exposed and forced the roof
		# compiler to tile dozens of plank shoulders. WarrenRoomCompositionPlanner
		# now owns macroscopic changes of shape, merges, cantilevers, and tower
		# relief, so preserve the previous phase whenever it is genuinely available.
		if _plate_fits(grid, base_plate, previous, origin_y,
				start_storey, end_storey, protected_owners, parcel_id):
			chosen = previous
		var start := posmod(Helper._mix64(world_seed ^ parcel_hash \
			^ block * 0x45d9f3b), directions.size())
		for direction_offset in directions.size() if chosen.x == 2147483647 \
				else 0:
			var candidate := previous + directions[
				posmod(start + direction_offset, directions.size())]
			if candidate.length_squared() > 4:
				continue
			if _plate_fits(grid, base_plate, candidate, origin_y,
					start_storey, end_storey, protected_owners, parcel_id):
				chosen = candidate
				break
		# A failed lateral proposal may keep its previous phase only when that
		# exact volume is still allocatable.  The former unconditional fallback
		# let two buildings claim the same residual-mass cells.
		if chosen.x == 2147483647 and _plate_fits(grid, base_plate,
				Vector2i.ZERO, origin_y, start_storey, end_storey,
				protected_owners, parcel_id):
			chosen = Vector2i.ZERO
		if chosen.x == 2147483647:
			# A collision in an optional crown must not erase the valid terrain
			# root, doorway, court wall, or bridge endpoint below it. End the
			# lineage at the last complete two-storey band when no later exact
			# interface depends on the missing mass. This is a real shorter house,
			# and gives the mountain another stepped roof break; it is not a partial
			# or unsupported room stamp.
			var later_forced := false
			for forced_block_value: Variant in forced_offsets.keys():
				if int(forced_block_value) >= block:
					later_forced = true
					break
			if not out.is_empty() and not later_forced:
				return out
			return [] as Array[Vector2i]
		out.append(chosen)
	return out


static func _maze_unfloored_address_detail(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan, parcel: WarrenBuildingParcel) -> String:
	## Why `_parcel_address_has_public_floor` refused this parcel's door, in
	## the vocabulary of the thing that decides it: which fine lane the door
	## opens onto, what the grid made of that lane, and whether the SOURCE
	## calls the macro square a walk cell, a transition, or neither.
	##
	## Maze mode only and only on the failure path. A door faces a passage cell
	## BY CONSTRUCTION in the plot model -- the plot planner put it there -- so
	## a landing with no floor is a disagreement between the planner and the
	## carve, and naming which of the three it is decides where the fix goes.
	var threshold := WarrenParcelConstruction.threshold_cell(parcel)
	if threshold.x == 2147483647:
		return "parcel has no authored threshold cell"
	var landing := threshold + Vector3i(parcel.frontage_direction.x, 0,
		parcel.frontage_direction.y)
	var macro := Vector3i(floori(float(landing.x) / 2.0), landing.y,
		floori(float(landing.z) / 2.0))
	var is_walk := volume.walk_cells.has(macro)
	var is_transition := false
	for transition: WarrenVolumeTransition in volume.transitions:
		for surface: Vector3i in transition.surface_cells():
			if surface == landing:
				is_transition = true
				break
		if is_transition:
			break
	var floor_claim := grid.face_claim(landing, Vector3i.DOWN)
	return ("landing %s (macro %s) use %d floor kind %d owner %s; " \
		+ "source walk=%s transition_surface=%s") % [landing, macro,
		grid.use_at(landing), int(floor_claim.get("kind", -1)),
		floor_claim.get("owner", &"-"), is_walk, is_transition]


static func _maze_exact_composition_conflict(grid: WarrenSpatialGrid,
		base_plate: Dictionary, origin_y: int, storeys: int,
		protected_owners: Dictionary, parcel_id: StringName) -> String:
	## TASK C5c RULING 4's diagnosis. `_composition_offsets` returns an empty
	## offset list without saying which cell refused it, and on a maze town
	## that is the gate almost every uncomposed parcel dies at. Re-walk the
	## parcel's own UNSHIFTED plate and name the first cell that is not free
	## mass: its band, the use it carries, and whoever else claimed it.
	##
	## Maze mode only and only on the failure path, so a composed parcel pays
	## nothing for it. It reads exactly what `_plate_fits` reads, including the
	## paired-allowance escape, so the two can never disagree about what a
	## conflict is.
	var columns: Array[Vector2i] = []
	columns.assign(base_plate.keys())
	columns.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y != b.y:
			return a.y < b.y
		return a.x < b.x)
	for storey in storeys:
		for y_offset in WarrenSpatialGrid.STOREY_CELLS:
			var band := origin_y \
				+ storey * WarrenSpatialGrid.STOREY_CELLS + y_offset
			for column: Vector2i in columns:
				var cell := Vector3i(column.x, band, column.y)
				if not grid.contains(cell):
					return "storey %d cell %s is outside the grid" % [storey,
						cell]
				if grid.use_at(cell) != WarrenSpatialGrid.Use.ALLOCATABLE:
					return "storey %d cell %s is use %d owned by %s" % [
						storey, cell, grid.use_at(cell),
						grid.owner_name_at(cell)]
				var others: Array[StringName] = []
				for owner_value: Variant in (protected_owners.get(cell,
						{}) as Dictionary).keys():
					var other := StringName(owner_value)
					if other == parcel_id:
						continue
					var allowance: Variant = (protected_owners[cell] \
						as Dictionary)[owner_value]
					if allowance is Dictionary \
							and (allowance as Dictionary).has(parcel_id):
						continue
					others.append(other)
				if others.is_empty():
					continue
				others.sort()
				return "storey %d cell %s is claimed by %s" % [storey, cell,
					others]
	return "no unshifted conflict"


static func _plate_fits(grid: WarrenSpatialGrid, base_plate: Dictionary,
		offset: Vector2i, origin_y: int, start_storey: int, end_storey: int,
		protected_owners: Dictionary, parcel_id: StringName) -> bool:
	for storey in range(start_storey, end_storey):
		for column_value: Variant in base_plate.keys():
			var column := column_value as Vector2i
			for y_offset in WarrenSpatialGrid.STOREY_CELLS:
				var cell := Vector3i(column.x + offset.x,
					origin_y + storey * WarrenSpatialGrid.STOREY_CELLS + y_offset,
					column.y + offset.y)
				# TASK F2. The `contains` probe was redundant: `use_at` returns
				# OUTSIDE for a cell the grid does not hold, and OUTSIDE is not
				# ALLOCATABLE, so the second term already rejected exactly the
				# cells the first one did.
				if grid.use_at(cell) != WarrenSpatialGrid.Use.ALLOCATABLE:
					return false
				var owners := protected_owners.get(cell, {}) as Dictionary
				for protected_id_value: Variant in owners.keys():
					if StringName(protected_id_value) == parcel_id:
						continue
					var allowance: Variant = owners[protected_id_value]
					if allowance is Dictionary \
							and (allowance as Dictionary).has(parcel_id):
						continue
					return false
	return true


static func _segment_cells(base_plate: Dictionary, origin_y: int,
		offsets: Array[Vector2i], start_storey: int,
		end_storey: int) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var complete_end_storey := mini(end_storey, offsets.size() * 2)
	for storey in range(start_storey, complete_end_storey):
		var offset := offsets[storey / 2]
		for column_value: Variant in base_plate.keys():
			var column := column_value as Vector2i
			for y_offset in WarrenSpatialGrid.STOREY_CELLS:
				out.append(Vector3i(column.x + offset.x,
					origin_y + storey * WarrenSpatialGrid.STOREY_CELLS + y_offset,
					column.y + offset.y))
	return out


static func _stamp_maze_back_rooms(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan, parcels: WarrenParcelPlan,
		proposals: Array[Dictionary],
		buildings: Array[WarrenBuildingVolume],
		supports: WarrenSupportGraph, required_supports: Array[StringName],
		terrain_support_ids: Array[StringName],
		support_edges: Array[Dictionary], protected_owners: Dictionary,
		construction_program: SettlementFabricProgram) -> Dictionary:
	## The DIRECTED residual pass. The plot planner already decided which mass
	## belongs to which house, so the cells a house's door rectangle left over
	## are not something composition has to discover: each `maze_back_rooms`
	## record is cut into rectangles of the five-kind vocabulary and stamped as
	## rooms of the same building, at the same storeys, reaching the street
	## through the parcel's own volume instead of a threshold of their own.
	##
	## Runs BEFORE `_backfill_residual_rooms`, which then sees the result as
	## ordinary sealed fabric. A rectangle this pass cannot stand up is left in
	## `maze_back_room_unstamped_cells` for the greedy scan to try, never
	## silently dropped.
	##
	## Maze mode only: `maze_back_rooms` exists on no searched plan, so the
	## empty-record guard is what keeps legacy composition byte-identical.
	var empty := {"failed": false, "cell_count": 0, "stamped_cell_count": 0,
		"building_count": 0, "addressed_count": 0, "private_count": 0,
		"rectangle_count": 0, "record_count": 0,
		"refusals": {},
		"unstamped_cells": {"count": 0, "cells": [] as Array[Vector3i]}}
	var records := parcels.audit.get("maze_back_rooms", []) as Array
	if records.is_empty():
		return empty
	var parcel_by_id: Dictionary = {}
	for proposal: Dictionary in proposals:
		var proposed := proposal.parcel as WarrenBuildingParcel
		parcel_by_id[proposed.stable_id] = proposed
	var building_by_id: Dictionary = {}
	var building_by_cell: Dictionary = {}
	var access_by_parcel := _maze_back_room_access_roots(buildings,
		building_by_id, building_by_cell)
	# One work item per (rectangle, storey), ordered by BAND: no back room is
	# then ever stamped before the mass it stands on, and no lower room's roof
	# preflight has to argue with the upper room that will replace that roof.
	var work: Array[Dictionary] = []
	var candidate_cells: Dictionary = {}
	var refusals: Dictionary = {}
	var rectangle_count := 0
	for record_index in records.size():
		var record := records[record_index] as Dictionary
		var parcel := parcel_by_id.get(
			StringName(record["parcel_id"])) as WarrenBuildingParcel
		if parcel == null:
			# The parcel left composition, so its back rooms have no building
			# to belong to and no storeys to copy.
			_note_maze_back_room_refusal(refusals, "parcel left composition")
			continue
		var yaw := _yaw_for_direction(Vector3i.BACK,
			Vector3i(parcel.frontage_direction.x, 0,
				parcel.frontage_direction.y))
		var access_id := StringName(access_by_parcel.get(parcel.stable_id,
			&""))
		if yaw < 0 or access_id.is_empty():
			_note_maze_back_room_refusal(refusals,
				"parcel volume has no frontage yaw or access root")
			continue
		var floor_band := int(record["floor"])
		var rectangles := _maze_back_room_rectangles(
			record["cells"] as Array, parcel.frontage_direction)
		rectangle_count += rectangles.size()
		for rectangle_index in rectangles.size():
			var rectangle := rectangles[rectangle_index] as Dictionary
			for storey in parcel.storey_count():
				var band := floor_band \
					+ storey * WarrenSpatialGrid.STOREY_CELLS
				var cells := _maze_back_room_cells(
					rectangle["columns"] as Array[Vector2i], band)
				var allocatable := true
				for cell: Vector3i in cells:
					if grid.use_at(cell) \
							!= WarrenSpatialGrid.Use.ALLOCATABLE:
						allocatable = false
						continue
					# The denominator is the mass this pass could really have
					# taken: a plot band a street was bored through is not
					# back-room mass and never counts against the share.
					candidate_cells[cell] = true
				if not allocatable:
					_note_maze_back_room_refusal(refusals,
						"storey is not whole allocatable mass")
					continue
				work.append({"kind": StringName(rectangle["kind"]),
					"columns": rectangle["columns"], "cells": cells,
					"band": band, "yaw": yaw, "access_id": access_id,
					"record": record_index, "rectangle": rectangle_index,
					# A back room is the SAME building as the parcel in front
					# of it, so it wears the same roof contract (Task C5
					# ruling 1): a flat-roofed plot's back rooms are slab-
					# crowned too, never pitched.
					"flat_roof": parcel.flat_roof})
	work.sort_custom(_maze_back_room_less)
	var stamped_cells: Dictionary = {}
	var added := 0
	var addressed_count := 0
	var private_count := 0
	for item: Dictionary in work:
		var cells := item["cells"] as Array[Vector3i]
		var blocked := false
		for cell: Vector3i in cells:
			if grid.use_at(cell) != WarrenSpatialGrid.Use.ALLOCATABLE \
					or _residual_feature_protected(grid, cell,
						protected_owners):
				blocked = true
				break
		if blocked:
			_note_maze_back_room_refusal(refusals,
				"mass already spent or feature-reserved")
			continue
		var band := int(item["band"])
		var columns := item["columns"] as Array[Vector2i]
		var kind := StringName(item["kind"])
		var yaw := int(item["yaw"])
		var origin := _maze_back_room_origin(kind, cells, yaw)
		# TASK C5c RULING 3 -- THE SECOND DOOR. A back room whose own shell can
		# open an authored doorway onto a street is an ADDRESSED room of this
		# building, not a windowless cell reached through the house in front of
		# it: the plot is a corner and this is its second frontage.
		var address := _maze_back_room_address(grid, kind, cells, yaw)
		if not address.is_empty():
			yaw = int(address.yaw)
			origin = address.origin as Vector3i
		if origin.x == 2147483647:
			_note_maze_back_room_refusal(refusals,
				"rectangle is not an authored shell")
			continue
		var terrain_bearing := _maze_back_room_bears_terrain(grid, volume,
			columns, band)
		var support_parent_id := &""
		var support_parent_cell := Vector3i(2147483647, 2147483647, 2147483647)
		if not terrain_bearing:
			var support_counts: Dictionary = {}
			var support_cell_by_owner: Dictionary = {}
			for cell: Vector3i in cells:
				if cell.y != band:
					continue
				var below := cell + Vector3i.DOWN
				var owner := StringName(building_by_cell.get(below, &""))
				if owner.is_empty():
					continue
				support_counts[owner] = int(
					support_counts.get(owner, 0)) + 1
				support_cell_by_owner[owner] = below
			support_parent_id = _largest_contact_owner(support_counts)
			var required := maxi(1, columns.size() * 2)
			if support_parent_id.is_empty() \
					or int(support_counts[support_parent_id]) < required:
				# Neither the ground nor half a floorplate of inhabited mass
				# stands under this rectangle. What is usually there instead is
				# structural ROCK, which is derived stone rather than
				# construction and which no room may name as its bearing.
				_note_maze_back_room_refusal(refusals,
					"no terrain or building bearing")
				continue
			support_parent_cell = support_cell_by_owner[
				support_parent_id] as Vector3i
		var parent_building := building_by_id.get(support_parent_id) \
			as WarrenBuildingVolume
		var parent_room := _maze_back_room_parent_room(parent_building,
			support_parent_cell)
		if not terrain_bearing and parent_room == null:
			_note_maze_back_room_refusal(refusals,
				"bearing parent has no room to name")
			continue
		var building_id := StringName("spatial.maze_back.%02d" % added)
		var source_id := StringName("maze.back.%02d" % added)
		var support_source := &"" if terrain_bearing \
			else parent_room.source_parcel_id
		var support_storey := -1 if terrain_bearing \
			else parent_room.source_storey_index
		var roof_feature := _residual_roof_feature(kind, origin,
			volume.world_seed)
		var addressed := not address.is_empty()
		var threshold_cell := address.get("threshold",
			Vector3i(2147483647, 2147483647, 2147483647)) as Vector3i
		var frontage_direction := address.get("direction",
			Vector3i.ZERO) as Vector3i
		var probe := WarrenRoomStamp.new(&"maze.back.envelope.probe",
			&"maze.back.envelope.probe", kind, origin, yaw, 0, terrain_bearing,
			addressed, threshold_cell, frontage_direction, roof_feature,
			support_source, support_storey, 0,
			bool(item.get("flat_roof", false)))
		probe.private_cells.assign(cells)
		if not _residual_room_envelope_fits(probe, building_by_id,
				construction_program, volume.world_seed, grid):
			_note_maze_back_room_refusal(refusals,
				"authored envelope does not fit")
			continue
		if _stamp_maze_private_room(grid, supports, {
				"building_id": building_id, "source_id": source_id,
				"kind": kind, "origin": origin, "yaw": yaw, "cells": cells,
				"floor_band": band, "terrain_bearing": terrain_bearing,
				"addressed": addressed, "threshold_cell": threshold_cell,
				"frontage_direction": frontage_direction,
				"access_id": StringName(item["access_id"]),
				"support_parcel_id": support_source,
				"support_storey_index": support_storey,
				"roof_feature": roof_feature,
				"flat_roof": bool(item.get("flat_roof", false)),
				"parent_building_id": &"" if terrain_bearing \
					else parent_building.stable_id},
				buildings, building_by_id, building_by_cell,
				required_supports, terrain_support_ids,
				support_edges) == null:
			return {"failed": true}
		for cell: Vector3i in cells:
			stamped_cells[cell] = true
		addressed_count += int(addressed)
		private_count += int(not addressed)
		added += 1
	var unstamped: Array[Vector3i] = []
	for cell_value: Variant in candidate_cells.keys():
		var cell := cell_value as Vector3i
		if not stamped_cells.has(cell):
			unstamped.append(cell)
	unstamped.sort_custom(_cell_less)
	return {"failed": false, "cell_count": candidate_cells.size(),
		"stamped_cell_count": stamped_cells.size(), "building_count": added,
		"addressed_count": addressed_count, "private_count": private_count,
		"rectangle_count": rectangle_count, "record_count": records.size(),
		"refusals": refusals,
		"unstamped_cells": {"count": unstamped.size(), "cells": unstamped}}


static func _stamp_maze_private_room(grid: WarrenSpatialGrid,
		supports: WarrenSupportGraph, spec: Dictionary,
		buildings: Array[WarrenBuildingVolume], building_by_id: Dictionary,
		building_by_cell: Dictionary, required_supports: Array[StringName],
		terrain_support_ids: Array[StringName],
		support_edges: Array[Dictionary]) -> WarrenBuildingVolume:
	## The one step both DIRECTED maze passes share: take a rectangle whose
	## mass, shell and bearing are already proved and make it a private room of
	## an existing lineage -- one grid transaction, one `WarrenRoomStamp`, one
	## `WarrenBuildingVolume` reaching the street through `add_private_parent`,
	## and the support-graph wiring. Returns the sealed building, or null with
	## `last_failure` set; a null is a broken invariant, never a refusal, and
	## every refusal a caller can survive is decided BEFORE this is called.
	##
	## `spec` carries `building_id`, `source_id`, `kind`, `origin`, `yaw`,
	## `cells`, `floor_band`, `terrain_bearing`, `access_id`,
	## `support_parcel_id`, `support_storey_index`, `roof_feature`,
	## `parent_building_id` (empty when the room stands on the ground) and the
	## optional `flat_roof` a back room inherits from its own parcel.
	##
	## Task C5c ruling 3 adds the optional `addressed`, `threshold_cell` and
	## `frontage_direction`: a rectangle whose own authored doorway meets a
	## street reaches it directly, with a threshold of its own, instead of
	## through the building in front of it. An addressed room takes the
	## threshold INSTEAD of `add_private_parent` -- exactly as the greedy
	## backfill does -- because a building with both would claim two ways in
	## and `WarrenBuildingVolume.seal` wants one.
	var cells := spec["cells"] as Array[Vector3i]
	var building_id := StringName(spec["building_id"])
	var assign := grid.begin_transaction(building_id)
	var admitted_uses: Array[int] = [WarrenSpatialGrid.Use.ALLOCATABLE]
	if bool(spec.get("allow_outside", false)):
		admitted_uses.append(WarrenSpatialGrid.Use.OUTSIDE)
	if not assign.require_use(cells,
			admitted_uses) \
			or not assign.assign_use(cells,
				WarrenSpatialGrid.Use.PRIVATE_VOLUME, building_id) \
			or not assign.commit():
		last_failure = "maze room %s changed before commit: %s" % [
			building_id, assign.last_rejection]
		return null
	var terrain_bearing := bool(spec["terrain_bearing"])
	var addressed := bool(spec.get("addressed", false))
	var threshold_cell := spec.get("threshold_cell",
		Vector3i(2147483647, 2147483647, 2147483647)) as Vector3i
	var frontage_direction := spec.get("frontage_direction",
		Vector3i.ZERO) as Vector3i
	var room := WarrenRoomStamp.new(
		StringName("%s.room00" % building_id),
		StringName(spec["source_id"]), StringName(spec["kind"]),
		spec["origin"] as Vector3i, int(spec["yaw"]), 0, terrain_bearing,
		addressed, threshold_cell, frontage_direction,
		int(spec["roof_feature"]), StringName(spec["support_parcel_id"]),
		int(spec["support_storey_index"]), 0,
		bool(spec.get("flat_roof", false)))
	var building := WarrenBuildingVolume.new(building_id,
		int(spec["floor_band"]))
	if not building.add_private_cells(cells) \
			or not room.add_private_cells(cells) \
			or not room.seal(grid, building_id) \
			or not building.add_room(room) \
			or addressed and not building.add_threshold(threshold_cell,
				threshold_cell + frontage_direction) \
			or not addressed and not building.add_private_parent(
				StringName(spec["access_id"])) \
			or not building.seal(grid) \
			or not supports.add_node(building_id):
		last_failure = ("maze room %s failed its building transaction: " \
			+ "%s/%s") % [building_id, room.last_rejection,
				building.last_rejection]
		return null
	room.audit.merge(spec.get("room_audit", {}) as Dictionary, true)
	if terrain_bearing:
		terrain_support_ids.append(building_id)
	else:
		support_edges.append({"child": building_id,
			"parent": StringName(spec["parent_building_id"])})
	required_supports.append(building_id)
	buildings.append(building)
	building_by_id[building_id] = building
	for cell: Vector3i in cells:
		building_by_cell[cell] = building_id
	return building


static func _stamp_maze_bridges(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan, parcels: WarrenParcelPlan,
		buildings: Array[WarrenBuildingVolume],
		supports: WarrenSupportGraph, required_supports: Array[StringName],
		terrain_support_ids: Array[StringName],
		support_edges: Array[Dictionary], protected_owners: Dictionary,
		construction_program: SettlementFabricProgram) -> Dictionary:
	## The second DIRECTED pass. A `maze_bridges` record is a one-storey plot
	## the carver selected over a street, so it becomes a private occupied
	## BRIDGE HOUSE -- a tower over a one-cell span or a slim house over a
	## two-cell span. The carver admits the record only when two lateral room
	## columns exist at this exact floor, and this pass must bind the authored
	## shell to those two endpoints. That is the maze producer's skywalk.
	##
	## What it bears on is its two FLANKS, never the street below, so
	## admission runs the residual machinery's own two-sided socket proof
	## against the flanks' real measured recipes -- the same proof
	## `WarrenSpatialFabricCompiler` re-runs strictly when it bonds the span.
	##
	## A record this pass cannot stand up is RELEASED, never patched: the bore
	## remains open and its reason is published in `maze_bridge_outcomes`.
	##
	## Maze mode only: `maze_bridges` exists on no searched plan.
	var empty := {"failed": false, "record_count": 0, "stamped": 0,
		"released": 0, "outcomes": [] as Array[Dictionary]}
	var records := parcels.audit.get("maze_bridges", []) as Array
	if records.is_empty():
		return empty
	var building_by_id: Dictionary = {}
	var building_by_cell: Dictionary = {}
	var access_by_parcel := _maze_back_room_access_roots(buildings,
		building_by_id, building_by_cell)
	var outcomes: Array[Dictionary] = []
	var stamped := 0
	for record_value: Variant in records:
		var record := record_value as Dictionary
		var id := StringName(record["id"])
		var source_span_index := int(record.get("span", stamped))
		var bridge_reservation_owner := \
			&"spatial.skywalk.reserve.maze_bridge."
		var columns: Array[Vector2i] = []
		columns.assign(record["cells"] as Array)
		var source_floor_band := int(record["floor"])
		var compound := _maze_bridge_compound_for(volume, columns)
		if compound.is_empty():
			outcomes.append(_maze_bridge_release(id,
				"source bridge has no sealed two-endpoint compound"))
			continue
		var floor_band := int(compound.floor)
		var top_band := int(compound.top)
		var kind := _maze_bridge_kind(columns)
		if kind.is_empty() \
				or top_band - floor_band != WarrenSpatialGrid.STOREY_CELLS:
			outcomes.append(_maze_bridge_release(id,
				"span is not a one-storey tower or slim shell"))
			continue
		var cells := _maze_bridge_cells(columns, floor_band, top_band)
		var blocked := false
		for cell: Vector3i in cells:
			if grid.use_at(cell) not in [WarrenSpatialGrid.Use.ALLOCATABLE,
					WarrenSpatialGrid.Use.OUTSIDE] \
					or _residual_feature_protected(grid, cell,
						protected_owners, bridge_reservation_owner):
				blocked = true
				break
		if blocked:
			outcomes.append(_maze_bridge_release(id,
				"span mass is already spent or feature-reserved"))
			continue
		var access_id := _maze_bridge_access_id(record, volume, parcels,
			access_by_parcel, columns, source_floor_band)
		var yaw := -1
		var origin := Vector3i(2147483647, 2147483647, 2147483647)
		var pose_candidates: Array[Dictionary] = []
		var preferred_yaw := _maze_bridge_endpoint_roof_yaw(
			(compound.get("endpoint_groups", []) as Array)[0] as Array,
			columns) if kind == &"tower" else -1
		var yaw_candidates: Array[int] = []
		if preferred_yaw >= 0:
			yaw_candidates.append(preferred_yaw)
		for candidate_yaw in 4:
			if not yaw_candidates.has(candidate_yaw):
				yaw_candidates.append(candidate_yaw)
		for candidate_yaw: int in yaw_candidates:
			var candidate := _maze_back_room_origin(kind, cells,
				candidate_yaw)
			if candidate.x == 2147483647:
				continue
			pose_candidates.append({"origin": candidate,
				"yaw_quarters": candidate_yaw})
		if pose_candidates.is_empty():
			outcomes.append(_maze_bridge_release(id,
				"span footprint is not an authored shell"))
			continue
		yaw = int(pose_candidates[0].yaw_quarters)
		origin = pose_candidates[0].origin as Vector3i
		# `_residual_bridge_span` accumulates its diagnosis into one static
		# counter dictionary that `_backfill_residual_rooms` wipes on entry.
		# Snapshot it per record here, or the only explanation of WHY a span
		# did not bind is gone by the time the audit is read.
		_residual_bridge_counts = {}
		# TASK E3b RULING 3. The plot model's own spans are the one caller that
		# may take the BRACKETED JETTY form when only one proved flank binds:
		# every other caller passes nothing and keeps the two-flank-only rule.
		var proved_flanks: Dictionary = {}
		for group_value: Variant in compound.get("endpoint_groups", []) as Array:
			for column_value: Variant in group_value as Array:
				var flank := column_value as Vector2i
				proved_flanks[flank] = true
		var span := _residual_bridge_span(cells, building_by_id,
			building_by_cell, volume.world_seed, construction_program,
			proved_flanks, false)
		var span_counts := _residual_bridge_counts.duplicate(true)
		# Identity follows the source span, not the number of earlier spans that
		# happened to survive authored-envelope qualification. Stable topology ids
		# are required for the endpoint party-roof contract to name the future body
		# before any bridge has been stamped.
		var building_id := StringName("spatial.maze_bridge.%02d" \
			% source_span_index)
		var future_bridge_room_id := StringName("%s.room00" % building_id)
		if span.is_empty():
			# The source proved two room-capable lateral macro columns, but ordinary
			# frontage composition is free to leave that mass unclaimed. Complete
			# those typed endpoints as one compound bridge-house transaction before
			# retrying the exact socket proof. This is not a decorative fallback:
			# both endpoint rooms must have full source-to-ground bearing, authored
			# envelopes, and matching cardinal sockets before either is committed.
			var endpoints: Dictionary = {}
			var endpoint_failures := PackedStringArray()
			for pose: Dictionary in pose_candidates:
				var pose_origin := pose.origin as Vector3i
				var pose_yaw := int(pose.yaw_quarters)
				endpoints = _complete_maze_bridge_endpoints(grid, volume,
					columns, floor_band, top_band, cells, id, access_id, kind,
					pose_origin, pose_yaw, future_bridge_room_id, buildings,
					building_by_id, building_by_cell, supports, required_supports,
					terrain_support_ids, support_edges, protected_owners,
					construction_program, bridge_reservation_owner)
				if bool(endpoints.get("fatal", false)):
					last_failure = String(endpoints.get("detail",
						endpoints.get("reason", "bridge endpoint commit failed")))
					return {"failed": true}
				if bool(endpoints.get("valid", false)):
					origin = pose_origin
					yaw = pose_yaw
					break
				endpoint_failures.append("r%d: %s (%s)" % [pose_yaw,
					String(endpoints.get("reason", "endpoint preflight rejected")),
					String(endpoints.get("detail", ""))])
			if not bool(endpoints.get("valid", false)):
				var endpoint_release := _maze_bridge_release(id, String(
					endpoints.get("reason",
						"two occupied endpoints could not be composed")),
					span_counts)
				endpoint_release["detail"] = "; ".join(endpoint_failures)
				outcomes.append(endpoint_release)
				continue
			access_id = StringName(endpoints.get("access_id", &""))
			_residual_bridge_counts = {}
			span = _residual_bridge_span(cells, building_by_id,
				building_by_cell, volume.world_seed, construction_program,
				proved_flanks, false)
			span_counts = _residual_bridge_counts.duplicate(true)
			if span.is_empty() or (span.room_ids as Array).size() != 2:
				last_failure = "bridge endpoint transaction did not produce two sockets"
				return {"failed": true}
		var parent_building := building_by_id.get(
			StringName(span.parent_building_id)) as WarrenBuildingVolume
		# A pre-existing exact endpoint is itself a sealed inhabited access
		# lineage. Source-reserved compounds normally return an addressed endpoint
		# above; this branch preserves old fixtures whose flank houses predate the
		# topology-owned endpoint contract without requiring the parcel index to
		# rediscover their ownership.
		if access_id.is_empty() and parent_building != null:
			access_id = parent_building.stable_id
		if access_id.is_empty():
			outcomes.append(_maze_bridge_release(id,
				"two-ended bridge compound has no inhabited access root",
				span_counts))
			continue
		var parent_room := _maze_back_room_parent_room(parent_building,
			span.parent_contact_cell as Vector3i)
		if parent_room == null:
			outcomes.append(_maze_bridge_release(id,
				"bearing flank has no room to name", span_counts))
			continue
		# An occupied bridge is a house, not a plank lid. Its envelope probe and
		# committed room therefore require the same complete pitched crown as any
		# other terminal inhabited mass. Square towers and reversed rectangular
		# stamps can share one logical footprint while presenting different measured
		# eaves. Select among those finite authored poses only after proving the full
		# shell, roof, and two flank seams together; the first footprint match is not
		# a construction decision.
		var bridge_rejection := "bridge has no measured authored pose"
		var pose_failures := PackedStringArray()
		for pose: Dictionary in pose_candidates:
			var pose_origin := pose.origin as Vector3i
			var pose_yaw := int(pose.yaw_quarters)
			var pose_roof_feature := _residual_roof_feature(kind, pose_origin,
				volume.world_seed)
			var probe := WarrenRoomStamp.new(future_bridge_room_id,
				&"maze.bridge.envelope.probe", kind, pose_origin, pose_yaw, 0,
				false, false,
				Vector3i(2147483647, 2147483647, 2147483647), Vector3i.ZERO,
				pose_roof_feature, parent_room.source_parcel_id,
				parent_room.source_storey_index, 0, false)
			probe.private_cells.assign(cells)
			probe.audit["bridge_support_room_ids"] = \
				(span.room_ids as Array).duplicate()
			var one_rejection := _residual_room_envelope_rejection(probe,
				building_by_id, construction_program, volume.world_seed, grid)
			if one_rejection.is_empty():
				origin = pose_origin
				yaw = pose_yaw
				bridge_rejection = ""
				break
			pose_failures.append("r%d: %s" % [pose_yaw, one_rejection])
		if not bridge_rejection.is_empty():
			var envelope_release := _maze_bridge_release(id,
				"authored envelope does not fit", span_counts)
			envelope_release["detail"] = "; ".join(pose_failures)
			outcomes.append(envelope_release)
			continue
		var roof_feature := _residual_roof_feature(kind, origin,
			volume.world_seed)
		var built := _stamp_maze_private_room(grid, supports, {
			"building_id": building_id,
			"source_id": StringName("maze.bridge.%02d" % source_span_index),
			"kind": kind, "origin": origin, "yaw": yaw, "cells": cells,
			"floor_band": floor_band, "terrain_bearing": false,
			"access_id": access_id,
			"support_parcel_id": parent_room.source_parcel_id,
			"support_storey_index": parent_room.source_storey_index,
			"roof_feature": roof_feature,
			"flat_roof": false,
			"allow_outside": true,
			"parent_building_id": parent_building.stable_id},
			buildings, building_by_id, building_by_cell, required_supports,
			terrain_support_ids, support_edges)
		if built == null:
			return {"failed": true}
		# Stamped after seal(), which rebuilds the room's audit. This is what
		# the fabric compiler reads to bond BOTH span sockets instead of
		# looking for a bearing parent underneath the room.
		var room := built.room_records[0]
		room.audit["bridge_support_room_ids"] = span.room_ids
		room.audit["bridge_support_directions"] = (span.get(
			"support_directions", []) as Array).duplicate()
		room.audit["bridge_support_building_ids"] = (span.get(
			"support_building_ids", []) as Array).duplicate()
		room.audit["bridge_support_records"] = (span.get(
			"support_records", []) as Array).duplicate(true)
		room.audit["bridge_is_bracketed_jetty"] = bool(span.get(
			"is_bracketed_jetty", false))
		room.audit["bridge_is_terrain_arcade"] = false
		outcomes.append({"id": id, "outcome": "stamped", "reason": "",
			"span_counts": span_counts})
		stamped += 1
	return {"failed": false, "record_count": records.size(),
		"stamped": stamped, "released": outcomes.size() - stamped,
		"outcomes": outcomes}


static func _maze_bridge_compound_for(volume: WarrenVolumePlan,
		span_columns: Array[Vector2i]) -> Dictionary:
	## Read the topology-first bridge record selected before public air was
	## committed. Matching its macro span as a set keeps this independent of
	## record order while preserving one authoritative floor and endpoint pair.
	var compounds := volume.mass_context.get(&"maze_bridge_compounds", {}) \
		as Dictionary
	var wanted: Dictionary = {}
	for column: Vector2i in span_columns:
		wanted[column] = true
	for plan_value: Variant in compounds.get("plans", []) as Array:
		var plan := plan_value as Dictionary
		var planned: Dictionary = {}
		for column_value: Variant in plan.get("columns", []) as Array:
			planned[column_value as Vector2i] = true
		if planned.size() != wanted.size():
			continue
		var same := true
		for column_value: Variant in planned.keys():
			same = same and wanted.has(column_value as Vector2i)
		if same:
			return plan
	return {}


static func _maze_bridge_endpoint_roof_clearance_cells(
		grid: WarrenSpatialGrid, volume: WarrenVolumePlan, compound: Dictionary,
		program: SettlementFabricProgram) -> Dictionary:
	## Raster the exact endpoint seam gables AND occupied bridge-house envelope
	## promised by the source compound. This is consumed before ordinary room
	## composition, so every mandatory crown is protected fact rather than a late
	## collision repair. Reserving only the endpoint gables allowed a neighboring
	## terminal roof to take the future bridge roof's eave space; the endpoint
	## boxes then survived while the actual connector was discarded.
	if grid == null or volume == null or program == null:
		return {}
	var span_columns: Array[Vector2i] = []
	span_columns.assign(compound.get("columns", []) as Array)
	var floor_band := int(compound.get("floor", 0))
	var top_band := int(compound.get("top", floor_band \
		+ WarrenSpatialGrid.STOREY_CELLS))
	var components: Array[Dictionary] = []
	var bridge_kind := _maze_bridge_kind(span_columns)
	var bridge_cells := _maze_bridge_cells(span_columns, floor_band, top_band)
	if bridge_kind.is_empty() or bridge_cells.is_empty():
		return {}
	var bridge_yaw := -1
	var bridge_origin := Vector3i(2147483647, 2147483647, 2147483647)
	var endpoint_groups := compound.get("endpoint_groups", []) as Array
	var preferred_yaw := _maze_bridge_endpoint_roof_yaw(
		endpoint_groups[0] as Array, span_columns) \
		if bridge_kind == &"tower" and not endpoint_groups.is_empty() else -1
	var yaw_candidates: Array[int] = []
	if preferred_yaw >= 0:
		yaw_candidates.append(preferred_yaw)
	for candidate_yaw in 4:
		if not yaw_candidates.has(candidate_yaw):
			yaw_candidates.append(candidate_yaw)
	for candidate_yaw: int in yaw_candidates:
		var candidate_origin := _maze_back_room_origin(bridge_kind,
			bridge_cells, candidate_yaw)
		if candidate_origin.x == 2147483647:
			continue
		bridge_yaw = candidate_yaw
		bridge_origin = candidate_origin
		break
	if bridge_yaw < 0:
		return {}
	var span_index := int(compound.get("span_index", 0))
	var bridge_room_id := StringName("spatial.maze_bridge.%02d.room00" \
		% span_index)
	var bridge_room := WarrenRoomStamp.new(bridge_room_id,
		StringName("maze.bridge.%02d" % span_index), bridge_kind,
		bridge_origin, bridge_yaw, 0, false, false,
		Vector3i(2147483647, 2147483647, 2147483647), Vector3i.ZERO,
		_residual_roof_feature(bridge_kind, bridge_origin, volume.world_seed),
		&"maze.bridge.preplan.support", 0, 0, false)
	bridge_room.private_cells.assign(bridge_cells)
	bridge_room.audit["bridge_support_room_ids"] = [
		&"maze.bridge.preplan.endpoint.0",
		&"maze.bridge.preplan.endpoint.1",
	] as Array[StringName]
	var bridge_recipe_id := WarrenSpatialFabricCompiler._room_recipe_id(
		bridge_room, volume.world_seed, false)
	if program.recipe(bridge_recipe_id) == null:
		return {}
	# Reserve the complete occupied bridge-house envelope, not only its upper
	# roof placements. A lower neighboring house closes at the bridge's floor
	# band; roof-only clearance allowed that terminal gable to enter the future
	# bridge wall/floor envelope even though both roofs looked independently
	# valid. The compound's endpoint rooms are stamped later under this same
	# reservation owner, so the complete reservation excludes only unrelated
	# construction and does not push the two required bearings away.
	components.append({"recipe_id": bridge_recipe_id,
		"origin": bridge_origin, "yaw_quarters": bridge_yaw})
	for group_value: Variant in compound.get("endpoint_groups", []) as Array:
		var columns: Array[Vector2i] = []
		columns.assign(group_value as Array)
		var kind := _maze_bridge_kind(columns)
		var cells := _maze_bridge_cells(columns, floor_band, top_band)
		if kind.is_empty() or cells.is_empty():
			return {}
		var yaw := -1
		var origin := Vector3i(2147483647, 2147483647, 2147483647)
		for candidate_yaw in 4:
			var candidate_origin := _maze_back_room_origin(kind, cells,
				candidate_yaw)
			if candidate_origin.x != 2147483647:
				yaw = candidate_yaw
				origin = candidate_origin
				break
		if yaw < 0:
			return {}
		var address := _maze_back_room_address(grid, kind, cells, yaw)
		if not address.is_empty():
			yaw = int(address.yaw)
			origin = address.origin as Vector3i
		var room := WarrenRoomStamp.new(&"maze.bridge.roof.reserve",
			&"maze.bridge.roof.reserve", kind, origin, yaw, 0, true, false,
			Vector3i(2147483647, 2147483647, 2147483647), Vector3i.ZERO,
			_residual_roof_feature(kind, origin, volume.world_seed),
			&"maze.bridge.roof.reserve", 0, 0, false)
		room.private_cells.assign(cells)
		var party_yaw := _maze_bridge_endpoint_roof_yaw(columns, span_columns)
		if kind == &"tower" and party_yaw >= 0:
			room.audit["bridge_party_roof_yaw_quarters"] = party_yaw
		var endpoint_recipe_id := WarrenSpatialFabricCompiler._room_recipe_id(
			room, volume.world_seed, false)
		if program.recipe(endpoint_recipe_id) == null:
			return {}
		# The endpoint is a complete inhabited room, not only a roof marker. Its
		# lower wall/floor band can meet a shorter neighbor's future gable even when
		# their private voxels do not overlap. Reserve that measured shell together
		# with its seam roof so composition cannot create a lower crown that the
		# endpoint would later cut through.
		components.append({"recipe_id": endpoint_recipe_id,
			"origin": origin, "yaw_quarters": yaw})
		var candidates := WarrenSpatialFabricCompiler._full_roof_candidates(room,
			volume.world_seed)
		if candidates.is_empty():
			return {}
		var chosen := candidates[0] as Dictionary
		var roof_id := StringName(chosen.recipe_id)
		if program.recipe(roof_id) == null:
			return {}
		components.append({"recipe_id": roof_id,
			"origin": origin + Vector3i.UP * WarrenSpatialGrid.STOREY_CELLS,
			"yaw_quarters": posmod(yaw + int(chosen.yaw_offset), 4)})
	return _skywalk_visual_clearance_cells(components, program)


static func _complete_maze_bridge_endpoints(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan, span_columns: Array[Vector2i], floor_band: int,
		top_band: int, span_cells: Array[Vector3i], bridge_id: StringName,
		access_id: StringName, bridge_kind: StringName,
		bridge_origin: Vector3i, bridge_yaw: int,
		future_bridge_room_id: StringName,
		buildings: Array[WarrenBuildingVolume],
		building_by_id: Dictionary, building_by_cell: Dictionary,
		supports: WarrenSupportGraph, required_supports: Array[StringName],
		terrain_support_ids: Array[StringName],
		support_edges: Array[Dictionary], protected_owners: Dictionary,
		program: SettlementFabricProgram,
		bridge_reservation_owner: StringName) -> Dictionary:
	## Compose the two ends of a maze skywalk from the same source proof that
	## chose its route span. One-cell spans receive two tower ends; two-cell
	## straight spans receive two slim-house ends. Every end occupies a complete
	## authored room footprint and reaches source ground through its whole macro
	## plate. The pair is preflighted together, including its sockets to the
	## future bridge body, before the grid changes, so a partial bridge compound
	## cannot survive a failed second end.
	var compound := _maze_bridge_compound_for(volume, span_columns)
	var groups: Array = compound.get("endpoint_groups", []) as Array
	if groups.size() != 2:
		return {"valid": false,
			"reason": "source did not prove two opposite endpoint footprints"}
	var span_set: Dictionary = {}
	for cell: Vector3i in span_cells:
		span_set[cell] = true
	var plans: Array[Dictionary] = []
	for endpoint_index in groups.size():
		var endpoint_columns: Array[Vector2i] = []
		endpoint_columns.assign(groups[endpoint_index] as Array)
		var kind := _maze_bridge_kind(endpoint_columns)
		var cells := _maze_bridge_cells(endpoint_columns, floor_band, top_band)
		if kind.is_empty() or cells.is_empty():
			return {"valid": false,
				"reason": "endpoint footprint has no complete room recipe"}
		for cell: Vector3i in cells:
			if grid.use_at(cell) not in [WarrenSpatialGrid.Use.ALLOCATABLE,
					WarrenSpatialGrid.Use.OUTSIDE] \
					or _residual_feature_protected(grid, cell,
						protected_owners, bridge_reservation_owner):
				return {"valid": false,
					"reason": "endpoint footprint was consumed before bridge composition",
					"detail": "cell=%s use=%d owner=%s" % [cell,
						grid.use_at(cell), grid.owner_name_at(cell)]}
		var direct_terrain_bearing := _maze_back_room_bears_terrain(grid,
			volume, endpoint_columns, floor_band)
		var yaw := -1
		var origin := Vector3i(2147483647, 2147483647, 2147483647)
		for candidate_yaw in 4:
			var candidate_origin := _maze_back_room_origin(kind, cells,
				candidate_yaw)
			if candidate_origin.x == 2147483647:
				continue
			yaw = candidate_yaw
			origin = candidate_origin
			break
		if yaw < 0:
			return {"valid": false,
				"reason": "endpoint cells do not match an authored room phase"}
		var address := _maze_back_room_address(grid, kind, cells, yaw)
		if not address.is_empty():
			yaw = int(address.yaw)
			origin = address.origin as Vector3i
		# A bridge end may sit on a complete, isolated two-band source-rock
		# course.  That is structurally sound but visually reads as the raw 1x1
		# stone cube reported in review.  Promote that course to the preceding
		# authored storey of this SAME tower lineage.  The decision is made from
		# topology and occupancy only: joined terrain stays terrain, incomplete
		# or obstructed courses stay ineligible, and no seed/location participates.
		var promoted_support := _maze_bridge_endpoint_support_course(grid,
			volume, endpoint_columns, floor_band, yaw, protected_owners,
			bridge_reservation_owner)
		var promotes_support := not promoted_support.is_empty()
		var addressed := not address.is_empty()
		var threshold_cell := address.get("threshold",
			Vector3i(2147483647, 2147483647, 2147483647)) as Vector3i
		var frontage_direction := address.get("direction",
			Vector3i.ZERO) as Vector3i
		var building_id := StringName("spatial.maze_bridge_end.%s.%02d" % [
			String(bridge_id).trim_prefix("bridge."), endpoint_index])
		var room_id := StringName("%s.room%02d" % [building_id,
			1 if promotes_support else 0])
		var source_id := StringName("maze.bridge_end.%s.%02d" % [
			String(bridge_id), endpoint_index])
		var room := WarrenRoomStamp.new(room_id, StringName(
			"maze.bridge_end.%s.%02d" % [String(bridge_id), endpoint_index]),
			kind, origin, yaw, 1 if promotes_support else 0,
			not promotes_support, addressed,
			threshold_cell, frontage_direction,
			_residual_roof_feature(kind, origin, volume.world_seed),
			source_id, 0,
			0, false)
		if not room.add_private_cells(cells):
			return {"valid": false,
				"reason": "endpoint room could not claim its exact private cells"}
		var party_roof_yaw := _maze_bridge_endpoint_roof_yaw(endpoint_columns,
			span_columns)
		if kind == &"tower" and party_roof_yaw >= 0:
			room.audit["bridge_party_roof_yaw_quarters"] = party_roof_yaw
			room.audit["roof_party_allowed_room_ids"] = [
				future_bridge_room_id] as Array[StringName]
		var portal_bearing := not WarrenSpatialFeatureSolver \
			._tunnel_roof_arcade_geometry(room, grid, volume).is_empty()
		if not direct_terrain_bearing and not portal_bearing \
				and not promotes_support:
			return {"valid": false,
				"reason": ("endpoint has neither continuous source bearing nor " \
					+ "complete terrain-reaching arcade portal")}
		var envelope_rejection := _residual_room_envelope_rejection(room,
			building_by_id, program, volume.world_seed, grid)
		if promotes_support:
			var support_probe := WarrenRoomStamp.new(
				StringName("%s.room00" % building_id), source_id, kind,
				promoted_support.origin as Vector3i, yaw, 0, true, false,
				Vector3i(2147483647, 2147483647, 2147483647),
				Vector3i.ZERO, 0, &"", -1, 0, false)
			support_probe.private_cells.assign(
				promoted_support.cells as Array[Vector3i])
			var support_rejection := _residual_room_envelope_rejection(
				support_probe, building_by_id, program, volume.world_seed, grid)
			if not support_rejection.is_empty():
				return {"valid": false,
					"reason": "promoted endpoint support envelope does not fit",
					"detail": support_rejection}
		var envelope_fits := envelope_rejection.is_empty()
		var socket_binding := _bridge_flank_binding(span_set, room,
			StringName("bridge.endpoint.probe.%d" % endpoint_index),
			volume.world_seed, program)
		if not envelope_fits or socket_binding.is_empty():
			return {"valid": false,
				"reason": "endpoint authored envelope or bridge socket does not fit",
				"detail": ("endpoint=%d envelope=%s bridge_socket=%s; %s" % [
					endpoint_index, envelope_fits, not socket_binding.is_empty(),
					envelope_rejection])}
		plans.append({"room": room, "cells": cells, "kind": kind,
			"origin": origin, "yaw": yaw,
			"promoted_support": promoted_support,
			"source_id": source_id, "addressed": addressed,
			"threshold_cell": threshold_cell,
			"frontage_direction": frontage_direction})
	# Opposite endpoint footprints cannot meet, but run the measured pairwise
	# envelope proof explicitly so future wider bridge recipes preserve the same
	# all-or-nothing transaction.
	if plans.size() == 2:
		var a := plans[0].room as WarrenRoomStamp
		var b := plans[1].room as WarrenRoomStamp
		if not _residual_room_envelope_fits(a, {
				&"endpoint.other": _probe_building_for_room(b)}, program,
				volume.world_seed, grid):
			return {"valid": false,
				"reason": "endpoint authored envelopes overlap"}
	# Access and construction are one compound proof. A topology-owned endpoint
	# may root the bridge directly only through the exact authored threshold the
	# public-realm grid already carries. Otherwise an older pre-composed flank
	# lineage must exist. Merely touching a random room is never promoted to a
	# private entrance.
	var addressed_endpoint_id := &""
	for endpoint: Dictionary in plans:
		if bool(endpoint.addressed):
			addressed_endpoint_id = _room_building_id(
				(endpoint.room as WarrenRoomStamp).stable_id)
			break
	var compound_access_id := addressed_endpoint_id \
		if not addressed_endpoint_id.is_empty() else access_id
	if compound_access_id.is_empty():
		return {"valid": false,
			"reason": "two-ended bridge compound has no exact public access root"}
	# Preflight the future bridge house against BOTH prospective endpoint
	# envelopes before changing the grid. This closes the former partial-commit
	# hole in which two endpoint boxes survived when the pitched bridge crown
	# failed only after their commits.
	var probe_buildings := building_by_id.duplicate()
	for endpoint: Dictionary in plans:
		var endpoint_room := endpoint.room as WarrenRoomStamp
		var endpoint_id := _room_building_id(endpoint_room.stable_id)
		probe_buildings[endpoint_id] = _probe_building_for_room(endpoint_room,
			endpoint_id)
	var bridge_probe := WarrenRoomStamp.new(future_bridge_room_id,
		&"maze.bridge.envelope.probe", bridge_kind, bridge_origin,
		bridge_yaw,
		0, false, false,
		Vector3i(2147483647, 2147483647, 2147483647), Vector3i.ZERO,
		_residual_roof_feature(bridge_kind, bridge_origin, volume.world_seed),
		&"maze.bridge.envelope.probe.support", 0, 0, false)
	bridge_probe.private_cells.assign(span_cells)
	var prospective_support_room_ids: Array[StringName] = []
	for endpoint: Dictionary in plans:
		prospective_support_room_ids.append(
			(endpoint.room as WarrenRoomStamp).stable_id)
	bridge_probe.audit["bridge_support_room_ids"] = \
		prospective_support_room_ids
	var bridge_rejection := _residual_room_envelope_rejection(bridge_probe,
		probe_buildings, program, volume.world_seed, grid)
	if not bridge_rejection.is_empty():
		return {"valid": false,
			"reason": "complete occupied bridge authored envelope does not fit",
			"detail": bridge_rejection}
	for endpoint_index in plans.size():
		var endpoint := plans[endpoint_index]
		var room := endpoint.room as WarrenRoomStamp
		var building_id := _room_building_id(room.stable_id)
		var addressed := bool(endpoint.addressed)
		var endpoint_access_id := compound_access_id
		var promoted_support := endpoint.promoted_support as Dictionary
		var committed: WarrenBuildingVolume = null
		if not promoted_support.is_empty():
			committed = _stamp_maze_bridge_endpoint_stack(grid, supports, {
				"building_id": building_id,
				"source_id": StringName(endpoint.source_id),
				"upper_room": room,
				"upper_cells": endpoint.cells,
				"support_cells": promoted_support.cells,
				"support_origin": promoted_support.origin,
				"support_floor_band": int(promoted_support.floor_band),
				"addressed": addressed,
				"threshold_cell": endpoint.threshold_cell,
				"frontage_direction": endpoint.frontage_direction,
				"access_id": endpoint_access_id,
			}, buildings, building_by_id, building_by_cell,
				required_supports, terrain_support_ids)
		else:
			committed = _stamp_maze_private_room(grid, supports, {
			"building_id": building_id,
			"source_id": StringName(endpoint.source_id),
			"kind": room.kind, "origin": room.lattice_origin,
			"yaw": room.yaw_quarters, "cells": endpoint.cells,
			"floor_band": floor_band, "terrain_bearing": true,
			"addressed": addressed,
			"threshold_cell": endpoint.threshold_cell,
			"frontage_direction": endpoint.frontage_direction,
			"access_id": endpoint_access_id,
			"support_parcel_id": room.source_parcel_id,
			"support_storey_index": room.source_storey_index,
			"roof_feature": room.roof_feature, "flat_roof": false,
			"room_audit": room.audit.duplicate(true),
			"allow_outside": true,
			"parent_building_id": &""}, buildings, building_by_id,
			building_by_cell, required_supports, terrain_support_ids,
			support_edges)
		if committed == null:
			return {"valid": false, "fatal": true,
				"reason": "preflighted endpoint commit failed",
				"detail": last_failure}
	return {"valid": true, "endpoint_count": plans.size(),
		"access_id": compound_access_id}


static func _maze_bridge_endpoint_support_course(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan, columns: Array[Vector2i], floor_band: int,
		yaw: int, protected_owners: Dictionary,
		bridge_reservation_owner: StringName) -> Dictionary:
	## Turn a complete source-rock storey directly below a tower bridge end into
	## a construction proposal.  A tower end one authored storey above its real
	## terrain bearing is a two-storey tower, regardless of whether one side is
	## embedded in a broader hill.  This lets the normal room compiler replace
	## every exposed rock face with one coherent facade while preserving the
	## exact source mass and terrain load path.
	if columns.size() != 1 or yaw < 0:
		return {}
	var support_floor := floor_band - WarrenSpatialGrid.STOREY_CELLS
	var cells := _maze_bridge_cells(columns, support_floor, floor_band)
	if cells.is_empty() or not _maze_back_room_bears_terrain(grid, volume,
			columns, support_floor):
		return {}
	for cell: Vector3i in cells:
		if not volume.has_mass(Vector3i(floori(float(cell.x) * 0.5),
				cell.y, floori(float(cell.z) * 0.5))) \
				or grid.use_at(cell) not in [WarrenSpatialGrid.Use.ALLOCATABLE,
					WarrenSpatialGrid.Use.OUTSIDE] \
				or _residual_feature_protected(grid, cell, protected_owners,
					bridge_reservation_owner):
			return {}
	var origin := _maze_back_room_origin(&"tower", cells, yaw)
	if origin.x == 2147483647:
		return {}
	return {"cells": cells, "floor_band": support_floor, "origin": origin}


static func _stamp_maze_bridge_endpoint_stack(grid: WarrenSpatialGrid,
		supports: WarrenSupportGraph, spec: Dictionary,
		buildings: Array[WarrenBuildingVolume], building_by_id: Dictionary,
		building_by_cell: Dictionary, required_supports: Array[StringName],
		terrain_support_ids: Array[StringName]) -> WarrenBuildingVolume:
	## Commit an isolated rock-supported bridge endpoint as one two-storey
	## building.  The lower course and endpoint room share an owner and source
	## lineage, so bearing, facade suppression, intermediate-roof suppression,
	## and the final pitched crown all follow from ordinary construction rules.
	var building_id := StringName(spec.building_id)
	var source_id := StringName(spec.source_id)
	var upper_room := spec.upper_room as WarrenRoomStamp
	var lower_cells := spec.support_cells as Array[Vector3i]
	var upper_cells := spec.upper_cells as Array[Vector3i]
	var all_cells: Array[Vector3i] = []
	all_cells.append_array(lower_cells)
	all_cells.append_array(upper_cells)
	var assign := grid.begin_transaction(building_id)
	if not assign.require_use(all_cells, [WarrenSpatialGrid.Use.ALLOCATABLE,
			WarrenSpatialGrid.Use.OUTSIDE]) \
			or not assign.assign_use(all_cells,
				WarrenSpatialGrid.Use.PRIVATE_VOLUME, building_id) \
			or not assign.commit():
		last_failure = "maze endpoint stack %s changed before commit: %s" % [
			building_id, assign.last_rejection]
		return null
	var lower_room := WarrenRoomStamp.new(
		StringName("%s.room00" % building_id), source_id, &"tower",
		spec.support_origin as Vector3i, upper_room.yaw_quarters, 0, true,
		false, Vector3i(2147483647, 2147483647, 2147483647),
		Vector3i.ZERO, 0, &"", -1, 0, false)
	if not lower_room.add_private_cells(lower_cells):
		last_failure = "maze endpoint stack %s could not claim lower room" % \
			building_id
		return null
	var upper_audit := upper_room.audit.duplicate(true)
	var building := WarrenBuildingVolume.new(building_id,
		int(spec.support_floor_band))
	var addressed := bool(spec.addressed)
	var threshold_cell := spec.threshold_cell as Vector3i
	var frontage_direction := spec.frontage_direction as Vector3i
	if not building.add_private_cells(all_cells) \
			or not lower_room.seal(grid, building_id) \
			or not upper_room.seal(grid, building_id) \
			or not building.add_room(lower_room) \
			or not building.add_room(upper_room) \
			or addressed and not building.add_threshold(threshold_cell,
				threshold_cell + frontage_direction) \
			or not addressed and not building.add_private_parent(
				StringName(spec.access_id)) \
			or not building.seal(grid) \
			or not supports.add_node(building_id):
		last_failure = ("maze endpoint stack %s failed its building " \
			+ "transaction: lower=%s upper=%s building=%s") % [building_id,
			lower_room.last_rejection, upper_room.last_rejection,
			building.last_rejection]
		return null
	upper_room.audit.merge(upper_audit, true)
	building.audit["promoted_isolated_rock_support"] = true
	building.audit["promoted_support_cell_count"] = lower_cells.size()
	required_supports.append(building_id)
	terrain_support_ids.append(building_id)
	buildings.append(building)
	building_by_id[building_id] = building
	for cell: Vector3i in all_cells:
		building_by_cell[cell] = building_id
	return building


static func _room_building_id(room_id: StringName) -> StringName:
	return StringName(String(room_id).get_slice(".room", 0))


static func _maze_bridge_endpoint_roof_yaw(endpoint_columns: Array,
		span_columns: Array[Vector2i]) -> int:
	## The compact gable's ridge is local Z.  A one-cell bridge compound joins
	## its endpoint houses across one cardinal party plane, so choose the one
	## quarter-turn whose ridge reaches that plane.  The axis is undirected:
	## either gable end may face the span without changing the envelope.
	var axis := Vector3i.ZERO
	var best_distance := 2147483647
	for endpoint_value: Variant in endpoint_columns:
		var endpoint := endpoint_value as Vector2i
		for span: Vector2i in span_columns:
			var delta := span - endpoint
			var distance := absi(delta.x) + absi(delta.y)
			if distance < best_distance:
				best_distance = distance
				axis = Vector3i(signi(delta.x), 0, signi(delta.y))
	if best_distance != 1 or axis == Vector3i.ZERO:
		return -1
	for yaw in 4:
		var ridge := FabricRecipe.transform_direction(Vector3i.BACK, yaw)
		if ridge == axis or ridge == -axis:
			return yaw
	return -1


static func _probe_building_for_room(room: WarrenRoomStamp,
		stable_id: StringName = &"bridge.endpoint.probe") \
		-> WarrenBuildingVolume:
	var building := WarrenBuildingVolume.new(stable_id,
		room.lattice_origin.y)
	building.room_records.append(room)
	return building


static func _maze_bridge_endpoint_groups(span_columns: Array[Vector2i],
		proved: Dictionary) -> Array[Array]:
	## Partition the carver's proved lateral columns into the two sides of the
	## straight span. The result retains the span's macro extent on each side,
	## which is why a two-cell bridge receives slim endpoints instead of four
	## unrelated tower boxes.
	if span_columns.is_empty() or proved.is_empty():
		return [] as Array[Array]
	var axis := Vector2i.RIGHT
	if span_columns.size() > 1:
		axis = span_columns[1] - span_columns[0]
		axis = Vector2i(signi(axis.x), signi(axis.y))
	var lateral := Vector2i(-axis.y, axis.x)
	var negative: Array[Vector2i] = []
	var positive: Array[Vector2i] = []
	for flank_value: Variant in proved.keys():
		var flank := flank_value as Vector2i
		var nearest := span_columns[0]
		var nearest_distance := 2147483647
		for span: Vector2i in span_columns:
			var distance := absi(flank.x - span.x) + absi(flank.y - span.y)
			if distance < nearest_distance:
				nearest = span
				nearest_distance = distance
		var delta := flank - nearest
		var side: int = delta.x * lateral.x + delta.y * lateral.y
		if side < 0:
			negative.append(flank)
		elif side > 0:
			positive.append(flank)
	negative.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.x < b.x if a.y == b.y else a.y < b.y)
	positive.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.x < b.x if a.y == b.y else a.y < b.y)
	if negative.size() != span_columns.size() \
			or positive.size() != span_columns.size():
		return [] as Array[Array]
	return [negative as Array, positive as Array] as Array[Array]


static func _maze_bridge_proved_flanks(volume: WarrenVolumePlan,
		columns: Array[Vector2i]) -> Dictionary:
	## TASK E3 RULING 3. The macro columns `WarrenMazeCarver` proved could
	## carry a room at this span's own band, as a set. Matched on the span's
	## own columns rather than on a record index, so the two sides cannot drift
	## apart if either list is ever reordered. `{}` when the source carries no
	## ledger -- an older plan, or a span this carver never tested -- and an
	## empty set restores the unrestricted search, which is exactly the
	## behaviour every caller had before this task.
	var source := volume.mass_context.get(&"maze_source_plan") \
		as WarrenMazeSourcePlan
	if source == null or source.excavation == null:
		return {}
	var wanted: Dictionary = {}
	for column: Vector2i in columns:
		wanted[column] = true
	for record_value: Variant in source.excavation.bridge_span_audit.get(
			"seeded", []) as Array:
		var record := record_value as Dictionary
		var span_columns: Dictionary = {}
		for cell_value: Variant in record.get("cells", []) as Array:
			var cell := cell_value as Vector3i
			span_columns[Vector2i(cell.x, cell.z)] = true
		if span_columns.size() != wanted.size():
			continue
		var same := true
		for column_value: Variant in span_columns.keys():
			same = same and wanted.has(column_value as Vector2i)
		if not same:
			continue
		# TASK E3b RULING 3. The ROOM-CAPABLE subset, not every walling flank:
		# those are the columns the seed-time proof really argued could carry a
		# room at this band, and binding through anything else is what produced
		# `bridge room ... has no built flank` before E3.
		var out: Dictionary = {}
		for column_value: Variant in record.get("room_flanks", []) as Array:
			out[column_value as Vector2i] = true
		return out
	return {}


static func _maze_bridge_release(id: StringName, reason: String,
		counts: Dictionary = {}) -> Dictionary:
	return {"id": id, "outcome": "released", "reason": reason,
		"span_counts": counts}


static func _maze_bridge_kind(columns: Array[Vector2i]) -> StringName:
	## A retained span is one macro cell, or two in a line -- exactly the tower
	## and slim shells of the room vocabulary. Anything else is a span shape
	## this pass does not author, and it is released rather than forced.
	if columns.size() == 1:
		return &"tower"
	if columns.size() != 2:
		return &""
	var delta := columns[1] - columns[0]
	return &"slim" if absi(delta.x) + absi(delta.y) == 1 else &""


static func _maze_bridge_cells(columns: Array[Vector2i], floor_band: int,
		top_band: int) -> Array[Vector3i]:
	## The one storey of fine mass a bridge plot owns.
	var out: Array[Vector3i] = []
	for column: Vector2i in columns:
		for band in range(floor_band, top_band):
			out.append_array(_fine_square(Vector3i(column.x, band, column.y)))
	return out


static func _maze_bridge_access_id(record: Dictionary,
		volume: WarrenVolumePlan, parcels: WarrenParcelPlan,
		access_by_parcel: Dictionary, columns: Array[Vector2i],
		floor_band: int) -> StringName:
	## The building volume a bridge room reaches the street through: the house
	## beside the span. The planner names one whenever a house plot stood at
	## the bridge's own floor as the span was placed, and the record then
	## carries that house's building group; a record naming ITSELF found none,
	## so the flanks are searched here for a house PLOT 4-adjacent to the span
	## whose `[floor, top)` contains the bridge floor.
	##
	## The search is over PLOTS rather than parcel rectangles because a plot's
	## flanking column is often the part its door rectangle left over -- back
	## room mass of the same house. The house is still the house; which of its
	## rectangles touches the span decides nothing about who owns the bridge.
	## Lowest group id where several qualify, and the first parcel of that
	## group which actually composed a volume wins.
	var groups := parcels.audit.get("maze_buildings", {}) as Dictionary
	var wanted: Array[StringName] = []
	var group := StringName(record["building_id"])
	if group != StringName(record["id"]):
		wanted.append(group)
	else:
		var footprint: Dictionary = {}
		for column: Vector2i in columns:
			footprint[column] = true
		var source := volume.mass_context.get(&"maze_source_plan") \
			as WarrenMazeSourcePlan
		if source == null:
			return &""
		for plot: Dictionary in source.plots:
			if StringName(plot["kind"]) != WarrenMazeSourcePlan.PLOT_HOUSE \
					or floor_band < int(plot["floor"]) \
					or floor_band > int(plot["top"]):
				continue
			var beside := false
			for cell_value: Variant in plot["cells"] as Array:
				var column := cell_value as Vector2i
				for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT,
						Vector2i.UP, Vector2i.DOWN]:
					beside = beside or footprint.has(column + direction)
				if beside:
					break
			var owner := StringName(plot["building_id"])
			if beside and not wanted.has(owner):
				wanted.append(owner)
	# Lexical, never `Array[StringName].sort()`: StringName compares by its
	# interned pointer, so the default sort orders by whatever order the town
	# happened to intern its ids in. That is stable inside one process and
	# different in the next, which is exactly the nondeterminism a seeded
	# generator may not have.
	wanted.sort_custom(_string_name_less)
	for owner: StringName in wanted:
		var members: Array[StringName] = []
		members.assign(groups.get(owner, []) as Array)
		members.sort_custom(_string_name_less)
		for parcel_id: StringName in members:
			var access := StringName(access_by_parcel.get(parcel_id, &""))
			if not access.is_empty():
				return access
	return &""


static func _maze_back_room_access_roots(
		buildings: Array[WarrenBuildingVolume], building_by_id: Dictionary,
		building_by_cell: Dictionary) -> Dictionary:
	## Source parcel id -> the volume a back room of that parcel should name as
	## its private parent, indexing the two cell/id maps on the same walk. The
	## ADDRESSED segment is preferred because it is the access root of its own
	## lineage; an all-transferred lineage falls back to its lowest segment id,
	## which reaches the street through the chain `_partition_rooms` built.
	var addressed: Dictionary = {}
	var any: Dictionary = {}
	for building: WarrenBuildingVolume in buildings:
		building_by_id[building.stable_id] = building
		for cell: Vector3i in building.private_cells:
			building_by_cell[cell] = building.stable_id
		var target := addressed if not building.thresholds.is_empty() else any
		for room: WarrenRoomStamp in building.room_records:
			var current := StringName(target.get(room.source_parcel_id, &""))
			if current.is_empty() \
					or String(building.stable_id) < String(current):
				target[room.source_parcel_id] = building.stable_id
	for parcel_value: Variant in any.keys():
		var parcel_id := StringName(parcel_value)
		if not addressed.has(parcel_id):
			addressed[parcel_id] = any[parcel_id]
	return addressed


static func _maze_back_room_parent_room(building: WarrenBuildingVolume,
		cell: Vector3i) -> WarrenRoomStamp:
	if building == null:
		return null
	for room: WarrenRoomStamp in building.room_records:
		if room.has_private_cell(cell):
			return room
	return building.room_records[0] if not building.room_records.is_empty() \
		else null


static func _note_maze_back_room_refusal(refusals: Dictionary,
		reason: String) -> void:
	refusals[reason] = int(refusals.get(reason, 0)) + 1


static func _maze_back_room_rectangles(columns: Array,
		frontage: Vector2i) -> Array[Dictionary]:
	## Cut one back-room record's macro columns into axis-aligned rectangles of
	## the five-kind vocabulary, largest first. Greedy and deterministic: walk
	## the still-unclaimed columns in (z, x) order and take the biggest kind
	## whose whole rectangle is unclaimed, anchored at that column's minimum
	## corner. A 1 x 1 tower always fits, so no column is left uncut.
	var free: Dictionary = {}
	for column_value: Variant in columns:
		free[column_value as Vector2i] = true
	var order: Array[Vector2i] = []
	order.assign(free.keys())
	order.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.x < b.x if a.y == b.y else a.y < b.y)
	var out: Array[Dictionary] = []
	for anchor: Vector2i in order:
		if not free.has(anchor):
			continue
		for shape: Dictionary in MAZE_BACK_ROOM_KINDS:
			var span := Vector2i(int(shape["depth"]), int(shape["width"])) \
				if frontage.x != 0 \
				else Vector2i(int(shape["width"]), int(shape["depth"]))
			var claimed: Array[Vector2i] = []
			for x in range(anchor.x, anchor.x + span.x):
				for z in range(anchor.y, anchor.y + span.y):
					if free.has(Vector2i(x, z)):
						claimed.append(Vector2i(x, z))
			if claimed.size() != span.x * span.y:
				continue
			for column: Vector2i in claimed:
				free.erase(column)
			out.append({"kind": StringName(shape["kind"]),
				"columns": claimed})
			break
	return out


static func _maze_back_room_cells(columns: Array[Vector2i],
		band: int) -> Array[Vector3i]:
	## One storey of fine mass under a macro rectangle.
	var out: Array[Vector3i] = []
	for column: Vector2i in columns:
		for y_offset in WarrenSpatialGrid.STOREY_CELLS:
			out.append_array(_fine_square(Vector3i(column.x, band + y_offset,
				column.y)))
	return out


static func _maze_back_room_address(grid: WarrenSpatialGrid,
		kind: StringName, cells: Array[Vector3i],
		parcel_yaw: int) -> Dictionary:
	## TASK C5c RULING 3. Can this back-room rectangle open its OWN authored
	## doorway onto a street?
	##
	## The rectangle already stands at the parcel's frontage yaw, whose door
	## faces the house in front of it -- so the question is which of the four
	## yaws stamps this exact box AND puts the authored threshold
	## `_residual_authored_threshold` names against canonical public floor.
	## That is the same admission the greedy backfill applies to a residual
	## room, asked here of a rectangle the plot planner already chose, so the
	## facade compiler can never be handed a doorway its shell cannot render.
	##
	## The parcel's own yaw is tried FIRST and the rest in ascending order, so
	## a rectangle that can face two streets keeps the orientation of the house
	## it belongs to. Returns `{yaw, origin, threshold, direction}` or empty.
	## Four yaws of constant work per rectangle: this is a decision, not a
	## search.
	var yaws: Array[int] = [parcel_yaw]
	for yaw in 4:
		if yaw != parcel_yaw:
			yaws.append(yaw)
	for yaw: int in yaws:
		var origin := _maze_back_room_origin(kind, cells, yaw)
		if origin.x == 2147483647:
			continue
		var threshold := _residual_authored_threshold(kind, origin, yaw)
		var direction := FabricRecipe.transform_direction(Vector3i.BACK, yaw)
		var landing := threshold + direction
		if grid.use_at(landing) != WarrenSpatialGrid.Use.PUBLIC_AIR:
			continue
		var floor_claim := grid.face_claim(landing, Vector3i.DOWN)
		if floor_claim.is_empty() or int(floor_claim.get("kind", -1)) \
				!= WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR:
			continue
		return {"yaw": yaw, "origin": origin, "threshold": threshold,
			"direction": direction}
	return {}


static func _maze_back_room_origin(kind: StringName, cells: Array[Vector3i],
		yaw: int) -> Vector3i:
	## The lattice origin at which `kind` at `yaw` stamps exactly `cells`. Both
	## are boxes, so aligning their minimum corners decides it; the set
	## comparison afterwards is what refuses a rectangle whose extent is not
	## this kind's, rather than trusting the caller's arithmetic.
	var invalid := Vector3i(2147483647, 2147483647, 2147483647)
	var local := WarrenRoomStamp.expected_private_cells(kind, Vector3i.ZERO,
		yaw)
	if local.is_empty() or local.size() != cells.size():
		return invalid
	var local_minimum := local[0]
	for cell: Vector3i in local:
		local_minimum = local_minimum.min(cell)
	var target_minimum := cells[0]
	var wanted: Dictionary = {}
	for cell: Vector3i in cells:
		target_minimum = target_minimum.min(cell)
		wanted[cell] = true
	var origin := target_minimum - local_minimum
	for cell: Vector3i in WarrenRoomStamp.expected_private_cells(kind, origin,
			yaw):
		if not wanted.has(cell):
			return invalid
	return origin


static func _maze_back_room_bears_terrain(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan, columns: Array[Vector2i],
		band: int) -> bool:
	## A back room stands on the ground when every one of its macro columns has
	## unbroken source mass from its own stamped bearing datum up to the room's
	## floor, and that rise is short enough for the authored stone course to
	## close. This is exactly the contract
	## `WarrenSpatialFabricCompiler._retained_foundation_cells` enforces on any
	## terrain-bearing room -- asked HERE, before the room enters the grid,
	## because there it rejects the whole town rather than one rectangle.
	##
	## TASK C5c MEASURED AND REVERTED, TASK C5d RE-APPLIED. The compiler's own
	## rule moved in C5c ruling 4 -- a maze room deeper than one plinth course
	## is carried by the retained mountain and takes no plinth -- and relaxing
	## this mirror to match it stamps more back rooms (3/standard went 0.319 ->
	## 0.301 unroomed, 11 -> 14 back rooms) but cost 12/compact and 4/compact
	## their towns at the PITCHED roof gates, because every extra room was
	## another authored crown to fit beside its neighbours. C5d made maze
	## houses flat-roofed, so the marginal room now brings a one-band slab
	## rather than a shell with an eave, and the mirror is aligned to the
	## builder here: a column the compiler would call STONE-BORNE -- a tier, a
	## tunnel roof, or a bored street under the hill -- is bearing, and the
	## only thing left to prove for it is that the room stands on real source
	## mass, which is the compiler's own second check.
	##
	## Mirroring rather than approximating is deliberate (C5c fix #1, Important
	## 4): a mirror stricter than the builder refuses rectangles the real
	## compile would have taken, and one looser than the builder rejects the
	## whole town instead of one rectangle.
	##
	## STONE-BORNE IS A ROOM-LEVEL VERDICT, not a per-column one, and that is
	## the whole shape of this function (C5d fix #1, Important 1). The builder
	## sets one `stone_borne` flag for the room the moment ANY column is
	## carried by stone, and then demands real source mass under EVERY column
	## at `band - 1` -- including the columns that were themselves at grade.
	## Deciding it per column let a MIXED footprint through: one stone-borne
	## column that stands on mass, plus one at grade with `depth == 0` that
	## never reached the standing test at all. The mirror said yes, the builder
	## then said `terrain-bearing room ... stands on nothing at ...` and took
	## the whole town rather than the one rectangle -- exactly the failure mode
	## this mirror exists to prevent.
	var maze_source := volume.mass_context.get(&"maze_source_plan") \
		as WarrenMazeSourcePlan
	var stone_borne := false
	var plinth_columns: Array[Vector2i] = []
	for column: Vector2i in columns:
		if not volume.envelope.contains_column(column):
			return false
		var ground := volume.envelope.bearing_at(column)
		var depth := band - ground
		if depth < 0:
			return false
		var span_is_whole := true
		for lower_band in range(ground, band):
			if not volume.has_mass(Vector3i(column.x, lower_band, column.y)):
				span_is_whole = false
				break
		if maze_source != null and (not span_is_whole \
				or depth > WarrenSpatialFabricCompiler \
					.FOUNDATION_MODULE_HEIGHT_BANDS \
				or maze_source.rock_shoulder(column) < band):
			# A tier, a tunnel roof, or a bored street under the hill: the plot
			# planner's own support rule already proved this floor stands on
			# something, and the mass below it is stone or another building
			# rather than this room's masonry course.
			stone_borne = true
			continue
		if not span_is_whole or depth > WarrenSpatialFabricCompiler \
				.FOUNDATION_MODULE_HEIGHT_BANDS:
			return false
		if depth > 0:
			plinth_columns.append(column)
	if stone_borne:
		# `_retained_foundation_cells`'s second check, over the whole
		# footprint: the room takes no plinth at all, so the only thing that
		# still has to hold is that there IS real source mass directly beneath
		# every column of it.
		for column: Vector2i in columns:
			if not volume.has_mass(Vector3i(column.x, band - 1, column.y)):
				return false
		return true
	for column: Vector2i in plinth_columns:
		for fine: Vector3i in _fine_square(Vector3i(column.x, band - 1,
				column.y)):
			if grid.use_at(fine) == WarrenSpatialGrid.Use.PUBLIC_AIR:
				return false
	return true


static func _maze_plot_mass_cells(volume: WarrenVolumePlan) -> Dictionary:
	## Every FINE cell inside some plot's own `[floor, top)`. In the plot model
	## this is the whole of a maze town's buildable mass: solid that no plot
	## stands in is structural ROCK -- interior stone the source plan derived,
	## which C5 renders and which is never a room. Empty for a searched volume,
	## which is what makes the residual filter maze-only.
	var out: Dictionary = {}
	var source := volume.mass_context.get(&"maze_source_plan") \
		as WarrenMazeSourcePlan
	if source == null:
		return out
	for plot: Dictionary in source.plots:
		for cell_value: Variant in plot["cells"] as Array:
			var column := cell_value as Vector2i
			for band in range(int(plot["floor"]), int(plot["top"])):
				for fine: Vector3i in _fine_square(Vector3i(column.x, band,
						column.y)):
					out[fine] = true
	return out


static func _backfill_residual_rooms(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan, buildings: Array[WarrenBuildingVolume],
		supports: WarrenSupportGraph, required_supports: Array[StringName],
		terrain_support_ids: Array[StringName],
		support_edges: Array[Dictionary],
		protected_owners: Dictionary, maximum_buildings: int,
		maximum_per_kind: int,
		construction_program: SettlementFabricProgram,
		fixed_feature_bounds: Array[AABB] = []) -> Dictionary:
	assert(maximum_buildings > 0 and maximum_per_kind > 0)
	_residual_bridge_counts = {}
	var massif := volume.mass_context.get(&"massif") as WarrenMassif
	if massif == null:
		return {"failed": false, "building_count": 0,
			"private_cell_count": 0, "kind_counts": {}}
	var building_by_id: Dictionary = {}
	var building_by_cell: Dictionary = {}
	for building: WarrenBuildingVolume in buildings:
		building_by_id[building.stable_id] = building
		for cell: Vector3i in building.private_cells:
			building_by_cell[cell] = building.stable_id
	# In the plot model a room may stand only in mass some plot claimed; solid
	# outside every plot is structural ROCK, which the source plan derived and
	# which is stone rather than construction. Empty on a searched volume, and
	# an empty set is what leaves the candidate check below byte-identical for
	# every legacy mode.
	var plot_mass_cells := _maze_plot_mass_cells(volume)
	# TASK C5c RULING 2 -- the budget is a SEARCHED town's idea. There the
	# greedy scan roams the whole massif and the budget is what stops it
	# turning a mountain into a rash of towers; here every candidate is already
	# confined to plot mass the planner assigned to a building, so a cap on the
	# COUNT just leaves buildings unbuilt. The scan therefore runs until no
	# candidate fits, bounded -- as ruling 2 asks -- by the plot-mass cell count
	# rather than by a room budget: a room owns at least one cell, so this can
	# never bind, and it can never diverge either.
	#
	# Keyed on the plot mass rather than on a global: the bound is a fact
	# about this town's own source, so a review render backfills exactly as
	# production does.
	if not plot_mass_cells.is_empty():
		maximum_buildings = plot_mass_cells.size()
		maximum_per_kind = plot_mass_cells.size()
	# Index each still-uncovered public floor by the private-volume cells that
	# could form its ceiling. This turns the first part of residual packing into
	# an explicit tunnel/bridge-house pass: complete inhabited rooms that span a
	# street outrank equally valid peripheral rooms by a wide margin.
	var uncovered_route_floors: Dictionary = {}
	var route_floor_by_overhead_cell: Dictionary = {}
	var route_floor_set: Dictionary = {}
	for air_cell: Vector3i in grid.cells_with_use(
			WarrenSpatialGrid.Use.PUBLIC_AIR):
		var floor_claim := grid.face_claim(air_cell, Vector3i.DOWN)
		if floor_claim.is_empty() or int(floor_claim.get("kind", -1)) \
				!= WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR:
			continue
		route_floor_set[air_cell] = true
		var already_covered := false
		for rise in range(WarrenVolumePlan.HEADROOM_BANDS, 7):
			if building_by_cell.has(air_cell + Vector3i.UP * rise):
				already_covered = true
				break
		if already_covered:
			continue
		uncovered_route_floors[air_cell] = true
		for rise in range(WarrenVolumePlan.HEADROOM_BANDS, 7):
			var overhead_cell := air_cell + Vector3i.UP * rise
			if not route_floor_by_overhead_cell.has(overhead_cell):
				route_floor_by_overhead_cell[overhead_cell] = \
					[] as Array[Vector3i]
			(route_floor_by_overhead_cell[overhead_cell] \
				as Array[Vector3i]).append(air_cell)
	var initial_uncovered_route_count := uncovered_route_floors.size()
	var uncovered_frontage_sides: Dictionary = {}
	var frontage_side_by_private_cell: Dictionary = {}
	for floor_value: Variant in route_floor_set.keys():
		var floor_cell := floor_value as Vector3i
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.FORWARD, Vector3i.BACK]:
			var neighbor := floor_cell + direction
			if route_floor_set.has(neighbor) or building_by_cell.has(neighbor) \
					or building_by_cell.has(neighbor + Vector3i.UP):
				continue
			var side_key := "%d:%d:%d/%d:%d" % [floor_cell.x,
				floor_cell.y, floor_cell.z, direction.x, direction.z]
			uncovered_frontage_sides[side_key] = true
			for private_cell: Vector3i in [neighbor,
					neighbor + Vector3i.UP]:
				if not frontage_side_by_private_cell.has(private_cell):
					frontage_side_by_private_cell[private_cell] = \
						PackedStringArray()
				(frontage_side_by_private_cell[private_cell] \
					as PackedStringArray).append(side_key)
	var initial_uncovered_frontage_count := uncovered_frontage_sides.size()
	var roof_clearance: Dictionary = {}
	# Native pitched roofs extend a fraction of a fine cell past their logical
	# footprint.  Keep that measured eave band distinct from the exact roof
	# volume: it blocks a later wall from rising through an earlier roof, but it
	# must not prevent two same-height roofs from meeting over party-wall rooms.
	var roof_eave_halo: Dictionary = {}
	_reserve_existing_roof_clearance(buildings, building_by_cell,
		roof_clearance, roof_eave_halo)
	var kind_counts: Dictionary = {}
	var added_count := 0
	var added_cells := 0
	var terrain_root_count := 0
	var massif_edge_room_count := 0
	var massif_edge_contact_count := 0
	var terrain_rooted_established_access_count := 0
	# TASK F2. Two facts about this scan, both PER SOLVE and both dropped when
	# this call returns.
	#
	# `allocatable` is `grid.cells_with_use(ALLOCATABLE)` maintained instead of
	# re-derived. The scan used to walk the whole fine grid and allocate a fresh
	# cell array on every pass, and there is one pass per residual room. Inside
	# this loop a cell only ever LEAVES the allocatable set -- the commit below
	# is the only grid write, and it assigns PRIVATE_VOLUME -- so filtering the
	# list keeps exactly the cells a fresh scan would return, in the same index
	# order, which is what decides ties between equal-scoring candidates.
	#
	# `stamp_offsets` is `WarrenRoomStamp.expected_private_cells` for origin
	# zero. `FabricRecipe.transform_cell` builds a `Basis` and rotates a vector
	# per cell, and the stamp is a pure translation of the origin-zero set --
	# `transform_cell(c, origin, yaw)` is `origin + round(Basis(yaw) * c)` --
	# so the rotation is done once per (kind, yaw) rather than ~48 times for
	# every one of the hundreds of thousands of candidates this scan tries.
	var allocatable := grid.cells_with_use(WarrenSpatialGrid.Use.ALLOCATABLE)
	var stamp_offsets: Array[Array] = []
	for kind_index in WarrenRoomStamp.KINDS.size():
		var per_yaw: Array = []
		for yaw in 4:
			per_yaw.append(WarrenRoomStamp.expected_private_cells(
				WarrenRoomStamp.KINDS[kind_index], Vector3i.ZERO, yaw))
		stamp_offsets.append(per_yaw)
	while added_count < maximum_buildings:
		var best: Dictionary = {}
		for origin: Vector3i in allocatable:
			for kind_index in WarrenRoomStamp.KINDS.size():
				var kind := WarrenRoomStamp.KINDS[kind_index]
				if int(kind_counts.get(kind, 0)) >= maximum_per_kind:
					continue
				var yaw_count := 1 if kind in [&"tower", &"building"] else 2
				for yaw in yaw_count:
					var candidate := _residual_room_candidate(grid, massif,
						origin, kind, yaw, building_by_id, building_by_cell,
						roof_clearance, roof_eave_halo, protected_owners,
						route_floor_by_overhead_cell, uncovered_route_floors,
						frontage_side_by_private_cell,
						uncovered_frontage_sides,
						volume.world_seed,
						int(kind_counts.get(kind, 0)), construction_program,
						plot_mass_cells,
						stamp_offsets[kind_index][yaw] as Array[Vector3i],
						fixed_feature_bounds)
					if candidate.is_empty():
						continue
					if best.is_empty() or float(candidate.score) \
							> float(best.score) or is_equal_approx(
							float(candidate.score), float(best.score)) \
							and String(candidate.key) < String(best.key):
						best = candidate
		if best.is_empty():
			break
		var building_id := StringName("spatial.residual.%02d" % added_count)
		var source_id := StringName("residual.mass.%02d" % added_count)
		var cells := best.cells as Array[Vector3i]
		var assign := grid.begin_transaction(building_id)
		if not assign.require_use(cells,
				[WarrenSpatialGrid.Use.ALLOCATABLE] as Array[int]) \
				or not assign.assign_use(cells,
					WarrenSpatialGrid.Use.PRIVATE_VOLUME, building_id) \
				or not assign.commit():
			last_failure = "residual room %s changed before commit: %s" % [
				building_id, assign.last_rejection]
			return {"failed": true}
		var parent_building := building_by_id.get(best.support_parent_id) \
			as WarrenBuildingVolume
		var parent_room: WarrenRoomStamp = null
		if parent_building != null:
			for room: WarrenRoomStamp in parent_building.room_records:
				if room.has_private_cell(best.support_parent_cell as Vector3i):
					parent_room = room
					break
			if parent_room == null and not parent_building.room_records.is_empty():
				parent_room = parent_building.room_records[0]
		var terrain_bearing := bool(best.terrain_bearing)
		terrain_root_count += int(terrain_bearing)
		terrain_rooted_established_access_count += int(terrain_bearing \
			and not bool(best.addressed))
		var edge_contacts := int(best.massif_edge_contact_count)
		massif_edge_room_count += int(edge_contacts > 0)
		massif_edge_contact_count += edge_contacts
		var addressed := bool(best.addressed)
		var threshold_cell := best.threshold_cell as Vector3i \
			if addressed else Vector3i(2147483647, 2147483647, 2147483647)
		var frontage_direction := best.frontage_direction as Vector3i \
			if addressed else Vector3i.ZERO
		var room := WarrenRoomStamp.new(
			StringName("%s.room00" % building_id), source_id,
			StringName(best.kind), best.origin as Vector3i, int(best.yaw), 0,
			terrain_bearing, addressed, threshold_cell, frontage_direction,
			_residual_roof_feature(StringName(best.kind),
				best.origin as Vector3i, volume.world_seed),
			&"" if terrain_bearing or parent_room == null \
				else parent_room.source_parcel_id,
			-1 if terrain_bearing or parent_room == null \
				else parent_room.source_storey_index)
		var building := WarrenBuildingVolume.new(building_id,
			(best.origin as Vector3i).y)
		if not building.add_private_cells(cells) \
				or not room.add_private_cells(cells) \
				or not room.seal(grid, building_id) \
				or not building.add_room(room) \
				or addressed and not building.add_threshold(threshold_cell,
					threshold_cell + frontage_direction) \
				or not addressed and not building.add_private_parent(
					StringName(best.access_parent_id)) \
				or not building.seal(grid) \
				or not supports.add_node(building_id):
			last_failure = "residual room %s failed its building transaction: %s/%s" \
				% [building_id, room.last_rejection, building.last_rejection]
			return {"failed": true}
		var bridge_support_room_ids: Array[StringName] = []
		bridge_support_room_ids.assign(best.get("bridge_support_room_ids",
			[]) as Array)
		if not bridge_support_room_ids.is_empty():
			# A street-bridge room bears on its two flanking walls; the compiler
			# binds both through the exact span sockets instead of a below
			# parent, and the support graph keeps one terrain-reaching edge.
			# Stamped after seal() because seal rebuilds the audit dictionary.
			room.audit["bridge_support_room_ids"] = bridge_support_room_ids
			room.audit["bridge_support_directions"] = (best.get(
				"bridge_support_directions", []) as Array).duplicate()
			room.audit["bridge_support_building_ids"] = (best.get(
				"bridge_support_building_ids", []) as Array).duplicate()
			room.audit["bridge_support_records"] = (
				best.get("bridge_support_records", []) as Array).duplicate(true)
			room.audit["bridge_is_bracketed_jetty"] = bool(best.get(
				"bridge_is_bracketed_jetty", false))
		if terrain_bearing:
			terrain_support_ids.append(building_id)
		else:
			if parent_building == null:
				last_failure = "residual room %s lost its bearing parent" % building_id
				return {"failed": true}
			support_edges.append({"child": building_id,
				"parent": parent_building.stable_id})
		required_supports.append(building_id)
		buildings.append(building)
		building_by_id[building_id] = building
		for cell: Vector3i in cells:
			building_by_cell[cell] = building_id
		for floor_cell: Vector3i in best.overhead_route_floors \
				as Array[Vector3i]:
			uncovered_route_floors.erase(floor_cell)
		for side_key: String in best.frontage_side_keys as PackedStringArray:
			uncovered_frontage_sides.erase(side_key)
		for cell_value: Variant in (best.roof_clearance as Dictionary).keys():
			var roof_cell := cell_value as Vector3i
			roof_clearance[roof_cell] = building_id
			for z_offset in range(-1, 2):
				for x_offset in range(-1, 2):
					roof_eave_halo[roof_cell + Vector3i(x_offset, 0,
						z_offset)] = building_id
		var kind := StringName(best.kind)
		kind_counts[kind] = int(kind_counts.get(kind, 0)) + 1
		added_count += 1
		added_cells += cells.size()
		# The committed cells are the only ones this pass took out of the
		# allocatable set, so drop exactly those and keep the rest in order.
		var consumed: Dictionary = {}
		for cell: Vector3i in cells:
			consumed[cell] = true
		var remaining: Array[Vector3i] = []
		for cell: Vector3i in allocatable:
			if not consumed.has(cell):
				remaining.append(cell)
		allocatable = remaining
	return {"failed": false, "building_count": added_count,
		"private_cell_count": added_cells, "kind_counts": kind_counts,
		"terrain_root_count": terrain_root_count,
		"massif_edge_room_count": massif_edge_room_count,
		"massif_edge_contact_count": massif_edge_contact_count,
		"terrain_rooted_established_access_count": \
			terrain_rooted_established_access_count,
		"bridge_counts": _residual_bridge_counts.duplicate(),
		"overhead_route_cell_count": initial_uncovered_route_count \
			- uncovered_route_floors.size(),
		"frontage_side_count": initial_uncovered_frontage_count \
			- uncovered_frontage_sides.size()}


static func _reserve_existing_roof_clearance(
		buildings: Array[WarrenBuildingVolume], building_by_cell: Dictionary,
		roof_clearance: Dictionary, roof_eave_halo: Dictionary) -> void:
	## Primary macro rooms are present before residual packing begins. Their
	## exposed top cells already imply a roof, even though the authored roof is
	## compiled later. Seed the same two-band clearance and one-cell measured eave
	## halo used for committed residual rooms so late infill cannot occupy a
	## shoulder and force the roof compiler into an overlapping micro-cap.
	for building: WarrenBuildingVolume in buildings:
		for room: WarrenRoomStamp in building.room_records:
			for cell: Vector3i in room.private_cells:
				if building_by_cell.has(cell + Vector3i.UP):
					continue
				for rise in range(1, ROOF_CLEARANCE_CELLS + 1):
					var roof_cell := cell + Vector3i.UP * rise
					roof_clearance[roof_cell] = building.stable_id
					for z_offset in range(-1, 2):
						for x_offset in range(-1, 2):
							roof_eave_halo[roof_cell + Vector3i(x_offset,
								0, z_offset)] = building.stable_id


static func _residual_room_candidate(grid: WarrenSpatialGrid,
		massif: WarrenMassif, origin: Vector3i, kind: StringName, yaw: int,
		building_by_id: Dictionary, building_by_cell: Dictionary,
		roof_clearance: Dictionary, roof_eave_halo: Dictionary,
		protected_owners: Dictionary,
		route_floor_by_overhead_cell: Dictionary,
		uncovered_route_floors: Dictionary,
		frontage_side_by_private_cell: Dictionary,
		uncovered_frontage_sides: Dictionary,
		world_seed: int, existing_kind_count: int,
		construction_program: SettlementFabricProgram,
		plot_mass_cells: Dictionary = {},
		stamp_offsets: Array[Vector3i] = [],
		fixed_feature_bounds: Array[AABB] = []) -> Dictionary:
	# TASK F2. `stamp_offsets` is this (kind, yaw)'s stamp at origin zero, and
	# the stamp at any origin is that set translated -- see the derivation at
	# the head of `_backfill_residual_rooms`. A caller that passes none gets
	# the original derivation, so nothing outside that scan changes.
	var cells: Array[Vector3i] = []
	if stamp_offsets.is_empty():
		cells = WarrenRoomStamp.expected_private_cells(kind, origin, yaw)
	else:
		cells.resize(stamp_offsets.size())
		for index in stamp_offsets.size():
			cells[index] = stamp_offsets[index] + origin
	if cells.is_empty():
		return {}
	# `plot_mass_cells` is empty in every searched mode and the short-circuit
	# below therefore never even reads the dictionary there. In MAZE mode it is
	# the town's plot mass, and a cell outside it is structural ROCK: derived
	# stone the plot planner never gave to a building, which the greedy scan
	# used to fill with unroofable towers.
	var footprint: Dictionary = {}
	for cell: Vector3i in cells:
		if grid.use_at(cell) != WarrenSpatialGrid.Use.ALLOCATABLE \
				or roof_eave_halo.has(cell) \
				or not plot_mass_cells.is_empty() \
					and not plot_mass_cells.has(cell) \
				or _residual_feature_protected(grid, cell, protected_owners):
			return {}
		footprint[Vector2i(cell.x, cell.z)] = true
	var candidate_roof_clearance: Dictionary = {}
	# A freestanding residual roof needs open air around its eaves; a bridge
	# room nestled between its two taller flanks does not — its roof compiles
	# as a party-wall cap or bound lean-to under the roof phase's own measured
	# gates. Record the halo verdict instead of rejecting outright so the
	# bridge admission below can waive exactly this one condition.
	var roof_halo_clear := true
	for column_value: Variant in footprint.keys():
		var column := column_value as Vector2i
		for rise in range(WarrenSpatialGrid.STOREY_CELLS,
				WarrenSpatialGrid.STOREY_CELLS + ROOF_CLEARANCE_CELLS):
			var roof_cell := Vector3i(column.x, origin.y + rise, column.y)
			var use := grid.use_at(roof_cell)
			if use not in [WarrenSpatialGrid.Use.ALLOCATABLE,
					WarrenSpatialGrid.Use.OUTSIDE] \
					or roof_clearance.has(roof_cell) \
					or _residual_feature_protected(grid, roof_cell,
						protected_owners):
				return {}
			for z_offset in range(-1, 2):
				for x_offset in range(-1, 2):
					if building_by_cell.has(roof_cell + Vector3i(x_offset,
							0, z_offset)):
						roof_halo_clear = false
			candidate_roof_clearance[roof_cell] = true
	var threshold_candidates: Array[Dictionary] = []
	# An adjacent street cell is not automatically a door. Use the same exact
	# authored local threshold as the final facade compiler so dense infill can
	# never claim a doorway that its selected room shell cannot render.
	var authored_threshold := _residual_authored_threshold(kind, origin, yaw)
	var authored_frontage := FabricRecipe.transform_direction(
		Vector3i.BACK, yaw)
	var authored_landing := authored_threshold + authored_frontage
	if grid.use_at(authored_landing) == WarrenSpatialGrid.Use.PUBLIC_AIR:
		var floor_claim := grid.face_claim(authored_landing, Vector3i.DOWN)
		if not floor_claim.is_empty() and int(floor_claim.get("kind", -1)) \
				== WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR:
			threshold_candidates.append({"cell": authored_threshold,
				"direction": authored_frontage,
				"key": "%d:%d:%d/%d:%d" % [authored_threshold.x,
					authored_threshold.y, authored_threshold.z,
					authored_frontage.x, authored_frontage.z]})
	threshold_candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.key) < String(b.key))
	var addressed := not threshold_candidates.is_empty()
	var selected_threshold: Dictionary = threshold_candidates[0] \
		if addressed else {}
	var access_counts: Dictionary = {}
	var access_cell_by_owner: Dictionary = {}
	for cell: Vector3i in cells:
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.FORWARD, Vector3i.BACK]:
			var neighbor := cell + direction
			var owner := StringName(building_by_cell.get(neighbor, &""))
			if owner.is_empty():
				continue
			access_counts[owner] = int(access_counts.get(owner, 0)) + 1
			access_cell_by_owner[owner] = neighbor
	var access_parent_id := _largest_contact_owner(access_counts)
	var terrain_contacts := 0
	var support_counts: Dictionary = {}
	var support_cell_by_owner: Dictionary = {}
	for column_value: Variant in footprint.keys():
		var column := column_value as Vector2i
		var macro := Vector2i(floori(float(column.x) / 2.0),
			floori(float(column.y) / 2.0))
		terrain_contacts += int(massif.has_column(macro) \
			and origin.y == massif.bearing_at(macro))
		var below := Vector3i(column.x, origin.y - 1, column.y)
		var owner := StringName(building_by_cell.get(below, &""))
		if owner.is_empty():
			continue
		support_counts[owner] = int(support_counts.get(owner, 0)) + 1
		support_cell_by_owner[owner] = below
	var required_bearing := maxi(1, ceili(float(footprint.size()) * 0.5))
	var terrain_bearing := terrain_contacts >= required_bearing
	var frontage_side_set: Dictionary = {}
	for cell: Vector3i in cells:
		for side_key: String in frontage_side_by_private_cell.get(cell,
				PackedStringArray()) as PackedStringArray:
			if uncovered_frontage_sides.has(side_key):
				frontage_side_set[side_key] = true
	var frontage_side_keys := PackedStringArray()
	for side_key_value: Variant in frontage_side_set.keys():
		frontage_side_keys.append(String(side_key_value))
	frontage_side_keys.sort()
	# Residual rooms complete the inhabited mass; they never scatter around it.
	# Every candidate must lean on the already sealed connected fabric with a
	# measured side interface. Earlier versions required direct contact with a
	# pre-backfill room, which limited the entire pass to a one-room-deep fringe:
	# a legal second infill room could not continue the same connected wing and
	# most of the carved massif disappeared into lawn. A residual parent is safe
	# here because it has already entered the support graph, shell, roof-clearance,
	# and private-access transactions before the next candidate is considered.
	var connected_parent := _largest_contact_owner(access_counts)
	# A terrain-rooted, addressed infill room already has two independent
	# cohesion facts: its exact street threshold and a full terrain bearing. Let
	# one measured side cell stitch that room to the established fabric. Requiring
	# two contacts here discarded otherwise roofable frontage at turns and left
	# the carved route opening into broad lawns. Elevated or unaddressed residuals
	# still require the original two-cell structural interface.
	var measured_contact_count := int(access_counts.get(connected_parent, 0))
	var closes_street_notch := terrain_bearing and addressed \
		and frontage_side_keys.size() >= 2
	var minimum_established_contact := 1 if terrain_bearing and addressed else 2
	if not closes_street_notch and (connected_parent.is_empty() \
			or measured_contact_count < minimum_established_contact):
		return {}
	if not addressed:
		if terrain_bearing:
			access_parent_id = connected_parent
		elif access_parent_id.is_empty() \
				or int(access_counts[access_parent_id]) < 2:
			return {}
	var support_parent_id := _largest_contact_owner(support_counts)
	var bridge_span: Dictionary = {}
	if not terrain_bearing and (support_parent_id.is_empty() \
			or int(support_counts[support_parent_id]) < required_bearing):
		# No half-footprint mass stands below. The one remaining legal bearing
		# form is a street bridge: a tower or slim room whose side cells
		# exactly meet the centred cardinal bearing sockets of two distinct
		# established flanking rooms, and whose body actually covers uncovered
		# canonical route. Anything else stays rejected.
		if kind not in [&"tower", &"slim"]:
			return {}
		var covers_uncovered_route := false
		for cell: Vector3i in cells:
			for floor_cell: Vector3i in route_floor_by_overhead_cell.get(cell,
					[] as Array[Vector3i]) as Array[Vector3i]:
				if uncovered_route_floors.has(floor_cell):
					covers_uncovered_route = true
					break
			if covers_uncovered_route:
				break
		if not covers_uncovered_route:
			return {}
		_residual_bridge_counts["route_covering_candidates"] = int(
			_residual_bridge_counts.get("route_covering_candidates", 0)) + 1
		bridge_span = _residual_bridge_span(cells, building_by_id,
			building_by_cell, world_seed, construction_program)
		if bridge_span.is_empty():
			_residual_bridge_counts["span_unbound"] = int(
				_residual_bridge_counts.get("span_unbound", 0)) + 1
			return {}
		_residual_bridge_counts["span_bound"] = int(
			_residual_bridge_counts.get("span_bound", 0)) + 1
		support_parent_id = StringName(bridge_span.parent_building_id)
	if not roof_halo_clear and bridge_span.is_empty():
		return {}
	var support_parent_cell := Vector3i(2147483647, 2147483647, 2147483647)
	if not terrain_bearing:
		support_parent_cell = bridge_span.parent_contact_cell as Vector3i \
			if not bridge_span.is_empty() \
			else support_cell_by_owner[support_parent_id] as Vector3i
	var massif_edge_contact_count := 0
	for column_value: Variant in footprint.keys():
		var column := column_value as Vector2i
		var macro := Vector2i(floori(float(column.x) / 2.0),
			floori(float(column.y) / 2.0))
		for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT,
				Vector2i.UP, Vector2i.DOWN]:
			if not massif.has_column(macro + direction):
				massif_edge_contact_count += 1
				break
	var overhead_route_floor_set: Dictionary = {}
	for cell: Vector3i in cells:
		for floor_cell: Vector3i in route_floor_by_overhead_cell.get(cell,
				[] as Array[Vector3i]):
			if uncovered_route_floors.has(floor_cell):
				overhead_route_floor_set[floor_cell] = true
	var overhead_route_floors: Array[Vector3i] = []
	overhead_route_floors.assign(overhead_route_floor_set.keys())
	overhead_route_floors.sort_custom(_cell_less)
	var tie := posmod(Helper._mix64(world_seed ^ origin.x * 73856093 \
		^ origin.y * 83492791 ^ origin.z * 19349663 ^ kind.hash() ^ yaw * 97),
		1000003)
	var provisional_room := WarrenRoomStamp.new(&"residual.envelope.probe",
		&"residual.envelope.probe", kind, origin, yaw, 0, terrain_bearing,
		addressed, selected_threshold.get("cell", Vector3i.ZERO) as Vector3i \
			if addressed else Vector3i(2147483647, 2147483647, 2147483647),
		selected_threshold.get("direction", Vector3i.ZERO) as Vector3i \
			if addressed else Vector3i.ZERO,
		_residual_roof_feature(kind, origin, world_seed))
	provisional_room.private_cells.assign(cells)
	# A street-bridge room does not wear the generic residual shell: its exact
	# flank sockets select the occupied-link recipe and its semantic party roof.
	# Carry those already-solved facts into the reversible envelope probe before
	# asking the shared compiler predicates. Stamping them only after commitment
	# made proposal admission prove a different building from the one constructed.
	var provisional_bridge_room_ids: Array[StringName] = []
	provisional_bridge_room_ids.assign(bridge_span.get("room_ids",
		[] as Array[StringName]) as Array)
	if not provisional_bridge_room_ids.is_empty():
		provisional_room.audit["bridge_support_room_ids"] = \
			provisional_bridge_room_ids
		provisional_room.audit["bridge_support_directions"] = (bridge_span.get(
			"support_directions", []) as Array).duplicate()
		provisional_room.audit["bridge_support_building_ids"] = (bridge_span.get(
			"support_building_ids", []) as Array).duplicate()
		provisional_room.audit["bridge_support_records"] = (
			bridge_span.get("support_records", []) as Array).duplicate(true)
		provisional_room.audit["bridge_is_bracketed_jetty"] = bool(
			bridge_span.get("is_bracketed_jetty", false))
	if not _residual_room_envelope_fits(provisional_room, building_by_id,
			construction_program, world_seed, grid, fixed_feature_bounds):
		return {}
	var score := float(overhead_route_floors.size() \
			* RESIDUAL_OVERHEAD_ROUTE_CELL_SCORE \
			+ frontage_side_keys.size() * RESIDUAL_FRONTAGE_SIDE_SCORE \
			+ int(terrain_bearing) * RESIDUAL_TERRAIN_ROOT_SCORE \
			+ massif_edge_contact_count * RESIDUAL_MASSIF_EDGE_COLUMN_SCORE \
			+ int(access_counts.get(access_parent_id, 0)) * 1000 \
		+ threshold_candidates.size() * 500 \
		+ maxi(terrain_contacts, int(support_counts.get(support_parent_id, 0))) \
			* 320 + footprint.size() * 90 + origin.y * 18 \
			- existing_kind_count * 240) - float(tie) * 0.000001
	return {"origin": origin, "kind": kind, "yaw": yaw, "cells": cells,
		"roof_clearance": candidate_roof_clearance,
		"terrain_bearing": terrain_bearing,
		"addressed": addressed,
		"threshold_cell": selected_threshold.get("cell", Vector3i.ZERO),
		"frontage_direction": selected_threshold.get("direction",
			Vector3i.ZERO),
		"access_parent_id": access_parent_id,
		"support_parent_id": support_parent_id,
		"support_parent_cell": support_parent_cell,
		"bridge_support_room_ids": bridge_span.get("room_ids",
			[] as Array[StringName]),
		"bridge_support_directions": bridge_span.get("support_directions", []),
		"bridge_support_building_ids": bridge_span.get(
			"support_building_ids", []),
		"bridge_support_records": bridge_span.get("support_records", []),
		"bridge_is_bracketed_jetty": bool(bridge_span.get(
			"is_bracketed_jetty", false)),
		"massif_edge_contact_count": massif_edge_contact_count,
		"overhead_route_floors": overhead_route_floors,
		"frontage_side_keys": frontage_side_keys,
		"score": score,
		"key": "%s/%d:%d:%d/r%d" % [String(kind), origin.x, origin.y,
			origin.z, yaw]}


static func _residual_bridge_span(cells: Array[Vector3i],
		building_by_id: Dictionary, building_by_cell: Dictionary,
		world_seed: int, program: SettlementFabricProgram,
		proved_flank_columns: Dictionary = {},
		jetty_brackets: bool = false) -> Dictionary:
	## Prove the two-sided wall bearing for a candidate bridge room: on each of
	## two opposing sides, one distinct established flanking room whose centred
	## cardinal bearing socket exactly meets a cell of this footprint. The
	## proof runs against the flanks' real measured recipes, so the strict
	## compile-time `_sockets_meet` bond can never disagree with admission.
	##
	## TASK E3 RULING 3 -- `proved_flank_columns` is the set of macro columns
	## the CARVER proved could carry a room at this span's own band before it
	## seeded the span (`WarrenExcavation.bridge_span_audit`). When it is
	## non-empty the search binds through those columns only, so the bond the
	## builder makes is the one the seed-time proof was about. Without it the
	## search took the first bindable pair in a fixed direction order, which on
	## `step/12/compact` bonded a perpendicular house whose own floor stood a
	## band ABOVE the bridge and whose lineage the fabric compiler then dropped
	## -- `bridge room ... has no built flank`, the whole town, one stage later.
	## EMPTY for every legacy caller (`_backfill_residual_rooms` passes none),
	## which is what keeps the searched modes byte-identical.
	if program == null:
		return {}
	var cell_set: Dictionary = {}
	for cell: Vector3i in cells:
		cell_set[cell] = true
	var bindings_by_direction: Dictionary = {}
	for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
			Vector3i.FORWARD, Vector3i.BACK]:
		for cell: Vector3i in cells:
			var neighbor := cell + direction
			if cell_set.has(neighbor):
				continue
			if not proved_flank_columns.is_empty() \
					and not proved_flank_columns.has(Vector2i(
						floori(float(neighbor.x) / 2.0),
						floori(float(neighbor.z) / 2.0))):
				_residual_bridge_counts["unproved_flank_column"] = int(
					_residual_bridge_counts.get("unproved_flank_column",
						0)) + 1
				continue
			var owner := StringName(building_by_cell.get(neighbor, &""))
			if owner.is_empty():
				continue
			var building := building_by_id.get(owner) as WarrenBuildingVolume
			if building == null:
				continue
			_residual_bridge_counts["flank_contacts"] = int(
				_residual_bridge_counts.get("flank_contacts", 0)) + 1
			var binding: Dictionary = {}
			for flank_room: WarrenRoomStamp in building.room_records:
				if not flank_room.has_private_cell(neighbor):
					continue
				# An earlier residual room is a legal flank — it carries its
				# own terrain-reaching support chain — but a bridge may not
				# bear on another bridge: no viaducts of unproven depth.
				if not (flank_room.audit.get("bridge_support_room_ids",
						[]) as Array).is_empty():
					continue
				_residual_bridge_counts["flank_rooms_probed"] = int(
					_residual_bridge_counts.get("flank_rooms_probed", 0)) + 1
				binding = _bridge_flank_binding(cell_set, flank_room, owner,
					world_seed, program)
				if not binding.is_empty():
					break
			if not binding.is_empty():
				bindings_by_direction[direction] = binding
				break
	if bindings_by_direction.size() == 1:
		_residual_bridge_counts["one_side_bound"] = int(
			_residual_bridge_counts.get("one_side_bound", 0)) + 1
	# Two exact socket bonds on distinct flanking rooms carry the room.
	# Opposing walls are the classic street bridge; perpendicular walls are
	# the corner-bridge form over a street bend.
	#
	# A single bound wall WITHOUT a bracket course is never an inhabited
	# residual room: it reads as a complete 3 m room pasted onto the parent
	# facade, which is the forbidden one-cell box rather than a shallow
	# outcropping. WITH one it is legal, and that is the branch below -- Task
	# E3b's bracketed jetty, admitted only when `jetty_brackets` is asked for
	# and a real course can be selected under the bearing edge. (Fix round 1,
	# IMPORTANT 4: this sentence used to read "even with brackets" and argued
	# against the branch thirty lines below it. The brackets are exactly what
	# changes the verdict; the box is the UNbracketed form.)
	var bound_directions: Array = bindings_by_direction.keys()
	bound_directions.sort_custom(func(a: Variant, b: Variant) -> bool:
		var left := a as Vector3i
		var right := b as Vector3i
		if left.x != right.x:
			return left.x < right.x
		return left.z < right.z)
	for first_index in bound_directions.size():
		for second_index in range(first_index + 1, bound_directions.size()):
			var first_direction := bound_directions[first_index] as Vector3i
			var second_direction := bound_directions[second_index] as Vector3i
			var negative := bindings_by_direction[
				first_direction] as Dictionary
			var positive := bindings_by_direction[
				second_direction] as Dictionary
			if not _bridge_flank_pair_is_two_ended(first_direction,
					second_direction, negative, positive):
				var rejection := "non_opposing_pair" \
					if first_direction != -second_direction \
					else "same_building_pair"
				_residual_bridge_counts[rejection] = int(
					_residual_bridge_counts.get(rejection, 0)) + 1
				continue
			var room_ids: Array[StringName] = [
				StringName(negative.room_id), StringName(positive.room_id)]
			return {
				"room_ids": room_ids,
				"support_directions": [first_direction,
					second_direction] as Array[Vector3i],
				"support_building_ids": [StringName(negative.building_id),
					StringName(positive.building_id)] as Array[StringName],
				"parent_building_id": StringName(negative.building_id),
				"parent_contact_cell": negative.contact_cell,
			}
	# TASK E3b RULING 3 -- THE BRACKETED JETTY GETS ITS PRODUCER.
	#
	# `is_bracketed_jetty` was READ in three places and SET in none:
	# `_room_recipe_id` picks the authored `room.jetty.*` shell for it (one
	# bearing parent, role `bracketed_jetty_room`) instead of `room.bridge.*`
	# (two), `_residual_room_candidate` carries it, and this function's
	# `support_records` are what `WarrenSpatialFeatureSolver
	# ._reserve_residual_jetty_supports` reserves as the measured bracket
	# course. All three were dead: the search above returns only on a TWO-flank
	# pair, so no span was ever a jetty and no bracket was ever reserved.
	#
	# The form the three consumers describe, stated as the admission rule:
	# ONE exact flank socket bond, plus a measured bracket course under the
	# bearing edge that the feature solver can really commit. That is what the
	# comment above means by "even with brackets" -- a one-flank room with NO
	# bracket is the forbidden box; with the authored course beneath it, it is
	# the reviewed one-bay jetty, which is the cantilever the milestone asks
	# for. `jetty_brackets` is false for every legacy caller
	# (`_backfill_residual_rooms` passes nothing), so the searched modes are
	# byte-identical and only the plot model's own spans may become one.
	if not jetty_brackets or bindings_by_direction.size() != 1:
		return {}
	var jetty_direction := bound_directions[0] as Vector3i
	var jetty_binding := bindings_by_direction[jetty_direction] as Dictionary
	var jetty_records := _bridge_jetty_support_records(cells, jetty_direction,
		program)
	if jetty_records.is_empty():
		_residual_bridge_counts["jetty_unbracketed"] = int(
			_residual_bridge_counts.get("jetty_unbracketed", 0)) + 1
		return {}
	_residual_bridge_counts["jetty_bound"] = int(
		_residual_bridge_counts.get("jetty_bound", 0)) + 1
	return {
		"room_ids": [StringName(jetty_binding.room_id)] as Array[StringName],
		"parent_building_id": StringName(jetty_binding.building_id),
		"parent_contact_cell": jetty_binding.contact_cell,
		"is_bracketed_jetty": true,
			"support_records": jetty_records,
		}


static func _bridge_flank_pair_is_two_ended(first_direction: Vector3i,
		second_direction: Vector3i, first: Dictionary,
		second: Dictionary) -> bool:
	## A skywalk is a straight occupied link, not merely a room touching two
	## walls. Both sockets must oppose one another and terminate on independent
	## building lineages; a same-building return or corner touch is a cantilever.
	if first_direction != -second_direction:
		return false
	var first_room := StringName(first.get("room_id", &""))
	var second_room := StringName(second.get("room_id", &""))
	var first_building := StringName(first.get("building_id", &""))
	var second_building := StringName(second.get("building_id", &""))
	return not first_room.is_empty() and not second_room.is_empty() \
		and not first_building.is_empty() and not second_building.is_empty() \
		and first_room != second_room and first_building != second_building


static func _bridge_jetty_support_records(cells: Array[Vector3i],
		flank_direction: Vector3i,
		program: SettlementFabricProgram) -> Array[Dictionary]:
	## TASK E3b RULING 3. The measured bracket course under a ONE-flank bridge
	## room, in the shape `_reserve_residual_jetty_supports` reserves and
	## `_outcrop_support_analysis` validates: `{recipe_id, origin, yaw_quarters,
	## role}` against a recipe tagged `cantilever_support`.
	##
	## The geometry is the diagonal outcropping's own, restated for a span. The
	## BEARING EDGE is the room's floor-band columns that touch the flank; the
	## authored brace attaches there and projects OUTWARD (away from the flank)
	## under the cantilevered half. The course tiles that edge in native 3 m
	## pairs with the authored 1.5 m terminal for an odd column, exactly as
	## `WarrenSpatialFeatureSolver._cantilever_support_course_records` does, and
	## refuses outright if the edge is not one contiguous run -- a scaled or
	## invented support is never the answer.
	var out: Array[Dictionary] = []
	if cells.is_empty() or program == null:
		return out
	var cell_set: Dictionary = {}
	var floor_band := cells[0].y
	for cell: Vector3i in cells:
		cell_set[cell] = true
		floor_band = mini(floor_band, cell.y)
	var edge: Array[Vector2i] = []
	for cell: Vector3i in cells:
		if cell.y != floor_band or cell_set.has(cell + flank_direction):
			continue
		edge.append(Vector2i(cell.x, cell.z))
	if edge.is_empty():
		return out
	var yaw := WarrenSpatialFeatureSolver._yaw_for_local_direction(
		Vector3i.BACK, -flank_direction)
	if yaw < 0:
		return out
	var span_direction_3d := FabricRecipe.transform_direction(Vector3i.RIGHT,
		yaw)
	var span_direction := Vector2i(span_direction_3d.x, span_direction_3d.z)
	edge.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.x * span_direction.x + a.y * span_direction.y \
			< b.x * span_direction.x + b.y * span_direction.y)
	for index in range(1, edge.size()):
		if edge[index] != edge[index - 1] + span_direction:
			return [] as Array[Dictionary]
	for index in range(0, edge.size(), 2):
		var course_size := mini(2, edge.size() - index)
		var recipe_id := StringName("outcrop.support.bracketed.%d" \
			% course_size)
		var recipe := program.recipe(recipe_id)
		if recipe == null or not recipe.has_tag(&"cantilever_support"):
			return [] as Array[Dictionary]
		out.append({"recipe_id": recipe_id,
			"origin": Vector3i(edge[index].x, floor_band, edge[index].y),
			"yaw_quarters": yaw,
			"role": StringName("bridge_jetty_support.%02d" % (index / 2))})
	# FIX ROUND 1, IMPORTANT 2 -- ONE COURSE, OR NO JETTY.
	#
	# `frontier_gateway_support` is a ONE-RECORD feature by contract, on both
	# ends: `WarrenSpatialFeatureSolver._reserve_frontier_gateway_supports`
	# refuses a geometry that needs more than one course, and
	# `WarrenSpatialFabricCompiler._compile_frontier_gateway_supports` refuses
	# any such feature outright ("lacks its anchored room or bracket"). A
	# bearing edge of three or more columns tiles into two or more records, so
	# emitting one here would stamp a room whose bracket course the compiler is
	# certain to reject -- a town lost at the last stage to a fact provable at
	# this one.
	#
	# Refusing it HERE is the graceful path: an empty course makes
	# `_residual_bridge_span` return `{}`, which `_stamp_maze_bridges` already
	# handles by RELEASING the span, exactly as it does for a span whose proved
	# flanks do not bind. The cost is that a jetty may only span a bearing edge
	# of one or two columns; the alternative is not a wider jetty but a dead
	# town. Measured inert on the 24-town corpus -- the one composed jetty
	# (`12/standard`) has a two-column edge and one record.
	if out.size() != 1:
		_residual_bridge_counts["jetty_course_not_single"] = int(
			_residual_bridge_counts.get("jetty_course_not_single", 0)) + 1
		return [] as Array[Dictionary]
	return out


static func _bridge_flank_binding(cell_set: Dictionary,
		flank_room: WarrenRoomStamp, owner_id: StringName, world_seed: int,
		program: SettlementFabricProgram) -> Dictionary:
	## A flank binds when its centred cardinal bearing socket faces a cell of
	## the candidate footprint at the exact same band. The bridge recipe
	## authors a span socket on every side cell, so this one-sided test is the
	## complete strict mutual-adjacency proof.
	var recipe := program.recipe(WarrenSpatialFabricCompiler._room_recipe_id(
		flank_room, world_seed, true, 0))
	if recipe == null:
		_residual_bridge_counts["flank_recipe_null"] = int(
			_residual_bridge_counts.get("flank_recipe_null", 0)) + 1
		return {}
	var probed_sockets := 0
	for socket_name: StringName in [&"bearing.east", &"bearing.west",
			&"bearing.north", &"bearing.south"]:
		var socket := recipe.socket(socket_name)
		if socket.is_empty():
			continue
		probed_sockets += 1
		var socket_cell := FabricRecipe.transform_cell(
			socket.cell as Vector3i, flank_room.lattice_origin,
			flank_room.yaw_quarters)
		var facing := FabricRecipe.transform_direction(
			socket.facing as Vector3i, flank_room.yaw_quarters)
		if cell_set.has(socket_cell + facing):
			return {"room_id": flank_room.stable_id,
				"building_id": owner_id,
				"contact_cell": socket_cell}
		if not _residual_bridge_counts.has("sample_miss"):
			var candidate_cells: Array = cell_set.keys()
			candidate_cells.sort_custom(_cell_less)
			_residual_bridge_counts["sample_miss"] = {
				"flank_room": flank_room.stable_id,
				"flank_kind": flank_room.kind,
				"socket": socket_name,
				"socket_cell": socket_cell,
				"facing": facing,
				"candidate_min": candidate_cells[0]}
	if probed_sockets == 0:
		_residual_bridge_counts["flank_no_cardinal_sockets"] = int(
			_residual_bridge_counts.get("flank_no_cardinal_sockets", 0)) + 1
	return {}


static func _residual_room_envelope_fits(candidate: WarrenRoomStamp,
		building_by_id: Dictionary, program: SettlementFabricProgram,
		world_seed: int, grid: WarrenSpatialGrid = null,
		fixed_feature_bounds: Array[AABB] = []) -> bool:
	return _residual_room_envelope_rejection(candidate, building_by_id, program,
		world_seed, grid, fixed_feature_bounds).is_empty()


static func _residual_room_envelope_rejection(candidate: WarrenRoomStamp,
		building_by_id: Dictionary, program: SettlementFabricProgram,
		world_seed: int, grid: WarrenSpatialGrid = null,
		fixed_feature_bounds: Array[AABB] = []) -> String:
	## Residual packing is allowed to close a real party wall or bearing face, but
	## it may not rely on the final compiler to discover that two nearby authored
	## shells overlap. Check both the rich and plain existing phases because those
	## lower rooms are selected before a later residual room and cannot backtrack.
	if candidate == null or program == null:
		return "candidate or construction program is missing"
	if not _residual_preserves_existing_roofability(candidate, building_by_id):
		return "candidate would leave an existing room without a complete crown"
	var roof_conflict := _residual_existing_exact_roof_conflict(candidate,
		building_by_id, program, world_seed, grid)
	if not roof_conflict.is_empty():
		return ("candidate intersects existing room roof closure %s" \
			% roof_conflict)
	var role_roof_rejection := _role_specific_roof_rejection(candidate,
		building_by_id, program, world_seed)
	if not role_roof_rejection.is_empty():
		return role_roof_rejection
	var candidate_recipe := program.recipe(
		WarrenSpatialFabricCompiler._room_recipe_id(candidate, world_seed, false))
	if candidate_recipe == null:
		return "candidate has no authored room recipe"
	var candidate_bounds := FabricRecipe.lattice_transform(
		candidate.lattice_origin, candidate.yaw_quarters) \
		* candidate_recipe.local_clearance_bounds
	for feature_bounds: AABB in fixed_feature_bounds:
		if SettlementFabricPlan._aabb_overlaps_volume(candidate_bounds,
				feature_bounds):
			return "candidate envelope intersects a fixed feature envelope"
	for building_value: Variant in building_by_id.values():
		var building := building_value as WarrenBuildingVolume
		for existing: WarrenRoomStamp in building.room_records:
			if _rooms_share_lattice_face(candidate, existing):
				var explicit_roof_party_ids: Array = candidate.audit.get(
					"roof_party_allowed_room_ids", []) as Array
				if explicit_roof_party_ids.is_empty() \
						or explicit_roof_party_ids.has(existing.stable_id):
					continue
			for phase_b: bool in [true, false]:
				var recipe := program.recipe(WarrenSpatialFabricCompiler \
					._room_recipe_id(existing, world_seed, phase_b))
				if recipe == null:
					return "existing room %s has no authored recipe" % existing.stable_id
				var existing_bounds := FabricRecipe.lattice_transform(
					existing.lattice_origin, existing.yaw_quarters) \
					* recipe.local_clearance_bounds
				if SettlementFabricPlan._aabb_overlaps_volume(candidate_bounds,
						existing_bounds) and not SettlementFabricPlan._is_edge_nick(
						candidate_bounds, existing_bounds):
					return ("candidate envelope %s intersects room %s envelope %s" % [
						candidate_bounds, existing.stable_id, existing_bounds])
	if not _residual_roof_envelope_fits(candidate, building_by_id, program,
			world_seed, grid):
		return "candidate has no exact roof envelope that clears existing rooms"
	return ""


static func _role_specific_roof_rejection(candidate: WarrenRoomStamp,
		building_by_id: Dictionary, program: SettlementFabricProgram,
		world_seed: int) -> String:
	## A bridge endpoint's crown is a mandatory role recipe rather than part of
	## its room shell. Compare that exact roof envelope against already-committed
	## integrated bridge roofs during the reversible endpoint transaction. The
	## ordinary closure test cannot see an integrated roof as a separate roof
	## unit, which formerly let a second connector invalidate the entire town only
	## during final assembly.
	if candidate == null or program == null \
			or not candidate.audit.has("bridge_party_roof_yaw_quarters"):
		return ""
	var roof_candidates := WarrenSpatialFabricCompiler._full_roof_candidates(
		candidate, world_seed)
	if roof_candidates.is_empty():
		return "bridge endpoint has no role-specific roof"
	var roof_choice := roof_candidates[0] as Dictionary
	var roof_recipe := program.recipe(StringName(roof_choice.recipe_id))
	if roof_recipe == null:
		return "bridge endpoint role-specific roof is missing"
	var roof_origin := candidate.lattice_origin + Vector3i.UP \
		* WarrenSpatialGrid.STOREY_CELLS
	var roof_yaw := posmod(candidate.yaw_quarters \
		+ int(roof_choice.yaw_offset), 4)
	var roof_bounds := FabricRecipe.lattice_transform(roof_origin, roof_yaw) \
		* roof_recipe.local_clearance_bounds
	var allowed: Dictionary = {}
	for room_id_value: Variant in candidate.audit.get(
			"roof_party_allowed_room_ids", []) as Array:
		allowed[StringName(room_id_value)] = true
	for building_value: Variant in building_by_id.values():
		var building := building_value as WarrenBuildingVolume
		for existing: WarrenRoomStamp in building.room_records:
			if allowed.has(existing.stable_id):
				continue
			var existing_recipe := program.recipe(WarrenSpatialFabricCompiler \
				._room_recipe_id(existing, world_seed, false))
			if existing_recipe == null \
					or not existing_recipe.has_tag(&"integrated_pitched_roof"):
				continue
			var existing_bounds := FabricRecipe.lattice_transform(
				existing.lattice_origin, existing.yaw_quarters) \
				* existing_recipe.local_clearance_bounds
			if SettlementFabricPlan._aabb_overlaps_volume(roof_bounds,
					existing_bounds):
				return ("bridge endpoint roof intersects existing occupied bridge %s" \
					% existing.stable_id)
	return ""


static func _residual_preserves_existing_roofability(
		candidate: WarrenRoomStamp, building_by_id: Dictionary) -> bool:
	## A late room changes more than its own envelope: by occupying cells over an
	## earlier room it can subtract most of that room's crown and leave a single
	## plank-sized remnant. Compare the exact global roof components before and
	## after admission with the composition planner's canonical roofability
	## predicate. Infill may improve an existing shoulder, but never introduce a
	## new component the authored pitched/slab/shed vocabulary cannot cover.
	if candidate == null:
		return false
	var rooms: Array[WarrenRoomStamp] = []
	var occupied_before: Dictionary = {}
	for building_value: Variant in building_by_id.values():
		var building := building_value as WarrenBuildingVolume
		for room: WarrenRoomStamp in building.room_records:
			rooms.append(room)
			for cell: Vector3i in room.private_cells:
				occupied_before[cell] = true
	var occupied_after := occupied_before.duplicate()
	for cell: Vector3i in candidate.private_cells:
		occupied_after[cell] = true
	return _roofability_defect_count(rooms, occupied_after) \
		<= _roofability_defect_count(rooms, occupied_before)


static func _roofability_defect_count(rooms: Array[WarrenRoomStamp],
		occupied: Dictionary) -> int:
	var defects := 0
	for room: WarrenRoomStamp in rooms:
		var top_y := room.lattice_origin.y \
			+ WarrenSpatialGrid.STOREY_CELLS - 1
		var exposed: Dictionary = {}
		var upper_columns: Dictionary = {}
		for occupied_cell_value: Variant in occupied.keys():
			var occupied_cell := occupied_cell_value as Vector3i
			if occupied_cell.y == top_y + 1:
				upper_columns[Vector2i(occupied_cell.x, occupied_cell.z)] = true
		for cell: Vector3i in room.private_cells:
			if cell.y == top_y and not occupied.has(cell + Vector3i.UP):
				exposed[Vector2i(cell.x, cell.z)] = true
		for component: Dictionary in WarrenRoomCompositionPlanner \
				._column_components(exposed):
			defects += int(not WarrenRoomCompositionPlanner \
				._shoulder_component_is_roofable(component, upper_columns, top_y))
	return defects


static func _residual_roof_envelope_fits(candidate: WarrenRoomStamp,
		building_by_id: Dictionary, program: SettlementFabricProgram,
		world_seed: int, grid: WarrenSpatialGrid = null) -> bool:
	## Residual rooms are selected after the macro composition, so they must prove
	## a complete roof profile before entering the grid. Room-shell adjacency alone
	## is insufficient: the old preflight skipped every shared face and admitted a
	## small infill whose eaves later passed through an upper neighboring facade.
	var room_recipe := program.recipe(WarrenSpatialFabricCompiler \
		._room_recipe_id(candidate, world_seed, false))
	if room_recipe != null and room_recipe.has_tag(&"integrated_pitched_roof"):
		# `_residual_room_envelope_fits` has already measured this exact room
		# recipe against the existing town. Its roof is part of that envelope.
		return true
	var roof_candidates := WarrenSpatialFabricCompiler._full_roof_candidates(
		candidate, world_seed)
	# Residual admission must expose the same complete finite terminal domain as
	# final roof construction. Dense party-wall neighborhoods sometimes need a
	# singleton or mixed stepped run rather than the all-low minimum closure;
	# dropping those reviewed alternatives rejects otherwise complete back
	# houses and turns their plots back into retained mass. This enumeration is
	# bounded by the authored footprint (at most seven profiles for a long room),
	# and the large-town performance fix belongs at the duplicated whole-town
	# transaction rather than by deleting valid construction choices here.
	# A semantic crown role is already a complete finite domain. In particular,
	# a bridge endpoint may use only the seam-clipped party gable facing its
	# occupied span; appending the ordinary terminal-gable alternatives here
	# would let proposal admission prove one roof and final construction require
	# a different one. Ordinary residual houses retain the full bounded terminal
	# vocabulary below.
	if not candidate.audit.has("bridge_party_roof_yaw_quarters"):
		for tight_id: StringName in WarrenSpatialFabricCompiler \
				._terminal_tight_gable_recipe_ids(candidate, world_seed):
			roof_candidates.append({"recipe_id": tight_id, "yaw_offset": 0})
	# Ask the final roof compiler for every exact finite closure domain with this
	# still-optional room included. The old loop below inferred permission from
	# any room-face contact, but a facade party wall and a roof-neighborhood seam
	# are different topology: that approximation admitted a gable which the
	# atomic campaign later found passing through an unrelated terminal-tight
	# roof. Candidate admission now uses the same semantic and measured-seam
	# predicate as sequential roof commitment.
	var closure_rooms: Array[WarrenRoomStamp] = []
	for building_value: Variant in building_by_id.values():
		var closure_building := building_value as WarrenBuildingVolume
		if closure_building != null:
			closure_rooms.append_array(closure_building.room_records)
	closure_rooms.append(candidate)
	var required_closures := WarrenSpatialFabricCompiler \
		.required_roof_closure_options_for_rooms(grid, closure_rooms, program,
			world_seed) if grid != null else [] as Array[Dictionary]
	# Residual admission and final roof construction share the compiler's exact
	# required closure, rather than independently enumerating every stepped-gable
	# permutation. For a complete free crown that closure is the all-low authored
	# tiled profile; for a partial crown it is the pair of exact handed halves.
	# Proving any broader candidate set here was both redundant and quadratic in
	# dense towns. Keep ordinary aesthetic candidates as alternatives, then add
	# only the finite closure options the final transaction says this room owns.
	var roof_candidate_ids: Dictionary = {}
	for roof_candidate: Dictionary in roof_candidates:
		roof_candidate_ids[StringName(roof_candidate.recipe_id)] = true
	for closure: Dictionary in required_closures:
		if StringName(closure.owner_room_id) != candidate.stable_id:
			continue
		for option: Dictionary in closure.options as Array[Dictionary]:
			var closure_id := StringName(option.recipe_id)
			if roof_candidate_ids.has(closure_id):
				continue
			roof_candidates.append({"recipe_id": closure_id, "yaw_offset": 0})
			roof_candidate_ids[closure_id] = true
	var unbuilt_roof_room_ids: Dictionary = {}
	for closure: Dictionary in required_closures:
		var closure_owner := StringName(closure.owner_room_id)
		if closure_owner != candidate.stable_id:
			unbuilt_roof_room_ids[closure_owner] = true
	var occupied: Dictionary = {}
	var existing_semantic_solids: Dictionary = {}
	var reserves_role_exact_shells := candidate.audit.has(
		"bridge_party_roof_yaw_quarters")
	for building_value: Variant in building_by_id.values():
		for existing: WarrenRoomStamp in (building_value \
				as WarrenBuildingVolume).room_records:
			for cell: Vector3i in existing.private_cells:
				occupied[cell] = true
			if reserves_role_exact_shells:
				# A role-specific roof owns cells outside the ordinary terminal
				# envelope, so reserve every finite shell phase it may meet. Ordinary
				# residual roofs use the shared closure/AABB proof and do not pay this
				# extra enumeration for every proposal in a large town.
				for phase_b: bool in [true, false]:
					for chosen_material: bool in [false, true]:
						var existing_recipe := program.recipe(
							WarrenSpatialFabricCompiler._room_recipe_id(existing,
								world_seed, phase_b, 0, false,
								chosen_material))
						if existing_recipe == null:
							return false
						for local_solid: Vector3i in existing_recipe.solid_cells:
							existing_semantic_solids[FabricRecipe.transform_cell(
								local_solid, existing.lattice_origin,
								existing.yaw_quarters)] = true
	# `flat_roof` is a source-plot height relationship, not permission to crown
	# a free inhabited box with boards. The final compiler pitches every complete
	# terminal plate, so proposal admission must prove that same real gable even
	# when an upper street may later consume part of the plate.
	for roof_candidate: Dictionary in roof_candidates:
		var roof_id := StringName(roof_candidate.recipe_id)
		var roof_recipe := program.recipe(roof_id)
		if roof_recipe == null:
			continue
		for yaw_offset: int in [int(roof_candidate.yaw_offset)]:
			var roof_origin := candidate.lattice_origin + Vector3i.UP \
				* WarrenSpatialGrid.STOREY_CELLS
			var roof_yaw := posmod(candidate.yaw_quarters + yaw_offset, 4)
			var roof_transform := FabricRecipe.lattice_transform(roof_origin,
				roof_yaw)
			var roof_bounds := roof_transform * roof_recipe.local_clearance_bounds
			var clear := true
			# The final fabric transaction arbitrates exact semantic solid cells,
			# not only visual AABBs. Mirror that authoritative fact here: a roof
			# proposal whose authored solid lattice enters any already inhabited
			# room can never become a legal seam later. This catches gable ends at
			# dense party walls even when both meshes' conservative clearance boxes
			# merely touch and prevents committing half of a bridge compound whose
			# endpoint crown the final transaction must reject.
			for local_solid: Vector3i in roof_recipe.solid_cells:
				var roof_solid := FabricRecipe.transform_cell(local_solid,
					roof_origin, roof_yaw)
				if occupied.has(roof_solid) \
						or existing_semantic_solids.has(roof_solid):
					clear = false
					break
			if clear and grid != null:
				# Use the compiler's exact solid/collider body-lane test now, while
				# this is still a reversible proposal. A room whose eaves enter a
				# public route must never be committed and discovered only during
				# final roof assembly.
				var roof_probe := FabricUnit.new(&"residual.roof.probe", roof_id,
					roof_origin, roof_yaw)
				var public_conflicts := WarrenSpatialFabricCompiler \
					._unit_public_air_conflicts(grid, roof_probe, roof_recipe)
				clear = public_conflicts.is_empty()
				if clear:
					var closure_conflict := WarrenSpatialFabricCompiler \
						._roof_candidate_required_closure_conflict(roof_probe,
							roof_recipe, candidate.stable_id, required_closures,
							unbuilt_roof_room_ids, program)
					clear = closure_conflict.is_empty()
			for building_value: Variant in building_by_id.values():
				if not clear:
					break
				var building := building_value as WarrenBuildingVolume
				for existing: WarrenRoomStamp in building.room_records:
					for phase_b: bool in [true, false]:
						var existing_recipe := program.recipe(
							WarrenSpatialFabricCompiler._room_recipe_id(existing,
								world_seed, phase_b))
						if existing_recipe == null:
							return false
						var existing_bounds := FabricRecipe.lattice_transform(
							existing.lattice_origin, existing.yaw_quarters) \
							* existing_recipe.local_clearance_bounds
						if SettlementFabricPlan._aabb_overlaps_volume(roof_bounds,
								existing_bounds) \
								and not SettlementFabricPlan._is_edge_nick(
									roof_bounds, existing_bounds):
							clear = false
							break
					if not clear:
						break
				if not clear:
					break
			if clear:
				return true
	return false


static func _room_has_complete_terminal_crown(room: WarrenRoomStamp,
		occupied: Dictionary) -> bool:
	if room == null:
		return false
	var top_y := room.lattice_origin.y + WarrenSpatialGrid.STOREY_CELLS - 1
	var top_count := 0
	for cell: Vector3i in room.private_cells:
		if cell.y != top_y:
			continue
		top_count += 1
		if occupied.has(cell + Vector3i.UP):
			return false
	return top_count > 0


static func _rooms_share_lattice_face(left: WarrenRoomStamp,
		right: WarrenRoomStamp) -> bool:
	if left == null or right == null:
		return false
	var right_cells: Dictionary = {}
	for cell: Vector3i in right.private_cells:
		right_cells[cell] = true
	for cell: Vector3i in left.private_cells:
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD, Vector3i.BACK]:
			if right_cells.has(cell + direction):
				return true
	return false


static func _residual_authored_threshold(kind: StringName, origin: Vector3i,
		yaw: int) -> Vector3i:
	var local := Vector3i.ZERO
	match kind:
		&"tower":
			local = Vector3i(0, 0, 0)
		&"slim":
			local = Vector3i(0, 0, 1)
		&"row":
			local = Vector3i(-1, 0, 0)
		&"building":
			local = Vector3i(-1, 0, 1)
		&"long":
			local = Vector3i(-1, 0, 2)
		_:
			return Vector3i(2147483647, 2147483647, 2147483647)
	return FabricRecipe.transform_cell(local, origin, yaw)


static func _largest_contact_owner(counts: Dictionary) -> StringName:
	var best := &""
	var best_count := -1
	for owner_value: Variant in counts.keys():
		var owner := StringName(owner_value)
		var count := int(counts[owner])
		if count > best_count or count == best_count \
				and String(owner) < String(best):
			best = owner
			best_count = count
	return best


static func _residual_feature_protected(grid: WarrenSpatialGrid,
		cell: Vector3i, protected_owners: Dictionary,
		allowed_owner: StringName = &"") -> bool:
	var bits := grid.reservation_bits_at(cell)
	if (bits & (WarrenSpatialGrid.Reservation.FEATURE \
			| WarrenSpatialGrid.Reservation.VISUAL_CLEARANCE \
			| WarrenSpatialGrid.Reservation.PRIVATE_CONNECTION \
			| WarrenSpatialGrid.Reservation.PUBLIC_CLEARANCE \
			| WarrenSpatialGrid.Reservation.DAYLIGHT)) != 0:
		return true
	for owner_value: Variant in (protected_owners.get(cell, {}) \
			as Dictionary).keys():
		if not allowed_owner.is_empty() and String(owner_value).begins_with(
				String(allowed_owner)):
			continue
		var owner := String(owner_value)
		if owner.begins_with("spatial.feature.") \
				or owner.begins_with("spatial.skywalk.reserve."):
			return true
	return false


static func _residual_roof_feature(kind: StringName, origin: Vector3i,
		world_seed: int) -> int:
	## TASK I3. The table moved to `WarrenParcelConstruction`, which owns the
	## OTHER pass that builds a room, because two copies of one roofscape rule
	## had already drifted apart -- see `ROOF_FEATURE_PHASES` there. The seed
	## material stays this pass's own: a residual room has no threshold column
	## to key on, only its origin.
	return WarrenParcelConstruction.roof_feature_for_phase(kind,
		posmod(world_seed ^ origin.x * 73856093 \
			^ origin.y * 83492791 ^ origin.z * 19349663,
			WarrenParcelConstruction.ROOF_FEATURE_PHASES))


static func _discard_unassigned_mass(grid: WarrenSpatialGrid) -> bool:
	var cells := grid.cells_with_use(WarrenSpatialGrid.Use.ALLOCATABLE)
	if cells.is_empty():
		return true
	var discard := grid.begin_transaction(&"massif.discard")
	if not discard.assign_use(cells, WarrenSpatialGrid.Use.OUTSIDE, &"") \
			or not discard.commit():
		last_failure = "could not discard unowned allocation: %s" \
			% discard.last_rejection
		return false
	return true


static func _residual_existing_exact_roof_conflict(
		candidate: WarrenRoomStamp, building_by_id: Dictionary,
		program: SettlementFabricProgram, world_seed: int,
		grid: WarrenSpatialGrid) -> StringName:
	## Residual packing is downstream of the primary room composition but upstream
	## of roof construction. Ask the roof compiler for the exact finite closure
	## domains of the town WITH the candidate present, then prove the candidate's
	## mandatory shell against those domains with the compiler's own measured seam
	## policy. This covers full crowns and partial/setback gables identically and
	## removes the former second AABB-only approximation of roofability.
	if candidate == null or program == null or grid == null:
		return &"invalid-candidate-or-program"
	var rooms: Array[WarrenRoomStamp] = []
	for building_value: Variant in building_by_id.values():
		var building := building_value as WarrenBuildingVolume
		if building != null:
			rooms.append_array(building.room_records)
	rooms.append(candidate)
	var closures := WarrenSpatialFabricCompiler \
		.required_roof_closure_options_for_rooms(grid, rooms, program,
			world_seed)
	var candidate_recipe := program.recipe(WarrenSpatialFabricCompiler \
		._room_recipe_id(candidate, world_seed, false))
	if candidate_recipe == null:
		return &"missing-candidate-recipe"
	return WarrenSpatialFabricCompiler._room_required_roof_conflict(candidate,
		candidate_recipe, closures, program)


static func _unassigned_mass_audit(grid: WarrenSpatialGrid) -> Dictionary:
	## Unclaimed source mass is only a *candidate* solid from the Gaussian massif;
	## it is not automatically a missing building. Classify it before discard so a
	## large exterior-connected source shell cannot be mislabeled as one enormous
	## room hole, while a genuinely enclosed residual or a one-cell slit between
	## two occupied walls cannot hide inside that same shell component.
	var remaining: Dictionary = {}
	for cell: Vector3i in grid.cells_with_use(WarrenSpatialGrid.Use.ALLOCATABLE):
		remaining[cell] = true
	var component_count := 0
	var largest_component := 0
	var room_sized_component_count := 0
	var room_sized_cell_count := 0
	var thin_component_count := 0
	var exterior_component_count := 0
	var exterior_cell_count := 0
	var enclosed_component_count := 0
	var enclosed_cell_count := 0
	var enclosed_room_sized_component_count := 0
	var enclosed_room_sized_cell_count := 0
	var public_frontage_component_count := 0
	var public_frontage_face_count := 0
	var private_contact_face_count := 0
	var component_sizes := PackedInt32Array()
	var component_details: Array[Dictionary] = []
	var interstitial_gap_cells: Dictionary = {}
	var feature_clearance_gap_cells: Dictionary = {}
	while not remaining.is_empty():
		var start := remaining.keys()[0] as Vector3i
		var pending: Array[Vector3i] = [start]
		remaining.erase(start)
		var size := 0
		var minimum := start
		var maximum := start
		var exterior_faces := 0
		var public_faces := 0
		var private_faces := 0
		while not pending.is_empty():
			var current: Vector3i = pending.pop_back()
			size += 1
			minimum = minimum.min(current)
			maximum = maximum.max(current)
			if _is_one_cell_interstitial_gap(grid, current):
				# A trapped course inside another feature's exclusive
				# reservation, or flanked by a feature's own authored wall,
				# is typed, owned air rather than an unexplained crack. It is
				# reported separately and never becomes a join obligation.
				if _cell_has_exclusive_feature_reservation(grid, current) \
						or _interstitial_gap_is_feature_adjacent(grid,
							current):
					feature_clearance_gap_cells[current] = true
				else:
					interstitial_gap_cells[current] = true
			for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
					Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD,
					Vector3i.BACK]:
				var neighbor := current + direction
				var neighbor_use := grid.use_at(neighbor)
				exterior_faces += int(neighbor_use \
					== WarrenSpatialGrid.Use.OUTSIDE)
				public_faces += int(neighbor_use in [
					WarrenSpatialGrid.Use.PUBLIC_AIR,
					WarrenSpatialGrid.Use.DAYLIGHT_AIR])
				private_faces += int(neighbor_use \
					== WarrenSpatialGrid.Use.PRIVATE_VOLUME)
				if not remaining.has(neighbor):
					continue
				remaining.erase(neighbor)
				pending.append(neighbor)
		component_count += 1
		largest_component = maxi(largest_component, size)
		component_sizes.append(size)
		# Eight fine cells are the smallest complete 2x2x2 room stamp.
		room_sized_component_count += int(size >= 8)
		room_sized_cell_count += size if size >= 8 else 0
		var extent := maximum - minimum + Vector3i.ONE
		thin_component_count += int(extent.x < 2 or extent.y < 2 \
			or extent.z < 2)
		var exterior_connected := exterior_faces > 0
		exterior_component_count += int(exterior_connected)
		exterior_cell_count += size if exterior_connected else 0
		enclosed_component_count += int(not exterior_connected)
		enclosed_cell_count += size if not exterior_connected else 0
		enclosed_room_sized_component_count += int(not exterior_connected \
			and size >= 8)
		enclosed_room_sized_cell_count += size if not exterior_connected \
			and size >= 8 else 0
		public_frontage_component_count += int(public_faces > 0)
		public_frontage_face_count += public_faces
		private_contact_face_count += private_faces
		if component_details.size() < 16:
			component_details.append({"size": size, "minimum": minimum,
				"maximum": maximum, "exterior_connected": exterior_connected,
				"exterior_face_count": exterior_faces,
				"public_frontage_face_count": public_faces,
				"private_contact_face_count": private_faces,
				"classification": &"discardable_exterior_trim" \
					if exterior_connected else &"enclosed_residual"})
	component_sizes.sort()
	component_sizes.reverse()
	if component_sizes.size() > 16:
		component_sizes.resize(16)
	var gap_component_sizes := _dictionary_component_sizes(
		interstitial_gap_cells)
	var gap_cells: Array[Vector3i] = []
	gap_cells.assign(interstitial_gap_cells.keys())
	gap_cells.sort_custom(_cell_less)
	var gap_details: Array[Dictionary] = []
	for cell: Vector3i in gap_cells:
		if gap_details.size() >= 16:
			break
		gap_details.append(_interstitial_gap_detail(grid, cell))
	return {"trimmed_mass_component_count": component_count,
		"trimmed_mass_largest_component_cell_count": largest_component,
		"trimmed_mass_room_sized_component_count": room_sized_component_count,
		"trimmed_mass_room_sized_cell_count": room_sized_cell_count,
		"trimmed_mass_thin_component_count": thin_component_count,
		"trimmed_mass_largest_component_sizes": component_sizes,
		"discardable_exterior_trim_component_count":
			exterior_component_count,
		"discardable_exterior_trim_cell_count": exterior_cell_count,
		"enclosed_residual_component_count": enclosed_component_count,
		"enclosed_residual_cell_count": enclosed_cell_count,
		"enclosed_room_sized_residual_component_count":
			enclosed_room_sized_component_count,
		"enclosed_room_sized_residual_cell_count":
			enclosed_room_sized_cell_count,
		"public_frontage_residual_component_count":
			public_frontage_component_count,
		"public_frontage_residual_face_count": public_frontage_face_count,
		"private_contact_residual_face_count": private_contact_face_count,
		"one_cell_interstitial_gap_cell_count": interstitial_gap_cells.size(),
		"one_cell_interstitial_gap_component_count":
			gap_component_sizes.size(),
		"one_cell_interstitial_gap_component_sizes": gap_component_sizes,
		"one_cell_interstitial_gap_details": gap_details,
		"feature_clearance_gap_cell_count": feature_clearance_gap_cells.size(),
		"trimmed_mass_component_details": component_details}


static func _cell_has_exclusive_feature_reservation(grid: WarrenSpatialGrid,
		cell: Vector3i) -> bool:
	## True when a composed feature exclusively owns this cell's air (visual
	## clearance, feature body reservation, or protected connection). Such a
	## course is deliberate typed void, not an unexplained interstitial crack.
	var bits := grid.reservation_bits_at(cell)
	var exclusive := bits & ~(WarrenSpatialGrid.Reservation.TERRAIN_BEARING \
		| WarrenSpatialGrid.Reservation.LOAD_CHANNEL \
		| WarrenSpatialGrid.Reservation.CONSTRUCTION_SEAM)
	return exclusive != 0


static func _interstitial_gap_is_feature_adjacent(grid: WarrenSpatialGrid,
		cell: Vector3i) -> bool:
	## A trapped course whose flanking wall belongs to a composed feature
	## (landmark prefab, bridge house, sealed strip) is part of that feature's
	## authored silhouette — a sculpted concavity or clearance reveal, never a
	## two-building contact defect the join transaction may fill with mass.
	var detail := _interstitial_gap_detail(grid, cell)
	return String(StringName(detail.get("negative_owner", &""))).begins_with(
			"spatial.feature.") \
		or String(StringName(detail.get("positive_owner", &""))).begins_with(
			"spatial.feature.")


static func _is_one_cell_interstitial_gap(grid: WarrenSpatialGrid,
		cell: Vector3i) -> bool:
	if grid.use_at(cell) != WarrenSpatialGrid.Use.ALLOCATABLE:
		return false
	# A single 1.5 m residual course trapped between occupied walls is too small
	# to read as a deliberate alley and is exactly the screenshot failure this
	# audit targets. A public-air cell is never included because intentional
	# passages are carved and typed before room composition.
	return grid.use_at(cell + Vector3i.LEFT) \
			== WarrenSpatialGrid.Use.PRIVATE_VOLUME \
		and grid.use_at(cell + Vector3i.RIGHT) \
			== WarrenSpatialGrid.Use.PRIVATE_VOLUME \
		or grid.use_at(cell + Vector3i.FORWARD) \
			== WarrenSpatialGrid.Use.PRIVATE_VOLUME \
		and grid.use_at(cell + Vector3i.BACK) \
			== WarrenSpatialGrid.Use.PRIVATE_VOLUME


static func _interstitial_gap_detail(grid: WarrenSpatialGrid,
		cell: Vector3i) -> Dictionary:
	var axis := &"x"
	var negative := cell + Vector3i.LEFT
	var positive := cell + Vector3i.RIGHT
	if grid.use_at(negative) != WarrenSpatialGrid.Use.PRIVATE_VOLUME \
			or grid.use_at(positive) != WarrenSpatialGrid.Use.PRIVATE_VOLUME:
		axis = &"z"
		negative = cell + Vector3i.FORWARD
		positive = cell + Vector3i.BACK
	return {"cell": cell, "axis": axis,
		"negative_owner": grid.owner_name_at(negative),
		"positive_owner": grid.owner_name_at(positive)}


static func _dictionary_component_sizes(cells: Dictionary) \
		-> PackedInt32Array:
	var remaining := cells.duplicate()
	var sizes := PackedInt32Array()
	while not remaining.is_empty():
		var start := remaining.keys()[0] as Vector3i
		var pending: Array[Vector3i] = [start]
		remaining.erase(start)
		var size := 0
		while not pending.is_empty():
			var current: Vector3i = pending.pop_back()
			size += 1
			for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
					Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD,
					Vector3i.BACK]:
				var neighbor := current + direction
				if not remaining.has(neighbor):
					continue
				remaining.erase(neighbor)
				pending.append(neighbor)
		sizes.append(size)
	sizes.sort()
	sizes.reverse()
	if sizes.size() > 16:
		sizes.resize(16)
	return sizes


static func _carve_route_connected_rooftop_court(grid: WarrenSpatialGrid,
		source: WarrenVolumePlan, route_floors: Array[Vector3i],
		buildings: Array[WarrenBuildingVolume]) -> Dictionary:
	## Turn one broad, supported room crown into canonical exterior circulation.
	## The selected cells are not a platform floating over the town: every floor
	## face is the top of inhabited volume, and a two-cell seam joins the existing
	## bored route.  The later shell pass sees PUBLIC_FLOOR on that interface and
	## therefore emits neither a pitched roof nor a second overlapping floor.
	if grid == null or grid.is_sealed() or source == null \
			or not source.is_sealed() or route_floors.is_empty() \
			or buildings.is_empty():
		last_failure = "roof-court planning lacks mutable town topology"
		return {"failed": true}
	var building_by_cell: Dictionary = {}
	for building: WarrenBuildingVolume in buildings:
		for cell: Vector3i in building.private_cells:
			building_by_cell[cell] = building.stable_id
	var available: Dictionary = {}
	for cell_value: Variant in building_by_cell.keys():
		var top_cell := cell_value as Vector3i
		if building_by_cell.has(top_cell + Vector3i.UP):
			continue
		var surface := top_cell + Vector3i.UP
		var headroom := surface + Vector3i.UP
		if not grid.contains(surface) or not grid.contains(headroom) \
				or grid.use_at(surface) not in [WarrenSpatialGrid.Use.OUTSIDE,
					WarrenSpatialGrid.Use.ALLOCATABLE] \
				or grid.use_at(headroom) not in [WarrenSpatialGrid.Use.OUTSIDE,
					WarrenSpatialGrid.Use.ALLOCATABLE] \
				or grid.reservation_bits_at(surface) != 0 \
				or grid.reservation_bits_at(headroom) != 0 \
				or not grid.face_claim(surface, Vector3i.DOWN).is_empty():
			continue
		var macro_column := Vector2i(floori(float(surface.x) / 2.0),
			floori(float(surface.z) / 2.0))
		if surface.y - source.envelope.ground_at(macro_column) \
				< MIN_ROOFTOP_COURT_LIFT_CELLS:
			continue
		available[surface] = building_by_cell[top_cell]
	if available.is_empty():
		return {"failed": false, "court_count": 0,
			"floor_cells": [] as Array[Vector3i],
			"audit": {"candidate_count": 0, "rejection": &"no_room_crowns"}}
	var route_set: Dictionary = {}
	for floor: Vector3i in route_floors:
		# A new court must join the actual bore (or its authored transition), not
		# depend on another supplemental surface that the realm adapter has not
		# connected yet.
		if grid.owner_name_at(floor) == &"public.route":
			route_set[floor] = true
	var candidates: Array[Dictionary] = []
	var seen: Dictionary = {}
	for surface_value: Variant in available.keys():
		var anchor := surface_value as Vector3i
		for shape: Vector2i in ROOFTOP_COURT_SHAPES:
			# A real court may absorb the same-level path that enters it. Search
			# every placement of this supported anchor inside the rectangle rather
			# than insisting that all cells be removable roofs. This lets the route
			# cross the broad roof plaza instead of hanging a one-cell doorway off a
			# two-cell-wide private crown.
			for anchor_z in shape.y:
				for anchor_x in shape.x:
					var corner := anchor - Vector3i(anchor_x, 0, anchor_z)
					var candidate_key := "%d:%d:%d/%d:%d" % [corner.x,
						corner.y, corner.z, shape.x, shape.y]
					if seen.has(candidate_key):
						continue
					seen[candidate_key] = true
					var cells: Array[Vector3i] = []
					var new_cells: Array[Vector3i] = []
					var owner_ids: Dictionary = {}
					var route_inside_count := 0
					var complete := true
					for z_offset in shape.y:
						for x_offset in shape.x:
							var surface := corner + Vector3i(x_offset, 0,
								z_offset)
							if available.has(surface):
								new_cells.append(surface)
								owner_ids[StringName(available[surface])] = true
							elif route_set.has(surface):
								route_inside_count += 1
							else:
								complete = false
								break
							cells.append(surface)
						if not complete:
							break
					if not complete or new_cells.size() < 8 \
							or new_cells.size() * 5 < cells.size() * 3 \
							or route_inside_count == 0:
						continue
					var best_seam_direction := Vector3i.ZERO
					var best_seam_count := route_inside_count
					for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
							Vector3i.FORWARD, Vector3i.BACK]:
						var seam_count := 0
						for cell: Vector3i in cells:
							var on_edge := cell.x == corner.x \
								if direction == Vector3i.LEFT \
								else cell.x == corner.x + shape.x - 1 \
									if direction == Vector3i.RIGHT \
								else cell.z == corner.z \
									if direction == Vector3i.FORWARD \
								else cell.z == corner.z + shape.y - 1
							if on_edge and route_set.has(cell + direction):
								seam_count += 1
						if seam_count > best_seam_count:
							best_seam_count = seam_count
							best_seam_direction = direction
					if best_seam_count < 2:
						continue
					var enclosing_facade_cells := 0
					for cell: Vector3i in cells:
						for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
								Vector3i.FORWARD, Vector3i.BACK]:
							var neighbor := cell + direction
							if available.has(neighbor) or route_set.has(neighbor):
								continue
							enclosing_facade_cells += int(grid.use_at(neighbor) \
								== WarrenSpatialGrid.Use.PRIVATE_VOLUME \
								or grid.use_at(neighbor + Vector3i.UP) \
									== WarrenSpatialGrid.Use.PRIVATE_VOLUME)
					var score := cells.size() * 10000 \
						+ best_seam_count * 800 \
						+ enclosing_facade_cells * 300 \
						+ owner_ids.size() * 120 + corner.y * 10
					var tie := posmod(Helper._mix64(source.world_seed \
						^ corner.x * 73856093 ^ corner.y * 83492791 \
						^ corner.z * 19349663 ^ shape.x * 131 \
						^ shape.y * 197), 1000003)
					candidates.append({"corner": corner, "shape": shape,
						"cells": new_cells, "combined_cells": cells,
						"owner_ids": owner_ids, "is_irregular": false,
						"seam_direction": best_seam_direction,
						"seam_count": best_seam_count,
						"route_inside_count": route_inside_count,
						"enclosing_facade_cell_count": enclosing_facade_cells,
						"score": score, "tie": tie})
	# Dense massing frequently forms an L/T roof union rather than one perfect
	# rectangle. Accept the complete connected crown when it still meets two
	# adjacent route lanes. This produces the requested non-boxy court outline
	# while preserving a literal player-width graph seam.
	if candidates.is_empty():
		candidates = _irregular_rooftop_court_candidates(available, route_set,
			grid, source.world_seed)
	if candidates.is_empty():
		return {"failed": false, "court_count": 0,
			"floor_cells": [] as Array[Vector3i],
			"audit": _rooftop_court_supply_audit(available, route_set)}
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.score) != int(b.score):
			return int(a.score) > int(b.score)
		return int(a.tie) < int(b.tie))
	var selected := candidates[0] as Dictionary
	var floors := selected.cells as Array[Vector3i]
	var air_set: Dictionary = {}
	for floor: Vector3i in floors:
		air_set[floor] = true
		air_set[floor + Vector3i.UP] = true
	var air_cells: Array[Vector3i] = []
	air_cells.assign(air_set.keys())
	air_cells.sort_custom(_cell_less)
	var feature_id := &"public.rooftop_court.00"
	var carve := grid.begin_transaction(feature_id)
	if not carve.require_use(air_cells, [WarrenSpatialGrid.Use.OUTSIDE,
			WarrenSpatialGrid.Use.ALLOCATABLE] as Array[int]) \
			or not carve.reserve(air_cells,
				WarrenSpatialGrid.Reservation.PUBLIC_CLEARANCE, feature_id) \
			or not carve.assign_use(air_cells,
				WarrenSpatialGrid.Use.PUBLIC_AIR, feature_id):
		last_failure = "could not stage route-connected roof court"
		return {"failed": true}
	for floor: Vector3i in floors:
		if not carve.claim_face(floor, Vector3i.DOWN,
				WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR, feature_id):
			last_failure = "could not stage roof-court floor at %s" % floor
			return {"failed": true}
	if not carve.commit():
		last_failure = "roof-court carve rejected: %s" % carve.last_rejection
		return {"failed": true}
	return {"failed": false, "court_count": 1, "floor_cells": floors,
		"audit": {"candidate_count": candidates.size(),
			"floor_cell_count": floors.size(),
			"combined_floor_cell_count": (selected.get("combined_cells",
				floors) as Array).size(),
			"shape": selected.shape, "floor_band": (floors[0] as Vector3i).y,
			"is_irregular": bool(selected.get("is_irregular", false)),
			"route_inside_cell_count": int(selected.get(
				"route_inside_count", 0)),
			"supporting_building_count": (selected.owner_ids as Dictionary).size(),
			"route_seam_cell_count": int(selected.seam_count),
			"route_seam_direction": selected.seam_direction,
			"enclosing_facade_cell_count": int(
				selected.enclosing_facade_cell_count)}}


static func _irregular_rooftop_court_candidates(available: Dictionary,
		route_set: Dictionary, grid: WarrenSpatialGrid,
		world_seed: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var remaining := available.duplicate()
	while not remaining.is_empty():
		var start := remaining.keys()[0] as Vector3i
		var frontier: Array[Vector3i] = [start]
		var cells: Array[Vector3i] = []
		remaining.erase(start)
		while not frontier.is_empty():
			var current: Vector3i = frontier.pop_back()
			cells.append(current)
			for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
					Vector3i.FORWARD, Vector3i.BACK]:
				var neighbor := current + direction
				if remaining.erase(neighbor):
					frontier.append(neighbor)
		if cells.size() < 12 or cells.size() > 24:
			continue
		cells.sort_custom(_cell_less)
		var minimum := Vector2i(2147483647, 2147483647)
		var maximum := Vector2i(-2147483648, -2147483648)
		for cell: Vector3i in cells:
			minimum = minimum.min(Vector2i(cell.x, cell.z))
			maximum = maximum.max(Vector2i(cell.x, cell.z))
		var spans := maximum - minimum + Vector2i.ONE
		if mini(spans.x, spans.y) < 3:
			# Long roof strips are useful galleries, but do not meet the civic-court
			# contract and must keep their ordinary roof treatment.
			continue
		var seams: Array[Dictionary] = []
		for cell: Vector3i in cells:
			for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
					Vector3i.FORWARD, Vector3i.BACK]:
				var route_cell := cell + direction
				if route_set.has(route_cell):
					seams.append({"court_cell": cell, "route_cell": route_cell,
						"direction": direction})
		var selected_seam: Array[Dictionary] = []
		for first_index in seams.size():
			for second_index in range(first_index + 1, seams.size()):
				var first := seams[first_index] as Dictionary
				var second := seams[second_index] as Dictionary
				var court_delta := (first.court_cell as Vector3i) \
					- (second.court_cell as Vector3i)
				var route_delta := (first.route_cell as Vector3i) \
					- (second.route_cell as Vector3i)
				if absi(court_delta.x) + absi(court_delta.z) == 1 \
						and court_delta.y == 0 \
						and absi(route_delta.x) + absi(route_delta.z) == 1 \
						and route_delta.y == 0:
					selected_seam.assign([first, second])
					break
			if not selected_seam.is_empty():
				break
		# A broad crown may meet one cell of an existing route node. The common
		# realm adapter folds this connected patch into that same node, so this is
		# not a one-lane graph edge and does not weaken the two-lane episode seam
		# invariant. It is simply a 1.5 m opening from a path into a wider court.
		if selected_seam.is_empty() and not seams.is_empty():
			selected_seam.append(seams[0])
		if selected_seam.is_empty():
			continue
		var owner_ids: Dictionary = {}
		var enclosing_facade_cells := 0
		for cell: Vector3i in cells:
			owner_ids[StringName(available[cell])] = true
			for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
					Vector3i.FORWARD, Vector3i.BACK]:
				var neighbor := cell + direction
				if available.has(neighbor) or route_set.has(neighbor):
					continue
				enclosing_facade_cells += int(
					grid.use_at(neighbor) == WarrenSpatialGrid.Use.PRIVATE_VOLUME \
					or grid.use_at(neighbor + Vector3i.UP) \
						== WarrenSpatialGrid.Use.PRIVATE_VOLUME)
		var seam_direction := (selected_seam[0] as Dictionary).direction \
			as Vector3i
		var tie := posmod(Helper._mix64(world_seed ^ start.x * 73856093 \
			^ start.y * 83492791 ^ start.z * 19349663), 1000003)
		out.append({"corner": start, "shape": Vector2i.ZERO,
			"cells": cells, "owner_ids": owner_ids, "is_irregular": true,
			"seam_direction": seam_direction, "seam_count": seams.size(),
			"enclosing_facade_cell_count": enclosing_facade_cells,
			"score": cells.size() * 9500 + enclosing_facade_cells * 300 \
				+ seams.size() * 800 + owner_ids.size() * 120 + start.y * 10,
			"tie": tie})
	return out


static func _rooftop_court_supply_audit(available: Dictionary,
		route_set: Dictionary) -> Dictionary:
	var remaining := available.duplicate()
	var component_sizes := PackedInt32Array()
	var component_details: Array[Dictionary] = []
	var route_adjacent_count := 0
	var route_adjacent_by_band: Dictionary = {}
	for cell_value: Variant in available.keys():
		var cell := cell_value as Vector3i
		var adjacent := false
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.FORWARD, Vector3i.BACK]:
			adjacent = adjacent or route_set.has(cell + direction)
		route_adjacent_count += int(adjacent)
		if adjacent:
			route_adjacent_by_band[cell.y] = int(
				route_adjacent_by_band.get(cell.y, 0)) + 1
	while not remaining.is_empty():
		var start := remaining.keys()[0] as Vector3i
		var frontier: Array[Vector3i] = [start]
		remaining.erase(start)
		var size := 0
		var minimum := start
		var maximum := start
		var nearest_route_distance := 2147483647
		var nearest_route_cell := Vector3i(2147483647, 2147483647, 2147483647)
		while not frontier.is_empty():
			var current: Vector3i = frontier.pop_back()
			size += 1
			minimum = minimum.min(current)
			maximum = maximum.max(current)
			for route_value: Variant in route_set.keys():
				var route_cell := route_value as Vector3i
				var distance := absi(route_cell.x - current.x) \
					+ absi(route_cell.y - current.y) \
					+ absi(route_cell.z - current.z)
				if distance < nearest_route_distance:
					nearest_route_distance = distance
					nearest_route_cell = route_cell
			for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
					Vector3i.FORWARD, Vector3i.BACK]:
				var neighbor := current + direction
				if remaining.erase(neighbor):
					frontier.append(neighbor)
		component_sizes.append(size)
		component_details.append({"size": size, "minimum": minimum,
			"maximum": maximum, "nearest_route_distance": nearest_route_distance,
			"nearest_route_cell": nearest_route_cell})
	component_sizes.sort()
	component_sizes.reverse()
	component_details.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.size) > int(b.size) if int(a.size) != int(b.size) \
			else int(a.nearest_route_distance) < int(b.nearest_route_distance))
	if component_sizes.size() > 12:
		component_sizes.resize(12)
	if component_details.size() > 12:
		component_details.resize(12)
	return {"candidate_count": 0,
		"rejection": &"no_broad_route_connected_crown",
		"available_room_crown_cell_count": available.size(),
		"route_adjacent_room_crown_cell_count": route_adjacent_count,
		"route_adjacent_room_crown_by_band": route_adjacent_by_band,
		"room_crown_component_sizes": component_sizes,
		"room_crown_component_details": component_details}


static func _derive_shell(grid: WarrenSpatialGrid,
		buildings: Array[WarrenBuildingVolume]) -> bool:
	var threshold_faces: Dictionary = {}
	for building: WarrenBuildingVolume in buildings:
		for threshold: Dictionary in building.thresholds:
			threshold_faces[WarrenSpatialGrid._face_key(
				threshold.private_cell as Vector3i,
				threshold.direction as Vector3i)] = building.stable_id
	var shell := grid.begin_transaction(&"spatial.shell")
	var roof_clearance_by_owner: Dictionary = {}
	for building: WarrenBuildingVolume in buildings:
		for cell: Vector3i in building.private_cells:
			for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
					Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD,
					Vector3i.BACK]:
				var neighbor := cell + direction
				var neighbor_use := grid.use_at(neighbor)
				# Topology-first composed features may already own this exact
				# interface (for example the open seam between a room and an
				# enclosed skywalk). Shell derivation never replaces it with a
				# generic party wall.
				if not grid.face_claim(cell, direction).is_empty():
					continue
				var face_kind := -1
				var owner_id := building.stable_id
				if neighbor_use == WarrenSpatialGrid.Use.PUBLIC_AIR:
					var key := WarrenSpatialGrid._face_key(cell, direction)
					if direction == Vector3i.UP:
						# The carver already owns the canonical upper interface
						# wherever a street or court walks on inhabited mass.
						# Reclassifying it as a soffit/roof would make the same
						# face contradict itself depending on traversal order.
						var existing := grid.face_claim(cell, direction)
						if not existing.is_empty() and int(existing.kind) \
								== WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR:
							continue
						face_kind = WarrenSpatialGrid.FaceKind.ROOF
					elif direction == Vector3i.DOWN:
						face_kind = WarrenSpatialGrid.FaceKind.SOFFIT
					else:
						face_kind = WarrenSpatialGrid.FaceKind.DOOR \
							if threshold_faces.has(key) \
							else WarrenSpatialGrid.FaceKind.FACADE
				elif neighbor_use == WarrenSpatialGrid.Use.PRIVATE_VOLUME:
					var neighbor_owner := grid.owner_name_at(neighbor)
					if neighbor_owner != building.stable_id:
						face_kind = WarrenSpatialGrid.FaceKind.PARTY_WALL
						owner_id = &"spatial.party_wall"
				elif direction == Vector3i.UP:
					face_kind = WarrenSpatialGrid.FaceKind.ROOF
					if not roof_clearance_by_owner.has(building.stable_id):
						roof_clearance_by_owner[building.stable_id] = \
							[] as Array[Vector3i]
					for y_offset in range(1, ROOF_CLEARANCE_CELLS + 1):
						var clearance := cell + Vector3i.UP * y_offset
						if grid.contains(clearance) and grid.use_at(clearance) \
								== WarrenSpatialGrid.Use.OUTSIDE:
							(roof_clearance_by_owner[building.stable_id] \
								as Array[Vector3i]).append(clearance)
				elif direction == Vector3i.DOWN:
					face_kind = WarrenSpatialGrid.FaceKind.PRIVATE_FLOOR
				elif neighbor_use in [WarrenSpatialGrid.Use.OUTSIDE,
						WarrenSpatialGrid.Use.DAYLIGHT_AIR,
						WarrenSpatialGrid.Use.SERVICE_VOID]:
					face_kind = WarrenSpatialGrid.FaceKind.FACADE
				if face_kind >= 0 and not shell.claim_face(cell, direction,
						face_kind, owner_id):
					last_failure = "could not classify shell face at %s" % cell
					return false
	for owner_value: Variant in roof_clearance_by_owner.keys():
		var owner_id := StringName(owner_value)
		var unique: Dictionary = {}
		for cell: Vector3i in roof_clearance_by_owner[owner_id] \
				as Array[Vector3i]:
			unique[cell] = true
		var cells: Array[Vector3i] = []
		cells.assign(unique.keys())
		if not cells.is_empty() and not shell.reserve(cells,
				WarrenSpatialGrid.Reservation.ROOF_CLEARANCE, owner_id):
			last_failure = "could not reserve roof clearance for %s" % owner_id
			return false
	if not shell.commit():
		last_failure = "derived shell rejected: %s" % shell.last_rejection
		return false
	return true


static func _fine_square(macro_cell: Vector3i) -> Array[Vector3i]:
	var origin := Vector3i(macro_cell.x * 2, macro_cell.y,
		macro_cell.z * 2)
	return [origin, origin + Vector3i.RIGHT, origin + Vector3i.BACK,
		origin + Vector3i(1, 0, 1)] as Array[Vector3i]


static func _cell_less(a: Vector3i, b: Vector3i) -> bool:
	if a.y != b.y:
		return a.y < b.y
	if a.z != b.z:
		return a.z < b.z
	return a.x < b.x


static func _string_name_less(left: StringName,
		right: StringName) -> bool:
	return String(left) < String(right)


static func _maze_back_room_less(left: Dictionary,
		right: Dictionary) -> bool:
	if int(left["band"]) != int(right["band"]):
		return int(left["band"]) < int(right["band"])
	if int(left["record"]) != int(right["record"]):
		return int(left["record"]) < int(right["record"])
	return int(left["rectangle"]) < int(right["rectangle"])
