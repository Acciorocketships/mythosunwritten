class_name FabricVolumePlan
extends RefCounted

## Resource-free proof that every public swept-air claim belongs to one
## outside-connected component and never enters occupied building volume.
## Exhaustive core classification can extend this record without changing the
## public-realm or recipe contracts.
var stable_id: StringName
var exterior_air_cells: Array[Vector3i] = []
var unreachable_air_cells: Array[Vector3i] = []
var occupied_air_overlaps: Array[Vector3i] = []
var _air_set: Dictionary = {}
var _occupied_set: Dictionary = {}
var _landing_cells: Array[Vector3i] = []
var _sealed := false
var last_rejection := ""


func _init(p_stable_id: StringName) -> void:
	stable_id = p_stable_id


func construct(air_claims: Dictionary, landing_air_cells: Array[Vector3i],
		structural_solids: Dictionary, inhabited_volume: Dictionary) -> void:
	## Store construction facts. Connectivity and overlap audits run in tests.
	_air_set = air_claims.duplicate()
	_occupied_set = structural_solids.duplicate()
	_occupied_set.merge(inhabited_volume, true)
	_landing_cells.assign(landing_air_cells)
	exterior_air_cells.assign(_air_set.keys())
	exterior_air_cells.sort_custom(_cell_less)
	_sealed = true


func seal(air_claims: Dictionary, landing_air_cells: Array[Vector3i],
		structural_solids: Dictionary, inhabited_volume: Dictionary) -> bool:
	if _sealed:
		return false
	construct(air_claims, landing_air_cells, structural_solids, inhabited_volume)
	var valid := validate()
	_sealed = valid
	return valid


func validate() -> bool:
	last_rejection = ""
	unreachable_air_cells.clear()
	occupied_air_overlaps.clear()
	if not _sealed or stable_id.is_empty() or _air_set.is_empty() or _landing_cells.is_empty():
		last_rejection = "missing volume id, exterior air, or landing-air seed"
		return false
	for cell: Vector3i in _air_set:
		if _occupied_set.has(cell):
			occupied_air_overlaps.append(cell)
	if not occupied_air_overlaps.is_empty():
		occupied_air_overlaps.sort_custom(_cell_less)
		last_rejection = "%d public-air cells overlap occupied volume" % occupied_air_overlaps.size()
		return false
	var reached: Dictionary = {}
	var pending: Array[Vector3i] = []
	for cell: Vector3i in _landing_cells:
		if _air_set.has(cell) and not reached.has(cell):
			reached[cell] = true
			pending.append(cell)
	if pending.is_empty():
		last_rejection = "landing has no claimed exterior-air seed"
		return false
	const DIRECTIONS: Array[Vector3i] = [
		Vector3i.LEFT, Vector3i.RIGHT, Vector3i.UP, Vector3i.DOWN,
		Vector3i.FORWARD, Vector3i.BACK,
	]
	while not pending.is_empty():
		var cell: Vector3i = pending.pop_back()
		for direction: Vector3i in DIRECTIONS:
			var neighbor := cell + direction
			if _air_set.has(neighbor) and not reached.has(neighbor):
				reached[neighbor] = true
				pending.append(neighbor)
	for cell_value: Variant in _air_set:
		var cell := cell_value as Vector3i
		if not reached.has(cell):
			unreachable_air_cells.append(cell)
	if not unreachable_air_cells.is_empty():
		unreachable_air_cells.sort_custom(_cell_less)
		last_rejection = "%d public-air cells are cut off from the route landing" % \
			unreachable_air_cells.size()
		return false
	return true


func is_sealed() -> bool:
	return _sealed


func has_exterior_air(cell: Vector3i) -> bool:
	return _air_set.has(cell)


func has_occupied_cell(cell: Vector3i) -> bool:
	return _occupied_set.has(cell)


func audit() -> Dictionary:
	return {
		"exterior_air_cell_count": exterior_air_cells.size(),
		"unreachable_exterior_air_count": unreachable_air_cells.size(),
		"public_air_occupied_overlap_count": occupied_air_overlaps.size(),
	}


static func _cell_less(a: Vector3i, b: Vector3i) -> bool:
	if a.y != b.y:
		return a.y < b.y
	if a.z != b.z:
		return a.z < b.z
	return a.x < b.x
