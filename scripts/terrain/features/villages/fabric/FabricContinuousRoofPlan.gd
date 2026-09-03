class_name FabricContinuousRoofPlan
extends RefCounted

## Pure, derived construction plan for collinear modular and compact gables. Individual
## rooms still own their complete bearing and weather-volume facts, but roofs
## whose measured end seams meet on the same ridge are rendered as one run:
## only the two exterior gables survive and every repeat uses one compatible
## material family. This is compiled from sealed recipe/run metadata; the
## renderer never searches nearby meshes or repairs offsets.
const SEAM_EPSILON := 0.002
const PROFILE_EPSILON := 0.002

var suppressed_placement_ids: Dictionary = {}
var asset_overrides: Dictionary = {}
var synthetic_placements: Array[Dictionary] = []
var components: Array[Dictionary] = []
var compiled_runs: Array[Dictionary] = []
var eligible_run_count := 0
var joined_run_count := 0
var internal_gable_count := 0
var normalized_repeat_count := 0
var flush_endpoint_count := 0
var last_rejection := ""
var _valid := false


static func compile(plan: SettlementFabricPlan) -> FabricContinuousRoofPlan:
	var out := FabricContinuousRoofPlan.new()
	out._compile(plan)
	return out


func is_valid() -> bool:
	return _valid


func audit() -> Dictionary:
	return {
		"continuous_roof_eligible_run_count": eligible_run_count,
		"continuous_roof_component_count": components.size(),
		"continuous_roof_joined_run_count": joined_run_count,
		"continuous_roof_internal_gable_count": internal_gable_count,
		"continuous_roof_normalized_repeat_count": normalized_repeat_count,
		"continuous_roof_flush_endpoint_count": flush_endpoint_count,
	}


func apply_to(placements: Array[Dictionary]) -> Array[Dictionary]:
	assert(_valid)
	var out: Array[Dictionary] = []
	for placement: Dictionary in placements:
		var stable_id := StringName(placement.get("stable_id", ""))
		if suppressed_placement_ids.has(stable_id):
			continue
		var realized := placement
		if asset_overrides.has(stable_id):
			realized = placement.duplicate()
			realized["asset_id"] = asset_overrides[stable_id]
		out.append(realized)
	out.append_array(synthetic_placements)
	return out


func _compile(plan: SettlementFabricPlan) -> void:
	last_rejection = ""
	if plan == null:
		last_rejection = "continuous roof compiler has no fabric plan"
		return
	var runs: Array[Dictionary] = []
	for unit: FabricUnit in plan.units:
		var recipe_value := plan.recipe(unit.recipe_id)
		if recipe_value == null:
			last_rejection = "roof unit %s has no recipe" % unit.stable_id
			return
		for run_value: Dictionary in recipe_value.construction_runs:
			if StringName(run_value.get("kind", "")) != &"roof":
				continue
			var compiled := _compile_run(unit, recipe_value, run_value)
			if compiled.is_empty():
				continue
			compiled["index"] = runs.size()
			runs.append(compiled)
		for run_value: Dictionary in recipe_value.compact_roof_runs:
			var compiled := _compile_compact_run(unit, run_value)
			if compiled.is_empty():
				continue
			compiled["index"] = runs.size()
			runs.append(compiled)
	eligible_run_count = runs.size()
	compiled_runs.assign(runs)
	if runs.size() < 2:
		_valid = true
		return

	var endpoint_buckets: Dictionary = {}
	for run: Dictionary in runs:
		for side in [&"start", &"end"]:
			var endpoint := run[side] as Vector3
			var key := _endpoint_key(endpoint, run)
			if not endpoint_buckets.has(key):
				endpoint_buckets[key] = [] as Array[Dictionary]
			(endpoint_buckets[key] as Array[Dictionary]).append({
				"run": int(run.index),
				"side": side,
				"placement_id": StringName(run.get(
					"%s_placement_id" % side, "")),
				"endpoint": endpoint,
			})

	var parents := PackedInt32Array()
	parents.resize(runs.size())
	for index in runs.size():
		parents[index] = index
	var joins: Array[Dictionary] = []
	var bucket_keys: Array = endpoint_buckets.keys()
	bucket_keys.sort()
	for key_value: Variant in bucket_keys:
		var bucket := endpoint_buckets[key_value] as Array[Dictionary]
		if bucket.size() != 2:
			# A lone endpoint is an exterior gable. More than two roofs meeting one
			# ridge point is a junction, not a continuous run, and keeps its authored
			# closures rather than guessing which pair should win.
			continue
		var left := bucket[0]
		var right := bucket[1]
		if int(left.run) == int(right.run) \
				or (left.endpoint as Vector3).distance_to(
					right.endpoint as Vector3) > SEAM_EPSILON:
			continue
		_union(parents, int(left.run), int(right.run))
		joins.append({"left": left, "right": right})

	var members_by_root: Dictionary = {}
	for run_index in runs.size():
		var root := _find(parents, run_index)
		if not members_by_root.has(root):
			members_by_root[root] = [] as Array[int]
		(members_by_root[root] as Array[int]).append(run_index)
	var joins_by_root: Dictionary = {}
	for join: Dictionary in joins:
		var root := _find(parents, int((join.left as Dictionary).run))
		if not joins_by_root.has(root):
			joins_by_root[root] = [] as Array[Dictionary]
		(joins_by_root[root] as Array[Dictionary]).append(join)

	var roots: Array = members_by_root.keys()
	roots.sort()
	for root_value: Variant in roots:
		var member_indices := members_by_root[root_value] as Array[int]
		if member_indices.size() < 2:
			continue
		var component_joins := joins_by_root.get(root_value,
			[] as Array[Dictionary]) as Array[Dictionary]
		if component_joins.size() != member_indices.size() - 1:
			# A continuous run is a chain. Cycles or branches retain their complete
			# roofs so no topology can lose an exterior closure.
			continue
		var component_runs: Array[Dictionary] = []
		for member_index: int in member_indices:
			component_runs.append(runs[member_index])
		component_runs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return _axis_scalar(a.start as Vector3, a) \
				< _axis_scalar(b.start as Vector3, b))
		if not _is_gapless_chain(component_runs):
			continue
		var canonical_material: StringName
		if StringName(component_runs[0].kind) == &"compact_gable":
			canonical_material = _realize_compact_component(component_runs,
				component_joins, components.size())
			if canonical_material.is_empty():
				continue
		else:
			canonical_material = _realize_modular_component(component_runs,
				component_joins)
		joined_run_count += component_runs.size()
		components.append({
			"run_count": component_runs.size(),
			"start": component_runs[0].start,
			"end": component_runs[-1].end,
			"base_y": float(component_runs[0].base_y),
			"peak_y": float(component_runs[0].peak_y),
			"repeat_pitch": float(component_runs[0].repeat_pitch),
			"seam_profile": StringName(component_runs[0].seam_profile),
			"material_asset": canonical_material,
		})
	_valid = true


func _compile_run(unit: FabricUnit, recipe_value: FabricRecipe,
		run_value: Dictionary) -> Dictionary:
	var run_id := StringName(run_value.get("id", ""))
	var start_id := StringName("%s.end.negative" % run_id)
	var end_id := StringName("%s.end.positive" % run_id)
	var placement_by_id: Dictionary = {}
	var placement_index_by_id: Dictionary = {}
	for index in recipe_value.placements.size():
		var placement := recipe_value.placements[index] as Dictionary
		var placement_id := StringName(placement.get("id", ""))
		placement_by_id[placement_id] = placement
		placement_index_by_id[placement_id] = index
	if not placement_by_id.has(start_id) or not placement_by_id.has(end_id) \
			or unit.suppressed_placement_ids.has(start_id) \
			or unit.suppressed_placement_ids.has(end_id):
		return {}
	var unit_transform := unit.transform()
	var start_pose := unit_transform * ((placement_by_id[start_id] \
		as Dictionary).transform as Transform3D)
	var end_pose := unit_transform * ((placement_by_id[end_id] \
		as Dictionary).transform as Transform3D)
	var start := start_pose.origin
	var end := end_pose.origin
	var delta := end - start
	if delta.length() <= SEAM_EPSILON:
		return {}
	var axis_x := absf(delta.x) >= absf(delta.z)
	if axis_x and absf(delta.z) > SEAM_EPSILON \
			or not axis_x and absf(delta.x) > SEAM_EPSILON:
		return {}
	if axis_x and end.x < start.x or not axis_x and end.z < start.z:
		var swap_point := start
		start = end
		end = swap_point
		var swap_id := start_id
		start_id = end_id
		end_id = swap_id
	var repeat_placements: Array[Dictionary] = []
	var repeat_bounds := AABB()
	var has_repeat_bounds := false
	var repeat_assets: Dictionary = {}
	for placement_value: Variant in run_value.get("placement_ids", []) as Array:
		var placement_id := StringName(placement_value)
		if placement_id in [start_id, end_id] \
				or not placement_by_id.has(placement_id) \
				or unit.suppressed_placement_ids.has(placement_id):
			continue
		var placement := placement_by_id[placement_id] as Dictionary
		var asset_id := StringName(placement.asset_id)
		repeat_assets[asset_id] = true
		repeat_placements.append({"placement_id": placement_id,
			"asset_id": asset_id})
		var index := int(placement_index_by_id[placement_id])
		if index < recipe_value.placement_bounds.size():
			var bounds := unit_transform * recipe_value.placement_bounds[index]
			repeat_bounds = bounds if not has_repeat_bounds \
				else repeat_bounds.merge(bounds)
			has_repeat_bounds = true
	if repeat_placements.is_empty() or not has_repeat_bounds:
		return {}
	return {
		"kind": &"modular_gable",
		"unit_id": unit.stable_id,
		"run_id": run_id,
		"start": start,
		"end": end,
		"start_placement_id": start_id,
		"end_placement_id": end_id,
		"axis_x": axis_x,
		"cross_min": repeat_bounds.position.z if axis_x \
			else repeat_bounds.position.x,
		"cross_max": repeat_bounds.end.z if axis_x else repeat_bounds.end.x,
		"base_y": repeat_bounds.position.y,
		"peak_y": repeat_bounds.end.y,
		"repeat_pitch": float(run_value.get("repeat_pitch", 0.0)),
		"seam_profile": StringName(run_value.get("seam_profile", "")),
		"repeat_placements": repeat_placements,
		"uniform_repeat_asset": repeat_assets.keys()[0] \
			if repeat_assets.size() == 1 else &"",
	}


func _compile_compact_run(unit: FabricUnit, run_value: Dictionary) -> Dictionary:
	var unit_transform := unit.transform()
	var local_start := run_value.get("local_start", Vector3.ZERO) as Vector3
	var local_end := run_value.get("local_end", Vector3.ZERO) as Vector3
	var raw_start := unit_transform * local_start
	var raw_end := unit_transform * local_end
	var delta := raw_end - raw_start
	if delta.length() <= SEAM_EPSILON:
		return {}
	var axis_x := absf(delta.x) >= absf(delta.z)
	if axis_x and absf(delta.z) > SEAM_EPSILON \
			or not axis_x and absf(delta.x) > SEAM_EPSILON:
		return {}
	var reversed := axis_x and raw_end.x < raw_start.x \
		or not axis_x and raw_end.z < raw_start.z
	var start := raw_end if reversed else raw_start
	var end := raw_start if reversed else raw_end
	var local_axis_x := absf(local_end.x - local_start.x) > SEAM_EPSILON
	var local_cross_min := float(run_value.get("cross_min", 0.0))
	var local_cross_max := float(run_value.get("cross_max", 0.0))
	var local_cross_a := Vector3(0.0, 0.0, local_cross_min) \
		if local_axis_x else Vector3(local_cross_min, 0.0, 0.0)
	var local_cross_b := Vector3(0.0, 0.0, local_cross_max) \
		if local_axis_x else Vector3(local_cross_max, 0.0, 0.0)
	var cross_a := unit_transform * local_cross_a
	var cross_b := unit_transform * local_cross_b
	var world_cross_min := minf(cross_a.z, cross_b.z) if axis_x \
		else minf(cross_a.x, cross_b.x)
	var world_cross_max := maxf(cross_a.z, cross_b.z) if axis_x \
		else maxf(cross_a.x, cross_b.x)
	var compiled_bays: Array[Dictionary] = []
	var original_ids: Array[StringName] = []
	var profile_base := INF
	var profile_peak := -INF
	for bay_value: Variant in run_value.get("bays", []) as Array:
		var bay := bay_value as Dictionary
		var compiled_families: Dictionary = {}
		for family_value: Variant in (bay.get("variants", {}) as Dictionary).keys():
			var source_roles := (bay.variants as Dictionary)[family_value] \
				as Dictionary
			var compiled_roles: Dictionary = {}
			for world_role: StringName in [&"start", &"start_flush", &"middle",
					&"middle_mirror", &"end", &"end_flush"]:
				var source_role: StringName = world_role
				if reversed and world_role == &"start":
					source_role = &"end"
				elif reversed and world_role == &"end":
					source_role = &"start"
				elif reversed and world_role == &"start_flush":
					source_role = &"end_flush"
				elif reversed and world_role == &"end_flush":
					source_role = &"start_flush"
				var source := source_roles[source_role] as Dictionary
				var bounds := unit_transform * (source.bounds as AABB)
				compiled_roles[world_role] = {
					"asset_id": StringName(source.asset_id),
					"transform": unit_transform * (source.transform as Transform3D),
					"bounds": bounds,
					"collision_pieces": int(source.collision_pieces),
				}
				profile_base = minf(profile_base, bounds.position.y)
				profile_peak = maxf(profile_peak, bounds.end.y)
			compiled_families[family_value] = compiled_roles
		for placement_value: Variant in bay.get("placement_ids", []) as Array:
			var placement_id := StringName(placement_value)
			if unit.suppressed_placement_ids.has(placement_id):
				return {}
			original_ids.append(placement_id)
		compiled_bays.append({
			"centre": unit_transform * (bay.centre as Vector3),
			"variants": compiled_families,
		})
	compiled_bays.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a.centre as Vector3).x < (b.centre as Vector3).x if axis_x \
			else (a.centre as Vector3).z < (b.centre as Vector3).z)
	return {
		"kind": &"compact_gable",
		"unit_id": unit.stable_id,
		"bearing_parent_ids": unit.parent_ids.duplicate(),
		"run_id": StringName(run_value.get("id", "")),
		"start": start,
		"end": end,
		"axis_x": axis_x,
		"cross_min": world_cross_min,
		"cross_max": world_cross_max,
		"base_y": profile_base,
		"peak_y": profile_peak,
		"repeat_pitch": float(run_value.get("repeat_pitch", 0.0)),
		"section_pitch": float(run_value.get("section_pitch",
			float(run_value.get("repeat_pitch", 0.0)) * 0.5)),
		"seam_profile": StringName(run_value.get("seam_profile", "")),
		"authored_material": StringName(run_value.get("material_family", "")),
		"bays": compiled_bays,
		"original_placement_ids": original_ids,
	}


func _realize_modular_component(component_runs: Array[Dictionary],
		component_joins: Array[Dictionary]) -> StringName:
	var canonical_asset := _canonical_repeat_asset(component_runs)
	for join: Dictionary in component_joins:
		for endpoint_key in [&"left", &"right"]:
			var endpoint := join[endpoint_key] as Dictionary
			var run: Dictionary = {}
			for candidate: Dictionary in component_runs:
				if int(candidate.index) == int(endpoint.run):
					run = candidate
					break
			if run.is_empty():
				continue
			var stable_id := StringName("%s/%s" % [run.unit_id,
				StringName(endpoint.placement_id)])
			suppressed_placement_ids[stable_id] = true
			internal_gable_count += 1
	if not canonical_asset.is_empty():
		for run: Dictionary in component_runs:
			for repeat_value: Variant in run.repeat_placements as Array:
				var repeat := repeat_value as Dictionary
				if StringName(repeat.asset_id) == canonical_asset:
					continue
				var stable_id := StringName("%s/%s" % [run.unit_id,
					StringName(repeat.placement_id)])
				asset_overrides[stable_id] = canonical_asset
				normalized_repeat_count += 1
	return canonical_asset


func _realize_compact_component(component_runs: Array[Dictionary],
		component_joins: Array[Dictionary], component_index: int) -> StringName:
	var length_by_family: Dictionary = {}
	var common_families: Dictionary = {}
	var first := true
	var bays: Array[Dictionary] = []
	var component_unit_ids: Array[StringName] = []
	var component_bearing_ids: Array[StringName] = []
	for run: Dictionary in component_runs:
		var component_unit_id := StringName(run.unit_id)
		if not component_unit_ids.has(component_unit_id):
			component_unit_ids.append(component_unit_id)
		for parent_id: StringName in run.get(
				"bearing_parent_ids", []) as Array[StringName]:
			if not component_bearing_ids.has(parent_id):
				component_bearing_ids.append(parent_id)
		var run_bays := run.bays as Array
		if run_bays.is_empty():
			return &""
		var available := ((run_bays[0] as Dictionary).variants \
			as Dictionary).keys()
		if first:
			for family_value: Variant in available:
				common_families[family_value] = true
			first = false
		else:
			for family_value: Variant in common_families.keys():
				if not available.has(family_value):
					common_families.erase(family_value)
		var authored := StringName(run.authored_material)
		var length := _axis_scalar(run.end as Vector3, run) \
			- _axis_scalar(run.start as Vector3, run)
		length_by_family[authored] = float(length_by_family.get(authored, 0.0)) \
			+ length
		bays.append_array(run_bays)
	if common_families.is_empty():
		return &""
	var families: Array = common_families.keys()
	families.sort_custom(func(a: Variant, b: Variant) -> bool:
		var left := float(length_by_family.get(a, 0.0))
		var right := float(length_by_family.get(b, 0.0))
		return left > right if not is_equal_approx(left, right) \
			else String(a) < String(b))
	var canonical := StringName(families[0])
	bays.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a.centre as Vector3).x < (b.centre as Vector3).x \
			if bool(component_runs[0].axis_x) \
			else (a.centre as Vector3).z < (b.centre as Vector3).z)
	for run: Dictionary in component_runs:
		for placement_id: StringName in run.original_placement_ids as Array[StringName]:
			suppressed_placement_ids[StringName("%s/%s" % [run.unit_id,
				placement_id])] = true
		if StringName(run.authored_material) != canonical:
			normalized_repeat_count += (run.bays as Array).size()
	internal_gable_count += component_joins.size() * 2
	# The source compact roof bows upward toward both authored gable ends. Cutting
	# one three-metre piece from it and translating that whole piece by three
	# metres therefore joins two *different* cross-sections and opens a visible
	# notch even though their AABBs touch. Construction instead repeats the
	# symmetric central 1.5 m profile: the negative and positive cut planes are
	# mirror-equivalent. Separate exterior strips keep the source roof's complete
	# measured eaves. This produces one continuous crown from compatible section
	# boundaries rather than covering a bad seam with trim or an overlap.
	var axis := Vector3.RIGHT if bool(component_runs[0].axis_x) \
		else Vector3.BACK
	var section_pitch := float(component_runs[0].section_pitch)
	var component_start := component_runs[0].start as Vector3
	var component_end := component_runs[-1].end as Vector3
	var desired_first_scalar := _axis_scalar(component_start,
		component_runs[0]) + section_pitch
	var desired_last_scalar := _axis_scalar(component_end,
		component_runs[0]) - section_pitch
	if desired_last_scalar + PROFILE_EPSILON < desired_first_scalar:
		return &""
	var first_bay := bays[0] as Dictionary
	var last_bay := bays[-1] as Dictionary
	var first_centre := first_bay.centre as Vector3
	var last_centre := last_bay.centre as Vector3
	var first_shift := axis * (desired_first_scalar \
		- _axis_scalar(first_centre, component_runs[0]))
	var last_shift := axis * (desired_last_scalar \
		- _axis_scalar(last_centre, component_runs[0]))
	var centre_distance := desired_last_scalar - desired_first_scalar
	var middle_count := roundi(centre_distance / section_pitch) + 1
	if middle_count < 1 \
			or absf(centre_distance - float(middle_count - 1) * section_pitch) \
			> PROFILE_EPSILON:
		return &""
	var sections: Array[Dictionary] = [{
		"variant": (((first_bay.variants as Dictionary)[canonical] \
			as Dictionary)[&"start"]) as Dictionary,
		"flush_variant": (((first_bay.variants as Dictionary)[canonical] \
			as Dictionary)[&"start_flush"]) as Dictionary,
		"offset": first_shift,
	}]
	var middle_variant := (((first_bay.variants as Dictionary)[canonical] \
		as Dictionary)[&"middle"]) as Dictionary
	var mirrored_middle_variant := (((first_bay.variants as Dictionary)[canonical] \
		as Dictionary)[&"middle_mirror"]) as Dictionary
	for middle_index in middle_count:
		sections.append({
			# Adjacent source cross-sections are identical only after alternating
			# the properly baked Z reflection. Runtime transforms remain proper;
			# winding, normals, tangents, and collision were corrected by the bake.
			"variant": middle_variant if middle_index % 2 == 0 \
				else mirrored_middle_variant,
			"offset": first_shift + axis * section_pitch * float(middle_index),
		})
	sections.append({
		"variant": (((last_bay.variants as Dictionary)[canonical] \
			as Dictionary)[&"end"]) as Dictionary,
		"flush_variant": (((last_bay.variants as Dictionary)[canonical] \
			as Dictionary)[&"end_flush"]) as Dictionary,
		"offset": last_shift,
	})
	for section_index in sections.size():
		var section := sections[section_index] as Dictionary
		var variant := section.variant as Dictionary
		var offset := section.offset as Vector3
		# Transform3D and AABB are value types. Reconstruct them explicitly so
		# the validation envelope and committed transform receive the identical
		# section translation.
		var source_transform := variant.transform as Transform3D
		var section_transform := Transform3D(source_transform.basis,
			source_transform.origin + offset)
		var source_bounds := variant.bounds as AABB
		var section_bounds := AABB(source_bounds.position + offset,
			source_bounds.size)
		var stable_id := StringName("%s/continuous-roof/%03d/%03d" % [
			StringName(component_runs[0].unit_id), component_index,
			section_index])
		var synthetic := {
			"stable_id": stable_id,
			"placement_id": stable_id,
			"asset_id": StringName(variant.asset_id),
			"transform": section_transform,
			"bounds": section_bounds,
			"collision_pieces": int(variant.collision_pieces),
			"roof_component_unit_ids": component_unit_ids.duplicate(),
			"roof_component_bearing_ids": component_bearing_ids.duplicate(),
		}
		if section.has("flush_variant"):
			var flush_variant := section.flush_variant as Dictionary
			var flush_source_transform := flush_variant.transform as Transform3D
			var flush_source_bounds := flush_variant.bounds as AABB
			synthetic["flush_alternative"] = {
				"asset_id": StringName(flush_variant.asset_id),
				"transform": Transform3D(flush_source_transform.basis,
					flush_source_transform.origin + offset),
				"bounds": AABB(flush_source_bounds.position + offset,
					flush_source_bounds.size),
				"collision_pieces": int(flush_variant.collision_pieces),
			}
		synthetic_placements.append(synthetic)
	return canonical


func select_flush_alternative(synthetic: Dictionary) -> bool:
	## Exterior gable overhangs remain the preferred construction. At a measured
	## perpendicular junction the plan may instead select the baked endpoint whose
	## ridge span ends at the semantic building plane. Because its bounds are a
	## strict subset of the preferred endpoint, this choice can remove but never
	## create an intersection.
	var alternative := synthetic.get("flush_alternative", {}) as Dictionary
	var current_bounds := synthetic.get("bounds", AABB()) as AABB
	var alternative_bounds := alternative.get("bounds", AABB()) as AABB
	if alternative.is_empty() or not alternative_bounds.has_volume() \
			or not current_bounds.grow(PROFILE_EPSILON).encloses(
				alternative_bounds):
		return false
	for key: String in ["asset_id", "transform", "bounds", "collision_pieces"]:
		synthetic[key] = alternative[key]
	synthetic.erase("flush_alternative")
	flush_endpoint_count += 1
	return true


static func _endpoint_key(endpoint: Vector3, run: Dictionary) -> String:
	return "%s:%s:%d:%d:%d:%d:%d:%d:%d:%s" % [
		StringName(run.kind),
		"x" if bool(run.axis_x) else "z",
		roundi(endpoint.x / SEAM_EPSILON),
		roundi(endpoint.y / SEAM_EPSILON),
		roundi(endpoint.z / SEAM_EPSILON),
		roundi(float(run.cross_min) / PROFILE_EPSILON),
		roundi(float(run.cross_max) / PROFILE_EPSILON),
		roundi(float(run.base_y) / PROFILE_EPSILON),
		roundi(float(run.peak_y) / PROFILE_EPSILON),
		StringName(run.seam_profile),
	]


static func _axis_scalar(point: Vector3, run: Dictionary) -> float:
	return point.x if bool(run.axis_x) else point.z


static func _is_gapless_chain(runs: Array[Dictionary]) -> bool:
	if runs.size() < 2:
		return false
	var pitch := float(runs[0].repeat_pitch)
	var section_pitch := float(runs[0].get("section_pitch", pitch * 0.5))
	for index in runs.size():
		var run := runs[index]
		if StringName(run.kind) != StringName(runs[0].kind) \
				or absf(float(run.repeat_pitch) - pitch) > PROFILE_EPSILON \
				or absf(float(run.get("section_pitch", pitch * 0.5)) \
					- section_pitch) > PROFILE_EPSILON:
			return false
		var length := _axis_scalar(run.end as Vector3, run) \
			- _axis_scalar(run.start as Vector3, run)
		if absf(roundf(length / pitch) * pitch - length) > SEAM_EPSILON:
			return false
		if index > 0:
			var prior := runs[index - 1]
			if absf(_axis_scalar(prior.end as Vector3, prior) \
					- _axis_scalar(run.start as Vector3, run)) > SEAM_EPSILON:
				return false
	return true


static func _canonical_repeat_asset(runs: Array[Dictionary]) -> StringName:
	var length_by_asset: Dictionary = {}
	for run: Dictionary in runs:
		var asset_id := StringName(run.uniform_repeat_asset)
		if asset_id.is_empty():
			return &""
		var length := _axis_scalar(run.end as Vector3, run) \
			- _axis_scalar(run.start as Vector3, run)
		length_by_asset[asset_id] = float(length_by_asset.get(asset_id, 0.0)) \
			+ length
	var assets: Array = length_by_asset.keys()
	assets.sort_custom(func(a: Variant, b: Variant) -> bool:
		var left := float(length_by_asset[a])
		var right := float(length_by_asset[b])
		return left > right if not is_equal_approx(left, right) \
			else String(a) < String(b))
	return StringName(assets[0]) if not assets.is_empty() else &""


static func _find(parents: PackedInt32Array, value: int) -> int:
	var root := value
	while parents[root] != root:
		root = parents[root]
	var cursor := value
	while parents[cursor] != cursor:
		var next := parents[cursor]
		parents[cursor] = root
		cursor = next
	return root


static func _union(parents: PackedInt32Array, left: int, right: int) -> void:
	var left_root := _find(parents, left)
	var right_root := _find(parents, right)
	if left_root == right_root:
		return
	parents[maxi(left_root, right_root)] = mini(left_root, right_root)
