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

# Direct unit tests of the join predicate with synthetic rivers — exercises
# the join OUTCOME deterministically (the geometric-convergence test above is
# vacuous on seeds where no two rivers happen to meet).

func test_join_target_hits_channel_only_when_downhill() -> void:
	var plan: WaterPlan = _plan()
	var other: RiverTrace = RiverTrace.new()
	other.source_cell = Vector2i(999, 999)
	other.priority = 1
	other.points = PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(200, 0)])
	other.widths = PackedFloat32Array([10.0, 10.0, 10.0])
	other.beds = PackedFloat32Array([5.0, 5.0, 5.0])
	# On the channel (within width) and our bed at/above theirs => join.
	assert_eq(plan._join_target(Vector2(100, 3), 6.0, [other]), other,
		"point within width and downhill joins the channel")
	# Our bed well below theirs (uphill) => no join.
	assert_null(plan._join_target(Vector2(100, 3), 4.0, [other]),
		"cannot join water whose bed is above ours (uphill)")
	# Beyond the channel width => no join.
	assert_null(plan._join_target(Vector2(100, 50), 6.0, [other]),
		"point beyond channel width does not join")

func test_join_target_hits_pond_footprint() -> void:
	var plan: WaterPlan = _plan()
	var other: RiverTrace = RiverTrace.new()
	other.source_cell = Vector2i(999, 998)
	other.priority = 1
	other.points = PackedVector2Array([Vector2(0, 0)])
	other.widths = PackedFloat32Array([10.0])
	other.beds = PackedFloat32Array([5.0])
	other.pond = PondStamp.new(Vector2(300, 300), 60.0, 4242, 2, 3.5)
	# pond.surface_y() = 2*4 - SURFACE_DROP(1) = 7. Inside footprint + bed>=7 => join.
	assert_eq(plan._join_target(Vector2(300, 300), 8.0, [other]), other,
		"point inside pond footprint and downhill joins")
	assert_null(plan._join_target(Vector2(300, 300), 6.0, [other]),
		"pond surface above our bed does not accept the join")

# ------------------------------------------------------------
# Carve field — window-independent, spawn-dry, lowers toward beds
# ------------------------------------------------------------

func test_carve_zero_in_spawn_disk() -> void:
	var plan: WaterPlan = _plan()
	for cell in [Vector2i(0, 0), Vector2i(3, -2), Vector2i(-5, 5)]:
		assert_eq(plan.carve_at_cell(cell.x, cell.y), 0.0, "spawn cell %s dry" % cell)

func test_carve_positive_under_a_terminal_pond() -> void:
	var plan: WaterPlan = _plan()
	var pond: PondStamp = null
	for sz in range(-4, 5):
		for sx in range(-4, 5):
			var t: RiverTrace = plan.river_for(Vector2i(sx, sz))
			if t != null and t.pond != null:
				pond = t.pond
				break
		if pond != null:
			break
	assert_not_null(pond, "window contains a terminal pond")
	var cx: int = roundi(pond.center.x / WaterPlan.TILE)
	var cz: int = roundi(pond.center.y / WaterPlan.TILE)
	var carve: float = plan.carve_at_cell(cx, cz)
	var ground: float = plan.noise_h(Vector2(cx * WaterPlan.TILE, cz * WaterPlan.TILE))
	# The trace ends at the pond centre, so the river's inlet trench (down to
	# bed - CHANNEL_DEPTH, floored at BED_MIN) may legitimately cut DEEPER than
	# the bowl bed — like a river inlet through a lakebed. The invariants: the
	# centre is carved at least bowl-deep, and never below the global bed floor.
	assert_true(ground - carve <= pond.bed_y() + 0.5,
		"pond centre cell carved at least to the bowl bed")
	assert_true(ground - carve >= WaterPlan.BED_MIN - 0.5,
		"carve never undershoots the global bed floor")

func test_carve_identical_across_instances_and_query_order() -> void:
	var a: WaterPlan = _plan()
	var b: WaterPlan = _plan()
	# Prime b with a far-away query first — result must not depend on history.
	b.carve_at_cell(400, 400)
	var cells: Array = [Vector2i(40, -60), Vector2i(-33, 21), Vector2i(90, 88)]
	for c in cells:
		assert_almost_eq(a.carve_at_cell(c.x, c.y), b.carve_at_cell(c.x, c.y), 0.0001,
			"carve at %s is a pure function of (seed, cell)" % c)

func test_bodies_near_finds_the_water_that_carved() -> void:
	var plan: WaterPlan = _plan()
	# Find a carved cell by scanning a band away from spawn.
	var hit: Vector2i = Vector2i.MAX
	for cz in range(20, 120):
		for cx in range(20, 120):
			if plan.carve_at_cell(cx, cz) > 0.5:
				hit = Vector2i(cx, cz)
				break
		if hit != Vector2i.MAX:
			break
	assert_true(hit != Vector2i.MAX, "found a carved cell in the scan band")
	var bodies: Dictionary = plan.bodies_near(hit, 2)
	assert_true(bodies.ponds.size() + bodies.rivers.size() > 0,
		"bodies_near sees the water that carved cell %s" % hit)

func test_bodies_near_covers_carved_cells_when_window_straddles_super_cells() -> void:
	var plan: WaterPlan = _plan()
	var radius: int = 5
	# Super-cell corners sit at cell multiples of SUPER/TILE = 32. A window
	# centered on a corner provably straddles 4 super-cells. Find one whose
	# window holds carved cells, then assert each is covered by a bodies_near
	# result — the union-across-super-cells guarantee.
	for gz in range(-3, 4):
		for gx in range(-3, 4):
			var center_cell: Vector2i = Vector2i(gx * 32, gz * 32)
			var cw: Vector2 = Vector2(center_cell.x * WaterPlan.TILE, center_cell.y * WaterPlan.TILE)
			if cw.length() < WaterPlan.SPAWN_WATER_RADIUS + 200.0:
				continue
			var carved: Array = []
			for dz in range(-radius, radius + 1):
				for dx in range(-radius, radius + 1):
					var cx: int = center_cell.x + dx
					var cz: int = center_cell.y + dz
					if plan.carve_at_cell(cx, cz) > 0.5:
						carved.append(Vector2(cx * WaterPlan.TILE, cz * WaterPlan.TILE))
			if carved.is_empty():
				continue
			var bodies: Dictionary = plan.bodies_near(center_cell, radius)
			for p in carved:
				var covered: bool = false
				for pond in bodies.ponds:
					if pond.footprint_t(p) < 1.0:
						covered = true
						break
				if not covered:
					for river in bodies.rivers:
						for i in river.points.size():
							if p.distance_to(river.points[i]) <= river.widths[i] + WaterPlan.FEATHER:
								covered = true
								break
						if covered:
							break
				assert_true(covered,
					"carved cell %s covered by a bodies_near body (corner window %s)" % [p, center_cell])
			return
	pass_test("no straddling-corner window held carved cells on this seed")

func test_sources_sit_on_hillsides() -> void:
	# Headwaters need real local slope — rivers rise out of hills, never
	# appear mid-plateau (they may still cross flat ground downstream).
	var plan: WaterPlan = _plan()
	for sc in _sources_in(plan, 6):
		assert_true(plan.grad(plan.source_pos(sc)).length() >= WaterPlan.SOURCE_MIN_SLOPE,
			"source %s rises from sloped ground" % sc)
