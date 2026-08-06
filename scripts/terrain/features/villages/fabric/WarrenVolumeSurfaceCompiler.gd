class_name WarrenVolumeSurfaceCompiler
extends RefCounted

## Converts the sealed volumetric route and parcel facts into the common public
## surface union. Horizontal mesh/collision, facade openings, and guards all
## derive from this one classification; construction assets cannot independently
## place a deck, erase a rail, or claim an entrance.
static var last_failure := ""


static func solve(volume: WarrenVolumePlan, realm: SectionalPublicRealmPlan,
		parcels: WarrenParcelPlan,
		pruning: WarrenPrunedMassPlan,
		exact_fabric: SettlementFabricPlan = null) -> PublicRealmSurfacePlan:
	last_failure = ""
	if volume == null or not volume.is_sealed() or realm == null \
			or not realm.is_sealed() or parcels == null \
			or not parcels.is_sealed() or parcels.source != volume \
			or pruning == null or not pruning.is_sealed() \
			or pruning.source != volume or pruning.parcels != parcels:
		last_failure = "missing or mismatched sealed inputs"
		return null
	var result := PublicRealmSurfacePlan.new(
		StringName("%s.surfaces" % volume.stable_id))
	for node_value: PublicRealmNode in realm.nodes:
		for cell: Vector3i in node_value.surface_cells:
			if not result.add_claim(cell, node_value.surface_kind,
					node_value.stable_id):
				last_failure = "surface claim rejected at %s: %s" % [cell,
					result.last_rejection]
				return null
			if node_value.surface_kind \
					== PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT:
				var macro_column := Vector2i(floori(float(cell.x) / 2.0),
					floori(float(cell.z) / 2.0))
				if not result.set_support_base(cell,
						volume.envelope.ground_at(macro_column)):
					last_failure = "support datum rejected at %s: %s" % [cell,
						result.last_rejection]
					return null
	for transition_index in volume.transitions.size():
		var transition := volume.transitions[transition_index]
		if not transition.is_vertical():
			continue
		var node_id := StringName("volume.transition.%02d" % transition_index)
		var transition_node := realm.node(node_id)
		if transition_node == null:
			last_failure = "vertical transition %d has no realm node" % \
				transition_index
			return null
		var payload := WarrenTransitionSurfaceBuilder.build(
			StringName("%s.mesh" % node_id), transition,
			transition_node.surface_cells)
		if payload.is_empty() or not result.add_transition_mesh_payload(payload):
			last_failure = "transition geometry %d rejected: %s" % [
				transition_index, result.last_rejection]
			return null
	var structural_solids := _expanded_structural_solids(pruning.building_cells)
	var entrances := _entrances(parcels)
	if exact_fabric != null:
		# The topology surface and transition meshes stay authoritative, but late
		# exact construction may add a reviewed prefab doorway or alter a guard
		# boundary. Derive those openings from the final units instead of retaining
		# the parcel-only snapshot and then repairing individual rails.
		for cell_value: Variant in exact_fabric.transformed_cells(&"solid"):
			var cell := cell_value as Vector3i
			structural_solids[_cell_key(cell)] = true
		entrances = _fabric_entrances(exact_fabric)
	var daylight_voids := _bounded_daylight_voids(realm,
		pruning.daylight_void_columns, structural_solids)
	var accepted_voids: Dictionary = {}
	for cell: Vector3i in daylight_voids:
		accepted_voids[_cell_key(cell)] = true
	for cell: Vector3i in realm.daylight_void_cells:
		if not accepted_voids.has(_cell_key(cell)):
			last_failure = "explicit daylight void is not bounded at %s" % cell
			return null
	var transition_seams: Array[Dictionary] = []
	for edge_value: PublicRealmEdge in realm.edges:
		for seam: Dictionary in edge_value.seams:
			transition_seams.append(seam.duplicate())
	var required: Array[Vector3i] = []
	required.assign(realm.required_classification_cells)
	var other_classified := structural_solids.duplicate()
	for cell: Vector3i in daylight_voids:
		other_classified[_cell_key(cell)] = true
	if not result.seal(required, other_classified, structural_solids,
			entrances, daylight_voids, transition_seams):
		last_failure = "surface seal rejected: %s" % result.last_rejection
		return null
	return result


static func _expanded_structural_solids(
		macro_solids: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for value: Variant in macro_solids.keys():
		var macro_cell := value as Vector3i
		for cell: Vector3i in _expand_macro_cell(macro_cell):
			out[_cell_key(cell)] = true
	return out


static func _entrances(parcels: WarrenParcelPlan) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for parcel: WarrenBuildingParcel in parcels.parcels:
		var facing := Vector3i(parcel.frontage_direction.x, 0,
			parcel.frontage_direction.y)
		var threshold := _threshold_cell(parcel, facing)
		out.append({
			"stable_id": StringName("%s.entrance" % parcel.stable_id),
			"unit_id": WarrenParcelConstruction.addressed_unit_id(parcel),
			"threshold_cell": threshold,
			"facing": facing,
			"landing_cell": threshold + facing,
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.stable_id) < String(b.stable_id))
	return out


static func _fabric_entrances(plan: SettlementFabricPlan) \
		-> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for unit_value: FabricUnit in plan.units:
		var recipe_value := plan.recipe(unit_value.recipe_id)
		for entrance: Dictionary in recipe_value.entrances:
			var threshold := FabricRecipe.transform_cell(
				entrance.cell as Vector3i, unit_value.lattice_origin,
				unit_value.yaw_quarters)
			var facing := FabricRecipe.transform_direction(
				entrance.facing as Vector3i, unit_value.yaw_quarters)
			out.append({
				"stable_id": StringName("%s/%s" % [unit_value.stable_id,
					StringName(entrance.id)]),
				"unit_id": unit_value.stable_id,
				"threshold_cell": threshold,
				"facing": facing,
				"landing_cell": threshold + facing,
			})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.stable_id) < String(b.stable_id))
	return out


static func _threshold_cell(parcel: WarrenBuildingParcel,
		facing: Vector3i) -> Vector3i:
	var threshold := WarrenParcelConstruction.threshold_cell(parcel)
	assert(threshold.x != 2147483647)
	assert(FabricRecipe.transform_direction(Vector3i.BACK,
		int(WarrenParcelConstruction.proposal(parcel).yaw_quarters)) == facing)
	return threshold


static func _bounded_daylight_voids(realm: SectionalPublicRealmPlan,
		macro_void_columns: Dictionary,
		structural_solids: Dictionary) -> Array[Vector3i]:
	var surface_cells: Dictionary = {}
	var guardable_surface_cells: Dictionary = {}
	for node_value: PublicRealmNode in realm.nodes:
		for cell: Vector3i in node_value.surface_cells:
			surface_cells[_cell_key(cell)] = true
			if node_value.surface_kind \
					== PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT:
				guardable_surface_cells[_cell_key(cell)] = true
	var exact_voids: Dictionary = {}
	for cell: Vector3i in realm.daylight_void_cells:
		exact_voids[_cell_key(cell)] = cell
	var candidates: Dictionary = {}
	for node_value: PublicRealmNode in realm.nodes:
		if node_value.surface_kind \
				!= PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT:
			continue
		for cell: Vector3i in node_value.surface_cells:
			for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
					Vector3i.FORWARD, Vector3i.BACK]:
				var neighbor := cell + direction
				var macro_column := Vector2i(
					floori(float(neighbor.x) / 2.0),
					floori(float(neighbor.z) / 2.0))
				if macro_void_columns.has(macro_column):
					candidates["%d:%d:%d" % [macro_column.x, cell.y,
						macro_column.y]] = {
						"column": macro_column,
						"y": cell.y,
					}
	var unique: Dictionary = {}
	var out: Array[Vector3i] = []
	for exact_value: Variant in exact_voids.values():
		var exact_cell := exact_value as Vector3i
		var bounded := true
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.FORWARD, Vector3i.BACK]:
			var neighbor := exact_cell + direction
			var neighbor_key := _cell_key(neighbor)
			# PublicRealmSurfacePlan derives fall guards from structural courts;
			# terrain streets are ground paint and cannot bound a hole at this
			# elevation. Accepting any surface here produced a logically bounded
			# void whose later guard audit still had an exposed edge.
			if not guardable_surface_cells.has(neighbor_key) \
					and not structural_solids.has(neighbor_key) \
					and not structural_solids.has(_cell_key(
						neighbor + Vector3i.UP)):
				bounded = false
				break
		if not bounded:
			continue
		unique[_cell_key(exact_cell)] = true
		out.append(exact_cell)
	for candidate_value: Variant in candidates.values():
		var candidate := candidate_value as Dictionary
		var column := candidate.column as Vector2i
		var y := int(candidate.y)
		var void_cells := _expand_macro_cell(Vector3i(column.x, y, column.y))
		var void_set: Dictionary = {}
		var overlaps_surface := false
		for cell: Vector3i in void_cells:
			void_set[_cell_key(cell)] = true
			overlaps_surface = overlaps_surface \
				or surface_cells.has(_cell_key(cell))
		# Platform infill may consume three quarters of an otherwise open macro
		# column. Its exact remaining lightwell is already a realm fact; never
		# recreate the old four-cell hole through the new platform.
		if overlaps_surface:
			continue
		var bounded := true
		for cell: Vector3i in void_cells:
			for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
					Vector3i.FORWARD, Vector3i.BACK]:
				var neighbor := cell + direction
				var neighbor_key := _cell_key(neighbor)
				if void_set.has(neighbor_key):
					continue
				if not guardable_surface_cells.has(neighbor_key) \
						and not structural_solids.has(neighbor_key) \
						and not structural_solids.has(_cell_key(
							neighbor + Vector3i.UP)):
					bounded = false
					break
			if not bounded:
				break
		if not bounded:
			continue
		for cell: Vector3i in void_cells:
			var key := _cell_key(cell)
			if not unique.has(key):
				unique[key] = true
				out.append(cell)
	out.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		if a.y != b.y:
			return a.y < b.y
		if a.z != b.z:
			return a.z < b.z
		return a.x < b.x)
	return out


static func _expand_macro_cell(cell: Vector3i) -> Array[Vector3i]:
	var origin := Vector3i(cell.x * 2, cell.y, cell.z * 2)
	return [origin, origin + Vector3i.RIGHT, origin + Vector3i.BACK,
		origin + Vector3i(1, 0, 1)] as Array[Vector3i]


static func _cell_key(cell: Vector3i) -> String:
	return "%d:%d:%d" % [cell.x, cell.y, cell.z]
