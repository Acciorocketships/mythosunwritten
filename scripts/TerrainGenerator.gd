extends Node3D

@export var RENDER_RANGE: int = 150
@export var MAX_LOAD_PER_STEP: int = 8

@export var player: Node3D
@export var terrain_parent: Node

var library: TerrainModuleLibrary
var terrain_index: TerrainIndex
var socket_index: PositionIndex
var queue: PriorityQueue

func _ready() -> void:
	library = TerrainModuleLibrary.new()
	library.init()
	
	socket_index = PositionIndex.new()
	terrain_index = TerrainIndex.new()

	var start_tile := load_start_tile()
	queue = PriorityQueue.new()
	for socket_name in start_tile.sockets.keys():
		var piece_socket: TerrainModuleSocket = TerrainModuleSocket.new(start_tile, socket_name)
		queue.push(piece_socket, 0)

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

		if distance > RENDER_RANGE:
			queue.push(piece_socket, distance)
			return

		var fill_prob = piece.def.socket_fill_prob.prob(socket_name)
		if randf() > fill_prob:
			return

		var size_prob_dist: Distribution = piece.def.socket_size[socket_name]
		var size: String = size_prob_dist.sample()

		var adjacent := get_adjacent_from_size(piece_socket, size)
		
		var chosen: TerrainModuleInstance = choose_piece(adjacent)
		
		print(chosen)
		
		
func choose_piece(adjacent: Dictionary[String, TerrainModuleSocket]) -> TerrainModuleInstance:
	var required_tags: TagList = library.get_required_tags(adjacent)
	var filtered: TerrainModuleList = library.get_by_tags(required_tags)
	var dist: Distribution = library.get_combined_distribution(adjacent)
	var chosen_template: TerrainModule = library.sample_from_modules(filtered, dist)
	var chosen: TerrainModuleInstance = chosen_template.spawn()
	# choose a new piece if it cant be placed (i.e. the bounding box overlaps with something)
	while not can_place(chosen):
		chosen = library.sample_from_modules(filtered, dist).spawn()
		push_warning("could not place piece %s" % chosen)
	return chosen


func get_dist_from_player(socket: Marker3D) -> float:
	return (socket.global_position - player.global_position).length()


func add_piece_to_queue(piece: TerrainModuleInstance) -> void:
	for socket_name: String in piece.sockets.keys():
		var socket: Marker3D = piece.sockets[socket_name]
		var dist := get_dist_from_player(socket)
		var item: TerrainModuleSocket = TerrainModuleSocket.new(piece, socket_name)
		queue.push(item, dist)


func register_piece_and_socket(piece_socket: TerrainModuleSocket) -> void:
	var piece: TerrainModuleInstance = piece_socket.piece
	socket_index.insert(piece_socket)
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
		var pos := _socket_world_pos(piece.transform, s, piece.root)

		var hit := socket_index.query(pos)
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
	var orig_main_world := orig_piece.transform * _to_root_tf(orig_sock, orig_piece.root)
	var test_main_local := _to_root_tf(test_main, test_piece.root)
	var aligned_tf := orig_main_world * test_main_local.affine_inverse()

	var out: Dictionary[String, TerrainModuleSocket] = {"main": orig_piece_socket}

	for socket_name: String in test_piece.sockets.keys():
		if socket_name == "main":
			continue

		var s: Marker3D = test_piece.sockets[socket_name]
		var pos := _socket_world_pos(aligned_tf, s, test_piece.root)

		var hit := socket_index.query(pos)
		if hit != null:
			out[socket_name] = hit

	test_piece.destroy()
	return out


func transform_to_socket(new_piece_socket: TerrainModuleSocket, orig_piece_socket: TerrainModuleSocket) -> void:
	var orig_piece: TerrainModuleInstance = orig_piece_socket.piece
	var orig_socket: Marker3D = orig_piece_socket.socket
	var new_piece: TerrainModuleInstance = new_piece_socket.piece
	var new_socket: Marker3D = new_piece_socket.socket

	var target_dir: Vector3 = orig_piece.get_position() - orig_socket.global_position
	var current_dir: Vector3 = new_socket.global_position - new_piece.get_position()

	target_dir.y = 0
	current_dir.y = 0
	target_dir = target_dir.normalized()
	current_dir = current_dir.normalized()

	var angle := atan2(target_dir.cross(current_dir).y, target_dir.dot(current_dir))
	var curr_basis := new_piece.transform.basis
	var new_basis := curr_basis.rotated(Vector3.UP, angle)

	var new_position := orig_socket.global_position + (new_piece.get_position() - new_socket.global_position)
	new_piece.set_transform(Transform3D(new_basis, new_position))


func add_piece(new_piece_socket: TerrainModuleSocket, orig_piece_socket: TerrainModuleSocket) -> bool:
	transform_to_socket(new_piece_socket, orig_piece_socket)

	var new_piece: TerrainModuleInstance = new_piece_socket.piece
	if not can_place(new_piece):
		return false

	new_piece.create()
	new_piece.root.reparent(terrain_parent, false)

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
	
	
### Helper ###


# Node3D -> transform relative to a given root (no scene tree needed)
func _to_root_tf(n: Node3D, root: Node3D) -> Transform3D:
	var tf := n.transform
	var p := n.get_parent()
	while p != null and p != root:
		if p is Node3D:
			tf = (p as Node3D).transform * tf
		p = p.get_parent()
	return tf


# Socket world position given a piece/world transform and socket node
func _socket_world_pos(piece_tf: Transform3D, socket_node: Node3D, root: Node3D) -> Vector3:
	return (piece_tf * _to_root_tf(socket_node, root)).origin
