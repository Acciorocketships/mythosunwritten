class_name TerrainGenerationRule
extends Resource

# Base class for terrain generation rules
# Rules should override matches() and apply() methods

func matches(_context: Dictionary) -> bool:
	# Override this to return true when the rule should be applied
	# context contains: chosen_piece, filtered, socket_name, adjacent, socket_index, etc.
	return false

func apply(_context: Dictionary) -> Dictionary:
	# Override this to implement the rule logic
	# Return dictionary may include:
	# - "chosen_piece": replacement for context.chosen_piece
	# - "piece_updates": Dictionary[TerrainModuleInstance, TerrainModuleInstance|Nil]
	#     key = piece to update, value = replacement piece or null to remove
	# - "sockets_for_queue": Array[TerrainModuleSocket]
	# - "skip": bool
	return {
		"chosen_piece": _context.get("chosen_piece", null),
		"piece_updates": {},
		"sockets_for_queue": [],
		"skip": false
	}
