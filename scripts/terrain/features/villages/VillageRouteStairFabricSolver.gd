class_name VillageRouteStairFabricSolver
extends RefCounted

## Compiles every non-entrance height transition into the same authored stair
## vocabulary. Runs occupy disjoint arclength intervals on their route; deck
## and ground-surface compilers consume those frozen intervals directly.
const EPS := 0.001
static func solve(settlement_id: StringName,
		circulation: VillageCirculationPlan,
		vocabulary: VillageElevatedProgram) -> VillageRouteStairFabricPlan:
	assert(not settlement_id.is_empty() and circulation != null)
	assert(circulation.accepted and vocabulary != null)
	var plan := VillageRouteStairFabricPlan.new()
	for link: VillageCirculationLink in circulation.links:
		if link.kind == VillageCirculationLink.Kind.ENTRANCE \
				or link.stair_count <= 0:
			continue
		var cumulative := _cumulative(link.samples)
		var occupied: Array[Vector2] = []
		if link.kind == VillageCirculationLink.Kind.GROUND_STAIR:
			for transition_index in link.stair_transitions.size():
				var transition := link.stair_transitions[transition_index]
				var run: VillageRouteStairRun
				var interval := link.stair_intervals[transition_index]
				run = _append_run(plan, settlement_id, link,
					transition_index, interval, transition.stair_count,
					transition.signed_rise, cumulative, vocabulary,
					Vector2(link.samples[transition.segment_index - 1].y,
						link.samples[transition.segment_index].y))
				if run == null:
					return _rejected(StringName(
						"ground_geometry_%s_%02d_%s_c%d_r%d" % [
							link.stable_key, transition_index,
							plan.reason,
							transition.stair_count,
							roundi(transition.signed_rise * 1000.0)]))
				occupied.append(interval)
		elif link.is_aerial():
			if link.stair_intervals.size() != 1:
				return _rejected(&"aerial_interval")
			var aerial_run := _append_run(plan, settlement_id, link, 0,
				link.stair_intervals[0], link.stair_count,
				link.samples[-1].y - link.samples[0].y,
				cumulative, vocabulary)
			if aerial_run == null:
				return _rejected(&"aerial_geometry")
		else:
			return _rejected(&"link_kind")
	if plan.runs.is_empty():
		plan.accepted = true
		plan.reason = &"accepted"
		return plan
	plan.accepted = true
	plan.reason = &"accepted"
	assert(plan.validate())
	return plan


static func _append_run(plan: VillageRouteStairFabricPlan,
		settlement_id: StringName, link: VillageCirculationLink,
		run_index: int, interval: Vector2, count: int, signed_rise: float,
		cumulative: PackedFloat32Array,
		vocabulary: VillageElevatedProgram,
		landing_heights: Vector2 = Vector2(INF, INF)) -> VillageRouteStairRun:
	if count <= 0 or absf(signed_rise) \
			<= TraversalEnvelope.MAX_PLANNED_STEP:
		plan.reason = &"transition_contract"
		return null
	var from_y := _point_at(link.samples, cumulative, interval.x).y
	var to_y := _point_at(link.samples, cumulative, interval.y).y
	# Aerial samples encode only horizontal planning geometry between two flat
	# landings. Ground flights freeze the two terrain samples that requested the
	# transition; their authored run may extend a little onto either landing,
	# but it is never moved to a different route edge.
	if link.is_aerial():
		from_y = link.samples[0].y
		to_y = link.samples[-1].y
	elif landing_heights.is_finite():
		from_y = landing_heights.x
		to_y = landing_heights.y
	if (to_y - from_y) * signed_rise <= 0.0:
		plan.reason = &"landing_direction"
		return null
	var stable_key := StringName("%s.%s.stair_run.%02d" % [settlement_id,
		link.stable_key, run_index])
	var run := VillageRouteStairRun.new(stable_key, link.stable_key,
		interval.x, interval.y, from_y, to_y, count)
	if not run.is_valid():
		plan.reason = &"run_contract"
		return null
	var rise := absf(to_y - from_y)
	var residual := (rise - float(count) * vocabulary.stair_aabb.size.y) * 0.5
	if not TraversalEnvelope.step_is_legal(residual):
		plan.reason = &"landing_residual"
		return null
	var ascending_forward := to_y > from_y
	var low_distance := interval.x if ascending_forward else interval.y
	var distance_sign := 1.0 if ascending_forward else -1.0
	var low_y := minf(from_y, to_y) + residual
	# Ground routes are one connected public-street compound, so two selected
	# graph edges may legitimately reuse or intersect the same stair landing.
	# Aerial flights retain their link owner because they compound with that
	# link's deck/platform and must stay distinct from unrelated structures.
	var owner := StringName("%s.%s" % [settlement_id, link.stable_key]) \
		if link.is_aerial() else StringName("%s.ground_circulation" \
			% settlement_id)
	var walk_network_id := StringName("%s.urban.walk_network" % settlement_id)
	var entry_start := plan.entries.size()
	var volume_start := plan.volumes.size()
	var clearance_start := plan.clearances.size()
	for index in count:
		var distance_a := low_distance + distance_sign \
			* float(index) * vocabulary.stair_module_run
		var distance_b := distance_a + distance_sign \
			* vocabulary.stair_module_run
		var point_a := _point_at(link.samples, cumulative, distance_a)
		var point_b := _point_at(link.samples, cumulative, distance_b)
		var a2 := Vector2(point_a.x, point_a.z)
		var b2 := Vector2(point_b.x, point_b.z)
		var high_direction := (b2 - a2).normalized()
		if not high_direction.is_normalized():
			plan.reason = &"run_direction"
			_rollback(plan, entry_start, volume_start, clearance_start)
			return null
		var yaw := Vector2.UP.angle() - high_direction.angle()
		var basis := Basis(Vector3.UP, yaw)
		var segment_y := low_y + float(index) * vocabulary.stair_aabb.size.y
		var stable_id := StringName("%s.%02d" % [stable_key, index])
		var local_contact := Vector3(vocabulary.stair_aabb.get_center().x,
			vocabulary.stair_aabb.position.y, vocabulary.stair_aabb.end.z)
		var transform := Transform3D(basis,
			Vector3(a2.x, segment_y, a2.y) - basis * local_contact)
		var centre := (a2 + b2) * 0.5
		var volume := VillageOccupancyVolume.new(
			VillageOccupancy.Role.WALK_SURFACE, centre,
			Vector2(a2.distance_to(b2), vocabulary.stair_aabb.size.x) * 0.5,
			high_direction.angle(), segment_y,
			segment_y + vocabulary.stair_aabb.size.y,
			StringName("%s.walk" % stable_id), owner, walk_network_id)
		var duplicate := false
		for existing: VillageOccupancyVolume in plan.volumes:
			if not volume.overlaps(existing):
				continue
			if not _same_stair_volume(volume, existing) \
					and existing.owner_id != owner:
				plan.reason = &"foreign_overlap"
				_rollback(plan, entry_start, volume_start, clearance_start)
				return null
			if _same_stair_volume(volume, existing):
				duplicate = true
				break
		if duplicate:
			continue
		plan.entries.append({"asset_id": vocabulary.stair_asset_id,
			"stable_id": stable_id, "transform": transform})
		plan.volumes.append(volume)
		plan.clearances.append(FeatureGroundShape.capsule(a2, b2,
			vocabulary.stair_aabb.size.x * 0.5 + 0.25,
			FeatureGroundField.NATURAL, 0,
			StringName("%s.clearance" % stable_id)))
		_append_side_railings(plan, stable_id, owner, walk_network_id,
			centre, high_direction, segment_y, vocabulary)
	plan.runs.append(run)
	plan.stair_count = plan.clearances.size()
	plan.railing_count = plan.entries.size() - plan.stair_count
	return run


static func _append_side_railings(plan: VillageRouteStairFabricPlan,
		stair_id: StringName, owner: StringName,
		walk_network_id: StringName, centre: Vector2, direction: Vector2,
		floor_y: float,
		vocabulary: VillageElevatedProgram) -> void:
	# The reviewed railing module is exactly one stair cell long. Keeping its
	# thin depth inside the walk-surface edge adds fall protection without
	# expanding the already validated route reservation into nearby buildings.
	var side := Vector2(-direction.y, direction.x)
	var extents := Vector2(vocabulary.railing_aabb.size.x,
		vocabulary.railing_aabb.size.z) * 0.5
	var offset := maxf(0.0,
		vocabulary.stair_aabb.size.x * 0.5 - extents.y)
	var rise := vocabulary.stair_aabb.size.y
	var tangent3 := Vector3(direction.x,
		rise / vocabulary.stair_module_run, direction.y).normalized()
	var side3 := Vector3(side.x, 0.0, side.y)
	var up3 := side3.cross(tangent3).normalized()
	var basis := Basis(tangent3, up3, side3)
	var local_contact := Vector3(vocabulary.railing_aabb.get_center().x,
		vocabulary.railing_aabb.position.y,
		vocabulary.railing_aabb.get_center().z)
	for side_index in 2:
		var signed_side := side if side_index == 0 else -side
		var rail_centre := centre + signed_side * offset
		var suffix := "left" if side_index == 0 else "right"
		var stable_id := StringName("%s.rail.%s" % [stair_id, suffix])
		plan.entries.append({"asset_id": vocabulary.railing_asset_id,
			"stable_id": stable_id,
			"transform": Transform3D(basis,
				Vector3(rail_centre.x, floor_y + rise * 0.5, rail_centre.y)
					- basis * local_contact)})
		plan.volumes.append(VillageOccupancyVolume.new(
			VillageOccupancy.Role.WALK_GUARD, rail_centre, extents,
			direction.angle(), floor_y,
			floor_y + rise + vocabulary.railing_aabb.size.y,
			StringName("%s.solid" % stable_id), owner, walk_network_id))


static func _rollback(plan: VillageRouteStairFabricPlan,
		entry_count: int, volume_count: int, clearance_count: int) -> void:
	plan.entries.resize(entry_count)
	plan.volumes.resize(volume_count)
	plan.clearances.resize(clearance_count)


static func _same_stair_volume(a: VillageOccupancyVolume,
		b: VillageOccupancyVolume) -> bool:
	return a.centre.distance_to(b.centre) <= 0.05 \
		and a.half_extents.is_equal_approx(b.half_extents) \
		and a.y_range.is_equal_approx(b.y_range) \
		and absf(sin(a.angle - b.angle)) <= 0.01


static func _cumulative(points: Array[Vector3]) -> PackedFloat32Array:
	var out := PackedFloat32Array([0.0])
	for index in range(1, points.size()):
		out.append(out[-1] + Vector2(points[index].x, points[index].z
			).distance_to(Vector2(points[index - 1].x, points[index - 1].z)))
	return out


static func _point_at(points: Array[Vector3], cumulative: PackedFloat32Array,
		distance: float) -> Vector3:
	var target := clampf(distance, 0.0, cumulative[-1])
	var segment := 1
	while segment < cumulative.size() - 1 and cumulative[segment] < target:
		segment += 1
	var span := cumulative[segment] - cumulative[segment - 1]
	var t := 0.0 if span <= EPS else (target - cumulative[segment - 1]) / span
	return points[segment - 1].lerp(points[segment], t)


static func _rejected(reason: StringName) -> VillageRouteStairFabricPlan:
	var plan := VillageRouteStairFabricPlan.new()
	plan.reason = reason
	return plan
