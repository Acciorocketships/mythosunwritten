extends GutTest
const Reference = preload("res://tests/fixtures/September10SurfaceReconciliationReference.gd")

func test_a_settled_lake_needs_no_priority_queue_work() -> void:
	var ground := PackedFloat32Array(); ground.resize(200 * 160); ground.fill(0.0)
	var levels := ground.duplicate(); levels.fill(3.0)
	var offers := WaterField._reconcile_connected_surface(levels, ground, 200, 3.0)
	assert_eq(offers, 0, "a settled lake must not push and pop every wet vertex")
	assert_eq(levels.count(3.0), levels.size())

func test_sparse_initial_front_matches_the_frozen_complete_heap() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 2697992464
	for sample in 96:
		var columns := rng.randi_range(3, 35)
		var rows := rng.randi_range(3, 29)
		var ground := PackedFloat32Array(); ground.resize(columns * rows)
		var levels := ground.duplicate()
		for i in ground.size():
			ground[i] = rng.randi_range(-8, 32) * .25
			levels[i] = ground[i] + rng.randi_range(1, 32) * .25 if rng.randf() > .2 else -INF
		var expected := levels.duplicate()
		var step := 3.0 if sample % 2 else 6.0
		Reference.reconcile(expected, ground, columns, step)
		WaterField._reconcile_connected_surface(levels, ground, columns, step)
		assert_eq(levels, expected, "same complete rectangular hydraulic solution, case %d" % sample)
