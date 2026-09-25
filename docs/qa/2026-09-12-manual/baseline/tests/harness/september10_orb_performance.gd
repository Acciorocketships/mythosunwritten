extends "res://tests/harness/september10_orb_replay.gd"

func _run(fixture: String) -> void:
	DirAccess.make_dir_recursive_absolute(_output)
	Engine.max_fps=0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
	var original := _camera.global_transform
	var rows: Array = []
	for offset in [Vector3.ZERO,Vector3(20,0,10),Vector3(-15,0,-20)]:
		_camera.global_transform=original
		_camera.global_position+=offset
		await _sample(0.0)
		for particle in _particles: particle.speed_scale=1.0
		var samples: Array[float] = []
		var gpu: Array[float] = []
		var cpu: Array[float] = []
		var previous := Time.get_ticks_usec()
		for frame in 450:
			var seconds := float(frame)/60.0
			for row in _large:
				row[0].position=row[1]+SpiritOrb.offset_at(seconds,SpiritOrb.phase_at(row[1]))
			for batch in _batches: batch.sample(seconds,batch.to_local(_camera.global_position))
			await get_tree().process_frame
			var now := Time.get_ticks_usec()
			if frame>=150:
				samples.append((now-previous)/1000.0)
				gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid()))
				cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid()))
			previous=now
		samples.sort()
		gpu.sort()
		cpu.sort()
		rows.append({"camera":str(_camera.global_transform),"median_ms":samples[150],"p95_ms":samples[285],
			"gpu_median_ms":gpu[150],"gpu_p95_ms":gpu[285],"render_cpu_median_ms":cpu[150],
			"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			"omni_lights":_world.find_children("*","OmniLight3D",true,false).size(),"samples":300})
		print("ORB_PERFORMANCE ",rows[-1])
	FileAccess.open(_output+"/performance.json",FileAccess.WRITE).store_string(JSON.stringify({
		"fixture":fixture,"fixture_sha256":FileAccess.get_sha256(fixture),"before":_before,"rows":rows},"  "))
	get_tree().quit()
