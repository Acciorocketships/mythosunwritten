class_name WarrenAssetPlan
extends RefCounted

## Resource-free placed construction vocabulary for every accepted parcel.
## The compiled program supplies measured visual contracts; this plan owns only
## deterministic unit selection, ancestry, and exact placement.
var stable_id: StringName
var town: WarrenTownPlan
var program: SettlementFabricProgram
var roof_topology: FabricRoofTopologyPlan
var units: Array[FabricUnit] = []
var proposals: Array[Dictionary] = []
var audit: Dictionary = {}
var last_rejection := ""
var _unit_recipe: Dictionary = {}
var _sealed := false


func _init(p_stable_id: StringName, p_town: WarrenTownPlan,
		p_program: SettlementFabricProgram) -> void:
	stable_id = p_stable_id
	town = p_town
	program = p_program


func seal(p_proposals: Array[Dictionary],
		p_units: Array[FabricUnit]) -> bool:
	if _sealed or stable_id.is_empty() or town == null \
			or not town.is_sealed() or program == null \
			or p_proposals.size() != town.parcels.parcels.size() \
			or p_units.is_empty():
		return _reject("missing town, program, proposals, or units")
	proposals.assign(p_proposals)
	roof_topology = FabricRoofTopologyPlan.build(proposals)
	if roof_topology == null:
		return _reject("roof topology could not classify every parcel seam")
	var ids: Dictionary = {}
	for unit_value: FabricUnit in p_units:
		var recipe_value := program.recipe(unit_value.recipe_id)
		if unit_value == null or not unit_value.is_valid() \
				or recipe_value == null or ids.has(unit_value.stable_id):
			return _reject("invalid, duplicate, or unknown construction unit")
		ids[unit_value.stable_id] = true
		_unit_recipe[unit_value.stable_id] = recipe_value
		units.append(unit_value)
	var proposal_by_id: Dictionary = {}
	for proposal: Dictionary in proposals:
		proposal_by_id[StringName(proposal.stable_id)] = proposal
	for parcel: WarrenBuildingParcel in town.parcels.parcels:
		var proposal := proposal_by_id.get(parcel.stable_id, {}) as Dictionary
		if proposal.is_empty() or not _proposal_extends_parcel_safely(
				parcel, proposal):
			return _reject("construction envelope leaves its parcel or bearing " \
				+ "reservation %s" %
				parcel.stable_id)
		if not _proposal_entrance_matches(parcel, proposal):
			return _reject("construction entrance differs from public threshold %s" %
				parcel.stable_id)
	var conflicts := visual_envelope_conflicts()
	var assets: Dictionary = {}
	var recipe_families: Dictionary = {}
	var same_theme_neighbors := 0
	var same_roof_material_neighbors := 0
	var same_streetscape_neighbors := 0
	var neighbor_pairs := 0
	var counted_pairs: Dictionary = {}
	var proposal_by_stable_id: Dictionary = {}
	var roof_material_by_proposal: Dictionary = {}
	var roof_material_counts: Dictionary = {}
	var facade_family_counts: Dictionary = {}
	var roof_geometry_families: Dictionary = {}
	var roof_feature_count := 0
	var facade_detail_count := 0
	for proposal: Dictionary in proposals:
		var proposal_id := StringName(proposal.stable_id)
		proposal_by_stable_id[proposal_id] = proposal
		var facade_family := StringName(proposal.get("theme", ""))
		facade_family_counts[facade_family] = int(facade_family_counts.get(
			facade_family, 0)) + 1
		var roof_recipe := _proposal_roof_recipe(proposal)
		if roof_recipe == null:
			return _reject("proposal lacks exactly one primary roof recipe")
		var material_family := _roof_material_family(roof_recipe)
		var geometry_family := _roof_geometry_family(roof_recipe)
		if material_family.is_empty() or geometry_family.is_empty():
			return _reject("primary roof has no classified visual family")
		roof_material_by_proposal[proposal_id] = material_family
		roof_material_counts[material_family] = int(roof_material_counts.get(
			material_family, 0)) + 1
		roof_geometry_families[geometry_family] = true
		roof_feature_count += int(_roof_has_feature(roof_recipe))
	for proposal: Dictionary in proposals:
		var proposal_id := StringName(proposal.stable_id)
		var roof_fact := roof_topology.fact(proposal_id)
		for junction: Dictionary in roof_fact.junctions as Array:
			var neighbor_id := StringName(junction.neighbor_id)
			var pair_ids := [String(proposal_id), String(neighbor_id)]
			pair_ids.sort()
			var pair_key := "%s|%s" % pair_ids
			if counted_pairs.has(pair_key):
				continue
			counted_pairs[pair_key] = true
			neighbor_pairs += 1
			var neighbor := proposal_by_stable_id[neighbor_id] as Dictionary
			var same_theme := StringName(proposal.get("theme", "")) \
				== StringName(neighbor.get("theme", ""))
			same_theme_neighbors += int(same_theme)
			same_roof_material_neighbors += int(StringName(
				roof_material_by_proposal[proposal_id]) == StringName(
					roof_material_by_proposal[neighbor_id]))
			same_streetscape_neighbors += int(same_theme \
				and StringName(proposal.kind) == StringName(neighbor.kind) \
				and int(proposal.get("facade_phase", 0)) \
					== int(neighbor.get("facade_phase", 0)) \
				and int(roof_fact.roof_base_band) \
					== int((roof_topology.fact(neighbor_id)).roof_base_band))
	for unit_value: FabricUnit in units:
		var recipe_value := _unit_recipe[unit_value.stable_id] as FabricRecipe
		facade_detail_count += int(recipe_value.has_tag(&"facade_detail"))
		for asset_id: StringName in recipe_value.asset_ids():
			assets[asset_id] = true
		if recipe_value.has_tag(&"compact_tower"):
			recipe_families[&"tower"] = true
		elif recipe_value.has_tag(&"slim_building"):
			recipe_families[&"slim"] = true
		elif recipe_value.has_tag(&"generated_building"):
			recipe_families[&"building"] = true
	var largest_roof_material_count := 0
	for count_value: Variant in roof_material_counts.values():
		largest_roof_material_count = maxi(largest_roof_material_count,
			int(count_value))
	var largest_facade_family_count := 0
	for count_value: Variant in facade_family_counts.values():
		largest_facade_family_count = maxi(largest_facade_family_count,
			int(count_value))
	audit = {
		"parcel_count": town.parcels.parcels.size(),
		"proposal_count": proposals.size(),
		"unit_count": units.size(),
		"placement_count": expanded_placements().size(),
		"asset_count": assets.size(),
		"recipe_family_count": recipe_families.size(),
		"visual_envelope_conflict_count": conflicts.size(),
		"unmapped_parcel_count": 0,
		"entrance_mismatch_count": 0,
		"roof_topology_signature": roof_topology.deterministic_signature(),
		"roof_junction_count": int(roof_topology.audit.junction_count),
		"perpendicular_roof_junction_count": int(
			roof_topology.audit.perpendicular_valley_count),
		"joined_roof_count": int(roof_topology.audit.joined_roof_count),
		"isolated_roof_count": int(roof_topology.audit.isolated_roof_count),
		"neighbor_pair_count": neighbor_pairs,
		"same_theme_neighbor_count": same_theme_neighbors,
		"facade_family_count": facade_family_counts.size(),
		"largest_facade_family_count": largest_facade_family_count,
		"largest_facade_family_ratio": float(largest_facade_family_count) \
			/ float(maxi(proposals.size(), 1)),
		"same_roof_material_neighbor_count": same_roof_material_neighbors,
		"roof_material_family_count": roof_material_counts.size(),
		"roof_geometry_family_count": roof_geometry_families.size(),
		"roof_feature_count": roof_feature_count,
		"facade_detail_count": facade_detail_count,
		"largest_roof_material_family_count": largest_roof_material_count,
		"largest_roof_material_family_ratio": float(
			largest_roof_material_count) / float(maxi(proposals.size(), 1)),
		"same_streetscape_neighbor_count": same_streetscape_neighbors,
	}
	_sealed = true
	return true


func is_sealed() -> bool:
	return _sealed


func deterministic_signature() -> String:
	var parts := PackedStringArray()
	for proposal: Dictionary in proposals:
		parts.append("%s/%s/%s/r%d/s%d/%s/%s/f%d/%s" % [StringName(proposal.stable_id),
			StringName(proposal.kind), proposal.origin,
			int(proposal.yaw_quarters), int(proposal.storeys),
			StringName(proposal.get("theme", "")),
			StringName(proposal.get("roof_theme", "")),
			int(proposal.get("facade_phase", 0)),
			StringName(proposal.get("roof_signature", "isolated"))])
	parts.sort()
	return "%s|%s" % [town.deterministic_signature(), ",".join(parts)]


func expanded_placements() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for unit_value: FabricUnit in units:
		var recipe_value := _unit_recipe[unit_value.stable_id] as FabricRecipe
		for placement: Dictionary in recipe_value.placements:
			out.append({
				"stable_id": StringName("%s/%s" % [unit_value.stable_id,
					StringName(placement.id)]),
				"asset_id": StringName(placement.asset_id),
				"transform": unit_value.transform() \
					* (placement.transform as Transform3D),
			})
	return out


func _proposal_roof_recipe(proposal: Dictionary) -> FabricRecipe:
	var found: FabricRecipe
	for component: Dictionary in StaggeredFabricCompiler.proposal_components(
			proposal):
		if StringName(component.role) != &"roof":
			continue
		if found != null:
			return null
		found = program.recipe(StringName(component.recipe_id))
	return found


static func _roof_material_family(recipe_value: FabricRecipe) -> StringName:
	var asset_ids := recipe_value.asset_ids()
	if recipe_value.has_tag(&"flat_roof"):
		return &"boarded"
	if asset_ids.has(SettlementFabricProgram.ROOM_ROOF_02) \
			or asset_ids.has(SettlementFabricProgram.ROOM_ROOF_05):
		return &"boarded"
	if asset_ids.has(SettlementFabricProgram.ROOF_BLUE):
		return &"blue_tile"
	if asset_ids.has(SettlementFabricProgram.COMPACT_ROOF_SLATE_03) \
			or asset_ids.has(SettlementFabricProgram.COMPACT_ROOF_SLATE_06):
		return &"blue_tile"
	# The compact 03/06 meshes and both complete LPFV room roofs are genuinely
	# orange. Palette-labelled recipes must therefore use the explicit slate
	# variants above rather than trusting a semantic `.blue` suffix.
	if asset_ids.has(SettlementFabricProgram.ROOF_ORANGE) \
			or asset_ids.has(SettlementFabricProgram.COMPACT_ROOF_03) \
			or asset_ids.has(SettlementFabricProgram.COMPACT_ROOF_06) \
			or asset_ids.has(SettlementFabricProgram.ROOM_ROOF_01) \
			or asset_ids.has(SettlementFabricProgram.ROOM_ROOF_04):
		return &"orange_tile"
	return &""


static func _roof_geometry_family(recipe_value: FabricRecipe) -> StringName:
	if recipe_value.has_tag(&"flat_roof"):
		return &"flat_plank_cap"
	if recipe_value.has_tag(&"dormer"):
		return &"dormered_long_gable"
	if recipe_value.has_tag(&"staggered_roof"):
		return &"staggered_slim_gable"
	if recipe_value.has_tag(&"compact_tower"):
		return &"compact_tower_gable"
	if recipe_value.has_tag(&"long_building"):
		return &"long_modular_gable"
	if recipe_value.has_tag(&"complete_gable"):
		return &"complete_room_gable"
	if recipe_value.has_tag(&"roof"):
		return &"modular_room_gable"
	return &""


static func _roof_has_feature(recipe_value: FabricRecipe) -> bool:
	return recipe_value.has_tag(&"dormer") \
		or recipe_value.has_tag(&"atomic_roof_junction") \
		or recipe_value.asset_ids().has(SettlementFabricProgram.COMPACT_CHIMNEY)


func visual_envelope_conflicts() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for left_index in units.size():
		var left := units[left_index]
		var left_recipe := _unit_recipe[left.stable_id] as FabricRecipe
		var left_bounds := left.transform() * left_recipe.local_clearance_bounds
		for right_index in range(left_index + 1, units.size()):
			var right := units[right_index]
			if left.parent_ids.has(right.stable_id) \
					or right.parent_ids.has(left.stable_id) \
					or left.visual_seam_ids.has(right.stable_id) \
					or right.visual_seam_ids.has(left.stable_id):
				continue
			var right_recipe := _unit_recipe[right.stable_id] as FabricRecipe
			var right_bounds := right.transform() \
				* right_recipe.local_clearance_bounds
			if SettlementFabricPlan._aabb_overlaps_volume(left_bounds,
					right_bounds):
				# The same corner-only diagnostic escape the fabric plan
				# honours; this is the third site running the identical test,
				# so leaving it out let a town clear the first two and fail
				# here for a reason that read as a different defect.
				if SettlementFabricPlan.DIAGNOSTIC_ALLOW_CORNER_ENVELOPE_OVERLAP \
						and SettlementFabricPlan._is_corner_nick(left_bounds,
							right_bounds):
					continue
				out.append({
					"left": left.stable_id,
					"right": right.stable_id,
					"left_recipe": left.recipe_id,
					"right_recipe": right.recipe_id,
					"left_bounds": left_bounds,
					"right_bounds": right_bounds,
					"overlap": left_bounds.intersection(right_bounds),
				})
	return out


func _proposal_entrance_matches(parcel: WarrenBuildingParcel,
		proposal: Dictionary) -> bool:
	var components := StaggeredFabricCompiler.proposal_components(proposal)
	if components.is_empty():
		return false
	var matches := 0
	for component: Dictionary in components:
		var recipe_value := program.recipe(StringName(component.recipe_id))
		if recipe_value == null:
			return false
		for entrance: Dictionary in recipe_value.entrances:
			var threshold := FabricRecipe.transform_cell(
				entrance.cell as Vector3i, component.origin as Vector3i,
				int(component.yaw_quarters))
			var facing := FabricRecipe.transform_direction(
				entrance.facing as Vector3i, int(component.yaw_quarters))
			if threshold == WarrenParcelConstruction.threshold_cell(parcel) \
					and facing == Vector3i(parcel.frontage_direction.x, 0,
						parcel.frontage_direction.y):
				matches += 1
	return matches == 1


func _proposal_extends_parcel_safely(parcel: WarrenBuildingParcel,
		proposal: Dictionary) -> bool:
	## The roof and addressed storeys must remain exactly the sealed parcel.
	## Additional lower storeys are legal only in the pruning plan's explicit
	## bearing opportunity, except for one half-band of bounded terrain burial
	## needed to preserve the address phase.
	var expected := _cell_set(_expanded_parcel_cells(parcel))
	var actual_cells := StaggeredFabricCompiler.proposal_occupied_cells(proposal)
	var actual := _cell_set(actual_cells)
	for cell_value: Variant in expected.keys():
		if not actual.has(cell_value):
			return false
	for cell: Vector3i in actual_cells:
		if expected.has(cell):
			continue
		var macro_column := Vector2i(floori(float(cell.x) / 2.0),
			floori(float(cell.z) / 2.0))
		if not parcel.footprint.has(macro_column):
			return false
		var macro_cell := Vector3i(macro_column.x, cell.y, macro_column.y)
		var ground := town.volume.envelope.ground_at(macro_column)
		if cell.y < ground:
			if cell.y != ground - 1:
				return false
		elif not town.pruning.bearing_opportunity_cells.has(macro_cell):
			return false
	return true


static func _same_cells(left: Array[Vector3i],
		right: Array[Vector3i]) -> bool:
	if left.size() != right.size():
		return false
	var right_set: Dictionary = {}
	for cell: Vector3i in right:
		right_set[cell] = true
	for cell: Vector3i in left:
		if not right_set.has(cell):
			return false
	return true


static func _cell_set(cells: Array[Vector3i]) -> Dictionary:
	var out: Dictionary = {}
	for cell: Vector3i in cells:
		out[cell] = true
	return out


static func _expanded_parcel_cells(
		parcel: WarrenBuildingParcel) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for macro_cell: Vector3i in parcel.occupied_cells():
		var origin := Vector3i(macro_cell.x * 2, macro_cell.y,
			macro_cell.z * 2)
		out.append(origin)
		out.append(origin + Vector3i.RIGHT)
		out.append(origin + Vector3i.BACK)
		out.append(origin + Vector3i(1, 0, 1))
	return out


func _reject(reason: String) -> bool:
	last_rejection = reason
	return false
