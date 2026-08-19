class_name PublicRealmSurfaceSolver
extends RefCounted

## Compiles topology and recipe claims into one exact surface union. It never
## infers a floor from an accidental gap.


static func solve(stable_id: StringName, realm: SectionalPublicRealmPlan,
		fabric_plan: SettlementFabricPlan,
		volume: WarrenVolumePlan = null) -> PublicRealmSurfacePlan:
	if stable_id.is_empty() or fabric_plan == null \
			or (realm != null and not realm.is_sealed()):
		return null
	var result := PublicRealmSurfacePlan.new(stable_id)
	if realm != null:
		for node_value: PublicRealmNode in realm.nodes:
			for cell: Vector3i in node_value.surface_cells:
				if not result.add_claim(cell, node_value.surface_kind,
						node_value.stable_id):
					return null
	for unit_value: FabricUnit in fabric_plan.units:
		var recipe_value := fabric_plan.recipe(unit_value.recipe_id)
		if not recipe_value.has_tag(&"public_walk"):
			continue
		var kind := _kind_for_recipe(recipe_value)
		if realm != null:
			var node_value := realm.node(unit_value.public_node_id)
			if node_value == null:
				return null
			kind = node_value.surface_kind
		for local_cell: Vector3i in recipe_value.walk_cells:
			var cell := FabricRecipe.transform_cell(local_cell,
				unit_value.lattice_origin, unit_value.yaw_quarters)
			if realm != null and not realm.node(unit_value.public_node_id).has_cell(cell):
				return null
			if not result.add_claim(cell, kind, unit_value.stable_id):
				return null
	if volume != null:
		if not volume.is_sealed() or realm == null:
			return null
		for transition_index in volume.transitions.size():
			var transition := volume.transitions[transition_index]
			if not transition.is_vertical():
				continue
			var node_id := StringName("volume.transition.%02d" % transition_index)
			var transition_node := realm.node(node_id)
			if transition_node == null or not _same_cells(
					transition_node.surface_cells, transition.surface_cells()):
				return null
			var payload := WarrenTransitionSurfaceBuilder.build(
				StringName("%s.mesh" % node_id), transition,
				transition_node.surface_cells)
			if payload.is_empty() \
					or not result.add_transition_mesh_payload(payload):
				return null
	var structural_solids: Dictionary = {}
	for cell_value: Variant in fabric_plan.transformed_cells(&"solid"):
		var cell := cell_value as Vector3i
		structural_solids[_cell_key(cell)] = true
	var other_classified := structural_solids.duplicate()
	if realm != null:
		for cell: Vector3i in realm.daylight_void_cells:
			other_classified[_cell_key(cell)] = true
	var entrances: Array[Dictionary] = []
	for unit_value: FabricUnit in fabric_plan.units:
		var recipe_value := fabric_plan.recipe(unit_value.recipe_id)
		for entrance: Dictionary in recipe_value.entrances:
			var threshold := FabricRecipe.transform_cell(
				entrance.cell as Vector3i, unit_value.lattice_origin,
				unit_value.yaw_quarters)
			var facing := FabricRecipe.transform_direction(
				entrance.facing as Vector3i, unit_value.yaw_quarters)
			var door_phase := -1
			if recipe_value.has_tag(&"generated_building"):
				door_phase = 1 if recipe_value.has_tag(
					&"alternate_door_phase") else 0
			entrances.append({
				"stable_id": StringName("%s/%s" % [unit_value.stable_id,
					StringName(entrance.id)]),
				"unit_id": unit_value.stable_id,
				"threshold_cell": threshold,
				"facing": facing,
				"landing_cell": threshold + facing,
				"door_phase": door_phase,
			})
	var required: Array[Vector3i] = []
	var daylight_voids: Array[Vector3i] = []
	var transition_seams: Array[Dictionary] = []
	if realm != null:
		required.assign(realm.required_classification_cells)
		daylight_voids.assign(realm.daylight_void_cells)
		for edge_value: PublicRealmEdge in realm.edges:
			for seam: Dictionary in edge_value.seams:
				transition_seams.append(seam.duplicate())
	if not result.seal(required, other_classified, structural_solids, entrances,
			daylight_voids, transition_seams):
		return null
	return result


static func _kind_for_recipe(recipe_value: FabricRecipe) \
		-> PublicRealmSurfacePlan.SurfaceKind:
	if recipe_value.has_tag(&"stair"):
		return PublicRealmSurfacePlan.SurfaceKind.STAIR
	if recipe_value.has_tag(&"gallery") or recipe_value.has_tag(&"platform"):
		return PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT
	return PublicRealmSurfacePlan.SurfaceKind.TERRAIN_STREET


static func _cell_key(cell: Vector3i) -> String:
	return "%d:%d:%d" % [cell.x, cell.y, cell.z]


static func _same_cells(left: Array[Vector3i],
		right: Array[Vector3i]) -> bool:
	if left.size() != right.size():
		return false
	var remaining: Dictionary = {}
	for cell: Vector3i in left:
		remaining[cell] = true
	for cell: Vector3i in right:
		if not remaining.erase(cell):
			return false
	return remaining.is_empty()
