class_name WarrenMassif
extends RefCounted

## Terraced solid city mass: per-column occupiable band interval. The public
## realm is carved FROM this object; it never grows to meet a route.
##
## "Solid" is an invariant seal() actually checks, not just a naming
## convention: a builder bug that fragments the footprint (see
## WarrenMassifBuilder's fix-round-1 history) must fail here, not silently
## pass through as a solid mass with holes in it.

var world_seed: int
var columns: Dictionary = {}
var core_top_bands: int = 0
var last_rejection := ""
var _sealed := false


func _init(p_world_seed: int) -> void:
	world_seed = p_world_seed


func seal() -> bool:
	if columns.is_empty():
		last_rejection = "empty massif"
		return false
	if not _is_single_component():
		last_rejection = "footprint is not a single connected component"
		return false
	var hole: Variant = _find_interior_hole()
	if hole != null:
		last_rejection = "interior hole at column %s" % str(hole)
		return false
	_sealed = true
	return true


func is_sealed() -> bool:
	return _sealed


func has_column(column: Vector2i) -> bool:
	return columns.has(column)


func top_at(column: Vector2i) -> int:
	return int((columns.get(column, {}) as Dictionary).get("top", 0))


func base_at(column: Vector2i) -> int:
	return int((columns.get(column, {}) as Dictionary).get("base", 0))


func terrace_levels() -> Array[int]:
	var seen: Dictionary = {}
	for column: Vector2i in columns:
		seen[top_at(column)] = true
	var out: Array[int] = []
	out.assign(seen.keys())
	out.sort()
	return out


func widest_plateau_cells() -> int:
	## Largest 4-connected component sharing one top band.
	var visited: Dictionary = {}
	var widest := 0
	for start_value: Variant in columns.keys():
		var start := start_value as Vector2i
		if visited.has(start):
			continue
		var level := top_at(start)
		var frontier: Array[Vector2i] = [start]
		var count := 0
		visited[start] = true
		while not frontier.is_empty():
			var cell: Vector2i = frontier.pop_back()
			count += 1
			for direction: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT,
					Vector2i.UP, Vector2i.DOWN]:
				var neighbor := cell + direction
				if visited.has(neighbor) or not columns.has(neighbor) \
						or top_at(neighbor) != level:
					continue
				visited[neighbor] = true
				frontier.append(neighbor)
		widest = maxi(widest, count)
	return widest


func _is_single_component() -> bool:
	## Flood fill on existence alone (ignoring top band), mirroring the
	## sibling WarrenVolumeEnvelope._seal() convention of validating the
	## solid's continuity before sealing.
	var keys: Array = columns.keys()
	if keys.is_empty():
		return true
	var start := keys[0] as Vector2i
	var visited: Dictionary = {}
	var frontier: Array[Vector2i] = [start]
	visited[start] = true
	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_back()
		for direction: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT,
				Vector2i.UP, Vector2i.DOWN]:
			var neighbor := cell + direction
			if visited.has(neighbor) or not columns.has(neighbor):
				continue
			visited[neighbor] = true
			frontier.append(neighbor)
	return visited.size() == columns.size()


func _find_interior_hole() -> Variant:
	## A missing column fully surrounded by present columns: not the natural
	## boundary taper, but a puncture through the middle of the solid.
	## Returns the first such column found, or null if there is none.
	var min_x := 2147483647
	var max_x := -2147483648
	var min_z := 2147483647
	var max_z := -2147483648
	for column: Vector2i in columns:
		min_x = mini(min_x, column.x)
		max_x = maxi(max_x, column.x)
		min_z = mini(min_z, column.y)
		max_z = maxi(max_z, column.y)
	for z in range(min_z + 1, max_z):
		for x in range(min_x + 1, max_x):
			var cell := Vector2i(x, z)
			if columns.has(cell):
				continue
			if columns.has(cell + Vector2i.RIGHT) and columns.has(cell + Vector2i.LEFT) \
					and columns.has(cell + Vector2i.UP) and columns.has(cell + Vector2i.DOWN):
				return cell
	return null
