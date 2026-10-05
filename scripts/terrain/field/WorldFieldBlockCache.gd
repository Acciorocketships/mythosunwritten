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
# Miss-only timings reveal field work hidden inside feature/route queries.
var region_build_usec := 0
var water_build_usec := 0
## Optional worker-side observer. Reports complete misses, including misses
## hidden inside road/village planning. Never exposes a live cache value.
var profile_callback := Callable()

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

## Whether this cache was built over these fields. Its blocks' regions and
## water levels are then the ones any cache over them builds: the query
## margin and shore limit set only a context's coverage (always its whole
## block) and its shore curves, never its levels (WaterFieldContext.build).
func serves(plan: HeightfieldPlan, water_plan: WaterPlan) -> bool:
	return _plan == plan and _water_plan == water_plan

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
	var spacing := HeightfieldPlan.POINT
	var centre := Vector2i(roundi(world_rect.get_center().x / spacing),
		roundi(world_rect.get_center().y / spacing))
	var half_points := ceili(maxf(world_rect.size.x, world_rect.size.y) \
		* 0.5 / spacing) + 2
	var expanded := _plan.compute_region(centre.x, centre.y, half_points)
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
	# The block owns points 16 k .. 16 k + 15; the region keeps a 96 m
	# (eight point) margin around them for the clamp, walls and dressing.
	var points := TerrainChunkMesher.POINTS_PER_CHUNK
	var centre := key * points + Vector2i.ONE * (points / 2)
	var started := Time.get_ticks_usec()
	if profile_callback.is_valid(): profile_callback.call(&"begin", &"region", key, 0)
	entry.region = _plan.compute_region(centre.x, centre.y, points)
	var elapsed := Time.get_ticks_usec() - started
	region_build_usec += elapsed
	if profile_callback.is_valid(): profile_callback.call(&"end", &"region", key, elapsed)
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
	var started := Time.get_ticks_usec()
	if profile_callback.is_valid(): profile_callback.call(&"begin", &"water", key, 0)
	entry.water = WaterFieldContext.build(_water_plan, core.grow(_query_margin),
		block_region, _shore_limit)
	var elapsed := Time.get_ticks_usec() - started
	water_build_usec += elapsed
	if profile_callback.is_valid(): profile_callback.call(&"end", &"water", key, elapsed)
	water_build_count += 1
	_touch(key, entry)
	return entry.water

## A read-only copy holding just these blocks' regions and water, for work
## that runs off the planning thread (parallel chunk tails): the shared cache
## keeps building and evicting on the planning thread, the view never changes.
## A query outside `keys` is a bug in the caller's halo; it is reported and
## then computed (which touches the plans' own caches).
func frozen_view(keys: Array[Vector2i]) -> WorldFieldBlockCache:
	var view := WorldFieldBlockCache.new(_plan, _water_plan, _query_margin,
		_shore_limit, maxi(keys.size(), 1))
	for key: Vector2i in keys:
		view._entries[key] = {"region": region(key), "water": water(key), "stamp": 0}
	view._frozen = true
	return view

var _frozen := false

func has_region(key: Vector2i) -> bool:
	return _entries.has(key) and _entries[key].region != null

func has_water(key: Vector2i) -> bool:
	return _entries.has(key) and _entries[key].water != null

func size() -> int:
	return _entries.size()

func stats() -> Dictionary:
	return {"region_builds": region_build_count, "water_builds": water_build_count,
		"region_hits": region_hit_count, "water_hits": water_hit_count,
		"evictions": eviction_count, "entries": _entries.size(),
		"region_build_usec": region_build_usec, "water_build_usec": water_build_usec}

func clear() -> void:
	_entries.clear()

func _entry(key: Vector2i) -> Dictionary:
	if not _entries.has(key):
		if _frozen:
			push_error("WorldFieldBlockCache frozen view missed block %s" % key)
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
	# A 12 m tile depends only on its four corner points, so a rectangle reads
	# the tile corners floor(x0 / 12) .. floor(x1 / 12) + 1. Prove that complete
	# read set instead of relying on HeightfieldRegion's zero default outside
	# its coverage.
	var spacing := HeightfieldPlan.POINT
	var minimum := Vector2i(floori(world_rect.position.x / spacing),
		floori(world_rect.position.y / spacing))
	var maximum := Vector2i(floori(world_rect.end.x / spacing) + 1,
		floori(world_rect.end.y / spacing) + 1)
	return region_value.has_surface_point(minimum.x, minimum.y) \
		and region_value.has_surface_point(maximum.x, minimum.y) \
		and region_value.has_surface_point(minimum.x, maximum.y) \
		and region_value.has_surface_point(maximum.x, maximum.y)
