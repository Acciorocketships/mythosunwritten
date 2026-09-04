extends Node3D

## In-world capture of one settlement through the production streamer.
## Unlike `village_capture.tscn`, it waits until every terrain chunk in
## `--radius` around the site is built and feature-ready before shooting, so
## terrain paths, handoff ramps, and outskirts roads are complete in the frame.
##
##   Godot --path . res://tests/harness/village_site_capture.tscn -- \
##     --seed 2697992464 --at -552,6,1133 --radius 1 --output DIR \
##     --view entry:-552,7,1148:-552,5,1131[:fov]
const WAIT_HARD_TIMEOUT_SECONDS := 900.0
const IDLE_SETTLE_SECONDS := 3.0

var _seed := 2697992464
var _at := Vector3(-552.0, 6.0, 1133.0)
var _radius := 1
var _grass := false
var _show_character := false
var _output_dir := "/tmp/mythos-village-site-capture"
var _views: Array[Dictionary] = []
var _streamer: FieldTerrainStreamer
var _character: CharacterBody3D
var _camera := Camera3D.new()


func _ready() -> void:
	_read_args()
	get_window().size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute(_output_dir)
	var world := (load("res://scenes/world.tscn") as PackedScene).instantiate()
	_streamer = world.find_child("FieldTerrain", true, false) as FieldTerrainStreamer
	_character = world.find_child("Character", true, false) as CharacterBody3D
	assert(_streamer != null and _character != null)
	_character.visible = _show_character
	_streamer.SEED_OVERRIDE = _seed
	_streamer.CHUNK_RADIUS = _radius
	_streamer.KEEP_RADIUS = _radius + 1
	_streamer.GRASS_ENABLED = _grass
	_character.position = _at + Vector3.UP * 4.0
	_character.velocity = Vector3.ZERO
	add_child(world)
	_camera.current = true
	add_child(_camera)
	_run.call_deferred()


func _read_args() -> void:
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		var next := args[index + 1] if index + 1 < args.size() else ""
		match args[index]:
			"--seed":
				_seed = int(next)
			"--at":
				_at = _parse_v3(next)
			"--radius":
				_radius = int(next)
			"--grass":
				_grass = true
			"--character":
				_show_character = true
			"--output":
				_output_dir = next
			"--view":
				var parts := next.split(":", false)
				assert(parts.size() >= 3, "--view id:px,py,pz:tx,ty,tz[:fov]")
				_views.append({
					"id": parts[0],
					"position": _parse_v3(parts[1]),
					"target": _parse_v3(parts[2]),
					"fov": float(parts[3]) if parts.size() > 3 else 62.0,
				})


static func _parse_v3(text: String) -> Vector3:
	var parts := text.split(",", false)
	assert(parts.size() == 3, "expected x,y,z")
	return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))


func _run() -> void:
	var ready := await _wait_for_site()
	print("[village_site_capture] site_ready=%s seed=%d at=%s" % [ready, _seed,
		_at])
	_character.set_physics_process(false)
	for view: Dictionary in _views:
		await _capture(view)
	print("[village_site_capture] complete captures=%d output=%s" % [
		_views.size(), _output_dir])
	get_tree().quit(0 if ready else 2)


func _wait_for_site() -> bool:
	var centre_chunk := FieldTerrainStreamer.chunk_of(_at)
	var wanted: Array = _streamer.desired_chunks(centre_chunk, _radius)
	var started := Time.get_ticks_msec()
	var idle_since := -1
	var last_report := 0
	while true:
		var elapsed := float(Time.get_ticks_msec() - started) / 1000.0
		if elapsed >= WAIT_HARD_TIMEOUT_SECONDS:
			print("[village_site_capture] TIMEOUT missing=", _missing(wanted))
			return false
		var missing := _missing(wanted)
		var progress := _streamer.worker_progress_snapshot()
		var active := bool(progress.get("active", false)) \
			and StringName(progress.get("phase", &"idle")) != &"idle"
		if int(elapsed) / 10 != last_report:
			last_report = int(elapsed) / 10
			print("[village_site_capture] waiting %.0fs missing=%s worker=%s" % [
				elapsed, missing, progress.get("phase", &"idle")])
		if missing.is_empty() and _streamer.startup_loading_complete() \
				and not active:
			if idle_since < 0:
				idle_since = Time.get_ticks_msec()
			elif float(Time.get_ticks_msec() - idle_since) / 1000.0 \
					>= IDLE_SETTLE_SECONDS:
				return true
		else:
			idle_since = -1
		await get_tree().create_timer(0.25).timeout
	return false


func _missing(wanted: Array) -> Array:
	var out: Array = []
	for chunk: Vector2i in wanted:
		if not _streamer._built.has(chunk) \
				or not _streamer._feature_square_ready(chunk):
			out.append(chunk)
	return out


func _capture(view: Dictionary) -> void:
	_camera.fov = float(view.fov)
	# A plan view names its own up vector so the frame stays axis-aligned to
	# the world instead of rolling with the look direction.
	var up := Vector3.FORWARD if String(view.id).begins_with("plan-") \
		else Vector3.UP
	_camera.look_at_from_position(view.position as Vector3,
		view.target as Vector3, up)
	_camera.force_update_transform()
	for unused in 3:
		await get_tree().process_frame
	RenderingServer.force_draw()
	await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [_output_dir, String(view.id)]
	assert(image != null and image.save_png(path) == OK)
	print("[village_site_capture] captured ", path)
