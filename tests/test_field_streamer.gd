extends GutTest
const Streamer := preload("res://scripts/terrain/field/FieldTerrainStreamer.gd")


static func _contains_scene_or_server_resource(value: Variant) -> bool:
	if value is Node or value is Mesh or value is Shape3D \
			or value is Material or value is MultiMesh:
		return true
	if value is Array:
		for item: Variant in value:
			if _contains_scene_or_server_resource(item):
				return true
	elif value is Dictionary:
		for item: Variant in value.values():
			if _contains_scene_or_server_resource(item):
				return true
	return false


func test_chunk_of_world_pos():
	# 192-unit chunks: world x in [0,192) → chunk 0; [192,384) → chunk 1; negative rounds down.
	assert_eq(Streamer.chunk_of(Vector3(10, 0, 10)), Vector2i(0, 0))
	assert_eq(Streamer.chunk_of(Vector3(200, 0, 10)), Vector2i(1, 0))
	assert_eq(Streamer.chunk_of(Vector3(-5, 0, -5)), Vector2i(-1, -1))

func test_desired_chunks_within_radius():
	var s := Streamer.new()
	var want := s.desired_chunks(Vector2i(0, 0), 1)
	assert_eq(want.size(), 9, "3x3 block for radius 1")
	assert_true(Vector2i(0, 0) in want)
	assert_true(Vector2i(1, 1) in want)
	s.free()

func test_background_builds_populate_radius():
	var s := Streamer.new()
	s.CHUNK_RADIUS = 1
	s.KEEP_RADIUS = 2
	# Hold integration until the test has inspected the worker hand-off.
	s.MAX_BUILD_PER_FRAME = 0
	s.SEED_OVERRIDE = 4242
	var parent := Node3D.new()
	var player := Node3D.new()
	add_child_autofree(parent)
	add_child_autofree(player)
	s.terrain_parent = parent
	s.player = player
	# Deferred free (like the real game frees the streamer) so _exit_tree joins
	# the worker thread before the node is deleted; a synchronous free() can't
	# succeed while the worker is parked in a live call frame on the node.
	add_child_autoqfree(s)
	# The spawn chunk is no longer built synchronously (a cold build blocked
	# the first frame for ~10s — the owner's grey startup screen). Instead the
	# player is HELD until the worker delivers their chunk.
	assert_eq(player.process_mode, Node.PROCESS_MODE_DISABLED,
		"player held from _ready until the spawn chunk lands")
	var payload_deadline := Time.get_ticks_msec() + 60_000
	var has_payload := false
	while not has_payload and Time.get_ticks_msec() < payload_deadline:
		s._mutex.lock()
		has_payload = not s._done.is_empty()
		s._mutex.unlock()
		if has_payload:
			break
		await wait_seconds(0.25)
	s._mutex.lock()
	var first_payload: Array = s._done[0] if not s._done.is_empty() else []
	s._mutex.unlock()
	assert_false(first_payload.is_empty(), "worker produced a chunk payload")
	if not first_payload.is_empty():
		assert_true(first_payload[1] is Dictionary,
			"terrain crosses the worker boundary as CPU-side data, never a Node")
		assert_true(first_payload[2] is Dictionary,
			"water crosses the worker boundary as CPU-side data, never a Node")
		assert_false(_contains_scene_or_server_resource(first_payload[1]),
			"terrain worker payload has no scene/render/physics resources")
		assert_false(_contains_scene_or_server_resource(first_payload[2]),
			"water worker payload has no scene/render/physics resources")
	s.MAX_BUILD_PER_FRAME = 4
	# the whole 3x3 radius arrives from the background thread
	var deadline := Time.get_ticks_msec() + 60_000
	while s._built.size() < 9 and Time.get_ticks_msec() < deadline:
		await wait_seconds(0.25)
	assert_eq(s._built.size(), 9, "radius-1 ring built in the background")
	for c in s._built:
		assert_true(is_instance_valid(s._built[c]), "chunk node alive: %s" % str(c))
	assert_eq(player.process_mode, Node.PROCESS_MODE_INHERIT,
		"player released once their chunk landed")
