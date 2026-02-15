extends GutTest

var _objects_to_free: Array[Object] = []
var _pieces_to_destroy: Array[TerrainModuleInstance] = []


func after_each() -> void:
	for p: TerrainModuleInstance in _pieces_to_destroy:
		if p != null and p.root != null:
			if p.root.get_parent() != null:
				p.root.get_parent().remove_child(p.root)
			p.root.free()
	_pieces_to_destroy.clear()

	for o: Object in _objects_to_free:
		if is_instance_valid(o) and not o is RefCounted:
			o.free()
	_objects_to_free.clear()


func _make_scene_with_socket(socket_name: String, local_pos: Vector3) -> PackedScene:
	var root: Node3D = Node3D.new()
	var mesh_i: MeshInstance3D = MeshInstance3D.new()
	mesh_i.name = "Mesh"
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3.ONE
	mesh_i.mesh = bm
	root.add_child(mesh_i)

	var body: StaticBody3D = StaticBody3D.new()
	body.name = "StaticBody3D"
	var cs: CollisionShape3D = CollisionShape3D.new()
	cs.name = "CollisionShape3D"
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3.ONE
	cs.shape = shape
	body.add_child(cs)
	root.add_child(body)

	var sockets: Node3D = Node3D.new()
	sockets.name = "Sockets"
	root.add_child(sockets)

	var marker: Marker3D = Marker3D.new()
	marker.name = socket_name
	marker.transform = Transform3D(Basis.IDENTITY, local_pos)
	sockets.add_child(marker)

	sockets.owner = root
	mesh_i.owner = root
	body.owner = root
	cs.owner = root
	marker.owner = root

	var scene: PackedScene = PackedScene.new()
	scene.pack(root)
	root.free()
	return scene


func _make_piece(world_pos: Vector3, socket_name: String = "main", socket_local: Vector3 = Vector3.ZERO) -> TerrainModuleInstance:
	var scene: PackedScene = _make_scene_with_socket(socket_name, socket_local)
	var mod: TerrainModule = TerrainModule.new(scene, AABB(), TagList.new(), {}, [], {}, {}, {}, {}, false)
	var piece: TerrainModuleInstance = mod.spawn()
	piece.set_transform(Transform3D(Basis.IDENTITY, world_pos))
	piece.create()
	_pieces_to_destroy.append(piece)
	return piece


func test_insert_and_query_returns_socket():
	var idx: PositionIndex = PositionIndex.new()
	_objects_to_free.append(idx)

	var piece: TerrainModuleInstance = _make_piece(Vector3(1, 0, 2), "main", Vector3.ZERO)
	var ps: TerrainModuleSocket = TerrainModuleSocket.new(piece, "main")
	idx.insert(ps)

	var hit: TerrainModuleSocket = idx.query(Vector3(1, 0, 2))
	assert_true(hit != null)
	assert_eq(hit.piece, piece)
	assert_eq(hit.socket_name, "main")


func test_query_other_excludes_current_piece():
	var idx: PositionIndex = PositionIndex.new()
	_objects_to_free.append(idx)

	var piece_a: TerrainModuleInstance = _make_piece(Vector3.ZERO, "main", Vector3.ZERO)
	var piece_b: TerrainModuleInstance = _make_piece(Vector3.ZERO, "main", Vector3.ZERO)

	idx.insert(TerrainModuleSocket.new(piece_a, "main"))
	idx.insert(TerrainModuleSocket.new(piece_b, "main"))

	var hit_from_a: TerrainModuleSocket = idx.query_other(Vector3.ZERO, piece_a)
	var hit_from_b: TerrainModuleSocket = idx.query_other(Vector3.ZERO, piece_b)
	assert_true(hit_from_a != null)
	assert_true(hit_from_b != null)
	assert_eq(hit_from_a.piece, piece_b)
	assert_eq(hit_from_b.piece, piece_a)


func test_query_other_returns_null_when_only_self_present():
	var idx: PositionIndex = PositionIndex.new()
	_objects_to_free.append(idx)

	var piece: TerrainModuleInstance = _make_piece(Vector3(3, 0, -4), "main", Vector3.ZERO)
	idx.insert(TerrainModuleSocket.new(piece, "main"))

	var hit: TerrainModuleSocket = idx.query_other(Vector3(3, 0, -4), piece)
	assert_true(hit == null)
