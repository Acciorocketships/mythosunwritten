class_name WorldFieldBlockCache
extends RefCounted

const BLOCK_WORLD := TerrainChunkMesher.CHUNK_WORLD

var _plan: HeightfieldPlan
var _water_plan: WaterPlan
var _query_margin: float
var _shore_limit: float
var _capacity: int
var _entries: Dictionary = {}
var _clock := 0

var region_build_count := 0
var water_build_count := 0
var region_hit_count := 0
var water_hit_count := 0
var eviction_count := 0

func _init(plan: HeightfieldPlan, water_plan: WaterPlan, query_margin: float,
		shore_limit: float, capacity := PathProgram.FIELD_CACHE_CAP) -> void:
	assert(plan != null and water_plan != null and capacity > 0)
	assert(is_finite(query_margin) and query_margin >= 0.0)
	assert(is_finite(shore_limit) and shore_limit >= 0.0)
	assert(query_margin + shore_limit <= WaterField.FILL_MARGIN * WaterField.FILL_STEP
		- WaterContour.MARGIN)
	_plan = plan
	_water_plan = water_plan
	_query_margin = query_margin
	_shore_limit = shore_limit
	_capacity = capacity

static func key_of(world_xz: Vector2) -> Vector2i:
	return Vector2i(int(floor(world_xz.x / BLOCK_WORLD)),
		int(floor(world_xz.y / BLOCK_WORLD)))

func region_at(world_xz: Vector2) -> HeightfieldRegion:
	return region(key_of(world_xz))


func region_covering(world_rect: Rect2) -> HeightfieldRegion:
	assert(world_rect.position.is_finite() and world_rect.size.is_finite())
	assert(world_rect.size.x >= 0.0 and world_rect.size.y >= 0.0)
	var cached := region_at(world_rect.get_center())
	if _region_covers_surface_rect(cached, world_rect):
		return cached
	var centre_cell := Vector2i(roundi(world_rect.get_center().x \
		/ TerrainSurfaceField.TILE), roundi(world_rect.get_center().y \
		/ TerrainSurfaceField.TILE))
	var half_cells := ceili(maxf(world_rect.size.x, world_rect.size.y) \
		* 0.5 / TerrainSurfaceField.TILE) + 2
	var expanded := _plan.compute_region(centre_cell.x, centre_cell.y,
		half_cells)
	assert(_region_covers_surface_rect(expanded, world_rect),
		"Explicit field region does not cover its requested surface rectangle")
	return expanded

func water_at(world_xz: Vector2) -> WaterFieldContext:
	return water(key_of(world_xz))


func planning_water_distance(world_xz: Vector2) -> float:
	return _water_plan.planning_signed_distance(world_xz)

func region(key: Vector2i) -> HeightfieldRegion:
	var entry := _entry(key)
	if entry.region != null:
		region_hit_count += 1
		_touch(key, entry)
		return entry.region
	var centre := key * TerrainChunkMesher.CELLS_PER_CHUNK \
		+ Vector2i.ONE * (TerrainChunkMesher.CELLS_PER_CHUNK / 2)
	entry.region = _plan.compute_region(centre.x, centre.y,
		TerrainChunkMesher.CELLS_PER_CHUNK)
	region_build_count += 1
	_touch(key, entry)
	return entry.region

func water(key: Vector2i) -> WaterFieldContext:
	var entry := _entry(key)
	if entry.water != null:
		water_hit_count += 1
		_touch(key, entry)
		return entry.water
	var block_region := region(key)
	entry = _entries[key]
	var core := Rect2(Vector2(key) * BLOCK_WORLD, Vector2.ONE * BLOCK_WORLD)
	entry.water = WaterFieldContext.build(_water_plan, core.grow(_query_margin),
		block_region, _shore_limit)
	water_build_count += 1
	_touch(key, entry)
	return entry.water

func has_region(key: Vector2i) -> bool:
	return _entries.has(key) and _entries[key].region != null

func has_water(key: Vector2i) -> bool:
	return _entries.has(key) and _entries[key].water != null

func size() -> int:
	return _entries.size()

func stats() -> Dictionary:
	return {"region_builds": region_build_count, "water_builds": water_build_count,
		"region_hits": region_hit_count, "water_hits": water_hit_count,
		"evictions": eviction_count, "entries": _entries.size()}

func clear() -> void:
	_entries.clear()

func _entry(key: Vector2i) -> Dictionary:
	if not _entries.has(key):
		_evict_if_full()
		_entries[key] = {"region": null, "water": null, "stamp": 0}
	return _entries[key]

func _touch(key: Vector2i, entry: Dictionary) -> void:
	_clock += 1
	entry.stamp = _clock
	_entries[key] = entry

func _evict_if_full() -> void:
	if _entries.size() < _capacity:
		return
	var victim: Vector2i
	var victim_stamp := 0
	var found := false
	for key: Vector2i in _entries:
		var stamp: int = _entries[key].stamp
		if not found or stamp < victim_stamp or (stamp == victim_stamp and _key_less(key, victim)):
			victim = key
			victim_stamp = stamp
			found = true
	_entries.erase(victim)
	eviction_count += 1

static func _key_less(a: Vector2i, b: Vector2i) -> bool:
	return a.x < b.x or (a.x == b.x and a.y < b.y)


static func _region_covers_surface_rect(region_value: HeightfieldRegion,
		world_rect: Rect2) -> bool:
	# height_bounds() bakes every intersected patch; each bake reads one ring of
	# cardinal/diagonal neighbours. Prove that complete read set here instead of
	# relying on HeightfieldRegion's intentional zero default outside coverage.
	var minimum := Vector2i(
		ceili((world_rect.position.x - TerrainSurfaceField.HALF) \
			/ TerrainSurfaceField.TILE) - 1,
		ceili((world_rect.position.y - TerrainSurfaceField.HALF) \
			/ TerrainSurfaceField.TILE) - 1)
	var maximum := Vector2i(
		floori((world_rect.end.x + TerrainSurfaceField.HALF) \
			/ TerrainSurfaceField.TILE) + 1,
		floori((world_rect.end.y + TerrainSurfaceField.HALF) \
			/ TerrainSurfaceField.TILE) + 1)
	return region_value.has_surface_cell(minimum.x, minimum.y) \
		and region_value.has_surface_cell(maximum.x, minimum.y) \
		and region_value.has_surface_cell(minimum.x, maximum.y) \
		and region_value.has_surface_cell(maximum.x, maximum.y)
