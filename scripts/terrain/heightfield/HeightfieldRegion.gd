class_name HeightfieldRegion
extends RefCounted

## Precomputed storey/level maps over a region, with the same read interface as
## HeightfieldPlan (storey_at/level_at/surface_height/tile_plan) but O(1) lookups.
## Built by HeightfieldPlan.compute_region; values equal the per-cell reference.

const STOREY_HEIGHT: float = 4.0
const LEVEL_HEIGHT: float = 0.5

var _storeys: Dictionary  # Vector2i -> int
var _levels: Dictionary   # Vector2i -> int


func _init(storeys: Dictionary, levels: Dictionary) -> void:
	_storeys = storeys
	_levels = levels


func storey_at(cx: int, cz: int) -> int:
	return int(_storeys.get(Vector2i(cx, cz), 0))


func level_at(cx: int, cz: int) -> int:
	return int(_levels.get(Vector2i(cx, cz), 0))


func surface_height(cx: int, cz: int) -> float:
	return float(storey_at(cx, cz)) * STOREY_HEIGHT + float(level_at(cx, cz)) * LEVEL_HEIGHT


func tile_plan(cx: int, cz: int) -> Dictionary:
	var s: int = storey_at(cx, cz)
	var l: int = level_at(cx, cz)
	return {"storey": s, "level": l, "height": float(s) * STOREY_HEIGHT + float(l) * LEVEL_HEIGHT}
