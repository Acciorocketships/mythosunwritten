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

## Back-pointer to the HeightfieldPlan this region was computed from (null
## for hand-built test fixtures that construct a HeightfieldRegion directly
## from a {storeys} dict with no real plan behind it). Untyped, duck-typed,
## to avoid a HeightfieldPlan<->HeightfieldRegion class-resolution cycle —
## the same convention HeightfieldPlan._water_plan already uses for its own
## cross-class back-pointer. Read by WaterField.profile() (C1 fix,
## .superpowers/sdd/final-review-run2.md): a region built by a real plan can
## be traded for a TRACE-OWNED canonical region from that SAME plan, so
## profile()'s terrain hug no longer depends on which caller's chunk-window
## happened to reach it first.
var plan = null


func _init(storeys: Dictionary, levels: Dictionary, carved: Dictionary = {}, p_plan = null) -> void:
	_storeys = storeys
	_levels = levels
	_carved = carved
	plan = p_plan


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
