extends "res://tests/harness/september11_bubble_qa.gd"
var _view: Viewport
var _bubble: Node
var _label: Label
var _diagnostic_elapsed := 0.0
var _last_tick := -1
var _gpu: CompositorEffect
var _gpu_rows: Array[Dictionary] = []
var _gpu_anomaly_received := false
var _frame_marker: ShaderMaterial
var _pose_ticks: Dictionary = {}
var _invalid_tag_count := 0

func _process(delta: float) -> void:
	if not OS.get_cmdline_user_args().has("--natural-draw"): return
	_diagnostic_elapsed += delta
	if _diagnostic_elapsed < 10.0: return
	_diagnostic_elapsed = 0.0
	print("DRAW_STATE tick=",_last_tick," fps=",Engine.get_frames_per_second()," low_usage=",OS.low_processor_usage_mode," loop=",RenderingServer.is_render_loop_enabled()," focused=",get_window().has_focus()," visible=",get_window().visible)

func _run() -> void:
	await get_tree().create_timer(2.0).timeout
	_camera = get_viewport().get_camera_3d() if _capture_view == null else _capture_view.get_camera_3d()
	if not _frozen:
		assert(await _wait_for_site())
	_character.set_physics_process(false)
	_camera.set_physics_process(false)
	_camera.set_process_input(false)
	_camera.set_process_unhandled_input(false)
	_camera._visibility.clear()
	var world := _character.get_parent().get_parent()
	if not _frozen and OS.get_cmdline_user_args().has("--save-snapshot"):
		preload("res://tests/harness/september11_snapshot.gd").save(world,_character,_output_dir.path_join("village-mist.scn"))
	if OS.get_cmdline_user_args().has("--window"):
		_view = get_viewport()
		if OS.get_cmdline_user_args().has("--retina"): get_window().size = Vector2i(3432,1930)
		if _frozen: world.process_mode = Node.PROCESS_MODE_DISABLED
	elif _frozen:
		_view = SubViewport.new()
		_view.size = Vector2i(3432,1930) if OS.get_cmdline_user_args().has("--retina") else Vector2i(1920,1080)
		_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(_view)
		world.reparent(_view)
		world.process_mode = Node.PROCESS_MODE_DISABLED
	else:
		_view = _capture_view
		if OS.get_cmdline_user_args().has("--retina"): _view.size = Vector2i(3432,1930)
	_camera.make_current()
	_character.anim_tree.active = false
	_character.global_position = _spot[2]
	var overlay := CanvasLayer.new()
	_view.add_child(overlay)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size",12)
	_label.position = Vector2(8,8)
	overlay.add_child(_label)
	if _view != get_viewport():
		var display := TextureRect.new()
		display.size = Vector2(1920,1080)
		display.texture = _view.get_texture()
		display.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(display)
	var args := OS.get_cmdline_user_args()
	FileAccess.open(_output_dir.path_join("launch.json"),FileAccess.WRITE).store_string(JSON.stringify({"arguments":args,"version":Engine.get_version_info(),"embedded":Engine.is_embedded_in_editor()},"  "))
	if args.has("--uncapped"): Engine.max_fps = 0
	if args.has("--present"):
		get_window().always_on_top = true
		get_window().grab_focus()
	if args.has("--gpu-watch"):
		_gpu = preload("res://tests/harness/september11_black_gpu.gd").new()
		_gpu.preview_frames.assign([480,481,482,532,533,1921,5357,5358,5359,5360,6108,6110])
		var compositor := Compositor.new()
		compositor.compositor_effects = [_gpu]
		_camera.compositor = compositor
		if args.has("--frame-marker"):
			_gpu.decode_marker = true
			_add_frame_marker()
	if args.has("--original"):
		_bubble = preload("res://tests/fixtures/september11/VisibilityArchive.gd").new()
	elif args.has("--issue-one"):
		_bubble = preload("res://tests/fixtures/september11/BubbleBefore.gd").new()
	elif args.has("--late-cutout"):
		_bubble = preload("res://tests/fixtures/september11/LateCutout.gd").new()
	else: _bubble = CameraVisibilityBubble.new()
	add_child(_bubble)
	if args.has("--no-local-lights"):
		for node: Node in world.find_children("*","Light3D",true,false):
			if node is OmniLight3D or node is SpotLight3D: node.hide()
	if args.has("--no-post"):
		for node: WorldEnvironment in world.find_children("*","WorldEnvironment",true,false):
			node.environment.ssao_enabled = false
			node.environment.glow_enabled = false
			node.environment.volumetric_fog_enabled = false
	for node: WorldEnvironment in world.find_children("*","WorldEnvironment",true,false):
		if args.has("--no-fog"): node.environment.volumetric_fog_enabled = false
		if args.has("--no-ssao"): node.environment.ssao_enabled = false
		if args.has("--no-glow"): node.environment.glow_enabled = false
	var first_tick := 0
	var first_argument := args.find("--first-tick")
	if first_argument >= 0: first_tick = int(args[first_argument+1])
	var eye := ReviewCam.solve_cam(_spot[2],_spot[3],26,16,1)
	var rows := []
	print("BLACK_CONFIG size=",_view.size," lights=",world.find_children("*","Light3D",true,false).size()," geometry=",world.find_children("*","GeometryInstance3D",true,false).size()," fog_volumes=",world.find_children("*","FogVolume",true,false).size())
	for tick in range(first_tick,first_tick+_ticks):
		_last_tick = tick
		var anchor := Vector3(_spot[2])
		if args.has("--photo-route"):
			var stops := _spots()
			var leg := (tick/180)%stops.size()
			var blend := smoothstep(0.0,1.0,float(tick%180)/179.0)
			anchor = Vector3(stops[leg][2]).lerp(stops[(leg+1)%stops.size()][2],blend)
		_character.global_position = anchor
		var angle := TAU*float(tick)/180.0
		if args.has("--mixed"):
			angle *= 3.0
			_character.global_position += Vector3(sin(tick*.03)*.15,0,cos(tick*.04)*.15)
		_camera.global_position = anchor+(eye-Vector3(_spot[2])).rotated(Vector3.UP,angle)
		if args.has("--mixed") and (tick/120)%2 == 1:
			_camera.global_position = anchor+(_camera.global_position-anchor)*.31
		_camera.look_at(anchor+Vector3.UP)
		if _frame_marker != null:
			_frame_marker.set_shader_parameter("tick",tick)
			_pose_ticks[str(_camera.global_transform)] = tick
		if not args.has("--disabled"):
			_bubble.update_bubble(_camera,_character,anchor,3.8 if args.has("--original") or args.has("--issue-one") else CameraVisibilityBubble.screen_radius(_camera,anchor),.12,1.0/30)
		_label.text = "seed %d | orbit tick %d | %s" % [WORLD_SEED,tick,_spot[0]]
		await get_tree().process_frame
		if not args.has("--natural-draw"): _draw_frame.call_deferred()
		await RenderingServer.frame_post_draw
		if _gpu != null:
			_gpu_anomaly_received = false
			_collect_gpu()
			if _invalid_tag_count >= 30:
				print("GPU_PRESENTATION_FAILED stale_frames=",_invalid_tag_count)
				break
			if tick % 180 == 0: print("GPU_FRAMES ",_gpu_rows.size())
			if tick % 180 != 0 and tick not in [531,532] and not _gpu_anomaly_received: continue
		if args.has("--sparse") and tick % 15 != 0: continue
		var captured := _view.get_texture().get_image()
		var probe := captured.duplicate() as Image
		probe.resize(120,68,Image.INTERPOLATE_NEAREST)
		var black := 0
		for y in range(2,68):
			for x in 120:
				var color := probe.get_pixel(x,y)
				if maxf(color.r,maxf(color.g,color.b)) < .01: black += 1
		var fraction := float(black)/(120*66)
		var partial := fraction > .02 and fraction < .95
		rows.append({"tick":tick,"black_fraction":fraction,"partial":partial,"window_visible":get_window().visible,"window_mode":get_window().mode,"window_focus":get_window().has_focus(),"camera":str(_camera.global_transform),"player":str(_character.global_position),"selected":_bubble._active.size(),"shaders":_bubble._shaders.size()})
		if tick % 45 == 0 or tick in [531,532] or partial or _gpu_anomaly_received or (fraction > .95 and tick % 120 == 0):
			captured.save_png(_output_dir.path_join("%04d.png" % tick))
		if tick % 30 == 0 or partial:
			print("BLACK_ORBIT tick=",tick," fraction=",fraction," partial=",partial)
		if partial:
			# Preserve the first real partial anomaly before changing any controls.
			await _diagnose(world)
			break
	FileAccess.open(_output_dir.path_join("orbit.json"),FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	if _gpu != null:
		_camera.compositor = null
		for frame in 6:
			await get_tree().process_frame
			_draw_frame.call_deferred()
			await RenderingServer.frame_post_draw
		_collect_gpu()
		FileAccess.open(_output_dir.path_join("gpu-frames.json"),FileAccess.WRITE).store_string(JSON.stringify(_gpu_rows,"  "))
	_bubble.clear()
	if _frozen: _streamer.free()
	get_tree().quit()

func _draw_frame() -> void:
	RenderingServer.force_draw(true)

func _collect_gpu() -> void:
	for row: Dictionary in _gpu.take_samples():
		if row.has("rendered_tick"):
			row.expected_tick = _pose_ticks.get(row.camera,-1)
			row.tag_matches = row.rendered_tick == row.expected_tick
			if not row.tag_matches and row.expected_tick >= 0:
				_invalid_tag_count += 1
				if _invalid_tag_count <= 3 or _invalid_tag_count%120 == 0:
					print("GPU_TAG_MISMATCH frame=",row.frame," expected=",row.expected_tick," observed=",row.rendered_tick)
		if row.black > 184 or row.invalid > 0: _gpu_anomaly_received = true
		if row.has("preview"):
			Image.create_from_data(128,72,false,Image.FORMAT_RGBA8,row.preview).save_png(_output_dir.path_join("gpu-%05d.png" % row.frame))
			row.erase("preview")
			print("GPU_ANOMALY " if row.black > 184 or row.invalid > 0 else "GPU_REFERENCE ",row)
		_gpu_rows.append(row)

func _add_frame_marker() -> void:
	# A tiny HDR-visible marker proves the scene image belongs to this camera
	# frame even when the native window is occluded. It is QA-only, three probe
	# samples wide in the top-left, and excluded from photo colour acceptance.
	var marker := MeshInstance3D.new()
	marker.mesh = QuadMesh.new()
	marker.position.z = -1.0
	marker.extra_cull_margin = 16384.0
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shader := Shader.new()
	shader.code = "shader_type spatial; render_mode unshaded, fog_disabled, depth_test_disabled, depth_draw_never, cull_disabled; uniform int tick=0; void vertex() { POSITION=vec4(VERTEX.xy*vec2(.04)+vec2(-.98,-.98),1,1); } void fragment() { ALBEDO=vec3(float((tick&31)+1),float(((tick>>5)&31)+1),float(((tick>>10)&31)+1))/32.0; ALPHA=1.0; }"
	_frame_marker = ShaderMaterial.new()
	_frame_marker.shader = shader
	_frame_marker.render_priority = 127
	marker.material_override = _frame_marker
	_character.add_child(marker)

func _diagnose(world: Node3D) -> void:
	# Keep the anomaly's actual camera transform. Each lighting/history control
	# starts from the original state, and is restored before the next control.
	world.process_mode = Node.PROCESS_MODE_DISABLED
	for index in 3: await _diagnostic_shot("anomaly-hold-%d" % index)
	for environment: WorldEnvironment in world.find_children("*","WorldEnvironment",true,false):
		for property: StringName in [&"volumetric_fog_enabled",&"glow_enabled",&"ssao_enabled"]:
			var saved: Variant = environment.environment.get(property)
			environment.environment.set(property,false)
			await _diagnostic_shot("without-"+String(property))
			environment.environment.set(property,saved)
			await _diagnostic_shot("restored-"+String(property))
	var lights := []
	for light: Light3D in world.find_children("*","Light3D",true,false):
		if (light is OmniLight3D or light is SpotLight3D) and light.visible:
			lights.append(light)
			light.hide()
	await _diagnostic_shot("without-local-lights")
	for light: Light3D in lights: light.show()
	await _diagnostic_shot("restored-local-lights")
	_bubble.clear()
	await _diagnostic_shot("without-bubble")

func _diagnostic_shot(label: String) -> void:
	for frame in 3:
		await get_tree().process_frame
		_draw_frame.call_deferred()
		await RenderingServer.frame_post_draw
	_view.get_texture().get_image().save_png(_output_dir.path_join(label+".png"))
