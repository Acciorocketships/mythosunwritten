class_name WarrenSpatialFabricCompiler
extends RefCounted

## Measured-construction adapter for the authoritative 3D town.  This initial
## phase realizes every exact WarrenRoomStamp and its true bearing/party-wall
## relationships. Composed features are then realized from their already-sealed
## construction records before roofs are selected around the resulting measured
## envelopes. No method here may move, resize, or restamp the spatial topology.
static var last_failure := ""
static var last_audit: Dictionary = {}

## Facade and roof colour is owned by a jittered architectural district rather
## than hashed independently per room. Twelve fine cells are 18 m: large enough
## for neighbouring storeys and party-wall houses to read as one historical
## quarter, but small enough for even the compact town to contain several
## palettes. Jittered Voronoi ownership avoids visible square zoning seams.
const ARCHITECTURAL_DISTRICT_CELLS := 12
const ARCHITECTURAL_DISTRICT_JITTER := 4
## Maximum measured horizontal penetration for a thin setback cap to become
## typed facade flashing. Half a 1.5 m fine cell plus 0.15 m of authored-frame
## tolerance closes the reviewed projecting facades while remaining well below
## a whole room cell. Height has its own much tighter thin-cap limit below.
const SHALLOW_FLASHING_MAX_OVERLAP_M := 0.90
const SHALLOW_FLASHING_MAX_HEIGHT_M := 0.25


static func solve(source: WarrenSpatialPlan,
		program: SettlementFabricProgram) -> SettlementFabricPlan:
	## Compile the authoritative spatial town through the same sealed fabric,
	## surface, exterior-air, and solid/void transaction used by production.
	## Nothing in this adapter may infer a replacement footprint or route.
	last_failure = ""
	last_audit = {}
	if source == null or not source.is_sealed() or program == null:
		last_failure = "missing sealed spatial town or measured vocabulary"
		return null
	var realm := WarrenSpatialPublicRealmAdapter.from_spatial(source)
	if realm == null:
		last_failure = "public realm adaptation failed: %s" % \
			WarrenSpatialPublicRealmAdapter.last_failure
		return null
	var rooms := source.compiled_room_units_cache()
	var room_audit := source.compiled_room_audit_cache()
	if rooms.is_empty():
		rooms = compile_room_units(source, program)
		if rooms.is_empty():
			return null
		room_audit = last_audit.duplicate(true)
		source.cache_compiled_room_units(rooms, room_audit)
	var features := compile_feature_units(source, program, rooms)
	if features.is_empty() and _constructed_feature_count(source) > 0:
		return null
	var feature_audit := last_audit.duplicate(true)
	var roofs := compile_roof_units(source, program, rooms, features)
	if roofs.is_empty():
		return null
	var roof_audit := last_audit.duplicate(true)
	var result := SettlementFabricPlan.new(StringName("%s.fabric" % \
		source.stable_id))
	if not result.set_public_realm(realm):
		last_failure = "could not attach authoritative spatial public realm"
		return null
	for recipe: FabricRecipe in program.recipes():
		if not result.register_recipe(recipe):
			last_failure = "could not register recipe %s" % recipe.recipe_id
			return null
	for unit: FabricUnit in rooms:
		if not result.add_unit(unit):
			last_failure = "room %s rejected by common fabric: %s" % [
				unit.stable_id, result.last_rejection]
			return null
	for unit: FabricUnit in features:
		if not result.add_unit(unit):
			last_failure = "feature component %s rejected by common fabric: %s" % [
				unit.stable_id, result.last_rejection]
			return null
	for unit: FabricUnit in roofs:
		if not result.add_unit(unit):
			last_failure = "roof %s rejected by common fabric: %s" % [
				unit.stable_id, result.last_rejection]
			return null
	var surfaces := PublicRealmSurfaceSolver.solve(
		StringName("%s.surfaces" % result.stable_id), realm, result)
	if surfaces == null or not result.set_surface_plan(surfaces):
		last_failure = "spatial public-surface closure failed"
		return null
	var volumes := FabricVolumeClassifier.solve(
		StringName("%s.volumes" % result.stable_id), realm, result)
	if volumes == null or not result.set_volume_plan(volumes):
		last_failure = "spatial exterior-air proof failed: %s" % \
			FabricVolumeClassifier.last_failure
		return null
	var solid_void := FabricSolidVoidClassifier.solve(
		StringName("%s.solid-void" % result.stable_id), realm, result)
	if solid_void == null or not result.set_solid_void_plan(solid_void):
		last_failure = "spatial solid/void proof failed: %s" % \
			FabricSolidVoidClassifier.last_failure
		return null
	var lineage := source.audit.duplicate(true)
	lineage.merge(source.construction_plan.audit, true)
	lineage.merge(room_audit, true)
	lineage.merge(feature_audit, true)
	lineage.merge(roof_audit, true)
	lineage.merge(volumes.audit(), true)
	lineage.merge(solid_void.audit(), true)
	lineage["spatial_signature"] = source.deterministic_signature().sha256_text()
	lineage["construction_signature"] = result.construction_signature()
	lineage["generation_source"] = &"spatial_volumetric_warren"
	var audit := SettlementFabricSolver.audit_plan(result, lineage)
	# Preserve the generic unit-name grouping as a diagnostic, but do not let it
	# replace the source plan's explicit private-access proof. Recomposition makes
	# one WarrenBuildingVolume per connected 3D owner, and its parent links are the
	# only authoritative statement that an unaddressed segment reaches a doorway.
	for key: StringName in [&"building_stack_count",
			&"connected_building_stack_count", &"detached_building_stack_count"]:
		audit[StringName("legacy_unit_group_%s" % key)] = audit.get(key, -1)
		audit[key] = source.audit.get(key, -1)
	if not result.seal(audit):
		last_failure = "spatial common-fabric seal failed: %s" % \
			result.last_rejection
		return null
	last_audit = audit
	return result


static func compile_room_units(source: WarrenSpatialPlan,
		program: SettlementFabricProgram) -> Array[FabricUnit]:
	last_failure = ""
	last_audit = {}
	if source == null or not source.is_sealed() or program == null:
		last_failure = "missing sealed spatial plan or measured vocabulary"
		return [] as Array[FabricUnit]
	var rooms: Array[WarrenRoomStamp] = []
	var building_by_room: Dictionary = {}
	var room_by_id: Dictionary = {}
	for building: WarrenBuildingVolume in source.buildings:
		for room: WarrenRoomStamp in building.room_records:
			rooms.append(room)
			building_by_room[room.stable_id] = building.stable_id
			room_by_id[room.stable_id] = room
	rooms.sort_custom(func(a: WarrenRoomStamp, b: WarrenRoomStamp) -> bool:
		if a.lattice_origin.y != b.lattice_origin.y:
			return a.lattice_origin.y < b.lattice_origin.y
		if a.source_storey_index != b.source_storey_index:
			return a.source_storey_index < b.source_storey_index
		return String(a.stable_id) < String(b.stable_id))
	var room_by_source_level: Dictionary = {}
	var room_by_private_cell: Dictionary = {}
	var room_id_by_private_cell: Dictionary = {}
	for room: WarrenRoomStamp in rooms:
		var key := _source_level_key(room.source_parcel_id,
			room.source_storey_index)
		if room_by_source_level.has(key):
			last_failure = "two rooms own source level %s" % key
			return [] as Array[FabricUnit]
		room_by_source_level[key] = room
		for cell: Vector3i in room.private_cells:
			room_by_private_cell[cell] = room
			room_id_by_private_cell[cell] = room.stable_id
	# Roof faces are already authoritative plan facts at this point. Reserve the
	# smallest measured construction that can close each face (flat full plate or
	# plain setback cap) before choosing optional phase-B facade projections.
	# Without this ordering a bay/laundry/sign detail can be legal against every
	# room, then make an unrelated roof impossible several compiler phases later.
	var required_roof_clearance := _required_roof_clearance(source, program,
		rooms, room_id_by_private_cell)
	var feature_portal_masks := _feature_portal_masks(source, room_by_id)
	if not last_failure.is_empty():
		return [] as Array[FabricUnit]
	var feature_portal_opening_count := 0
	for mask_value: Variant in feature_portal_masks.values():
		feature_portal_opening_count += _feature_portal_bit_count(int(mask_value))
	var units: Array[FabricUnit] = []
	var unit_by_room: Dictionary = {}
	var prior_unit_by_cell: Dictionary = {}
	var desired_phase_b_count := 0
	var selected_phase_b_count := 0
	var facade_phase_fallback_count := 0
	var hero_feature_facade_fallback_count := 0
	var roof_clearance_facade_fallback_count := 0
	var physical_support_redirect_count := 0
	var suppressed_party_wall_module_count := 0
	var facade_family_counts: Dictionary = {}
	var room_probe := SettlementFabricPlan.new(&"spatial.room-phase-selection")
	for recipe_value: FabricRecipe in program.recipes():
		if not room_probe.register_recipe(recipe_value):
			last_failure = "room phase selection could not register %s" \
				% recipe_value.recipe_id
			return [] as Array[FabricUnit]
	for room: WarrenRoomStamp in rooms:
		var feature_portal_mask := int(feature_portal_masks.get(room.stable_id, 0))
		var recipe_id := _room_recipe_id(room, source.world_seed, true,
			feature_portal_mask)
		var desired_phase_b := _is_phase_b_recipe(recipe_id)
		desired_phase_b_count += int(desired_phase_b)
		var recipe := program.recipe(recipe_id)
		if recipe == null or not _recipe_stays_inside_stamp(recipe, room):
			last_failure = "measured recipe %s changes room stamp %s" % [
				recipe_id, room.stable_id]
			return [] as Array[FabricUnit]
		if not _entrance_matches(recipe, room):
			var entrance := (recipe.entrances[0] as Dictionary) \
				if recipe != null and recipe.entrances.size() == 1 else {}
			var actual_cell := FabricRecipe.transform_cell(
				entrance.get("cell", Vector3i.ZERO) as Vector3i,
				room.lattice_origin, room.yaw_quarters) if not entrance.is_empty() \
				else Vector3i(2147483647, 2147483647, 2147483647)
			var actual_facing := FabricRecipe.transform_direction(
				entrance.get("facing", Vector3i.ZERO) as Vector3i,
				room.yaw_quarters) if not entrance.is_empty() else Vector3i.ZERO
			last_failure = ("measured doorway in %s changes threshold for %s " \
				+ "kind=%s phase=%d yaw=%d expected=%s/%s actual=%s/%s") % [
				recipe_id, room.stable_id, room.kind, room.address_door_phase,
				room.yaw_quarters, room.threshold_cell, room.frontage_direction,
				actual_cell, actual_facing]
			return [] as Array[FabricUnit]
		var parents: Array[StringName] = []
		var bonds: Array[Dictionary] = []
		if not room.terrain_bearing:
			var parent_key := _source_level_key(
				room.support_parent_parcel_id,
				room.support_parent_storey_index)
			var lineage_parent := room_by_source_level.get(parent_key) \
				as WarrenRoomStamp
			var parent_room := _physical_support_parent(room,
				room_by_private_cell, lineage_parent)
			if parent_room == null or not unit_by_room.has(parent_room.stable_id):
				last_failure = "room %s has no built support parent %s" % [
					room.stable_id, parent_key]
				return [] as Array[FabricUnit]
			physical_support_redirect_count += int(lineage_parent != null \
				and parent_room.stable_id != lineage_parent.stable_id)
			var parent_unit := unit_by_room[parent_room.stable_id] as FabricUnit
			var bearing := _bearing_bond(room, parent_room, parent_unit.stable_id)
			if bearing.is_empty():
				last_failure = "offset room %s has no exact bearing overlap" % \
					room.stable_id
				return [] as Array[FabricUnit]
			parents.append(parent_unit.stable_id)
			bonds.append(bearing)
		var seams := _prior_visual_seam_units(source.grid, room,
			prior_unit_by_cell, building_by_room, room_probe, recipe)
		var suppressed := _suppressed_party_wall_placements(source.grid,
			room, recipe)
		var unit := FabricUnit.new(StringName("spatial.fabric.%s" % room.stable_id),
			recipe_id, room.lattice_origin, room.yaw_quarters, parents, bonds,
			&"", seams, suppressed)
		if not unit.is_valid():
			last_failure = "room %s produced an invalid fabric unit" % room.stable_id
			return [] as Array[FabricUnit]
		var feature_conflict := _room_feature_envelope_conflict(source,
			program, room, recipe)
		var roof_conflict := _room_required_roof_conflict(room, recipe,
			required_roof_clearance)
		var desired_rejection := "visual envelope intersects unrelated feature %s" \
			% feature_conflict if not feature_conflict.is_empty() \
			else "visual envelope intersects required roof %s" % roof_conflict \
			if not roof_conflict.is_empty() else ""
		var desired_added := feature_conflict.is_empty() \
			and roof_conflict.is_empty() \
			and room_probe.add_unit(unit)
		if not desired_added:
			if desired_rejection.is_empty():
				desired_rejection = room_probe.last_rejection
			var fallback_id := _room_recipe_id(room, source.world_seed, false,
				feature_portal_mask)
			if fallback_id == recipe_id:
				last_audit["room_phase_failure"] = \
					_room_phase_failure_audit(room, recipe, seams,
						room_probe, unit_by_room, room_by_id, source.grid)
				last_failure = "room %s failed measured phase selection: %s" % [
					room.stable_id, desired_rejection]
				return [] as Array[FabricUnit]
			var fallback_recipe := program.recipe(fallback_id)
			if fallback_recipe == null \
					or not _recipe_stays_inside_stamp(fallback_recipe, room) \
					or not _entrance_matches(fallback_recipe, room):
				last_failure = "room %s has no measured facade fallback" \
					% room.stable_id
				return [] as Array[FabricUnit]
			suppressed = _suppressed_party_wall_placements(source.grid,
				room, fallback_recipe)
			unit = FabricUnit.new(unit.stable_id, fallback_id,
				room.lattice_origin, room.yaw_quarters, parents, bonds, &"", seams,
				suppressed)
			var fallback_conflict := _room_feature_envelope_conflict(source,
				program, room, fallback_recipe)
			var fallback_roof_conflict := _room_required_roof_conflict(room,
				fallback_recipe, required_roof_clearance)
			if not unit.is_valid() or not fallback_conflict.is_empty() \
					or not fallback_roof_conflict.is_empty() \
					or not room_probe.add_unit(unit):
				last_audit["room_phase_failure"] = \
					_room_phase_failure_audit(room, fallback_recipe, seams,
						room_probe, unit_by_room, room_by_id, source.grid)
				var fallback_rejection := \
					"visual envelope intersects unrelated feature %s" \
						% fallback_conflict if not fallback_conflict.is_empty() \
					else "visual envelope intersects required roof %s" \
						% fallback_roof_conflict \
						if not fallback_roof_conflict.is_empty() \
					else room_probe.last_rejection
				last_failure = "room %s fallback failed measured phase selection: %s" \
					% [room.stable_id, fallback_rejection]
				return [] as Array[FabricUnit]
			facade_phase_fallback_count += 1
			hero_feature_facade_fallback_count += int(
				not feature_conflict.is_empty())
			roof_clearance_facade_fallback_count += int(
				not roof_conflict.is_empty())
		selected_phase_b_count += int(_is_phase_b_recipe(unit.recipe_id))
		suppressed_party_wall_module_count += \
			unit.suppressed_placement_ids.size()
		var facade_family := _room_recipe_facade_family(unit.recipe_id)
		facade_family_counts[facade_family] = int(
			facade_family_counts.get(facade_family, 0)) + 1
		units.append(unit)
		unit_by_room[room.stable_id] = unit
		for cell: Vector3i in room.private_cells:
			prior_unit_by_cell[cell] = unit.stable_id
	last_audit = {
		"desired_facade_phase_b_count": desired_phase_b_count,
		"selected_facade_phase_b_count": selected_phase_b_count,
		"facade_phase_fallback_count": facade_phase_fallback_count,
		"facade_phase_a_count": units.size() - selected_phase_b_count,
		"hero_feature_facade_fallback_count": \
			hero_feature_facade_fallback_count,
		"roof_clearance_facade_fallback_count": \
			roof_clearance_facade_fallback_count,
		"required_roof_clearance_envelope_count": \
			required_roof_clearance.size(),
		"physical_support_redirect_count": physical_support_redirect_count,
		"suppressed_party_wall_module_count": \
			suppressed_party_wall_module_count,
		"feature_portal_room_count": feature_portal_masks.size(),
		"feature_portal_opening_count": feature_portal_opening_count,
		"facade_family_counts": facade_family_counts,
	}
	return units


static func _room_phase_failure_audit(room: WarrenRoomStamp,
		recipe: FabricRecipe, declared_seams: Array[StringName],
		probe: SettlementFabricPlan, unit_by_room: Dictionary,
		room_by_id: Dictionary, grid: WarrenSpatialGrid) -> Dictionary:
	var bounds := FabricRecipe.lattice_transform(room.lattice_origin,
		room.yaw_quarters) * recipe.local_clearance_bounds
	var overlaps: Array[Dictionary] = []
	for prior_room_value: Variant in unit_by_room.keys():
		var prior_room_id := StringName(prior_room_value)
		var prior_unit := unit_by_room[prior_room_id] as FabricUnit
		var prior_recipe := probe.recipe(prior_unit.recipe_id)
		if prior_recipe == null:
			continue
		var prior_bounds := prior_unit.transform() \
			* prior_recipe.local_clearance_bounds
		if not SettlementFabricPlan._aabb_overlaps_volume(bounds, prior_bounds):
			continue
		var prior_room := room_by_id.get(prior_room_id) as WarrenRoomStamp
		var contact_faces: Array[Dictionary] = []
		if prior_room != null:
			for cell: Vector3i in room.private_cells:
				for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
						Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD,
						Vector3i.BACK]:
					if not prior_room.has_private_cell(cell + direction):
						continue
					var claim := grid.face_claim(cell, direction)
					contact_faces.append({"cell": cell, "direction": direction,
						"kind": int(claim.get("kind", -1)),
						"owner": StringName(claim.get("owner_id", &""))})
		overlaps.append({"unit_id": prior_unit.stable_id,
			"room_id": prior_room_id, "recipe_id": prior_unit.recipe_id,
			"bounds": prior_bounds,
			"declared_seam": declared_seams.has(prior_unit.stable_id),
			"edge_nick": SettlementFabricPlan._is_edge_nick(bounds,
				prior_bounds), "contact_faces": contact_faces})
	return {"room_id": room.stable_id, "source_parcel_id": room.source_parcel_id,
		"kind": room.kind, "origin": room.lattice_origin,
		"recipe_id": recipe.recipe_id, "bounds": bounds,
		"declared_seams": declared_seams.duplicate(), "overlaps": overlaps}


static func _required_roof_clearance(source: WarrenSpatialPlan,
		program: SettlementFabricProgram, rooms: Array[WarrenRoomStamp],
		room_id_by_private_cell: Dictionary) -> Array[Dictionary]:
	## Compile a lower bound on the measured roof construction that the sealed
	## face plan must eventually receive. Full exposed plates can always fall back
	## to their exact flat recipe; partial plates can always fall back from a
	## railed terrace to the equivalent plain native cap. These envelopes are not
	## speculative pitched-roof halos: they are the smallest authored closure the
	## final compiler is required to place.
	var out: Array[Dictionary] = []
	var roof_faces_by_room := _roof_faces_by_room(source,
		room_id_by_private_cell)
	for room: WarrenRoomStamp in rooms:
		if not roof_faces_by_room.has(room.stable_id):
			continue
		var face_cells := roof_faces_by_room[room.stable_id] \
			as Array[Vector3i]
		var allowed_room_ids: Dictionary = {room.stable_id: true}
		for cell: Vector3i in room.private_cells:
			for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
					Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD,
					Vector3i.BACK]:
				var neighbor_id := StringName(room_id_by_private_cell.get(
					cell + direction, &""))
				if neighbor_id.is_empty() or neighbor_id == room.stable_id:
					continue
				var claim := source.grid.face_claim(cell, direction)
				if int(claim.get("kind", -1)) \
						== WarrenSpatialGrid.FaceKind.PARTY_WALL:
					allowed_room_ids[neighbor_id] = true
		if _is_full_roof_plate(room, face_cells) \
				and not _touches_public_air(source.grid, face_cells):
			var flat_id := _flat_roof_recipe_id(room)
			var flat_recipe := program.recipe(flat_id)
			if flat_recipe != null:
				var flat_transform := FabricRecipe.lattice_transform(
					room.lattice_origin + Vector3i.UP \
						* WarrenSpatialGrid.STOREY_CELLS,
					room.yaw_quarters)
				out.append({"owner_room_id": room.stable_id,
					"recipe_id": flat_id,
					"bounds": flat_transform \
						* flat_recipe.local_clearance_bounds,
					"allowed_room_ids": allowed_room_ids})
			continue
		for piece_value: Variant in _cap_pieces(face_cells):
			var piece := piece_value as Dictionary
			var reserve_rows: Array[Array] = []
			if StringName(piece.kind) == &"stamp":
				reserve_rows = _terminal_cap_rows(
					piece.cells as Array[Vector3i])
			else:
				reserve_rows.append(piece.cells as Array[Vector3i])
			for row: Array[Vector3i] in reserve_rows:
				var cap := _cap_placement(source.grid, row, room,
					source.world_seed)
				if cap.is_empty():
					continue
				var cap_recipe := program.recipe(StringName(cap.recipe_id))
				if cap_recipe == null:
					continue
				var cap_transform := FabricRecipe.lattice_transform(
					cap.origin as Vector3i, int(cap.yaw_quarters))
				out.append({"owner_room_id": room.stable_id,
					"recipe_id": StringName(cap.recipe_id),
					"bounds": cap_transform * cap_recipe.local_clearance_bounds,
					"allowed_room_ids": allowed_room_ids})
	return out


static func _room_required_roof_conflict(room: WarrenRoomStamp,
		recipe: FabricRecipe, required_roof_clearance: Array[Dictionary]) \
		-> StringName:
	if room == null or recipe == null or recipe.placements.is_empty():
		return &""
	var room_bounds := FabricRecipe.lattice_transform(room.lattice_origin,
		room.yaw_quarters) * recipe.local_clearance_bounds
	for roof: Dictionary in required_roof_clearance:
		if (roof.allowed_room_ids as Dictionary).has(room.stable_id):
			continue
		if _aabb_overlaps_volume(room_bounds, roof.bounds as AABB):
			return StringName("%s/%s" % [roof.owner_room_id,
				roof.recipe_id])
	return &""


static func _aabb_overlaps_volume(left: AABB, right: AABB,
		epsilon: float = 0.10) -> bool:
	# Keep this identical to SettlementFabricPlan's measured-envelope policy.
	# This is an early ordering gate, not a looser second definition of contact.
	var overlap_x := minf(left.end.x, right.end.x) \
		- maxf(left.position.x, right.position.x)
	var overlap_y := minf(left.end.y, right.end.y) \
		- maxf(left.position.y, right.position.y)
	var overlap_z := minf(left.end.z, right.end.z) \
		- maxf(left.position.z, right.position.z)
	return overlap_x > epsilon and overlap_y > epsilon and overlap_z > epsilon


static func _feature_portal_masks(source: WarrenSpatialPlan,
		room_by_id: Dictionary) -> Dictionary:
	## Reduce sealed feature endpoints into local room-face masks before any room
	## recipe is selected. The feature geometry is already authoritative here;
	## the compiler is only choosing the finite shell variant that tells the same
	## story visually and in its solid/headroom layers.
	var out: Dictionary = {}
	for feature: WarrenFeatureReservation in source.features:
		if feature.construction_records.is_empty():
			continue
		if feature.kind in [&"tower_annex", &"facade_bay"]:
			var room_id := StringName(feature.audit.get("annex_room_id", &""))
			if room_id.is_empty() or feature.endpoints.size() != 1:
				last_failure = "%s %s lacks one portal endpoint" % [
					feature.kind, feature.stable_id]
				return {}
			var facing := feature.audit.get("annex_endpoint_facing",
				Vector3i.ZERO) as Vector3i
			if not _record_feature_portal(out, room_by_id, room_id,
					(feature.endpoints[0] as Dictionary).cell as Vector3i,
					_feature_endpoint_facing(feature, 0, facing)):
				return {}
		elif feature.kind == &"balcony":
			var room_id := StringName(feature.audit.get("balcony_room_id", &""))
			if room_id.is_empty() or feature.endpoints.size() != 1:
				last_failure = "balcony %s lacks one portal endpoint" % \
					feature.stable_id
				return {}
			var facing := feature.audit.get("balcony_endpoint_facing",
				Vector3i.ZERO) as Vector3i
			if not _record_feature_portal(out, room_by_id, room_id,
					(feature.endpoints[0] as Dictionary).cell as Vector3i,
					_feature_endpoint_facing(feature, 0, facing)):
				return {}
		elif feature.kind == &"courtyard_bridge_house":
			var room_id := StringName(feature.audit.get(
				"courtyard_bridge_house_room_id", &""))
			if room_id.is_empty() or feature.endpoints.size() != 1:
				last_failure = "courtyard bridge %s lacks one portal endpoint" \
					% feature.stable_id
				return {}
			var facing := feature.audit.get(
				"courtyard_bridge_house_endpoint_facing",
				Vector3i.ZERO) as Vector3i
			if not _record_feature_portal(out, room_by_id, room_id,
					(feature.endpoints[0] as Dictionary).cell as Vector3i,
					_feature_endpoint_facing(feature, 0, facing)):
				return {}
		elif feature.kind == &"enclosed_skywalk":
			var bindings: Array[Dictionary] = []
			bindings.assign(feature.audit.get("skywalk_endpoint_bindings", []) \
				as Array)
			if bindings.is_empty():
				bindings = [
					{"endpoint_kind": &"room", "room_id": StringName(
						feature.audit.get("skywalk_left_room_id", &""))},
					{"endpoint_kind": &"room", "room_id": StringName(
						feature.audit.get("skywalk_right_room_id", &""))},
				] as Array[Dictionary]
			if bindings.size() != feature.endpoints.size():
				last_failure = "skywalk %s portal bindings differ from endpoints" % \
					feature.stable_id
				return {}
			for endpoint_index in bindings.size():
				var binding := bindings[endpoint_index]
				var endpoint_kind := StringName(binding.get("endpoint_kind", &"room"))
				if endpoint_kind == &"landmark":
					continue
				if endpoint_kind != &"room":
					last_failure = "skywalk %s has unsupported endpoint kind %s" % [
						feature.stable_id, endpoint_kind]
					return {}
				var room_id := StringName(binding.get("room_id", &""))
				var facing := binding.get("facing", Vector3i.ZERO) as Vector3i
				if not _record_feature_portal(out, room_by_id, room_id,
						(feature.endpoints[endpoint_index] as Dictionary).cell \
							as Vector3i,
						_feature_endpoint_facing(feature, endpoint_index, facing)):
					return {}
	return out


static func _feature_endpoint_facing(feature: WarrenFeatureReservation,
		endpoint_index: int, recorded_facing: Vector3i) -> Vector3i:
	if _is_cardinal_xz(recorded_facing):
		return recorded_facing
	# Compatibility with source plans sealed before endpoint facing became an
	# explicit audit fact: the occupied feature begins exactly one cell outside
	# its room endpoint, so the unique adjacent reserved cell recovers direction.
	var endpoint := (feature.endpoints[endpoint_index] as Dictionary).cell \
		as Vector3i
	var recovered: Array[Vector3i] = []
	for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
			Vector3i.FORWARD, Vector3i.BACK]:
		if feature.reserved_cells.has(endpoint + direction):
			recovered.append(direction)
	return recovered[0] if recovered.size() == 1 else Vector3i.ZERO


static func _record_feature_portal(out: Dictionary, room_by_id: Dictionary,
		room_id: StringName, endpoint_cell: Vector3i,
		world_facing: Vector3i) -> bool:
	var room := room_by_id.get(room_id) as WarrenRoomStamp
	if room == null:
		last_failure = "feature portal names missing room %s" % room_id
		return false
	if not _is_cardinal_xz(world_facing):
		last_failure = "feature portal %s has no cardinal outward direction" % \
			room_id
		return false
	var local_facing := FabricRecipe.transform_direction(world_facing,
		-room.yaw_quarters)
	var portal_bit := _portal_bit_for_facing(local_facing)
	var local_cell := _inverse_cell(endpoint_cell, room.lattice_origin,
		room.yaw_quarters)
	var expected_cell := _portal_cell_for_room(room.kind, portal_bit)
	if portal_bit == 0 or local_cell != expected_cell:
		last_failure = "feature portal %s endpoint %s is not its centre facade %s" \
			% [room_id, local_cell, local_facing]
		return false
	out[room_id] = int(out.get(room_id, 0)) | portal_bit
	return true


static func _portal_bit_for_facing(local_facing: Vector3i) -> int:
	match local_facing:
		Vector3i.FORWARD:
			return SettlementFabricProgram.FEATURE_PORTAL_NORTH
		Vector3i.RIGHT:
			return SettlementFabricProgram.FEATURE_PORTAL_EAST
		Vector3i.BACK:
			return SettlementFabricProgram.FEATURE_PORTAL_SOUTH
		Vector3i.LEFT:
			return SettlementFabricProgram.FEATURE_PORTAL_WEST
		_:
			return 0


static func _portal_cell_for_room(kind: StringName, portal_bit: int) \
		-> Vector3i:
	var minimum := Vector2i.ZERO
	var maximum := Vector2i.ZERO
	match kind:
		&"tower":
			minimum = Vector2i(-1, -1)
			maximum = Vector2i(0, 0)
		&"slim":
			minimum = Vector2i(-1, -2)
			maximum = Vector2i(0, 1)
		&"row":
			minimum = Vector2i(-2, -1)
			maximum = Vector2i(1, 0)
		&"building":
			minimum = Vector2i(-2, -2)
			maximum = Vector2i(1, 1)
		&"long":
			minimum = Vector2i(-2, -3)
			maximum = Vector2i(1, 2)
		_:
			return Vector3i(2147483647, 2147483647, 2147483647)
	match portal_bit:
		SettlementFabricProgram.FEATURE_PORTAL_NORTH:
			return Vector3i(0, 0, minimum.y)
		SettlementFabricProgram.FEATURE_PORTAL_EAST:
			return Vector3i(maximum.x, 0, 0)
		SettlementFabricProgram.FEATURE_PORTAL_SOUTH:
			return Vector3i(0, 0, maximum.y)
		SettlementFabricProgram.FEATURE_PORTAL_WEST:
			return Vector3i(minimum.x, 0, 0)
		_:
			return Vector3i(2147483647, 2147483647, 2147483647)


static func _feature_portal_bit_count(mask: int) -> int:
	var count := 0
	for bit in [SettlementFabricProgram.FEATURE_PORTAL_NORTH,
			SettlementFabricProgram.FEATURE_PORTAL_EAST,
			SettlementFabricProgram.FEATURE_PORTAL_SOUTH,
			SettlementFabricProgram.FEATURE_PORTAL_WEST]:
		count += int((mask & bit) != 0)
	return count


static func _is_cardinal_xz(direction: Vector3i) -> bool:
	return direction.y == 0 and absi(direction.x) + absi(direction.z) == 1


static func _is_phase_b_recipe(recipe_id: StringName) -> bool:
	var id := String(recipe_id)
	return id.ends_with(".b") or id.contains(".b.")


static func compile_feature_units(source: WarrenSpatialPlan,
		program: SettlementFabricProgram,
		room_units: Array[FabricUnit]) -> Array[FabricUnit]:
	## Construction records are sealed topology facts. This adapter may only bind
	## their measured sockets to the already-compiled endpoint rooms; it proves
	## that the resulting recipe layers reproduce the exact reserved cell union.
	last_failure = ""
	last_audit = {}
	if source == null or not source.is_sealed() or program == null \
			or room_units.is_empty():
		last_failure = "missing spatial plan, vocabulary, or compiled rooms"
		return [] as Array[FabricUnit]
	var room_unit_by_stamp: Dictionary = {}
	var source_parcel_by_room: Dictionary = {}
	var seam_ids_by_source_parcel: Dictionary = {}
	for room_unit: FabricUnit in room_units:
		var room_id := StringName(String(room_unit.stable_id).trim_prefix(
			"spatial.fabric."))
		room_unit_by_stamp[room_id] = room_unit
	for building: WarrenBuildingVolume in source.buildings:
		for room: WarrenRoomStamp in building.room_records:
			source_parcel_by_room[room.stable_id] = room.source_parcel_id
			if not seam_ids_by_source_parcel.has(room.source_parcel_id):
				seam_ids_by_source_parcel[room.source_parcel_id] = [] \
					as Array[StringName]
			var room_unit := room_unit_by_stamp.get(room.stable_id) as FabricUnit
			if room_unit != null:
				(seam_ids_by_source_parcel[room.source_parcel_id] \
					as Array[StringName]).append(room_unit.stable_id)
	for seam_ids_value: Variant in seam_ids_by_source_parcel.values():
		(seam_ids_value as Array[StringName]).sort_custom(func(a: StringName,
				b: StringName) -> bool:
			return String(a) < String(b))
	var probe := SettlementFabricPlan.new(&"spatial.feature-selection")
	for recipe: FabricRecipe in program.recipes():
		if not probe.register_recipe(recipe):
			last_failure = "feature selection could not register recipe %s" % \
				recipe.recipe_id
			return [] as Array[FabricUnit]
	for room_unit: FabricUnit in room_units:
		if not probe.add_unit(room_unit):
			last_failure = "feature selection rejected source room %s: %s" % [
				room_unit.stable_id, probe.last_rejection]
			return [] as Array[FabricUnit]
	var ordered_features: Array[WarrenFeatureReservation] = []
	for feature: WarrenFeatureReservation in source.features:
		if not feature.construction_records.is_empty():
			ordered_features.append(feature)
	ordered_features.sort_custom(func(a: WarrenFeatureReservation,
			b: WarrenFeatureReservation) -> bool:
		return String(a.stable_id) < String(b.stable_id))
	var out: Array[FabricUnit] = []
	var compiled_support_units: Array[FabricUnit] = []
	var realized_cells: Dictionary = {}
	var compiled_feature_unit_by_owner: Dictionary = {}
	var skywalk_count := 0
	var courtyard_bridge_count := 0
	var market_count := 0
	var balcony_count := 0
	var room_outcropping_support_count := 0
	var frontier_gateway_support_count := 0
	var tower_annex_count := 0
	var facade_bay_count := 0
	var landmark_count := 0
	var interstitial_join_count := 0
	for feature: WarrenFeatureReservation in ordered_features:
		var feature_units: Array[FabricUnit] = []
		match feature.kind:
			&"courtyard_bridge_house":
				feature_units = _compile_courtyard_bridge_house_feature(feature,
					program, room_unit_by_stamp, source_parcel_by_room,
					seam_ids_by_source_parcel)
				courtyard_bridge_count += int(not feature_units.is_empty())
			&"enclosed_skywalk":
				feature_units = _compile_skywalk_feature(feature, program,
					room_unit_by_stamp, source_parcel_by_room,
					seam_ids_by_source_parcel,
					compiled_feature_unit_by_owner)
				skywalk_count += int(not feature_units.is_empty())
			&"covered_market":
				feature_units = _compile_market_feature(feature, program,
					room_unit_by_stamp, source_parcel_by_room,
					seam_ids_by_source_parcel)
				market_count += int(not feature_units.is_empty())
			&"balcony":
				feature_units = _compile_balcony_feature(feature, program,
					room_unit_by_stamp, source_parcel_by_room,
					seam_ids_by_source_parcel)
				balcony_count += int(not feature_units.is_empty())
			&"room_outcropping":
				feature_units = _compile_room_outcropping_supports(feature,
					program, room_unit_by_stamp)
				room_outcropping_support_count += int(
					not feature_units.is_empty())
			&"frontier_gateway_support":
				feature_units = _compile_frontier_gateway_supports(feature,
					program, room_unit_by_stamp)
				frontier_gateway_support_count += int(
					not feature_units.is_empty())
			&"tower_annex":
				feature_units = _compile_tower_annex_feature(feature, program,
					room_unit_by_stamp, source_parcel_by_room,
					seam_ids_by_source_parcel)
				tower_annex_count += int(not feature_units.is_empty())
			&"facade_bay":
				feature_units = _compile_tower_annex_feature(feature, program,
					room_unit_by_stamp, source_parcel_by_room,
					seam_ids_by_source_parcel)
				facade_bay_count += int(not feature_units.is_empty())
			&"interstitial_join":
				feature_units = _compile_interstitial_join_feature(feature,
					program, source, room_unit_by_stamp, out)
				interstitial_join_count += int(not feature_units.is_empty())
			&"prefab_landmark":
				feature_units = _compile_landmark_feature(feature, program)
				landmark_count += int(not feature_units.is_empty())
			_:
				last_failure = "constructed spatial feature %s has no compiler" % \
					feature.kind
				return [] as Array[FabricUnit]
		if feature_units.is_empty():
			return [] as Array[FabricUnit]
		if not _feature_units_match_reservation(feature, feature_units, program):
			last_failure = "feature %s construction changes its reserved volume" % \
				feature.stable_id
			return [] as Array[FabricUnit]
		for unit: FabricUnit in feature_units:
			var unit_recipe := program.recipe(unit.recipe_id)
			var unit_is_support := unit_recipe != null \
				and unit_recipe.has_tag(&"cantilever_support")
			if unit_recipe != null:
				var unit_clearance := unit.transform() \
					* unit_recipe.local_clearance_bounds
				# Support courses are selected as one compatible structural frame.
				# Make every measured intersection explicit before the plan gate sees
				# it; this is a typed timber joint, not a general overlap exemption.
				# Interstitial strips extend the same rule to any feature whose
				# measured envelope crosses one: the strip fills proven-vacant
				# trapped cells, so the crossing is a joint, not displacement.
				for prior: FabricUnit in compiled_support_units:
					var prior_recipe := program.recipe(prior.recipe_id)
					if prior_recipe == null:
						continue
					var prior_is_strip := String(prior.recipe_id).begins_with(
							"interstitial.") \
						or String(prior.recipe_id).begins_with(
							"roof.setback.lean.")
					if not unit_is_support and not prior_is_strip:
						continue
					var prior_clearance := prior.transform() \
						* prior_recipe.local_clearance_bounds
					if SettlementFabricPlan._aabb_overlaps_volume(
							unit_clearance, prior_clearance) \
							and not unit.visual_seam_ids.has(prior.stable_id):
						unit.visual_seam_ids.append(prior.stable_id)
			if not probe.add_unit(unit):
				last_failure = "feature component %s rejected: %s" % [
					unit.stable_id, probe.last_rejection]
				return [] as Array[FabricUnit]
			out.append(unit)
			if unit_recipe != null and unit_recipe.has_tag(&"cantilever_support"):
				compiled_support_units.append(unit)
			# Interstitial strips are structural courses wedged against the same
			# walls the bracket frames anchor to; a later support course that
			# measures into one declares the same typed timber joint it would
			# declare against an earlier brace.
			if feature.kind == &"interstitial_join":
				compiled_support_units.append(unit)
		if feature.kind == &"prefab_landmark" and feature_units.size() == 1:
			compiled_feature_unit_by_owner[feature.stable_id] = feature_units[0]
		for cell: Vector3i in feature.reserved_cells:
			if realized_cells.has(cell):
				last_failure = "constructed features overlap at %s" % cell
				return [] as Array[FabricUnit]
			realized_cells[cell] = feature.stable_id
	last_audit = {
		"source_constructed_feature_count": ordered_features.size(),
		"realized_constructed_feature_count": skywalk_count + market_count \
			+ balcony_count + tower_annex_count + facade_bay_count + landmark_count \
			+ courtyard_bridge_count + room_outcropping_support_count \
			+ frontier_gateway_support_count + interstitial_join_count,
		"skywalk_feature_count": skywalk_count,
		"interstitial_join_feature_count": interstitial_join_count,
		"courtyard_bridge_house_feature_count": courtyard_bridge_count,
		"covered_market_feature_count": market_count,
		"balcony_feature_count": balcony_count,
		"room_outcropping_support_feature_count":
			room_outcropping_support_count,
		"frontier_gateway_support_feature_count":
			frontier_gateway_support_count,
		"tower_annex_feature_count": tower_annex_count,
		"facade_bay_feature_count": facade_bay_count,
		"prefab_landmark_feature_count": landmark_count,
		"feature_construction_unit_count": out.size(),
		"feature_reserved_cell_count": realized_cells.size(),
	}
	return out


static func _compile_room_outcropping_supports(
		feature: WarrenFeatureReservation,
		program: SettlementFabricProgram,
		room_unit_by_stamp: Dictionary) -> Array[FabricUnit]:
	## The occupied upper room was compiled in the ordinary room pass. These
	## records realize only the exact bracket courses derived from its sealed
	## bearing edge; they neither restamp nor resize the room volume.
	var out: Array[FabricUnit] = []
	var upper_id := StringName(feature.audit.get("outcrop_upper_room_id", &""))
	var lower_id := StringName(feature.audit.get("outcrop_lower_room_id", &""))
	var upper_unit := room_unit_by_stamp.get(upper_id) as FabricUnit
	var lower_unit := room_unit_by_stamp.get(lower_id) as FabricUnit
	if upper_unit == null or lower_unit == null \
			or feature.construction_records.is_empty() \
			or not bool(feature.audit.get(
				"outcrop_is_integrated_cantilever", false)):
		last_failure = "room outcropping %s lacks its two room plates or supports" \
			% feature.stable_id
		return out
	var neighbor_units: Array[StringName] = []
	for neighbor_value: Variant in feature.audit.get(
			"outcrop_support_neighbor_room_ids", []):
		var neighbor_id := StringName(neighbor_value)
		var neighbor_unit := room_unit_by_stamp.get(neighbor_id) as FabricUnit
		if neighbor_unit == null:
			last_failure = "room outcropping %s names missing support seam %s" % [
				feature.stable_id, neighbor_id]
			return [] as Array[FabricUnit]
		neighbor_units.append(neighbor_unit.stable_id)
	var shells: Array[FabricUnit] = []
	for index in feature.construction_records.size():
		var record := feature.construction_records[index]
		shells.append(_feature_component_shell(feature, index, record))
	var built_support_seams: Array[StringName] = []
	for shell: FabricUnit in shells:
		var recipe := program.recipe(shell.recipe_id)
		if recipe == null or not recipe.has_tag(&"cantilever_support") \
				or not recipe.has_tag(&"visual_attachment") \
				or not recipe.solid_cells.is_empty() \
				or not recipe.walk_cells.is_empty() \
				or not recipe.headroom_cells.is_empty() \
				or recipe.bearing_parent_count != 0:
			last_failure = "room outcropping %s has a non-attachment support recipe" \
				% feature.stable_id
			return [] as Array[FabricUnit]
		# SettlementFabricPlan validates a visual seam against construction that
		# already exists. A multi-brace support course is therefore an ordered
		# dependency: every brace may meet its two room plates and earlier braces,
		# while the later brace declares the reciprocal geometric exception when
		# it is added. Forward-referencing every sibling made the first brace fail
		# despite the complete feature reservation being valid.
		var seams: Array[StringName] = [upper_unit.stable_id,
			lower_unit.stable_id]
		seams.append_array(neighbor_units)
		seams.append_array(built_support_seams)
		out.append(FabricUnit.new(shell.stable_id, shell.recipe_id,
			shell.lattice_origin, shell.yaw_quarters,
			[] as Array[StringName], [] as Array[Dictionary], &"", seams))
		built_support_seams.append(shell.stable_id)
	return out


static func _compile_frontier_gateway_supports(
		feature: WarrenFeatureReservation,
		program: SettlementFabricProgram,
		room_unit_by_stamp: Dictionary) -> Array[FabricUnit]:
	## The gateway room already owns the occupied volume. This adapter realizes
	## only its sealed underside bracket course and names every measured room it
	## touches as an explicit joinery seam.
	var out: Array[FabricUnit] = []
	var room_id := StringName(feature.audit.get("gateway_room_id", &""))
	var room_unit := room_unit_by_stamp.get(room_id) as FabricUnit
	if room_unit == null or feature.construction_records.size() != 1 \
			or not bool(feature.audit.get("gateway_is_terrain_anchored", false)):
		last_failure = "frontier gateway %s lacks its terrain-rooted room or bracket" \
			% feature.stable_id
		return out
	var seams: Array[StringName] = [room_unit.stable_id]
	for neighbor_value: Variant in feature.audit.get(
			"gateway_support_neighbor_room_ids", []):
		var neighbor_id := StringName(neighbor_value)
		var neighbor_unit := room_unit_by_stamp.get(neighbor_id) as FabricUnit
		if neighbor_unit == null:
			last_failure = "frontier gateway %s names missing support seam %s" % [
				feature.stable_id, neighbor_id]
			return [] as Array[FabricUnit]
		seams.append(neighbor_unit.stable_id)
	var record := feature.construction_records[0] as Dictionary
	var shell := _feature_component_shell(feature, 0, record)
	var recipe := program.recipe(shell.recipe_id)
	if recipe == null or not recipe.has_tag(&"cantilever_support") \
			or not recipe.has_tag(&"visual_attachment") \
			or not recipe.solid_cells.is_empty() \
			or not recipe.walk_cells.is_empty() \
			or not recipe.headroom_cells.is_empty() \
			or recipe.bearing_parent_count != 0:
		last_failure = "frontier gateway %s has a non-attachment support recipe" \
			% feature.stable_id
		return [] as Array[FabricUnit]
	out.append(FabricUnit.new(shell.stable_id, shell.recipe_id,
		shell.lattice_origin, shell.yaw_quarters,
		[] as Array[StringName], [] as Array[Dictionary], &"", seams))
	return out


static func _compile_interstitial_join_feature(
		feature: WarrenFeatureReservation,
		program: SettlementFabricProgram, source: WarrenSpatialPlan,
		room_unit_by_stamp: Dictionary,
		prior_feature_units: Array[FabricUnit]) -> Array[FabricUnit]:
	## Realize a typed interstitial join. The reservation already owns the slot
	## volume and its two-owner relationship; this adapter binds the measured
	## strip to its exact bearing parent and names every touching room as a
	## visual seam, so the join compiles through the same envelope gate as any
	## other unit instead of hiding a gap behind coincidental meshes.
	var out: Array[FabricUnit] = []
	if feature.construction_records.size() != 1:
		last_failure = "interstitial join %s needs exactly one record" \
			% feature.stable_id
		return out
	var record := feature.construction_records[0]
	var shell := _feature_component_shell(feature, 0, record)
	var recipe := program.recipe(shell.recipe_id)
	if recipe == null:
		last_failure = "interstitial join %s names unknown recipe %s" % [
			feature.stable_id, shell.recipe_id]
		return out
	var strip_cells: Dictionary = {}
	for cell: Vector3i in feature.reserved_cells:
		strip_cells[cell] = true
	# Every room touching the strip (including the diagonal upper wall a
	# stepped shoulder seals against) is an explicit visual seam.
	var seams: Array[StringName] = []
	var seam_set: Dictionary = {}
	for building: WarrenBuildingVolume in source.buildings:
		for room: WarrenRoomStamp in building.room_records:
			if not room_unit_by_stamp.has(room.stable_id):
				continue
			var touches := false
			for cell_value: Variant in strip_cells:
				var cell := cell_value as Vector3i
				for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
						Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD,
						Vector3i.BACK,
						Vector3i.UP + Vector3i.LEFT,
						Vector3i.UP + Vector3i.RIGHT,
						Vector3i.UP + Vector3i.FORWARD,
						Vector3i.UP + Vector3i.BACK,
						Vector3i.DOWN + Vector3i.LEFT,
						Vector3i.DOWN + Vector3i.RIGHT,
						Vector3i.DOWN + Vector3i.FORWARD,
						Vector3i.DOWN + Vector3i.BACK]:
					if room.has_private_cell(cell + direction):
						touches = true
						break
				if touches:
					break
			if not touches:
				continue
			var unit := room_unit_by_stamp.get(room.stable_id) as FabricUnit
			if unit != null and not seam_set.has(unit.stable_id):
				seam_set[unit.stable_id] = true
				seams.append(unit.stable_id)
	# A room whose measured eave or bay envelope grazes the strip from a
	# distance shares the reveal too: the strip never exceeds its proven
	# trapped cells, so every such intersection is a typed joint, mirrored
	# from the room gate's interstitial exemption.
	var strip_bounds := FabricRecipe.lattice_transform(shell.lattice_origin,
		shell.yaw_quarters) * recipe.local_clearance_bounds
	for building: WarrenBuildingVolume in source.buildings:
		for room: WarrenRoomStamp in building.room_records:
			var unit := room_unit_by_stamp.get(room.stable_id) as FabricUnit
			if unit == null or seam_set.has(unit.stable_id):
				continue
			var room_recipe := program.recipe(unit.recipe_id)
			if room_recipe == null:
				continue
			var room_bounds := FabricRecipe.lattice_transform(
				room.lattice_origin, room.yaw_quarters) \
				* room_recipe.local_clearance_bounds
			if SettlementFabricPlan._aabb_overlaps_volume(strip_bounds,
					room_bounds):
				seam_set[unit.stable_id] = true
				seams.append(unit.stable_id)
	# Sibling strips: a stacked slit band, or a nearby shoulder whose sloped
	# envelope grazes this one, names the earlier strip as a typed joint —
	# the same structural-course rule the bracket frames use.
	for prior: FabricUnit in prior_feature_units:
		if not String(prior.recipe_id).begins_with("interstitial.") \
				and not String(prior.recipe_id).begins_with(
					"roof.setback.lean."):
			continue
		var prior_recipe := program.recipe(prior.recipe_id)
		if prior_recipe == null or seam_set.has(prior.stable_id):
			continue
		var prior_bounds := FabricRecipe.lattice_transform(
			prior.lattice_origin, prior.yaw_quarters) \
			* prior_recipe.local_clearance_bounds
		if SettlementFabricPlan._aabb_overlaps_volume(strip_bounds,
				prior_bounds):
			seam_set[prior.stable_id] = true
			seams.append(prior.stable_id)
	seams = _unique_sorted_names(seams)
	var parents: Array[StringName] = []
	var bonds: Array[Dictionary] = []
	if recipe.bearing_parent_count > 0:
		var below := (record.origin as Vector3i) + Vector3i.DOWN
		var parent_room: WarrenRoomStamp = null
		for building: WarrenBuildingVolume in source.buildings:
			for room: WarrenRoomStamp in building.room_records:
				if room.has_private_cell(below):
					parent_room = room
					break
			if parent_room != null:
				break
		var parent_unit := room_unit_by_stamp.get(
			parent_room.stable_id) as FabricUnit if parent_room != null \
			else null
		if parent_unit == null:
			last_failure = "interstitial join %s has no built bearing parent" \
				% feature.stable_id
			return out
		var parent_local := _inverse_cell(below, parent_room.lattice_origin,
			parent_room.yaw_quarters)
		parents.append(parent_unit.stable_id)
		bonds.append(FabricUnit.bond(&"bearing.bottom", parent_unit.stable_id,
			SettlementFabricProgram._bearing_cell_socket_id(&"top",
				parent_local.x, parent_local.z)))
	out.append(FabricUnit.new(shell.stable_id, shell.recipe_id,
		shell.lattice_origin, shell.yaw_quarters, parents, bonds, &"", seams))
	return out


static func _compile_tower_annex_feature(feature: WarrenFeatureReservation,
		program: SettlementFabricProgram,
		room_unit_by_stamp: Dictionary, source_parcel_by_room: Dictionary,
		seam_ids_by_source_parcel: Dictionary) -> Array[FabricUnit]:
	var room_id := StringName(feature.audit.get("annex_room_id", &""))
	if room_id.is_empty() or feature.endpoints.size() != 1 \
			or feature.construction_records.size() != 1:
		last_failure = "%s %s lacks one exact room/recipe" \
			% [feature.kind, feature.stable_id]
		return [] as Array[FabricUnit]
	var room_unit := room_unit_by_stamp.get(room_id) as FabricUnit
	if room_unit == null:
		last_failure = "%s %s parent room %s was not compiled" % [
			feature.kind, feature.stable_id, room_id]
		return [] as Array[FabricUnit]
	var component := _feature_component_shell(feature, 0,
		feature.construction_records[0])
	var recipe := program.recipe(component.recipe_id)
	if recipe == null or not recipe.has_tag(&"outcropping") \
			or recipe.bearing_parent_count != 1:
		last_failure = "%s %s lacks a one-bearing occupied recipe" \
			% [feature.kind, feature.stable_id]
		return [] as Array[FabricUnit]
	var endpoint_cell := (feature.endpoints[0] as Dictionary).cell as Vector3i
	var matches := _matching_room_connections(component, room_unit, program,
		endpoint_cell, true)
	if matches.size() != 1:
		last_failure = "%s %s has %d exact room/socket matches" % [
			feature.kind, feature.stable_id, matches.size()]
		return [] as Array[FabricUnit]
	var source_parcel_id := StringName(source_parcel_by_room.get(room_id, &""))
	var seams: Array[StringName] = []
	seams.assign(seam_ids_by_source_parcel.get(source_parcel_id, []) \
		as Array[StringName])
	return [_feature_component_with_connections(component,
		[matches[0]] as Array[Dictionary], [room_unit] as Array[FabricUnit],
		true, seams)] as Array[FabricUnit]


static func _compile_landmark_feature(feature: WarrenFeatureReservation,
		program: SettlementFabricProgram) -> Array[FabricUnit]:
	if feature.endpoints.size() != 1 \
			or feature.construction_records.size() != 1:
		last_failure = "prefab landmark %s lacks one exact doorway/recipe" \
			% feature.stable_id
		return [] as Array[FabricUnit]
	var component := _feature_component_shell(feature, 0,
		feature.construction_records[0])
	var recipe := program.recipe(component.recipe_id)
	if recipe == null or not recipe.has_tag(&"prefab_anchor") \
			or not recipe.has_tag(&"terrain_bearing") \
			or recipe.bearing_parent_count != 0:
		last_failure = "prefab landmark %s lacks a terrain-bearing anchor recipe" \
			% feature.stable_id
		return [] as Array[FabricUnit]
	var expected_entrance := feature.audit.get("landmark_entrance_cell",
		Vector3i(2147483647, 2147483647, 2147483647)) as Vector3i
	var expected_landing := feature.audit.get("landmark_public_landing_cell",
		Vector3i(2147483647, 2147483647, 2147483647)) as Vector3i
	var matching_entrances := 0
	for entrance: Dictionary in recipe.entrances:
		var world_cell := FabricRecipe.transform_cell(entrance.cell as Vector3i,
			component.lattice_origin, component.yaw_quarters)
		var world_facing := FabricRecipe.transform_direction(
			entrance.facing as Vector3i, component.yaw_quarters)
		matching_entrances += int(world_cell == expected_entrance \
			and world_cell + world_facing == expected_landing)
	if matching_entrances != 1:
		last_failure = "prefab landmark %s construction moves its public doorway" \
			% feature.stable_id
		return [] as Array[FabricUnit]
	return [component] as Array[FabricUnit]


static func _compile_balcony_feature(feature: WarrenFeatureReservation,
		program: SettlementFabricProgram,
		room_unit_by_stamp: Dictionary, source_parcel_by_room: Dictionary,
		seam_ids_by_source_parcel: Dictionary) -> Array[FabricUnit]:
	var room_id := StringName(feature.audit.get("balcony_room_id", &""))
	if room_id.is_empty() or feature.endpoints.size() != 1 \
			or feature.construction_records.size() != 1:
		last_failure = "balcony %s lacks one exact room/recipe" % feature.stable_id
		return [] as Array[FabricUnit]
	var room_unit := room_unit_by_stamp.get(room_id) as FabricUnit
	if room_unit == null:
		last_failure = "balcony %s parent room %s was not compiled" % [
			feature.stable_id, room_id]
		return [] as Array[FabricUnit]
	var component := _feature_component_shell(feature, 0,
		feature.construction_records[0])
	var recipe := program.recipe(component.recipe_id)
	if recipe == null or not recipe.has_tag(&"balcony") \
			or recipe.bearing_parent_count != 1:
		last_failure = "balcony %s lacks a one-bearing occupied recipe" % \
			feature.stable_id
		return [] as Array[FabricUnit]
	var endpoint_cell := (feature.endpoints[0] as Dictionary).cell as Vector3i
	var matches := _matching_room_connections(component, room_unit, program,
		endpoint_cell, true)
	if matches.size() != 1:
		last_failure = "balcony %s has %d exact doorway/socket matches" % [
			feature.stable_id, matches.size()]
		return [] as Array[FabricUnit]
	var source_parcel_id := StringName(source_parcel_by_room.get(room_id, &""))
	var seams: Array[StringName] = []
	seams.assign(seam_ids_by_source_parcel.get(source_parcel_id, []) \
		as Array[StringName])
	return [_feature_component_with_connections(component,
		[matches[0]] as Array[Dictionary], [room_unit] as Array[FabricUnit],
		true, seams)] as Array[FabricUnit]


static func _compile_market_feature(feature: WarrenFeatureReservation,
		program: SettlementFabricProgram,
		room_unit_by_stamp: Dictionary, source_parcel_by_room: Dictionary,
		seam_ids_by_source_parcel: Dictionary) -> Array[FabricUnit]:
	var room_id := StringName(feature.audit.get("market_backing_room_id", &""))
	if room_id.is_empty() or feature.endpoints.size() != 1 \
			or feature.construction_records.size() != 1:
		last_failure = "covered market %s lacks one exact backing room/recipe" % \
			feature.stable_id
		return [] as Array[FabricUnit]
	var room_unit := room_unit_by_stamp.get(room_id) as FabricUnit
	if room_unit == null:
		last_failure = "covered market %s backing room %s was not compiled" % [
			feature.stable_id, room_id]
		return [] as Array[FabricUnit]
	var component := _feature_component_shell(feature, 0,
		feature.construction_records[0])
	var recipe := program.recipe(component.recipe_id)
	if recipe == null or not recipe.has_tag(&"covered_market") \
			or recipe.bearing_parent_count != 0:
		last_failure = "covered market %s lacks a terrain-bearing bazaar recipe" % \
			feature.stable_id
		return [] as Array[FabricUnit]
	var endpoint_cell := (feature.endpoints[0] as Dictionary).cell as Vector3i
	var matches := _matching_market_connections(component, room_unit, program,
		endpoint_cell)
	if matches.size() != 1:
		last_failure = "covered market %s has %d exact backing socket matches" % [
			feature.stable_id, matches.size()]
		return [] as Array[FabricUnit]
	var source_parcel_id := StringName(source_parcel_by_room.get(room_id, &""))
	var seams: Array[StringName] = []
	seams.assign(seam_ids_by_source_parcel.get(source_parcel_id, []) \
		as Array[StringName])
	var connection := matches[0] as Dictionary
	var bonds: Array[Dictionary] = [FabricUnit.bond(
		StringName(connection.own_market), room_unit.stable_id,
		StringName(connection.target_market))]
	return [FabricUnit.new(component.stable_id, component.recipe_id,
		component.lattice_origin, component.yaw_quarters,
		[] as Array[StringName], bonds, &"", seams)] as Array[FabricUnit]


static func _compile_courtyard_bridge_house_feature(
		feature: WarrenFeatureReservation, program: SettlementFabricProgram,
		room_unit_by_stamp: Dictionary, source_parcel_by_room: Dictionary,
		seam_ids_by_source_parcel: Dictionary) -> Array[FabricUnit]:
	## The topology record is ordered parent-to-child: a pitched corner knuckle
	## bonds to the addressed room, then a single inhabited cantilever bay bonds
	## to the remaining corner socket. The far end is deliberately closed; making
	## it seek a second room would recreate the impossible U-link that blocked the
	## upper public gateway beside the court.
	var room_id := StringName(feature.audit.get(
		"courtyard_bridge_house_room_id", &""))
	if room_id.is_empty() or feature.endpoints.size() != 1 \
			or feature.construction_records.size() != 2:
		last_failure = "courtyard bridge %s lacks one room or two components" \
			% feature.stable_id
		return [] as Array[FabricUnit]
	var room_unit := room_unit_by_stamp.get(room_id) as FabricUnit
	if room_unit == null:
		last_failure = "courtyard bridge %s parent room %s was not compiled" % [
			feature.stable_id, room_id]
		return [] as Array[FabricUnit]
	var source_parcel_id := StringName(source_parcel_by_room.get(room_id, &""))
	var lineage_seams: Array[StringName] = []
	lineage_seams.assign(seam_ids_by_source_parcel.get(source_parcel_id, []) \
		as Array[StringName])
	var corner_shell := _feature_component_shell(feature, 0,
		feature.construction_records[0])
	var corner_recipe := program.recipe(corner_shell.recipe_id)
	if corner_recipe == null or not String(corner_shell.recipe_id).begins_with(
			"skywalk.corner.") or corner_recipe.bearing_parent_count != 1:
		last_failure = "courtyard bridge %s lacks its measured corner knuckle" \
			% feature.stable_id
		return [] as Array[FabricUnit]
	var endpoint_cell := (feature.endpoints[0] as Dictionary).cell as Vector3i
	var room_matches := _matching_room_connections(corner_shell, room_unit,
		program, endpoint_cell, true)
	if room_matches.size() != 1:
		last_failure = "courtyard bridge %s has %d exact room/socket matches" % [
			feature.stable_id, room_matches.size()]
		return [] as Array[FabricUnit]
	var corner := _feature_component_with_connections(corner_shell,
		[room_matches[0]] as Array[Dictionary],
		[room_unit] as Array[FabricUnit], true, lineage_seams)
	var bay_shell := _feature_component_shell(feature, 1,
		feature.construction_records[1])
	var bay_recipe := program.recipe(bay_shell.recipe_id)
	if bay_recipe == null or not String(bay_shell.recipe_id).begins_with(
			"skywalk.cantilever.") or bay_recipe.bearing_parent_count != 1:
		last_failure = "courtyard bridge %s lacks its one-bearing occupied bay" \
			% feature.stable_id
		return [] as Array[FabricUnit]
	var bay_matches := _matching_room_connections(bay_shell, corner, program)
	if bay_matches.size() != 1:
		last_failure = "courtyard bridge %s bay has %d corner/socket matches" % [
			feature.stable_id, bay_matches.size()]
		return [] as Array[FabricUnit]
	var bay := _feature_component_with_connections(bay_shell,
		[bay_matches[0]] as Array[Dictionary], [corner] as Array[FabricUnit],
		true, lineage_seams)
	return [corner, bay] as Array[FabricUnit]


static func _compile_skywalk_feature(feature: WarrenFeatureReservation,
		program: SettlementFabricProgram,
		room_unit_by_stamp: Dictionary, source_parcel_by_room: Dictionary,
		seam_ids_by_source_parcel: Dictionary,
		compiled_feature_unit_by_owner: Dictionary = {}) -> Array[FabricUnit]:
	var bindings: Array[Dictionary] = []
	bindings.assign(feature.audit.get("skywalk_endpoint_bindings", []) as Array)
	if bindings.is_empty():
		bindings = [
			{"endpoint_kind": &"room", "owner_id": &"", "room_id":
				StringName(feature.audit.get("skywalk_left_room_id", &""))},
			{"endpoint_kind": &"room", "owner_id": &"", "room_id":
				StringName(feature.audit.get("skywalk_right_room_id", &""))},
		] as Array[Dictionary]
	if bindings.size() != 2 or feature.endpoints.size() != 2:
		last_failure = "skywalk %s lacks two exact endpoint rooms" % \
			feature.stable_id
		return [] as Array[FabricUnit]
	var endpoint_specs: Array[Dictionary] = []
	for endpoint_index in 2:
		var binding := bindings[endpoint_index]
		var endpoint_kind := StringName(binding.get("endpoint_kind", &"room"))
		var room_id := StringName(binding.get("room_id", &""))
		var room_unit: FabricUnit
		var seam_ids: Array[StringName] = []
		if endpoint_kind == &"landmark":
			var owner_id := StringName(binding.get("owner_id", &""))
			room_unit = compiled_feature_unit_by_owner.get(owner_id) as FabricUnit
			if room_unit != null:
				seam_ids.append(room_unit.stable_id)
		else:
			room_unit = room_unit_by_stamp.get(room_id) as FabricUnit
			var source_parcel_id := StringName(source_parcel_by_room.get(room_id,
				&""))
			seam_ids.assign(seam_ids_by_source_parcel.get(source_parcel_id, []) \
				as Array[StringName])
		if room_unit == null:
			last_failure = "skywalk %s endpoint %s was not compiled" % [
				feature.stable_id, room_id]
			return [] as Array[FabricUnit]
		endpoint_specs.append({"unit": room_unit, "cell":
			(feature.endpoints[endpoint_index] as Dictionary).cell as Vector3i,
			"seam_ids": seam_ids})
	var records := feature.construction_records
	if records.size() == 1:
		var component := _feature_component_shell(feature, 0, records[0])
		var recipe := program.recipe(component.recipe_id)
		if recipe == null or recipe.bearing_parent_count != 2:
			last_failure = "straight skywalk %s lacks a two-bearing recipe" % \
				feature.stable_id
			return [] as Array[FabricUnit]
		var connections: Array[Dictionary] = []
		for endpoint: Dictionary in endpoint_specs:
			var matches := _matching_room_connections(component,
				endpoint.unit as FabricUnit, program, endpoint.cell as Vector3i, true)
			if matches.size() != 1:
				last_failure = "straight skywalk %s has %d socket matches to %s" % [
					feature.stable_id, matches.size(),
					(endpoint.unit as FabricUnit).stable_id]
				return [] as Array[FabricUnit]
			connections.append(matches[0])
		if connections[0].own_room == connections[1].own_room:
			last_failure = "straight skywalk %s reuses one endpoint socket" % \
				feature.stable_id
			return [] as Array[FabricUnit]
		return [_feature_component_with_connections(component, connections,
			[endpoint_specs[0].unit, endpoint_specs[1].unit] as Array[FabricUnit],
			true, _unique_sorted_names((endpoint_specs[0].seam_ids \
				as Array[StringName]) + (endpoint_specs[1].seam_ids \
				as Array[StringName])))] as Array[FabricUnit]
	if records.size() != 3:
		last_failure = "skywalk %s has unsupported %d-component construction" % [
			feature.stable_id, records.size()]
		return [] as Array[FabricUnit]
	var endpoint_lineage_seams := _unique_sorted_names(
		(endpoint_specs[0].seam_ids as Array[StringName]) \
		+ (endpoint_specs[1].seam_ids as Array[StringName]))
	var first_shell := _feature_component_shell(feature, 0, records[0])
	var endpoint_options: Array[Dictionary] = []
	for endpoint_index in endpoint_specs.size():
		var endpoint := endpoint_specs[endpoint_index]
		var matches := _matching_room_connections(first_shell,
			endpoint.unit as FabricUnit, program, endpoint.cell as Vector3i, true)
		for match: Dictionary in matches:
			endpoint_options.append({"endpoint_index": endpoint_index,
				"connection": match})
	if endpoint_options.size() != 1:
		last_failure = "corner skywalk %s first arm has %d endpoint matches" % [
			feature.stable_id, endpoint_options.size()]
		return [] as Array[FabricUnit]
	var first_endpoint_index := int(endpoint_options[0].endpoint_index)
	var first_endpoint := endpoint_specs[first_endpoint_index]
	var first := _feature_component_with_connections(first_shell,
		[endpoint_options[0].connection] as Array[Dictionary],
		[first_endpoint.unit] as Array[FabricUnit], true,
		endpoint_lineage_seams)
	var corner_shell := _feature_component_shell(feature, 1, records[1])
	var corner_matches := _matching_room_connections(corner_shell, first,
		program)
	if corner_matches.size() != 1:
		last_failure = "corner skywalk %s knuckle has %d arm matches" % [
			feature.stable_id, corner_matches.size()]
		return [] as Array[FabricUnit]
	var corner := _feature_component_with_connections(corner_shell,
		[corner_matches[0]] as Array[Dictionary], [first] as Array[FabricUnit],
		true, endpoint_lineage_seams)
	var final_shell := _feature_component_shell(feature, 2, records[2])
	var corner_to_final := _matching_room_connections(final_shell, corner,
		program)
	var final_endpoint := endpoint_specs[1 - first_endpoint_index]
	var endpoint_to_final := _matching_room_connections(final_shell,
		final_endpoint.unit as FabricUnit, program,
		final_endpoint.cell as Vector3i, true)
	if corner_to_final.size() != 1 or endpoint_to_final.size() != 1 \
			or corner_to_final[0].own_room == endpoint_to_final[0].own_room:
		last_failure = "corner skywalk %s final arm does not close both seams" % \
			feature.stable_id
		return [] as Array[FabricUnit]
	var final_connections: Array[Dictionary] = [corner_to_final[0],
		endpoint_to_final[0]]
	var final_unit := _feature_component_with_connections(final_shell,
		final_connections, [corner] as Array[FabricUnit], false,
		endpoint_lineage_seams)
	return [first, corner, final_unit] as Array[FabricUnit]


static func _feature_component_shell(feature: WarrenFeatureReservation,
		index: int, record: Dictionary) -> FabricUnit:
	return FabricUnit.new(StringName("spatial.fabric.%s.component.%02d" % [
		feature.stable_id, index]), StringName(record.recipe_id),
		record.origin as Vector3i, int(record.yaw_quarters))


static func _feature_component_with_connections(shell: FabricUnit,
		connections: Array[Dictionary], bearing_parents: Array[FabricUnit],
		all_connections_bear: bool,
		visual_seams: Array[StringName] = []) -> FabricUnit:
	var parents: Array[StringName] = []
	for parent: FabricUnit in bearing_parents:
		parents.append(parent.stable_id)
	var bonds: Array[Dictionary] = []
	for connection_index in connections.size():
		var connection := connections[connection_index]
		bonds.append(FabricUnit.bond(StringName(connection.own_room),
			StringName(connection.target_unit),
			StringName(connection.target_room)))
		if all_connections_bear or connection_index < bearing_parents.size():
			bonds.append(FabricUnit.bond(StringName(connection.own_bearing),
				StringName(connection.target_unit),
				StringName(connection.target_bearing)))
	return FabricUnit.new(shell.stable_id, shell.recipe_id,
		shell.lattice_origin, shell.yaw_quarters, parents, bonds, &"",
		visual_seams)


static func _matching_room_connections(own: FabricUnit, target: FabricUnit,
		program: SettlementFabricProgram,
		expected_target_cell: Vector3i = Vector3i.ZERO,
		require_expected_cell: bool = false) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var own_recipe := program.recipe(own.recipe_id)
	var target_recipe := program.recipe(target.recipe_id)
	if own_recipe == null or target_recipe == null:
		return out
	for own_socket: Dictionary in own_recipe.sockets:
		var own_room := StringName(own_socket.id)
		if int(own_socket.kind) != FabricRecipe.SocketKind.ROOM \
				or String(own_room).contains(".corner."):
			continue
		for target_socket: Dictionary in target_recipe.sockets:
			var target_room := StringName(target_socket.id)
			if int(target_socket.kind) != FabricRecipe.SocketKind.ROOM \
					or String(target_room).contains(".corner.") \
					or not SettlementFabricPlan._sockets_meet(own, own_socket,
						target, target_socket):
				continue
			if require_expected_cell and _socket_world_cell(target,
					target_socket) != expected_target_cell:
				continue
			var own_bearing := StringName(String(own_room).replace("room.",
				"bearing."))
			var target_bearing := StringName(String(target_room).replace("room.",
				"bearing."))
			var own_bearing_socket := own_recipe.socket(own_bearing)
			var target_bearing_socket := target_recipe.socket(target_bearing)
			if own_bearing_socket.is_empty() or target_bearing_socket.is_empty() \
					or not SettlementFabricPlan._sockets_meet(own,
						own_bearing_socket, target, target_bearing_socket):
				continue
			out.append({"own_room": own_room, "target_unit": target.stable_id,
				"target_room": target_room, "own_bearing": own_bearing,
				"target_bearing": target_bearing})
	return out


static func _matching_market_connections(own: FabricUnit, target: FabricUnit,
		program: SettlementFabricProgram,
		expected_target_cell: Vector3i) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var own_recipe := program.recipe(own.recipe_id)
	var target_recipe := program.recipe(target.recipe_id)
	if own_recipe == null or target_recipe == null:
		return out
	for own_socket: Dictionary in own_recipe.sockets:
		if int(own_socket.kind) != FabricRecipe.SocketKind.MARKET:
			continue
		for target_socket: Dictionary in target_recipe.sockets:
			if int(target_socket.kind) != FabricRecipe.SocketKind.MARKET \
					or _socket_world_cell(target, target_socket) \
						!= expected_target_cell \
					or not SettlementFabricPlan._sockets_meet(own, own_socket,
						target, target_socket):
				continue
			out.append({"own_market": StringName(own_socket.id),
				"target_market": StringName(target_socket.id)})
	return out


static func _socket_world_cell(unit_value: FabricUnit,
		socket: Dictionary) -> Vector3i:
	return FabricRecipe.transform_cell(socket.cell as Vector3i,
		unit_value.lattice_origin, unit_value.yaw_quarters)


static func _feature_units_match_reservation(
		feature: WarrenFeatureReservation, units: Array[FabricUnit],
		program: SettlementFabricProgram) -> bool:
	if feature.kind in [&"room_outcropping", &"frontier_gateway_support"]:
		# The feature's reserved cells are the already-realized upper room. Its
		# construction records are deliberately zero-cell bracket attachments;
		# requiring them to reproduce the room would duplicate occupied mass.
		for unit: FabricUnit in units:
			var attachment := program.recipe(unit.recipe_id)
			if attachment == null \
					or not attachment.has_tag(&"cantilever_support") \
					or not attachment.solid_cells.is_empty() \
					or not attachment.walk_cells.is_empty() \
					or not attachment.headroom_cells.is_empty():
				return false
		return not units.is_empty()
	var realized: Dictionary = {}
	for unit: FabricUnit in units:
		var recipe := program.recipe(unit.recipe_id)
		if recipe == null:
			return false
		for cells: Array[Vector3i] in [recipe.solid_cells,
				recipe.headroom_cells, recipe.walk_cells]:
			for local_cell: Vector3i in cells:
				realized[FabricRecipe.transform_cell(local_cell,
					unit.lattice_origin, unit.yaw_quarters)] = true
	var reserved: Dictionary = {}
	for cell: Vector3i in feature.reserved_cells:
		reserved[cell] = true
	return _same_cell_set(realized, reserved)


static func _constructed_feature_count(source: WarrenSpatialPlan) -> int:
	var count := 0
	for feature: WarrenFeatureReservation in source.features:
		count += int(not feature.construction_records.is_empty())
	return count


static func compile_roof_units(source: WarrenSpatialPlan,
		program: SettlementFabricProgram,
		room_units: Array[FabricUnit],
		fixed_feature_units: Array[FabricUnit] = [],
		collision_flattened_rooms: Dictionary = {},
		collision_flattened_component_count: int = 0) -> Array[FabricUnit]:
	last_failure = ""
	last_audit = {}
	if source == null or not source.is_sealed() or program == null \
			or room_units.is_empty():
		last_failure = "missing spatial plan, vocabulary, or compiled rooms"
		return [] as Array[FabricUnit]
	var room_by_id: Dictionary = {}
	var room_id_by_cell: Dictionary = {}
	for building: WarrenBuildingVolume in source.buildings:
		for room: WarrenRoomStamp in building.room_records:
			room_by_id[room.stable_id] = room
			for cell: Vector3i in room.private_cells:
				room_id_by_cell[cell] = room.stable_id
	var unit_by_room: Dictionary = {}
	var unit_by_private_cell: Dictionary = {}
	for unit: FabricUnit in room_units:
		var room_id := StringName(String(unit.stable_id).trim_prefix(
			"spatial.fabric."))
		if not room_by_id.has(room_id):
			last_failure = "room unit %s has no spatial stamp" % unit.stable_id
			return [] as Array[FabricUnit]
		unit_by_room[room_id] = unit
		var room := room_by_id[room_id] as WarrenRoomStamp
		for cell: Vector3i in room.private_cells:
			unit_by_private_cell[cell] = unit.stable_id
	var probe := SettlementFabricPlan.new(&"spatial.roof-selection")
	for recipe: FabricRecipe in program.recipes():
		if not probe.register_recipe(recipe):
			last_failure = "roof selection could not register recipe %s" % \
				recipe.recipe_id
			return [] as Array[FabricUnit]
	for room_unit: FabricUnit in room_units:
		if not probe.add_unit(room_unit):
			last_failure = "roof selection rejected source room %s: %s" % [
				room_unit.stable_id, probe.last_rejection]
			return [] as Array[FabricUnit]
	for feature_unit: FabricUnit in fixed_feature_units:
		if not probe.add_unit(feature_unit):
			last_failure = "roof selection rejected fixed feature %s: %s" % [
				feature_unit.stable_id, probe.last_rejection]
			return [] as Array[FabricUnit]
	var roof_faces_by_room := _roof_faces_by_room(source, room_id_by_cell)
	var roof_neighborhood := _spatial_roof_neighborhood(source,
		room_by_id, roof_faces_by_room)
	if roof_neighborhood.is_empty() and not last_failure.is_empty():
		return [] as Array[FabricUnit]
	var roof_proposal_by_room := roof_neighborhood.get(
		"proposal_by_room", {}) as Dictionary
	# A late measured-clearance failure is allowed to flatten a complete joined
	# campaign, but never just the room that happened to be visited first.  Apply
	# the retry decision only after topology has exposed the connected campaign so
	# every ridge/valley member changes treatment together.
	for room_id_value: Variant in collision_flattened_rooms.keys():
		var flattened_room_id := StringName(room_id_value)
		if not roof_proposal_by_room.has(flattened_room_id):
			continue
		var flattened_proposal := (roof_proposal_by_room[
			flattened_room_id] as Dictionary).duplicate(true)
		flattened_proposal["flat_roof"] = true
		flattened_proposal["roof_junction_rules"] = [] as Array[Dictionary]
		roof_proposal_by_room[flattened_room_id] = flattened_proposal
	var room_ids: Array[StringName] = []
	room_ids.assign(roof_faces_by_room.keys())
	room_ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		var left := room_by_id[a] as WarrenRoomStamp
		var right := room_by_id[b] as WarrenRoomStamp
		return left.lattice_origin.y < right.lattice_origin.y \
			if left.lattice_origin.y != right.lattice_origin.y \
			else String(a) < String(b))
	var out: Array[FabricUnit] = []
	var source_face_count := 0
	var realized_face_count := 0
	var pitched_count := 0
	var flat_count := 0
	var flat_terrace_count := 0
	var flat_garden_count := 0
	var rich_flat_garden_count := 0
	var rich_flat_garden_fallback_count := 0
	var micro_flat_garden_count := 0
	var flat_garden_rejections: Array[Dictionary] = []
	var flat_roof_recipe_counts: Dictionary = {}
	var lived_in_flat_terrace_count := 0
	var awning_flat_terrace_count := 0
	var furnished_flat_terrace_count := 0
	var lamped_flat_terrace_count := 0
	var cap_count := 0
	var lean_to_cap_count := 0
	var macro_gable_cap_count := 0
	var macro_gable_fallback_count := 0
	var terminal_macro_cap_fallback_count := 0
	var terrace_cap_count := 0
	var garden_cap_count := 0
	var terrace_cap_fallback_count := 0
	var garden_cap_fallback_count := 0
	var one_storey_chimney_roof_count := 0
	var rejected_pitched_count := 0
	var rejected_flat_count := 0
	var dormered_pitched_roof_count := 0
	var paired_dormer_roof_count := 0
	var rejected_pitched_details: Array[Dictionary] = []
	var pitched_roof_family_counts := {&"orange": 0, &"blue": 0,
		&"boarded": 0}
	var pitched_roof_recipe_counts: Dictionary = {}
	var exposed_roof_room_kind_counts: Dictionary = {}
	var exposed_roof_feature_counts: Dictionary = {}
	var alternate_pitched_roof_count := 0
	var quarter_turned_square_roof_count := 0
	var pending_roof_trims: Array[Dictionary] = []
	var atomic_neighborhood_roof_count := 0
	for room_id: StringName in room_ids:
		var room := room_by_id[room_id] as WarrenRoomStamp
		exposed_roof_room_kind_counts[room.kind] = int(
			exposed_roof_room_kind_counts.get(room.kind, 0)) + 1
		exposed_roof_feature_counts[room.roof_feature] = int(
			exposed_roof_feature_counts.get(room.roof_feature, 0)) + 1
		var parent_unit := unit_by_room[room_id] as FabricUnit
		var face_cells := roof_faces_by_room[room_id] as Array[Vector3i]
		source_face_count += face_cells.size()
		var full := _is_full_roof_plate(room, face_cells)
		var room_seams := _roof_room_seams(source.grid, room,
			unit_by_private_cell, parent_unit.stable_id)
		var selected := false
		var attempt_failures := PackedStringArray()
		var neighborhood_proposal := roof_proposal_by_room.get(room_id,
			{}) as Dictionary
		var requires_atomic_neighborhood := not neighborhood_proposal.is_empty() \
			and not bool(neighborhood_proposal.get("flat_roof", false)) \
			and not (neighborhood_proposal.get(
				"roof_junction_rules", []) as Array).is_empty()
		if full and not _touches_public_air(source.grid, face_cells):
			var pitched_candidates := _full_roof_candidates(room,
				source.world_seed, neighborhood_proposal)
			var pitched_rejections: Array[Dictionary] = []
			for candidate_index in pitched_candidates.size():
				var candidate := pitched_candidates[candidate_index]
				var pitched_id := StringName(candidate.recipe_id)
				var yaw_offset := int(candidate.yaw_offset)
				var pitched := _full_roof_unit(room_id, room, parent_unit,
					pitched_id, _roof_seams_for_candidate(room_seams,
						parent_unit.stable_id, out, fixed_feature_units),
					yaw_offset)
				var pitched_recipe := program.recipe(pitched_id)
				if pitched_recipe == null:
					last_failure = "missing full roof recipe %s" % pitched_id
					return [] as Array[FabricUnit]
				if _unit_touches_public_air(source.grid, pitched, pitched_recipe):
					var air_rejection := "exact roof volume enters public air"
					pitched_rejections.append({"recipe_id": pitched_id,
						"yaw_offset": yaw_offset, "rejection": air_rejection})
					attempt_failures.append("pitched %s/r%d: %s" % [pitched_id,
						yaw_offset, air_rejection])
					continue
				if probe.add_unit(pitched):
					out.append(pitched)
					if bool(candidate.get("uses_roof_neighborhood", false)):
						atomic_neighborhood_roof_count += 1
						for trim_value: Variant in candidate.get(
								"trim_components", []):
							pending_roof_trims.append({
								"room_id": room_id,
								"roof_unit_id": pitched.stable_id,
								"component": (trim_value as Dictionary).duplicate(true),
							})
					realized_face_count += face_cells.size()
					pitched_count += 1
					alternate_pitched_roof_count += int(candidate_index > 0)
					quarter_turned_square_roof_count += int(yaw_offset != 0)
					var roof_family := _roof_recipe_family(pitched_id)
					pitched_roof_family_counts[roof_family] = int(
						pitched_roof_family_counts.get(roof_family, 0)) + 1
					pitched_roof_recipe_counts[pitched_id] = int(
						pitched_roof_recipe_counts.get(pitched_id, 0)) + 1
					one_storey_chimney_roof_count += int(
						room.source_storey_index == 0 and String(pitched_id) \
							.contains(".short."))
					dormered_pitched_roof_count += int(pitched_recipe.has_tag(
						&"dormer"))
					paired_dormer_roof_count += int(pitched_recipe.has_tag(
						&"paired_dormer"))
					selected = true
					break
				pitched_rejections.append({"recipe_id": pitched_id,
					"yaw_offset": yaw_offset, "rejection": probe.last_rejection})
				attempt_failures.append("pitched %s/r%d: %s" % [pitched_id,
					yaw_offset, probe.last_rejection])
			if not selected:
				rejected_pitched_count += 1
				if rejected_pitched_details.size() < 32:
					rejected_pitched_details.append({"room_id": room_id,
						"attempts": pitched_rejections})
		if selected:
			continue
		# A joined roof is one atomic neighborhood choice. Falling back one member
		# at a time produced the capture defect where a pitched eave stopped against
		# an unrelated flat plate or a differently aligned gable. Reject this whole
		# construction and let the bounded selector choose another composition.
		if requires_atomic_neighborhood:
			var campaign := _roof_neighborhood_component(
				roof_proposal_by_room, room_id)
			var retry_flattened := collision_flattened_rooms.duplicate(true)
			for campaign_room_id: StringName in campaign:
				retry_flattened[campaign_room_id] = true
			if retry_flattened.size() == collision_flattened_rooms.size():
				last_failure = "atomic roof neighborhood for %s rejected after its complete campaign was flattened: %s" % [
					room_id, "; ".join(attempt_failures)]
				return [] as Array[FabricUnit]
			return compile_roof_units(source, program, room_units,
				fixed_feature_units, retry_flattened,
				collision_flattened_component_count + 1)
		if full and not _touches_public_air(source.grid, face_cells):
			var flat_id := _flat_roof_recipe_id(room)
			var flat := _full_roof_unit(room_id, room, parent_unit, flat_id,
				_roof_seams_for_candidate(room_seams, parent_unit.stable_id, out,
					fixed_feature_units))
			var flat_recipe := program.recipe(flat_id)
			if flat_recipe == null:
				last_failure = "missing exact flat roof recipe %s" % flat_id
				return [] as Array[FabricUnit]
			if _unit_touches_public_air(source.grid, flat, flat_recipe):
				rejected_flat_count += 1
				attempt_failures.append(
					"flat: exact roof volume enters public air")
			else:
				if probe.add_unit(flat):
					var base_garden_id := StringName("%s.garden" % flat_id)
					var garden_ids: Array[StringName] = [StringName(
						"%s.rich" % base_garden_id), base_garden_id,
						StringName("%s.micro" % base_garden_id),
						StringName("%s.micro.0" % base_garden_id),
						StringName("%s.micro.1" % base_garden_id),
						StringName("%s.micro.2" % base_garden_id),
						StringName("%s.micro.3" % base_garden_id)]
					var garden: FabricUnit
					var garden_selected := false
					for garden_index in garden_ids.size():
						var garden_id := garden_ids[garden_index]
						if program.recipe(garden_id) == null:
							continue
						garden = _flat_roof_garden_unit(room_id, flat,
							garden_id)
						if probe.add_unit(garden):
							garden_selected = true
							rich_flat_garden_count += int(garden_index == 0)
							rich_flat_garden_fallback_count += int(
								garden_index > 0)
							var garden_recipe := program.recipe(garden_id)
							micro_flat_garden_count += int(garden_recipe != null \
								and garden_recipe.has_tag(&"micro_roof_garden"))
							break
						flat_garden_rejections.append({"room_id": room_id,
							"recipe_id": garden_id,
							"rejection": probe.last_rejection})
					if not garden_selected:
						last_failure = ("flat roof %s has no collision-free measured " \
							+ "accent: %s") % [room_id,
							JSON.stringify(flat_garden_rejections.slice(
								maxi(0, flat_garden_rejections.size() - 3)))]
						return [] as Array[FabricUnit]
					out.append(flat)
					out.append(garden)
					realized_face_count += face_cells.size()
					flat_count += 1
					flat_garden_count += 1
					flat_roof_recipe_counts[flat_id] = int(
						flat_roof_recipe_counts.get(flat_id, 0)) + 1
					continue
				rejected_flat_count += 1
				attempt_failures.append("flat: %s" % probe.last_rejection)
		var pieces := _cap_pieces(face_cells)
		if pieces.is_empty():
			last_failure = "no finite setback cap partition fits roof region for %s (%s; %s)" \
				% [room_id, "; ".join(attempt_failures),
					_cap_failure_diagnostic(source.grid, face_cells)]
			return [] as Array[FabricUnit]
		for row_index in pieces.size():
			var piece := pieces[row_index] as Dictionary
			var macro_piece := StringName(piece.kind) == &"stamp"
			var row := piece.cells as Array[Vector3i]
			var cap := _setback_gable_placement(piece, room,
				source.world_seed) \
				if macro_piece \
				else _cap_placement(source.grid, row, room, source.world_seed)
			if cap.is_empty():
				last_failure = "no native setback cap fits row %d for %s" % [
					row_index, room_id]
				return [] as Array[FabricUnit]
			if not macro_piece:
				var lean_to := _setback_lean_to_placement(source,
					row, room, cap, unit_by_room)
				if not lean_to.is_empty():
					cap = lean_to
			# A setback roof is not a license to intersect every room that happens
			# to share a party wall with its parent.  That broad exception admitted
			# little gables deep into the valley between two continuing upper rooms.
			# Multiple pieces over this one parent and physically attached feature
			# units remain explicit seams; a lean-to adds its one measured wall seam
			# below.  An ordinary macro gable that clips a neighbor must therefore
			# take the plain or flat fallback.
			var seams := _roof_seams_for_candidate([] as Array[StringName],
				parent_unit.stable_id, out, fixed_feature_units)
			var end_wall_room_ids: Array[StringName] = []
			if not macro_piece:
				end_wall_room_ids = _setback_wall_room_ids(row,
					unit_by_private_cell)
			var upper_room_unit_id := StringName(cap.get(
				"upper_room_unit_id", &""))
			if not upper_room_unit_id.is_empty() \
					and not seams.has(upper_room_unit_id):
				seams.append(upper_room_unit_id)
			for upper_id_value: Variant in cap.get(
					"upper_room_unit_ids", []) as Array:
				var upper_id := StringName(upper_id_value)
				if not upper_id.is_empty() and not seams.has(upper_id):
					seams.append(upper_id)
				seams = _unique_sorted_names(seams)
			var cap_unit := _cap_unit(room_id, row_index, room, parent_unit,
				cap, seams)
			_append_shallow_prior_roof_seams(cap_unit, room_seams, out,
				program)
			_append_shallow_room_seams(cap_unit, end_wall_room_ids,
				unit_by_room, unit_by_private_cell, program)
			var cap_recipe := program.recipe(StringName(cap.recipe_id))
			var cap_enters_public_air := cap_recipe != null \
				and _unit_touches_public_air(source.grid, cap_unit, cap_recipe)
			if cap_enters_public_air or not probe.add_unit(cap_unit):
				var terrace_rejection := probe.last_rejection
				if cap_enters_public_air:
					terrace_rejection = "exact setback roof volume enters public air"
				if macro_piece:
					var fallback_ids: Array[StringName] = []
					var plain_id := _plain_pitched_recipe_id(
						StringName(cap.recipe_id))
					if plain_id != StringName(cap.recipe_id):
						fallback_ids.append(plain_id)
					fallback_ids.append(_flat_roof_recipe_id_for_kind(
						StringName(piece.room_kind)))
					var fallback_failures := PackedStringArray([
						terrace_rejection])
					var fallback_selected := false
					for fallback_id: StringName in fallback_ids:
						cap["recipe_id"] = fallback_id
						cap_unit = _cap_unit(room_id, row_index, room,
							parent_unit, cap, seams)
						_append_shallow_prior_roof_seams(cap_unit, room_seams,
							out, program)
						_append_shallow_room_seams(cap_unit, end_wall_room_ids,
							unit_by_room, unit_by_private_cell, program)
						var fallback_recipe := program.recipe(fallback_id)
						if fallback_recipe != null \
								and not _unit_touches_public_air(source.grid,
									cap_unit, fallback_recipe) \
								and probe.add_unit(cap_unit):
							fallback_selected = true
							break
						fallback_failures.append("%s: %s" % [fallback_id,
							probe.last_rejection])
					if not fallback_selected:
						# A compound shoulder is admitted because its exact cells can be
						# partitioned into authored shapes.  If the recognizable gable's
						# measured eave cannot clear a neighboring macro room, preserve the
						# same lossless partition with native terminal strips.  Prefer the
						# typed lean-to when a complete row meets one upper facade; otherwise
						# use the shallow plain cap.  This is an atomic fallback: no first
						# strip is committed unless every strip fits.
						var terminal := _terminal_macro_cap_fallback(source,
							program, probe, row, row_index, room_id, room,
							parent_unit, seams, room_seams, unit_by_room,
							unit_by_private_cell, out)
						var terminal_units := terminal.get("units",
							[] as Array[FabricUnit]) as Array[FabricUnit]
						if terminal_units.is_empty():
							fallback_failures.append(String(terminal.get(
								"failure", "terminal strip fallback rejected")))
							last_failure = "macro setback roof %d for %s and its complete fallbacks were rejected: %s" % [
								row_index, room_id, "; ".join(fallback_failures)]
							return [] as Array[FabricUnit]
						for terminal_unit: FabricUnit in terminal_units:
							if not probe.add_unit(terminal_unit):
								last_failure = "proved terminal roof fallback changed before commit for %s: %s" % [
									room_id, probe.last_rejection]
								return [] as Array[FabricUnit]
							out.append(terminal_unit)
							cap_count += 1
							lean_to_cap_count += int(String(
								terminal_unit.recipe_id).begins_with(
									"roof.setback.lean."))
						realized_face_count += row.size()
						macro_gable_fallback_count += 1
						terminal_macro_cap_fallback_count += 1
						continue
					macro_gable_fallback_count += 1
				elif String(cap.recipe_id).contains(".terrace.") \
						or String(cap.recipe_id).contains(".garden.") \
						or String(cap.recipe_id).contains(".lean."):
					var rejected_garden := String(cap.recipe_id).contains(
						".garden.")
					cap["recipe_id"] = StringName("roof.setback.cap.%d" \
						% row.size())
					cap_unit = _cap_unit(room_id, row_index, room,
						parent_unit, cap, seams)
					_append_shallow_prior_roof_seams(cap_unit, room_seams, out,
						program)
					_append_shallow_room_seams(cap_unit, end_wall_room_ids,
						unit_by_room, unit_by_private_cell, program)
					if not probe.add_unit(cap_unit):
						last_failure = "setback terrace and plain cap %d for %s were rejected after %s: %s; %s" \
							% [row_index, room_id, "; ".join(attempt_failures),
								terrace_rejection, probe.last_rejection]
						return [] as Array[FabricUnit]
					garden_cap_fallback_count += int(rejected_garden)
					terrace_cap_fallback_count += int(not rejected_garden)
				else:
					last_failure = "exact setback cap %d for %s was rejected after %s: %s" \
						% [row_index, room_id, "; ".join(attempt_failures),
							probe.last_rejection]
					return [] as Array[FabricUnit]
			out.append(cap_unit)
			realized_face_count += row.size()
			cap_count += 1
			lean_to_cap_count += int(String(cap_unit.recipe_id) \
				.begins_with("roof.setback.lean."))
			macro_gable_cap_count += int(macro_piece and not String(
				cap_unit.recipe_id).begins_with("roof.flat."))
			terrace_cap_count += int(String(cap_unit.recipe_id) \
				.contains(".terrace."))
			garden_cap_count += int(String(cap_unit.recipe_id) \
				.contains(".garden."))
	var roof_unit_by_room: Dictionary = {}
	for roof_unit: FabricUnit in out:
		var roof_text := String(roof_unit.stable_id)
		if roof_text.begins_with("spatial.roof.") \
				and not roof_text.contains(".cap"):
			roof_unit_by_room[StringName(roof_text.trim_prefix(
				"spatial.roof."))] = roof_unit
	var roof_trim_count := 0
	var rejected_roof_trim_count := 0
	var rejected_roof_trim_details: Array[Dictionary] = []
	for pending: Dictionary in pending_roof_trims:
		var room_id := StringName(pending.room_id)
		var parent_roof := roof_unit_by_room.get(room_id) as FabricUnit
		var component := pending.component as Dictionary
		if parent_roof == null:
			last_failure = "roof trim %s lost its bearing roof" % room_id
			return [] as Array[FabricUnit]
		var side := int(component.get("roof_junction_side", -1))
		var side_name := "negative" \
			if side == FabricRoofTopologyPlan.Side.EAVE_NEGATIVE else "positive"
		var seams: Array[StringName] = []
		for seam_value: Variant in component.get("neighbor_room_ids", []):
			var neighbor_room_id := StringName(seam_value)
			# A classified valley/eave trim physically seals to both the
			# neighboring roof and its wall plate.  The roof is not a proxy for
			# that room: on stepped contacts the authored trim deliberately
			# reaches the neighboring facade before it reaches the roof volume.
			var neighbor_room := unit_by_room.get(neighbor_room_id) as FabricUnit
			if neighbor_room != null:
				seams.append(neighbor_room.stable_id)
			var neighbor_roof := roof_unit_by_room.get(
				neighbor_room_id) as FabricUnit
			if neighbor_roof != null:
				seams.append(neighbor_roof.stable_id)
		seams = _unique_sorted_names(seams)
		var trim := FabricUnit.new(StringName("%s.trim.%02d" % [
			parent_roof.stable_id, roof_trim_count]),
			StringName(component.recipe_id), component.origin as Vector3i,
			int(component.yaw_quarters),
			[parent_roof.stable_id] as Array[StringName],
			[FabricUnit.bond(&"bearing.bottom", parent_roof.stable_id,
				StringName("bearing.junction.eave.%s" % side_name))] \
				as Array[Dictionary], &"", seams)
		if not probe.add_unit(trim):
			# The two complete roof shells remain watertight when optional flashing
			# cannot fit a third intersecting setback roof. Omitting that trim is a
			# coherent atomic fallback; never flatten just one side of the campaign.
			rejected_roof_trim_count += 1
			if rejected_roof_trim_details.size() < 16:
				rejected_roof_trim_details.append({"trim_id": trim.stable_id,
					"rejection": probe.last_rejection})
			continue
		out.append(trim)
		roof_trim_count += 1
	if realized_face_count != source_face_count:
		last_failure = "roof realization covered %d of %d authoritative faces" % [
			realized_face_count, source_face_count]
		return [] as Array[FabricUnit]
	last_audit = {
		"source_roof_face_count": source_face_count,
		"realized_roof_face_count": realized_face_count,
		"roofed_room_count": room_ids.size(),
		"roof_unit_count": out.size(),
		"pitched_roof_count": pitched_count,
		"flat_roof_count": flat_count,
		"flat_roof_terrace_count": flat_terrace_count,
		"flat_roof_garden_count": flat_garden_count,
		"rich_flat_roof_garden_count": rich_flat_garden_count,
		"rich_flat_roof_garden_fallback_count":
			rich_flat_garden_fallback_count,
		"micro_flat_roof_garden_count": micro_flat_garden_count,
		"flat_roof_garden_rejections": flat_garden_rejections,
		"flat_roof_recipe_counts": flat_roof_recipe_counts,
		"lived_in_flat_roof_terrace_count": lived_in_flat_terrace_count,
		"awning_flat_roof_terrace_count": awning_flat_terrace_count,
		"furnished_flat_roof_terrace_count": furnished_flat_terrace_count,
		"lamped_flat_roof_terrace_count": lamped_flat_terrace_count,
		"bare_flat_roof_count": flat_count - flat_terrace_count \
			- flat_garden_count,
		"setback_cap_unit_count": cap_count,
		"setback_lean_to_unit_count": lean_to_cap_count,
		"setback_macro_gable_unit_count": macro_gable_cap_count,
		"setback_macro_gable_fallback_count": macro_gable_fallback_count,
		"setback_terminal_macro_fallback_count": \
			terminal_macro_cap_fallback_count,
		"setback_terrace_unit_count": terrace_cap_count,
		"setback_garden_unit_count": garden_cap_count,
		"setback_dressed_unit_count": terrace_cap_count + garden_cap_count,
		"setback_plain_cap_unit_count": cap_count - terrace_cap_count \
			- garden_cap_count,
		"setback_terrace_fallback_count": terrace_cap_fallback_count,
		"setback_garden_fallback_count": garden_cap_fallback_count,
		"one_storey_chimney_roof_count": one_storey_chimney_roof_count,
		"dormered_pitched_roof_count": dormered_pitched_roof_count,
		"paired_dormer_roof_count": paired_dormer_roof_count,
		"rejected_pitched_count": rejected_pitched_count,
		"rejected_pitched_details": rejected_pitched_details,
		"rejected_flat_count": rejected_flat_count,
		"pitched_roof_family_counts": pitched_roof_family_counts,
		"pitched_roof_recipe_counts": pitched_roof_recipe_counts,
		"exposed_roof_room_kind_counts": exposed_roof_room_kind_counts,
		"exposed_roof_feature_counts": exposed_roof_feature_counts,
		"alternate_pitched_roof_count": alternate_pitched_roof_count,
		"quarter_turned_square_roof_count": quarter_turned_square_roof_count,
		"roof_neighborhood_join_count": int(roof_neighborhood.get(
			"junction_count", 0)),
		"continuous_ridge_join_count": int(roof_neighborhood.get(
			"ridge_continuation_count", 0)),
		"parallel_valley_join_count": int(roof_neighborhood.get(
			"parallel_valley_count", 0)),
		"perpendicular_valley_join_count": int(roof_neighborhood.get(
			"perpendicular_valley_count", 0)),
		"roof_neighborhood_flattened_room_count": int(roof_neighborhood.get(
			"flattened_room_count", 0)),
		"roof_junction_trim_unit_count": roof_trim_count,
		"rejected_optional_roof_trim_count": rejected_roof_trim_count,
		"rejected_optional_roof_trim_details": rejected_roof_trim_details,
		"atomic_neighborhood_roof_count": atomic_neighborhood_roof_count,
		"broken_atomic_roof_neighborhood_count": 0,
		"collision_flattened_roof_room_count": collision_flattened_rooms.size(),
		"collision_flattened_roof_component_count": \
			collision_flattened_component_count,
	}
	return out


static func _roof_neighborhood_component(proposal_by_room: Dictionary,
		start_room_id: StringName) -> Array[StringName]:
	## Return the complete joined campaign around one measured collision.  The
	## graph includes stepped joins as well as equal-height continuations: a flat
	## interruption at either kind of authored seam is the visual defect this
	## retry exists to prevent.
	var out: Array[StringName] = []
	var pending: Array[StringName] = [start_room_id]
	var seen: Dictionary = {start_room_id: true}
	while not pending.is_empty():
		var room_id: StringName = pending.pop_back()
		out.append(room_id)
		var proposal := proposal_by_room.get(room_id, {}) as Dictionary
		for rule: Dictionary in proposal.get(
				"roof_junction_rules", []) as Array:
			var neighbor_id := StringName(rule.get("neighbor_id", &""))
			if neighbor_id == &"" or seen.has(neighbor_id) \
					or not proposal_by_room.has(neighbor_id):
				continue
			seen[neighbor_id] = true
			pending.append(neighbor_id)
	out.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	return out


static func _full_roof_unit(room_id: StringName, room: WarrenRoomStamp,
		parent_unit: FabricUnit, recipe_id: StringName,
		seams: Array[StringName], yaw_offset: int = 0) -> FabricUnit:
	return FabricUnit.new(StringName("spatial.roof.%s" % room_id), recipe_id,
		room.lattice_origin + Vector3i.UP * WarrenSpatialGrid.STOREY_CELLS,
		posmod(room.yaw_quarters + yaw_offset, 4),
		[parent_unit.stable_id] as Array[StringName],
		[FabricUnit.bond(&"bearing.bottom", parent_unit.stable_id,
			&"bearing.top")] as Array[Dictionary], &"", seams)


static func _flat_roof_garden_unit(room_id: StringName,
		flat_roof: FabricUnit, recipe_id: StringName) -> FabricUnit:
	return FabricUnit.new(StringName("spatial.roof.%s.garden" % room_id),
		recipe_id, flat_roof.lattice_origin, flat_roof.yaw_quarters,
		[flat_roof.stable_id] as Array[StringName],
		[FabricUnit.bond(&"bearing.bottom", flat_roof.stable_id,
			&"bearing.top")] as Array[Dictionary])


static func _cap_unit(room_id: StringName, row_index: int,
		room: WarrenRoomStamp, parent_unit: FabricUnit, cap: Dictionary,
		seams: Array[StringName], stable_suffix: String = "") -> FabricUnit:
	var anchor_face := cap.anchor_face as Vector3i
	var parent_local := _inverse_cell(anchor_face, room.lattice_origin,
		room.yaw_quarters)
	var stable_id := StringName("spatial.roof.%s.cap%02d%s" % [room_id,
		row_index, "" if stable_suffix.is_empty() else ".%s" % stable_suffix])
	return FabricUnit.new(stable_id, StringName(cap.recipe_id),
		cap.origin as Vector3i,
		int(cap.yaw_quarters), [parent_unit.stable_id] as Array[StringName],
		[FabricUnit.bond(&"bearing.bottom", parent_unit.stable_id,
			SettlementFabricProgram._bearing_cell_socket_id(&"top",
				parent_local.x, parent_local.z))] as Array[Dictionary], &"", seams)


static func _terminal_macro_cap_fallback(source: WarrenSpatialPlan,
		program: SettlementFabricProgram, probe: SettlementFabricPlan,
		face_cells: Array[Vector3i], row_index: int, room_id: StringName,
		room: WarrenRoomStamp, parent_unit: FabricUnit,
		base_seams: Array[StringName], neighbor_room_unit_ids: Array[StringName],
		unit_by_room: Dictionary, unit_by_private_cell: Dictionary,
		prior_roofs: Array[FabricUnit]) -> Dictionary:
	## Replace one colliding macro gable with a complete, lossless set of native
	## strips.  The two phases deliberately form a tiny rule table: rows abutting
	## a complete upper facade first become lean-tos; if that measured asset does
	## not fit, every row falls back together to its shallow cap.
	var rows := _terminal_cap_rows(face_cells)
	if rows.is_empty():
		return {"units": [] as Array[FabricUnit],
			"failure": "macro face set has no terminal strip partition"}
	var failures := PackedStringArray()
	for use_lean_to: bool in [true, false]:
		var candidates: Array[FabricUnit] = []
		var candidate_failure := ""
		for strip_index in rows.size():
			var strip := rows[strip_index] as Array[Vector3i]
			var cap := _cap_placement(source.grid, strip, room,
				source.world_seed)
			if cap.is_empty():
				candidate_failure = "no native cap placement for terminal strip %d" \
					% strip_index
				break
			cap["recipe_id"] = StringName("roof.setback.cap.%d" % strip.size())
			if use_lean_to:
				var lean_to := _setback_lean_to_placement(source, strip, room,
					cap, unit_by_room)
				if not lean_to.is_empty():
					cap = lean_to
			var seams: Array[StringName] = []
			seams.assign(base_seams)
			var upper_id := StringName(cap.get("upper_room_unit_id", &""))
			if not upper_id.is_empty() and not seams.has(upper_id):
				seams.append(upper_id)
			for earlier: FabricUnit in candidates:
				if not seams.has(earlier.stable_id):
					seams.append(earlier.stable_id)
			seams = _unique_sorted_names(seams)
			var unit := _cap_unit(room_id, row_index, room, parent_unit, cap,
				seams, "terminal%02d" % strip_index)
			_append_shallow_prior_roof_seams(unit, neighbor_room_unit_ids,
				prior_roofs, program)
			_append_shallow_room_seams(unit, [] as Array[StringName],
				unit_by_room, unit_by_private_cell, program)
			var recipe := program.recipe(unit.recipe_id)
			if recipe == null or _unit_touches_public_air(source.grid, unit,
					recipe):
				candidate_failure = "terminal strip %d enters public air or lacks recipe %s" \
					% [strip_index, unit.recipe_id]
				break
			candidates.append(unit)
		if candidate_failure.is_empty():
			var fit := _roof_units_fit_probe(program, probe.units, candidates)
			if bool(fit.get("fits", false)):
				return {"units": candidates}
			candidate_failure = String(fit.get("failure",
				"terminal strip transaction rejected"))
		failures.append("%s phase: %s" % [
			"lean-to" if use_lean_to else "plain", candidate_failure])
	return {"units": [] as Array[FabricUnit], "failure": "; ".join(failures)}


static func _roof_units_fit_probe(program: SettlementFabricProgram,
		existing_units: Array[FabricUnit], candidates: Array[FabricUnit]) \
		-> Dictionary:
	## SettlementFabricPlan has transactional single-unit admission but not a
	## multi-unit rollback. Rebuild this rare fallback's small CPU-only probe so a
	## partial terminal roof can never leak into the authoritative transaction.
	var trial := SettlementFabricPlan.new(&"spatial.terminal-roof-probe")
	for recipe: FabricRecipe in program.recipes():
		if not trial.register_recipe(recipe):
			return {"fits": false, "failure": "could not register recipe %s" \
				% recipe.recipe_id}
	for existing: FabricUnit in existing_units:
		if not trial.add_unit(existing):
			return {"fits": false, "failure": "could not rebuild existing unit %s: %s" \
				% [existing.stable_id, trial.last_rejection]}
	for candidate: FabricUnit in candidates:
		if not trial.add_unit(candidate):
			return {"fits": false, "failure": trial.last_rejection}
	return {"fits": true}


static func _setback_lean_to_placement(source: WarrenSpatialPlan,
		face_cells: Array[Vector3i], room: WarrenRoomStamp,
		cap: Dictionary, unit_by_room: Dictionary) -> Dictionary:
	## A lean-to is legal only where one complete long edge of the cap meets one
	## continuing upper room. This is a measured wall/roof seam, not decoration
	## inferred from proximity. One-cell caps have no 3 m repeat and remain plain.
	if source == null or face_cells.size() not in [2, 4, 6] \
			or cap.is_empty():
		return {}
	var origin := cap.origin as Vector3i
	var yaw := int(cap.yaw_quarters)
	var owner_by_side: Dictionary = {}
	for side in [-1, 1]:
		var side_owners: Dictionary = {}
		var complete := true
		for local_x in face_cells.size():
			var row_cell := FabricRecipe.transform_cell(
				Vector3i(local_x, 0, 0), origin, yaw)
			var side_direction := FabricRecipe.transform_direction(
				Vector3i(0, 0, side), yaw)
			var upper_neighbor := row_cell + Vector3i.UP + side_direction
			if source.grid.use_at(upper_neighbor) \
					!= WarrenSpatialGrid.Use.PRIVATE_VOLUME:
				complete = false
				break
			var owner := source.grid.owner_name_at(upper_neighbor)
			if owner.is_empty():
				complete = false
				break
			side_owners[owner] = true
		if complete and side_owners.size() == 1:
			owner_by_side[side] = StringName(side_owners.keys()[0])
	if owner_by_side.size() != 1:
		return {}
	var wall_side := int(owner_by_side.keys()[0])
	var upper_room_unit_id := &""
	var upper_building_id := StringName(owner_by_side[wall_side])
	for building: WarrenBuildingVolume in source.buildings:
		if building.stable_id != upper_building_id:
			continue
		for upper_room: WarrenRoomStamp in building.room_records:
			if not unit_by_room.has(upper_room.stable_id):
				continue
			for upper_cell: Vector3i in upper_room.private_cells:
				if source.grid.owner_name_at(upper_cell) == upper_building_id:
					upper_room_unit_id = (unit_by_room[
						upper_room.stable_id] as FabricUnit).stable_id
					break
			if not upper_room_unit_id.is_empty():
				break
		break
	if upper_room_unit_id.is_empty():
		return {}
	var theme := _architectural_district_theme(room.lattice_origin,
		source.world_seed)
	var family := "orange" if theme == &"orange" else "blue"
	return {
		"recipe_id": StringName("roof.setback.lean.%s.%d.%s" % [family,
			face_cells.size(), "negative" if wall_side < 0 else "positive"]),
		"origin": origin,
		"yaw_quarters": yaw,
		"anchor_face": cap.anchor_face,
		"upper_room_unit_id": upper_room_unit_id,
	}


static func _setback_gable_placement(piece: Dictionary,
		room: WarrenRoomStamp, world_seed: int) -> Dictionary:
	## A rectangular island inside a compound shoulder is a small complete house
	## crown, not a collection of deck tiles. Its exact stamp origin/yaw chooses
	## one of the ordinary measured pitched-roof recipes. It does not declare
	## neighboring upper rooms as visual seams: if the measured eave clips one,
	## the common transaction must select the plain or complete flat fallback.
	if StringName(piece.get("kind", &"")) != &"stamp":
		return {}
	var kind := StringName(piece.get("room_kind", &""))
	var origin := piece.get("origin", Vector3i.ZERO) as Vector3i
	var yaw := int(piece.get("yaw_quarters", 0))
	var cells := piece.get("cells", []) as Array[Vector3i]
	if cells.is_empty() or kind not in WarrenRoomStamp.KINDS:
		return {}
	origin.y = cells[0].y + 1
	var theme := _architectural_district_theme(origin, world_seed)
	var family := "orange" if theme == &"orange" else "blue"
	var detail := posmod(Helper._mix64(world_seed ^ String(room.stable_id).hash()
		^ origin.x * 73856093 ^ origin.y * 83492791 ^ origin.z * 19349663), 4)
	var recipe_id: StringName
	match kind:
		&"tower":
			recipe_id = StringName("roof.tower.%s.dormer.%s" % [family,
				"left" if detail % 2 == 0 else "right"])
		&"slim":
			recipe_id = StringName("roof.slim.%s.dormer.%s" % [family,
				"left" if detail % 2 == 0 else "right"])
		&"row":
			recipe_id = StringName("roof.row.%s.dormer.%s" % [family,
				"left" if detail % 2 == 0 else "right"])
		&"building":
			recipe_id = StringName("roof.square.%s.dormer.%s" % [family,
				"left" if detail % 2 == 0 else "right"])
		&"long":
			recipe_id = StringName("roof.long.%s.dormer.%s%s" % [family,
				"pair." if detail >= 2 else "",
				"left" if detail % 2 == 0 else "right"])
		_:
			return {}
	return {"recipe_id": recipe_id, "origin": origin,
		"yaw_quarters": yaw, "anchor_face": origin - Vector3i.UP}


static func _room_recipe_id(room: WarrenRoomStamp, world_seed: int,
		allow_phase_b: bool = true, feature_portal_mask: int = 0) \
		-> StringName:
	var prefix := "room.long" if room.kind == &"long" \
		else "room.slim" if room.kind == &"slim" \
		else "room.row" if room.kind == &"row" \
		else "room.tower" if room.kind == &"tower" else "room"
	if room.terrain_bearing:
		var terrain_recipe := StringName("%s.base.rock%s" % [prefix,
			"" if room.addressed else ".closed"])
		if room.addressed:
			terrain_recipe = SettlementFabricProgram.address_door_phase_recipe_id(
				terrain_recipe, room.address_door_phase)
		return SettlementFabricProgram.feature_portal_recipe_id(terrain_recipe,
			feature_portal_mask) if feature_portal_mask > 0 else terrain_recipe
	var theme := String(_architectural_district_theme(room.lattice_origin,
		world_seed))
	# Some lineages carry a real two-storey masonry plinth above their terrain
	# bearing room. This is a coherent building-level accent, not a random stone
	# module sprinkled through otherwise timber storeys.
	if room.source_storey_index <= 1 and posmod(Helper._mix64(world_seed \
			^ room.lattice_origin.x * 73856093 \
			^ room.lattice_origin.z * 19349663 ^ 0x4d41534f4e5259), 6) == 0:
		theme = "stone"
	var addressed := ".address" if room.addressed else ""
	# Alternate complete facade recipes by storey. The phase-B vocabulary uses a
	# different authored module arrangement plus measured ivy, laundry, or sign
	# projections; its clearance envelope participates in the same compiler
	# transaction, so a detail is kept only when the dense 3D fabric really has
	# room for it. Hashing the horizontal slot prevents every neighboring stack
	# from changing phase on the same floor.
	var phase_b := allow_phase_b and posmod(room.source_storey_index \
		+ room.lattice_origin.x \
		+ room.lattice_origin.z + world_seed, 2) == 1
	var base_recipe_id: StringName
	if room.kind == &"long":
		base_recipe_id = StringName("%s.upper%s.%s.%s" % [prefix, addressed, theme,
			"b" if phase_b else "a"])
	else:
		base_recipe_id = StringName("%s.upper%s.%s%s" % [prefix, addressed, theme,
			".b" if phase_b else ""])
	if room.addressed:
		base_recipe_id = SettlementFabricProgram.address_door_phase_recipe_id(
			base_recipe_id, room.address_door_phase)
	return SettlementFabricProgram.feature_portal_recipe_id(base_recipe_id,
		feature_portal_mask) if feature_portal_mask > 0 else base_recipe_id


static func _full_roof_recipe_id(room: WarrenRoomStamp,
		world_seed: int) -> StringName:
	var district_theme := _architectural_district_theme(room.lattice_origin,
		world_seed)
	# Amber timber quarters share the cool slate roof family. Both compact roof
	# silhouettes have measured slate-palette variants, so the theme remains an
	# honest construction choice rather than metadata over an orange source mesh.
	var orange := district_theme == &"orange"
	var theme := "orange" if orange else "blue"
	if room.kind == &"tower":
		theme = "orange" if posmod(Helper._mix64(world_seed \
			^ room.lattice_origin.x * 19 ^ room.lattice_origin.y * 11 \
			^ room.lattice_origin.z * 23), 2) == 0 else "blue"
		if room.source_storey_index == 0:
			return StringName("roof.tower.short.%s" % theme)
		if room.roof_feature in [1, 2]:
			return StringName("roof.tower.%s.dormer.%s" % [theme,
				"left" if room.roof_feature == 1 else "right"])
		return StringName("roof.tower.chimney.%s" % theme) \
			if room.roof_feature == 3 else StringName("roof.tower.%s" % theme)
	if room.kind == &"slim":
		if room.source_storey_index == 0:
			return StringName("roof.slim.short.%s" % theme)
		if room.roof_feature in [1, 2]:
			return StringName("roof.slim.%s.dormer.%s" % [theme,
				"left" if room.roof_feature == 1 else "right"])
		return StringName("roof.slim.chimney.%s" % theme) \
			if room.roof_feature == 3 else StringName("roof.slim.%s" % theme)
	if room.kind == &"row":
		if room.source_storey_index == 0:
			return StringName("roof.row.short.%s" % theme)
		if room.roof_feature in [1, 2]:
			return StringName("roof.row.%s.dormer.%s" % [theme,
				"left" if room.roof_feature == 1 else "right"])
		return StringName("roof.row.chimney.%s" % theme) \
			if room.roof_feature == 3 else StringName("roof.row.%s" % theme)
	if room.kind == &"long":
		var feature := room.roof_feature
		if feature in [1, 2, 4, 5]:
			return StringName("roof.long.%s.dormer.%s%s" % [theme,
				"pair." if feature in [4, 5] else "",
				"left" if feature in [1, 4] else "right"])
		return StringName("roof.long.%s" % theme)
	if room.roof_feature in [1, 2]:
		return StringName("roof.square.%s.dormer.%s" % [theme,
			"left" if room.roof_feature == 1 else "right"])
	if room.roof_feature == 3:
		return &"roof.square.04" if orange else &"roof.square.blue.plain"
	# The complete boarded shell remains an authored chimney variant, but the
	# ordinary cool square roof should actually read blue. Routing every
	# non-orange square through the boarded LPFV shell was the main source of the
	# orange/brown roof sea despite the nominal 50/50 palette hash.
	return &"roof.square.01" if orange else &"roof.square.blue.plain"


static func _architectural_district_theme(origin: Vector3i,
		world_seed: int) -> StringName:
	var owner := _architectural_district_owner(origin, world_seed)
	var phase := posmod(Helper._mix64(world_seed ^ owner.x * 73856093 \
		^ owner.y * 19349663 ^ 0x50414c45545445), 8)
	# Half the districts are blue, one quarter orange, and one quarter amber.
	# Amber facades also take cool roofs, deliberately offsetting the compact
	# tower vocabulary whose two honest authored roofs are both orange.
	return &"blue" if phase < 4 else &"orange" if phase < 6 else &"amber"


static func _architectural_district_owner(origin: Vector3i,
		world_seed: int) -> Vector2i:
	var base := Vector2i(
		floori(float(origin.x) / float(ARCHITECTURAL_DISTRICT_CELLS)),
		floori(float(origin.z) / float(ARCHITECTURAL_DISTRICT_CELLS)))
	var best_owner := base
	var best_distance := 9223372036854775807
	var best_tie := 9223372036854775807
	for district_z in range(base.y - 1, base.y + 2):
		for district_x in range(base.x - 1, base.x + 2):
			var owner := Vector2i(district_x, district_z)
			var owner_hash := Helper._mix64(world_seed \
				^ district_x * 73856093 ^ district_z * 19349663 \
				^ 0x4449535452494354)
			var jitter_x := posmod(Helper._mix64(owner_hash ^ 0x584a4954544552),
				ARCHITECTURAL_DISTRICT_JITTER * 2 + 1) \
				- ARCHITECTURAL_DISTRICT_JITTER
			var jitter_z := posmod(Helper._mix64(owner_hash ^ 0x5a4a4954544552),
				ARCHITECTURAL_DISTRICT_JITTER * 2 + 1) \
				- ARCHITECTURAL_DISTRICT_JITTER
			var centre := owner * ARCHITECTURAL_DISTRICT_CELLS \
				+ Vector2i(ARCHITECTURAL_DISTRICT_CELLS / 2 + jitter_x,
					ARCHITECTURAL_DISTRICT_CELLS / 2 + jitter_z)
			var delta := Vector2i(origin.x, origin.z) - centre
			var distance := delta.x * delta.x + delta.y * delta.y
			var tie := posmod(owner_hash, 2147483647)
			if distance < best_distance \
					or distance == best_distance and tie < best_tie:
				best_owner = owner
				best_distance = distance
				best_tie = tie
	return best_owner


static func _spatial_roof_neighborhood(source: WarrenSpatialPlan,
		room_by_id: Dictionary, roof_faces_by_room: Dictionary) -> Dictionary:
	## The occupancy grid owns the exposed faces, but a roof is selected from the
	## complete neighborhood. Treating each room independently and then declaring
	## every overlap a visual seam is exactly what produced broken ridges and
	## colliding eaves in dense captures. Reuse the measured junction classifier
	## and module table that already protects the route-first vocabulary.
	var proposals: Array[Dictionary] = []
	for room_id_value: Variant in roof_faces_by_room.keys():
		var room_id := StringName(room_id_value)
		var room := room_by_id.get(room_id) as WarrenRoomStamp
		if room == null:
			continue
		var face_cells := roof_faces_by_room[room_id] as Array[Vector3i]
		if not _is_full_roof_plate(room, face_cells) \
				or _touches_public_air(source.grid, face_cells):
			continue
		proposals.append({
			"stable_id": room_id,
			"kind": room.kind,
			"origin": room.lattice_origin,
			"yaw_quarters": room.yaw_quarters,
			"storeys": 1,
			"route_y": room.lattice_origin.y,
			"roof_feature": room.roof_feature,
			"theme": &"blue",
			"ground_theme": &"blue",
			"facade_phase": 0,
		})
	if proposals.is_empty():
		return {"proposal_by_room": {}, "junction_count": 0,
			"flattened_room_count": 0}
	var topology := FabricRoofTopologyPlan.build(proposals)
	if topology == null:
		last_failure = "could not classify the spatial roof neighborhood"
		return {}
	var by_id: Dictionary = {}
	for proposal: Dictionary in proposals:
		by_id[StringName(proposal.stable_id)] = proposal
	var flattened: Dictionary = {}
	var ids: Array[StringName] = []
	ids.assign(by_id.keys())
	ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	# Reject unsupported junction pairs locally. The fallback is an authored flat
	# terrace over the exact complete room, never an intersecting pitched shell.
	for owner_id: StringName in ids:
		for seam: Dictionary in topology.fact(owner_id).junctions as Array:
			var neighbor_id := StringName(seam.neighbor_id)
			if String(owner_id) >= String(neighbor_id):
				continue
			# The generic table contains experimental valley flashing for isolated
			# module proofs, but full-town captures show that the current authored
			# roof shells still pile their eaves at these crossings. Until a true
			# valley/cross-gable mesh exists, spatial production only promises the
			# continuous-ridge and stepped-wall joins that visually close.
			if not _spatial_roof_join_supported(int(seam.kind)):
				flattened[owner_id] = true
				flattened[neighbor_id] = true
				continue
			var pair: Array[Dictionary] = [
				(by_id[owner_id] as Dictionary).duplicate(true),
				(by_id[neighbor_id] as Dictionary).duplicate(true),
			]
			var pair_topology := FabricRoofTopologyPlan.build(pair)
			if pair_topology == null or FabricRoofJunctionModuleTable.build(
					pair, pair_topology).is_empty():
				flattened[owner_id] = true
				flattened[neighbor_id] = true
	# One authored roof can carry one atomic T-junction. A multi-valley roof is
	# explicitly outside the finite vocabulary and therefore becomes a terrace.
	for owner_id: StringName in ids:
		var perpendicular_count := 0
		for seam: Dictionary in topology.fact(owner_id).junctions as Array:
			perpendicular_count += int(int(seam.kind) \
				== FabricRoofTopologyPlan.JunctionKind.PERPENDICULAR_VALLEY)
		if perpendicular_count > 1:
			flattened[owner_id] = true
	for room_id_value: Variant in flattened.keys():
		(by_id[StringName(room_id_value)] as Dictionary)["flat_roof"] = true
	var styled_proposals: Array[Dictionary] = []
	for room_id: StringName in ids:
		styled_proposals.append(by_id[room_id] as Dictionary)
	var junction_modules := FabricRoofJunctionModuleTable.build(
		styled_proposals, topology)
	if junction_modules.is_empty():
		# A higher-order signature can still be unsupported even when each pair is
		# legal alone. Flatten only the joined roofs and rebuild once; isolated
		# pitched roofs retain their silhouette and dormers.
		for room_id: StringName in ids:
			if not (topology.fact(room_id).junctions as Array).is_empty():
				flattened[room_id] = true
				(by_id[room_id] as Dictionary)["flat_roof"] = true
		styled_proposals.clear()
		for room_id: StringName in ids:
			styled_proposals.append(by_id[room_id] as Dictionary)
		junction_modules = FabricRoofJunctionModuleTable.build(
			styled_proposals, topology)
		if junction_modules.is_empty():
			last_failure = "spatial roof neighborhood has no sealed junction treatment: %s" \
				% FabricRoofJunctionModuleTable.last_failure
			return {}
	var rules_by_id := junction_modules.rules_by_id as Dictionary
	# Equal-height neighbors form one roof campaign. A shared ridge or valley
	# cannot change tile family halfway through merely because the two rooms have
	# different stable IDs; stepped roofs may still vary independently.
	var assigned_theme: Dictionary = {}
	for start_id: StringName in ids:
		if assigned_theme.has(start_id) or flattened.has(start_id):
			continue
		var component: Array[StringName] = []
		var pending: Array[StringName] = [start_id]
		var seen: Dictionary = {start_id: true}
		while not pending.is_empty():
			var current: StringName = pending.pop_back()
			component.append(current)
			for seam: Dictionary in topology.fact(current).junctions as Array:
				var neighbor := StringName(seam.neighbor_id)
				if int(seam.height_delta) != 0 or flattened.has(neighbor) \
						or seen.has(neighbor):
					continue
				seen[neighbor] = true
				pending.append(neighbor)
		component.sort_custom(func(a: StringName, b: StringName) -> bool:
			return String(a) < String(b))
		var anchor_room := room_by_id[component[0]] as WarrenRoomStamp
		var theme := _architectural_district_theme(anchor_room.lattice_origin,
			source.world_seed)
		var roof_theme := &"orange" if theme == &"orange" else &"blue"
		for room_id: StringName in component:
			assigned_theme[room_id] = roof_theme
	for room_id: StringName in ids:
		var proposal := by_id[room_id] as Dictionary
		if not assigned_theme.has(room_id):
			var room := room_by_id[room_id] as WarrenRoomStamp
			var theme := _architectural_district_theme(room.lattice_origin,
				source.world_seed)
			assigned_theme[room_id] = &"orange" \
				if theme == &"orange" else &"blue"
		proposal["roof_theme"] = assigned_theme[room_id]
		var rules: Array[Dictionary] = []
		rules.assign(rules_by_id.get(room_id, []) as Array)
		proposal["roof_junction_rules"] = rules
		proposal["roof_signature"] = StringName(topology.fact(room_id).signature)
		by_id[room_id] = proposal
	return {
		"proposal_by_room": by_id,
		"junction_count": int(topology.audit.junction_count),
		"ridge_continuation_count": int(topology.audit \
			.ridge_continuation_count),
		"parallel_valley_count": int(topology.audit.parallel_valley_count),
		"perpendicular_valley_count": int(topology.audit \
			.perpendicular_valley_count),
		"flattened_room_count": flattened.size(),
	}


static func _spatial_roof_join_supported(kind: int) -> bool:
	return kind in [
		FabricRoofTopologyPlan.JunctionKind.RIDGE_CONTINUATION,
		FabricRoofTopologyPlan.JunctionKind.STEPPED_EAVE_WALL,
		FabricRoofTopologyPlan.JunctionKind.STEPPED_GABLE_WALL,
	]


static func _full_roof_candidates(room: WarrenRoomStamp,
		world_seed: int, neighborhood_proposal: Dictionary = {}) \
		-> Array[Dictionary]:
	## Construction gets a finite exact alternative set before falling back to a
	## flat cap. Decorative projections are removed first. Square floorplates may
	## also turn a reviewed roof profile by 90 degrees because their semantic
	## solid set is rotation-invariant; rectangular rooms may not rotate their
	## ridge sideways. No candidate moves or scales the authored asset.
	if not neighborhood_proposal.is_empty() \
			and bool(neighborhood_proposal.get("flat_roof", false)):
		return [] as Array[Dictionary]
	if not neighborhood_proposal.is_empty() \
			and not (neighborhood_proposal.get(
				"roof_junction_rules", []) as Array).is_empty():
		var roof_component: Dictionary = {}
		var trim_components: Array[Dictionary] = []
		for component: Dictionary in StaggeredFabricCompiler \
				.proposal_components(neighborhood_proposal):
			var role := StringName(component.role)
			if role == &"roof":
				roof_component = component
			elif String(role).begins_with("roof.trim."):
				var trim := component.duplicate(true)
				var neighbors: Array[StringName] = []
				for rule: Dictionary in neighborhood_proposal \
						.roof_junction_rules as Array:
					if bool(rule.get("emits_module", false)) \
							and int(rule.side) == int(component \
								.roof_junction_side):
						neighbors.append(StringName(rule.neighbor_id))
				trim["neighbor_room_ids"] = neighbors
				trim_components.append(trim)
		if not roof_component.is_empty():
			var joined_candidates: Array[Dictionary] = [{
				"recipe_id": StringName(roof_component.recipe_id),
				"yaw_offset": posmod(int(roof_component.yaw_quarters) \
					- room.yaw_quarters, 4),
				"uses_roof_neighborhood": true,
				"trim_components": trim_components,
			}] as Array[Dictionary]
			# Dormers and chimneys are optional projections, never the authority for
			# the ridge/valley campaign. If that detail clips a nearby higher room,
			# try the matching plain pitched shell with the same yaw and junction
			# modules before rejecting the entire atomic neighborhood.
			var detailed_id := StringName(roof_component.recipe_id)
			var plain_joined_id := _plain_pitched_recipe_id(detailed_id)
			if plain_joined_id != detailed_id:
				var plain_candidate := joined_candidates[0].duplicate(true)
				plain_candidate["recipe_id"] = plain_joined_id
				joined_candidates.append(plain_candidate)
			return joined_candidates
	var preferred := _full_roof_recipe_id(room, world_seed)
	var ids: Array[StringName] = [preferred]
	var plain := _plain_pitched_recipe_id(preferred)
	if not ids.has(plain):
		ids.append(plain)
	if room.kind == &"building":
		var modular := &"roof.square.orange.plain" \
			if _roof_recipe_family(preferred) == &"orange" \
			else &"roof.square.blue.plain"
		if not ids.has(modular):
			ids.append(modular)
	var out: Array[Dictionary] = []
	for recipe_id: StringName in ids:
		out.append({"recipe_id": recipe_id, "yaw_offset": 0})
	# Compact tower and 6 x 6 square solids are unchanged by a quarter turn. The
	# measured eave/ridge AABB is not, so this often closes a tight party-wall
	# corner that otherwise became a conspicuous flat box.
	if room.kind in [&"tower", &"building"]:
		for recipe_id: StringName in ids:
			out.append({"recipe_id": recipe_id, "yaw_offset": 1})
	return out


static func _plain_pitched_recipe_id(recipe_id: StringName) -> StringName:
	var id := String(recipe_id)
	if id.begins_with("roof.long.") and id.contains(".dormer."):
		return StringName(id.get_slice(".dormer.", 0))
	if id.begins_with("roof.slim.chimney."):
		return StringName(id.replace("roof.slim.chimney.", "roof.slim."))
	if id.begins_with("roof.row.chimney."):
		return StringName(id.replace("roof.row.chimney.", "roof.row."))
	if id.begins_with("roof.tower.chimney."):
		return StringName(id.replace("roof.tower.chimney.", "roof.tower."))
	if id.begins_with("roof.slim.short."):
		return StringName(id.replace("roof.slim.short.", "roof.slim."))
	if id.begins_with("roof.row.short."):
		return StringName(id.replace("roof.row.short.", "roof.row."))
	if id.begins_with("roof.tower.short."):
		return StringName(id.replace("roof.tower.short.", "roof.tower."))
	if id.begins_with("roof.slim.") and id.contains(".dormer."):
		return StringName(id.get_slice(".dormer.", 0))
	if id.begins_with("roof.row.") and id.contains(".dormer."):
		return StringName(id.get_slice(".dormer.", 0))
	if id.begins_with("roof.tower.") and id.contains(".dormer."):
		return StringName(id.get_slice(".dormer.", 0))
	if id.begins_with("roof.square.") and id.contains(".dormer."):
		var theme := "orange" if id.contains(".orange.") else "blue"
		return StringName("roof.square.%s.plain" % theme)
	return recipe_id


static func _room_recipe_facade_family(recipe_id: StringName) -> StringName:
	var id := String(recipe_id)
	for family: String in ["stone", "blue", "orange", "amber", "rock"]:
		if id.contains(".%s" % family):
			return StringName(family)
	return &"other"


static func _roof_recipe_family(recipe_id: StringName) -> StringName:
	var id := String(recipe_id)
	if id.contains(".orange") or id.ends_with(".01") \
			or id.ends_with(".04"):
		return &"orange"
	if id.contains(".blue"):
		return &"blue"
	return &"boarded"


static func _flat_roof_recipe_id(room: WarrenRoomStamp) -> StringName:
	return _flat_roof_recipe_id_for_kind(room.kind)


static func _flat_roof_recipe_id_for_kind(kind: StringName) -> StringName:
	if kind == &"tower":
		return &"roof.flat.tower"
	if kind == &"slim":
		return &"roof.flat.slim"
	if kind == &"row":
		return &"roof.flat.row"
	if kind == &"long":
		return &"roof.flat.long"
	return &"roof.flat.square"


static func _flat_roof_terrace_candidates(room: WarrenRoomStamp,
		world_seed: int) -> Array[StringName]:
	var base := String(_flat_roof_recipe_id(room))
	var sides: Array[StringName] = [&"north", &"east", &"south", &"west"]
	var phase := posmod(Helper._mix64(world_seed \
		^ String(room.stable_id).hash()), sides.size())
	var out: Array[StringName] = []
	for offset in sides.size():
		var side := sides[(phase + offset) % sides.size()]
		out.append(StringName("%s.terrace.%s.lived" % [base, side]))
		out.append(StringName("%s.terrace.%s" % [base, side]))
	return out


static func _roof_faces_by_room(source: WarrenSpatialPlan,
		room_id_by_cell: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for region: WarrenConstructionRegion in source.construction_plan \
			.regions_for_kind(WarrenSpatialGrid.FaceKind.ROOF):
		for cell: Vector3i in region.face_cells:
			var room_id := StringName(room_id_by_cell.get(cell, &""))
			if room_id.is_empty():
				continue
			if not out.has(room_id):
				out[room_id] = [] as Array[Vector3i]
			(out[room_id] as Array[Vector3i]).append(cell)
	return out


static func _is_full_roof_plate(room: WarrenRoomStamp,
		face_cells: Array[Vector3i]) -> bool:
	var top_count := 0
	for cell: Vector3i in room.private_cells:
		top_count += int(cell.y == room.lattice_origin.y + 1)
	return face_cells.size() == top_count


static func _touches_public_air(grid: WarrenSpatialGrid,
		face_cells: Array[Vector3i]) -> bool:
	for cell: Vector3i in face_cells:
		if grid.use_at(cell + Vector3i.UP) == WarrenSpatialGrid.Use.PUBLIC_AIR:
			return true
	return false


static func _unit_touches_public_air(grid: WarrenSpatialGrid,
		unit: FabricUnit, recipe: FabricRecipe) -> bool:
	## A pitched or staggered roof may occupy two or more lattice bands even when
	## the first band immediately over its source face is clear. Elevated streets
	## and galleries reserve their complete 3D headroom, so test the candidate's
	## actual semantic solid volume rather than approximating it from the face.
	for local_cell: Vector3i in recipe.solid_cells:
		var world_cell := FabricRecipe.transform_cell(local_cell,
			unit.lattice_origin, unit.yaw_quarters)
		if grid.use_at(world_cell) == WarrenSpatialGrid.Use.PUBLIC_AIR:
			return true
	return false


static func _cap_placement(grid: WarrenSpatialGrid,
		face_cells: Array[Vector3i], room: WarrenRoomStamp,
		world_seed: int) -> Dictionary:
	if face_cells.size() not in [1, 2, 4, 6]:
		return {}
	var targets: Dictionary = {}
	for cell: Vector3i in face_cells:
		targets[cell + Vector3i.UP] = true
	for yaw in 4:
		for anchor_face: Vector3i in face_cells:
			var target_anchor := anchor_face + Vector3i.UP
			var local_anchor := FabricRecipe.transform_cell(Vector3i.ZERO,
				Vector3i.ZERO, yaw)
			var origin := target_anchor - local_anchor
			var visible: Dictionary = {}
			for x in face_cells.size():
				visible[FabricRecipe.transform_cell(Vector3i(x, 0, 0),
					origin, yaw)] = true
			if not _same_cell_set(visible, targets):
				continue
			var recipe_id := StringName("roof.setback.cap.%d" \
				% face_cells.size())
			# Exposed shoulders remain roofs, not circulation. The former railing
			# treatment silently promoted every collision-free shelf to a balcony even
			# though no door, stair, or path reached it. A measured central garden can
			# enrich the cap without making a false accessibility claim; the separate
			# balcony/court solvers own all genuine exterior occupied floors.
			if String(recipe_id).begins_with("roof.setback.cap.") \
					and face_cells.size() >= 2 \
					and posmod(Helper._mix64(world_seed \
						^ String(room.stable_id).hash() ^ anchor_face.x * 53 \
						^ anchor_face.y * 97 ^ anchor_face.z * 193), 3) != 0:
				recipe_id = StringName("roof.setback.garden.%d" \
					% face_cells.size())
			return {"recipe_id": recipe_id, "origin": origin,
				"yaw_quarters": yaw, "anchor_face": anchor_face}
	return {}


static func _cap_pieces(face_cells: Array[Vector3i]) -> Array[Dictionary]:
	## Losslessly partition an arbitrary exposed plate into the largest complete
	## room-shaped roofs first, then finite native strips. This is the compiler's
	## macroscopic replacement pass: a 2x2 or 2x4 cluster becomes a recognisable
	## gabled house crown rather than four/eight visible voxel caps.
	var remaining: Dictionary = {}
	for cell: Vector3i in face_cells:
		remaining[cell] = true
	var out: Array[Dictionary] = []
	var y := face_cells[0].y if not face_cells.is_empty() else 0
	# Exactly one largest recognizable crown may own an irregular shoulder. A
	# second sibling gable over the same parent is not a larger house; it is the
	# modular roof pile seen in close review, with intersecting valleys hidden by
	# the parent's broad seam exception. The planner's admitted compound grammar
	# already requires the residual to be terminal rows, so consuming one stamp
	# here makes the construction pass match that proof.
	var found_macro := false
	for kind: StringName in [&"long", &"building", &"slim", &"row", &"tower"]:
		if found_macro:
			break
		var ordered: Array[Vector3i] = []
		ordered.assign(remaining.keys())
		ordered.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
			return a.z < b.z if a.z != b.z else a.x < b.x)
		for anchor: Vector3i in ordered:
			for yaw in 4:
				# Search a small origin halo around the first occupied cell;
				# exact set containment is the authority, not this anchor phase.
				for x in range(anchor.x - 3, anchor.x + 4):
					for z in range(anchor.z - 3, anchor.z + 4):
						var origin := Vector3i(x, y, z)
						var stamp := WarrenRoomStamp.expected_private_cells(
							kind, origin, yaw)
						var top: Array[Vector3i] = []
						var fits := true
						for cell: Vector3i in stamp:
							if cell.y != y:
								continue
							top.append(cell)
							if not remaining.has(cell):
								fits = false
								break
						if not fits or top.is_empty():
							continue
						out.append({"kind": &"stamp", "room_kind": kind,
							"origin": origin, "yaw_quarters": yaw,
							"cells": top})
						for cell: Vector3i in top:
							remaining.erase(cell)
						found_macro = true
						break
					if found_macro:
						break
				if found_macro:
					break
			if found_macro:
				break
	while not remaining.is_empty():
		var ordered: Array[Vector3i] = []
		ordered.assign(remaining.keys())
		ordered.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
			if a.y != b.y:
				return a.y < b.y
			if a.z != b.z:
				return a.z < b.z
			return a.x < b.x)
		var start: Vector3i = ordered[0]
		var chosen: Array[Vector3i] = []
		for length: int in [6, 4, 2, 1]:
			for direction: Vector3i in [Vector3i.RIGHT, Vector3i.BACK]:
				var candidate: Array[Vector3i] = []
				var fits := true
				for offset: int in length:
					var cell: Vector3i = start + direction * offset
					if not remaining.has(cell):
						fits = false
						break
					candidate.append(cell)
				if fits:
					chosen = candidate
					break
			if not chosen.is_empty():
				break
		if chosen.is_empty():
			return [] as Array[Dictionary]
		out.append({"kind": &"row", "cells": chosen})
		for cell: Vector3i in chosen:
			remaining.erase(cell)
	return out


static func _cap_rows(face_cells: Array[Vector3i]) -> Array[Array]:
	## Compatibility helper for focused tests and diagnostics that only need the
	## terminal strip partition. Production uses `_cap_pieces` above.
	var out: Array[Array] = []
	for piece: Dictionary in _cap_pieces(face_cells):
		out.append(piece.cells as Array[Vector3i])
	return out


static func _terminal_cap_rows(face_cells: Array[Vector3i]) \
		-> Array[Array]:
	## Strip-only form used for conservative pre-reservation and as the conceptual
	## final fallback for a macro roof. It never recursively extracts another
	## gable, so callers can reason about a finite native closure.
	var remaining: Dictionary = {}
	for cell: Vector3i in face_cells:
		remaining[cell] = true
	var out: Array[Array] = []
	while not remaining.is_empty():
		var ordered: Array[Vector3i] = []
		ordered.assign(remaining.keys())
		ordered.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
			if a.y != b.y:
				return a.y < b.y
			if a.z != b.z:
				return a.z < b.z
			return a.x < b.x)
		var start := ordered[0] as Vector3i
		var chosen: Array[Vector3i] = []
		for length: int in [6, 4, 2, 1]:
			for direction: Vector3i in [Vector3i.RIGHT, Vector3i.BACK]:
				var candidate: Array[Vector3i] = []
				var fits := true
				for offset: int in length:
					var cell := start + direction * offset
					if not remaining.has(cell):
						fits = false
						break
					candidate.append(cell)
				if fits:
					chosen = candidate
					break
			if not chosen.is_empty():
				break
		if chosen.is_empty():
			return [] as Array[Array]
		out.append(chosen)
		for cell: Vector3i in chosen:
			remaining.erase(cell)
	return out


static func _roof_seams_for_candidate(room_seams: Array[StringName],
		parent_unit_id: StringName,
		prior_roofs: Array[FabricUnit],
		fixed_feature_units: Array[FabricUnit] = []) -> Array[StringName]:
	## A roof may meet a previously compiled roof only where their underlying
	## rooms share an exact party wall. Multiple native caps over one room are
	## also explicit pieces of the same authoritative roof region.
	var related_rooms: Dictionary = {parent_unit_id: true}
	for room_seam: StringName in room_seams:
		related_rooms[room_seam] = true
	var out: Array[StringName] = []
	out.append_array(room_seams)
	for feature_unit: FabricUnit in fixed_feature_units:
		var connected := feature_unit.parent_ids.has(parent_unit_id) \
			or feature_unit.visual_seam_ids.has(parent_unit_id)
		if not connected:
			for bond: Dictionary in feature_unit.socket_bonds:
				if StringName(bond.target_unit) == parent_unit_id:
					connected = true
					break
		if connected:
			out.append(feature_unit.stable_id)
	for prior: FabricUnit in prior_roofs:
		for prior_parent: StringName in prior.parent_ids:
			if related_rooms.has(prior_parent):
				out.append(prior.stable_id)
				break
	return _unique_sorted_names(out)


static func _prior_roof_seams_for_neighbor_rooms(
		neighbor_room_unit_ids: Array[StringName],
		prior_roofs: Array[FabricUnit]) -> Array[StringName]:
	## A setback strip may close against a roof whose underlying room shares an
	## exact PARTY_WALL with this room.  Name only the roof unit: naming the room
	## itself would recreate the old broad exemption that let a gable eave pass
	## through the neighboring facade.
	var neighbors: Dictionary = {}
	for room_unit_id: StringName in neighbor_room_unit_ids:
		neighbors[room_unit_id] = true
	var out: Array[StringName] = []
	for prior: FabricUnit in prior_roofs:
		for parent_id: StringName in prior.parent_ids:
			if neighbors.has(parent_id):
				out.append(prior.stable_id)
				break
	return _unique_sorted_names(out)


static func _append_shallow_prior_roof_seams(candidate: FabricUnit,
		neighbor_room_unit_ids: Array[StringName],
		prior_roofs: Array[FabricUnit],
		program: SettlementFabricProgram) -> void:
	## Exact PARTY_WALL adjacency makes two roofs part of one construction, but it
	## does not excuse arbitrary interpenetration. Declare the roof-to-roof seam
	## only when the measured contact is shallow on two axes. A gable entering a
	## neighbor wall still has no relationship and remains a hard rejection.
	if candidate == null or program == null:
		return
	var candidate_recipe := program.recipe(candidate.recipe_id)
	if candidate_recipe == null:
		return
	var candidate_bounds := candidate.transform() \
		* candidate_recipe.local_clearance_bounds
	var candidate_roof_ids := _prior_roof_seams_for_neighbor_rooms(
		neighbor_room_unit_ids, prior_roofs)
	for prior: FabricUnit in prior_roofs:
		if not candidate_roof_ids.has(prior.stable_id):
			continue
		var prior_recipe := program.recipe(prior.recipe_id)
		if prior_recipe == null:
			continue
		var prior_bounds := prior.transform() \
			* prior_recipe.local_clearance_bounds
		if SettlementFabricPlan._aabb_overlaps_volume(candidate_bounds,
				prior_bounds) and SettlementFabricPlan._is_edge_nick(
				candidate_bounds, prior_bounds) \
				and not candidate.visual_seam_ids.has(prior.stable_id):
			candidate.visual_seam_ids.append(prior.stable_id)
	candidate.visual_seam_ids = _unique_sorted_names(
		candidate.visual_seam_ids)


static func _setback_wall_room_ids(face_cells: Array[Vector3i],
		unit_by_private_cell: Dictionary) -> Array[StringName]:
	## The cell immediately above each authoritative roof face is the cap volume.
	## Any private cell directly across its horizontal perimeter is an exact upper
	## wall contact. A complete long-side contact may select the pitched lean-to;
	## partial sides and short ends can only receive the shallow flashing rule.
	var out: Array[StringName] = []
	if face_cells.is_empty():
		return out
	var cap_cells: Dictionary = {}
	for face: Vector3i in face_cells:
		cap_cells[face + Vector3i.UP] = true
	for cap_cell_value: Variant in cap_cells.keys():
		var cap_cell := cap_cell_value as Vector3i
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.FORWARD, Vector3i.BACK]:
			var neighbor := cap_cell + direction
			if cap_cells.has(neighbor):
				continue
			var room_unit_id := StringName(unit_by_private_cell.get(neighbor, &""))
			if not room_unit_id.is_empty() and not out.has(room_unit_id):
				out.append(room_unit_id)
	return _unique_sorted_names(out)


static func _append_shallow_room_seams(candidate: FabricUnit,
		candidate_room_unit_ids: Array[StringName], unit_by_room: Dictionary,
		unit_by_private_cell: Dictionary,
		program: SettlementFabricProgram) -> void:
	## End-wall flashing is a measured shallow connection, not an envelope
	## exemption. The detailed terrace/garden remains rejected when its height
	## makes the overlap deep; the plain cap may tuck beneath the facade frame.
	if candidate == null or program == null:
		return
	var candidate_recipe := program.recipe(candidate.recipe_id)
	if candidate_recipe == null:
		return
	var candidate_bounds := candidate.transform() \
		* candidate_recipe.local_clearance_bounds
	var adjacent_room_ids: Array[StringName] = []
	adjacent_room_ids.assign(candidate_room_unit_ids)
	var candidate_solid_cells: Dictionary = {}
	var local_contact_cells: Array[Vector3i] = []
	local_contact_cells.assign(candidate_recipe.solid_cells)
	for occluder_cell: Vector3i in candidate_recipe.occluder_cells:
		if not local_contact_cells.has(occluder_cell):
			local_contact_cells.append(occluder_cell)
	for local_cell: Vector3i in local_contact_cells:
		candidate_solid_cells[FabricRecipe.transform_cell(local_cell,
			candidate.lattice_origin, candidate.yaw_quarters)] = true
	for cell_value: Variant in candidate_solid_cells.keys():
		var cell := cell_value as Vector3i
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.FORWARD, Vector3i.BACK]:
			var neighbor := cell + direction
			if candidate_solid_cells.has(neighbor):
				continue
			var room_unit_id := StringName(unit_by_private_cell.get(neighbor,
				&""))
			if not room_unit_id.is_empty() \
					and not adjacent_room_ids.has(room_unit_id):
				adjacent_room_ids.append(room_unit_id)
	# A one-cell structural setback can still be closed by an authored facade
	# projection reaching the thin cap. The lattice alone cannot name that seam,
	# so let the measured envelopes discover it below; the strict shallow-depth
	# test remains the authority and rejects a tall terrace or deep intersection.
	for room_unit_value: Variant in unit_by_room.values():
		var room_unit := room_unit_value as FabricUnit
		if room_unit != null \
				and not adjacent_room_ids.has(room_unit.stable_id):
			adjacent_room_ids.append(room_unit.stable_id)
	adjacent_room_ids = _unique_sorted_names(adjacent_room_ids)
	for room_unit_id: StringName in adjacent_room_ids:
		var room_unit := _room_unit_with_stable_id(unit_by_room, room_unit_id)
		if room_unit == null:
			continue
		var room_recipe := program.recipe(room_unit.recipe_id)
		if room_recipe == null:
			continue
		var room_bounds := room_unit.transform() \
			* room_recipe.local_clearance_bounds
		if _is_shallow_flashing_contact(candidate_bounds, room_bounds) \
				and not candidate.visual_seam_ids.has(room_unit_id):
			candidate.visual_seam_ids.append(room_unit_id)
	candidate.visual_seam_ids = _unique_sorted_names(
		candidate.visual_seam_ids)


static func _room_unit_with_stable_id(unit_by_room: Dictionary,
		stable_unit_id: StringName) -> FabricUnit:
	for unit_value: Variant in unit_by_room.values():
		var unit := unit_value as FabricUnit
		if unit != null and unit.stable_id == stable_unit_id:
			return unit
	return null


static func _is_shallow_flashing_contact(left: AABB, right: AABB) -> bool:
	if not SettlementFabricPlan._aabb_overlaps_volume(left, right):
		return false
	var overlap := SettlementFabricPlan._overlap_size(left, right)
	return overlap.y <= SHALLOW_FLASHING_MAX_HEIGHT_M \
		and minf(overlap.x, overlap.z) <= SHALLOW_FLASHING_MAX_OVERLAP_M


static func _cap_failure_diagnostic(grid: WarrenSpatialGrid,
		face_cells: Array[Vector3i]) -> String:
	var parts := PackedStringArray()
	for face: Vector3i in face_cells:
		var above := face + Vector3i.UP
		for z in range(-1, 2):
			for x in range(-1, 2):
				var cell := above + Vector3i(x, 0, z)
				parts.append("%d:%d:%d=%d/%s" % [cell.x, cell.y, cell.z,
					grid.use_at(cell), String(grid.owner_name_at(cell))])
	parts.sort()
	return ",".join(parts)


static func _roof_room_seams(grid: WarrenSpatialGrid,
		room: WarrenRoomStamp, unit_by_private_cell: Dictionary,
		own_unit_id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for cell: Vector3i in room.private_cells:
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD, Vector3i.BACK]:
			var neighbor := cell + direction
			if not unit_by_private_cell.has(neighbor):
				continue
			var claim := grid.face_claim(cell, direction)
			var neighbor_id := StringName(unit_by_private_cell[neighbor])
			if int(claim.get("kind", -1)) \
					== WarrenSpatialGrid.FaceKind.PARTY_WALL \
					and neighbor_id != own_unit_id and not out.has(neighbor_id):
				out.append(neighbor_id)
	return _unique_sorted_names(out)


static func _same_cell_set(left: Dictionary, right: Dictionary) -> bool:
	if left.size() != right.size():
		return false
	for value: Variant in left.keys():
		if not right.has(value):
			return false
	return true


static func _unique_sorted_names(values: Array[StringName]) \
		-> Array[StringName]:
	var unique: Dictionary = {}
	for value: StringName in values:
		if not value.is_empty():
			unique[value] = true
	var out: Array[StringName] = []
	out.assign(unique.keys())
	out.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	return out


static func _recipe_stays_inside_stamp(recipe: FabricRecipe,
		room: WarrenRoomStamp) -> bool:
	var allowed: Dictionary = {}
	for cell: Vector3i in room.private_cells:
		allowed[cell] = true
	var claimed: Dictionary = {}
	for source_cells: Array[Vector3i] in [recipe.solid_cells,
			recipe.headroom_cells, recipe.inhabited_cells]:
		for local_cell: Vector3i in source_cells:
			var cell := FabricRecipe.transform_cell(local_cell,
				room.lattice_origin, room.yaw_quarters)
			if not allowed.has(cell):
				return false
			claimed[cell] = true
	return not claimed.is_empty()


static func _entrance_matches(recipe: FabricRecipe,
		room: WarrenRoomStamp) -> bool:
	if room.addressed and recipe.entrances.size() != 1:
		return false
	if not room.addressed:
		return recipe.entrances.is_empty()
	var entrance := recipe.entrances[0] as Dictionary
	return FabricRecipe.transform_cell(entrance.cell as Vector3i,
		room.lattice_origin, room.yaw_quarters) == room.threshold_cell \
		and FabricRecipe.transform_direction(entrance.facing as Vector3i,
			room.yaw_quarters) == room.frontage_direction


static func _bearing_bond(upper: WarrenRoomStamp,
		lower: WarrenRoomStamp, lower_unit_id: StringName) -> Dictionary:
	var lower_columns: Dictionary = {}
	for cell: Vector3i in lower.private_cells:
		lower_columns[Vector2i(cell.x, cell.z)] = true
	var shared: Array[Vector2i] = []
	for cell: Vector3i in upper.private_cells:
		var column := Vector2i(cell.x, cell.z)
		if lower_columns.has(column) and not shared.has(column):
			shared.append(column)
	shared.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or a.y == b.y and a.x < b.x)
	if shared.is_empty():
		return {}
	var column := shared[0]
	var upper_world := Vector3i(column.x, upper.lattice_origin.y, column.y)
	var lower_world := Vector3i(column.x, lower.lattice_origin.y + 1, column.y)
	var upper_local := _inverse_cell(upper_world, upper.lattice_origin,
		upper.yaw_quarters)
	var lower_local := _inverse_cell(lower_world, lower.lattice_origin,
		lower.yaw_quarters)
	return FabricUnit.bond(SettlementFabricProgram._bearing_cell_socket_id(
		&"bottom", upper_local.x, upper_local.z), lower_unit_id,
		SettlementFabricProgram._bearing_cell_socket_id(&"top", lower_local.x,
		lower_local.z))


static func _physical_support_parent(upper: WarrenRoomStamp,
		room_by_private_cell: Dictionary,
		preferred: WarrenRoomStamp) -> WarrenRoomStamp:
	## Cross-lineage recomposition is keyed by absolute 1.5 m bands. A source
	## lineage handoff remains useful ancestry, but after per-storey splitting its
	## relative storey number need not name the room directly below every overlap
	## column. Construction binds the authoritative spatial fact: the room whose
	## top cell is immediately below the upper room's bottom plate.
	var counts: Dictionary = {}
	var room_by_id: Dictionary = {}
	for cell: Vector3i in upper.private_cells:
		if cell.y != upper.lattice_origin.y:
			continue
		var candidate := room_by_private_cell.get(cell + Vector3i.DOWN) \
			as WarrenRoomStamp
		if candidate == null or candidate.stable_id == upper.stable_id:
			continue
		counts[candidate.stable_id] = int(counts.get(candidate.stable_id, 0)) + 1
		room_by_id[candidate.stable_id] = candidate
	if counts.is_empty():
		return preferred
	var ids: Array[StringName] = []
	ids.assign(counts.keys())
	ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		if int(counts[a]) != int(counts[b]):
			return int(counts[a]) > int(counts[b])
		if preferred != null and (a == preferred.stable_id) \
				!= (b == preferred.stable_id):
			return a == preferred.stable_id
		return String(a) < String(b))
	return room_by_id[ids[0]] as WarrenRoomStamp


static func _room_feature_envelope_conflict(source: WarrenSpatialPlan,
		program: SettlementFabricProgram, room: WarrenRoomStamp,
		recipe: FabricRecipe) -> StringName:
	var room_bounds := FabricRecipe.lattice_transform(room.lattice_origin,
		room.yaw_quarters) * recipe.local_clearance_bounds
	for feature: WarrenFeatureReservation in source.features:
		# An interstitial strip occupies proven-vacant trapped cells and can
		# never displace a room; an eave or bay grazing the strip from above
		# is a typed reveal, declared as a seam on the strip's own unit. Every
		# other feature keeps the hard displacement gate.
		if feature.kind == &"interstitial_join":
			continue
		if feature.construction_records.is_empty() \
				or _feature_is_related_to_room(source, feature, room):
			continue
		for record: Dictionary in feature.construction_records:
			var feature_recipe := program.recipe(StringName(record.recipe_id))
			if feature_recipe == null:
				return feature.stable_id
			var feature_bounds := FabricRecipe.lattice_transform(
				record.origin as Vector3i, int(record.yaw_quarters)) \
				* feature_recipe.local_clearance_bounds
			if SettlementFabricPlan._aabb_overlaps_volume(room_bounds,
					feature_bounds):
				return feature.stable_id
	return &""


static func _feature_is_related_to_room(source: WarrenSpatialPlan,
		feature: WarrenFeatureReservation, room: WarrenRoomStamp) -> bool:
	var room_id := room.stable_id
	for key: String in ["annex_room_id", "balcony_room_id",
			"market_backing_room_id", "courtyard_bridge_house_room_id",
			"outcrop_upper_room_id", "outcrop_lower_room_id", "gateway_room_id"]:
		if StringName(feature.audit.get(key, &"")) == room_id:
			return true
	for neighbor_value: Variant in feature.audit.get(
			"outcrop_support_neighbor_room_ids", []):
		if StringName(neighbor_value) == room_id:
			return true
	for neighbor_value: Variant in feature.audit.get(
			"gateway_support_neighbor_room_ids", []):
		if StringName(neighbor_value) == room_id:
			return true
	# An interstitial join is by definition wedged against its named wall,
	# bearing, and continuing-upper owners; the strip's authored ridge/board
	# seam may cross their conservative AABBs while the occupied cells remain
	# disjoint. Every other room still treats the sealed strip as a hard limit.
	if feature.kind == &"interstitial_join":
		var owner_ids: Array = (feature.audit.get(
			"interstitial_wall_owner_ids", []) as Array).duplicate()
		owner_ids.append_array(feature.audit.get(
			"interstitial_cover_owner_ids", []) as Array)
		owner_ids.append(feature.audit.get(
			"interstitial_bearing_owner_id", &""))
		owner_ids.append(feature.audit.get(
			"interstitial_upper_owner_id", &""))
		var room_lineage_prefix := "spatial.%s.part" % room.source_parcel_id
		for owner_value: Variant in owner_ids:
			var owner_id := String(StringName(owner_value))
			if owner_id.is_empty():
				continue
			if String(room_id).begins_with(owner_id + ".room"):
				return true
			# The strip is wedged into this parcel's recomposed lineage; every
			# storey of that lineage shares the sealed reveal relationship,
			# exactly like the balcony/annex lineage exceptions above.
			if owner_id.begins_with(room_lineage_prefix):
				return true
		# Physical contact is itself the sealed relationship: any room whose
		# occupied cells touch the strip (including a storey stepping
		# diagonally over or under it) legitimately shares the reveal, while
		# genuinely detached rooms keep the hard envelope limit.
		var strip_set: Dictionary = {}
		for strip_cell: Vector3i in feature.reserved_cells:
			strip_set[strip_cell] = true
		var contact_directions: Array[Vector3i] = [Vector3i.LEFT,
			Vector3i.RIGHT, Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD,
			Vector3i.BACK]
		for side: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.FORWARD, Vector3i.BACK]:
			contact_directions.append(Vector3i.UP + side)
			contact_directions.append(Vector3i.DOWN + side)
		for room_cell: Vector3i in room.private_cells:
			for direction: Vector3i in contact_directions:
				if strip_set.has(room_cell + direction):
					return true
	# A balcony, annex, or market is selected against every measured room in its
	# recomposed source lineage. Its brackets/eaves may legitimately cross the
	# conservative AABB of the storey directly below even though the occupied
	# cells remain disjoint. Preserve that authored construction seam here.
	for key: String in ["annex_source_parcel_id",
			"balcony_source_parcel_id", "market_backing_parcel_id",
			"courtyard_bridge_house_source_parcel_id"]:
		if StringName(feature.audit.get(key, &"")) == room.source_parcel_id:
			return true
	for binding_value: Variant in feature.audit.get(
			"skywalk_endpoint_bindings", []):
		var endpoint_room_id := StringName((binding_value as Dictionary).get(
			"room_id", &""))
		if endpoint_room_id == room_id:
			return true
		for building: WarrenBuildingVolume in source.buildings:
			for endpoint_room: WarrenRoomStamp in building.room_records:
				if endpoint_room.stable_id == endpoint_room_id \
						and endpoint_room.source_parcel_id \
						== room.source_parcel_id:
					return true
	return false


static func _suppressed_party_wall_placements(grid: WarrenSpatialGrid,
		room: WarrenRoomStamp, recipe: FabricRecipe) -> Array[StringName]:
	## Translate the sealed fine-grid PARTY_WALL field into whole authored facade
	## modules. A 3 m module is omitted only when both of its horizontal cells,
	## across both 1.5 m height bands, meet private volume through the same typed
	## seam. This keeps partial contacts visible and closes the old loophole where
	## two composable rooms still rendered coincident timber/stone skins.
	var minimum := Vector2i.ZERO
	var maximum := Vector2i.ZERO
	match room.kind:
		&"tower":
			minimum = Vector2i(-1, -1)
			maximum = Vector2i(0, 0)
		&"slim":
			minimum = Vector2i(-1, -2)
			maximum = Vector2i(0, 1)
		&"row":
			minimum = Vector2i(-2, -1)
			maximum = Vector2i(1, 0)
		&"building":
			minimum = Vector2i(-2, -2)
			maximum = Vector2i(1, 1)
		&"long":
			minimum = Vector2i(-2, -3)
			maximum = Vector2i(1, 2)
		_:
			return [] as Array[StringName]
	var available: Dictionary = {}
	for placement: Dictionary in recipe.placements:
		available[StringName(placement.id)] = true
	var suppressed: Dictionary = {}
	var front_ids: Array[StringName] = []
	var x_segments := int((maximum.x - minimum.x + 1) / 2)
	for index in x_segments:
		var x0 := minimum.x + index * 2
		var front_id := StringName("south") if room.kind in [&"tower", &"slim"] \
			else StringName("front.%d" % index)
		var back_id := StringName("north") if room.kind in [&"tower", &"slim"] \
			else StringName("back.%d" % index)
		front_ids.append(front_id)
		_suppress_complete_party_wall_segment(grid, room, available,
			suppressed, front_id, Vector3i.BACK, [
				Vector3i(x0, 0, maximum.y),
				Vector3i(x0 + 1, 0, maximum.y),
			])
		_suppress_complete_party_wall_segment(grid, room, available,
			suppressed, back_id, Vector3i.FORWARD, [
				Vector3i(x0, 0, minimum.y),
				Vector3i(x0 + 1, 0, minimum.y),
			])
	var z_segments := int((maximum.y - minimum.y + 1) / 2)
	for index in z_segments:
		var z0 := minimum.y + index * 2
		var west_id := StringName("west") if room.kind == &"tower" \
			else StringName("left.%d" % index) if room.kind == &"building" \
			else StringName("west.%d" % index)
		var east_id := StringName("east") if room.kind == &"tower" \
			else StringName("right.%d" % index) if room.kind == &"building" \
			else StringName("east.%d" % index)
		_suppress_complete_party_wall_segment(grid, room, available,
			suppressed, west_id, Vector3i.LEFT, [
				Vector3i(minimum.x, 0, z0),
				Vector3i(minimum.x, 0, z0 + 1),
			])
		_suppress_complete_party_wall_segment(grid, room, available,
			suppressed, east_id, Vector3i.RIGHT, [
				Vector3i(maximum.x, 0, z0),
				Vector3i(maximum.x, 0, z0 + 1),
			])
	var complete_front_is_hidden := not front_ids.is_empty()
	for placement_id: StringName in front_ids:
		complete_front_is_hidden = complete_front_is_hidden \
			and suppressed.has(placement_id)
	if complete_front_is_hidden:
		for placement: Dictionary in recipe.placements:
			var placement_id := StringName(placement.id)
			if String(placement_id).begins_with("facade."):
				suppressed[placement_id] = true
	var out: Array[StringName] = []
	out.assign(suppressed.keys())
	out.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	return out


static func _suppress_complete_party_wall_segment(grid: WarrenSpatialGrid,
		room: WarrenRoomStamp, available: Dictionary, suppressed: Dictionary,
		placement_id: StringName, local_direction: Vector3i,
		local_columns: Array[Vector3i]) -> void:
	if not available.has(placement_id):
		return
	var direction := FabricRecipe.transform_direction(local_direction,
		room.yaw_quarters)
	for local_column: Vector3i in local_columns:
		for y in WarrenSpatialGrid.STOREY_CELLS:
			var local_cell := Vector3i(local_column.x, y, local_column.z)
			var cell := FabricRecipe.transform_cell(local_cell,
				room.lattice_origin, room.yaw_quarters)
			var neighbor := cell + direction
			var claim := grid.face_claim(cell, direction)
			if room.has_private_cell(neighbor) \
					or grid.use_at(neighbor) \
						!= WarrenSpatialGrid.Use.PRIVATE_VOLUME \
					or int(claim.get("kind", -1)) \
						!= WarrenSpatialGrid.FaceKind.PARTY_WALL:
				return
	suppressed[placement_id] = true


static func _prior_visual_seam_units(grid: WarrenSpatialGrid,
		room: WarrenRoomStamp, prior_unit_by_cell: Dictionary,
		building_by_room: Dictionary, probe: SettlementFabricPlan,
		current_recipe: FabricRecipe) -> Array[StringName]:
	## Face-adjacent rooms use the shell's explicit PARTY_WALL fact. A second,
	## genuinely 3D seam exists where two occupied stamps meet along one lattice
	## edge: their cells differ by one on exactly two axes. Admit that seam only
	## when the measured construction overlap is shallow on those same axes;
	## nearby but unrelated shells remain an error.
	var unique: Dictionary = {}
	var own_building := StringName(building_by_room.get(room.stable_id, &""))
	for cell: Vector3i in room.private_cells:
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD, Vector3i.BACK]:
			var neighbor := cell + direction
			if not prior_unit_by_cell.has(neighbor):
				continue
			var claim := grid.face_claim(cell, direction)
			if int(claim.get("kind", -1)) \
					== WarrenSpatialGrid.FaceKind.PARTY_WALL \
					and grid.owner_name_at(neighbor) != own_building:
				unique[StringName(prior_unit_by_cell[neighbor])] = true
	var current_bounds := FabricRecipe.lattice_transform(room.lattice_origin,
		room.yaw_quarters) * current_recipe.local_clearance_bounds
	var edge_offsets: Array[Vector3i] = []
	for first_axis in 3:
		for second_axis in range(first_axis + 1, 3):
			for first_sign in [-1, 1]:
				for second_sign in [-1, 1]:
					var offset := Vector3i.ZERO
					offset[first_axis] = first_sign
					offset[second_axis] = second_sign
					edge_offsets.append(offset)
	for cell: Vector3i in room.private_cells:
		for offset: Vector3i in edge_offsets:
			var prior_id := StringName(prior_unit_by_cell.get(cell + offset, &""))
			if prior_id.is_empty() or unique.has(prior_id):
				continue
			var prior_unit := probe.unit(prior_id)
			var prior_recipe := probe.recipe(prior_unit.recipe_id) \
				if prior_unit != null else null
			if prior_recipe == null or prior_recipe.placements.is_empty():
				continue
			var prior_bounds := prior_unit.transform() \
				* prior_recipe.local_clearance_bounds
			if SettlementFabricPlan._aabb_overlaps_volume(current_bounds,
					prior_bounds) and SettlementFabricPlan._is_edge_nick(
						current_bounds, prior_bounds):
				unique[prior_id] = true
	var out: Array[StringName] = []
	out.assign(unique.keys())
	out.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	return out


static func _inverse_cell(world: Vector3i, origin: Vector3i,
		yaw_quarters: int) -> Vector3i:
	return FabricRecipe.transform_cell(world - origin, Vector3i.ZERO,
		-yaw_quarters)


static func _source_level_key(parcel_id: StringName, level: int) -> String:
	return "%s/%d" % [String(parcel_id), level]
