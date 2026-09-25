extends Node3D

## Production-world visual review at a pinned corpus site. It waits for the
## complete terrain/feature neighbourhood and for staged village visuals,
## then captures deterministic overview and street-height views.
const DEFAULT_SEED := 4242
const DEFAULT_CENTRE := Vector2(1008.0, -240.0)
const TIMEOUT_SECONDS := 90.0

var _seed := DEFAULT_SEED
var _centre := DEFAULT_CENTRE
var _output_dir := "/tmp/mythos-village-review"
var _streamer: FieldTerrainStreamer
var _camera := Camera3D.new()

func _ready() -> void:
	_read_args()
	get_window().size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute(_output_dir)
	var world := (load("res://scenes/world.tscn") as PackedScene).instantiate()
	_streamer = world.find_child("FieldTerrain", true, false) as FieldTerrainStreamer
	_streamer.SEED_OVERRIDE = _seed
	_streamer.CHUNK_RADIUS = 1
	_streamer.KEEP_RADIUS = 2
	_streamer.GRASS_ENABLED = false
	var character := world.find_child("Character", true, false) as CharacterBody3D
	character.position = Vector3(_centre.x, 36.0, _centre.y)
	add_child(world)
	_camera.fov = 52.0
	_camera.current = true
	add_child(_camera)
	_capture_when_ready.call_deferred()

func _read_args() -> void:
	var args := OS.get_cmdline_user_args()
	for index in args.size() - 1:
		match args[index]:
			"--seed": _seed = int(args[index + 1])
			"--centre-x": _centre.x = float(args[index + 1])
			"--centre-z": _centre.y = float(args[index + 1])
			"--output": _output_dir = args[index + 1]

func _capture_when_ready() -> void:
	var centre_chunk := FieldTerrainStreamer.chunk_of(Vector3(
		_centre.x, 0.0, _centre.y))
	var started := Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - started) / 1000.0 < TIMEOUT_SECONDS:
		var complete := true
		for z in range(-1, 2):
			for x in range(-1, 2):
				var key := centre_chunk + Vector2i(x, z)
				complete = complete and _streamer._built.has(key) \
					and _streamer._feature_ready.has(key)
		if complete and _streamer._feature_queue.pending_count() == 0:
			await get_tree().create_timer(2.0).timeout
			_print_feature_batches()
			await _capture_views()
			get_tree().quit()
			return
		await get_tree().create_timer(0.25).timeout
	push_error("Village review timed out at seed=%d centre=%s" % [_seed, _centre])
	get_tree().quit(1)

func _print_feature_batches() -> void:
	var root := _streamer.get_node_or_null("ManmadeFeatures")
	if root == null:
		root = _streamer.get_parent().get_node_or_null("ManmadeFeatures")
	if root == null:
		root = find_child("ManmadeFeatures", true, false)
	assert(root != null)
	print("[village_review] feature_nodes=", _streamer._feature_nodes.keys(),
		" root_children=", root.get_child_count())
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child: Node in node.get_children():
			stack.append(child)
		var instance := node as MultiMeshInstance3D
		if instance == null:
			continue
		var multimesh := instance.multimesh
		var first := Vector3.ZERO
		if multimesh != null and multimesh.instance_count > 0:
			first = multimesh.get_instance_transform(0).origin
		print("[village_review] batch=%s count=%d first=%s" % [
			String(instance.name), multimesh.instance_count, first])

func _capture_views() -> void:
	var ground_y := _ground_y()
	var focus := Vector3(_centre.x, ground_y + 5.0, _centre.y)
	_camera.look_at_from_position(focus + Vector3(105.0, 92.0, 118.0), focus)
	await _save("overview")
	_camera.fov = 58.0
	_camera.look_at_from_position(focus + Vector3(40.0, 7.0, 48.0),
		focus + Vector3(0.0, 2.0, 0.0))
	await _save("street")

func _ground_y() -> float:
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(_centre.x, 100.0, _centre.y),
		Vector3(_centre.x, -100.0, _centre.y))
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return float((hit.get("position", Vector3.ZERO) as Vector3).y)

func _save(view_name: String) -> void:
	for unused in 4:
		await get_tree().process_frame
	RenderingServer.force_draw()
	await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var path := "%s/seed-%d-x%d-z%d-%s.png" % [_output_dir, _seed,
		roundi(_centre.x), roundi(_centre.y), view_name]
	assert(image != null and image.save_png(path) == OK,
		"Could not capture village review image")
	print("[village_review] captured ", path)
