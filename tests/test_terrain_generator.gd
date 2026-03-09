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
	# Reset static module cache to release loaded level resources between tests.
	LevelEdgeRule.module_by_level_tag.clear()

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
	# Ensure sockets are considered fillable in tests.
	var fill: Dictionary[String, float] = {}
	for n: String in pos_by_name.keys():
		fill[n] = 1.0
	var mod: TerrainModule = TerrainModule.new(
		scene,
		AABB(),
		TagList.new(),
		{},
		[],
		{},
		{},
		fill,
		{},
		false
	)
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


class _DebugTerrainGenerator:
	extends "res://scripts/terrain/TerrainGenerator.gd"

	var debug_socket_stats: Dictionary = {}

	func _init() -> void:
		debug_socket_stats = {
			"placed_total": 0,
			"deferred_out_of_range_total": 0,
		}

	func _add_debug_stat(key: String, amount: int = 1) -> void:
		var current: int = int(debug_socket_stats.get(key, 0))
		debug_socket_stats[key] = current + amount

	func _process_socket(piece_socket: TerrainModuleSocket, distance: float) -> bool:
		if piece_socket.piece.root == null or piece_socket.piece.sockets.is_empty():
			return false
		if _is_socket_connected(piece_socket):
			return false
		if _defer_if_out_of_range(piece_socket, distance):
			_add_debug_stat("deferred_out_of_range_total")
			return false
		if not _passes_fill_prob_roll(piece_socket):
			return false

		var size: String = _sample_socket_size(piece_socket.piece, piece_socket.socket_name)
		var placement_context: Dictionary = _resolve_placement_context(piece_socket, size)
		var placed: bool = _try_place_with_rules(piece_socket, placement_context)
		if placed:
			_add_debug_stat("placed_total")
		return placed


func _new_debug_generator() -> Variant:
	var g: Variant = _DebugTerrainGenerator.new()
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


func _queue_health_snapshot(gen: Variant) -> Dictionary:
	var duplicate_counts: Dictionary = {}
	for entry in gen.queue.heap:
		if not (entry is Dictionary):
			continue
		var item: Variant = entry.get("item", null)
		if not (item is TerrainModuleSocket):
			continue
		var socket: TerrainModuleSocket = item
		var key: String = str(socket.piece.get_instance_id()) + ":" + socket.socket_name
		var count: int = int(duplicate_counts.get(key, 0))
		duplicate_counts[key] = count + 1
	var duplicate_entry_count: int = 0
	var duplicate_key_count: int = 0
	for count in duplicate_counts.values():
		if count <= 1:
			continue
		duplicate_key_count += 1
		duplicate_entry_count += int(count) - 1
	return {
		"queue_size": gen.queue.size(),
		"duplicate_key_count": duplicate_key_count,
		"duplicate_entry_count": duplicate_entry_count
	}


func _has_ground_near_position(gen: Variant, position: Vector3, radius: float = 20.0) -> bool:
	var half_size: Vector3 = Vector3(radius, 4.0, radius)
	var box: AABB = AABB(position - half_size, half_size * 2.0)
	var pieces: Array = gen.terrain_index.query_box(box)
	for hit in pieces:
		if not (hit is TerrainModuleInstance):
			continue
		var piece: TerrainModuleInstance = hit
		if piece.def != null and piece.def.tags.has("ground"):
			return true
	return false


func _max_ground_x_within(gen: Variant, center: Vector3, half_extent: float) -> float:
	var box: AABB = AABB(
		Vector3(center.x - half_extent, -20.0, center.z - half_extent),
		Vector3(half_extent * 2.0, 60.0, half_extent * 2.0)
	)
	var pieces: Array = gen.terrain_index.query_box(box)
	var max_x: float = -INF
	for hit in pieces:
		if not (hit is TerrainModuleInstance):
			continue
		var piece: TerrainModuleInstance = hit
		if piece.def == null or not piece.def.tags.has("ground"):
			continue
		max_x = max(max_x, piece.transform.origin.x)
	return max_x


func _audit_level_module_missing_fill_prob(gen: Variant) -> Dictionary:
	var out: Dictionary = {}
	if gen.library == null or gen.library.terrain_modules == null:
		return out
	for module in gen.library.terrain_modules.library:
		if module == null or not module.tags.has("level"):
			continue
		var piece: TerrainModuleInstance = module.spawn()
		piece.create()
		var missing: Array[String] = []
		for socket_name in piece.sockets.keys():
			if not module.socket_fill_prob.has(socket_name):
				missing.append(socket_name)
		piece.destroy()
		if not missing.is_empty():
			out[str(module.tags.tags)] = missing
	return out


func test_get_dist_from_player():
	var gen: Variant = _new_generator()
	gen.player.global_position = Vector3(1, 0, 0)
	var mock_def := TerrainModule.new(null, AABB(), TagList.new(), {}, [], {}, {}, {}, {}, false)
	var mock_piece = TerrainModuleInstance.new(mock_def)
	mock_piece.root = Node3D.new()
	_track_node_for_cleanup(mock_piece.root)
	var sock: Marker3D = Marker3D.new()
	sock.transform.origin = Vector3(0, -1, 0)
	mock_piece.root.add_child(sock)
	mock_piece.sockets = {"test_socket": sock}
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
	var fill: Dictionary[String, float] = {}
	for n: String in pos_by_name.keys():
		fill[n] = 1.0
	var mod: TerrainModule = TerrainModule.new(
		scene,
		AABB(),
		TagList.new(),
		{},
		[],
		{},
		{},
		fill,
		{},
		false
	)

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


func test_forbidden_adjacency_allows_null_fill_prob_hit():
	var gen: Variant = _new_generator()
	var blocker_mod: TerrainModule = _make_module(Vector3(2, 2, 2), {"diag": Vector3.ZERO})
	blocker_mod.socket_fill_prob = {"diag": null}
	var blocker_piece: TerrainModuleInstance = _spawn_piece(blocker_mod)
	var adjacent: Dictionary[String, TerrainModuleSocket] = {
		"frontleft": TerrainModuleSocket.new(blocker_piece, "diag")
	}
	assert_false(
		gen._has_forbidden_adjacency(adjacent),
		"null fill_prob sockets should be non-blocking adjacency-only sockets"
	)


func test_forbidden_adjacency_blocks_explicit_zero_fill_prob_hit():
	var gen: Variant = _new_generator()
	var blocker_mod: TerrainModule = _make_module(Vector3(2, 2, 2), {"diag": Vector3.ZERO})
	blocker_mod.socket_fill_prob["diag"] = 0.0
	var blocker_piece: TerrainModuleInstance = _spawn_piece(blocker_mod)
	var adjacent: Dictionary[String, TerrainModuleSocket] = {
		"frontleft": TerrainModuleSocket.new(blocker_piece, "diag")
	}
	assert_true(
		gen._has_forbidden_adjacency(adjacent),
		"explicit 0 fill_prob sockets remain blocking"
	)


func test_level_modules_have_explicit_fill_prob_entries_for_all_scene_sockets():
	var gen: Variant = _new_generator()
	_set_generator_library(gen, TerrainModuleLibrary.new())
	gen.library.init()
	var missing: Dictionary = _audit_level_module_missing_fill_prob(gen)
	assert_true(
		missing.is_empty(),
		"All level module sockets must be explicitly authored in socket_fill_prob: " + str(missing)
	)


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
	
	for i in range(1500):
		gen.load_terrain()

	var expected_positions = []
	for x in range(-5, 6):
		for z in range(-5, 6):
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
	var search_half_extent: float = 450.0
	if gen != null:
		var render_range_value: Variant = gen.get("RENDER_RANGE")
		if render_range_value is float or render_range_value is int:
			search_half_extent = float(render_range_value) + 120.0
	var search_box: AABB = AABB(
		Vector3(-search_half_extent, -10, -search_half_extent),
		Vector3(search_half_extent * 2.0, 200, search_half_extent * 2.0)
	)
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


func _run_generation_until_level_count(
	gen: Variant,
	max_steps: int,
	target_level_count: int,
	probe_every: int = 20
) -> void:
	for i in range(max_steps):
		gen.load_terrain()
		if target_level_count <= 0:
			continue
		var should_probe: bool = (i + 1) % probe_every == 0 or i == max_steps - 1
		if not should_probe:
			continue
		var level_count: int = _collect_level_pieces(gen).size()
		if level_count >= target_level_count:
			break


func _level_missing_sockets(gen: Variant, piece: TerrainModuleInstance) -> Array[String]:
	var rule: LevelEdgeRule = LevelEdgeRule.new()
	return rule._missing_sockets_for_piece(piece, gen.socket_index, gen.terrain_index)


func _level_variant_tag(piece: TerrainModuleInstance) -> String:
	var variants: Array[String] = [
		"level-center",
		"level-side",
		"level-line",
		"level-corner",
		"level-peninsula",
		"level-island",
		"level-inner-corner",
		"level-inner-corner-diag",
		"level-inner-corner-side",
		"level-inner-corner-edge1",
		"level-inner-corner-edge2",
		"level-inner-corner-edge-both",
		"level-inner-corner-side-edge",
		"level-inner-corner-three",
		"level-inner-corner-all",
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
	gen.player.global_position = Vector3.ZERO
	gen.RENDER_RANGE = 300
	gen.MAX_LOAD_PER_STEP = 20
	seed(12345)
	_run_generator_ready(gen)

	for module in gen.library.terrain_modules.library:
		if module.tags.has("ground"):
			module.socket_fill_prob["topcenter"] = 1.0
			module.socket_tag_prob["topcenter"] = Distribution.new({"level-center": 1.0})

	_run_generation_until_level_count(gen, 800, 24)

	var level_pieces: Array[TerrainModuleInstance] = _collect_level_pieces(gen)
	assert_true(level_pieces.size() > 0, "Expected level tiles to be generated")

	var best_neighbor_count: int = 0
	var mismatch_count: int = 0
	for piece in level_pieces:
		var missing: Array[String] = _level_missing_sockets(gen, piece)
		var neighbors: int = 4 - missing.size()
		if neighbors > best_neighbor_count:
			best_neighbor_count = neighbors

		var variant_tag: String = _level_variant_tag(piece)
		assert_ne(variant_tag, "", "Level tile missing a variant tag: " + str(piece.def.tags.tags))

		var canonical_missing: Array = LevelEdgeRule.CANONICAL_MISSING_BY_TAG.get(variant_tag, []).duplicate()
		var matches_rotation: bool = false
		for k in range(4):
			if _socket_set_equals(_rotate_socket_set(canonical_missing.duplicate(), k), missing):
				matches_rotation = true
				break
		if not matches_rotation:
			mismatch_count += 1

	var mismatch_rate: float = float(mismatch_count) / float(max(level_pieces.size(), 1))
	assert_true(
		mismatch_rate <= 0.1,
		"Too many variant mismatches: %d/%d (%.1f%%)" % [mismatch_count, level_pieces.size(), mismatch_rate * 100.0]
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

	_run_generation_until_level_count(gen, 500, 8)

	var level_pieces: Array[TerrainModuleInstance] = _collect_level_pieces(gen)
	assert_true(level_pieces.size() >= 6, "Expected at least 6 level tiles in default generation")

	var pieces_with_level_neighbor: int = 0
	var best_neighbor_count: int = 0
	for piece in level_pieces:
		var missing: Array[String] = _level_missing_sockets(gen, piece)
		var neighbors: int = 4 - missing.size()
		if neighbors > 0:
			pieces_with_level_neighbor += 1
		if neighbors > best_neighbor_count:
			best_neighbor_count = neighbors

	assert_true(pieces_with_level_neighbor >= 2, "Expected some level tiles to have adjacent level neighbors")
	assert_true(best_neighbor_count >= 1, "Expected at least one level tile connected to a level neighbor")
	_dispose_generator_immediately(gen)
	await _flush_deferred_frees()


func test_integration_default_level_generation_forms_cluster_early():
	var gen: Variant = _new_debug_generator()
	_set_generator_library(gen, TerrainModuleLibrary.new())
	gen.library.init()
	_set_generator_test_pieces_library(gen, TerrainModuleLibrary.new())
	gen.test_pieces_library.init_test_pieces()
	gen.player.global_position = Vector3.ZERO
	gen.RENDER_RANGE = 300
	gen.MAX_LOAD_PER_STEP = 20
	seed(12345)
	_run_generator_ready(gen)

	_run_generation_until_level_count(gen, 400, 6)

	var level_pieces: Array[TerrainModuleInstance] = _collect_level_pieces(gen)
	assert_true(level_pieces.size() >= 4, "Expected at least 4 level tiles after early generation")

	var pieces_with_level_neighbor: int = 0
	var best_neighbor_count: int = 0
	for piece in level_pieces:
		var missing: Array[String] = _level_missing_sockets(gen, piece)
		var neighbors: int = 4 - missing.size()
		if neighbors > 0:
			pieces_with_level_neighbor += 1
		if neighbors > best_neighbor_count:
			best_neighbor_count = neighbors

	assert_true(pieces_with_level_neighbor >= 1, "Expected early generation to include at least one adjacent pair")
	assert_true(best_neighbor_count >= 1, "Expected at least one level tile with a level neighbor")
	_dispose_generator_immediately(gen)
	await _flush_deferred_frees()


func test_integration_default_level_generation_not_sparse_across_seeds():
	var failing_seeds: Array[int] = []
	var seeds: Array[int] = [1, 2, 3, 4]
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

		_run_generation_until_level_count(gen, 400, 4)

		var level_pieces: Array[TerrainModuleInstance] = _collect_level_pieces(gen)
		var pieces_with_level_neighbor: int = 0
		for piece in level_pieces:
			var missing: Array[String] = _level_missing_sockets(gen, piece)
			var neighbors: int = 4 - missing.size()
			if neighbors > 0:
				pieces_with_level_neighbor += 1

		var has_density: bool = level_pieces.size() >= 4
		var has_connectivity: bool = pieces_with_level_neighbor >= 1
		if not has_density or not has_connectivity:
			failing_seeds.append(run_seed)
		_dispose_generator_immediately(gen)
		await _flush_deferred_frees()

	assert_true(
		failing_seeds.is_empty(),
		"Expected dense/connected default level generation across seeds; failing seeds: " + str(failing_seeds)
	)


func test_integration_moving_player_frontier_keeps_generating_ground():
	var gen: Variant = _new_debug_generator()
	_set_generator_library(gen, TerrainModuleLibrary.new())
	gen.library.init()
	_set_generator_test_pieces_library(gen, TerrainModuleLibrary.new())
	gen.test_pieces_library.init_test_pieces()
	gen.player.global_position = Vector3.ZERO
	gen.RENDER_RANGE = 260
	gen.MAX_LOAD_PER_STEP = 14
	seed(24681357)
	_run_generator_ready(gen)

	var queue_peak: int = 0
	var duplicate_entry_peak: int = 0
	var no_ground_near_player_checks: int = 0
	var prev_placed_total: int = 0
	var zero_placement_streak: int = 0
	var longest_zero_placement_streak: int = 0
	for step in range(280):
		if step > 0 and step % 4 == 0:
			gen.player.global_position += Vector3(12, 0, 0)
		gen.load_terrain()

		var queue_health: Dictionary = _queue_health_snapshot(gen)
		queue_peak = max(queue_peak, int(queue_health["queue_size"]))
		duplicate_entry_peak = max(duplicate_entry_peak, int(queue_health["duplicate_entry_count"]))

		var placed_total: int = int(gen.debug_socket_stats.get("placed_total", 0))
		if placed_total == prev_placed_total:
			zero_placement_streak += 1
		else:
			zero_placement_streak = 0
		longest_zero_placement_streak = max(longest_zero_placement_streak, zero_placement_streak)
		prev_placed_total = placed_total

		if step >= 40 and step % 8 == 0:
			if not _has_ground_near_position(gen, gen.player.global_position, 22.0):
				no_ground_near_player_checks += 1

	var max_ground_x: float = _max_ground_x_within(gen, gen.player.global_position, 420.0)
	print(
		"moving-frontier-debug",
		{
			"player_x": gen.player.global_position.x,
			"max_ground_x": max_ground_x,
			"queue_peak": queue_peak,
			"duplicate_entry_peak": duplicate_entry_peak,
			"no_ground_near_player_checks": no_ground_near_player_checks,
			"longest_zero_placement_streak": longest_zero_placement_streak,
			"deferred_total": int(gen.debug_socket_stats.get("deferred_out_of_range_total", 0)),
			"placed_total": int(gen.debug_socket_stats.get("placed_total", 0)),
		}
	)

	assert_eq(duplicate_entry_peak, 0, "Queue should not contain duplicate socket entries")
	assert_true(no_ground_near_player_checks <= 5, "Ground should stay available near moving player")
	assert_true(
		max_ground_x >= gen.player.global_position.x - 72.0,
		"Ground frontier should keep up with player progression"
	)
	assert_true(longest_zero_placement_streak <= 70, "Placement should not starve for long streaks")
	_dispose_generator_immediately(gen)
	await _flush_deferred_frees()


func test_integration_out_of_range_requeue_does_not_duplicate_and_recovers():
	var gen: Variant = _new_debug_generator()
	_set_generator_library(gen, TerrainModuleLibrary.new())
	gen.library.init()
	_set_generator_test_pieces_library(gen, TerrainModuleLibrary.new())
	gen.test_pieces_library.init_test_pieces()
	gen.player.global_position = Vector3.ZERO
	gen.RENDER_RANGE = 220
	gen.MAX_LOAD_PER_STEP = 10
	seed(445566)
	_run_generator_ready(gen)

	for _i in range(120):
		gen.load_terrain()

	gen.player.global_position = Vector3(3000, 0, 0)
	var queue_size_during_deferral_peak: int = 0
	var duplicate_entry_peak: int = 0
	var before_deferral_placed_total: int = int(gen.debug_socket_stats.get("placed_total", 0))
	for _i in range(140):
		gen.load_terrain()
		var queue_health: Dictionary = _queue_health_snapshot(gen)
		queue_size_during_deferral_peak = max(queue_size_during_deferral_peak, int(queue_health["queue_size"]))
		duplicate_entry_peak = max(duplicate_entry_peak, int(queue_health["duplicate_entry_count"]))

	var deferred_total_after_far: int = int(gen.debug_socket_stats.get("deferred_out_of_range_total", 0))
	gen.player.global_position = Vector3.ZERO
	for _i in range(140):
		gen.load_terrain()

	var after_recovery_placed_total: int = int(gen.debug_socket_stats.get("placed_total", 0))
	print(
		"requeue-recovery-debug",
		{
			"queue_size_during_deferral_peak": queue_size_during_deferral_peak,
			"duplicate_entry_peak": duplicate_entry_peak,
			"deferred_total_after_far": deferred_total_after_far,
			"placed_before_far": before_deferral_placed_total,
			"placed_after_recovery": after_recovery_placed_total,
		}
	)

	assert_eq(duplicate_entry_peak, 0, "Out-of-range deferral should not duplicate queued sockets")
	assert_true(deferred_total_after_far > 0, "Expected out-of-range deferrals while player is far away")
	assert_true(
		after_recovery_placed_total > before_deferral_placed_total,
		"Generation should recover and place more pieces after returning player near frontier"
	)
	_dispose_generator_immediately(gen)
	await _flush_deferred_frees()


func test_level_edge_rule_classifies_new_inner_corner_edge_variants() -> void:
	var rule: LevelEdgeRule = LevelEdgeRule.new()
	assert_eq(
		rule._tag_for_missing_sockets(["frontleft", "back"]),
		"level-inner-corner-edge1"
	)
	assert_eq(
		rule._tag_for_missing_sockets(["frontleft", "right"]),
		"level-inner-corner-edge2"
	)
	assert_eq(
		rule._tag_for_missing_sockets(["frontleft", "back", "right"]),
		"level-inner-corner-edge-both"
	)
	assert_eq(
		rule._tag_for_missing_sockets(["frontleft", "backleft", "right"]),
		"level-inner-corner-side-edge"
	)


func test_level_edge_rule_missing_sockets_uses_cardinal_and_diagonal_adjacency() -> void:
	var gen: Variant = _new_generator()
	var rule: LevelEdgeRule = LevelEdgeRule.new()
	var layout: Dictionary[String, Vector3] = {
		"front": Vector3(0, 0, -1),
		"right": Vector3(1, 0, 0),
		"back": Vector3(0, 0, 1),
		"left": Vector3(-1, 0, 0),
		"frontright": Vector3(1, 0, -1),
		"backright": Vector3(1, 0, 1),
		"backleft": Vector3(-1, 0, 1),
		"frontleft": Vector3(-1, 0, -1),
	}
	var level_mod: TerrainModule = _make_module(Vector3(2, 2, 2), layout)
	level_mod.tags = TagList.new(["level"])
	var center_piece: TerrainModuleInstance = _spawn_piece(level_mod)
	var neighbor_mod: TerrainModule = _make_module(Vector3(1, 1, 1), {"main": Vector3.ZERO})
	neighbor_mod.tags = TagList.new(["level"])
	var front_neighbor: TerrainModuleInstance = _spawn_piece(
		neighbor_mod,
		Transform3D(Basis.IDENTITY, Vector3(0, 0, -1))
	)
	var left_neighbor: TerrainModuleInstance = _spawn_piece(
		neighbor_mod,
		Transform3D(Basis.IDENTITY, Vector3(-1, 0, 0))
	)
	gen.socket_index.insert(TerrainModuleSocket.new(front_neighbor, "main"))
	gen.socket_index.insert(TerrainModuleSocket.new(left_neighbor, "main"))
	var missing: Array[String] = rule._missing_sockets_for_piece(
		center_piece,
		gen.socket_index,
		gen.terrain_index
	)
	assert_true(missing.has("back"))
	assert_true(missing.has("right"))
	assert_true(missing.has("frontleft"))
	assert_false(missing.has("backleft"))
	assert_false(missing.has("frontright"))
	assert_false(missing.has("backright"))


func test_level_edge_rule_diagonal_neighbor_blocks_inner_corner() -> void:
	var gen: Variant = _new_generator()
	var rule: LevelEdgeRule = LevelEdgeRule.new()
	var layout: Dictionary[String, Vector3] = {
		"front": Vector3(0, 0, -1),
		"right": Vector3(1, 0, 0),
		"back": Vector3(0, 0, 1),
		"left": Vector3(-1, 0, 0),
	}
	var level_mod: TerrainModule = _make_module(Vector3(2, 2, 2), layout)
	level_mod.tags = TagList.new(["level"])
	var center_piece: TerrainModuleInstance = _spawn_piece(level_mod)
	var neighbor_mod: TerrainModule = _make_module(Vector3(1, 1, 1), {"main": Vector3.ZERO})
	neighbor_mod.tags = TagList.new(["level"])
	var front_neighbor: TerrainModuleInstance = _spawn_piece(
		neighbor_mod,
		Transform3D(Basis.IDENTITY, Vector3(0, 0, -1))
	)
	var left_neighbor: TerrainModuleInstance = _spawn_piece(
		neighbor_mod,
		Transform3D(Basis.IDENTITY, Vector3(-1, 0, 0))
	)
	var diagonal_neighbor: TerrainModuleInstance = _spawn_piece(
		neighbor_mod,
		Transform3D(Basis.IDENTITY, Vector3(-2, 0, -2))
	)
	gen.socket_index.insert(TerrainModuleSocket.new(front_neighbor, "main"))
	gen.socket_index.insert(TerrainModuleSocket.new(left_neighbor, "main"))
	gen.terrain_index.insert(diagonal_neighbor)
	var missing: Array[String] = rule._missing_sockets_for_piece(
		center_piece,
		gen.socket_index,
		gen.terrain_index
	)
	assert_false(
		missing.has("frontleft"),
		"Inner corner must not be marked missing when diagonal level tile exists"
	)


func test_level_edge_rule_missing_diagonal_adds_inner_corner() -> void:
	var gen: Variant = _new_generator()
	var rule: LevelEdgeRule = LevelEdgeRule.new()
	var layout: Dictionary[String, Vector3] = {
		"front": Vector3(0, 0, -1),
		"right": Vector3(1, 0, 0),
		"back": Vector3(0, 0, 1),
		"left": Vector3(-1, 0, 0),
	}
	var level_mod: TerrainModule = _make_module(Vector3(2, 2, 2), layout)
	level_mod.tags = TagList.new(["level"])
	var center_piece: TerrainModuleInstance = _spawn_piece(level_mod)
	var neighbor_mod: TerrainModule = _make_module(Vector3(1, 1, 1), {"main": Vector3.ZERO})
	neighbor_mod.tags = TagList.new(["level"])
	var front_neighbor: TerrainModuleInstance = _spawn_piece(
		neighbor_mod,
		Transform3D(Basis.IDENTITY, Vector3(0, 0, -1))
	)
	var left_neighbor: TerrainModuleInstance = _spawn_piece(
		neighbor_mod,
		Transform3D(Basis.IDENTITY, Vector3(-1, 0, 0))
	)
	gen.socket_index.insert(TerrainModuleSocket.new(front_neighbor, "main"))
	gen.socket_index.insert(TerrainModuleSocket.new(left_neighbor, "main"))
	var missing: Array[String] = rule._missing_sockets_for_piece(
		center_piece,
		gen.socket_index,
		gen.terrain_index
	)
	assert_true(
		missing.has("frontleft"),
		"Inner corner must be marked missing when diagonal level tile is absent"
	)


func _insert_all_piece_sockets(gen: Variant, piece: TerrainModuleInstance) -> void:
	for socket_name in piece.sockets.keys():
		gen.socket_index.insert(TerrainModuleSocket.new(piece, socket_name))


func test_level_edge_rule_top_diagonal_present_blocks_inner_corner() -> void:
	var gen: Variant = _new_generator()
	var rule: LevelEdgeRule = LevelEdgeRule.new()
	var center_mod: TerrainModule = _make_module(
		Vector3(2, 2, 2),
		{
			"front": Vector3(0, 0, -1),
			"left": Vector3(-1, 0, 0),
			"frontleft": Vector3(-1, 0, -1),
			"topfrontleft": Vector3(-1, 1, -1),
		}
	)
	center_mod.tags = TagList.new(["level"])
	var center_piece: TerrainModuleInstance = _spawn_piece(center_mod)
	var neighbor_mod: TerrainModule = _make_module(Vector3(1, 1, 1), {"main": Vector3.ZERO})
	neighbor_mod.tags = TagList.new(["level"])
	var front_neighbor: TerrainModuleInstance = _spawn_piece(neighbor_mod, Transform3D(Basis.IDENTITY, Vector3(0, 0, -1)))
	var left_neighbor: TerrainModuleInstance = _spawn_piece(neighbor_mod, Transform3D(Basis.IDENTITY, Vector3(-1, 0, 0)))
	gen.socket_index.insert(TerrainModuleSocket.new(front_neighbor, "main"))
	gen.socket_index.insert(TerrainModuleSocket.new(left_neighbor, "main"))
	var top_diagonal_mod: TerrainModule = _make_module(Vector3(1, 1, 1), {"main": Vector3(1, 1, 1)})
	top_diagonal_mod.tags = TagList.new(["level"])
	var top_diagonal_piece: TerrainModuleInstance = _spawn_piece(
		top_diagonal_mod,
		Transform3D(Basis.IDENTITY, Vector3(-2, 0, -2))
	)
	gen.socket_index.insert(TerrainModuleSocket.new(top_diagonal_piece, "main"))
	gen.terrain_index.insert(top_diagonal_piece)
	var missing: Array[String] = rule._missing_sockets_for_piece(center_piece, gen.socket_index, gen.terrain_index)
	assert_false(
		missing.has("frontleft"),
		"Top diagonal level tile should block frontleft inner-corner missing state"
	)


func test_level_edge_rule_top_diagonal_absent_requires_inner_corner() -> void:
	var gen: Variant = _new_generator()
	var rule: LevelEdgeRule = LevelEdgeRule.new()
	var center_mod: TerrainModule = _make_module(
		Vector3(2, 2, 2),
		{
			"front": Vector3(0, 0, -1),
			"left": Vector3(-1, 0, 0),
			"frontleft": Vector3(-1, 0, -1),
			"topfrontleft": Vector3(-1, 1, -1),
		}
	)
	center_mod.tags = TagList.new(["level"])
	var center_piece: TerrainModuleInstance = _spawn_piece(center_mod)
	var neighbor_mod: TerrainModule = _make_module(Vector3(1, 1, 1), {"main": Vector3.ZERO})
	neighbor_mod.tags = TagList.new(["level"])
	var front_neighbor: TerrainModuleInstance = _spawn_piece(neighbor_mod, Transform3D(Basis.IDENTITY, Vector3(0, 0, -1)))
	var left_neighbor: TerrainModuleInstance = _spawn_piece(neighbor_mod, Transform3D(Basis.IDENTITY, Vector3(-1, 0, 0)))
	gen.socket_index.insert(TerrainModuleSocket.new(front_neighbor, "main"))
	gen.socket_index.insert(TerrainModuleSocket.new(left_neighbor, "main"))
	var missing: Array[String] = rule._missing_sockets_for_piece(center_piece, gen.socket_index, gen.terrain_index)
	assert_true(
		missing.has("frontleft"),
		"Without top diagonal level tile, frontleft should be treated as missing inner corner"
	)


func test_level_edge_rule_diagonal_projection_ignores_side_touching_socket_noise() -> void:
	var gen: Variant = _new_generator()
	var rule: LevelEdgeRule = LevelEdgeRule.new()
	var center_mod: TerrainModule = _make_module(
		Vector3(2, 2, 2),
		{
			"front": Vector3(0, 0, -1),
			"left": Vector3(-1, 0, 0),
			"frontleft": Vector3(-1, 0, -1),
		}
	)
	center_mod.tags = TagList.new(["level"])
	var center_piece: TerrainModuleInstance = _spawn_piece(center_mod)
	var side_touching_mod: TerrainModule = _make_module(
		Vector3(1, 1, 1),
		{
			"corner": Vector3.ZERO,
			"front_touch": Vector3(1, 0, 0),
		}
	)
	side_touching_mod.tags = TagList.new(["level"])
	var side_touching_piece: TerrainModuleInstance = _spawn_piece(
		side_touching_mod,
		Transform3D(Basis.IDENTITY, Vector3(-3, 0, -2))
	)
	_insert_all_piece_sockets(gen, side_touching_piece)
	var true_diagonal_mod: TerrainModule = _make_module(Vector3(1, 1, 1), {"main": Vector3.ZERO})
	true_diagonal_mod.tags = TagList.new(["level"])
	var true_diagonal_piece: TerrainModuleInstance = _spawn_piece(
		true_diagonal_mod,
		Transform3D(Basis.IDENTITY, Vector3(-2, 0, -2))
	)
	gen.terrain_index.insert(side_touching_piece)
	gen.terrain_index.insert(true_diagonal_piece)
	var hit: TerrainModuleInstance = rule._get_diagonal_level_neighbor_piece(
		center_piece,
		"frontleft",
		gen.terrain_index
	)
	assert_true(hit != null, "Expected a true diagonal hit after ignoring side-touching sockets")
	assert_eq(hit, true_diagonal_piece)


func test_level_edge_rule_diagonal_projection_ignores_wrong_layer_hit() -> void:
	var gen: Variant = _new_generator()
	var rule: LevelEdgeRule = LevelEdgeRule.new()
	var center_mod: TerrainModule = _make_module(
		Vector3(2, 2, 2),
		{
			"front": Vector3(0, 0, -1),
			"left": Vector3(-1, 0, 0),
			"frontleft": Vector3(-1, 0, -1),
		}
	)
	center_mod.tags = TagList.new(["level"])
	var center_piece: TerrainModuleInstance = _spawn_piece(center_mod)
	var wrong_layer_mod: TerrainModule = _make_module(Vector3(1, 1, 1), {"main": Vector3.ZERO})
	wrong_layer_mod.tags = TagList.new(["ground"])
	var wrong_layer_piece: TerrainModuleInstance = _spawn_piece(
		wrong_layer_mod,
		Transform3D(Basis.IDENTITY, Vector3(-2, 0, -2))
	)
	gen.terrain_index.insert(wrong_layer_piece)
	var hit: TerrainModuleInstance = rule._get_diagonal_level_neighbor_piece(
		center_piece,
		"frontleft",
		gen.terrain_index
	)
	assert_eq(hit, null, "Diagonal adjacency should reject wrong-layer hits")


func test_level_edge_rule_top_diagonal_insertion_order_invariant() -> void:
	var orders: Array = [true, false]
	for front_first in orders:
		var gen: Variant = _new_generator()
		var rule: LevelEdgeRule = LevelEdgeRule.new()
		var center_mod: TerrainModule = _make_module(
			Vector3(2, 2, 2),
			{
				"front": Vector3(0, 0, -1),
				"left": Vector3(-1, 0, 0),
				"frontleft": Vector3(-1, 0, -1),
				"topfrontleft": Vector3(-1, 1, -1),
			}
		)
		center_mod.tags = TagList.new(["level"])
		var center_piece: TerrainModuleInstance = _spawn_piece(center_mod)
		var neighbor_mod: TerrainModule = _make_module(Vector3(1, 1, 1), {"main": Vector3.ZERO})
		neighbor_mod.tags = TagList.new(["level"])
		var front_neighbor: TerrainModuleInstance = _spawn_piece(neighbor_mod, Transform3D(Basis.IDENTITY, Vector3(0, 0, -1)))
		var left_neighbor: TerrainModuleInstance = _spawn_piece(neighbor_mod, Transform3D(Basis.IDENTITY, Vector3(-1, 0, 0)))
		var top_diagonal_mod: TerrainModule = _make_module(Vector3(1, 1, 1), {"main": Vector3(1, 1, 1)})
		top_diagonal_mod.tags = TagList.new(["level"])
		var top_diagonal_piece: TerrainModuleInstance = _spawn_piece(
			top_diagonal_mod,
			Transform3D(Basis.IDENTITY, Vector3(-2, 0, -2))
		)
		if front_first:
			gen.socket_index.insert(TerrainModuleSocket.new(front_neighbor, "main"))
			gen.socket_index.insert(TerrainModuleSocket.new(left_neighbor, "main"))
		else:
			gen.socket_index.insert(TerrainModuleSocket.new(left_neighbor, "main"))
			gen.socket_index.insert(TerrainModuleSocket.new(front_neighbor, "main"))
		gen.socket_index.insert(TerrainModuleSocket.new(top_diagonal_piece, "main"))
		gen.terrain_index.insert(top_diagonal_piece)
		var missing: Array[String] = rule._missing_sockets_for_piece(center_piece, gen.socket_index, gen.terrain_index)
		assert_false(missing.has("frontleft"))


func test_level_edge_rule_projection_matches_legacy_for_plain_and_top_diagonal() -> void:
	var rule: LevelEdgeRule = LevelEdgeRule.new()
	var use_top_variants: Array[bool] = [false, true]
	for use_top in use_top_variants:
		var gen: Variant = _new_generator()
		var center_mod: TerrainModule = _make_module(
			Vector3(2, 2, 2),
			{
				"front": Vector3(0, 0, -1),
				"left": Vector3(-1, 0, 0),
				"frontleft": Vector3(-1, 0, -1),
				"topfrontleft": Vector3(-1, 1, -1),
			}
		)
		center_mod.tags = TagList.new(["level"])
		var center_piece: TerrainModuleInstance = _spawn_piece(center_mod)
		var front_mod: TerrainModule = _make_module(Vector3(1, 1, 1), {"main": Vector3.ZERO})
		front_mod.tags = TagList.new(["level"])
		var front_neighbor: TerrainModuleInstance = _spawn_piece(front_mod, Transform3D(Basis.IDENTITY, Vector3(0, 0, -1)))
		var left_neighbor: TerrainModuleInstance = _spawn_piece(front_mod, Transform3D(Basis.IDENTITY, Vector3(-1, 0, 0)))
		gen.socket_index.insert(TerrainModuleSocket.new(front_neighbor, "main"))
		gen.socket_index.insert(TerrainModuleSocket.new(left_neighbor, "main"))
		var diagonal_offset: Vector3 = Vector3(1, 0, 1)
		if use_top:
			diagonal_offset = Vector3(1, 1, 1)
		var diagonal_mod: TerrainModule = _make_module(Vector3(1, 1, 1), {"main": diagonal_offset})
		diagonal_mod.tags = TagList.new(["level"])
		var diagonal_piece: TerrainModuleInstance = _spawn_piece(
			diagonal_mod,
			Transform3D(Basis.IDENTITY, Vector3(-2, 0, -2))
		)
		gen.terrain_index.insert(diagonal_piece)
		var by_current: TerrainModuleInstance = rule._get_diagonal_level_neighbor_piece(
			center_piece,
			"frontleft",
			gen.terrain_index
		)
		var by_legacy: TerrainModuleInstance = _legacy_diagonal_neighbor_from_terrain_for_test(
			center_piece,
			"frontleft",
			gen.terrain_index
		)
		assert_eq(
			by_current,
			by_legacy,
			"Current diagonal projection should match legacy behavior for use_top=%s" % [use_top]
		)
		_dispose_generator_immediately(gen)
		await _flush_deferred_frees()


func _legacy_diagonal_target_center_for_test(
	piece: TerrainModuleInstance,
	diagonal_socket_name: String
) -> Variant:
	var cardinals: Dictionary = {
		"frontleft": ["front", "left"],
		"frontright": ["front", "right"],
		"backright": ["back", "right"],
		"backleft": ["back", "left"],
	}
	var required_cardinals: Array = cardinals.get(diagonal_socket_name, [])
	if required_cardinals.size() != 2:
		return null
	var first_cardinal: String = required_cardinals[0]
	var second_cardinal: String = required_cardinals[1]
	if not piece.sockets.has(first_cardinal) or not piece.sockets.has(second_cardinal):
		return null
	var center: Vector3 = piece.transform.origin
	var first_pos: Vector3 = TerrainModuleSocket.new(piece, first_cardinal).get_socket_position()
	var second_pos: Vector3 = TerrainModuleSocket.new(piece, second_cardinal).get_socket_position()
	var first_offset: Vector3 = first_pos - center
	var second_offset: Vector3 = second_pos - center
	return center + (first_offset + second_offset) * 2.0


func _legacy_diagonal_neighbor_from_terrain_for_test(
	piece: TerrainModuleInstance,
	diagonal_socket_name: String,
	terrain_index: TerrainIndex
) -> TerrainModuleInstance:
	var diagonal_target: Variant = _legacy_diagonal_target_center_for_test(piece, diagonal_socket_name)
	if not (diagonal_target is Vector3):
		return null
	var target_pos: Vector3 = diagonal_target
	var query_box: AABB = AABB(target_pos + Vector3(-0.6, -2.0, -0.6), Vector3(1.2, 4.0, 1.2))
	var hits: Array = terrain_index.query_box(query_box)
	for hit in hits:
		if not (hit is TerrainModuleInstance):
			continue
		var other: TerrainModuleInstance = hit
		if other == piece:
			continue
		if not other.def.tags.has("level"):
			continue
		if abs(piece.transform.origin.y - other.transform.origin.y) > LevelEdgeRule.SAME_LEVEL_EPS:
			continue
		var delta: Vector3 = other.transform.origin - target_pos
		if abs(delta.x) <= 0.6 and abs(delta.z) <= 0.6:
			return other
	return null


func test_level_edge_rule_generated_world_projection_matches_legacy_projection() -> void:
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
	for _i in range(100):
		gen.load_terrain()
	var level_pieces: Array[TerrainModuleInstance] = _collect_level_pieces(gen)
	assert_true(level_pieces.size() > 0, "Expected generated level pieces for diagonal agreement check")
	var rule: LevelEdgeRule = LevelEdgeRule.new()
	var diagonal_sockets: Array[String] = ["frontleft", "frontright", "backright", "backleft"]
	var mismatch_count: int = 0
	var sample_mismatches: Array[String] = []
	for piece in level_pieces:
		for diagonal_socket_name in diagonal_sockets:
			var by_current: TerrainModuleInstance = rule._get_diagonal_level_neighbor_piece(
				piece,
				diagonal_socket_name,
				gen.terrain_index
			)
			var by_legacy: TerrainModuleInstance = _legacy_diagonal_neighbor_from_terrain_for_test(
				piece,
				diagonal_socket_name,
				gen.terrain_index
			)
			if by_current == by_legacy:
				continue
			mismatch_count += 1
			if sample_mismatches.size() < 12:
				sample_mismatches.append(
					"piece=%s socket=%s current=%s legacy=%s"
					% [piece.transform.origin, diagonal_socket_name, by_current, by_legacy]
				)
	assert_eq(
		mismatch_count,
		0,
		"Diagonal mismatch count=%s; sample=%s"
			% [mismatch_count, sample_mismatches]
	)
	_dispose_generator_immediately(gen)
	await _flush_deferred_frees()


# --------------------------------------------------------
# Level stacking (mountain) tests
# --------------------------------------------------------

func _configure_vertical_stacking_test_generation(gen: Variant) -> void:
	for module in gen.library.terrain_modules.library:
		if module.tags.has("ground"):
			module.socket_fill_prob["topcenter"] = 1.0
			module.socket_tag_prob["topcenter"] = Distribution.new({"level-ground-center": 1.0})
		if module.tags.has("level-ground-center"):
			module.socket_fill_prob["topcenter"] = 0.95
			module.socket_tag_prob["topcenter"] = Distribution.new({"level-stack-center": 1.0})
		if module.tags.has("level-stack-center"):
			module.socket_fill_prob["topcenter"] = 0.95
			module.socket_tag_prob["topcenter"] = Distribution.new({"level-stack-center": 1.0})


func _get_level_piece_below(gen: Variant, piece: TerrainModuleInstance) -> TerrainModuleInstance:
	if piece == null or piece.root == null or not piece.sockets.has("bottom"):
		return null
	var bottom_socket: TerrainModuleSocket = TerrainModuleSocket.new(piece, "bottom")
	var below: TerrainModuleSocket = gen.socket_index.query_other(
		bottom_socket.get_socket_position(),
		piece
	)
	if below == null or below.piece == null:
		return null
	if not below.piece.def.tags.has("level"):
		return null
	return below.piece


func _count_cardinal_level_neighbors(gen: Variant, piece: TerrainModuleInstance) -> int:
	var count: int = 0
	for socket_name in ["front", "back", "left", "right"]:
		if not piece.sockets.has(socket_name):
			continue
		var socket: TerrainModuleSocket = TerrainModuleSocket.new(piece, socket_name)
		var other: TerrainModuleSocket = gen.socket_index.query_other(
			socket.get_socket_position(),
			piece
		)
		if other == null or other.piece == null:
			continue
		if not other.piece.def.tags.has("level"):
			continue
		count += 1
	return count


func _count_elevated_level_pieces(gen: Variant) -> int:
	var elevated_count: int = 0
	for piece in _collect_level_pieces(gen):
		if piece.transform.origin.y > 0.6:
			elevated_count += 1
	return elevated_count


func _run_generation_until_elevated_level_count(
	gen: Variant,
	max_steps: int,
	target_count: int
) -> void:
	for _i in range(max_steps):
		gen.load_terrain()
		if _count_elevated_level_pieces(gen) >= target_count:
			return

func test_level_center_has_nonzero_topcenter_fill_prob():
	var module: TerrainModule = TerrainModuleDefinitions.load_level_middle_tile()
	assert_true(module.socket_fill_prob.has("topcenter"))
	var fill: Variant = module.socket_fill_prob["topcenter"]
	assert_true(fill is float, "topcenter fill_prob should be a float")
	assert_true(float(fill) >= 0.95, "topcenter fill_prob should be >= 0.95")


func test_level_edge_has_null_topcenter_fill_prob():
	var module: TerrainModule = TerrainModuleDefinitions.load_level_side_tile()
	assert_true(module.socket_fill_prob.has("topcenter"))
	assert_eq(module.socket_fill_prob["topcenter"], null)


func test_level_tiles_have_cardinal_fill_prob():
	var module: TerrainModule = TerrainModuleDefinitions.load_level_middle_tile()
	for socket_name in ["front", "back", "left", "right"]:
		assert_true(
			module.socket_fill_prob.has(socket_name),
			"level module missing fill_prob for " + socket_name
		)
		assert_true(
			module.socket_fill_prob[socket_name] is float
				and float(module.socket_fill_prob[socket_name]) > 0.0,
			"level cardinal fill_prob should be > 0: " + socket_name
		)


func test_level_center_has_topcenter_tag_prob():
	var module: TerrainModule = TerrainModuleDefinitions.load_level_middle_tile()
	assert_true(module.socket_tag_prob.has("topcenter"))
	var dist: Distribution = module.socket_tag_prob["topcenter"]
	assert_true(dist != null, "topcenter should have a tag distribution")
	assert_true(
		dist.prob("level-stack-center") > 0.0,
		"ground-level center should spawn stacked centers above it"
	)


func test_level_stack_center_is_vertical_only():
	var module: TerrainModule = TerrainModuleDefinitions.load_level_stack_middle_tile()
	for socket_name in ["front", "back", "left", "right"]:
		assert_true(
			module.socket_fill_prob.has(socket_name),
			"stack module missing fill_prob for " + socket_name
		)
		assert_eq(
			module.socket_fill_prob[socket_name],
			null,
			"stacked level cardinal fill_prob should be null: " + socket_name
		)
	assert_true(module.socket_fill_prob["topcenter"] is float)
	assert_true(
		float(module.socket_fill_prob["topcenter"]) >= 0.95,
		"stacked level center should strongly prefer vertical growth"
	)
	var top_dist: Distribution = module.socket_tag_prob["topcenter"]
	assert_true(
		top_dist.prob("level-stack-center") > 0.0,
		"stacked level center should keep spawning stacked centers upward"
	)


func test_ground_level_tiles_keep_lateral_fill_prob():
	var module: TerrainModule = TerrainModuleDefinitions.load_level_middle_tile()
	for socket_name in ["front", "back", "left", "right"]:
		assert_true(
			module.socket_fill_prob[socket_name] is float
				and float(module.socket_fill_prob[socket_name]) > 0.0,
			"ground-level level tiles should still expand laterally: " + socket_name
		)
	var lateral_dist: Distribution = module.socket_tag_prob["front"]
	assert_true(
		lateral_dist.prob("level-ground-center") > 0.0,
		"ground-level lateral expansion should keep building the base patch"
	)


func test_level_edge_rule_keeps_center_when_stacked():
	var gen: Variant = _new_generator()
	var rule: LevelEdgeRule = LevelEdgeRule.new()
	var layout: Dictionary[String, Vector3] = {
		"front": Vector3(0, 0, -1),
		"right": Vector3(1, 0, 0),
		"back": Vector3(0, 0, 1),
		"left": Vector3(-1, 0, 0),
		"topcenter": Vector3(0, 0.5, 0),
	}
	var level_mod: TerrainModule = _make_module(Vector3(2, 2, 2), layout)
	level_mod.tags = TagList.new(["level", "level-center"])
	var center_piece: TerrainModuleInstance = _spawn_piece(level_mod)

	var stacked_mod: TerrainModule = _make_module(
		Vector3(2, 2, 2), {"bottom": Vector3(0, -0.5, 0)}
	)
	stacked_mod.tags = TagList.new(["level"])
	var stacked_piece: TerrainModuleInstance = _spawn_piece(
		stacked_mod,
		Transform3D(Basis.IDENTITY, Vector3(0, 1, 0))
	)
	gen.socket_index.insert(
		TerrainModuleSocket.new(stacked_piece, "bottom")
	)
	assert_true(
		rule._is_stacked_support(center_piece, gen.socket_index),
		"Center with stacked tile should be identified as support"
	)


func test_level_edge_rule_removes_stacked_when_becoming_edge():
	var gen: Variant = _new_generator()
	var rule: LevelEdgeRule = LevelEdgeRule.new()
	var layout: Dictionary[String, Vector3] = {
		"front": Vector3(0, 0, -1),
		"right": Vector3(1, 0, 0),
		"back": Vector3(0, 0, 1),
		"left": Vector3(-1, 0, 0),
		"topcenter": Vector3(0, 0.5, 0),
		"frontright": Vector3(1, 0, -1),
		"frontleft": Vector3(-1, 0, -1),
		"backright": Vector3(1, 0, 1),
		"backleft": Vector3(-1, 0, 1),
	}
	var level_mod: TerrainModule = _make_module(Vector3(2, 2, 2), layout)
	level_mod.tags = TagList.new(["level", "level-center"])
	var center_piece: TerrainModuleInstance = _spawn_piece(level_mod)

	var stacked_mod: TerrainModule = _make_module(
		Vector3(2, 2, 2), {"bottom": Vector3(0, -0.5, 0)}
	)
	stacked_mod.tags = TagList.new(["level"])
	var stacked_piece: TerrainModuleInstance = _spawn_piece(
		stacked_mod,
		Transform3D(Basis.IDENTITY, Vector3(0, 1, 0))
	)
	gen.socket_index.insert(
		TerrainModuleSocket.new(stacked_piece, "bottom")
	)
	gen.terrain_index.insert(center_piece)
	var stacked_found: TerrainModuleInstance = rule._get_stacked_piece(
		center_piece, gen.socket_index
	)
	assert_eq(
		stacked_found,
		stacked_piece,
		"_get_stacked_piece should find the stacked level tile"
	)


func test_replace_piece_queues_topcenter_when_stack_piece_retiles_to_center():
	var gen: Variant = _new_generator()
	var side_module: TerrainModule = TerrainModuleDefinitions.load_level_stack_side_tile()
	var side_piece: TerrainModuleInstance = _spawn_piece(side_module)
	gen.terrain_parent.add_child(side_piece.root)
	gen.register_piece(side_piece, "")

	var center_module: TerrainModule = TerrainModuleDefinitions.load_level_stack_middle_tile()
	var center_piece: TerrainModuleInstance = center_module.spawn()
	center_piece.set_transform(side_piece.transform)
	center_piece.create()
	_pieces_to_destroy.append(center_piece)

	gen._replace_piece(side_piece, center_piece)

	var queued_topcenter: bool = false
	for entry in gen.queue.heap:
		if not (entry is Dictionary):
			continue
		var queued_socket: Variant = entry.get("item", null)
		if not (queued_socket is TerrainModuleSocket):
			continue
		if queued_socket.piece != center_piece:
			continue
		if queued_socket.socket_name != "topcenter":
			continue
		queued_topcenter = true
		break

	assert_true(
		queued_topcenter,
		"Retiling a stacked piece to level-stack-center should enqueue its topcenter socket"
	)


func test_level_edge_rule_ignores_elevated_diagonal_when_computing_inner_corner():
	var gen: Variant = _new_generator()
	var rule: LevelEdgeRule = LevelEdgeRule.new()
	var layout: Dictionary[String, Vector3] = {
		"front": Vector3(0, 0, -1),
		"left": Vector3(-1, 0, 0),
		"frontleft": Vector3(-1, 0, -1),
	}
	var level_mod: TerrainModule = _make_module(Vector3(2, 2, 2), layout)
	level_mod.tags = TagList.new(["level"])
	var center_piece: TerrainModuleInstance = _spawn_piece(level_mod)
	var neighbor_mod: TerrainModule = _make_module(Vector3(1, 1, 1), {"main": Vector3.ZERO})
	neighbor_mod.tags = TagList.new(["level"])
	var front_neighbor: TerrainModuleInstance = _spawn_piece(
		neighbor_mod,
		Transform3D(Basis.IDENTITY, Vector3(0, 0, -1))
	)
	var left_neighbor: TerrainModuleInstance = _spawn_piece(
		neighbor_mod,
		Transform3D(Basis.IDENTITY, Vector3(-1, 0, 0))
	)
	var elevated_diagonal: TerrainModuleInstance = _spawn_piece(
		neighbor_mod,
		Transform3D(Basis.IDENTITY, Vector3(-2, 1, -2))
	)
	gen.socket_index.insert(TerrainModuleSocket.new(front_neighbor, "main"))
	gen.socket_index.insert(TerrainModuleSocket.new(left_neighbor, "main"))
	gen.terrain_index.insert(elevated_diagonal)
	assert_eq(
		rule._get_diagonal_level_neighbor_piece(center_piece, "frontleft", gen.terrain_index),
		null,
		"Elevated diagonal tiles must not count as same-layer diagonal neighbors"
	)
	var missing: Array[String] = rule._missing_sockets_for_piece(
		center_piece,
		gen.socket_index,
		gen.terrain_index
	)
	assert_true(
		missing.has("frontleft"),
		"Elevated diagonals must not suppress inner-corner edges on the lower level"
	)


func test_integration_vertical_stacking_produces_elevated_level_tiles():
	var gen: Variant = _new_debug_generator()
	gen.player.global_position = Vector3.ZERO
	gen.RENDER_RANGE = 220
	gen.MAX_LOAD_PER_STEP = 20
	seed(42)
	_run_generator_ready(gen)
	_configure_vertical_stacking_test_generation(gen)
	_run_generation_until_elevated_level_count(gen, 1800, 1)

	var level_pieces: Array[TerrainModuleInstance] = _collect_level_pieces(gen)
	var max_y: float = 0.0
	var stacked_count: int = 0
	for piece in level_pieces:
		var y: float = piece.transform.origin.y
		if y > max_y:
			max_y = y
		if y > 0.6:
			stacked_count += 1
	assert_true(
		level_pieces.size() > 0,
		"Expected level tiles to be generated"
	)
	assert_true(
		stacked_count > 0,
		"Expected at least one stacked level tile (y > 0.6)"
	)
	_dispose_generator_immediately(gen)
	await _flush_deferred_frees()


func test_integration_stacked_level_tiles_only_use_full_cardinal_supports():
	var gen: Variant = _new_debug_generator()
	gen.player.global_position = Vector3.ZERO
	gen.RENDER_RANGE = 220
	gen.MAX_LOAD_PER_STEP = 20
	seed(42)
	_run_generator_ready(gen)
	_configure_vertical_stacking_test_generation(gen)
	_run_generation_until_elevated_level_count(gen, 1800, 1)

	var level_pieces: Array[TerrainModuleInstance] = _collect_level_pieces(gen)
	var stacked_count: int = 0
	for piece in level_pieces:
		if piece.transform.origin.y <= 0.6:
			continue
		stacked_count += 1
		var support: TerrainModuleInstance = _get_level_piece_below(gen, piece)
		assert_true(
			support != null,
			"Each elevated level tile must have a supporting level tile below it"
		)
		if support == null:
			continue
		assert_eq(
			_count_cardinal_level_neighbors(gen, support),
			4,
			"Support tile below an elevated level tile must have level neighbors in all four cardinals"
		)
	assert_true(stacked_count > 0, "Expected at least one elevated level tile to validate support rules")
	_dispose_generator_immediately(gen)
	await _flush_deferred_frees()
