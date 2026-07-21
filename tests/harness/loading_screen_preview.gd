extends Node
## Rendered smoke test for the atlas loading screen.
##
## Run with a rendering context:
##   godot --path . res://tests/harness/loading_screen_preview.tscn

const OUT_PATH: String = "user://mythos_loading_screen_preview.png"
const CLOUD_A_PATH: String = "user://mythos_loading_clouds_a.png"
const CLOUD_B_PATH: String = "user://mythos_loading_clouds_b.png"
const RIVER_A_PATH: String = "user://mythos_loading_river_a.png"
const RIVER_B_PATH: String = "user://mythos_loading_river_b.png"
const SETTLE_FRAMES: int = 8
const SAMPLE_STEP: int = 20


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	for _frame in range(SETTLE_FRAMES):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var first := get_viewport().get_texture().get_image()
	await get_tree().create_timer(1.4).timeout
	await RenderingServer.frame_post_draw
	var second := get_viewport().get_texture().get_image()
	var cloud_tl_delta := _sample_region_delta(first, second,
		Rect2(0.02, 0.02, 0.31, 0.28))
	var cloud_tr_delta := _sample_region_delta(first, second,
		Rect2(0.70, 0.02, 0.28, 0.30))
	var cloud_bl_delta := _sample_region_delta(first, second,
		Rect2(0.02, 0.62, 0.25, 0.30))
	var cloud_br_delta := _sample_region_delta(first, second,
		Rect2(0.73, 0.58, 0.25, 0.34))
	var left_city_delta := _sample_region_delta(first, second,
		Rect2(0.12, 0.40, 0.28, 0.34))
	var right_city_delta := _sample_region_delta(first, second,
		Rect2(0.79, 0.27, 0.19, 0.34))
	var river_delta := _sample_region_delta(first, second,
		Rect2(0.17, 0.36, 0.43, 0.47))
	var chart_delta := _sample_region_delta(first, second,
		Rect2(0.68, 0.02, 0.28, 0.26))
	var title_delta := _sample_title_delta(first, second)
	var save_error := second.save_png(OUT_PATH)

	# Isolate each disputed channel. The old broad samples could pass because a
	# chart or city moved inside the same rectangle while clouds/river remained
	# visually static. These frames contain only the named component over the
	# plate, so a passing delta now means the requested pixels themselves moved.
	var background := get_node(
		"MythosLoadingScreen/LoadingCanvas/Overlay/Background") as TextureRect
	var material := background.material as ShaderMaterial
	material.set_shader_parameter("city_opacity", 0.0)
	material.set_shader_parameter("chart_opacity", 0.0)
	material.set_shader_parameter("river_opacity", 0.0)
	material.set_shader_parameter("river_overlay_opacity", 0.0)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var cloud_first := get_viewport().get_texture().get_image()
	await get_tree().create_timer(1.4).timeout
	await RenderingServer.frame_post_draw
	var cloud_second := get_viewport().get_texture().get_image()
	var isolated_cloud_delta := _sample_region_delta(cloud_first, cloud_second,
		Rect2(0.0, 0.0, 1.0, 0.90))
	cloud_first.save_png(CLOUD_A_PATH)
	cloud_second.save_png(CLOUD_B_PATH)

	material.set_shader_parameter("cloud_opacity", 0.0)
	material.set_shader_parameter("river_opacity", 1.0)
	material.set_shader_parameter("river_overlay_opacity", 0.84)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var river_first := get_viewport().get_texture().get_image()
	await get_tree().create_timer(1.4).timeout
	await RenderingServer.frame_post_draw
	var river_second := get_viewport().get_texture().get_image()
	var isolated_river_delta := _sample_region_delta(river_first, river_second,
		Rect2(0.12, 0.34, 0.34, 0.48))
	river_first.save_png(RIVER_A_PATH)
	river_second.save_png(RIVER_B_PATH)
	print("[loading-screen] saved=", ProjectSettings.globalize_path(OUT_PATH),
		" cloud_tl=", cloud_tl_delta, " cloud_tr=", cloud_tr_delta,
		" cloud_bl=", cloud_bl_delta, " cloud_br=", cloud_br_delta,
		" left_city=", left_city_delta,
		" right_city=", right_city_delta, " river=", river_delta,
		" chart=", chart_delta, " title=", title_delta,
		" isolated_cloud=", isolated_cloud_delta,
		" isolated_river=", isolated_river_delta)
	if save_error != OK \
			or cloud_tl_delta < 0.00005 \
			or cloud_tr_delta < 0.00005 \
			or cloud_bl_delta < 0.00005 \
			or cloud_br_delta < 0.00005 \
			or left_city_delta < 0.00005 \
			or right_city_delta < 0.00005 \
			or river_delta < 0.00005 \
			or isolated_cloud_delta < 0.0005 \
			or isolated_river_delta < 0.0005 \
			or chart_delta < 0.00005 \
			or title_delta > 0.00002:
		push_error("Loading-screen render smoke test failed.")
		get_tree().quit(1)
	else:
		get_tree().quit()


func _sample_region_delta(first: Image, second: Image, region: Rect2) -> float:
	var difference: float = 0.0
	var samples: int = 0
	var x0 := int(first.get_width() * region.position.x)
	var x1 := int(first.get_width() * region.end.x)
	var y0 := int(first.get_height() * region.position.y)
	var y1 := int(first.get_height() * region.end.y)
	for y in range(y0, y1, SAMPLE_STEP):
		for x in range(x0, x1, SAMPLE_STEP):
			var a := first.get_pixel(x, y)
			var b := second.get_pixel(x, y)
			difference += absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
			samples += 1
	return difference / maxf(float(samples) * 3.0, 1.0)


func _sample_title_delta(first: Image, second: Image) -> float:
	var difference: float = 0.0
	var samples: int = 0
	for y in range(int(first.get_height() * 0.36), int(first.get_height() * 0.62), 12):
		for x in range(int(first.get_width() * 0.33), int(first.get_width() * 0.67), 12):
			var a := first.get_pixel(x, y)
			var luminance := a.r * 0.299 + a.g * 0.587 + a.b * 0.114
			if luminance > 0.58:
				continue
			var b := second.get_pixel(x, y)
			difference += absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
			samples += 1
	return difference / maxf(float(samples) * 3.0, 1.0)
