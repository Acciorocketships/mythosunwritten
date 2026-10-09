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
	old.imposter.geometry_signature = EnvironmentImposter.geometry_signature_of(fresh)
	ResourceSaver.save(old, path)
	BAKE._carry_imposter(path, fresh)
	assert_not_null(fresh.imposter, "a headless re-bake must not drop every imposter")
	assert_eq(fresh.imposter.frames, 6)
	# The same tree re-baked at another scale is a different card: drop it.
	var rescaled := EnvironmentVisual.new()
	var piece := EnvironmentVisualPiece.new()
	piece.mesh = BoxMesh.new()
	piece.local_transform = Transform3D.IDENTITY.scaled(Vector3.ONE * 1.3)
	rescaled.pieces = [piece]
	BAKE._carry_imposter(path, rescaled)
	assert_null(rescaled.imposter, "a stale imposter (geometry changed) must not be carried")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(dir)

## The baked atlases are BC7: decompress before reading texels.
func _image(texture: Texture2D) -> Image:
	var image := texture.get_image()
	if image.is_compressed():
		image.decompress()
	return image

func _headless() -> bool:
	return DisplayServer.get_name() == "headless"

const OAK := "res://terrain/environment/visuals/angry_mesh_meadow/meadow_oak_01_summer.tres"
const BIRCH := "res://terrain/environment/visuals/angry_mesh_meadow/meadow_birch_05_summer.tres"
## IMPOSTER_DUMP=1 writes review copies of the captured atlases here (look at
## them after a capture change).
const REVIEW_DIR := "/private/tmp/imposter-oak"

func _dump(imposter: EnvironmentImposter, name: String) -> void:
	if OS.get_environment("IMPOSTER_DUMP") != "1":
		return
	DirAccess.make_dir_recursive_absolute(REVIEW_DIR)
	_image(imposter.albedo).save_png("%s/%s_albedo.png" % [REVIEW_DIR, name])
	_image(imposter.normal).save_png("%s/%s_normal.png" % [REVIEW_DIR, name])

## Fewest empty pixels between any frame's covered texels and its border.
func _min_margin(imposter: EnvironmentImposter, px: int) -> int:
	var albedo := _image(imposter.albedo)
	var margin := px
	for f in imposter.frames:
		for y in px:
			for x in px:
				if albedo.get_pixel(f * px + x, y).a > 0.5:
					margin = mini(margin, mini(mini(x, px - 1 - x), mini(y, px - 1 - y)))
	return margin

## Mean tint response (normal alpha) over covered texels of frame 0 in a box.
func _response(imposter: EnvironmentImposter, box: Rect2i) -> float:
	var albedo := _image(imposter.albedo)
	var normal := _image(imposter.normal)
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
	var albedo := _image(imposter.albedo)
	_dump(imposter, "oak")
	assert_eq(albedo.get_width(), 128 * 8)
	assert_eq(albedo.get_height(), 128)
	assert_eq(imposter.size.x, imposter.size.y, "a square frame maps undistorted onto the runtime quad")
	assert_gte(_min_margin(imposter, 128), 8, "every frame keeps an empty border")
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

func test_capture_frames_a_tall_tree_about_its_vertical_axis() -> void:
	if _headless():
		pass_test("needs a renderer")
		return
	const CAPTURE := preload("res://tools/environment_bake/imposter_capture.gd")
	var visual := load(BIRCH) as EnvironmentVisual
	var imposter: EnvironmentImposter = await CAPTURE.capture(get_tree(), visual, 128)
	_dump(imposter, "birch")
	assert_gte(_min_margin(imposter, 128), 8, "every frame keeps an empty border")
	# The trunk base sits on the axis the runtime billboard turns about, so it
	# stays at the frame's centre column from every azimuth.
	var albedo := _image(imposter.albedo)
	for f in imposter.frames:
		var low := -1
		var sum := 0
		var count := 0
		for y in range(127, -1, -1):
			for x in 128:
				if albedo.get_pixel(f * 128 + x, y).a > 0.5:
					if low < 0: low = y
					if y > low - 4:
						sum += x
						count += 1
		assert_almost_eq(float(sum) / maxf(count, 1), 63.5, 4.0, "frame %d trunk base on the axis" % f)

func test_every_baked_tree_has_an_imposter_inside_the_environment_tree() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var missing: Array[String] = []
	for id: StringName in catalog.ids():
		var descriptor := catalog.descriptor(id)
		if not descriptor.tags.has(&"tree"):
			continue
		var visual := load(descriptor.visual_path) as EnvironmentVisual
		if visual.imposter == null or visual.imposter.albedo == null or visual.imposter.normal == null:
			missing.append(String(id))
			continue
		for texture: Texture2D in [visual.imposter.albedo, visual.imposter.normal]:
			assert_true(texture.resource_path.begins_with("res://terrain/environment/textures/"),
				"%s imposter texture lives in the generated tree: %s" % [id, texture.resource_path])
		assert_eq(visual.imposter.albedo.get_width(), visual.imposter.albedo.get_height() * visual.imposter.frames,
			"%s atlas holds its frames side by side" % id)
	assert_eq(missing, [], "trees without an imposter (run the bake with --imposters-only)")

const IMPOSTER_SHADER := "res://terrain/environment/materials/tree_imposter.gdshader"

func test_imposter_shader_billboards_blends_frames_and_tints_by_response() -> void:
	var code := (load(IMPOSTER_SHADER) as Shader).code
	for needle in ["render_mode", "cull_disabled", "ALPHA_SCISSOR_THRESHOLD", "MODEL_MATRIX",
			"frames", "normal_atlas", "COLOR.rgb", "mix(vec3(1.0), COLOR.rgb"]:
		assert_true(code.contains(needle), "imposter shader: " + needle)
	assert_false(code.contains("INSTANCE_CUSTOM"), "custom data carries the tactical footprint")

## IMPOSTER_DUMP=1 writes the runtime renders here.
const RENDER_DIR := "/private/tmp/imposter-render"
const RENDER_PX := 192
const INSTANCE_SCALE := 1.2
const INSTANCE_YAW := 0.7

func _imposter_material(imposter: EnvironmentImposter) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load(IMPOSTER_SHADER)
	material.set_shader_parameter(&"albedo_atlas", imposter.albedo)
	material.set_shader_parameter(&"normal_atlas", imposter.normal)
	material.set_shader_parameter(&"frames", imposter.frames)
	material.set_shader_parameter(&"frame_size", imposter.size)
	material.set_shader_parameter(&"pivot_height", imposter.pivot_height)
	return material

## One imposter instance (yawed, scaled, tinted) through a MultiMesh, seen
## from `azimuth` at `elevation` degrees, lit by a sun and ambient light.
## `sun_offset` turns the sun about the vertical from the camera's azimuth
## (+PI/2: low sun from the camera's right).
func _render_imposter(imposter: EnvironmentImposter, azimuth: float, elevation: float,
		tint: Color, distance: float, sun_offset := 0.6) -> Dictionary:
	var view := SubViewport.new()
	view.size = Vector2i(RENDER_PX, RENDER_PX)
	view.own_world_3d = true
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	multimesh.mesh = quad
	multimesh.instance_count = 1
	multimesh.set_instance_transform(0, Transform3D(Basis(Vector3.UP, INSTANCE_YAW).scaled(Vector3.ONE * INSTANCE_SCALE), Vector3.ZERO))
	multimesh.set_instance_color(0, tint)
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.material_override = _imposter_material(imposter)
	view.add_child(instance)
	var sun := DirectionalLight3D.new()
	view.add_child(sun)
	var sun_from := Vector3(sin(azimuth + sun_offset), 0.6, cos(azimuth + sun_offset))
	sun.look_at_from_position(sun_from, Vector3.ZERO, Vector3.UP)
	var environment := Environment.new()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.5, 0.55, 0.6)
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	view.add_child(world_environment)
	var camera := Camera3D.new()
	camera.fov = 40.0
	view.add_child(camera)
	add_child(view)
	var centre_y := (imposter.pivot_height + 0.5 * imposter.size.y) * INSTANCE_SCALE
	var e := deg_to_rad(elevation)
	var eye := Vector3(sin(azimuth) * cos(e), sin(e), cos(azimuth) * cos(e)) * distance + Vector3(0.0, centre_y, 0.0)
	camera.look_at_from_position(eye, Vector3(0.0, centre_y, 0.0), Vector3.UP)
	camera.current = true
	for frame in 5:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := view.get_texture().get_image()
	var base := camera.unproject_position(Vector3.ZERO)
	view.free()
	return {"image": image, "base": base}

## Mean luminance of covered crown pixels (upper 60%) in the (left, right) halves.
func _halves(image: Image) -> Vector2:
	var sums := Vector2.ZERO
	var counts := Vector2.ZERO
	for y in int(image.get_height() * 0.6):
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			if c.a > 0.5:
				var side := 0 if x < image.get_width() / 2 else 1
				sums[side] += c.get_luminance()
				counts[side] += 1.0
	return Vector2(sums.x / maxf(counts.x, 1.0), sums.y / maxf(counts.y, 1.0))

## (covered pixel count, lowest covered row, mean luminance of covered pixels).
func _coverage(image: Image) -> Vector3:
	var count := 0
	var lowest := -1
	var luminance := 0.0
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			if c.a > 0.5:
				count += 1
				lowest = maxi(lowest, y)
				luminance += c.get_luminance()
	return Vector3(count, lowest, luminance / maxf(count, 1))

## The lowest covered texel of frame 0, in asset metres above the origin.
func _baked_base(imposter: EnvironmentImposter) -> float:
	var albedo := _image(imposter.albedo)
	var px := albedo.get_height()
	for y in range(px - 1, -1, -1):
		for x in px:
			if albedo.get_pixel(x, y).a > 0.5:
				return imposter.pivot_height + (1.0 - (y + 1.0) / px) * imposter.size.y
	return imposter.pivot_height

func test_imposter_renders_lit_tinted_and_rooted_from_every_side() -> void:
	if _headless():
		pass_test("needs a renderer")
		return
	var imposter := (load(OAK) as EnvironmentVisual).imposter
	var distance := imposter.size.y * INSTANCE_SCALE * 1.6
	# Up close the card yields to its tree (per-instance crossfade): switch at 0 m.
	var switch := EnvironmentCommitQueue.IMPOSTER_DISTANCE
	EnvironmentCommitQueue.set_imposter_distance(0.0)
	var base_m := _baked_base(imposter) * INSTANCE_SCALE
	for azimuth in [0.0, 2.1, 4.4]:
		var shot: Dictionary = await _render_imposter(imposter, azimuth, 8.0, Color.WHITE, distance)
		var image: Image = shot["image"]
		if OS.get_environment("IMPOSTER_DUMP") == "1":
			DirAccess.make_dir_recursive_absolute(RENDER_DIR)
			image.save_png("%s/oak_az%.1f.png" % [RENDER_DIR, azimuth])
		var stats := _coverage(image)
		assert_gt(stats.x, RENDER_PX * RENDER_PX * 0.08, "azimuth %.1f: the crown covers the view" % azimuth)
		assert_gt(stats.z, 0.12, "azimuth %.1f: the imposter is lit, not black" % azimuth)
		# The trunk base stands where the instance origin projects (the baked
		# base is at most a few centimetres off the origin), so pivot_height,
		# frame_size and the instance scale all place the card correctly.
		var base: Vector2 = shot["base"]
		var expected_row := base.y - base_m / (2.0 * distance * tan(deg_to_rad(20.0))) * RENDER_PX
		assert_almost_eq(stats.y, expected_row, 4.0, "azimuth %.1f: trunk base on the instance origin" % azimuth)
		# The baked normals, rotated through frame azimuth and instance yaw,
		# light the crown on the sun's side: a low sun from the camera's right
		# brightens the right half relative to the same sun from the left
		# (the ratio cancels the baked albedo).
		var from_right: Dictionary = await _render_imposter(imposter, azimuth, 8.0, Color.WHITE, distance, PI / 2.0)
		var from_left: Dictionary = await _render_imposter(imposter, azimuth, 8.0, Color.WHITE, distance, -PI / 2.0)
		var right := _halves(from_right["image"])
		var left := _halves(from_left["image"])
		assert_gt(right.y / left.y, 1.15 * right.x / left.x,
			"azimuth %.1f: the sunlit half is brighter (sun right %s, sun left %s)" % [azimuth, right, left])
	# The tint multiplies through the baked response (leaves and this oak's bark ~1).
	var white: Dictionary = await _render_imposter(imposter, 0.0, 8.0, Color.WHITE, distance)
	var grey: Dictionary = await _render_imposter(imposter, 0.0, 8.0, Color(0.4, 0.4, 0.4), distance)
	assert_lt(_coverage(grey["image"]).z, _coverage(white["image"]).z * 0.8, "the instance tint darkens the crown")
	# Seen from overhead the card dissolves instead of collapsing to a line.
	var top: Dictionary = await _render_imposter(imposter, 0.0, 80.0, Color.WHITE, distance)
	assert_lt(_coverage(top["image"]).x, 20.0, "top-down view fades the card out")
	# Nearer than the switch the card draws nothing: the tree owns every cell.
	EnvironmentCommitQueue.set_imposter_distance(distance + 2.0 * EnvironmentCommitQueue.IMPOSTER_FADE)
	var yielded: Dictionary = await _render_imposter(imposter, 0.0, 8.0, Color.WHITE, distance)
	assert_lt(_coverage(yielded["image"]).x, 20.0, "inside the switch distance the card yields to its tree")
	EnvironmentCommitQueue.set_imposter_distance(switch)

func test_crossfade_has_leaf_sized_patches_instead_of_a_pixel_dot_grid() -> void:
	if _headless():
		pass_test("needs a renderer")
		return
	var imposter := (load(OAK) as EnvironmentVisual).imposter
	var distance := imposter.size.y * INSTANCE_SCALE * 1.6
	var saved := EnvironmentCommitQueue.IMPOSTER_DISTANCE
	EnvironmentCommitQueue.set_imposter_distance(0.0)
	var full: Image = (await _render_imposter(imposter,0.0,8.0,Color.WHITE,distance)).image
	var centre := (imposter.pivot_height + .5 * imposter.size.y) * INSTANCE_SCALE
	var eye := Vector3(0.0,centre+sin(deg_to_rad(8.0))*distance,cos(deg_to_rad(8.0))*distance)
	EnvironmentCommitQueue.set_imposter_distance(eye.length())
	var half: Image = (await _render_imposter(imposter,0.0,8.0,Color.WHITE,distance)).image
	EnvironmentCommitQueue.set_imposter_distance(saved)
	var pairs := 0
	var transitions := 0
	var covered := 0
	for y in full.get_height():
		for x in range(full.get_width()-1):
			if full.get_pixel(x,y).a < .99 or full.get_pixel(x+1,y).a < .99:continue
			pairs += 1
			var a := half.get_pixel(x,y).a > .5
			var b := half.get_pixel(x+1,y).a > .5
			if a: covered += 1
			if a != b:transitions += 1
	assert_gt(pairs,1000,"measure inside the full crown, excluding leaf silhouette edges")
	assert_between(float(covered)/pairs,.25,.75,"both representations still receive a substantial share halfway through")
	assert_lt(float(transitions)/pairs,.25,"the handover cannot alternate visible/absent pixels across the crown")
