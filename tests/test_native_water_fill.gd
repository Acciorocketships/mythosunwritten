extends GutTest
const F := preload("res://scripts/native/NativeWaterFill.gd")
const PQ := preload("res://scripts/core/PriorityQueue.gd")

func test_priority_queue_tie_order_matches_gdscript() -> void:
	if not ClassDB.class_exists(&"CSharpScript"): pass_test("standard editor"); return
	var rng := RandomNumberGenerator.new(); rng.seed = 5
	var gd := PQ.new()
	var pushes := PackedFloat64Array()
	for i in 500:
		var p := float(rng.randi_range(0, 9))     # many ties
		pushes.append(p); gd.push(i, p)
		if rng.randf() < 0.3 and not gd.is_empty(): pushes.append(-1.0); gd.pop()
	var order_gd := PackedInt64Array()
	while not gd.is_empty(): order_gd.append(gd.pop())
	gd.free()
	assert_eq(F.queue_replay(pushes), order_gd, "-1 = pop; the native heap must pop the same items")

func test_fill_kernels_match_gdscript_exactly_or_stay_off() -> void:
	F.setup()
	if not ClassDB.class_exists(&"CSharpScript"):
		assert_false(F.enabled); return
	assert_true(F.enabled, "parity gate passed (random basins incl. ties and INF ground)")

## Unsampled (INF) ground keeps relax and smooth on the GDScript path, which
## samples the region lazily; complete ground runs natively and agrees.
func test_relax_with_complete_ground_matches_reference_through_the_dispatch() -> void:
	F.setup()
	var side := 9
	var ground := PackedFloat32Array(); ground.resize(side * side)
	for j in side:
		for i in side:
			ground[j * side + i] = floorf(absf(i - 4) + absf(j - 4) * 0.5)
	var rivers := PackedFloat32Array(); rivers.resize(side * side); rivers.fill(-INF)
	var run := func(native: bool) -> PackedFloat32Array:
		F.force_off = not native
		var levels := PackedFloat32Array(); levels.resize(side * side); levels.fill(-INF)
		var queue := PQ.new()
		queue.push([40, 2.5], 2.5)
		queue.push([0, 3.0], 3.0)
		WaterField._relax_fill(null, Vector2.ZERO, side, levels, ground, rivers, queue)
		assert_true(queue.is_empty(), "the queue is consumed")
		queue.free()
		F.force_off = false
		return levels
	assert_eq(run.call(true), run.call(false))


## Random terraced basins (many equal spill heights, so heap tie order
## matters), river anchors, wet boundary nodes, a dense uncarved ground and
## flow ceilings with INF / -INF: the native cap must match the GDScript
## SpillSearch + _cap_hydrostatic_fill exactly, levels and ceilings.
func test_cap_matches_gdscript_on_random_basins() -> void:
	F.setup()
	if not ClassDB.class_exists(&"CSharpScript"): pass_test("standard editor"); return
	var rng := RandomNumberGenerator.new(); rng.seed = 77
	for case_index in 8:
		var m1 := rng.randi_range(12, 50)
		var rows := m1 if case_index % 2 == 0 else rng.randi_range(12, 50)
		var n := m1 * rows
		var ground := PackedFloat32Array(); ground.resize(n)
		var bowl := Vector2(rng.randf_range(0.2, 0.8) * m1, rng.randf_range(0.2, 0.8) * rows)
		for j in rows:
			for i in m1:
				ground[j * m1 + i] = floorf(Vector2(i, j).distance_to(bowl) * rng.randf_range(0.2, 0.5)
					+ rng.randf_range(-1.5, 1.5)) * 0.5
		var levels := PackedFloat32Array(); levels.resize(n)
		var anchors := PackedFloat32Array(); anchors.resize(n); anchors.fill(-INF)
		var natural := PackedFloat32Array(); natural.resize(n)
		var flow := PackedFloat32Array(); flow.resize(n)
		var head := float(rng.randi_range(2, 8))
		for idx in n:
			levels[idx] = head if rng.randf() < 0.85 else -INF
			if rng.randf() < 0.05:
				anchors[idx] = ground[idx] + float(rng.randi_range(0, 3)) * 0.5
			natural[idx] = ground[idx] + (float(rng.randi_range(0, 6)) * 0.5 if rng.randf() < 0.5 else 0.0)
			var roll := rng.randf()
			flow[idx] = INF if roll < 0.1 else -INF if roll < 0.2 else ground[idx] + rng.randf_range(0.0, 4.0)
		var run := func(native: bool, with_natural: bool) -> Array:
			F.force_off = not native
			var l := levels.duplicate()
			var c := WaterField._cap_hydrostatic_fill(null, Vector2.ZERO, m1, l, ground.duplicate(),
				anchors, WaterField.FILL_STEP, null, natural if with_natural else null,
				flow if with_natural else PackedFloat32Array())
			F.force_off = false
			return [l, c]
		for with_natural in [false, true]:
			assert_eq(run.call(true, with_natural), run.call(false, with_natural),
				"case %d (%dx%d, natural %s)" % [case_index, m1, rows, with_natural])


## The source solve now samples the uncarved ground once, densely
## (TerrainTileField.sample_grid32), where the cap used to sample it lazily
## through _ground_at's baked path. Both must give the same float32 values on
## a real source domain.
func test_dense_natural_ground_equals_the_lazy_samples_on_a_real_domain() -> void:
	var seed := 2697992464
	var water := TerrainWorldTuning.make_water(seed)
	var plan := TerrainWorldTuning.make_heightfield(seed, water)
	var base := Vector2(-2403.0, -2277.0)
	var m1 := 70
	var rows := 61
	var domain := WaterField._point_domain(Rect2(base, Vector2(m1 - 1, rows - 1) * WaterField.FILL_STEP))
	var owned := plan.compute_rect_region(domain)
	var natural_plan := HeightfieldPlan.new(plan.world_seed, plan.height_amplitude,
		plan.max_storeys, plan.aggregation, plan.max_step)
	natural_plan.set_raw_height_override(owned.plan.uncarved_height)
	var natural := natural_plan.compute_rect_region(domain)
	var dense := WaterField._sample_ground_lattice(natural, base, m1, WaterField.FILL_STEP, rows)
	var lazy := PackedFloat32Array(); lazy.resize(m1 * rows); lazy.fill(INF)
	var bakes: Dictionary = {}
	for index in m1 * rows:
		WaterField._ground_at(natural, base, m1, lazy, index % m1, int(index / m1), WaterField.FILL_STEP, bakes)
	assert_eq(dense.size(), lazy.size())
	var differ := 0
	for index in lazy.size():
		if dense[index] != lazy[index]: differ += 1
	assert_eq(differ, 0, "dense and lazy uncarved ground agree at every node")
	var carved := 0
	var ground := WaterField._sample_ground_lattice(owned, base, m1, WaterField.FILL_STEP, rows)
	for index in lazy.size():
		if ground[index] < dense[index]: carved += 1
	assert_gt(carved, 0, "the domain contains carved channels (a meaningful comparison)")
