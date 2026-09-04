class_name PublicRealmSurfaceSolver
extends RefCounted

## Compiles topology and recipe claims into one exact surface union. The only
## closure it performs is a typed, borne concave court corner: the missing
## fourth cell of an otherwise complete 2 x 2 court beside structural mass.
## That is a module-union seam, not permission to infer floors from arbitrary
## empty space.

const CARDINAL_DIRECTIONS := [
	Vector3i.LEFT,
	Vector3i.RIGHT,
	Vector3i.FORWARD,
	Vector3i.BACK,
]


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
	var structural_solids: Dictionary = {}
	for cell_value: Variant in fabric_plan.transformed_cells(&"solid"):
		var cell := cell_value as Vector3i
		structural_solids[_cell_key(cell)] = true
	var daylight_void_set: Dictionary = {}
	if realm != null:
		for cell: Vector3i in realm.daylight_void_cells:
			daylight_void_set[_cell_key(cell)] = true
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
		# A court assembled from adjacent modules may leave the fourth cell of a
		# borne 2 x 2 corner unclaimed where it meets a structural wall. Seal that
		# exact orthogonal union before support datums and guard boundaries are
		# derived. The source claims are snapshotted, so closure cannot grow or
		# cascade across unrelated empty space.
		if not _close_borne_court_corners(result, structural_solids,
				daylight_void_set, fabric_plan.retained_terrace_cells):
			return null
		# Structural platforms descend to the terrain below their own fine-grid
		# column, never to an implicit global band zero.  The renderer formerly
		# received no datums here, so `support_base_at()` silently returned zero;
		# on stepped settlement ground that produced the long posts ending in
		# open air seen in review captures.  The volume envelope is the topology
		# owner's exact local terrain field, and fine X/Z map back to its 3 m
		# macro columns by floor division (including negative coordinates).
		for kind: PublicRealmSurfacePlan.SurfaceKind in [
				PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT,
				PublicRealmSurfacePlan.SurfaceKind.BRIDGE]:
			for cell: Vector3i in result.cells_for_kind(kind):
				var column := Vector2i(floori(float(cell.x) / 2.0),
					floori(float(cell.z) / 2.0))
				var support_base := volume.envelope.ground_at(column)
				if support_base > cell.y \
						or not result.set_support_base(cell, support_base):
					return null
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
	# TASK I4 ROUND 4. THE VILLAGE GREEN'S OWN MOUTHS, which only this call site
	# can name. The guard rule fences a court boundary whose far side carries no
	# CLAIM, and a lawn is not a claim -- it is a green cap on retained mass one
	# band down, level with the pavement by the entrance rule's own arithmetic.
	# Every claim is in by now, so the assembler can read the surface off
	# `result` exactly as it reads it off a sealed plan, and the fabric plan
	# carries the retained mass and the built solids the garden is derived from.
	# A plan with no square names nothing and every guard stands where it did.
	if not result.seal(required, other_classified, structural_solids, entrances,
			daylight_voids, transition_seams,
			SettlementFabricAssembler.maze_plaza_threshold_openings(fabric_plan,
				result)):
		return null
	return result

static func _close_borne_court_corners(result: PublicRealmSurfacePlan,
		structural_solids: Dictionary, daylight_voids: Dictionary,
		retained: Dictionary) -> bool:
	var original_courts: Dictionary = {}
	for cell: Vector3i in result.cells_for_kind(
			PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT):
		original_courts[cell] = true
	var candidates: Dictionary = {}
	for cell_value: Variant in original_courts.keys():
		var cell := cell_value as Vector3i
		for direction: Vector3i in CARDINAL_DIRECTIONS:
			candidates[cell + direction] = true
	var ordered: Array[Vector3i] = []
	ordered.assign(candidates.keys())
	ordered.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		return a.y < b.y if a.y != b.y else a.z < b.z \
			if a.z != b.z else a.x < b.x)
	for candidate: Vector3i in ordered:
		if result.has_cell(candidate) \
				or structural_solids.has(_cell_key(candidate)) \
				or structural_solids.has(_cell_key(candidate + Vector3i.UP)) \
				or daylight_voids.has(_cell_key(candidate)) \
				or not retained.has(candidate + Vector3i.DOWN):
			continue
		var closes_corner := false
		for x_direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT]:
			for z_direction: Vector3i in [Vector3i.FORWARD, Vector3i.BACK]:
				if original_courts.has(candidate + x_direction) \
						and original_courts.has(candidate + z_direction) \
						and original_courts.has(candidate + x_direction \
							+ z_direction):
					closes_corner = true
					break
			if closes_corner:
				break
		if not closes_corner:
			continue
		var touches_structure := false
		for direction: Vector3i in CARDINAL_DIRECTIONS:
			if structural_solids.has(_cell_key(candidate + direction)) \
					or structural_solids.has(_cell_key(candidate + direction \
						+ Vector3i.UP)):
				touches_structure = true
				break
		if not touches_structure:
			continue
		if not result.add_derived_claim(candidate,
				PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT,
				StringName("surface-corner-closure/%d/%d/%d" % [candidate.x,
					candidate.y, candidate.z])):
			return false
	return true


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
