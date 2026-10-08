extends GutTest

const BAKE := preload("res://tools/environment_bake/environment_bake.gd")

func test_visual_carries_an_optional_imposter() -> void:
	var visual := EnvironmentVisual.new()
	assert_null(visual.imposter)
	visual.imposter = EnvironmentImposter.new()
	assert_eq(visual.imposter.frames, 8)

func test_a_rebake_without_the_pass_keeps_the_baked_imposter() -> void:
	var dir := "user://imposter_carry_test"
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir + "/visual.tres"
	var old := EnvironmentVisual.new()
	old.imposter = EnvironmentImposter.new()
	old.imposter.frames = 6
	ResourceSaver.save(old, path)
	var fresh := EnvironmentVisual.new()
	BAKE._carry_imposter(path, fresh)
	assert_not_null(fresh.imposter, "a headless re-bake must not drop every imposter")
	assert_eq(fresh.imposter.frames, 6)
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(dir)

func _headless() -> bool:
	return DisplayServer.get_name() == "headless"

const OAK := "res://terrain/environment/visuals/angry_mesh_meadow/meadow_oak_01_summer.tres"
## Review copies of the captured atlases (look at them after a capture change).
const REVIEW_DIR := "/private/tmp/imposter-oak"

## Mean tint response (normal alpha) over covered texels of frame 0 in a box.
func _response(imposter: EnvironmentImposter, box: Rect2i) -> float:
	var albedo := imposter.albedo.get_image()
	var normal := imposter.normal.get_image()
	var total := 0.0
	var count := 0
	for y in range(box.position.y, box.end.y):
		for x in range(box.position.x, box.end.x):
			if albedo.get_pixel(x, y).a > 0.5:
				total += normal.get_pixel(x, y).a
				count += 1
	assert_gt(count, 0, "the probe box %s holds covered texels" % box)
	return total / maxf(count, 1)

func test_capture_keeps_full_crowns_and_measures_tint_response() -> void:
	if _headless():
		pass_test("needs a renderer")
		return
	const CAPTURE := preload("res://tools/environment_bake/imposter_capture.gd")
	var visual := load(OAK) as EnvironmentVisual
	var imposter: EnvironmentImposter = await CAPTURE.capture(get_tree(), visual, 128)
	assert_eq(imposter.frames, 8)
	var albedo := imposter.albedo.get_image()
	var normal := imposter.normal.get_image()
	DirAccess.make_dir_recursive_absolute(REVIEW_DIR)
	albedo.save_png(REVIEW_DIR + "/albedo.png")
	normal.save_png(REVIEW_DIR + "/normal.png")
	assert_eq(albedo.get_width(), 128 * 8)
	assert_eq(albedo.get_height(), 128)
	assert_eq(imposter.size.x, imposter.size.y, "a square frame maps undistorted onto the runtime quad")
	# Coverage in every frame: a thinned or killed crown shows up here.
	for f in 8:
		var covered := 0
		for y in range(0, 128, 2):
			for x in range(0, 128, 2):
				if albedo.get_pixel(f * 128 + x, y).a > 0.5: covered += 1
		assert_gt(covered, 600, "frame %d keeps its crown (no shadow-pass thinning)" % f)
	# The response is measured from the real materials, not assumed: painted
	# leaves multiply COLOR, and this oak's bark material (vertex colour as
	# albedo) multiplies the instance colour too, exactly as at runtime.
	assert_gt(_response(imposter, Rect2i(48, 20, 32, 20)), 0.9, "upper crown follows the tint")
	assert_gt(_response(imposter, Rect2i(56, 104, 16, 16)), 0.9, "this oak's bark follows the tint at runtime")
	# A piece drawn without instance colour ignores the tint entirely.
	var untinted := visual.duplicate(true) as EnvironmentVisual
	for piece: EnvironmentVisualPiece in untinted.pieces:
		piece.use_instance_color = false
	var plain: EnvironmentImposter = await CAPTURE.capture(get_tree(), untinted, 128)
	assert_lt(_response(plain, Rect2i(48, 20, 32, 20)), 0.1, "no instance colour, no response")
	assert_lt(_response(plain, Rect2i(56, 104, 16, 16)), 0.1, "no instance colour, no response")
