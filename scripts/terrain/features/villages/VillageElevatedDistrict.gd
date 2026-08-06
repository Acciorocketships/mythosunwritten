class_name VillageElevatedDistrict
extends RefCounted

## Pure atomic compiler for the inhabited vertical-street graph. Rock plinths
## carry the grounded part of each building; square timber cells exist only
## beneath an overhang or along a thin route. All instances, occupancy, and
## audit data are proposed before the caller can observe the district.
# Boundary corners live on the half-module lattice. A parity of eight selects
# each side roughly every four 1.5 m cells (six metres), alternating across a
# one-cell street so the undercroft stays structurally legible rather than
# becoming a forest of posts.
const SUPPORT_PARITY := 8

static func solve(frame: VillageFrame, tier: StringName, theme: StringName,
		street_axis: Vector2, accepted_streets: Dictionary,
		program: VillageProgram, occupancy: VillageOccupancy,
		fields: WorldFieldBlockCache = null, side_sign: float = 1.0) -> Dictionary:
	assert(side_sign == 1.0 or side_sign == -1.0)
	var vocabulary := program.elevated_program
	if vocabulary == null or not vocabulary.eligible(tier):
		return _rejected(&"not_applicable")
	var datum_y := TerrainSurfaceField.surface_y(_region_at(frame, fields,
		frame.centre), frame.centre.x, frame.centre.y)
	var entries: Array[Dictionary] = []
	var volumes: Array[VillageOccupancyVolume] = []
	var surfaces: Array[FeatureGroundShape] = []
	var clearances: Array[FeatureGroundShape] = []
	var walk_cells: Dictionary = {}
	var building_plans: Dictionary = {}
	var building_audit: Array[Dictionary] = []
	var cores: Array[Dictionary] = []
	var building_solids: Array[Dictionary] = []
	var rock_piece_count := 0
	for node: VillageElevatedBuildingSpec in vocabulary.buildings_for_tier(tier):
		var built := _building(frame, theme, street_axis, side_sign, datum_y, node,
			vocabulary, program, fields)
		if not bool(built.accepted):
			return _rejected(StringName("building_%s" % String(built.reason)))
		entries.append_array(built.entries)
		volumes.append_array(built.volumes)
		clearances.append(built.clearance)
		for cell: Dictionary in built.walk_cells:
			walk_cells[_cell_key(cell.point, int(cell.level))] = cell
		building_plans[node.stable_key] = built.plan
		building_audit.append(built.audit)
		cores.append(built.plan.core)
		building_solids.append(built.plan.solid)
		rock_piece_count += int(built.rock_piece_count)
	var network := _network(frame, tier, street_axis, side_sign, datum_y,
		accepted_streets, vocabulary, building_plans, fields)
	if not bool(network.accepted):
		return _rejected(StringName("route_%s" % String(network.reason)))
	entries.append_array(network.entries)
	volumes.append_array(network.volumes)
	surfaces.append_array(network.surfaces)
	clearances.append_array(network.clearances)
	for cell: Dictionary in network.walk_cells:
		walk_cells[_cell_key(cell.point, int(cell.level))] = cell
	# Rock is the walk-bearing fabric wherever the plinth reaches. Removing a
	# whole timber cell on any core overlap makes the "wood only where the
	# building overhangs" rule true by construction. Test the tile footprint,
	# not its centre: a boundary tile may otherwise intrude halfway into rock.
	for key: String in walk_cells.keys():
		var cell: Dictionary = walk_cells[key]
		if _footprint_overlaps_any(cell.point,
				vocabulary.floor_size * 0.5, street_axis.angle(), cores):
			walk_cells.erase(key)
	var skirt_tile_count := 0
	for cell: Dictionary in walk_cells.values():
		if cell.kind == &"skirt":
			skirt_tile_count += 1
	var support_exclusions: Array[Dictionary] = cores.duplicate()
	support_exclusions.append_array(network.support_exclusions)
	var railing_exclusions: Array[Dictionary] = cores.duplicate()
	railing_exclusions.append_array(building_solids)
	railing_exclusions.append_array(network.support_exclusions)
	var floors := _walk_fabric(frame, street_axis, datum_y, walk_cells,
		support_exclusions, railing_exclusions, network.railing_openings,
		vocabulary, fields)
	if not bool(floors.accepted):
		return _rejected(StringName("walk_%s" % String(floors.reason)))
	entries.append_array(floors.entries)
	volumes.append_array(floors.volumes)
	var ground_activities := _ground_activities(frame, tier, theme, street_axis,
		side_sign, vocabulary, building_plans, program, fields)
	entries.append_array(ground_activities.entries)
	volumes.append_array(ground_activities.volumes)
	clearances.append_array(ground_activities.clearances)
	var undercroft := _undercroft(frame, building_plans,
		vocabulary, fields)
	if not bool(undercroft.accepted):
		return _rejected(StringName("undercroft_%s" \
			% String(undercroft.reason)))
	volumes.append_array(undercroft.volumes)
	clearances.append_array(undercroft.clearances)
	var conflict := occupancy.first_conflict(volumes)
	if not conflict.is_empty():
		var candidate := conflict.candidate as VillageOccupancyVolume
		var existing := conflict.existing as VillageOccupancyVolume
		return _rejected(&"occupancy", "%s conflicts with %s" % [
			String(candidate.stable_id), String(existing.stable_id)])
	assert(occupancy.add_all(volumes))
	var centre := Vector2.ZERO
	for node: VillageElevatedBuildingSpec in vocabulary.buildings_for_tier(tier):
		centre += _world(frame.centre, street_axis, node.local_door, side_sign)
	centre /= float(vocabulary.buildings_for_tier(tier).size())
	return {
		"accepted": true,
		"reason": &"",
		"entries": entries,
		"volumes": volumes,
		"surfaces": surfaces,
		"clearances": clearances,
		"centre": centre,
		"buildings": building_audit,
		"transitions": network.audit,
		"walkways": network.walkways,
		"descents": network.descents,
		"undercroft": undercroft.audit,
		"level_count": 3,
		"support_count": int(floors.support_count),
		"support_piece_count": int(floors.support_piece_count),
		"railing_count": int(floors.railing_count),
		"timber_tile_count": walk_cells.size(),
		"rock_piece_count": rock_piece_count,
		"skirt_tile_count": skirt_tile_count,
		"walkway_tile_count": walk_cells.size() - skirt_tile_count,
		"walk_cells": _sorted_cells(walk_cells),
	}

static func materialize(result: Dictionary,
		payload: EnvironmentInstancePayload,
		surfaces: Array[FeatureGroundShape],
		clearances: Array[FeatureGroundShape]) -> void:
	assert(bool(result.accepted))
	for entry: Dictionary in result.entries:
		payload.add(entry.asset_id, entry.transform, Color.WHITE,
			entry.stable_id)
	surfaces.append_array(result.surfaces)
	clearances.append_array(result.clearances)

static func _building(frame: VillageFrame, theme: StringName,
		street_axis: Vector2, side_sign: float, datum_y: float,
		node: VillageElevatedBuildingSpec,
		vocabulary: VillageElevatedProgram, program: VillageProgram,
		fields: WorldFieldBlockCache) -> Dictionary:
	var spec := program.assets[node.asset_id] as VillageAssetSpec
	var door := _world(frame.centre, street_axis, node.local_door, side_sign)
	var outward := _direction(street_axis, node.local_outward, side_sign)
	var placement := spec.placement_for_door(door, outward)
	var flat := Transform3D(Basis(Vector3.UP, float(placement.yaw)),
		Vector3(float(placement.origin.x), 0.0,
			float(placement.origin.y)))
	var floor_y := vocabulary.level_y(datum_y, node.level)
	var transform := flat
	transform.origin.y = floor_y - spec.entrance_floor_local_y
	var contact := spec.world_ground_contact(transform)
	var core := _plinth_rect(contact, outward)
	if core.is_empty():
		return _building_rejected(&"plinth_grid")
	var rock_module := vocabulary.rock_module(program)
	var entries: Array[Dictionary] = []
	var rock_piece_count := 0
	var lowest_ground := INF
	for support: Dictionary in _perimeter_supports(core,
			program.foundation_module_width,
			program.foundation_module_depth):
		var anchor: Vector2 = support.anchor
		if not program.anchor_allowed(frame.centre, anchor):
			return _building_rejected(&"anchor_bounds")
		var modules: Array[SupportModule] = [rock_module]
		var region := _region_at(frame, fields, anchor)
		var bounds := SupportSolver.ground_bounds(anchor, float(support.angle),
			modules, region)
		if bounds.y - bounds.x \
				> VillageElevatedProgram.MAX_SUPPORT_GROUND_SPAN + 0.001:
			return _building_rejected(&"plinth_ground_span")
		for point: Vector2 in SupportSolver.ground_samples(anchor,
				float(support.angle), modules):
			if _is_wet(frame, fields, point):
				return _building_rejected(&"plinth_water")
		lowest_ground = minf(lowest_ground, bounds.x)
		var request := SupportRequest.new(
			StringName("%s.elevated.%s.rock.%03d" % [frame.settlement_id,
				String(node.stable_key), int(support.index)]), [anchor], floor_y,
			float(support.angle), modules,
			program.foundation_module_depth * 0.5,
			VillageElevatedProgram.MAX_SUPPORT_GROUND_SPAN,
			VillageElevatedProgram.MAX_ROCK_SUPPORT_BURIAL,
			VillageElevatedProgram.MAX_ROCK_STACK_MODULES,
			SupportRequest.GroundReference.LOWEST)
		var solved := SupportSolver.solve(request, region)
		if not bool(solved.accepted):
			return _building_rejected(StringName("plinth_%s" \
				% String(solved.reason)))
		entries.append_array(solved.pieces)
		rock_piece_count += (solved.pieces as Array).size()
	var stable_id := StringName("%s.elevated.building.%s" % [
		frame.settlement_id, String(node.stable_key)])
	entries.append({"asset_id": spec.asset_for_theme(theme),
		"stable_id": stable_id, "transform": transform})
	for attachment: VillageAttachedAssetSpec in spec.attachments:
		entries.append({"asset_id": attachment.asset_for_theme(theme),
			"stable_id": StringName("%s.component.%s" % [stable_id,
				String(attachment.stable_key)]),
			"transform": attachment.world_transform(transform)})
	var owner_id := stable_id
	var solid := spec.world_solid(transform)
	var lot := spec.world_lot(transform)
	var clearance := FeatureGroundShape.oriented_rect(lot.centre,
		lot.half_extents, lot.angle, FeatureGroundField.NATURAL, 0,
		StringName("%s.clearance" % stable_id))
	var volumes: Array[VillageOccupancyVolume] = [
		VillageOccupancyVolume.new(VillageOccupancy.Role.SOLID,
			core.centre, core.half_extents, float(core.angle),
			lowest_ground, floor_y,
			StringName("%s.plinth" % stable_id), owner_id),
		VillageOccupancyVolume.new(VillageOccupancy.Role.SOLID,
			solid.centre, solid.half_extents, solid.angle, floor_y,
			transform.origin.y + spec.measured_aabb.end.y,
			StringName("%s.solid" % stable_id), owner_id),
		VillageOccupancyVolume.new(VillageOccupancy.Role.HEADROOM,
			door + outward * 1.1,
			Vector2(1.1, TraversalEnvelope.MIN_APERTURE_WIDTH * 0.5),
			outward.angle(), floor_y,
			floor_y + TraversalEnvelope.MIN_HEADROOM,
			StringName("%s.access" % stable_id), owner_id),
	]
	var cells := _skirt_cells(door, outward, contact, core, node.level)
	if cells.is_empty():
		return _building_rejected(&"missing_overhang")
	return {"accepted": true, "reason": &"", "entries": entries,
		"volumes": volumes, "walk_cells": cells,
		"clearance": clearance,
		"rock_piece_count": rock_piece_count,
		"plan": {"node": node, "door": door, "outward": outward,
			"floor_y": floor_y, "transform": transform, "core": core,
			"solid": solid, "skirt_cells": cells},
		"audit": {"key": node.stable_key, "centre": solid.centre,
			"half_extents": solid.half_extents,
			"floor_y": floor_y,
			"level": node.level, "building_asset_id": node.asset_id,
			"door": door, "outward": outward,
			"plinth_centre": core.centre,
			"plinth_half_extents": core.half_extents,
			"plinth_angle": float(core.angle),
			"rock_piece_count": rock_piece_count,
			"support_count": 0, "tile_count": cells.size()},
	}

static func _plinth_rect(contact: Dictionary,
		outward: Vector2) -> Dictionary:
	var side := Vector2(-outward.y, outward.x)
	var projections := _rect_projections(contact, side, outward)
	var full_width := float(projections.side_max) \
		- float(projections.side_min)
	var full_depth := float(projections.out_max) \
		- float(projections.out_min)
	var width_modules := maxi(2, floori(full_width \
		* VillageElevatedProgram.PLINTH_WIDTH_FRACTION \
		/ VillageProgram.MODULE + 0.0001))
	var depth_modules := maxi(2, floori(full_depth \
		* VillageElevatedProgram.PLINTH_DEPTH_FRACTION \
		/ VillageProgram.MODULE + 0.0001))
	var width := float(width_modules) * VillageProgram.MODULE
	var depth := float(depth_modules) * VillageProgram.MODULE
	if width > full_width + 0.001 or depth > full_depth + 0.001:
		return {}
	var side_projection := (float(projections.side_min) \
		+ float(projections.side_max)) * 0.5
	var outward_projection := float(projections.out_min) + depth * 0.5
	return {"centre": side * side_projection + outward * outward_projection,
		"half_extents": Vector2(width, depth) * 0.5,
		"angle": side.angle(), "side": side, "outward": outward,
		"front_projection": float(projections.out_min) + depth,
		"contact_front_projection": float(projections.out_max)}

static func _perimeter_supports(rect: Dictionary, module_width: float,
		module_depth: float) -> Array[Dictionary]:
	var centre: Vector2 = rect.centre
	var extents: Vector2 = rect.half_extents
	var angle := float(rect.angle)
	var axis_x := Vector2.RIGHT.rotated(angle)
	var axis_z := Vector2.DOWN.rotated(angle)
	var corners: Array[Vector2] = [
		centre - axis_x * extents.x - axis_z * extents.y,
		centre + axis_x * extents.x - axis_z * extents.y,
		centre + axis_x * extents.x + axis_z * extents.y,
		centre - axis_x * extents.x + axis_z * extents.y,
	]
	var out: Array[Dictionary] = []
	for edge in corners.size():
		var a := corners[edge]
		var b := corners[(edge + 1) % corners.size()]
		var delta := b - a
		var count := roundi(delta.length() / module_width)
		if count <= 0 or absf(delta.length() / module_width \
				- float(count)) > 0.001:
			return []
		var direction := delta.normalized()
		var inward := Vector2(-direction.y, direction.x)
		for segment in count:
			out.append({"anchor": a + direction * module_width \
				* (float(segment) + 0.5) + inward * module_depth * 0.5,
				"angle": Vector2.RIGHT.angle() - direction.angle(),
				"index": out.size()})
	return out

static func _skirt_cells(door: Vector2, outward: Vector2,
		contact: Dictionary, core: Dictionary, level: int) -> Array[Dictionary]:
	var side := Vector2(-outward.y, outward.x)
	var projections := _rect_projections(contact, side, outward)
	var full_width := float(projections.side_max) \
		- float(projections.side_min)
	var columns := ceili(full_width / VillageProgram.MODULE - 0.0001)
	if columns % 2 == 0:
		columns += 1
	var unsupported_depth := float(projections.out_max) \
		- float(core.front_projection)
	var inward_rows := maxi(1, ceili(unsupported_depth \
		/ VillageProgram.MODULE - 0.0001))
	var unique: Dictionary = {}
	for row in inward_rows + VillageElevatedProgram.SKIRT_APRON_ROWS:
		var outward_offset := float(VillageElevatedProgram.SKIRT_APRON_ROWS \
			- 1 - row) * VillageProgram.MODULE
		for column in columns:
			var side_offset := (float(column) \
				- (float(columns) - 1.0) * 0.5) * VillageProgram.MODULE
			var point := door + side * side_offset + outward * outward_offset
			if _point_inside_rect(point, core,
					VillageProgram.MODULE * 0.5 - 0.01):
				continue
			var cell := {"point": point, "level": level,
				"kind": &"skirt"}
			unique[_cell_key(point, level)] = cell
	var out: Array[Dictionary] = []
	out.assign(unique.values())
	return out

static func _network(frame: VillageFrame, tier: StringName,
		street_axis: Vector2, side_sign: float, datum_y: float,
		accepted_streets: Dictionary,
		vocabulary: VillageElevatedProgram, building_plans: Dictionary,
		fields: WorldFieldBlockCache) -> Dictionary:
	var entries: Array[Dictionary] = []
	var volumes: Array[VillageOccupancyVolume] = []
	var surfaces: Array[FeatureGroundShape] = []
	var clearances: Array[FeatureGroundShape] = []
	var walk_cells: Dictionary = {}
	var audit: Array[Dictionary] = []
	var walkway_audit: Array[Dictionary] = []
	var descents: Array[Dictionary] = []
	var support_exclusions: Array[Dictionary] = []
	var railing_openings: Dictionary = {}
	var street_contacts: Dictionary = {}
	var walk_owner := StringName("%s.elevated.walk_network" \
		% frame.settlement_id)
	for route: VillageElevatedRouteSpec in vocabulary.routes_for_tier(tier):
		for index in range(1, route.points.size()):
			var local_a := route.points[index - 1]
			var local_b := route.points[index]
			var level_a := route.levels[index - 1]
			var level_b := route.levels[index]
			var a := _world(frame.centre, street_axis, local_a, side_sign)
			var b := _world(frame.centre, street_axis, local_b, side_sign)
			var segment_id := StringName("%s.elevated.route.%s.%02d" % [
				frame.settlement_id, String(route.stable_key), index])
			if level_a == level_b:
				if level_a == 0:
					var region := _region_at(frame, fields, a)
					if not TerrainSurfaceField.cardinal_strip_is_walkable(region,
							a, b, VillagePlan.CONNECTOR_RADIUS):
						return _network_rejected(&"ground_walkability")
					for sample in 7:
						if _is_wet(frame, fields, a.lerp(b,
								float(sample) / 6.0)):
							return _network_rejected(&"ground_water")
					if _ground_contact_valid(frame, a, accepted_streets, fields):
						street_contacts[_cell_key(a, 0)] = true
					if _ground_contact_valid(frame, b, accepted_streets, fields):
						street_contacts[_cell_key(b, 0)] = true
					surfaces.append(FeatureGroundShape.capsule(a, b,
						VillagePlan.CONNECTOR_RADIUS,
						FeatureGroundField.WORN_PATH,
						VillagePlan.SURFACE_PRIORITY, segment_id))
					clearances.append(FeatureGroundShape.capsule(a, b,
						VillagePlan.CONNECTOR_RADIUS + 0.5,
						FeatureGroundField.NATURAL, 0,
						StringName("%s.clearance" % segment_id)))
				else:
					for cell: Dictionary in _segment_cells(a, b, level_a):
						walk_cells[_cell_key(cell.point, level_a)] = cell
					clearances.append(FeatureGroundShape.capsule(a, b,
						maxf(vocabulary.floor_size.x,
							vocabulary.floor_size.y) * 0.5,
						FeatureGroundField.NATURAL, 0,
						StringName("%s.clearance" % segment_id)))
					walkway_audit.append({"key": StringName("%s.%02d" % [
						String(route.stable_key), index]), "start": a,
						"end": b, "level": level_a,
						"y": vocabulary.level_y(datum_y, level_a)})
				continue
			var low_point := a if level_a < level_b else b
			var high_point := b if level_b > level_a else a
			var low_level := mini(level_a, level_b)
			var high_level := maxi(level_a, level_b)
			var high_direction := (high_point - low_point).normalized()
			var low_y := vocabulary.level_y(datum_y, low_level)
			var high_y := vocabulary.level_y(datum_y, high_level)
			var stair_base := high_y - vocabulary.stair_rise
			if not TraversalEnvelope.step_is_legal(stair_base - low_y):
				return _network_rejected(&"stair_contact")
			if low_level == 0 and _ground_contact_valid(frame, low_point,
					accepted_streets, fields):
				street_contacts[_cell_key(low_point, 0)] = true
			if low_level > 0:
				railing_openings[_edge_key(low_point, low_level,
					high_direction)] = true
			railing_openings[_edge_key(high_point, high_level,
				-high_direction)] = true
			var yaw := Vector2.UP.angle() - high_direction.angle()
			var stair_basis := Basis(Vector3.UP, yaw)
			var segment_point := low_point
			var segment_y := stair_base
			var prefix := "%s.elevated.route.%s.stair.%02d" % [
				frame.settlement_id, String(route.stable_key), index]
			clearances.append(FeatureGroundShape.capsule(low_point, high_point,
				vocabulary.stair_aabb.size.x * 0.5,
				FeatureGroundField.NATURAL, 0,
				StringName("%s.clearance" % prefix)))
			for segment_index in VillageElevatedProgram.STAIR_SEGMENTS_PER_STOREY:
				var local_contact := Vector3(
					vocabulary.stair_aabb.get_center().x,
					vocabulary.stair_aabb.position.y,
					vocabulary.stair_aabb.end.z)
				entries.append({"asset_id": vocabulary.stair_asset_id,
					"stable_id": StringName("%s.segment.%02d" % [prefix,
						segment_index]),
					"transform": Transform3D(stair_basis,
						Vector3(segment_point.x, segment_y, segment_point.y)
							- stair_basis * local_contact)})
				segment_point += high_direction \
					* vocabulary.stair_module_run
				segment_y += vocabulary.stair_aabb.size.y
			volumes.append(VillageOccupancyVolume.new(
				VillageOccupancy.Role.WALK_SURFACE,
				low_point.lerp(high_point, 0.5),
				Vector2(vocabulary.stair_run * 0.5,
					vocabulary.stair_aabb.size.x * 0.5),
				high_direction.angle(), stair_base, high_y,
				StringName("%s.walk" % prefix), walk_owner))
			support_exclusions.append({"centre": low_point.lerp(high_point,
				0.5), "half_extents": Vector2(vocabulary.stair_run * 0.5,
					vocabulary.stair_aabb.size.x * 0.5 + 0.25),
				"angle": high_direction.angle()})
			var item := {"key": StringName("%s.%02d" % [
				String(route.stable_key), index]), "kind": &"stair",
				"low_level": low_level, "high_level": high_level,
				"bottom": low_point, "top": high_point,
				"low_y": low_y, "stair_base_y": stair_base,
				"high_y": high_y, "residual_step": stair_base - low_y}
			audit.append(item)
			if low_level == 0:
				descents.append(item)
	for plan: Dictionary in building_plans.values():
		var node := plan.node as VillageElevatedBuildingSpec
		walk_cells[_cell_key(plan.door, node.level)] = {
			"point": plan.door, "level": node.level, "kind": &"door"}
		railing_openings[_edge_key(plan.door, node.level,
			-plan.outward)] = true
	if street_contacts.size() < 2:
		return _network_rejected(&"street_contact")
	return {"accepted": true, "reason": &"", "entries": entries,
		"volumes": volumes, "surfaces": surfaces,
		"clearances": clearances, "walk_cells": walk_cells.values(),
		"audit": audit, "descents": descents,
		"walkways": walkway_audit,
		"railing_openings": railing_openings,
		"support_exclusions": support_exclusions}

static func _segment_cells(a: Vector2, b: Vector2,
		level: int) -> Array[Dictionary]:
	var count := roundi(a.distance_to(b) / VillageProgram.MODULE)
	var out: Array[Dictionary] = []
	for index in count + 1:
		out.append({"point": a.lerp(b, float(index) / float(count)),
			"level": level, "kind": &"walkway"})
	return out

static func _walk_fabric(frame: VillageFrame, street_axis: Vector2,
		datum_y: float, cells: Dictionary,
		support_exclusions: Array[Dictionary],
		railing_exclusions: Array[Dictionary], railing_openings: Dictionary,
		vocabulary: VillageElevatedProgram,
		fields: WorldFieldBlockCache) -> Dictionary:
	var entries: Array[Dictionary] = []
	var volumes: Array[VillageOccupancyVolume] = []
	var keys: Array = cells.keys()
	keys.sort()
	var basis := Basis(Vector3.UP, street_axis.angle())
	var walk_owner := StringName("%s.elevated.walk_network" \
		% frame.settlement_id)
	for index in keys.size():
		var cell: Dictionary = cells[keys[index]]
		var point: Vector2 = cell.point
		var top_y := vocabulary.level_y(datum_y, int(cell.level))
		var bottom_y := top_y - vocabulary.floor_aabb.size.y
		var local_contact := Vector3(vocabulary.floor_aabb.get_center().x,
			vocabulary.floor_aabb.position.y,
			vocabulary.floor_aabb.get_center().z)
		var stable_id := StringName("%s.elevated.floor.%03d" % [
			frame.settlement_id, index])
		entries.append({"asset_id": vocabulary.floor_asset_id,
			"stable_id": stable_id,
			"transform": Transform3D(basis,
				Vector3(point.x, bottom_y, point.y) - basis * local_contact)})
		volumes.append(VillageOccupancyVolume.new(
			VillageOccupancy.Role.WALK_SURFACE, point,
			vocabulary.floor_size * 0.5, street_axis.angle(), bottom_y,
			top_y, StringName("%s.walk" % stable_id), walk_owner))
	var timber_module := vocabulary.timber_module()
	var railings := _railings(frame, datum_y, cells, railing_exclusions,
		railing_openings, vocabulary)
	entries.append_array(railings.entries)
	volumes.append_array(railings.volumes)
	var anchors := _boundary_supports(cells, support_exclusions, timber_module,
		street_axis.angle(), vocabulary.floor_size * 0.5)
	var modules: Array[SupportModule] = [timber_module]
	var support_piece_count := 0
	var accepted_support_count := 0
	for index in anchors.size():
		var support: Dictionary = anchors[index]
		var anchor: Vector2 = support.point
		var level := int(support.level)
		var target_y := vocabulary.level_y(datum_y, level) \
			- vocabulary.floor_aabb.size.y
		var region := _region_at(frame, fields, anchor)
		var support_wet := false
		for point: Vector2 in SupportSolver.ground_samples(anchor,
				street_axis.angle(), modules):
			if _is_wet(frame, fields, point):
				support_wet = true
				break
		if support_wet:
			continue
		var request := SupportRequest.new(
			StringName("%s.elevated.walk_support.%03d" % [
				frame.settlement_id, index]), [anchor], target_y,
			street_axis.angle(), modules, 0.18,
			VillageElevatedProgram.MAX_SUPPORT_GROUND_SPAN,
			VillageElevatedProgram.MAX_TIMBER_SUPPORT_BURIAL, level + 1)
		var solved := SupportSolver.solve(request, region)
		if not bool(solved.accepted):
			# Timber posts are sparse braces, not the walk-bearing surface. A
			# boundary candidate over water, a cliff seam, or terrain above the
			# deck is omitted; fixed geometry is never stretched or buried to
			# force it. Stable ids retain the candidate index, so filtering cannot
			# perturb any surviving support.
			continue
		entries.append_array(solved.pieces)
		volumes.append_array(solved.volumes)
		support_piece_count += (solved.pieces as Array).size()
		accepted_support_count += 1
	return {"accepted": true, "reason": &"", "entries": entries,
		"volumes": volumes, "support_count": accepted_support_count,
		"support_piece_count": support_piece_count,
		"railing_count": int(railings.count)}

static func _railings(frame: VillageFrame, datum_y: float,
		cells: Dictionary, exclusions: Array[Dictionary], openings: Dictionary,
		vocabulary: VillageElevatedProgram) -> Dictionary:
	var entries: Array[Dictionary] = []
	var volumes: Array[VillageOccupancyVolume] = []
	var keys: Array = cells.keys()
	keys.sort()
	var rail_owner := StringName("%s.elevated.railing_network" \
		% frame.settlement_id)
	for key: String in keys:
		var cell: Dictionary = cells[key]
		var point: Vector2 = cell.point
		var level := int(cell.level)
		for normal: Vector2 in [Vector2.RIGHT, Vector2.DOWN,
				Vector2.LEFT, Vector2.UP]:
			if cells.has(_cell_key(point + normal * VillageProgram.MODULE,
					level)) or openings.has(_edge_key(point, level, normal)):
				continue
			var edge_centre := point + normal * VillageProgram.MODULE * 0.5
			var tangent := Vector2(-normal.y, normal.x)
			var extents := Vector2(vocabulary.railing_aabb.size.x,
				vocabulary.railing_aabb.size.z) * 0.5
			if _footprint_overlaps_any(edge_centre, extents,
					tangent.angle(), exclusions):
				continue
			var yaw := -tangent.angle()
			var basis := Basis(Vector3.UP, yaw)
			var floor_y := vocabulary.level_y(datum_y, level)
			var local_contact := Vector3(
				vocabulary.railing_aabb.get_center().x,
				vocabulary.railing_aabb.position.y,
				vocabulary.railing_aabb.get_center().z)
			var stable_id := StringName("%s.elevated.railing.%04d" % [
				frame.settlement_id, entries.size()])
			entries.append({"asset_id": vocabulary.railing_asset_id,
				"stable_id": stable_id,
				"transform": Transform3D(basis,
					Vector3(edge_centre.x, floor_y, edge_centre.y)
						- basis * local_contact)})
			volumes.append(VillageOccupancyVolume.new(
				VillageOccupancy.Role.SOLID, edge_centre, extents,
				tangent.angle(), floor_y,
				floor_y + vocabulary.railing_aabb.size.y,
				StringName("%s.solid" % stable_id), rail_owner))
	return {"entries": entries, "volumes": volumes,
		"count": entries.size()}

static func _boundary_supports(cells: Dictionary,
		exclusions: Array[Dictionary], timber_module: SupportModule,
		support_angle: float, floor_extents: Vector2) -> Array[Dictionary]:
	var corners: Dictionary = {}
	var half := VillageProgram.MODULE * 0.5
	for cell: Dictionary in cells.values():
		var point: Vector2 = cell.point
		var level := int(cell.level)
		for offset: Vector2 in [Vector2(-half, -half),
				Vector2(half, -half), Vector2(half, half),
				Vector2(-half, half)]:
			var corner := point + offset
			var key := "%d:%d:%d" % [roundi(corner.x * 1000.0),
				roundi(corner.y * 1000.0), level]
			var item: Dictionary = corners.get(key,
				{"point": corner, "level": level, "count": 0})
			item.count = int(item.count) + 1
			corners[key] = item
	var out: Array[Dictionary] = []
	var keys: Array = corners.keys()
	keys.sort()
	for key: String in keys:
		var item: Dictionary = corners[key]
		if int(item.count) >= 4 or _support_overlaps_any(item.point,
				support_angle, timber_module, exclusions):
			continue
		if _support_crosses_lower_walk(item, cells, support_angle,
				timber_module, floor_extents):
			continue
		var qx := roundi(float(item.point.x) / (VillageProgram.MODULE * 0.5))
		var qz := roundi(float(item.point.y) / (VillageProgram.MODULE * 0.5))
		if posmod(qx + qz, SUPPORT_PARITY) != 0:
			continue
		out.append(item)
	return out

static func _ground_activities(frame: VillageFrame, tier: StringName,
		theme: StringName, street_axis: Vector2, side_sign: float,
		vocabulary: VillageElevatedProgram, building_plans: Dictionary,
		program: VillageProgram, fields: WorldFieldBlockCache) -> Dictionary:
	var entries: Array[Dictionary] = []
	var volumes: Array[VillageOccupancyVolume] = []
	var clearances: Array[FeatureGroundShape] = []
	var results: Dictionary = {}
	for activity: VillageGroundActivitySpec in \
			vocabulary.ground_activities_for_tier(tier):
		var spec := program.assets[activity.asset_id] as VillageAssetSpec
		var door := _world(frame.centre, street_axis, activity.local_door,
			side_sign)
		var outward := _direction(street_axis, activity.local_outward,
			side_sign)
		var placement := spec.placement_for_door(door, outward)
		var flat := Transform3D(Basis(Vector3.UP, float(placement.yaw)),
			Vector3(float(placement.origin.x), 0.0,
				float(placement.origin.y)))
		var contact := spec.world_ground_contact(flat)
		var shape := FeatureGroundShape.oriented_rect(contact.centre,
			contact.half_extents, contact.angle)
		var region := _region_at(frame, fields, contact.centre)
		var bounds := TerrainSurfaceField.height_bounds(region, shape.bounds())
		if bounds.y - bounds.x > spec.max_ground_relief:
			results[activity.stable_key] = &"terrain_relief"
			continue
		var wet := false
		for point: Vector2 in _rect_samples(contact):
			if _is_wet(frame, fields, point):
				wet = true
				break
		if wet:
			results[activity.stable_key] = &"water"
			continue
		var floor_y := bounds.y
		var transform := flat
		transform.origin.y = floor_y - spec.measured_aabb.position.y
		# A bound ground lot may sit beside, beneath, or between overhangs.
		# The shared 3D occupancy transaction decides actual clearance;
		# association never imposes a fake universal ceiling.
		assert(building_plans.has(activity.building_key))
		var stable_id := StringName("%s.elevated.ground_activity.%s" % [
			frame.settlement_id, String(activity.stable_key)])
		entries.append({"asset_id": spec.asset_for_theme(theme),
			"stable_id": stable_id, "transform": transform})
		for attachment: VillageAttachedAssetSpec in spec.attachments:
			entries.append({"asset_id": attachment.asset_for_theme(theme),
				"stable_id": StringName("%s.component.%s" % [stable_id,
					String(attachment.stable_key)]),
				"transform": attachment.world_transform(transform)})
		var solid := spec.world_solid(transform)
		volumes.append(VillageOccupancyVolume.new(
			VillageOccupancy.Role.SOLID, solid.centre, solid.half_extents,
			solid.angle, floor_y, floor_y + spec.measured_aabb.size.y,
			StringName("%s.solid" % stable_id), stable_id))
		var world_lot := spec.world_lot(transform)
		clearances.append(FeatureGroundShape.oriented_rect(
			world_lot.centre, world_lot.half_extents, world_lot.angle,
			FeatureGroundField.NATURAL, 0,
			StringName("%s.clearance" % stable_id)))
		results[activity.stable_key] = &"accepted"
	return {"accepted": true, "reason": &"", "entries": entries,
		"volumes": volumes, "clearances": clearances, "results": results}

static func _undercroft(frame: VillageFrame, building_plans: Dictionary,
		vocabulary: VillageElevatedProgram,
		fields: WorldFieldBlockCache) -> Dictionary:
	var plans: Array[Dictionary] = []
	for value: Dictionary in building_plans.values():
		plans.append(value)
	plans.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_level := (a.node as VillageElevatedBuildingSpec).level
		var b_level := (b.node as VillageElevatedBuildingSpec).level
		if a_level != b_level:
			return a_level < b_level
		return String((a.node as VillageElevatedBuildingSpec).stable_key) \
			< String((b.node as VillageElevatedBuildingSpec).stable_key))
	for plan: Dictionary in plans:
		var candidate := _undercroft_for_building(frame, plan, vocabulary,
			fields)
		if bool(candidate.accepted):
			return candidate
	return {"accepted": false, "reason": &"headroom",
		"volumes": [], "clearances": [], "audit": {}}

static func _undercroft_for_building(frame: VillageFrame, plan: Dictionary,
		vocabulary: VillageElevatedProgram,
		fields: WorldFieldBlockCache) -> Dictionary:
	var door: Vector2 = plan.door
	var outward: Vector2 = plan.outward
	var side := Vector2(-outward.y, outward.x)
	var extents := Vector2(TraversalEnvelope.MIN_APERTURE_WIDTH * 0.5,
		VillageProgram.MODULE * 1.25)
	# The stair owns the direct front-door axis. Derive the lower street as the
	# adjacent parallel aisle beneath the unsupported skirt, with enough lateral
	# separation for both reviewed traversal envelopes.
	var aisle_offset := vocabulary.stair_aabb.size.x * 0.5 \
		+ extents.x + 0.25
	var angle := side.angle()
	var ceiling := float(plan.floor_y) - vocabulary.floor_aabb.size.y
	for lateral_sign: float in [1.0, -1.0]:
		var aisle_side := side * lateral_sign
		for depth_modules: float in [1.0, 2.0, 3.0]:
			var centre := door + aisle_side * aisle_offset \
				- outward * VillageProgram.MODULE * depth_modules
			var shape := FeatureGroundShape.oriented_rect(centre, extents, angle)
			var region := _region_at(frame, fields, centre)
			var ground := TerrainSurfaceField.height_bounds(region,
				shape.bounds())
			if ceiling - ground.y < TraversalEnvelope.MIN_HEADROOM:
				continue
			var stable_id := StringName("%s.elevated.undercroft" \
				% frame.settlement_id)
			return {"accepted": true, "reason": &"",
				"volumes": [VillageOccupancyVolume.new(
					VillageOccupancy.Role.HEADROOM, centre, extents, angle,
					ground.y, ceiling, stable_id)],
				"clearances": [FeatureGroundShape.oriented_rect(centre,
					extents + Vector2(0.25, 0.0), angle,
					FeatureGroundField.NATURAL, 0,
					StringName("%s.clearance" % stable_id))],
				"audit": {"centre": centre, "normal": aisle_side,
					"tangent": outward, "half_extents": extents,
					"ground_y": ground.y, "ceiling_y": ceiling,
					"seam_key": StringName("%s.overhang" \
						% String((plan.node as VillageElevatedBuildingSpec).stable_key))}}
	return {"accepted": false, "reason": &"headroom",
		"volumes": [], "clearances": [], "audit": {}}

static func _ground_contact_valid(frame: VillageFrame, point: Vector2,
		accepted_streets: Dictionary,
		fields: WorldFieldBlockCache) -> bool:
	var on_street := frame.path_ground != null \
		and frame.path_ground.surface_at(point) == FeatureGroundField.WORN_PATH
	for street: Dictionary in accepted_streets.values():
		if Geometry2D.get_closest_point_to_segment(point,
				street.start, street.end).distance_to(point) <= 0.01:
			on_street = true
			break
	if not on_street or _is_wet(frame, fields, point):
		return false
	return true

static func _rect_projections(rect: Dictionary, side: Vector2,
		outward: Vector2) -> Dictionary:
	var side_min := INF
	var side_max := -INF
	var out_min := INF
	var out_max := -INF
	var axis_x := Vector2.RIGHT.rotated(float(rect.angle))
	var axis_z := Vector2.DOWN.rotated(float(rect.angle))
	for local: Vector2 in [
			Vector2(-rect.half_extents.x, -rect.half_extents.y),
			Vector2(rect.half_extents.x, -rect.half_extents.y),
			Vector2(rect.half_extents.x, rect.half_extents.y),
			Vector2(-rect.half_extents.x, rect.half_extents.y)]:
		var point: Vector2 = rect.centre + axis_x * local.x \
			+ axis_z * local.y
		side_min = minf(side_min, point.dot(side))
		side_max = maxf(side_max, point.dot(side))
		out_min = minf(out_min, point.dot(outward))
		out_max = maxf(out_max, point.dot(outward))
	return {"side_min": side_min, "side_max": side_max,
		"out_min": out_min, "out_max": out_max}

static func _rect_samples(rect: Dictionary) -> Array[Vector2]:
	var out: Array[Vector2] = [rect.centre]
	var axis_x := Vector2.RIGHT.rotated(float(rect.angle))
	var axis_z := Vector2.DOWN.rotated(float(rect.angle))
	for local: Vector2 in [
			Vector2(-rect.half_extents.x, -rect.half_extents.y),
			Vector2(rect.half_extents.x, -rect.half_extents.y),
			Vector2(rect.half_extents.x, rect.half_extents.y),
			Vector2(-rect.half_extents.x, rect.half_extents.y)]:
		out.append(rect.centre + axis_x * local.x + axis_z * local.y)
	return out

static func _point_inside_rect(point: Vector2, rect: Dictionary,
		margin: float = 0.0) -> bool:
	var relative := (point - (rect.centre as Vector2)).rotated(
		-float(rect.angle))
	var extents: Vector2 = rect.half_extents
	return absf(relative.x) <= extents.x + margin \
		and absf(relative.y) <= extents.y + margin

static func _support_overlaps_any(anchor: Vector2, angle: float,
		module: SupportModule, rects: Array[Dictionary]) -> bool:
	for stencil: Dictionary in module.solid_stencil:
		var centre := anchor + (stencil.offset as Vector2).rotated(angle)
		if _footprint_overlaps_any(centre, stencil.half_extents, angle,
				rects):
			return true
	return false

static func _support_crosses_lower_walk(support: Dictionary,
		cells: Dictionary, angle: float, module: SupportModule,
		floor_extents: Vector2) -> bool:
	for cell: Dictionary in cells.values():
		if int(cell.level) >= int(support.level):
			continue
		for stencil: Dictionary in module.solid_stencil:
			var centre: Vector2 = support.point \
				+ (stencil.offset as Vector2).rotated(angle)
			if _footprints_overlap(centre, stencil.half_extents, angle,
					cell.point, floor_extents, angle):
				return true
	return false

static func _footprint_overlaps_any(centre: Vector2, extents: Vector2,
		angle: float, rects: Array[Dictionary]) -> bool:
	for rect: Dictionary in rects:
		if _footprints_overlap(centre, extents, angle,
				rect.centre, rect.half_extents, float(rect.angle)):
			return true
	return false

static func _footprints_overlap(a_centre: Vector2, a_extents: Vector2,
		a_angle: float, b_centre: Vector2, b_extents: Vector2,
		b_angle: float) -> bool:
	# Oriented-rectangle SAT with the same one-millimetre contact tolerance as
	# VillageOccupancyVolume. Planning exclusions and final occupancy therefore
	# agree at authored seams.
	const CONTACT_EPS := 0.001
	var a_x := Vector2.RIGHT.rotated(a_angle)
	var a_z := Vector2.DOWN.rotated(a_angle)
	var b_x := Vector2.RIGHT.rotated(b_angle)
	var b_z := Vector2.DOWN.rotated(b_angle)
	var delta := b_centre - a_centre
	for axis: Vector2 in [a_x, a_z, b_x, b_z]:
		var a_radius := absf(axis.dot(a_x)) * a_extents.x \
			+ absf(axis.dot(a_z)) * a_extents.y
		var b_radius := absf(axis.dot(b_x)) * b_extents.x \
			+ absf(axis.dot(b_z)) * b_extents.y
		if absf(delta.dot(axis)) >= a_radius + b_radius - CONTACT_EPS:
			return false
	return true

static func _cell_key(point: Vector2, level: int) -> String:
	return "%d:%d:%d" % [roundi(point.x * 1000.0),
		roundi(point.y * 1000.0), level]

static func _edge_key(point: Vector2, level: int,
		direction: Vector2) -> String:
	return "%s:%d:%d" % [_cell_key(point, level),
		roundi(direction.x), roundi(direction.y)]

static func _sorted_cells(cells: Dictionary) -> Array[Dictionary]:
	var keys: Array = cells.keys()
	keys.sort()
	var out: Array[Dictionary] = []
	for key: String in keys:
		out.append(cells[key])
	return out

static func _world(origin: Vector2, x_axis: Vector2,
		local: Vector2, side_sign: float = 1.0) -> Vector2:
	var z_axis := Vector2(-x_axis.y, x_axis.x) * side_sign
	return origin + x_axis * local.x + z_axis * local.y

static func _direction(x_axis: Vector2, local: Vector2,
		side_sign: float = 1.0) -> Vector2:
	var z_axis := Vector2(-x_axis.y, x_axis.x) * side_sign
	return (x_axis * local.x + z_axis * local.y).normalized()

static func _region_at(frame: VillageFrame, fields: WorldFieldBlockCache,
		point: Vector2) -> HeightfieldRegion:
	return frame.region if fields == null else fields.region_at(point)

static func _is_wet(frame: VillageFrame, fields: WorldFieldBlockCache,
		point: Vector2) -> bool:
	var water := frame.water if fields == null else fields.water_at(point)
	return water.is_wet(point)

static func _building_rejected(reason: StringName) -> Dictionary:
	return {"accepted": false, "reason": reason, "entries": [],
		"volumes": [], "walk_cells": [], "rock_piece_count": 0,
		"plan": {}, "audit": {}}

static func _network_rejected(reason: StringName) -> Dictionary:
	return {"accepted": false, "reason": reason, "entries": [],
		"volumes": [], "surfaces": [], "clearances": [],
		"walk_cells": [], "audit": [], "descents": [],
		"walkways": [],
		"railing_openings": {},
		"support_exclusions": []}

static func _walk_rejected(reason: StringName) -> Dictionary:
	return {"accepted": false, "reason": reason, "entries": [],
		"volumes": [], "support_count": 0, "support_piece_count": 0,
		"railing_count": 0}

static func _rejected(reason: StringName, diagnostic: String = "") -> Dictionary:
	return {"accepted": false, "reason": reason, "entries": [],
		"volumes": [], "surfaces": [], "clearances": [], "buildings": [],
		"transitions": [], "walkways": [], "descents": [], "undercroft": {},
		"level_count": 0,
		"support_count": 0, "support_piece_count": 0, "railing_count": 0,
		"timber_tile_count": 0,
		"rock_piece_count": 0, "skirt_tile_count": 0,
		"walkway_tile_count": 0, "walk_cells": [],
		"diagnostic": diagnostic}
