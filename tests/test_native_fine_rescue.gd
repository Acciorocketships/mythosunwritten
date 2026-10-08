extends GutTest
## The fine rescue's seed and anchor stages in C# (NativeFineRescue.cs) against
## WaterField._rescue_seed_anchors, and the whole rescue through the dispatch.
const F := preload("res://scripts/native/NativeWaterFill.gd")


func before_each() -> void:
	F.setup()


## Many more random lattices than the gate's 12, on another seed.
func test_seed_and_anchor_stages_match_gdscript_on_random_lattices() -> void:
	if not F.enabled: pass_test("native fill unavailable"); return
	assert_eq(F.rescue_parity(48, 99), "", "every output bit-identical")


## The random lattices must actually reach every wall branch of _wall_span:
## a spill (both sides wet, upper water over the crown), a wet/dry pair across
## a cliff, and a submerged wall (cliff, both wet, linear), plus shore cells.
func test_random_lattices_cover_the_wall_branches() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261008
	var spills := 0
	var pairs := 0
	var submerged := 0
	var shores := 0
	for case_index in 12:
		var made := F.rescue_case(rng, case_index)
		var coarse: PackedFloat32Array = made.coarse
		var n: int = made.coarse_n
		var base: Vector2 = made.base
		var ctx := {"fill_base": base, "fill_size": n, "fill": {"levels": coarse}, "region": made.region}
		for j in int(made.coarse_rows) - 1:
			for i in n - 1:
				var a := coarse[j * n + i]
				var b := coarse[j * n + i + 1]
				if (a == -INF) != (coarse[(j + 1) * n + i] == -INF): shores += 1
				if a == -INF and b == -INF: continue
				if not WaterField._may_straddle_a_cliff(ctx, i, j, n): continue
				var x0 := base.x + i * WaterField.FILL_STEP
				var z := base.y + j * WaterField.FILL_STEP
				var ga := WaterField._node_ground(ctx, i, j, n)
				var gb := WaterField._node_ground(ctx, i + 1, j, n)
				var va := a if a != -INF else ga - 0.45
				var vb := b if b != -INF else gb - 0.45
				for s in [x0 + 1.5, x0 + 4.5]:
					var linear := lerpf(va, vb, (s - x0) / WaterField.FILL_STEP)
					var got := WaterField._wall_span(made.region, 12.0, va, vb, a != -INF, b != -INF, x0, s, z, 0)
					var wall_drop := absf(ga - gb) >= 4.0
					if a != -INF and b != -INF:
						if got != linear: spills += 1
						elif wall_drop: submerged += 1
					elif got != linear:
						pairs += 1
	assert_gt(spills, 0, "spills over a crown")
	assert_gt(pairs, 0, "wet/dry pairs across a cliff")
	assert_gt(submerged, 0, "submerged walls")
	assert_gt(shores, 0, "mixed (shore) cells")


## The whole rescue (seed and anchors in C#, flood and finish in GDScript)
## equals the all-GDScript rescue, levels and ground.
func test_whole_rescue_through_the_dispatch_matches_gdscript() -> void:
	if not F.enabled: pass_test("native fill unavailable"); return
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var rescued := 0
	for case_index in 10:
		var made := F.rescue_case(rng, case_index)
		var coarse: PackedFloat32Array = made.coarse
		var river := PackedFloat32Array(); river.resize(coarse.size()); river.fill(-INF)
		for idx in coarse.size():
			if coarse[idx] == -INF and rng.randf() < 0.1: river[idx] = 14.0
		F.force_off = true
		var expected := WaterField._build_sub_lattice_rescue(made.region, made.base, coarse, river, made.coarse_n)
		F.force_off = false
		var actual := WaterField._build_sub_lattice_rescue(made.region, made.base, coarse, river, made.coarse_n)
		assert_eq(actual.levels, expected.levels, "rescued levels (case %d)" % case_index)
		assert_eq(actual.ground, expected.ground, "rescue ground (case %d)" % case_index)
		rescued += (expected.levels as PackedFloat32Array).size() - (expected.levels as PackedFloat32Array).count(-INF)
	assert_gt(rescued, 0, "some cases rescue a pocket")


## A throwing C# call returns the GDScript stages and turns the port off.
func test_a_throwing_rescue_call_falls_back_to_gdscript() -> void:
	if not F.enabled: pass_test("native fill unavailable"); return
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var made := F.rescue_case(rng, 0)
	F.force_off = true
	var expected := WaterField._build_sub_lattice_rescue(made.region, made.base, made.coarse,
		PackedFloat32Array(), made.coarse_n)
	F.force_off = false
	F.arm_fault()
	var actual := WaterField._build_sub_lattice_rescue(made.region, made.base, made.coarse,
		PackedFloat32Array(), made.coarse_n)
	assert_eq(actual.levels, expected.levels)
	assert_eq(actual.ground, expected.ground)
	assert_false(F.on(), "the port turned itself off")
	F._faulted = false
	F.enabled = true
	var warned := 0
	for e in get_errors():
		if e.contains_text("forced test fault"):
			e.handled = true
			warned += 1
	assert_gt(warned, 0, "a warning names the C# failure")
