extends GutTest

# Socket <-> world-direction mapping for heightfield placement (Phase 3b).

func test_offset_to_socket_covers_four_cardinals_and_four_diagonals() -> void:
	var seen: Dictionary = {}
	for off in HeightfieldFacing.OFFSET_TO_SOCKET.keys():
		seen[HeightfieldFacing.OFFSET_TO_SOCKET[off]] = true
	for name in ["front", "right", "back", "left",
			"frontright", "backright", "backleft", "frontleft"]:
		assert_true(seen.has(name), "mapping includes socket '%s'" % name)

func test_offset_to_socket_matches_scene_for_one_cardinal() -> void:
	var scene: PackedScene = load("res://terrain/scenes/CliffSide.tscn")
	var root: Node3D = scene.instantiate()
	var sockets: Node = root.get_node("Sockets")
	var front_marker: Marker3D = sockets.get_node("front") as Marker3D
	var p: Vector3 = front_marker.position
	root.free()
	var front_offset: Vector2i = HeightfieldFacing.socket_to_offset("front")
	if absf(p.x) > absf(p.z):
		assert_true(front_offset.x != 0 and front_offset.y == 0, "front is an X-axis face")
	else:
		assert_true(front_offset.y != 0 and front_offset.x == 0, "front is a Z-axis face")

func test_yaw_for_rotation_steps() -> void:
	assert_almost_eq(HeightfieldFacing.yaw_for_rotation_steps(0), 0.0, 0.0001, "0 steps => 0 rad")
	assert_almost_eq(HeightfieldFacing.yaw_for_rotation_steps(1), PI * 0.5 * 3.0, 0.0001, "matches (4-steps)%4 convention")
	assert_almost_eq(HeightfieldFacing.yaw_for_rotation_steps(2), PI, 0.0001, "2 steps => 180 deg")
