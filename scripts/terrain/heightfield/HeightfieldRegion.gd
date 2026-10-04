class_name HeightfieldRegion
extends RefCounted

## Precomputed storey/level maps over a region, with the same read interface as
## HeightfieldPlan (storey_at/level_at/surface_height/tile_plan) but O(1) lookups.
## Built by HeightfieldPlan.compute_region; values equal the per-point reference.
## Everything is keyed by lattice point index (world position 12 i, 12 j).

const STOREY_HEIGHT: float = 4.0
const LEVEL_HEIGHT: float = 1.0

var _storeys: Dictionary  # Vector2i -> int
var _levels: Dictionary   # Vector2i -> int
var _carved: Dictionary   # Vector2i -> true (water carve removed ground here)
var terrain_grades: Array[TerrainGradePatch] = []
# Only this inner domain is certified independent of the finite clamp edges.
# Scratch margins and hand-built fixtures must not be reused as complete fields.
var certified_points := Rect2i()
# Vector2i point -> metres (town grades; per-point).
var native_control_heights: Dictionary = {}
var _native_grade_views: Dictionary = {}

func with_terrain_grades(grades: Array[TerrainGradePatch]) -> HeightfieldRegion:
	if grades.is_empty():
		return self
	if _native_grade_views.has(grades): return _native_grade_views[grades]
	var result := HeightfieldRegion.new(_storeys, _levels, _carved, plan)
	result.native_control_heights = native_control_heights.duplicate()
	for grade: TerrainGradePatch in grades:
		result.native_control_heights.merge(preload("res://scripts/terrain/field/NativeTerrainGrade.gd").controls(grade,self),true)
	# The selected controls now go through ordinary terrain classification.
	# There is no post-classification warp of the crown, corner or side face.
	if _native_grade_views.size() >= 8: _native_grade_views.erase(_native_grade_views.keys()[0])
	_native_grade_views[grades.duplicate()] = result
	return result

## Road verges (owner review, October 1): no cliff stands beside a road. A
## point next to a road point (cardinal, not itself on the road) that stands
## two or more storeys above it is lowered to one storey above it, so the
## nearest wall rising from the road is one point back (18 m from the road's
## centre line) and its cliff dressing never meets the road's keep-out in a
## sheer cut. Only lowering: a road on a cliff top keeps its drop (the
## dressing falls away from it), water points are never touched (water is
## solved on the natural field) and points another control already owns (a
## town grade) keep it. `masks`: the 24 m route cells' connection masks
## (bit 1 +x, 2 -x, 4 +z, 8 -z), as FeatureGroundField paints them.
func with_road_verges(masks: Dictionary) -> HeightfieldRegion:
	var road := {}
	for cell: Vector2i in masks:
		var mask: int = masks[cell]
		var p := cell * PathProgram.POINTS_PER_ROUTE_CELL
		road[p] = true
		for arm: Array in [[1, Vector2i(1, 0)], [2, Vector2i(-1, 0)], [4, Vector2i(0, 1)], [8, Vector2i(0, -1)]]:
			if (mask & int(arm[0])) != 0:
				road[p + arm[1]] = true
	var verges := {}
	for p: Vector2i in road:
		if not has_surface_point(p.x, p.y):
			continue
		var top := (storey_at(p.x, p.y) + 1) * STOREY_HEIGHT
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := p + d
			if road.has(n) or not has_surface_point(n.x, n.y) or is_carved(n.x, n.y) \
					or native_control_heights.has(n):
				continue
			if storey_at(n.x, n.y) - storey_at(p.x, p.y) >= 2:
				verges[n] = minf(float(verges.get(n, INF)), top)
	if verges.is_empty():
		return self
	var result := HeightfieldRegion.new(_storeys, _levels, _carved, plan)
	result.terrain_grades = terrain_grades
	result.native_control_heights = native_control_heights.duplicate()
	result.native_control_heights.merge(verges, false)
	return result


func without_terrain_grades() -> HeightfieldRegion:
	# Remove only the legacy post-classification warp. Native controls are
	# already the final terrain lattice and must survive native piece selection.
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


## World pitch of the lattice this region is keyed by (TerrainTileField reads it).
func terrain_tile_size() -> float:
	return HeightfieldPlan.POINT


func storey_at(cx: int, cz: int) -> int:
	if native_control_heights.has(Vector2i(cx,cz)):
		return floori(float(native_control_heights[Vector2i(cx,cz)])/STOREY_HEIGHT)
	return int(_storeys.get(Vector2i(cx, cz), 0))


## Whether the water carve lowered this point — a water basin/channel cell.
## Retained for water-aware cliff dressing; this tag does not create a wall.
func is_carved(cx: int, cz: int) -> bool:
	return _carved.has(Vector2i(cx, cz))


func level_at(cx: int, cz: int) -> int:
	if native_control_heights.has(Vector2i(cx,cz)):
		return floori(fposmod(float(native_control_heights[Vector2i(cx,cz)]),STOREY_HEIGHT))
	return int(_levels.get(Vector2i(cx, cz), 0))


func has_surface_point(cx: int, cz: int) -> bool:
	return _levels.has(Vector2i(cx, cz))


func surface_height(cx: int, cz: int) -> float:
	if native_control_heights.has(Vector2i(cx,cz)):
		return float(native_control_heights[Vector2i(cx,cz)])
	# Level terraces are IN the rendered surface (HeightfieldPlan.RENDER_LEVELS, owner 2026-07-15):
	# each 1m level step ramps through the same tile slope profile as a one-storey edge —
	# short slope tiles (walls key off storey_at only).
	var h := float(storey_at(cx, cz)) * STOREY_HEIGHT
	if HeightfieldPlan.RENDER_LEVELS:
		h += float(level_at(cx, cz)) * LEVEL_HEIGHT
	return h


func tile_plan(cx: int, cz: int) -> Dictionary:
	var s: int = storey_at(cx, cz)
	var l: int = level_at(cx, cz)
	return {"storey": s, "level": l, "height": surface_height(cx, cz)}
