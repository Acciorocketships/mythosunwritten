class_name DressingField
extends RefCounted

const PROPOSAL_CELL := 24.0
## A colony member's centre distance from its main rock, from the deepest
## nestle the shared rule allows (0) to bases just touching (1).
const COLONY_NESTLE := Vector2(0.15, 0.6)

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
		region: HeightfieldRegion, water: WaterFieldContext,
		features: FeatureContext = null, terrain_reservations: Array[Rect2] = []) -> EnvironmentInstancePayload:
	assert(program != null and region != null and water != null)
	var eligible: Array[Dictionary] = []
	for set_data: Dictionary in program.sets:
		eligible.append_array(_eligible_for_set(set_data, world_seed, core, region,
			water, features,terrain_reservations))
	var winners: Array[Dictionary] = []
	for candidate: Dictionary in eligible:
		var survives := true
		for other: Dictionary in eligible:
			if _same_candidate(other, candidate) \
					or other.spacing_group != candidate.spacing_group:
				continue
			var conflict_radius := maxf(candidate.spacing_radius, other.spacing_radius)
			# Two embedded rocks follow the nestle rule alone, so colonies
			# can touch and overlap; anything else keeps its structural spacing.
			var nestle := DressingCompiler.nestle_distance(float(candidate.base_radius),
				float(other.base_radius))
			if candidate.embed_fraction > 0.0 and other.embed_fraction > 0.0:
				conflict_radius = nestle
			elif candidate.embed_fraction > 0.0 or other.embed_fraction > 0.0:
				conflict_radius = maxf(conflict_radius, nestle)
			if conflict_radius <= 0.0 \
					or candidate.anchor.distance_squared_to(other.anchor) >= conflict_radius * conflict_radius:
				continue
			if _key_less(other, candidate):
				survives = false
				break
		if survives and _contains_half_open(core, candidate.anchor):
			winners.append(candidate)
	winners.sort_custom(_key_less)
	var payload := EnvironmentInstancePayload.new()
	for candidate: Dictionary in winners:
		var color: Color = candidate.color
		if candidate.embed_fraction > 0.0:
			payload.ground_skirts.append(_skirt(candidate, region, world_seed))
			# An embedded rock's grass top is the lawn it is set into: the
			# terrain's own tint (as its skirt takes it), clamped like the
			# terrain's 8-bit vertex tints, with no rock exposure (September
			# 27 judging: rock tops read paler than the ground around them).
			var tint: Color = RockSkirt.terrain_surface(region, world_seed).tint.call(candidate.anchor)
			color = Color(clampf(tint.r, 0.0, 1.0), clampf(tint.g, 0.0, 1.0), clampf(tint.b, 0.0, 1.0), 0.0)
		payload.add(candidate.asset_id, candidate.transform, color)
	return payload

## The ground rises to meet an embedded rock: a skirt from the rendered
## terrain up to a low mound under the rock's world-space base outline.
static func _skirt(candidate: Dictionary, region: HeightfieldRegion, world_seed: int) -> Dictionary:
	var t: Transform3D = candidate.transform
	var outline := PackedVector2Array()
	for local: Vector2 in candidate.support_points:
		var w := t * Vector3(local.x, 0.0, local.y)
		outline.append(Vector2(w.x, w.z))
	var surface := RockSkirt.terrain_surface(region, world_seed)
	var exposed: float = t.origin.y + float(candidate.visual_height) * t.basis.y.length() \
		- float(surface.height.call(candidate.anchor))
	return RockSkirt.build("%s/%s/%d" % [candidate.set_id, candidate.cell, candidate.slot],
		candidate.anchor, RockSkirt.contact_radii(outline, candidate.anchor),
		exposed, surface)

static func _eligible_for_set(set_data: Dictionary, world_seed: int, core: Rect2,
		region: HeightfieldRegion, water: WaterFieldContext,
		features: FeatureContext = null, terrain_reservations: Array[Rect2] = []) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var query: Rect2 = core.grow(float(set_data.group_radius))
	var colony_radius: float = set_data.colony_radius
	var cells: Rect2 = query.grow(colony_radius)
	var min_cell := Vector2i(int(floor(cells.position.x / PROPOSAL_CELL)),
		int(floor(cells.position.y / PROPOSAL_CELL)))
	var max_cell := Vector2i(int(ceil(cells.end.x / PROPOSAL_CELL)) - 1,
		int(ceil(cells.end.y / PROPOSAL_CELL)) - 1)
	for cz in range(min_cell.y, max_cell.y + 1):
		for cx in range(min_cell.x, max_cell.x + 1):
			var proposal_cell := Vector2i(cx, cz)
			# A colony set is a clustered (Neyman-Scott) process: each proposal
			# cell may hold one colony, decided once at its jittered centre, and
			# its members gather within colony_radius. Between colonies the
			# ground stays genuinely empty instead of evenly sprinkled.
			var colony := {}
			if colony_radius > 0.0:
				var parent: int = _identity(world_seed, set_data, proposal_cell, -1)
				var centre := Vector2((float(cx) + _roll(parent, SALT_JITTER_X)) * PROPOSAL_CELL,
					(float(cz) + _roll(parent, SALT_JITTER_Z)) * PROPOSAL_CELL)
				var centre_weights: Dictionary = Helper.biome_weights5(
					Vector3(centre.x, 0.0, centre.y), world_seed)
				var colonies: float = _intensity(set_data, centre, world_seed, centre_weights) \
					/ float(set_data.colony_members)
				if _roll(parent, SALT_ELIGIBILITY) >= clampf(colonies, 0.0, 1.0):
					continue
				# The colony gathers round its main rock at the centre (slot 0):
				# every member's stone community is the colony's own.
				var main := _draft(set_data, _identity(world_seed, set_data, proposal_cell, 0),
					centre_weights, centre, world_seed)
				colony = {"centre": centre, "weights": centre_weights,
					"radius": float(main.get("radius", 0.0)),
					"turn": _roll(parent, SALT_JITTER_X) * TAU}
			for slot_index in set_data.slot_count:
				var identity: int = _identity(world_seed, set_data, proposal_cell, slot_index)
				var anchor: Vector2
				var weights: Dictionary
				var keep: float
				var draft: Dictionary
				if colony.is_empty():
					anchor = Vector2(
						(float(cx) + _roll(identity, SALT_JITTER_X)) * PROPOSAL_CELL,
						(float(cz) + _roll(identity, SALT_JITTER_Z)) * PROPOSAL_CELL)
					if not _contains_half_open(query, anchor):
						continue
					weights = Helper.biome_weights5(Vector3(anchor.x, 0.0, anchor.y), world_seed)
					keep = _intensity(set_data, anchor, world_seed, weights) / set_data.slot_count
					if _roll(identity, SALT_ELIGIBILITY) >= clampf(keep, 0.0, 1.0):
						continue
					draft = _draft(set_data, identity, weights, anchor, world_seed)
				else:
					# Owner, September 27 judging: rocks too spaced out; slightly
					# overlapping clusters. The main rock stands at the centre and
					# every other member nestles into it, spread round it, between
					# the shared nestle distance and bases just touching (never
					# beyond colony_radius, which bounds the colony's reach).
					weights = colony.weights
					draft = _draft(set_data, identity, weights, colony.centre, world_seed)
					if draft.is_empty():
						continue
					if slot_index == 0:
						anchor = colony.centre
					else:
						keep = (float(set_data.colony_members) - 1.0) / (set_data.slot_count - 1)
						if _roll(identity, SALT_ELIGIBILITY) >= clampf(keep, 0.0, 1.0):
							continue
						var r0: float = colony.radius
						var reach := minf(colony_radius, lerpf(DressingCompiler.nestle_distance(r0, draft.radius),
							r0 + float(draft.radius), lerpf(COLONY_NESTLE.x, COLONY_NESTLE.y, _roll(identity, SALT_JITTER_Z))))
						anchor = colony.centre + Vector2.from_angle(float(colony.turn)
							+ TAU * (float(slot_index - 1) + 0.3 * _roll(identity, SALT_JITTER_X)) / (set_data.slot_count - 1)) * reach
					if not _contains_half_open(query, anchor):
						continue
				if draft.is_empty():
					continue
				var choice: Dictionary = draft.choice
				var yaw: float = _roll(identity, SALT_YAW) * TAU
				var scale: float = draft.scale
				var brightness: float = lerpf(set_data.brightness_range.x, set_data.brightness_range.y,
					_roll(identity, SALT_BRIGHTNESS))
				var tint: Color = BiomeRegistry.blended_environment_tint(weights, choice.tint_group)
				var basis: Basis = Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale)
				var qualification: Dictionary = _qualify(set_data, anchor, region, water,
					features, choice, basis,terrain_reservations)
				if qualification.is_empty():
					continue
				out.append({
					"set_id": set_data.id,
					"cell": proposal_cell,
					"slot": slot_index,
					"key_hash": Helper._mix64(identity ^ SALT_ARBITRATION),
					"spacing_group": set_data.spacing_group,
					"spacing_radius": choice.spacing_radius,
					"embed_fraction": set_data.embed_fraction,
					"base_radius": choice.ground_radius * scale,
					"support_points": choice.support_points,
					"visual_height": choice.visual_height,
					"anchor": anchor,
					"asset_id": choice.asset_id,
					"transform": Transform3D(basis,
						Vector3(anchor.x, qualification.y, anchor.y)),
					"color": Color(tint.r * brightness, tint.g * brightness,
						tint.b * brightness, tint.a),
				})
	return out

## Expected population per proposal cell at a point: authored biome fill,
## shaped by the shared land occupancy and the set's habitat layers.
## One member's asset and size: its choice (biome weights, and the stone
## community at `community_at`) and scale, with its base radius.
static func _draft(set_data: Dictionary, identity: int, weights: Dictionary,
		community_at: Vector2, world_seed: int) -> Dictionary:
	var choice_roll := _roll(identity, SALT_CHOICE)
	if set_data.community_hash != 0:
		var community_roll := DressingEcology.community_roll(community_at, world_seed,
			set_data.community_hash, set_data.community_scale)
		choice_roll = lerpf(choice_roll, community_roll, set_data.community_strength)
	var choice: Dictionary = _choose(set_data.choices, weights, choice_roll)
	if choice.is_empty():
		return {}
	var scale: float = choice.scale_multiplier * lerpf(
		set_data.scale_range.x, set_data.scale_range.y, _roll(identity, SALT_SCALE))
	return {"choice": choice, "scale": scale, "radius": float(choice.ground_radius) * scale}

static func _intensity(set_data: Dictionary, point: Vector2, world_seed: int,
		weights: Dictionary) -> float:
	var intensity: float = _biome_dot(set_data.fill_per_cell, weights)
	if set_data.water_mode == DressingSet.WaterMode.LAND:
		intensity *= DressingEcology.land_occupancy01(point, world_seed)
	for layer: Dictionary in set_data.habitat_layers:
		var coverage: float = _biome_dot(layer.coverage, weights)
		var habitat := DressingEcology.habitat01(point, world_seed,
			layer.channel_hash, layer.scale)
		intensity *= DressingEcology.suitability(habitat, coverage,
			layer.preference, layer.softness)
	return intensity

static func _qualify(set_data: Dictionary, anchor: Vector2,
		region: HeightfieldRegion, water: WaterFieldContext,
		features: FeatureContext = null, choice: Dictionary = {},
		basis: Basis = Basis.IDENTITY, terrain_reservations: Array[Rect2] = []) -> Dictionary:
	if features != null:
		var footprint_half: Vector2 = choice.get(
			"feature_footprint_half_extents", Vector2.ZERO)
		if footprint_half.x > 0.0 and footprint_half.y > 0.0:
			var footprint_centre: Vector2 = choice.get(
				"feature_footprint_centre", Vector2.ZERO)
			var centre_offset := basis * Vector3(
				footprint_centre.x, 0.0, footprint_centre.y)
			var x_axis := basis * Vector3.RIGHT
			var scale := Vector2(x_axis.x, x_axis.z).length()
			var angle := atan2(x_axis.z, x_axis.x)
			var footprint := FeatureGroundShape.oriented_rect(
				anchor + Vector2(centre_offset.x, centre_offset.z),
				footprint_half * scale, angle)
			if features.overlaps_clearance(footprint,
					float(set_data.feature_clearance)):
				return {}
		elif features.clearance_at(anchor) < float(set_data.feature_clearance):
			return {}
	var points: Array[Vector2] = [anchor]
	if set_data.surface_mode == DressingSet.SurfaceMode.GROUND_SUPPORT:
		var radius: float = set_data.support_radius
		for direction: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN,
			Vector2(1, 1).normalized(), Vector2(1, -1).normalized(),
			Vector2(-1, 1).normalized(), Vector2(-1, -1).normalized()]:
			points.append(anchor + direction * radius)
	# Supported dressing uses its visible, yawed and scaled near-ground mesh
	# footprint in every set. This is the global overhang guard: an asset cannot
	# balance from its origin while roots, a bush base, rock, or a log cross a drop.
	for local_point: Vector2 in choice.get("support_points", PackedVector2Array()):
		var offset := basis * Vector3(local_point.x, 0.0, local_point.y)
		points.append(anchor + Vector2(offset.x, offset.z))
	# Native terrain additions reserve their complete footprints before ambient
	# placement. Query the supported base, not an unrelated high canopy.
	var base_bounds := Rect2(anchor,Vector2.ZERO)
	for point: Vector2 in points: base_bounds=base_bounds.expand(point)
	for reserved: Rect2 in terrain_reservations:
		if reserved.intersects(base_bounds.grow(.1)): return {}
	for point: Vector2 in points:
		if not water.covers(point) or not _water_ok(set_data, water, point):
			return {}
	if set_data.surface_mode == DressingSet.SurfaceMode.WATER_SURFACE:
		var level: float = water.level_at(anchor)
		return {} if is_nan(level) else {"y": level}
	var heights := PackedFloat32Array()
	for point: Vector2 in points:
		heights.append(TerrainTileField.surface_y(region, point.x, point.y))
	var min_height: float = heights[0]
	var max_height: float = heights[0]
	for height: float in heights:
		min_height = minf(min_height, height)
		max_height = maxf(max_height, height)
	var visual_support: PackedVector2Array = choice.get("support_points",
		PackedVector2Array())
	var has_visual_support: bool = not visual_support.is_empty()
	if set_data.surface_mode == DressingSet.SurfaceMode.GROUND_SUPPORT or has_visual_support:
		if max_height - min_height > set_data.max_support_height_span:
			return {}
		var radius: float = set_data.support_radius
		for point: Vector2 in points:
			radius = maxf(radius, point.distance_to(anchor))
		if radius > 0.0 and (max_height - min_height) / (2.0 * radius) > set_data.max_grade:
			return {}
	else:
		var step: float = DressingCompiler.SURFACE_STENCIL
		var hx: float = TerrainTileField.surface_y(region, anchor.x + step, anchor.y) \
			- TerrainTileField.surface_y(region, anchor.x - step, anchor.y)
		var hz: float = TerrainTileField.surface_y(region, anchor.x, anchor.y + step) \
			- TerrainTileField.surface_y(region, anchor.x, anchor.y - step)
		if Vector2(hx, hz).length() / (2.0 * step) > set_data.max_grade:
			return {}
	var relief_radius: float = set_data.get("relief_radius",0.0)
	if relief_radius > 0.0:
		var rise := 0.0
		for index in 16:
			var point := anchor+Vector2.RIGHT.rotated(index*TAU/16.0)*relief_radius
			rise=maxf(rise,TerrainTileField.surface_y(region,point.x,point.y)-heights[0])
		var relief: Vector2 = set_data.relief_range
		if rise < relief.x or rise > relief.y: return {}
	var embed: float = set_data.get("embed_fraction", 0.0)
	if embed > 0.0:
		# Every point of the visible base outline lies below the ground by a
		# fixed share of the rock's height; the skirt then rises to meet it.
		return {"y": min_height - embed * float(choice.visual_height) * basis.y.length()}
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
