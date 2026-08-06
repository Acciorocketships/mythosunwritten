class_name DressingCompiler
extends RefCounted

const PROPOSAL_CELL := 24.0
const PROPOSAL_HALF := PROPOSAL_CELL * 0.5
const SURFACE_STENCIL := 1.0
const LOCAL_SPACING_CAP := 12.0
const AUTO_SUPPORT_HEIGHT_SPAN := 0.65
const GROUND_BAND_MIN := 0.35
const GROUND_BAND_MAX := 1.0
const GROUND_BAND_HEIGHT_FRACTION := 0.12
const SUPPORT_DIRECTION_COUNT := 16

static func compile(index: DressingCatalogIndex,
		environment_catalog: EnvironmentCatalog) -> DressingProgram:
	if index == null or environment_catalog == null:
		return _fail("Dressing compilation requires both indexes")
	var authored: Array[DressingSet] = index.sets.duplicate()
	authored.sort_custom(func(a: DressingSet, b: DressingSet) -> bool:
		return String(a.id) < String(b.id))
	var program := DressingProgram.new()
	var seen: Dictionary = {}
	var referenced: Dictionary = {}
	var group_radius: Dictionary = {}
	var support_cache: Dictionary = {}
	for set_resource: DressingSet in authored:
		var compiled := _compile_set(set_resource, environment_catalog, support_cache)
		if compiled.is_empty():
			return null
		if seen.has(compiled.id):
			return _fail("Duplicate dressing set ID: %s" % String(compiled.id))
		seen[compiled.id] = true
		program.sets.append(compiled)
		group_radius[compiled.spacing_group] = maxf(
			float(group_radius.get(compiled.spacing_group, 0.0)), compiled.spacing_radius)
		program.maximum_spacing_radius = maxf(program.maximum_spacing_radius,
			compiled.spacing_radius)
		program.maximum_feature_clearance = maxf(program.maximum_feature_clearance,
			compiled.feature_clearance)
		program.shore_distance_limit = maxf(program.shore_distance_limit,
			compiled.shore_limit)
		for choice: Dictionary in compiled.choices:
			referenced[choice.asset_id] = true
			program.ground_radius_by_asset[choice.asset_id] = maxf(
				float(program.ground_radius_by_asset.get(choice.asset_id, 0.0)),
				choice.ground_radius)
			if not choice.support_points.is_empty():
				# _ground_support_points is cached per asset, so repeated choices
				# share one deterministic resource-free outline.
				program.ground_stencil_by_asset[choice.asset_id] = choice.support_points
	for compiled: Dictionary in program.sets:
		compiled["group_radius"] = float(group_radius[compiled.spacing_group])
		# _eligible_for_set rejects every jittered anchor outside core grown by
		# group_radius. The proposal cell is only an enumeration device, so its
		# 12 m half-size is not part of the field sampling footprint. Coverage
		# needs two explicit reaches: near-ground support samples terrain/water;
		# full visual bounds query only authored reservations and may be wider
		# than water's deliberately finite canonical context.
		program.query_margin = maxf(program.query_margin,
			compiled.group_radius + compiled.query_support_radius \
				+ SURFACE_STENCIL)
		program.feature_query_margin = maxf(program.feature_query_margin,
			compiled.group_radius + compiled.query_feature_radius)
	var water_context_margin := WaterField.FILL_MARGIN * WaterField.FILL_STEP \
		- WaterContour.MARGIN
	if program.query_margin + program.shore_distance_limit > water_context_margin:
		return _fail("Dressing query %.2f plus shore %.2f exceeds canonical water margin %.2f" % [
			program.query_margin, program.shore_distance_limit, water_context_margin])
	# Proposal cost is a program-level estimate, so derive every set from the
	# final common margin rather than whichever partial maximum happened to be
	# visible while compiling that set.
	for compiled: Dictionary in program.sets:
		var cells_across := 8 + 2 * int(ceil(program.query_margin / PROPOSAL_CELL))
		program.estimated_proposals_per_chunk += cells_across * cells_across * compiled.slot_count
	program.referenced_asset_ids.assign(referenced.keys())
	program.referenced_asset_ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	return program

static func _compile_set(source: DressingSet,
		environment_catalog: EnvironmentCatalog,
		support_cache: Dictionary = {}) -> Dictionary:
	if source == null:
		_fail("Active dressing index contains a null set")
		return {}
	var set_id := String(source.id)
	if set_id.is_empty() or source.seed_version < 1:
		_fail("Dressing set requires a non-empty ID and seed_version >= 1")
		return {}
	if not _ordered_finite(source.scale_range) or source.scale_range.x <= 0.0:
		_fail("Dressing set %s scale range must be ordered and strictly positive" % set_id)
		return {}
	if not _ordered_finite(source.brightness_range) or source.brightness_range.x < 0.0:
		_fail("Dressing set %s brightness range must be ordered and non-negative" % set_id)
		return {}
	if not _ordered_finite(source.depth_range) or not _ordered_finite(source.shore_distance_range):
		_fail("Dressing set %s has a non-finite or reversed field range" % set_id)
		return {}
	if not is_finite(source.max_grade) or source.max_grade < 0.0 \
			or not is_finite(source.spacing_radius) or source.spacing_radius < 0.0 \
			or not is_finite(source.feature_clearance) or source.feature_clearance < 0.0 \
			or source.spacing_radius > LOCAL_SPACING_CAP:
		_fail("Dressing set %s has invalid grade, clearance, or local spacing" % set_id)
		return {}
	if source.surface_mode == DressingSet.SurfaceMode.GROUND_SUPPORT:
		if not is_finite(source.support_radius) or source.support_radius <= 0.0 \
				or not is_finite(source.max_support_height_span) \
				or source.max_support_height_span < 0.0:
			_fail("GROUND_SUPPORT set %s requires finite positive support" % set_id)
			return {}
	elif source.support_radius != 0.0:
		_fail("Non-support set %s must not hide behaviour in support_radius" % set_id)
		return {}
	if source.surface_mode == DressingSet.SurfaceMode.WATER_SURFACE \
			and source.water_mode != DressingSet.WaterMode.FLOATING:
		_fail("WATER_SURFACE set %s must use FLOATING" % set_id)
		return {}
	if source.water_mode == DressingSet.WaterMode.FLOATING \
			and source.surface_mode != DressingSet.SurfaceMode.WATER_SURFACE:
		_fail("FLOATING set %s must use WATER_SURFACE" % set_id)
		return {}
	if source.water_mode in [DressingSet.WaterMode.SHALLOW, DressingSet.WaterMode.EMERGENT] \
			and source.surface_mode == DressingSet.SurfaceMode.WATER_SURFACE:
		_fail("Ground-rooted wet set %s cannot use WATER_SURFACE" % set_id)
		return {}
	var biome_ids := BiomeRegistry.biome_ids()
	var fill := _affinity_array(source.fill_per_cell, biome_ids, "set %s fill" % set_id)
	if fill.is_empty() or _maximum(fill) <= 0.0:
		return {}
	var habitat_layers: Array[Dictionary] = []
	for layer: DressingHabitatLayer in source.habitat_layers:
		if layer == null or layer.channel.is_empty() or not is_finite(layer.scale) \
				or layer.scale <= 0.0 or not is_finite(layer.edge_softness) \
				or layer.edge_softness <= 0.0 or layer.edge_softness >= 0.5:
			_fail("Dressing set %s has an invalid habitat layer" % set_id)
			return {}
		var coverage := _affinity_array(layer.coverage, biome_ids,
			"set %s habitat %s coverage" % [set_id, layer.channel])
		if coverage.is_empty() or _maximum(coverage) > 1.0:
			_fail("Dressing set %s habitat coverage must stay in [0,1]" % set_id)
			return {}
		habitat_layers.append({
			"channel_hash": stable_id_hash(layer.channel),
			"scale": layer.scale,
			"preference": layer.preference,
			"coverage": coverage,
			"softness": layer.edge_softness,
		})
	var has_community := not source.community_channel.is_empty()
	if has_community != (source.community_scale > 0.0) \
			or not is_finite(source.community_scale) \
			or not is_finite(source.community_strength) \
			or source.community_strength < 0.0 or source.community_strength > 1.0:
		_fail("Dressing set %s community channel and positive scale must be authored together" % set_id)
		return {}
	var choices: Array[Dictionary] = []
	var compiled_spacing_radius := source.spacing_radius
	var query_support_radius := source.support_radius
	var query_feature_radius := 0.0
	var authored_choices: Array[DressingChoice] = source.choices.duplicate()
	authored_choices.sort_custom(func(a: DressingChoice, b: DressingChoice) -> bool:
		return String(a.asset_id) < String(b.asset_id))
	for choice_resource: DressingChoice in authored_choices:
		if choice_resource == null or choice_resource.asset_id.is_empty() \
				or not is_finite(choice_resource.weight) or choice_resource.weight < 0.0 \
				or not is_finite(choice_resource.scale_multiplier) \
				or choice_resource.scale_multiplier <= 0.0 \
				or not is_finite(choice_resource.spacing_radius) \
				or choice_resource.spacing_radius < 0.0 \
				or choice_resource.spacing_radius > LOCAL_SPACING_CAP:
			_fail("Dressing set %s has an invalid choice" % set_id)
			return {}
		var descriptor := environment_catalog.descriptor(choice_resource.asset_id)
		if descriptor == null:
			_fail("Dressing set %s references unknown asset %s" % [set_id, choice_resource.asset_id])
			return {}
		if not descriptor.supports_instance_color:
			_fail("Dressing asset %s is not instance-colour compatible" % choice_resource.asset_id)
			return {}
		var choice_affinity := _affinity_array(choice_resource.biome_affinity, biome_ids,
			"choice %s" % String(choice_resource.asset_id))
		if choice_affinity.is_empty():
			return {}
		var choice_spacing := maxf(source.spacing_radius, choice_resource.spacing_radius)
		compiled_spacing_radius = maxf(compiled_spacing_radius, choice_spacing)
		var support_points := _ground_support_points(descriptor, support_cache)
		var ground_radius := _maximum_radius(support_points)
		var feature_centre := Vector2(
			descriptor.measured_aabb.get_center().x,
			descriptor.measured_aabb.get_center().z)
		var feature_half_extents := Vector2(
			descriptor.measured_aabb.size.x,
			descriptor.measured_aabb.size.z) * 0.5
		if not feature_centre.is_finite() or not feature_half_extents.is_finite() \
				or feature_half_extents.x <= 0.0 or feature_half_extents.y <= 0.0:
			_fail("Dressing asset %s requires finite non-empty visual bounds" \
				% choice_resource.asset_id)
			return {}
		var maximum_scale := choice_resource.scale_multiplier * source.scale_range.y
		query_support_radius = maxf(query_support_radius,
			ground_radius * maximum_scale)
		query_feature_radius = maxf(query_feature_radius,
			(feature_centre.length() + feature_half_extents.length()) \
				* maximum_scale)
		choices.append({
			"asset_id": choice_resource.asset_id,
			"weight": choice_resource.weight,
			"affinity": choice_affinity,
			"tint_group": descriptor.tint_group,
			"scale_multiplier": choice_resource.scale_multiplier,
			"spacing_radius": choice_spacing,
			"support_points": support_points,
			"ground_radius": ground_radius,
			# The full visual XZ AABB becomes an oriented rectangle after the
			# runtime yaw. It is deliberately distinct from support_points:
			# crowns may overhang natural cliffs, but never authored space.
			"feature_footprint_centre": feature_centre,
			"feature_footprint_half_extents": feature_half_extents,
		})
	if choices.is_empty():
		_fail("Dressing set %s has no choices" % set_id)
		return {}
	for biome_index in biome_ids.size():
		if fill[biome_index] <= 0.0:
			continue
		var available := false
		for choice: Dictionary in choices:
			if choice.weight * choice.affinity[biome_index] > 0.0:
				available = true
				break
		if not available:
			_fail("Dressing set %s enables %s without an eligible choice" % [set_id, biome_ids[biome_index]])
			return {}
	var slot_count := maxi(1, int(ceil(_maximum(fill))))
	var resolved_group := source.spacing_group if not source.spacing_group.is_empty() else source.id
	var shore_limit := maxf(absf(source.shore_distance_range.x), absf(source.shore_distance_range.y))
	return {
		"id": source.id,
		"id_hash": stable_id_hash(source.id),
		"seed_version": source.seed_version,
		"choices": choices,
		"fill_per_cell": fill,
		"habitat_layers": habitat_layers,
		"community_hash": stable_id_hash(source.community_channel) if has_community else 0,
		"community_scale": source.community_scale,
		"community_strength": source.community_strength,
		"surface_mode": source.surface_mode,
		"water_mode": source.water_mode,
		"depth_range": source.depth_range,
		"shore_range": source.shore_distance_range,
		"shore_limit": shore_limit,
		"support_radius": source.support_radius,
		"query_support_radius": query_support_radius,
		"query_feature_radius": query_feature_radius,
		"max_support_height_span": source.max_support_height_span \
			if source.surface_mode == DressingSet.SurfaceMode.GROUND_SUPPORT \
			else AUTO_SUPPORT_HEIGHT_SPAN,
		"max_grade": source.max_grade,
		"feature_clearance": source.feature_clearance,
		"spacing_group": resolved_group,
		"spacing_radius": compiled_spacing_radius,
		"scale_range": source.scale_range,
		"brightness_range": source.brightness_range,
		"slot_count": slot_count,
	}

## Compile-time only: reduce each collidable visual to the radial extrema of
## its actual near-ground vertices. Trees therefore include authored roots,
## rocks include their visible base, and the worker receives only Vector2 data.
## Foliage high above the ground cannot inflate this footprint.
static func _ground_support_points(descriptor: EnvironmentAssetDescriptor,
		cache: Dictionary) -> PackedVector2Array:
	if descriptor.collision_piece_count <= 0:
		return PackedVector2Array()
	if cache.has(descriptor.id):
		return cache[descriptor.id]
	assert(OS.get_thread_caller_id() == OS.get_main_thread_id(),
		"Dressing support stencils must be compiled while visuals are main-thread resources")
	var visual := load(descriptor.visual_path) as EnvironmentVisual
	if visual == null:
		_fail("Dressing asset %s has no readable visual" % descriptor.id)
		return PackedVector2Array()
	var vertices: Array[Vector3] = []
	var minimum_y := INF
	var maximum_y := -INF
	for piece: EnvironmentVisualPiece in visual.pieces:
		if piece == null or piece.mesh == null:
			continue
		for surface_index in piece.mesh.get_surface_count():
			var arrays := piece.mesh.surface_get_arrays(surface_index)
			var vertex_value: Variant = arrays[Mesh.ARRAY_VERTEX]
			if not vertex_value is PackedVector3Array:
				continue
			for vertex: Vector3 in vertex_value:
				var transformed := piece.local_transform * vertex
				vertices.append(transformed)
				minimum_y = minf(minimum_y, transformed.y)
				maximum_y = maxf(maximum_y, transformed.y)
	if vertices.is_empty():
		_fail("Dressing asset %s has no visual vertices" % descriptor.id)
		return PackedVector2Array()
	var band_height := clampf((maximum_y - minimum_y) * GROUND_BAND_HEIGHT_FRACTION,
		GROUND_BAND_MIN, GROUND_BAND_MAX)
	var band_top := minimum_y + band_height
	var out := PackedVector2Array()
	for direction_index in SUPPORT_DIRECTION_COUNT:
		var angle := TAU * float(direction_index) / float(SUPPORT_DIRECTION_COUNT)
		var direction := Vector2(cos(angle), sin(angle))
		var best := Vector2.ZERO
		var best_projection := -INF
		for vertex: Vector3 in vertices:
			if vertex.y > band_top:
				continue
			var point := Vector2(vertex.x, vertex.z)
			var projection := point.dot(direction)
			if projection > best_projection:
				best_projection = projection
				best = point
		if best_projection > -INF:
			var duplicate := false
			for existing: Vector2 in out:
				if existing.is_equal_approx(best):
					duplicate = true
					break
			if not duplicate:
				out.append(best)
	cache[descriptor.id] = out
	return out

static func _maximum_radius(points: PackedVector2Array) -> float:
	var result := 0.0
	for point: Vector2 in points:
		result = maxf(result, point.length())
	return result

static func stable_id_hash(value: StringName) -> int:
	var hash_value: int = -3750763034362895579 # FNV-1a 64-bit offset, signed
	for byte: int in String(value).to_utf8_buffer():
		hash_value = (hash_value ^ byte) * 1099511628211
	return hash_value

static func _affinity_array(source: Dictionary, ids: Array[StringName], label: String) -> PackedFloat32Array:
	if source.size() != ids.size():
		_fail("%s affinity must contain exactly the canonical biome IDs" % label)
		return PackedFloat32Array()
	var out := PackedFloat32Array()
	for biome_id: StringName in ids:
		var key: Variant = biome_id if source.has(biome_id) else String(biome_id)
		if not source.has(key):
			_fail("%s affinity is missing biome %s" % [label, biome_id])
			return PackedFloat32Array()
		var amount := float(source[key])
		if not is_finite(amount) or amount < 0.0:
			_fail("%s affinity for %s must be finite and non-negative" % [label, biome_id])
			return PackedFloat32Array()
		out.append(amount)
	return out

static func _maximum(values: PackedFloat32Array) -> float:
	var result := 0.0
	for value: float in values:
		result = maxf(result, value)
	return result

static func _ordered_finite(value: Vector2) -> bool:
	return value.is_finite() and value.x <= value.y

static func _fail(message: String):
	push_error(message)
	return null
