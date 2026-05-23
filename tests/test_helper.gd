extends GutTest

# ------------------------------------------------------------
# Socket System Tests
# ------------------------------------------------------------

func test_get_attachment_socket_name_basic_directions():
	assert_eq(Helper.get_attachment_socket_name("front"), "back", "front attaches to back")
	assert_eq(Helper.get_attachment_socket_name("back"), "front", "back attaches to front")
	assert_eq(Helper.get_attachment_socket_name("left"), "right", "left attaches to right")
	assert_eq(Helper.get_attachment_socket_name("right"), "left", "right attaches to left")

func test_get_attachment_socket_name_top_sockets():
	assert_eq(Helper.get_attachment_socket_name("top"), "bottom", "top attaches to bottom")
	assert_eq(Helper.get_attachment_socket_name("topfront"), "bottom", "topfront attaches to bottom")
	assert_eq(Helper.get_attachment_socket_name("topleft"), "bottom", "topleft attaches to bottom")

func test_get_attachment_socket_name_bottom_and_top():
	assert_eq(Helper.get_attachment_socket_name("bottom"), "topcenter", "bottom attaches to topcenter")
	assert_eq(Helper.get_attachment_socket_name("top"), "bottom", "top attaches to bottom")

func test_get_attachment_socket_name_unknown():
	assert_eq(Helper.get_attachment_socket_name("unknown"), "bottom", "unknown socket defaults to bottom")


func test_rotate_adjacency_basic_rotation():
	var adjacency = {
		"front": null,
		"right": null,
		"back": null,
		"left": null
	}
	
	var rotated = Helper.rotate_adjacency(adjacency)
	
	assert_true(rotated.has("right"), "should have right key")
	assert_true(rotated.has("back"), "should have back key")
	assert_true(rotated.has("left"), "should have left key")
	assert_true(rotated.has("front"), "should have front key")
	
	# front -> right, right -> back, back -> left, left -> front
	assert_eq(rotated["right"], adjacency["front"], "front should rotate to right")
	assert_eq(rotated["back"], adjacency["right"], "right should rotate to back")
	assert_eq(rotated["left"], adjacency["back"], "back should rotate to left")
	assert_eq(rotated["front"], adjacency["left"], "left should rotate to front")

func test_rotate_adjacency_compound_directions():
	var adjacency = {
		"frontright": null,
		"backright": null,
		"backleft": null,
		"frontleft": null
	}
	
	var rotated = Helper.rotate_adjacency(adjacency)
	
	# frontright -> backright, backright -> backleft, backleft -> frontleft, frontleft -> frontright
	assert_eq(rotated["backright"], adjacency["frontright"], "frontright should rotate to backright")
	assert_eq(rotated["backleft"], adjacency["backright"], "backright should rotate to backleft")
	assert_eq(rotated["frontleft"], adjacency["backleft"], "backleft should rotate to frontleft")
	assert_eq(rotated["frontright"], adjacency["frontleft"], "frontleft should rotate to frontright")

func test_rotate_adjacency_mixed_directions():
	var adjacency = {
		"front": null,
		"frontright": null,
		"top": null
	}
	
	var rotated = Helper.rotate_adjacency(adjacency)
	
	assert_eq(rotated["right"], adjacency["front"], "front rotates to right")
	assert_eq(rotated["backright"], adjacency["frontright"], "frontright rotates to backright")
	assert_eq(rotated["top"], adjacency["top"], "top stays as top (no rotation rule)")

func test_rotate_adjacency_empty():
	var adjacency = {}
	var rotated = Helper.rotate_adjacency(adjacency)
	assert_eq(rotated.size(), 0, "empty adjacency should remain empty")


func test_snap_vec3_snaps_to_grid():
	var out: Vector3 = Helper.snap_vec3(Vector3(0.015, -0.014, 1.234))
	assert_eq(out, Vector3(0.01, -0.01, 1.23))


func test_to_root_tf_accumulates_parent_transforms():
	var root: Node3D = Node3D.new()
	add_child_autofree(root)

	var parent: Node3D = Node3D.new()
	root.add_child(parent)
	parent.transform = Transform3D(Basis.IDENTITY, Vector3(2, 0, 0))

	var socket: Marker3D = Marker3D.new()
	parent.add_child(socket)
	socket.transform = Transform3D(Basis.IDENTITY, Vector3(0, 0, 3))

	var tf_to_root: Transform3D = Helper.to_root_tf(socket, root)
	assert_eq(tf_to_root.origin, Vector3(2, 0, 3))


func test_socket_world_pos_uses_piece_transform_off_tree():
	var root: Node3D = Node3D.new()
	var sockets: Node3D = Node3D.new()
	sockets.name = "Sockets"
	root.add_child(sockets)

	var sock: Marker3D = Marker3D.new()
	sock.name = "right"
	sock.transform = Transform3D(Basis.IDENTITY, Vector3(1, 0, 0))
	sockets.add_child(sock)

	var piece_tf: Transform3D = Transform3D(Basis.IDENTITY, Vector3(10, 0, 5))
	var world_pos: Vector3 = Helper.socket_world_pos(piece_tf, sock, root)
	assert_eq(world_pos, Vector3(11, 0, 5))

	root.free()