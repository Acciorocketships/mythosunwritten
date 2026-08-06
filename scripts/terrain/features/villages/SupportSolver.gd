class_name SupportSolver
extends RefCounted

## Deterministically composes fixed support modules downward from a frozen deck
## elevation. No collision-bearing transform is stretched to fit terrain.
const EPS := 0.001

static func solve(request: SupportRequest, region: HeightfieldRegion,
		water: WaterFieldContext = null,
		occupancy: VillageOccupancy = null) -> Dictionary:
	assert(request != null and region != null)
	var modules: Array[SupportModule] = request.modules.duplicate()
	modules.sort_custom(func(a: SupportModule, b: SupportModule) -> bool:
		return String(a.asset_id) < String(b.asset_id))
	var pieces: Array[Dictionary] = []
	var volumes: Array[VillageOccupancyVolume] = []
	var stacks: Array[Dictionary] = []
	for anchor_index in request.anchors.size():
		var anchor: Vector2 = request.anchors[anchor_index]
		var bounds: Vector2 = ground_bounds(anchor, request.angle, modules,
			region)
		if bounds.y - bounds.x > request.max_ground_span + EPS:
			return _rejected(&"ground_span")
		if water != null:
			for point: Vector2 in ground_samples(anchor, request.angle, modules):
				if water.is_wet(point):
					return _rejected(&"water")
		var span := bounds.y - bounds.x
		var reference_y := bounds.y
		var available_burial := request.max_bottom_burial
		if request.ground_reference == SupportRequest.GroundReference.LOWEST:
			# Broad stone bases must reach the low side of a natural slope. The
			# same fixed module is then buried on the high side, which seals the
			# footprint without stretching collision or leaving a visible gap.
			reference_y = bounds.x
			available_burial -= span
			if available_burial < -EPS:
				return _rejected(&"ground_span")
		var required: float = request.target_y - reference_y
		if required <= EPS:
			return _rejected(&"deck_below_ground")
		var stack: Dictionary = _choose_stack(modules, required,
			maxf(0.0, available_burial), request.max_modules_per_stack)
		if stack.is_empty():
			return _rejected(&"no_fixed_stack")
		stack["anchor"] = anchor
		stack["ground_bounds"] = bounds
		stack["maximum_burial"] = float(stack.burial) + span \
			if request.ground_reference \
				== SupportRequest.GroundReference.LOWEST \
			else float(stack.burial)
		stacks.append(stack)
		var used_height := 0.0
		var selected: Array = stack.modules
		for layer in selected.size():
			var module := selected[layer] as SupportModule
			var top_y := request.target_y - used_height
			var bottom_y := top_y - module.height
			var id := StringName("%s.support.%d.%d" % [
				String(request.stable_id), anchor_index, layer])
			pieces.append({
				"asset_id": module.asset_id,
				"stable_id": id,
				"transform": Transform3D(Basis(Vector3.UP, request.angle),
					Vector3(anchor.x,
						top_y - (module.local_bottom_y + module.height),
						anchor.y)),
				"burial": float(stack.burial) \
					if layer == selected.size() - 1 else 0.0,
			})
			for stencil_index in module.solid_stencil.size():
				var stencil: Dictionary = module.solid_stencil[stencil_index]
				var centre: Vector2 = anchor \
					+ (stencil.offset as Vector2).rotated(
						request.angle)
				volumes.append(VillageOccupancyVolume.new(
					VillageOccupancy.Role.SOLID, centre,
					stencil.half_extents, request.angle, bottom_y, top_y,
					StringName("%s.solid.%d" % [id, stencil_index]),
					request.owner_id))
			used_height += module.height
	if occupancy != null and not occupancy.add_all(volumes):
		return _rejected(&"occupancy")
	return {
		"accepted": true,
		"reason": &"",
		"pieces": pieces,
		"volumes": volumes,
		"stacks": stacks,
	}

## Conservative ground interval beneath the actual compiled solid stencil.
## This is public so an atomic multi-support group can choose one common deck
## elevation before asking the solver to materialize any stack.
static func ground_bounds(anchor: Vector2, angle: float,
		modules: Array[SupportModule], region: HeightfieldRegion) -> Vector2:
	assert(not modules.is_empty() and region != null)
	var minimum := INF
	var maximum := -INF
	for module: SupportModule in modules:
		for stencil: Dictionary in module.solid_stencil:
			var centre: Vector2 = anchor \
				+ (stencil.offset as Vector2).rotated(angle)
			var shape: FeatureGroundShape = FeatureGroundShape.oriented_rect(centre,
				stencil.half_extents, angle)
			var bounds: Vector2 = TerrainSurfaceField.height_bounds(region,
				shape.bounds())
			minimum = minf(minimum, bounds.x)
			maximum = maxf(maximum, bounds.y)
	assert(minimum != INF and maximum != -INF)
	return Vector2(minimum, maximum)

static func ground_samples(anchor: Vector2, angle: float,
		modules: Array[SupportModule]) -> Array[Vector2]:
	var unique: Dictionary = {}
	for module: SupportModule in modules:
		for stencil: Dictionary in module.solid_stencil:
			var centre: Vector2 = anchor \
				+ (stencil.offset as Vector2).rotated(angle)
			var extents: Vector2 = stencil.half_extents
			for local: Vector2 in [Vector2.ZERO,
					Vector2(-extents.x, -extents.y),
					Vector2(extents.x, -extents.y), extents,
					Vector2(-extents.x, extents.y)]:
				var point: Vector2 = centre + local.rotated(angle)
				unique[Vector2i(roundi(point.x * 1000.0),
					roundi(point.y * 1000.0))] = point
	var out: Array[Vector2] = []
	out.assign(unique.values())
	return out

static func _choose_stack(modules: Array[SupportModule], required: float,
		max_burial: float, max_count: int) -> Dictionary:
	var candidates: Array[Dictionary] = []
	_enumerate_stacks(modules, required, max_burial, max_count,
		0, [], 0.0, candidates)
	if candidates.is_empty():
		return {}
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if float(a.burial) != float(b.burial):
			return float(a.burial) < float(b.burial)
		if (a.modules as Array).size() != (b.modules as Array).size():
			return (a.modules as Array).size() < (b.modules as Array).size()
		return String(a.signature) < String(b.signature))
	return candidates[0]

static func _enumerate_stacks(modules: Array[SupportModule], required: float,
		max_burial: float, max_count: int, minimum_index: int,
		selected: Array[SupportModule], total: float,
		out: Array[Dictionary]) -> void:
	if not selected.is_empty() and total >= required - EPS:
		var burial := total - required
		if burial <= max_burial + EPS:
			var ids: Array[String] = []
			for module: SupportModule in selected:
				ids.append(String(module.asset_id))
			out.append({
				"modules": selected.duplicate(),
				"height": total,
				"burial": maxf(0.0, burial),
				"signature": ",".join(ids),
			})
		return
	if selected.size() >= max_count:
		return
	for module_index in range(minimum_index, modules.size()):
		var next: Array[SupportModule] = selected.duplicate()
		next.append(modules[module_index])
		_enumerate_stacks(modules, required, max_burial, max_count,
			module_index, next, total + modules[module_index].height, out)

static func _rejected(reason: StringName) -> Dictionary:
	return {
		"accepted": false,
		"reason": reason,
		"pieces": [],
		"volumes": [],
		"stacks": [],
	}
