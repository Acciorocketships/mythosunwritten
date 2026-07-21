# tests/test_slope_atlas.gd
extends GutTest

func test_grass_uv_in_range() -> void:
	var uv := SlopeAtlas.grass_uv()
	assert_between(uv.x, 0.0, 1.0)
	assert_between(uv.y, 0.0, 1.0)

func test_grass_uv_samples_green() -> void:
	# The sampled texel in the self-contained baked palette must read as green
	# (G dominant). Tests must not keep source-pack dependencies alive.
	var uv := SlopeAtlas.grass_uv()
	var visual := load(SlopeAtlas.TOP_VISUAL) as EnvironmentVisual
	var material := visual.pieces[0].mesh.surface_get_material(0) as StandardMaterial3D
	var tex := material.albedo_texture
	assert_not_null(tex)
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()  # palette png is imported VRAM-compressed; get_pixel needs raw
	var px := img.get_pixel(
		int(clampf(uv.x, 0.0, 0.999) * img.get_width()),
		int(clampf(uv.y, 0.0, 0.999) * img.get_height()))
	assert_gt(px.g, px.r)
	assert_gt(px.g, px.b)

func test_cliff_uv_differs_from_grass():
	var grass := SlopeAtlas.grass_uv()
	var cliff := SlopeAtlas.cliff_uv()
	assert_true(cliff is Vector2)
	assert_false(grass.is_equal_approx(cliff), "rock swatch is a different texel than grass")

func test_path_uv_is_centred_inside_one_warm_tan_island() -> void:
	var uv := SlopeAtlas.path_uv()
	assert_almost_eq(fposmod(uv.x, 0.25), 0.125, 0.0001)
	assert_almost_eq(fposmod(uv.y, 0.25), 0.125, 0.0001)
	var visual := load(SlopeAtlas.TOP_VISUAL) as EnvironmentVisual
	var material := visual.pieces[0].mesh.surface_get_material(0) as StandardMaterial3D
	var image := material.albedo_texture.get_image()
	if image.is_compressed():
		image.decompress()
	var centre := image.get_pixel(int(uv.x * image.get_width()),
		int(uv.y * image.get_height()))
	assert_gt(centre.r, centre.g)
	assert_gt(centre.g, centre.b)
	for offset: Vector2 in [Vector2(0.08, 0.0), Vector2(-0.08, 0.0),
			Vector2(0.0, 0.08), Vector2(0.0, -0.08)]:
		var sample_uv := uv + offset
		var sample := image.get_pixel(int(sample_uv.x * image.get_width()),
			int(sample_uv.y * image.get_height()))
		assert_gt(sample.r, sample.g)
		assert_gt(sample.g, sample.b)
		assert_lt(Vector3(sample.r, sample.g, sample.b).distance_to(
			Vector3(centre.r, centre.g, centre.b)), 0.25,
			"filter/mipmap padding remains inside the same tan family")
	var spot_uv := SlopeAtlas.path_spot_uv()
	assert_almost_eq(spot_uv.x, uv.x, 0.0001)
	assert_between(spot_uv.y, 0.25, 0.5,
		"stylized path spots stay inside the same padded tan swatch")
	var spot := image.get_pixel(int(spot_uv.x * image.get_width()),
		int(spot_uv.y * image.get_height()))
	assert_lt(spot.get_luminance(), centre.get_luminance(),
		"spots use a slightly darker tan than the original path")
	assert_lt(Vector3(spot.r, spot.g, spot.b).distance_to(
		Vector3(centre.r, centre.g, centre.b)), 0.1,
		"spot shade remains close to the original path tan")
