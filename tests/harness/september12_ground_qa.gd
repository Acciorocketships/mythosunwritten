extends "res://tests/harness/september11_bubble_qa.gd"
const GROUND_BEFORE := preload("res://tests/fixtures/september12/VisibilityBefore.gd")

func _read_args() -> void:
	super._read_args()
	var args := OS.get_cmdline_user_args()
	if args.has("--single"):
		var index := args.find("--spot")
		assert(index >= 0 and index+1 < args.size(),"A single replay requires --spot followed by its source ID")
		assert(args[index+1] == _spot[0],"Unknown source photo ID")

func _spots() -> Array:
	return [
		["24_spawn", "11.56.57 AM", Vector3(6.5,0,-7.4), Vector3(6.9,1.2,-7.5)],
		["30_heath", "12.27.00 PM", Vector3(-419.6,21.9,-660.4), Vector3(-424.8,28,-653.2)],
		["28_heath", "12.34.46 PM", Vector3(805.8,24,-1860.4), Vector3(796,32,-1853.4)],
		["23_town", "12.35.28 PM", Vector3(956.3,16,-2065.3), Vector3(956.1,17.2,-2064.9)],
		["14_town", "12.01.38 PM", Vector3(-215.1,29.1,-960.0), Vector3(-215.2,30.4,-959.6)]]

func _run() -> void:
	await get_tree().create_timer(5).timeout
	if _frozen:
		_capture_view = SubViewport.new()
		_capture_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(_capture_view)
		_character.get_parent().get_parent().reparent(_capture_view)
		_camera.make_current()
		_show_capture_view()
	assert(_capture_view != null,"Use --offscreen so live workers never reparent")
	_capture_view.size = Vector2i(1716,1033)
	_camera = _capture_view.get_camera_3d()
	_camera.set_physics_process(false)
	_camera.set_process_input(false)
	_camera.set_process_unhandled_input(false)
	var world := _character.get_parent().get_parent()
	var output := _output_dir
	var poses: Array[Dictionary] = []
	for spot: Array in ([_spot] if OS.get_cmdline_user_args().has("--single") else _spots()):
		_spot = spot
		world.process_mode = Node.PROCESS_MODE_INHERIT
		_character.set_physics_process(false)
		_character.global_position = spot[2]
		print("SEPT12_WAIT ",spot[0])
		if not _frozen: assert(await _wait_for_site())
		_camera._visibility.clear()
		_character.set_physics_process(false)
		_character.global_position = spot[2]
		_character.step_visual_offset_y = 0
		_character._update_step_visual_smoothing(0)
		_character.anim_tree.active = false
		# Frozen animation must not remove the collision used by visibility.
		for body: Node in world.find_children("*","CollisionObject3D",true,false):
			body.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
		world.process_mode = Node.PROCESS_MODE_DISABLED
		var site_dir := output.path_join(spot[0])
		DirAccess.make_dir_recursive_absolute(site_dir)
		if not _frozen:
			preload("res://tests/harness/september11_snapshot.gd").save(world,_character,site_dir.path_join("world.scn"))
		# Freeze shader clocks for paired pixel evidence while retaining the
		# actual production geometry and all published shader field textures.
		_freeze_material_clocks(world)
		var eye := ReviewCam.solve_cam(spot[2],spot[3],26,16,1)
		var angles: Array = [0,-8,8]
		var angle_argument := OS.get_cmdline_user_args().find("--angle")
		if angle_argument >= 0:
			angles = [float(OS.get_cmdline_user_args()[angle_argument+1])]
		for angle: float in angles:
			_camera.global_position = Vector3(spot[2])+(eye-Vector3(spot[2])).rotated(Vector3.UP,deg_to_rad(angle))
			_camera.look_at(Vector3(spot[2])+Vector3.UP)
			poses.append({"spot":spot[0],"player":str(spot[2]),"crosshair":str(spot[3]),"angle":angle,"camera":str(_camera.global_transform),"size":str(_capture_view.size)})
			for phase: String in ["opaque","before","after"]:
				var bubble: Node = GROUND_BEFORE.new() if phase == "before" else CameraVisibilityBubble.new()
				add_child(bubble)
				for frame in 16:
					bubble.update_bubble(_camera,_character,spot[2],CameraVisibilityBubble.screen_radius(_camera,spot[2]),.12,.1)
					await get_tree().process_frame
				if phase == "opaque":
					for id: int in bubble._active:
						instance_from_id(id).set_instance_shader_parameter("tactical_strength",0.0)
				_output_dir = site_dir.path_join(phase)
				DirAccess.make_dir_recursive_absolute(_output_dir)
				await _shot("%s_%d"%[spot[0],int(angle)])
				if phase == "after":
					bubble._receivers.texture().get_image().save_png(site_dir.path_join("receiver_%d.png"%int(angle)))
				print("SEPT12_SHOT ",spot[0]," ",angle," ",phase)
				bubble.clear()
				bubble.free()
		FileAccess.open(site_dir.path_join("poses.json"),FileAccess.WRITE).store_string(JSON.stringify(poses,"  "))
		_character.anim_tree.active = true
	FileAccess.open(output.path_join("poses.json"),FileAccess.WRITE).store_string(JSON.stringify(poses,"  "))
	world.process_mode = Node.PROCESS_MODE_INHERIT
	if _frozen: _streamer.free()
	get_tree().quit()

func _freeze_material_clocks(world: Node3D) -> void:
	var materials := {}
	for node: Node in world.find_children("*","GeometryInstance3D",true,false):
		var mesh: Mesh = node.mesh if node is MeshInstance3D else node.multimesh.mesh if node is MultiMeshInstance3D and node.multimesh != null else null
		if node.material_override != null: materials[node.material_override.get_instance_id()] = node.material_override
		if mesh != null:
			for surface in mesh.get_surface_count():
				var material := mesh.surface_get_material(surface)
				if material != null: materials[material.get_instance_id()] = material
	for material: Material in materials.values():
		if material is ShaderMaterial and material.shader != null and material.shader.code.contains("TIME"):
			var shader := Shader.new()
			shader.code = material.shader.code.replace("TIME","0.0")
			material.shader = shader
