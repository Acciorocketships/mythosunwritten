extends "res://tests/harness/september15_reported_qa.gd"

const BEFORE_SIM = preload("res://tests/fixtures/september15/water-motion/sim_before.gd")
const QA_DIR := "res://docs/qa/2026-09-15-manual/04-water-motion"

func _capture_views(world:Node3D) -> void:
	await _prepare_review_grass()
	_character.anim_tree.active = false
	_freeze_material_clocks(world)
	_character.global_position = _spot[2]
	_character.step_visual_offset_y = 0
	_character._update_step_visual_smoothing(0)
	var samplers := []
	var seen := {}
	if _frozen:
		samplers = FileAccess.open(QA_DIR+"/native/samplers.bin",FileAccess.READ).get_var()
		for data:Dictionary in samplers:
			var sampler := WaterSampler.new()
			for key:String in data: sampler.set(key,data[key])
			var owner := Node.new()
			world.add_child(owner)
			owner.add_to_group("water_volume")
			owner.set_meta("sampler",sampler)
	else:
		for owner:Node in get_tree().get_nodes_in_group("water_volume"):
			if not owner.has_meta("sampler"): continue
			var sampler:WaterSampler = owner.get_meta("sampler")
			if seen.has(sampler.get_instance_id()): continue
			seen[sampler.get_instance_id()] = true
			var data := {}
			for property:Dictionary in sampler.get_property_list():
				if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE: data[property.name] = sampler.get(property.name)
			samplers.append(data)
		FileAccess.open(_output_dir.path_join("samplers.bin"),FileAccess.WRITE).store_var(samplers)
	print("MOTION_SAMPLERS ",samplers.size())
	var original := WaterSurfaceBuilder.sheet_material()
	var waters := []
	for node:MeshInstance3D in world.find_children("*","MeshInstance3D",true,false):
		if node.is_in_group("tactical_preserve_surface"): waters.append(node)
	print("MOTION_MESHES ",waters.size())
	var output := _output_dir
	var phases := ["before"] if "--baseline-only" in OS.get_cmdline_user_args() else ["before","after"]
	var records := []
	var poses := []
	for phase:String in phases:
		var sim = BEFORE_SIM.new() if phase=="before" else WaterRippleSim.new()
		sim.player = _character
		world.add_child(sim)
		sim.set_process(false)
		RenderingServer.viewport_set_measure_render_time(sim._packet_vp.get_viewport_rid(),true)
		var code := FileAccess.get_file_as_string("res://tests/fixtures/september15/water-motion/water_before.gdshader" if phase=="before" else "res://terrain/water/water_unified.gdshader")
		var shader := Shader.new()
		shader.code = code.replace("TIME","review_time").replace("shader_type spatial;","shader_type spatial;\nuniform float review_time = 0.0;")
		var material := original.duplicate() as ShaderMaterial
		material.shader = shader
		for water:MeshInstance3D in waters: water.material_override=material
		_character.global_position = _spot[2]
		_character.velocity = Vector3.ZERO
		_character.set("in_water",false)
		_output_dir = output.path_join(phase)
		DirAccess.make_dir_recursive_absolute(_output_dir)
		for frame in 541:
			if frame >= 420: _character.global_position.x = _spot[2].x+float(frame-420)*.1
			var started := Time.get_ticks_usec()
			sim._process(1.0/30.0)
			var cpu_us := Time.get_ticks_usec()-started
			for parameter:String in ["ripple_tex","ripple_origin","ripple_size","packet_tex","packet_origin","packet_size","packet_center"]:
				var value = original.get_shader_parameter(parameter)
				if value != null: material.set_shader_parameter(parameter,value)
			material.set_shader_parameter("review_time",float(frame)/30.0)
			await get_tree().process_frame
			RenderingServer.force_draw(false)
			if frame >= 60: records.append({"phase":phase,"frame":frame,"cpu_us":cpu_us,
				"packet_gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(sim._packet_vp.get_viewport_rid())})
			if frame in [300,360,419,450,540]:
				var feet:Vector3 = _spot[2]
				var eye := ReviewCam.solve_cam(feet,_spot[3],26,16,1)
				for angle:float in [0,-8,8]:
					_camera.fov=50
					_camera.global_position=feet+Vector3.UP+(eye-feet-Vector3.UP).rotated(Vector3.UP,deg_to_rad(angle))
					_camera.look_at(feet+Vector3.UP)
					poses.append({"phase":phase,"frame":frame,"angle":angle,"camera":str(_camera.global_transform),"fov":_camera.fov,"feet":str(_character.global_position)})
					await _shot("P12_%03d_%d"%[frame,int(angle)])
				FileAccess.open(_output_dir.path_join("state_%d.json"%frame),FileAccess.WRITE).store_string(JSON.stringify(sim.debug_state(),"  "))
				sim.save_debug_images(_output_dir.path_join("field_%d"%frame))
		sim.free()
	FileAccess.open(output.path_join("timings.json"),FileAccess.WRITE).store_string(JSON.stringify(records))
	FileAccess.open(output.path_join("poses.json"),FileAccess.WRITE).store_string(JSON.stringify(poses,"  "))
	_output_dir=output
	print("MOTION_REVIEW_DONE")
