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
		assert_true(plan.smooth_h(p) >= WaterPlan.SOURCE_MIN_HEIGHT,
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
	# Every 12 m terrain lattice point over the footprint and its 24 m ring.
	var pitch := HeightfieldPlan.POINT
	var r_cells: int = int(ceil((pond.bound_radius() + WaterPlan.TILE) / pitch))
	var cc: Vector2i = Vector2i(roundi(pond.center.x / pitch), roundi(pond.center.y / pitch))
	for dz in range(-r_cells, r_cells + 1):
		for dx in range(-r_cells, r_cells + 1):
			var p: Vector2 = Vector2(float(cc.x + dx) * pitch, float(cc.y + dz) * pitch)
			if pond.footprint_t(p) <= 1.0 + WaterPlan.TILE / pond.radius:
				min_h = minf(min_h, plan.noise_h(p))
	# maxf mirrors _pond_level's floor of storey 1 (beds must stay above y=0);
	# lowland basins can floor to storey 0 and still get a level-1 pond.
	# FLOOR semantics: the level itself never exceeds the raw ring minimum, so
	# the surface (level*4 - 1) sits at least a metre under the lowest bank.
	assert_true(float(pond.level) * 4.0 <= maxf(min_h, 4.0) + 0.0001,
		"pond bank storey never exceeds the footprint∪ring minimum (or the storey-1 floor)")

func test_channel_water_is_contained_by_both_banks() -> void:
	# Owner: "cut deep enough such that after we convert the heightmap to
	# tiles, there is a channel for the water that is bounded on both sides."
	# CONTAIN_DROP caps every bed a full storey below the lowest flanking
	# bank's natural storey, so the water surface always sits well under both
	# bank tops — never a sheet hanging off a hillside or cliff lip. Skips
	# pond-backwater samples (the pond's own ring-minimum rule bounds those)
	# and world-floor banks (BED_MIN forbids cutting deeper in lowlands).
	var plan: WaterPlan = _plan()
	var checked: int = 0
	for sz in range(-3, 4):
		for sx in range(-3, 4):
			var t: RiverTrace = plan.river_for(Vector2i(sx, sz), 0)
			if t == null:
				continue
			var prof: PackedFloat32Array = WaterSurfaceBuilder.surface_profile(t)
			for i in range(1, t.points.size()):
				if t.pond != null and prof[i] <= t.pond.surface_y() + 0.001:
					continue   # backwater — pond level, pond containment rules
				var dir: Vector2 = (t.points[i] - t.points[i - 1]).normalized()
				var n: Vector2 = Vector2(-dir.y, dir.x)
				# Bank probes one 12 m terrain point apart past the feather.
				var d0: float = t.widths[i] + WaterPlan.FEATHER + HeightfieldPlan.POINT * 0.5
				var bank: float = INF
				for off in [n * d0, -n * d0, n * (d0 + HeightfieldPlan.POINT), -n * (d0 + HeightfieldPlan.POINT)]:
					bank = minf(bank, roundf(plan.noise_h(t.points[i] + off) / 4.0) * 4.0)
				if bank <= 0.0:
					continue   # storey-0 world floor — containment impossible
				checked += 1
				assert_true(prof[i] <= bank - 2.5,
					"river %s sample %d: surface %.1f under bank %.1f" % [
						t.source_cell, i, prof[i], bank])
	assert_true(checked > 0, "window has contained channel samples to check")

func test_steep_reaches_follow_contours_while_the_bed_descends() -> void:
	var plan := _plan()
	var checked := 0
	var contour_steps := 0
	for sc in _sources_in(plan, 3):
		var t := plan.river_for(sc, 0)
		for i in t.points.size() - 1:
			var g := plan.grad(t.points[i])
			if g.length() < WaterPlan.STEEP_HI:
				continue
			checked += 1
			var heading := (t.points[i + 1] - t.points[i]).normalized()
			contour_steps += int(absf(heading.dot(g.normalized())) < 0.6)
			assert_lte(t.beds[i + 1], t.beds[i], "hydraulic bed never climbs along a contour")
	assert_gt(checked, 20, "real mountain reaches exercised")
	assert_gt(float(contour_steps) / maxi(checked, 1), 0.5,
		"most mountain steps follow the hillside instead of rushing straight down")


func test_source_pool_never_overtops_its_ring() -> void:
	# Owner: rivers starting on hills had "a waterfall on all sides" — the pool
	# level ROUNDED to the nearest storey, up to half a storey above the lowest
	# rim ground, so the whole pool overtopped its banks. Floor semantics: the
	# pool surface always sits at least SURFACE_DROP under the raw ring minimum
	# (storey-1 lowland clamp aside — sources sit on high ground anyway).
	var plan: WaterPlan = _plan()
	var checked: int = 0
	for sc in _sources_in(plan, 4):
		var t: RiverTrace = plan.river_for(sc, 0)
		if t == null:
			continue
		var pool: PondStamp = t.source_pool
		var bound: float = pool.bound_radius() + WaterPlan.TILE
		# Every 12 m terrain lattice point: an odd point can be the lowest rim.
		var pitch := HeightfieldPlan.POINT
		var r_cells: int = int(ceil(bound / pitch))
		var cc: Vector2i = Vector2i(roundi(pool.center.x / pitch), roundi(pool.center.y / pitch))
		var min_h: float = INF
		for dz in range(-r_cells, r_cells + 1):
			for dx in range(-r_cells, r_cells + 1):
				var p: Vector2 = Vector2(float(cc.x + dx) * pitch, float(cc.y + dz) * pitch)
				if p.distance_to(pool.center) <= bound:
					min_h = minf(min_h, plan.noise_h(p))
		if float(pool.level) * 4.0 <= 4.0 + 0.0001:
			continue   # storey-1 clamp — not a rounding artefact
		checked += 1
		assert_true(pool.surface_y() <= min_h - 0.9,
			"pool at %s stays under its lowest rim ground (surface %.1f, ring min %.1f)" % [
				sc, pool.surface_y(), min_h])
	assert_true(checked > 0, "window has unclamped source pools to check")

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
	for t: RiverTrace in rivers:
		if not t.joined:
			continue
		# The discovery halo extends beyond the measured window. Validate the
		# actual immutable dependency set, including those outside its edges.
		var index := plan._index_neighbour_rivers(plan._neighbour_rivers(t.source_cell, WaterPlan.JOIN_DEPTH))
		assert_not_null(plan._join_target(t.points[-1], t.beds[-1], index),
			"joined tail touches lower water on a higher-priority dependency")

func test_junction_dependencies_remain_in_the_realized_network() -> void:
	var plan := _plan()
	for sc in _sources_in(plan, 2):
		var dependency := plan.river_for(sc, 1)
		var realized := plan.river_for(sc, WaterPlan.JOIN_DEPTH)
		assert_gte(realized.points.size(), dependency.points.size(),
			"a depth-one join target remains present in the final depth-two river")
		assert_eq(realized.points.slice(0, dependency.points.size()), dependency.points,
			"junction resolution keeps one immutable route, including every dependent join")


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
	var index := plan._index_neighbour_rivers([other])
	# On the channel (within width) and our bed at/above theirs => join.
	assert_eq(plan._join_target(Vector2(100, 3), 6.0, index), other,
		"point within width and downhill joins the channel")
	# Our bed well below theirs (uphill) => no join.
	assert_null(plan._join_target(Vector2(100, 3), 4.0, index),
		"cannot join water whose bed is above ours (uphill)")
	# Beyond the channel width => no join.
	assert_null(plan._join_target(Vector2(100, 50), 6.0, index),
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
	var index := plan._index_neighbour_rivers([other])
	# pond.surface_y() = 2*4 - SURFACE_DROP(1) = 7. Inside footprint + bed>=7 => join.
	assert_eq(plan._join_target(Vector2(300, 300), 8.0, index), other,
		"point inside pond footprint and downhill joins")
	assert_null(plan._join_target(Vector2(300, 300), 6.0, index),
		"pond surface above our bed does not accept the join")

# ------------------------------------------------------------
# Carve field — window-independent, spawn-dry, lowers toward beds
# ------------------------------------------------------------

func test_carve_zero_in_spawn_disk() -> void:
	var plan: WaterPlan = _plan()
	for cell in [Vector2i(0, 0), Vector2i(3, -2), Vector2i(-5, 5)]:
		assert_eq(plan.carve_at(cell.x * WaterPlan.TILE, cell.y * WaterPlan.TILE), 0.0, "spawn cell %s dry" % cell)

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
	var carve: float = plan.carve_at(cx * WaterPlan.TILE, cz * WaterPlan.TILE)
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
	b.carve_at(400 * WaterPlan.TILE, 400 * WaterPlan.TILE)
	var cells: Array = [Vector2i(40, -60), Vector2i(-33, 21), Vector2i(90, 88)]
	for c in cells:
		assert_almost_eq(a.carve_at(c.x * WaterPlan.TILE, c.y * WaterPlan.TILE), b.carve_at(c.x * WaterPlan.TILE, c.y * WaterPlan.TILE), 0.0001,
			"carve at %s is a pure function of (seed, cell)" % c)

func test_bodies_near_finds_the_water_that_carved() -> void:
	var plan: WaterPlan = _plan()
	# Find a carved cell by scanning a band away from spawn.
	var hit: Vector2i = Vector2i.MAX
	for cz in range(20, 120):
		for cx in range(20, 120):
			if plan.carve_at(cx * WaterPlan.TILE, cz * WaterPlan.TILE) > 0.5:
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
					if plan.carve_at(cx * WaterPlan.TILE, cz * WaterPlan.TILE) > 0.5:
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
							if p.distance_to(river.points[i]) <= river.widths[i] + WaterPlan.BANK_FEATHER:
								covered = true
								break
						if covered:
							break
				assert_true(covered,
					"carved cell %s covered by a bodies_near body (corner window %s)" % [p, center_cell])
			return
	pass_test("no straddling-corner window held carved cells on this seed")

func test_sources_sit_at_local_peaks() -> void:
	# Sources gradient-ascend to a summit: near-zero local gradient, a
	# prominent ring (real hill/mountain, not plateau), and no ring sample
	# meaningfully higher than the source itself.
	var plan: WaterPlan = _plan()
	var checked: int = 0
	for sc in _sources_in(plan, 6):
		checked += 1
		var p: Vector2 = plan.source_pos(sc)
		assert_true(plan.grad(p).length() < WaterPlan.SOURCE_PEAK_EPS,
			"source %s gradient ~0 (summit)" % sc)
		assert_true(plan._ring_prominence(p) >= WaterPlan.PROMINENCE_MIN,
			"source %s ring is prominent (not plateau)" % sc)
		for i in 8:
			var q: Vector2 = p + Vector2.from_angle(TAU * float(i) / 8.0) * 24.0
			assert_true(plan.smooth_h(q) <= plan.smooth_h(p) + 0.75,
				"source %s is a local top (ring sample %d not above it)" % [sc, i])
	assert_true(checked > 0, "window contains sources to check")

func test_source_pos_is_cached_and_pure() -> void:
	var a: WaterPlan = _plan()
	var b: WaterPlan = _plan()
	for sc in [Vector2i(2, 3), Vector2i(-4, 1), Vector2i(5, -5)]:
		assert_eq(a.source_pos(sc), b.source_pos(sc), "ascent is a pure function of (seed, cell)")
		assert_eq(a.source_pos(sc), a.source_pos(sc), "cache returns the same point")

# The lazy-gated carve must equal the exhaustive reference for every cell —
# gated-out terms all contribute exactly 0. Sweeps a band far enough out to
# cross rivers/ponds for this seed; the wet-count guard keeps the sweep honest.
func test_carve_lazy_gates_match_reference():
	var w := WaterPlan.new(991177, 22.0, 8)
	var checked := 0
	var wet := 0
	for cz in range(-90, 91, 3):
		for cx in range(-90, 91, 3):
			var expect := _carve_reference(w, cx, cz)
			var got: float = w.carve_at(cx * WaterPlan.TILE, cz * WaterPlan.TILE)
			assert_almost_eq(got, expect, 0.0001, "cell (%d,%d)" % [cx, cz])
			checked += 1
			if expect > 0.05:
				wet += 1
	assert_gt(wet, 5, "sweep found only %d/%d carved cells - widen it or change seed" % [wet, checked])

# Exhaustive reference for the lazy pond/channel gates. Channel samples are
# only the bucket acceleration structure; the hydraulic footprint is the
# continuous variable-width segment between samples, matching WaterField.
func _carve_reference(w: WaterPlan, cx: int, cz: int) -> float:
	var p := Vector2(float(cx) * WaterPlan.TILE, float(cz) * WaterPlan.TILE)
	if p.length() < WaterPlan.SPAWN_WATER_RADIUS:
		return 0.0
	var rc := Vector2i(int(floor(p.x / WaterPlan.SUPER)), int(floor(p.y / WaterPlan.SUPER)))
	var region: Dictionary = w._region_for(rc)
	var ground: float = w.noise_h(p)
	var best := 0.0
	for t in region.rivers:
		if t.source_pool != null:
			best = maxf(best, t.source_pool.carve_at(p, ground))
		if t.pond != null:
			best = maxf(best, t.pond.carve_at(p, ground))
	var key := Vector2i(cx, cz)
	if region.buckets.has(key):
		var seen_segments: Dictionary = {}
		for entry in region.buckets[key]:
			var t: RiverTrace = entry[0]
			var i: int = entry[1]
			for si in [i - 1, i]:
				if si < 0 or si + 1 >= t.points.size():
					continue
				var segment_key := Vector3i(t.source_cell.x, t.source_cell.y, si)
				if seen_segments.has(segment_key):
					continue
				seen_segments[segment_key] = true
				var a: Vector2 = t.points[si]
				var b: Vector2 = t.points[si + 1]
				var ab: Vector2 = b - a
				var len2: float = ab.length_squared()
				var along: float = clampf((p - a).dot(ab) / len2, 0.0, 1.0) \
					if len2 > 0.000001 else 0.0
				var nearest: Vector2 = a + ab * along
				var width: float = lerpf(t.widths[si], t.widths[si + 1], along)
				var d: float = p.distance_to(nearest)
				var infl: float = width + WaterPlan.BANK_FEATHER
				if d >= infl:
					continue
				var grade: float = absf(t.beds[si + 1] - t.beds[si]) \
					/ maxf(sqrt(len2), 0.001)
				var extra: float = WaterPlan.CARVE_BED_EXTRA \
					if grade < WaterPlan.CARVE_EXTRA_MAX_GRADE else 0.0
				var bed: float = lerpf(t.beds[si], t.beds[si + 1], along)
				var carve_bed: float = maxf(bed - extra, WaterPlan.BED_MIN)
				var target := carve_bed if d <= width else lerpf(
					bed + WaterField.SURFACE_RIDE + 0.5, ground,
					(d - width) / WaterPlan.BANK_FEATHER)
				var weights := w.bank_strengths(t)
				var strength := lerpf(weights[si], weights[si+1], along)
				var original_weight := SlopeProfile.smootherstep(clampf(
					(width+WaterPlan.CARVE_FEATHER-d)/WaterPlan.CARVE_FEATHER,0,1))
				var original_carve := maxf(0.0,ground-carve_bed)*original_weight
				best = maxf(best,lerpf(original_carve,maxf(0.0,ground-target),strength))
	return best


# ------------------------------------------------------------
# carve_at(x, z): pure in position, valid at every 12 m lattice point
# ------------------------------------------------------------

func test_carve_at_is_zero_in_the_spawn_disk_at_odd_points() -> void:
	var plan: WaterPlan = _plan()
	for p in [Vector2(12, 12), Vector2(-36, 60), Vector2(132, -12)]:
		assert_eq(plan.carve_at(p.x, p.y), 0.0, "spawn point %s dry" % p)

func test_carve_at_is_pure_in_position_across_instances_and_order() -> void:
	var a: WaterPlan = _plan()
	var b: WaterPlan = _plan()
	b.carve_at(9600.0, -9600.0)  # prime b with a far region first
	for p in [Vector2(12 * 41, -12 * 55), Vector2(-12 * 33, 12 * 21), Vector2(12 * 181, 12 * 177),
			Vector2(768.0 - 12.0, 768.0 - 12.0), Vector2(-768.0 + 12.0, 768.0 + 12.0)]:
		assert_almost_eq(a.carve_at(p.x, p.y), b.carve_at(p.x, p.y), 0.0001,
			"carve at %s is a pure function of (seed, position)" % p)

# The bucket index must not hide water from 12 m lattice points: odd points and
# points on a 24 m cell border (x = 24 c + 12), including the 12 m strip at a
# super-cell edge (which belongs to the neighbouring super-cell's last point
# but to THIS super-cell's first cell), must equal a brute-force evaluation over
# every river/pond of the owning region.
func test_carve_at_twelve_metre_points_match_bruteforce_reference() -> void:
	var w := WaterPlan.new(991177, 22.0, 8)
	var wet := 0
	var border := 0
	var checked := 0
	for j in range(-150, 151, 2):
		for i in range(-150, 151, 2):
			# (i, j) are 12 m point indices; stepping by 2 alternates the
			# sweep origin so odd points are hit by the +1 offsets below.
			for off in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				var pt: Vector2i = Vector2i(i, j) + off
				var p := Vector2(pt) * HeightfieldPlan.POINT
				var expect := _carve_bruteforce(w, p)
				assert_almost_eq(w.carve_at(p.x, p.y), expect, 0.0001, "point %s" % pt)
				checked += 1
				if expect > 0.05:
					wet += 1
					if posmod(pt.x, 2) == 1 or posmod(pt.y, 2) == 1:
						border += 1
	assert_gt(wet, 50, "sweep found only %d/%d carved points" % [wet, checked])
	assert_gt(border, 20, "sweep found only %d carved odd/border points" % border)

func _carve_bruteforce(w: WaterPlan, p: Vector2) -> float:
	if p.length() < WaterPlan.SPAWN_WATER_RADIUS:
		return 0.0
	var cx := floori(p.x / WaterPlan.TILE + 0.5)
	var cz := floori(p.y / WaterPlan.TILE + 0.5)
	var per := int(WaterPlan.SUPER / WaterPlan.TILE)
	var region: Dictionary = w._region_for(Vector2i(floori(float(cx) / per), floori(float(cz) / per)))
	var ground: float = w.noise_h(p)
	var best := 0.0
	for t: RiverTrace in region.rivers:
		if t.source_pool != null:
			best = maxf(best, t.source_pool.carve_at(p, ground))
		if t.pond != null:
			best = maxf(best, t.pond.carve_at(p, ground))
		for si in t.points.size() - 1:
			var a: Vector2 = t.points[si]
			var ab: Vector2 = t.points[si + 1] - a
			var len2: float = ab.length_squared()
			var along: float = clampf((p - a).dot(ab) / len2, 0.0, 1.0) if len2 > 0.000001 else 0.0
			var width: float = lerpf(t.widths[si], t.widths[si + 1], along)
			var d: float = p.distance_to(a + ab * along)
			if d >= width + WaterPlan.BANK_FEATHER:
				continue
			var grade: float = absf(t.beds[si + 1] - t.beds[si]) / maxf(sqrt(len2), 0.001)
			var extra: float = WaterPlan.CARVE_BED_EXTRA if grade < WaterPlan.CARVE_EXTRA_MAX_GRADE else 0.0
			var bed: float = lerpf(t.beds[si], t.beds[si + 1], along)
			var carve_bed: float = maxf(bed - extra, WaterPlan.BED_MIN)
			var target := carve_bed
			if d > width:
				target = lerpf(bed + WaterField.SURFACE_RIDE + 0.5, ground,
					(d - width) / WaterPlan.BANK_FEATHER)
			var weights := w.bank_strengths(t)
			var strength := lerpf(weights[si], weights[si + 1], along)
			var original_weight := SlopeProfile.smootherstep(clampf(
				(width + WaterPlan.CARVE_FEATHER - d) / WaterPlan.CARVE_FEATHER, 0, 1))
			var original_carve := maxf(0.0, ground - carve_bed) * original_weight
			var carve := lerpf(original_carve, maxf(0.0, ground - target), strength)
			var crest := ceilf((bed + WaterField.SURFACE_RIDE + .75) / WaterPlan.STOREY) * WaterPlan.STOREY
			var bar_carve := maxf(0.0, ground - crest)
			best = maxf(best, lerpf(carve, minf(carve, bar_carve), t.retained_ground_weight(p)))
	return best
