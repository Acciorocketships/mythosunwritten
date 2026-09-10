extends RefCounted

# Frozen pre-migration oracle; production never loads this test fixture.
const MAX_CANTILEVER_SUPPORT_ASSIGNMENT_NODES := 4096

static func _cantilever_support_options(records: Array[Dictionary],
		related_room_ids: Dictionary, buildings: Array[WarrenBuildingVolume],
		existing_features: Array[WarrenFeatureReservation],
		program: SettlementFabricProgram, world_seed: int) -> Array[Dictionary]:
	## Each diagonal course has one authored shallow alternative. Enumerating
	## per-course choices matters: replacing an entire facade at once can move a
	## collision from one end of a room to the other and falsely reject a sound
	## mixed support course.
	var diagonal_indices: Array[int] = []
	for index in records.size():
		if String(records[index].recipe_id).begins_with(
				"outcrop.support.diagonal."):
			diagonal_indices.append(index)
	var option_count := 1 << diagonal_indices.size()
	var out: Array[Dictionary] = []
	for mask in option_count:
		var option_records: Array[Dictionary] = []
		for source: Dictionary in records:
			option_records.append(source.duplicate(true))
		for bit in diagonal_indices.size():
			if mask & (1 << bit):
				var source_recipe := StringName(
					option_records[diagonal_indices[bit]].recipe_id)
				option_records[diagonal_indices[bit]]["recipe_id"] = \
					&"outcrop.support.bracketed.1" \
					if source_recipe == &"outcrop.support.diagonal.1" \
					else &"outcrop.support.bracketed.2"
		var analysis := WarrenSpatialFeatureSolver._outcrop_support_analysis(option_records,
			related_room_ids, buildings, existing_features, program, world_seed)
		if not StringName(analysis.conflict).is_empty():
			continue
		var bounds := _cantilever_support_bounds(option_records, program)
		if bounds.size() != option_records.size():
			continue
		out.append({"records": option_records, "analysis": analysis,
			"bounds": bounds,
			"diagonal_count": option_records.filter(
				func(record: Dictionary) -> bool:
					return String(record.recipe_id).begins_with(
						"outcrop.support.diagonal.")).size(),
			"tie": mask})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.diagonal_count) != int(b.diagonal_count):
			return int(a.diagonal_count) > int(b.diagonal_count)
		return int(a.tie) < int(b.tie))
	return out


static func _cantilever_support_bounds(records: Array[Dictionary],
		program: SettlementFabricProgram) -> Array[AABB]:
	var out: Array[AABB] = []
	if program == null:
		return out
	for record: Dictionary in records:
		var recipe := program.recipe(StringName(record.recipe_id))
		if recipe == null or not recipe.has_tag(&"cantilever_support"):
			return [] as Array[AABB]
		out.append(FabricRecipe.lattice_transform(record.origin as Vector3i,
			int(record.yaw_quarters)) * recipe.local_clearance_bounds)
	return out


static func _assign_cantilever_supports(entries: Array[Dictionary],
		state: Dictionary) -> Dictionary:
	var ordered := entries.duplicate(true)
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_options := (a.options as Array).size()
		var b_options := (b.options as Array).size()
		if a_options != b_options:
			return a_options < b_options
		return String(a.key) < String(b.key))
	var assignments: Dictionary = {}
	var claimed_supports: Array[Dictionary] = []
	if _assign_cantilever_supports_recursive(ordered, 0, claimed_supports,
			assignments, state):
		return assignments
	return {}


static func _assign_cantilever_supports_recursive(entries: Array,
		position: int, claimed_supports: Array[Dictionary], assignments: Dictionary,
		state: Dictionary) -> bool:
	state["visited_node_count"] = int(state.visited_node_count) + 1
	state["peak_assigned_count"] = maxi(int(state.peak_assigned_count), position)
	if int(state.visited_node_count) > MAX_CANTILEVER_SUPPORT_ASSIGNMENT_NODES:
		return false
	if position >= entries.size():
		return true
	var entry := entries[position] as Dictionary
	for option_value: Variant in entry.options as Array:
		var option := option_value as Dictionary
		var overlaps := false
		var option_bounds: Array[AABB] = []
		option_bounds.assign(option.bounds as Array)
		var option_records: Array[Dictionary] = []
		option_records.assign(option.get("records", []) as Array)
		for bounds_index in option_bounds.size():
			var bounds := option_bounds[bounds_index]
			var record := option_records[bounds_index] as Dictionary \
				if bounds_index < option_records.size() else {}
			for claimed: Dictionary in claimed_supports:
				if SettlementFabricPlan._aabb_overlaps_volume(bounds,
						claimed.bounds as AABB) \
						and not _cantilever_supports_share_frame(record,
							claimed.record as Dictionary):
					overlaps = true
					break
			if overlaps:
				break
		if overlaps:
			continue
		var old_support_count := claimed_supports.size()
		for bounds_index in option_bounds.size():
			claimed_supports.append({"bounds": option_bounds[bounds_index],
				"record": option_records[bounds_index] as Dictionary \
					if bounds_index < option_records.size() else {}})
		assignments[String(entry.key)] = option
		if _assign_cantilever_supports_recursive(entries, position + 1,
				claimed_supports, assignments, state):
			return true
		assignments.erase(String(entry.key))
		claimed_supports.resize(old_support_count)
	return false


static func _cantilever_supports_share_frame(left: Dictionary,
		right: Dictionary) -> bool:
	## Cantilever courses are authored pieces of one town-wide timber frame. Their
	## conservative AABBs may overlap at shared posts, consecutive lifts, or a
	## perpendicular braced joint; the fabric compiler records those intersections
	## as explicit joinery seams. Feature and inhabited-room envelopes were already
	## checked before this global assignment and remain hard conflicts.
	if left.is_empty() or right.is_empty():
		return false
	return String(left.get("recipe_id", "")).begins_with(
		"outcrop.support.") and String(right.get("recipe_id", "")).begins_with(
			"outcrop.support.")
