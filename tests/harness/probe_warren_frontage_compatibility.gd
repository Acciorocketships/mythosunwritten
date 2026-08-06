extends SceneTree

## Diagnoses why logical opposite-frontage parcels do or do not survive the
## measured construction vocabulary. It reports the first exact component
## envelope conflict instead of weakening compatibility by guesswork.


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seed := _argument_int(args, "--seed", 6046713720826375059)
	var attempt := _argument_int(args, "--attempt", 56)
	var envelope := WarrenVolumeEnvelope.build(seed)
	var volume := WarrenPublicRealmCarver.sealed_candidate(seed, attempt,
		envelope)
	assert(volume != null)
	var program := SettlementFabricProgram.compile(
		EnvironmentCatalog.load_default())
	assert(program != null)
	var candidates: Array[Dictionary] = WarrenParcelizer._candidates(volume)
	var realm := WarrenVolumePublicRealmAdapter.from_volume(volume)
	var parcels := WarrenParcelizer.solve(volume,
		Callable(WarrenAssetCompiler, "parcels_are_visually_compatible").bind(
			program),
		Callable(WarrenAssetCompiler, "skywalk_reservation").bind(program,
			realm.air_claims()),
		Callable(WarrenAssetCompiler,
			"parcel_preserves_skywalk_reservation").bind(program))
	var town := WarrenTownSolver.solve_attempt(seed, attempt, {}, program)
	var logical_pairs := 0
	var visual_pairs := 0
	var logical_opposite_pairs := 0
	var visual_opposite_pairs := 0
	var first_conflict: Dictionary = {}
	for left_index in candidates.size():
		var left := candidates[left_index].parcel as WarrenBuildingParcel
		for right_index in range(left_index + 1, candidates.size()):
			var right := candidates[right_index].parcel as WarrenBuildingParcel
			if left.address_walk_cell != right.address_walk_cell \
					or left.frontage_direction == right.frontage_direction \
					or _overlap(left, right):
				continue
			logical_pairs += 1
			var compatible := WarrenAssetCompiler.parcels_are_visually_compatible(
				left, right, program)
			if right.frontage_direction == -left.frontage_direction:
				logical_opposite_pairs += 1
				visual_opposite_pairs += int(compatible)
			if compatible:
				visual_pairs += 1
			elif first_conflict.is_empty():
				first_conflict = _conflict(left, right, program)
	print(JSON.stringify({
		"seed": seed,
		"attempt": attempt,
		"candidate_count": candidates.size(),
		"logical_opposite_frontage_pairs": logical_pairs,
		"visual_opposite_frontage_pairs": visual_pairs,
		"logical_facing_pairs": logical_opposite_pairs,
		"visual_facing_pairs": visual_opposite_pairs,
		"first_conflict": first_conflict,
		"town_accepted": town != null,
		"parcel_plan_accepted": parcels != null,
		"parcel_audit": {} if parcels == null else parcels.audit,
		"town_failure": WarrenTownSolver.last_failure,
		"town_audit": {} if town == null else town.audit,
	}, "  "))
	quit(0)


static func _conflict(left: WarrenBuildingParcel,
		right: WarrenBuildingParcel, program: SettlementFabricProgram) \
		-> Dictionary:
	var left_proposal := WarrenParcelConstruction.proposal(left)
	var right_proposal := WarrenParcelConstruction.proposal(right)
	for left_component: Dictionary in StaggeredFabricCompiler.proposal_components(
			left_proposal):
		var left_recipe := program.recipe(StringName(left_component.recipe_id))
		var left_box := FabricRecipe.lattice_transform(
			left_component.origin as Vector3i,
			int(left_component.yaw_quarters)) \
			* left_recipe.local_clearance_bounds
		for right_component: Dictionary in \
				StaggeredFabricCompiler.proposal_components(right_proposal):
			var right_recipe := program.recipe(StringName(right_component.recipe_id))
			var right_box := FabricRecipe.lattice_transform(
				right_component.origin as Vector3i,
				int(right_component.yaw_quarters)) \
				* right_recipe.local_clearance_bounds
			if SettlementFabricPlan._aabb_overlaps_volume(left_box, right_box):
				return {
					"address": str(left.address_walk_cell),
					"left_shape": "%dx%d" % [left.width_cells, left.depth_cells],
					"right_shape": "%dx%d" % [right.width_cells, right.depth_cells],
					"left_component": String(left_component.recipe_id),
					"right_component": String(right_component.recipe_id),
					"left_box": _box(left_box),
					"right_box": _box(right_box),
				}
	return {}


static func _overlap(left: WarrenBuildingParcel,
		right: WarrenBuildingParcel) -> bool:
	var occupied: Dictionary = {}
	for cell: Vector3i in left.occupied_cells():
		occupied[cell] = true
	for cell: Vector3i in right.occupied_cells():
		if occupied.has(cell):
			return true
	return false


static func _box(value: AABB) -> Dictionary:
	return {"position": str(value.position), "size": str(value.size)}


static func _argument_int(args: PackedStringArray, key: String,
		fallback: int) -> int:
	var index := args.find(key)
	return fallback if index < 0 or index + 1 >= args.size() \
		else int(args[index + 1])
