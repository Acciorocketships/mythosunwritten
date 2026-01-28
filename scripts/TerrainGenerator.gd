extends Node3D

@export var RENDER_RANGE: int = 250
@export var MAX_LOAD_PER_STEP: int = 8

@export var player: Node3D
@export var terrain_parent: Node
@export var proximity_rules: ProximityTagRules

var library: TerrainModuleLibrary
var test_pieces_library: TerrainModuleLibrary
var terrain_index: TerrainIndex
var socket_index: PositionIndex
var queue: PriorityQueue


func _ready() -> void:
	library = TerrainModuleLibrary.new()
	library.init()

	test_pieces_library = TerrainModuleLibrary.new()
	test_pieces_library.init_test_pieces()

	socket_index = PositionIndex.new()
	terrain_index = TerrainIndex.new()
	if proximity_rules == null:
		proximity_rules = ProximityTagRules.new()

	var start_tile := load_start_tile()
	queue = PriorityQueue.new()
	# Register the start tile in indices so collision checks work and adjacency can be detected
	var dummy_socket: TerrainModuleSocket = TerrainModuleSocket.new(start_tile, "front")
	register_piece_and_socket(dummy_socket)
	for socket_name in start_tile.sockets.keys():
		if float(start_tile.def.socket_fill_prob.get(socket_name, 0.0)) <= 0.0:
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

		var origin_world: Vector3 = piece_socket.get_socket_position()
		var size: String = "point"
		if socket_name in piece.def.socket_size:
			var size_prob_dist: Distribution = piece.def.socket_size[socket_name]
			size = size_prob_dist.sample()

		var adjacent := get_adjacent_from_size(piece_socket, size)
		if adjacent.is_empty():
			# Adjacent sockets include forbidden areas (fill_prob <= 0), skip this expansion
			continue

		# Compute the tag distribution once, then use its proximity factor to adjust
		# BOTH: (1) whether we fill at all, and (2) which tag we sample.
		var probs: Dictionary = compute_socket_probs(piece, socket_name, adjacent, origin_world, size)
		var filtered: TerrainModuleList = probs["filtered"] as TerrainModuleList
		var dist: Distribution = probs["dist"] as Distribution
		var fill_prob: float = float(probs["fill_prob"])
		if randf() > fill_prob:
			# Continue to next socket instead of stopping processing for this frame
			continue

		# Determine the attachment socket name based on the expansion socket
		var attachment_socket_name: String = Helper.get_attachment_socket_name(socket_name)

		var placed_ok := false
		for attempt in range(4):
			var chosen_template: TerrainModule = library.sample_from_modules(filtered, dist)
			var chosen: TerrainModuleInstance = chosen_template.spawn()
			chosen.create()
			var new_piece_socket: TerrainModuleSocket = TerrainModuleSocket.new(chosen, attachment_socket_name)
			var placed := add_piece(new_piece_socket, piece_socket)
			if placed:
				num_added += 1
				placed_ok = true
				break
			else:
				chosen.destroy()
		if placed_ok:
			continue
		# Continue to next socket instead of stopping processing for this frame
		continue


func compute_socket_probs(
	piece: TerrainModuleInstance,
	socket_name: String,
	adjacent: Dictionary[String, TerrainModuleSocket],
	origin_world: Vector3,
	size: String,
) -> Dictionary:
	# Returns:
	# - filtered: TerrainModuleList
	# - dist: Distribution
	# - factor: float (tag-dist inflation factor)
	# - fill_prob: float (base fill prob * factor, clamped 0..1)
	
	# Try different rotations of adjacency until we find one that works
	var current_adjacent = adjacent.duplicate()
	for rotation_attempt in range(4):  # Try up to 4 rotations
		var required_tags: TagList = library.get_required_tags(current_adjacent)
		required_tags.append(size) # only find pieces with the given size
		var filtered: TerrainModuleList = library.get_by_tags(required_tags)
		
		if !filtered.is_empty():
			# Found valid results with this adjacency
			var dist_raw: Distribution = library.get_combined_distribution(current_adjacent)
			var dist: Distribution = dist_raw.copy()
			var fill_prob_base: float = float(piece.def.socket_fill_prob.get(socket_name, 0.0))
			var factor: float = 1.0
			if proximity_rules != null:
				var res: Dictionary = proximity_rules.augment_distribution_with_factor(
					dist,
					origin_world,
					terrain_index,
					fill_prob_base
				)
				dist = res["dist"] as Distribution
				factor = float(res["factor"])

			var fill_prob: float = clampf(fill_prob_base * factor, 0.0, 1.0)

			return {
				"filtered": filtered,
				"dist": dist,
				"factor": factor,
				"fill_prob": fill_prob,
			}
		
		# Rotate adjacency for next attempt
		current_adjacent = Helper.rotate_adjacency(current_adjacent)
	
	# No valid adjacency found after all rotations
	print("CRITICAL: No modules for any rotation of adjacency (size %s, original adj %s)" % [size, adjacent.keys()])
	return {
		"filtered": TerrainModuleList.new(),
		"dist": Distribution.new(),
		"factor": 0.0,
		"fill_prob": 0.0,
	}

func get_dist_from_player(socket: Marker3D) -> float:
	return (socket.global_position - player.global_position).length()






func add_piece_to_queue(piece: TerrainModuleInstance) -> void:
	for socket_name: String in piece.sockets.keys():
		if float(piece.def.socket_fill_prob.get(socket_name, 0.0)) <= 0.0:
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
		# Index all sockets (including those with fill_prob = 0) so they can act as adjacency barriers
		# Skip only the attachment socket
		if socket_name != piece_socket.socket_name:
			var piece_other_socket: TerrainModuleSocket = TerrainModuleSocket.new(piece, socket_name)
			socket_index.insert(piece_other_socket)
	terrain_index.insert(piece)


func can_place(new_piece: TerrainModuleInstance, parent_piece: TerrainModuleInstance) -> bool:
	assert(new_piece.def != null)
	if new_piece.def.replace_existing:
		return true
	var other_pieces: Array = terrain_index.query_box(new_piece.aabb)
	if parent_piece != null:
		other_pieces.erase(parent_piece)
	return other_pieces.is_empty()


func remove_piece(piece: TerrainModuleInstance) -> void:
	# Remove from terrain index
	terrain_index.remove(piece)

	# Remove all sockets from position index
	for socket_name in piece.sockets.keys():
		var socket_pos = Helper.socket_world_pos(piece.transform, piece.sockets[socket_name], piece.root)
		var snapped_pos = Helper.snap_vec3(socket_pos)
		if socket_index.store.has(snapped_pos):
			var sockets_at_pos = socket_index.store[snapped_pos]
			sockets_at_pos = sockets_at_pos.filter(func(ps): return ps.piece != piece)
			if sockets_at_pos.is_empty():
				socket_index.store.erase(snapped_pos)
			else:
				socket_index.store[snapped_pos] = sockets_at_pos

	# Remove from priority queue
	queue.remove_where(func(item): return item is TerrainModuleSocket and item.piece == piece)

	# Remove from scene tree
	if piece.root and piece.root.get_parent() == terrain_parent:
		terrain_parent.remove_child(piece.root)
		piece.root.queue_free()


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


func get_adjacent_from_size(
	orig_piece_socket: TerrainModuleSocket,
	size: String
) -> Dictionary[String, TerrainModuleSocket]:
	if size == "point":
		return {"bottom": orig_piece_socket}

	var orig_piece: TerrainModuleInstance = orig_piece_socket.piece
	var orig_sock: Marker3D = orig_piece_socket.socket
	assert(orig_piece.root != null)
	assert(orig_sock != null)

	# Get test piece for this size
	var test_pieces: TerrainModuleList = test_pieces_library.get_by_tags(TagList.new([size]))
	if test_pieces.is_empty():
		push_error("No test piece found for size: " + size)
		return {}

	var test_piece_template: TerrainModule = test_pieces_library.get_random(test_pieces, true)
	var test_piece: TerrainModuleInstance = test_piece_template.spawn()
	assert(test_piece != null)
	test_piece.create()

	# Determine which socket on the test piece should attach
	var attachment_socket_name: String = Helper.get_attachment_socket_name(orig_piece_socket.socket_name)
	var attachment_socket: Marker3D = test_piece.sockets.get(attachment_socket_name, null)
	if attachment_socket == null:
		push_error("Test piece does not have attachment socket: " + attachment_socket_name)
		test_piece.destroy()
		return {}

	# Position the test piece so the attachment socket aligns with the expansion socket
	var orig_socket_pos: Vector3 = orig_piece_socket.get_socket_position()
	var attachment_local: Transform3D = Helper.to_root_tf(attachment_socket, test_piece.root)
	test_piece.set_position(orig_socket_pos - attachment_local.origin)

	# Get initial adjacency
	var adjacency: Dictionary[String, TerrainModuleSocket] = {attachment_socket_name: orig_piece_socket}

	for socket_name: String in test_piece.sockets.keys():
		if socket_name == attachment_socket_name:
			continue

		var s: Marker3D = test_piece.sockets[socket_name]
		var pos := Helper.socket_world_pos(test_piece.transform, s, test_piece.root)
		var hit := socket_index.query_other(pos, test_piece)
		if hit != null:
			# If we find any adjacent socket with fill_prob <= 0, prevent this placement entirely
			var adjacent_fill_prob: float = float(hit.piece.def.socket_fill_prob.get(hit.socket_name, 0.0))
			if adjacent_fill_prob <= 0.0:
				test_piece.destroy()
				return {}

		# Only include in adjacency if this socket can actually expand
		if float(test_piece.def.socket_fill_prob.get(socket_name, 0.0)) > 0.0:
			if hit != null:
				adjacency[socket_name] = hit

	test_piece.destroy()
	return adjacency


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

func add_piece(
	new_piece_socket: TerrainModuleSocket,
	orig_piece_socket: TerrainModuleSocket
) -> bool:
	transform_to_socket(new_piece_socket, orig_piece_socket)

	var new_piece: TerrainModuleInstance = new_piece_socket.piece
	if not can_place(new_piece, orig_piece_socket.piece):
		return false

	# If replace_existing is true, remove all overlapping pieces
	if new_piece.def.replace_existing:
		var overlapping_pieces: Array = terrain_index.query_box(new_piece.aabb)
		if orig_piece_socket.piece != null:
			overlapping_pieces.erase(orig_piece_socket.piece)
		for piece in overlapping_pieces:
			remove_piece(piece)

	terrain_parent.add_child(new_piece.root)

	register_piece_and_socket(new_piece_socket)
	add_piece_to_queue(new_piece)

	# Remove sockets that are now linked into from the queue
	remove_linked_sockets_from_queue(new_piece_socket)

	return true


func remove_linked_sockets_from_queue(new_piece_socket: TerrainModuleSocket) -> void:
	# Remove sockets that were linked into by the new piece from the queue
	# These are the sockets that the new piece connected to

	var new_piece: TerrainModuleInstance = new_piece_socket.piece
	var linked_sockets: Array[TerrainModuleSocket] = []

	# Find all sockets on other pieces that are at the same positions as our new piece's sockets
	for socket_name in new_piece.sockets.keys():
		var socket: Marker3D = new_piece.sockets[socket_name]
		var socket_pos := Helper.socket_world_pos(new_piece.transform, socket, new_piece.root)

		# Find any existing socket at this position (not belonging to our new piece)
		var existing_socket := socket_index.query_other(socket_pos, new_piece)
		if existing_socket != null:
			linked_sockets.append(existing_socket)

	# Remove these linked sockets from the queue
	for linked_socket in linked_sockets:
		queue.remove_where(func(item): return item is TerrainModuleSocket and item.piece == linked_socket.piece and item.socket_name == linked_socket.socket_name)


func load_start_tile() -> TerrainModuleInstance:
	var def : TerrainModule = TerrainModuleDefinitions.load_ground_tile()
	var initial_tile := def.spawn()
	initial_tile.set_transform(Transform3D.IDENTITY)
	var root := initial_tile.create()
	terrain_parent.add_child(root)

	# For the start tile, we need to register it with the "front" socket as the attachment point
	var dummy_socket: TerrainModuleSocket = TerrainModuleSocket.new(initial_tile, "front")
	register_piece_and_socket(dummy_socket)

	return initial_tile
