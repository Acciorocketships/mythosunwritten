extends Node3D

## Maintained catalogue review scene. It renders one stable-ID page at a
## time and can capture deterministic PNGs for review:
##   godot --path /Users/ryko/story res://tests/harness/environment_lineup.tscn \
##     -- --page 0 --capture /tmp/environment-page-0.png
## A rigid asset can be examined from any side with `--asset`, `--view-yaw`,
## `--show-collision`, and `--collision-closeup`. Add
## `--depth-test-collision` to reveal only the parts that escape the visible mesh.
## Headless/source-pack checks can use `--verify-only` to instantiate every
## page without requiring a renderer.

const PAGE_SIZE := 6
const COLUMNS := 3
const CELL := Vector2(24.0, 21.0)

var _catalog: EnvironmentCatalog
var _cache: EnvironmentRenderCache
var _content := Node3D.new()
var _page := 0
var _capture_path := ""
var _verify_only := false
var _show_collisions := false
var _depth_test_collisions := false
var _collision_closeup := false
var _normalize_review_scale := false
var _asset_id := StringName()
var _view_yaw_degrees := 0.0
var _page_label := Label.new()
var _camera := Camera3D.new()

func _ready() -> void:
	_catalog = EnvironmentCatalog.load_default()
	assert(_catalog != null)
	_cache = EnvironmentRenderCache.new(_catalog)
	_read_args()
	_build_stage()
	add_child(_content)
	if _verify_only:
		for page_index in _page_count():
			_page = page_index
			_show_page()
		print("[environment_lineup] verified %d assets across %d pages" % [
			_catalog.size(), _page_count()])
		get_tree().quit()
		return
	_show_page()
	if not _capture_path.is_empty():
		_capture.call_deferred()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_right"):
		_page = mini(_page + 1, _page_count() - 1)
		_show_page()
	elif event.is_action_pressed("ui_left"):
		_page = maxi(_page - 1, 0)
		_show_page()

func _read_args() -> void:
	var args := OS.get_cmdline_user_args()
	var index := 0
	while index < args.size():
		match args[index]:
			"--page":
				if index + 1 < args.size():
					_page = maxi(0, int(args[index + 1]))
					index += 1
			"--capture":
				if index + 1 < args.size():
					_capture_path = args[index + 1]
					index += 1
			"--verify-only":
				_verify_only = true
			"--show-collision":
				_show_collisions = true
			"--depth-test-collision":
				_depth_test_collisions = true
			"--collision-closeup":
				_collision_closeup = true
			"--asset":
				if index + 1 < args.size():
					_asset_id = StringName(args[index + 1])
					index += 1
			"--view-yaw":
				if index + 1 < args.size():
					_view_yaw_degrees = float(args[index + 1])
					index += 1
			"--normalize":
				_normalize_review_scale = true
		index += 1

func _build_stage() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("#9db8c2")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("#d9e7e8")
	settings.ambient_light_energy = 0.75
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = settings
	add_child(environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -32.0, 0.0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)

	_camera.position = Vector3(0.0, 28.0, 41.0)
	_camera.look_at_from_position(_camera.position, Vector3(0.0, 4.0, -8.0))
	_camera.fov = 54.0
	add_child(_camera)

	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2(CELL.x * COLUMNS + 12.0,
		CELL.y * int(ceil(float(PAGE_SIZE) / COLUMNS)) + 14.0)
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color("#6f806c")
	ground_material.roughness = 1.0
	ground_mesh.material = ground_material
	var ground := MeshInstance3D.new()
	ground.mesh = ground_mesh
	ground.position = Vector3(0.0, -0.04, -CELL.y * 0.5)
	add_child(ground)

	var overlay := CanvasLayer.new()
	# macOS/Metal leaves a transient black resize tile in the extreme
	# top-left of programmatic captures; keep the review HUD clear of it.
	_page_label.position = Vector2(350.0, 18.0)
	_page_label.add_theme_font_size_override("font_size", 22)
	_page_label.add_theme_color_override("font_color", Color.WHITE)
	_page_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_page_label.add_theme_constant_override("shadow_offset_x", 2)
	_page_label.add_theme_constant_override("shadow_offset_y", 2)
	overlay.add_child(_page_label)
	add_child(overlay)

func _show_page() -> void:
	for child: Node in _content.get_children():
		_content.remove_child(child)
		child.free()
	var ids := _catalog.ids()
	if not String(_asset_id).is_empty():
		assert(_catalog.has(_asset_id), "Unknown environment asset: %s" % _asset_id)
		assert(_cache.prepare([_asset_id]))
		# Page slot one is the centre column at the front of the stage.
		_add_asset(_asset_id, 1)
		var descriptor := _catalog.descriptor(_asset_id)
		_page_label.text = "Environment collision detail  |  %s  |  %d collider%s" % [
			String(_asset_id), descriptor.collision_piece_count,
			"" if descriptor.collision_piece_count == 1 else "s"]
		_frame_asset(descriptor.measured_aabb)
		return
	_page = clampi(_page, 0, _page_count() - 1)
	var first := _page * PAGE_SIZE
	var last := mini(first + PAGE_SIZE, ids.size())
	var page_ids: Array[StringName] = []
	for index in range(first, last):
		page_ids.append(ids[index])
	assert(_cache.prepare(page_ids))
	for page_index in page_ids.size():
		_add_asset(page_ids[page_index], page_index)
	_page_label.text = "Environment catalogue  |  page %d/%d  |  IDs %d–%d of %d  |  ← / →" % [
		_page + 1, _page_count(), first + 1, last, ids.size()]

func _add_asset(asset_id: StringName, page_index: int) -> void:
	var descriptor := _catalog.descriptor(asset_id)
	var visual := _cache.visual(asset_id)
	assert(descriptor != null and visual != null)
	var column := page_index % COLUMNS
	var row := page_index / COLUMNS
	var cell_origin := Vector3(
		(float(column) - float(COLUMNS - 1) * 0.5) * CELL.x,
		0.0,
		-float(row) * CELL.y)
	var aabb := descriptor.measured_aabb
	var review_scale := 1.0
	if _normalize_review_scale and String(_asset_id).is_empty():
		review_scale = minf(8.5 / maxf(aabb.size.x, aabb.size.z), 11.0 / aabb.size.y)
	var placement := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * review_scale),
		cell_origin + Vector3(
			-(aabb.position.x + aabb.size.x * 0.5) * review_scale,
			-aabb.position.y * review_scale,
			-(aabb.position.z + aabb.size.z * 0.5) * review_scale))
	for piece: EnvironmentVisualPiece in visual.pieces:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = piece.mesh
		mesh_instance.transform = placement * piece.local_transform
		_content.add_child(mesh_instance)
	if _show_collisions:
		for collision: EnvironmentCollisionPiece in visual.collisions:
			var debug_instance := MeshInstance3D.new()
			debug_instance.mesh = collision.shape.get_debug_mesh()
			debug_instance.transform = placement * collision.local_transform
			var debug_material := StandardMaterial3D.new()
			debug_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			debug_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			debug_material.albedo_color = Color(1.0, 0.05, 0.55, 0.38)
			debug_material.cull_mode = BaseMaterial3D.CULL_DISABLED
			debug_material.no_depth_test = not _depth_test_collisions
			debug_instance.material_override = debug_material
			_content.add_child(debug_instance)

	var label := Label3D.new()
	label.text = "%s\n%s\n%.1f × %.1f × %.1f m  |  %d collider%s" % [
		String(asset_id), String(descriptor.provenance_id),
		aabb.size.x, aabb.size.y, aabb.size.z,
		descriptor.collision_piece_count,
		"" if descriptor.collision_piece_count == 1 else "s"]
	label.position = cell_origin + Vector3(0.0, 0.75, 7.0)
	if not String(_asset_id).is_empty():
		label.position = cell_origin + Vector3(0.0, aabb.size.y + 1.2, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 48
	label.pixel_size = 0.015
	label.modulate = Color("#f2f6eb")
	label.outline_modulate = Color("#152018")
	label.outline_size = 6
	_content.add_child(label)

	# One-metre review marker makes source-pack scale errors immediately visible.
	var marker_mesh := BoxMesh.new()
	marker_mesh.size = Vector3(0.12, 1.0, 0.12)
	var marker_material := StandardMaterial3D.new()
	marker_material.albedo_color = Color("#f7d75c")
	marker_mesh.material = marker_material
	var marker := MeshInstance3D.new()
	marker.mesh = marker_mesh
	marker.position = cell_origin + Vector3(-10.5, 0.5, 7.0)
	if not _normalize_review_scale:
		_content.add_child(marker)
	else:
		marker.free()

func _frame_asset(aabb: AABB) -> void:
	var focus := Vector3(0.0, aabb.size.y * 0.48, 0.0)
	var extent := maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	if _collision_closeup:
		focus.y = minf(3.2, aabb.size.y * 0.3)
		extent = minf(extent, 8.0)
	var distance := maxf(4.0, extent * 2.6)
	var view_direction := Vector3(0.9, 0.55, 1.0).normalized() \
		.rotated(Vector3.UP, deg_to_rad(_view_yaw_degrees))
	_camera.look_at_from_position(focus + view_direction * distance, focus)

func _page_count() -> int:
	return maxi(1, int(ceil(float(_catalog.size()) / PAGE_SIZE)))

func _capture() -> void:
	for unused in 8:
		await get_tree().process_frame
	# Mesh/material uploads and Metal's resized-window tiles complete
	# asynchronously; a real-time settle makes captured pages reviewable.
	await get_tree().create_timer(1.5).timeout
	RenderingServer.force_draw()
	await get_tree().process_frame
	var captured_image: Image = get_viewport().get_texture().get_image()
	if captured_image == null:
		push_error("Lineup capture requires a rendering backend")
		get_tree().quit(1)
		return
	var error := captured_image.save_png(_capture_path)
	assert(error == OK, "Could not save lineup capture: %s" % _capture_path)
	print("[environment_lineup] page %d saved to %s" % [_page, _capture_path])
	get_tree().quit()
