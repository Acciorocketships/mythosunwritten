extends GutTest
## The fine rescue's seed, anchor, spill init and flood stages in C#
## (NativeFineRescue.cs) against WaterField._rescue_seed_anchors and
## _rescue_flood, and the whole rescue through the dispatch.
const F := preload("res://scripts/native/NativeWaterFill.gd")


func before_each() -> void:
	F.setup()


## With the C# built, the parity gate (seed through flood) must pass: the
## other tests skip when the port is off, which would hide a mismatch.
func test_the_parity_gate_passes_when_the_csharp_is_built() -> void:
	if F._native == null: pass_test("C# not built"); return
	assert_true(F.enabled, "NativeWaterFill gate passed (a warning names the mismatch)")


## Many more random lattices than the gate's 12, on another seed (the C#
## path from the seed stage through the flood).
func test_the_whole_csharp_rescue_path_matches_gdscript_on_random_lattices() -> void:
	if not F.enabled: pass_test("native fill unavailable"); return
	assert_eq(F.rescue_parity(48, 99), "", "every output bit-identical")


## The main thread never runs the deferred gate (~1.3 s): on() there keeps
## the GDScript until a worker has gated.
func test_on_never_gates_on_the_main_thread() -> void:
	var was_gated: bool = F._gated
	var was_enabled: bool = F.enabled
	F._gated = false
	F.enabled = false
	assert_false(F.on(), "the main thread uses GDScript")
	assert_false(F._gated, "and leaves the gate to a worker")
	F._gated = was_gated
	F.enabled = was_enabled


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


## The whole rescue (seed through flood in C#, finish in GDScript)
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


## The gate's random lattices must make the flood do real work: rescued
## pockets, spill searches that cap a level, and river ceilings that bind.
func test_random_lattices_exercise_the_flood() -> void:
	if not F.enabled: pass_test("native fill unavailable"); return
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261008
	var rescued := 0
	var searches := 0
	var capped := 0
	var ceilinged := 0
	for case_index in 12:
		var made := F.rescue_case(rng, case_index)
		var coarse: PackedFloat32Array = made.coarse
		var n := (int(made.coarse_n) - 1) * 2 + 1
		var rows := (int(made.coarse_rows) - 1) * 2 + 1
		var ground := PackedFloat32Array(); ground.resize(n * rows); ground.fill(INF)
		var r := F.rescue_flood(made.region, made.base, coarse, made.coarse_n, ground, made.river)
		assert_false(r.is_empty(), "C# flood ran (case %d)" % case_index)
		var levels: PackedFloat32Array = r.levels
		rescued += levels.size() - levels.count(-INF)
		searches += int(r.spill_searches)
		# Settled nodes the flood did not rescue: capped dry by a spill height
		# or ceiling, or coarse-wet already.
		if int(r.flood_settled) > levels.size() - levels.count(-INF): capped += 1
		if not (made.river as PackedFloat32Array).is_empty():
			var open := F.rescue_flood(made.region, made.base, coarse, made.coarse_n, ground,
				PackedFloat32Array())
			if open.levels != levels: ceilinged += 1
	assert_gt(rescued, 0, "rescued 3 m nodes")
	assert_gt(searches, 0, "spill searches")
	assert_gt(capped, 0, "settled nodes left unrescued")
	assert_gt(ceilinged, 0, "river ceilings that change the flood")


## Profiling counters (PROFILE_WATER_COST) belong to one rescue at a time:
## concurrent profiled rescues on several threads neither crash nor leave the
## counters claimed (the October 8 class: no unlocked static container).
func test_profiled_rescues_on_several_threads_share_the_counters_safely() -> void:
	var was := WaterField.profile_source_cost
	WaterField.profile_source_cost = true
	F.force_off = true   # the GDScript stages tick the counters on every helper
	var threads: Array[Thread] = []
	for t in 3:
		var thread := Thread.new()
		thread.start(_profiled_rescues.bind(100 + t))
		threads.append(thread)
	_profiled_rescues(99)
	var done := 0
	for thread in threads:
		done += int(thread.wait_to_finish())
	WaterField.profile_source_cost = was
	F.force_off = false
	assert_eq(done, 3 * 4, "every threaded rescue finished")
	assert_eq(WaterField._fine_owner, -1, "counters released")
	assert_eq(WaterField._fine_stage, 0, "no stage left running")


func _profiled_rescues(rng_seed: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var finished := 0
	for case_index in 4:
		var made := F.rescue_case(rng, case_index)
		WaterField._build_sub_lattice_rescue(made.region, made.base, made.coarse, made.river,
			made.coarse_n)
		finished += 1
	return finished
