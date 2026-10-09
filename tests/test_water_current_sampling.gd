extends GutTest


func test_current_fast_path_is_exact_for_wet_cells_and_shore_fallbacks() -> void:
	var points := {}
	for z in range(-4, 12):
		for x in range(-4, 12):
			points[Vector2i(x, z)] = (x * x + z * z) % 7
	var region := HeightfieldRegion.new(points, points)
	var rng := RandomNumberGenerator.new()
	rng.seed = 261009
	var errors := []
	var checked := 0
	var original_mode := TerrainTileField.cliff_end
	for trial in 32:
		TerrainTileField.cliff_end = int(trial / 8)
		var levels := PackedFloat32Array()
		levels.resize(25)
		for k in levels.size():
			levels[k] = -INF if rng.randf() < .2 else rng.randf_range(.04, 32)
		var fine := PackedFloat32Array()
		var ground := PackedFloat32Array()
		var dry := PackedByteArray()
		for index in 81:
			fine.append(rng.randf_range(.04, 4))
			ground.append(0)
			dry.append(0)
			if trial > 0 and rng.randf() < .25:
				fine[index] = -INF
			if trial > 2 and rng.randf() < .1:
				ground[index] = INF
			if trial > 3 and rng.randf() < .1:
				dry[index] = 1
		var ctx := {
			"fill_base": Vector2(3, 3),
			"fill_size": 5,
			"region": region,
			"fill": {"levels": levels, "sub_levels": fine, "sub_ground": ground, "sub_dry": dry}
		}
		if trial % 8 == 6:
			ctx.fill.erase("sub_levels")
			ctx.fill.erase("sub_ground")
			ctx.fill.erase("sub_dry")
		elif trial % 8 == 7:
			ctx.fill.sub_levels.fill(-INF)
			ctx.fill.sub_dry.fill(0)
		var sampler := WaterSampler.build(ctx, region, Vector2(3, 3), 3, 9, 9)
		for probe in 500:
			var p := Vector2(rng.randf_range(3, 27), rng.randf_range(3, 27))
			if probe < 81:
				p = Vector2(3, 3) + Vector2(probe % 9, int(probe / 9)) * 3
			var expected := sampler._native_fill_level_at(p)
			var actual := sampler._current_fill_level_at(p)
			checked += 1
			if actual != expected and not (is_nan(actual) and is_nan(expected)):
				errors.append([trial, p, expected, actual])
	TerrainTileField.cliff_end = original_mode
	assert_eq(errors, [], "wave steering retains the exact authoritative surface")
	assert_eq(checked, 16000)


func test_flow_cache_invalidates_only_cells_a_changed_sampler_can_own() -> void:
	var sampler := WaterSampler.new()
	sampler._origin = Vector2(0, 0)
	sampler._nx = 3
	sampler._nz = 2
	sampler._step = 3
	sampler._velocity = PackedVector2Array(
		[Vector2.RIGHT, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
	)
	var sim := WaterRippleSim.new()
	var cells := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(100, 100)]
	for cell: Vector2i in cells:
		sim._flow_cells[cell] = Color(.3, .2, 0, 0)
	sim._invalidate_flow_cells([sampler])
	assert_false(sim._flow_cells.has(cells[0]), "the changed current is recomputed")
	assert_true(
		sim._flow_cells.has(cells[1]), "a calm part of the same sampler cannot change ownership"
	)
	assert_true(sim._flow_cells.has(cells[2]), "a distant chunk keeps its cached current")
	sim.free()


func test_scalar_current_lookup_matches_corner_reference_at_edges_and_inside() -> void:
	var sampler := WaterSampler.new()
	sampler._origin = Vector2(-3, -6)
	sampler._step = 3
	sampler._nx = 9
	sampler._nz = 7
	var rng := RandomNumberGenerator.new()
	rng.seed = 911
	for index in 63:
		sampler._velocity.append(
			(
				Vector2.ZERO
				if index % 5 == 0
				else Vector2(rng.randf_range(-4, 4), rng.randf_range(-4, 4))
			)
		)
	var errors := []
	for probe in 1000:
		var p := Vector2(rng.randf_range(-7, 25), rng.randf_range(-10, 18))
		if probe < 63:
			p = sampler._origin + Vector2(probe % 9, int(probe / 9)) * 3
		var expected := Vector2.ZERO
		var covered := false
		for corner: Array in sampler._corners(p):
			var velocity: Vector2 = sampler._velocity[corner[1] * 9 + corner[0]]
			expected += velocity * corner[2]
			covered = covered or velocity != Vector2.ZERO
		if expected != sampler._interpolated_velocity(p) or covered != sampler.covers_current(p):
			errors.append(p)
	assert_eq(errors, [])


func test_compiled_frozen_cells_are_identical_for_parallel_consumers() -> void:
	var state: Dictionary = bytes_to_var(
		(
			FileAccess
			. get_file_as_bytes("res://tests/fixtures/october9/ripple-late-update.bin.gz")
			. decompress_dynamic(32 * 1024 * 1024, FileAccess.COMPRESSION_GZIP)
		)
	)
	var row: Dictionary = state.samplers[0]
	var sampler := WaterSampler.new()
	var snapshot := WaterGroundSnapshot.new()
	for key: String in row._fill_ctx.region:
		snapshot.set(key, row._fill_ctx.region[key])
	row._fill_ctx.region = snapshot
	for key: String in row:
		sampler.set(key, row[key])
	var points := PackedVector2Array()
	var expected := PackedFloat64Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 941
	for index in 300:
		var p: Vector2 = (
			sampler._origin
			+ (
				Vector2(rng.randf(), rng.randf())
				* Vector2(sampler._nx - 1, sampler._nz - 1)
				* sampler._step
			)
		)
		points.append(p)
		expected.append(sampler._native_fill_level_at(p))
	var boxes := [{"errors": []}, {"errors": []}]
	var tasks := []
	for box: Dictionary in boxes:
		tasks.append(
			WorkerThreadPool.add_task(_check_current_samples.bind(sampler, points, expected, box))
		)
	for task: int in tasks:
		WorkerThreadPool.wait_for_task_completion(task)
	assert_eq(boxes[0].errors, [])
	assert_eq(boxes[1].errors, [])


static func _check_current_samples(
	sampler: WaterSampler, points: PackedVector2Array, expected: PackedFloat64Array, box: Dictionary
) -> void:
	var errors := []
	for index in points.size():
		var actual := sampler._current_fill_level_at(points[index])
		if actual != expected[index] and not (is_nan(actual) and is_nan(expected[index])):
			errors.append(index)
	box.errors = errors


func test_compiled_surface_accepts_raw_canonical_context_without_fill_size() -> void:
	var width := WaterField.FILL_M + 1
	var fine_width := WaterField.FILL_M * 2 + 1
	var coarse := PackedFloat32Array()
	coarse.resize(width * width)
	coarse.fill(2.0)
	var fine := PackedFloat32Array()
	fine.resize(fine_width * fine_width)
	fine.fill(2.0)
	var ground := PackedFloat32Array()
	ground.resize(fine.size())
	var ctx := {"fill_base": Vector2.ZERO, "fill": {"levels": coarse,
		"sub_levels": fine, "sub_ground": ground}, "region": HeightfieldRegion.new({}, {})}
	var surface := preload("res://scripts/terrain/water/WaterCurrentSurface.gd").new()
	for p: Vector2 in [Vector2.ZERO, Vector2(13.27, 29.51), Vector2.ONE * WaterField.FILL_M * WaterField.FILL_STEP]:
		assert_eq(surface.sample(ctx, p), WaterField.level_at(ctx, p))
