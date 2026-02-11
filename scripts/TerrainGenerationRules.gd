class_name TerrainGenerationRules
extends Resource

# Array of TerrainGenerationRule instances
@export var rules: Array[TerrainGenerationRule] = []


func _init() -> void:
	# Initialize with default rules
	rules.append(create_level_contradiction_rule())


# Helper function to detect contradictions when placing a piece
func has_contradictions(piece: TerrainModuleInstance, attachment_socket_name: String, socket_index: PositionIndex, rule_context: Dictionary = {}) -> bool:
	# Check if placing this piece would create contradictions
	# Use estimated positions based on the attachment

	if piece.def.tags.has("level"):
		print("LEVEL_DEBUG: Checking contradictions for ", piece.def.tags.tags, " attachment: ", attachment_socket_name)

	# If we have context with adjacent pieces, use a simpler check
	if rule_context.has("adjacent") and piece.def.tags.has("level"):
		var adjacent = rule_context["adjacent"] as Dictionary
		for adj_socket_name in adjacent.keys():
			var adj_piece = adjacent[adj_socket_name]
			if adj_piece != null and adj_piece.def.tags.has("level"):
				# Two level tiles adjacent - check for blocked edge conflicts
				var piece_fill_prob = float(piece.def.socket_fill_prob.get(adj_socket_name, 0.0))
				var adj_fill_prob = float(adj_piece.def.socket_fill_prob.get(Helper.get_attachment_socket_name(adj_socket_name), 0.0))

				if piece_fill_prob <= 0.0 and adj_fill_prob > 0.0:
					print("LEVEL_DEBUG: FOUND Contradiction - ", piece.def.tags.tags, " blocked socket ", adj_socket_name, " (fill_prob=", piece_fill_prob, ") adjacent to fillable socket on ", adj_piece.def.tags.tags, " (fill_prob=", adj_fill_prob, ")")
					return true

	return false


# Find neighbors that are causing contradictions with the given piece
func find_conflicting_neighbors(piece: TerrainModuleInstance, attachment_socket_name: String, socket_index: PositionIndex) -> Array:
	var conflicting = []

	# Check Type 1 contradictions: piece has socket that must be filled but adjacent cannot be filled
	for socket_name in piece.sockets.keys():
		if socket_name == attachment_socket_name:
			continue

		var fill_prob = float(piece.def.socket_fill_prob.get(socket_name, 0.0))
		if fill_prob <= 0.0:
			continue  # This socket doesn't need to be filled

		var socket_pos = Helper.socket_world_pos(piece.transform, piece.sockets[socket_name], piece.root)
		var adjacent_socket = socket_index.query_other(socket_pos, piece)
		if adjacent_socket != null:
			var adjacent_fill_prob = float(adjacent_socket.piece.def.socket_fill_prob.get(adjacent_socket.socket_name, 0.0))
			if adjacent_fill_prob <= 0.0:
				# This neighbor is blocking a socket that must be filled
				if not conflicting.has(adjacent_socket.piece):
					conflicting.append(adjacent_socket.piece)

	# Check Type 2 contradictions: piece has socket that cannot be filled but adjacent must be filled
	for socket_name in piece.sockets.keys():
		if socket_name == attachment_socket_name:
			continue

		var fill_prob = float(piece.def.socket_fill_prob.get(socket_name, 0.0))
		if fill_prob > 0.0:
			continue  # This socket can be filled, so it doesn't block

		var socket_pos = Helper.socket_world_pos(piece.transform, piece.sockets[socket_name], piece.root)
		var adjacent_socket = socket_index.query_other(socket_pos, piece)
		if adjacent_socket != null:
			var adjacent_fill_prob = float(adjacent_socket.piece.def.socket_fill_prob.get(adjacent_socket.socket_name, 0.0))
			if adjacent_fill_prob > 0.0:
				# Adjacent piece requires this position to be filled, but this piece blocks it
				if not conflicting.has(adjacent_socket.piece):
					conflicting.append(adjacent_socket.piece)

	return conflicting

# Terrain generation rule for level pieces that avoids contradictions
class LevelContradictionRule:
	extends TerrainGenerationRule
	
	func matches(context: Dictionary) -> bool:
		var has_level = context.has("chosen_piece") and context.chosen_piece != null and context.chosen_piece.def.tags.has("level")
		return has_level
	
	func apply(context: Dictionary) -> Dictionary:
		if not context.has("chosen_piece") or not context.has("filtered") or not context.has("socket_name") or not context.has("adjacent") or not context.has("socket_index") or not context.has("rules_instance"):
			return {"updated_piece": context.get("chosen_piece", null)}  # Defensive: pass through if context is incomplete

		var rules_instance = context.rules_instance
		var chosen_piece = context.chosen_piece
		var attachment_socket_name = Helper.get_attachment_socket_name(context.socket_name)
		var socket_index = context.socket_index

		print("DEBUG: Level rule triggered for piece ", chosen_piece.def.tags.tags, " at socket ", context.socket_name)

		# First check if the chosen piece creates contradictions
		var contradiction_context = {
			"adjacent": context.get("adjacent", {}),
			"socket_name": context.get("socket_name", "")
		}
		if not rules_instance.has_contradictions(chosen_piece, attachment_socket_name, socket_index, contradiction_context):
			print("DEBUG: No contradictions detected for ", chosen_piece.def.tags.tags)
			return {"updated_piece": chosen_piece}  # No contradictions, use this piece

		print("DEBUG: Contradictions detected for ", chosen_piece.def.tags.tags, " - trying alternatives")

		# Try other pieces from the filtered list
		var filtered = context.filtered
		for i in range(filtered.size()):
			var alternative_template = filtered.get_at_index(i)
			if alternative_template == chosen_piece.def:
				continue  # Skip the one we already tried

			var alternative_piece = alternative_template.spawn()
			alternative_piece.create()

			if not rules_instance.has_contradictions(alternative_piece, attachment_socket_name, socket_index, contradiction_context):
				# Found a piece that doesn't create contradictions
				print("DEBUG: Found alternative piece ", alternative_template.tags.tags, " without contradictions")
				chosen_piece.destroy()  # Clean up the original
				return {"updated_piece": alternative_piece}

			alternative_piece.destroy()  # Clean up this attempt

		print("DEBUG: No alternatives found, checking for conflicting neighbors")

		# No alternative pieces work, need to remove conflicting neighbors
		var conflicting_pieces = rules_instance.find_conflicting_neighbors(chosen_piece, attachment_socket_name, socket_index)
		if not conflicting_pieces.is_empty():
			print("DEBUG: Found ", conflicting_pieces.size(), " conflicting neighbors to remove")
			chosen_piece.destroy()  # Don't place the problematic piece
			var sockets_to_requeue = []
			for piece in conflicting_pieces:
				for socket_name in piece.sockets.keys():
					var socket = TerrainModuleSocket.new(piece, socket_name)
					sockets_to_requeue.append(socket)
			return {
				"pieces_to_remove": conflicting_pieces,
				"sockets_for_queue": sockets_to_requeue,
				"updated_piece": null  # Don't place anything this attempt
			}

		# No conflicts found or no pieces to remove, just skip this placement
		print("DEBUG: No conflicting neighbors found, skipping placement")
		chosen_piece.destroy()
		return {"skip": true}


func create_level_contradiction_rule() -> TerrainGenerationRule:
	return LevelContradictionRule.new()
