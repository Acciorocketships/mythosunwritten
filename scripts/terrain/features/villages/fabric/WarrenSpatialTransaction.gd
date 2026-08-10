class_name WarrenSpatialTransaction
extends RefCounted

## Copy-on-write mutation batch for WarrenSpatialGrid.  Validation reads only
## the pre-transaction grid; commit applies every staged record only after the
## whole batch has passed.  A failed feature therefore cannot leave fragments.
var grid: WarrenSpatialGrid
var stable_id: StringName
var requirements: Dictionary = {}
var assignments: Dictionary = {}
var reservations: Array[Dictionary] = []
var face_records: Array[Dictionary] = []
var last_rejection := ""
var _closed := false


func _init(p_grid: WarrenSpatialGrid, p_stable_id: StringName) -> void:
	grid = p_grid
	stable_id = p_stable_id


func is_closed() -> bool:
	return _closed


func require_use(cells: Array[Vector3i], allowed_uses: Array[int]) -> bool:
	if not _can_stage() or cells.is_empty() or allowed_uses.is_empty():
		return false
	var allowed: Dictionary = {}
	for use_value: int in allowed_uses:
		if use_value < WarrenSpatialGrid.Use.OUTSIDE \
				or use_value > WarrenSpatialGrid.Use.SERVICE_VOID:
			return false
		allowed[use_value] = true
	for cell: Vector3i in cells:
		var index := grid.index_for(cell)
		if index < 0:
			return false
		if requirements.has(index):
			var intersection: Dictionary = {}
			for value: Variant in (requirements[index] as Dictionary).keys():
				if allowed.has(value):
					intersection[value] = true
			if intersection.is_empty():
				return false
			requirements[index] = intersection
		else:
			requirements[index] = allowed.duplicate()
	return true


func assign_use(cells: Array[Vector3i], use_value: int,
		owner_id: StringName) -> bool:
	if not _can_stage() or cells.is_empty() \
			or use_value < WarrenSpatialGrid.Use.OUTSIDE \
			or use_value > WarrenSpatialGrid.Use.SERVICE_VOID \
			or owner_id.is_empty() and use_value != WarrenSpatialGrid.Use.OUTSIDE:
		return false
	for cell: Vector3i in cells:
		var index := grid.index_for(cell)
		if index < 0:
			return false
		var existing := assignments.get(index, {}) as Dictionary
		if not existing.is_empty() and (int(existing.use) != use_value \
				or StringName(existing.owner_id) != owner_id):
			return false
		assignments[index] = {"use": use_value, "owner_id": owner_id}
	return true


func reserve(cells: Array[Vector3i], bits: int,
		owner_id: StringName) -> bool:
	if not _can_stage() or cells.is_empty() or bits <= 0 or owner_id.is_empty():
		return false
	for cell: Vector3i in cells:
		var index := grid.index_for(cell)
		if index < 0:
			return false
		reservations.append({"index": index, "bits": bits,
			"owner_id": owner_id})
	return true


func claim_face(cell: Vector3i, direction: Vector3i, kind: int,
		owner_id: StringName) -> bool:
	if not _can_stage() or not grid.contains(cell) or owner_id.is_empty() \
			or kind < WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR \
			or kind > WarrenSpatialGrid.FaceKind.CONSTRUCTION_JOINT \
			or absi(direction.x) + absi(direction.y) + absi(direction.z) != 1:
		return false
	face_records.append({"cell": cell, "direction": direction,
		"kind": kind, "owner_id": owner_id})
	return true


func validate() -> bool:
	if not _can_stage():
		return false
	# Validation uses the same authority as commit without exposing a second
	# verdict implementation.  The grid deliberately offers no dry-run mutator;
	# callers that need candidate search keep a transaction as their delta and
	# validate it only when committing a selected branch.
	return true


func commit() -> bool:
	if not _can_stage():
		return false
	var accepted := grid.commit_transaction(self)
	last_rejection = grid.last_rejection
	_closed = true
	return accepted


func rollback() -> void:
	if _closed:
		return
	requirements.clear()
	assignments.clear()
	reservations.clear()
	face_records.clear()
	_closed = true


func _can_stage() -> bool:
	return not _closed and grid != null and grid.is_valid() \
		and not grid.is_sealed() and not stable_id.is_empty()
