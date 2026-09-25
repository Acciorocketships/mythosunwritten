extends SceneTree
const OUT := "res://docs/qa/2026-09-19-manual/117-loading-frontier"
func _init() -> void: run.call_deferred()
func run() -> void:
	Engine.max_fps = 30
	root.size = Vector2i(1280, 800)
	var world := load("res://scenes/world.tscn").instantiate() as Node3D
	var player := world.get_node("Characters/Character") as CharacterBody3D
	var stream := world.get_node("FieldTerrain") as FieldTerrainStreamer
	stream.SEED_OVERRIDE = 2697992464
	stream.PROFILE_STREAMING = true
	stream.CHUNK_RADIUS = 1
	player.position = Vector3(-566.9, 32, 127.4)
	root.add_child(world)
	var camera := world.get_node("Camera3D") as Camera3D
	camera.set_physics_process(false)
	camera.set_process(false)
	var feet := player.position
	var aim := Vector3(-568.9,32,130.9)
	var pivot := feet+Vector3.UP*CameraMouseView.PIVOT_HEIGHT
	var backward := (pivot-aim).normalized()
	camera.position = ReviewCam.solve_cam(feet,aim,Vector2(backward.x,backward.z).length()*CameraMouseView.BOOM_LENGTH,CameraMouseView.PIVOT_HEIGHT+backward.y*CameraMouseView.BOOM_LENGTH,CameraMouseView.PIVOT_HEIGHT)
	camera.look_at(pivot)
	camera.fov = 75
	var log := FileAccess.open(OUT.path_join("live.jsonl"),FileAccess.WRITE)
	var started := Time.get_ticks_msec()
	var captured := false
	while not stream.startup_loading_complete() or stream._feature_queue.pending_count()>0 or stream._dressing_queue.pending_count()>0:
		await create_timer(1).timeout
		var state := stream.streaming_profile_snapshot()
		state["worker"] = stream.worker_progress_snapshot()
		state["elapsed_ms"] = Time.get_ticks_msec()-started
		state["loaded_chunks"] = stream._built.keys()
		log.store_line(JSON.stringify(state)); log.flush()
		if not captured and stream._built.has(FieldTerrainStreamer.chunk_of(feet)):
			captured = true
			RenderingServer.force_draw(false)
			root.get_texture().get_image().save_png(OUT.path_join("live-first-ground.png"))
		if Time.get_ticks_msec()-started>1200000:
			push_error("frontier live startup timeout"); quit(1); return
	player.process_mode = Node.PROCESS_MODE_DISABLED
	stream.set_process(false)
	if stream._grass_work != null: stream._grass_work.stop()
	stream._mutex.lock()
	stream._jobs.clear(); stream._queued.clear(); stream._followups.clear()
	stream._mutex.unlock()
	var report := stream.streaming_profile_snapshot()
	report["camera"] = camera.transform
	report["elapsed_ms"] = Time.get_ticks_msec()-started
	report["loaded_chunks"] = stream._built.keys()
	FileAccess.open(OUT.path_join("live-final.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	preload("res://tests/harness/september11_snapshot.gd").save(world,player,OUT.path_join("world.scn"))
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(OUT.path_join("live-loaded.png"))
	quit()
