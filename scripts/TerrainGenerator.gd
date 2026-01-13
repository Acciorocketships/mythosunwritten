extends Node3D

@export var RENDER_RANGE: int = 150
@export var MAX_LOAD_PER_STEP: int = 8

@export var player: Node3D
@export var terrain_parent: Node

var library: TerrainModuleLibrary
var terrain_index: TerrainIndex
var socket_index: PositionIndex
var queue: PriorityQueue

func _compute_inward_normal(piece: TerrainModuleInstance, socket_name: String) -> Vector3:
	# Compute normal as inward-facing normal of nearest face in LOCAL space,
	# then transform to world using the piece's basis. This avoids axis-aligned AABB artifacts.
	var socket_node: Marker3D = piece.sockets.get(socket_name, null)
	if socket_node == null:
		return Vector3.ZERO
	var local_tf: Transform3D = Helper.to_root_tf(socket_node, piece.root)
	var p_local: Vector3 = local_tf.origin
	var local_box: AABB = piece.def.size
	var minp_l: Vector3 = local_box.position
	var maxp_l: Vector3 = local_box.position + local_box.size
	var dx_min: float = abs(p_local.x - minp_l.x)
	var dx_max: float = abs(maxp_l.x - p_local.x)
	var dy_min: float = abs(p_local.y - minp_l.y)
	var dy_max: float = abs(maxp_l.y - p_local.y)
	var dz_min: float = abs(p_local.z - minp_l.z)
	var dz_max: float = abs(maxp_l.z - p_local.z)
	var nearest: float = dx_min
	var n_local: Vector3 = Vector3(-1, 0, 0) # outward on min X
	if dx_max < nearest:
		nearest = dx_max
		n_local = Vector3(1, 0, 0)
	if dy_min < nearest:
		nearest = dy_min
		n_local = Vector3(0, -1, 0)
	if dy_max < nearest:
		nearest = dy_max
		n_local = Vector3(0, 1, 0)
	if dz_min < nearest:
		nearest = dz_min
		n_local = Vector3(0, 0, -1)
	if dz_max < nearest:
		nearest = dz_max
		n_local = Vector3(0, 0, 1)
	# Inward is opposite of outward
	var inward_local: Vector3 = -n_local
	var inward_world: Vector3 = piece.transform.basis * inward_local
	return inward_world.normalized()

func _ready() -> void:
	library = TerrainModuleLibrary.new()
	library.init()

	socket_index = PositionIndex.new()
	terrain_index = TerrainIndex.new()

	var start_tile := load_start_tile()
	queue = PriorityQueue.new()
	# Register the start tile in indices so collision checks work and adjacency can be detected
	var dummy_socket: TerrainModuleSocket = TerrainModuleSocket.new(start_tile, "__init__")
	register_piece_and_socket(dummy_socket)
	for socket_name in start_tile.sockets.keys():
		if start_tile.def.socket_fill_prob.prob(socket_name) <= 0.0:
			continue
		var piece_socket: TerrainModuleSocket = TerrainModuleSocket.new(start_tile, socket_name)
		var dist := get_dist_from_player(piece_socket.socket)
		queue.push(piece_socket, dist)

func _process(_delta: float) -> void:
	load_terrain()

func load_terrain() -> void:
	var num_added: int = 0
	while num_added < MAX_LOAD_PER_STEP and !queue.is_empty():
		var piece_socket = queue.pop()
		var piece: TerrainModuleInstance = piece_socket.piece
		var socket_name: String = piece_socket.socket_name
		var socket: Marker3D = piece_socket.socket
		var distance := get_dist_from_player(socket)

		# If this socket is already connected (another piece has a socket at the same position),
		# skip it to avoid repeatedly trying to place overlapping tiles.
		if socket_index.query_other(piece_socket.get_socket_position(), piece) != null:
			continue

		if distance > RENDER_RANGE:
			queue.push(piece_socket, distance)
			return

		var fill_prob = piece.def.socket_fill_prob.prob(socket_name)
		if randf() > fill_prob:
			return

		var size_prob_dist: Distribution = piece.def.socket_size[socket_name]
		var size: String = size_prob_dist.sample()

		var adjacent := get_adjacent_from_size(piece_socket, size)

		var placed_ok := false
		for attempt in range(4):
			var chosen: TerrainModuleInstance = choose_piece(adjacent)
			chosen.create()
			var new_piece_socket: TerrainModuleSocket = TerrainModuleSocket.new(chosen, "main")
			var placed := add_piece(new_piece_socket, piece_socket)
			if placed:
				num_added += 1
				placed_ok = true
				break
			else:
				chosen.destroy()
		if placed_ok:
			continue
		return



func choose_piece(adjacent: Dictionary[String, TerrainModuleSocket]) -> TerrainModuleInstance:
	var required_tags: TagList = library.get_required_tags(adjacent)
	var filtered: TerrainModuleList = library.get_by_tags(required_tags)
	var dist: Distribution = library.get_combined_distribution(adjacent)
	var chosen_template: TerrainModule = library.sample_from_modules(filtered, dist)
	var chosen: TerrainModuleInstance = chosen_template.spawn()
	return chosen


func get_dist_from_player(socket: Marker3D) -> float:
	return (socket.global_position - player.global_position).length()


func add_piece_to_queue(piece: TerrainModuleInstance) -> void:
	for socket_name: String in piece.sockets.keys():
		# "main" is the attachment socket; do not expand from it (it points back inward).
		if socket_name == "main":
			continue
		if piece.def.socket_fill_prob.prob(socket_name) <= 0.0:
			continue
		var socket: Marker3D = piece.sockets[socket_name]
		var pos := Helper.socket_world_pos(piece.transform, socket, piece.root)
		# If this socket is already connected (another piece has a socket here), don't enqueue it.
		if socket_index.query_other(pos, piece) != null:
			continue
		var dist := get_dist_from_player(socket)
		var item: TerrainModuleSocket = TerrainModuleSocket.new(piece, socket_name)
		queue.push(item, dist)


func register_piece_and_socket(piece_socket: TerrainModuleSocket) -> void:
	var piece: TerrainModuleInstance = piece_socket.piece
	for socket_name: String in piece.sockets.keys():
		# Only index sockets with non-zero fill probability, skip the one used for attachment
		if socket_name != piece_socket.socket_name and piece.def.socket_fill_prob.prob(socket_name) > 0.0:
			var piece_other_socket: TerrainModuleSocket = TerrainModuleSocket.new(piece, socket_name)
			socket_index.insert(piece_other_socket)
	terrain_index.insert(piece)


func can_place(new_piece: TerrainModuleInstance) -> bool:
	var other_pieces = terrain_index.query_box(new_piece.aabb)
	return other_pieces.is_empty()


func get_adjacent(piece: TerrainModuleInstance) -> Dictionary[String, TerrainModuleSocket]:
	if piece.root == null:
		return {}

	var out: Dictionary[String, TerrainModuleSocket] = {}
	for socket_name: String in piece.sockets.keys():
		var s: Marker3D = piece.sockets[socket_name]
		var pos := Helper.socket_world_pos(piece.transform, s, piece.root)

		var hit := socket_index.query_other(pos, piece)
		if hit != null:
			out[socket_name] = hit
	return out


func get_adjacent_from_size(orig_piece_socket: TerrainModuleSocket, size: String) -> Dictionary[String, TerrainModuleSocket]:
	var orig_piece: TerrainModuleInstance = orig_piece_socket.piece
	var orig_sock: Marker3D = orig_piece_socket.socket
	assert(orig_piece.root != null)
	assert(orig_sock != null)

	var all_pieces_of_size: TerrainModuleList = library.get_by_tags(TagList.new([size]))
	var test_piece_template: TerrainModule = library.get_random(all_pieces_of_size, true)
	var test_piece: TerrainModuleInstance = test_piece_template.spawn()
	assert(test_piece != null)
	test_piece.create()

	var test_main: Marker3D = test_piece.sockets.get("main", null)
	assert(test_main != null)

	# Align test piece so its "main" socket lands on the given orig socket
	var orig_main_world := orig_piece.transform * Helper.to_root_tf(orig_sock, orig_piece.root)
	var test_main_local := Helper.to_root_tf(test_main, test_piece.root)
	var aligned_tf := orig_main_world * test_main_local.affine_inverse()
	aligned_tf = Helper.snap_transform_origin(aligned_tf)

	var out: Dictionary[String, TerrainModuleSocket] = {"main": orig_piece_socket}

	for socket_name: String in test_piece.sockets.keys():
		# Only consider test sockets with non-zero fill probability
		if socket_name == "main" or test_piece.def.socket_fill_prob.prob(socket_name) <= 0.0:
			continue

		var s: Marker3D = test_piece.sockets[socket_name]
		var pos := Helper.socket_world_pos(aligned_tf, s, test_piece.root)

		# We only care about existing world sockets, never sockets on the test_piece. 
		# Now test_piece isn't indexed, but using query_other makes this future-proof.
		var hit := socket_index.query_other(pos, test_piece)
		if hit != null:
			out[socket_name] = hit

	test_piece.destroy()
	return out


func transform_to_socket(new_ps: TerrainModuleSocket, orig_ps: TerrainModuleSocket) -> void:
	var orig_socket_pos: Vector3 = orig_ps.get_socket_position()
	var new_socket_pos: Vector3 = new_ps.get_socket_position()
	var orig_piece_pos: Vector3 = orig_ps.get_piece_position()
	var new_piece_pos: Vector3 = new_ps.get_piece_position()

	var new_piece: TerrainModuleInstance = new_ps.piece
	# Align in XZ only (prevent tilting) by using the actual socket direction:
	# d = (piece_center -> socket_pos) projected to XZ.
	#
	# This is more robust than choosing a face normal from an AABB, especially when sockets sit
	# on edges/corners (e.g. y=0 plane), where "nearest face" is ambiguous.
	var target2 := Vector2(orig_socket_pos.x - orig_piece_pos.x, orig_socket_pos.z - orig_piece_pos.z)
	var current2 := Vector2(new_socket_pos.x - new_piece_pos.x, new_socket_pos.z - new_piece_pos.z)

	if target2.length() > 1e-6 and current2.length() > 1e-6:
		# We want the new socket to be on the opposite side of the shared point, so the two pieces
		# sit adjacent rather than overlapping.
		var desired2 := (-target2).normalized()
		current2 = current2.normalized()
		var ang_desired := atan2(desired2.y, desired2.x)
		var ang_current := atan2(current2.y, current2.x)
		# Godot's yaw sign in XZ is opposite our atan2 convention here.
		# Flipping the sign makes +X rotate toward the intended XZ direction.
		var yaw := ang_current - ang_desired
		var rot_y := Basis(Vector3.UP, yaw)
		new_piece.set_basis(rot_y * new_piece.transform.basis)

	# Recompute socket pos after rotation
	var rotated_socket_pos := new_ps.get_socket_position()

	# Translate so sockets coincide
	var new_position: Vector3 = new_piece_pos + (orig_socket_pos - rotated_socket_pos)
	new_piece.set_position(Helper.snap_vec3(new_position))

func add_piece(new_piece_socket: TerrainModuleSocket, orig_piece_socket: TerrainModuleSocket) -> bool:
	transform_to_socket(new_piece_socket, orig_piece_socket)

	var new_piece: TerrainModuleInstance = new_piece_socket.piece
	if not can_place(new_piece):
		return false

	terrain_parent.add_child(new_piece.root)

	register_piece_and_socket(new_piece_socket)
	add_piece_to_queue(new_piece)
	return true


func load_start_tile() -> TerrainModuleInstance:
	var def := library.load_ground_tile()
	var initial_tile := def.spawn()
	initial_tile.set_transform(Transform3D.IDENTITY)
	var root := initial_tile.create()
	terrain_parent.add_child(root)
	return initial_tile
