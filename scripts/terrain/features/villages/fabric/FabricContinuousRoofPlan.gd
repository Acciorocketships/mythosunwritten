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
var tight_cross_component_count := 0
## Perpendicular same-datum junctions whose branch crown continues to the host
## ridge, and material families normalized across a joined roof group.
var junction_extension_count := 0
var junction_group_recolor_count := 0
var turned_square_count := 0
var modular_continuation_count := 0
var last_rejection := ""
var _valid := false
var _junctions := true


static func compile(plan: SettlementFabricPlan,
		junctions: bool = true) -> FabricContinuousRoofPlan:
	## `junctions` false compiles collinear continuity only. Authored valley-pair
	## admission compares that exact continuity before and after its own finite
	## junction; the generic perpendicular continuation applies to the result.
	var out := FabricContinuousRoofPlan.new()
	out._junctions = junctions
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
		"continuous_roof_tight_cross_component_count": tight_cross_component_count,
		"continuous_roof_junction_extension_count": junction_extension_count,
		"continuous_roof_junction_group_recolor_count": junction_group_recolor_count,
		"continuous_roof_turned_square_count": turned_square_count,
		"continuous_roof_modular_continuation_count": modular_continuation_count,
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
			compiled["bounded_ends"] = recipe_value.has_tag(&"partial_gable")
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
	# Maximal collinear chains. A lone run is a chain of one; it keeps its
	# complete authored roof unless a junction or group material requires the
	# chain to be realized from sections.
	var chains: Array[Dictionary] = []
	for root_value: Variant in roots:
		var member_indices := members_by_root[root_value] as Array[int]
		var component_joins := joins_by_root.get(root_value,
			[] as Array[Dictionary]) as Array[Dictionary]
		var component_runs: Array[Dictionary] = []
		for member_index: int in member_indices:
			component_runs.append(runs[member_index])
		if member_indices.size() >= 2:
			if component_joins.size() != member_indices.size() - 1:
				# A continuous run is a chain. Cycles or branches retain their complete
				# roofs so no topology can lose an exterior closure.
				continue
			component_runs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return _axis_scalar(a.start as Vector3, a) \
					< _axis_scalar(b.start as Vector3, b))
			if not _is_gapless_chain(component_runs):
				continue
		chains.append({"runs": component_runs, "joins": component_joins,
			"start_extension": 0.0, "end_extension": 0.0,
			"partners": {} as Dictionary})
	if _junctions:
		_continue_modular_over_compact(chains, plan)
		_turn_square_leaves(chains, plan)
		_link_perpendicular_junctions(chains, plan)
		for chain: Dictionary in chains:
			for extra: Dictionary in chain.get("turned_extras", []) as Array:
				extra["roof_junction_unit_ids"] = _partner_ids(chain.partners as Dictionary)
	var group_family := _junction_group_families(chains)
	for chain_index in chains.size():
		var chain := chains[chain_index] as Dictionary
		var component_runs := chain.runs as Array[Dictionary]
		var component_joins := chain.joins as Array[Dictionary]
		var extended := float(chain.start_extension) > 0.0 \
			or float(chain.end_extension) > 0.0 or bool(chain.get("turned", false))
		var family := StringName(group_family.get(chain_index, &""))
		var recolor := StringName(component_runs[0].kind) == &"compact_gable" \
			and not family.is_empty() \
			and StringName(component_runs[0].authored_material) != family
		if component_runs.size() < 2 and not extended and not recolor:
			continue
		var canonical_material: StringName
		if StringName(component_runs[0].kind) == &"compact_gable":
			canonical_material = _realize_compact_component(component_runs,
				component_joins, components.size(), plan, chain, family)
			if canonical_material.is_empty():
				continue
		else:
			canonical_material = _realize_modular_component(component_runs,
				component_joins)
		if extended:
			junction_extension_count += int(float(chain.start_extension) > 0.0) \
				+ int(float(chain.end_extension) > 0.0)
		if recolor and component_runs.size() < 2 and not extended:
			junction_group_recolor_count += 1
		joined_run_count += component_runs.size() if component_runs.size() > 1 else 0
		components.append({
			"run_count": component_runs.size(),
			"start": component_runs[0].start,
			"end": component_runs[-1].end,
			"base_y": float(component_runs[0].base_y),
			"peak_y": float(component_runs[0].peak_y),
			"repeat_pitch": float(component_runs[0].repeat_pitch),
			"seam_profile": StringName(component_runs[0].seam_profile),
			"material_asset": canonical_material,
			"start_extension": float(chain.start_extension),
			"end_extension": float(chain.end_extension),
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
		"valley": _compile_valley(unit_transform,run_value),
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


static func _compile_valley(pose: Transform3D, run: Dictionary) -> Dictionary:
	if not run.has("valley"): return {}
	var source := run.valley as Dictionary
	return {"frame":pose.basis,"junction":pose*(source.junction as Vector3),
		"eave_sign":int(source.eave_sign),"end_sign":int(source.end_sign),
		"assets":run.valley_assets,"theme":source.theme}


static func _valley_section(variant: Dictionary, pose: Transform3D,
		bounds: AABB, runs: Array[Dictionary], family: StringName) -> Dictionary:
	for run: Dictionary in runs:
		var valley := run.get("valley",{}) as Dictionary
		if valley.is_empty(): continue
		if StringName(valley.theme)!=family: return {"invalid":true}
		var frame := valley.frame as Basis
		var delta := frame.inverse()*(pose.origin-(valley.junction as Vector3))
		if absf(delta.x)>SEAM_EPSILON: continue
		var role: StringName=&""
		if absf(delta.z)<=SEAM_EPSILON:
			role=&"end" if ".run.start" in String(variant.asset_id) or ".run.end" in String(variant.asset_id) else &"middle"
		elif absf(delta.z+float(valley.end_sign)*1.5)<=SEAM_EPSILON:
			role=&"adjacent"
		if role.is_empty(): continue
		# Profile keys may already select tight native stock. Check the actual
		# selected section rather than requiring an optional .tight profile key.
		if ".tight" not in String(variant.asset_id):
			return {"invalid":true}
		# Native phase is part of this finite cut, not an arbitrary roof rotation.
		if not pose.basis.is_equal_approx(frame) \
				or (role==&"adjacent")!=String(variant.asset_id).ends_with(".mirror_z"):
			return {"invalid":true}
		var prepared := ((valley.assets as Dictionary)[family] as Dictionary)[role] as Dictionary
		var cut_pose := Transform3D(pose.basis,Vector3(pose.origin.x,bounds.position.y,pose.origin.z))
		return {"asset_id":prepared.asset_id,"transform":cut_pose,
			"bounds":cut_pose*(prepared.bounds as AABB),"collision_pieces":prepared.collision_pieces}
	return {}


func _realize_compact_component(component_runs: Array[Dictionary],
		component_joins: Array[Dictionary], component_index: int,
		plan: SettlementFabricPlan, chain: Dictionary = {},
		preferred_family: StringName = &"") -> StringName:
	var start_extension := float(chain.get("start_extension", 0.0))
	var end_extension := float(chain.get("end_extension", 0.0))
	var partners := chain.get("partners", {}) as Dictionary
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
	if not preferred_family.is_empty() and common_families.has(preferred_family):
		canonical = preferred_family
	var profile := canonical
	var tight_profile := StringName("%s.tight" % canonical)
	# Junction partners own the space the branch deliberately enters.
	var eave_members := component_unit_ids.duplicate()
	var eave_bearers := component_bearing_ids.duplicate()
	for partner_id: StringName in partners:
		if bool(partners[partner_id]): eave_members.append(partner_id)
		else: eave_bearers.append(partner_id)
	if common_families.has(tight_profile) and _cross_eave_space_is_occupied(
			component_runs, canonical, eave_members, eave_bearers, plan):
		profile = tight_profile
	bays.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a.centre as Vector3).x < (b.centre as Vector3).x \
			if bool(component_runs[0].axis_x) \
			else (a.centre as Vector3).z < (b.centre as Vector3).z)
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
	# A junction continues the crown beyond its own end plane to the host ridge.
	var component_start := (component_runs[0].start as Vector3) - axis * start_extension
	var component_end := (component_runs[-1].end as Vector3) + axis * end_extension
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
		"variant": (((first_bay.variants as Dictionary)[profile] \
			as Dictionary)[&"start"]) as Dictionary,
		"flush_variant": (((first_bay.variants as Dictionary)[profile] \
			as Dictionary)[&"start_flush"]) as Dictionary,
		"offset": first_shift,
	}]
	var middle_variant := (((first_bay.variants as Dictionary)[profile] \
		as Dictionary)[&"middle"]) as Dictionary
	var mirrored_middle_variant := (((first_bay.variants as Dictionary)[profile] \
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
		"variant": (((last_bay.variants as Dictionary)[profile] \
			as Dictionary)[&"end"]) as Dictionary,
		"flush_variant": (((last_bay.variants as Dictionary)[profile] \
			as Dictionary)[&"end_flush"]) as Dictionary,
		"offset": last_shift,
	})
	var prepared_sections: Array[Dictionary]=[]
	var prepared_flush_count:=0
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
			"roof_junction_unit_ids": _partner_ids(partners),
		}
		var valley_section := _valley_section(variant,section_transform,section_bounds,component_runs,canonical)
		if valley_section.get("invalid",false): return &""
		if not valley_section.is_empty(): synthetic.merge(valley_section,true)
		if section.has("flush_variant") and valley_section.is_empty():
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
		# A continued end lies in the host ridge plane: its baked flush gable is
		# buried under the host crown instead of exposing eave stock beyond it.
		if (section_index == 0 and start_extension > 0.0) \
				or (section_index == sections.size() - 1 and end_extension > 0.0):
			if not select_flush_alternative(synthetic):
				return &""
			flush_endpoint_count -= 1
		# Joining exact half-depth crowns cannot acquire exterior stock beyond
		# their original end planes. Complete ordinary roofs keep their eaves.
		elif (section_index==0 and bool(component_runs[0].get("bounded_ends",false))) \
				or (section_index==sections.size()-1 and bool(component_runs[-1].get("bounded_ends",false))):
			if select_flush_alternative(synthetic):
				flush_endpoint_count-=1
				prepared_flush_count+=1
		prepared_sections.append(synthetic)
	for run: Dictionary in component_runs:
		for placement_id: StringName in run.original_placement_ids as Array[StringName]:
			suppressed_placement_ids[StringName("%s/%s" % [run.unit_id,placement_id])]=true
		if StringName(run.authored_material)!=canonical:
			normalized_repeat_count+=(run.bays as Array).size()
	flush_endpoint_count+=prepared_flush_count
	if profile==tight_profile: tight_cross_component_count+=1
	internal_gable_count+=component_joins.size()*2
	synthetic_placements.append_array(prepared_sections)
	return canonical


func _cross_eave_space_is_occupied(runs: Array[Dictionary], family: StringName,
		members: Array[StringName], bearers: Array[StringName],
		plan: SettlementFabricPlan) -> bool:
	# Select the complete chain's transverse profile from allocated space before
	# emitting sections. The ordinary and tight profiles are both authored finite
	# choices. No completed roof is tested, discarded, or rebuilt here.
	var run := runs[0]
	var axis_x := bool(run.axis_x)
	var start := run.start as Vector3
	var end := (runs[-1] as Dictionary).end as Vector3
	var roles := (((run.bays as Array)[0] as Dictionary).variants as Dictionary)[family] as Dictionary
	var bounds := (roles[&"middle"] as Dictionary).bounds as AABB
	var cross_low := bounds.position.z if axis_x else bounds.position.x
	var cross_high := bounds.end.z if axis_x else bounds.end.x
	var belts: Array[AABB] = []
	for span: Vector2 in [Vector2(cross_low, float(run.cross_min)),
			Vector2(float(run.cross_max), cross_high)]:
		if span.y <= span.x + PROFILE_EPSILON:
			continue
		var low := Vector3(start.x, float(run.base_y), span.x) if axis_x \
			else Vector3(span.x, float(run.base_y), start.z)
		var high := Vector3(end.x, float(run.peak_y), span.y) if axis_x \
			else Vector3(span.y, float(run.peak_y), end.z)
		belts.append(AABB(low, high - low))
	for unit: FabricUnit in plan.units:
		if members.has(unit.stable_id) or bearers.has(unit.stable_id):
			continue
		var recipe := plan.recipe(unit.recipe_id)
		var pose := unit.transform()
		for index in recipe.placements.size():
			if unit.suppressed_placement_ids.has(StringName(recipe.placements[index].id)):
				continue
			var occupied := pose * recipe.placement_bounds[index]
			for belt: AABB in belts:
				if SettlementFabricPlan._aabb_overlaps_volume(belt, occupied):
					return true
	return false


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


func _continue_modular_over_compact(chains: Array[Dictionary],
		plan: SettlementFabricPlan) -> void:
	## Parallel compact crowns at one eave datum that exactly tile a wider
	## modular roof's width along its end wall are the same building block
	## under separate roofs. The modular run continues over them: its authored
	## repeat pairs repeat at their own pitch and its end gable moves to the new
	## end. The compact units' roofs are withdrawn as a whole.
	var consumed: Dictionary = {}
	for modular_index in chains.size():
		var modular_runs := (chains[modular_index] as Dictionary).runs as Array[Dictionary]
		if modular_runs.size() != 1 or StringName(modular_runs[0].kind) != &"modular_gable":
			continue
		var modular := modular_runs[0]
		var pitch := float(modular.repeat_pitch)
		var ridge := (float(modular.cross_min) + float(modular.cross_max)) * 0.5
		var width := float(modular.cross_max) - float(modular.cross_min)
		for side in [-1, 1]:
			var seam := _axis_scalar(modular.start as Vector3, modular) if side < 0 \
				else _axis_scalar(modular.end as Vector3, modular)
			var group: Array[int] = []
			var along := Vector2(INF, -INF)
			var cross := Vector2(INF, -INF)
			for index in chains.size():
				if index == modular_index or consumed.has(index):
					continue
				var runs := (chains[index] as Dictionary).runs as Array[Dictionary]
				if not _junction_eligible(runs) or bool(runs[0].axis_x) != bool(modular.axis_x) \
						or absf(float(runs[0].base_y) - float(modular.base_y)) > PROFILE_EPSILON:
					continue
				var low := _axis_scalar(runs[0].start as Vector3, runs[0])
				var high := _axis_scalar((runs[-1] as Dictionary).end as Vector3, runs[0])
				var touching := high if side < 0 else low
				if absf(touching - seam) > SEAM_EPSILON \
						or float(runs[0].cross_min) < float(modular.cross_min) - SEAM_EPSILON \
						or float(runs[0].cross_max) > float(modular.cross_max) + SEAM_EPSILON:
					continue
				group.append(index)
				along = Vector2(minf(along.x, low), maxf(along.y, high))
				cross = Vector2(minf(cross.x, float(runs[0].cross_min)),
					maxf(cross.y, float(runs[0].cross_max)))
			if group.size() < 2:
				continue
			# Every member spans the same interval and together they tile the
			# modular wall width without gaps, centred under its ridge.
			var covered := 0.0
			var same_span := true
			for index in group:
				var runs := (chains[index] as Dictionary).runs as Array[Dictionary]
				covered += float(runs[0].cross_max) - float(runs[0].cross_min)
				same_span = same_span and absf(_axis_scalar(runs[0].start as Vector3, runs[0]) - along.x) <= SEAM_EPSILON \
					and absf(_axis_scalar((runs[-1] as Dictionary).end as Vector3, runs[0]) - along.y) <= SEAM_EPSILON
			var length := along.y - along.x
			if not same_span or absf(covered - (cross.y - cross.x)) > SEAM_EPSILON \
					or absf((cross.x + cross.y) * 0.5 - ridge) > SEAM_EPSILON \
					or cross.y - cross.x > width + SEAM_EPSILON or cross.y - cross.x < width - 1.0 \
					or pitch <= 0.0 or absf(roundf(length / pitch) * pitch - length) > SEAM_EPSILON:
				continue
			if not _modular_continuation(modular, side, length, group, chains, plan):
				continue
			for index in group:
				consumed[index] = true
			consumed[modular_index] = true
			modular_continuation_count += 1
			break
	var kept: Array[Dictionary] = []
	for index in chains.size():
		if not consumed.has(index):
			kept.append(chains[index])
	chains.assign(kept)


func _modular_continuation(modular: Dictionary, side: int, length: float,
		group: Array[int], chains: Array[Dictionary], plan: SettlementFabricPlan) -> bool:
	var unit := plan.unit(StringName(modular.unit_id))
	if unit == null:
		return false
	var recipe := plan.recipe(unit.recipe_id)
	var pose := unit.transform()
	var axis := Vector3.RIGHT if bool(modular.axis_x) else Vector3.BACK
	var pitch := float(modular.repeat_pitch)
	var seam := _axis_scalar(modular.start as Vector3, modular) if side < 0 \
		else _axis_scalar(modular.end as Vector3, modular)
	var end_id := StringName(modular.start_placement_id if side < 0 else modular.end_placement_id)
	var index_by_id: Dictionary = {}
	for index in recipe.placements.size():
		index_by_id[StringName(recipe.placements[index].id)] = index
	if not index_by_id.has(end_id):
		return false
	# The repeat pair nearest the seam is the authored cross-section repeated.
	var nearest: Array[Dictionary] = []
	var nearest_distance := INF
	for repeat: Dictionary in modular.repeat_placements as Array:
		var index := int(index_by_id[StringName(repeat.placement_id)])
		var origin := (pose * (recipe.placements[index].transform as Transform3D)).origin
		var distance := absf(_axis_scalar(origin, modular) - seam)
		if distance < nearest_distance - SEAM_EPSILON:
			nearest.clear()
			nearest_distance = distance
		if absf(distance - nearest_distance) <= SEAM_EPSILON:
			nearest.append({"index": index, "id": StringName(repeat.placement_id)})
	var members: Array[StringName] = [unit.stable_id]
	var bearers: Array[StringName] = unit.parent_ids.duplicate()
	for index in group:
		for run: Dictionary in (chains[index] as Dictionary).runs as Array[Dictionary]:
			if not members.has(StringName(run.unit_id)): members.append(StringName(run.unit_id))
			for parent_id: StringName in run.get("bearing_parent_ids", []) as Array[StringName]:
				if not bearers.has(parent_id): bearers.append(parent_id)
	var additions: Array[Dictionary] = []
	var count := roundi(length / pitch)
	for step in range(1, count + 1):
		var offset := axis * float(side) * pitch * float(step)
		for source: Dictionary in nearest:
			var index := int(source.index)
			additions.append(_shifted_placement(unit, recipe, index, offset,
				StringName("%s/continuation/%02d/%s" % [unit.stable_id, step, source.id]), members, bearers))
	var end_index := int(index_by_id[end_id])
	var end_gable := _shifted_placement(unit, recipe, end_index, axis * float(side) * length,
		StringName("%s/continuation/end/%s" % [unit.stable_id, end_id]), members, bearers)
	# The moved gable stands on the block's end wall: its bearing rooms are its
	# declared junction partners, exactly as the source gable bore on its own.
	end_gable["roof_junction_unit_ids"] = bearers.duplicate()
	additions.append(end_gable)
	# The continued roof is taller than the crowns it replaces: its whole volume
	# must hold nothing but the member roofs and their bearing rooms.
	for addition: Dictionary in additions:
		if plan._continuous_roof_bounds_enter_public_route(addition.bounds as AABB):
			return false
	var member_set: Dictionary = {}
	for member_id: StringName in members + bearers:
		member_set[member_id] = true
	for other: FabricUnit in plan.units:
		if member_set.has(other.stable_id):
			continue
		var other_recipe := plan.recipe(other.recipe_id)
		var other_pose := other.transform()
		for index in mini(other_recipe.placements.size(), other_recipe.placement_bounds.size()):
			if other.suppressed_placement_ids.has(StringName(other_recipe.placements[index].id)):
				continue
			var bounds := other_pose * other_recipe.placement_bounds[index]
			for addition: Dictionary in additions:
				if SettlementFabricPlan._aabb_overlaps_volume(addition.bounds as AABB, bounds):
					return false
	suppressed_placement_ids[StringName("%s/%s" % [unit.stable_id, end_id])] = true
	for index in group:
		for run: Dictionary in (chains[index] as Dictionary).runs as Array[Dictionary]:
			var member := plan.unit(StringName(run.unit_id))
			var member_recipe := plan.recipe(member.recipe_id)
			for placement: Dictionary in member_recipe.placements:
				suppressed_placement_ids[StringName("%s/%s" % [member.stable_id, placement.id])] = true
	synthetic_placements.append_array(additions)
	return true


static func _shifted_placement(unit: FabricUnit, recipe: FabricRecipe, index: int,
		offset: Vector3, stable_id: StringName, members: Array[StringName],
		bearers: Array[StringName]) -> Dictionary:
	var pose := unit.transform() * (recipe.placements[index].transform as Transform3D)
	var bounds := unit.transform() * recipe.placement_bounds[index]
	return {
		"stable_id": stable_id,
		"placement_id": stable_id,
		"asset_id": StringName(recipe.placements[index].asset_id),
		"transform": Transform3D(pose.basis, pose.origin + offset),
		"bounds": AABB(bounds.position + offset, bounds.size),
		"collision_pieces": recipe.placement_collision_pieces[index] \
			if index < recipe.placement_collision_pieces.size() else 0,
		"roof_component_unit_ids": members.duplicate(),
		"roof_component_bearing_ids": bearers.duplicate(),
	}


func _turn_square_leaves(chains: Array[Dictionary], plan: SettlementFabricPlan) -> void:
	## A square compact crown standing beside a longer parallel crown at the same
	## datum forms two disconnected gables. Its footprint is unchanged by a
	## quarter turn about its own centre, after which its ridge meets the longer
	## crown's side as an ordinary perpendicular junction. The turn rotates the
	## complete roof unit (sections, dormers, chimneys) and is admitted only when
	## the new eave space holds nothing but same-datum crowns.
	var turned: Dictionary = {}
	for chain_index in chains.size():
		var chain := chains[chain_index] as Dictionary
		var runs := chain.runs as Array[Dictionary]
		if runs.size() != 1 or not _junction_eligible(runs):
			continue
		var run := runs[0]
		var low := _axis_scalar(run.start as Vector3, run)
		var high := _axis_scalar(run.end as Vector3, run)
		if absf((high - low) - (float(run.cross_max) - float(run.cross_min))) > SEAM_EPSILON:
			continue
		var beside := false
		for other_index in chains.size():
			if other_index == chain_index or turned.has(other_index):
				continue
			var other_runs := (chains[other_index] as Dictionary).runs as Array[Dictionary]
			if not _junction_eligible(other_runs):
				continue
			var other := other_runs[0]
			if bool(other.axis_x) != bool(run.axis_x) \
					or absf(float(other.base_y) - float(run.base_y)) > PROFILE_EPSILON \
					or absf(float(other.peak_y) - float(run.peak_y)) > PROFILE_EPSILON:
				continue
			var other_low := _axis_scalar(other.start as Vector3, other)
			var other_high := _axis_scalar((other_runs[-1] as Dictionary).end as Vector3, other)
			# Only a strictly longer neighbour: two equal squares keep their pair.
			if other_high - other_low <= high - low + SEAM_EPSILON \
					or low < other_low - SEAM_EPSILON or high > other_high + SEAM_EPSILON:
				continue
			if absf(float(run.cross_max) - float(other.cross_min)) <= SEAM_EPSILON \
					or absf(float(run.cross_min) - float(other.cross_max)) <= SEAM_EPSILON:
				beside = true
		if not beside:
			continue
		var turn := _turned_run(run, plan)
		if turn.is_empty() or not _turned_space_is_clear(turn, chains, plan):
			continue
		chain["runs"] = [turn.run] as Array[Dictionary]
		chain["turned"] = true
		chain["turned_extras"] = turn.extras
		for extra: Dictionary in turn.extras as Array:
			suppressed_placement_ids[StringName(extra.source_id)] = true
			synthetic_placements.append(extra)
		turned[chain_index] = true
		turned_square_count += 1


func _turned_run(run: Dictionary, plan: SettlementFabricPlan) -> Dictionary:
	var unit := plan.unit(StringName(run.unit_id))
	if unit == null:
		return {}
	var start := run.start as Vector3
	var end := run.end as Vector3
	var centre := (start + end) * 0.5
	# +90 degrees maps +Z to +X; -90 maps +X to +Z, so each run's start stays
	# at the new minimum and the baked start/end roles keep their meaning.
	var basis := Basis(Vector3.UP, -PI * 0.5 if bool(run.axis_x) else PI * 0.5)
	var pivot := Transform3D(basis, centre - basis * centre)
	var turned := run.duplicate()
	turned["axis_x"] = not bool(run.axis_x)
	var half := (end - start).length() * 0.5
	var direction := Vector3.RIGHT if bool(turned.axis_x) else Vector3.BACK
	turned["start"] = centre - direction * half
	turned["end"] = centre + direction * half
	turned["cross_min"] = _axis_scalar(start, run)
	turned["cross_max"] = _axis_scalar(end, run)
	var bays: Array[Dictionary] = []
	for bay: Dictionary in run.bays as Array:
		var families: Dictionary = {}
		for family: Variant in (bay.variants as Dictionary):
			var roles: Dictionary = {}
			for role: Variant in ((bay.variants as Dictionary)[family] as Dictionary):
				var variant := (((bay.variants as Dictionary)[family] as Dictionary)[role] as Dictionary).duplicate()
				variant["transform"] = pivot * (variant.transform as Transform3D)
				variant["bounds"] = pivot * (variant.bounds as AABB)
				roles[role] = variant
			families[family] = roles
		bays.append({"centre": pivot * (bay.centre as Vector3), "variants": families})
	turned["bays"] = bays
	var sections: Dictionary = {}
	for placement_id: StringName in run.original_placement_ids as Array[StringName]:
		sections[placement_id] = true
	var extras: Array[Dictionary] = []
	var recipe := plan.recipe(unit.recipe_id)
	var pose := unit.transform()
	for index in recipe.placements.size():
		var placement := recipe.placements[index] as Dictionary
		var placement_id := StringName(placement.id)
		if sections.has(placement_id) or unit.suppressed_placement_ids.has(placement_id) \
				or index >= recipe.placement_bounds.size():
			continue
		var source_id := StringName("%s/%s" % [unit.stable_id, placement_id])
		extras.append({
			"stable_id": StringName("%s/turned" % source_id),
			"placement_id": placement_id,
			"source_id": source_id,
			"asset_id": StringName(placement.asset_id),
			"transform": pivot * pose * (placement.transform as Transform3D),
			"bounds": pivot * (pose * recipe.placement_bounds[index]),
			"collision_pieces": recipe.placement_collision_pieces[index] \
				if index < recipe.placement_collision_pieces.size() else 0,
			"roof_component_unit_ids": [unit.stable_id] as Array[StringName],
			"roof_component_bearing_ids": unit.parent_ids.duplicate(),
		})
	return {"run": turned, "extras": extras}


func _turned_space_is_clear(turn: Dictionary, chains: Array[Dictionary],
		plan: SettlementFabricPlan) -> bool:
	var run := turn.run as Dictionary
	var boxes: Array[AABB] = []
	for bay: Dictionary in run.bays as Array:
		var family: Variant = (bay.variants as Dictionary).keys()[0]
		for role: Variant in ((bay.variants as Dictionary)[family] as Dictionary):
			boxes.append((((bay.variants as Dictionary)[family] as Dictionary)[role] as Dictionary).bounds as AABB)
	for extra: Dictionary in turn.extras as Array:
		boxes.append(extra.bounds as AABB)
	for box: AABB in boxes:
		if plan._continuous_roof_bounds_enter_public_route(box):
			return false
	var allowed: Dictionary = {}
	for source: Dictionary in chains:
		var source_runs := source.runs as Array[Dictionary]
		if not _junction_eligible(source_runs) \
				or absf(float(source_runs[0].base_y) - float(run.base_y)) > PROFILE_EPSILON \
				or absf(float(source_runs[0].peak_y) - float(run.peak_y)) > PROFILE_EPSILON:
			continue
		for member: Dictionary in source_runs:
			for placement_id: StringName in member.get("original_placement_ids", []) as Array[StringName]:
				allowed[StringName("%s/%s" % [member.unit_id, placement_id])] = true
	var own := plan.unit(StringName(run.unit_id))
	for unit: FabricUnit in plan.units:
		if unit.stable_id == own.stable_id:
			continue
		var bearing_parent := own.parent_ids.has(unit.stable_id)
		var recipe := plan.recipe(unit.recipe_id)
		var pose := unit.transform()
		for index in mini(recipe.placements.size(), recipe.placement_bounds.size()):
			var placement_id := StringName(recipe.placements[index].id)
			if unit.suppressed_placement_ids.has(placement_id) \
					or allowed.has(StringName("%s/%s" % [unit.stable_id, placement_id])):
				continue
			var other := pose * recipe.placement_bounds[index]
			# The roof skin meets its bearing walls, but rotating a chimney or
			# dormer does not grant it permission to enter those walls. Keep the
			# original orientation when any complete extra loses that clearance.
			if bearing_parent:
				for extra: Dictionary in turn.extras as Array:
					if SettlementFabricPlan._aabb_overlaps_volume(extra.bounds, other):
						return false
				continue
			for box: AABB in boxes:
				if SettlementFabricPlan._aabb_overlaps_volume(box, other):
					return false
	return true


func _link_perpendicular_junctions(chains: Array[Dictionary],
		plan: SettlementFabricPlan) -> void:
	## A compact crown whose exterior end plane lies on the side wall of a
	## perpendicular compact crown at the same eave datum and profile meets that
	## host as a T or L. Continuing the branch across the host half-width to its
	## ridge makes the two identical prisms intersect in real valleys; the flush
	## end then lies in the host ridge plane under the host crown. Exactly one
	## host must receive an end, the branch's whole width must bear on that side,
	## and the continued volume must hold nothing but the two roofs.
	for chain_index in chains.size():
		var chain := chains[chain_index] as Dictionary
		var runs := chain.runs as Array[Dictionary]
		if not _junction_eligible(runs):
			continue
		var first := runs[0]
		for side in [-1, 1]:
			var plane := _axis_scalar(first.start as Vector3, first) if side < 0 \
				else _axis_scalar((runs[-1] as Dictionary).end as Vector3, first)
			var hosts: Array[int] = []
			for host_index in chains.size():
				if host_index == chain_index:
					continue
				var host_runs := (chains[host_index] as Dictionary).runs as Array[Dictionary]
				if not _junction_eligible(host_runs):
					continue
				var host := host_runs[0]
				if bool(host.axis_x) == bool(first.axis_x) \
						or absf(float(host.base_y) - float(first.base_y)) > PROFILE_EPSILON \
						or absf(float(host.peak_y) - float(first.peak_y)) > PROFILE_EPSILON \
						or absf(float(host.section_pitch) - float(first.section_pitch)) > PROFILE_EPSILON:
					continue
				var near_wall := float(host.cross_min) if side > 0 else float(host.cross_max)
				if absf(near_wall - plane) > SEAM_EPSILON:
					continue
				var host_low := _axis_scalar(host.start as Vector3, host)
				var host_high := _axis_scalar((host_runs[-1] as Dictionary).end as Vector3, host)
				if float(first.cross_min) < host_low - SEAM_EPSILON \
						or float(first.cross_max) > host_high + SEAM_EPSILON:
					continue
				hosts.append(host_index)
			if hosts.size() != 1:
				continue
			var host_chain := chains[hosts[0]] as Dictionary
			var host_first := (host_chain.runs as Array[Dictionary])[0]
			var ridge := (float(host_first.cross_min) + float(host_first.cross_max)) * 0.5
			var extension := (ridge - plane) * float(side)
			var pitch := float(first.section_pitch)
			if extension <= SEAM_EPSILON or pitch <= 0.0 \
					or absf(roundf(extension / pitch) * pitch - extension) > SEAM_EPSILON:
				continue
			if not _junction_volume_is_clear(chain, host_chain, plane, ridge, plan, chains):
				continue
			chain["start_extension" if side < 0 else "end_extension"] = extension
			_add_partners(chain, host_chain)
			_add_partners(host_chain, chain)
			var links := chain.get("junction_links", []) as Array
			links.append(hosts[0])
			chain["junction_links"] = links


func _junction_eligible(runs: Array[Dictionary]) -> bool:
	for run: Dictionary in runs:
		# Bounded half-depth crowns may still continue: the continued end is flush.
		if StringName(run.kind) != &"compact_gable" \
				or not (run.get("valley", {}) as Dictionary).is_empty():
			return false
	return true


static func _add_partners(chain: Dictionary, other: Dictionary) -> void:
	var partners := chain.partners as Dictionary
	for run: Dictionary in other.runs as Array[Dictionary]:
		partners[StringName(run.unit_id)] = true
		for parent_id: StringName in run.get("bearing_parent_ids", []) as Array[StringName]:
			if not partners.has(parent_id): partners[parent_id] = false


static func _partner_ids(partners: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	for partner_id: StringName in partners:
		out.append(partner_id)
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return out


func _junction_volume_is_clear(chain: Dictionary, host_chain: Dictionary,
		plane: float, ridge: float, plan: SettlementFabricPlan,
		chains: Array[Dictionary]) -> bool:
	var run := (chain.runs as Array[Dictionary])[0]
	var axis_x := bool(run.axis_x)
	var along_low := minf(plane, ridge)
	var along_high := maxf(plane, ridge)
	var low := Vector3(along_low, float(run.base_y), float(run.cross_min)) if axis_x \
		else Vector3(float(run.cross_min), float(run.base_y), along_low)
	var high := Vector3(along_high, float(run.peak_y), float(run.cross_max)) if axis_x \
		else Vector3(float(run.cross_max), float(run.peak_y), along_high)
	var volume := AABB(low, high - low)
	if plan._continuous_roof_bounds_enter_public_route(volume):
		return false
	# Crown sections of identical same-datum compact roofs may share the volume:
	# their union forms the valleys. Dormers, chimneys, walls and every other
	# unit remain hard conflicts.
	var own_sections: Dictionary = {}
	var ignored_units: Dictionary = {}
	for source: Dictionary in chains:
		var source_runs := source.runs as Array[Dictionary]
		if not _junction_eligible(source_runs) \
				or absf(float(source_runs[0].base_y) - float(run.base_y)) > PROFILE_EPSILON \
				or absf(float(source_runs[0].peak_y) - float(run.peak_y)) > PROFILE_EPSILON:
			continue
		for member: Dictionary in source_runs:
			for placement_id: StringName in member.get("original_placement_ids", []) as Array[StringName]:
				own_sections[StringName("%s/%s" % [member.unit_id, placement_id])] = true
	for source: Dictionary in [chain, host_chain]:
		for member: Dictionary in source.runs as Array[Dictionary]:
			for parent_id: StringName in member.get("bearing_parent_ids", []) as Array[StringName]:
				ignored_units[parent_id] = true
	for unit: FabricUnit in plan.units:
		if ignored_units.has(unit.stable_id):
			continue
		var recipe := plan.recipe(unit.recipe_id)
		var pose := unit.transform()
		for index in mini(recipe.placements.size(), recipe.placement_bounds.size()):
			var placement_id := StringName(recipe.placements[index].id)
			if unit.suppressed_placement_ids.has(placement_id) \
					or own_sections.has(StringName("%s/%s" % [unit.stable_id, placement_id])):
				continue
			if SettlementFabricPlan._aabb_overlaps_volume(volume,
					pose * recipe.placement_bounds[index]):
				return false
	return true


func _junction_group_families(chains: Array[Dictionary]) -> Dictionary:
	## One joined roof reads as one building: every chain linked by a junction
	## uses the family covering the greatest total length of that group.
	var parents := PackedInt32Array()
	parents.resize(chains.size())
	for index in chains.size():
		parents[index] = index
	for index in chains.size():
		for link: int in (chains[index] as Dictionary).get("junction_links", []) as Array:
			_union(parents, index, link)
	var length_by_root: Dictionary = {}
	var size_by_root: Dictionary = {}
	for index in chains.size():
		var root := _find(parents, index)
		size_by_root[root] = int(size_by_root.get(root, 0)) + 1
		if not length_by_root.has(root):
			length_by_root[root] = {}
		for run: Dictionary in (chains[index] as Dictionary).runs as Array[Dictionary]:
			var material := StringName(run.get("authored_material", ""))
			if material.is_empty():
				continue
			var lengths := length_by_root[root] as Dictionary
			lengths[material] = float(lengths.get(material, 0.0)) \
				+ _axis_scalar(run.end as Vector3, run) - _axis_scalar(run.start as Vector3, run)
	var out: Dictionary = {}
	for index in chains.size():
		var root := _find(parents, index)
		if int(size_by_root[root]) < 2:
			continue
		var lengths := length_by_root[root] as Dictionary
		var materials: Array = lengths.keys()
		if materials.is_empty():
			continue
		materials.sort_custom(func(a: Variant, b: Variant) -> bool:
			var left := float(lengths[a])
			var right := float(lengths[b])
			return left > right if not is_equal_approx(left, right) \
				else String(a) < String(b))
		out[index] = StringName(materials[0])
	return out


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
