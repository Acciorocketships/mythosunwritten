extends "res://tests/harness/september16_manual_qa.gd"
const QA := "res://docs/qa/2026-09-16-manual/02-water-distance"
func _capture_views(world: Node3D) -> void:
	var data: Array = FileAccess.open(QA+"/production-after/samplers.bin",FileAccess.READ).get_var()
	for values: Dictionary in data:
		var sampler := WaterSampler.new()
		for key: String in values: sampler.set(key,values[key])
		var owner := Node.new()
		owner.set_meta("sampler",sampler)
		world.add_child(owner)
		owner.add_to_group("water_volume")
	var waters := []
	for node: MeshInstance3D in world.find_children("*","MeshInstance3D",true,false):
		if node.is_in_group("tactical_preserve_surface"): waters.append(node)
	var output := _output_dir
	var original := WaterSurfaceBuilder.sheet_material()
	var reports := []
	for phase: String in ["before","after"]:
		_character.global_position = _spot[2]
		_character.velocity = Vector3.ZERO
		_character.in_water = false
		var sim := WaterRippleSim.new()
		sim.player = _character
		world.add_child(sim)
		sim.set_process(false)
		if phase == "before":
			var old_ripple := Shader.new()
			old_ripple.code = FileAccess.get_file_as_string(QA+"/ripple-before.gdshader.txt")
			for mat: ShaderMaterial in sim._mat: mat.shader = old_ripple
		var shader := Shader.new()
		shader.code = FileAccess.get_file_as_string(QA+"/water-before.gdshader.txt" if phase == "before" else "res://terrain/water/water_unified.gdshader").replace("TIME","review_time").replace("shader_type spatial;","shader_type spatial;\nuniform float review_time = 0.0;")
		var material := original.duplicate() as ShaderMaterial
		material.shader = shader
		for node: MeshInstance3D in waters: node.material_override = material
		for frame in 720:
			if frame >= 600:
				_character.global_position.x = _spot[2].x + (frame-600)/10.0
				_character.velocity.x = 3.0
			if frame == 610:
				_character.in_water = true
				_character.velocity.y = -3.0
			var start := Time.get_ticks_usec()
			sim._process(1.0/30.0)
			var cpu := Time.get_ticks_usec()-start
			for key: String in ["ripple_tex","ripple_origin","ripple_size","packet_tex","packet_origin","packet_size","packet_center"]:
				material.set_shader_parameter(key,original.get_shader_parameter(key))
			material.set_shader_parameter("review_time",frame/30.0)
			await get_tree().process_frame
			RenderingServer.force_draw(false)
			if frame >= 60: reports.append({"phase":phase,"frame":frame,"cpu_us":cpu})
			if frame in [599,629,719]:
				_output_dir = output.path_join(phase).path_join(str(frame))
				DirAccess.make_dir_recursive_absolute(_output_dir)
				var moving_feet := _character.global_position
				await super._capture_views(world)
				_character.global_position = moving_feet
				sim._vp[sim._cur].get_texture().get_image().save_exr(_output_dir.path_join("ripple.exr"))
				print("RIPPLE_REPLAY ",phase," ",frame)
		sim.free()
	FileAccess.open(output.path_join("timings.json"),FileAccess.WRITE).store_string(JSON.stringify(reports))
	_output_dir = output
