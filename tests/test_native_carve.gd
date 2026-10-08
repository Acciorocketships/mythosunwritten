extends GutTest
## The batched prefetch carve (C# NativeCarve over a whole window) equals the
## serial GDScript sample (_sample -> WaterPlan.carve_at) bit for bit.
const N := preload("res://scripts/native/NativeCarve.gd")

const SEED := 2697992464
const WINDOW := 60


func test_native_carve_prefetch_matches_serial_samples_or_stays_off() -> void:
	var water := TerrainWorldTuning.make_water(SEED)
	if not ClassDB.class_exists(&"CSharpScript"):
		assert_false(N.ready_for(SEED), "no .NET: stays off")
		return
	var serial := TerrainWorldTuning.make_heightfield(SEED, water)
	var batched := TerrainWorldTuning.make_heightfield(SEED, water)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	# Windows (lattice point of the 60 x 60 interior's corner): random ones
	# within +-4 km and ones on the Task 4 river cells.
	var corners: Array[Vector2i] = []
	for i in 3:
		corners.append(Vector2i(rng.randi_range(-333, 273), rng.randi_range(-333, 273)))
	for sc: Vector2i in [Vector2i(1, -5), Vector2i(2, 2), Vector2i(-6, 4)]:
		corners.append(sc * 64 + Vector2i(rng.randi_range(0, 4), rng.randi_range(0, 4)))
	var checked := 0
	var carved := 0
	var native_regions := 0
	for corner: Vector2i in corners:
		var interior := Rect2i(corner, Vector2i(WINDOW, WINDOW))
		var filled_before := N.samples_filled
		var size_before := batched._samples.size()
		batched.compute_rect_region(interior)
		native_regions = N.regions_served
		# Every sample this window added was filled by the C# batch.
		var added := batched._samples.size() - size_before
		assert_gt(added, HeightfieldPlan.PREFETCH_MIN, "window %s prefetched" % corner)
		assert_eq(N.samples_filled - filled_before, added, "window %s filled natively" % corner)
		# 500 points per window: random within the window plus its whole
		# central lattice row.
		var points: Array[Vector2i] = []
		for k in 440:
			points.append(corner + Vector2i(rng.randi_range(0, WINDOW - 1), rng.randi_range(0, WINDOW - 1)))
		for x in WINDOW:
			points.append(corner + Vector2i(x, WINDOW / 2))
		for q: Vector2i in points:
			batched._samples_lock.lock()
			var b = batched._samples.get(q)
			batched._samples_lock.unlock()
			assert_not_null(b, "prefetched %s" % q)
			var a: Array = serial._sample(q.x, q.y)
			assert_eq(b, a, "sample %s [h - carve, carve, h]" % q)
			checked += 1
			if float(a[1]) > 0.0:
				carved += 1
	assert_true(N.ready_for(SEED), "NativeCarve enabled under .NET")
	assert_gt(native_regions, 0, "the prefetch carved natively")
	assert_eq(checked, 3000)
	assert_gt(carved, 100, "the probe set crosses water")
	gut.p("checked %d points, %d carved, %d native regions" % [checked, carved, native_regions])


## A C# carve call that throws (region build or SampleBatch) turns the seed off;
## the prefetch then samples that window in GDScript (the serial samples).
func test_a_throwing_call_falls_back_to_gdscript_and_disables() -> void:
	var water := TerrainWorldTuning.make_water(SEED)
	if not N.ready_for(SEED):
		pass_test("native carve unavailable")
		return
	var serial := TerrainWorldTuning.make_heightfield(SEED, water)
	var batched := TerrainWorldTuning.make_heightfield(SEED, water)
	var corner := Vector2i(1, -5) * 64
	batched.compute_rect_region(Rect2i(corner, Vector2i(WINDOW, WINDOW)))   # warms the carve regions
	var shifted := corner + Vector2i(0, WINDOW + 8)
	var filled_before := N.samples_filled
	N.arm_fault()
	batched.compute_rect_region(Rect2i(shifted, Vector2i(WINDOW, WINDOW)))
	assert_false(N.ready_for(SEED), "the seed turned off")
	assert_eq(N.samples_filled, filled_before, "nothing was filled natively after the fault")
	var same := true
	for z in WINDOW:
		for x in WINDOW:
			var q := shifted + Vector2i(x, z)
			batched._samples_lock.lock()
			var b = batched._samples.get(q)
			batched._samples_lock.unlock()
			same = same and b != null and b == serial._sample(q.x, q.y)
	assert_true(same, "every sample equals the serial GDScript sample")
	N.failed = {}
	_expect_fault_warning()


## The fault's warning is the expected outcome, not a test failure.
func _expect_fault_warning() -> void:
	var warned := 0
	for e in get_errors():
		if e.contains_text("forced test fault"):
			e.handled = true
			warned += 1
	assert_gt(warned, 0, "a warning names the C# failure")
