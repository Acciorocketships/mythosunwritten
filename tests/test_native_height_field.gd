extends GutTest

## The C# height field (scripts/native) is an exact mirror of
## TerrainField.height_m. Under the standard editor it is absent and the game
## uses GDScript; under the .NET editor it must pass its parity check for
## these seeds and stay bit-identical on an independent point set.

const NativeHeightField := preload("res://scripts/native/NativeHeightField.gd")
const SEEDS := [2697992464, 7]


func _dotnet() -> bool:
	return ClassDB.class_exists(&"CSharpScript")


func _points(seed: int, count: int) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed ^ 0x5eed
	var out := PackedVector2Array()
	for i in count:
		var r: float = [250.0, 2500.0, 9000.0, 45000.0][i % 4]
		var p := Vector2(rng.randf_range(-r, r), rng.randf_range(-r, r))
		if i % 3 == 0:
			p = (p / 12.0).round() * 12.0
		out.append(p)
	return out


func test_setup_enables_only_where_csharp_exists() -> void:
	for seed: int in SEEDS:
		NativeHeightField.setup(seed)
		if _dotnet():
			assert_true(NativeHeightField.enabled, "the .NET editor serves heights natively")
			assert_true(NativeHeightField.ready_for(seed), "seed %d passes its parity check" % seed)
		else:
			assert_false(NativeHeightField.enabled, "no C# under the standard editor")
			assert_false(NativeHeightField.ready_for(seed))


func test_native_heights_are_bit_identical_to_gdscript() -> void:
	if not _dotnet():
		pass_test("standard editor: GDScript heights only (fallback asserted above)")
		return
	for seed: int in SEEDS:
		NativeHeightField.setup(seed)
		var points := _points(seed, 600)
		var mismatches := 0
		for detail: bool in [true, false]:
			var batch := NativeHeightField.height_batch(points, seed, detail)
			for i in points.size():
				var gd := TerrainField.height_m(points[i], seed, detail)
				if gd != NativeHeightField.height_m(points[i], seed, detail) or gd != batch[i]:
					mismatches += 1
		assert_eq(mismatches, 0, "seed %d: C# == GDScript on %d independent samples" % [seed, points.size() * 2])


func test_height01_is_the_same_with_and_without_the_native_path() -> void:
	for seed: int in SEEDS:
		NativeHeightField.setup(seed)
		var points := _points(seed + 1, 200)
		var routed := PackedFloat64Array()
		for p: Vector2 in points:
			routed.append(HeightfieldPlan.height01(Vector3(p.x, 0.0, p.y), seed, true))
			routed.append(HeightfieldPlan.height01(Vector3(p.x, 0.0, p.y), seed, false))
		var was := NativeHeightField.enabled
		NativeHeightField.enabled = false
		var reference := PackedFloat64Array()
		for p: Vector2 in points:
			reference.append(HeightfieldPlan.height01(Vector3(p.x, 0.0, p.y), seed, true))
			reference.append(HeightfieldPlan.height01(Vector3(p.x, 0.0, p.y), seed, false))
		NativeHeightField.enabled = was
		assert_eq(routed, reference, "seed %d: height01 is unchanged by the native path" % seed)


func test_a_forced_archetype_stays_on_gdscript() -> void:
	NativeHeightField.setup(7)
	TerrainRegimeField.set_force_archetype(&"tableland")
	assert_false(NativeHeightField.ready_for(7), "forced archetypes are GDScript-only state")
	TerrainRegimeField.set_force_archetype(&"")
	assert_eq(NativeHeightField.ready_for(7), _dotnet())


func test_a_throwing_call_falls_back_to_gdscript_and_disables() -> void:
	if not _dotnet():
		pass_test("standard editor: no C#")
		return
	var seed: int = SEEDS[0]
	NativeHeightField.setup(seed)
	assert_true(NativeHeightField.ready_for(seed))
	var p := Vector2(1234.5, -876.25)
	NativeHeightField.arm_fault()
	assert_eq(NativeHeightField.height_m(p, seed, true), TerrainField.height_m(p, seed, true),
		"the faulted call returns the GDScript height")
	assert_false(NativeHeightField.ready_for(seed), "the port turned itself off")
	var points := _points(seed, 20)
	NativeHeightField.enabled = true
	NativeHeightField.arm_fault()
	var batch := NativeHeightField.height_batch(points, seed, false)
	for i in points.size():
		assert_eq(batch[i], TerrainField.height_m(points[i], seed, false))
	assert_false(NativeHeightField.enabled)
	NativeHeightField.enabled = true
	_expect_fault_warning()


## NativeGates.deferred (the game): setup() only registers; the main thread
## never gates and keeps GDScript; the first worker call gates the seed.
func test_deferred_gate_runs_on_a_worker_not_the_main_thread() -> void:
	if not _dotnet():
		pass_test("standard editor: no C#")
		return
	var gates := preload("res://scripts/native/NativeGates.gd")
	var seed := 31337
	gates.deferred = true
	NativeHeightField.setup(seed)
	assert_false(NativeHeightField.ready_for(seed), "main thread: still GDScript, no gate")
	var on_worker := [false]
	var task := WorkerThreadPool.add_task(func() -> void:
		on_worker[0] = NativeHeightField.ready_for(seed))
	WorkerThreadPool.wait_for_task_completion(task)
	gates.deferred = false
	assert_true(on_worker[0], "the worker ran the gate and the seed is native")
	assert_true(NativeHeightField.ready_for(seed))


## The fault's warning is the expected outcome, not a test failure.
func _expect_fault_warning() -> void:
	var warned := 0
	for e in get_errors():
		if e.contains_text("forced test fault"):
			e.handled = true
			warned += 1
	assert_gt(warned, 0, "a warning names the C# failure")
