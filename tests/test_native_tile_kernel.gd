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
			heights[Vector2i(i, j)] = h
	return Region.new(heights)

func test_sample_window_equals_surface_y_on_side() -> void:
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
			oi.append(Tile.point_of(x, region)); oj.append(Tile.point_of(z, region))
		var got := Tile.sample_window(window, xs, zs, oi, oj)
		for k in xs.size():
			assert_eq(got[k], Tile.surface_y_on_side(region, xs[k], zs[k], Vector2i(oi[k], oj[k])))
	Tile.cliff_end = saved

func test_native_matches_or_stays_off() -> void:
	K.setup()
	if not _dotnet():
		assert_false(K.enabled, "standard editor keeps the GDScript kernel")
		return
	assert_true(K.enabled, "parity gate passed")
