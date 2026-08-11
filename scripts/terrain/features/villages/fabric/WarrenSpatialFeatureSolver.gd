class_name WarrenSpatialFeatureSolver
extends RefCounted

## Commits topology-first composed features into the still-mutable fine grid.
## Each accepted feature owns one atomic reservation and, where appropriate,
## its exact private/structural cells and construction transform. Generic room
## and roof compilation may respond to these facts but never recreate them.
const TARGET_SKYWALKS := 3
const TARGET_PREFAB_LANDMARKS := 2
const MIN_TOWER_ANNEXES_PER_TALL_LINEAGE := 2
const TARGET_BALCONIES := 6
const MIN_BALCONY_BUILDINGS := 3
const MAX_BALCONIES_PER_BUILDING := 2
const TARGET_ROOM_OUTCROPPINGS := 6
const MIN_COURT_SIDE_COUNT := 3
const MIN_COURT_BELOW_ROUTE_CELLS := 4
const MIN_COURT_UPPER_ROUTE_CELLS := 2
const SKY_DIRECTIONS: Array[Vector3i] = [
	Vector3i.RIGHT, Vector3i.BACK, Vector3i.LEFT, Vector3i.FORWARD,
]

static var last_failure := ""
static var last_audit: Dictionary = {}
static var last_skywalk_diagnostic: Dictionary = {}
static var last_outcropping_diagnostic: Dictionary = {}


static func solve(grid: WarrenSpatialGrid, source: WarrenVolumePlan,
		buildings: Array[WarrenBuildingVolume], supports: WarrenSupportGraph,
		preplanned_skywalks: Array[Dictionary] = [],
		preplanned_courtyard_bridge: Dictionary = {},
		preplanned_market: Dictionary = {},
		preplanned_landmarks: Array[Dictionary] = [],
		construction_program: SettlementFabricProgram = null,
		composition_audit: Dictionary = {}) \
		-> Array[WarrenFeatureReservation]:
	last_failure = ""
	last_audit = {}
	last_skywalk_diagnostic = {}
	last_outcropping_diagnostic = {}
	if grid == null or grid.is_sealed() or source == null \
			or not source.is_sealed() or buildings.is_empty() or supports == null \
			or not supports.is_sealed():
		last_failure = "missing mutable grid, source volume, buildings, or supports"
		return [] as Array[WarrenFeatureReservation]
	var out: Array[WarrenFeatureReservation] = []
	var scale_profile := WarrenVillageScaleProfile.for_id(StringName(
		source.mass_context.get(&"scale_profile_id",
			WarrenVillageScaleProfile.LARGE)))
	if scale_profile == null:
		last_failure = "spatial features have an invalid scale profile"
		return [] as Array[WarrenFeatureReservation]
	var target_skywalks := scale_profile.skywalk_range.x
	var target_landmarks := scale_profile.landmark_range.x
	var target_balconies := scale_profile.balcony_range.x
	var target_outcroppings := scale_profile.cantilever_range.x
	var market := _reserve_preplanned_market(grid, buildings, supports,
		preplanned_market)
	if market == null:
		return [] as Array[WarrenFeatureReservation]
	out.append(market)
	var landmarks := _record_preplanned_landmarks(grid, supports,
		preplanned_landmarks)
	if landmarks.size() < target_landmarks:
		last_failure = "only %d of %d topology-first prefab landmarks survived" \
			% [landmarks.size(), target_landmarks]
		return [] as Array[WarrenFeatureReservation]
	out.append_array(landmarks)
	var skywalks := _reserve_preplanned_skywalks(grid, buildings, supports,
		preplanned_skywalks, landmarks) if not preplanned_skywalks.is_empty() \
		else _reserve_skywalks(grid, buildings, supports, source.world_seed,
			target_skywalks)
	if skywalks.size() < target_skywalks:
		var detail := last_failure
		last_failure = "only %d of %d topology-first skywalks fit: %s (%s)" % [
			skywalks.size(), target_skywalks, detail,
			last_skywalk_diagnostic]
		return [] as Array[WarrenFeatureReservation]
	out.append_array(skywalks)
	var courtyard_bridge: WarrenFeatureReservation
	if scale_profile.requires_elevated_courtyard:
		courtyard_bridge = _reserve_preplanned_courtyard_bridge_house(grid,
			buildings, supports, preplanned_courtyard_bridge)
		if courtyard_bridge == null:
			return [] as Array[WarrenFeatureReservation]
		out.append(courtyard_bridge)
	# The court transaction sees the cantilever's actual committed
	# PRIVATE_VOLUME. It never counts its endpoint, clearance envelope, or visual
	# mesh as an enclosing facade, and the three ordinary skywalks remain fully
	# independent circulation features elsewhere in the mountain.
	var court: WarrenFeatureReservation
	if scale_profile.requires_elevated_courtyard:
		court = _reserve_courtyard(grid, source, buildings, supports)
		if court == null:
			return [] as Array[WarrenFeatureReservation]
		out.append(court)
	var tall_tower_sources: Array[StringName] = []
	for source_value: Variant in composition_audit.get(
			"tall_tower_only_lineage_ids", []):
		tall_tower_sources.append(StringName(source_value))
	var tower_annexes := _reserve_tower_annexes(grid, buildings, supports,
		source.world_seed, construction_program, out, tall_tower_sources)
	var required_tower_annexes := tall_tower_sources.size() \
		* MIN_TOWER_ANNEXES_PER_TALL_LINEAGE
	if tower_annexes.size() < required_tower_annexes:
		var annexes_by_source: Dictionary = {}
		for annex: WarrenFeatureReservation in tower_annexes:
			var source_id := StringName(annex.audit.annex_source_parcel_id)
			if not annexes_by_source.has(source_id):
				annexes_by_source[source_id] = []
			(annexes_by_source[source_id] as Array).append({
				"storey": int(annex.audit.annex_source_storey_index),
				"facade": String(annex.audit.annex_vertical_facade_key),
				"recipe": StringName(annex.audit.annex_recipe_id),
			})
		last_failure = "only %d of %d tower-breaking room annexes fit: %s" % [
			tower_annexes.size(), required_tower_annexes, annexes_by_source]
		return [] as Array[WarrenFeatureReservation]
	out.append_array(tower_annexes)
	var balconies := _reserve_balconies(grid, buildings, supports,
		source.world_seed, construction_program, out, target_balconies)
	var balcony_buildings: Dictionary = {}
	for balcony: WarrenFeatureReservation in balconies:
		balcony_buildings[StringName(balcony.audit.balcony_building_id)] = true
	var minimum_balcony_buildings := mini(MIN_BALCONY_BUILDINGS,
		target_balconies)
	if balconies.size() < target_balconies \
			or balcony_buildings.size() < minimum_balcony_buildings:
		last_failure = "only %d balconies across %d buildings fit; need %d across %d" \
			% [balconies.size(), balcony_buildings.size(), target_balconies,
				minimum_balcony_buildings]
		return [] as Array[WarrenFeatureReservation]
	out.append_array(balconies)
	var outcroppings := _reserve_room_outcroppings(grid, buildings, supports,
		source.world_seed, construction_program, out, target_outcroppings)
	if outcroppings.size() < target_outcroppings:
		last_failure = "only %d of %d room-scale outcroppings exist" % [
			outcroppings.size(), target_outcroppings]
		return [] as Array[WarrenFeatureReservation]
	out.append_array(outcroppings)
	last_audit = {
		"elevated_courtyard_count": int(
			scale_profile.requires_elevated_courtyard),
		"covered_market_count": 1,
		"prefab_landmark_count": landmarks.size(),
		"enclosed_skywalk_count": skywalks.size(),
		"courtyard_bridge_house_count": int(
			scale_profile.requires_elevated_courtyard),
		"tower_annex_count": tower_annexes.size(),
		"tower_annex_source_count": tall_tower_sources.size(),
		"usable_balcony_count": balconies.size(),
		"balcony_building_count": balcony_buildings.size(),
		"room_outcropping_count": outcroppings.size(),
		"feature_count": out.size(),
	}
	last_audit.merge(last_outcropping_diagnostic, false)
	if courtyard_bridge != null:
		last_audit.merge(courtyard_bridge.audit, false)
	if court != null:
		last_audit.merge(court.audit, false)
	last_audit.merge(market.audit, false)
	return out


static func _reserve_tower_annexes(grid: WarrenSpatialGrid,
		buildings: Array[WarrenBuildingVolume], supports: WarrenSupportGraph,
		world_seed: int, program: SettlementFabricProgram,
		existing_features: Array[WarrenFeatureReservation],
		tall_tower_sources: Array[StringName]) \
		-> Array[WarrenFeatureReservation]:
	if program == null:
		return [] as Array[WarrenFeatureReservation]
	var rooms_by_source: Dictionary = {}
	var building_by_room: Dictionary = {}
	for building: WarrenBuildingVolume in buildings:
		for room: WarrenRoomStamp in building.room_records:
			building_by_room[room.stable_id] = building
			if not rooms_by_source.has(room.source_parcel_id):
				rooms_by_source[room.source_parcel_id] = [] \
					as Array[WarrenRoomStamp]
			(rooms_by_source[room.source_parcel_id] \
				as Array[WarrenRoomStamp]).append(room)
	var target_sources: Dictionary = {}
	for source_id: StringName in tall_tower_sources:
		if rooms_by_source.has(source_id):
			target_sources[source_id] = true
	if target_sources.is_empty():
		return [] as Array[WarrenFeatureReservation]
	var used_endpoint_cells: Dictionary = {}
	for feature: WarrenFeatureReservation in existing_features:
		for endpoint: Dictionary in feature.endpoints:
			used_endpoint_cells[endpoint.cell as Vector3i] = true
	var owner_ids_by_source: Dictionary = {}
	for building: WarrenBuildingVolume in buildings:
		for room: WarrenRoomStamp in building.room_records:
			if not owner_ids_by_source.has(room.source_parcel_id):
				owner_ids_by_source[room.source_parcel_id] = {}
			(owner_ids_by_source[room.source_parcel_id] \
				as Dictionary)[building.stable_id] = true
	var recipe_ids: Array[StringName] = [
		&"outcrop.blue", &"outcrop.orange",
		&"outcrop.corner.wrap.left.amber",
		&"outcrop.corner.wrap.right.blue",
		&"outcrop.corner.wrap.left.orange",
		&"outcrop.corner.wrap.right.amber",
		&"outcrop.dormer.gable.teal.left",
		&"outcrop.dormer.gable.orange.right",
		&"outcrop.dormer.shed.teal.right",
		&"outcrop.dormer.shed.orange.left",
		&"outcrop.flue.corner.left.blue",
		&"outcrop.flue.corner.right.orange",
		&"outcrop.capped.corner.left.amber",
		&"outcrop.capped.corner.right.amber",
	]
	var candidates: Array[Dictionary] = []
	for endpoint: Dictionary in _balcony_room_endpoints(buildings):
		var room := endpoint.room as WarrenRoomStamp
		if not target_sources.has(room.source_parcel_id) \
				or room.source_storey_index < 1 \
				or used_endpoint_cells.has(endpoint.cell as Vector3i):
			continue
		var facing := endpoint.facing as Vector3i
		var building := endpoint.building as WarrenBuildingVolume
		var allowed_owner_ids := owner_ids_by_source[room.source_parcel_id] \
			as Dictionary
		for recipe_id: StringName in recipe_ids:
			var recipe := program.recipe(recipe_id)
			if recipe == null or not recipe.has_tag(&"outcropping") \
					or recipe.bearing_parent_count != 1:
				continue
			var socket := recipe.socket(&"room.back")
			var yaw := _yaw_for_local_direction(Vector3i.FORWARD, -facing)
			if socket.is_empty() or yaw < 0:
				continue
			var socket_world := (endpoint.cell as Vector3i) + facing
			var origin := socket_world - FabricRecipe.transform_cell(
				socket.cell as Vector3i, Vector3i.ZERO, yaw)
			var body := _feature_recipe_cells(recipe, origin, yaw)
			if body.is_empty() or not WarrenVolumetricSolver \
					._skywalk_body_fits_grid(grid, body):
				continue
			var components: Array[Dictionary] = [{"recipe_id": recipe_id,
				"origin": origin, "yaw_quarters": yaw}]
			var clearance := WarrenVolumetricSolver \
				._skywalk_visual_clearance_cells(components, program)
			var clearance_audit := _balcony_clearance_audit(grid, clearance,
				body, allowed_owner_ids, origin.y)
			if not bool(clearance_audit.get("fits", false)) \
					or not _tower_annex_clears_room_envelopes(recipe, origin,
						yaw, room.source_parcel_id, buildings, program,
						world_seed):
				continue
			candidates.append({"recipe_id": recipe_id, "origin": origin,
				"yaw_quarters": yaw, "body": body, "clearance": clearance,
				"body_cell_count": body.size(),
				"clearance_only": clearance_audit.clearance_only,
				"covered_public_cells": clearance_audit.covered_public_cells,
				"endpoint_cell": endpoint.cell, "socket_world": socket_world,
				"facing": facing,
				"room": room, "building": building,
				"allowed_owner_ids": allowed_owner_ids,
				"tie": posmod(Helper._mix64(world_seed \
					^ String(room.stable_id).hash() * 31 \
					^ String(recipe_id).hash() * 47 \
					^ (endpoint.cell as Vector3i).x * 73856093 \
					^ (endpoint.cell as Vector3i).z * 19349663), 1000003)})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_room := a.room as WarrenRoomStamp
		var b_room := b.room as WarrenRoomStamp
		if a_room.source_storey_index != b_room.source_storey_index:
			return a_room.source_storey_index > b_room.source_storey_index
		if int(a.body_cell_count) != int(b.body_cell_count):
			return int(a.body_cell_count) > int(b.body_cell_count)
		return int(a.tie) < int(b.tie))
	var out: Array[WarrenFeatureReservation] = []
	var source_ids: Array[StringName] = []
	source_ids.assign(target_sources.keys())
	source_ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	var selected_by_source: Dictionary = {}
	for source_id: StringName in source_ids:
		selected_by_source[source_id] = [] as Array[Dictionary]
	# Round-robin selection prevents one especially open shaft from consuming the
	# relief budget.  Pass one chooses the strongest upper room; pass two must be
	# at least two storeys away and use another authored mass profile, creating a
	# compound cadence rather than two vertically repeated bay windows. A dense
	# party-wall shaft may have only one exposed compass side, so facade direction
	# itself is not required to change.
	for relief_round in MIN_TOWER_ANNEXES_PER_TALL_LINEAGE:
		for source_id: StringName in source_ids:
			var prior := selected_by_source[source_id] as Array[Dictionary]
			var chosen: Dictionary = {}
			var chosen_distance := -1
			for candidate: Dictionary in candidates:
				var room := candidate.room as WarrenRoomStamp
				if room.source_parcel_id != source_id:
					continue
				var vertical_distance := 0
				if not prior.is_empty():
					var first_room := prior[0].room as WarrenRoomStamp
					vertical_distance = absi(room.source_storey_index \
						- first_room.source_storey_index)
					if vertical_distance < 2 \
							or candidate.recipe_id == prior[0].recipe_id:
						continue
				if not WarrenVolumetricSolver._skywalk_body_fits_grid(grid,
						candidate.body as Dictionary):
					continue
				var refreshed := _balcony_clearance_audit(grid,
					candidate.clearance as Dictionary,
					candidate.body as Dictionary,
					candidate.allowed_owner_ids as Dictionary,
					(candidate.origin as Vector3i).y)
				if not bool(refreshed.get("fits", false)):
					continue
				if chosen.is_empty() or vertical_distance > chosen_distance:
					chosen = candidate.duplicate()
					chosen["clearance_only"] = refreshed.clearance_only
					chosen["covered_public_cells"] = \
						refreshed.covered_public_cells
					chosen_distance = vertical_distance
			if chosen.is_empty():
				continue
			var feature := _commit_tower_annex(grid, chosen, supports,
				out.size())
			if feature == null:
				continue
			prior.append(chosen)
			out.append(feature)
	return out


static func _tower_annex_clears_room_envelopes(recipe: FabricRecipe,
		origin: Vector3i, yaw_quarters: int, own_source_id: StringName,
		buildings: Array[WarrenBuildingVolume], program: SettlementFabricProgram,
		world_seed: int) -> bool:
	## The integer clearance raster protects topology, but authored eaves and
	## facade details can cross a cell boundary by centimetres. Use the same
	## measured AABBs as SettlementFabricPlan before reserving an annex; only
	## rooms in its own source lineage are explicit visual seams.
	var annex_bounds := FabricRecipe.lattice_transform(origin, yaw_quarters) \
		* recipe.local_clearance_bounds
	for building: WarrenBuildingVolume in buildings:
		for room: WarrenRoomStamp in building.room_records:
			if room.source_parcel_id == own_source_id:
				continue
			var recipe_ids: Array[StringName] = [
				WarrenSpatialFabricCompiler._room_recipe_id(room, world_seed),
				WarrenSpatialFabricCompiler._room_recipe_id(room, world_seed, false),
			]
			var seen: Dictionary = {}
			for recipe_id: StringName in recipe_ids:
				if seen.has(recipe_id):
					continue
				seen[recipe_id] = true
				var room_recipe := program.recipe(recipe_id)
				if room_recipe == null:
					return false
				var room_bounds := FabricRecipe.lattice_transform(
					room.lattice_origin, room.yaw_quarters) \
					* room_recipe.local_clearance_bounds
				if SettlementFabricPlan._aabb_overlaps_volume(annex_bounds,
						room_bounds):
					return false
	return true


static func _commit_tower_annex(grid: WarrenSpatialGrid,
		candidate: Dictionary, supports: WarrenSupportGraph,
		ordinal: int) -> WarrenFeatureReservation:
	var feature_id := StringName("spatial.feature.tower-annex.%02d" % ordinal)
	var body_dict := candidate.body as Dictionary
	var body: Array[Vector3i] = []
	body.assign(body_dict.keys())
	body.sort_custom(_cell_less)
	var clearance_only: Array[Vector3i] = []
	clearance_only.assign((candidate.clearance_only as Dictionary).keys())
	var covered_public: Array[Vector3i] = []
	covered_public.assign((candidate.covered_public_cells as Dictionary).keys())
	var endpoint_cell := candidate.endpoint_cell as Vector3i
	var socket_world := candidate.socket_world as Vector3i
	var building := candidate.building as WarrenBuildingVolume
	var room := candidate.room as WarrenRoomStamp
	var base_y := (candidate.origin as Vector3i).y
	var tx := grid.begin_transaction(feature_id)
	if not tx.require_use(body, [WarrenSpatialGrid.Use.OUTSIDE,
			WarrenSpatialGrid.Use.ALLOCATABLE] as Array[int]) \
			or not tx.reserve(body, WarrenSpatialGrid.Reservation.FEATURE \
				| WarrenSpatialGrid.Reservation.PRIVATE_CONNECTION \
				| WarrenSpatialGrid.Reservation.VISUAL_CLEARANCE, feature_id) \
			or not clearance_only.is_empty() and not tx.reserve(clearance_only,
				WarrenSpatialGrid.Reservation.VISUAL_CLEARANCE, feature_id) \
			or not covered_public.is_empty() and not tx.reserve(covered_public,
				WarrenSpatialGrid.Reservation.CONSTRUCTION_SEAM, feature_id) \
			or not tx.assign_use(body, WarrenSpatialGrid.Use.PRIVATE_VOLUME,
				feature_id):
		return null
	for cell: Vector3i in body:
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD, Vector3i.BACK]:
			var neighbor := cell + direction
			if body_dict.has(neighbor):
				continue
			var opens_to_room := Vector2i(cell.x, cell.z) \
					== Vector2i(socket_world.x, socket_world.z) \
				and neighbor == endpoint_cell + Vector3i.UP * (cell.y - base_y)
			var kind := WarrenSpatialGrid.FaceKind.FACADE
			if opens_to_room:
				kind = WarrenSpatialGrid.FaceKind.OPEN_SEAM
			elif direction == Vector3i.DOWN:
				kind = WarrenSpatialGrid.FaceKind.SOFFIT \
					if grid.use_at(neighbor) == WarrenSpatialGrid.Use.PUBLIC_AIR \
					else WarrenSpatialGrid.FaceKind.PRIVATE_FLOOR
			elif direction == Vector3i.UP:
				kind = WarrenSpatialGrid.FaceKind.ROOF
			if not tx.claim_face(cell, direction, kind, feature_id):
				return null
	if not tx.commit():
		return null
	var feature := WarrenFeatureReservation.new(feature_id, &"tower_annex")
	if not feature.add_reserved_cells(body) \
			or not feature.add_endpoint(endpoint_cell, building.stable_id) \
			or not feature.add_construction_record(
				StringName(candidate.recipe_id), candidate.origin as Vector3i,
				int(candidate.yaw_quarters), &"occupied_room_annex") \
			or not feature.set_support_node(building.stable_id) \
			or not feature.set_audit_facts({
				"annex_room_id": room.stable_id,
				"annex_building_id": building.stable_id,
				"annex_source_parcel_id": room.source_parcel_id,
				"annex_recipe_id": StringName(candidate.recipe_id),
				"annex_breaks_tower_lineage": true,
				"annex_source_storey_index": room.source_storey_index,
				"annex_vertical_facade_key": "%s/%d,%d/%d,%d" % [
					String(room.source_parcel_id), endpoint_cell.x,
					endpoint_cell.z, (candidate.facing as Vector3i).x,
					(candidate.facing as Vector3i).z],
				"annex_relief_profile_key": "%s/%s" % [
					String(room.source_parcel_id), String(candidate.recipe_id)],
				"annex_reserved_cell_count": body.size(),
			}) or not feature.seal(grid, supports):
		return null
	return feature


static func _record_preplanned_landmarks(grid: WarrenSpatialGrid,
		supports: WarrenSupportGraph,
		reservations: Array[Dictionary]) -> Array[WarrenFeatureReservation]:
	## Landmark volume, clearance, terrain bearing, doorway, and shell faces were
	## committed before room composition. This phase only seals the immutable
	## semantic records; it never searches for a new transform after packing.
	var out: Array[WarrenFeatureReservation] = []
	for reservation: Dictionary in reservations:
		var feature_id := StringName(reservation.get("feature_id", &""))
		var body: Array[Vector3i] = []
		body.assign((reservation.get("body", {}) as Dictionary).keys())
		body.sort_custom(_cell_less)
		var bearing: Array[Vector3i] = []
		bearing.assign((reservation.get("bearing_cells", {}) as Dictionary).keys())
		bearing.sort_custom(_cell_less)
		var entrance_cell := reservation.get("entrance_cell",
			Vector3i(2147483647, 2147483647, 2147483647)) as Vector3i
		var landing_cell := reservation.get("landing_cell",
			Vector3i(2147483647, 2147483647, 2147483647)) as Vector3i
		if feature_id.is_empty() or body.is_empty() or bearing.is_empty() \
				or not body.has(entrance_cell):
			last_failure = "preplanned prefab landmark record is incomplete"
			return [] as Array[WarrenFeatureReservation]
		for cell: Vector3i in body:
			if grid.use_at(cell) != WarrenSpatialGrid.Use.PRIVATE_VOLUME \
					or grid.owner_name_at(cell) != feature_id:
				last_failure = "prefab landmark %s lost body cell %s" % [
					feature_id, cell]
				return [] as Array[WarrenFeatureReservation]
		var blocker_ids: Array[StringName] = []
		blocker_ids.assign((reservation.get("blocker_parcels", {}) \
			as Dictionary).keys())
		blocker_ids.sort_custom(func(a: StringName, b: StringName) -> bool:
			return String(a) < String(b))
		var feature := WarrenFeatureReservation.new(feature_id,
			&"prefab_landmark")
		if not feature.add_reserved_cells(body) \
				or not feature.add_terrain_bearing_cells(bearing) \
				or not feature.add_endpoint(entrance_cell, feature_id) \
				or not feature.add_construction_record(
					StringName(reservation.recipe_id),
					reservation.origin as Vector3i,
					int(reservation.yaw_quarters), &"terrain_rooted_landmark") \
				or not feature.set_audit_facts({
					"landmark_recipe_id": StringName(reservation.recipe_id),
					"landmark_source_family": StringName(
						reservation.source_family),
					"landmark_entrance_cell": entrance_cell,
					"landmark_public_landing_cell": landing_cell,
					"landmark_terrain_bearing_cell_count": bearing.size(),
					"landmark_visual_clearance_cell_count": (
						reservation.clearance as Dictionary).size(),
					"landmark_height_cell_count": int(
						reservation.height_cell_count),
					"landmark_displaced_parcel_ids": blocker_ids,
					"landmark_publicly_addressed": true,
					"landmark_terrain_rooted": true,
				}) or not feature.seal(grid, supports):
			last_failure = "prefab landmark feature seal failed: %s" \
				% feature.last_rejection
			return [] as Array[WarrenFeatureReservation]
		out.append(feature)
	return out


static func _reserve_preplanned_courtyard_bridge_house(
		grid: WarrenSpatialGrid, buildings: Array[WarrenBuildingVolume],
		supports: WarrenSupportGraph,
		reservation: Dictionary) -> WarrenFeatureReservation:
	## Commit the one-ended inhabited projection selected before room
	## composition. Unlike an ordinary skywalk, this is a room-scale cantilever:
	## one real building bears it, its far end remains occupied, and it encloses
	## only the court-edge cells that its measured body physically occupies.
	if reservation.is_empty() or StringName(reservation.get("feature_id", &"")) \
			!= WarrenVolumetricSolver.COURTYARD_BRIDGE_FEATURE_ID:
		last_failure = "missing topology-first courtyard bridge house"
		return null
	var owner_ids := reservation.get("owner_parcel_ids", []) as Array
	var endpoints := reservation.get("owner_endpoints", []) as Array
	if owner_ids.size() != 1 or endpoints.size() != 1:
		last_failure = "courtyard bridge house lacks one source endpoint"
		return null
	var source_parcel_id := StringName(owner_ids[0])
	var endpoint_record := endpoints[0] as Dictionary
	var endpoint_cell := endpoint_record.cell as Vector3i
	var endpoint_facing := endpoint_record.facing as Vector3i
	var resolved: Dictionary = {}
	for building: WarrenBuildingVolume in buildings:
		for room: WarrenRoomStamp in building.room_records:
			if room.source_parcel_id != source_parcel_id \
					or not room.has_private_cell(endpoint_cell):
				continue
			if not resolved.is_empty():
				last_failure = "courtyard bridge endpoint has multiple room owners"
				return null
			resolved = {"building": building, "room": room}
	if resolved.is_empty():
		last_failure = "courtyard bridge house lost its exact room endpoint"
		return null
	var body_set := reservation.get("reserved_cells", {}) as Dictionary
	if not body_set.has(endpoint_cell + endpoint_facing):
		last_failure = "courtyard bridge body does not begin outside its room"
		return null
	var body: Array[Vector3i] = []
	body.assign(body_set.keys())
	body.sort_custom(_cell_less)
	var lower_public_columns := _lower_public_columns(grid, body)
	if lower_public_columns.size() < 2:
		last_failure = "courtyard bridge house lost the lower public street"
		return null
	var feature_id := WarrenVolumetricSolver.COURTYARD_BRIDGE_FEATURE_ID
	var clearance_only: Array[Vector3i] = []
	for cell_value: Variant in (reservation.get("visual_clearance_cells", {}) \
			as Dictionary).keys():
		if body_set.has(cell_value):
			continue
		var cell := cell_value as Vector3i
		if (grid.reservation_bits_at(cell) \
				& WarrenSpatialGrid.Reservation.VISUAL_CLEARANCE) != 0:
			last_failure = "courtyard bridge clearance changed before commit at %s" \
				% cell
			return null
		clearance_only.append(cell)
	var tx := grid.begin_transaction(feature_id)
	if not tx.require_use(body, [WarrenSpatialGrid.Use.OUTSIDE,
			WarrenSpatialGrid.Use.ALLOCATABLE] as Array[int]) \
			or not tx.reserve(body, WarrenSpatialGrid.Reservation.FEATURE \
				| WarrenSpatialGrid.Reservation.PRIVATE_CONNECTION \
				| WarrenSpatialGrid.Reservation.VISUAL_CLEARANCE, feature_id) \
			or not clearance_only.is_empty() and not tx.reserve(clearance_only,
				WarrenSpatialGrid.Reservation.VISUAL_CLEARANCE, feature_id) \
			or not tx.assign_use(body, WarrenSpatialGrid.Use.PRIVATE_VOLUME,
				feature_id):
		last_failure = "could not stage courtyard bridge house: %s" \
			% tx.last_rejection
		return null
	var endpoint_owner := (resolved.building as WarrenBuildingVolume).stable_id
	for cell: Vector3i in body:
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD, Vector3i.BACK]:
			var neighbor := cell + direction
			if body_set.has(neighbor):
				continue
			var kind := WarrenSpatialGrid.FaceKind.FACADE
			if neighbor == endpoint_cell:
				kind = WarrenSpatialGrid.FaceKind.OPEN_SEAM
			elif direction == Vector3i.UP:
				kind = WarrenSpatialGrid.FaceKind.ROOF
			elif direction == Vector3i.DOWN:
				kind = WarrenSpatialGrid.FaceKind.PRIVATE_FLOOR
			if not tx.claim_face(cell, direction, kind, feature_id):
				last_failure = "could not stage courtyard bridge face at %s" % cell
				return null
	if not tx.commit():
		last_failure = "courtyard bridge house rejected: %s" % tx.last_rejection
		return null
	var feature := WarrenFeatureReservation.new(feature_id,
		&"courtyard_bridge_house")
	if not feature.add_reserved_cells(body) \
			or not feature.add_endpoint(endpoint_cell, endpoint_owner):
		last_failure = "could not record courtyard bridge volume or endpoint"
		return null
	var components := reservation.get("components", []) as Array
	for component_index in components.size():
		var component := components[component_index] as Dictionary
		if not feature.add_construction_record(StringName(component.recipe_id),
				component.origin as Vector3i, int(component.yaw_quarters),
				StringName("component.%02d" % component_index)):
			last_failure = "could not record courtyard bridge component"
			return null
	var room := resolved.room as WarrenRoomStamp
	if components.size() != 2 or not feature.set_support_node(endpoint_owner) \
			or not feature.set_audit_facts({
				"courtyard_bridge_house_room_id": room.stable_id,
				"courtyard_bridge_house_source_parcel_id": source_parcel_id,
				"courtyard_bridge_house_endpoint_facing": endpoint_facing,
				"courtyard_bridge_house_component_count": components.size(),
				"courtyard_bridge_house_lower_public_column_count":
					lower_public_columns.size(),
				"courtyard_bridge_house_side_mask": int(reservation.get(
					"courtyard_side_mask", 0)),
				"courtyard_bridge_house_visual_clearance_cell_count":
					body.size() + clearance_only.size(),
			}) or not feature.seal(grid, supports):
		last_failure = "courtyard bridge feature seal failed: %s" \
			% feature.last_rejection
		return null
	return feature


static func _reserve_courtyard(grid: WarrenSpatialGrid,
		source: WarrenVolumePlan, buildings: Array[WarrenBuildingVolume],
		supports: WarrenSupportGraph) -> WarrenFeatureReservation:
	var floors: Dictionary = {}
	for macro: Vector3i in source.courtyard_cells:
		for cell: Vector3i in WarrenVolumetricSolver._fine_square(macro):
			if grid.use_at(cell) != WarrenSpatialGrid.Use.PUBLIC_AIR:
				last_failure = "elevated court floor left public air at %s" % cell
				return null
			floors[cell] = true
	if floors.size() < 16:
		last_failure = "elevated court is smaller than the required 6 x 6 m"
		return null
	var minimum_y := 2147483647
	var maximum_y := -2147483648
	var protected: Dictionary = {}
	for floor_value: Variant in floors.keys():
		var floor := floor_value as Vector3i
		minimum_y = mini(minimum_y, floor.y)
		maximum_y = maxi(maximum_y, floor.y)
		for y_offset in WarrenSpatialGrid.STOREY_CELLS:
			var air := floor + Vector3i.UP * y_offset
			if grid.use_at(air) != WarrenSpatialGrid.Use.PUBLIC_AIR:
				last_failure = "elevated court lacks protected headroom at %s" % air
				return null
			protected[air] = true
		var macro_column := Vector2i(floor.x / 2, floor.z / 2)
		if floor.y - source.envelope.ground_at(macro_column) \
				< WarrenSpatialGrid.STOREY_CELLS * 2:
			last_failure = "court is not on the third-storey datum"
			return null
	if minimum_y != maximum_y:
		last_failure = "elevated court floor is not coplanar"
		return null
	var below: Dictionary = {}
	var above: Dictionary = {}
	for floor_value: Variant in floors.keys():
		var floor := floor_value as Vector3i
		for offset in range(1, 9):
			var candidate := floor + Vector3i.DOWN * offset
			if grid.use_at(candidate) == WarrenSpatialGrid.Use.PUBLIC_AIR:
				below[candidate] = true
		for offset in range(2, 9):
			var candidate := floor + Vector3i.UP * offset
			if grid.use_at(candidate) == WarrenSpatialGrid.Use.PUBLIC_AIR:
				above[candidate] = true
	if below.size() < MIN_COURT_BELOW_ROUTE_CELLS:
		last_failure = "elevated court has no real public passage beneath it"
		return null
	if above.size() < MIN_COURT_UPPER_ROUTE_CELLS:
		last_failure = "elevated court has no upper route crossing"
		return null
	for value: Variant in below.keys():
		protected[value] = true
	for value: Variant in above.keys():
		protected[value] = true
	var side_endpoints := _courtyard_side_endpoints(grid, floors)
	if side_endpoints.size() < MIN_COURT_SIDE_COUNT:
		last_failure = "elevated court is addressed on only %d sides" % \
			side_endpoints.size()
		return null
	var feature_id := StringName("spatial.feature.courtyard.%d" % \
		source.world_seed)
	var protected_cells: Array[Vector3i] = []
	protected_cells.assign(protected.keys())
	protected_cells.sort_custom(_cell_less)
	var reserve := grid.begin_transaction(feature_id)
	if not reserve.reserve(protected_cells, WarrenSpatialGrid.Reservation.FEATURE,
			feature_id) or not reserve.commit():
		last_failure = "elevated court reservation failed: %s" % \
			reserve.last_rejection
		return null
	var feature := WarrenFeatureReservation.new(feature_id,
		&"third_storey_courtyard")
	if not feature.add_reserved_cells(protected_cells):
		last_failure = "could not record elevated court cells"
		return null
	var support_owner := &""
	for endpoint: Dictionary in side_endpoints:
		if not feature.add_endpoint(endpoint.cell as Vector3i,
				StringName(endpoint.owner_id)):
			last_failure = "could not record court facade endpoint"
			return null
		var endpoint_owner := StringName(endpoint.owner_id)
		if support_owner.is_empty() and supports.reaches_terrain(endpoint_owner):
			support_owner = endpoint_owner
	if support_owner.is_empty() or not feature.set_support_node(support_owner) \
			or not feature.set_audit_facts({
				"courtyard_floor_cell_count": floors.size(),
				"courtyard_below_route_cell_count": below.size(),
				"courtyard_upper_route_cell_count": above.size(),
				"courtyard_addressed_side_count": side_endpoints.size(),
				"courtyard_floor_band": minimum_y,
			}) or not feature.seal(grid, supports):
		last_failure = "elevated court feature seal failed: %s" % \
			feature.last_rejection
		return null
	return feature


static func _reserve_balconies(grid: WarrenSpatialGrid,
		buildings: Array[WarrenBuildingVolume], supports: WarrenSupportGraph,
		world_seed: int, program: SettlementFabricProgram,
		existing_features: Array[WarrenFeatureReservation],
		target_count: int = TARGET_BALCONIES) \
		-> Array[WarrenFeatureReservation]:
	## Search the actual three-dimensional residual void around upper room
	## sockets. A candidate is a complete measured recipe and owns its deck,
	## private headroom, guards, door seam, support, and clearance before roofs
	## are allowed to compile around it.
	if program == null:
		return [] as Array[WarrenFeatureReservation]
	var used_endpoint_cells: Dictionary = {}
	for feature: WarrenFeatureReservation in existing_features:
		for endpoint: Dictionary in feature.endpoints:
			used_endpoint_cells[endpoint.cell as Vector3i] = true
	var allowed_owner_ids_by_source: Dictionary = {}
	for building: WarrenBuildingVolume in buildings:
		for room: WarrenRoomStamp in building.room_records:
			if not allowed_owner_ids_by_source.has(room.source_parcel_id):
				allowed_owner_ids_by_source[room.source_parcel_id] = {}
			(allowed_owner_ids_by_source[room.source_parcel_id] \
				as Dictionary)[building.stable_id] = true
	var room_clearance_bounds_by_source := \
		_room_clearance_bounds_by_source(buildings, program, world_seed)
	var recipe_ids: Array[StringName] = [
		&"balcony.bracketed.left.blue",
		&"balcony.bracketed.right.orange",
		&"balcony.bracketed.left.amber",
		&"balcony.bracketed.right.blue",
	]
	var candidates: Array[Dictionary] = []
	for endpoint: Dictionary in _balcony_room_endpoints(buildings):
		var endpoint_cell := endpoint.cell as Vector3i
		if used_endpoint_cells.has(endpoint_cell):
			continue
		var facing := endpoint.facing as Vector3i
		var room := endpoint.room as WarrenRoomStamp
		var building := endpoint.building as WarrenBuildingVolume
		var owner_ids := allowed_owner_ids_by_source.get(room.source_parcel_id,
			{}) as Dictionary
		var phase := posmod(Helper._mix64(world_seed \
			^ String(room.stable_id).hash() ^ endpoint_cell.x * 73856093 \
			^ endpoint_cell.z * 19349663), recipe_ids.size())
		for recipe_offset in recipe_ids.size():
			var recipe_id := recipe_ids[(phase + recipe_offset) % recipe_ids.size()]
			var recipe := program.recipe(recipe_id)
			if recipe == null or not recipe.has_tag(&"balcony"):
				continue
			var socket := recipe.socket(&"room.back")
			var yaw := _yaw_for_local_direction(Vector3i.FORWARD, -facing)
			if socket.is_empty() or yaw < 0:
				continue
			var socket_world := endpoint_cell + facing
			var origin := socket_world - FabricRecipe.transform_cell(
				socket.cell as Vector3i, Vector3i.ZERO, yaw)
			if _feature_bounds_overlap_unrelated_room(recipe, origin, yaw,
					room.source_parcel_id, room_clearance_bounds_by_source):
				continue
			var body := _feature_recipe_cells(recipe, origin, yaw)
			if body.is_empty() or not WarrenVolumetricSolver \
					._skywalk_body_fits_grid(grid, body):
				continue
			var components: Array[Dictionary] = [{"recipe_id": recipe_id,
				"origin": origin, "yaw_quarters": yaw}]
			var clearance := WarrenVolumetricSolver \
				._skywalk_visual_clearance_cells(components, program)
			var clearance_audit := _balcony_clearance_audit(grid, clearance,
				body, owner_ids, origin.y)
			if not bool(clearance_audit.get("fits", false)):
				continue
			var facade_key := _balcony_facade_key(endpoint_cell, facing)
			candidates.append({"recipe_id": recipe_id, "origin": origin,
				"yaw_quarters": yaw, "body": body, "clearance": clearance,
				"clearance_only": clearance_audit.clearance_only,
				"covered_public_cells": clearance_audit.covered_public_cells,
				"endpoint_cell": endpoint_cell, "endpoint_facing": facing,
				"socket_world": socket_world, "room": room,
				"building": building, "allowed_owner_ids": owner_ids,
				"facade_key": facade_key,
				"covered_public_count": int(clearance_audit.covered_public_count),
				"tie": posmod(Helper._mix64(world_seed ^ String(recipe_id).hash()
					^ endpoint_cell.x * 31 ^ endpoint_cell.y * 43 \
					^ endpoint_cell.z * 47), 1000003)})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.covered_public_count) != int(b.covered_public_count):
			return int(a.covered_public_count) > int(b.covered_public_count)
		var a_room := a.room as WarrenRoomStamp
		var b_room := b.room as WarrenRoomStamp
		if a_room.source_storey_index != b_room.source_storey_index:
			return a_room.source_storey_index > b_room.source_storey_index
		return int(a.tie) < int(b.tie))
	var out: Array[WarrenFeatureReservation] = []
	var count_by_building: Dictionary = {}
	var used_facades: Dictionary = {}
	var used_rooms: Dictionary = {}
	for candidate: Dictionary in candidates:
		if out.size() >= target_count:
			break
		var building := candidate.building as WarrenBuildingVolume
		var room := candidate.room as WarrenRoomStamp
		if int(count_by_building.get(building.stable_id, 0)) \
				>= MAX_BALCONIES_PER_BUILDING or used_rooms.has(room.stable_id) \
				or used_facades.has(String(candidate.facade_key)):
			continue
		# Earlier accepted balconies may have consumed this residual void; rerun
		# the exact checks against the current grid before committing.
		var body := candidate.body as Dictionary
		if not WarrenVolumetricSolver._skywalk_body_fits_grid(grid, body):
			continue
		var refreshed := _balcony_clearance_audit(grid,
			candidate.clearance as Dictionary, body,
			candidate.allowed_owner_ids as Dictionary,
			(candidate.origin as Vector3i).y)
		if not bool(refreshed.get("fits", false)):
			continue
		candidate["clearance_only"] = refreshed.clearance_only
		candidate["covered_public_cells"] = refreshed.covered_public_cells
		candidate["covered_public_count"] = refreshed.covered_public_count
		var feature := _commit_balcony(grid, candidate, supports, out.size())
		if feature == null:
			continue
		out.append(feature)
		count_by_building[building.stable_id] = int(count_by_building.get(
			building.stable_id, 0)) + 1
		used_rooms[room.stable_id] = true
		used_facades[String(candidate.facade_key)] = true
	return out


static func _commit_balcony(grid: WarrenSpatialGrid, candidate: Dictionary,
		supports: WarrenSupportGraph, ordinal: int) -> WarrenFeatureReservation:
	var feature_id := StringName("spatial.feature.balcony.%02d" % ordinal)
	var body_dict := candidate.body as Dictionary
	var body: Array[Vector3i] = []
	body.assign(body_dict.keys())
	body.sort_custom(_cell_less)
	var clearance_only: Array[Vector3i] = []
	clearance_only.assign((candidate.clearance_only as Dictionary).keys())
	var covered_public: Array[Vector3i] = []
	covered_public.assign((candidate.covered_public_cells as Dictionary).keys())
	var endpoint_cell := candidate.endpoint_cell as Vector3i
	var socket_world := candidate.socket_world as Vector3i
	var building := candidate.building as WarrenBuildingVolume
	var room := candidate.room as WarrenRoomStamp
	var allowed_owner_ids := candidate.allowed_owner_ids as Dictionary
	var base_y := (candidate.origin as Vector3i).y
	var tx := grid.begin_transaction(feature_id)
	if not tx.require_use(body, [WarrenSpatialGrid.Use.OUTSIDE,
			WarrenSpatialGrid.Use.ALLOCATABLE] as Array[int]) \
			or not tx.reserve(body, WarrenSpatialGrid.Reservation.FEATURE \
				| WarrenSpatialGrid.Reservation.PRIVATE_CONNECTION \
				| WarrenSpatialGrid.Reservation.VISUAL_CLEARANCE, feature_id) \
			or not clearance_only.is_empty() and not tx.reserve(clearance_only,
				WarrenSpatialGrid.Reservation.VISUAL_CLEARANCE, feature_id) \
			or not covered_public.is_empty() and not tx.reserve(covered_public,
				WarrenSpatialGrid.Reservation.CONSTRUCTION_SEAM, feature_id) \
			or not tx.assign_use(body, WarrenSpatialGrid.Use.PRIVATE_VOLUME,
				feature_id):
		return null
	for cell: Vector3i in body:
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD, Vector3i.BACK]:
			var neighbor := cell + direction
			if body_dict.has(neighbor):
				continue
			var opens_to_room := Vector2i(cell.x, cell.z) \
					== Vector2i(socket_world.x, socket_world.z) \
				and neighbor == endpoint_cell + Vector3i.UP * (cell.y - base_y)
			var kind := WarrenSpatialGrid.FaceKind.OPEN_SEAM
			if opens_to_room:
				kind = WarrenSpatialGrid.FaceKind.OPEN_SEAM
			elif direction == Vector3i.DOWN:
				kind = WarrenSpatialGrid.FaceKind.SOFFIT \
					if grid.use_at(neighbor) == WarrenSpatialGrid.Use.PUBLIC_AIR \
					else WarrenSpatialGrid.FaceKind.PRIVATE_FLOOR
			elif direction == Vector3i.UP:
				kind = WarrenSpatialGrid.FaceKind.OPEN_SEAM
			elif allowed_owner_ids.has(grid.owner_name_at(neighbor)):
				kind = WarrenSpatialGrid.FaceKind.FACADE
			elif cell.y == base_y:
				kind = WarrenSpatialGrid.FaceKind.GUARD
			if not tx.claim_face(cell, direction, kind, feature_id):
				return null
	if not tx.commit():
		return null
	var feature := WarrenFeatureReservation.new(feature_id, &"balcony")
	if not feature.add_reserved_cells(body) \
			or not feature.add_endpoint(endpoint_cell, building.stable_id) \
			or not feature.add_construction_record(
				StringName(candidate.recipe_id), candidate.origin as Vector3i,
				int(candidate.yaw_quarters), &"occupied_balcony") \
			or not feature.set_support_node(building.stable_id) \
			or not feature.set_audit_facts({
				"balcony_room_id": room.stable_id,
				"balcony_building_id": building.stable_id,
				"balcony_source_parcel_id": room.source_parcel_id,
				"balcony_recipe_id": StringName(candidate.recipe_id),
				"balcony_endpoint_facing": candidate.endpoint_facing as Vector3i,
				"balcony_usable_width_cells": 2,
				"balcony_usable_depth_cells": 1,
				"balcony_door_count": 1,
				"balcony_guard_segment_count": 4,
				"balcony_support_kind": &"bracket_cantilever",
				"balcony_reserved_headroom_cell_count": body.size(),
				"balcony_visual_clearance_cell_count":
					(candidate.clearance as Dictionary).size(),
				"balcony_covered_public_cell_count": covered_public.size(),
				"balcony_facade_key": String(candidate.facade_key),
			}) or not feature.seal(grid, supports):
		return null
	return feature


static func _balcony_room_endpoints(
		buildings: Array[WarrenBuildingVolume]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for building: WarrenBuildingVolume in buildings:
		for room: WarrenRoomStamp in building.room_records:
			# Ground-floor decks read as porches. Balconies must contribute to the
			# interlocked upper silhouette and therefore begin on storey two.
			if room.source_storey_index < 1:
				continue
			var footprint := _room_footprint(room.kind)
			if footprint.is_empty():
				continue
			var minimum := footprint.minimum as Vector2i
			var maximum := minimum + footprint.size as Vector2i - Vector2i.ONE
			for local: Dictionary in [
				{"cell": Vector3i(maximum.x, 0, 0), "facing": Vector3i.RIGHT},
				{"cell": Vector3i(minimum.x, 0, 0), "facing": Vector3i.LEFT},
				{"cell": Vector3i(0, 0, minimum.y), "facing": Vector3i.FORWARD},
				{"cell": Vector3i(0, 0, maximum.y), "facing": Vector3i.BACK},
			]:
				out.append({"cell": FabricRecipe.transform_cell(
					local.cell as Vector3i, room.lattice_origin,
					room.yaw_quarters), "facing": FabricRecipe.transform_direction(
					local.facing as Vector3i, room.yaw_quarters),
					"room": room, "building": building})
	return out


static func _feature_recipe_cells(recipe: FabricRecipe, origin: Vector3i,
		yaw_quarters: int) -> Dictionary:
	var out: Dictionary = {}
	for cells: Array[Vector3i] in [recipe.solid_cells, recipe.walk_cells,
			recipe.headroom_cells]:
		for local_cell: Vector3i in cells:
			out[FabricRecipe.transform_cell(local_cell, origin, yaw_quarters)] = true
	return out


static func _room_clearance_bounds_by_source(
		buildings: Array[WarrenBuildingVolume], program: SettlementFabricProgram,
		world_seed: int) -> Dictionary:
	## Feature raster clearance and authored visual clearance answer different
	## questions. Cache both possible facade phases for every final room so a
	## balcony cannot fit between lattice cells while clipping a neighbour's
	## eaves, ivy, sign, or other measured projection.
	var out: Dictionary = {}
	for building: WarrenBuildingVolume in buildings:
		for room: WarrenRoomStamp in building.room_records:
			if not out.has(room.source_parcel_id):
				out[room.source_parcel_id] = [] as Array[AABB]
			var seen_recipes: Dictionary = {}
			for allow_phase_b in [true, false]:
				var recipe_id := WarrenSpatialFabricCompiler._room_recipe_id(
					room, world_seed, allow_phase_b)
				if seen_recipes.has(recipe_id):
					continue
				seen_recipes[recipe_id] = true
				var recipe := program.recipe(recipe_id)
				if recipe == null:
					continue
				(out[room.source_parcel_id] as Array[AABB]).append(
					FabricRecipe.lattice_transform(room.lattice_origin,
						room.yaw_quarters) * recipe.local_clearance_bounds)
	return out


static func _feature_bounds_overlap_unrelated_room(recipe: FabricRecipe,
		origin: Vector3i, yaw_quarters: int, related_source_id: StringName,
		room_bounds_by_source: Dictionary) -> bool:
	var feature_bounds := FabricRecipe.lattice_transform(origin, yaw_quarters) \
		* recipe.local_clearance_bounds
	for source_value: Variant in room_bounds_by_source.keys():
		if StringName(source_value) == related_source_id:
			continue
		for room_bounds: AABB in (room_bounds_by_source[source_value] \
				as Array[AABB]):
			if SettlementFabricPlan._aabb_overlaps_volume(feature_bounds,
					room_bounds):
				return true
	return false


static func _balcony_clearance_audit(grid: WarrenSpatialGrid,
		clearance: Dictionary, body: Dictionary, allowed_owner_ids: Dictionary,
		base_y: int) -> Dictionary:
	if clearance.is_empty():
		return {"fits": false}
	var clearance_only: Dictionary = {}
	var covered_public: Dictionary = {}
	for cell_value: Variant in clearance.keys():
		var cell := cell_value as Vector3i
		if not grid.contains(cell):
			return {"fits": false}
		if body.has(cell):
			continue
		var use_value := grid.use_at(cell)
		var owner_id := grid.owner_name_at(cell)
		if use_value == WarrenSpatialGrid.Use.PRIVATE_VOLUME \
				and allowed_owner_ids.has(owner_id):
			continue
		if use_value == WarrenSpatialGrid.Use.PUBLIC_AIR and cell.y < base_y:
			covered_public[cell] = true
			continue
		if use_value not in [WarrenSpatialGrid.Use.OUTSIDE,
				WarrenSpatialGrid.Use.ALLOCATABLE]:
			return {"fits": false}
		if (grid.reservation_bits_at(cell) & (
				WarrenSpatialGrid.Reservation.FEATURE \
				| WarrenSpatialGrid.Reservation.VISUAL_CLEARANCE)) != 0:
			return {"fits": false}
		clearance_only[cell] = true
	return {"fits": true, "clearance_only": clearance_only,
		"covered_public_cells": covered_public,
		"covered_public_count": covered_public.size()}


static func _balcony_facade_key(cell: Vector3i, facing: Vector3i) -> String:
	# Deliberately omit Y: equivalent XZ/facing coordinates may not repeat up a
	# facade, which prevents a balcony stack from recreating the tower pattern.
	return "%d:%d/%d:%d" % [cell.x, cell.z, facing.x, facing.z]


static func _yaw_for_local_direction(local_direction: Vector3i,
		target_direction: Vector3i) -> int:
	for yaw in 4:
		if FabricRecipe.transform_direction(local_direction, yaw) \
				== target_direction:
			return yaw
	return -1


static func _reserve_preplanned_market(grid: WarrenSpatialGrid,
		buildings: Array[WarrenBuildingVolume], supports: WarrenSupportGraph,
		reservation: Dictionary) -> WarrenFeatureReservation:
	## Commit the exact topology-first canopy/posts around an existing four-cell
	## public aisle. The public cells retain their canonical route owner; the
	## market incorporates them through a named construction seam instead of
	## painting a disconnected prefab beside the street after packing.
	if reservation.is_empty():
		last_failure = "covered market has no pre-partition reservation"
		return null
	var feature_id := StringName(reservation.get("feature_id", &""))
	var backing_parcel_id := StringName(reservation.get(
		"backing_parcel_id", &""))
	var backing_cell := reservation.get("backing_cell",
		Vector3i(2147483647, 2147483647, 2147483647)) as Vector3i
	var backing_building: WarrenBuildingVolume
	var backing_room: WarrenRoomStamp
	for building: WarrenBuildingVolume in buildings:
		for room: WarrenRoomStamp in building.room_records:
			if room.source_parcel_id != backing_parcel_id \
					or not room.has_private_cell(backing_cell):
				continue
			if backing_room != null:
				last_failure = "covered market backing socket has multiple room owners"
				return null
			backing_building = building
			backing_room = room
	if feature_id.is_empty() or backing_building == null or backing_room == null \
			or not backing_building.feature_ids.has(feature_id):
		last_failure = "covered market lost its exact backing room"
		return null
	var body: Array[Vector3i] = []
	body.assign((reservation.get("reserved_cells", {}) as Dictionary).keys())
	body.sort_custom(_cell_less)
	var public_cells: Array[Vector3i] = []
	public_cells.assign((reservation.get("public_cells", {}) as Dictionary).keys())
	public_cells.sort_custom(_cell_less)
	var covered_aisle_cells := reservation.get("covered_aisle_cells", {}) \
		as Dictionary
	var bearing_cells: Array[Vector3i] = []
	bearing_cells.assign((reservation.get("bearing_cells", {}) \
		as Dictionary).keys())
	if body.is_empty() or public_cells.size() < 4 \
			or covered_aisle_cells.size() != 4 or bearing_cells.is_empty():
		last_failure = "covered market reservation is incomplete"
		return null
	var body_set: Dictionary = {}
	for cell: Vector3i in body:
		body_set[cell] = true
	var overhead_public_floor_seam_count := 0
	var tx := grid.begin_transaction(feature_id)
	if not tx.require_use(body, [WarrenSpatialGrid.Use.OUTSIDE,
			WarrenSpatialGrid.Use.ALLOCATABLE] as Array[int]) \
			or not tx.reserve(body, WarrenSpatialGrid.Reservation.FEATURE \
				| WarrenSpatialGrid.Reservation.VISUAL_CLEARANCE, feature_id) \
			or not tx.reserve(public_cells,
				WarrenSpatialGrid.Reservation.CONSTRUCTION_SEAM, feature_id) \
			or not tx.reserve(bearing_cells,
				WarrenSpatialGrid.Reservation.TERRAIN_BEARING, feature_id) \
			or not tx.assign_use(body,
				WarrenSpatialGrid.Use.STRUCTURAL_VOLUME, feature_id):
		last_failure = "could not stage topology-first covered market"
		return null
	for cell: Vector3i in body:
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD, Vector3i.BACK]:
			var neighbor := cell + direction
			if body_set.has(neighbor):
				continue
			var kind := WarrenSpatialGrid.FaceKind.FACADE
			if direction == Vector3i.UP:
				kind = WarrenSpatialGrid.FaceKind.ROOF
			elif direction == Vector3i.DOWN:
				kind = WarrenSpatialGrid.FaceKind.SOFFIT \
					if grid.use_at(neighbor) == WarrenSpatialGrid.Use.PUBLIC_AIR \
					else WarrenSpatialGrid.FaceKind.PRIVATE_FLOOR
			var existing := grid.face_claim(cell, direction)
			if not existing.is_empty():
				# A topology-first market may fit immediately beneath an upper
				# public route. Its canopy and that route meet at one physical
				# interface; the already-sealed PUBLIC_FLOOR remains the authority
				# instead of being overwritten by a duplicate ROOF label.
				if direction == Vector3i.UP and int(existing.kind) \
						== WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR:
					overhead_public_floor_seam_count += 1
					continue
				last_failure = "covered-market face conflicts at %s toward %s" % [
					cell, direction]
				return null
			if not tx.claim_face(cell, direction, kind, feature_id):
				last_failure = "could not stage covered-market interface at %s" % cell
				return null
	if not tx.commit():
		last_failure = "covered market %s rejected: %s" % [feature_id,
			tx.last_rejection]
		return null
	var components := reservation.get("components", []) as Array
	if components.size() != 1:
		last_failure = "covered market is not one atomic reviewed construction"
		return null
	var component := components[0] as Dictionary
	var feature := WarrenFeatureReservation.new(feature_id, &"covered_market")
	if not feature.add_reserved_cells(body) \
			or not feature.add_public_cells(public_cells) \
			or not feature.add_endpoint(backing_cell,
				backing_building.stable_id) \
			or not feature.add_construction_record(
				StringName(component.recipe_id), component.origin as Vector3i,
				int(component.yaw_quarters), &"covered_bazaar") \
			or not feature.set_support_node(backing_building.stable_id) \
			or not feature.set_audit_facts({
				"market_aisle_cell_count": public_cells.size(),
				"market_covered_aisle_cell_count": covered_aisle_cells.size(),
				"market_aisle_extension_cell_count": int(reservation.get(
					"aisle_extension_cell_count", 0)),
				"market_new_public_cell_count": int(reservation.get(
					"new_public_cell_count", 0)),
				"market_street_entrance_edge_count": int(reservation.get(
					"street_entrance_edge_count", 0)),
				"market_street_entrance_width": int(reservation.get(
					"street_entrance_width", 0)),
				"market_stocked_bay_count": 2,
				"market_continuous_canopy": true,
				"market_overhead_public_floor_seam_count":
					overhead_public_floor_seam_count,
				"market_open_horizon_max_cells": int(reservation.get(
					"open_horizon_max_cells", 2147483647)),
				"market_open_horizon_total_cells": int(reservation.get(
					"open_horizon_total_cells", 2147483647)),
				"market_core_radius_squared": float(reservation.get(
					"core_radius_squared", INF)),
				"market_backing_room_id": backing_room.stable_id,
				"market_backing_building_id": backing_building.stable_id,
				"market_backing_parcel_id": backing_parcel_id,
				"market_recipe_id": StringName(component.recipe_id),
				"market_terrain_bearing_cell_count": bearing_cells.size(),
			}) or not feature.seal(grid, supports):
		last_failure = "covered market feature seal failed: %s" % \
			feature.last_rejection
		return null
	return feature


static func _reserve_preplanned_skywalks(grid: WarrenSpatialGrid,
		buildings: Array[WarrenBuildingVolume], supports: WarrenSupportGraph,
		reservations: Array[Dictionary],
		landmarks: Array[WarrenFeatureReservation] = []) \
		-> Array[WarrenFeatureReservation]:
	## Commit the exact feature-set selected before room partition. The former
	## late scanner threw those reservations away and tried to rediscover only
	## straight links after rooms had consumed the surrounding mass, which made
	## a topology-first plan indistinguishable from the retired detail pass.
	var out: Array[WarrenFeatureReservation] = []
	var offset_rooms := _offset_room_ids(buildings)
	for reservation_index in reservations.size():
		var reservation := reservations[reservation_index]
		var resolved := _resolve_preplanned_endpoints(grid, reservation, buildings,
			landmarks)
		if resolved.size() != 2:
			last_skywalk_diagnostic = _preplanned_endpoint_diagnostic(grid,
				reservation, buildings, reservation_index)
			last_failure = "preplanned skywalk %d lost an exact room endpoint" \
				% reservation_index
			return [] as Array[WarrenFeatureReservation]
		var endpoint_owner_ids: Dictionary = {}
		var offset_endpoint_count := 0
		var landmark_endpoint_count := 0
		for endpoint: Dictionary in resolved:
			endpoint_owner_ids[StringName(endpoint.building_id)] = true
			var is_landmark := StringName(endpoint.get("endpoint_kind", &"")) \
				== &"landmark"
			landmark_endpoint_count += int(is_landmark)
			offset_endpoint_count += int(is_landmark or offset_rooms.has(
				StringName(endpoint.room_id)))
		if endpoint_owner_ids.size() != 2 or offset_endpoint_count < 1:
			last_failure = "preplanned skywalk %d lacks two owners or an offset endpoint" \
				% reservation_index
			return [] as Array[WarrenFeatureReservation]
		var body_set := reservation.get("reserved_cells", {}) as Dictionary
		var body: Array[Vector3i] = []
		body.assign(body_set.keys())
		body.sort_custom(_cell_less)
		if body.is_empty():
			last_failure = "preplanned skywalk %d has no reserved body" \
				% reservation_index
			return [] as Array[WarrenFeatureReservation]
		var lower_public_columns := _lower_public_columns(grid, body)
		if lower_public_columns.size() < 2:
			last_failure = "preplanned skywalk %d lost public circulation below" \
				% reservation_index
			return [] as Array[WarrenFeatureReservation]
		var feature := _commit_preplanned_skywalk(grid, reservation, resolved,
			body, lower_public_columns.size(), supports, reservation_index,
			offset_endpoint_count, landmark_endpoint_count)
		if feature == null:
			return [] as Array[WarrenFeatureReservation]
		out.append(feature)
	last_skywalk_diagnostic = {
		"preplanned_count": reservations.size(),
		"accepted_count": out.size(),
		"late_reinference_used": false,
	}
	return out


static func _preplanned_endpoint_diagnostic(grid: WarrenSpatialGrid,
		reservation: Dictionary, buildings: Array[WarrenBuildingVolume],
		reservation_index: int) -> Dictionary:
	var facts: Array[Dictionary] = []
	var owner_ids := reservation.get("owner_parcel_ids", []) as Array
	var endpoints := reservation.get("owner_endpoints", []) as Array
	for endpoint_index in mini(owner_ids.size(), endpoints.size()):
		var source_parcel_id := StringName(owner_ids[endpoint_index])
		var endpoint := endpoints[endpoint_index] as Dictionary
		var cell := endpoint.cell as Vector3i
		var source_rooms: Array[Dictionary] = []
		for building: WarrenBuildingVolume in buildings:
			for room: WarrenRoomStamp in building.room_records:
				if room.source_parcel_id != source_parcel_id:
					continue
				source_rooms.append({"building_id": building.stable_id,
					"room_id": room.stable_id, "origin": room.lattice_origin,
					"storey": room.source_storey_index,
					"contains_endpoint": room.has_private_cell(cell)})
		facts.append({"source_parcel_id": source_parcel_id, "cell": cell,
			"facing": endpoint.facing, "grid_use": grid.use_at(cell),
			"grid_owner": grid.owner_name_at(cell), "source_rooms": source_rooms})
	return {"reservation_index": reservation_index,
		"endpoint_facts": facts,
		"endpoint_pair_key": WarrenVolumetricSolver \
			._skywalk_endpoint_pair_key(reservation)}


static func _resolve_preplanned_endpoints(grid: WarrenSpatialGrid,
		reservation: Dictionary,
		buildings: Array[WarrenBuildingVolume],
		landmarks: Array[WarrenFeatureReservation] = []) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var landmark_by_id: Dictionary = {}
	for landmark: WarrenFeatureReservation in landmarks:
		landmark_by_id[landmark.stable_id] = landmark
	var owner_ids := reservation.get("owner_parcel_ids", []) as Array
	var endpoints := reservation.get("owner_endpoints", []) as Array
	if owner_ids.size() != 2 or endpoints.size() != 2:
		return out
	var body := reservation.get("reserved_cells", {}) as Dictionary
	for endpoint_index in 2:
		var source_parcel_id := StringName(owner_ids[endpoint_index])
		var endpoint := endpoints[endpoint_index] as Dictionary
		var cell := endpoint.cell as Vector3i
		var facing := endpoint.facing as Vector3i
		if not body.has(cell + facing):
			return [] as Array[Dictionary]
		var landmark := landmark_by_id.get(source_parcel_id) \
			as WarrenFeatureReservation
		if landmark != null:
			if not landmark.reserved_cells.has(cell) \
					or grid.use_at(cell) != WarrenSpatialGrid.Use.PRIVATE_VOLUME \
					or grid.owner_name_at(cell) != landmark.stable_id:
				return [] as Array[Dictionary]
			out.append({"cell": cell, "facing": facing,
				"building_id": landmark.stable_id,
				"room_id": landmark.stable_id,
				"source_parcel_id": landmark.stable_id,
				"endpoint_kind": &"landmark"})
			continue
		var endpoint_match: Dictionary = {}
		for building: WarrenBuildingVolume in buildings:
			for room: WarrenRoomStamp in building.room_records:
				if room.source_parcel_id != source_parcel_id \
						or not room.has_private_cell(cell):
					continue
				if not endpoint_match.is_empty():
					return [] as Array[Dictionary]
				endpoint_match = {"cell": cell, "facing": facing,
					"building_id": building.stable_id,
					"room_id": room.stable_id,
					"source_parcel_id": source_parcel_id,
					"endpoint_kind": &"room"}
		if endpoint_match.is_empty():
			return [] as Array[Dictionary]
		out.append(endpoint_match)
	return out


static func _lower_public_columns(grid: WarrenSpatialGrid,
		body: Array[Vector3i]) -> Dictionary:
	var minimum_y := 2147483647
	for cell: Vector3i in body:
		minimum_y = mini(minimum_y, cell.y)
	var out: Dictionary = {}
	for cell: Vector3i in body:
		if cell.y != minimum_y:
			continue
		for down in range(1, 9):
			if grid.use_at(cell + Vector3i.DOWN * down) \
					== WarrenSpatialGrid.Use.PUBLIC_AIR:
				out[Vector2i(cell.x, cell.z)] = true
				break
	return out


static func _commit_preplanned_skywalk(grid: WarrenSpatialGrid,
		reservation: Dictionary, resolved: Array[Dictionary],
		body: Array[Vector3i], lower_public_column_count: int,
		supports: WarrenSupportGraph, ordinal: int,
		offset_endpoint_count: int,
		landmark_endpoint_count: int = 0) -> WarrenFeatureReservation:
	var feature_id := StringName("spatial.feature.skywalk.%02d" % ordinal)
	var body_set: Dictionary = {}
	for cell: Vector3i in body:
		body_set[cell] = true
	var endpoint_cells: Dictionary = {}
	var endpoint_owner_ids: Dictionary = {}
	for endpoint: Dictionary in resolved:
		endpoint_cells[endpoint.cell as Vector3i] = true
		endpoint_owner_ids[StringName(endpoint.building_id)] = true
	var clearance_only: Array[Vector3i] = []
	for cell_value: Variant in (reservation.get("visual_clearance_cells", {}) \
			as Dictionary).keys():
		if body_set.has(cell_value):
			continue
		var cell := cell_value as Vector3i
		var existing_visual := (grid.reservation_bits_at(cell) \
			& WarrenSpatialGrid.Reservation.VISUAL_CLEARANCE) != 0
		if existing_visual:
			var endpoint_owns_clearance := false
			for owner_value: Variant in endpoint_owner_ids.keys():
				if grid.reservation_owned_by(cell,
						WarrenSpatialGrid.Reservation.VISUAL_CLEARANCE,
						StringName(owner_value)):
					endpoint_owns_clearance = true
					break
			if endpoint_owns_clearance:
				continue
			# Candidate selection already rejects intersecting measured AABBs for
			# every pair in the accepted triple. Two disjoint eaves may still touch
			# the same conservative 1.5 m raster cell; the earlier skywalk keeps
			# ownership of that coarse cell and the later one relies on the exact
			# pair proof. Solid/private volume remains mutually exclusive below.
			var prior_skywalk_owns_clearance := false
			for prior_ordinal in ordinal:
				var prior_id := StringName("spatial.feature.skywalk.%02d" \
					% prior_ordinal)
				if grid.reservation_owned_by(cell,
						WarrenSpatialGrid.Reservation.VISUAL_CLEARANCE,
						prior_id):
					prior_skywalk_owns_clearance = true
					break
			if prior_skywalk_owns_clearance:
				continue
			last_failure = "skywalk clearance changed before commit at %s; owners=%s" \
				% [cell, grid.reservation_owner_names_at(cell,
					WarrenSpatialGrid.Reservation.VISUAL_CLEARANCE)]
			return null
		clearance_only.append(cell)
	var tx := grid.begin_transaction(feature_id)
	if not tx.require_use(body, [WarrenSpatialGrid.Use.OUTSIDE,
			WarrenSpatialGrid.Use.ALLOCATABLE] as Array[int]) \
			or not tx.reserve(body, WarrenSpatialGrid.Reservation.FEATURE \
				| WarrenSpatialGrid.Reservation.PRIVATE_CONNECTION \
				| WarrenSpatialGrid.Reservation.VISUAL_CLEARANCE, feature_id) \
			or not clearance_only.is_empty() and not tx.reserve(clearance_only,
				WarrenSpatialGrid.Reservation.VISUAL_CLEARANCE, feature_id) \
			or not tx.assign_use(body, WarrenSpatialGrid.Use.PRIVATE_VOLUME,
				feature_id):
		last_failure = "could not stage preplanned skywalk %s" % feature_id
		return null
	for cell: Vector3i in body:
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD, Vector3i.BACK]:
			var neighbor := cell + direction
			if body_set.has(neighbor):
				continue
			var kind := WarrenSpatialGrid.FaceKind.FACADE
			if endpoint_cells.has(neighbor):
				kind = WarrenSpatialGrid.FaceKind.OPEN_SEAM
			elif direction == Vector3i.UP:
				kind = WarrenSpatialGrid.FaceKind.ROOF
			elif direction == Vector3i.DOWN:
				kind = WarrenSpatialGrid.FaceKind.PRIVATE_FLOOR
			if not tx.claim_face(cell, direction, kind, feature_id):
				last_failure = "could not stage skywalk interface at %s" % cell
				return null
	if not tx.commit():
		last_failure = "preplanned skywalk %s rejected: %s" % [feature_id,
			tx.last_rejection]
		return null
	var feature := WarrenFeatureReservation.new(feature_id,
		&"enclosed_skywalk")
	if not feature.add_reserved_cells(body):
		last_failure = "could not record preplanned skywalk volume"
		return null
	for endpoint: Dictionary in resolved:
		if not feature.add_endpoint(endpoint.cell as Vector3i,
				StringName(endpoint.building_id)):
			last_failure = "could not record preplanned skywalk endpoint"
			return null
	var components := reservation.get("components", []) as Array
	for component_index in components.size():
		var component := components[component_index] as Dictionary
		if not feature.add_construction_record(
				StringName(component.recipe_id), component.origin as Vector3i,
				int(component.yaw_quarters), StringName("component.%02d" \
					% component_index)):
			last_failure = "could not record skywalk construction component"
			return null
	var left := resolved[0]
	var right := resolved[1]
	var support_owner := &""
	for endpoint: Dictionary in resolved:
		var candidate_owner := StringName(endpoint.building_id)
		if supports.reaches_terrain(candidate_owner):
			support_owner = candidate_owner
			break
	var endpoint_bindings: Array[Dictionary] = []
	for endpoint: Dictionary in resolved:
		endpoint_bindings.append({
			"endpoint_kind": StringName(endpoint.endpoint_kind),
			"owner_id": StringName(endpoint.building_id),
			"room_id": StringName(endpoint.room_id),
			"cell": endpoint.cell,
			"facing": endpoint.facing,
		})
	if support_owner.is_empty() or not feature.set_support_node(support_owner) \
			or not feature.set_audit_facts({
				"skywalk_kind": StringName(reservation.get("kind", &"straight")),
				"skywalk_component_count": components.size(),
				"skywalk_lower_public_column_count": lower_public_column_count,
				"skywalk_offset_endpoint_count": offset_endpoint_count,
				"skywalk_landmark_endpoint_count": landmark_endpoint_count,
				"skywalk_visual_clearance_cell_count": body.size() \
					+ clearance_only.size(),
				"skywalk_endpoint_bindings": endpoint_bindings,
				"skywalk_left_room_id": StringName(left.room_id),
				"skywalk_right_room_id": StringName(right.room_id),
				"skywalk_endpoint_pair_key": WarrenVolumetricSolver \
					._skywalk_endpoint_pair_key(reservation),
			}) or not feature.seal(grid, supports):
		last_failure = "preplanned skywalk feature seal failed: %s" \
			% feature.last_rejection
		return null
	return feature


static func _courtyard_side_endpoints(grid: WarrenSpatialGrid,
		floors: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for direction: Vector3i in SKY_DIRECTIONS:
		var endpoint: Dictionary = {}
		var cells: Array[Vector3i] = []
		cells.assign(floors.keys())
		cells.sort_custom(_cell_less)
		for floor: Vector3i in cells:
			if floors.has(floor + direction):
				continue
			for y_offset in WarrenSpatialGrid.STOREY_CELLS:
				var neighbor := floor + direction + Vector3i.UP * y_offset
				if grid.use_at(neighbor) == WarrenSpatialGrid.Use.PRIVATE_VOLUME:
					endpoint = {"cell": neighbor,
						"owner_id": grid.owner_name_at(neighbor),
						"direction": direction}
					break
			if not endpoint.is_empty():
				break
		if not endpoint.is_empty():
			out.append(endpoint)
	return out


static func _reserve_skywalks(grid: WarrenSpatialGrid,
		buildings: Array[WarrenBuildingVolume], supports: WarrenSupportGraph,
		world_seed: int, target_count: int = TARGET_SKYWALKS) \
		-> Array[WarrenFeatureReservation]:
	var endpoints := _room_endpoints(buildings)
	var by_key: Dictionary = {}
	for endpoint: Dictionary in endpoints:
		by_key[_endpoint_key(endpoint.cell as Vector3i,
			endpoint.facing as Vector3i)] = endpoint
	var candidates: Array[Dictionary] = []
	var endpoint_pair_count := 0
	var offset_endpoint_pair_count := 0
	for left: Dictionary in endpoints:
		var facing := left.facing as Vector3i
		for distance: int in [3, 5, 7]:
			var right_cell := (left.cell as Vector3i) + facing * distance
			var right := by_key.get(_endpoint_key(right_cell, -facing), {}) \
				as Dictionary
			if right.is_empty() or left.building_id == right.building_id \
					or String(left.room_id) > String(right.room_id):
				continue
			endpoint_pair_count += 1
			offset_endpoint_pair_count += int(bool(left.offset_floorplate) \
				or bool(right.offset_floorplate))
			var candidate := _skywalk_candidate(grid, left, right, distance)
			if not candidate.is_empty():
				candidate["tie"] = posmod(Helper._mix64(world_seed \
					^ String(left.room_id).hash() ^ String(right.room_id).hash()),
					1000003)
				candidates.append(candidate)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.lower_public_column_count) != int(b.lower_public_column_count):
			return int(a.lower_public_column_count) \
				> int(b.lower_public_column_count)
		if int(a.distance) != int(b.distance):
			return int(a.distance) > int(b.distance)
		return int(a.tie) < int(b.tie))
	var out: Array[WarrenFeatureReservation] = []
	var endpoint_pairs: Dictionary = {}
	var candidate_summaries: Array[Dictionary] = []
	for candidate: Dictionary in candidates:
		candidate_summaries.append({
			"left": StringName(candidate.left.building_id),
			"right": StringName(candidate.right.building_id),
			"distance": int(candidate.distance),
			"origin": candidate.origin,
		})
		if out.size() >= target_count:
			break
		var pair_key := _pair_key(StringName(candidate.left.building_id),
			StringName(candidate.right.building_id))
		if endpoint_pairs.has(pair_key):
			continue
		var feature := _commit_skywalk(grid, candidate, supports, out.size())
		if feature == null:
			continue
		endpoint_pairs[pair_key] = true
		out.append(feature)
	last_skywalk_diagnostic = {
		"room_endpoint_count": endpoints.size(),
		"endpoint_pair_count": endpoint_pair_count,
		"offset_endpoint_pair_count": offset_endpoint_pair_count,
		"clear_candidate_count": candidates.size(),
		"accepted_count": out.size(),
		"candidates": candidate_summaries,
	}
	return out


static func _skywalk_candidate(grid: WarrenSpatialGrid, left: Dictionary,
		right: Dictionary, distance: int) -> Dictionary:
	if not bool(left.offset_floorplate) and not bool(right.offset_floorplate):
		return {}
	var direction := left.facing as Vector3i
	var length_cells := distance - 1
	var yaw := _yaw_from_right(direction)
	if yaw < 0 or length_cells not in [2, 4, 6]:
		return {}
	var minimum_x := -length_cells / 2
	var first_gap := (left.cell as Vector3i) + direction
	var origin := first_gap - FabricRecipe.transform_cell(
		Vector3i(minimum_x, 0, 0), Vector3i.ZERO, yaw)
	var body: Dictionary = {}
	for y in 4:
		for z in range(-1, 1):
			for x in range(minimum_x, minimum_x + length_cells):
				var cell := FabricRecipe.transform_cell(Vector3i(x, y, z),
					origin, yaw)
				if not grid.contains(cell) or grid.use_at(cell) not in [
						WarrenSpatialGrid.Use.OUTSIDE,
						WarrenSpatialGrid.Use.ALLOCATABLE] \
						or (grid.reservation_bits_at(cell) \
							& WarrenSpatialGrid.Reservation.FEATURE) != 0:
					return {}
				body[cell] = true
	var lower_public_columns: Dictionary = {}
	for body_value: Variant in body.keys():
		var body_cell := body_value as Vector3i
		if body_cell.y != origin.y:
			continue
		for down in range(1, 9):
			var lower := body_cell + Vector3i.DOWN * down
			if grid.use_at(lower) == WarrenSpatialGrid.Use.PUBLIC_AIR:
				lower_public_columns[Vector2i(body_cell.x, body_cell.z)] = true
				break
	if lower_public_columns.size() < 2:
		return {}
	var body_cells: Array[Vector3i] = []
	body_cells.assign(body.keys())
	body_cells.sort_custom(_cell_less)
	return {"left": left, "right": right, "distance": distance,
		"origin": origin, "yaw_quarters": yaw, "body_cells": body_cells,
		"lower_public_column_count": lower_public_columns.size()}


static func _commit_skywalk(grid: WarrenSpatialGrid, candidate: Dictionary,
		supports: WarrenSupportGraph, ordinal: int) -> WarrenFeatureReservation:
	var feature_id := StringName("spatial.feature.skywalk.%02d" % ordinal)
	var body := candidate.body_cells as Array[Vector3i]
	var body_set: Dictionary = {}
	for cell: Vector3i in body:
		body_set[cell] = true
	var left := candidate.left as Dictionary
	var right := candidate.right as Dictionary
	var endpoints: Dictionary = {
		left.cell as Vector3i: true,
		right.cell as Vector3i: true,
	}
	var tx := grid.begin_transaction(feature_id)
	if not tx.require_use(body, [WarrenSpatialGrid.Use.OUTSIDE,
			WarrenSpatialGrid.Use.ALLOCATABLE] as Array[int]) \
			or not tx.reserve(body, WarrenSpatialGrid.Reservation.FEATURE \
				| WarrenSpatialGrid.Reservation.PRIVATE_CONNECTION \
				| WarrenSpatialGrid.Reservation.VISUAL_CLEARANCE, feature_id) \
			or not tx.assign_use(body, WarrenSpatialGrid.Use.PRIVATE_VOLUME,
				feature_id):
		return null
	for cell: Vector3i in body:
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD, Vector3i.BACK]:
			var neighbor := cell + direction
			if body_set.has(neighbor):
				continue
			var kind := WarrenSpatialGrid.FaceKind.FACADE
			if endpoints.has(neighbor):
				kind = WarrenSpatialGrid.FaceKind.OPEN_SEAM
			elif direction == Vector3i.UP:
				kind = WarrenSpatialGrid.FaceKind.ROOF
			elif direction == Vector3i.DOWN:
				kind = WarrenSpatialGrid.FaceKind.PRIVATE_FLOOR
			if not tx.claim_face(cell, direction, kind, feature_id):
				return null
	if not tx.commit():
		return null
	var distance := int(candidate.distance)
	var recipe_id := &"skywalk.3.blue" if distance == 3 \
		else &"skywalk.6.orange" if distance == 5 else &"skywalk.9.blue"
	var feature := WarrenFeatureReservation.new(feature_id,
		&"enclosed_skywalk")
	if not feature.add_reserved_cells(body) \
			or not feature.add_endpoint(left.cell as Vector3i,
				StringName(left.building_id)) \
			or not feature.add_endpoint(right.cell as Vector3i,
				StringName(right.building_id)) \
			or not feature.set_support_node(StringName(left.building_id)) \
			or not feature.add_construction_record(recipe_id,
				candidate.origin as Vector3i, int(candidate.yaw_quarters)) \
			or not feature.set_audit_facts({
				"skywalk_distance_cells": distance,
				"skywalk_lower_public_column_count": int(
					candidate.lower_public_column_count),
				"skywalk_left_room_id": StringName(left.room_id),
				"skywalk_right_room_id": StringName(right.room_id),
			}) or not feature.seal(grid, supports):
		return null
	return feature


static func _reserve_room_outcroppings(grid: WarrenSpatialGrid,
		buildings: Array[WarrenBuildingVolume], supports: WarrenSupportGraph,
		world_seed: int, program: SettlementFabricProgram,
		existing_features: Array[WarrenFeatureReservation] = [],
		target_count: int = TARGET_ROOM_OUTCROPPINGS) \
		-> Array[WarrenFeatureReservation]:
	if program == null or program.recipe(&"outcrop.support.bracketed.2") == null \
			or program.recipe(&"outcrop.support.diagonal.2") == null:
		last_failure = "room outcroppings lack the measured bracket vocabulary"
		return [] as Array[WarrenFeatureReservation]
	var building_by_room: Dictionary = {}
	var rooms_by_source: Dictionary = {}
	for building: WarrenBuildingVolume in buildings:
		for room: WarrenRoomStamp in building.room_records:
			building_by_room[room.stable_id] = building
			if not rooms_by_source.has(room.source_parcel_id):
				rooms_by_source[room.source_parcel_id] = [] \
					as Array[WarrenRoomStamp]
			(rooms_by_source[room.source_parcel_id] \
				as Array[WarrenRoomStamp]).append(room)
	var candidates: Array[Dictionary] = []
	for rooms_value: Variant in rooms_by_source.values():
		var rooms := rooms_value as Array[WarrenRoomStamp]
		rooms.sort_custom(func(a: WarrenRoomStamp, b: WarrenRoomStamp) -> bool:
			return a.source_storey_index < b.source_storey_index)
		for index in range(1, rooms.size()):
			var lower := rooms[index - 1]
			var upper := rooms[index]
			var delta := Vector2i(upper.lattice_origin.x - lower.lattice_origin.x,
				upper.lattice_origin.z - lower.lattice_origin.z)
			if delta == Vector2i.ZERO:
				continue
			var geometry := _room_cantilever_geometry(lower, upper)
			if geometry.is_empty():
				continue
			candidates.append({"lower": lower, "upper": upper,
				"building": building_by_room[upper.stable_id], "delta": delta,
				"extension_column_count": int(geometry.extension_column_count),
				"cantilever_geometry": geometry,
				"tie": posmod(Helper._mix64(world_seed \
					^ String(upper.stable_id).hash()), 1000003)})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_valid := bool((a.cantilever_geometry as Dictionary).valid)
		var b_valid := bool((b.cantilever_geometry as Dictionary).valid)
		if a_valid != b_valid:
			return a_valid
		if int(a.extension_column_count) != int(b.extension_column_count):
			return int(a.extension_column_count) > int(b.extension_column_count)
		return int(a.tie) < int(b.tie))
	var valid_candidate_count := 0
	var rejection_counts: Dictionary = {}
	for candidate: Dictionary in candidates:
		var geometry := candidate.cantilever_geometry as Dictionary
		valid_candidate_count += int(bool(geometry.valid))
		if not bool(geometry.valid):
			var rejection := StringName(geometry.rejection)
			rejection_counts[rejection] = int(rejection_counts.get(rejection, 0)) + 1
	var out: Array[WarrenFeatureReservation] = []
	var used_buildings: Dictionary = {}
	var measured_support_conflict_count := 0
	for candidate: Dictionary in candidates:
		if out.size() >= target_count:
			break
		# Invalid shifted rooms remain in the diagnostic census so future grammar
		# changes cannot silently reintroduce them, but they are not outcroppings.
		# A corner-shifted box or a mostly floating upper plate must never satisfy
		# this feature quota merely because some columns differ from the floor below.
		if not bool((candidate.cantilever_geometry as Dictionary).valid):
			continue
		var building := candidate.building as WarrenBuildingVolume
		if used_buildings.has(building.stable_id):
			continue
		var upper := candidate.upper as WarrenRoomStamp
		var geometry := candidate.cantilever_geometry as Dictionary
		var support_records := _cantilever_support_records(upper, geometry, grid)
		if support_records.is_empty():
			continue
		var related_room_ids := {
			upper.stable_id: true,
			(candidate.lower as WarrenRoomStamp).stable_id: true,
		}
		if not _outcrop_supports_clear_measured_envelopes(support_records,
				related_room_ids, buildings, existing_features, program,
				world_seed):
			measured_support_conflict_count += 1
			continue
		var feature_id := StringName("spatial.feature.outcrop.%02d" % out.size())
		var tx := grid.begin_transaction(feature_id)
		if not tx.reserve(upper.private_cells,
				WarrenSpatialGrid.Reservation.FEATURE, feature_id) \
				or not tx.commit():
			continue
		var feature := WarrenFeatureReservation.new(feature_id,
			&"room_outcropping")
		if not feature.add_reserved_cells(upper.private_cells) \
				or not feature.add_endpoint(upper.private_cells[0],
					building.stable_id) \
				or not feature.set_support_node(building.stable_id):
			last_failure = "room outcropping support identity failed"
			return [] as Array[WarrenFeatureReservation]
		for record: Dictionary in support_records:
			if not feature.add_construction_record(StringName(record.recipe_id),
					record.origin as Vector3i, int(record.yaw_quarters),
					StringName(record.role)):
				last_failure = "room outcropping bracket record failed"
				return [] as Array[WarrenFeatureReservation]
		if not feature.set_audit_facts({
					"outcrop_upper_room_id": upper.stable_id,
					"outcrop_lower_room_id": (candidate.lower \
						as WarrenRoomStamp).stable_id,
					"outcrop_extension_column_count": int(
						candidate.extension_column_count),
					"outcrop_room_footprint_column_count": \
						upper.private_cells.size() / WarrenSpatialGrid.STOREY_CELLS,
					"outcrop_is_integrated_cantilever": bool(geometry.valid),
					"outcrop_projection_direction": geometry.direction as Vector2i,
					"outcrop_projection_depth_cells": int(geometry.depth_cells),
					"outcrop_attachment_span_cells": int(
						geometry.attachment_span_cells),
					"outcrop_bearing_column_count": int(geometry.bearing_column_count),
					"outcrop_bearing_ratio": float(geometry.bearing_ratio),
					"outcrop_support_course_count": support_records.size(),
					"outcrop_diagonal_support_course_count": support_records.filter(
						func(record: Dictionary) -> bool:
							return StringName(record.recipe_id) \
								== &"outcrop.support.diagonal.2").size(),
					"outcrop_geometry_rejection": StringName(geometry.rejection),
				}) or not feature.seal(grid, supports):
			last_failure = "room outcropping seal failed: %s" % \
				feature.last_rejection
			return [] as Array[WarrenFeatureReservation]
		used_buildings[building.stable_id] = true
		out.append(feature)
	last_outcropping_diagnostic = {
		"room_outcropping_candidate_count": candidates.size(),
		"integrated_cantilever_candidate_count": valid_candidate_count,
		"noncantilever_outcropping_candidate_count": candidates.size() \
			- valid_candidate_count,
		"selected_integrated_cantilever_count": out.filter(
			func(feature: WarrenFeatureReservation) -> bool:
				return bool(feature.audit.get(
					"outcrop_is_integrated_cantilever", false))).size(),
		"outcrop_diagonal_support_course_count": out.reduce(
			func(total: int, feature: WarrenFeatureReservation) -> int:
				return total + int(feature.audit.get(
					"outcrop_diagonal_support_course_count", 0)), 0),
		"cantilever_rejection_counts": rejection_counts,
		"cantilever_measured_support_conflict_count":
			measured_support_conflict_count,
	}
	return out


static func _outcrop_supports_clear_measured_envelopes(
		support_records: Array[Dictionary], related_room_ids: Dictionary,
		buildings: Array[WarrenBuildingVolume],
		existing_features: Array[WarrenFeatureReservation],
		program: SettlementFabricProgram, world_seed: int) -> bool:
	## Brackets are selected as measured construction, not added after topology.
	## They may enter the conservative envelopes of the exact upper/lower room
	## plates they join, but no other room or previously reserved feature.
	var support_bounds: Array[AABB] = []
	for record: Dictionary in support_records:
		var support_recipe := program.recipe(StringName(record.recipe_id))
		if support_recipe == null or not support_recipe.has_tag(
				&"cantilever_support"):
			return false
		support_bounds.append(FabricRecipe.lattice_transform(
			record.origin as Vector3i, int(record.yaw_quarters)) \
			* support_recipe.local_clearance_bounds)
	for building: WarrenBuildingVolume in buildings:
		for room: WarrenRoomStamp in building.room_records:
			if related_room_ids.has(room.stable_id):
				continue
			var seen_recipes: Dictionary = {}
			for allow_phase_b in [true, false]:
				var room_recipe_id := WarrenSpatialFabricCompiler._room_recipe_id(
					room, world_seed, allow_phase_b)
				if seen_recipes.has(room_recipe_id):
					continue
				seen_recipes[room_recipe_id] = true
				var room_recipe := program.recipe(room_recipe_id)
				if room_recipe == null:
					return false
				var room_bounds := FabricRecipe.lattice_transform(
					room.lattice_origin, room.yaw_quarters) \
					* room_recipe.local_clearance_bounds
				for bounds: AABB in support_bounds:
					if SettlementFabricPlan._aabb_overlaps_volume(bounds,
							room_bounds):
						return false
	for feature: WarrenFeatureReservation in existing_features:
		for record: Dictionary in feature.construction_records:
			var feature_recipe := program.recipe(StringName(record.recipe_id))
			if feature_recipe == null:
				return false
			var feature_bounds := FabricRecipe.lattice_transform(
				record.origin as Vector3i, int(record.yaw_quarters)) \
				* feature_recipe.local_clearance_bounds
			for bounds: AABB in support_bounds:
				if SettlementFabricPlan._aabb_overlaps_volume(bounds,
						feature_bounds):
					return false
	return true


static func _cantilever_support_records(upper: WarrenRoomStamp,
		geometry: Dictionary, grid: WarrenSpatialGrid = null) \
		-> Array[Dictionary]:
	## Tile the exact bearing edge with native 3 m bracket pairs. Local BACK is
	## the unsupported projection direction and local RIGHT follows the facade.
	## Room side spans are even in the admissible 3/6/9 m vocabulary; an odd or
	## discontinuous edge is rejected instead of receiving a stretched support.
	var out: Array[Dictionary] = []
	if upper == null or not bool(geometry.get("valid", false)):
		return out
	var direction_2d := geometry.get("direction", Vector2i.ZERO) as Vector2i
	var direction := Vector3i(direction_2d.x, 0, direction_2d.y)
	var yaw := _yaw_for_local_direction(Vector3i.BACK, direction)
	if yaw < 0:
		return out
	var span_direction_3d := FabricRecipe.transform_direction(Vector3i.RIGHT,
		yaw)
	var span_direction := Vector2i(span_direction_3d.x, span_direction_3d.z)
	var attachment: Array[Vector2i] = []
	attachment.assign(geometry.get("attachment_columns", []) as Array)
	if attachment.size() < 2 or attachment.size() % 2 != 0:
		return out
	attachment.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.x * span_direction.x + a.y * span_direction.y \
			< b.x * span_direction.x + b.y * span_direction.y)
	for index in range(1, attachment.size()):
		if attachment[index] != attachment[index - 1] + span_direction:
			return [] as Array[Dictionary]
	for index in range(0, attachment.size(), 2):
		var column := attachment[index]
		var course_columns: Array[Vector2i] = [column, column + span_direction]
		var recipe_id := &"outcrop.support.diagonal.2" \
			if _diagonal_cantilever_sweep_is_clear(grid, course_columns,
				direction, upper.lattice_origin.y) \
			else &"outcrop.support.bracketed.2"
		out.append({
			"recipe_id": recipe_id,
			"origin": Vector3i(column.x, upper.lattice_origin.y, column.y),
			"yaw_quarters": yaw,
			"role": StringName("cantilever_support.%02d" % (index / 2)),
		})
	return out


static func _diagonal_cantilever_sweep_is_clear(grid: WarrenSpatialGrid,
		attachment_columns: Array[Vector2i], direction: Vector3i,
		upper_base_y: int) -> bool:
	## The native brace drops 3.606 m (slightly over two fine bands) and projects
	## 2.372 m from its facade post. Conservatively inspect three bands below the
	## room and two outward columns. Private mass is allowed here because the
	## measured-envelope pass immediately afterwards proves it belongs to the
	## upper/lower room pair; public, daylight, service, or court structure is
	## never pierced by a decorative support.
	if grid == null:
		return false
	for attachment: Vector2i in attachment_columns:
		for depth in [0, 1, 2]:
			var column := Vector2i(attachment.x + direction.x * depth,
				attachment.y + direction.z * depth)
			for y in range(upper_base_y - 3, upper_base_y):
				var use_value := grid.use_at(Vector3i(column.x, y, column.y))
				if use_value in [WarrenSpatialGrid.Use.PUBLIC_AIR,
						WarrenSpatialGrid.Use.DAYLIGHT_AIR,
						WarrenSpatialGrid.Use.SERVICE_VOID,
						WarrenSpatialGrid.Use.STRUCTURAL_VOLUME]:
					return false
	return true


static func _room_cantilever_geometry(lower: WarrenRoomStamp,
		upper: WarrenRoomStamp) -> Dictionary:
	## A room outcropping is an integrated floorplate change, not an arbitrary
	## upper room which happens not to register with the room beneath it. Its
	## unsupported columns form one contiguous strip beyond exactly one facade;
	## at least half of the upper plate remains on real bearing, and projection
	## depth is bounded to one 3 m bay. This describes the user's drawn jetty:
	## continuous upper wall over a void, with a legible attachment edge.
	var lower_columns := _room_columns(lower)
	var upper_columns := _room_columns(upper)
	var extension: Dictionary = {}
	var bearing := 0
	for column_value: Variant in upper_columns.keys():
		var column := column_value as Vector2i
		if lower_columns.has(column):
			bearing += 1
		else:
			extension[column] = true
	if upper_columns.size() < 4 or extension.is_empty():
		return {}
	var lower_bounds := _column_bounds(lower_columns)
	var direction := Vector2i.ZERO
	var depth := 0
	for column_value: Variant in extension.keys():
		var column := column_value as Vector2i
		var outside := Vector2i.ZERO
		var column_depth := 0
		if column.x < int(lower_bounds.minimum.x):
			outside = Vector2i.LEFT
			column_depth = int(lower_bounds.minimum.x) - column.x
		elif column.x > int(lower_bounds.maximum.x):
			outside = Vector2i.RIGHT
			column_depth = column.x - int(lower_bounds.maximum.x)
		elif column.y < int(lower_bounds.minimum.y):
			outside = Vector2i.UP
			column_depth = int(lower_bounds.minimum.y) - column.y
		elif column.y > int(lower_bounds.maximum.y):
			outside = Vector2i.DOWN
			column_depth = column.y - int(lower_bounds.maximum.y)
		else:
			return _cantilever_rejection(extension, bearing,
				upper_columns.size(), &"internal_hole")
		if direction == Vector2i.ZERO:
			direction = outside
		elif outside != direction:
			return _cantilever_rejection(extension, bearing,
				upper_columns.size(), &"multiple_facades")
		depth = maxi(depth, column_depth)
	if depth > 2:
		return _cantilever_rejection(extension, bearing,
			upper_columns.size(), &"projection_too_deep", direction, depth)
	if not _columns_are_connected(extension):
		return _cantilever_rejection(extension, bearing,
			upper_columns.size(), &"disconnected_projection", direction, depth)
	var attachment: Dictionary = {}
	for column_value: Variant in extension.keys():
		var column := column_value as Vector2i
		var inward := column - direction
		if lower_columns.has(inward):
			attachment[inward] = true
	if attachment.size() < 2:
		return _cantilever_rejection(extension, bearing,
			upper_columns.size(), &"attachment_too_narrow", direction, depth,
			attachment.size())
	var bearing_ratio := float(bearing) / float(upper_columns.size())
	if bearing_ratio < 0.50:
		return _cantilever_rejection(extension, bearing,
			upper_columns.size(), &"insufficient_bearing", direction, depth,
			attachment.size())
	return {
		"valid": true,
		"rejection": &"",
		"direction": direction,
		"depth_cells": depth,
		"attachment_span_cells": attachment.size(),
		"attachment_columns": _sorted_columns(attachment),
		"extension_columns": _sorted_columns(extension),
		"extension_column_count": extension.size(),
		"bearing_column_count": bearing,
		"bearing_ratio": bearing_ratio,
	}


static func _cantilever_rejection(extension: Dictionary, bearing: int,
		upper_count: int, rejection: StringName,
		direction: Vector2i = Vector2i.ZERO, depth: int = 0,
		attachment_span: int = 0) -> Dictionary:
	return {
		"valid": false,
		"rejection": rejection,
		"direction": direction,
		"depth_cells": depth,
		"attachment_span_cells": attachment_span,
		"extension_column_count": extension.size(),
		"bearing_column_count": bearing,
		"bearing_ratio": float(bearing) / float(upper_count) \
			if upper_count > 0 else 0.0,
	}


static func _room_columns(room: WarrenRoomStamp) -> Dictionary:
	var out: Dictionary = {}
	for cell: Vector3i in room.private_cells:
		out[Vector2i(cell.x, cell.z)] = true
	return out


static func _column_bounds(columns: Dictionary) -> Dictionary:
	var minimum := Vector2i(2147483647, 2147483647)
	var maximum := Vector2i(-2147483648, -2147483648)
	for column_value: Variant in columns.keys():
		var column := column_value as Vector2i
		minimum = minimum.min(column)
		maximum = maximum.max(column)
	return {"minimum": minimum, "maximum": maximum}


static func _columns_are_connected(columns: Dictionary) -> bool:
	if columns.is_empty():
		return false
	var keys: Array = columns.keys()
	var frontier: Array[Vector2i] = [keys[0] as Vector2i]
	var visited: Dictionary = {frontier[0]: true}
	while not frontier.is_empty():
		var column: Vector2i = frontier.pop_back()
		for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT,
				Vector2i.UP, Vector2i.DOWN]:
			var neighbor := column + direction
			if columns.has(neighbor) and not visited.has(neighbor):
				visited[neighbor] = true
				frontier.append(neighbor)
	return visited.size() == columns.size()


static func _sorted_columns(columns: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	out.assign(columns.keys())
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.x < b.x if a.x != b.x else a.y < b.y)
	return out


static func _room_endpoints(buildings: Array[WarrenBuildingVolume]) \
		-> Array[Dictionary]:
	var offset_rooms := _offset_room_ids(buildings)
	var out: Array[Dictionary] = []
	var seen: Dictionary = {}
	for building: WarrenBuildingVolume in buildings:
		for room: WarrenRoomStamp in building.room_records:
			var footprint := _room_footprint(room.kind)
			if footprint.is_empty():
				continue
			var minimum := footprint.minimum as Vector2i
			var maximum := minimum + footprint.size as Vector2i - Vector2i.ONE
			var locals: Array[Dictionary] = []
			for z in [minimum.y, 0, maximum.y]:
				locals.append({"cell": Vector3i(maximum.x, 0, z),
					"facing": Vector3i.RIGHT})
				locals.append({"cell": Vector3i(minimum.x, 0, z),
					"facing": Vector3i.LEFT})
			for x in [minimum.x, 0, maximum.x]:
				locals.append({"cell": Vector3i(x, 0, maximum.y),
					"facing": Vector3i.BACK})
				locals.append({"cell": Vector3i(x, 0, minimum.y),
					"facing": Vector3i.FORWARD})
			for local: Dictionary in locals:
				var cell := FabricRecipe.transform_cell(local.cell as Vector3i,
					room.lattice_origin, room.yaw_quarters)
				var facing := FabricRecipe.transform_direction(
					local.facing as Vector3i, room.yaw_quarters)
				var key := "%s/%s/%s" % [room.stable_id, cell, facing]
				if seen.has(key):
					continue
				seen[key] = true
				out.append({"cell": cell, "facing": facing,
					"building_id": building.stable_id,
					"room_id": room.stable_id,
					"offset_floorplate": offset_rooms.has(room.stable_id)})
	return out


static func _offset_room_ids(buildings: Array[WarrenBuildingVolume]) \
		-> Dictionary:
	var by_source: Dictionary = {}
	for building: WarrenBuildingVolume in buildings:
		for room: WarrenRoomStamp in building.room_records:
			if not by_source.has(room.source_parcel_id):
				by_source[room.source_parcel_id] = [] as Array[WarrenRoomStamp]
			(by_source[room.source_parcel_id] \
				as Array[WarrenRoomStamp]).append(room)
	var out: Dictionary = {}
	for rooms_value: Variant in by_source.values():
		var rooms := rooms_value as Array[WarrenRoomStamp]
		rooms.sort_custom(func(a: WarrenRoomStamp, b: WarrenRoomStamp) -> bool:
			return a.source_storey_index < b.source_storey_index)
		for index in range(1, rooms.size()):
			var lower := rooms[index - 1]
			var upper := rooms[index]
			if lower.lattice_origin.x != upper.lattice_origin.x \
					or lower.lattice_origin.z != upper.lattice_origin.z:
				out[upper.stable_id] = true
	return out


static func _room_footprint(kind: StringName) -> Dictionary:
	match kind:
		&"tower":
			return {"minimum": Vector2i(-1, -1), "size": Vector2i(2, 2)}
		&"slim":
			return {"minimum": Vector2i(-1, -2), "size": Vector2i(2, 4)}
		&"long":
			return {"minimum": Vector2i(-2, -3), "size": Vector2i(4, 6)}
		&"building":
			return {"minimum": Vector2i(-2, -2), "size": Vector2i(4, 4)}
		_:
			return {}


static func _yaw_from_right(direction: Vector3i) -> int:
	for yaw in 4:
		if FabricRecipe.transform_direction(Vector3i.RIGHT, yaw) == direction:
			return yaw
	return -1


static func _endpoint_key(cell: Vector3i, facing: Vector3i) -> String:
	return "%d:%d:%d/%d:%d:%d" % [cell.x, cell.y, cell.z, facing.x,
		facing.y, facing.z]


static func _pair_key(left: StringName, right: StringName) -> String:
	return "%s|%s" % [String(left), String(right)] \
		if String(left) < String(right) else "%s|%s" % [String(right),
			String(left)]


static func _cell_less(a: Vector3i, b: Vector3i) -> bool:
	if a.y != b.y:
		return a.y < b.y
	if a.z != b.z:
		return a.z < b.z
	return a.x < b.x
