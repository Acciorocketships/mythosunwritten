extends GutTest

const EXACT_SEED := 2697992464
const EXACT_CHUNK := Vector2i(-4, -18)

func _trace(a: Vector2, b: Vector2, wa: float, wb: float,
		source := Vector2i.ZERO) -> RiverTrace:
	var trace := RiverTrace.new()
	trace.source_cell = source
	trace.points = PackedVector2Array([a, b])
	trace.widths = PackedFloat32Array([wa, wb])
	trace.beds = PackedFloat32Array([0.0, 0.0])
	return trace

func _fixture(rivers: Array, ponds: Array) -> WaterPlan:
	var water := WaterPlan.new(77, 22.0, 8)
	var region := {"rivers": rivers, "buckets": {}, "ponds": ponds}
	for z in range(-2, 3):
		for x in range(-2, 3):
			water._region_cache[Vector2i(x, z)] = region
	return water

func _world_interval(interval: Vector2, a: Vector2, b: Vector2) -> PackedVector2Array:
	return PackedVector2Array([a.lerp(b, interval.x), a.lerp(b, interval.y)])

func _mapped_reverse(intervals: Array[Vector2]) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i in range(intervals.size() - 1, -1, -1):
		out.append(Vector2(1.0 - intervals[i].y, 1.0 - intervals[i].x))
	return out

func _assert_intervals_close(actual: Array[Vector2], expected: Array[Vector2],
		tolerance := 0.001) -> void:
	assert_eq(actual.size(), expected.size())
	for i in mini(actual.size(), expected.size()):
		assert_almost_eq(actual[i].x, expected[i].x, tolerance)
		assert_almost_eq(actual[i].y, expected[i].y, tolerance)

func test_river_capsule_crossings_and_guarded_distance() -> void:
	var trace := _trace(Vector2(-100.0, 0.0), Vector2(100.0, 0.0), 10.0, 10.0)
	var water := _fixture([trace], [])
	var a := Vector2(0.0, -40.0)
	var b := Vector2(0.0, 40.0)
	var intervals := water.planning_intervals(a, b)
	assert_eq(intervals.size(), 1)
	var world := _world_interval(intervals[0], a, b)
	assert_almost_eq(world[0].y, -16.0, 0.12)
	assert_almost_eq(world[1].y, 16.0, 0.12)
	assert_lte(water.planning_signed_distance(Vector2(0.0, 16.0)), 0.001)
	assert_gt(water.planning_signed_distance(Vector2(0.0, 17.0)), 0.9)

	var oblique := water.planning_intervals(Vector2(-40.0, -40.0), Vector2(40.0, 40.0))
	assert_eq(oblique.size(), 1)
	assert_true(oblique[0].x < 0.5 and oblique[0].y > 0.5)

	# The guarded round cap is touched at exactly one world point. The fixed
	# refinement tolerance may conservatively retain a tiny interval around it.
	var tangent_a := Vector2(116.0, -40.0)
	var tangent_b := Vector2(116.0, 40.0)
	var tangent := water.planning_intervals(tangent_a, tangent_b)
	assert_eq(tangent.size(), 1)
	var tangent_world := _world_interval(tangent[0], tangent_a, tangent_b)
	assert_lt(tangent_world[0].distance_to(tangent_world[1]), 0.2)
	assert_almost_eq((tangent_world[0].y + tangent_world[1].y) * 0.5, 0.0, 0.1)

func test_variable_width_and_segment_end_crossings() -> void:
	var trace := _trace(Vector2(-100.0, 0.0), Vector2(100.0, 0.0), 9.0, 15.0)
	var water := _fixture([trace], [])
	var left := water.planning_intervals(Vector2(-80.0, -40.0), Vector2(-80.0, 40.0))[0]
	var right := water.planning_intervals(Vector2(80.0, -40.0), Vector2(80.0, 40.0))[0]
	assert_gt(right.y - right.x, left.y - left.x)

	var end_a := Vector2(108.0, -40.0)
	var end_b := Vector2(108.0, 40.0)
	var end_crossing := water.planning_intervals(end_a, end_b)
	assert_eq(end_crossing.size(), 1)
	assert_true(end_crossing[0].x < 0.5 and end_crossing[0].y > 0.5)

func test_pond_centre_oblique_tangent_and_miss() -> void:
	var pond := PondStamp.new(Vector2.ZERO, 60.0, 991, 1, 3.5)
	var water := _fixture([], [pond])
	for direction in [Vector2.RIGHT, Vector2(1.0, 0.7).normalized()]:
		var intervals := water.planning_intervals(-direction * 120.0, direction * 120.0)
		assert_eq(intervals.size(), 1)
		assert_true(intervals[0].x < 0.5 and intervals[0].y > 0.5)

	var tangent_point := Vector2.ZERO
	for i in 4096:
		var angle := TAU * float(i) / 4096.0
		var point := Vector2.from_angle(angle) * (pond.radius_at(angle)
			+ WaterPlan.PATH_WATER_GUARD)
		if point.y > tangent_point.y:
			tangent_point = point
	var tangent := water.planning_intervals(
		tangent_point + Vector2(-120.0, 0.0), tangent_point + Vector2(120.0, 0.0))
	assert_eq(tangent.size(), 1)
	var tangent_world := _world_interval(tangent[0],
		tangent_point + Vector2(-120.0, 0.0), tangent_point + Vector2(120.0, 0.0))
	assert_lt(tangent_world[0].distance_to(tangent_world[1]), 0.3)
	assert_true(water.planning_intervals(Vector2(-120.0, 120.0), Vector2(120.0, 120.0)).is_empty())

func test_multiple_intervals_merge_and_reverse_canonically() -> void:
	var lower := _trace(Vector2(-100.0, -30.0), Vector2(100.0, -30.0),
		9.0, 9.0, Vector2i(1, 0))
	var upper := _trace(Vector2(-100.0, 30.0), Vector2(100.0, 30.0),
		9.0, 9.0, Vector2i(2, 0))
	var a := Vector2(0.0, -80.0)
	var b := Vector2(0.0, 80.0)
	var forward := _fixture([upper, lower], []).planning_intervals(a, b)
	var reordered := _fixture([lower, upper], []).planning_intervals(a, b)
	assert_eq(forward.size(), 2)
	_assert_intervals_close(reordered, forward)
	var reverse := _fixture([lower, upper], []).planning_intervals(b, a)
	_assert_intervals_close(_mapped_reverse(reverse), forward)

	# Touching guarded footprints coalesce instead of exposing a zero-width gap.
	upper.points = PackedVector2Array([Vector2(-100.0, 0.0), Vector2(100.0, 0.0)])
	var merged := _fixture([lower, upper], []).planning_intervals(a, b)
	assert_eq(merged.size(), 1)

func test_super_cell_ownership_is_identical_on_both_sides() -> void:
	var water := WaterPlan.new(77, 22.0, 8)
	for boundary in [-WaterPlan.SUPER, WaterPlan.SUPER]:
		var trace := _trace(Vector2(boundary, -60.0), Vector2(boundary, 60.0),
			9.0, 9.0, Vector2i(int(boundary), 0))
		var region := {"rivers": [trace], "buckets": {}, "ponds": []}
		var owner := int(floor(boundary / WaterPlan.SUPER))
		water._region_cache[Vector2i(owner - 1, 0)] = region
		water._region_cache[Vector2i(owner, 0)] = region
		assert_almost_eq(water.planning_signed_distance(Vector2(boundary - 0.1, 0.0)),
			water.planning_signed_distance(Vector2(boundary + 0.1, 0.0)), 0.0001)

func test_exact_intervals_use_zero_limit_context_curves_and_reverse() -> void:
	var water := WaterPlan.new(EXACT_SEED, 22.0, 8)
	var plan := HeightfieldPlan.new(EXACT_SEED, 22.0, 8, "mean", 3)
	plan.set_water_plan(water)
	var centre := EXACT_CHUNK * 8 + Vector2i(4, 4)
	var region := plan.compute_region(centre.x, centre.y, 8)
	var core := Rect2(Vector2(EXACT_CHUNK) * 192.0, Vector2.ONE * 192.0)
	var context := WaterFieldContext.build(water, core, region, 0.0)
	assert_false(context._shore_curves_ready)

	var found := false
	for z in range(int(core.position.y) + 6, int(core.end.y), 6):
		var a := Vector2(core.position.x, float(z))
		var b := Vector2(core.end.x, float(z))
		var intervals := context.wet_intervals(a, b)
		if intervals.is_empty() or (intervals.size() == 1
				and intervals[0].x <= 0.000001 and intervals[0].y >= 0.999999):
			continue
		found = true
		assert_true(context._shore_curves_ready)
		_assert_intervals_close(_mapped_reverse(context.wet_intervals(b, a)), intervals, 0.00001)
		for interval: Vector2 in intervals:
			if interval.y - interval.x > 0.01:
				assert_true(context.is_wet(a.lerp(b, (interval.x + interval.y) * 0.5)))
			var before := interval.x - 0.02
			var after := interval.y + 0.02
			if before >= 0.0:
				assert_false(context.is_wet(a.lerp(b, before)))
			if after <= 1.0:
				assert_false(context.is_wet(a.lerp(b, after)))
		break
	assert_true(found, "the pinned pond context exposes at least one mixed wet/dry segment")
