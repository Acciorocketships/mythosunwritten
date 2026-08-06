class_name VillageTimberFabricSolver
extends RefCounted

## Shared fixed-cell structural materializer. It derives exposed railings and
## sparse boundary supports from the union of cells, so curved walkways and
## skirts cannot disagree about seams or create doubled internal barriers.
const EPS := 0.001
# Corner coordinates advance by two half-modules along an axis-aligned cell.
# A modulus of two therefore selected every corner, producing a picket forest
# below otherwise thin streets. This lattice phase selects roughly one stack
# per three modules in cardinal and diagonal runs while staying deterministic.
const SUPPORT_SPACING_BUCKETS := 6


static func solve(terrain: VillageTerrainView, settlement_id: StringName,
		input_cells: Array[VillageTimberCell],
		vocabulary: VillageElevatedProgram,
		support_exclusions: Array[Dictionary] = [],
		railing_exclusions: Array[Dictionary] = [],
		openings: Array[FeatureGroundShape] = []) -> VillageTimberFabricPlan:
	assert(terrain != null and not settlement_id.is_empty())
	assert(vocabulary != null)
	if input_cells.is_empty():
		return _rejected(&"cells")
	var plan := VillageTimberFabricPlan.new()
	var walk_network_id := StringName("%s.urban.walk_network" % settlement_id)
	plan.cells.assign(input_cells)
	plan.cells.sort_custom(_cell_less)
	for cell: VillageTimberCell in plan.cells:
		var top_y := cell.floor_y
		var bottom_y := top_y - vocabulary.floor_aabb.size.y
		var basis := Basis(Vector3.UP, -cell.yaw)
		var local_contact := Vector3(vocabulary.floor_aabb.get_center().x,
			vocabulary.floor_aabb.position.y,
			vocabulary.floor_aabb.get_center().z)
		plan.entries.append({"asset_id": vocabulary.floor_asset_id,
			"stable_id": cell.stable_id,
			"transform": Transform3D(basis,
				Vector3(cell.centre.x, bottom_y, cell.centre.y)
					- basis * local_contact)})
		plan.volumes.append(VillageOccupancyVolume.new(
			VillageOccupancy.Role.WALK_SURFACE, cell.centre,
			Vector2.ONE * VillageProgram.MODULE * 0.5, cell.yaw,
			bottom_y, top_y, StringName("%s.walk" % cell.stable_id),
			cell.owner_id, walk_network_id))
	var railings := _railings(settlement_id, plan.cells, vocabulary,
		railing_exclusions, openings)
	plan.entries.append_array(railings.entries)
	plan.volumes.append_array(railings.volumes)
	plan.railing_count = int(railings.count)
	var supports := _supports(terrain, settlement_id, plan.cells,
		vocabulary, support_exclusions)
	plan.entries.append_array(supports.entries)
	plan.volumes.append_array(supports.volumes)
	plan.support_count = int(supports.count)
	plan.support_piece_count = int(supports.piece_count)
	if plan.railing_count <= 0 or plan.support_count <= 0:
		return _rejected(&"structural_edges")
	plan.accepted = true
	plan.reason = &"accepted"
	var rejection := plan.rejection_reason()
	if not rejection.is_empty():
		return _rejected(StringName("invalid_%s" % String(rejection)))
	return plan


static func _railings(settlement_id: StringName,
		cells: Array[VillageTimberCell], vocabulary: VillageElevatedProgram,
		exclusions: Array[Dictionary],
		openings: Array[FeatureGroundShape]) -> Dictionary:
	var entries: Array[Dictionary] = []
	var volumes: Array[VillageOccupancyVolume] = []
	for cell: VillageTimberCell in cells:
		var axis_x := Vector2.RIGHT.rotated(cell.yaw)
		var axis_z := Vector2.DOWN.rotated(cell.yaw)
		for normal: Vector2 in [axis_x, axis_z, -axis_x, -axis_z]:
			var edge := cell.centre + normal * VillageProgram.MODULE * 0.5
			var tangent := Vector2(-normal.y, normal.x)
			var extents := Vector2(vocabulary.railing_aabb.size.x,
				vocabulary.railing_aabb.size.z) * 0.5
			if _edge_is_covered(edge, normal, cell.floor_y, cells) \
					or _railing_hits_other_floor(edge, extents,
						tangent.angle(), cell, cells,
						vocabulary.railing_aabb.size.y,
						vocabulary.floor_aabb.size.y) \
					or _point_in_any(edge, openings):
				continue
			if _volume_hits_any(edge, extents, tangent.angle(), cell.floor_y,
					cell.floor_y + vocabulary.railing_aabb.size.y, exclusions):
				continue
			var basis := Basis(Vector3.UP, -tangent.angle())
			var local_contact := Vector3(
				vocabulary.railing_aabb.get_center().x,
				vocabulary.railing_aabb.position.y,
				vocabulary.railing_aabb.get_center().z)
			var stable_id := StringName("%s.urban.railing.%04d" % [
				settlement_id, entries.size()])
			entries.append({"asset_id": vocabulary.railing_asset_id,
				"stable_id": stable_id,
				"transform": Transform3D(basis,
					Vector3(edge.x, cell.floor_y, edge.y)
						- basis * local_contact)})
			volumes.append(VillageOccupancyVolume.new(
				VillageOccupancy.Role.WALK_GUARD, edge, extents, tangent.angle(),
				cell.floor_y, cell.floor_y + vocabulary.railing_aabb.size.y,
				StringName("%s.solid" % stable_id), cell.owner_id,
				StringName("%s.urban.walk_network" % settlement_id)))
	return {"entries": entries, "volumes": volumes,
		"count": entries.size()}


static func _supports(terrain: VillageTerrainView,
		settlement_id: StringName, cells: Array[VillageTimberCell],
		vocabulary: VillageElevatedProgram,
		exclusions: Array[Dictionary]) -> Dictionary:
	var corners: Dictionary = {}
	var half := VillageProgram.MODULE * 0.5
	for cell: VillageTimberCell in cells:
		for local: Vector2 in [Vector2(-half, -half), Vector2(half, -half),
				Vector2(half, half), Vector2(-half, half)]:
			var point := cell.centre + local.rotated(cell.yaw)
			var key := _point_y_key(point, cell.floor_y)
			var item: Dictionary = corners.get(key, {"point": point,
				"floor_y": cell.floor_y, "yaw": cell.yaw, "count": 0,
				"owner_id": cell.owner_id})
			item.count = int(item.count) + 1
			if item.owner_id != cell.owner_id:
				item.owner_id = &""
			corners[key] = item
	var keys: Array = corners.keys()
	keys.sort()
	var entries: Array[Dictionary] = []
	var volumes: Array[VillageOccupancyVolume] = []
	var accepted := 0
	var module := vocabulary.timber_module()
	for candidate_index in keys.size():
		var item: Dictionary = corners[keys[candidate_index]]
		if int(item.count) >= 4:
			continue
		var point: Vector2 = item.point
		var floor_y := float(item.floor_y)
		var yaw := float(item.yaw)
		var owner_id: StringName = item.owner_id
		var qx := roundi(point.x / (VillageProgram.MODULE * 0.5))
		var qz := roundi(point.y / (VillageProgram.MODULE * 0.5))
		if posmod(qx + qz * 2, SUPPORT_SPACING_BUCKETS) != 0 \
				or _volume_hits_any(point, module.half_extents, yaw,
					-INF, floor_y, exclusions):
			continue
		var wet := false
		for sample: Vector2 in SupportSolver.ground_samples(point, yaw,
				[module]):
			if terrain.is_wet(sample):
				wet = true
				break
		if wet:
			continue
		var shape := FeatureGroundShape.oriented_rect(point,
			module.half_extents, yaw)
		var request := SupportRequest.new(
			StringName("%s.urban.walk_support.%04d" % [settlement_id,
				candidate_index]), [point],
			floor_y - vocabulary.floor_aabb.size.y, yaw, [module],
			0.18, VillageElevatedProgram.MAX_SUPPORT_GROUND_SPAN,
			VillageElevatedProgram.MAX_TIMBER_SUPPORT_BURIAL,
			VillageElevatedProgram.MAX_ROCK_STACK_MODULES,
			SupportRequest.GroundReference.HIGHEST, owner_id)
		var solved := SupportSolver.solve(request,
			terrain.region_covering(shape.bounds()))
		if not bool(solved.accepted) or _support_hits_foreign_floor(
				solved.volumes, owner_id, cells,
				vocabulary.floor_aabb.size.y):
			continue
		entries.append_array(solved.pieces)
		volumes.append_array(solved.volumes)
		accepted += 1
	return {"entries": entries, "volumes": volumes, "count": accepted,
		"piece_count": entries.size()}


static func _support_hits_foreign_floor(
		supports: Array[VillageOccupancyVolume], owner_id: StringName,
		cells: Array[VillageTimberCell], floor_thickness: float) -> bool:
	for support: VillageOccupancyVolume in supports:
		for cell: VillageTimberCell in cells:
			if not owner_id.is_empty() and owner_id == cell.owner_id:
				continue
			var floor_volume := VillageOccupancyVolume.new(
				VillageOccupancy.Role.WALK_SURFACE, cell.centre,
				Vector2.ONE * VillageProgram.MODULE * 0.5, cell.yaw,
				cell.floor_y - floor_thickness, cell.floor_y,
				&"floor.proof", cell.owner_id)
			if support.overlaps(floor_volume):
				return true
	return false


static func _edge_is_covered(edge: Vector2, normal: Vector2, floor_y: float,
		cells: Array[VillageTimberCell]) -> bool:
	var probe := edge + normal * 0.02
	for other: VillageTimberCell in cells:
		if absf(other.floor_y - floor_y) \
				<= TraversalEnvelope.MAX_PLANNED_STEP + EPS \
				and other.shape().contains(probe):
			return true
	return false


static func _railing_hits_other_floor(centre: Vector2,
		half_extents: Vector2, yaw: float, source: VillageTimberCell,
		cells: Array[VillageTimberCell], railing_height: float,
		floor_thickness: float) -> bool:
	var railing_shape := FeatureGroundShape.oriented_rect(centre,
		half_extents, yaw)
	for other: VillageTimberCell in cells:
		if other == source or not VillageRouteGeometry.vertical_overlap(
				source.floor_y, source.floor_y + railing_height,
				other.floor_y - floor_thickness, other.floor_y):
			continue
		if railing_shape.intersects(other.shape()):
			return true
	return false


static func _point_in_any(point: Vector2,
		shapes: Array[FeatureGroundShape]) -> bool:
	for shape: FeatureGroundShape in shapes:
		if shape.contains(point):
			return true
	return false


static func _volume_hits_any(centre: Vector2, half_extents: Vector2,
		yaw: float, minimum_y: float, maximum_y: float,
		exclusions: Array[Dictionary]) -> bool:
	var shape := FeatureGroundShape.oriented_rect(centre, half_extents, yaw)
	for item: Dictionary in exclusions:
		var other: FeatureGroundShape = item.shape
		if shape.intersects(other) and VillageRouteGeometry.vertical_overlap(
				minimum_y, maximum_y, float(item.min_y), float(item.max_y)):
			return true
	return false


static func _cell_less(a: VillageTimberCell,
		b: VillageTimberCell) -> bool:
	return String(a.stable_id) < String(b.stable_id)


static func _point_y_key(point: Vector2, floor_y: float) -> String:
	return "%d:%d:%d" % [roundi(point.x * 1000.0),
		roundi(point.y * 1000.0), roundi(floor_y * 1000.0)]


static func _rejected(reason: StringName) -> VillageTimberFabricPlan:
	var plan := VillageTimberFabricPlan.new()
	plan.reason = reason
	return plan
