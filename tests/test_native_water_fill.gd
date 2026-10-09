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


## River and pond seeding on real source domains (the WaterField._source_fill
## inputs: contributors in the rect, the owned region, the dense carved
## ground): the C# claims, containment and pond seeds must equal the GDScript
## _seed_rivers + _seed_ponds exactly: river levels, claim margins and the
## queue (source indices, levels, priorities, in heap order).
func test_river_seeding_matches_gdscript_on_real_domains() -> void:
	F.setup()
	if not ClassDB.class_exists(&"CSharpScript"): pass_test("standard editor"); return
	assert_true(F.enabled)
	var seed := 2697992464
	var water := TerrainWorldTuning.make_water(seed)
	var plan := TerrainWorldTuning.make_heightfield(seed, water)
	var rivers_seen := 0
	var seeds_seen := 0
	var banks_seen := 0
	for domain_spec: Array in [[Vector2(-2403.0, -2277.0), 70, 61], [Vector2(-807.0, -999.0), 72, 72],
			[Vector2(189.0, -957.0), 64, 70], [Vector2(-1203.0, -1599.0), 80, 66]]:
		var base: Vector2 = domain_spec[0]
		var m1: int = domain_spec[1]
		var rows: int = domain_spec[2]
		var rect := Rect2(base, Vector2(m1 - 1, rows - 1) * WaterField.FILL_STEP)
		var contributors: Dictionary = water.bodies_in_rect(rect)
		var context := {"water": water, "rivers": contributors.rivers, "ponds": contributors.ponds}
		var owned := plan.compute_rect_region(WaterField._point_domain(rect))
		var ground := WaterField._sample_ground_lattice(owned, base, m1, WaterField.FILL_STEP, rows)
		var dry := PackedFloat32Array(); dry.resize(m1 * rows); dry.fill(-INF)
		# GDScript reference.
		var expected := dry.duplicate()
		var claims := WaterField._river_claims(context, owned)
		var margins := WaterField._claim_rivers(claims, base, m1, expected)
		var queue := PQ.new()
		WaterField._contain_rivers(context.ponds, owned, base, m1, dry, ground, expected, margins, queue)
		WaterField._seed_ponds(context, owned, base, m1, dry, ground, queue)
		var index := PackedInt32Array()
		var level := PackedFloat64Array()
		var priority := PackedFloat64Array()
		for entry: Dictionary in queue.heap:
			index.append(entry.item[0]); level.append(entry.item[1]); priority.append(entry.priority)
		queue.free()
		# The dispatch the source solve uses.
		var actual := dry.duplicate()
		var heap := WaterField._seed_sources_native(context, owned, base, m1, dry, ground, actual)
		assert_false(heap.is_empty(), "native seeding ran")
		if heap.is_empty(): return
		var label := "domain %s %dx%d" % [base, m1, rows]
		assert_eq(actual, expected, label + ": river levels")
		assert_eq(heap.margins, margins, label + ": claim margins")
		assert_eq(heap.index, index, label + ": source indices (heap order)")
		assert_eq(heap.level, level, label + ": seed levels")
		assert_eq(heap.priority, priority, label + ": seed priorities")
		rivers_seen += contributors.rivers.size()
		seeds_seen += index.size()
		for k in margins.size():
			if is_finite(margins[k]) and margins[k] > 0.0: banks_seen += 1
	assert_gt(rivers_seen, 3, "the domains hold real rivers")
	assert_gt(seeds_seen, 100, "and real seeds")
	assert_gt(banks_seen, 100, "and bank constraints")


## The September 9 bank fixture with complete ground: the seeding dispatch
## and the GDScript agree, and the source fill's relax on the native heap
## equals the GDScript relax of the GDScript queue.
func test_seeded_heap_relaxes_like_the_gdscript_queue() -> void:
	F.setup()
	if not ClassDB.class_exists(&"CSharpScript"): pass_test("standard editor"); return
	var river := RiverTrace.new()
	river.source_cell = Vector2i(901, 903)
	river.points = PackedVector2Array([Vector2(-36, 0), Vector2(0, 6), Vector2(36, 0)])
	river.beds = PackedFloat32Array([4, 3.5, 3])
	river.widths = PackedFloat32Array([20, 14, 20])
	var near_pond := PondStamp.new(Vector2(0, 36), 12, 17, 2, 3)
	var far_pond := PondStamp.new(Vector2(700, 700), 60, 31, 2, 3)
	river.pond = near_pond
	var water := WaterPlan.new(123, 32, 8)
	var context := {"water": water, "rivers": [river], "ponds": [near_pond, far_pond]}
	var region := HeightfieldRegion.new({}, {})
	var m1 := 17
	var ground := PackedFloat32Array(); ground.resize(m1 * m1)
	for j in m1:
		for i in m1:
			ground[j * m1 + i] = floorf(absf(j - 8) * 0.6 + absf(i - 8) * 0.2)
	var dry := PackedFloat32Array(); dry.resize(m1 * m1); dry.fill(-INF)
	var base := Vector2(-48, -48)
	var expected_rivers := dry.duplicate()
	var expected := dry.duplicate()
	var queue := PQ.new()
	WaterField._seed_rivers(context, region, base, m1, dry, ground, expected_rivers, queue)
	WaterField._seed_ponds(context, region, base, m1, dry, ground, queue)
	WaterField._relax_fill(null, base, m1, expected, ground, expected_rivers, queue)
	queue.free()
	var actual_rivers := dry.duplicate()
	var actual := dry.duplicate()
	var heap := WaterField._seed_sources_native(context, region, base, m1, dry, ground, actual_rivers)
	assert_false(heap.is_empty())
	F.relax_heap(m1, actual, ground, actual_rivers, heap)
	assert_eq(actual_rivers, expected_rivers, "river levels")
	assert_eq(actual, expected, "relaxed levels")
	assert_gt(heap.index.size(), 0)


## A C# kernel that throws turns the port off for good and its caller runs
## the GDScript kernel: the same levels, no script error.
func test_a_throwing_call_falls_back_to_gdscript_and_disables() -> void:
	F.setup()
	if not F.enabled:
		pass_test("native fill unavailable")
		return
	var side := 9
	var ground := PackedFloat32Array(); ground.resize(side * side)
	for j in side:
		for i in side:
			ground[j * side + i] = floorf(absf(i - 4) + absf(j - 4) * 0.5)
	var rivers := PackedFloat32Array(); rivers.resize(side * side); rivers.fill(-INF)
	var run := func() -> PackedFloat32Array:
		var levels := PackedFloat32Array(); levels.resize(side * side); levels.fill(-INF)
		var queue := PQ.new()
		queue.push([40, 2.5], 2.5)
		queue.push([0, 3.0], 3.0)
		WaterField._relax_fill(null, Vector2.ZERO, side, levels, ground, rivers, queue)
		assert_true(queue.is_empty(), "the queue is consumed")
		queue.free()
		return levels
	F.force_off = true
	var expected: PackedFloat32Array = run.call()
	F.force_off = false
	F.arm_fault()
	assert_eq(run.call(), expected, "the faulted relax returns the GDScript levels")
	assert_false(F.on(), "the port turned itself off")
	F._faulted = false
	F.enabled = true
	_expect_fault_warning()


## The fault's warning is the expected outcome, not a test failure.
func _expect_fault_warning() -> void:
	var warned := 0
	for e in get_errors():
		if e.contains_text("forced test fault"):
			e.handled = true
			warned += 1
	assert_gt(warned, 0, "a warning names the C# failure")


func test_source_support_matches_photographed_grid_exactly() -> void:
	F.setup()
	if not ClassDB.class_exists(&"CSharpScript"):
		pass_test("standard editor uses reference"); return
	assert_true(F.on(), "the native parity gate is enabled")
	var support = load("res://scripts/terrain/water/WaterSourceSupport.gd")
	var file := FileAccess.open("res://tests/fixtures/october9/water-support-branch.bin",FileAccess.READ)
	var grid: Dictionary = file.get_var()
	var expected: PackedFloat32Array = support.constrain(grid.levels,grid.ground,grid.size,grid.conservative_roots)
	assert_eq(F.source_support(grid.levels,grid.ground,grid.size,grid.conservative_roots),expected)

func test_source_support_fault_falls_back_for_the_same_call() -> void:
	F.setup()
	if not ClassDB.class_exists(&"CSharpScript"):
		pass_test("standard editor uses reference"); return
	var support = load("res://scripts/terrain/water/WaterSourceSupport.gd")
	var levels := PackedFloat32Array([5,3,4,4])
	var ground := PackedFloat32Array([0,0,3.5,0])
	var roots := PackedInt32Array([0])
	F.arm_fault()
	assert_eq(support.solve(levels,ground,4,roots),support.constrain(levels,ground,4,roots))
	assert_false(F.enabled,"a fault disables the port")
	F._faulted = false
	F.enabled = true
	_expect_fault_warning()
