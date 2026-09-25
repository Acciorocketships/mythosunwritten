class_name WarrenConstructionRegion
extends RefCounted

## One connected coplanar construction interface derived from the sealed
## spatial volume.  A region is still pure planning data: it says which exact
## fine-cell faces must become a roof, facade, floor, soffit, party wall, or
## explicit opening, but it does not choose meshes or create resources.
var stable_id: StringName
var face_kind: int
var owner_id: StringName
var direction: Vector3i
var face_cells: Array[Vector3i] = []
var audit: Dictionary = {}
var last_rejection := ""
var _cell_set: Dictionary = {}
var _sealed := false


func _init(p_stable_id: StringName, p_face_kind: int,
		p_owner_id: StringName, p_direction: Vector3i) -> void:
	stable_id = p_stable_id
	face_kind = p_face_kind
	owner_id = p_owner_id
	direction = p_direction


func add_face(cell: Vector3i) -> bool:
	if _sealed or _cell_set.has(cell):
		return false
	_cell_set[cell] = true
	face_cells.append(cell)
	return true


func seal(grid: WarrenSpatialGrid) -> bool:
	last_rejection = ""
	if _sealed or grid == null or stable_id.is_empty() or owner_id.is_empty() \
			or face_kind < WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR \
			or face_kind > WarrenSpatialGrid.FaceKind.CONSTRUCTION_JOINT \
			or not _canonical_direction(direction) or face_cells.is_empty():
		return _reject("invalid construction-region identity")
	var plane := _plane_coordinate(face_cells[0])
	for cell: Vector3i in face_cells:
		if _plane_coordinate(cell) != plane:
			return _reject("construction region is not coplanar")
		var claim := grid.face_claim(cell, direction)
		if claim.is_empty() or int(claim.get("kind", -1)) != face_kind \
				or StringName(claim.get("owner_id", "")) != owner_id:
			return _reject("region differs from source face at %s" % cell)
	if not _connected():
		return _reject("construction region is disconnected")
	if _must_remain_explicit(face_kind) and face_cells.size() != 1:
		return _reject("opening or seam was merged across cells")
	face_cells.sort_custom(_cell_less)
	var minimum := face_cells[0]
	var maximum := face_cells[0]
	for cell: Vector3i in face_cells:
		minimum = Vector3i(mini(minimum.x, cell.x), mini(minimum.y, cell.y),
			mini(minimum.z, cell.z))
		maximum = Vector3i(maxi(maximum.x, cell.x), maxi(maximum.y, cell.y),
			maxi(maximum.z, cell.z))
	audit = {
		"face_count": face_cells.size(),
		"plane_coordinate": plane,
		"minimum": minimum,
		"maximum": maximum,
	}
	_sealed = true
	return true


func is_sealed() -> bool:
	return _sealed


func has_face(cell: Vector3i) -> bool:
	return _cell_set.has(cell)


func deterministic_signature() -> String:
	var cells := PackedStringArray()
	for cell: Vector3i in face_cells:
		cells.append("%d:%d:%d" % [cell.x, cell.y, cell.z])
	cells.sort()
	return "%s=%d/%s/%d:%d:%d[%s]" % [String(stable_id), face_kind,
		String(owner_id), direction.x, direction.y, direction.z,
		",".join(cells)]


func _connected() -> bool:
	var seen: Dictionary = {face_cells[0]: true}
	var pending: Array[Vector3i] = [face_cells[0]]
	var tangents := _tangent_directions(direction)
	while not pending.is_empty():
		var cell: Vector3i = pending.pop_back()
		for tangent: Vector3i in tangents:
			var neighbor := cell + tangent
			if _cell_set.has(neighbor) and not seen.has(neighbor):
				seen[neighbor] = true
				pending.append(neighbor)
	return seen.size() == face_cells.size()


func _plane_coordinate(cell: Vector3i) -> int:
	return cell.x + 1 if direction.x != 0 \
		else cell.y + 1 if direction.y != 0 else cell.z + 1


static func _canonical_direction(value: Vector3i) -> bool:
	return value in [Vector3i.RIGHT, Vector3i.UP, Vector3i.BACK]


static func _must_remain_explicit(kind: int) -> bool:
	return kind in [WarrenSpatialGrid.FaceKind.DOOR,
		WarrenSpatialGrid.FaceKind.WINDOW,
		WarrenSpatialGrid.FaceKind.OPEN_SEAM,
		WarrenSpatialGrid.FaceKind.CONSTRUCTION_JOINT]


static func _tangent_directions(normal: Vector3i) -> Array[Vector3i]:
	if normal.x != 0:
		return [Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD,
			Vector3i.BACK] as Array[Vector3i]
	if normal.y != 0:
		return [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD,
			Vector3i.BACK] as Array[Vector3i]
	return [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.UP,
		Vector3i.DOWN] as Array[Vector3i]


static func _cell_less(a: Vector3i, b: Vector3i) -> bool:
	if a.y != b.y:
		return a.y < b.y
	if a.z != b.z:
		return a.z < b.z
	return a.x < b.x


func _reject(reason: String) -> bool:
	last_rejection = reason
	return false
