class_name LevelContradictionRule
extends TerrainGenerationRule

# Detect contradictions when placing a piece (level tiles: fillable vs blocked sockets)
static func has_contradictions(piece: TerrainModuleInstance, _attachment_socket_name: String, _socket_index: PositionIndex, rule_context: Dictionary = {}) -> bool:
	if piece.def.tags.has("level"):
		print("LEVEL_DEBUG: Checking contradictions for ", piece.def.tags.tags, " attachment: ", _attachment_socket_name)

	if rule_context.has("adjacent") and piece.def.tags.has("level"):
		var adjacent = rule_context["adjacent"] as Dictionary
		for adj_socket_name in adjacent.keys():
			var adj_socket: TerrainModuleSocket = adjacent[adj_socket_name]
			if adj_socket != null and adj_socket.piece.def.tags.has("level"):
				var piece_fill_prob = float(piece.def.socket_fill_prob.get(adj_socket_name, 0.0))
				var adj_fill_prob = float(adj_socket.piece.def.socket_fill_prob.get(Helper.get_attachment_socket_name(adj_socket_name), 0.0))

				if piece_fill_prob <= 0.0 and adj_fill_prob > 0.0:
					print("LEVEL_DEBUG: FOUND Contradiction - ", piece.def.tags.tags, " blocked socket ", adj_socket_name, " (fill_prob=", piece_fill_prob, ") adjacent to fillable socket on ", adj_socket.piece.def.tags.tags, " (fill_prob=", adj_fill_prob, ")")
					return true

	return false


# Find neighbors that are causing contradictions with the given piece
static func find_conflicting_neighbors(piece: TerrainModuleInstance, attachment_socket_name: String, socket_index: PositionIndex) -> Array:
	var conflicting = []

	for socket_name in piece.sockets.keys():
		if socket_name == attachment_socket_name:
			continue

		var fill_prob = float(piece.def.socket_fill_prob.get(socket_name, 0.0))
		if fill_prob <= 0.0:
			continue

		var socket_pos = Helper.socket_world_pos(piece.transform, piece.sockets[socket_name], piece.root)
		var adjacent_socket = socket_index.query_other(socket_pos, piece)
		if adjacent_socket != null:
			var adjacent_fill_prob = float(adjacent_socket.piece.def.socket_fill_prob.get(adjacent_socket.socket_name, 0.0))
			if adjacent_fill_prob <= 0.0:
				if not conflicting.has(adjacent_socket.piece):
					conflicting.append(adjacent_socket.piece)

	for socket_name in piece.sockets.keys():
		if socket_name == attachment_socket_name:
			continue

		var fill_prob = float(piece.def.socket_fill_prob.get(socket_name, 0.0))
		if fill_prob > 0.0:
			continue

		var socket_pos = Helper.socket_world_pos(piece.transform, piece.sockets[socket_name], piece.root)
		var adjacent_socket = socket_index.query_other(socket_pos, piece)
		if adjacent_socket != null:
			var adjacent_fill_prob = float(adjacent_socket.piece.def.socket_fill_prob.get(adjacent_socket.socket_name, 0.0))
			if adjacent_fill_prob > 0.0:
				if not conflicting.has(adjacent_socket.piece):
					conflicting.append(adjacent_socket.piece)

	return conflicting


func matches(context: Dictionary) -> bool:
	var has_level = context.has("chosen_piece") and context.chosen_piece != null and context.chosen_piece.def.tags.has("level")
	return has_level


func apply(context: Dictionary) -> Dictionary:
	if not context.has("chosen_piece") or not context.has("filtered") or not context.has("socket_name") or not context.has("adjacent") or not context.has("socket_index"):
		return {"updated_piece": context.get("chosen_piece", null)}

	var chosen_piece = context.chosen_piece
	var attachment_socket_name = Helper.get_attachment_socket_name(context.socket_name)
	var socket_index = context.socket_index

	print("DEBUG: Level rule triggered for piece ", chosen_piece.def.tags.tags, " at socket ", context.socket_name)

	var contradiction_context = {
		"adjacent": context.get("adjacent", {}),
		"socket_name": context.get("socket_name", "")
	}
	if not has_contradictions(chosen_piece, attachment_socket_name, socket_index, contradiction_context):
		print("DEBUG: No contradictions detected for ", chosen_piece.def.tags.tags)
		return {"updated_piece": chosen_piece}

	print("DEBUG: Contradictions detected for ", chosen_piece.def.tags.tags, " - trying alternatives")

	var filtered = context.filtered
	for i in range(filtered.size()):
		var alternative_template = filtered.get_at_index(i)
		if alternative_template == chosen_piece.def:
			continue

		var alternative_piece = alternative_template.spawn()
		alternative_piece.create()

		if not has_contradictions(alternative_piece, attachment_socket_name, socket_index, contradiction_context):
			print("DEBUG: Found alternative piece ", alternative_template.tags.tags, " without contradictions")
			chosen_piece.destroy()
			return {"updated_piece": alternative_piece}

		alternative_piece.destroy()

	print("DEBUG: No alternatives found, checking for conflicting neighbors")

	var conflicting_pieces = find_conflicting_neighbors(chosen_piece, attachment_socket_name, socket_index)
	if not conflicting_pieces.is_empty():
		print("DEBUG: Found ", conflicting_pieces.size(), " conflicting neighbors to remove")
		chosen_piece.destroy()
		var sockets_to_requeue = []
		for piece in conflicting_pieces:
			for socket_name in piece.sockets.keys():
				var socket = TerrainModuleSocket.new(piece, socket_name)
				sockets_to_requeue.append(socket)
		return {
			"pieces_to_remove": conflicting_pieces,
			"sockets_for_queue": sockets_to_requeue,
			"updated_piece": null
		}

	print("DEBUG: No conflicting neighbors found, skipping placement")
	chosen_piece.destroy()
	return {"skip": true}
