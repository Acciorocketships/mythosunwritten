extends Node3D

@export var RENDER_RANGE: int = 250
@export var MAX_LOAD_PER_STEP: int = 8

@export var player: Node3D
@export var terrain_parent: Node
@export var generation_rules: TerrainGenerationRuleLibrary

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
	if generation_rules == null:
		generation_rules = TerrainGenerationRuleLibrary.new()

	var start_tile := load_start_tile()
	queue = PriorityQueue.new()
	# Register the start tile in indices so collision checks work and adjacency can be detected
	# Sockets are indexed so they can act as adjacency barriers.
	register_piece(start_tile, "")
	for socket_name in start_tile.sockets.keys():
		if float(start_tile.def.socket_fill_prob.get(socket_name, 0.0)) <= 0.0:
			continue
		var piece_socket: TerrainModuleSocket = TerrainModuleSocket.new(start_tile, socket_name)
		var dist := get_dist_from_player(piece_socket.piece, piece_socket.socket_name)
		queue.push(piece_socket, dist)

func _process(_delta: float) -> void:
	load_terrain()

func load_terrain() -> void:
	var num_added: int = 0
	var num_processed: int = 0

	while num_added < MAX_LOAD_PER_STEP and num_processed < MAX_LOAD_PER_STEP * 2 and !queue.is_empty():
		var piece_socket = queue.pop()
		var piece: TerrainModuleInstance = piece_socket.piece
		var socket_name: String = piece_socket.socket_name
		var socket: Marker3D = piece_socket.socket
		var distance := get_dist_from_player(piece, socket_name)

		num_processed += 1

		if not _process_socket(piece_socket, distance):
			continue
		num_added += 1


func _process_socket(piece_socket: TerrainModuleSocket, distance: float) -> bool:
	var piece: TerrainModuleInstance = piece_socket.piece
	var socket_name: String = piece_socket.socket_name
	var socket: Marker3D = piece_socket.socket

	# If this socket is already connected (another piece has a socket at the same position),
	# skip it to avoid repeatedly trying to place overlapping tiles.
	# Exception: Ground pieces are allowed to overlap with non-ground pieces' sockets.
	# If this socket is already connected (another piece has a socket at the same position),
	# skip it to avoid repeatedly trying to place overlapping tiles.
	# Exception: Ground pieces are allowed to overlap with non-ground pieces' sockets.
	# This allows ground to be generated under level pieces.
	var existing_socket = socket_index.query_other(piece_socket.get_socket_position(), piece)
	
	if existing_socket != null:
		var is_existing_ground = existing_socket.piece.def.tags.has("ground")
		var is_current_ground = piece.def.tags.has("ground")
		
		# If both are ground, it's a real connection/overlap, so skip.
		# If both are non-ground, it's a real connection/overlap, so skip.
		if is_current_ground == is_existing_ground:
			return false
		
		# If one is ground and the other isn't, we allow it to proceed.
		# This allows ground to be generated under level pieces, and level pieces on ground.
		pass

	if distance > RENDER_RANGE:
		# Defer distant sockets back to queue for later processing when player moves closer
		queue.push(piece_socket, distance)
		return false

	var origin_world: Vector3 = piece_socket.get_socket_position()
	var size: String = "point"
	if socket_name in piece.def.socket_size:
		var size_prob_dist: Distribution = piece.def.socket_size[socket_name]
		size = size_prob_dist.sample()

	var adjacent := get_adjacent_from_size(piece_socket, size)

	# Check for forbidden areas (adjacent sockets with fill_prob <= 0)
	var attachment_socket_name = Helper.get_attachment_socket_name(socket_name)
	var required_tags: TagList
	var filtered: TerrainModuleList
	var dist: Distribution
	var fill_prob: float

	var found_valid_adjacency := false
	for adj_socket_name in adjacent.keys():
		if adj_socket_name == attachment_socket_name:
			continue  # Skip the attachment socket
		var hit = adjacent[adj_socket_name]
		if hit != null:
			var adjacent_fill_prob: float = float(hit.piece.def.socket_fill_prob.get(hit.socket_name, 0.0))
			if adjacent_fill_prob <= 0.0:
				# Forbidden area, skip this placement
				found_valid_adjacency = true
				required_tags = TagList.new()
				filtered = TerrainModuleList.new()
				dist = Distribution.new()
				fill_prob = 0.0
				break

	if not found_valid_adjacency:
		# Try different rotations of adjacency until we find one that works
		var current_adjacent = adjacent.duplicate()
		var current_attachment_socket_name = attachment_socket_name
		for rotation_attempt in range(4):  # Try up to 4 rotations
			required_tags = library.get_required_tags(current_adjacent, current_attachment_socket_name)
			required_tags.append(size) # only find pieces with the given size
			filtered = library.get_by_tags(required_tags)

			if !filtered.is_empty():
				# Found valid results with this adjacency
				var dist_raw: Distribution = library.get_combined_distribution(current_adjacent)
				dist = dist_raw.copy()
				var fill_prob_base: float = float(piece.def.socket_fill_prob.get(socket_name, 0.0))
				fill_prob = fill_prob_base
				found_valid_adjacency = true
				break

			# Rotate adjacency for next attempt
			current_adjacent = Helper.rotate_adjacency(current_adjacent)
			current_attachment_socket_name = Helper.rotate_socket_name(current_attachment_socket_name)

		if not found_valid_adjacency:
			# No valid adjacency found after all rotations
			required_tags = TagList.new()
			filtered = TerrainModuleList.new()
			dist = Distribution.new()
			fill_prob = 0.0

	if randf() > fill_prob:
		# Continue to next socket instead of stopping processing for this frame
		return false

	for attempt in range(4):
		var chosen_template: TerrainModule = library.sample_from_modules(filtered, dist)
		var chosen: TerrainModuleInstance = chosen_template.spawn()
		chosen.create()

		# Apply generation rules to the chosen piece
		var rule_context = {
			"size": size,
			"required_tags": required_tags,
			"socket_name": socket_name,
			"adjacent": adjacent,
			"chosen_piece": chosen,
			"filtered": filtered,
			"origin_world": origin_world,
			"terrain_index": terrain_index,
			"socket_index": socket_index,
			"queue": queue,
			"library": library,
			"rules_instance": generation_rules
		}

		# Apply all matching rules
		var applicable_rules = []
		for rule in generation_rules.rules:
			if rule.matches(rule_context):
				applicable_rules.append(rule)

		var final_piece = rule_context.get("chosen_piece", null)
		var all_pieces_to_remove = []
		var all_sockets_for_queue = []
		var should_skip = false

		for rule in applicable_rules:
			var rule_result = rule.apply(rule_context)

			if rule_result.get("skip", false):
				should_skip = true
				break

			var updated_piece = rule_result.get("updated_piece", null)
			if updated_piece != null:
				final_piece = updated_piece

			if rule_result.has("pieces_to_remove"):
				all_pieces_to_remove.append_array(rule_result.pieces_to_remove)

			if rule_result.has("sockets_for_queue"):
				all_sockets_for_queue.append_array(rule_result.sockets_for_queue)


		var rule_result = {
			"updated_piece": final_piece,
			"pieces_to_remove": all_pieces_to_remove,
			"sockets_for_queue": all_sockets_for_queue,
			"skip": should_skip
		}

		# Clean up the original piece if it was replaced
		if final_piece != chosen:
			chosen.destroy()

		if rule_result["skip"]:
			if final_piece != null:
				final_piece.destroy()
			break  # Successfully "handled" this attempt

		# Remove any pieces that rules requested to be removed (only instances; rules must not pass sockets)
		for piece_to_remove in rule_result["pieces_to_remove"]:
			if piece_to_remove is TerrainModuleInstance:
				remove_piece(piece_to_remove)

		# Re-queue specific sockets that rules requested
		for socket_to_queue in rule_result["sockets_for_queue"]:
			queue.push(socket_to_queue, 0)  # Priority will be recalculated when processed

		# Only place if we have a valid piece instance (rules may return updated_piece: null)
		if final_piece == null or not (final_piece is TerrainModuleInstance):
			continue

		var new_piece_socket: TerrainModuleSocket = TerrainModuleSocket.new(final_piece, attachment_socket_name)
		var placed := add_piece(new_piece_socket, piece_socket)
		if placed:
			return true  # Successfully placed
		else:
			final_piece.destroy()

	return false  # No successful placement


func get_dist_from_player(piece: TerrainModuleInstance, socket_name: String) -> float:
	var socket: Marker3D = piece.sockets[socket_name]
	var socket_world_pos := Helper.socket_world_pos(piece.transform, socket, piece.root)
	return (socket_world_pos - player.global_position).length()


func add_piece_to_queue(piece: TerrainModuleInstance) -> void:
	for socket_name: String in piece.sockets.keys():
		var fill_prob = float(piece.def.socket_fill_prob.get(socket_name, 0.0))
		if fill_prob <= 0.0:
			continue
		var socket: Marker3D = piece.sockets[socket_name]
		var pos := Helper.socket_world_pos(piece.transform, socket, piece.root)
		# If this socket is already connected (another piece has a socket here), don't enqueue it.
		# Exception: Ground pieces are allowed to overlap with non-ground pieces' sockets.
		var existing_socket = socket_index.query_other(pos, piece)
		if existing_socket != null:
			var is_existing_ground = existing_socket.piece.def.tags.has("ground")
			var is_current_ground = piece.def.tags.has("ground")
			if is_current_ground == is_existing_ground:
				continue
		var dist := get_dist_from_player(piece, socket_name)
		var item: TerrainModuleSocket = TerrainModuleSocket.new(piece, socket_name)
		queue.push(item, dist)


func register_piece(piece: TerrainModuleInstance, attachment_socket_name: String) -> void:
	for socket_name: String in piece.sockets.keys():
		# Index all sockets (including those with fill_prob = 0) so they can act as adjacency barriers
		# Skip only the attachment socket
		if socket_name != attachment_socket_name:
			var piece_other_socket: TerrainModuleSocket = TerrainModuleSocket.new(piece, socket_name)
			socket_index.insert(piece_other_socket)
	terrain_index.insert(piece)


func can_place(new_piece: TerrainModuleInstance, parent_piece: TerrainModuleInstance) -> bool:
	assert(new_piece.def != null)
	if new_piece.def.tags.has("ground"):
		return true
	if new_piece.def.replace_existing:
		return true
	var other_pieces: Array = terrain_index.query_box(new_piece.aabb)
	if parent_piece != null:
		other_pieces.erase(parent_piece)

	# Ignore collisions with ground pieces (they can overlap)
	other_pieces = other_pieces.filter(func(p): return not p.def.tags.has("ground"))

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
			var is_hit_ground = hit.piece.def.tags.has("ground")
			if orig_piece.def.tags.has("ground") and not is_hit_ground:
				# Ignore non-ground adjacency for ground pieces
				continue
				
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
	var can_place_result := can_place(new_piece, orig_piece_socket.piece)

	if not can_place_result:
		return false

		# If replace_existing is true, remove all overlapping pieces
		if new_piece.def.replace_existing:
			var overlapping_pieces: Array = terrain_index.query_box(new_piece.aabb)
			if orig_piece_socket.piece != null:
				overlapping_pieces.erase(orig_piece_socket.piece)
			# Don't remove ground pieces
			overlapping_pieces = overlapping_pieces.filter(func(p): return not p.def.tags.has("ground"))
			
			for piece in overlapping_pieces:
				remove_piece(piece)

	terrain_parent.add_child(new_piece.root)

	register_piece(new_piece, new_piece_socket.socket_name)
	add_piece_to_queue(new_piece)


	# Remove sockets that are now linked into from the queue
	remove_linked_sockets_from_queue(new_piece_socket)

	return true



# Removed ensure_ground_coverage_around_piece - using prioritized ground expansion instead


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
			# Only remove if they are the same layer (ground vs non-ground)
			var is_existing_ground = existing_socket.piece.def.tags.has("ground")
			var is_new_ground = new_piece.def.tags.has("ground")
			if is_existing_ground == is_new_ground:
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

	# For the start tile, we need to register it without an attachment point
	register_piece(initial_tile, "")

	return initial_tile
