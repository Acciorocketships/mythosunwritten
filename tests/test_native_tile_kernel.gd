extends GutTest
const K := preload("res://scripts/native/NativeTileKernel.gd")
const Tile := preload("res://scripts/terrain/field/TerrainTileField.gd")
const Region := preload("res://tests/fixtures/tile_point_region.gd")

func _dotnet() -> bool:
	return ClassDB.class_exists(&"CSharpScript")

func _random_region(rng: RandomNumberGenerator) -> Object:
	var heights := {}
	for j in range(-2, 8):
		for i in range(-2, 8):
			var h := float(rng.randi_range(0, 6)) * 4.0 + float(rng.randi_range(0, 3))
			if rng.randf() < 0.1: h += 0.5          # graded controls are whole metres; keep a few off-grid
			elif rng.randf() < 0.15: h += rng.randf_range(0.0, 3.999)   # non-integer, float32-rounded
			heights[Vector2i(i, j)] = h
	return Region.new(heights)

func test_sample_window_equals_surface_y_on_side() -> void:
	K.setup()   # compare the production dispatch (native when it passed its gate)
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	var saved := Tile.cliff_end
	for mode in [Tile.CliffEnd.E1, Tile.CliffEnd.E2, Tile.CliffEnd.E3]:
		Tile.cliff_end = mode
		var region = _random_region(rng)
		var window := Tile.dense_window(region, Vector2i(-2, -2), Vector2i(10, 10))
		var xs := PackedFloat64Array(); var zs := PackedFloat64Array()
		var oi := PackedInt32Array(); var oj := PackedInt32Array()
		for k in 400:
			var x := rng.randf_range(-6.0, 66.0); var z := rng.randf_range(-6.0, 66.0)
			if k % 5 == 0: x = 12.0 * rng.randi_range(0, 5) + 6.0     # wall midlines
			if k % 7 == 0: z = 12.0 * rng.randi_range(0, 5)          # lattice lines
			xs.append(x); zs.append(z)
			var o := Vector2i(Tile.point_of(x, region), Tile.point_of(z, region))
			if k % 3 == 0:   # non-point_of owners, as the mesher passes (window holds -2..7)
				o.x = clampi(o.x + rng.randi_range(-1, 1), -1, 6)
				o.y = clampi(o.y + rng.randi_range(-1, 1), -1, 6)
			oi.append(o.x); oj.append(o.y)
		assert_true(Tile._owners_inside(window, oi, oj), "the test window holds every owner's tiles")
		var got := Tile.sample_window(window, xs, zs, oi, oj)
		for k in xs.size():
			assert_eq(got[k], Tile.surface_y_on_side(region, xs[k], zs[k], Vector2i(oi[k], oj[k])))
		# Separable grid: columns xs[0..19] (owners oi), rows zs[0..14] (owners oj).
		var gx := xs.slice(0, 20); var gz := zs.slice(0, 15)
		var gox := oi.slice(0, 20); var goz := oj.slice(0, 15)
		var grid := Tile.sample_grid_window(window, gx, gz, gox, goz)
		var grid32 := Tile.sample_grid_window32(window, gx, gz, gox, goz)
		var same := true
		var same32 := true
		for k in gz.size():
			for i in gx.size():
				var want := Tile.surface_y_on_side(region, gx[i], gz[k], Vector2i(gox[i], goz[k]))
				same = same and grid[k * gx.size() + i] == want
				var want32 := PackedFloat32Array([want])
				same32 = same32 and grid32[k * gx.size() + i] == want32[0]
		assert_true(same, "sample_grid_window == surface_y_on_side")
		assert_true(same32, "sample_grid_window32 == float32(surface_y_on_side)")
	Tile.cliff_end = saved

func test_native_matches_or_stays_off() -> void:
	K.setup()
	if not _dotnet():
		assert_false(K.enabled, "standard editor keeps the GDScript kernel")
		return
	assert_true(K.enabled, "parity gate passed")

func test_sample_grid_matches_sample_baked_with_grades() -> void:
	K.setup()
	var water := TerrainWorldTuning.make_water(2697992464)
	var plan := TerrainWorldTuning.make_heightfield(2697992464, water)
	var region := plan.compute_region(16, 16, 12)
	var grade := TerrainGradePatch.new(&"t", {Vector2i(12, 12): 30.0, Vector2i(13, 12): 30.0}, Vector2(180, 180), 3.0)
	var graded := region.with_terrain_grades([grade])   # native controls (terrain_grades stays empty)
	# A region still carrying the post-classification grade list (the
	# sample_baked(..., region) -> _apply_grade path).
	var listed := HeightfieldRegion.new(region._storeys, region._levels, region._carved, region.plan)
	listed.terrain_grades.append(grade)
	var xs := PackedFloat64Array(); var zs := PackedFloat64Array()
	for i in 40: xs.append(150.0 + i * 1.5)
	for k in 40: zs.append(150.0 + k * 1.5)
	var changed := 0
	for r in [region, graded, listed]:
		var got := Tile.sample_grid(r, xs, zs)
		var got32 := Tile.sample_grid32(r, xs, zs)
		assert_eq(got.size(), xs.size() * zs.size())
		assert_eq(got32, Tile._to_float32(got), "sample_grid32 rounds sample_grid like a float32 store")
		var same := true
		for k in zs.size():
			for i in xs.size():
				var p := Vector2i(Tile.point_of(xs[i], r), Tile.point_of(zs[k], r))
				var want := Tile.sample_baked(Tile.bake_point(r, p), p, xs[i], zs[k], r)
				same = same and got[k * xs.size() + i] == want
				if r == listed and want != Tile.sample_baked(Tile.bake_point(region, p), p, xs[i], zs[k], region):
					changed += 1
		assert_true(same, "sample_grid == sample_baked on every sample")
	assert_gt(changed, 0, "the listed grade patch actually moves the ground in this window")
