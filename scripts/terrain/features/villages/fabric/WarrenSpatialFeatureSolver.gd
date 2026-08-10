class_name WarrenSpatialFeatureSolver
extends RefCounted

## Commits topology-first composed features into the still-mutable fine grid.
## Each accepted feature owns one atomic reservation and, where appropriate,
## its exact private/structural cells and construction transform. Generic room
## and roof compilation may respond to these facts but never recreate them.
const TARGET_SKYWALKS := 3
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


static func solve(grid: WarrenSpatialGrid, source: WarrenVolumePlan,
		buildings: Array[WarrenBuildingVolume], supports: WarrenSupportGraph,
		preplanned_skywalks: Array[Dictionary] = [],
		preplanned_market: Dictionary = {}) \
		-> Array[WarrenFeatureReservation]:
	last_failure = ""
	last_audit = {}
	last_skywalk_diagnostic = {}
	if grid == null or grid.is_sealed() or source == null \
			or not source.is_sealed() or buildings.is_empty() or supports == null \
			or not supports.is_sealed():
		last_failure = "missing mutable grid, source volume, buildings, or supports"
		return [] as Array[WarrenFeatureReservation]
	var out: Array[WarrenFeatureReservation] = []
	var court := _reserve_courtyard(grid, source, buildings, supports)
	if court == null:
		return [] as Array[WarrenFeatureReservation]
	out.append(court)
	var market := _reserve_preplanned_market(grid, buildings, supports,
		preplanned_market)
	if market == null:
		return [] as Array[WarrenFeatureReservation]
	out.append(market)
	var skywalks := _reserve_preplanned_skywalks(grid, buildings, supports,
		preplanned_skywalks) if not preplanned_skywalks.is_empty() \
		else _reserve_skywalks(grid, buildings, supports, source.world_seed)
	if skywalks.size() < TARGET_SKYWALKS:
		var detail := last_failure
		last_failure = "only %d of %d topology-first skywalks fit: %s (%s)" % [
			skywalks.size(), TARGET_SKYWALKS, detail,
			last_skywalk_diagnostic]
		return [] as Array[WarrenFeatureReservation]
	out.append_array(skywalks)
	var outcroppings := _reserve_room_outcroppings(grid, buildings, supports,
		source.world_seed)
	if outcroppings.size() < TARGET_ROOM_OUTCROPPINGS:
		last_failure = "only %d of %d room-scale outcroppings exist" % [
			outcroppings.size(), TARGET_ROOM_OUTCROPPINGS]
		return [] as Array[WarrenFeatureReservation]
	out.append_array(outcroppings)
	last_audit = {
		"elevated_courtyard_count": 1,
		"covered_market_count": 1,
		"enclosed_skywalk_count": skywalks.size(),
		"room_outcropping_count": outcroppings.size(),
		"feature_count": out.size(),
	}
	last_audit.merge(court.audit, false)
	return out


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
		if support_owner.is_empty():
			support_owner = StringName(endpoint.owner_id)
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
				"market_stocked_bay_count": 1,
				"market_continuous_canopy": true,
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
		reservations: Array[Dictionary]) -> Array[WarrenFeatureReservation]:
	## Commit the exact feature-set selected before room partition. The former
	## late scanner threw those reservations away and tried to rediscover only
	## straight links after rooms had consumed the surrounding mass, which made
	## a topology-first plan indistinguishable from the retired detail pass.
	var out: Array[WarrenFeatureReservation] = []
	var offset_rooms := _offset_room_ids(buildings)
	for reservation_index in reservations.size():
		var reservation := reservations[reservation_index]
		var resolved := _resolve_preplanned_endpoints(reservation, buildings)
		if resolved.size() != 2:
			last_skywalk_diagnostic = _preplanned_endpoint_diagnostic(grid,
				reservation, buildings, reservation_index)
			last_failure = "preplanned skywalk %d lost an exact room endpoint" \
				% reservation_index
			return [] as Array[WarrenFeatureReservation]
		var endpoint_owner_ids: Dictionary = {}
		var offset_endpoint_count := 0
		for endpoint: Dictionary in resolved:
			endpoint_owner_ids[StringName(endpoint.building_id)] = true
			offset_endpoint_count += int(offset_rooms.has(
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
			offset_endpoint_count)
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


static func _resolve_preplanned_endpoints(reservation: Dictionary,
		buildings: Array[WarrenBuildingVolume]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
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
					"source_parcel_id": source_parcel_id}
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
		offset_endpoint_count: int) -> WarrenFeatureReservation:
	var feature_id := StringName("spatial.feature.skywalk.%02d" % ordinal)
	var body_set: Dictionary = {}
	for cell: Vector3i in body:
		body_set[cell] = true
	var endpoint_cells: Dictionary = {}
	for endpoint: Dictionary in resolved:
		endpoint_cells[endpoint.cell as Vector3i] = true
	var tx := grid.begin_transaction(feature_id)
	if not tx.require_use(body, [WarrenSpatialGrid.Use.OUTSIDE,
			WarrenSpatialGrid.Use.ALLOCATABLE] as Array[int]) \
			or not tx.reserve(body, WarrenSpatialGrid.Reservation.FEATURE \
				| WarrenSpatialGrid.Reservation.PRIVATE_CONNECTION \
				| WarrenSpatialGrid.Reservation.VISUAL_CLEARANCE, feature_id) \
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
	if not feature.set_support_node(StringName(left.building_id)) \
			or not feature.set_audit_facts({
				"skywalk_kind": StringName(reservation.get("kind", &"straight")),
				"skywalk_component_count": components.size(),
				"skywalk_lower_public_column_count": lower_public_column_count,
				"skywalk_offset_endpoint_count": offset_endpoint_count,
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
		world_seed: int) -> Array[WarrenFeatureReservation]:
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
		if out.size() >= TARGET_SKYWALKS:
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
		world_seed: int) -> Array[WarrenFeatureReservation]:
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
			var lower_columns: Dictionary = {}
			for cell: Vector3i in lower.private_cells:
				lower_columns[Vector2i(cell.x, cell.z)] = true
			var upper_columns: Dictionary = {}
			var extension_columns: Dictionary = {}
			for cell: Vector3i in upper.private_cells:
				var column := Vector2i(cell.x, cell.z)
				upper_columns[column] = true
				if not lower_columns.has(column):
					extension_columns[column] = true
			if upper_columns.size() < 4 or extension_columns.is_empty():
				continue
			candidates.append({"lower": lower, "upper": upper,
				"building": building_by_room[upper.stable_id], "delta": delta,
				"extension_column_count": extension_columns.size(),
				"tie": posmod(Helper._mix64(world_seed \
					^ String(upper.stable_id).hash()), 1000003)})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.extension_column_count) != int(b.extension_column_count):
			return int(a.extension_column_count) > int(b.extension_column_count)
		return int(a.tie) < int(b.tie))
	var out: Array[WarrenFeatureReservation] = []
	var used_buildings: Dictionary = {}
	for candidate: Dictionary in candidates:
		if out.size() >= TARGET_ROOM_OUTCROPPINGS:
			break
		var building := candidate.building as WarrenBuildingVolume
		if used_buildings.has(building.stable_id):
			continue
		var upper := candidate.upper as WarrenRoomStamp
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
				or not feature.set_support_node(building.stable_id) \
				or not feature.set_audit_facts({
					"outcrop_upper_room_id": upper.stable_id,
					"outcrop_lower_room_id": (candidate.lower \
						as WarrenRoomStamp).stable_id,
					"outcrop_extension_column_count": int(
						candidate.extension_column_count),
					"outcrop_room_footprint_column_count": \
						upper.private_cells.size() / WarrenSpatialGrid.STOREY_CELLS,
				}) or not feature.seal(grid, supports):
			last_failure = "room outcropping seal failed: %s" % \
				feature.last_rejection
			return [] as Array[WarrenFeatureReservation]
		used_buildings[building.stable_id] = true
		out.append(feature)
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
