extends GutTest

## TerrainModuleInstance tags each socket level/slope from its baked marker Y.

func test_socket_category_from_marker_y() -> void:
	var inst := TerrainModuleInstance.new(TerrainModuleDefinitions.create_24x24_test_piece())
	var socket_root := Node3D.new()
	var flat := Marker3D.new()
	flat.name = "topfront"
	flat.transform.origin = Vector3(0.0, 0.0, -9.0)
	var low := Marker3D.new()
	low.name = "topback"
	low.transform.origin = Vector3(0.0, -2.0, 9.0)
	socket_root.add_child(flat)
	socket_root.add_child(low)
	add_child_autofree(socket_root)
	inst.socket_node = socket_root
	inst._find_sockets()
	assert_eq(inst.get_socket_category("topfront"), "level", "y~0 socket is level")
	assert_eq(inst.get_socket_category("topback"), "slope", "socket dropped below the plateau is slope")
	assert_eq(inst.get_socket_category("missing"), "level", "unknown socket defaults to level")
