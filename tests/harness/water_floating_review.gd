extends Node

## Current-world reproduction from the owner's rounded F3 readouts. The
## recovered azimuth is approximate because those readouts have 0.1m precision.
const WORLD := preload("res://scenes/world.tscn")
var _player: CharacterBody3D

func _process(_delta: float) -> void:
	if _player != null: _player.set_physics_process(false)

func _ready() -> void:
	var output := "/private/tmp/water-reported"
	var only_site := ""
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--report" and i + 1 < args.size(): output = args[i + 1]
		if args[i] == "--site" and i + 1 < args.size(): only_site = args[i + 1]
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://tests/fixtures/september7_reported_water.json"))
	get_window().size = Vector2i(1440,900)
	var world := WORLD.instantiate()
	_player = world.get_node("Characters/Character")
	var streamer: FieldTerrainStreamer = world.get_node("FieldTerrain")
	streamer.SEED_OVERRIDE = int(fixture.seed)
	_player.position = Vector3(12.7,4.1,-157.5)
	add_child(world)
	var camera: Camera3D = world.get_node("Camera3D")
	camera.set_physics_process(false)
	for site: Dictionary in fixture.sites:
		if not only_site.is_empty() and site.name != only_site: continue
		var p := Vector3(site.player[0],site.player[1],site.player[2])
		var hit := Vector3(site.crosshair[0],site.crosshair[1],site.crosshair[2])
		_player.position = p
		_player.velocity = Vector3.ZERO
		camera.position = ReviewCam.solve_cam(p,hit)
		camera.look_at(p)
		streamer.set_process(true)
		var started := Time.get_ticks_msec()
		while true:
			var complete := streamer.startup_loading_complete()
			for chunk: Vector2i in streamer.desired_chunks(FieldTerrainStreamer.chunk_of(p),1):
				complete = complete and streamer._built.has(chunk) and streamer._feature_square_ready(chunk)
			if complete and streamer._dressing_queue.pending_count() == 0: break
			if Time.get_ticks_msec() - started > 600000:
				push_error("Reported water scene readiness timeout")
				get_tree().quit(1)
				return
			await get_tree().create_timer(0.2).timeout
		streamer.set_process(false)
		_player.position = p
		await get_tree().create_timer(3).timeout
		RenderingServer.force_draw()
		var path: String = output + "-" + site.name + ".png"
		get_viewport().get_texture().get_image().save_png(path)
		print("WATER_REVIEW ",site.name," camera=",camera.position," player=",_player.position," capture=",path)
	get_tree().quit()
