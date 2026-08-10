class_name WarrenRoomStamp
extends RefCounted

## One exact 3 m-tall volumetric grammar room.  Its topology, phase, door, and
## construction family are fixed before asset realization; a compiler may pick
## a measured visual variant, but it may not move or resize this stamp.
const KINDS: Array[StringName] = [&"tower", &"slim", &"building", &"long"]

var stable_id: StringName
var source_parcel_id: StringName
var kind: StringName
var lattice_origin: Vector3i
var yaw_quarters: int
var source_storey_index: int
var terrain_bearing: bool
## Exact lower room that carries this stamp. Ordinarily this is the previous
## storey of the same source lineage; a volumetric handoff may instead name a
## room from the neighboring lineage whose wider plate bridges both supports.
var support_parent_parcel_id: StringName
var support_parent_storey_index: int
var addressed: bool
var threshold_cell := Vector3i(2147483647, 2147483647, 2147483647)
var frontage_direction := Vector3i.ZERO
var address_door_phase: int
var roof_feature: int
var private_cells: Array[Vector3i] = []
var audit: Dictionary = {}
var last_rejection := ""
var _cell_set: Dictionary = {}
var _sealed := false


func _init(p_stable_id: StringName, p_source_parcel_id: StringName,
		p_kind: StringName, p_lattice_origin: Vector3i, p_yaw_quarters: int,
		p_source_storey_index: int, p_terrain_bearing: bool,
		p_addressed: bool, p_threshold_cell: Vector3i = Vector3i(2147483647,
			2147483647, 2147483647),
		p_frontage_direction: Vector3i = Vector3i.ZERO,
		p_roof_feature: int = 0,
		p_support_parent_parcel_id: StringName = &"",
		p_support_parent_storey_index: int = -1,
		p_address_door_phase: int = 0) -> void:
	stable_id = p_stable_id
	source_parcel_id = p_source_parcel_id
	kind = p_kind
	lattice_origin = p_lattice_origin
	yaw_quarters = p_yaw_quarters
	source_storey_index = p_source_storey_index
	terrain_bearing = p_terrain_bearing
	if terrain_bearing:
		support_parent_parcel_id = &""
		support_parent_storey_index = -1
	else:
		support_parent_parcel_id = p_support_parent_parcel_id \
			if not p_support_parent_parcel_id.is_empty() else source_parcel_id
		support_parent_storey_index = p_support_parent_storey_index \
			if p_support_parent_storey_index >= 0 else source_storey_index - 1
	addressed = p_addressed
	threshold_cell = p_threshold_cell
	frontage_direction = p_frontage_direction
	address_door_phase = p_address_door_phase
	roof_feature = p_roof_feature


func add_private_cells(cells: Array[Vector3i]) -> bool:
	if _sealed or cells.is_empty():
		return false
	for cell: Vector3i in cells:
		if _cell_set.has(cell):
			return false
		_cell_set[cell] = true
		private_cells.append(cell)
	return true


func seal(grid: WarrenSpatialGrid, building_id: StringName) -> bool:
	last_rejection = ""
	if _sealed or grid == null or stable_id.is_empty() \
			or source_parcel_id.is_empty() or building_id.is_empty() \
			or kind not in KINDS or yaw_quarters < 0 or yaw_quarters > 3 \
			or source_storey_index < 0 or private_cells.is_empty() \
			or address_door_phase < 0 or address_door_phase > 1 \
			or not addressed and address_door_phase != 0 \
			or terrain_bearing and (not support_parent_parcel_id.is_empty() \
				or support_parent_storey_index >= 0) \
			or not terrain_bearing and (support_parent_parcel_id.is_empty() \
				or support_parent_storey_index < 0 \
				or support_parent_parcel_id == source_parcel_id \
					and support_parent_storey_index >= source_storey_index):
		return _reject("invalid room-stamp identity")
	var expected := expected_private_cells(kind, lattice_origin, yaw_quarters)
	if expected.size() != private_cells.size():
		return _reject("room stamp does not fill its construction envelope")
	var expected_set: Dictionary = {}
	for cell: Vector3i in expected:
		expected_set[cell] = true
	for cell: Vector3i in private_cells:
		if not expected_set.has(cell) or not grid.contains(cell) \
				or grid.use_at(cell) != WarrenSpatialGrid.Use.PRIVATE_VOLUME \
				or grid.owner_name_at(cell) != building_id:
			return _reject("room stamp differs from private volume at %s" % cell)
	if addressed:
		var public_landing := threshold_cell + frontage_direction
		var floor_claim := grid.face_claim(public_landing, Vector3i.DOWN)
		if not _cell_set.has(threshold_cell) \
				or absi(frontage_direction.x) + absi(frontage_direction.y) \
					+ absi(frontage_direction.z) != 1 \
				or frontage_direction.y != 0 \
				or grid.use_at(public_landing) \
					!= WarrenSpatialGrid.Use.PUBLIC_AIR \
				or floor_claim.is_empty() \
				or int(floor_claim.get("kind", -1)) \
					!= WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR:
			return _reject("addressed room has no exact public threshold")
	elif threshold_cell.x != 2147483647:
		return _reject("unaddressed room carries a threshold")
	private_cells.sort_custom(_cell_less)
	audit = {
		"private_cell_count": private_cells.size(),
		"addressed": addressed,
		"address_door_phase": address_door_phase,
		"terrain_bearing": terrain_bearing,
		"roof_feature": roof_feature,
	}
	_sealed = true
	return true


func is_sealed() -> bool:
	return _sealed


func has_private_cell(cell: Vector3i) -> bool:
	return _cell_set.has(cell)


func deterministic_signature() -> String:
	return "%s/%s/%s@%d:%d:%d/r%d/s%d/b%d/p=%s:%d/a%d/dp%d/t=%d:%d:%d/f=%d:%d:%d/rf%d" % [
		String(stable_id), String(source_parcel_id), String(kind),
		lattice_origin.x, lattice_origin.y, lattice_origin.z, yaw_quarters,
		source_storey_index, int(terrain_bearing),
		String(support_parent_parcel_id), support_parent_storey_index,
		int(addressed), address_door_phase,
		threshold_cell.x, threshold_cell.y, threshold_cell.z,
		frontage_direction.x, frontage_direction.y, frontage_direction.z,
		roof_feature]


static func expected_private_cells(p_kind: StringName, origin: Vector3i,
		yaw: int) -> Array[Vector3i]:
	var minimum := Vector3i.ZERO
	var size := Vector3i.ZERO
	match p_kind:
		&"tower":
			minimum = Vector3i(-1, 0, -1)
			size = Vector3i(2, WarrenSpatialGrid.STOREY_CELLS, 2)
		&"slim":
			minimum = Vector3i(-1, 0, -2)
			size = Vector3i(2, WarrenSpatialGrid.STOREY_CELLS, 4)
		&"building":
			minimum = Vector3i(-2, 0, -2)
			size = Vector3i(4, WarrenSpatialGrid.STOREY_CELLS, 4)
		&"long":
			minimum = Vector3i(-2, 0, -3)
			size = Vector3i(4, WarrenSpatialGrid.STOREY_CELLS, 6)
		_:
			return [] as Array[Vector3i]
	if yaw < 0 or yaw > 3:
		return [] as Array[Vector3i]
	var out: Array[Vector3i] = []
	for local_cell: Vector3i in FabricRecipe.box_cells(minimum, size):
		out.append(FabricRecipe.transform_cell(local_cell, origin, yaw))
	return out


static func _cell_less(a: Vector3i, b: Vector3i) -> bool:
	if a.y != b.y:
		return a.y < b.y
	if a.z != b.z:
		return a.z < b.z
	return a.x < b.x


func _reject(reason: String) -> bool:
	last_rejection = reason
	return false
