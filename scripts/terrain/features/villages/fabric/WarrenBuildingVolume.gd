class_name WarrenBuildingVolume
extends RefCounted

## One connected 3D inhabited owner.  Storeys are derived from private-volume
## cells rather than extruded from a footprint, so offsets, setbacks, bridge
## rooms, terraces, and ownership handoffs remain structural plan facts.
const MAX_IDENTICAL_FLOORPLATE_RUN := 2
const MIN_COMPOSITION_BREAK_RATIO := 0.25

var stable_id: StringName
var storey_base_band: int
var private_cells: Array[Vector3i] = []
var room_records: Array[Dictionary] = []
var thresholds: Array[Dictionary] = []
var feature_ids: Array[StringName] = []
var private_parent_ids: Array[StringName] = []
var audit: Dictionary = {}
var last_rejection := ""
var _private_set: Dictionary = {}
var _sealed := false


func _init(p_stable_id: StringName, p_storey_base_band: int) -> void:
	stable_id = p_stable_id
	storey_base_band = p_storey_base_band


func add_private_cells(cells: Array[Vector3i]) -> bool:
	if _sealed or cells.is_empty():
		return false
	for cell: Vector3i in cells:
		if _private_set.has(cell):
			return false
		_private_set[cell] = true
		private_cells.append(cell)
	return true


func add_room(record: Dictionary) -> bool:
	if _sealed or StringName(record.get("stable_id", "")).is_empty() \
			or (record.get("cells", []) as Array).is_empty():
		return false
	room_records.append(record.duplicate(true))
	return true


func add_threshold(private_cell: Vector3i, public_cell: Vector3i) -> bool:
	if _sealed or not _private_set.has(private_cell) \
			or private_cell.y != public_cell.y \
			or absi(private_cell.x - public_cell.x) \
				+ absi(private_cell.z - public_cell.z) != 1:
		return false
	thresholds.append({"private_cell": private_cell,
		"public_cell": public_cell, "direction": public_cell - private_cell})
	return true


func add_feature(feature_id: StringName) -> bool:
	if _sealed or feature_id.is_empty() or feature_ids.has(feature_id):
		return false
	feature_ids.append(feature_id)
	return true


func add_private_parent(parent_id: StringName) -> bool:
	if _sealed or parent_id.is_empty() or parent_id == stable_id \
			or private_parent_ids.has(parent_id):
		return false
	private_parent_ids.append(parent_id)
	return true


func seal(grid: WarrenSpatialGrid) -> bool:
	last_rejection = ""
	if _sealed or grid == null or stable_id.is_empty() or private_cells.is_empty():
		return _reject("missing grid, id, or private volume")
	for cell: Vector3i in private_cells:
		if not grid.contains(cell) \
				or grid.use_at(cell) != WarrenSpatialGrid.Use.PRIVATE_VOLUME \
				or grid.owner_name_at(cell) != stable_id:
			return _reject("private volume differs from grid at %s" % cell)
	if not _connected():
		return _reject("private volume is disconnected")
	var plates := _floorplates()
	if plates.is_empty():
		return _reject("private volume has no storeys")
	var composition := _composition_audit(plates)
	audit = composition.duplicate(true)
	if int(composition.longest_identical_floorplate_run) \
			> MAX_IDENTICAL_FLOORPLATE_RUN:
		return _reject("identical floorplate repeats as a vertical tower")
	if int(composition.storey_count) >= 4 \
			and float(composition.minimum_composition_break_ratio) \
			< MIN_COMPOSITION_BREAK_RATIO:
		return _reject("floorplate composition break is too small")
	if thresholds.is_empty() and private_parent_ids.is_empty():
		return _reject("building has no public threshold or private parent")
	for threshold: Dictionary in thresholds:
		var private_cell := threshold.private_cell as Vector3i
		var public_cell := threshold.public_cell as Vector3i
		if not _private_set.has(private_cell) or not grid.contains(public_cell) \
				or grid.use_at(public_cell) != WarrenSpatialGrid.Use.PUBLIC_AIR:
			return _reject("threshold does not meet public air")
	audit["private_cell_count"] = private_cells.size()
	audit["threshold_count"] = thresholds.size()
	audit["room_count"] = room_records.size()
	audit["feature_count"] = feature_ids.size()
	_sealed = true
	return true


func is_sealed() -> bool:
	return _sealed


func has_private_cell(cell: Vector3i) -> bool:
	return _private_set.has(cell)


func floorplates() -> Array[Dictionary]:
	var source := _floorplates()
	var out: Array[Dictionary] = []
	for plate: Dictionary in source:
		out.append(plate.duplicate())
	return out


func deterministic_signature() -> String:
	var cells := PackedStringArray()
	for cell: Vector3i in private_cells:
		cells.append("%d:%d:%d" % [cell.x, cell.y, cell.z])
	cells.sort()
	var doors := PackedStringArray()
	for threshold: Dictionary in thresholds:
		var private_cell := threshold.private_cell as Vector3i
		var public_cell := threshold.public_cell as Vector3i
		doors.append("%d:%d:%d>%d:%d:%d" % [private_cell.x,
			private_cell.y, private_cell.z, public_cell.x, public_cell.y,
			public_cell.z])
	doors.sort()
	return "%s@%d[%s]/doors=%s" % [String(stable_id), storey_base_band,
		",".join(cells), ",".join(doors)]


func _connected() -> bool:
	var seen: Dictionary = {}
	var frontier: Array[Vector3i] = [private_cells[0]]
	seen[private_cells[0]] = true
	while not frontier.is_empty():
		var cell: Vector3i = frontier.pop_back()
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD, Vector3i.BACK]:
			var neighbor: Vector3i = cell + direction
			if _private_set.has(neighbor) and not seen.has(neighbor):
				seen[neighbor] = true
				frontier.append(neighbor)
	return seen.size() == private_cells.size()


func _floorplates() -> Array[Dictionary]:
	var by_storey: Dictionary = {}
	var highest := -1
	for cell: Vector3i in private_cells:
		if cell.y < storey_base_band:
			return []
		var storey := floori(float(cell.y - storey_base_band) \
			/ float(WarrenSpatialGrid.STOREY_CELLS))
		highest = maxi(highest, storey)
		if not by_storey.has(storey):
			by_storey[storey] = {}
		(by_storey[storey] as Dictionary)[Vector2i(cell.x, cell.z)] = true
	var out: Array[Dictionary] = []
	for storey in range(highest + 1):
		if not by_storey.has(storey):
			return []
		out.append(by_storey[storey] as Dictionary)
	return out


static func _composition_audit(plates: Array[Dictionary]) -> Dictionary:
	var longest_run := 1
	var current_run := 1
	for index in range(1, plates.size()):
		if _same_set(plates[index - 1], plates[index]):
			current_run += 1
			longest_run = maxi(longest_run, current_run)
		else:
			current_run = 1
	var minimum_break := 1.0
	var break_count := 0
	for upper_index in range(2, plates.size(), 2):
		var lower := plates[upper_index - 1]
		var upper := plates[upper_index]
		var union: Dictionary = lower.duplicate()
		for key: Variant in upper.keys():
			union[key] = true
		var difference := 0
		for key: Variant in union.keys():
			difference += int(lower.has(key) != upper.has(key))
		var ratio := float(difference) / float(maxi(union.size(), 1))
		minimum_break = minf(minimum_break, ratio)
		break_count += 1
	return {
		"storey_count": plates.size(),
		"longest_identical_floorplate_run": longest_run,
		"composition_break_count": break_count,
		"minimum_composition_break_ratio": minimum_break,
	}


static func _same_set(left: Dictionary, right: Dictionary) -> bool:
	if left.size() != right.size():
		return false
	for key: Variant in left.keys():
		if not right.has(key):
			return false
	return true


func _reject(reason: String) -> bool:
	last_rejection = reason
	return false
