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
	var rooms := compile_room_units(source, program)
	if rooms.is_empty():
		return null
	var room_audit := last_audit.duplicate(true)
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
		var unit := FabricUnit.new(StringName("spatial.fabric.%s" % room.stable_id),
			recipe_id, room.lattice_origin, room.yaw_quarters, parents, bonds,
			&"", seams)
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
			unit = FabricUnit.new(unit.stable_id, fallback_id,
				room.lattice_origin, room.yaw_quarters, parents, bonds, &"", seams)
			var fallback_conflict := _room_feature_envelope_conflict(source,
				program, room, fallback_recipe)
			var fallback_roof_conflict := _room_required_roof_conflict(room,
				fallback_recipe, required_roof_clearance)
			if not unit.is_valid() or not fallback_conflict.is_empty() \
					or not fallback_roof_conflict.is_empty() \
					or not room_probe.add_unit(unit):
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
		"feature_portal_room_count": feature_portal_masks.size(),
		"feature_portal_opening_count": feature_portal_opening_count,
		"facade_family_counts": facade_family_counts,
	}
	return units


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
		for row_value: Variant in _cap_rows(face_cells):
			var row := row_value as Array[Vector3i]
			var cap := _cap_placement(source.grid, row, room,
				source.world_seed)
			if cap.is_empty():
				continue
			var plain_cap_id := StringName("roof.setback.cap.%d" % row.size())
			var cap_recipe := program.recipe(plain_cap_id)
			if cap_recipe == null:
				continue
			var cap_transform := FabricRecipe.lattice_transform(
				cap.origin as Vector3i, int(cap.yaw_quarters))
			out.append({"owner_room_id": room.stable_id,
				"recipe_id": plain_cap_id,
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
			if unit_recipe != null and unit_recipe.has_tag(&"cantilever_support"):
				var unit_clearance := unit.transform() \
					* unit_recipe.local_clearance_bounds
				# Support courses are selected as one compatible structural frame.
				# Make every measured intersection explicit before the plan gate sees
				# it; this is a typed timber joint, not a general overlap exemption.
				for prior: FabricUnit in compiled_support_units:
					var prior_recipe := program.recipe(prior.recipe_id)
					if prior_recipe == null:
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
			+ frontier_gateway_support_count,
		"skywalk_feature_count": skywalk_count,
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
		fixed_feature_units: Array[FabricUnit] = []) -> Array[FabricUnit]:
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
	var flat_garden_rejections: Array[Dictionary] = []
	var flat_roof_recipe_counts: Dictionary = {}
	var lived_in_flat_terrace_count := 0
	var awning_flat_terrace_count := 0
	var furnished_flat_terrace_count := 0
	var lamped_flat_terrace_count := 0
	var cap_count := 0
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
		if full and not _touches_public_air(source.grid, face_cells):
			var neighborhood_proposal := roof_proposal_by_room.get(room_id,
				{}) as Dictionary
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
		if full and not _touches_public_air(source.grid, face_cells):
			for flat_terrace_id: StringName in _flat_roof_terrace_candidates(
					room, source.world_seed):
				var terrace := _full_roof_unit(room_id, room, parent_unit,
					flat_terrace_id, _roof_seams_for_candidate(room_seams,
						parent_unit.stable_id, out, fixed_feature_units))
				var terrace_recipe := program.recipe(flat_terrace_id)
				if terrace_recipe == null:
					last_failure = "missing flat-roof terrace recipe %s" \
						% flat_terrace_id
					return [] as Array[FabricUnit]
				if _unit_touches_public_air(source.grid, terrace,
						terrace_recipe):
					attempt_failures.append(
						"flat terrace %s: exact roof volume enters public air" \
						% flat_terrace_id)
					continue
				if probe.add_unit(terrace):
					out.append(terrace)
					realized_face_count += face_cells.size()
					flat_count += 1
					flat_terrace_count += 1
					lived_in_flat_terrace_count += int(String(flat_terrace_id) \
						.ends_with(".lived"))
					awning_flat_terrace_count += int(terrace_recipe.has_tag(
						&"roof_terrace_awning"))
					furnished_flat_terrace_count += int(terrace_recipe.has_tag(
						&"furnished_roof_terrace"))
					lamped_flat_terrace_count += int(terrace_recipe.has_tag(
						&"terrace_lamp"))
					selected = true
					break
				attempt_failures.append("flat terrace %s: %s" % [
					flat_terrace_id, probe.last_rejection])
		if selected:
			continue
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
					var garden_id := StringName("%s.garden" % flat_id)
					var garden_recipe := program.recipe(garden_id)
					if garden_recipe == null:
						last_failure = "missing flat-roof garden accent %s" \
							% garden_id
						return [] as Array[FabricUnit]
					var garden := _flat_roof_garden_unit(room_id, flat,
						garden_id)
					if not probe.add_unit(garden):
						var garden_rejection := probe.last_rejection
						flat_garden_rejections.append({"room_id": room_id,
							"recipe_id": garden_id,
							"rejection": garden_rejection})
						last_failure = "flat roof %s has no collision-free central accent: %s" \
							% [room_id, garden_rejection]
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
		var rows := _cap_rows(face_cells)
		if rows.is_empty():
			last_failure = "no finite setback cap partition fits roof region for %s (%s; %s)" \
				% [room_id, "; ".join(attempt_failures),
					_cap_failure_diagnostic(source.grid, face_cells)]
			return [] as Array[FabricUnit]
		for row_index in rows.size():
			var row := rows[row_index] as Array[Vector3i]
			var cap := _cap_placement(source.grid, row, room,
				source.world_seed)
			if cap.is_empty():
				last_failure = "no native setback cap fits row %d for %s" % [
					row_index, room_id]
				return [] as Array[FabricUnit]
			var seams := _roof_seams_for_candidate(room_seams,
				parent_unit.stable_id, out, fixed_feature_units)
			var cap_unit := _cap_unit(room_id, row_index, room, parent_unit,
				cap, seams)
			var cap_recipe := program.recipe(StringName(cap.recipe_id))
			var cap_enters_public_air := cap_recipe != null \
				and _unit_touches_public_air(source.grid, cap_unit, cap_recipe)
			if cap_enters_public_air or not probe.add_unit(cap_unit):
				var terrace_rejection := probe.last_rejection
				if cap_enters_public_air:
					terrace_rejection = "exact setback roof volume enters public air"
				if String(cap.recipe_id).contains(".terrace.") \
						or String(cap.recipe_id).contains(".garden."):
					var rejected_garden := String(cap.recipe_id).contains(
						".garden.")
					cap["recipe_id"] = StringName("roof.setback.cap.%d" \
						% row.size())
					cap_unit = _cap_unit(room_id, row_index, room,
						parent_unit, cap, seams)
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
			last_failure = "classified roof trim %s was rejected: %s" % [
				trim.stable_id, probe.last_rejection]
			return [] as Array[FabricUnit]
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
		"flat_roof_garden_rejections": flat_garden_rejections,
		"flat_roof_recipe_counts": flat_roof_recipe_counts,
		"lived_in_flat_roof_terrace_count": lived_in_flat_terrace_count,
		"awning_flat_roof_terrace_count": awning_flat_terrace_count,
		"furnished_flat_roof_terrace_count": furnished_flat_terrace_count,
		"lamped_flat_roof_terrace_count": lamped_flat_terrace_count,
		"bare_flat_roof_count": flat_count - flat_terrace_count \
			- flat_garden_count,
		"setback_cap_unit_count": cap_count,
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
	}
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
		seams: Array[StringName]) -> FabricUnit:
	var anchor_face := cap.anchor_face as Vector3i
	var parent_local := _inverse_cell(anchor_face, room.lattice_origin,
		room.yaw_quarters)
	return FabricUnit.new(StringName("spatial.roof.%s.cap%02d" % [room_id,
		row_index]), StringName(cap.recipe_id), cap.origin as Vector3i,
		int(cap.yaw_quarters), [parent_unit.stable_id] as Array[StringName],
		[FabricUnit.bond(&"bearing.bottom", parent_unit.stable_id,
			SettlementFabricProgram._bearing_cell_socket_id(&"top",
				parent_local.x, parent_local.z))] as Array[Dictionary], &"", seams)


static func _room_recipe_id(room: WarrenRoomStamp, world_seed: int,
		allow_phase_b: bool = true, feature_portal_mask: int = 0) \
		-> StringName:
	var prefix := "room.long" if room.kind == &"long" \
		else "room.slim" if room.kind == &"slim" \
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
			return [{
				"recipe_id": StringName(roof_component.recipe_id),
				"yaw_offset": posmod(int(roof_component.yaw_quarters) \
					- room.yaw_quarters, 4),
				"uses_roof_neighborhood": true,
				"trim_components": trim_components,
			}] as Array[Dictionary]
	var preferred := _full_roof_recipe_id(room, world_seed)
	var ids: Array[StringName] = [preferred]
	var preferred_text := String(preferred)
	var plain := preferred
	if preferred_text.begins_with("roof.long.") \
			and preferred_text.contains(".dormer."):
		plain = StringName(preferred_text.get_slice(".dormer.", 0))
	elif preferred_text.begins_with("roof.slim.chimney."):
		plain = StringName(preferred_text.replace("roof.slim.chimney.",
			"roof.slim."))
	elif preferred_text.begins_with("roof.tower.chimney."):
		plain = StringName(preferred_text.replace("roof.tower.chimney.",
			"roof.tower."))
	elif preferred_text.begins_with("roof.slim.short."):
		plain = StringName(preferred_text.replace("roof.slim.short.",
			"roof.slim."))
	elif preferred_text.begins_with("roof.tower.short."):
		plain = StringName(preferred_text.replace("roof.tower.short.",
			"roof.tower."))
	elif preferred_text.begins_with("roof.square.") \
			and preferred_text.contains(".dormer."):
		var theme := "orange" if preferred_text.contains(".orange.") else "blue"
		plain = StringName("roof.square.%s.plain" % theme)
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
	if room.kind == &"tower":
		return &"roof.flat.tower"
	if room.kind == &"slim":
		return &"roof.flat.slim"
	if room.kind == &"long":
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
			# Exact setbacks should usually read as occupied roof terraces and
			# balcony-like ledges, not a stack of bare plank shelves. Keep a small
			# deterministic plain-cap minority so the skyline does not acquire a
			# railing at every level.
			if posmod(Helper._mix64(world_seed \
					^ String(room.stable_id).hash() \
					^ anchor_face.x * 73856093 ^ anchor_face.y * 83492791 \
					^ anchor_face.z * 19349663), 5) != 0:
				var exposed_sides: Array[int] = []
				for rail_side: int in [-1, 1]:
					var local_side := Vector3i(0, 0, rail_side)
					var world_side := FabricRecipe.transform_direction(local_side,
						yaw)
					var exposed := true
					for face: Vector3i in face_cells:
						if grid.use_at(face + world_side) in [
								WarrenSpatialGrid.Use.PRIVATE_VOLUME,
								WarrenSpatialGrid.Use.STRUCTURAL_VOLUME]:
							exposed = false
							break
					if exposed:
						exposed_sides.append(rail_side)
				if not exposed_sides.is_empty():
					var selected_side := exposed_sides[posmod(Helper._mix64(
						world_seed ^ anchor_face.x * 31 ^ anchor_face.z * 47),
						exposed_sides.size())]
					recipe_id = StringName("roof.setback.terrace.%d.%s" % [
						face_cells.size(), "left" if selected_side < 0 \
						else "right"])
			# Enclosed two-cell-or-longer shoulders cannot receive honest edge
			# rails, but a measured roof garden makes them read as deliberately
			# inhabited terraces instead of raw solver slabs. Keep a deterministic
			# plain minority, and let the exact visual-envelope transaction reject
			# any garden whose planter would meet a neighboring projection.
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


static func _cap_rows(face_cells: Array[Vector3i]) \
		-> Array[Array]:
	## Losslessly partition an arbitrary exposed roof plate into fixed native
	## 1.5 m strips. Long rows are preferred, but the one-cell recipe makes the
	## operation total: no protected air or upper room can force a hidden slab.
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
