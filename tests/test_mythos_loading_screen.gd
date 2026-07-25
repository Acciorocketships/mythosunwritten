extends GutTest

const LOADING_SCREEN_SCENE: PackedScene = preload(
	"res://ui/loading_screens/mythos_loading_screen.tscn")
const LOADING_SHADER: Shader = preload(
	"res://ui/loading_screens/mythos_loading_screen.gdshader")


func test_scene_has_animated_atlas_and_progress_contract() -> void:
	var screen := LOADING_SCREEN_SCENE.instantiate() as MythosLoadingScreen
	screen.auto_start = false
	add_child_autofree(screen)
	await wait_process_frames(1)
	var canvas := screen.get_node("LoadingCanvas") as CanvasLayer
	var background := screen.get_node("LoadingCanvas/Overlay/Background") as TextureRect
	var progress := screen.get_node(
		"LoadingCanvas/Overlay/ProgressBar") as MythosTaperedProgressBar
	assert_eq(canvas.layer, 100, "loading art stays above the live world CanvasLayers")
	assert_not_null(background.texture)
	assert_true(background.material is ShaderMaterial)
	var material := background.material as ShaderMaterial
	assert_eq(material.shader, LOADING_SHADER)
	var plate := material.get_shader_parameter("background_plate") as Texture2D
	assert_true(plate.resource_path.ends_with(
		"mythos_mythic_atlas_background_cloudless.png"),
		"moving clouds must not sit over a stationary baked duplicate")
	assert_gt(float(material.get_shader_parameter("cloud_drift")), 0.01,
		"cloud displacement is subtle but visibly larger than texture shimmer")
	assert_lt(float(material.get_shader_parameter("river_flow_width")), 0.65,
		"animated texture stays inside the stationary painted river banks")
	assert_lt(float(material.get_shader_parameter("river_wave_strength")), 0.08,
		"far-away wavelets remain subtle")
	assert_gt(float(material.get_shader_parameter("river_wave_frequency")), 800.0,
		"far-away wavelets are small and closely spaced")
	assert_almost_eq(progress.fill_thickness, 1.35, 0.001)
	assert_eq(progress.progress, 0.0)
	assert_eq(progress.rotation, 0.0)
	assert_null(progress.material,
		"the real progress Control is outside every animated shader transform")
	assert_eq(screen.target_scene_path, "res://scenes/world.tscn")


func test_shader_keeps_motion_channels_independently_tunable() -> void:
	var uniform_names: Array[String] = []
	for property: Dictionary in LOADING_SHADER.get_shader_uniform_list():
		uniform_names.append(String(property.name))
	for required: String in [
		"background_plate", "city_layer", "cloud_layer", "chart_layer",
		"cloud_speed", "cloud_drift", "cloud_opacity", "city_speed", "city_drift",
		"water_speed", "water_strength", "river_opacity",
		"river_overlay_opacity", "river_flow_width", "river_wave_strength",
		"river_wave_frequency", "chart_speed", "chart_opacity",
	]:
		assert_has(uniform_names, required)
	assert_does_not_have(uniform_names, "river_layer",
		"the generated replacement river is no longer used")


func test_shader_rotates_only_the_explicit_chart_texture() -> void:
	var source := LOADING_SHADER.get_code()
	assert_eq(source.count("rotate_atlas_uv("), 2,
		"one definition plus one chart-only call; no other component rotates")
	assert_true(source.contains("texture(chart_layer"))
	assert_true(source.contains("vec2 cloud_offsets[4]"),
		"four cloud groups have independent translation offsets")
	assert_true(source.contains("float river_spine("),
		"river motion follows a hand-fitted local centreline")
	assert_true(source.contains("vec4(original.rgb, river_alpha)"),
		"the base river uses the actual atlas painting")
	assert_true(source.contains("texture(TEXTURE, clamp(flow_uv_a"),
		"the moving overlay scrolls a second sample of the actual atlas texture")
	assert_true(source.contains("float reset_blend = smoothstep(0.80, 1.0, scroll)"),
		"opposing wrap samples cross-fade only near reset instead of cancelling motion")
	assert_true(source.contains("float screen_wave_y = UV.y * river_wave_frequency"),
		"perspective wave fronts are horizontal in screen space, not spline-normal")
	assert_true(source.contains("vec4(moving_river, flow_alpha)"),
		"moving texture uses the narrower inner-channel mask")
	assert_eq(source.count("river_tangent *"), 2,
		"both wraparound samples move along the local river tangent")


func test_bar_progress_reads_integrated_spawn_support_not_elapsed_time() -> void:
	var screen := LOADING_SCREEN_SCENE.instantiate() as MythosLoadingScreen
	screen.auto_start = false
	add_child_autofree(screen)
	await wait_process_frames(1)
	var streamer := FieldTerrainStreamer.new()
	add_child_autofree(streamer)
	streamer._startup_support_chunks = FieldTerrainStreamer.support_chunks_at(Vector3.ZERO)
	screen._startup_streamer = streamer
	screen._waiting_for_spawn = true
	screen._poll_spawn_loading()
	assert_almost_eq(screen._requested_progress,
		MythosLoadingScreen.RESOURCE_LOAD_WEIGHT, 0.0001,
		"the already-loaded scene resource owns the first narrow progress slice")
	var integrated_chunk := Node3D.new()
	add_child_autofree(integrated_chunk)
	streamer._built[streamer._startup_support_chunks[0]] = integrated_chunk
	screen._poll_spawn_loading()
	var quarter := MythosLoadingScreen.RESOURCE_LOAD_WEIGHT \
		+ 0.25 * MythosLoadingScreen.STREAMER_LOAD_WEIGHT
	assert_almost_eq(screen._requested_progress, quarter, 0.0001,
		"one of four support chunks advances the actual streamer slice")
	assert_almost_eq(screen._progress_bar.progress, quarter, 0.0001)
	screen._on_startup_loading_progress_changed(0.5, 2, 4)
	var halfway := MythosLoadingScreen.RESOURCE_LOAD_WEIGHT \
		+ 0.5 * MythosLoadingScreen.STREAMER_LOAD_WEIGHT
	assert_almost_eq(screen._requested_progress, halfway, 0.0001,
		"the readiness signal updates the bar without waiting for player movement")
	assert_almost_eq(screen._progress_bar.progress, halfway, 0.0001)
