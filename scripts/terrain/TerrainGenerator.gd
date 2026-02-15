extends Node3D

@export var RENDER_RANGE: int = 250
@export var MAX_LOAD_PER_STEP: int = 8

@export var player: Node3D
@export var terrain_parent: Node

var generation_rules: TerrainGenerationRuleLibrary
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
	generation_rules = TerrainGenerationRuleLibrary.new()

	var start_tile := load_start_tile()
	queue = PriorityQueue.new()
	# Register the start tile in indices so collision checks work and adjacency can be detected
	# Sockets are indexed so they can act as adjacency barriers.
	register_piece(start_tile, "")
	for socket_name in start_tile.sockets.keys():
		var piece_socket: TerrainModuleSocket = TerrainModuleSocket.new(start_tile, socket_name)
		if not _is_socket_expandable(piece_socket):
			continue
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
		var distance := get_dist_from_player(piece, socket_name)

		num_processed += 1

		var added: bool = _process_socket(piece_socket, distance)
		if added:
			num_added += 1


func _process_socket(piece_socket: TerrainModuleSocket, distance: float) -> bool:
	if _is_socket_connected(piece_socket):
		return false
	if _defer_if_out_of_range(piece_socket, distance):
		return false
	if not _passes_fill_prob_roll(piece_socket):
		return false

	var size: String = _sample_socket_size(piece_socket.piece, piece_socket.socket_name)
	var placement_context: Dictionary = _resolve_placement_context(piece_socket, size)
	return _try_place_with_rules(piece_socket, placement_context)


func _is_socket_connected(piece_socket: TerrainModuleSocket) -> bool:
	var existing_socket: TerrainModuleSocket = socket_index.query_other(piece_socket.get_socket_position(), piece_socket.piece)
	return existing_socket != null and _sockets_same_layer(piece_socket, existing_socket)


func _sockets_same_layer(a: TerrainModuleSocket, b: TerrainModuleSocket) -> bool:
	if a == null or b == null:
		return false
	var a_is_ground: bool = a.piece.def.tags.has("ground")
	var b_is_ground: bool = b.piece.def.tags.has("ground")
	return a_is_ground == b_is_ground


func _defer_if_out_of_range(piece_socket: TerrainModuleSocket, distance: float) -> bool:
	if distance <= RENDER_RANGE:
		return false
	queue.push(piece_socket, distance)
	return true


func _sample_socket_size(piece: TerrainModuleInstance, socket_name: String) -> String:
	if not piece.def.socket_size.has(socket_name):
		return "point"
	var size_prob_dist: Distribution = piece.def.socket_size[socket_name]
	return size_prob_dist.sample()


func _get_socket_fill_prob(piece: TerrainModuleInstance, socket_name: String) -> float:
	return float(piece.def.socket_fill_prob.get(socket_name, 0.0))


func _is_socket_expandable(piece_socket: TerrainModuleSocket) -> bool:
	return _get_socket_fill_prob(piece_socket.piece, piece_socket.socket_name) > 0.0


func _passes_fill_prob_roll(piece_socket: TerrainModuleSocket) -> bool:
	var fill_prob: float = _get_socket_fill_prob(piece_socket.piece, piece_socket.socket_name)
	return fill_prob > 0.0 and randf() <= fill_prob


func _resolve_placement_context(piece_socket: TerrainModuleSocket, size: String) -> Dictionary:
	var socket_name: String = piece_socket.socket_name
	var adjacent: Dictionary[String, TerrainModuleSocket] = get_adjacent_from_size(piece_socket, size)
	var attachment_socket_name: String = Helper.get_attachment_socket_name(socket_name)
	var origin_world: Vector3 = piece_socket.get_socket_position()

	if _has_forbidden_adjacency(adjacent):
		return _empty_placement_context(size, adjacent, attachment_socket_name, origin_world)

	var rotated_adjacent: Dictionary = adjacent.duplicate()
	var rotated_attachment_socket: String = attachment_socket_name
	for _rotation_attempt in range(4):
		var required_tags: TagList = library.get_required_tags(rotated_adjacent, rotated_attachment_socket)
		required_tags.append(size)
		var filtered: TerrainModuleList = library.get_by_tags(required_tags)
		if not filtered.is_empty():
			return {
				"size": size,
				"adjacent": rotated_adjacent,
				"attachment_socket_name": rotated_attachment_socket,
				"required_tags": required_tags,
				"filtered": filtered,
				"dist": library.get_combined_distribution(rotated_adjacent).copy(),
				"origin_world": origin_world
			}
		rotated_adjacent = Helper.rotate_adjacency(rotated_adjacent)
		rotated_attachment_socket = Helper.rotate_socket_name(rotated_attachment_socket)

	return _empty_placement_context(size, adjacent, attachment_socket_name, origin_world)


func _empty_placement_context(
	size: String,
	adjacent: Dictionary[String, TerrainModuleSocket],
	attachment_socket_name: String,
	origin_world: Vector3
) -> Dictionary:
	return {
		"size": size,
		"adjacent": adjacent,
		"attachment_socket_name": attachment_socket_name,
		"required_tags": TagList.new(),
		"filtered": TerrainModuleList.new(),
		"dist": Distribution.new(),
		"origin_world": origin_world
	}


func _has_forbidden_adjacency(adjacent: Dictionary[String, TerrainModuleSocket]) -> bool:
	for hit in adjacent.values():
		if hit == null:
			continue
		if not _is_socket_expandable(hit):
			return true
	return false


func _try_place_with_rules(orig_piece_socket: TerrainModuleSocket, placement_context: Dictionary) -> bool:
	var filtered: TerrainModuleList = placement_context.get("filtered", TerrainModuleList.new())
	var dist: Distribution = placement_context.get("dist", Distribution.new())
	var attachment_socket_name: String = placement_context.get("attachment_socket_name", "bottom")
	if filtered.is_empty():
		return false

	for _attempt in range(4):
		var chosen_template: TerrainModule = library.sample_from_modules(filtered, dist)
		var chosen: TerrainModuleInstance = chosen_template.spawn()
		chosen.create()
		var rule_context: Dictionary = _build_rule_context(orig_piece_socket, placement_context, chosen, filtered)
		var rule_result: Dictionary = _apply_generation_rules(rule_context, chosen)
		if rule_result.get("skip", false):
			var skipped_piece = rule_result.get("updated_piece", null)
			if skipped_piece != null:
				skipped_piece.destroy()
			break

		for piece_to_remove in rule_result.get("pieces_to_remove", []):
			if piece_to_remove is TerrainModuleInstance:
				remove_piece(piece_to_remove)
		for socket_to_queue in rule_result.get("sockets_for_queue", []):
			queue.push(socket_to_queue, 0)

		var final_piece: TerrainModuleInstance = rule_result.get("updated_piece", null)
		if final_piece == null or not (final_piece is TerrainModuleInstance):
			continue
		var new_piece_socket: TerrainModuleSocket = TerrainModuleSocket.new(final_piece, attachment_socket_name)
		if add_piece(new_piece_socket, orig_piece_socket):
			return true
		final_piece.destroy()
	return false


func _build_rule_context(
	orig_piece_socket: TerrainModuleSocket,
	placement_context: Dictionary,
	chosen_piece: TerrainModuleInstance,
	filtered: TerrainModuleList
) -> Dictionary:
	return {
		"size": placement_context.get("size", "point"),
		"required_tags": placement_context.get("required_tags", TagList.new()),
		"socket_name": orig_piece_socket.socket_name,
		"adjacent": placement_context.get("adjacent", {}),
		"chosen_piece": chosen_piece,
		"filtered": filtered,
		"origin_world": placement_context.get("origin_world", orig_piece_socket.get_socket_position()),
		"terrain_index": terrain_index,
		"socket_index": socket_index,
		"queue": queue,
		"library": library,
		"rules_instance": generation_rules
	}


func _apply_generation_rules(rule_context: Dictionary, chosen_piece: TerrainModuleInstance) -> Dictionary:
	var final_piece: TerrainModuleInstance = rule_context.get("chosen_piece", null)
	var all_pieces_to_remove: Array = []
	var all_sockets_for_queue: Array = []
	var should_skip: bool = false
	for rule in generation_rules.rules:
		if not rule.matches(rule_context):
			continue
		var step_result: Dictionary = rule.apply(rule_context)
		if step_result.get("skip", false):
			should_skip = true
			break
		var updated_piece = step_result.get("updated_piece", null)
		if updated_piece != null:
			final_piece = updated_piece
		if step_result.has("pieces_to_remove"):
			all_pieces_to_remove.append_array(step_result.pieces_to_remove)
		if step_result.has("sockets_for_queue"):
			all_sockets_for_queue.append_array(step_result.sockets_for_queue)

	if final_piece != chosen_piece:
		chosen_piece.destroy()
	return {
		"updated_piece": final_piece,
		"pieces_to_remove": all_pieces_to_remove,
		"sockets_for_queue": all_sockets_for_queue,
		"skip": should_skip
	}


func get_dist_from_player(piece: TerrainModuleInstance, socket_name: String) -> float:
	var socket: Marker3D = piece.sockets[socket_name]
	var socket_world_pos := Helper.socket_world_pos(piece.transform, socket, piece.root)
	return (socket_world_pos - player.global_position).length()


func add_piece_to_queue(piece: TerrainModuleInstance) -> void:
	for socket_name: String in piece.sockets.keys():
		var current_socket: TerrainModuleSocket = TerrainModuleSocket.new(piece, socket_name)
		if not _is_socket_expandable(current_socket):
			continue
		var socket: Marker3D = piece.sockets[socket_name]
		var pos := Helper.socket_world_pos(piece.transform, socket, piece.root)
		var existing_socket: TerrainModuleSocket = socket_index.query_other(pos, piece)
		if existing_socket != null and _sockets_same_layer(current_socket, existing_socket):
				continue
		var dist := get_dist_from_player(piece, socket_name)
		queue.push(current_socket, dist)


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
	terrain_index.remove(piece)
	socket_index.remove_piece(piece)
	queue.remove_where(func(item): return item is TerrainModuleSocket and item.piece == piece)
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
	if new_piece.def.replace_existing:
		var overlapping_pieces: Array = terrain_index.query_box(new_piece.aabb)
		if orig_piece_socket.piece != null:
			overlapping_pieces.erase(orig_piece_socket.piece)
		overlapping_pieces = overlapping_pieces.filter(func(p): return not p.def.tags.has("ground"))
		for piece in overlapping_pieces:
			remove_piece(piece)

	var can_place_result := can_place(new_piece, orig_piece_socket.piece)

	if not can_place_result:
		return false

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
			var new_socket: TerrainModuleSocket = TerrainModuleSocket.new(new_piece, socket_name)
			if _sockets_same_layer(new_socket, existing_socket):
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
	return initial_tile
