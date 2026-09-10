extends Node3D

## Production-streamed visual review, including features, water and nature.
## Example: godot --path /Users/ryko/story res://tests/harness/atmosphere_review.tscn
##   -- --x 672 --z 96 --capture /tmp/cherryveil.png

const WORLD := preload("res://scenes/world.tscn")
const REVIEW_POSITION := Vector3(48.0, 30.0, -1500.0)
const SHORE_REVIEW_POSITION := Vector3(-672.0, 30.0, -3360.0)
const REVIEW_SEED := 2697992464
const TIMEOUT_SECONDS := 300.0

var _capture_path := "/tmp/atmosphere-review.png"
var _review_actor: CharacterBody3D
var _review_position := REVIEW_POSITION
var _camera_offset := Vector3(28.0, 19.0, 34.0)

func _ready() -> void:
	_read_args()
	var world := WORLD.instantiate()
	var player := world.get_node("Characters/Character") as CharacterBody3D
	_review_actor = player
	var streamer := world.get_node("FieldTerrain") as FieldTerrainStreamer
	# Configure the detached scene before any _ready callback can start the
	# worker. Exactly one chunk ring makes both the capture and its counters
	# bit-reproducible instead of racing the normal radius-3 stream.
	streamer.SEED_OVERRIDE = REVIEW_SEED
	streamer.CHUNK_RADIUS = 1
	streamer.KEEP_RADIUS = 1
	streamer.MAX_BUILD_PER_FRAME = 3
	player.position = _review_position
	add_child(world)
	_run.call_deferred(world, player)

func _physics_process(_dt: float) -> void:
	# Let gravity find the real ground/water, but do not let river current move
	# the review into another chunk while its neighbours are still loading.
	if is_instance_valid(_review_actor):
		_review_actor.position.x = _review_position.x
		_review_actor.position.z = _review_position.z
		_review_actor.velocity.x = 0.0
		_review_actor.velocity.z = 0.0

func _read_args() -> void:
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		if args[index] == "--capture" and index + 1 < args.size():
			_capture_path = args[index + 1]
		elif args[index] == "--x" and index + 1 < args.size():
			_review_position.x = float(args[index + 1])
		elif args[index] == "--z" and index + 1 < args.size():
			_review_position.z = float(args[index + 1])
		elif args[index] == "--wide":
			_camera_offset = Vector3(60.0, 38.0, 74.0)
		elif args[index] == "--shore":
			_review_position = SHORE_REVIEW_POSITION

func _run(world: Node3D, player: Node3D) -> void:
	var streamer := world.get_node("FieldTerrain") as FieldTerrainStreamer
	var started := Time.get_ticks_msec()
	while not _streaming_ready(streamer):
		if float(Time.get_ticks_msec() - started) / 1000.0 > TIMEOUT_SECONDS:
			push_error("Dressing review timed out waiting for streamed batches")
			get_tree().quit(1)
			return
		await get_tree().create_timer(0.1).timeout
	await get_tree().create_timer(8.0).timeout

	var batch_count := 0
	var instance_count := 0
	var collision_count := 0
	for chunk_node: Node3D in streamer._built.values():
		var dressing := chunk_node.get_node_or_null("Dressing") as Node3D
		if dressing != null:
			for child: Node in dressing.get_children():
				var batch := child as MultiMeshInstance3D
				if batch != null and batch.multimesh != null:
					batch_count += 1
					instance_count += batch.multimesh.instance_count
		var collision_body := chunk_node.get_node_or_null("DressingCollision") as StaticBody3D
		if collision_body != null:
			collision_count += collision_body.get_child_count()
	if batch_count == 0 or instance_count == 0:
		push_error("Streamed review produced no dressing batches")
		get_tree().quit(1)
		return
	if collision_count == 0:
		push_error("Streamed review produced no dressing collision shapes")
		get_tree().quit(1)
		return

	set_physics_process(false)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	(world.get_node("CoordOverlay") as CanvasLayer).visible = false
	(world.get_node("ReviewTeleporter") as CanvasLayer).visible = false
	var camera := world.get_node("Camera3D") as Camera3D
	camera.set_physics_process(false)
	camera.fov = 48.0 if _camera_offset.length() > 90.0 else 52.0
	var focus := player.global_position + Vector3.UP * (4.0 if _camera_offset.length() > 90.0 else 2.0)
	camera.global_position = focus + _camera_offset
	camera.look_at(focus, Vector3.UP)
	for unused in 8:
		await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	RenderingServer.force_draw()
	await get_tree().process_frame
	print("[atmosphere-review] grass ", streamer._grass_streamer.stats())
	var captured_image: Image = get_viewport().get_texture().get_image()
	if captured_image == null or captured_image.save_png(_capture_path) != OK:
		push_error("Could not capture streamed dressing review: %s" % _capture_path)
		get_tree().quit(1)
		return
	print("[atmosphere-review] %d batches, %d instances, %d collision shapes -> %s" % [
		batch_count, instance_count, collision_count, _capture_path])
	get_tree().quit()

func _streaming_ready(streamer: FieldTerrainStreamer) -> bool:
	return streamer != null and streamer._built.size() == 9 \
		and streamer._dressing_queue != null \
		and streamer._dressing_queue.pending_count() == 0
