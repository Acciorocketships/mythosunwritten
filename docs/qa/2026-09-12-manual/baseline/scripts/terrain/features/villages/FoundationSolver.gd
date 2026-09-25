class_name FoundationSolver
extends RefCounted

## Fits a fixed-module perimeter and an entrance connector above immutable
## terrain. The returned plan is plain worker data; rendering and physics are
## downstream adapters.
const MIN_STEP_RUN := 0.6
const GRID_EPS := 0.001

static func solve(request: FoundationRequest, region: HeightfieldRegion,
		water: WaterFieldContext = null) -> Dictionary:
	assert(request != null and region != null)
	var bounds := TerrainSurfaceField.height_bounds(region, request.bounds_xz())
	var natural_floor_y := bounds.y + request.floor_guard
	var floor_y := request.target_floor_y if is_finite(
		request.target_floor_y) else natural_floor_y
	if floor_y < natural_floor_y - GRID_EPS:
		return _rejected(&"foundation_below_terrain", bounds)
	if floor_y - bounds.x > request.max_covered_depth:
		return _rejected(&"foundation_depth", bounds)
	var perimeter := _perimeter_anchors(request)
	if perimeter.is_empty():
		return _rejected(&"module_grid", bounds)
	var probes := water_probes(request, perimeter)
	if water != null:
		for point: Vector2 in probes:
			if water.is_wet(point):
				return _rejected(&"water", bounds)
	var pieces: Array[Dictionary] = []
	var volumes: Array[VillageOccupancyVolume] = []
	for item: Dictionary in perimeter:
		var anchor: Vector2 = item.anchor
		# A module is a footprint, not a point. Sampling only its centre can
		# classify a sloping edge as naturally supported while one end of the
		# same fixed piece visibly hangs in space. The complete support stencil
		# decides both visibility and stack depth, so coverage cannot acquire
		# holes as terrain crosses a module boundary.
		var ground_y := INF
		for point: Vector2 in item.probes:
			ground_y = minf(ground_y,
				TerrainSurfaceField.surface_y(region, point.x, point.y))
		var required := floor_y - ground_y
		if required <= TraversalEnvelope.MAX_PLANNED_STEP + GRID_EPS:
			# A terrain-to-floor contact already inside the canonical movement
			# envelope is a threshold, not a three-metre wall mostly buried to
			# expose a distracting sliver. Only structurally visible drops get
			# fixed foundation modules.
			continue
		if required > request.max_covered_depth:
			return _rejected(&"foundation_depth", bounds)
		var layer_count := ceili(required / request.module_height)
		var stack_height := float(layer_count) * request.module_height
		var burial := stack_height - required
		if burial > request.max_bottom_burial + GRID_EPS:
			return _rejected(&"bottom_burial", bounds)
		for layer in layer_count:
			var bottom_y := floor_y - (float(layer) + 1.0) \
				* request.module_height
			var stable_id := StringName("%s.foundation.%d.%d.%d" % [
				String(request.stable_id), int(item.edge), int(item.segment), layer])
			var basis := Basis(Vector3.UP, float(item.yaw))
			pieces.append({
				"asset_id": request.module_id,
				"stable_id": stable_id,
				"transform": Transform3D(basis,
					Vector3(anchor.x,
						bottom_y - request.module_local_bottom_y,
						anchor.y)),
				"burial": burial if layer == layer_count - 1 else 0.0,
			})
			var world_x := basis * Vector3.RIGHT
			volumes.append(VillageOccupancyVolume.new(
				VillageOccupancy.Role.SOLID, anchor,
				Vector2(request.module_width, request.module_depth) * 0.5,
				Vector2(world_x.x, world_x.z).angle(), bottom_y,
				bottom_y + request.module_height,
				StringName("%s.solid" % stable_id), request.stable_id))
	var connector := _entrance_connector(request, region, floor_y)
	if not bool(connector.accepted):
		return _rejected(connector.reason, bounds)
	return {
		"accepted": true,
		"reason": &"",
		"floor_y": floor_y,
		"terrain_bounds": bounds,
		"foundation_pieces": pieces,
		"volumes": volumes,
		"connector": connector,
	}

## Exact structural-water probes. The terrain-led wrapper uses this public
## geometry with VillageTerrainView so a footprint may safely cross cache
## blocks without leaking WaterFieldContext ownership into this solver.
static func water_probes(request: FoundationRequest,
		perimeter: Array[Dictionary] = []) -> Array[Vector2]:
	assert(request != null)
	var anchors := perimeter if not perimeter.is_empty() \
		else _perimeter_anchors(request)
	var unique: Dictionary = {}
	for point: Vector2 in [request.centre, request.doorway_inside,
			request.doorway_outside]:
		unique[Vector2i(roundi(point.x * 1000.0),
			roundi(point.y * 1000.0))] = point
	for item: Dictionary in anchors:
		for point: Vector2 in item.probes:
			unique[Vector2i(roundi(point.x * 1000.0),
				roundi(point.y * 1000.0))] = point
	var out: Array[Vector2] = []
	out.assign(unique.values())
	out.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		return a.x < b.x if a.x != b.x else a.y < b.y)
	return out

static func _perimeter_anchors(request: FoundationRequest) -> Array[Dictionary]:
	var corners := request.corners()
	var out: Array[Dictionary] = []
	var entrance_edge := _closest_edge(corners, request.doorway_inside)
	for edge in corners.size():
		var a: Vector2 = corners[edge]
		var b: Vector2 = corners[(edge + 1) % corners.size()]
		var delta := b - a
		var exact_count := delta.length() / request.module_width
		var count := roundi(exact_count)
		if count <= 0 or absf(exact_count - float(count)) > GRID_EPS:
			return []
		var direction := delta.normalized()
		var inward := Vector2(-direction.y, direction.x)
		for segment in count:
			var boundary_anchor := a + direction * request.module_width \
				* (float(segment) + 0.5)
			# The entrance is part of the foundation vocabulary, not a repair
			# applied later. Every fixed module whose authored bay overlaps the
			# protected opening is absent, guaranteeing a centred ≥1m gap even
			# when the doorway falls on a module boundary.
			if edge == entrance_edge and boundary_anchor.distance_to(
					request.doorway_inside) <= (request.module_width \
					+ request.opening_width) * 0.5 + GRID_EPS:
				continue
			var anchor := boundary_anchor \
				+ inward * request.module_depth * 0.5
			var half_span := direction * request.module_width * 0.5
			var inner_offset := inward * request.module_depth
			out.append({
				# The authored module's outside face, not its centreline, lies on
				# the reviewed support perimeter. Its top can therefore never
				# draw a detached outline beyond the building contact footprint.
				"anchor": anchor,
				# Six boundary/inner-face samples conservatively cover the fixed
				# module. Adjacent modules share their endpoint probes exactly.
				"probes": [boundary_anchor - half_span, boundary_anchor,
					boundary_anchor + half_span,
					boundary_anchor - half_span + inner_offset,
					boundary_anchor + inner_offset,
					boundary_anchor + half_span + inner_offset],
				"yaw": request.module_axis.angle() - direction.angle(),
				"edge": edge,
				"segment": segment,
			})
	return out

static func _closest_edge(corners: Array[Vector2], point: Vector2) -> int:
	var best_edge := 0
	var best_distance := INF
	for edge in corners.size():
		var closest := Geometry2D.get_closest_point_to_segment(point,
			corners[edge], corners[(edge + 1) % corners.size()])
		var distance := point.distance_squared_to(closest)
		if distance < best_distance:
			best_distance = distance
			best_edge = edge
	return best_edge

static func _entrance_connector(request: FoundationRequest,
		region: HeightfieldRegion, floor_y: float) -> Dictionary:
	var outside_y := TerrainSurfaceField.surface_y(region,
		request.doorway_outside.x, request.doorway_outside.y)
	var rise := floor_y - outside_y
	if rise < -TraversalEnvelope.MAX_PLANNED_STEP:
		return {"accepted": false, "reason": &"door_above_floor"}
	if absf(rise) <= TraversalEnvelope.MAX_PLANNED_STEP:
		return {
			"accepted": true,
			"kind": &"threshold",
			"contacts": [Vector3(request.doorway_outside.x, outside_y,
				request.doorway_outside.y), Vector3(request.doorway_inside.x,
				floor_y, request.doorway_inside.y)],
			"max_step": absf(rise),
		}
	var run := request.doorway_inside.distance_to(request.doorway_outside)
	var step_count := ceili(rise / TraversalEnvelope.MAX_PLANNED_STEP)
	if run + GRID_EPS < float(step_count) * MIN_STEP_RUN:
		return {"accepted": false, "reason": &"door_run"}
	var contacts: Array[Vector3] = []
	for index in step_count + 1:
		var t := float(index) / float(step_count)
		var point := request.doorway_outside.lerp(request.doorway_inside, t)
		contacts.append(Vector3(point.x, lerpf(outside_y, floor_y, t), point.y))
	var step_height := rise / float(step_count)
	assert(TraversalEnvelope.step_is_legal(step_height))
	return {
		"accepted": true,
		"kind": &"stairs",
		"contacts": contacts,
		"max_step": step_height,
	}

static func _rejected(reason: StringName, bounds: Vector2) -> Dictionary:
	return {
		"accepted": false,
		"reason": reason,
		"terrain_bounds": bounds,
		"foundation_pieces": [],
		"volumes": [],
		"connector": {},
	}
