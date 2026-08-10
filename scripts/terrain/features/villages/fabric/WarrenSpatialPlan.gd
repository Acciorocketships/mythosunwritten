class_name WarrenSpatialPlan
extends RefCounted

## Sealed source of truth for the fine-grid volumetric town.  Compatibility
## adapters may project this plan into the existing public-realm and FabricUnit
## layers, but they may never re-infer or mutate its topology.
var stable_id: StringName
var world_seed: int
var grid: WarrenSpatialGrid
## Optional immutable lineage for the first migration adapter. Geometry is
## never read back from this after seal; it only preserves the exact macro
## route identity while the production assembler learns the fine plan.
var source_volume: WarrenVolumePlan
var entry_floor_cell: Vector3i
var route_floor_cells: Array[Vector3i] = []
var buildings: Array[WarrenBuildingVolume] = []
var features: Array[WarrenFeatureReservation] = []
var support_graph: WarrenSupportGraph
## Phase-7 lossless merge of every exact grid face. Asset realization consumes
## these regions; it may not rebuild a shell from a 2D building footprint.
var construction_plan: WarrenConstructionRegionPlan
var audit: Dictionary = {}
var last_rejection := ""
var _route_set: Dictionary = {}
var _building_by_id: Dictionary = {}
var _sealed := false


func _init(p_stable_id: StringName, p_world_seed: int,
		p_grid: WarrenSpatialGrid) -> void:
	stable_id = p_stable_id
	world_seed = p_world_seed
	grid = p_grid


func add_route_floor(cell: Vector3i) -> bool:
	if _sealed or grid == null or not grid.contains(cell) or _route_set.has(cell):
		return false
	_route_set[cell] = true
	route_floor_cells.append(cell)
	return true


func add_building(building: WarrenBuildingVolume) -> bool:
	if _sealed or building == null or not building.is_sealed() \
			or _building_by_id.has(building.stable_id):
		return false
	_building_by_id[building.stable_id] = building
	buildings.append(building)
	return true


func add_feature(feature: WarrenFeatureReservation) -> bool:
	if _sealed or feature == null or not feature.is_sealed():
		return false
	for existing: WarrenFeatureReservation in features:
		if existing.stable_id == feature.stable_id:
			return false
	features.append(feature)
	return true


func set_support_graph(value: WarrenSupportGraph) -> bool:
	if _sealed or support_graph != null or value == null or not value.is_sealed():
		return false
	support_graph = value
	return true


func seal(p_entry_floor_cell: Vector3i) -> bool:
	last_rejection = ""
	if _sealed or stable_id.is_empty() or grid == null or not grid.is_valid() \
			or grid.is_sealed() or route_floor_cells.size() < 2 \
			or buildings.is_empty() or support_graph == null \
			or not support_graph.is_sealed() or not _route_set.has(
				p_entry_floor_cell):
		return _reject("missing grid, route, entry, buildings, or support graph")
	entry_floor_cell = p_entry_floor_cell
	if not _validate_route():
		return false
	if not _validate_building_ownership():
		return false
	var allocatable_count := grid.count_use(WarrenSpatialGrid.Use.ALLOCATABLE)
	if allocatable_count != 0:
		return _reject("allocatable mass survives final classification")
	for building: WarrenBuildingVolume in buildings:
		if not support_graph.reaches_terrain(building.stable_id):
			return _reject("building support does not reach terrain: %s" \
				% building.stable_id)
	var interface_audit := _interface_audit()
	if int(interface_audit.unclassified_public_private_face_count) != 0:
		return _reject("public/private interface is unclassified")
	if int(interface_audit.missing_roof_face_count) != 0:
		return _reject("private volume terminates without a roof interface")
	if int(interface_audit.threshold_face_mismatch_count) != 0:
		return _reject("building threshold is not a door interface")
	construction_plan = WarrenConstructionRegionPlan.derive(
		StringName("%s.construction" % stable_id), grid)
	if construction_plan == null:
		return _reject("construction interfaces could not be derived")
	audit = {
		"public_route_floor_count": route_floor_cells.size(),
		"public_air_cell_count": grid.count_use(
			WarrenSpatialGrid.Use.PUBLIC_AIR),
		"private_volume_cell_count": grid.count_use(
			WarrenSpatialGrid.Use.PRIVATE_VOLUME),
		"structural_volume_cell_count": grid.count_use(
			WarrenSpatialGrid.Use.STRUCTURAL_VOLUME),
		"daylight_air_cell_count": grid.count_use(
			WarrenSpatialGrid.Use.DAYLIGHT_AIR),
		"allocatable_cell_count": allocatable_count,
		"building_count": buildings.size(),
		"feature_count": features.size(),
	}
	audit.merge(interface_audit, true)
	audit.merge(construction_plan.audit, true)
	if not grid.seal():
		return _reject("fine grid could not seal")
	_sealed = true
	return true


func is_sealed() -> bool:
	return _sealed


func deterministic_signature() -> String:
	var building_parts := PackedStringArray()
	for building: WarrenBuildingVolume in buildings:
		building_parts.append(building.deterministic_signature())
	building_parts.sort()
	var feature_parts := PackedStringArray()
	for feature: WarrenFeatureReservation in features:
		feature_parts.append(feature.deterministic_signature())
	feature_parts.sort()
	var routes := PackedStringArray()
	for cell: Vector3i in route_floor_cells:
		routes.append("%d:%d:%d" % [cell.x, cell.y, cell.z])
	routes.sort()
	return "%s/%d|grid=%s|route=%s|buildings=%s|features=%s|support=%s|construction=%s" % [
		String(stable_id), world_seed, grid.deterministic_signature(),
		",".join(routes), "|".join(building_parts),
		"|".join(feature_parts), support_graph.deterministic_signature(),
		construction_plan.deterministic_signature()]


func _validate_route() -> bool:
	for cell: Vector3i in route_floor_cells:
		if grid.use_at(cell) != WarrenSpatialGrid.Use.PUBLIC_AIR \
				or grid.use_at(cell + Vector3i.UP) \
					!= WarrenSpatialGrid.Use.PUBLIC_AIR:
			return _reject("public route lacks full swept headroom at %s" % cell)
		var floor := grid.face_claim(cell, Vector3i.DOWN)
		if floor.is_empty() or int(floor.kind) \
				!= WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR:
			return _reject("public route lacks a classified floor at %s" % cell)
	var seen: Dictionary = {route_floor_cells[0]: true}
	var frontier: Array[Vector3i] = [route_floor_cells[0]]
	while not frontier.is_empty():
		var cell: Vector3i = frontier.pop_back()
		for candidate: Vector3i in route_floor_cells:
			if seen.has(candidate) or not _route_neighbors(cell, candidate):
				continue
			seen[candidate] = true
			frontier.append(candidate)
	if seen.size() != route_floor_cells.size():
		return _reject("public route graph is disconnected")
	return true


func _validate_building_ownership() -> bool:
	var claimed: Dictionary = {}
	for building: WarrenBuildingVolume in buildings:
		for cell: Vector3i in building.private_cells:
			if claimed.has(cell):
				return _reject("building volumes overlap at %s" % cell)
			claimed[cell] = building.stable_id
	for cell: Vector3i in grid.cells_with_use(
			WarrenSpatialGrid.Use.PRIVATE_VOLUME):
		var owner_id := grid.owner_name_at(cell)
		if not _building_by_id.has(owner_id) \
				or not (_building_by_id[owner_id] as WarrenBuildingVolume) \
					.has_private_cell(cell) or claimed.get(cell, &"") != owner_id:
			return _reject("private cell has no exact building owner at %s" % cell)
	if claimed.size() != grid.count_use(WarrenSpatialGrid.Use.PRIVATE_VOLUME):
		return _reject("building ownership does not cover private volume")
	return true


func _interface_audit() -> Dictionary:
	var unclassified := 0
	var missing_roofs := 0
	var threshold_mismatch := 0
	var allowed_public_faces: Dictionary = {
		WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR: true,
		WarrenSpatialGrid.FaceKind.FACADE: true,
		WarrenSpatialGrid.FaceKind.DOOR: true,
		WarrenSpatialGrid.FaceKind.SOFFIT: true,
		WarrenSpatialGrid.FaceKind.ROOF: true,
		WarrenSpatialGrid.FaceKind.CONSTRUCTION_JOINT: true,
	}
	for building: WarrenBuildingVolume in buildings:
		for cell: Vector3i in building.private_cells:
			for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
					Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD,
					Vector3i.BACK]:
				var neighbor: Vector3i = cell + direction
				if grid.use_at(neighbor) != WarrenSpatialGrid.Use.PUBLIC_AIR:
					continue
				var face := grid.face_claim(cell, direction)
				unclassified += int(face.is_empty() \
					or not allowed_public_faces.has(int(face.get("kind", -1))))
			var above: Vector3i = cell + Vector3i.UP
			if building.has_private_cell(above) \
					or grid.use_at(above) == WarrenSpatialGrid.Use.PRIVATE_VOLUME:
				continue
			var roof := grid.face_claim(cell, Vector3i.UP)
			var roof_kind := int(roof.get("kind", -1))
			var carries_public_floor := grid.use_at(above) \
				== WarrenSpatialGrid.Use.PUBLIC_AIR and roof_kind \
				== WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR
			missing_roofs += int(roof.is_empty() or roof_kind \
				!= WarrenSpatialGrid.FaceKind.ROOF and not carries_public_floor)
		for threshold: Dictionary in building.thresholds:
			var private_cell := threshold.private_cell as Vector3i
			var public_cell := threshold.public_cell as Vector3i
			var face := grid.face_claim(private_cell,
				public_cell - private_cell)
			threshold_mismatch += int(face.is_empty() \
				or int(face.get("kind", -1)) != WarrenSpatialGrid.FaceKind.DOOR)
	return {
		"unclassified_public_private_face_count": unclassified,
		"missing_roof_face_count": missing_roofs,
		"threshold_face_mismatch_count": threshold_mismatch,
	}


static func _route_neighbors(left: Vector3i, right: Vector3i) -> bool:
	var delta := right - left
	return absi(delta.x) + absi(delta.z) == 1 and absi(delta.y) <= 1


func _reject(reason: String) -> bool:
	last_rejection = reason
	return false
