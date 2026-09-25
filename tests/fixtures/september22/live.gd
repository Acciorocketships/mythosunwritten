extends SceneTree
## Fresh production world capture at every photo of one town.
## Usage (GUI): -s live.gd -- --town=town-e --out=res://docs/qa/2026-09-22-manual/live/before
const SPOTS := preload("res://tests/fixtures/september22/spots.gd")
func _init() -> void: run.call_deferred()
func shot(path: String) -> void:
	for i in 8: await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(path)
func run() -> void:
	var town := "town-e"
	var out := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--town="): town = arg.trim_prefix("--town=")
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	Engine.max_fps = 30
	root.size = SPOTS.SIZE
	var photos: Array = SPOTS.town_photos(town)
	var first: Dictionary = SPOTS.SPOTS[photos[0]]
	var world := load("res://scenes/world.tscn").instantiate() as Node3D
	var player := world.get_node("Characters/Character") as CharacterBody3D
	var stream := world.get_node("FieldTerrain") as FieldTerrainStreamer
	stream.SEED_OVERRIDE = 2697992464
	stream.CHUNK_RADIUS = 1
	player.position = first.feet
	root.add_child(world)
	var camera := world.get_node("Camera3D") as Camera3D
	camera.set_physics_process(false)
	camera.set_process(false)
	camera.fov = 75
	var started := Time.get_ticks_msec()
	while not stream.startup_loading_complete() or stream._feature_queue.pending_count()>0 or stream._dressing_queue.pending_count()>0:
		await create_timer(1).timeout
		if Time.get_ticks_msec()-started>1800000:
			push_error("live startup timeout"); quit(1); return
	await create_timer(3).timeout
	player.process_mode = Node.PROCESS_MODE_DISABLED
	stream.set_process(false)
	if stream._grass_work != null: stream._grass_work.stop()
	stream._mutex.lock()
	stream._jobs.clear(); stream._queued.clear(); stream._followups.clear()
	stream._mutex.unlock()
	var poses := {}
	for name: String in photos:
		var spot: Dictionary = SPOTS.SPOTS[name]
		player.global_position = spot.feet
		await physics_frame
		var excluded: Array[RID] = [player.get_rid()]
		var view: Dictionary = SPOTS.resolved(camera.get_world_3d().direct_space_state, spot.feet, spot.aim, excluded)
		camera.global_position = view.eye
		camera.look_at(view.pivot)
		poses[name] = {"camera": str(camera.global_transform), "feet": str(spot.feet), "aim": str(spot.aim)}
		await shot(out.path_join(name + ".png"))
	FileAccess.open(out.path_join("poses.json"), FileAccess.WRITE).store_string(JSON.stringify({"poses": poses, "startup_ms": Time.get_ticks_msec()-started}, "  "))
	preload("res://tests/harness/september11_snapshot.gd").save(world, player, out.path_join("world.scn"))
	print("LIVE_DONE town=", town, " ms=", Time.get_ticks_msec()-started)
	quit()
