class_name WarrenFabricCompiler
extends RefCounted

## Adapts one already-sealed volumetric town and its exact construction into
## the common settlement fabric transaction. Public routes remain owned by the
## authoritative surface payload, including collision-bearing ramps/stairs;
## buildings enter through ordinary recipes, occupancy, exterior-air, and
## solid/void validation used by every other settlement implementation.
static var last_failure := ""


static func solve(assets: WarrenAssetPlan,
		additional_specs: Array[Dictionary] = []) -> SettlementFabricPlan:
	last_failure = ""
	if assets == null or not assets.is_sealed() or assets.program == null:
		last_failure = "missing sealed volumetric construction"
		return null
	var town := assets.town
	var result := SettlementFabricPlan.new(
		StringName("%s.fabric" % assets.stable_id))
	if not result.set_public_realm(town.public_realm):
		last_failure = "could not attach authoritative public realm"
		return null
	for recipe_value: FabricRecipe in assets.program.recipes():
		if not result.register_recipe(recipe_value):
			last_failure = "could not register recipe %s" % recipe_value.recipe_id
			return null
	for unit_value: FabricUnit in assets.units:
		if not result.add_unit(unit_value):
			last_failure = "construction unit %s rejected: %s" % [
				unit_value.stable_id, result.last_rejection]
			return null
	for spec: Dictionary in additional_specs:
		var unit_value := _unit_from_spec(spec)
		if unit_value == null or not result.add_unit(unit_value):
			last_failure = "detail unit %s rejected: %s" % [
				StringName(spec.get("stable_id", "<missing>")),
				result.last_rejection]
			return null
	var exact_surfaces := WarrenVolumeSurfaceCompiler.solve(town.volume,
		town.public_realm, town.parcels, town.pruning, result)
	if exact_surfaces == null or not result.set_surface_plan(exact_surfaces):
		last_failure = "could not derive exact construction surfaces: %s" % \
			WarrenVolumeSurfaceCompiler.last_failure
		return null
	var volume := FabricVolumeClassifier.solve(
		StringName("%s.volumes" % assets.stable_id), town.public_realm, result)
	if volume == null or not result.set_volume_plan(volume):
		last_failure = "exterior-air classification failed: %s" % \
			FabricVolumeClassifier.last_failure
		return null
	var solid_void := FabricSolidVoidClassifier.solve(
		StringName("%s.solid-void" % assets.stable_id), town.public_realm, result)
	if solid_void == null or not result.set_solid_void_plan(solid_void):
		last_failure = "solid/void classification failed: %s" % \
			FabricSolidVoidClassifier.last_failure
		return null
	if not result.set_retained_terrace(_retained_terrace(town, result)):
		last_failure = "retained terrace overlaps built mass"
		return null
	var lineage_audit := assets.audit.duplicate(true)
	lineage_audit.merge(town.audit, true)
	lineage_audit.merge(exact_surfaces.audit(), true)
	lineage_audit.merge(volume.audit(), true)
	lineage_audit.merge(solid_void.audit(), true)
	lineage_audit["maze_route_signature"] = \
		town.volume.deterministic_signature().sha256_text()
	lineage_audit["maze_canonical_route_signature"] = \
		town.volume.canonical_deterministic_signature().sha256_text()
	lineage_audit["construction_signature"] = result.construction_signature()
	lineage_audit["generation_source"] = &"volumetric_warren"
	var audit := SettlementFabricSolver.audit_plan(result, lineage_audit)
	if not result.seal(audit):
		last_failure = "common fabric seal failed: %s" % result.last_rejection
		return null
	return result


static func _retained_terrace(town: WarrenTownPlan,
		plan: SettlementFabricPlan) -> Dictionary:
	## Every cell of the standing solid that is not a building: the hill the
	## town is cut into, at construction resolution.
	##
	## The per-parcel declaration alone renders only the plinth directly under a
	## raised house, which leaves the other ~250 massif columns invisible -- so
	## a house's plinth stands as an isolated stone face however short the
	## massif's own steps are, and the excavated street, whose covered majority
	## the carver's cover gate guarantees, has no mass drawn around or above it
	## and reads as an open trench. Rendering the whole remainder is what makes
	## the massif's MAX_NEIGHBOR_STEP_BANDS silhouette visible: no exposed stone
	## face can then exceed one riser, because the mass one cell over is drawn
	## too, and a covered route cell becomes a passage with stone beside and
	## overhead.
	##
	## MASS-FIRST ONLY, keyed on the massif provenance the excavation adapter
	## attaches and nothing else sets. A route-first town's Gaussian mass is
	## deliberately NOT rock (see WarrenPrunedMassPlan's header) and this must
	## not start rendering it.
	var out: Dictionary = {}
	if town == null or town.parcels == null:
		return out
	for parcel: WarrenBuildingParcel in town.parcels.parcels:
		for cell: Vector3i in WarrenParcelConstruction.retained_terrace_cells(
				parcel):
			out[cell] = true
	if town.volume == null or not town.volume.mass_context.has(&"massif"):
		return out
	var solids := plan.transformed_cells(&"solid")
	var macro_cells: Array[Vector3i] = []
	macro_cells.assign(town.volume.mass_cells.keys())
	macro_cells.sort()
	for macro_cell: Vector3i in macro_cells:
		for x_offset in 2:
			for z_offset in 2:
				var cell := Vector3i(macro_cell.x * 2 + x_offset, macro_cell.y,
					macro_cell.z * 2 + z_offset)
				if solids.has(cell):
					continue
				out[cell] = true
	return out


static func _unit_from_spec(spec: Dictionary) -> FabricUnit:
	var parents: Array[StringName] = []
	for value: Variant in spec.get("parents", []):
		parents.append(StringName(value))
	var bonds: Array[Dictionary] = []
	for value: Variant in spec.get("bonds", []):
		bonds.append((value as Dictionary).duplicate())
	var seams: Array[StringName] = []
	for value: Variant in spec.get("visual_seams", []):
		seams.append(StringName(value))
	var result := FabricUnit.new(StringName(spec.get("stable_id", "")),
		StringName(spec.get("recipe_id", "")),
		spec.get("origin", Vector3i()) as Vector3i,
		int(spec.get("yaw_quarters", -1)), parents, bonds,
		StringName(spec.get("public_node_id", "")), seams)
	return result if result.is_valid() else null
