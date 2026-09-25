class_name VillagePlatformRegion
extends RefCounted

## One connected union of module cells serving nearby inhabited front doors
## at the same finished floor. A region has no free-standing area and cannot
## exist without at least two frontages.
var stable_key: StringName
var frontage_keys: Array[StringName] = []
var surface_y: float
var yaw: float
var cell_centres: Array[Vector2] = []


func is_valid() -> bool:
	if stable_key.is_empty() or frontage_keys.size() < 2 \
			or not is_finite(surface_y) or not is_finite(yaw) \
			or cell_centres.is_empty():
		return false
	var frontages: Dictionary = {}
	for key: StringName in frontage_keys:
		if key.is_empty() or frontages.has(key):
			return false
		frontages[key] = true
	var cells: Dictionary = {}
	for centre: Vector2 in cell_centres:
		if not centre.is_finite():
			return false
		var key := _cell_key(centre)
		if cells.has(key):
			return false
		cells[key] = centre
	var pending: Array[String] = [String(cells.keys()[0])]
	var seen: Dictionary = {}
	while not pending.is_empty():
		var key: String = pending.pop_back()
		if seen.has(key):
			continue
		seen[key] = true
		var centre: Vector2 = cells[key]
		for offset: Vector2 in [Vector2.RIGHT, Vector2.DOWN,
				Vector2.LEFT, Vector2.UP]:
			var neighbour := _cell_key(centre \
				+ offset.rotated(yaw) * VillageProgram.MODULE)
			if cells.has(neighbour) and not seen.has(neighbour):
				pending.append(neighbour)
	return seen.size() == cells.size()


func cell_shapes() -> Array[FeatureGroundShape]:
	var out: Array[FeatureGroundShape] = []
	for index in cell_centres.size():
		out.append(FeatureGroundShape.oriented_rect(cell_centres[index],
			Vector2.ONE * VillageProgram.MODULE * 0.5, yaw,
			FeatureGroundField.NATURAL, 0,
			StringName("%s.cell.%03d" % [stable_key, index])))
	return out


func contains_cell(centre: Vector2, cell_yaw: float) -> bool:
	var candidate := FeatureGroundShape.oriented_rect(centre,
		Vector2.ONE * VillageProgram.MODULE * 0.5, cell_yaw)
	for shape: FeatureGroundShape in cell_shapes():
		if shape.intersects(candidate):
			return true
	return false


static func _cell_key(centre: Vector2) -> String:
	return "%d:%d" % [roundi(centre.x * 1000.0),
		roundi(centre.y * 1000.0)]
