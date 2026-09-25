class_name VillageAerialRouter
extends RefCounted

## Bounded local route vocabulary between inhabited fronts. Routes always
## depart along reviewed facade normals, then consider symmetric rounded bows;
## no long-span or empty-platform fallback exists.
const WALKWAY_HALF_WIDTH := TraversalEnvelope.MIN_APERTURE_WIDTH * 0.5
const SAMPLE_STEP := VillageProgram.MODULE


static func candidates(doors: Array[VillageCirculationNode],
		placements: Array[VillageMassingPlacement],
		vocabulary: VillageElevatedProgram,
		reserved_volumes: Array[VillageOccupancyVolume] = []
		) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for index in doors.size():
		for prior in index:
			var a := doors[prior]
			var b := doors[index]
			var direct_distance := a.point.distance_to(b.point)
			if direct_distance < VillageProgram.MODULE * 2.0 \
					or direct_distance > VillageMassingProgram.MAX_LINK_RADIUS:
				continue
			var link := _curved_link(a, b, placements, vocabulary,
				reserved_volumes)
			if link == null:
				continue
			out.append({
				"link": link,
				"vertical": absf(a.surface_y - b.surface_y) \
					> TraversalEnvelope.MAX_PLANNED_STEP,
			})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if bool(a.vertical) != bool(b.vertical):
			return bool(a.vertical)
		return VillageRouteGeometry.link_less(a.link, b.link))
	return out


static func _curved_link(a: VillageCirculationNode,
		b: VillageCirculationNode, placements: Array[VillageMassingPlacement],
		vocabulary: VillageElevatedProgram,
		reserved_volumes: Array[VillageOccupancyVolume]
		) -> VillageCirculationLink:
	var delta_y := b.surface_y - a.surface_y
	var transition := VillageStairSolver.transition(absf(delta_y), vocabulary,
		VillageMassingProgram.MAX_PUBLIC_STAIR_SEGMENTS)
	if transition.is_empty():
		return null
	var distance := a.point.distance_to(b.point)
	var direction := (b.point - a.point).normalized()
	var side := Vector2(-direction.y, direction.x)
	var placement_a := _placement_for(a.owner_key, placements)
	var placement_b := _placement_for(b.owner_key, placements)
	if placement_a == null or placement_b == null:
		return null
	var route_half_width := maxf(WALKWAY_HALF_WIDTH,
		vocabulary.stair_aabb.size.x * 0.5) if int(transition.count) > 0 \
		else WALKWAY_HALF_WIDTH
	var start := a.point + a.outward * VillageDoorGeometry.clear_departure(
		placement_a, route_half_width)
	var end := b.point + b.outward * VillageDoorGeometry.clear_departure(
		placement_b, route_half_width)
	# The rounded departure corner can begin before the exact facade-clear
	# point. Keep a complete construction module after that point free so no
	# fixed stair tread can cut back through either inhabited shell.
	var start_clearance := a.point.distance_to(start) + VillageProgram.MODULE
	var end_clearance := b.point.distance_to(end) + VillageProgram.MODULE
	var middle := (start + end) * 0.5
	var valid: Array[VillageCirculationLink] = []
	# Module-spaced bows form one bounded vocabulary. Using every module (not
	# every second one) matters for tall transitions: a narrow gap can require
	# just one extra landing module to fit the fixed stair run without forcing a
	# much wider, over-length bridge.
	for side_offset: float in [0.0, VillageProgram.MODULE,
			-VillageProgram.MODULE, VillageProgram.MODULE * 2.0,
			-VillageProgram.MODULE * 2.0, VillageProgram.MODULE * 3.0,
			-VillageProgram.MODULE * 3.0, VillageProgram.MODULE * 4.0,
			-VillageProgram.MODULE * 4.0, VillageProgram.MODULE * 5.0,
			-VillageProgram.MODULE * 5.0, VillageProgram.MODULE * 6.0,
			-VillageProgram.MODULE * 6.0]:
		var controls: Array[Vector2] = [a.point, start,
			middle + side * side_offset, end, b.point]
		var horizontal_samples := _rounded_samples(controls)
		var horizontal_length := VillageRouteGeometry.polyline_length_2d(
			horizontal_samples)
		if horizontal_length > VillageMassingProgram.MAX_LINK_RADIUS + 0.001:
			continue
		var stair_intervals: Array[Vector2] = []
		if int(transition.count) > 0:
			stair_intervals = VillageRouteGeometry.aerial_stair_interval(
				horizontal_length,
				float(transition.count) * vocabulary.stair_module_run,
				start_clearance, end_clearance)
			if stair_intervals.is_empty():
				continue
		var samples := _lift_samples(horizontal_samples,
			a.surface_y, b.surface_y)
		if VillageRouteGeometry.path_hits_solids(samples, placements,
				a.owner_key, b.owner_key, route_half_width) \
				or VillageRouteGeometry.path_hits_volumes(samples,
					reserved_volumes, route_half_width):
			continue
		var link := VillageCirculationLink.new(
			VillageRouteGeometry.edge_key(&"aerial", a.stable_key, b.stable_key),
			VillageCirculationLink.Kind.AERIAL_WALKWAY,
			a.stable_key, b.stable_key)
		var control_distance := 0.0
		var control_total := VillageRouteGeometry.polyline_length_2d(controls)
		for control_index in controls.size():
			if control_index > 0:
				control_distance += controls[control_index - 1].distance_to(
					controls[control_index])
			var t := 0.0 if control_total <= 0.001 \
				else control_distance / control_total
			link.control_points.append(VillageRouteGeometry.point3(
				controls[control_index], lerpf(a.surface_y, b.surface_y, t)))
		link.samples = samples
		link.length = VillageRouteGeometry.polyline_length(samples)
		link.stair_count = int(transition.count)
		link.residual_step = float(transition.residual) * signf(delta_y)
		link.stair_intervals = stair_intervals
		valid.append(link)
	valid.sort_custom(VillageRouteGeometry.link_less)
	return null if valid.is_empty() else valid[0]


static func _rounded_samples(controls: Array[Vector2]) -> Array[Vector2]:
	var out: Array[Vector2] = [controls[0]]
	for index in range(1, controls.size() - 1):
		var prior := controls[index - 1]
		var corner := controls[index]
		var next := controls[index + 1]
		if prior.distance_to(corner) <= 0.01 \
				or corner.distance_to(next) <= 0.01:
			continue
		var radius := minf(VillageProgram.MODULE * 0.5,
			minf(prior.distance_to(corner), corner.distance_to(next)) * 0.3)
		var entry := corner + (prior - corner).normalized() * radius
		var exit := corner + (next - corner).normalized() * radius
		_append_line_samples(out, entry)
		for sample_index in range(1, 5):
			var t := float(sample_index) / 4.0
			var one_minus := 1.0 - t
			out.append(entry * one_minus * one_minus \
				+ corner * 2.0 * one_minus * t + exit * t * t)
	_append_line_samples(out, controls[-1])
	return out


static func _append_line_samples(out: Array[Vector2], end: Vector2) -> void:
	var start := out[-1]
	var divisions := maxi(1, ceili(start.distance_to(end) / SAMPLE_STEP))
	for index in range(1, divisions + 1):
		out.append(start.lerp(end, float(index) / float(divisions)))


static func _lift_samples(points: Array[Vector2], start_y: float,
		end_y: float) -> Array[Vector3]:
	var total := VillageRouteGeometry.polyline_length_2d(points)
	var travelled := 0.0
	var out: Array[Vector3] = []
	for index in points.size():
		if index > 0:
			travelled += points[index - 1].distance_to(points[index])
		var t := 0.0 if total <= 0.001 else travelled / total
		out.append(VillageRouteGeometry.point3(points[index],
			lerpf(start_y, end_y, t)))
	return out


static func _placement_for(key: StringName,
		placements: Array[VillageMassingPlacement]) -> VillageMassingPlacement:
	for placement: VillageMassingPlacement in placements:
		if placement.stable_key == key:
			return placement
	return null
