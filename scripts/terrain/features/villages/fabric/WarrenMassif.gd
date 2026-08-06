class_name WarrenMassif
extends RefCounted

## Terraced solid city mass: per-column occupiable band interval. The public
## realm is carved FROM this object; it never grows to meet a route.

var world_seed: int
var columns: Dictionary = {}
var core_top_bands: int = 0
var _sealed := false


func _init(p_world_seed: int) -> void:
	world_seed = p_world_seed


func seal() -> bool:
	if columns.is_empty():
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
