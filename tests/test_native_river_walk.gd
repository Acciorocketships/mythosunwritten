extends GutTest
const N := preload("res://scripts/native/NativeRiverWalk.gd")

func test_native_walks_match_gdscript_exactly_or_stay_off() -> void:
	var seed := 2697992464
	N.setup(seed)
	if not ClassDB.class_exists(&"CSharpScript"):
		assert_false(N.ready_for(seed)); return
	assert_true(N.ready_for(seed), "parity gate passed")
	var gd := TerrainWorldTuning.make_water(seed)
	var native := TerrainWorldTuning.make_water(seed)
	TerrainWorldTuning.make_heightfield(seed, gd)
	TerrainWorldTuning.make_heightfield(seed, native)
	for sc in [Vector2i(-3, -11), Vector2i(1, -5), Vector2i(2, 2), Vector2i(-6, 4), Vector2i(9, -9)]:
		N.force_off = true
		var a := gd.has_source(sc)
		var ta: RiverTrace = gd._walk(sc) if a else null
		N.force_off = false
		var b := native.has_source(sc)
		assert_eq(a, b, "has_source %s" % sc)
		if a:
			var tb: RiverTrace = native._walk(sc)
			assert_eq(ta.points, tb.points); assert_eq(ta.beds, tb.beds); assert_eq(ta.widths, tb.widths)
			assert_eq(ta.pond.center, tb.pond.center); assert_eq(ta.pond.level, tb.pond.level)
			assert_eq(ta.source_pool.level, tb.source_pool.level)


## A C# call that throws turns the seed off and WaterPlan runs the GDScript.
func test_a_throwing_call_falls_back_to_gdscript_and_disables() -> void:
	var seed := 2697992464
	N.setup(seed)
	if not N.ready_for(seed):
		pass_test("native river walk unavailable")
		return
	var sc := Vector2i(1, -5)
	var native := TerrainWorldTuning.make_water(seed)
	var gd := TerrainWorldTuning.make_water(seed)
	N.force_off = true
	var want := gd.source_pos(sc)
	N.force_off = false
	N.arm_fault()
	assert_eq(native.source_pos(sc), want, "the faulted call returns the GDScript source")
	assert_false(N.ready_for(seed), "the seed turned off")
	N.reset()
	_expect_fault_warning()


## NativeGates.deferred: the main thread never gates; a worker does.
func test_deferred_gate_runs_on_a_worker_not_the_main_thread() -> void:
	if not ClassDB.class_exists(&"CSharpScript"):
		pass_test("standard editor: no C#")
		return
	var gates := preload("res://scripts/native/NativeGates.gd")
	var seed := 2697992464
	N.reset()
	gates.deferred = true
	N.setup(seed)
	assert_false(N.ready_for(seed), "main thread: no gate, GDScript")
	var on_worker := [false]
	var task := WorkerThreadPool.add_task(func() -> void: on_worker[0] = N.ready_for(seed))
	WorkerThreadPool.wait_for_task_completion(task)
	gates.deferred = false
	assert_true(on_worker[0], "the worker ran the gate")


## The fault's warning is the expected outcome, not a test failure.
func _expect_fault_warning() -> void:
	var warned := 0
	for e in get_errors():
		if e.contains_text("forced test fault"):
			e.handled = true
			warned += 1
	assert_gt(warned, 0, "a warning names the C# failure")
