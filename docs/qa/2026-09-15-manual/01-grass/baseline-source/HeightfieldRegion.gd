class_name HeightfieldRegion
extends RefCounted

## Precomputed storey/level maps over a region, with the same read interface as
## HeightfieldPlan (storey_at/level_at/surface_height/tile_plan) but O(1) lookups.
## Built by HeightfieldPlan.compute_region; values equal the per-cell reference.

const STOREY_HEIGHT: float = 4.0
const LEVEL_HEIGHT: float = 1.0

var _storeys: Dictionary  # Vector2i -> int
var _levels: Dictionary   # Vector2i -> int
var _carved: Dictionary   # Vector2i -> true (water carve removed ground here)
var terrain_grades: Array[TerrainGradePatch] = []

func with_terrain_grades(grades: Array[TerrainGradePatch]) -> HeightfieldRegion:
	if grades.is_empty():
		return self
	var result := HeightfieldRegion.new(_storeys, _levels, _carved, plan)
	result.terrain_grades.assign(grades)
	return result

func without_terrain_grades() -> HeightfieldRegion:
	return self if terrain_grades.is_empty() else HeightfieldRegion.new(
		_storeys, _levels, _carved, plan)


func graded_height(x: float, z: float, natural_height: float) -> float:
	var height := natural_height
	for grade: TerrainGradePatch in terrain_grades:
		height = grade.surface_y(Vector2(x, z), height)
	return height

func has_grade_in(area: Rect2) -> bool:
	for grade: TerrainGradePatch in terrain_grades:
		if grade.bounds.intersects(area, true):
			return true
	return false

# A region's grade patches are immutable. Clip sampling revisits the same
# finite authored-piece bounds for thousands of surface vertices.
var _grade_effect_cache: Dictionary = {}

func has_grade_effect_in(area: Rect2) -> bool:
	if terrain_grades.is_empty(): return false
	if _grade_effect_cache.has(area): return _grade_effect_cache[area]
	var affected := false
	for grade: TerrainGradePatch in terrain_grades:
		if not grade.bounds.intersects(area, true): continue
		var local := Rect2(area.position - grade._origin, area.size)
		if grade._weight_bounds(local).y > 0.000001:
			affected = true
			break
	_grade_effect_cache[area] = affected
	return affected


func graded_height_bounds(area: Rect2, natural: Vector2) -> Vector2:
	var interval := natural
	for grade: TerrainGradePatch in terrain_grades:
		interval = grade.height_bounds(area, interval)
	return interval

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
## Retained for water-aware cliff dressing; this tag does not create a wall.
func is_carved(cx: int, cz: int) -> bool:
	return _carved.has(Vector2i(cx, cz))


func level_at(cx: int, cz: int) -> int:
	return int(_levels.get(Vector2i(cx, cz), 0))


func has_surface_cell(cx: int, cz: int) -> bool:
	return _levels.has(Vector2i(cx, cz))


func surface_height(cx: int, cz: int) -> float:
	# Level terraces are IN the rendered surface (HeightfieldPlan.RENDER_LEVELS, owner 2026-07-15):
	# each 1m level step ramps through the same half-cell slope profile as the 4m storey slopes —
	# short slope tiles, no KayKit dressing (walls/lips/skirts key off storey_at only).
	var h := float(storey_at(cx, cz)) * STOREY_HEIGHT
	if HeightfieldPlan.RENDER_LEVELS:
		h += float(level_at(cx, cz)) * LEVEL_HEIGHT
	return h


func tile_plan(cx: int, cz: int) -> Dictionary:
	var s: int = storey_at(cx, cz)
	var l: int = level_at(cx, cz)
	return {"storey": s, "level": l, "height": float(s) * STOREY_HEIGHT + float(l) * LEVEL_HEIGHT}
