class_name WarrenFeatureReservation
extends RefCounted

## Atomic semantic contract for a composed 3D feature.  The grid owns the
## reserved volume; this record names its endpoints and support obligation so a
## partially built skywalk, balcony, market, or court cannot enter a sealed
## spatial plan.
var stable_id: StringName
var kind: StringName
var reserved_cells: Array[Vector3i] = []
var endpoints: Array[Dictionary] = []
var support_node_id: StringName
var audit: Dictionary = {}
var last_rejection := ""
var _cell_set: Dictionary = {}
var _sealed := false


func _init(p_stable_id: StringName, p_kind: StringName) -> void:
	stable_id = p_stable_id
	kind = p_kind


func add_reserved_cells(cells: Array[Vector3i]) -> bool:
	if _sealed or cells.is_empty():
		return false
	for cell: Vector3i in cells:
		if _cell_set.has(cell):
			return false
		_cell_set[cell] = true
		reserved_cells.append(cell)
	return true


func add_endpoint(cell: Vector3i, owner_id: StringName) -> bool:
	if _sealed or owner_id.is_empty():
		return false
	endpoints.append({"cell": cell, "owner_id": owner_id})
	return true


func set_support_node(stable_id_value: StringName) -> bool:
	if _sealed or stable_id_value.is_empty() or not support_node_id.is_empty():
		return false
	support_node_id = stable_id_value
	return true


func seal(grid: WarrenSpatialGrid, supports: WarrenSupportGraph) -> bool:
	last_rejection = ""
	if _sealed or stable_id.is_empty() or kind.is_empty() or grid == null \
			or reserved_cells.is_empty():
		return _reject("missing feature identity or reserved volume")
	for cell: Vector3i in reserved_cells:
		if not grid.reservation_owned_by(cell,
				WarrenSpatialGrid.Reservation.FEATURE, stable_id):
			return _reject("feature reservation differs from grid at %s" % cell)
	var endpoint_owners: Dictionary = {}
	for endpoint: Dictionary in endpoints:
		var cell := endpoint.cell as Vector3i
		var owner_id := StringName(endpoint.owner_id)
		if not grid.contains(cell) or grid.owner_name_at(cell) != owner_id:
			return _reject("feature endpoint is not owned")
		endpoint_owners[owner_id] = true
	if kind in [&"enclosed_skywalk", &"public_skybridge"] \
			and endpoint_owners.size() < 2:
		return _reject("skywalk lacks two distinct endpoint owners")
	if kind == &"balcony" and endpoint_owners.size() != 1:
		return _reject("balcony lacks one private endpoint owner")
	if not support_node_id.is_empty() \
			and (supports == null or not supports.reaches_terrain(support_node_id)):
		return _reject("feature support does not reach terrain")
	audit = {"reserved_cell_count": reserved_cells.size(),
		"endpoint_count": endpoints.size(), "endpoint_owner_count":
		endpoint_owners.size()}
	_sealed = true
	return true


func is_sealed() -> bool:
	return _sealed


func deterministic_signature() -> String:
	var cells := PackedStringArray()
	for cell: Vector3i in reserved_cells:
		cells.append("%d:%d:%d" % [cell.x, cell.y, cell.z])
	cells.sort()
	var endpoint_parts := PackedStringArray()
	for endpoint: Dictionary in endpoints:
		var cell := endpoint.cell as Vector3i
		endpoint_parts.append("%d:%d:%d/%s" % [cell.x, cell.y, cell.z,
			StringName(endpoint.owner_id)])
	endpoint_parts.sort()
	return "%s/%s[%s]>%s/support=%s" % [String(stable_id), String(kind),
		",".join(cells), ",".join(endpoint_parts), String(support_node_id)]


func _reject(reason: String) -> bool:
	last_rejection = reason
	return false
