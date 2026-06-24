extends GutTest

# Socket <-> world-direction mapping for heightfield placement (Phase 3b).

func test_offset_to_socket_covers_four_cardinals_and_four_diagonals() -> void:
	var seen: Dictionary = {}
	for off in HeightfieldFacing.OFFSET_TO_SOCKET.keys():
		seen[HeightfieldFacing.OFFSET_TO_SOCKET[off]] = true
	for name in ["front", "right", "back", "left",
			"frontright", "backright", "backleft", "frontleft"]:
		assert_true(seen.has(name), "mapping includes socket '%s'" % name)

func test_offset_to_socket_matches_scene_for_all_cardinals() -> void:
	# Asset grounding: each cardinal socket's OFFSET_TO_SOCKET entry must equal the
	# UNIT direction (sign included) of that marker's horizontal position in the
	# real scene — so a front<->back or left<->right sign flip is caught, not just
	# an axis swap.
	var scene: PackedScene = load("res://terrain/scenes/cliff/CliffSide.tscn")
	var root: Node3D = scene.instantiate()
	var sockets: Node = root.get_node("Sockets")
	for socket_name in ["front", "right", "back", "left"]:
		var m: Marker3D = sockets.get_node(socket_name) as Marker3D
		var p: Vector3 = m.position
		var expected: Vector2i = Vector2i(signi(int(round(p.x))), signi(int(round(p.z))))
		assert_eq(HeightfieldFacing.socket_to_offset(socket_name), expected,
			"%s offset matches its marker direction incl. sign" % socket_name)
	root.free()

func test_yaw_for_rotation_steps() -> void:
	assert_almost_eq(HeightfieldFacing.yaw_for_rotation_steps(0), 0.0, 0.0001, "0 steps => 0 rad")
	assert_almost_eq(HeightfieldFacing.yaw_for_rotation_steps(1), PI * 0.5 * 3.0, 0.0001, "matches (4-steps)%4 convention")
	assert_almost_eq(HeightfieldFacing.yaw_for_rotation_steps(2), PI, 0.0001, "2 steps => 180 deg")
	assert_almost_eq(HeightfieldFacing.yaw_for_rotation_steps(3), PI * 0.5, 0.0001, "3 steps => 90 deg")
