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
