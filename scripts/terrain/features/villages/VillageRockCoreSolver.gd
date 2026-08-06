class_name VillageRockCoreSolver
extends RefCounted

## Builds one compact terrain-attached rock core from the reviewed building
## ground contact. It uses only fixed support modules and validates the full
## perimeter before returning any pieces.


static func solve(terrain: VillageTerrainView, stable_id: StringName,
		placement: VillageMassingPlacement, spec: VillageAssetSpec,
		program: VillageProgram,
		reserved_volumes: Array[VillageOccupancyVolume] = []
		) -> VillageBuildingSupportPlan:
	assert(terrain != null and not stable_id.is_empty())
	assert(placement != null and spec != null and program != null)
	var plan := VillageBuildingSupportPlan.new()
	plan.stable_id = stable_id
	plan.mode = VillageBuildingSupportPlan.Mode.ROCK_CORE
	plan.floor_y = placement.floor_y
	var transform := placement.building_transform(spec)
	var contact := spec.world_ground_contact(transform)
	var cores := _core_rects(contact, placement.entrance_outward)
	if cores.is_empty():
		return _rejected(plan, &"core_grid")
	var accepted: Array[VillageBuildingSupportPlan] = []
	var first_reason := &"perimeter_grid"
	for core: Dictionary in cores:
		var candidate := _solve_core(terrain, stable_id, placement,
			program, core, reserved_volumes)
		if candidate.accepted:
			accepted.append(candidate)
		elif accepted.is_empty():
			first_reason = candidate.reason
	if accepted.is_empty():
		return _rejected(plan, first_reason)
	accepted.sort_custom(func(a: VillageBuildingSupportPlan,
			b: VillageBuildingSupportPlan) -> bool:
		var a_area := (a.core.half_extents as Vector2).x \
			* (a.core.half_extents as Vector2).y
		var b_area := (b.core.half_extents as Vector2).x \
			* (b.core.half_extents as Vector2).y
		if a_area != b_area:
			return a_area > b_area
		if a.pieces.size() != b.pieces.size():
			return a.pieces.size() < b.pieces.size()
		return String(a.core.signature) < String(b.core.signature))
	return accepted[0]


static func _solve_core(terrain: VillageTerrainView, stable_id: StringName,
		placement: VillageMassingPlacement, program: VillageProgram,
		core: Dictionary,
		reserved_volumes: Array[VillageOccupancyVolume]
		) -> VillageBuildingSupportPlan:
	var plan := VillageBuildingSupportPlan.new()
	plan.stable_id = stable_id
	plan.mode = VillageBuildingSupportPlan.Mode.ROCK_CORE
	plan.floor_y = placement.floor_y
	var supports := _perimeter_supports(core,
		program.foundation_module_width, program.foundation_module_depth)
	if supports.is_empty():
		return _rejected(plan, &"perimeter_grid")
	var module := program.elevated_program.rock_module(program)
	for support: Dictionary in supports:
		var anchor: Vector2 = support.anchor
		var angle := float(support.angle)
		var modules: Array[SupportModule] = [module]
		var region := terrain.region_at(anchor)
		var bounds := SupportSolver.ground_bounds(anchor, angle,
			modules, region)
		if not plan.terrain_bounds.is_finite():
			plan.terrain_bounds = bounds
		else:
			plan.terrain_bounds.x = minf(plan.terrain_bounds.x, bounds.x)
			plan.terrain_bounds.y = maxf(plan.terrain_bounds.y, bounds.y)
		if bounds.y - bounds.x \
				> VillageElevatedProgram.MAX_SUPPORT_GROUND_SPAN + 0.001:
			return _rejected(plan, &"ground_span")
		for point: Vector2 in SupportSolver.ground_samples(anchor,
				angle, modules):
			if terrain.is_wet(point):
				return _rejected(plan, &"water")
		var request := SupportRequest.new(
			StringName("%s.rock.%03d" % [stable_id, int(support.index)]),
			[anchor], placement.floor_y, angle, modules,
			program.foundation_module_depth * 0.5,
			VillageElevatedProgram.MAX_SUPPORT_GROUND_SPAN,
			VillageElevatedProgram.MAX_ROCK_SUPPORT_BURIAL,
			VillageElevatedProgram.MAX_ROCK_STACK_MODULES,
			SupportRequest.GroundReference.LOWEST)
		var solved := SupportSolver.solve(request, region)
		if not bool(solved.accepted):
			return _rejected(plan,
				StringName("stack_%s" % String(solved.reason)))
		plan.pieces.append_array(solved.pieces)
		for volume: VillageOccupancyVolume in solved.volumes:
			# Adjacent fixed modules are one authored compound core. Explicit
			# ownership permits their closed faces to meet while different cores
			# and all unrelated solids remain strict occupancy conflicts.
			volume.owner_id = stable_id
			plan.volumes.append(volume)
	var conflict := VillageOccupancy.first_cross_conflict(plan.volumes,
		reserved_volumes)
	if not conflict.is_empty():
		var existing := conflict.existing as VillageOccupancyVolume
		return _rejected(plan, StringName("occupancy_%s" \
			% String(existing.stable_id)))
	plan.core = core
	plan.accepted = true
	plan.reason = &"accepted"
	assert(plan.validate())
	return plan


static func _core_rects(contact: Dictionary,
		outward: Vector2) -> Array[Dictionary]:
	var side := Vector2(-outward.y, outward.x)
	var projections := _rect_projections(contact, side, outward)
	var full_width := float(projections.side_max) \
		- float(projections.side_min)
	var full_depth := float(projections.out_max) \
		- float(projections.out_min)
	var preferred_width_modules := maxi(2, floori(full_width \
		* VillageElevatedProgram.PLINTH_WIDTH_FRACTION \
		/ VillageProgram.MODULE + 0.0001))
	var preferred_depth_modules := maxi(2, floori(full_depth \
		* VillageElevatedProgram.PLINTH_DEPTH_FRACTION \
		/ VillageProgram.MODULE + 0.0001))
	if float(preferred_width_modules) * VillageProgram.MODULE \
			> full_width + 0.001 \
			or float(preferred_depth_modules) * VillageProgram.MODULE \
				> full_depth + 0.001:
		return []
	var out: Array[Dictionary] = []
	for width_modules in range(preferred_width_modules, 1, -1):
		for depth_modules in range(preferred_depth_modules, 1, -1):
			var width := float(width_modules) * VillageProgram.MODULE
			var depth := float(depth_modules) * VillageProgram.MODULE
			var side_steps := floori((full_width - width) \
				/ VillageProgram.MODULE + 0.001)
			var outward_steps := floori((full_depth - depth) \
				/ VillageProgram.MODULE + 0.001)
			for outward_step in range(outward_steps + 1):
				for side_step in range(side_steps + 1):
					var side_projection := float(projections.side_min) \
						+ width * 0.5 \
						+ float(side_step) * VillageProgram.MODULE
					var outward_projection := float(projections.out_min) \
						+ depth * 0.5 \
						+ float(outward_step) * VillageProgram.MODULE
					out.append({
						"centre": side * side_projection \
							+ outward * outward_projection,
						"half_extents": Vector2(width, depth) * 0.5,
						"angle": side.angle(),
						"front_projection": outward_projection \
							+ depth * 0.5,
						"contact_front_projection": float(projections.out_max),
						"signature": "%02d:%02d:%02d:%02d" % [
							width_modules, depth_modules,
							outward_step, side_step],
					})
	return out


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
			out.append({
				"anchor": a + direction * module_width \
					* (float(segment) + 0.5) \
					+ inward * module_depth * 0.5,
				"angle": Vector2.RIGHT.angle() - direction.angle(),
				"index": out.size(),
			})
	return out


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
		var point: Vector2 = rect.centre + axis_x * local.x + axis_z * local.y
		side_min = minf(side_min, point.dot(side))
		side_max = maxf(side_max, point.dot(side))
		out_min = minf(out_min, point.dot(outward))
		out_max = maxf(out_max, point.dot(outward))
	return {"side_min": side_min, "side_max": side_max,
		"out_min": out_min, "out_max": out_max}


static func _rejected(plan: VillageBuildingSupportPlan,
		reason: StringName) -> VillageBuildingSupportPlan:
	plan.reason = reason
	plan.floor_y = NAN
	plan.terrain_bounds = Vector2(NAN, NAN)
	plan.core.clear()
	plan.pieces.clear()
	plan.volumes.clear()
	assert(plan.validate())
	return plan
