class_name DressingField
extends RefCounted

const PROPOSAL_CELL := 24.0

# Named-purpose salts keep unrelated visual decisions stable when one concern
# changes. Values are fixed engine data, never derived from resource order.
const SALT_ELIGIBILITY := 0x1A2B3C4D
const SALT_JITTER_X := 0x243F6A88
const SALT_JITTER_Z := 0x85A308D3
const SALT_ARBITRATION := 0x13198A2E
const SALT_CHOICE := 0x03707344
const SALT_YAW := 0xA4093822
const SALT_SCALE := 0x299F31D0
const SALT_BRIGHTNESS := 0x082EFA98

static func compute(program: DressingProgram, world_seed: int, core: Rect2,
		region: HeightfieldRegion, water: WaterFieldContext) -> DressingPayload:
	assert(program != null and region != null and water != null)
	var eligible: Array[Dictionary] = []
	for set_data: Dictionary in program.sets:
		eligible.append_array(_eligible_for_set(set_data, world_seed, core, region, water))
	var winners: Array[Dictionary] = []
	for candidate: Dictionary in eligible:
		var survives := true
		for other: Dictionary in eligible:
			if _same_candidate(other, candidate) \
					or other.spacing_group != candidate.spacing_group:
				continue
			var conflict_radius := maxf(candidate.spacing_radius, other.spacing_radius)
			if conflict_radius <= 0.0 \
					or candidate.anchor.distance_squared_to(other.anchor) >= conflict_radius * conflict_radius:
				continue
			if _key_less(other, candidate):
				survives = false
				break
		if survives and _contains_half_open(core, candidate.anchor):
			winners.append(candidate)
	winners.sort_custom(_key_less)
	var payload := DressingPayload.new()
	for candidate: Dictionary in winners:
		payload.add(candidate.asset_id, candidate.transform, candidate.color)
	return payload

static func _eligible_for_set(set_data: Dictionary, world_seed: int, core: Rect2,
		region: HeightfieldRegion, water: WaterFieldContext) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var query: Rect2 = core.grow(float(set_data.group_radius))
	var min_cell := Vector2i(int(floor(query.position.x / PROPOSAL_CELL)),
		int(floor(query.position.y / PROPOSAL_CELL)))
	var max_cell := Vector2i(int(ceil(query.end.x / PROPOSAL_CELL)) - 1,
		int(ceil(query.end.y / PROPOSAL_CELL)) - 1)
	for cz in range(min_cell.y, max_cell.y + 1):
		for cx in range(min_cell.x, max_cell.x + 1):
			var proposal_cell := Vector2i(cx, cz)
			for slot_index in set_data.slot_count:
				var identity: int = _identity(world_seed, set_data, proposal_cell, slot_index)
				var anchor: Vector2 = Vector2(
					(float(cx) + _roll(identity, SALT_JITTER_X)) * PROPOSAL_CELL,
					(float(cz) + _roll(identity, SALT_JITTER_Z)) * PROPOSAL_CELL)
				if not _contains_half_open(query, anchor):
					continue
				var weights: Dictionary = Helper.biome_weights5(Vector3(anchor.x, 0.0, anchor.y), world_seed)
				var intensity: float = _biome_dot(set_data.fill_per_cell, weights)
				if set_data.water_mode == DressingSet.WaterMode.LAND:
					intensity *= DressingEcology.land_occupancy01(anchor, world_seed)
				for layer: Dictionary in set_data.habitat_layers:
					var coverage: float = _biome_dot(layer.coverage, weights)
					var habitat := DressingEcology.habitat01(anchor, world_seed,
						layer.channel_hash, layer.scale)
					intensity *= DressingEcology.suitability(habitat, coverage,
						layer.preference, layer.softness)
				if _roll(identity, SALT_ELIGIBILITY) >= clampf(intensity / set_data.slot_count, 0.0, 1.0):
					continue
				var qualification: Dictionary = _qualify(set_data, anchor, region, water)
				if qualification.is_empty():
					continue
				var choice_roll := _roll(identity, SALT_CHOICE)
				if set_data.community_hash != 0:
					var community_roll := DressingEcology.community_roll(anchor, world_seed,
						set_data.community_hash, set_data.community_scale)
					choice_roll = lerpf(choice_roll, community_roll, set_data.community_strength)
				var choice: Dictionary = _choose(set_data.choices, weights, choice_roll)
				if choice.is_empty():
					continue
				var yaw: float = _roll(identity, SALT_YAW) * TAU
				var scale: float = choice.scale_multiplier * lerpf(
					set_data.scale_range.x, set_data.scale_range.y,
					_roll(identity, SALT_SCALE))
				var brightness: float = lerpf(set_data.brightness_range.x, set_data.brightness_range.y,
					_roll(identity, SALT_BRIGHTNESS))
				var tint: Color = BiomeRegistry.blended_environment_tint(weights, choice.tint_group)
				var basis: Basis = Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale)
				out.append({
					"set_id": set_data.id,
					"cell": proposal_cell,
					"slot": slot_index,
					"key_hash": Helper._mix64(identity ^ SALT_ARBITRATION),
					"spacing_group": set_data.spacing_group,
					"spacing_radius": choice.spacing_radius,
					"anchor": anchor,
					"asset_id": choice.asset_id,
					"transform": Transform3D(basis,
						Vector3(anchor.x, qualification.y, anchor.y)),
					"color": Color(tint.r * brightness, tint.g * brightness,
						tint.b * brightness, tint.a),
				})
	return out

static func _qualify(set_data: Dictionary, anchor: Vector2,
		region: HeightfieldRegion, water: WaterFieldContext) -> Dictionary:
	var points: Array[Vector2] = [anchor]
	if set_data.surface_mode == DressingSet.SurfaceMode.GROUND_SUPPORT:
		var radius: float = set_data.support_radius
		for direction: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN,
			Vector2(1, 1).normalized(), Vector2(1, -1).normalized(),
			Vector2(-1, 1).normalized(), Vector2(-1, -1).normalized()]:
			points.append(anchor + direction * radius)
	for point: Vector2 in points:
		if not water.covers(point) or not _water_ok(set_data, water, point):
			return {}
	if set_data.surface_mode == DressingSet.SurfaceMode.WATER_SURFACE:
		var level: float = water.level_at(anchor)
		return {} if is_nan(level) else {"y": level}
	var heights := PackedFloat32Array()
	for point: Vector2 in points:
		heights.append(TerrainSurfaceField.surface_y(region, point.x, point.y))
	var min_height: float = heights[0]
	var max_height: float = heights[0]
	for height: float in heights:
		min_height = minf(min_height, height)
		max_height = maxf(max_height, height)
	if set_data.surface_mode == DressingSet.SurfaceMode.GROUND_SUPPORT:
		if max_height - min_height > set_data.max_support_height_span:
			return {}
		var radius: float = set_data.support_radius
		if radius > 0.0 and (max_height - min_height) / (2.0 * radius) > set_data.max_grade:
			return {}
	else:
		var step: float = DressingCompiler.SURFACE_STENCIL
		var hx: float = TerrainSurfaceField.surface_y(region, anchor.x + step, anchor.y) \
			- TerrainSurfaceField.surface_y(region, anchor.x - step, anchor.y)
		var hz: float = TerrainSurfaceField.surface_y(region, anchor.x, anchor.y + step) \
			- TerrainSurfaceField.surface_y(region, anchor.x, anchor.y - step)
		if Vector2(hx, hz).length() / (2.0 * step) > set_data.max_grade:
			return {}
	return {"y": heights[0]}

static func _water_ok(set_data: Dictionary, water: WaterFieldContext, point: Vector2) -> bool:
	match set_data.water_mode:
		DressingSet.WaterMode.LAND:
			return not water.is_wet(point) \
				and water.shore_distance_at(point) >= set_data.shore_range.x
		DressingSet.WaterMode.SHORE:
			var shore: float = water.shore_distance_at(point)
			return shore >= set_data.shore_range.x and shore <= set_data.shore_range.y
		DressingSet.WaterMode.SHALLOW:
			if not water.is_wet(point):
				return false
			var depth: float = water.signed_depth_at(point)
			return depth >= set_data.depth_range.x and depth <= set_data.depth_range.y
		DressingSet.WaterMode.EMERGENT:
			if not water.is_wet(point):
				return false
			var depth: float = water.signed_depth_at(point)
			var inward_shore_distance := -water.shore_distance_at(point)
			return depth >= set_data.depth_range.x and depth <= set_data.depth_range.y \
				and inward_shore_distance >= set_data.shore_range.x \
				and inward_shore_distance <= set_data.shore_range.y
		DressingSet.WaterMode.FLOATING:
			return water.is_wet(point)
	return false

static func _choose(choices: Array, biome_weights: Dictionary, roll: float) -> Dictionary:
	var total: float = 0.0
	var resolved: Array[float] = []
	for choice: Dictionary in choices:
		var weight: float = choice.weight * _biome_dot(choice.affinity, biome_weights)
		resolved.append(weight)
		total += weight
	if total <= 0.0:
		return {}
	var target: float = roll * total
	var accumulated: float = 0.0
	for index in choices.size():
		accumulated += resolved[index]
		if target < accumulated:
			return choices[index]
	return choices[-1]

static func _biome_dot(affinity: PackedFloat32Array, weights: Dictionary) -> float:
	var out: float = 0.0
	var biome_ids: Array[StringName] = BiomeRegistry.biome_ids()
	for index in biome_ids.size():
		out += affinity[index] * float(weights[biome_ids[index]])
	return out

static func _identity(world_seed: int, set_data: Dictionary,
		cell: Vector2i, slot_index: int) -> int:
	return Helper._mix64(world_seed ^ set_data.id_hash \
		^ Helper._mix64(set_data.seed_version) \
		^ Helper._mix64(cell.x) ^ Helper._mix64(cell.y) \
		^ Helper._mix64(slot_index))

static func _roll(identity: int, salt: int) -> float:
	return Helper._hash01(Helper._mix64(identity ^ salt))

static func _key_less(a: Dictionary, b: Dictionary) -> bool:
	if a.key_hash != b.key_hash:
		return a.key_hash < b.key_hash
	var a_set := String(a.set_id)
	var b_set := String(b.set_id)
	if a_set != b_set:
		return a_set < b_set
	if a.cell.x != b.cell.x:
		return a.cell.x < b.cell.x
	if a.cell.y != b.cell.y:
		return a.cell.y < b.cell.y
	return a.slot < b.slot

static func _same_candidate(a: Dictionary, b: Dictionary) -> bool:
	return a.set_id == b.set_id and a.cell == b.cell and a.slot == b.slot

static func _contains_half_open(rect: Rect2, point: Vector2) -> bool:
	return point.x >= rect.position.x and point.y >= rect.position.y \
		and point.x < rect.end.x and point.y < rect.end.y
