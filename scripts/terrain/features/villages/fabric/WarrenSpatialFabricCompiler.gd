class_name WarrenSpatialFabricCompiler
extends RefCounted

## Measured-construction adapter for the authoritative 3D town.  This initial
## phase realizes every exact WarrenRoomStamp and its true bearing/party-wall
## relationships. Roof and composed-feature units are appended by later phases;
## no method here may move, resize, or restamp the spatial topology.
static var last_failure := ""
static var last_audit: Dictionary = {}


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
	var roofs := compile_roof_units(source, program, rooms)
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
	lineage.merge(roof_audit, true)
	lineage.merge(volumes.audit(), true)
	lineage.merge(solid_void.audit(), true)
	lineage["spatial_signature"] = source.deterministic_signature().sha256_text()
	lineage["construction_signature"] = result.construction_signature()
	lineage["generation_source"] = &"spatial_volumetric_warren"
	var audit := SettlementFabricSolver.audit_plan(result, lineage)
	if not result.seal(audit):
		last_failure = "spatial common-fabric seal failed: %s" % \
			result.last_rejection
		return null
	last_audit = audit
	return result


static func compile_room_units(source: WarrenSpatialPlan,
		program: SettlementFabricProgram) -> Array[FabricUnit]:
	last_failure = ""
	if source == null or not source.is_sealed() or program == null:
		last_failure = "missing sealed spatial plan or measured vocabulary"
		return [] as Array[FabricUnit]
	var rooms: Array[WarrenRoomStamp] = []
	var building_by_room: Dictionary = {}
	for building: WarrenBuildingVolume in source.buildings:
		for room: WarrenRoomStamp in building.room_records:
			rooms.append(room)
			building_by_room[room.stable_id] = building.stable_id
	rooms.sort_custom(func(a: WarrenRoomStamp, b: WarrenRoomStamp) -> bool:
		if a.source_storey_index != b.source_storey_index:
			return a.source_storey_index < b.source_storey_index
		if a.lattice_origin.y != b.lattice_origin.y:
			return a.lattice_origin.y < b.lattice_origin.y
		return String(a.stable_id) < String(b.stable_id))
	var room_by_source_level: Dictionary = {}
	for room: WarrenRoomStamp in rooms:
		var key := _source_level_key(room.source_parcel_id,
			room.source_storey_index)
		if room_by_source_level.has(key):
			last_failure = "two rooms own source level %s" % key
			return [] as Array[FabricUnit]
		room_by_source_level[key] = room
	var units: Array[FabricUnit] = []
	var unit_by_room: Dictionary = {}
	var prior_unit_by_cell: Dictionary = {}
	for room: WarrenRoomStamp in rooms:
		var recipe_id := _room_recipe_id(room, source.world_seed)
		var recipe := program.recipe(recipe_id)
		if recipe == null or not _recipe_stays_inside_stamp(recipe, room):
			last_failure = "measured recipe %s changes room stamp %s" % [
				recipe_id, room.stable_id]
			return [] as Array[FabricUnit]
		if not _entrance_matches(recipe, room):
			last_failure = "measured doorway changes threshold for %s" % \
				room.stable_id
			return [] as Array[FabricUnit]
		var parents: Array[StringName] = []
		var bonds: Array[Dictionary] = []
		if not room.terrain_bearing:
			var parent_key := _source_level_key(room.source_parcel_id,
				room.source_storey_index - 1)
			var parent_room := room_by_source_level.get(parent_key) \
				as WarrenRoomStamp
			if parent_room == null or not unit_by_room.has(parent_room.stable_id):
				last_failure = "room %s has no built lower source level" % \
					room.stable_id
				return [] as Array[FabricUnit]
			var parent_unit := unit_by_room[parent_room.stable_id] as FabricUnit
			var bearing := _bearing_bond(room, parent_room, parent_unit.stable_id)
			if bearing.is_empty():
				last_failure = "offset room %s has no exact bearing overlap" % \
					room.stable_id
				return [] as Array[FabricUnit]
			parents.append(parent_unit.stable_id)
			bonds.append(bearing)
		var seams := _prior_party_wall_units(source.grid, room,
			prior_unit_by_cell, building_by_room)
		var unit := FabricUnit.new(StringName("spatial.fabric.%s" % room.stable_id),
			recipe_id, room.lattice_origin, room.yaw_quarters, parents, bonds,
			&"", seams)
		if not unit.is_valid():
			last_failure = "room %s produced an invalid fabric unit" % room.stable_id
			return [] as Array[FabricUnit]
		units.append(unit)
		unit_by_room[room.stable_id] = unit
		for cell: Vector3i in room.private_cells:
			prior_unit_by_cell[cell] = unit.stable_id
	return units


static func compile_roof_units(source: WarrenSpatialPlan,
		program: SettlementFabricProgram,
		room_units: Array[FabricUnit]) -> Array[FabricUnit]:
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
	var roof_faces_by_room := _roof_faces_by_room(source, room_id_by_cell)
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
	var cap_count := 0
	var rejected_pitched_count := 0
	var rejected_flat_count := 0
	for room_id: StringName in room_ids:
		var room := room_by_id[room_id] as WarrenRoomStamp
		var parent_unit := unit_by_room[room_id] as FabricUnit
		var face_cells := roof_faces_by_room[room_id] as Array[Vector3i]
		source_face_count += face_cells.size()
		var full := _is_full_roof_plate(room, face_cells)
		var room_seams := _roof_room_seams(source.grid, room,
			unit_by_private_cell, parent_unit.stable_id)
		var selected := false
		var attempt_failures := PackedStringArray()
		if full and not _touches_public_air(source.grid, face_cells):
			var pitched_id := _full_roof_recipe_id(room, source.world_seed)
			var pitched := _full_roof_unit(room_id, room, parent_unit,
				pitched_id, _roof_seams_for_candidate(room_seams,
					parent_unit.stable_id, out))
			if program.recipe(pitched_id) == null:
				last_failure = "missing full roof recipe %s" % pitched_id
				return [] as Array[FabricUnit]
			if probe.add_unit(pitched):
				out.append(pitched)
				realized_face_count += face_cells.size()
				pitched_count += 1
				selected = true
			else:
				rejected_pitched_count += 1
				attempt_failures.append("pitched: %s" % probe.last_rejection)
		if selected:
			continue
		if full and not _touches_public_air(source.grid, face_cells):
			var flat_id := _flat_roof_recipe_id(room)
			var flat := _full_roof_unit(room_id, room, parent_unit, flat_id,
				_roof_seams_for_candidate(room_seams, parent_unit.stable_id, out))
			if program.recipe(flat_id) == null:
				last_failure = "missing exact flat roof recipe %s" % flat_id
				return [] as Array[FabricUnit]
			if probe.add_unit(flat):
				out.append(flat)
				realized_face_count += face_cells.size()
				flat_count += 1
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
			var cap := _cap_placement(source.grid, row)
			if cap.is_empty():
				last_failure = "no native setback cap fits row %d for %s" % [
					row_index, room_id]
				return [] as Array[FabricUnit]
			var seams := _roof_seams_for_candidate(room_seams,
				parent_unit.stable_id, out)
			var cap_unit := _cap_unit(room_id, row_index, room, parent_unit,
				cap, seams)
			if not probe.add_unit(cap_unit):
				last_failure = "exact setback cap %d for %s was rejected after %s: %s" \
					% [row_index, room_id, "; ".join(attempt_failures),
						probe.last_rejection]
				return [] as Array[FabricUnit]
			out.append(cap_unit)
			realized_face_count += row.size()
			cap_count += 1
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
		"setback_cap_unit_count": cap_count,
		"rejected_pitched_count": rejected_pitched_count,
		"rejected_flat_count": rejected_flat_count,
	}
	return out


static func _full_roof_unit(room_id: StringName, room: WarrenRoomStamp,
		parent_unit: FabricUnit, recipe_id: StringName,
		seams: Array[StringName]) -> FabricUnit:
	return FabricUnit.new(StringName("spatial.roof.%s" % room_id), recipe_id,
		room.lattice_origin + Vector3i.UP * WarrenSpatialGrid.STOREY_CELLS,
		room.yaw_quarters, [parent_unit.stable_id] as Array[StringName],
		[FabricUnit.bond(&"bearing.bottom", parent_unit.stable_id,
			&"bearing.top")] as Array[Dictionary], &"", seams)


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


static func _room_recipe_id(room: WarrenRoomStamp, world_seed: int) \
		-> StringName:
	var prefix := "room.long" if room.kind == &"long" \
		else "room.slim" if room.kind == &"slim" \
		else "room.tower" if room.kind == &"tower" else "room"
	if room.terrain_bearing:
		return StringName("%s.base.rock%s" % [prefix,
			"" if room.addressed else ".closed"])
	var phase := posmod(room.lattice_origin.x * 31 + room.lattice_origin.y * 17 \
		+ room.lattice_origin.z * 13 + world_seed \
		+ room.source_storey_index * 7, 6)
	var theme := "blue" if phase in [0, 3] \
		else "orange" if phase in [1, 4] else "amber"
	var addressed := ".address" if room.addressed else ""
	# Phase-B shells carry projecting signs/ivy/laundry. In the dense massif those
	# are separate reserved feature units; selecting them as the structural room
	# shell would let an incidental detail invalidate a legal party-wall bay.
	var phase_b := false
	if room.kind == &"long":
		return StringName("%s.upper%s.%s.%s" % [prefix, addressed, theme,
			"b" if phase_b else "a"])
	return StringName("%s.upper%s.%s%s" % [prefix, addressed, theme,
		".b" if phase_b else ""])


static func _full_roof_recipe_id(room: WarrenRoomStamp,
		world_seed: int) -> StringName:
	var orange := posmod(room.lattice_origin.x * 19 + room.lattice_origin.z * 23 \
		+ room.lattice_origin.y * 11 + world_seed, 3) != 0
	var theme := "orange" if orange else "blue"
	if room.kind == &"tower":
		return StringName("roof.tower.chimney.%s" % theme) \
			if room.roof_feature == 3 else StringName("roof.tower.%s" % theme)
	if room.kind == &"slim":
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
		return &"roof.square.04" if orange else &"roof.square.05"
	return &"roof.square.01" if orange else &"roof.square.02"


static func _flat_roof_recipe_id(room: WarrenRoomStamp) -> StringName:
	if room.kind == &"tower":
		return &"roof.flat.tower"
	if room.kind == &"slim":
		return &"roof.flat.slim"
	if room.kind == &"long":
		return &"roof.flat.long"
	return &"roof.flat.square"


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


static func _cap_placement(_grid: WarrenSpatialGrid,
		face_cells: Array[Vector3i]) -> Dictionary:
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
			return {"recipe_id": StringName("roof.setback.cap.%d" \
				% face_cells.size()), "origin": origin,
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
		prior_roofs: Array[FabricUnit]) -> Array[StringName]:
	## A roof may meet a previously compiled roof only where their underlying
	## rooms share an exact party wall. Multiple native caps over one room are
	## also explicit pieces of the same authoritative roof region.
	var related_rooms: Dictionary = {parent_unit_id: true}
	for room_seam: StringName in room_seams:
		related_rooms[room_seam] = true
	var out: Array[StringName] = []
	out.append_array(room_seams)
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


static func _prior_party_wall_units(grid: WarrenSpatialGrid,
		room: WarrenRoomStamp, prior_unit_by_cell: Dictionary,
		building_by_room: Dictionary) -> Array[StringName]:
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
