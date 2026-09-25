extends "res://tests/harness/september11_movement_qa.gd"
const BEFORE := preload("res://tests/fixtures/september11/BubbleBefore.gd")
var _capture_view: SubViewport

func _show_capture_view() -> void:
	# Display the actual capture target in the native game window.
	var layer := CanvasLayer.new()
	add_child(layer)
	var display := TextureRect.new()
	display.size = Vector2(1920,1080)
	display.texture = _capture_view.get_texture()
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(display)

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.has("--offscreen") or args.has("--frozen"):
		super._ready()
		return
	# Live workers stay in their original scene tree throughout capture.
	# Reparenting a loaded world invokes its shutdown hooks.
	Engine.max_fps = 30
	_read_args()
	DirAccess.make_dir_recursive_absolute(_output_dir)
	get_window().size = Vector2i(1920,1080)
	_capture_view = SubViewport.new()
	_capture_view.size = Vector2i(1920,1080)
	_capture_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_capture_view)
	_show_capture_view()
	var world := (load("res://scenes/world.tscn") as PackedScene).instantiate()
	_streamer = world.find_child("FieldTerrain",true,false) as FieldTerrainStreamer
	_character = world.find_child("Character",true,false) as CharacterBody3D
	_streamer.SEED_OVERRIDE = WORLD_SEED
	_streamer.PROFILE_STREAMING = args.has("--profile")
	_streamer.CHUNK_RADIUS = 1
	_streamer.KEEP_RADIUS = 2
	_streamer.GRASS_ENABLED = _grass_enabled()
	_character.position = Vector3(_spot[2])+Vector3.UP*4.0
	_character.set_physics_process(false)
	_capture_view.add_child(world)
	_run.call_deferred()

func _run() -> void:
	await get_tree().create_timer(5.0).timeout
	_camera = _capture_view.get_camera_3d() if _capture_view != null else get_viewport().get_camera_3d()
	_camera.set_physics_process(false)
	_camera.set_process_input(false)
	_camera.set_process_unhandled_input(false)
	if not _frozen:
		print("BUBBLE_WAIT_SITE")
		assert(await _wait_for_site())
	print("BUBBLE_SITE_READY")
	_character.set_physics_process(false)
	_camera._visibility.clear()
	if OS.get_cmdline_user_args().has("--marker"):
		var layer := CanvasLayer.new()
		add_child(layer)
		var marker := ColorRect.new()
		marker.color = Color.WHITE
		marker.size = Vector2(24,24)
		layer.add_child(marker)
	var world := _character.get_parent().get_parent()
	if OS.get_cmdline_user_args().has("--offscreen") and _capture_view == null:
		_capture_view = SubViewport.new()
		_capture_view.size = Vector2i(1920,1080)
		_capture_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(_capture_view)
		_show_capture_view()
		world.reparent(_capture_view)
		_camera.make_current()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	print("BUBBLE_WORLD_PAUSED")
	_character.anim_tree.active = false
	var output := _output_dir
	var poses := []
	for spot: Array in ([_spot] if OS.get_cmdline_user_args().has("--single") else _spots()):
		_character.global_position = spot[2]
		_character.step_visual_offset_y = 0.0
		_character._update_step_visual_smoothing(0.0)
		var eye := ReviewCam.solve_cam(spot[2],spot[3],26.0,16.0,1.0)
		for angle: float in [0.0,-8.0,8.0]:
			_camera.global_position = Vector3(spot[2])+(eye-Vector3(spot[2])).rotated(Vector3.UP,deg_to_rad(angle))
			_camera.look_at(Vector3(spot[2])+Vector3.UP)
			var radius := CameraVisibilityBubble.screen_radius(_camera,spot[2],.5)
			poses.append({"spot":spot[0],"angle":angle,"camera":str(_camera.global_transform),"player":str(spot[2]),"radius":radius})
			for before: bool in [true,false]:
				var bubble: Node = BEFORE.new() if before else CameraVisibilityBubble.new()
				if before and OS.get_cmdline_user_args().has("--archived-original"):
					bubble.free()
					bubble = preload("res://tests/fixtures/september11/VisibilityArchive.gd").new()
				add_child(bubble)
				for frame in 12:
					bubble.update_bubble(_camera,_character,spot[2],3.8 if before else radius,.12,.1)
					await get_tree().process_frame
				_output_dir = output.path_join("before" if before else "after")
				DirAccess.make_dir_recursive_absolute(_output_dir)
				print("BUBBLE_READY_TO_DRAW ",spot[0]," ",angle," before=",before)
				await _shot("%s_%d" % [spot[0],int(angle)])
				print("BUBBLE_CAPTURE before=",before," active=",bubble._active.size()," materials=",bubble._materials.size()," visible=",get_window().visible," minimized=",get_window().mode==Window.MODE_MINIMIZED)
				bubble.clear()
				bubble.free()
	FileAccess.open(output+"/poses.json",FileAccess.WRITE).store_string(JSON.stringify(poses,"  "))
	if _frozen: _streamer.free()
	get_tree().quit()

func _request_capture_draw() -> void:
	RenderingServer.force_draw(true)

func _shot(label: String) -> void:
	if _capture_view == null:
		await get_tree().process_frame
		_request_capture_draw.call_deferred()
		await RenderingServer.frame_post_draw
		assert(get_viewport().get_texture().get_image().save_png(_output_dir.path_join(label+".png")) == OK)
		print("WINDOW_CAPTURE ",_output_dir.path_join(label+".png"))
		if OS.get_cmdline_user_args().has("--pause-on-black"):
			var saved := Image.load_from_file(_output_dir.path_join(label+".png"))
			var black := true
			for x in [10,480,960,1440,1900]:
				for y in [10,270,540,810,1070]:
					var pixel := saved.get_pixel(x,y)
					if maxf(pixel.r,maxf(pixel.g,pixel.b)) > .01: black = false
			if black:
				print("BLACK_CAPTURE_PAUSE ",_output_dir.path_join(label+".png"))
				await get_tree().create_timer(45.0).timeout
		return
	await get_tree().process_frame
	_request_capture_draw.call_deferred()
	await RenderingServer.frame_post_draw
	var image := _capture_view.get_texture().get_image()
	assert(image.save_png(_output_dir.path_join(label+".png")) == OK)
	print("SUBVIEW_CAPTURE ",_output_dir.path_join(label+".png"))
