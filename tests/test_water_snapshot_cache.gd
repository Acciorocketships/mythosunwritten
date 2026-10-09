extends GutTest


func _snapshot() -> WaterGroundSnapshot:
	var points := {}
	for z in range(-4, 12):
		for x in range(-4, 12):
			points[Vector2i(x, z)] = (x * x + z * z) % 7
	return WaterGroundSnapshot.capture(HeightfieldRegion.new(points, points), Rect2(0, 0, 60, 60))


func test_exact_coordinates_survive_float32_index_collisions() -> void:
	var snapshot := _snapshot()
	var errors := []
	for x: float in [16.00000001, 16.00000002, 16.00000001, 16.0, 16.00000002]:
		var actual := snapshot.water_surface_y(x, 13.00000001)
		var expected := TerrainTileField.surface_y(snapshot, x, 13.00000001)
		if actual != expected:
			errors.append([x, actual, expected])
	assert_eq(errors, [])
	assert_eq(snapshot._surface_memo.size(), 1, "rounded keys cannot multiply cache entries")


func test_cache_is_bounded_and_eviction_preserves_the_surface() -> void:
	var snapshot := _snapshot()
	var errors := []
	for index in snapshot.SURFACE_CACHE_CAP + 20:
		var x := 12.0 + float(index) * .001
		var actual := snapshot.water_surface_y(x, 13.0)
		if actual != TerrainTileField.surface_y(snapshot, x, 13.0):
			errors.append(index)
	assert_eq(errors, [])
	assert_eq(snapshot._surface_memo.size(), snapshot.SURFACE_CACHE_CAP)
	assert_eq(snapshot._surface_keys.size(), snapshot.SURFACE_CACHE_CAP)
	assert_eq(
		snapshot.water_surface_y(12.0, 13.0), TerrainTileField.surface_y(snapshot, 12.0, 13.0)
	)


func test_parallel_readers_keep_identical_values() -> void:
	var snapshot := _snapshot()
	var boxes := [{"errors": []}, {"errors": []}]
	var tasks := []
	for index in 2:
		tasks.append(WorkerThreadPool.add_task(_check_snapshot.bind(snapshot, boxes[index])))
	for task: int in tasks:
		WorkerThreadPool.wait_for_task_completion(task)
	assert_eq(boxes[0].errors, [])
	assert_eq(boxes[1].errors, [])


static func _check_snapshot(snapshot: WaterGroundSnapshot, box: Dictionary) -> void:
	var errors := []
	for sample in 700:
		var x := 12.0 + float(sample) * .031
		var z := 13.0 + float(sample % 31) * .11
		if snapshot.water_surface_y(x, z) != TerrainTileField.surface_y(snapshot, x, z):
			errors.append(sample)
	box.errors = errors
