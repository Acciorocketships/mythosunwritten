class_name TerrainGenerationRule
extends Resource

# Base class for terrain generation rules
# Rules should override matches() and apply() methods

func matches(context: Dictionary) -> bool:
	# Override this to return true when the rule should be applied
	# context contains: chosen_piece, filtered, socket_name, adjacent, socket_index, etc.
	return false

func apply(context: Dictionary) -> Dictionary:
	# Override this to implement the rule logic
	# Return dictionary with: "updated_piece", "pieces_to_remove", "sockets_for_queue", "skip"
	return {"updated_piece": context.get("chosen_piece", null)}
