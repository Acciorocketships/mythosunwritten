extends "res://tests/harness/september10_stream_teleports.gd"

const GRASS_SITES := [
	{"id": "11_forest", "player": Vector3(1618,12,-571), "cross": Vector3(1617.7,12.2,-570.9)},
	{"id": "19_heath", "player": Vector3(899.7,4.5,-1765.8), "cross": Vector3(899.5,4.7,-1766.1)},
	{"id": "meadow", "player": Vector3(-174.7,4,315.7), "cross": Vector3(-174.9,4.2,315.4), "ground_snap": true},
]
var _output := "/private/tmp/grass-latency"
var _grass_log: FileAccess
var _grass_sample_msec := 0
var _release_msec := 0
var _captures: Array[Dictionary] = []

func _ready() -> void:
	super._ready()
	get_window().size = Vector2i(1718,1035)
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--output": _output = args[i+1]
	DirAccess.make_dir_recursive_absolute(_output)
	_grass_log = FileAccess.open(_report + ".grass.jsonl", FileAccess.WRITE)
	_hold = true; _hold_position = Vector3(1618,12,-571)
	assert(_stream._grass_runtime_enabled, "Run this visual latency review graphically")

func _review_sites() -> Array:
	return GRASS_SITES

func _process(delta: float) -> void:
	super._process(delta)
	if _grass_log == null or Time.get_ticks_msec() - _grass_sample_msec < 250: return
	_grass_sample_msec = Time.get_ticks_msec()
	var row := _grass_observation()
	row.merge({"msec": _grass_sample_msec, "site": _site, "phase": _phase,
		"since_release_msec": _grass_sample_msec - _release_msec,
		"position": str(_player.position), "frozen": _stream._player_frozen})
	_grass_log.store_line(JSON.stringify(row)); _grass_log.flush()

func _grass_observation() -> Dictionary:
	var service := _stream._grass_streamer
	var origin := Vector2(_player.position.x, _player.position.z)
	var underfoot := GrassField.tile_of(origin)
	var missing_near := 0
	var desired_near := 0
	var built_instances := 0
	var known_nonempty: Array[String] = []
	for tile: Vector2i in GrassStreamer.desired_tiles(origin):
		if GrassStreamer.distance_to_tile(origin,tile) <= 24.0:
			desired_near += 1
			if not service._built.has(tile): missing_near += 1
	for tile: Vector2i in service._built:
		var instances := 0
		for batch: Dictionary in service._built[tile].batches: instances += int(batch.count)
		built_instances += instances
		if instances > 0: known_nonempty.append(str(tile))
	var sampling_chunks := 0
	for ground: Node3D in _stream._built.values():
		if ground.has_meta(&"grass_sampling"): sampling_chunks += 1
	var work = _stream.get("_grass_work")
	return {"sampling_chunks":sampling_chunks,
		"visual_worker":work.stats() if work != null else {},
		"underfoot": str(underfoot), "underfoot_ready": service._built.has(underfoot),
		"parent_ready": _stream._built.has(GrassField.parent_chunk(underfoot)),
		"missing_near": missing_near, "desired_near": desired_near,
		"built_instances": built_instances, "known_nonempty": known_nonempty,
		"stats": service.stats()}

func _run() -> void:
	while not _stream.startup_loading_complete():
		if Time.get_ticks_msec()-_start > 900000: _finish("startup_timeout"); return
		await get_tree().create_timer(.1).timeout
	_startup_ms = Time.get_ticks_msec()-_start
	var camera := _world.get_node("Camera3D") as Camera3D
	camera.set("target",null); camera.set_physics_process(false); camera.fov = 75
	var visibility: CameraVisibilityBubble = camera.get("_visibility")
	if visibility != null: visibility.clear()
	var sites := _review_sites()
	for index in sites.size():
		var site: Dictionary = sites[index].duplicate(true)
		_site = index; _phase = "arrival"; _hold = true
		_hold_position = site.player; _player.position = site.player
		_player.velocity = Vector3.ZERO; _controller.motion = Vector2.ZERO
		var arrived := Time.get_ticks_msec()
		for i in 3: await get_tree().process_frame
		while _stream._player_frozen:
			if Time.get_ticks_msec()-arrived > 900000: _finish("arrival_timeout"); return
			await get_tree().create_timer(.05).timeout
		if site.get("ground_snap",false):
			var at: Vector3 = site.player
			var query := PhysicsRayQueryParameters3D.create(Vector3(at.x,256,at.z),
				Vector3(at.x,-256,at.z),1,[_player.get_rid()])
			var hit := _player.get_world_3d().direct_space_state.intersect_ray(query)
			if hit.is_empty(): _finish("ground_snap_failed"); return
			var offset: Vector3 = site.cross-site.player
			site.player = hit.position+Vector3.UP*.1; site.cross = site.player+offset
			_hold_position = site.player; _player.position = site.player
		_release_msec = Time.get_ticks_msec(); _phase = "visible"
		var cam := ReviewCam.solve_cam(site.player,site.cross)
		var visit := {"index": index, "id": site.id,
			"ready_msec": _release_msec-arrived, "at_release": _grass_observation()}
		for seconds: int in [0,2,10,30]:
			while Time.get_ticks_msec()-_release_msec < seconds*1000:
				await get_tree().process_frame
			await _capture(site,cam,"t%02d" % seconds,camera)
		for degrees: int in [-8,8]:
			await _capture(site,site.player+(cam-site.player).rotated(Vector3.UP,deg_to_rad(degrees)),
				"near_%d" % degrees,camera)
		visit["after_30_seconds"] = _grass_observation()
		_phase = "walk"; _hold = false; _frozen = 0; _distance = 0
		_controller.motion = Vector2(0,-1)
		await _walk_review(site,camera)
		_controller.motion = Vector2.ZERO
		visit["walk_meters"] = _distance; visit["walk_frozen_seconds"] = _frozen
		_visits.append(visit)
		print("GRASS_VISIT ",JSON.stringify(visit))
	FileAccess.open(_output+"/cameras.json",FileAccess.WRITE).store_string(JSON.stringify(_captures,"  "))
	_finish("complete")

func _walk_review(_site_data: Dictionary, _camera: Camera3D) -> void:
	await get_tree().create_timer(_walk_seconds).timeout

func _capture(site: Dictionary, position: Vector3, label: String, camera: Camera3D) -> void:
	camera.position = position; camera.look_at(site.player,Vector3.UP)
	camera.force_update_transform()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var name := String(site.id)+"_"+label
	get_viewport().get_texture().get_image().save_png(_output+"/"+name+".png")
	_captures.append({"name":name,"camera":str(position),"player":str(site.player),
		"crosshair":str(site.cross),"since_release_msec":Time.get_ticks_msec()-_release_msec,
		"physical_player":str(_player.position),
		"grass":_grass_observation()})
