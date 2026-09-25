class_name VillageRouteGeometry
extends RefCounted

## Shared resource-free route geometry. Ground and aerial routers use the same
## swept-volume and deterministic ordering facts without depending on each
## other's search vocabulary.
const STAIR_RUN_SEAM_TOLERANCE := VillageProgram.MODULE * 0.1


static func aerial_stair_interval(total: float, run_length: float,
		start_clearance: float, end_clearance: float) -> Array[Vector2]:
	if not is_finite(total) or not is_finite(run_length) \
			or not is_finite(start_clearance) or not is_finite(end_clearance) \
			or run_length <= 0.0 or start_clearance < 0.0 \
			or end_clearance < 0.0 \
			or total < start_clearance + run_length + end_clearance - 0.001:
		return []
	var available_start := start_clearance
	var available_end := total - end_clearance
	var start := clampf(total * 0.5 - run_length * 0.5,
		available_start, available_end - run_length)
	return [Vector2(start, start + run_length)]


static func ground_stair_intervals(samples: Array[Vector3],
		transitions: Array[VillageStairTransition],
		stair_module_run: float) -> Array[Vector2]:
	if samples.size() < 2 or transitions.is_empty() \
			or not is_finite(stair_module_run) or stair_module_run <= 0.0:
		return []
	var cumulative := PackedFloat32Array([0.0])
	for index in range(1, samples.size()):
		cumulative.append(cumulative[-1] + Vector2(samples[index].x,
			samples[index].z).distance_to(Vector2(samples[index - 1].x,
				samples[index - 1].z)))
	var total := cumulative[-1]
	var out: Array[Vector2] = []
	for transition: VillageStairTransition in transitions:
		var length := float(transition.stair_count) * stair_module_run
		if transition.segment_index <= 0 \
				or transition.segment_index >= cumulative.size() \
				or total < length - 0.001:
			return []
		var desired := (cumulative[transition.segment_index - 1] \
			+ cumulative[transition.segment_index]) * 0.5
		var start := clampf(desired - length * 0.5, 0.0, total - length)
		var interval := Vector2(start, start + length)
		for other: Vector2 in out:
			if interval.x < other.y - STAIR_RUN_SEAM_TOLERANCE \
					and other.x < interval.y - STAIR_RUN_SEAM_TOLERANCE:
				return []
		out.append(interval)
	return out


static func path_hits_solids(samples: Array[Vector3],
		placements: Array[VillageMassingPlacement], from_owner: StringName,
		to_owner: StringName, half_width: float) -> bool:
	return not first_solid_hit(samples, placements, from_owner, to_owner,
		half_width).is_empty()


static func first_solid_hit(samples: Array[Vector3],
		placements: Array[VillageMassingPlacement], from_owner: StringName,
		to_owner: StringName, half_width: float) -> StringName:
	for index in range(1, samples.size()):
		var a := samples[index - 1]
		var b := samples[index]
		var shape := FeatureGroundShape.capsule(Vector2(a.x, a.z),
			Vector2(b.x, b.z), half_width)
		var minimum_y := minf(a.y, b.y)
		var maximum_y := maxf(a.y, b.y) \
			+ TraversalEnvelope.MIN_HEADROOM
		for placement: VillageMassingPlacement in placements:
			if (placement.stable_key == from_owner \
					or placement.stable_key == to_owner) \
					and _inside_access_corridor(Vector2(a.x, a.z),
						Vector2(b.x, b.z), half_width, placement):
				continue
			if not placement.ground_route_support_profile:
				if shape.intersects(placement.solid_shape(),
						VillageMassingProgram.ACCESS_CLEARANCE) \
						and vertical_overlap(minimum_y, maximum_y,
							placement.solid_min_y, placement.solid_max_y):
					return placement.stable_key
				continue
			# A complete prefab's measured visual OBB contains its roof eaves.
			# Projecting that whole box to the ground made a street beside the wall
			# collide with a harmless overhead eave. The reviewed contact rectangle
			# is the occupied lower-storey fact; the broader visual OBB becomes a
			# blocker only above traversal headroom. This is the same two-volume
			# contract used when the accepted outskirts building is committed.
			var hits_lower_storey := shape.intersects(
				placement.support_shape(),
				VillageMassingProgram.ACCESS_CLEARANCE) \
				and vertical_overlap(minimum_y, maximum_y,
					placement.solid_min_y, placement.solid_max_y)
			var upper_solid_min := maxf(placement.solid_min_y,
				placement.floor_y + TraversalEnvelope.MIN_HEADROOM)
			var hits_upper_visual := upper_solid_min \
				< placement.solid_max_y - 0.001 \
				and shape.intersects(placement.solid_shape(),
					VillageMassingProgram.ACCESS_CLEARANCE) \
				and vertical_overlap(minimum_y, maximum_y,
					upper_solid_min, placement.solid_max_y)
			if hits_lower_storey or hits_upper_visual:
				return placement.stable_key
	return &""


static func path_hits_volumes(samples: Array[Vector3],
		volumes: Array[VillageOccupancyVolume], half_width: float) -> bool:
	if volumes.is_empty():
		return false
	for index in range(1, samples.size()):
		var a := samples[index - 1]
		var b := samples[index]
		var a2 := Vector2(a.x, a.z)
		var b2 := Vector2(b.x, b.z)
		var delta := b2 - a2
		if delta.length_squared() <= 0.0001:
			continue
		var sweep := VillageOccupancyVolume.new(
			VillageOccupancy.Role.HEADROOM, (a2 + b2) * 0.5,
			Vector2(delta.length() * 0.5, half_width), delta.angle(),
			minf(a.y, b.y), maxf(a.y, b.y) + TraversalEnvelope.MIN_HEADROOM,
			StringName("route.sweep.%03d" % index))
		for volume: VillageOccupancyVolume in volumes:
			if sweep.overlaps(volume):
				return true
	return false


static func _inside_access_corridor(a: Vector2, b: Vector2,
		half_width: float, placement: VillageMassingPlacement) -> bool:
	var interval := _segment_box_interval(a, b, placement.solid_centre,
		placement.solid_half_extents + Vector2.ONE * half_width,
		placement.solid_angle)
	if interval.x > interval.y:
		return true
	var access := placement.route_access_shape()
	# The route capsule, not merely its centreline, must fit inside the reviewed
	# doorway capsule wherever it actually crosses the conservative solid OBB.
	# Both sets are convex, so proving the two clipped endpoints proves the
	# complete interval without a density-dependent sample loop.
	return access.signed_distance(a.lerp(b, interval.x)) \
		<= -half_width + 0.001 \
		and access.signed_distance(a.lerp(b, interval.y)) \
			<= -half_width + 0.001


static func _segment_box_interval(a: Vector2, b: Vector2,
		centre: Vector2, half_extents: Vector2, angle: float) -> Vector2:
	var local_a := (a - centre).rotated(-angle)
	var local_b := (b - centre).rotated(-angle)
	var delta := local_b - local_a
	var interval := Vector2(0.0, 1.0)
	for axis in 2:
		var start := local_a[axis]
		var direction := delta[axis]
		var extent := half_extents[axis]
		if absf(direction) <= 0.000001:
			if absf(start) > extent:
				return Vector2(1.0, 0.0)
			continue
		var first := (-extent - start) / direction
		var second := (extent - start) / direction
		if first > second:
			var swap := first
			first = second
			second = swap
		interval.x = maxf(interval.x, first)
		interval.y = minf(interval.y, second)
		if interval.x > interval.y:
			return Vector2(1.0, 0.0)
	return interval


static func sample_polyline_2d(points: Array[Vector2],
		step: float) -> Array[Vector2]:
	var out: Array[Vector2] = [points[0]]
	for index in range(1, points.size()):
		var a := points[index - 1]
		var b := points[index]
		var divisions := maxi(1, ceili(a.distance_to(b) / step))
		for sample_index in range(1, divisions + 1):
			out.append(a.lerp(b,
				float(sample_index) / float(divisions)))
	return out


static func linear_samples(a: Vector3, b: Vector3,
		step: float) -> Array[Vector3]:
	var divisions := maxi(1, ceili(a.distance_to(b) / step))
	var out: Array[Vector3] = []
	for index in range(divisions + 1):
		out.append(a.lerp(b, float(index) / float(divisions)))
	return out


static func polyline_length(points: Array[Vector3]) -> float:
	var total := 0.0
	for index in range(1, points.size()):
		total += points[index - 1].distance_to(points[index])
	return total


static func polyline_horizontal_length(points: Array[Vector3]) -> float:
	var total := 0.0
	for index in range(1, points.size()):
		var a := points[index - 1]
		var b := points[index]
		total += Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
	return total


static func polyline_length_2d(points: Array[Vector2]) -> float:
	var total := 0.0
	for index in range(1, points.size()):
		total += points[index - 1].distance_to(points[index])
	return total


static func point3(point: Vector2, y: float) -> Vector3:
	return Vector3(point.x, y, point.y)


static func edge_key(prefix: StringName, a: StringName,
		b: StringName) -> StringName:
	var first := String(a)
	var second := String(b)
	if second < first:
		var swap := first
		first = second
		second = swap
	return StringName("%s.%s.%s" % [prefix, first, second])


static func link_less(a: VillageCirculationLink,
		b: VillageCirculationLink) -> bool:
	if a.length != b.length:
		return a.length < b.length
	return String(a.stable_key) < String(b.stable_key)


static func vertical_overlap(a_min: float, a_max: float,
		b_min: float, b_max: float) -> bool:
	return a_min < b_max - 0.001 and b_min < a_max - 0.001
