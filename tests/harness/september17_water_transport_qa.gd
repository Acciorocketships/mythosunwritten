extends "res://tests/harness/september16_manual_qa.gd"
const PRIOR_SIM = preload("res://tests/fixtures/september17/water-transport/sim_before.gd")
const PROBE = preload("res://tests/harness/september17_packet_flow_probe.gd")
const FLOW := "res://docs/qa/2026-09-16-manual/03-water-flow/production-final"

func _capture_views(world: Node3D) -> void:
	await _prepare_review_grass()
	_character.anim_tree.active = false
	_freeze_material_clocks(world)
	_character.global_position = _spot[2]
	_character.step_visual_offset_y = 0
	_character._update_step_visual_smoothing(0)
	_character.velocity = Vector3.ZERO
	_character.in_water = false
	var waters := []
	for node: MeshInstance3D in world.find_children("*","MeshInstance3D",true,false):
		if node.is_in_group("tactical_preserve_surface"): waters.append(node)
	var output := _output_dir
	var original := WaterSurfaceBuilder.sheet_material()
	var poses: Array = JSON.parse_string(FileAccess.get_file_as_string(FLOW+"/P10/poses.json"))
	var records := []
	for phase: String in ["before","after"]:
		var owners := []
		var samplers: Array[WaterSampler] = []
		var path := "res://docs/qa/2026-09-16-manual/baseline/P10/samplers.bin" if phase == "before" else FLOW+"/P10/samplers.bin"
		var data: Array = FileAccess.open(path,FileAccess.READ).get_var()
		for values: Dictionary in data:
			var sampler: WaterSampler = PROBE.OldSampler.new() if phase == "before" else WaterSampler.new()
			for key: String in values: sampler.set(key,values[key])
			samplers.append(sampler)
			var owner := Node.new()
			owner.set_meta("sampler",sampler)
			world.add_child(owner);owner.add_to_group("water_volume");owners.append(owner)
		var sim = PRIOR_SIM.new() if phase == "before" else WaterRippleSim.new()
		sim.player = _character
		world.add_child(sim);sim.set_process(false)
		var shader := Shader.new()
		shader.code = FileAccess.get_file_as_string("res://terrain/water/water_unified.gdshader").replace("TIME","review_time").replace("shader_type spatial;","shader_type spatial;\nuniform float review_time = 0.0;")
		var material := original.duplicate() as ShaderMaterial
		material.shader = shader
		var updated_vertices := 0
		for water: MeshInstance3D in waters:
			water.material_override = material
			var arrays := water.mesh.surface_get_arrays(0)
			var payload: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM1]
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for i in vertices.size():
				var p: Vector3 = water.global_transform*vertices[i]
				for sampler: WaterSampler in samplers:
					if sampler._corners(Vector2(p.x,p.z)).is_empty(): continue
					var v := sampler.velocity_at(Vector2(p.x,p.z))
					var d := sampler.flow_diagnostics_at(Vector2(p.x,p.z))
					payload[i*4]=v.x;payload[i*4+1]=v.y
					payload[i*4+2]=d.x;payload[i*4+3]=d.y
					updated_vertices += 1
					break
			arrays[Mesh.ARRAY_CUSTOM1] = payload
			water.mesh = WaterSkin.commit(arrays)
		_output_dir = output.path_join(phase)
		DirAccess.make_dir_recursive_absolute(_output_dir)
		_pose(poses[0])
		for frame in 391:
			var started := Time.get_ticks_usec()
			sim._process(1.0/30)
			var elapsed := Time.get_ticks_usec()-started
			for key: String in ["ripple_tex","ripple_origin","ripple_size","packet_tex","packet_origin","packet_size","packet_center"]:
				material.set_shader_parameter(key,original.get_shader_parameter(key))
			material.set_shader_parameter("review_time",float(frame)/30)
			await get_tree().process_frame
			RenderingServer.force_draw(false)
			if frame >= 60: records.append({"phase":phase,"frame":frame,"cpu_us":elapsed})
			if frame >= 300 and frame % 3 == 0:
				await _shot("P10_%03d"%((frame-300)/3))
			if frame in [300,330,360,390]:
				for pose: Dictionary in poses.slice(1):
					_pose(pose)
					await _shot("P10_%d_%d"%[frame,int(pose.angle)])
				_pose(poses[0])
				FileAccess.open(_output_dir.path_join("packets_%d.json"%frame),FileAccess.WRITE).store_string(JSON.stringify(sim.debug_state(),"  "))
		print("TRANSPORT_REPLAY ",phase," mesh_count=",waters.size()," updated_vertices=",updated_vertices)
		sim.free()
		for owner: Node in owners: owner.free()
	FileAccess.open(output.path_join("timings.json"),FileAccess.WRITE).store_string(JSON.stringify(records))
	FileAccess.open(output.path_join("poses.json"),FileAccess.WRITE).store_string(JSON.stringify(poses,"  "))
	_output_dir = output

func _pose(record: Dictionary) -> void:
	var pattern := RegEx.new();pattern.compile("-?[0-9]+(?:\\.[0-9]+)?")
	var v: Array[float] = []
	for found in pattern.search_all(record.camera): v.append(float(found.get_string()))
	assert(v.size()==12)
	_camera.global_transform = Transform3D(Basis(Vector3(v[0],v[1],v[2]),Vector3(v[3],v[4],v[5]),Vector3(v[6],v[7],v[8])),Vector3(v[9],v[10],v[11]))
	_camera.fov = record.fov
