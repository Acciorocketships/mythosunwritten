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

static var last_failure := ""
static var last_diagnostic: Dictionary = {}
static var last_preplan_skywalk_diagnostic: Dictionary = {}


static func solve(world_seed: int,
		ground_bands: Dictionary = {},
		construction_program: SettlementFabricProgram = null) -> WarrenSpatialPlan:
	last_failure = ""
	last_diagnostic = {}
	last_preplan_skywalk_diagnostic = {}
	if construction_program == null:
		last_failure = "volumetric feature search requires measured construction vocabulary"
		return null
	var frontier := WarrenTownSolver.mass_first_frontier(world_seed, ground_bands)
	if frontier.is_empty():
		last_failure = WarrenTownSolver.last_failure
		return null
	frontier.sort_custom(func(a: WarrenVolumePlan, b: WarrenVolumePlan) -> bool:
		return WarrenPublicRealmCarver.topology_score(a) \
			< WarrenPublicRealmCarver.topology_score(b))
	var failures := PackedStringArray()
	for volume: WarrenVolumePlan in frontier:
		for variant in MAX_PARTITION_VARIANTS:
			var plan := from_volume(volume, variant, construction_program)
			if plan != null:
				last_failure = ""
				return plan
			failures.append("%s/v%d: %s" % [String(volume.stable_id),
				variant, last_failure])
	last_failure = "no volumetric partition sealed: %s" % " | ".join(failures)
	return null


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
	var route_floors := _carve_public_volume(grid, volume)
	if route_floors.is_empty():
		return null
	var parcel_plan := WarrenTownSolver.partition_parcels(volume,
		partition_variant, construction_program)
	if parcel_plan == null:
		last_failure = WarrenTownSolver.last_partition_failure
		return null
	var partition := _partition_rooms(grid, volume, parcel_plan,
		construction_program)
	if partition.is_empty():
		return null
	var buildings := partition.buildings as Array[WarrenBuildingVolume]
	var supports := partition.supports as WarrenSupportGraph
	if buildings.size() < MIN_BUILDINGS:
		last_failure = "only %d volumetric buildings formed" % buildings.size()
		return null
	var features := WarrenSpatialFeatureSolver.solve(grid, volume, buildings,
		supports)
	if features.is_empty():
		last_failure = WarrenSpatialFeatureSolver.last_failure
		return null
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
	plan.audit["partition_variant"] = partition_variant
	plan.audit["room_stamp_count"] = int(partition.room_count)
	plan.audit["offset_composition_block_count"] = int(partition.offset_blocks)
	plan.audit["ownership_handoff_count"] = int(partition.handoffs)
	plan.audit["preplanned_skywalk_count"] = int(
		partition.preplanned_skywalk_count)
	plan.audit.merge(WarrenSpatialFeatureSolver.last_audit, true)
	last_diagnostic = plan.audit.duplicate(true)
	return plan


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
	for parcel: WarrenBuildingParcel in parcels.parcels:
		var proposal := WarrenParcelConstruction.proposal(parcel)
		if proposal.is_empty():
			continue
		proposal["parcel"] = parcel
		proposals.append(proposal)
	if proposals.is_empty():
		last_failure = "parcel seed produced no complete room proposals"
		return {}
	proposals.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.stable_id) < String(b.stable_id))
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
	# Select three measured straight links *before* upper composition blocks are
	# frozen. Each candidate shifts both endpoint blocks together by one fine
	# cell, creating a genuine floorplate break while preserving exact sockets.
	# Unrelated generic blocks must move around the reserved connector volume.
	var skywalk_plan := _preplan_spatial_skywalks(grid, volume, proposals,
		construction_program, protected_owners,
		WarrenSpatialFeatureSolver.TARGET_SKYWALKS)
	var skywalk_reservations := skywalk_plan.get("reservations", []) \
		as Array[Dictionary]
	if skywalk_reservations.size() < WarrenSpatialFeatureSolver.TARGET_SKYWALKS:
		last_failure = "pre-partition beam found only %d measured skywalk corridors (%s)" \
			% [skywalk_reservations.size(), last_preplan_skywalk_diagnostic]
		return {}
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
		for cell_value: Variant in (reservation.reserved_cells as Dictionary).keys():
			var cell := cell_value as Vector3i
			if not protected_owners.has(cell):
				protected_owners[cell] = {}
			(protected_owners[cell] as Dictionary)[reservation_owner] = true
	var forced_offsets_by_parcel := skywalk_plan.forced_offsets as Dictionary
	var buildings: Array[WarrenBuildingVolume] = []
	var supports := WarrenSupportGraph.new()
	var required_supports: Array[StringName] = []
	var room_count := 0
	var offset_blocks := 0
	var handoffs := 0
	for proposal: Dictionary in proposals:
		var parcel := proposal.parcel as WarrenBuildingParcel
		var storeys := int(proposal.storeys)
		var origin := proposal.origin as Vector3i
		var base_plate := _proposal_base_plate(proposal)
		if storeys <= 0 or base_plate.is_empty():
			continue
		# The storey containing the authored doorway is an immovable public
		# interface.  Offsetting that composition block would preserve the room
		# volume but strand its real threshold inside the old facade plane.
		var threshold := WarrenParcelConstruction.threshold_cell(parcel)
		var addressed_storey := clampi(floori(float(threshold.y - origin.y) \
			/ float(WarrenSpatialGrid.STOREY_CELLS)), 0, storeys - 1)
		var forced_offsets: Dictionary = {0: Vector2i.ZERO,
			floori(float(addressed_storey) / 2.0): Vector2i.ZERO}
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
		for offset: Vector2i in offsets:
			offset_blocks += int(offset != Vector2i.ZERO)
		var segments := _composition_segments(offsets, storeys)
		handoffs += maxi(0, segments.size() - 1)
		var segment_ids: Array[StringName] = []
		for segment_index in segments.size():
			segment_ids.append(StringName("spatial.%s.part%02d" % [
				StringName(parcel.stable_id), segment_index]))
		var threshold_segment := -1
		for segment_index in segments.size():
			var segment := segments[segment_index] as Vector2i
			if threshold.y >= origin.y + segment.x * WarrenSpatialGrid.STOREY_CELLS \
					and threshold.y < origin.y \
						+ segment.y * WarrenSpatialGrid.STOREY_CELLS:
				threshold_segment = segment_index
				break
		for segment_index in segments.size():
			var segment := segments[segment_index] as Vector2i
			var building_id := segment_ids[segment_index]
			var cells := _segment_cells(base_plate, origin.y, offsets,
				segment.x, segment.y)
			var assign := grid.begin_transaction(building_id)
			if not assign.require_use(cells,
					[WarrenSpatialGrid.Use.ALLOCATABLE] as Array[int]) \
					or not assign.assign_use(cells,
						WarrenSpatialGrid.Use.PRIVATE_VOLUME, building_id) \
					or not assign.commit():
				last_failure = "room segment %s rejected: %s" % [building_id,
					assign.last_rejection]
				return {}
			var building := WarrenBuildingVolume.new(building_id,
				origin.y + segment.x * WarrenSpatialGrid.STOREY_CELLS)
			if not building.add_private_cells(cells):
				last_failure = "could not assign private cells to %s" % building_id
				return {}
			for storey in range(segment.x, segment.y):
				var room_cells := _segment_cells(base_plate, origin.y, offsets,
					storey, storey + 1)
				var offset := offsets[storey / 2]
				var addressed := threshold.y >= origin.y \
					+ storey * WarrenSpatialGrid.STOREY_CELLS \
					and threshold.y < origin.y \
						+ (storey + 1) * WarrenSpatialGrid.STOREY_CELLS
				var room := WarrenRoomStamp.new(
					StringName("%s.room%02d" % [building_id,
						storey - segment.x]), parcel.stable_id,
					StringName(proposal.kind), origin + Vector3i(offset.x,
						storey * WarrenSpatialGrid.STOREY_CELLS, offset.y),
					int(proposal.yaw_quarters), storey, storey == 0,
					addressed, threshold if addressed else Vector3i(2147483647,
						2147483647, 2147483647),
					Vector3i(parcel.frontage_direction.x, 0,
						parcel.frontage_direction.y), int(proposal.roof_feature))
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
			if segment_index == 0:
				if not supports.mark_terrain_root(segment_ids[segment_index]):
					last_failure = "could not root %s" % segment_ids[segment_index]
					return {}
			elif not supports.add_edge(segment_ids[segment_index],
					segment_ids[segment_index - 1]):
				last_failure = "could not support %s" % segment_ids[segment_index]
				return {}
	if buildings.size() < MIN_BUILDINGS:
		last_failure = "room partition formed only %d buildings" % buildings.size()
		return {}
	if not supports.seal(required_supports):
		last_failure = "support DAG rejected: %s" % supports.last_rejection
		return {}
	return {"buildings": buildings, "supports": supports,
		"room_count": room_count, "offset_blocks": offset_blocks,
		"handoffs": handoffs,
		"preplanned_skywalk_count": skywalk_reservations.size()}


static func _proposal_base_plate(proposal: Dictionary) -> Dictionary:
	var origin := proposal.origin as Vector3i
	var out: Dictionary = {}
	for cell: Vector3i in StaggeredFabricCompiler.proposal_occupied_cells(
			proposal):
		if cell.y == origin.y:
			out[Vector2i(cell.x, cell.z)] = true
	return out


static func _preplan_spatial_skywalks(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan, proposals: Array[Dictionary],
		program: SettlementFabricProgram, protected_owners: Dictionary,
		target_count: int) -> Dictionary:
	## Bounded feature-set search over exact measured straight-link contracts.
	## Unlike the retired late detail pass, candidates may displace unrelated
	## generic rooms; the endpoint composition blocks and bridge void are fixed
	## before `_partition_rooms` commits any private volume.
	var parcels: Array[WarrenBuildingParcel] = []
	var proposal_by_slot: Dictionary = {}
	for proposal: Dictionary in proposals:
		var parcel := proposal.parcel as WarrenBuildingParcel
		parcels.append(parcel)
		proposal_by_slot[parcel.slot_signature()] = proposal
	var realm := WarrenVolumePublicRealmAdapter.from_volume(volume)
	if realm == null:
		return {}
	var public_air := realm.air_claims()
	var cache := WarrenAssetCompiler.massif_partition_asset_cache(parcels,
		volume.world_seed, program)
	if not bool(cache.get(&"enabled", false)):
		return {}
	var candidates: Array[Dictionary] = []
	var raw_count := 0
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
					var raw := _raw_straight_skywalk_reservation(left,
						right, left_endpoint, right_endpoint, program, public_air)
					if raw.is_empty():
						continue
					raw_count += 1
					var left_proposal := proposal_by_slot[left.slot_signature()] \
						as Dictionary
					var right_proposal := proposal_by_slot[right.slot_signature()] \
						as Dictionary
					var left_block := _proposal_block_for_cell(left_proposal,
						left_endpoint.cell as Vector3i)
					var right_block := _proposal_block_for_cell(right_proposal,
						right_endpoint.cell as Vector3i)
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
						if not _skywalk_body_fits_grid(grid, body):
							continue
						if _sets_overlap(body, left_plate) \
								or _sets_overlap(body, right_plate):
							continue
						body_fit_count += 1
						var lower_cover := _lower_public_cover(body, public_air)
						if lower_cover < 2:
							continue
						route_cover_count += 1
						var blockers := _skywalk_blocker_count(body,
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
						candidates.append({"reservation": shifted,
							"body": body, "forced_offsets": forced,
							"priority_cells": priority_cells,
							"pair_key": "%s|%s" % [left.stable_id,
								right.stable_id], "blocker_count": blockers,
							"lower_cover": lower_cover,
							"tie": posmod(Helper._mix64(volume.world_seed \
								^ String(left.stable_id).hash() \
								^ String(right.stable_id).hash() \
								^ int(sign_value) * 0x45d9f3b \
								^ (left_endpoint.cell as Vector3i).y * 17),
								1000003)})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.blocker_count) != int(b.blocker_count):
			return int(a.blocker_count) < int(b.blocker_count)
		if int(a.lower_cover) != int(b.lower_cover):
			return int(a.lower_cover) > int(b.lower_cover)
		return int(a.tie) < int(b.tie))
	# Three nested loops are a complete bounded beam for the current hard target.
	# Capping the ranked frontier prevents dense endpoint graphs from turning one
	# town into an unbounded detail search.
	var frontier_size := mini(candidates.size(), 64)
	var selected: Array[Dictionary] = []
	if target_count == 3:
		for first in frontier_size:
			for second in range(first + 1, frontier_size):
				if not _skywalk_candidates_compatible(candidates[first],
						candidates[second]):
					continue
				for third in range(second + 1, frontier_size):
					if _skywalk_candidates_compatible(candidates[first],
							candidates[third]) \
							and _skywalk_candidates_compatible(candidates[second],
								candidates[third]):
						selected = [candidates[first], candidates[second],
							candidates[third]] as Array[Dictionary]
						break
				if not selected.is_empty():
					break
			if not selected.is_empty():
				break
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
	for candidate: Dictionary in candidates:
		pair_keys[String(candidate.pair_key)] = true
	last_preplan_skywalk_diagnostic = {"raw_straight_count": raw_count,
		"upper_block_pair_count": upper_block_count,
		"forced_offset_fit_count": forced_fit_count,
		"body_fit_count": body_fit_count,
		"route_cover_count": route_cover_count,
		"compatible_candidate_count": candidates.size(),
		"distinct_pair_count": pair_keys.size(),
		"pair_keys": pair_keys.keys(),
		"selected_count": selected.size()}
	return {"reservations": reservations, "forced_offsets": forced_offsets,
		"priority_cells": priority_cells,
		"candidate_count": candidates.size()}


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
	if not _skywalk_body_fits_grid(grid, body):
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
			var blockers := _skywalk_blocker_count(body, protected_owners,
				{left.stable_id: true, right.stable_id: true})
			var reservation := raw.duplicate(true)
			reservation["owner_parcel_ids"] = [left.stable_id,
				right.stable_id]
			out.append({"reservation": reservation, "body": body,
				"forced_offsets": forced, "priority_cells": priority_cells,
				"pair_key": "%s|%s" % [left.stable_id, right.stable_id],
				"blocker_count": blockers, "lower_cover": lower_cover,
				"tie": posmod(Helper._mix64(world_seed \
					^ String(left.stable_id).hash() \
					^ String(right.stable_id).hash() \
					^ owner.stable_id.hash() ^ int(sign_value) * 0x27d4eb2d),
					1000003)})
	return out


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
	return {"kind": &"straight", "recipe_id": recipe_id,
		"origin": origin, "yaw_quarters": yaw,
		"components": [{"recipe_id": recipe_id, "origin": origin,
			"yaw_quarters": yaw}], "reserved_cells": reserved,
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
				WarrenSpatialGrid.Use.ALLOCATABLE]:
			return false
	return true


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
					if StringName(protected_id_value) != parcel_id:
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
	for storey in range(start_storey, end_storey):
		var offset := offsets[storey / 2]
		for column_value: Variant in base_plate.keys():
			var column := column_value as Vector2i
			for y_offset in WarrenSpatialGrid.STOREY_CELLS:
				out.append(Vector3i(column.x + offset.x,
					origin_y + storey * WarrenSpatialGrid.STOREY_CELLS + y_offset,
					column.y + offset.y))
	return out


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
