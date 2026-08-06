class_name VillageTerrainView
extends RefCounted

## Canonical read-only terrain input for village solvers. Production views use
## the worker-confined world-field cache so a survey can cross streaming-block
## boundaries without leaking block-local coverage assumptions into layout.
## Region views keep synthetic unit tests small and explicit.
var _fixed_region: HeightfieldRegion
var _fixed_water: WaterFieldContext
var _fields: WorldFieldBlockCache


static func from_region(region: HeightfieldRegion,
		water: WaterFieldContext = null) -> VillageTerrainView:
	assert(region != null)
	var view := VillageTerrainView.new()
	view._fixed_region = region
	view._fixed_water = water
	return view


static func from_fields(fields: WorldFieldBlockCache) -> VillageTerrainView:
	assert(fields != null)
	var view := VillageTerrainView.new()
	view._fields = fields
	return view


func region_at(point: Vector2) -> HeightfieldRegion:
	assert(point.is_finite())
	return _fields.region_at(point) if _fields != null else _fixed_region


func surface_y(point: Vector2) -> float:
	assert(point.is_finite())
	var region := region_at(point)
	return TerrainSurfaceField.surface_y(region, point.x, point.y)


func region_covering(world_rect: Rect2) -> HeightfieldRegion:
	assert(world_rect.position.is_finite() and world_rect.size.is_finite())
	if _fields != null:
		return _fields.region_covering(world_rect)
	return _fixed_region


func is_wet(point: Vector2) -> bool:
	assert(point.is_finite())
	if _fields != null:
		return _fields.water_at(point).is_wet(point)
	if _fixed_water == null:
		return false
	# A fixed view is intentionally strict: callers that need to cross a field
	# block must construct a cache-backed view instead of treating unknown water
	# as dry land.
	assert(_fixed_water.covers(point),
		"Village terrain query exceeds its fixed water coverage")
	return _fixed_water.is_wet(point)


func may_be_wet(point: Vector2) -> bool:
	assert(point.is_finite())
	if _fields != null:
		# The guarded source footprint is conservative and much cheaper than a
		# hydrostatic fill. Final structural compilation still uses is_wet() on
		# the few selected footprints.
		return _fields.planning_water_distance(point) <= 0.0
	return is_wet(point)


func proves_planning_dry(centre: Vector2, radius: float) -> bool:
	assert(centre.is_finite() and is_finite(radius) and radius >= 0.0)
	if _fields == null:
		return false
	return _fields.planning_water_distance(centre) \
		> WaterPlan.PLANNING_DISTANCE_LIPSCHITZ * radius \
			+ WaterPlan.PATH_INTERVAL_TOLERANCE
