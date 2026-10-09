extends GutTest


func _context() -> Dictionary:
	var points := {}
	for z in range(-2, 28):
		for x in range(-2, 28):
			points[Vector2i(x, z)] = 0
	var region := HeightfieldRegion.new(points, points)
	var n := WaterField.FILL_M + 1
	var fine_n := WaterField.FILL_SUB_M + 1
	var levels := PackedFloat32Array()
	levels.resize(n * n)
	levels.fill(2)
	var fine := PackedFloat32Array()
	fine.resize(fine_n * fine_n)
	fine.fill(-INF)
	var ground := PackedFloat32Array()
	ground.resize(fine.size())
	ground.fill(0)
	return {
		"region": region,
		"fill_base": Vector2.ZERO,
		"fill_size": n,
		"fill": {"levels": levels, "sub_levels": fine, "sub_ground": ground}
	}


func _reject_square(ctx: Dictionary) -> void:
	var dry := PackedByteArray()
	dry.resize(ctx.fill.sub_levels.size())
	var n := WaterField.FILL_SUB_M + 1
	for z in range(3, 8):
		for x in range(3, 8):
			dry[z * n + x] = 1
	ctx.fill["sub_dry"] = dry


func test_explicitly_dry_fine_area_does_not_resurrect_coarse_water() -> void:
	var ctx := _context()
	assert_eq(WaterField.level_at(ctx, Vector2(15, 15)), 2.0)
	_reject_square(ctx)
	assert_eq(WaterField.level_at(ctx, Vector2(15, 15)), -INF)
	assert_eq(
		WaterField.level_at(ctx, Vector2(30, 30)),
		2.0,
		"unaffected cells retain the exact old coarse answer"
	)


func test_empty_fine_override_still_inherits_coarse_water() -> void:
	var ctx := _context()
	var dry := PackedByteArray()
	dry.resize(ctx.fill.sub_levels.size())
	ctx.fill["sub_dry"] = dry
	assert_eq(WaterField.level_at(ctx, Vector2(15, 15)), 2.0)
	assert_eq(
		bytes_to_var(var_to_bytes(ctx.fill)),
		ctx.fill,
		"explicit dry representation round-trips through the planning cache"
	)


func test_detached_sampler_preserves_rejection_after_context_changes() -> void:
	var ctx := _context()
	_reject_square(ctx)
	var sampler := WaterSampler.build(ctx, ctx.region, Vector2(9, 9), 3, 7, 7)
	assert_true(is_nan(sampler.level_at(Vector2(15, 15))))
	ctx.fill.sub_dry.fill(0)
	assert_eq(WaterField.level_at(ctx, Vector2(15, 15)), 2.0)
	assert_true(
		is_nan(sampler.level_at(Vector2(15, 15))), "snapshot owns the dry mask independently"
	)


func test_rectangular_source_grid_uses_its_own_fine_dimensions() -> void:
	var ctx := _context()
	ctx.fill_size = 3
	ctx.fill.levels.resize(12)
	ctx.fill.sub_levels.resize(35)
	ctx.fill.sub_levels.fill(-INF)
	ctx.fill.sub_ground.resize(35)
	var dry := PackedByteArray()
	dry.resize(35)
	for z in [5, 6]:
		for x in [3, 4]:
			dry[z * 5 + x] = 1
	ctx.fill.sub_dry = dry
	assert_eq(WaterField._fill_bilinear(ctx, Vector2(10.5, 16.5)), -INF)
	assert_eq(WaterField._fill_bilinear(ctx, Vector2(1.5, 1.5)), 2.0)
