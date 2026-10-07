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
		batched.compute_rect_region(interior)
		native_regions = N.regions_served
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
