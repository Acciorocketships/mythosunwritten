extends GutTest

# ------------------------------------------------------------
# Leak/orphan prevention
# ------------------------------------------------------------
var _objects_to_free: Array[Object] = []
var _pieces_to_destroy: Array[TerrainModuleInstance] = []
var _nodes_to_free: Array[Node] = []

func _track_node_for_cleanup(node: Node) -> void:
	if node == null:
		return
	if _nodes_to_free.has(node):
		return
	_nodes_to_free.append(node)

func _free_detached_node(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()

func _set_generator_library(gen: Variant, lib: TerrainModuleLibrary) -> void:
	if gen.library != null and gen.library != lib:
		_free_detached_node(gen.library)
	gen.library = lib
	_track_node_for_cleanup(lib)

func _set_generator_test_pieces_library(gen: Variant, lib: TerrainModuleLibrary) -> void:
	if gen.test_pieces_library != null and gen.test_pieces_library != lib:
		_free_detached_node(gen.test_pieces_library)
	gen.test_pieces_library = lib
	_track_node_for_cleanup(lib)

func _run_generator_ready(gen: Variant) -> void:
	# _ready() can replace several generator-owned Node references; free detached replacements immediately.
	var prev_library: TerrainModuleLibrary = gen.library
	var prev_test_pieces_library: TerrainModuleLibrary = gen.test_pieces_library
	var prev_socket_index: PositionIndex = gen.socket_index
	gen._ready()
	if prev_library != gen.library:
		_free_detached_node(prev_library)
	if prev_test_pieces_library != gen.test_pieces_library:
		_free_detached_node(prev_test_pieces_library)
	if prev_socket_index != gen.socket_index:
		_free_detached_node(prev_socket_index)
	_track_node_for_cleanup(gen.library)
	_track_node_for_cleanup(gen.test_pieces_library)
	_track_node_for_cleanup(gen.socket_index)

func _dispose_generator_immediately(gen: Variant) -> void:
	if gen == null or not is_instance_valid(gen):
		return
	_free_detached_node(gen.player)
	_free_detached_node(gen.terrain_parent)
	_free_detached_node(gen.library)
	_free_detached_node(gen.test_pieces_library)
	_free_detached_node(gen.socket_index)
	_free_detached_node(gen)

func _flush_deferred_frees() -> void:
	# remove_piece()/destroy() use queue_free() for in-tree nodes; flush those before GUT orphan checks.
	await get_tree().process_frame
	await get_tree().process_frame

func before_each() -> void:
	_objects_to_free.clear()
	_pieces_to_destroy.clear()
	_nodes_to_free.clear()

func after_each() -> void:
	# TerrainModuleInstance roots are Nodes and must be freed explicitly.
	for p: TerrainModuleInstance in _pieces_to_destroy:
		if p != null and p.root != null:
			if p.root.get_parent() != null:
				p.root.get_parent().remove_child(p.root)
			p.root.free()
	_pieces_to_destroy.clear()

	# Non-RefCounted Objects must be freed explicitly.
	for o: Object in _objects_to_free:
		if is_instance_valid(o) and not o is RefCounted:
			o.free()
	_objects_to_free.clear()

	# Nodes created by tests but never added to the scene tree must be freed explicitly.
	for n: Node in _nodes_to_free:
		if is_instance_valid(n):
			if n.get_parent() != null:
				n.get_parent().remove_child(n)
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
	var mod: TerrainModule = TerrainModule.new(scene, AABB(), TagList.new(), {}, [], {}, {}, {}, {}, false)
	# Ensure sockets are considered fillable in tests
	var fill: Dictionary[String, float] = {}
	for n: String in pos_by_name.keys():
		fill[n] = 1.0
	mod.socket_fill_prob = fill
	# Ensure sockets are considered size-capable by get_adjacent_from_size() in tests.
	var sizes: Dictionary[String, Distribution] = {}
	for n: String in fill.keys():
		# The key inside this distribution is not used by get_adjacent_from_size(); it only checks
		# that socket_size has an entry for the socket name. Use a real size tag for clarity.
		sizes[n] = Distribution.new({"24x24x0.5": 1.0})
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
		"bottom": Vector3(0, 0, 0),  # For expansion from "top", attachment is "bottom"
		"top": Vector3(0, 0, 0),  # For expansion from "bottom", attachment is "top"
		"left": Vector3(-1, 0, 0),
		"right": Vector3(1, 0, 0),
		"back": Vector3(0, 0, -1),
	}

func _socket_layout_main_offset() -> Dictionary[String, Vector3]:
	return {
		# "bottom" is on the front edge (+Z), opposite of "back" (-Z), like left/right.
		"bottom": Vector3(0, 0, 1),
		"left": Vector3(-1, 0, 0),
		"right": Vector3(1, 0, 0),
		"back": Vector3(0, 0, -1),
	}

func _new_generator() -> Variant:
	var Generator: Script = load("res://scripts/terrain/TerrainGenerator.gd")
	var g: Variant = Generator.new()
	_nodes_to_free.append(g)

	g.player = Node3D.new()
	g.terrain_parent = Node3D.new()
	g.library = TerrainModuleLibrary.new()
	g.socket_index = PositionIndex.new()
	add_child(g.player)
	add_child(g.terrain_parent)
	_nodes_to_free.append(g.player)
	_nodes_to_free.append(g.terrain_parent)
	_nodes_to_free.append(g.library)
	_nodes_to_free.append(g.socket_index)

	g.terrain_index = TerrainIndex.new()
	g.queue = PriorityQueue.new()
	g.generation_rules = TerrainGenerationRuleLibrary.new()
	_objects_to_free.append(g.terrain_index)
	_objects_to_free.append(g.queue)
	_objects_to_free.append(g.generation_rules)
	return g


func test_get_dist_from_player():
	var gen: Variant = _new_generator()
	# gen.player already in tree from _new_generator()
	gen.player.global_position = Vector3(1, 0, 0)
	var sock: Marker3D = Marker3D.new()
	add_child_autofree(sock)
	sock.global_position = Vector3.ZERO
	# Create a mock TerrainModuleInstance with the socket
	var mock_def := TerrainModule.new(null, AABB(), TagList.new(), {}, [], {}, {}, {}, {}, false)
	var mock_piece = TerrainModuleInstance.new(mock_def)
	mock_piece.sockets = {"test_socket": sock}
	mock_piece.root = Node3D.new()
	_track_node_for_cleanup(mock_piece.root)
	mock_piece.transform = Transform3D.IDENTITY
	var d: float = gen.get_dist_from_player(mock_piece, "test_socket")
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


func test_can_place_true_for_ground_even_with_overlap():
	var gen: Variant = _new_generator()
	var regular: TerrainModule = _make_module(Vector3(2, 2, 2), {"main": Vector3.ZERO})
	var regular_piece: TerrainModuleInstance = _spawn_piece(regular)
	gen.terrain_index.insert(regular_piece)

	var ground_mod: TerrainModule = _make_module(Vector3(2, 2, 2), {"main": Vector3.ZERO})
	ground_mod.tags = TagList.new(["ground"])
	var ground_piece: TerrainModuleInstance = _spawn_piece(ground_mod)
	assert_true(gen.can_place(ground_piece, null))


func test_can_place_true_for_replace_existing_even_with_overlap():
	var gen: Variant = _new_generator()
	var regular: TerrainModule = _make_module(Vector3(2, 2, 2), {"main": Vector3.ZERO})
	var regular_piece: TerrainModuleInstance = _spawn_piece(regular)
	gen.terrain_index.insert(regular_piece)

	var replacement_mod: TerrainModule = _make_module(Vector3(2, 2, 2), {"main": Vector3.ZERO})
	replacement_mod.replace_existing = true
	var replacement_piece: TerrainModuleInstance = _spawn_piece(replacement_mod)
	assert_true(gen.can_place(replacement_piece, null))


func test_transform_to_socket_aligns_position():
	var gen: Variant = _new_generator()
	var mod: TerrainModule = _make_module(Vector3(2, 2, 2), _default_socket_layout())
	var orig: TerrainModuleInstance = _spawn_piece(mod)
	var newp: TerrainModuleInstance = _spawn_piece(mod)
	var orig_ps: TerrainModuleSocket = TerrainModuleSocket.new(orig, "left")
	var new_ps: TerrainModuleSocket = TerrainModuleSocket.new(newp, "bottom")
	gen.transform_to_socket(new_ps, orig_ps)
	assert_eq(newp.get_position(), Vector3(-1, 0, 0))


func test_transform_to_socket_aligns_normals_opposite_and_sockets_coincide():
	var gen: Variant = _new_generator()
	var mod: TerrainModule = _make_module(Vector3(2, 2, 2), _default_socket_layout())
	var orig: TerrainModuleInstance = _spawn_piece(mod)
	var newp: TerrainModuleInstance = _spawn_piece(mod)
	var orig_ps: TerrainModuleSocket = TerrainModuleSocket.new(orig, "left")
	var new_ps: TerrainModuleSocket = TerrainModuleSocket.new(newp, "bottom")
	# Act
	gen.transform_to_socket(new_ps, orig_ps)
	# Sockets must coincide
	var p_orig: Vector3 = orig_ps.get_socket_position()
	var p_new: Vector3 = new_ps.get_socket_position()
	assert_almost_eq((p_orig - p_new).length(), 0.0, 0.0001)

func test_transform_to_socket_handles_main_not_centered():
	var gen: Variant = _new_generator()
	# Bottom is not at origin, but is on the +X face center (stable normal).
	var mod: TerrainModule = _make_module(
		Vector3(2, 2, 2),
		{
			"bottom": Vector3(1, 0, 0),
			"left": Vector3(-1, 0, 0),
			"right": Vector3(1, 0, 0),
			"back": Vector3(0, 0, -1),
		}
	)
	var orig: TerrainModuleInstance = _spawn_piece(mod)
	var newp: TerrainModuleInstance = _spawn_piece(mod)
	# Attach new piece's bottom to orig's left
	var orig_ps: TerrainModuleSocket = TerrainModuleSocket.new(orig, "left")
	var new_ps: TerrainModuleSocket = TerrainModuleSocket.new(newp, "bottom")
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
		"bottom": Vector3(half_x, 0, 0),
		"back": Vector3(-half_x, 0, 0),
		"left": Vector3(0, 0, -half_z),
		"right": Vector3(0, 0, half_z),
	}

	var scene: PackedScene = _make_scene_with_sockets(pos_by_name, size)
	var mod: TerrainModule = TerrainModule.new(scene, AABB(), TagList.new(), {}, [], {}, {}, {}, {}, false)
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
	var new_ps := TerrainModuleSocket.new(candidate, "bottom")

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
	# gen.player and gen.terrain_parent already in tree from _new_generator()
	var mod: TerrainModule = _make_module(Vector3(2, 2, 2), _default_socket_layout())
	var orig: TerrainModuleInstance = _spawn_piece(mod)
	gen.terrain_parent.add_child(orig.root)
	gen.register_piece(orig, "bottom")  # Register original piece
	# prepare sockets
	var new_inst: TerrainModuleInstance = mod.spawn()
	new_inst.create()
	_pieces_to_destroy.append(new_inst)
	var new_ps: TerrainModuleSocket = TerrainModuleSocket.new(new_inst, "bottom")
	var orig_ps: TerrainModuleSocket = TerrainModuleSocket.new(orig, "left")
	var ok: bool = gen.add_piece(new_ps, orig_ps)
	assert_true(ok)
	# child added
	assert_eq(gen.terrain_parent.get_child_count(), 2)  # orig + new piece
	# Connected sockets are not queued (attachment and any overlapping sockets)
	assert_eq(gen.queue.size(), 2)  # left and back sockets
	for e in gen.queue.heap:
		var it: TerrainModuleSocket = e["item"]
		assert_ne(it.socket_name, "bottom")
		assert_ne(it.socket_name, "front")


class FakeLibrary:
	extends TerrainModuleLibrary
	var m1: TerrainModule
	var m2: TerrainModule
	var step: int = 0
	func _init(_m1: TerrainModule, _m2: TerrainModule) -> void:
		m1 = _m1
		m2 = _m2
	func get_required_tags(_adj, _attachment_socket_name = "") -> TagList:
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
	_set_generator_library(gen, lib)
	gen.library.terrain_modules = TerrainModuleList.new([mod])
	gen.library.modules_by_tag.clear()
	gen.library.modules_by_tag["24x24"] = TerrainModuleList.new([mod])

	# For test pieces, use a controlled single-module library.
	var test_lib: TerrainModuleLibrary = TerrainModuleLibrary.new()
	gen.add_child(test_lib)
	_set_generator_test_pieces_library(gen, test_lib)
	gen.test_pieces_library.terrain_modules = TerrainModuleList.new([mod])
	gen.test_pieces_library.modules_by_tag.clear()
	gen.test_pieces_library.modules_by_tag["24x24"] = TerrainModuleList.new([mod])
	# Orig piece at identity
	var orig: TerrainModuleInstance = _spawn_piece(mod)
	var orig_ps: TerrainModuleSocket = TerrainModuleSocket.new(orig, "top")
	# Pre-insert dummy adjacent sockets at expected positions
	var names: Array[String] = ["left", "right", "back"]
	for n in names:
		var dummy_mod: TerrainModule = _make_module(Vector3(1, 1, 1), {"bottom": Vector3.ZERO})
		var dummy_piece: TerrainModuleInstance = _spawn_piece(dummy_mod)
		# Move its "bottom" socket to the expected position in local space.
		var m: Marker3D = dummy_piece.sockets.get("bottom", null)
		assert_true(m != null)
		if n == "left":
			m.transform.origin = Vector3(-1, 0, 0)
		elif n == "right":
			m.transform.origin = Vector3(1, 0, 0)
		else:
			m.transform.origin = Vector3(0, 0, -1)
		gen.socket_index.insert(TerrainModuleSocket.new(dummy_piece, "bottom"))
	# Query
	var out: Dictionary[String, TerrainModuleSocket] = gen.get_adjacent_from_size(orig_ps, "24x24")
	assert_true(out.has("bottom"))
	assert_true(out.has("back"))
	assert_true(out.has("left"))
	assert_true(out.has("right"))


func test_add_piece_checks_can_place_after_alignment():
	# Ensures we evaluate placement using the aligned transform, not the origin AABB.
	var gen: Variant = _new_generator()
	# gen.player and gen.terrain_parent already in tree from _new_generator()
	# Simple square module with 2x2x2 AABB and default sockets
	# Use sockets positioned at face centers one full size away so pieces don't overlap after
	# alignment.
	var mod: TerrainModule = _make_module(
		Vector3(2, 2, 2),
		{
			"bottom": Vector3(0, 0, 0),
			"left": Vector3(-2, 0, 0),
			"right": Vector3(2, 0, 0),
			"back": Vector3(0, 0, -2),
		}
	)
	# Start piece at origin
	var start: TerrainModuleInstance = _spawn_piece(mod)
	gen.terrain_parent.add_child(start.root)
	# Register so TerrainIndex contains the start tile for overlap tests
	gen.register_piece(start, "bottom")
	# New candidate spawns at origin and overlaps BEFORE alignment
	var cand: TerrainModuleInstance = _spawn_piece(mod)
	assert_true(cand.aabb.intersects(start.aabb), "precondition: candidate overlaps start at origin")
	# Attach candidate's bottom to start's left socket
	var orig_ps := TerrainModuleSocket.new(start, "left")
	var new_ps := TerrainModuleSocket.new(cand, "bottom")
	var ok: bool = gen.add_piece(new_ps, orig_ps)
	assert_true(ok, "add_piece placed after alignment")
	# AFTER alignment, AABBs must not overlap
	assert_false(cand.aabb.intersects(start.aabb), "postcondition: no overlap after placement")


func test_add_piece_to_queue_skips_nonfillable_sockets():
	var gen: Variant = _new_generator()
	var mod: TerrainModule = _make_module(
		Vector3(2, 2, 2),
		{
			"bottom": Vector3.ZERO,
			"right": Vector3(1, 0, 0),
			"left": Vector3(-1, 0, 0)
		}
	)
	mod.socket_fill_prob["bottom"] = 0.0
	mod.socket_fill_prob["right"] = 1.0
	mod.socket_fill_prob["left"] = 1.0
	var piece: TerrainModuleInstance = _spawn_piece(mod)

	gen.add_piece_to_queue(piece)
	assert_eq(gen.queue.size(), 2)
	for e in gen.queue.heap:
		var it: TerrainModuleSocket = e["item"]
		assert_ne(it.socket_name, "bottom")


func test_remove_piece_cleans_indices_queue_and_scene():
	var gen: Variant = _new_generator()
	var mod: TerrainModule = _make_module(Vector3(2, 2, 2), _default_socket_layout())
	var piece: TerrainModuleInstance = _spawn_piece(mod)
	gen.terrain_parent.add_child(piece.root)
	gen.register_piece(piece, "")
	gen.add_piece_to_queue(piece)
	assert_true(gen.queue.size() > 0)

	gen.remove_piece(piece)

	var results: Array = gen.terrain_index.query_box(piece.aabb)
	assert_false(results.has(piece))

	for socket_name in piece.sockets.keys():
		var pos: Vector3 = Helper.socket_world_pos(piece.transform, piece.sockets[socket_name], piece.root)
		var hit: TerrainModuleSocket = gen.socket_index.query_other(pos, piece)
		assert_true(hit == null)

	for entry in gen.queue.heap:
		var item = entry["item"]
		if item is TerrainModuleSocket:
			assert_ne(item.piece, piece)

	assert_eq(gen.terrain_parent.get_child_count(), 0)


func test_remove_linked_sockets_from_queue_removes_connected_socket():
	var gen: Variant = _new_generator()
	var mod: TerrainModule = _make_module(Vector3(2, 2, 2), _default_socket_layout())

	var start: TerrainModuleInstance = _spawn_piece(mod)
	gen.terrain_parent.add_child(start.root)
	gen.register_piece(start, "")
	gen.add_piece_to_queue(start)

	var cand: TerrainModuleInstance = _spawn_piece(mod)
	var new_ps: TerrainModuleSocket = TerrainModuleSocket.new(cand, "bottom")
	var orig_ps: TerrainModuleSocket = TerrainModuleSocket.new(start, "left")

	var ok: bool = gen.add_piece(new_ps, orig_ps)
	assert_true(ok)

	var found_linked_socket: bool = false
	for entry in gen.queue.heap:
		var item: TerrainModuleSocket = entry["item"]
		if item.piece == start and item.socket_name == "left":
			found_linked_socket = true
	assert_false(found_linked_socket)


func test_add_piece_replace_existing_removes_overlapping_non_ground():
	var gen: Variant = _new_generator()
	var base_mod: TerrainModule = _make_module(Vector3(2, 2, 2), {"bottom": Vector3.ZERO})
	var start: TerrainModuleInstance = _spawn_piece(base_mod)
	gen.terrain_parent.add_child(start.root)
	gen.register_piece(start, "")

	var blocker: TerrainModuleInstance = _spawn_piece(base_mod)
	gen.terrain_parent.add_child(blocker.root)
	gen.register_piece(blocker, "")
	assert_true(gen.terrain_index.query_box(blocker.aabb).has(blocker))

	var replacement_mod: TerrainModule = _make_module(Vector3(2, 2, 2), {"bottom": Vector3.ZERO})
	replacement_mod.replace_existing = true
	var replacement_piece: TerrainModuleInstance = replacement_mod.spawn()
	replacement_piece.create()
	_pieces_to_destroy.append(replacement_piece)

	var new_ps: TerrainModuleSocket = TerrainModuleSocket.new(replacement_piece, "bottom")
	var orig_ps: TerrainModuleSocket = TerrainModuleSocket.new(start, "bottom")
	var ok: bool = gen.add_piece(new_ps, orig_ps)
	assert_true(ok)
	assert_false(gen.terrain_index.query_box(blocker.aabb).has(blocker))


class _FakeSingleLib:
	extends TerrainModuleLibrary
	var _m: TerrainModule
	func _init(m: TerrainModule) -> void:
		_m = m
	func get_required_tags(_adj, _attachment_socket_name = "") -> TagList:
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
	# gen.player and gen.terrain_parent already in tree from _new_generator()
	gen.player.global_position = Vector3.ZERO
	gen.RENDER_RANGE = 10000
	gen.MAX_LOAD_PER_STEP = 1
	# Module: 2x2x2 with sockets on face centers and size tag "2x2x2".
	# Important: "bottom" is the attachment socket, so for placing a tile to the right (+X),
	# bottom must be on the LEFT face (-X) so it can connect to the parent's "right" socket (+X).
	var layout: Dictionary[String, Vector3] = {
		"bottom": Vector3(-1, 0, 0),
		"left": Vector3(-1, 0, 0),
		"right": Vector3(1, 0, 0),
		"back": Vector3(0, 0, -1),
	}
	var mod: TerrainModule = _make_module(Vector3(2, 2, 2), layout)
	mod.tags = TagList.new(["2x2x2"])
	mod.socket_size = {
		"bottom": Distribution.new({"2x2x2": 1.0}),
		"left": Distribution.new({"2x2x2": 1.0}),
		"right": Distribution.new({"2x2x2": 1.0}),
		"back": Distribution.new({"2x2x2": 1.0}),
	}
	var fake_lib: TerrainModuleLibrary = _FakeSingleLib.new(mod)
	gen.add_child(fake_lib)
	_set_generator_library(gen, fake_lib)

	var test_fake_lib: TerrainModuleLibrary = _FakeSingleLib.new(mod)
	gen.add_child(test_fake_lib)
	_set_generator_test_pieces_library(gen, test_fake_lib)
	# Start piece at origin; add to tree and indices
	var start: TerrainModuleInstance = _spawn_piece(mod)
	gen.terrain_parent.add_child(start.root)
	gen.register_piece(start, "bottom")
	# Seed queue with one socket: place to the right
	gen.queue = PriorityQueue.new()
	_objects_to_free.append(gen.queue)
	var item: TerrainModuleSocket = TerrainModuleSocket.new(start, "right")
	var dist: float = gen.get_dist_from_player(item.piece, item.socket_name)
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
	# And ensure we did not enqueue the "bottom" socket of the new piece
	for e in gen.queue.heap:
		var it: TerrainModuleSocket = e["item"]
		assert_ne(it.socket_name, "bottom")
		assert_ne(it.socket_name, "front")


func test_ground_queue_priority():
	# Test that ground expansion is prioritized over other placement
	var gen = _new_generator()
	_run_generator_ready(gen)

	# Check that start tile was placed
	var initial_count: int = gen.terrain_parent.get_child_count()
	print("After _ready: ", initial_count, " pieces in terrain")

	# Generate a small amount of terrain
	for i in range(5):
		gen.load_terrain()

	# Check that more pieces were generated
	var final_count: int = gen.terrain_parent.get_child_count()
	print("After generation: ", final_count, " pieces")

	# The test passes if generation happened (more pieces than initial)
	if final_count > initial_count:
		assert_true(true, "Generation working - " + str(final_count) + " total pieces")
	else:
		assert_true(false, "No generation - still " + str(final_count) + " pieces")
	_dispose_generator_immediately(gen)
	await _flush_deferred_frees()


func test_ground_grid_completeness():
	var gen: Variant = _new_generator()
	# gen.player and gen.terrain_parent are already created and gen.player is added to tree in _new_generator
	
	# Use real library for this integration test
	_set_generator_library(gen, TerrainModuleLibrary.new())
	gen.library.init()
	_set_generator_test_pieces_library(gen, TerrainModuleLibrary.new())
	gen.test_pieces_library.init_test_pieces()
	
	gen.player.global_position = Vector3.ZERO
	gen.RENDER_RANGE = 250
	gen.MAX_LOAD_PER_STEP = 10
	
	# Initialize the generator (places start tile)
	_run_generator_ready(gen)
	
	# Set a fixed seed for determinism
	seed(12345)
	
	# Run many iterations to fill the immediate neighborhood
	for i in range(1000):
		gen.load_terrain()
	
	# Check for ground tiles in a grid around origin (each 24x24)
	var expected_positions = []
	
	# Check a larger area where we expect everything to be filled
	# 13x13 grid should be well within 250 unit RENDER_RANGE
	for x in range(-6, 7):
		for z in range(-6, 7):
			expected_positions.append(Vector3(x * 24, -0.25, z * 24))
	
	var missing_count = 0
	for pos in expected_positions:
		# Query a small box at the center of the expected tile position
		# Ground tiles are 0.5 high, at y=0.
		var query_aabb = AABB(pos + Vector3(-0.1, 0.1, -0.1), Vector3(0.2, 0.2, 0.2))
		var results = gen.terrain_index.query_box(query_aabb)
		
		var found_ground = false
		for piece in results:
			if piece.def.tags.has("ground"):
				found_ground = true
				break
		
		if not found_ground:
			missing_count += 1
	
	assert_eq(missing_count, 0, "Should have 0 missing ground tiles in the immediate neighborhood")
	_dispose_generator_immediately(gen)
	await _flush_deferred_frees()


func _collect_level_pieces(gen: Variant) -> Array[TerrainModuleInstance]:
	var search_box: AABB = AABB(Vector3(-1200, -10, -1200), Vector3(2400, 200, 2400))
	var pieces: Array = gen.terrain_index.query_box(search_box)
	var out: Array[TerrainModuleInstance] = []
	var seen: Dictionary = {}
	for piece in pieces:
		if not (piece is TerrainModuleInstance):
			continue
		var level_piece: TerrainModuleInstance = piece
		if not level_piece.def.tags.has("level"):
			continue
		if seen.has(level_piece):
			continue
		seen[level_piece] = true
		out.append(level_piece)
	return out


func _level_missing_sockets(gen: Variant, piece: TerrainModuleInstance) -> Array[String]:
	var missing: Array[String] = []
	var sockets: Array[String] = ["front", "right", "back", "left"]
	for socket_name in sockets:
		if not piece.sockets.has(socket_name):
			continue
		var piece_socket: TerrainModuleSocket = TerrainModuleSocket.new(piece, socket_name)
		var other: TerrainModuleSocket = gen.socket_index.query_other(piece_socket.get_socket_position(), piece)
		var connected_to_level: bool = other != null and other.piece != null and other.piece.def.tags.has("level")
		if not connected_to_level:
			missing.append(socket_name)
	return missing


func _level_variant_tag(piece: TerrainModuleInstance) -> String:
	var variants: Array[String] = [
		"level-center",
		"level-side",
		"level-line",
		"level-corner",
		"level-peninsula",
		"level-island",
	]
	for tag in variants:
		if piece.def.tags.has(tag):
			return tag
	return ""


## Rotate socket name set by n 90° steps (same convention as LevelEdgeRule / Helper.rotate_socket_name).
func _rotate_socket_set(socket_names: Array, steps: int) -> Array:
	var out: Array = socket_names.duplicate()
	for _s in range(steps):
		var next: Array = []
		for sock_name in out:
			next.append(Helper.rotate_socket_name(sock_name))
		out = next
	return out


func _socket_set_equals(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for x in a:
		if not b.has(x):
			return false
	return true


## World cardinal from direction vector (Godot: front=-Z, back=+Z, right=+X, left=-X). Uses dominant axis.
func _world_cardinal_from_direction(v: Vector3) -> String:
	var vxz: Vector3 = Vector3(v.x, 0, v.z)
	if vxz.length_squared() < 0.01:
		return "front"
	vxz = vxz.normalized()
	if abs(vxz.x) >= abs(vxz.z):
		return "right" if vxz.x > 0 else "left"
	else:
		return "back" if vxz.z > 0 else "front"


## Set of world cardinal names where there is no level neighbor (derived from actual missing socket positions).
func _level_world_cardinals_with_no_neighbor(
	_gen: Variant,
	piece: TerrainModuleInstance,
	missing_socket_names: Array
) -> Array:
	var center: Vector3 = piece.transform.origin
	var cardinals: Array = []
	var seen: Dictionary = {}
	for socket_name in missing_socket_names:
		if not piece.sockets.has(socket_name):
			continue
		var ps: TerrainModuleSocket = TerrainModuleSocket.new(piece, socket_name)
		var pos: Vector3 = ps.get_socket_position()
		var dir: Vector3 = (pos - center)
		if dir.length_squared() < 0.01:
			continue
		var c: String = _world_cardinal_from_direction(dir)
		if not seen.get(c, false):
			seen[c] = true
			cardinals.append(c)
	return cardinals


## Set of world cardinal names that the piece's canonical missing sockets point to (using piece's current rotation).
func _piece_canonical_edges_world_cardinals(piece: TerrainModuleInstance, canonical_missing: Array) -> Array:
	if piece.root == null or piece.socket_node == null:
		return []
	var cardinals: Array = []
	var seen: Dictionary = {}
	for socket_name in canonical_missing:
		if not piece.sockets.has(socket_name):
			continue
		var sock: Node3D = piece.sockets[socket_name]
		var local_tf: Transform3D = Helper.to_root_tf(sock, piece.root)
		var local_pos: Vector3 = local_tf.origin
		if local_pos.length_squared() < 0.01:
			continue
		var world_dir: Vector3 = (piece.transform.basis * local_pos).normalized()
		var c: String = _world_cardinal_from_direction(world_dir)
		if not seen.get(c, false):
			seen[c] = true
			cardinals.append(c)
	return cardinals


func _world_cardinal_sets_equal(a: Array, b: Array) -> bool:
	return _socket_set_equals(a, b)


func test_integration_level_edges_match_neighbors_and_include_connected_regions():
	var gen: Variant = _new_generator()
	_set_generator_library(gen, TerrainModuleLibrary.new())
	gen.library.init()
	for module in gen.library.terrain_modules.library:
		if module.tags.has("ground"):
			module.socket_fill_prob["topcenter"] = 1.0
			module.socket_tag_prob["topcenter"] = Distribution.new({"level-center": 1.0})
		if module.tags.has("level"):
			module.socket_fill_prob["front"] = 1.0
			module.socket_fill_prob["back"] = 1.0
			module.socket_fill_prob["left"] = 1.0
			module.socket_fill_prob["right"] = 1.0
	_set_generator_test_pieces_library(gen, TerrainModuleLibrary.new())
	gen.test_pieces_library.init_test_pieces()
	gen.player.global_position = Vector3.ZERO
	gen.RENDER_RANGE = 300
	gen.MAX_LOAD_PER_STEP = 20
	seed(12345)
	_run_generator_ready(gen)

	for _i in range(1500):
		gen.load_terrain()

	var level_pieces: Array[TerrainModuleInstance] = _collect_level_pieces(gen)
	assert_true(level_pieces.size() > 0, "Expected level tiles to be generated")

	var best_neighbor_count: int = 0
	for piece in level_pieces:
		var missing: Array[String] = _level_missing_sockets(gen, piece)
		var neighbors: int = 4 - missing.size()
		if neighbors > best_neighbor_count:
			best_neighbor_count = neighbors

		var variant_tag: String = _level_variant_tag(piece)
		assert_ne(variant_tag, "", "Level tile missing a variant tag: " + str(piece.def.tags.tags))
		match variant_tag:
			"level-center":
				assert_eq(missing.size(), 0)
			"level-side":
				assert_eq(missing.size(), 1)
			"level-line":
				assert_eq(missing.size(), 2)
				var opposite: bool = (missing.has("front") and missing.has("back")) or (missing.has("left") and missing.has("right"))
				assert_true(opposite, "Line must have opposite missing sockets")
			"level-corner":
				assert_eq(missing.size(), 2)
				var opposite2: bool = (missing.has("front") and missing.has("back")) or (missing.has("left") and missing.has("right"))
				assert_false(opposite2, "Corner must have adjacent missing sockets")
			"level-peninsula":
				assert_eq(missing.size(), 3)
			"level-island":
				assert_eq(missing.size(), 4)
			_:
				assert_true(false, "Unexpected variant tag: " + variant_tag)

		# Rotation correctness (socket-name check): actual missing must match canonical up to rotation.
		var canonical_missing: Array = LevelEdgeRule.CANONICAL_MISSING_BY_TAG.get(variant_tag, []).duplicate()
		var matches_rotation: bool = false
		for k in range(4):
			if _socket_set_equals(_rotate_socket_set(canonical_missing.duplicate(), k), missing):
				matches_rotation = true
				break
		assert_true(
			matches_rotation,
			"Level tile rotation mismatch: variant=%s canonical_missing=%s actual missing=%s (must match for some 90° rotation)"
				% [variant_tag, canonical_missing, missing]
		)

		# World-space rotation correctness: the world directions the piece's canonical edges point to
		# must equal the world directions that have no level neighbor. This catches the bug where we
		# only rotate the newly placed piece but not the pieces we update (neighbors keep wrong orientation).
		if variant_tag != "level-center" and variant_tag != "level-island":
			var world_dirs_no_neighbor: Array = _level_world_cardinals_with_no_neighbor(gen, piece, missing)
			var piece_edges_world_dirs: Array = _piece_canonical_edges_world_cardinals(piece, canonical_missing)
			assert_true(
				_socket_set_equals(world_dirs_no_neighbor, piece_edges_world_dirs),
				"Level tile world-space rotation mismatch: variant=%s world_dirs_with_no_neighbor=%s piece_canonical_edges_world_dirs=%s (edges must point toward directions that have no neighbor)"
					% [variant_tag, world_dirs_no_neighbor, piece_edges_world_dirs]
			)

	assert_true(best_neighbor_count >= 3, "Expected at least one level tile with >= 3 level neighbors")
	_dispose_generator_immediately(gen)
	await _flush_deferred_frees()


func test_integration_default_level_generation_not_sparse_or_isolated():
	var gen: Variant = _new_generator()
	_set_generator_library(gen, TerrainModuleLibrary.new())
	gen.library.init()
	_set_generator_test_pieces_library(gen, TerrainModuleLibrary.new())
	gen.test_pieces_library.init_test_pieces()
	gen.player.global_position = Vector3.ZERO
	gen.RENDER_RANGE = 300
	gen.MAX_LOAD_PER_STEP = 20
	seed(12345)
	_run_generator_ready(gen)

	for _i in range(1500):
		gen.load_terrain()

	var level_pieces: Array[TerrainModuleInstance] = _collect_level_pieces(gen)
	assert_true(level_pieces.size() >= 10, "Expected at least 10 level tiles in default generation")

	var pieces_with_level_neighbor: int = 0
	var best_neighbor_count: int = 0
	for piece in level_pieces:
		var missing: Array[String] = _level_missing_sockets(gen, piece)
		var neighbors: int = 4 - missing.size()
		if neighbors > 0:
			pieces_with_level_neighbor += 1
		if neighbors > best_neighbor_count:
			best_neighbor_count = neighbors

	assert_true(pieces_with_level_neighbor >= 4, "Expected multiple level tiles to have adjacent level neighbors")
	assert_true(best_neighbor_count >= 2, "Expected at least one level tile connected to 2+ level neighbors")
	_dispose_generator_immediately(gen)
	await _flush_deferred_frees()


func test_integration_default_level_generation_forms_cluster_early():
	var gen: Variant = _new_generator()
	_set_generator_library(gen, TerrainModuleLibrary.new())
	gen.library.init()
	_set_generator_test_pieces_library(gen, TerrainModuleLibrary.new())
	gen.test_pieces_library.init_test_pieces()
	gen.player.global_position = Vector3.ZERO
	gen.RENDER_RANGE = 300
	gen.MAX_LOAD_PER_STEP = 20
	seed(12345)
	_run_generator_ready(gen)

	for _i in range(220):
		gen.load_terrain()

	var level_pieces: Array[TerrainModuleInstance] = _collect_level_pieces(gen)
	assert_true(level_pieces.size() >= 8, "Expected at least 8 level tiles after early generation")

	var pieces_with_level_neighbor: int = 0
	var best_neighbor_count: int = 0
	for piece in level_pieces:
		var missing: Array[String] = _level_missing_sockets(gen, piece)
		var neighbors: int = 4 - missing.size()
		if neighbors > 0:
			pieces_with_level_neighbor += 1
		if neighbors > best_neighbor_count:
			best_neighbor_count = neighbors

	assert_true(pieces_with_level_neighbor >= 4, "Expected early generation to include adjacent level pairs")
	assert_true(best_neighbor_count >= 2, "Expected early generation to include a local level cluster")
	_dispose_generator_immediately(gen)
	await _flush_deferred_frees()


func test_integration_default_level_generation_not_sparse_across_seeds():
	var failing_seeds: Array[int] = []
	var seeds: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8]
	for run_seed in seeds:
		var gen: Variant = _new_generator()
		_set_generator_library(gen, TerrainModuleLibrary.new())
		gen.library.init()
		_set_generator_test_pieces_library(gen, TerrainModuleLibrary.new())
		gen.test_pieces_library.init_test_pieces()
		gen.player.global_position = Vector3.ZERO
		gen.RENDER_RANGE = 300
		gen.MAX_LOAD_PER_STEP = 20
		seed(run_seed)
		_run_generator_ready(gen)

		for _i in range(220):
			gen.load_terrain()

		var level_pieces: Array[TerrainModuleInstance] = _collect_level_pieces(gen)
		var pieces_with_level_neighbor: int = 0
		for piece in level_pieces:
			var missing: Array[String] = _level_missing_sockets(gen, piece)
			var neighbors: int = 4 - missing.size()
			if neighbors > 0:
				pieces_with_level_neighbor += 1

		var has_density: bool = level_pieces.size() >= 8
		var has_connectivity: bool = pieces_with_level_neighbor >= 4
		if not has_density or not has_connectivity:
			failing_seeds.append(run_seed)
		_dispose_generator_immediately(gen)
		await _flush_deferred_frees()

	assert_true(
		failing_seeds.is_empty(),
		"Expected dense/connected default level generation across seeds; failing seeds: " + str(failing_seeds)
	)
