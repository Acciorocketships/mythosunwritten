extends GutTest

# ------------------------------------------------------------
# WaterPlan — deterministic river-network plan
# ------------------------------------------------------------

const SEED := 991177

func _plan() -> WaterPlan:
	return WaterPlan.new(SEED, 22.0, 8)

## Scan a super-cell window for cells that have a source. Returns Array[Vector2i].
func _sources_in(plan: WaterPlan, r: int) -> Array:
	var out: Array = []
	for sz in range(-r, r + 1):
		for sx in range(-r, r + 1):
			var sc: Vector2i = Vector2i(sx, sz)
			if plan.has_source(sc):
				out.append(sc)
	return out

func test_sources_deterministic_across_instances() -> void:
	var a: Array = _sources_in(_plan(), 6)
	var b: Array = _sources_in(_plan(), 6)
	assert_eq(a, b, "same seed => identical source set")
	assert_true(a.size() > 0, "a 13x13 super-cell window (10km) contains at least one source")

func test_sources_sit_on_high_smooth_ground() -> void:
	var plan: WaterPlan = _plan()
	for sc in _sources_in(plan, 6):
		var p: Vector2 = plan.source_pos(sc)
		assert_true(plan.smooth01(p) >= WaterPlan.SOURCE_MIN01,
			"source %s at %s is on high ground" % [sc, p])

func test_no_source_inside_spawn_ring() -> void:
	var plan: WaterPlan = _plan()
	for sc in _sources_in(plan, 6):
		assert_true(plan.source_pos(sc).length() >= WaterPlan.SPAWN_WATER_RADIUS,
			"sources keep out of the spawn disk")

# ------------------------------------------------------------
# Tracing — monotone beds, bounded length, guaranteed terminal water
# ------------------------------------------------------------

## First super-cell with a source, scanning outward — the shared test subject.
func _first_source(plan: WaterPlan) -> Vector2i:
	for r in range(0, 10):
		for sz in range(-r, r + 1):
			for sx in range(-r, r + 1):
				if maxi(absi(sx), absi(sz)) != r:
					continue
				if plan.has_source(Vector2i(sx, sz)):
					return Vector2i(sx, sz)
	assert_true(false, "no source found within 10 super-cell rings")
	return Vector2i.ZERO

func test_trace_is_deterministic_across_instances() -> void:
	var sc_a: Vector2i = _first_source(_plan())
	var a: RiverTrace = _plan().river_for(sc_a, 0)
	var b: RiverTrace = _plan().river_for(sc_a, 0)
	assert_eq(a.points, b.points, "identical polyline across instances")
	assert_eq(a.beds, b.beds, "identical beds across instances")

func test_trace_bed_is_monotone_nonincreasing() -> void:
	var plan: WaterPlan = _plan()
	var t: RiverTrace = plan.river_for(_first_source(plan), 0)
	for i in range(1, t.beds.size()):
		assert_true(t.beds[i] <= t.beds[i - 1] + 0.0001,
			"bed never rises (i=%d: %f -> %f)" % [i, t.beds[i - 1], t.beds[i]])

func test_trace_is_bounded_and_ends_in_water() -> void:
	var plan: WaterPlan = _plan()
	var t: RiverTrace = plan.river_for(_first_source(plan), 0)
	assert_true(t.points.size() >= 2, "trace has at least two samples")
	assert_true(t.points.size() <= WaterPlan.MAX_STEPS, "trace respects MAX_STEPS")
	assert_not_null(t.source_pool, "every river starts with a source pool")
	assert_true(t.joined or t.pond != null, "every river ends in water")

func test_trace_widths_grow_downstream() -> void:
	var plan: WaterPlan = _plan()
	var t: RiverTrace = plan.river_for(_first_source(plan), 0)
	assert_true(t.widths[t.widths.size() - 1] >= t.widths[0],
		"ribbon widens downstream")

func test_pond_level_at_or_below_ring_minimum() -> void:
	var plan: WaterPlan = _plan()
	var t: RiverTrace = plan.river_for(_first_source(plan), 0)
	if t.pond == null:
		pass_test("river joined; pond rule untestable on this seed cell")
		return
	var pond: PondStamp = t.pond
	var min_h: float = INF
	var r_cells: int = int(ceil((pond.bound_radius() + WaterPlan.TILE) / WaterPlan.TILE))
	var cc: Vector2i = Vector2i(roundi(pond.center.x / WaterPlan.TILE), roundi(pond.center.y / WaterPlan.TILE))
	for dz in range(-r_cells, r_cells + 1):
		for dx in range(-r_cells, r_cells + 1):
			var p: Vector2 = Vector2(float(cc.x + dx) * WaterPlan.TILE, float(cc.y + dz) * WaterPlan.TILE)
			if pond.footprint_t(p) <= 1.0 + WaterPlan.TILE / pond.radius:
				min_h = minf(min_h, plan.noise_h(p))
	assert_true(float(pond.level) * 4.0 <= roundi(min_h / 4.0) * 4.0 + 0.0001,
		"pond bank storey never exceeds the footprint∪ring minimum")

func test_trace_never_enters_spawn_disk() -> void:
	var plan: WaterPlan = _plan()
	var t: RiverTrace = plan.river_for(_first_source(plan), 0)
	for p in t.points:
		assert_true(p.length() >= WaterPlan.SPAWN_WATER_RADIUS - 0.001,
			"polyline stays out of the spawn disk")

# ------------------------------------------------------------
# Junctions — strict priority, bounded depth, joins land in real water
# ------------------------------------------------------------

func _all_rivers(plan: WaterPlan, r: int) -> Array:
	var out: Array = []
	for sz in range(-r, r + 1):
		for sx in range(-r, r + 1):
			var t: RiverTrace = plan.river_for(Vector2i(sx, sz))
			if t != null:
				out.append(t)
	return out

func test_full_depth_rivers_deterministic_across_instances() -> void:
	var a: Array = _all_rivers(_plan(), 4)
	var b: Array = _all_rivers(_plan(), 4)
	assert_eq(a.size(), b.size(), "same river count")
	for i in a.size():
		assert_eq(a[i].points, b[i].points, "river %d identical polyline" % i)
		assert_eq(a[i].joined, b[i].joined, "river %d identical join outcome" % i)

func test_joined_rivers_touch_higher_priority_water() -> void:
	var plan: WaterPlan = _plan()
	var rivers: Array = _all_rivers(plan, 4)
	var by_cell: Dictionary = {}
	for t in rivers:
		by_cell[t.source_cell] = t
	for t in rivers:
		if not t.joined:
			continue
		var tail: Vector2 = t.points[t.points.size() - 1]
		var found: bool = false
		for other in rivers:
			if other.priority <= t.priority:
				continue
			# tail must lie inside the other's channel or a pond footprint
			if other.source_pool != null and other.source_pool.footprint_t(tail) < 1.2:
				found = true
			if other.pond != null and other.pond.footprint_t(tail) < 1.2:
				found = true
			for i in other.points.size():
				if tail.distance_to(other.points[i]) <= other.widths[i] + WaterPlan.FEATHER:
					found = true
					break
			if found:
				break
		assert_true(found, "joined river %s tail sits in higher-priority water" % t.source_cell)

func test_every_river_still_ends_in_water_at_full_depth() -> void:
	for t in _all_rivers(_plan(), 4):
		assert_true(t.joined or t.pond != null, "river %s ends in water" % t.source_cell)
