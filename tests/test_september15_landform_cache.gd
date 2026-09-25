extends GutTest

func _reference() -> GDScript:
	var oracle := GDScript.new()
	oracle.source_code = FileAccess.get_file_as_string("res://docs/qa/2026-09-15-manual/02-streaming/LandformField-pre-owner-cache.gd.txt").replace("class_name LandformField\n", "")
	assert(oracle.reload() == OK)
	return oracle

func _sample(seed: int) -> PackedFloat64Array:
	var samples := PackedFloat64Array()
	for i in 128:
		var point := Vector3(float(i % 16) * 767.9 - 6144.0, 0, float(i / 16) * 768.1 - 3072.0)
		samples.append(LandformField.height01(point, seed))
	return samples

func test_eviction_and_concurrent_seeds_preserve_exact_geography() -> void:
	var oracle := _reference()
	var seeds: Array[int] = [2697992464, 31, 2697992464 + (1 << 32)]
	var expected: Array[PackedFloat64Array] = []
	for seed in seeds:
		var samples := PackedFloat64Array()
		for i in 128:
			var point := Vector3(float(i % 16) * 767.9 - 6144.0, 0, float(i / 16) * 768.1 - 3072.0)
			samples.append(oracle.height01(point, seed))
		expected.append(samples)
	# Cross the bounded cache's capacity with unrelated complete provinces.
	for i in LandformField.OWNER_CACHE_LIMIT + 7:
		LandformField._owner_parameters(7, Vector2i(i, -i))
	assert_eq(LandformField._owners.size(), LandformField.OWNER_CACHE_LIMIT)
	var workers: Array[Thread] = []
	for seed in seeds:
		var worker := Thread.new()
		assert_eq(worker.start(_sample.bind(seed)), OK)
		workers.append(worker)
	for i in workers.size():
		assert_eq(workers[i].wait_to_finish(), expected[i])
	assert_eq(LandformField._owners.size(), LandformField.OWNER_CACHE_LIMIT)
