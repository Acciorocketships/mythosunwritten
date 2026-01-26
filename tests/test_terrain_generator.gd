extends GutTest

# ------------------------------------------------------------
# Leak/orphan prevention
# ------------------------------------------------------------
var _objects_to_free: Array[Object] = []
var _pieces_to_destroy: Array[TerrainModuleInstance] = []
var _nodes_to_free: Array[Node] = []

func before_each() -> void:
	_objects_to_free.clear()
	_pieces_to_destroy.clear()
	_nodes_to_free.clear()

func after_each() -> void:
	# TerrainModuleInstance roots are Nodes and must be freed explicitly.
	for p: TerrainModuleInstance in _pieces_to_destroy:
		if p != null:
			p.destroy()
	_pieces_to_destroy.clear()

	# Non-RefCounted Objects must be freed explicitly.
	for o: Object in _objects_to_free:
		if is_instance_valid(o):
			o.free()
	_objects_to_free.clear()

	# Nodes created by tests but never added to the scene tree must be freed explicitly.
	for n: Node in _nodes_to_free:
		if is_instance_valid(n):
			# If it ended up in the tree, queue it; otherwise free immediately.
			if n.is_inside_tree():
				n.queue_free()
			else:
				n.free()
	_nodes_to_free.clear()

# Helpers
func _make_scene_with_sockets(
	pos_by_name: Dictionary[String, Vector3],
	mesh_size: Vector3 = Vector3.ONE,
	with_collision: bool = true
) -> PackedScene:
	var root: Node3D = Node3D.new()

	# Provide a mesh so TerrainModuleInstance can compute bounds automatically.
	var mesh_i: MeshInstance3D = MeshInstance3D.new()
	mesh_i.name = "Mesh"
	var bm: BoxMesh = BoxMesh.new()
	bm.size = mesh_size
	mesh_i.mesh = bm
	root.add_child(mesh_i)

	if with_collision:
		var body: StaticBody3D = StaticBody3D.new()
		body.name = "StaticBody3D"
		var cs: CollisionShape3D = CollisionShape3D.new()
		cs.name = "CollisionShape3D"
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = mesh_size
		cs.shape = shape
		body.add_child(cs)
		root.add_child(body)

	var sockets: Node3D = Node3D.new()
	sockets.name = "Sockets"
	root.add_child(sockets)
	for sock_name: String in pos_by_name.keys():
		var m: Marker3D = Marker3D.new()
		m.name = sock_name
		m.transform.origin = pos_by_name[sock_name]
		sockets.add_child(m)
	# Ensure children are included in PackedScene by setting owners.
	mesh_i.owner = root
	if with_collision:
		var body2: Node = root.get_node("StaticBody3D")
		if body2 != null:
			body2.owner = root
			var cs2: Node = body2.get_node("CollisionShape3D")
			if cs2 != null:
				cs2.owner = root
	sockets.owner = root
	for c in sockets.get_children():
		if c is Node:
			(c as Node).owner = root
	var ps: PackedScene = PackedScene.new()
	ps.pack(root)
	# PackedScene.pack() duplicates data; free the temporary node tree immediately.
	root.free()
	return ps

func _make_module(size: Vector3, pos_by_name: Dictionary[String, Vector3]) -> TerrainModule:
	var scene: PackedScene = _make_scene_with_sockets(pos_by_name, size)
	var mod: TerrainModule = TerrainModule.new(scene, AABB(), TagList.new())
	# Ensure sockets are considered fillable in tests
	var fill: Dictionary[String, float] = {}
	for n: String in pos_by_name.keys():
		fill[n] = 1.0
	# Also include main if not present
	if not pos_by_name.has("main"):
		fill["main"] = 1.0
	mod.socket_fill_prob = fill
	# Ensure sockets are considered size-capable by get_adjacent_from_size() in tests.
	var sizes: Dictionary[String, Distribution] = {}
	for n: String in fill.keys():
		# The key inside this distribution is not used by get_adjacent_from_size(); it only checks
		# that socket_size has an entry for the socket name. Use a real size tag for clarity.
		sizes[n] = Distribution.new({"24x24": 1.0})
	mod.socket_size = sizes
	return mod

func _spawn_piece(
	mod: TerrainModule,
	tf: Transform3D = Transform3D.IDENTITY
) -> TerrainModuleInstance:
	var inst: TerrainModuleInstance = mod.spawn()
	inst.set_transform(tf)
	inst.create()
	_pieces_to_destroy.append(inst)
	return inst

# A compact default socket layout used in multiple tests
func _default_socket_layout() -> Dictionary[String, Vector3]:
	return {
		"main": Vector3(0, 0, 0),
		"left": Vector3(-1, 0, 0),
		"right": Vector3(1, 0, 0),
		"back": Vector3(0, 0, -1),
	}

func _socket_layout_main_offset() -> Dictionary[String, Vector3]:
	return {
		# "main" is on the front edge (+Z), opposite of "back" (-Z), like left/right.
		"main": Vector3(0, 0, 1),
		"left": Vector3(-1, 0, 0),
		"right": Vector3(1, 0, 0),
		"back": Vector3(0, 0, -1),
	}

func _new_generator() -> Variant:
	var Generator: Script = preload("res://scripts/TerrainGenerator.gd")
	var g: Variant = Generator.new()
	_nodes_to_free.append(g)

	g.player = Node3D.new()
	g.terrain_parent = Node.new()
	g.library = TerrainModuleLibrary.new()
	g.socket_index = PositionIndex.new()
	_nodes_to_free.append(g.player)
	_nodes_to_free.append(g.terrain_parent)
	_nodes_to_free.append(g.library)
	_nodes_to_free.append(g.socket_index)

	g.terrain_index = TerrainIndex.new()
	g.queue = PriorityQueue.new()
	_objects_to_free.append(g.terrain_index)
	_objects_to_free.append(g.queue)
	return g


func test_get_dist_from_player():
	var gen: Variant = _new_generator()
	add_child_autofree(gen.player)
	gen.player.global_position = Vector3(1, 0, 0)
	var sock: Marker3D = Marker3D.new()
	add_child_autofree(sock)
	sock.global_position = Vector3.ZERO
	var d: float = gen.get_dist_from_player(sock)
	assert_eq(d, 1.0)


func test_can_place_true_when_index_empty():
	var gen: Variant = _new_generator()
	var mod: TerrainModule = _make_module(Vector3(2, 2, 2), {"main": Vector3.ZERO})
	var piece: TerrainModuleInstance = _spawn_piece(mod)
	# can_place requires a parent piece (can be null for no parent)
	assert_true(gen.can_place(piece, null))


func test_can_place_allows_touching_edges_after_alignment():
	var gen: Variant = _new_generator()
	var mod: TerrainModule = _make_module(Vector3(2, 2, 2), {"main": Vector3.ZERO})
	var start: TerrainModuleInstance = _spawn_piece(mod)
	gen.terrain_index.insert(start)
	var neighbor: TerrainModuleInstance = mod.spawn()
	neighbor.set_position(Vector3(2, 0, 0)) # edge-touching on X
	neighbor.create()
	_pieces_to_destroy.append(neighbor)
	assert_true(gen.can_place(neighbor, start))


func test_can_place_false_when_overlap_exists():
	var gen: Variant = _new_generator()
	# New piece at origin with 2x2x2 size
	var new_mod: TerrainModule = _make_module(Vector3(2, 2, 2), {"main": Vector3.ZERO})
	var new_piece: TerrainModuleInstance = _spawn_piece(new_mod)
	# Insert another overlapping module into the index
	var other_mod: TerrainModule = _make_module(Vector3(2, 2, 2), {"main": Vector3.ZERO})
	var other_piece: TerrainModuleInstance = other_mod.spawn()
	other_piece.set_position(Vector3(0.5, 0, 0.5)) # overlaps at origin
	other_piece.create()
	_pieces_to_destroy.append(other_piece)
	gen.terrain_index.insert(other_piece)
	assert_false(gen.can_place(new_piece, null))


func test_transform_to_socket_aligns_position():
	var gen: Variant = _new_generator()
	var mod: TerrainModule = _make_module(Vector3(2, 2, 2), _default_socket_layout())
	var orig: TerrainModuleInstance = _spawn_piece(mod)
	var newp: TerrainModuleInstance = _spawn_piece(mod)
	var orig_ps: TerrainModuleSocket = TerrainModuleSocket.new(orig, "left")
	var new_ps: TerrainModuleSocket = TerrainModuleSocket.new(newp, "main")
	gen.transform_to_socket(new_ps, orig_ps)
	assert_eq(newp.get_position(), Vector3(-1, 0, 0))


func test_transform_to_socket_aligns_normals_opposite_and_sockets_coincide():
	var gen: Variant = _new_generator()
	var mod: TerrainModule = _make_module(Vector3(2, 2, 2), _default_socket_layout())
	var orig: TerrainModuleInstance = _spawn_piece(mod)
	var newp: TerrainModuleInstance = _spawn_piece(mod)
	var orig_ps: TerrainModuleSocket = TerrainModuleSocket.new(orig, "left")
	var new_ps: TerrainModuleSocket = TerrainModuleSocket.new(newp, "main")
	# Act
	gen.transform_to_socket(new_ps, orig_ps)
	# Sockets must coincide
	var p_orig: Vector3 = orig_ps.get_socket_position()
	var p_new: Vector3 = new_ps.get_socket_position()
	assert_almost_eq((p_orig - p_new).length(), 0.0, 0.0001)

func test_transform_to_socket_handles_main_not_centered():
	var gen: Variant = _new_generator()
	# Main is not at origin, but is on the +X face center (stable normal).
	var mod: TerrainModule = _make_module(
		Vector3(2, 2, 2),
		{
			"main": Vector3(1, 0, 0),
			"left": Vector3(-1, 0, 0),
			"right": Vector3(1, 0, 0),
			"back": Vector3(0, 0, -1),
		}
	)
	var orig: TerrainModuleInstance = _spawn_piece(mod)
	var newp: TerrainModuleInstance = _spawn_piece(mod)
	# Attach new piece's main to orig's left
	var orig_ps: TerrainModuleSocket = TerrainModuleSocket.new(orig, "left")
	var new_ps: TerrainModuleSocket = TerrainModuleSocket.new(newp, "main")
	gen.transform_to_socket(new_ps, orig_ps)
	# Sockets coincide exactly on-grid
	var p_orig: Vector3 = orig_ps.get_socket_position()
	var p_new: Vector3 = new_ps.get_socket_position()
	assert_almost_eq((p_orig - p_new).length(), 0.0, 0.0001)


func test_transform_to_socket_rotated_parent_socket_places_adjacent_not_overlapping():
	# Regression for a real-world failure: when sockets sit on y=0, transform_to_socket must still
	# place adjacent (not overlapping), even with rotated parent sockets.
	var gen: Variant = _new_generator()

	var size := Vector3(24, 2, 24)
	var half_x := size.x * 0.5
	var half_z := size.z * 0.5

	var pos_by_name: Dictionary[String, Vector3] = {
		# sockets on the perimeter (y=0 plane, like the ground tiles)
		"main": Vector3(half_x, 0, 0),
		"back": Vector3(-half_x, 0, 0),
		"left": Vector3(0, 0, -half_z),
		"right": Vector3(0, 0, half_z),
	}

	var scene: PackedScene = _make_scene_with_sockets(pos_by_name, size)
	var mod: TerrainModule = TerrainModule.new(scene, AABB(), TagList.new())
	var fill: Dictionary[String, float] = {}
	for n: String in pos_by_name.keys():
		fill[n] = 1.0
	mod.socket_fill_prob = fill

	# Parent tile rotated so its local "back" (-X) points to world +Z.
	var rot := Basis(Vector3.UP, deg_to_rad(-90.0))
	var start_tf := Transform3D(rot, Vector3(0, 0, 24))
	var start: TerrainModuleInstance = _spawn_piece(mod, start_tf)

	# Candidate starts at origin; transform_to_socket should move it to +Z (adjacent), not overlap.
	var candidate: TerrainModuleInstance = _spawn_piece(mod)

	var orig_ps := TerrainModuleSocket.new(start, "back")
	var new_ps := TerrainModuleSocket.new(candidate, "main")

	gen.transform_to_socket(new_ps, orig_ps)

	# Sockets coincide
	var orig_socket_pos := orig_ps.get_socket_position()
	var new_socket_pos := new_ps.get_socket_position()
	assert_almost_eq((orig_socket_pos - new_socket_pos).length(), 0.0, 0.0001)

	# Pieces are adjacent (non-overlapping)
	assert_ne(candidate.get_position(), start.get_position())
	assert_false(candidate.aabb.intersects(start.aabb))

	# The socket directions from each piece center should oppose in XZ
	var dir_orig := orig_socket_pos - orig_ps.get_piece_position()
	var dir_new := new_socket_pos - new_ps.get_piece_position()
	var d0 := Vector2(dir_orig.x, dir_orig.z)
	var d1 := Vector2(dir_new.x, dir_new.z)
	if d0.length() > 1e-6 and d1.length() > 1e-6:
		d0 = d0.normalized()
		d1 = d1.normalized()
		assert_almost_eq(d0.dot(d1), -1.0, 0.0001)


func test_add_piece_registers_and_queues():
	var gen: Variant = _new_generator()
	# Ensure nodes using global_position are inside the scene tree
	add_child_autofree(gen.player)
	add_child_autofree(gen.terrain_parent)
	var mod: TerrainModule = _make_module(Vector3(2, 2, 2), _default_socket_layout())
	var orig: TerrainModuleInstance = _spawn_piece(mod)
	# prepare sockets
	var new_inst: TerrainModuleInstance = mod.spawn()
	new_inst.create()
	_pieces_to_destroy.append(new_inst)
	var new_ps: TerrainModuleSocket = TerrainModuleSocket.new(new_inst, "main")
	var orig_ps: TerrainModuleSocket = TerrainModuleSocket.new(orig, "left")
	var ok: bool = gen.add_piece(new_ps, orig_ps)
	assert_true(ok)
	# child added
	assert_eq(gen.terrain_parent.get_child_count(), 1)
	# main socket is not queued (attachment socket)
	assert_eq(gen.queue.size(), new_inst.sockets.size() - 1)
	for e in gen.queue.heap:
		var it: TerrainModuleSocket = e["item"]
		assert_ne(it.socket_name, "main")


class FakeLibrary:
	extends TerrainModuleLibrary
	var m1: TerrainModule
	var m2: TerrainModule
	var step: int = 0
	func _init(_m1: TerrainModule, _m2: TerrainModule) -> void:
		m1 = _m1
		m2 = _m2
	func get_required_tags(_adj) -> TagList:
		return TagList.new()
	func get_combined_distribution(_adj) -> Distribution:
		return Distribution.new({"x": 1.0})
	func get_by_tags(_tags) -> TerrainModuleList:
		return TerrainModuleList.new([m1, m2])
	func sample_from_modules(_modules, _dist) -> TerrainModule:
		step += 1
		return m1 if step == 1 else m2


func test_get_adjacent_from_size_hits_expected_sockets():
	var gen: Variant = _new_generator()
	# Use a controlled module and a fake library.
	var mod: TerrainModule = _make_module(Vector3(2, 2, 2), _default_socket_layout())
	# Use the actual library’s simple behavior with a single module in terrain_modules and tag index.
	# Replace the library with a new one, and ensure it is freed with the generator.
	var lib: TerrainModuleLibrary = TerrainModuleLibrary.new()
	gen.add_child(lib)
	gen.library = lib
	gen.library.terrain_modules = TerrainModuleList.new([mod])
	gen.library.modules_by_tag.clear()
	gen.library.modules_by_tag["24x24"] = TerrainModuleList.new([mod])
	# Orig piece at identity
	var orig: TerrainModuleInstance = _spawn_piece(mod)
	var orig_ps: TerrainModuleSocket = TerrainModuleSocket.new(orig, "main")
	# Pre-insert dummy adjacent sockets at expected positions
	var names: Array[String] = ["left", "right", "back"]
	for n in names:
		var dummy_mod: TerrainModule = _make_module(Vector3(1, 1, 1), {"main": Vector3.ZERO})
		var dummy_piece: TerrainModuleInstance = _spawn_piece(dummy_mod)
		# Move its "main" socket to the expected position in local space.
		var m: Marker3D = dummy_piece.sockets.get("main", null)
		assert_true(m != null)
		if n == "left":
			m.transform.origin = Vector3(-1, 0, 0)
		elif n == "right":
			m.transform.origin = Vector3(1, 0, 0)
		else:
			m.transform.origin = Vector3(0, 0, -1)
		gen.socket_index.insert(TerrainModuleSocket.new(dummy_piece, "main"))
	# Query
	var out: Dictionary[String, TerrainModuleSocket] = gen.get_adjacent_from_size(orig_ps, "24x24")
	assert_true(out.has("main"))
	assert_true(out.has("left"))
	assert_true(out.has("right"))
	assert_true(out.has("back"))


func test_add_piece_checks_can_place_after_alignment():
	# Ensures we evaluate placement using the aligned transform, not the origin AABB.
	var gen: Variant = _new_generator()
	add_child_autofree(gen.player)
	add_child_autofree(gen.terrain_parent)
	# Simple square module with 2x2x2 AABB and default sockets
	# Use sockets positioned at face centers one full size away so pieces don't overlap after
	# alignment.
	var mod: TerrainModule = _make_module(
		Vector3(2, 2, 2),
		{
			"main": Vector3(0, 0, 0),
			"left": Vector3(-2, 0, 0),
			"right": Vector3(2, 0, 0),
			"back": Vector3(0, 0, -2),
		}
	)
	# Start piece at origin
	var start: TerrainModuleInstance = _spawn_piece(mod)
	gen.terrain_parent.add_child(start.root)
	# Register so TerrainIndex contains the start tile for overlap tests
	gen.register_piece_and_socket(TerrainModuleSocket.new(start, "main"))
	# New candidate spawns at origin and overlaps BEFORE alignment
	var cand: TerrainModuleInstance = _spawn_piece(mod)
	assert_true(cand.aabb.intersects(start.aabb), "precondition: candidate overlaps start at origin")
	# Attach candidate's main to start's left socket
	var orig_ps := TerrainModuleSocket.new(start, "left")
	var new_ps := TerrainModuleSocket.new(cand, "main")
	var ok: bool = gen.add_piece(new_ps, orig_ps)
	assert_true(ok, "add_piece placed after alignment")
	# AFTER alignment, AABBs must not overlap
	assert_false(cand.aabb.intersects(start.aabb), "postcondition: no overlap after placement")


class _FakeSingleLib:
	extends TerrainModuleLibrary
	var _m: TerrainModule
	func _init(m: TerrainModule) -> void:
		_m = m
	func get_required_tags(_adj) -> TagList:
		return TagList.new()
	func get_combined_distribution(_adj) -> Distribution:
		return Distribution.new({"x": 1.0})
	func get_by_tags(_tags) -> TerrainModuleList:
		return TerrainModuleList.new([_m])
	func sample_from_modules(_modules, _dist) -> TerrainModule:
		return _m

func test_integration_one_iteration_places_expected_tile_to_right():
	# Run one iteration of load_terrain with a controlled library and start tile.
	var gen: Variant = _new_generator()
	add_child_autofree(gen.player)
	add_child_autofree(gen.terrain_parent)
	gen.player.global_position = Vector3.ZERO
	gen.RENDER_RANGE = 10000
	gen.MAX_LOAD_PER_STEP = 1
	# Module: 2x2x2 with sockets on face centers and size tag "2x2".
	# Important: "main" is the attachment socket, so for placing a tile to the right (+X),
	# main must be on the LEFT face (-X) so it can connect to the parent's "right" socket (+X).
	var layout: Dictionary[String, Vector3] = {
		"main": Vector3(-1, 0, 0),
		"left": Vector3(-1, 0, 0),
		"right": Vector3(1, 0, 0),
		"back": Vector3(0, 0, -1),
	}
	var mod: TerrainModule = _make_module(Vector3(2, 2, 2), layout)
	mod.tags = TagList.new(["2x2"])
	mod.socket_size = {
		"main": Distribution.new({"2x2": 1.0}),
		"left": Distribution.new({"2x2": 1.0}),
		"right": Distribution.new({"2x2": 1.0}),
		"back": Distribution.new({"2x2": 1.0}),
	}
	var fake_lib: TerrainModuleLibrary = _FakeSingleLib.new(mod)
	gen.add_child(fake_lib)
	gen.library = fake_lib
	# Start piece at origin; add to tree and indices
	var start: TerrainModuleInstance = _spawn_piece(mod)
	gen.terrain_parent.add_child(start.root)
	gen.register_piece_and_socket(TerrainModuleSocket.new(start, "main"))
	# Seed queue with one socket: place to the right
	gen.queue = PriorityQueue.new()
	_objects_to_free.append(gen.queue)
	var item: TerrainModuleSocket = TerrainModuleSocket.new(start, "right")
	var dist: float = gen.get_dist_from_player(item.socket)
	gen.queue.push(item, dist)
	# Act: one iteration
	gen.load_terrain()
	# Assert: exactly one new child placed
	assert_eq(gen.terrain_parent.get_child_count(), 2)
	# Find the new node and assert its position is exactly at +2 on X (edge-touching)
	var placed_root: Node3D = null
	for c in gen.terrain_parent.get_children():
		if c != start.root:
			placed_root = c as Node3D
	assert_true(placed_root != null)
	assert_eq(placed_root.global_position, Vector3(2, 0, 0))
	# And ensure we did not enqueue the "main" socket of the new piece
	for e in gen.queue.heap:
		var it: TerrainModuleSocket = e["item"]
		assert_ne(it.socket_name, "main")
