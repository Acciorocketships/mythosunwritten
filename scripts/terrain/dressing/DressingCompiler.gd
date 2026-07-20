class_name DressingCompiler
extends RefCounted

const PROPOSAL_CELL := 24.0
const PROPOSAL_HALF := PROPOSAL_CELL * 0.5
const SURFACE_STENCIL := 1.0
const LOCAL_SPACING_CAP := 12.0

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
	for set_resource: DressingSet in authored:
		var compiled := _compile_set(set_resource, environment_catalog)
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
		program.shore_distance_limit = maxf(program.shore_distance_limit,
			compiled.shore_limit)
		for choice: Dictionary in compiled.choices:
			referenced[choice.asset_id] = true
	for compiled: Dictionary in program.sets:
		compiled["group_radius"] = float(group_radius[compiled.spacing_group])
		program.query_margin = maxf(program.query_margin,
			PROPOSAL_HALF + compiled.group_radius + compiled.support_radius + SURFACE_STENCIL)
	var water_context_margin := WaterField.FILL_MARGIN * WaterField.FILL_STEP \
		- WaterContour.MARGIN
	if program.query_margin + program.shore_distance_limit > water_context_margin:
		return _fail("Dressing query, spacing, and shore margins exceed the canonical water field window")
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
		environment_catalog: EnvironmentCatalog) -> Dictionary:
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
			or source.spacing_radius > LOCAL_SPACING_CAP:
		_fail("Dressing set %s has invalid grade or local spacing" % set_id)
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
		choices.append({
			"asset_id": choice_resource.asset_id,
			"weight": choice_resource.weight,
			"affinity": choice_affinity,
			"tint_group": descriptor.tint_group,
			"scale_multiplier": choice_resource.scale_multiplier,
			"spacing_radius": choice_spacing,
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
		"max_support_height_span": source.max_support_height_span,
		"max_grade": source.max_grade,
		"spacing_group": resolved_group,
		"spacing_radius": compiled_spacing_radius,
		"scale_range": source.scale_range,
		"brightness_range": source.brightness_range,
		"slot_count": slot_count,
	}

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
