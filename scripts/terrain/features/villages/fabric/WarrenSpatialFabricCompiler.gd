class_name WarrenSpatialFabricCompiler
extends RefCounted

## Measured-construction adapter for the authoritative 3D town.  This initial
## phase realizes every exact WarrenRoomStamp and its true bearing/party-wall
## relationships. Roof and composed-feature units are appended by later phases;
## no method here may move, resize, or restamp the spatial topology.
static var last_failure := ""


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
	for room_id: StringName in room_ids:
		var room := room_by_id[room_id] as WarrenRoomStamp
		var parent_unit := unit_by_room[room_id] as FabricUnit
		var face_cells := roof_faces_by_room[room_id] as Array[Vector3i]
		var full := _is_full_roof_plate(room, face_cells)
		var unit: FabricUnit
		if full and not _touches_public_air(source.grid, face_cells):
			var recipe_id := _full_roof_recipe_id(room, source.world_seed)
			if program.recipe(recipe_id) == null:
				last_failure = "missing full roof recipe %s" % recipe_id
				return [] as Array[FabricUnit]
			var seams := _roof_room_seams(source.grid, room,
				unit_by_private_cell, parent_unit.stable_id)
			unit = FabricUnit.new(StringName("spatial.roof.%s" % room_id),
				recipe_id, room.lattice_origin + Vector3i.UP \
					* WarrenSpatialGrid.STOREY_CELLS, room.yaw_quarters,
				[parent_unit.stable_id] as Array[StringName], [FabricUnit.bond(
					&"bearing.bottom", parent_unit.stable_id, &"bearing.top")]
					as Array[Dictionary], &"", seams)
		else:
			var cap := _cap_placement(source.grid, face_cells)
			if cap.is_empty():
				last_failure = "no finite setback cap fits roof region for %s (%s)" \
					% [room_id, _cap_failure_diagnostic(source.grid, face_cells)]
				return [] as Array[FabricUnit]
			var anchor_face := cap.anchor_face as Vector3i
			var parent_local := _inverse_cell(anchor_face,
				room.lattice_origin, room.yaw_quarters)
			var seams: Array[StringName] = []
			seams.append_array(_roof_room_seams(source.grid, room,
				unit_by_private_cell, parent_unit.stable_id))
			seams = _unique_sorted_names(seams)
			unit = FabricUnit.new(StringName("spatial.roof.%s" % room_id),
				StringName(cap.recipe_id), cap.origin as Vector3i,
				int(cap.yaw_quarters), [parent_unit.stable_id] as Array[StringName],
				[FabricUnit.bond(&"bearing.bottom", parent_unit.stable_id,
					SettlementFabricProgram._bearing_cell_socket_id(&"top",
						parent_local.x, parent_local.z))] as Array[Dictionary],
				&"", seams)
		if unit == null or not unit.is_valid():
			last_failure = "roof region for %s produced an invalid unit" % room_id
			return [] as Array[FabricUnit]
		out.append(unit)
	return out


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
