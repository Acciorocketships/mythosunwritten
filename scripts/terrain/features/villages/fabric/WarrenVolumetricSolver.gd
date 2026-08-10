class_name WarrenVolumetricSolver
extends RefCounted

## First production front end for the fine-grid volumetric architecture.  It
## reuses the proven terrain-grounded massif and bore as topology input, then
## abandons the old extrusion interpretation: remaining mass is assigned to
## offset 3D room volumes, exact interfaces, and an explicit support DAG.
const MIN_BUILDINGS := 10
const GRID_PADDING_CELLS := 2
const ROOF_CLEARANCE_CELLS := 2
const MAX_PARTITION_VARIANTS := WarrenSolidPartitioner.PARTITION_VARIANTS
const MAX_LANDMARK_SET_ATTEMPTS := 12
const MAX_RESIDUAL_BACKFILL_BUILDINGS := 24
const MAX_RESIDUAL_BACKFILL_PER_KIND := 6
const RESIDUAL_OVERHEAD_ROUTE_CELL_SCORE := 50000
const RESIDUAL_FRONTAGE_SIDE_SCORE := 6000
## Screenshot-backed production gates. A town with every requested feature can
## still read as isolated facades around an open plaza; require the compiled
## exterior realm to keep most long views broken and a substantial fraction of
## the route physically under inhabited mass.
const MIN_PRODUCTION_OVERHEAD_ROUTE_RATIO := 0.38
const MAX_PRODUCTION_THROUGH_SIGHTLINES := 48
const MAX_PRODUCTION_GROUND_THROUGH_SIGHTLINES := 20
const COURTYARD_BRIDGE_FEATURE_ID := \
	&"spatial.feature.courtyard_bridge_house.00"
## The third courtyard side may be a real occupied bridge-house selected by the
## joint 3D feature transaction.  The parcel partition must still supply two
## independent room walls; the complete spatial proof below requires all three.
const MIN_COURT_PARCEL_SIDE_COUNT := 2

static var last_failure := ""
static var last_diagnostic: Dictionary = {}
static var last_preplan_skywalk_diagnostic: Dictionary = {}
static var last_preplan_market_diagnostic: Dictionary = {}
static var last_preplan_landmark_diagnostic: Dictionary = {}
static var _last_skywalk_selection_failure := ""
## Harness-only performance seam. Production never sets this; it lets a probe
## stop after geometric/fixed-block skywalk filtering instead of paying for the
## endpoint-composition beam while diagnosing candidate growth.
static var diagnostic_stop_after_skywalk_candidates := false
static var diagnostic_stop_after_skywalk_individual := false
static var diagnostic_skywalk_candidate_limit := -1
static var diagnostic_trace_skywalk_timing := false
static var diagnostic_trace_room_gate := false
static var diagnostic_feature_market_limit := -1


static func solve(world_seed: int,
		ground_bands: Dictionary = {},
		construction_program: SettlementFabricProgram = null) -> WarrenSpatialPlan:
	last_failure = ""
	last_diagnostic = {}
	last_preplan_skywalk_diagnostic = {}
	last_preplan_market_diagnostic = {}
	last_preplan_landmark_diagnostic = {}
	if construction_program == null:
		last_failure = "volumetric feature search requires measured construction vocabulary"
		return null
	var frontier := WarrenTownSolver.mass_first_frontier(world_seed, ground_bands)
	if frontier.is_empty():
		last_failure = WarrenTownSolver.last_failure
		return null
	# Rank complete (topology, parcel-variant) pairs by the mass that will survive
	# as actual rooms. The macro massif's overhang score includes allocation later
	# discarded by _discard_unassigned_mass(), which is why a nominally 78%-covered
	# source produced the visually open 34% town caught by screenshot review.
	# This proxy uses exact fine route floors and proposed private cells, but no
	# market/landmark/skywalk search or authored resource construction, so weak
	# street canyons are rejected cheaply before the expensive 3D composition.
	var ranked_variants := _ranked_precomposition_variants(frontier,
		construction_program)
	if ranked_variants.is_empty():
		last_failure = "no volumetric parcel variant retained inhabited mass"
		return null
	var failures := PackedStringArray()
	for ranked: Dictionary in ranked_variants:
		var volume := ranked.volume as WarrenVolumePlan
		var variant := int(ranked.variant)
		if diagnostic_trace_room_gate:
			print("SKYWALK_TIMING partition_begin source=", volume.stable_id,
				" variant=", variant, " proxy=", ranked.audit)
		var plan := from_volume(volume, variant, construction_program)
		if plan != null:
			for key: Variant in (ranked.audit as Dictionary).keys():
				plan.audit["precomposition_%s" % String(key)] = ranked.audit[key]
			var fabric := WarrenSpatialFabricCompiler.solve(plan,
				construction_program)
			if fabric == null:
				last_failure = "production fabric gate failed: %s" \
					% WarrenSpatialFabricCompiler.last_failure
			else:
				var quality_failure := production_quality_failure(fabric.audit)
				if quality_failure.is_empty():
					for key: StringName in [&"frontage_ratio",
							&"overhead_route_ratio",
							&"through_sightline_count",
							&"ground_through_sightline_count"]:
						plan.audit[key] = fabric.audit.get(key, 0)
					last_failure = ""
					return plan
				last_failure = quality_failure
		failures.append("%s/v%d: %s" % [String(volume.stable_id),
			variant, last_failure])
	last_failure = "no volumetric partition sealed: %s" % " | ".join(failures)
	return null


static func production_quality_failure(audit: Dictionary) -> String:
	var overhead := float(audit.get("overhead_route_ratio", 0.0))
	var through := int(audit.get("through_sightline_count", 2147483647))
	var ground_through := int(audit.get(
		"ground_through_sightline_count", 2147483647))
	if overhead < MIN_PRODUCTION_OVERHEAD_ROUTE_RATIO:
		return "compiled town overhead ratio %.3f is below %.3f" % [
			overhead, MIN_PRODUCTION_OVERHEAD_ROUTE_RATIO]
	if through > MAX_PRODUCTION_THROUGH_SIGHTLINES:
		return "compiled town has %d through sightlines; maximum is %d" % [
			through, MAX_PRODUCTION_THROUGH_SIGHTLINES]
	if ground_through > MAX_PRODUCTION_GROUND_THROUGH_SIGHTLINES:
		return "compiled town has %d ground through sightlines; maximum is %d" % [
			ground_through, MAX_PRODUCTION_GROUND_THROUGH_SIGHTLINES]
	return ""


static func solve_selected(world_seed: int, selected: WarrenSpatialPlan,
		ground_bands: Dictionary = {},
		construction_program: SettlementFabricProgram = null) -> WarrenSpatialPlan:
	## Rebuild exactly one flat-preview topology against local terrain.  Production
	## placement must not pay for the complete twelve-bore and eight-partition
	## search again for every yaw, nor silently switch to a different maze after
	## the road has already been aligned to the preview entrance.
	last_failure = ""
	if selected == null or not selected.is_sealed() \
			or selected.source_volume == null or construction_program == null:
		last_failure = "selected volumetric preview is missing or unsealed"
		return null
	var attempt := WarrenTownSolver.mass_first_attempt_index(world_seed,
		selected.source_volume)
	if attempt < 0:
		last_failure = "selected preview has no mass-first excavation identity"
		return null
	var candidates := WarrenTownSolver.mass_first_attempt_frontier(world_seed,
		attempt, ground_bands)
	if candidates.is_empty():
		last_failure = WarrenTownSolver.last_failure
		return null
	var source: WarrenVolumePlan
	for candidate: WarrenVolumePlan in candidates:
		if candidate.stable_id == selected.source_volume.stable_id:
			source = candidate
			break
	if source == null:
		last_failure = "selected gallery topology no longer fits local terrain"
		return null
	var partition_variant := int(selected.audit.get("partition_variant", -1))
	if partition_variant < 0 or partition_variant >= MAX_PARTITION_VARIANTS:
		last_failure = "selected preview has no partition identity"
		return null
	var rebuilt := from_volume(source, partition_variant, construction_program)
	if rebuilt == null:
		return null
	if rebuilt.source_volume.entry_cell != selected.source_volume.entry_cell:
		last_failure = "selected terrain rebuild changed its route entrance"
		return null
	return rebuilt


static func _spatial_topology_less(a: WarrenVolumePlan,
		b: WarrenVolumePlan) -> bool:
	var a_walk := int(a.audit.get("walk_cell_count", 2147483647))
	var b_walk := int(b.audit.get("walk_cell_count", 2147483647))
	if a_walk != b_walk:
		return a_walk < b_walk
	var a_interior := int(a.audit.get("exact_route_interior_cell_count",
		2147483647))
	var b_interior := int(b.audit.get("exact_route_interior_cell_count",
		2147483647))
	if a_interior != b_interior:
		return a_interior < b_interior
	return WarrenPublicRealmCarver.topology_score(a) \
		< WarrenPublicRealmCarver.topology_score(b)


static func _ranked_precomposition_variants(
		frontier: Array[WarrenVolumePlan],
		construction_program: SettlementFabricProgram) -> Array[Dictionary]:
	var ranked: Array[Dictionary] = []
	for volume: WarrenVolumePlan in frontier:
		# Partition rotations alter local room choices but not the street network;
		# one canonical projection is sufficient to rank source volumes. Measuring
		# all eight cost almost a minute while returning the same enclosure numbers.
		var audit := _precomposition_enclosure_audit(volume, 0,
			construction_program)
		if audit.is_empty():
			continue
		for variant in MAX_PARTITION_VARIANTS:
			ranked.append({"volume": volume, "variant": variant,
				"audit": audit,
				"score": _precomposition_quality_score(volume, audit)})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_score := float(a.score)
		var b_score := float(b.score)
		if not is_equal_approx(a_score, b_score):
			return a_score > b_score
		var a_volume := a.volume as WarrenVolumePlan
		var b_volume := b.volume as WarrenVolumePlan
		if a_volume.stable_id != b_volume.stable_id:
			return _spatial_topology_less(a_volume, b_volume)
		return int(a.variant) < int(b.variant))
	return ranked


static func _precomposition_enclosure_audit(volume: WarrenVolumePlan,
		partition_variant: int,
		construction_program: SettlementFabricProgram) -> Dictionary:
	var massif := volume.mass_context.get(&"massif") as WarrenMassif
	if massif == null or not massif.is_sealed():
		return {}
	var grid := WarrenSpatialGrid.new(_grid_bounds(massif).minimum,
		_grid_bounds(massif).size)
	if not grid.is_valid() or not _project_massif(grid, massif):
		return {}
	var projected_mass_cell_count := grid.cells_with_use(
		WarrenSpatialGrid.Use.ALLOCATABLE).size()
	var route_floors := _carve_public_volume(grid, volume)
	if route_floors.is_empty():
		return {}
	var parcels := WarrenTownSolver.partition_parcels(volume,
		partition_variant, construction_program)
	if parcels == null:
		return {}
	var occupied: Dictionary = {}
	var proposal_count := 0
	for parcel: WarrenBuildingParcel in parcels.parcels:
		if not _parcel_address_has_public_floor(grid, parcel):
			continue
		var proposal := WarrenParcelConstruction.proposal(parcel)
		if proposal.is_empty():
			continue
		proposal_count += 1
		for cell: Vector3i in StaggeredFabricCompiler \
				.proposal_occupied_cells(proposal):
			occupied[cell] = parcel.stable_id
	if proposal_count < MIN_BUILDINGS or occupied.is_empty():
		return {}
	var route: Dictionary = {}
	var ground_route: Dictionary = {}
	for cell: Vector3i in route_floors:
		route[cell] = true
		var macro_column := Vector2i(floori(float(cell.x) / 2.0),
			floori(float(cell.z) / 2.0))
		if cell.y == volume.envelope.ground_at(macro_column):
			ground_route[cell] = true
	var eligible_sides := 0
	var enclosed_sides := 0
	var overhead_count := 0
	for cell: Vector3i in route_floors:
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.FORWARD, Vector3i.BACK]:
			if route.has(cell + direction):
				continue
			eligible_sides += 1
			enclosed_sides += int(occupied.has(cell + direction) \
				or occupied.has(cell + direction + Vector3i.UP))
		for rise in range(2, 7):
			if occupied.has(cell + Vector3i.UP * rise):
				overhead_count += 1
				break
	var sightline := SettlementFabricSolver._audit_sightlines(route, occupied)
	var ground_sightline := SettlementFabricSolver._audit_sightlines(
		ground_route, occupied)
	return {
		"proposal_count": proposal_count,
		"projected_mass_cell_count": projected_mass_cell_count,
		"occupied_cell_count": occupied.size(),
		"proposed_mass_ratio": float(occupied.size()) \
			/ float(maxi(1, projected_mass_cell_count)),
		"frontage_ratio": float(enclosed_sides) / float(maxi(1, eligible_sides)),
		"overhead_route_ratio": float(overhead_count) \
			/ float(maxi(1, route.size())),
		"through_sightline_count": int(sightline.through_count),
		"ground_through_sightline_count": int(ground_sightline.through_count),
	}


static func _precomposition_quality_score(volume: WarrenVolumePlan,
		audit: Dictionary) -> float:
	# Actual proposed street walls dominate; macro metrics only break ties between
	# similarly dense fine-grid projections.
	return float(audit.overhead_route_ratio) * 1000.0 \
		+ float(audit.frontage_ratio) * 450.0 \
		- float(audit.through_sightline_count) * 3.0 \
		- float(audit.ground_through_sightline_count) * 7.0 \
		+ float(volume.audit.get("all_overhang_walk_ratio", 0.0)) * 80.0 \
		+ float(volume.audit.get("route_crossover_count", 0)) * 60.0


static func from_volume(volume: WarrenVolumePlan,
		partition_variant: int = 0,
		construction_program: SettlementFabricProgram = null) -> WarrenSpatialPlan:
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
		return null
	var projected_mass_cell_count := grid.cells_with_use(
		WarrenSpatialGrid.Use.ALLOCATABLE).size()
	var route_floors := _carve_public_volume(grid, volume)
	if route_floors.is_empty():
		return null
	var parcel_plan := WarrenTownSolver.partition_parcels(volume,
		partition_variant, construction_program)
	if parcel_plan == null:
		last_failure = WarrenTownSolver.last_partition_failure
		return null
	var courtyard_parcel_sides := _parcel_courtyard_address_side_count(grid,
		volume, parcel_plan)
	if courtyard_parcel_sides < MIN_COURT_PARCEL_SIDE_COUNT:
		last_failure = "courtyard partition forms only %d exact room sides" \
			% courtyard_parcel_sides
		return null
	var partition := _partition_rooms(grid, volume, parcel_plan,
		construction_program)
	if partition.is_empty():
		return null
	for cell_value: Variant in (partition.market_reservation.public_cells \
			as Dictionary).keys():
		var market_floor := cell_value as Vector3i
		if not route_floors.has(market_floor):
			route_floors.append(market_floor)
	route_floors.sort_custom(_cell_less)
	var buildings := partition.buildings as Array[WarrenBuildingVolume]
	var supports := partition.supports as WarrenSupportGraph
	if buildings.size() < MIN_BUILDINGS:
		last_failure = "only %d volumetric buildings formed" % buildings.size()
		return null
	var features := WarrenSpatialFeatureSolver.solve(grid, volume, buildings,
		supports, partition.skywalk_reservations as Array[Dictionary],
		partition.courtyard_bridge_reservation as Dictionary,
		partition.market_reservation as Dictionary,
		partition.landmark_reservations as Array[Dictionary],
		construction_program, partition.composition_audit as Dictionary)
	if features.is_empty():
		last_failure = WarrenSpatialFeatureSolver.last_failure
		return null
	var unassigned_mass_cell_count := grid.cells_with_use(
		WarrenSpatialGrid.Use.ALLOCATABLE).size()
	var retained_private_cell_count := grid.cells_with_use(
		WarrenSpatialGrid.Use.PRIVATE_VOLUME).size()
	if not _discard_unassigned_mass(grid) or not _derive_shell(grid, buildings):
		return null
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
	plan.audit["projected_mass_cell_count"] = projected_mass_cell_count
	plan.audit["unassigned_mass_cell_count"] = unassigned_mass_cell_count
	plan.audit["retained_private_mass_cell_count"] = retained_private_cell_count
	plan.audit["retained_private_mass_ratio"] = \
		float(retained_private_cell_count) \
		/ float(maxi(1, projected_mass_cell_count))
	plan.audit["partition_variant"] = partition_variant
	plan.audit["room_stamp_count"] = int(partition.room_count)
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
	# A spatial topology is not production-valid until the authored construction
	# shells for its final recomposed rooms clear every unrelated hero feature.
	# This exact, bounded gate runs once per complete partition survivor.  It lets
	# the existing topology/partition frontier advance past a courtyard placement
	# whose measured eaves collide, without inflating every 3D search cell with a
	# conservative halo or teaching the renderer to forgive the intersection.
	var room_units := WarrenSpatialFabricCompiler.compile_room_units(plan,
		construction_program)
	if room_units.is_empty():
		last_failure = "authored room envelope gate failed: %s" \
			% WarrenSpatialFabricCompiler.last_failure
		if diagnostic_trace_room_gate:
			print("SKYWALK_TIMING authored_room_gate source=",
				volume.stable_id, " variant=", partition_variant, " failure=",
				last_failure)
		return null
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


static func _carve_public_volume(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan) -> Array[Vector3i]:
	var air: Dictionary = {}
	for macro_cell: Vector3i in volume.public_air_cells:
		for fine_cell: Vector3i in _fine_square(macro_cell):
			air[fine_cell] = true
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


static func _partition_rooms(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan, parcels: WarrenParcelPlan,
		construction_program: SettlementFabricProgram) -> Dictionary:
	var proposals: Array[Dictionary] = []
	var rejected_unfloored_addresses := 0
	for parcel: WarrenBuildingParcel in parcels.parcels:
		var proposal := WarrenParcelConstruction.proposal(parcel)
		if proposal.is_empty():
			continue
		# Mass-first frontage includes intermediate stair/ramp macro cells. Only
		# two fine lanes inside such a square carry the actual transition surface;
		# a door aimed at either unused half opens into swept public air with no
		# floor. Reject that parcel before it can reserve hero features or enter the
		# room composition, and keep the same fact as a final room/building seal.
		if not _parcel_address_has_public_floor(grid, parcel):
			rejected_unfloored_addresses += 1
			continue
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
	# The covered bazaar is town topology, not a late prop pass. Select and
	# reserve its exact canopy/posts, under-canopy public aisle, measured visual
	# envelope, and backing-room socket before generic composition blocks move.
	var market_plan := _preplan_spatial_market(grid, volume, proposals,
		construction_program, protected_owners)
	var market_candidates: Array[Dictionary] = []
	market_candidates.assign(market_plan.get("candidates", []) as Array)
	if market_candidates.is_empty():
		last_failure = "no topology-first covered market fits the connected ground street"
		return {}
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
	var feature_set_attempts: Array[Dictionary] = []
	var realm := WarrenVolumePublicRealmAdapter.from_volume(volume)
	if realm == null:
		last_failure = "could not recover exact public air for joint hero features"
		return {}
	var public_air := realm.air_claims()
	var market_attempt_count := 0
	var selected_court_alternatives: Array[Dictionary] = []
	var selected_market_landmark_owners: Dictionary = {}
	for candidate: Dictionary in market_candidates:
		if diagnostic_feature_market_limit >= 0 \
				and market_attempt_count >= diagnostic_feature_market_limit:
			break
		market_attempt_count += 1
		var market_attempt_started := Time.get_ticks_msec()
		if diagnostic_trace_skywalk_timing:
			print("SKYWALK_TIMING market_begin parcel=",
				candidate.backing_parcel_id)
		var market_owners := _protected_owners_with_market(protected_owners,
			candidate)
		var raw_court_candidates := _courtyard_cantilever_room_candidates(grid,
			volume, proposals, construction_program, market_owners, public_air)
		if raw_court_candidates.is_empty():
			feature_set_attempts.append({
				"market_parcel": candidate.backing_parcel_id,
				"market_origin": candidate.origin, "landmark_count": 0,
				"landmark_recipes": [] as Array[StringName],
				"courtyard_bridge_count": 0,
				"skywalk_count": 0, "skywalk_candidate_count": 0})
			continue
		var court_candidate_limit := 1 if diagnostic_stop_after_skywalk_candidates \
			or diagnostic_stop_after_skywalk_individual \
			else raw_court_candidates.size()
		for court_candidate_index in court_candidate_limit:
			var raw_court_candidate := raw_court_candidates[court_candidate_index]
			var court_candidate := raw_court_candidate.duplicate(true)
			var court_reservation := (raw_court_candidate.reservation \
				as Dictionary).duplicate(true)
			court_reservation["feature_id"] = COURTYARD_BRIDGE_FEATURE_ID
			court_candidate["reservation"] = court_reservation
			var court_owners := _protected_owners_with_courtyard_bridge(
				market_owners, court_candidate)
			var baseline_skywalk_plan := _preplan_spatial_skywalks(grid, volume,
				proposals, construction_program, court_owners,
				WarrenSpatialFeatureSolver.TARGET_SKYWALKS,
				raw_court_candidates.size())
			var skywalk_corpus: Array[Dictionary] = []
			skywalk_corpus.assign(baseline_skywalk_plan.get("candidate_corpus", []) \
				as Array)
			if diagnostic_trace_skywalk_timing:
				print("SKYWALK_TIMING market_baseline ms=",
					Time.get_ticks_msec() - market_attempt_started, " corpus=",
					skywalk_corpus.size())
			if skywalk_corpus.is_empty():
				feature_set_attempts.append({
					"market_parcel": candidate.backing_parcel_id,
					"market_origin": candidate.origin,
					"courtyard_bridge_count": 1,
					"landmark_count": 0,
					"landmark_recipes": [] as Array[StringName],
					"skywalk_count": 0, "skywalk_candidate_count": 0})
				continue
			var landmark_plan := _preplan_spatial_landmarks(grid, volume,
				construction_program, court_owners, candidate,
				[] as Array[Dictionary])
			var landmark_candidates: Array[Dictionary] = []
			landmark_candidates.assign(landmark_plan.get("candidates", []) as Array)
			var landmark_sets := _landmark_candidate_sets(landmark_candidates,
				volume.world_seed)
			_rank_landmark_sets_for_skywalks(landmark_sets, skywalk_corpus)
			for set_index in mini(MAX_LANDMARK_SET_ATTEMPTS,
					landmark_sets.size()):
				var landmark_attempt_started := Time.get_ticks_msec()
				var landmark_set := (landmark_sets[set_index] as Dictionary) \
					.get("reservations", []) as Array[Dictionary]
				var trial_owners := _protected_owners_with_landmarks(court_owners,
					landmark_set)
				var trial_skywalk_plan := _skywalk_plan_for_landmarks(grid, volume,
					proposals, trial_owners, skywalk_corpus, landmark_set,
					construction_program, public_air)
				var trial_skywalks: Array[Dictionary] = []
				trial_skywalks.assign(trial_skywalk_plan.get("reservations", []) \
					as Array)
				if diagnostic_trace_skywalk_timing:
					print("SKYWALK_TIMING landmark_set index=", set_index,
						" ms=", Time.get_ticks_msec() - landmark_attempt_started,
						" candidates=", trial_skywalk_plan.get(
							"candidate_count", 0),
						" selected=", trial_skywalks.size())
				feature_set_attempts.append({
					"market_parcel": candidate.backing_parcel_id,
					"market_origin": candidate.origin,
					"courtyard_bridge_count": 1,
					"courtyard_bridge_origin": court_reservation.origin,
					"landmark_count": landmark_set.size(),
					"landmark_recipes": _landmark_recipe_ids(landmark_set),
					"skywalk_count": trial_skywalks.size(),
					"skywalk_candidate_count": int((landmark_sets[set_index] \
						as Dictionary).get("skywalk_candidate_count", 0)),
					"exact_skywalk_candidate_count": int(trial_skywalk_plan.get(
						"candidate_count", 0)),
					"skywalk_pair_frontier_count": int(trial_skywalk_plan.get(
						"pair_frontier_count", 0))})
				if landmark_set.size() \
						< WarrenSpatialFeatureSolver.TARGET_PREFAB_LANDMARKS \
						or trial_skywalks.size() \
							< WarrenSpatialFeatureSolver.TARGET_SKYWALKS:
					continue
				market_reservation = candidate
				courtyard_bridge_candidate = court_candidate
				courtyard_bridge_reservation = court_reservation
				landmark_reservations.assign(landmark_set)
				skywalk_plan = trial_skywalk_plan
				selected_court_alternatives.assign(raw_court_candidates)
				selected_market_landmark_owners = \
					_protected_owners_with_landmarks(market_owners,
						landmark_set)
				break
			if not market_reservation.is_empty():
				break
		if not market_reservation.is_empty():
			break
	var skywalk_reservations: Array[Dictionary] = []
	skywalk_reservations.assign(skywalk_plan.get("reservations", []) as Array)
	var maximum_joint_skywalk_count := 0
	var maximum_exact_skywalk_candidate_count := 0
	var maximum_skywalk_pair_frontier_count := 0
	for attempt: Dictionary in feature_set_attempts:
		maximum_joint_skywalk_count = maxi(maximum_joint_skywalk_count,
			int(attempt.skywalk_count))
		maximum_exact_skywalk_candidate_count = maxi(
			maximum_exact_skywalk_candidate_count,
			int(attempt.get("exact_skywalk_candidate_count", 0)))
		maximum_skywalk_pair_frontier_count = maxi(
			maximum_skywalk_pair_frontier_count,
			int(attempt.get("skywalk_pair_frontier_count", 0)))
	last_preplan_market_diagnostic["feature_set_attempts"] = feature_set_attempts
	last_preplan_landmark_diagnostic["joint_attempt_count"] = \
		feature_set_attempts.size()
	last_preplan_landmark_diagnostic["maximum_joint_skywalk_count"] = \
		maximum_joint_skywalk_count
	last_preplan_landmark_diagnostic["maximum_exact_skywalk_candidate_count"] = \
		maximum_exact_skywalk_candidate_count
	last_preplan_landmark_diagnostic["maximum_skywalk_pair_frontier_count"] = \
		maximum_skywalk_pair_frontier_count
	if market_reservation.is_empty() or courtyard_bridge_reservation.is_empty() \
			or landmark_reservations.size() \
				< WarrenSpatialFeatureSolver.TARGET_PREFAB_LANDMARKS \
			or skywalk_reservations.size() \
				< WarrenSpatialFeatureSolver.TARGET_SKYWALKS:
		last_failure = "joint hero-feature beam found court=%d, %d landmarks, and %d skywalks (%s; %s)" \
			% [int(not courtyard_bridge_reservation.is_empty()),
				landmark_reservations.size(), skywalk_reservations.size(),
				last_preplan_landmark_diagnostic,
				last_preplan_skywalk_diagnostic]
		return {}
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
		var exact_fit := _court_candidate_preserves_exact_room_envelopes(
			grid, volume, proposals, construction_program, market_reservation,
			alternative, selected_market_landmark_owners,
			court_fixed_blocks_by_parcel, skywalk_plan)
		if diagnostic_trace_skywalk_timing:
			print("SKYWALK_TIMING final_court_envelope attempt=",
				exact_court_attempt_count, " fit=", exact_fit, " ms=",
				Time.get_ticks_msec() - exact_started)
		if not exact_fit:
			exact_court_rejection_count += 1
			continue
		courtyard_bridge_candidate = alternative
		courtyard_bridge_reservation = alternative_reservation
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
	if not _reserve_market_preplan(grid, market_reservation):
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
		"parcel": market_reservation.backing_parcel_id,
		"origin": market_reservation.origin,
		"yaw": market_reservation.yaw_quarters,
		"recipe": market_reservation.recipe_id}
	var market_feature_id := StringName(market_reservation.feature_id)
	# Selected hero-feature endpoint blocks outrank generic room proposals. Make
	# that priority explicit in the provisional-owner field so every displaced
	# parcel either finds another legal block offset or drops transactionally.
	for cell_value: Variant in (skywalk_plan.priority_cells as Dictionary).keys():
		protected_owners[cell_value] = {
			StringName((skywalk_plan.priority_cells as Dictionary)[cell_value]): true,
		}
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
	var solved_offsets_by_parcel: Dictionary = {}
	var exact_forced_offsets_by_parcel: Dictionary = {}
	var court_displaced_parcels: Dictionary = {}
	for parcel_value: Variant in courtyard_bridge_candidate.get(
			"excluded_parcel_ids", []):
		court_displaced_parcels[StringName(parcel_value)] = true
	for proposal: Dictionary in proposals:
		var parcel := proposal.parcel as WarrenBuildingParcel
		if court_displaced_parcels.has(parcel.stable_id):
			continue
		var storeys := int(proposal.storeys)
		var origin := proposal.origin as Vector3i
		var base_plate := _proposal_base_plate(proposal)
		if storeys <= 0 or base_plate.is_empty():
			continue
		var threshold := WarrenParcelConstruction.threshold_cell(parcel)
		var addressed_storey := clampi(floori(float(threshold.y - origin.y) \
			/ float(WarrenSpatialGrid.STOREY_CELLS)), 0, storeys - 1)
		var forced_offsets: Dictionary = {0: Vector2i.ZERO,
			floori(float(addressed_storey) / 2.0): Vector2i.ZERO}
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
			continue
		var offsets := _composition_offsets(grid, base_plate, origin.y,
			storeys, protected_owners, parcel.stable_id, volume.world_seed,
			forced_offsets)
		if offsets.is_empty():
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
	var composition := WarrenRoomCompositionPlanner.solve(grid, volume,
		proposals, solved_offsets_by_parcel, exact_forced_offsets_by_parcel,
		market_reservation, protected_owners, forced_offsets_by_parcel,
		skywalk_reservations, volume.world_seed)
	if composition.is_empty():
		last_failure = "3D room composition failed: %s" \
			% WarrenRoomCompositionPlanner.last_failure
		return {}
	var composed_court_side_mask := _composition_courtyard_side_mask(
		court_floors, composition, courtyard_bridge_candidate.body as Dictionary)
	var composed_court_side_count := _side_mask_count(composed_court_side_mask)
	if composed_court_side_count \
			< WarrenSpatialFeatureSolver.MIN_COURT_SIDE_COUNT:
		last_failure = ("3D room composition preserves only %d courtyard " \
			+ "sides (mask=%d)") % [composed_court_side_count,
				composed_court_side_mask]
		return {}
	var composition_audit := composition.audit as Dictionary
	composition_audit["court_displaced_parcel_count"] = \
		court_displaced_parcels.size()
	composition_audit["composed_courtyard_side_mask"] = \
		composed_court_side_mask
	composition_audit["composed_courtyard_side_count"] = \
		composed_court_side_count
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
		for segment_index in blocks.size():
			var block := blocks[segment_index] as Dictionary
			if threshold.y >= origin.y + int(block.start_storey) \
					* WarrenSpatialGrid.STOREY_CELLS \
					and threshold.y < origin.y + int(block.end_storey) \
						* WarrenSpatialGrid.STOREY_CELLS:
				threshold_segment = segment_index
				break
		if threshold_segment < 0:
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
				var addressed := threshold.y >= origin.y \
					+ storey * WarrenSpatialGrid.STOREY_CELLS \
					and threshold.y < origin.y \
						+ (storey + 1) * WarrenSpatialGrid.STOREY_CELLS
				var support_parent_parcel_id := &""
				var support_parent_storey_index := -1
				if storey == int(block.start_storey) \
						and block.has("support_parent_lineage_id"):
					support_parent_parcel_id = StringName(
						block.support_parent_lineage_id)
					support_parent_storey_index = int(
						block.support_parent_source_storey)
				var room := WarrenRoomStamp.new(
					StringName("%s.room%02d" % [building_id,
						storey - int(block.start_storey)]), parcel.stable_id,
					StringName(block.kind), room_origin,
					int(block.yaw_quarters), storey,
					storey == 0 and not block.has(
						"support_parent_lineage_id"),
					addressed, threshold if addressed else Vector3i(2147483647,
						2147483647, 2147483647),
					Vector3i(parcel.frontage_direction.x, 0,
						parcel.frontage_direction.y), int(proposal.roof_feature),
					support_parent_parcel_id, support_parent_storey_index,
					parcel.address_door_phase if addressed else 0)
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
			else:
				var access_index := clampi(threshold_segment, 0,
					segment_ids.size() - 1)
				if not building.add_private_parent(segment_ids[access_index]):
					last_failure = "could not attach private segment %s" % building_id
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
			if StringName(market_reservation.backing_parcel_id) == parcel.stable_id \
					and building.has_private_cell(
						market_reservation.backing_cell as Vector3i):
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
	var backfill := _backfill_residual_rooms(grid, volume, buildings, supports,
		required_supports, terrain_support_ids, support_edges, protected_owners)
	if bool(backfill.get("failed", false)):
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
	return {"buildings": buildings, "supports": supports,
		"room_count": room_count, "offset_blocks": offset_blocks,
		"handoffs": handoffs,
		"composition_audit": composition_audit,
		"rejected_unfloored_address_count": rejected_unfloored_addresses,
		"preplanned_skywalk_count": skywalk_reservations.size(),
		"skywalk_reservations": skywalk_reservations,
		"courtyard_bridge_reservation": courtyard_bridge_reservation,
		"landmark_reservations": landmark_reservations,
		"market_reservation": market_reservation}


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


static func _preplan_spatial_landmarks(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan, program: SettlementFabricProgram,
		protected_owners: Dictionary, market_reservation: Dictionary,
		skywalk_reservations: Array[Dictionary]) -> Dictionary:
	var required_parcels: Dictionary = {
		StringName(market_reservation.get("backing_parcel_id", &"")): true,
	}
	for reservation: Dictionary in skywalk_reservations:
		for parcel_value: Variant in reservation.get("owner_parcel_ids", []):
			required_parcels[StringName(parcel_value)] = true
	required_parcels.erase(&"")
	var prefab_recipes: Array[FabricRecipe] = []
	for recipe: FabricRecipe in program.recipes():
		if recipe.has_tag(&"prefab_anchor") and not recipe.entrances.is_empty() \
				and maxf(recipe.local_clearance_bounds.size.x,
					recipe.local_clearance_bounds.size.z) <= 21.0:
			prefab_recipes.append(recipe)
	var prefab_stamps: Dictionary = {}
	for recipe: FabricRecipe in prefab_recipes:
		for yaw in 4:
			var local_body: Dictionary = {}
			for cells: Array[Vector3i] in [recipe.solid_cells,
					recipe.headroom_cells, recipe.walk_cells]:
				for local_cell: Vector3i in cells:
					local_body[FabricRecipe.transform_cell(local_cell,
						Vector3i.ZERO, yaw)] = true
			var local_bearing: Dictionary = {}
			for local_cell: Vector3i in recipe.terrain_bearing_cells:
				local_bearing[FabricRecipe.transform_cell(local_cell,
					Vector3i.ZERO, yaw)] = true
			var components: Array[Dictionary] = [{"recipe_id": recipe.recipe_id,
				"origin": Vector3i.ZERO, "yaw_quarters": yaw}]
			prefab_stamps["%s/r%d" % [recipe.recipe_id, yaw]] = {
				"body": local_body, "bearing": local_bearing,
				"clearance": _skywalk_visual_clearance_cells(components,
					program),
			}
	var candidates: Array[Dictionary] = []
	var landing_count := 0
	var body_fit_count := 0
	var bearing_fit_count := 0
	var clearance_fit_count := 0
	var mandatory_rejection_count := 0
	var seen: Dictionary = {}
	for landing: Vector3i in grid.cells_with_use(
			WarrenSpatialGrid.Use.PUBLIC_AIR):
		var floor_claim := grid.face_claim(landing, Vector3i.DOWN)
		if landing.y > 1 or floor_claim.is_empty() \
				or int(floor_claim.kind) != WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR:
			continue
		landing_count += 1
		for side: Vector3i in WarrenSpatialFeatureSolver.SKY_DIRECTIONS:
			if grid.use_at(landing + side) not in [WarrenSpatialGrid.Use.OUTSIDE,
					WarrenSpatialGrid.Use.ALLOCATABLE]:
				continue
			for recipe: FabricRecipe in prefab_recipes:
				var entrance := recipe.entrances[0] as Dictionary
				var yaw := _yaw_for_direction(entrance.facing as Vector3i, -side)
				if yaw < 0:
					continue
				var origin := landing + side - FabricRecipe.transform_cell(
					entrance.cell as Vector3i, Vector3i.ZERO, yaw)
				var key := "%s@%s/r%d" % [recipe.recipe_id, origin, yaw]
				if seen.has(key):
					continue
				seen[key] = true
				var stamp := prefab_stamps["%s/r%d" % [recipe.recipe_id, yaw]] \
					as Dictionary
				var body := _translated_cell_set(stamp.body as Dictionary, origin)
				if body.is_empty() or not _skywalk_body_fits_grid(grid, body):
					continue
				body_fit_count += 1
				var bearing := _translated_cell_set(stamp.bearing as Dictionary,
					origin)
				if bearing.is_empty() or not _landmark_bearing_follows_terrain(
						bearing, volume):
					continue
				bearing_fit_count += 1
				var clearance := _translated_cell_set(stamp.clearance as Dictionary,
					origin)
				var protected_cells := clearance.duplicate()
				protected_cells.merge(body, true)
				protected_cells.merge(bearing, true)
				if clearance.is_empty() or not _cells_fit_grid(grid, clearance) \
						or not _skywalk_clearance_fits_grid(grid, clearance) \
						or not _skywalk_clearance_fits_protected(protected_cells,
							protected_owners):
					continue
				clearance_fit_count += 1
				var blockers: Dictionary = {}
				var mandatory_hit := false
				for cell_value: Variant in protected_cells.keys():
					for owner_value: Variant in (protected_owners.get(cell_value, {}) \
							as Dictionary).keys():
						var owner_id := StringName(owner_value)
						if required_parcels.has(owner_id) \
								or _protected_owner_is_feature(owner_id):
							mandatory_hit = true
						else:
							blockers[owner_id] = true
				if mandatory_hit:
					mandatory_rejection_count += 1
					continue
				var assets := recipe.asset_ids()
				var source_family := &"unknown" if assets.is_empty() else \
					StringName(String(assets[0]).get_slice(".", 0))
				candidates.append({"recipe_id": recipe.recipe_id,
					"source_family": source_family, "origin": origin,
					"yaw_quarters": yaw, "landing_cell": landing,
					"entrance_cell": landing + side,
					"entrance_facing": -side,
					"body": body, "bearing_cells": bearing,
					"clearance": clearance, "protected_cells": protected_cells,
					"blocker_parcels": blockers,
					"blocker_count": blockers.size(),
					"height_cell_count": ceili(
						recipe.local_clearance_bounds.size.y \
							/ FabricRecipe.CELL_SIZE),
					"footprint_area": recipe.local_clearance_bounds.size.x \
						* recipe.local_clearance_bounds.size.z,
					"tie": posmod(Helper._mix64(volume.world_seed \
						^ String(recipe.recipe_id).hash() ^ origin.x * 31 \
						^ origin.z * 47 ^ yaw * 131), 1000003)})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.blocker_count) != int(b.blocker_count):
			return int(a.blocker_count) > int(b.blocker_count)
		if not is_equal_approx(float(a.footprint_area), float(b.footprint_area)):
			return float(a.footprint_area) > float(b.footprint_area)
		return int(a.tie) < int(b.tie))
	var candidate_preview: Array[Dictionary] = []
	for candidate_index in mini(8, candidates.size()):
		var candidate := candidates[candidate_index]
		var blocker_ids: Array[StringName] = []
		blocker_ids.assign((candidate.blocker_parcels as Dictionary).keys())
		blocker_ids.sort_custom(func(a: StringName, b: StringName) -> bool:
			return String(a) < String(b))
		candidate_preview.append({"recipe_id": candidate.recipe_id,
			"source_family": candidate.source_family,
			"origin": candidate.origin,
			"yaw_quarters": candidate.yaw_quarters,
			"landing_cell": candidate.landing_cell,
			"entrance_cell": candidate.entrance_cell,
			"body_cell_count": (candidate.body as Dictionary).size(),
			"clearance_cell_count": (candidate.clearance as Dictionary).size(),
			"blocker_count": candidate.blocker_count,
			"blocker_parcels": blocker_ids,
			"footprint_area": candidate.footprint_area})
	last_preplan_landmark_diagnostic = {"landing_count": landing_count,
		"prefab_recipe_count": prefab_recipes.size(),
		"body_fit_count": body_fit_count,
		"bearing_fit_count": bearing_fit_count,
		"clearance_fit_count": clearance_fit_count,
		"mandatory_rejection_count": mandatory_rejection_count,
		"candidate_count": candidates.size(),
		"candidate_preview": candidate_preview}
	return {"candidates": candidates}


static func _translated_cell_set(local_cells: Dictionary,
		origin: Vector3i) -> Dictionary:
	var out: Dictionary = {}
	for value: Variant in local_cells.keys():
		out[(value as Vector3i) + origin] = true
	return out


static func _landmark_candidate_sets(candidates: Array[Dictionary],
		world_seed: int) -> Array[Dictionary]:
	## Two genuinely separate, measured prefabs are the minimum massing
	## intervention. Pair selection happens before the skywalk beam so the latter
	## routes around these buildings instead of consuming every viable anchor.
	var out: Array[Dictionary] = []
	for left_index in candidates.size():
		for right_index in range(left_index + 1, candidates.size()):
			var left := candidates[left_index]
			var right := candidates[right_index]
			if not _landmark_candidates_compatible(left, right):
				continue
			var first := left.duplicate(true)
			var second := right.duplicate(true)
			first["feature_id"] = &"spatial.feature.landmark.00"
			second["feature_id"] = &"spatial.feature.landmark.01"
			var blocker_union := (left.blocker_parcels as Dictionary).duplicate()
			blocker_union.merge(right.blocker_parcels as Dictionary, true)
			var protected_union := (left.protected_cells as Dictionary).duplicate()
			protected_union.merge(right.protected_cells as Dictionary, true)
			var left_landing := left.landing_cell as Vector3i
			var right_landing := right.landing_cell as Vector3i
			var separation := Vector2i(left_landing.x - right_landing.x,
				left_landing.z - right_landing.z).length_squared()
			var distinct_family: bool = left.source_family != right.source_family
			out.append({"reservations": [first, second] \
				as Array[Dictionary], "distinct_source_families": distinct_family,
				"displaced_parcel_count": blocker_union.size(),
				"protected_cell_count": protected_union.size(),
				"separation_squared": separation,
				"footprint_area": float(left.footprint_area) \
					+ float(right.footprint_area),
				"tie": posmod(Helper._mix64(world_seed \
					^ String(left.recipe_id).hash() \
					^ String(right.recipe_id).hash() \
					^ left_landing.x * 31 ^ left_landing.z * 47 \
					^ right_landing.x * 73 ^ right_landing.z * 89), 1000003)})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.displaced_parcel_count) != int(b.displaced_parcel_count):
			return int(a.displaced_parcel_count) < int(b.displaced_parcel_count)
		if int(a.protected_cell_count) != int(b.protected_cell_count):
			return int(a.protected_cell_count) < int(b.protected_cell_count)
		if int(a.separation_squared) != int(b.separation_squared):
			return int(a.separation_squared) > int(b.separation_squared)
		if bool(a.distinct_source_families) != bool(b.distinct_source_families):
			return bool(a.distinct_source_families)
		if not is_equal_approx(float(a.footprint_area), float(b.footprint_area)):
			return float(a.footprint_area) > float(b.footprint_area)
		return int(a.tie) < int(b.tie))
	last_preplan_landmark_diagnostic["compatible_pair_count"] = out.size()
	var pair_preview: Array[Dictionary] = []
	for pair_index in mini(8, out.size()):
		var pair := out[pair_index]
		var reservations := pair.reservations as Array[Dictionary]
		pair_preview.append({"recipe_ids": _landmark_recipe_ids(reservations),
			"landing_cells": [reservations[0].landing_cell,
				reservations[1].landing_cell],
			"distinct_source_families": pair.distinct_source_families,
			"displaced_parcel_count": pair.displaced_parcel_count,
			"protected_cell_count": pair.protected_cell_count,
			"separation_squared": pair.separation_squared,
			"footprint_area": pair.footprint_area})
	last_preplan_landmark_diagnostic["pair_preview"] = pair_preview
	return out


static func _rank_landmark_sets_for_skywalks(sets: Array[Dictionary],
		skywalk_corpus: Array[Dictionary]) -> void:
	for landmark_set: Dictionary in sets:
		var protected := _landmark_set_protected_cells(
			landmark_set.reservations as Array[Dictionary])
		var blocked_parcels := _landmark_set_blocker_parcels(
			landmark_set.reservations as Array[Dictionary])
		var candidate_count := 0
		var pair_keys: Dictionary = {}
		for skywalk: Dictionary in skywalk_corpus:
			if not _skywalk_candidate_avoids_landmarks(skywalk, protected,
					blocked_parcels):
				continue
			candidate_count += 1
			pair_keys[String(skywalk.pair_key)] = true
		landmark_set["skywalk_candidate_count"] = candidate_count
		landmark_set["skywalk_pair_count"] = pair_keys.size()
	sets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		# Three links are the contract; surplus candidate count is not worth
		# demolishing a street block around a landmark. First keep sets with a
		# viable bridge frontier, then preserve the most inhabited frontage.
		var a_viable := int(a.skywalk_pair_count) \
			>= WarrenSpatialFeatureSolver.TARGET_SKYWALKS \
			and int(a.skywalk_candidate_count) \
				>= WarrenSpatialFeatureSolver.TARGET_SKYWALKS
		var b_viable := int(b.skywalk_pair_count) \
			>= WarrenSpatialFeatureSolver.TARGET_SKYWALKS \
			and int(b.skywalk_candidate_count) \
				>= WarrenSpatialFeatureSolver.TARGET_SKYWALKS
		if a_viable != b_viable:
			return a_viable
		if int(a.displaced_parcel_count) != int(b.displaced_parcel_count):
			return int(a.displaced_parcel_count) < int(b.displaced_parcel_count)
		if int(a.protected_cell_count) != int(b.protected_cell_count):
			return int(a.protected_cell_count) < int(b.protected_cell_count)
		if int(a.skywalk_pair_count) != int(b.skywalk_pair_count):
			return int(a.skywalk_pair_count) > int(b.skywalk_pair_count)
		if int(a.skywalk_candidate_count) != int(b.skywalk_candidate_count):
			return int(a.skywalk_candidate_count) > int(b.skywalk_candidate_count)
		if int(a.separation_squared) != int(b.separation_squared):
			return int(a.separation_squared) > int(b.separation_squared)
		if bool(a.distinct_source_families) != bool(b.distinct_source_families):
			return bool(a.distinct_source_families)
		return int(a.tie) < int(b.tie))
	var preview: Array[Dictionary] = []
	for index in mini(8, sets.size()):
		var pair := sets[index]
		var reservations := pair.reservations as Array[Dictionary]
		preview.append({"recipe_ids": _landmark_recipe_ids(reservations),
			"landing_cells": [reservations[0].landing_cell,
				reservations[1].landing_cell],
			"skywalk_candidate_count": pair.skywalk_candidate_count,
			"skywalk_pair_count": pair.skywalk_pair_count,
			"displaced_parcel_count": pair.displaced_parcel_count,
			"protected_cell_count": pair.protected_cell_count})
	last_preplan_landmark_diagnostic["joint_pair_preview"] = preview


static func _landmark_set_protected_cells(
		landmarks: Array[Dictionary]) -> Dictionary:
	var out: Dictionary = {}
	for landmark: Dictionary in landmarks:
		out.merge(landmark.protected_cells as Dictionary, true)
	return out


static func _landmark_set_blocker_parcels(
		landmarks: Array[Dictionary]) -> Dictionary:
	var out: Dictionary = {}
	for landmark: Dictionary in landmarks:
		out.merge(landmark.blocker_parcels as Dictionary, true)
	return out


static func _skywalk_candidate_avoids_landmarks(candidate: Dictionary,
		protected: Dictionary, blocked_parcels: Dictionary = {}) -> bool:
	for owner_value: Variant in (candidate.reservation as Dictionary).get(
			"owner_parcel_ids", []):
		if blocked_parcels.has(StringName(owner_value)):
			return false
	for field: StringName in [&"clearance", &"body", &"priority_cells"]:
		for cell_value: Variant in (candidate.get(field, {}) as Dictionary).keys():
			if protected.has(cell_value):
				return false
	return true


static func _skywalk_plan_for_landmarks(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan, proposals: Array[Dictionary],
		protected_owners: Dictionary,
		candidate_corpus: Array[Dictionary],
		landmarks: Array[Dictionary], program: SettlementFabricProgram,
		public_air: Dictionary) -> Dictionary:
	var stage_started := Time.get_ticks_msec()
	var landmark_cells: Dictionary = {}
	for cell_value: Variant in protected_owners.keys():
		for owner_value: Variant in (protected_owners[cell_value] \
				as Dictionary).keys():
			if String(owner_value).begins_with("spatial.feature.landmark."):
				landmark_cells[cell_value] = true
				break
	var blocked_parcels := _landmark_set_blocker_parcels(landmarks)
	# A complete triple must contain at least one landmark endpoint. Generate that
	# scarce topology first; when neither the baseline corpus nor this landmark
	# set supplies one, no amount of ordinary pair/triple recomposition can pass.
	var landmark_attached := _landmark_attached_skywalk_candidates(grid,
		volume, proposals, landmarks, program, protected_owners, public_air)
	var existing_landmark_endpoint_count := 0
	for candidate: Dictionary in candidate_corpus:
		existing_landmark_endpoint_count += int(candidate.get(
			"landmark_endpoint_count", 0))
	if diagnostic_trace_skywalk_timing:
		print("SKYWALK_TIMING landmark_attached_initial ms=",
			Time.get_ticks_msec() - stage_started, " attached=",
			landmark_attached.size())
	if landmark_attached.is_empty() and existing_landmark_endpoint_count == 0:
		last_preplan_skywalk_diagnostic["landmark_filtered_candidate_count"] = 0
		last_preplan_skywalk_diagnostic["landmark_attached_candidate_count"] = 0
		last_preplan_skywalk_diagnostic["landmark_joint_selected_count"] = 0
		last_preplan_skywalk_diagnostic["composition_ranked_combination_count"] = 0
		last_preplan_skywalk_diagnostic["ranked_triple_count"] = 0
		last_preplan_skywalk_diagnostic["composition_trial_count"] = 0
		return _skywalk_plan_from_selected([] as Array[Dictionary], 0)
	var candidates: Array[Dictionary] = []
	for candidate: Dictionary in candidate_corpus:
		if not _skywalk_candidate_avoids_landmarks(candidate, landmark_cells,
				blocked_parcels) \
				or not _skywalk_selection_preserves_endpoint_rooms(grid, volume,
					[candidate] as Array[Dictionary], proposals, protected_owners,
					volume.world_seed):
			continue
		candidates.append(candidate)
	if diagnostic_trace_skywalk_timing:
		print("SKYWALK_TIMING landmark_individual ms=",
			Time.get_ticks_msec() - stage_started, " candidates=",
			candidates.size())
	for candidate: Dictionary in landmark_attached:
		if not _skywalk_selection_preserves_endpoint_rooms(grid, volume,
				[candidate] as Array[Dictionary], proposals, protected_owners,
				volume.world_seed):
			continue
		candidates.append(candidate)
	if diagnostic_trace_skywalk_timing:
		print("SKYWALK_TIMING landmark_attached ms=",
			Time.get_ticks_msec() - stage_started, " attached=",
			landmark_attached.size())
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("landmark_endpoint_count", 0)) \
				!= int(b.get("landmark_endpoint_count", 0)):
			return int(a.get("landmark_endpoint_count", 0)) \
				> int(b.get("landmark_endpoint_count", 0))
		if int(a.blocker_count) != int(b.blocker_count):
			return int(a.blocker_count) < int(b.blocker_count)
		if int(a.lower_cover) != int(b.lower_cover):
			return int(a.lower_cover) > int(b.lower_cover)
		return int(a.tie) < int(b.tie))
	var selected: Array[Dictionary] = []
	var selected_tower_risk := 2147483647
	var selected_quality := 2147483647
	var composition_ranked_combination_count := 0
	var composition_trial_count := 0
	var primary_frontier_size := mini(candidates.size(), 64)
	var pair_frontier: Array[Vector2i] = []
	var stop_pairs := false
	for first in primary_frontier_size:
		var accepted_for_first := 0
		for second in candidates.size():
			if second == first or not _skywalk_candidates_compatible(
					candidates[first], candidates[second]):
				continue
			var pair := [candidates[first], candidates[second]] \
				as Array[Dictionary]
			if not _skywalk_selection_preserves_endpoint_rooms(grid, volume,
					pair, proposals, protected_owners, volume.world_seed):
				continue
			pair_frontier.append(Vector2i(first, second))
			accepted_for_first += 1
			if pair_frontier.size() >= 128:
				stop_pairs = true
				break
			if accepted_for_first >= 4:
				break
		if stop_pairs:
			break
	if diagnostic_trace_skywalk_timing:
		print("SKYWALK_TIMING landmark_pairs ms=",
			Time.get_ticks_msec() - stage_started, " pairs=",
			pair_frontier.size())
	# Rank the finite compatible triples using the same quality function before
	# invoking the exact room-composition proof.  The former loop proved every
	# surviving triple just to discover the minimum tower risk, so a 500-member
	# corpus expanded into tens of thousands of identical-cost recompositions.
	# The first exact survivor in this ordering is the same optimum (with an
	# explicit deterministic tie-break) and lets the search stop immediately.
	var proposal_by_id: Dictionary = {}
	for proposal: Dictionary in proposals:
		var proposal_parcel := proposal.parcel as WarrenBuildingParcel
		proposal_by_id[proposal_parcel.stable_id] = proposal
	var ranked_triples: Array[Dictionary] = []
	var seen_triples: Dictionary = {}
	for pair_indices: Vector2i in pair_frontier:
		var first := pair_indices.x
		var second := pair_indices.y
		for third in candidates.size():
			if third in [first, second] \
					or not _skywalk_candidates_compatible(candidates[first],
						candidates[third]) \
					or not _skywalk_candidates_compatible(candidates[second],
						candidates[third]):
				continue
			var combination := [candidates[first], candidates[second],
				candidates[third]] as Array[Dictionary]
			var landmark_endpoint_count := 0
			for candidate: Dictionary in combination:
				landmark_endpoint_count += int(candidate.get(
					"landmark_endpoint_count", 0))
			if landmark_endpoint_count < 1:
				continue
			var sorted_indices: Array[int] = [first, second, third]
			sorted_indices.sort()
			var triple_key := "%d/%d/%d" % sorted_indices
			if seen_triples.has(triple_key):
				continue
			seen_triples[triple_key] = true
			var tower_risk := _skywalk_combination_tower_risk(combination,
				proposals, proposal_by_id)
			var quality := 0
			var tie := 0
			for candidate: Dictionary in combination:
				quality += int(candidate.blocker_count) * 100 \
					- int(candidate.lower_cover) * 10
				tie += int(candidate.tie)
			ranked_triples.append({"indices": sorted_indices,
				"tower_risk": tower_risk, "quality": quality,
				"landmark_endpoint_count": landmark_endpoint_count,
				"tie": tie})
	ranked_triples.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.tower_risk) != int(b.tower_risk):
			return int(a.tower_risk) < int(b.tower_risk)
		if int(a.quality) != int(b.quality):
			return int(a.quality) < int(b.quality)
		if int(a.landmark_endpoint_count) != int(b.landmark_endpoint_count):
			return int(a.landmark_endpoint_count) \
				> int(b.landmark_endpoint_count)
		return int(a.tie) < int(b.tie))
	if diagnostic_trace_skywalk_timing:
		print("SKYWALK_TIMING landmark_triples ms=",
			Time.get_ticks_msec() - stage_started, " triples=",
			ranked_triples.size())
	for ranked: Dictionary in ranked_triples:
		composition_trial_count += 1
		var indices := ranked.indices as Array[int]
		var combination := [candidates[indices[0]], candidates[indices[1]],
			candidates[indices[2]]] as Array[Dictionary]
		if not _skywalk_selection_preserves_endpoint_rooms(grid, volume,
				combination, proposals, protected_owners, volume.world_seed):
			continue
		composition_ranked_combination_count += 1
		selected = combination
		selected_tower_risk = int(ranked.tower_risk)
		selected_quality = int(ranked.quality)
		break
	if diagnostic_trace_skywalk_timing:
		print("SKYWALK_TIMING landmark_exact ms=",
			Time.get_ticks_msec() - stage_started, " trials=",
			composition_trial_count, " selected=", selected.size())
	last_preplan_skywalk_diagnostic["landmark_filtered_candidate_count"] = \
		candidates.size()
	last_preplan_skywalk_diagnostic["landmark_attached_candidate_count"] = \
		landmark_attached.size()
	last_preplan_skywalk_diagnostic["landmark_joint_selected_count"] = \
		selected.size()
	last_preplan_skywalk_diagnostic["composition_ranked_combination_count"] = \
		composition_ranked_combination_count
	last_preplan_skywalk_diagnostic["ranked_triple_count"] = \
		ranked_triples.size()
	last_preplan_skywalk_diagnostic["composition_trial_count"] = \
		composition_trial_count
	last_preplan_skywalk_diagnostic["selected_tower_risk"] = \
		selected_tower_risk
	var plan := _skywalk_plan_from_selected(selected, candidates.size())
	plan["pair_frontier_count"] = pair_frontier.size()
	plan["tower_risk"] = selected_tower_risk
	return plan


static func _skywalk_combination_tower_risk(
		combination: Array[Dictionary], proposals: Array[Dictionary],
		cached_proposal_by_id: Dictionary = {}) -> int:
	## Exact endpoint survival alone can still force a stationary upper block on
	## a tall narrow parcel, leaving the later 3D composer no legal alternative
	## to a tower. Rank complete bridge triples by that downstream obligation:
	## shifted tall endpoints are cheaper than stationary ones, and fewer/highly
	## constrained tower parcels are preferred. This is topology selection, not a
	## post-construction decoration score.
	var proposal_by_id := cached_proposal_by_id
	if proposal_by_id.is_empty():
		for proposal: Dictionary in proposals:
			var parcel := proposal.parcel as WarrenBuildingParcel
			proposal_by_id[parcel.stable_id] = proposal
	var states: Dictionary = {}
	for candidate: Dictionary in combination:
		for parcel_value: Variant in (candidate.forced_offsets \
				as Dictionary).keys():
			var parcel_id := StringName(parcel_value)
			if not proposal_by_id.has(parcel_id):
				continue
			var proposal := proposal_by_id[parcel_id] as Dictionary
			if StringName(proposal.kind) != &"tower" \
					or int(proposal.storeys) < \
						WarrenRoomCompositionPlanner.TALL_LINEAGE_STOREYS:
				continue
			if not states.has(parcel_id):
				states[parcel_id] = {"shifted": false, "highest_block": 0,
					"storeys": int(proposal.storeys)}
			var state := states[parcel_id] as Dictionary
			for block_value: Variant in ((candidate.forced_offsets \
					as Dictionary)[parcel_id] as Dictionary).keys():
				var delta := ((candidate.forced_offsets as Dictionary)[
					parcel_id] as Dictionary)[block_value] as Vector2i
				state["shifted"] = bool(state.shifted) or delta != Vector2i.ZERO
				state["highest_block"] = maxi(int(state.highest_block),
					int(block_value))
	var risk := 0
	for state_value: Variant in states.values():
		var state := state_value as Dictionary
		risk += 100000 if not bool(state.shifted) else 10000
		risk += int(state.highest_block) * 1000 + int(state.storeys)
	return risk


static func _landmark_attached_skywalk_candidates(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan, proposals: Array[Dictionary],
		landmarks: Array[Dictionary], program: SettlementFabricProgram,
		protected_owners: Dictionary, public_air: Dictionary) \
		-> Array[Dictionary]:
	## Large authored buildings expose the same measured ROOM/BEARING sockets as
	## modular rooms. Let one of the required links terminate in that real socket;
	## otherwise two landmarks can erase the third bridge endpoint even while a
	## perfectly good elevated facade connection exists on the prefab itself.
	var parcels: Array[WarrenBuildingParcel] = []
	var proposal_by_id: Dictionary = {}
	for proposal: Dictionary in proposals:
		var parcel := proposal.parcel as WarrenBuildingParcel
		parcels.append(parcel)
		proposal_by_id[parcel.stable_id] = proposal
	var cache := WarrenAssetCompiler.massif_partition_asset_cache(parcels,
		volume.world_seed, program)
	if not bool(cache.get(&"enabled", false)):
		return [] as Array[Dictionary]
	var all_landmark_cells := _landmark_set_protected_cells(landmarks)
	var blocked_parcels := _landmark_set_blocker_parcels(landmarks)
	var out: Array[Dictionary] = []
	var seen: Dictionary = {}
	var socket_count := 0
	var body_socket_count := 0
	var endpoint_pair_count := 0
	var raw_link_count := 0
	var raw_straight_count := 0
	var raw_corner_count := 0
	var upper_block_count := 0
	var body_fit_count := 0
	var route_cover_count := 0
	for landmark: Dictionary in landmarks:
		var landmark_id := StringName(landmark.feature_id)
		var landmark_recipe := program.recipe(StringName(landmark.recipe_id))
		if landmark_recipe == null:
			continue
		for socket: Dictionary in landmark_recipe.sockets:
			if int(socket.kind) != FabricRecipe.SocketKind.ROOM \
					or String(StringName(socket.id)).contains(".corner."):
				continue
			socket_count += 1
			var landmark_endpoint := {
				"slot_signature": String(landmark_id),
				"owner_kind": &"landmark",
				"cell": FabricRecipe.transform_cell(socket.cell as Vector3i,
					landmark.origin as Vector3i, int(landmark.yaw_quarters)),
				"facing": FabricRecipe.transform_direction(
					socket.facing as Vector3i, int(landmark.yaw_quarters)),
			}
			if not (landmark.body as Dictionary).has(landmark_endpoint.cell):
				continue
			body_socket_count += 1
			for parcel: WarrenBuildingParcel in parcels:
				if blocked_parcels.has(parcel.stable_id):
					continue
				var proposal := proposal_by_id[parcel.stable_id] as Dictionary
				for parcel_endpoint: Dictionary in WarrenAssetCompiler \
						._parcel_room_endpoints(parcel, program, cache):
					endpoint_pair_count += 1
					var raw_links: Array[Dictionary] = []
					var straight := _raw_straight_skywalk_between_endpoints(
						landmark_endpoint, parcel_endpoint, landmark_id,
						parcel.stable_id, program, public_air)
					if not straight.is_empty():
						raw_links.append(straight)
						raw_straight_count += 1
					var corners := _raw_corner_skywalks_between_endpoints(
						landmark_endpoint, parcel_endpoint, landmark_id,
						parcel.stable_id, program, public_air)
					raw_corner_count += corners.size()
					raw_links.append_array(corners)
					raw_link_count += raw_links.size()
					for raw: Dictionary in raw_links:
						var body := raw.reserved_cells as Dictionary
						var clearance := raw.visual_clearance_cells as Dictionary
						var block := _proposal_block_for_cell(proposal,
							parcel_endpoint.cell as Vector3i)
						var priority := _forced_block_cells(proposal, block,
							Vector2i.ZERO)
						if block <= 0:
							continue
						upper_block_count += 1
						if priority.is_empty() \
								or not _forced_block_fits(grid, proposal, block,
									Vector2i.ZERO) \
								or _sets_overlap(body, all_landmark_cells) \
								or _sets_overlap(priority, all_landmark_cells) \
								or not _skywalk_body_fits_grid(grid, body) \
								or not _skywalk_clearance_fits_grid(grid, clearance) \
								or not _landmark_link_clearance_fits_protected(
									clearance, protected_owners, landmark_id):
							continue
						body_fit_count += 1
						var lower_cover := _lower_public_cover(body, public_air)
						if lower_cover < 2:
							continue
						route_cover_count += 1
						raw["owner_parcel_ids"] = [landmark_id, parcel.stable_id]
						var endpoint_key := _skywalk_endpoint_pair_key(raw)
						var construction_key := _skywalk_construction_key(raw)
						var unique_key := "%s/%s" % [endpoint_key, construction_key]
						if seen.has(unique_key):
							continue
						seen[unique_key] = true
						var priority_cells: Dictionary = {}
						for cell_value: Variant in priority.keys():
							priority_cells[cell_value] = parcel.stable_id
						out.append({"reservation": raw, "body": body,
							"clearance": clearance,
							"forced_offsets": {parcel.stable_id: {
								block: Vector2i.ZERO}},
							"priority_cells": priority_cells,
							"pair_key": "%s|%s" % [landmark_id,
								parcel.stable_id],
							"endpoint_pair_key": endpoint_key,
							"blocker_count": _skywalk_blocker_count(clearance,
								protected_owners, {landmark_id: true,
									parcel.stable_id: true}),
							"lower_cover": lower_cover,
							"landmark_endpoint_count": 1,
							"tie": posmod(Helper._mix64(volume.world_seed \
								^ String(landmark_id).hash() \
								^ String(parcel.stable_id).hash() \
								^ (landmark_endpoint.cell as Vector3i).y * 131),
								1000003)})
	last_preplan_skywalk_diagnostic["landmark_link_socket_count"] = socket_count
	last_preplan_skywalk_diagnostic["landmark_link_body_socket_count"] = \
		body_socket_count
	last_preplan_skywalk_diagnostic["landmark_link_endpoint_pair_count"] = \
		endpoint_pair_count
	last_preplan_skywalk_diagnostic["landmark_link_raw_count"] = raw_link_count
	last_preplan_skywalk_diagnostic["landmark_link_raw_straight_count"] = \
		raw_straight_count
	last_preplan_skywalk_diagnostic["landmark_link_raw_corner_count"] = \
		raw_corner_count
	last_preplan_skywalk_diagnostic["landmark_link_upper_block_count"] = \
		upper_block_count
	last_preplan_skywalk_diagnostic["landmark_link_body_fit_count"] = \
		body_fit_count
	last_preplan_skywalk_diagnostic["landmark_link_route_cover_count"] = \
		route_cover_count
	if diagnostic_trace_skywalk_timing:
		print("SKYWALK_TIMING landmark_link_gates ", {
			"sockets": socket_count, "body_sockets": body_socket_count,
			"endpoint_pairs": endpoint_pair_count, "raw": raw_link_count,
			"straight": raw_straight_count, "corner": raw_corner_count,
			"upper": upper_block_count, "body_fit": body_fit_count,
			"cover": route_cover_count, "accepted": out.size()})
	return out


static func _landmark_link_clearance_fits_protected(clearance: Dictionary,
		protected_owners: Dictionary, allowed_landmark_id: StringName) -> bool:
	for cell_value: Variant in clearance.keys():
		for owner_value: Variant in (protected_owners.get(cell_value, {}) \
				as Dictionary).keys():
			var owner_id := StringName(owner_value)
			if _protected_owner_is_feature(owner_id) \
					and owner_id != allowed_landmark_id:
				return false
	return true


static func _raw_straight_skywalk_between_endpoints(left_endpoint: Dictionary,
		right_endpoint: Dictionary, left_owner_id: StringName,
		right_owner_id: StringName, program: SettlementFabricProgram,
		public_air: Dictionary) -> Dictionary:
	if (left_endpoint.cell as Vector3i).y \
			!= (right_endpoint.cell as Vector3i).y \
			or (left_endpoint.facing as Vector3i) \
				!= -(right_endpoint.facing as Vector3i):
		return {}
	var forward := left_endpoint.facing as Vector3i
	var delta := (right_endpoint.cell as Vector3i) \
		- (left_endpoint.cell as Vector3i)
	var distance: int = delta.x * forward.x + delta.z * forward.z
	if distance < 3 or distance > 7 or posmod(distance, 2) != 1 \
			or delta != forward * distance:
		return {}
	var segments := (distance - 1) / 2
	var recipe_id := &"skywalk.3.blue" if segments == 1 \
		else &"skywalk.6.orange" if segments == 2 else &"skywalk.9.blue"
	var recipe := program.recipe(recipe_id)
	var yaw := -1
	for candidate_yaw in 4:
		if FabricRecipe.transform_direction(Vector3i.LEFT, candidate_yaw) \
				== -forward:
			yaw = candidate_yaw
			break
	if recipe == null or yaw < 0:
		return {}
	var west := recipe.socket(&"room.west")
	if west.is_empty():
		return {}
	var origin := (left_endpoint.cell as Vector3i) + forward \
		- FabricRecipe.transform_cell(west.cell as Vector3i, Vector3i.ZERO, yaw)
	var reserved: Dictionary = {}
	for source_cells: Array[Vector3i] in [recipe.solid_cells,
			recipe.headroom_cells]:
		for local: Vector3i in source_cells:
			var cell := FabricRecipe.transform_cell(local, origin, yaw)
			if public_air.has(cell):
				return {}
			reserved[cell] = true
	var components: Array[Dictionary] = [{"recipe_id": recipe_id,
		"origin": origin, "yaw_quarters": yaw}]
	var left_record := left_endpoint.duplicate(true)
	left_record["owner_id"] = left_owner_id
	var right_record := right_endpoint.duplicate(true)
	right_record["owner_id"] = right_owner_id
	return {"kind": &"straight", "recipe_id": recipe_id,
		"origin": origin, "yaw_quarters": yaw, "components": components,
		"reserved_cells": reserved,
		"visual_bounds": [FabricRecipe.lattice_transform(origin, yaw) \
			* recipe.local_clearance_bounds] as Array[AABB],
		"visual_clearance_cells": _skywalk_visual_clearance_cells(components,
			program), "owner_endpoints": [left_record, right_record]}


static func _skywalk_plan_from_selected(selected: Array[Dictionary],
		candidate_count: int) -> Dictionary:
	var reservations: Array[Dictionary] = []
	var forced_offsets: Dictionary = {}
	var priority_cells: Dictionary = {}
	for candidate: Dictionary in selected:
		reservations.append((candidate.reservation as Dictionary).duplicate(true))
		for parcel_value: Variant in (candidate.forced_offsets \
				as Dictionary).keys():
			var parcel_id := StringName(parcel_value)
			if not forced_offsets.has(parcel_id):
				forced_offsets[parcel_id] = {}
			for block_value: Variant in ((candidate.forced_offsets \
					as Dictionary)[parcel_id] as Dictionary).keys():
				(forced_offsets[parcel_id] as Dictionary)[int(block_value)] = \
					((candidate.forced_offsets as Dictionary)[parcel_id] \
						as Dictionary)[block_value]
		for cell_value: Variant in (candidate.priority_cells as Dictionary).keys():
			priority_cells[cell_value] = (candidate.priority_cells \
				as Dictionary)[cell_value]
	return {"reservations": reservations, "forced_offsets": forced_offsets,
		"priority_cells": priority_cells, "candidate_count": candidate_count,
		"selected_candidates": selected.duplicate(true)}


static func _landmark_candidates_compatible(left: Dictionary,
		right: Dictionary) -> bool:
	if left.landing_cell == right.landing_cell \
			or StringName(left.recipe_id) == StringName(right.recipe_id):
		return false
	for cell_value: Variant in (left.protected_cells as Dictionary).keys():
		if (right.protected_cells as Dictionary).has(cell_value):
			return false
	return true


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


static func _landmark_recipe_ids(landmarks: Array[Dictionary]) \
		-> Array[StringName]:
	var out: Array[StringName] = []
	for landmark: Dictionary in landmarks:
		out.append(StringName(landmark.recipe_id))
	return out


static func _reserve_landmark_preplans(grid: WarrenSpatialGrid,
		landmarks: Array[Dictionary]) -> bool:
	for landmark: Dictionary in landmarks:
		if not _reserve_landmark_preplan(grid, landmark):
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
			if skywalk_socket_faces.get(cell, Vector3i.ZERO) == direction:
				continue
			var kind := WarrenSpatialGrid.FaceKind.FACADE
			if cell == entrance_cell and neighbor == landing_cell:
				kind = WarrenSpatialGrid.FaceKind.DOOR
			elif direction == Vector3i.UP:
				kind = WarrenSpatialGrid.FaceKind.ROOF
			elif direction == Vector3i.DOWN:
				kind = WarrenSpatialGrid.FaceKind.PRIVATE_FLOOR
			if not tx.claim_face(cell, direction, kind, feature_id):
				return false
	return tx.commit()


static func _landmark_bearing_follows_terrain(bearing: Dictionary,
		volume: WarrenVolumePlan) -> bool:
	var massif := volume.mass_context.get("massif") as WarrenMassif
	if massif == null:
		return false
	for cell_value: Variant in bearing.keys():
		var cell := cell_value as Vector3i
		var macro_column := Vector2i(floori(float(cell.x) / 2.0),
			floori(float(cell.z) / 2.0))
		if massif.bearing_at(macro_column) != cell.y:
			return false
	return true


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
			var recipe_id := StringName("market.covered.%02d" % family)
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
			candidates.append({"feature_id": feature_id,
				"kind": &"covered_market", "recipe_id": recipe_id,
				"origin": market_origin, "yaw_quarters": market_yaw,
				"components": components, "reserved_cells": body,
				"public_cells": public_cells,
				"covered_aisle_cells": covered_aisle_cells,
				"aisle_extension_cell_count": public_cells.size() \
					- covered_aisle_cells.size(),
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
				"tie": posmod(Helper._mix64(volume.world_seed \
					^ String(recipe_id).hash() ^ market_origin.x * 31 \
					^ market_origin.z * 47 ^ market_yaw * 131), 1000003)})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.blocker_count) != int(b.blocker_count):
			return int(a.blocker_count) < int(b.blocker_count)
		return int(a.tie) < int(b.tie))
	var viable: Array[Dictionary] = []
	for candidate: Dictionary in candidates:
		if not _market_backing_composition_survives(grid, candidate, proposals,
				protected_owners, volume.world_seed):
			continue
		backing_fit_count += 1
		viable.append(candidate)
	last_preplan_market_diagnostic = {"socket_count": socket_count,
		"ground_fit_count": ground_fit_count, "body_fit_count": body_fit_count,
		"aisle_fit_count": aisle_fit_count,
		"clearance_fit_count": clearance_fit_count,
		"candidate_count": candidates.size(),
		"backing_fit_count": backing_fit_count,
		"aisle_failures": aisle_failures}
	return {"candidates": viable}


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
	var parcel := proposal.parcel as WarrenBuildingParcel
	var origin := proposal.origin as Vector3i
	var storeys := int(proposal.storeys)
	var threshold := WarrenParcelConstruction.threshold_cell(parcel)
	var addressed_storey := clampi(floori(float(threshold.y - origin.y) \
		/ float(WarrenSpatialGrid.STOREY_CELLS)), 0, storeys - 1)
	var forced: Dictionary = {0: Vector2i.ZERO,
		addressed_storey / 2: Vector2i.ZERO}
	return not _composition_offsets(grid, _proposal_base_plate(proposal),
		origin.y, storeys, trial, backing_parcel_id, world_seed, forced).is_empty()


static func _protected_owners_with_market(protected_owners: Dictionary,
		market: Dictionary) -> Dictionary:
	var trial := protected_owners.duplicate(true)
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
	return trial


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


static func _court_candidate_preserves_exact_room_envelopes(
		grid: WarrenSpatialGrid, volume: WarrenVolumePlan,
		proposals: Array[Dictionary], program: SettlementFabricProgram,
		market: Dictionary, court_candidate: Dictionary,
		base_protected_owners: Dictionary,
		court_fixed_blocks_by_parcel: Dictionary,
		skywalk_plan: Dictionary) -> bool:
	## Exact post-feature preflight for the six-member court frontier. Solve the
	## actual room grammar with the already-fixed market, landmarks, three
	## skywalks, and this cantilever, then compare authored room envelopes against
	## its two measured components. This is deliberately not a raster halo: party
	## walls and narrow streets remain legal, while the exact eave collision that
	## final fabric compilation would reject removes only this court candidate.
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
	var composition := WarrenRoomCompositionPlanner.solve(grid, volume,
		proposals, solved_offsets_by_parcel, exact_forced_offsets_by_parcel,
		market, trial_owners, forced_offsets_by_parcel,
		skywalk_reservations, volume.world_seed)
	if composition.is_empty():
		return false
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
	for component_value: Variant in reservation.get("components", []):
		var component := component_value as Dictionary
		var feature_recipe := program.recipe(StringName(component.recipe_id))
		if feature_recipe == null:
			return false
		feature_bounds.append(FabricRecipe.lattice_transform(
			component.origin as Vector3i, int(component.yaw_quarters)) \
			* feature_recipe.local_clearance_bounds)
	var required_parcels := related_parcels.duplicate()
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
	var displaced_parcels: Dictionary = {}
	for proposal: Dictionary in proposals:
		var parcel := proposal.parcel as WarrenBuildingParcel
		if related_parcels.has(parcel.stable_id):
			continue
		var lineage := (composition.lineages as Dictionary).get(
			parcel.stable_id, {}) as Dictionary
		if lineage.is_empty():
			continue
		var proposal_origin := proposal.origin as Vector3i
		var threshold := WarrenParcelConstruction.threshold_cell(parcel)
		for block: Dictionary in lineage.blocks as Array[Dictionary]:
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
				var room := WarrenRoomStamp.new(&"court.envelope.probe",
					parcel.stable_id, StringName(block.kind), room_origin,
					int(block.yaw_quarters), storey,
					storey == 0 and not block.has(
						"support_parent_lineage_id"), addressed,
					threshold if addressed else Vector3i(2147483647,
						2147483647, 2147483647),
					Vector3i(parcel.frontage_direction.x, 0,
						parcel.frontage_direction.y), int(proposal.roof_feature),
					&"", -1, parcel.address_door_phase if addressed else 0)
				var desired := program.recipe(
					WarrenSpatialFabricCompiler._room_recipe_id(room,
						volume.world_seed, true))
				var fallback := program.recipe(
					WarrenSpatialFabricCompiler._room_recipe_id(room,
						volume.world_seed, false))
				if desired == null or fallback == null:
					return false
				if _room_recipe_overlaps_any_bounds(room_origin,
						int(block.yaw_quarters), desired, feature_bounds) \
						and _room_recipe_overlaps_any_bounds(room_origin,
							int(block.yaw_quarters), fallback, feature_bounds):
					if required_parcels.has(parcel.stable_id):
						last_preplan_market_diagnostic[
							"last_exact_court_required_conflict"] = {
								"parcel": parcel.stable_id,
								"storey": storey,
								"room_origin": room_origin,
								"desired_recipe": desired.recipe_id,
								"fallback_recipe": fallback.recipe_id,
							}
						return false
					displaced_parcels[parcel.stable_id] = true
	var displaced_ids: Array[StringName] = []
	displaced_ids.assign(displaced_parcels.keys())
	displaced_ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	court_candidate["excluded_parcel_ids"] = displaced_ids
	return true


static func _room_recipe_overlaps_any_bounds(origin: Vector3i, yaw: int,
		recipe: FabricRecipe, other_bounds: Array[AABB]) -> bool:
	var bounds := FabricRecipe.lattice_transform(origin, yaw) \
		* recipe.local_clearance_bounds
	for other: AABB in other_bounds:
		if SettlementFabricPlan._aabb_overlaps_volume(bounds, other):
			return true
	return false


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
	for extension_length in 4:
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


static func _preplan_spatial_skywalks(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan, proposals: Array[Dictionary],
		program: SettlementFabricProgram, protected_owners: Dictionary,
		target_count: int, court_bridge_candidate_count: int = 0) -> Dictionary:
	## Bounded feature-set search over exact measured straight-link contracts.
	## Unlike the retired late detail pass, candidates may displace unrelated
	## generic rooms; the endpoint composition blocks and bridge void are fixed
	## before `_partition_rooms` commits any private volume.
	var stage_started := Time.get_ticks_msec()
	var parcels: Array[WarrenBuildingParcel] = []
	var proposal_by_slot: Dictionary = {}
	for proposal: Dictionary in proposals:
		var parcel := proposal.parcel as WarrenBuildingParcel
		parcels.append(parcel)
		proposal_by_slot[parcel.slot_signature()] = proposal
	var court_fixed_blocks_by_parcel: Dictionary = {}
	var court_neighbors := _courtyard_neighbor_cells(
		_courtyard_floor_cells(volume))
	for proposal: Dictionary in proposals:
		var parcel := proposal.parcel as WarrenBuildingParcel
		var fixed := _proposal_court_fixed_blocks(proposal, court_neighbors)
		if not fixed.is_empty():
			court_fixed_blocks_by_parcel[parcel.stable_id] = fixed
	var realm := WarrenVolumePublicRealmAdapter.from_volume(volume)
	if realm == null:
		return {}
	var public_air := realm.air_claims()
	var cache := WarrenAssetCompiler.massif_partition_asset_cache(parcels,
		volume.world_seed, program)
	if not bool(cache.get(&"enabled", false)):
		return {}
	var candidates: Array[Dictionary] = []
	var forced_block_cache: Dictionary = {}
	var corner_reservation_cache: Dictionary = {}
	var raw_count := 0
	var corner_raw_count := 0
	var corner_summaries: Array[Dictionary] = []
	var corner_upper_block_count := 0
	var corner_forced_fit_count := 0
	var corner_body_fit_count := 0
	var corner_route_cover_count := 0
	var upper_block_count := 0
	var forced_fit_count := 0
	var body_fit_count := 0
	var route_cover_count := 0
	for left_index in parcels.size():
		var left := parcels[left_index]
		for right_index in range(left_index + 1, parcels.size()):
			var right := parcels[right_index]
			if not WarrenAssetCompiler.parcels_may_form_skywalk(left, right,
					program, cache):
				continue
			var left_endpoints := WarrenAssetCompiler._parcel_room_endpoints(left,
				program, cache)
			var right_endpoints := WarrenAssetCompiler._parcel_room_endpoints(right,
				program, cache)
			for left_endpoint: Dictionary in left_endpoints:
				for right_endpoint: Dictionary in right_endpoints:
					var left_proposal := proposal_by_slot[left.slot_signature()] \
						as Dictionary
					var right_proposal := proposal_by_slot[right.slot_signature()] \
						as Dictionary
					var left_block := _proposal_block_for_cell(left_proposal,
						left_endpoint.cell as Vector3i)
					var right_block := _proposal_block_for_cell(right_proposal,
						right_endpoint.cell as Vector3i)
					var corner_result := _shifted_corner_skywalk_candidates(grid,
						left, right, left_proposal, right_proposal,
						left_endpoint, right_endpoint, left_block, right_block,
						program, protected_owners, public_air, volume.world_seed,
						forced_block_cache, corner_reservation_cache)
					var corner_candidates := corner_result.get("candidates", []) \
						as Array[Dictionary]
					if not corner_candidates.is_empty():
						candidates.append_array(corner_candidates)
					corner_upper_block_count += int(corner_result.get(
						"upper_pair_count", 0))
					corner_forced_fit_count += int(corner_result.get(
						"forced_fit_count", 0))
					corner_body_fit_count += int(corner_result.get(
						"body_fit_count", 0))
					corner_route_cover_count += int(corner_result.get(
						"route_cover_count", 0))
					var raw := _raw_straight_skywalk_reservation(left,
						right, left_endpoint, right_endpoint, program, public_air)
					if raw.is_empty():
						continue
					raw_count += 1
					candidates.append_array(_stationary_skywalk_candidates(grid,
						raw, left, right, left_proposal, right_proposal,
						left_endpoint, right_endpoint, left_block, right_block,
						protected_owners, public_air, volume.world_seed))
					# A shifted base block would no longer bear on immutable terrain.
					# Both endpoints therefore live in true upper composition blocks.
					if left_block <= 0 or right_block <= 0:
						continue
					upper_block_count += 1
					var facing := left_endpoint.facing as Vector3i
					var perpendicular := Vector3i(-facing.z, 0, facing.x)
					for sign_value in [-1, 1]:
						var delta3 := perpendicular * int(sign_value)
						var delta := Vector2i(delta3.x, delta3.z)
						if not _forced_block_fits(grid, left_proposal,
								left_block, delta) \
								or not _forced_block_fits(grid, right_proposal,
									right_block, delta):
							continue
						forced_fit_count += 1
						var left_plate := _forced_block_cells(left_proposal,
							left_block, delta)
						var right_plate := _forced_block_cells(right_proposal,
							right_block, delta)
						if _sets_overlap(left_plate, right_plate):
							continue
						var shifted := _translate_skywalk_reservation(raw,
							delta3)
						var body := shifted.reserved_cells as Dictionary
						var clearance := shifted.visual_clearance_cells as Dictionary
						if not _skywalk_body_fits_grid(grid, body) \
								or not _skywalk_clearance_fits_grid(grid, clearance) \
								or not _skywalk_clearance_fits_protected(clearance,
									protected_owners):
							continue
						if _sets_overlap(body, left_plate) \
								or _sets_overlap(body, right_plate):
							continue
						body_fit_count += 1
						var lower_cover := _lower_public_cover(body, public_air)
						if lower_cover < 2:
							continue
						route_cover_count += 1
						var blockers := _skywalk_blocker_count(clearance,
							protected_owners, {left.stable_id: true,
								right.stable_id: true})
						var forced: Dictionary = {
							left.stable_id: {left_block: delta},
							right.stable_id: {right_block: delta},
						}
						var priority_cells: Dictionary = {}
						for value: Variant in left_plate.keys():
							priority_cells[value] = left.stable_id
						for value: Variant in right_plate.keys():
							priority_cells[value] = right.stable_id
						shifted["owner_parcel_ids"] = [left.stable_id,
							right.stable_id]
						var endpoint_pair_key := _skywalk_endpoint_pair_key(shifted)
						candidates.append({"reservation": shifted,
							"body": body, "clearance": clearance,
							"forced_offsets": forced,
							"priority_cells": priority_cells,
							"pair_key": "%s|%s" % [left.stable_id,
								right.stable_id],
							"endpoint_pair_key": endpoint_pair_key,
							"blocker_count": blockers,
							"lower_cover": lower_cover,
							"tie": posmod(Helper._mix64(volume.world_seed \
								^ String(left.stable_id).hash() \
								^ String(right.stable_id).hash() \
								^ int(sign_value) * 0x45d9f3b \
								^ (left_endpoint.cell as Vector3i).y * 17),
								1000003)})
			var corner_raw := WarrenAssetCompiler._corner_skywalk_reservation(
				left, right, program, public_air, cache)
			if not corner_raw.is_empty():
				corner_raw_count += 1
				corner_summaries.append({
					"pair_key": "%s|%s" % [left.stable_id, right.stable_id],
					"endpoint_pair_key": _skywalk_endpoint_pair_key(corner_raw),
					"origin": corner_raw.origin,
					"reserved_cell_count": (corner_raw.reserved_cells \
						as Dictionary).size(),
				})
	var fixed_block_rejection_count := 0
	var fixed_block_candidates: Array[Dictionary] = []
	for candidate: Dictionary in candidates:
		if _skywalk_candidate_respects_fixed_blocks(candidate, proposal_by_slot,
				court_fixed_blocks_by_parcel):
			fixed_block_candidates.append(candidate)
		else:
			fixed_block_rejection_count += 1
	candidates = fixed_block_candidates
	var candidate_generation_ms := Time.get_ticks_msec() - stage_started
	if diagnostic_trace_skywalk_timing:
		print("SKYWALK_TIMING baseline_generate ms=", candidate_generation_ms,
			" candidates=", candidates.size())
	if diagnostic_stop_after_skywalk_candidates:
		last_preplan_skywalk_diagnostic = {
			"raw_straight_count": raw_count,
			"raw_corner_count": corner_raw_count,
			"courtyard_bridge_candidate_count": court_bridge_candidate_count,
			"generated_candidate_count": candidates.size() \
				+ fixed_block_rejection_count,
			"fixed_block_rejection_count": fixed_block_rejection_count,
			"pre_individual_candidate_count": candidates.size(),
			"courtyard_fixed_block_count": _nested_dictionary_entry_count(
				court_fixed_blocks_by_parcel),
			"candidate_generation_ms": candidate_generation_ms,
		}
		return {"reservations": [] as Array[Dictionary],
			"forced_offsets": {}, "priority_cells": {},
			"candidate_count": 0, "candidate_corpus": [] as Array[Dictionary],
			"public_air": public_air}
	var individual_rejection_count := 0
	var individual_rejection_failures: Dictionary = {}
	var individually_viable: Array[Dictionary] = []
	candidates.sort_custom(_skywalk_candidate_less)
	var individual_started := Time.get_ticks_msec()
	var individual_limit := candidates.size()
	if diagnostic_skywalk_candidate_limit >= 0:
		individual_limit = mini(individual_limit,
			diagnostic_skywalk_candidate_limit)
	for candidate_index in individual_limit:
		var candidate := candidates[candidate_index]
		if _skywalk_selection_preserves_endpoint_rooms(grid, volume,
				[candidate] as Array[Dictionary], proposals, protected_owners,
				volume.world_seed):
			individually_viable.append(candidate)
		else:
			individual_rejection_count += 1
			individual_rejection_failures[_last_skywalk_selection_failure] = int(
				individual_rejection_failures.get(
					_last_skywalk_selection_failure, 0)) + 1
	var individual_validation_ms := Time.get_ticks_msec() - individual_started
	if diagnostic_trace_skywalk_timing:
		print("SKYWALK_TIMING baseline_individual total_ms=",
			Time.get_ticks_msec() - stage_started, " stage_ms=",
			individual_validation_ms, " viable=", individually_viable.size())
	if diagnostic_stop_after_skywalk_individual:
		last_preplan_skywalk_diagnostic = {
			"raw_straight_count": raw_count,
			"raw_corner_count": corner_raw_count,
			"generated_candidate_count": candidates.size()
				+ fixed_block_rejection_count,
			"fixed_block_rejection_count": fixed_block_rejection_count,
			"pre_individual_candidate_count": candidates.size(),
			"courtyard_fixed_block_count": _nested_dictionary_entry_count(
				court_fixed_blocks_by_parcel),
			"candidate_generation_ms": candidate_generation_ms,
			"individual_validated_count": individual_limit,
			"individual_viable_count": individually_viable.size(),
			"individual_validation_ms": individual_validation_ms,
			"individual_candidate_rejection_count": individual_rejection_count,
			"individual_candidate_rejection_failures":
				individual_rejection_failures,
		}
		return {"reservations": [] as Array[Dictionary],
			"forced_offsets": {}, "priority_cells": {},
			"candidate_count": 0,
			"candidate_corpus": [] as Array[Dictionary],
			"public_air": public_air}
	candidates = individually_viable
	candidates.sort_custom(_skywalk_candidate_less)
	# Build a bounded progressive beam. Pair survival is materially cheaper than
	# trying every triple and keeps candidates from one dense corner from crowding
	# all three slots; the third member may come from the complete finite corpus.
	var primary_frontier_size := mini(candidates.size(), 64)
	const MAX_PAIR_FRONTIER := 128
	const MAX_PAIRS_PER_FIRST := 4
	var selected: Array[Dictionary] = []
	var endpoint_survival_rejection_count := 0
	var endpoint_survival_failures: Dictionary = {}
	if target_count == 3:
		var pair_frontier: Array[Vector2i] = []
		var stop_pairs := false
		for first in primary_frontier_size:
			var accepted_for_first := 0
			for second in candidates.size():
				if second == first:
					continue
				if not _skywalk_candidates_compatible(candidates[first],
						candidates[second]):
					continue
				var pair := [candidates[first], candidates[second]] \
					as Array[Dictionary]
				if not _skywalk_selection_preserves_endpoint_rooms(grid, volume,
						pair, proposals, protected_owners, volume.world_seed):
					endpoint_survival_rejection_count += 1
					endpoint_survival_failures[_last_skywalk_selection_failure] = \
						int(endpoint_survival_failures.get(
							_last_skywalk_selection_failure, 0)) + 1
					continue
				pair_frontier.append(Vector2i(first, second))
				accepted_for_first += 1
				if pair_frontier.size() >= MAX_PAIR_FRONTIER:
					stop_pairs = true
					break
				if accepted_for_first >= MAX_PAIRS_PER_FIRST:
					break
			if stop_pairs:
				break
		for pair_indices: Vector2i in pair_frontier:
			var first := pair_indices.x
			var second := pair_indices.y
			for third in candidates.size():
				if third in [first, second] \
						or not _skywalk_candidates_compatible(candidates[first],
							candidates[third]) \
						or not _skywalk_candidates_compatible(candidates[second],
							candidates[third]):
					continue
				var combination := [candidates[first], candidates[second],
					candidates[third]] as Array[Dictionary]
				if not _skywalk_selection_preserves_endpoint_rooms(grid, volume,
						combination, proposals, protected_owners,
						volume.world_seed):
					endpoint_survival_rejection_count += 1
					endpoint_survival_failures[_last_skywalk_selection_failure] = \
						int(endpoint_survival_failures.get(
							_last_skywalk_selection_failure, 0)) + 1
					continue
				selected = combination
				break
			if not selected.is_empty():
				break
	if diagnostic_trace_skywalk_timing:
		print("SKYWALK_TIMING baseline_beam total_ms=",
			Time.get_ticks_msec() - stage_started, " selected=", selected.size())
	var reservations: Array[Dictionary] = []
	var forced_offsets: Dictionary = {}
	var priority_cells: Dictionary = {}
	for candidate: Dictionary in selected:
		reservations.append((candidate.reservation as Dictionary).duplicate(true))
		for parcel_value: Variant in (candidate.forced_offsets \
				as Dictionary).keys():
			var parcel_id := StringName(parcel_value)
			if not forced_offsets.has(parcel_id):
				forced_offsets[parcel_id] = {}
			for block_value: Variant in ((candidate.forced_offsets \
					as Dictionary)[parcel_id] as Dictionary).keys():
				(forced_offsets[parcel_id] as Dictionary)[int(block_value)] = \
					((candidate.forced_offsets as Dictionary)[parcel_id] \
						as Dictionary)[block_value]
		for cell_value: Variant in (candidate.priority_cells as Dictionary).keys():
			priority_cells[cell_value] = (candidate.priority_cells \
				as Dictionary)[cell_value]
	var pair_keys: Dictionary = {}
	var endpoint_pair_keys: Dictionary = {}
	var candidate_summaries: Array[Dictionary] = []
	for candidate: Dictionary in candidates:
		pair_keys[String(candidate.pair_key)] = true
		endpoint_pair_keys[String(candidate.endpoint_pair_key)] = true
	for candidate_index in mini(candidates.size(), 32):
		var candidate := candidates[candidate_index]
		candidate_summaries.append({
			"pair_key": String(candidate.pair_key),
			"endpoint_pair_key": String(candidate.endpoint_pair_key),
			"origin": (candidate.reservation as Dictionary).origin,
			"forced_offsets": candidate.forced_offsets,
			"body_cell_count": (candidate.body as Dictionary).size(),
			"lower_cover": int(candidate.lower_cover),
		})
	var selected_summaries: Array[Dictionary] = []
	for candidate: Dictionary in selected:
		selected_summaries.append({
			"pair_key": String(candidate.pair_key),
			"endpoint_pair_key": String(candidate.endpoint_pair_key),
			"origin": (candidate.reservation as Dictionary).origin,
			"forced_offsets": candidate.forced_offsets,
			"body_cell_count": (candidate.body as Dictionary).size(),
			"lower_cover": int(candidate.lower_cover),
		})
	last_preplan_skywalk_diagnostic = {"raw_straight_count": raw_count,
		"raw_corner_count": corner_raw_count,
		"courtyard_bridge_candidate_count": court_bridge_candidate_count,
		"raw_corners": corner_summaries,
		"corner_upper_block_pair_count": corner_upper_block_count,
		"corner_forced_offset_fit_count": corner_forced_fit_count,
		"corner_body_fit_count": corner_body_fit_count,
		"corner_route_cover_count": corner_route_cover_count,
		"upper_block_pair_count": upper_block_count,
		"forced_offset_fit_count": forced_fit_count,
		"body_fit_count": body_fit_count,
		"route_cover_count": route_cover_count,
		"compatible_candidate_count": candidates.size(),
		"fixed_block_rejection_count": fixed_block_rejection_count,
		"candidate_generation_ms": candidate_generation_ms,
		"courtyard_fixed_block_count": _nested_dictionary_entry_count(
			court_fixed_blocks_by_parcel),
		"individual_candidate_rejection_count": individual_rejection_count,
		"individual_validated_count": individual_limit,
		"individual_validation_ms": individual_validation_ms,
		"individual_candidate_rejection_failures": \
			individual_rejection_failures,
		"distinct_pair_count": pair_keys.size(),
		"pair_keys": pair_keys.keys(),
		"distinct_endpoint_pair_count": endpoint_pair_keys.size(),
		"candidates": candidate_summaries,
		"selected": selected_summaries,
		"endpoint_survival_rejection_count": \
			endpoint_survival_rejection_count,
		"endpoint_survival_failures": endpoint_survival_failures,
		"selected_count": selected.size()}
	return {"reservations": reservations, "forced_offsets": forced_offsets,
		"priority_cells": priority_cells,
		"candidate_count": candidates.size(), "candidate_corpus": candidates,
		"public_air": public_air}


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
	var corner_recipe := program.recipe(&"skywalk.corner.orange")
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
						"recipe_id": &"skywalk.corner.orange",
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
						"tie": posmod(Helper._mix64(volume.world_seed \
							^ String(parcel.stable_id).hash() ^ key.hash()),
							1000003)})
	out.sort_custom(_skywalk_candidate_less)
	if diagnostic_trace_skywalk_timing:
		print("SKYWALK_TIMING court_cantilever_gates ", {
			"raw": raw_count, "court_side": court_side_count,
			"body": body_fit_count,
			"clearance_grid": clearance_grid_fit_count,
			"clearance_protected": clearance_protected_fit_count,
			"grid": grid_fit_count, "cover": cover_count,
			"accepted": out.size(), "rejections": rejection_samples})
	return out


static func _courtyard_bridge_skywalk_candidates(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan, proposals: Array[Dictionary],
		program: SettlementFabricProgram, protected_owners: Dictionary,
		public_air: Dictionary) -> Array[Dictionary]:
	## A court cut through a solid mountain may have its third raw wall hovering
	## over the lower street instead of standing on a vertical bearing column.
	## Realize that condition as one measured U-shaped bridge-house: two pitched
	## corner knuckles bond to independent rooms and a reviewed enclosed link runs
	## along the court edge.  The body, endpoints, lower route, and asset seams all
	## participate in the same pre-partition transaction.
	var out: Array[Dictionary] = []
	var court_floors := _courtyard_floor_cells(volume)
	var parcel_side_mask := _proposal_courtyard_side_mask(volume, proposals)
	var proposal_by_id: Dictionary = {}
	var endpoints: Array[Dictionary] = []
	var court_y := 2147483647
	for floor_value: Variant in court_floors.keys():
		court_y = mini(court_y, (floor_value as Vector3i).y)
	for proposal: Dictionary in proposals:
		var parcel := proposal.parcel as WarrenBuildingParcel
		proposal_by_id[parcel.stable_id] = proposal
		for endpoint: Dictionary in _all_proposal_room_endpoints(proposal,
				parcel, program):
			if (endpoint.cell as Vector3i).y == court_y:
				endpoints.append(endpoint)
	var seen: Dictionary = {}
	var parallel_pair_count := 0
	var raw_count := 0
	var court_side_fit_count := 0
	var grid_fit_count := 0
	var lower_cover_count := 0
	var endpoint_block_fit_count := 0
	var court_endpoint_preview: Array[Dictionary] = []
	var raw_preview: Array[Dictionary] = []
	for endpoint: Dictionary in endpoints:
		if StringName(endpoint.owner_id) in [&"parcel.solid.0050",
				&"parcel.solid.0051"]:
			court_endpoint_preview.append({"owner": endpoint.owner_id,
				"cell": endpoint.cell, "facing": endpoint.facing})
	for left_index in endpoints.size():
		var left := endpoints[left_index]
		var left_id := StringName(left.owner_id)
		for right_index in range(left_index + 1, endpoints.size()):
			var right := endpoints[right_index]
			var right_id := StringName(right.owner_id)
			if left_id == right_id or left.facing != right.facing:
				continue
			parallel_pair_count += 1
			for reservation: Dictionary in _raw_u_courtyard_bridges(left,
					right, left_id, right_id, program, public_air):
				raw_count += 1
				var body := reservation.reserved_cells as Dictionary
				var body_side_mask := _courtyard_address_side_mask_from_occupied(
					court_floors, body)
				if raw_preview.size() < 32:
					raw_preview.append({"left": left, "right": right,
						"origin": reservation.origin, "side_mask": body_side_mask,
						"body": body.keys()})
				if body_side_mask == 0 or not _skywalk_selection_addresses_courtyard(
						[{"courtyard_side_mask": body_side_mask}] \
							as Array[Dictionary], parcel_side_mask):
					continue
				court_side_fit_count += 1
				var clearance := reservation.visual_clearance_cells as Dictionary
				if not _skywalk_body_fits_grid(grid, body) \
						or not _skywalk_clearance_fits_grid(grid, clearance) \
						or not _skywalk_clearance_fits_protected(clearance,
							protected_owners):
					continue
				grid_fit_count += 1
				var lower_cover := _lower_public_cover(body, public_air)
				if lower_cover < 2:
					continue
				lower_cover_count += 1
				var left_proposal := proposal_by_id[left_id] as Dictionary
				var right_proposal := proposal_by_id[right_id] as Dictionary
				var left_block := _proposal_block_for_cell(left_proposal,
					left.cell as Vector3i)
				var right_block := _proposal_block_for_cell(right_proposal,
					right.cell as Vector3i)
				if left_block < 0 or right_block < 0 \
						or not _forced_block_fits(grid, left_proposal, left_block,
							Vector2i.ZERO) \
						or not _forced_block_fits(grid, right_proposal, right_block,
							Vector2i.ZERO):
					continue
				endpoint_block_fit_count += 1
				var left_plate := _forced_block_cells(left_proposal, left_block,
					Vector2i.ZERO)
				var right_plate := _forced_block_cells(right_proposal, right_block,
					Vector2i.ZERO)
				if _sets_overlap(body, left_plate) or _sets_overlap(body,
						right_plate):
					continue
				var construction_key := _skywalk_construction_key(reservation)
				if seen.has(construction_key):
					continue
				seen[construction_key] = true
				var priority_cells: Dictionary = {}
				for value: Variant in left_plate.keys():
					priority_cells[value] = left_id
				for value: Variant in right_plate.keys():
					priority_cells[value] = right_id
				out.append({"reservation": reservation, "body": body,
					"clearance": clearance,
					"forced_offsets": {left_id: {left_block: Vector2i.ZERO},
						right_id: {right_block: Vector2i.ZERO}},
					"priority_cells": priority_cells,
					"pair_key": "%s|%s" % [left_id, right_id],
					"endpoint_pair_key": _skywalk_endpoint_pair_key(reservation),
					"blocker_count": _skywalk_blocker_count(clearance,
						protected_owners, {left_id: true, right_id: true}),
					"lower_cover": lower_cover,
					"courtyard_bridge": true,
					"courtyard_side_mask": body_side_mask,
					"tie": posmod(Helper._mix64(volume.world_seed \
						^ String(left_id).hash() ^ String(right_id).hash() \
						^ construction_key.hash()), 1000003)})
	out.sort_custom(_skywalk_candidate_less)
	if diagnostic_trace_skywalk_timing:
		print("SKYWALK_TIMING court_bridge_gates ", {
			"endpoints": endpoints.size(), "parallel_pairs": parallel_pair_count,
			"raw": raw_count, "court_side": court_side_fit_count,
			"grid": grid_fit_count, "lower_cover": lower_cover_count,
			"endpoint_blocks": endpoint_block_fit_count,
			"accepted": out.size(), "court_endpoints": court_endpoint_preview,
			"raw_preview": raw_preview})
	return out


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


static func _raw_u_courtyard_bridges(left_endpoint: Dictionary,
		right_endpoint: Dictionary, left_owner_id: StringName,
		right_owner_id: StringName, program: SettlementFabricProgram,
		public_air: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var left_cell := left_endpoint.cell as Vector3i
	var right_cell := right_endpoint.cell as Vector3i
	var facing := left_endpoint.facing as Vector3i
	var delta := right_cell - left_cell
	if left_cell.y != right_cell.y or facing != right_endpoint.facing \
			or delta.y != 0 or delta.x != 0 and delta.z != 0:
		return out
	var distance := absi(delta.x) + absi(delta.z)
	if distance < 5 or distance > 9:
		return out
	var along := Vector3i(signi(delta.x), 0, signi(delta.z))
	if along == Vector3i.ZERO or along == facing or along == -facing:
		return out
	var corner_recipe := program.recipe(&"skywalk.corner.orange")
	if corner_recipe == null:
		return out
	var seen: Dictionary = {}
	var yaw_pair_count := 0
	var middle_fit_count := 0
	var component_fit_count := 0
	var middle_preview: Array[Dictionary] = []
	for left_yaw in 4:
		var left_attach := WarrenAssetCompiler._socket_facing(corner_recipe,
			-facing, left_yaw)
		var left_free := WarrenAssetCompiler._socket_facing(corner_recipe,
			along, left_yaw)
		if left_attach.is_empty() or left_free.is_empty() \
				or left_attach.id == left_free.id:
			continue
		var left_origin := WarrenAssetCompiler._attached_origin(corner_recipe,
			StringName(left_attach.id), left_yaw, left_cell, facing)
		var left_free_cell := FabricRecipe.transform_cell(
			left_free.cell as Vector3i, left_origin, left_yaw)
		for right_yaw in 4:
			var right_attach := WarrenAssetCompiler._socket_facing(corner_recipe,
				-facing, right_yaw)
			var right_free := WarrenAssetCompiler._socket_facing(corner_recipe,
				-along, right_yaw)
			if right_attach.is_empty() or right_free.is_empty() \
					or right_attach.id == right_free.id:
				continue
			yaw_pair_count += 1
			var right_origin := WarrenAssetCompiler._attached_origin(corner_recipe,
				StringName(right_attach.id), right_yaw, right_cell, facing)
			var right_free_cell := FabricRecipe.transform_cell(
				right_free.cell as Vector3i, right_origin, right_yaw)
			var middle := _raw_straight_skywalk_between_endpoints(
				{"cell": left_free_cell, "facing": along},
				{"cell": right_free_cell, "facing": -along},
				&"court.corner.left", &"court.corner.right", program, public_air)
			if middle.is_empty():
				if middle_preview.size() < 8:
					var geometry_only := _raw_straight_skywalk_between_endpoints(
						{"cell": left_free_cell, "facing": along},
						{"cell": right_free_cell, "facing": -along},
						&"court.corner.left", &"court.corner.right", program, {})
					var public_conflicts: Array[Vector3i] = []
					for cell_value: Variant in (geometry_only.get("reserved_cells", {}) \
							as Dictionary).keys():
						if public_air.has(cell_value):
							public_conflicts.append(cell_value as Vector3i)
					middle_preview.append({"left_yaw": left_yaw,
						"right_yaw": right_yaw, "left_free": left_free_cell,
						"right_free": right_free_cell,
						"geometry_only": not geometry_only.is_empty(),
						"public_conflicts": public_conflicts})
				continue
			middle_fit_count += 1
			var components: Array[Dictionary] = [{
				"recipe_id": &"skywalk.corner.orange", "origin": left_origin,
				"yaw_quarters": left_yaw}]
			components.append_array(middle.components as Array)
			components.append({"recipe_id": &"skywalk.corner.orange",
				"origin": right_origin, "yaw_quarters": right_yaw})
			var reservation := WarrenAssetCompiler._component_reservation(
				components, program, public_air)
			if reservation.is_empty():
				continue
			component_fit_count += 1
			reservation["visual_clearance_cells"] = \
				_skywalk_visual_clearance_cells(components, program)
			reservation["kind"] = &"courtyard_bridge_house"
			reservation["recipe_id"] = StringName(middle.recipe_id)
			reservation["origin"] = middle.origin
			reservation["yaw_quarters"] = int(middle.yaw_quarters)
			var left_record := left_endpoint.duplicate(true)
			left_record["owner_id"] = left_owner_id
			var right_record := right_endpoint.duplicate(true)
			right_record["owner_id"] = right_owner_id
			reservation["owner_endpoints"] = [left_record, right_record]
			var key := _skywalk_construction_key(reservation)
			if seen.has(key):
				continue
			seen[key] = true
			out.append(reservation)
	if diagnostic_trace_skywalk_timing \
			and ((left_owner_id == &"parcel.solid.0050" \
				and right_owner_id == &"parcel.solid.0051") \
			or (left_owner_id == &"parcel.solid.0051" \
				and right_owner_id == &"parcel.solid.0050")):
		print("SKYWALK_TIMING target_u_bridge ", {"left": left_endpoint,
			"right": right_endpoint, "yaw_pairs": yaw_pair_count,
			"middle_fit": middle_fit_count, "component_fit": component_fit_count,
			"accepted": out.size(), "middle_preview": middle_preview})
	return out


static func _skywalk_candidate_respects_fixed_blocks(candidate: Dictionary,
		proposal_by_slot: Dictionary,
		court_fixed_blocks_by_parcel: Dictionary = {}) -> bool:
	for parcel_value: Variant in (candidate.forced_offsets as Dictionary).keys():
		var parcel_id := StringName(parcel_value)
		var proposal: Dictionary = {}
		for proposal_value: Variant in proposal_by_slot.values():
			var candidate_proposal := proposal_value as Dictionary
			if (candidate_proposal.parcel as WarrenBuildingParcel).stable_id \
					== parcel_id:
				proposal = candidate_proposal
				break
		if proposal.is_empty():
			return false
		var parcel := proposal.parcel as WarrenBuildingParcel
		var origin := proposal.origin as Vector3i
		var storeys := int(proposal.storeys)
		var threshold := WarrenParcelConstruction.threshold_cell(parcel)
		var addressed_storey := clampi(floori(float(threshold.y - origin.y) \
			/ float(WarrenSpatialGrid.STOREY_CELLS)), 0, storeys - 1)
		var addressed_block := addressed_storey / 2
		for block_value: Variant in ((candidate.forced_offsets as Dictionary)[
				parcel_id] as Dictionary).keys():
			var block := int(block_value)
			var wanted := ((candidate.forced_offsets as Dictionary)[parcel_id] \
				as Dictionary)[block] as Vector2i
			var court_fixed := (court_fixed_blocks_by_parcel.get(parcel_id, {}) \
				as Dictionary).has(block)
			if (block in [0, addressed_block] or court_fixed) \
					and wanted != Vector2i.ZERO:
				return false
	return true


static func _shifted_corner_skywalk_candidates(grid: WarrenSpatialGrid,
		left: WarrenBuildingParcel, right: WarrenBuildingParcel,
		left_proposal: Dictionary, right_proposal: Dictionary,
		left_endpoint: Dictionary, right_endpoint: Dictionary,
		left_block: int, right_block: int,
		program: SettlementFabricProgram, protected_owners: Dictionary,
		public_air: Dictionary, world_seed: int,
		forced_block_cache: Dictionary,
		corner_reservation_cache: Dictionary) -> Dictionary:
	## Re-solve the complete L-shaped recipe after independently shifting its
	## endpoint composition blocks. Translating an already-solved corner only
	## admitted one of the three high opportunities; recomposition preserves the
	## measured sockets while allowing the two arms to change length around the
	## immutable public void.
	var out: Array[Dictionary] = []
	var left_cell := left_endpoint.cell as Vector3i
	var right_cell := right_endpoint.cell as Vector3i
	var left_facing := left_endpoint.facing as Vector3i
	var right_facing := right_endpoint.facing as Vector3i
	if left_cell.y != right_cell.y \
			or left_facing.x * right_facing.x \
				+ left_facing.z * right_facing.z != 0 \
			or left_block < 0 or right_block < 0:
		return {"candidates": out}
	var left_storey := _proposal_storey_for_cell(left_proposal, left_cell)
	var right_storey := _proposal_storey_for_cell(right_proposal, right_cell)
	var left_can_break := left_storey > 0 and posmod(left_storey, 2) == 0
	var right_can_break := right_storey > 0 and posmod(right_storey, 2) == 0
	if not left_can_break and not right_can_break:
		return {"candidates": out}
	var deltas: Array[Vector2i] = [Vector2i.ZERO, Vector2i.RIGHT,
		Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
	var forced_fit_count := 0
	var body_fit_count := 0
	var route_cover_count := 0
	var seen: Dictionary = {}
	for left_delta: Vector2i in deltas:
		if left_delta != Vector2i.ZERO and left_block <= 0:
			continue
		var left_state := _cached_forced_block_state(forced_block_cache, grid,
			left_proposal, left_block, left_delta)
		if not bool(left_state.fits):
			continue
		var left_plate := left_state.cells as Dictionary
		for right_delta: Vector2i in deltas:
			if left_delta == Vector2i.ZERO and right_delta == Vector2i.ZERO:
				continue
			if not (left_can_break and left_delta != Vector2i.ZERO) \
					and not (right_can_break and right_delta != Vector2i.ZERO):
				continue
			if right_delta != Vector2i.ZERO and right_block <= 0:
				continue
			var right_state := _cached_forced_block_state(forced_block_cache,
				grid, right_proposal, right_block, right_delta)
			if not bool(right_state.fits):
				continue
			forced_fit_count += 1
			var right_plate := right_state.cells as Dictionary
			if _sets_overlap(left_plate, right_plate):
				continue
			var shifted_left := left_endpoint.duplicate(true)
			shifted_left["cell"] = left_cell + Vector3i(left_delta.x, 0,
				left_delta.y)
			var shifted_right := right_endpoint.duplicate(true)
			shifted_right["cell"] = right_cell + Vector3i(right_delta.x, 0,
				right_delta.y)
			var reservations := _cached_corner_skywalk_reservations(
				corner_reservation_cache, left, right, shifted_left,
				shifted_right, program, public_air)
			for reservation: Dictionary in reservations:
				var body := reservation.reserved_cells as Dictionary
				var clearance := reservation.visual_clearance_cells as Dictionary
				if not _skywalk_body_fits_grid(grid, body) \
						or not _skywalk_clearance_fits_grid(grid, clearance) \
						or not _skywalk_clearance_fits_protected(clearance,
							protected_owners) \
						or _sets_overlap(body, left_plate) \
						or _sets_overlap(body, right_plate):
					continue
				body_fit_count += 1
				var lower_cover := _lower_public_cover(body, public_air)
				if lower_cover < 2:
					continue
				route_cover_count += 1
				var endpoint_pair_key := _skywalk_endpoint_pair_key(reservation)
				var construction_key := _skywalk_construction_key(reservation)
				var unique_key := "%s/%s" % [endpoint_pair_key, construction_key]
				if seen.has(unique_key):
					continue
				seen[unique_key] = true
				var blockers := _skywalk_blocker_count(clearance,
					protected_owners, {left.stable_id: true,
						right.stable_id: true})
				var forced: Dictionary = {
					left.stable_id: {left_block: left_delta},
					right.stable_id: {right_block: right_delta},
				}
				var priority_cells: Dictionary = {}
				for value: Variant in left_plate.keys():
					priority_cells[value] = left.stable_id
				for value: Variant in right_plate.keys():
					priority_cells[value] = right.stable_id
				reservation["owner_parcel_ids"] = [left.stable_id,
					right.stable_id]
				var corner_origin := reservation.origin as Vector3i
				out.append({"reservation": reservation, "body": body,
					"clearance": clearance,
					"forced_offsets": forced, "priority_cells": priority_cells,
					"pair_key": "%s|%s" % [left.stable_id, right.stable_id],
					"endpoint_pair_key": endpoint_pair_key,
					"blocker_count": blockers, "lower_cover": lower_cover,
					"tie": posmod(Helper._mix64(world_seed \
						^ String(left.stable_id).hash() \
						^ String(right.stable_id).hash() \
						^ left_delta.x * 0x45d9f3b \
						^ left_delta.y * 0x27d4eb2d \
						^ right_delta.x * 0x165667b1 \
						^ right_delta.y * 0x1b873593 \
						^ corner_origin.x * 31 ^ corner_origin.z * 47), 1000003)})
	return {"candidates": out,
		"upper_pair_count": int(left_block > 0 or right_block > 0),
		"forced_fit_count": forced_fit_count,
		"body_fit_count": body_fit_count,
		"route_cover_count": route_cover_count}


static func _cached_forced_block_state(cache: Dictionary,
		grid: WarrenSpatialGrid, proposal: Dictionary, block: int,
		offset: Vector2i) -> Dictionary:
	var key := "%s/b%d/%d:%d" % [StringName(proposal.stable_id), block,
		offset.x, offset.y]
	if cache.has(key):
		return cache[key] as Dictionary
	var cells := _forced_block_cells(proposal, block, offset)
	var state := {"fits": _forced_block_fits(grid, proposal, block, offset),
		"cells": cells}
	cache[key] = state
	return state


static func _cached_corner_skywalk_reservations(cache: Dictionary,
		left: WarrenBuildingParcel, right: WarrenBuildingParcel,
		left_endpoint: Dictionary, right_endpoint: Dictionary,
		program: SettlementFabricProgram, public_air: Dictionary) \
		-> Array[Dictionary]:
	var key := "%s|%s/%s|%s" % [left.stable_id, right.stable_id,
		_skywalk_endpoint_part(left_endpoint),
		_skywalk_endpoint_part(right_endpoint)]
	if not cache.has(key):
		cache[key] = _raw_corner_skywalk_reservations(left, right,
			left_endpoint, right_endpoint, program, public_air)
	var out: Array[Dictionary] = []
	for value: Variant in cache[key] as Array:
		out.append((value as Dictionary).duplicate(true))
	return out


static func _skywalk_endpoint_part(endpoint: Dictionary) -> String:
	var cell := endpoint.cell as Vector3i
	var facing := endpoint.facing as Vector3i
	return "%d:%d:%d/%d:%d:%d" % [cell.x, cell.y, cell.z,
		facing.x, facing.y, facing.z]


static func _raw_corner_skywalk_reservations(left: WarrenBuildingParcel,
		right: WarrenBuildingParcel, left_endpoint: Dictionary,
		right_endpoint: Dictionary, program: SettlementFabricProgram,
		public_air: Dictionary) -> Array[Dictionary]:
	return _raw_corner_skywalks_between_endpoints(left_endpoint,
		right_endpoint, left.stable_id, right.stable_id, program, public_air)


static func _raw_corner_skywalks_between_endpoints(left_endpoint: Dictionary,
		right_endpoint: Dictionary, left_owner_id: StringName,
		right_owner_id: StringName, program: SettlementFabricProgram,
		public_air: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var left_cell := left_endpoint.cell as Vector3i
	var right_cell := right_endpoint.cell as Vector3i
	var left_facing := left_endpoint.facing as Vector3i
	var right_facing := right_endpoint.facing as Vector3i
	if left_cell.y != right_cell.y \
			or left_facing.x * right_facing.x \
				+ left_facing.z * right_facing.z != 0:
		return out
	var corner_recipe := program.recipe(&"skywalk.corner.orange")
	if corner_recipe == null:
		return out
	var seen: Dictionary = {}
	for corner_yaw in 4:
		var left_socket := WarrenAssetCompiler._socket_facing(corner_recipe,
			-left_facing, corner_yaw)
		var right_socket := WarrenAssetCompiler._socket_facing(corner_recipe,
			-right_facing, corner_yaw)
		if left_socket.is_empty() or right_socket.is_empty() \
				or left_socket.id == right_socket.id:
			continue
		for left_distance: int in [3, 5, 7]:
			var desired_left: Vector3i = left_cell \
				+ left_facing * left_distance
			var corner_origin: Vector3i = desired_left \
				- FabricRecipe.transform_cell(
				left_socket.cell as Vector3i, Vector3i.ZERO, corner_yaw)
			var right_corner_cell := FabricRecipe.transform_cell(
				right_socket.cell as Vector3i, corner_origin, corner_yaw)
			var right_delta := right_corner_cell - right_cell
			var right_distance: int = right_delta.x * right_facing.x \
				+ right_delta.z * right_facing.z
			if right_distance not in [3, 5, 7] \
					or right_delta != right_facing * right_distance:
				continue
			var left_recipe_id := WarrenAssetCompiler._cantilever_recipe(
				(left_distance - 1) / 2)
			var right_recipe_id := WarrenAssetCompiler._cantilever_recipe(
				(right_distance - 1) / 2)
			var left_recipe := program.recipe(left_recipe_id)
			var right_recipe := program.recipe(right_recipe_id)
			var left_yaw := WarrenAssetCompiler._yaw_for_facing(Vector3i.LEFT,
				-left_facing)
			var right_yaw := WarrenAssetCompiler._yaw_for_facing(Vector3i.LEFT,
				right_facing)
			if left_recipe == null or right_recipe == null \
					or left_yaw < 0 or right_yaw < 0:
				continue
			var left_origin := WarrenAssetCompiler._attached_origin(left_recipe,
				&"room.west", left_yaw, left_cell, left_facing)
			var right_corner_facing := FabricRecipe.transform_direction(
				right_socket.facing as Vector3i, corner_yaw)
			var right_origin := WarrenAssetCompiler._attached_origin(right_recipe,
				&"room.west", right_yaw, right_corner_cell,
				right_corner_facing)
			var components: Array[Dictionary] = [
				{"recipe_id": left_recipe_id, "origin": left_origin,
					"yaw_quarters": left_yaw},
				{"recipe_id": &"skywalk.corner.orange", "origin": corner_origin,
					"yaw_quarters": corner_yaw},
				{"recipe_id": right_recipe_id, "origin": right_origin,
					"yaw_quarters": right_yaw},
			]
			var reservation := WarrenAssetCompiler._component_reservation(
				components, program, public_air)
			if reservation.is_empty():
				continue
			reservation["visual_clearance_cells"] = \
				_skywalk_visual_clearance_cells(components, program)
			reservation["kind"] = &"corner"
			reservation["recipe_id"] = &"skywalk.corner.orange"
			reservation["origin"] = corner_origin
			reservation["yaw_quarters"] = corner_yaw
			var left_record := left_endpoint.duplicate(true)
			left_record["owner_id"] = left_owner_id
			var right_record := right_endpoint.duplicate(true)
			right_record["owner_id"] = right_owner_id
			reservation["owner_endpoints"] = [left_record, right_record]
			var key := _skywalk_construction_key(reservation)
			if seen.has(key):
				continue
			seen[key] = true
			out.append(reservation)
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
	var out: Dictionary = {}
	var cell_size := FabricRecipe.CELL_SIZE
	var half := cell_size * 0.5
	for component: Dictionary in components:
		var recipe := program.recipe(StringName(component.recipe_id))
		if recipe == null:
			return {}
		var bounds := FabricRecipe.lattice_transform(
			component.origin as Vector3i, int(component.yaw_quarters)) \
			* recipe.local_clearance_bounds
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
						+ Vector3(-half, 0.0, -half),
						Vector3.ONE * cell_size)
					if SettlementFabricPlan._aabb_overlaps_volume(bounds,
							cell_bounds):
						out[cell] = true
	return out


static func _skywalk_endpoint_owner_set(reservation: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for owner_value: Variant in reservation.get("owner_parcel_ids", []):
		out[StringName(owner_value)] = true
	return out


static func _stationary_skywalk_candidates(grid: WarrenSpatialGrid,
		raw: Dictionary, left: WarrenBuildingParcel,
		right: WarrenBuildingParcel, left_proposal: Dictionary,
		right_proposal: Dictionary, left_endpoint: Dictionary,
		right_endpoint: Dictionary, left_block: int, right_block: int,
		protected_owners: Dictionary, public_air: Dictionary,
		world_seed: int) -> Array[Dictionary]:
	## Keep the exact connector/endpoints fixed and move the composition block
	## immediately below one endpoint. This is legal only when the endpoint is
	## the first storey of block 2 or higher; its floorplate then differs from the
	## actual storey beneath without shifting terrain-bearing mass.
	var out: Array[Dictionary] = []
	var body := raw.reserved_cells as Dictionary
	var clearance := raw.visual_clearance_cells as Dictionary
	if not _skywalk_body_fits_grid(grid, body) \
			or not _skywalk_clearance_fits_grid(grid, clearance) \
			or not _skywalk_clearance_fits_protected(clearance,
				protected_owners):
		return out
	var lower_cover := _lower_public_cover(body, public_air)
	if lower_cover < 2:
		return out
	var facing := left_endpoint.facing as Vector3i
	var perpendicular := Vector3i(-facing.z, 0, facing.x)
	for side: Dictionary in [
		{"parcel": left, "proposal": left_proposal,
			"endpoint": left_endpoint, "block": left_block,
			"other_parcel": right, "other_block": right_block},
		{"parcel": right, "proposal": right_proposal,
			"endpoint": right_endpoint, "block": right_block,
			"other_parcel": left, "other_block": left_block},
	]:
		var block := int(side.block)
		var storey := _proposal_storey_for_cell(side.proposal as Dictionary,
			(side.endpoint as Dictionary).cell as Vector3i)
		if block < 2 or storey != block * 2:
			continue
		for sign_value in [-1, 1]:
			var delta3 := perpendicular * int(sign_value)
			var delta := Vector2i(delta3.x, delta3.z)
			var previous_block := block - 1
			if not _forced_block_fits(grid, side.proposal as Dictionary,
					previous_block, delta):
				continue
			var shifted_lower := _forced_block_cells(side.proposal as Dictionary,
				previous_block, delta)
			if _sets_overlap(body, shifted_lower):
				continue
			var owner := side.parcel as WarrenBuildingParcel
			var other := side.other_parcel as WarrenBuildingParcel
			var forced: Dictionary = {
				owner.stable_id: {previous_block: delta, block: Vector2i.ZERO},
				other.stable_id: {int(side.other_block): Vector2i.ZERO},
			}
			var priority_cells: Dictionary = {}
			for value: Variant in shifted_lower.keys():
				priority_cells[value] = owner.stable_id
			var blockers := _skywalk_blocker_count(clearance, protected_owners,
				{left.stable_id: true, right.stable_id: true})
			var reservation := raw.duplicate(true)
			reservation["owner_parcel_ids"] = [left.stable_id,
				right.stable_id]
			var endpoint_pair_key := _skywalk_endpoint_pair_key(reservation)
			out.append({"reservation": reservation, "body": body,
				"clearance": clearance,
				"forced_offsets": forced, "priority_cells": priority_cells,
				"pair_key": "%s|%s" % [left.stable_id, right.stable_id],
				"endpoint_pair_key": endpoint_pair_key,
				"blocker_count": blockers, "lower_cover": lower_cover,
				"tie": posmod(Helper._mix64(world_seed \
					^ String(left.stable_id).hash() \
					^ String(right.stable_id).hash() \
					^ owner.stable_id.hash() ^ int(sign_value) * 0x27d4eb2d),
					1000003)})
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


static func _raw_straight_skywalk_reservation(left: WarrenBuildingParcel,
		right: WarrenBuildingParcel, left_endpoint: Dictionary,
		right_endpoint: Dictionary, program: SettlementFabricProgram,
		public_air: Dictionary) -> Dictionary:
	if (left_endpoint.cell as Vector3i).y != (right_endpoint.cell as Vector3i).y \
			or (left_endpoint.facing as Vector3i) \
				!= -(right_endpoint.facing as Vector3i):
		return {}
	var forward := left_endpoint.facing as Vector3i
	var delta := (right_endpoint.cell as Vector3i) \
		- (left_endpoint.cell as Vector3i)
	var distance: int = delta.x * forward.x + delta.z * forward.z
	if distance < 3 or distance > 7 or posmod(distance, 2) != 1 \
			or delta != forward * distance:
		return {}
	var segments := (distance - 1) / 2
	var recipe_id := &"skywalk.3.blue" if segments == 1 \
		else &"skywalk.6.orange" if segments == 2 else &"skywalk.9.blue"
	var recipe := program.recipe(recipe_id)
	var yaw := -1
	for candidate_yaw in 4:
		if FabricRecipe.transform_direction(Vector3i.LEFT, candidate_yaw) \
				== -forward:
			yaw = candidate_yaw
			break
	if recipe == null or yaw < 0:
		return {}
	var west := recipe.socket(&"room.west")
	if west.is_empty():
		return {}
	var origin := (left_endpoint.cell as Vector3i) + forward \
		- FabricRecipe.transform_cell(west.cell as Vector3i, Vector3i.ZERO, yaw)
	var reserved: Dictionary = {}
	for source_cells: Array[Vector3i] in [recipe.solid_cells,
			recipe.headroom_cells]:
		for local: Vector3i in source_cells:
			var cell := FabricRecipe.transform_cell(local, origin, yaw)
			if public_air.has(cell):
				return {}
			reserved[cell] = true
	var components: Array[Dictionary] = [{"recipe_id": recipe_id,
		"origin": origin, "yaw_quarters": yaw}]
	return {"kind": &"straight", "recipe_id": recipe_id,
		"origin": origin, "yaw_quarters": yaw,
		"components": components, "reserved_cells": reserved,
		"visual_bounds": [FabricRecipe.lattice_transform(origin, yaw) \
			* recipe.local_clearance_bounds] as Array[AABB],
		"visual_clearance_cells": _skywalk_visual_clearance_cells(components,
			program),
		"owner_endpoints": [
			{"slot_signature": left.slot_signature(),
				"cell": left_endpoint.cell, "facing": left_endpoint.facing},
			{"slot_signature": right.slot_signature(),
				"cell": right_endpoint.cell, "facing": right_endpoint.facing},
		]}


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


static func _translate_skywalk_reservation(source: Dictionary,
		delta: Vector3i) -> Dictionary:
	var out := source.duplicate(true)
	var cells: Dictionary = {}
	for value: Variant in (source.reserved_cells as Dictionary).keys():
		cells[(value as Vector3i) + delta] = true
	out["reserved_cells"] = cells
	var clearance: Dictionary = {}
	for value: Variant in (source.get("visual_clearance_cells", {}) \
			as Dictionary).keys():
		clearance[(value as Vector3i) + delta] = true
	out["visual_clearance_cells"] = clearance
	var visual_bounds: Array[AABB] = []
	for bounds_value: Variant in source.get("visual_bounds", []):
		var bounds := bounds_value as AABB
		bounds.position += Vector3(delta) * FabricRecipe.CELL_SIZE
		visual_bounds.append(bounds)
	out["visual_bounds"] = visual_bounds
	var endpoints: Array[Dictionary] = []
	for value: Variant in source.get("owner_endpoints", []):
		var endpoint := (value as Dictionary).duplicate(true)
		endpoint["cell"] = (endpoint.cell as Vector3i) + delta
		endpoints.append(endpoint)
	out["owner_endpoints"] = endpoints
	var components: Array[Dictionary] = []
	for value: Variant in source.get("components", []):
		var component := (value as Dictionary).duplicate(true)
		component["origin"] = (component.origin as Vector3i) + delta
		components.append(component)
	out["components"] = components
	out["origin"] = (source.get("origin", Vector3i()) as Vector3i) + delta
	return out


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


static func _skywalk_selection_preserves_endpoint_rooms(
		grid: WarrenSpatialGrid, volume: WarrenVolumePlan,
		selected: Array[Dictionary],
		proposals: Array[Dictionary], protected_owners: Dictionary,
		world_seed: int) -> bool:
	## Validate a whole connector set against the same priority field and exact
	## composition solver used by `_partition_rooms`. Individual endpoint blocks
	## can each fit while a third feature displaces the rest of one endpoint
	## parcel; accepting that set would create a one-ended skywalk after packing.
	_last_skywalk_selection_failure = ""
	var trial_owners := protected_owners.duplicate(true)
	var forced_by_parcel: Dictionary = {}
	for candidate_index in selected.size():
		var candidate := selected[candidate_index]
		for cell_value: Variant in (candidate.priority_cells as Dictionary).keys():
			trial_owners[cell_value] = {
				StringName((candidate.priority_cells as Dictionary)[cell_value]): true,
			}
		var reservation_owner := StringName("spatial.skywalk.trial.%02d" \
			% candidate_index)
		var body := candidate.body as Dictionary
		for cell_value: Variant in body.keys():
			if not trial_owners.has(cell_value):
				trial_owners[cell_value] = {}
			(trial_owners[cell_value] as Dictionary)[reservation_owner] = true
		var reservation := candidate.reservation as Dictionary
		var allowed_endpoint_owners := _skywalk_endpoint_owner_set(reservation)
		for cell_value: Variant in (candidate.get("clearance", body) \
				as Dictionary).keys():
			if body.has(cell_value):
				continue
			if not trial_owners.has(cell_value):
				trial_owners[cell_value] = {}
			(trial_owners[cell_value] as Dictionary)[reservation_owner] = \
				allowed_endpoint_owners
		for parcel_value: Variant in (candidate.forced_offsets \
				as Dictionary).keys():
			var parcel_id := StringName(parcel_value)
			if not forced_by_parcel.has(parcel_id):
				forced_by_parcel[parcel_id] = {}
			var blocks := (candidate.forced_offsets as Dictionary)[parcel_id] \
				as Dictionary
			for block_value: Variant in blocks.keys():
				var block := int(block_value)
				var wanted := blocks[block_value] as Vector2i
				if (forced_by_parcel[parcel_id] as Dictionary).has(block) \
						and (forced_by_parcel[parcel_id] \
							as Dictionary)[block] != wanted:
					_last_skywalk_selection_failure = "forced-offset conflict"
					return false
				(forced_by_parcel[parcel_id] as Dictionary)[block] = wanted
	var proposal_by_id: Dictionary = {}
	var solved_offsets_by_parcel: Dictionary = {}
	for proposal: Dictionary in proposals:
		var parcel := proposal.parcel as WarrenBuildingParcel
		proposal_by_id[parcel.stable_id] = proposal
	var endpoint_parcel_ids := forced_by_parcel.duplicate()
	var required_parcel_ids := forced_by_parcel.duplicate()
	# Named feature-clearance allowances identify structural endpoint parcels.
	# The preplanned market has no shifted block, so it would otherwise fall out
	# of this skywalk-only forced-offset set even though its exact backing socket
	# is just as mandatory as either end of a bridge.
	for owners_value: Variant in trial_owners.values():
		for allowance_value: Variant in (owners_value as Dictionary).values():
			if not allowance_value is Dictionary:
				continue
			for parcel_value: Variant in (allowance_value as Dictionary).keys():
				var parcel_id := StringName(parcel_value)
				if _protected_owner_is_feature(parcel_id):
					continue
				endpoint_parcel_ids[parcel_id] = true
				required_parcel_ids[parcel_id] = true
	var court_floors: Dictionary = {}
	for macro: Vector3i in volume.courtyard_cells:
		for floor_cell: Vector3i in _fine_square(macro):
			court_floors[floor_cell] = true
	var court_neighbor_cells := _courtyard_neighbor_cells(court_floors)
	for proposal: Dictionary in proposals:
		var parcel := proposal.parcel as WarrenBuildingParcel
		for occupied: Vector3i in StaggeredFabricCompiler \
				.proposal_occupied_cells(proposal):
			if court_neighbor_cells.has(occupied):
				required_parcel_ids[parcel.stable_id] = true
				break
	for parcel_value: Variant in required_parcel_ids.keys():
		var parcel_id := StringName(parcel_value)
		var proposal := proposal_by_id.get(parcel_id, {}) as Dictionary
		if proposal.is_empty():
			_last_skywalk_selection_failure = "missing endpoint proposal"
			return false
		var parcel := proposal.parcel as WarrenBuildingParcel
		var storeys := int(proposal.storeys)
		var origin := proposal.origin as Vector3i
		var threshold := WarrenParcelConstruction.threshold_cell(parcel)
		var addressed_storey := clampi(floori(float(threshold.y - origin.y) \
			/ float(WarrenSpatialGrid.STOREY_CELLS)), 0, storeys - 1)
		var forced: Dictionary = {0: Vector2i.ZERO,
			floori(float(addressed_storey) / 2.0): Vector2i.ZERO}
		for court_block_value: Variant in _proposal_court_fixed_blocks(proposal,
				court_neighbor_cells).keys():
			forced[int(court_block_value)] = Vector2i.ZERO
		for block_value: Variant in (forced_by_parcel.get(parcel_id, {}) \
				as Dictionary).keys():
			var block := int(block_value)
			var wanted := (forced_by_parcel[parcel_id] \
				as Dictionary)[block] as Vector2i
			if forced.has(block) and forced[block] != wanted:
				_last_skywalk_selection_failure = "addressed-block offset conflict"
				return false
			forced[block] = wanted
		var solved_offsets := _composition_offsets(grid,
			_proposal_base_plate(proposal), origin.y, storeys, trial_owners,
			parcel_id, world_seed, forced)
		if solved_offsets.is_empty():
			if not endpoint_parcel_ids.has(parcel_id):
				continue
			_last_skywalk_selection_failure = "endpoint composition failed: %s" % \
				parcel_id
			return false
		solved_offsets_by_parcel[parcel_id] = solved_offsets
	# Court enclosure is owned by the separately selected occupied cantilever
	# room plus the two fixed parcel walls. Independent skywalks are therefore
	# judged only on their own endpoints and 3D circulation here; the final court
	# transaction re-proves its real PRIVATE_VOLUME sides after all features land.
	for candidate: Dictionary in selected:
		var reservation := candidate.reservation as Dictionary
		var owner_ids := reservation.get("owner_parcel_ids", []) as Array
		var endpoints := reservation.get("owner_endpoints", []) as Array
		var offset_endpoint_count := 0
		for endpoint_index in mini(owner_ids.size(), endpoints.size()):
			var parcel_id := StringName(owner_ids[endpoint_index])
			if String(parcel_id).begins_with("spatial.feature.landmark."):
				offset_endpoint_count += 1
				continue
			var proposal := proposal_by_id.get(parcel_id, {}) as Dictionary
			var offsets := solved_offsets_by_parcel.get(parcel_id, []) \
				as Array[Vector2i]
			if proposal.is_empty() or offsets.is_empty():
				_last_skywalk_selection_failure = "endpoint solve missing after beam"
				return false
			var endpoint := endpoints[endpoint_index] as Dictionary
			var storey := _proposal_storey_for_cell(proposal,
				endpoint.cell as Vector3i)
			if storey <= 0:
				continue
			var current_block := storey / 2
			var lower_block := (storey - 1) / 2
			if current_block < offsets.size() and lower_block < offsets.size() \
					and offsets[current_block] != offsets[lower_block]:
				offset_endpoint_count += 1
		if offset_endpoint_count < 1:
			_last_skywalk_selection_failure = "no exact floorplate break"
			return false
	_last_skywalk_selection_failure = ""
	return true


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


static func _annotate_skywalk_courtyard_side_masks(volume: WarrenVolumePlan,
		candidates: Array[Dictionary]) -> void:
	var floors := _courtyard_floor_cells(volume)
	for candidate: Dictionary in candidates:
		candidate["courtyard_side_mask"] = \
			_courtyard_address_side_mask_from_occupied(floors,
				candidate.body as Dictionary)


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


static func _courtyard_addressing_candidate_count(candidates: Array[Dictionary],
		parcel_side_mask: int) -> int:
	var count := 0
	for candidate: Dictionary in candidates:
		count += int(_skywalk_selection_addresses_courtyard(
			[candidate] as Array[Dictionary], parcel_side_mask))
	return count


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


static func _courtyard_address_side_count_from_occupied(
		court_floors: Dictionary, occupied: Dictionary) -> int:
	var side_mask := _courtyard_address_side_mask_from_occupied(court_floors,
		occupied)
	var side_count := 0
	for bit in 4:
		side_count += int((side_mask & (1 << bit)) != 0)
	return side_count


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


static func _nested_dictionary_entry_count(values: Dictionary) -> int:
	var out := 0
	for nested_value: Variant in values.values():
		out += (nested_value as Dictionary).size()
	return out


static func _solved_courtyard_address_side_count(court_floors: Dictionary,
		solved_offsets_by_parcel: Dictionary,
		proposal_by_id: Dictionary,
		selected_skywalks: Array[Dictionary] = []) -> int:
	var occupied: Dictionary = {}
	for parcel_value: Variant in solved_offsets_by_parcel.keys():
		var parcel_id := StringName(parcel_value)
		var proposal := proposal_by_id[parcel_id] as Dictionary
		var offsets := solved_offsets_by_parcel[parcel_id] as Array[Vector2i]
		var origin := proposal.origin as Vector3i
		for cell: Vector3i in _segment_cells(_proposal_base_plate(proposal),
				origin.y, offsets, 0, int(proposal.storeys)):
			occupied[cell] = parcel_id
	for candidate: Dictionary in selected_skywalks:
		for cell_value: Variant in (candidate.body as Dictionary).keys():
			occupied[cell_value] = StringName("occupied.court.connector")
	return _courtyard_address_side_count_from_occupied(court_floors, occupied)


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
		var start := posmod(Helper._mix64(world_seed ^ parcel_hash \
			^ block * 0x45d9f3b), directions.size())
		for direction_offset in directions.size():
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
		if chosen.x == 2147483647 and _plate_fits(grid, base_plate, previous,
				origin_y, start_storey, end_storey, protected_owners, parcel_id):
			chosen = previous
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
				if not grid.contains(cell) \
						or grid.use_at(cell) != WarrenSpatialGrid.Use.ALLOCATABLE:
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


static func _composition_segments(offsets: Array[Vector2i],
		storeys: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var start_storey := 0
	for block in range(1, offsets.size()):
		if offsets[block] == offsets[block - 1]:
			out.append(Vector2i(start_storey, block * 2))
			start_storey = block * 2
	out.append(Vector2i(start_storey, storeys))
	return out


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


static func _backfill_residual_rooms(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan, buildings: Array[WarrenBuildingVolume],
		supports: WarrenSupportGraph, required_supports: Array[StringName],
		terrain_support_ids: Array[StringName],
		support_edges: Array[Dictionary],
		protected_owners: Dictionary) -> Dictionary:
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
	var kind_counts: Dictionary = {}
	var added_count := 0
	var added_cells := 0
	while added_count < MAX_RESIDUAL_BACKFILL_BUILDINGS:
		var best: Dictionary = {}
		for origin: Vector3i in grid.cells_with_use(
				WarrenSpatialGrid.Use.ALLOCATABLE):
			for kind: StringName in WarrenRoomStamp.KINDS:
				if int(kind_counts.get(kind, 0)) \
						>= MAX_RESIDUAL_BACKFILL_PER_KIND:
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
						int(kind_counts.get(kind, 0)))
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
	return {"failed": false, "building_count": added_count,
		"private_cell_count": added_cells, "kind_counts": kind_counts,
		"overhead_route_cell_count": initial_uncovered_route_count \
			- uncovered_route_floors.size(),
		"frontage_side_count": initial_uncovered_frontage_count \
			- uncovered_frontage_sides.size()}


static func _residual_room_candidate(grid: WarrenSpatialGrid,
		massif: WarrenMassif, origin: Vector3i, kind: StringName, yaw: int,
		building_by_id: Dictionary, building_by_cell: Dictionary,
		roof_clearance: Dictionary, roof_eave_halo: Dictionary,
		protected_owners: Dictionary,
		route_floor_by_overhead_cell: Dictionary,
		uncovered_route_floors: Dictionary,
		frontage_side_by_private_cell: Dictionary,
		uncovered_frontage_sides: Dictionary,
		world_seed: int, existing_kind_count: int) -> Dictionary:
	var cells := WarrenRoomStamp.expected_private_cells(kind, origin, yaw)
	if cells.is_empty():
		return {}
	var footprint: Dictionary = {}
	for cell: Vector3i in cells:
		if grid.use_at(cell) != WarrenSpatialGrid.Use.ALLOCATABLE \
				or roof_eave_halo.has(cell) \
				or _residual_feature_protected(grid, cell, protected_owners):
			return {}
		footprint[Vector2i(cell.x, cell.z)] = true
	var candidate_roof_clearance: Dictionary = {}
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
						return {}
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
	if not addressed and (access_parent_id.is_empty() \
			or int(access_counts[access_parent_id]) < 2):
		return {}
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
	var support_parent_id := _largest_contact_owner(support_counts)
	if not terrain_bearing and (support_parent_id.is_empty() \
			or int(support_counts[support_parent_id]) < required_bearing):
		return {}
	var support_parent_cell := Vector3i(2147483647, 2147483647, 2147483647) \
		if terrain_bearing else support_cell_by_owner[support_parent_id] as Vector3i
	var overhead_route_floor_set: Dictionary = {}
	for cell: Vector3i in cells:
		for floor_cell: Vector3i in route_floor_by_overhead_cell.get(cell,
				[] as Array[Vector3i]):
			if uncovered_route_floors.has(floor_cell):
				overhead_route_floor_set[floor_cell] = true
	var overhead_route_floors: Array[Vector3i] = []
	overhead_route_floors.assign(overhead_route_floor_set.keys())
	overhead_route_floors.sort_custom(_cell_less)
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
	var tie := posmod(Helper._mix64(world_seed ^ origin.x * 73856093 \
		^ origin.y * 83492791 ^ origin.z * 19349663 ^ kind.hash() ^ yaw * 97),
		1000003)
	var score := float(overhead_route_floors.size() \
			* RESIDUAL_OVERHEAD_ROUTE_CELL_SCORE \
		+ frontage_side_keys.size() * RESIDUAL_FRONTAGE_SIDE_SCORE \
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
		"overhead_route_floors": overhead_route_floors,
		"frontage_side_keys": frontage_side_keys,
		"score": score,
		"key": "%s/%d:%d:%d/r%d" % [String(kind), origin.x, origin.y,
			origin.z, yaw]}


static func _residual_authored_threshold(kind: StringName, origin: Vector3i,
		yaw: int) -> Vector3i:
	var local := Vector3i.ZERO
	match kind:
		&"tower":
			local = Vector3i(0, 0, 0)
		&"slim":
			local = Vector3i(0, 0, 1)
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
		cell: Vector3i, protected_owners: Dictionary) -> bool:
	var bits := grid.reservation_bits_at(cell)
	if (bits & (WarrenSpatialGrid.Reservation.FEATURE \
			| WarrenSpatialGrid.Reservation.VISUAL_CLEARANCE \
			| WarrenSpatialGrid.Reservation.PRIVATE_CONNECTION \
			| WarrenSpatialGrid.Reservation.PUBLIC_CLEARANCE \
			| WarrenSpatialGrid.Reservation.DAYLIGHT)) != 0:
		return true
	for owner_value: Variant in (protected_owners.get(cell, {}) \
			as Dictionary).keys():
		var owner := String(owner_value)
		if owner.begins_with("spatial.feature.") \
				or owner.begins_with("spatial.skywalk.reserve."):
			return true
	return false


static func _residual_roof_feature(kind: StringName, origin: Vector3i,
		world_seed: int) -> int:
	var phase := posmod(world_seed ^ origin.x * 73856093 \
		^ origin.y * 83492791 ^ origin.z * 19349663, 6)
	if kind == &"long":
		return [1, 2, 4, 5, 1, 2][phase]
	if kind == &"building":
		return 1 if phase in [0, 1] else 2 if phase in [2, 3] \
			else 3 if phase == 4 else 0
	if kind in [&"tower", &"slim"]:
		return 3 if phase == 0 else 0
	return 0


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
