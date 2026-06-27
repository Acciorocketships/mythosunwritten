# tests/test_slope_atlas.gd
extends GutTest

func test_grass_uv_in_range() -> void:
	var uv := SlopeAtlas.grass_uv()
	assert_between(uv.x, 0.0, 1.0)
	assert_between(uv.y, 0.0, 1.0)

func test_grass_uv_samples_green() -> void:
	# The sampled texel in the forest palette must read as green (G dominant).
	var uv := SlopeAtlas.grass_uv()
	var tex := load("res://assets/KayKitNature/Assets/gltf/Color1/forest_texture.png") as Texture2D
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
