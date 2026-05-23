class_name CliffEdgeRule
extends TerrainGenerationRule

const CARDINAL_SOCKETS: Array[String] = ["front", "right", "back", "left"]
const DIAGONAL_SOCKETS: Array[String] = ["frontright", "backright", "backleft", "frontleft"]
const SAME_LEVEL_EPS: float = 0.1

# Canonical missing-socket patterns for each cliff variant.
const CANONICAL_MISSING_BY_TAG: Dictionary[String, Array] = {
	"cliff-edge": ["front"],
	"cliff-outer-corner": ["front", "left"],
	"cliff-inner-corner": ["frontleft"],
	"cliff-inner-corner-diag": ["frontleft", "backright"],
}
# Order checked: most-constrained first (so inner-corner-diag with both diagonals
# wins over inner-corner with just one).
const CLIFF_TAG_ORDER: Array[String] = [
	"cliff-inner-corner-diag",
	"cliff-inner-corner",
	"cliff-outer-corner",
	"cliff-edge",
]
const INNER_CORNER_CARDINALS_BY_DIAGONAL: Dictionary[String, Array] = {
	"frontleft": ["front", "left"],
	"frontright": ["front", "right"],
	"backright": ["back", "right"],
	"backleft": ["back", "left"]
}

static var module_by_cliff_tag: Dictionary = {}


func matches(context: Dictionary) -> bool:
	if not context.has("chosen_piece"):
		return false
	var chosen_piece: TerrainModuleInstance = context["chosen_piece"]
	if chosen_piece == null:
		return false
	return chosen_piece.def.tags.has("cliff")


func apply(context: Dictionary) -> Dictionary:
	# Stub for now; filled in over the next tasks.
	return {"chosen_piece": context.get("chosen_piece", null), "piece_updates": {}}
