extends "res://tests/harness/village_reported_qa.gd"
## Fresh streamed-world acceptance, including production terrain and grass.

func _ready() -> void:
	# Fail before the expensive world build if an isolated checkout lacks the
	# ignored native terrain meshes required by the production scene.
	var rocks := preload("res://scripts/terrain/field/CliffSlopeRocks.gd")
	rocks.prepare()
	assert(rocks._pieces.size() == rocks.PIECES.size())
	super._ready()

func _grass_enabled() -> bool:
	return true

func _shot(name: String) -> void:
	await super._shot(name)
	if not OS.get_cmdline_user_args().has("--profile-frames"):
		return
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var viewport := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport, true)
	var samples: Array[float] = []
	var gpu: Array[float] = []
	var cpu: Array[float] = []
	var previous := Time.get_ticks_usec()
	for frame in 180:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		if frame >= 60:
			samples.append((now-previous)/1000.0)
			gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport))
			cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport))
		previous = now
	samples.sort()
	gpu.sort()
	cpu.sort()
	var report := {"view":name,"samples":samples.size(),"median_ms":samples[60],
		"p95_ms":samples[114],"gpu_median_ms":gpu[60],"gpu_timing_available":gpu[60]>0.0,
		"render_cpu_median_ms":cpu[60],"resolution":str(get_viewport().get_visible_rect().size),
		"chunk_radius":_streamer.CHUNK_RADIUS,"grass":_streamer.GRASS_ENABLED,
		"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"static_memory_bytes":Performance.get_monitor(Performance.MEMORY_STATIC)}
	FileAccess.open(_output_dir.path_join(name+"-performance.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("WORLD_RENDER_PROFILE ",JSON.stringify(report))
	Engine.max_fps = 30

func _capture_spot(spot: Array) -> void:
	if String(spot[0]).begins_with("wooded_") or spot[0] == "at":
		spot = spot.duplicate(true)
		var point := Vector2(spot[2].x,spot[2].z)
		var context := _streamer._features.context_for(WorldFieldBlockCache.key_of(point))
		var region := context.graded_region(_streamer._fields.region_at(point))
		var ground := TerrainTileField.surface_y(region,point.x,point.y)
		spot[2].y = ground + 0.1
		spot[3].y = ground + 0.1
	_character.global_position = spot[2]
	var target := Vector3(spot[2])+Vector3.UP*CameraMouseView.PIVOT_HEIGHT
	var delta := target-Vector3(spot[3])
	var pitch := atan2(delta.y,Vector2(delta.x,delta.z).length())
	var eye := ReviewCam.solve_cam(spot[2],spot[3],
		CameraMouseView.BOOM_LENGTH*cos(pitch),
		CameraMouseView.PIVOT_HEIGHT+CameraMouseView.BOOM_LENGTH*sin(pitch),
		CameraMouseView.PIVOT_HEIGHT)
	_camera.fov = 75.0
	for angle: float in [0.0,-8.0,8.0]:
		_camera.look_at_from_position(target+(eye-target).rotated(Vector3.UP,deg_to_rad(angle)),target)
		for i in 4: await get_tree().process_frame
		await _shot("%s_%d" % [spot[0],int(angle)])
	if spot[0] == "reported_overview":
		_character.hide()
		_camera.look_at_from_position(Vector3(410,60,1160),Vector3(325,20,1085))
		await _shot("town_wide")
		_character.show()
	if spot[0] == "at":
		_character.hide()
		var centre: Vector3 = spot[2]
		_camera.look_at_from_position(centre+Vector3(100,90,100),centre+Vector3.UP*8)
		await _shot("at_wide")
		_character.show()
	if spot[0] == "wooded_green":
		_character.hide()
		_camera.look_at_from_position(Vector3(-180,85,490),Vector3(-265,15,425))
		await _shot("wooded_wide")
		_character.show()

func _spots() -> Array:
	var args := OS.get_cmdline_user_args()
	if args.has("--at"):
		var values := args[args.find("--at")+1].split(",")
		assert(values.size()==3,"--at expects world x,y,z")
		var point := Vector3(float(values[0]),float(values[1]),float(values[2]))
		return [["at","world coordinate review",point,point+Vector3(8,0,0)]]
	if OS.get_cmdline_user_args().has("--wooded"):
		return [
			["wooded_green", "procedural wooded town (-1,0)",Vector3(-302,14,444),Vector3(-294,14,444)],
			["wooded_reverse", "wooded town reverse",Vector3(-286,14,452),Vector3(-278,14,452)],
		]
	return [
		["green", "reserved town green",Vector3(362,14,1104),Vector3(354,14,1104)],
		["green_reverse", "reserved town green reverse",Vector3(330,14,1104),Vector3(346,14,1104)],
		["reported_overview", "October 1 owner overview",Vector3(374.4,22.9,1030),Vector3(352.5,12,1055.2)],
		["reported_walkway", "September 30 owner walkway",Vector3(312.4,20.3,1096.9),Vector3(319,19,1097)],
	]
