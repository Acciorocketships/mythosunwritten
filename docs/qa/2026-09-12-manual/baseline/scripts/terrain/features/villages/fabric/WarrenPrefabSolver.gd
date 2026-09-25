class_name WarrenPrefabSolver
extends RefCounted

## Derives complete source-pack houses from still-open route boundaries. Each
## candidate puts the prefab's reviewed exterior threshold exactly one lattice
## cell beyond a real public surface, facing back toward that landing. The
## common transaction remains the sole collision, envelope, entrance, and
## exterior-air authority.


static func candidate_specs(program: SettlementFabricProgram,
		plan: SettlementFabricPlan, world_seed: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if program == null or plan == null or not plan.is_sealed() \
			or plan.solid_void_plan == null:
		return out
	var prefab_recipes: Array[FabricRecipe] = []
	for recipe_value: FabricRecipe in program.recipes():
		if recipe_value.has_tag(&"prefab_anchor") \
				and not recipe_value.entrances.is_empty():
			prefab_recipes.append(recipe_value)
	var seen: Dictionary = {}
	for obligation: Dictionary in plan.solid_void_plan.unbounded_obligations:
		var surface := obligation.surface_cell as Vector3i
		var side := obligation.side as Vector3i
		# Reviewed source-pack buildings are ground-rooted accents. Allowing their
		# threshold to follow an upper gallery made the terrain-bearing contract
		# technically valid only by extruding a forest of rock supports to that
		# datum. Elevated mass is composed from the smaller bearing-aware room
		# grammar instead; a complete prefab may address only the two lowest bands.
		if surface.y > 1 or side.y != 0:
			continue
		for recipe_value: FabricRecipe in prefab_recipes:
			var entrance := recipe_value.entrances[0] as Dictionary
			var yaw := _yaw_for_facing(entrance.facing as Vector3i, -side)
			if yaw < 0:
				continue
			var rotated_door := FabricRecipe.transform_cell(
				entrance.cell as Vector3i, Vector3i.ZERO, yaw)
			var origin := surface + side - rotated_door
			var key := "%s/%d/%d/%d/%d" % [recipe_value.recipe_id,
				origin.x, origin.y, origin.z, yaw]
			if seen.has(key):
				continue
			seen[key] = true
			if not _candidate_is_statically_clear(recipe_value, origin, yaw, plan):
				continue
			var stable_id := StringName("warren.prefab.%s.%d.%d.%d.r%d" % [
				String(recipe_value.recipe_id).trim_prefix("anchor.prefab."),
				origin.x, origin.y, origin.z, yaw])
			out.append({
				"stable_id": stable_id,
				"recipe_id": recipe_value.recipe_id,
				"source_family": _source_family(recipe_value),
				# The exact public cell whose boundary produced this plot. Coupled
				# ground-anchor selection uses the semantic landing to protect the
				# market alley without reverse-engineering it from prefab bounds.
				"landing_cell": surface,
				"footprint_area": recipe_value.local_clearance_bounds.size.x \
					* recipe_value.local_clearance_bounds.size.z,
				"footprint_span": maxf(
					recipe_value.local_clearance_bounds.size.x,
					recipe_value.local_clearance_bounds.size.z),
				"spec": SettlementFabricSolver.unit_spec(stable_id,
					recipe_value.recipe_id, origin, yaw),
			})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a.footprint_span), float(b.footprint_span)):
			return float(a.footprint_span) < float(b.footprint_span)
		if not is_equal_approx(float(a.footprint_area), float(b.footprint_area)):
			return float(a.footprint_area) < float(b.footprint_area)
		var a_key := String(a.stable_id)
		var b_key := String(b.stable_id)
		var a_hash := _seeded_hash(a_key, world_seed)
		var b_hash := _seeded_hash(b_key, world_seed)
		return a_hash < b_hash if a_hash != b_hash else a_key < b_key)
	return out


static func _candidate_is_statically_clear(recipe_value: FabricRecipe,
		origin: Vector3i, yaw: int, plan: SettlementFabricPlan) -> bool:
	## Cheap exact broad phase for a unit that declares no seams or parents.
	## This mirrors only universal construction conflicts; it deliberately does
	## not predict entrance service, terrain bearing, exterior-air provenance, or
	## any other complete-plan fact. Surviving candidates still enter the common
	## transaction, so this optimization cannot make an invalid prefab legal.
	var solids := plan.transformed_cells(&"solid")
	var headroom := plan.transformed_cells(&"headroom")
	var walks := plan.transformed_cells(&"walk")
	var public_air := plan.transformed_cells(&"public_air")
	for local_cell: Vector3i in recipe_value.solid_cells:
		var cell := FabricRecipe.transform_cell(local_cell, origin, yaw)
		if solids.has(cell) or headroom.has(cell) or walks.has(cell) \
				or public_air.has(cell):
			return false
	for local_cell: Vector3i in recipe_value.headroom_cells:
		var cell := FabricRecipe.transform_cell(local_cell, origin, yaw)
		if solids.has(cell) or headroom.has(cell):
			return false
	var basis := Basis(Vector3.UP, float(posmod(yaw, 4)) * PI * 0.5)
	var transform := Transform3D(basis,
		Vector3(origin) * FabricRecipe.CELL_SIZE)
	var candidate_bounds := transform * recipe_value.local_clearance_bounds
	for existing_bounds: AABB in plan.transformed_visual_clearance_bounds():
		if _aabb_overlaps_volume(candidate_bounds, existing_bounds):
			return false
	return true


static func _aabb_overlaps_volume(left: AABB, right: AABB,
		epsilon: float = 0.10) -> bool:
	var overlap_x := minf(left.end.x, right.end.x) \
		- maxf(left.position.x, right.position.x)
	var overlap_y := minf(left.end.y, right.end.y) \
		- maxf(left.position.y, right.position.y)
	var overlap_z := minf(left.end.z, right.end.z) \
		- maxf(left.position.z, right.position.z)
	return overlap_x > epsilon and overlap_y > epsilon and overlap_z > epsilon


static func _source_family(recipe_value: FabricRecipe) -> StringName:
	for asset_id: StringName in recipe_value.asset_ids():
		return StringName(String(asset_id).get_slice(".", 0))
	return &"unknown"


static func _yaw_for_facing(local_facing: Vector3i,
		world_facing: Vector3i) -> int:
	for yaw in 4:
		if FabricRecipe.transform_direction(local_facing, yaw) == world_facing:
			return yaw
	return -1


static func _seeded_hash(value: String, seed: int) -> int:
	var hash_value := seed ^ 0x6b1d2e77
	for byte in value.to_utf8_buffer():
		hash_value = int((hash_value ^ int(byte)) * 16777619) & 0x7fffffff
	return hash_value
