class_name HeightfieldRegion
extends RefCounted

## Precomputed storey/level maps over a region, with the same read interface as
## HeightfieldPlan (storey_at/level_at/surface_height/tile_plan) but O(1) lookups.
## Built by HeightfieldPlan.compute_region; values equal the per-cell reference.

const STOREY_HEIGHT: float = 4.0
const LEVEL_HEIGHT: float = 0.5

var _storeys: Dictionary  # Vector2i -> int
var _levels: Dictionary   # Vector2i -> int
var _carved: Dictionary   # Vector2i -> true (water carve removed ground here)


func _init(storeys: Dictionary, levels: Dictionary, carved: Dictionary = {}) -> void:
	_storeys = storeys
	_levels = levels
	_carved = carved


func storey_at(cx: int, cz: int) -> int:
	return int(_storeys.get(Vector2i(cx, cz), 0))


## Whether the water carve lowered this cell — a water basin/channel cell.
## Dry banks one storey above a carved cell render as vertical dressed walls
## (crisp shorelines) instead of bare ramps dipping into the water.
func is_carved(cx: int, cz: int) -> bool:
	return _carved.has(Vector2i(cx, cz))


func level_at(cx: int, cz: int) -> int:
	return int(_levels.get(Vector2i(cx, cz), 0))


func surface_height(cx: int, cz: int) -> float:
	# Levels are FLATTENED out of the rendered surface for now (HeightfieldPlan.RENDER_LEVELS) — the
	# owner wants flat "level-texture" ground, not the smooth interpolation of the level field. The
	# level map is still stored (level_at/tile_plan) for the future flat-terrace feature.
	var h := float(storey_at(cx, cz)) * STOREY_HEIGHT
	if HeightfieldPlan.RENDER_LEVELS:
		h += float(level_at(cx, cz)) * LEVEL_HEIGHT
	return h


func tile_plan(cx: int, cz: int) -> Dictionary:
	var s: int = storey_at(cx, cz)
	var l: int = level_at(cx, cz)
	return {"storey": s, "level": l, "height": float(s) * STOREY_HEIGHT + float(l) * LEVEL_HEIGHT}
