class_name LevelEdgeRule
extends TerrainGenerationRule

const TOPCENTER_FILL_PROB: float = 0.95
const CARDINAL_SOCKETS: Array[String] = ["front", "right", "back", "left"]
const DIAGONAL_SOCKETS: Array[String] = ["frontright", "backright", "backleft", "frontleft"]
const SAME_LEVEL_EPS: float = 0.1

const CANONICAL_MISSING_BY_TAG: Dictionary[String, Array] = {
	"level-center": [],
	"level-side": ["front"],
	"level-line": ["front", "back"],
	"level-corner": ["front", "left"],
	"level-peninsula": ["front", "left", "right"],
	"level-island": ["front", "right", "back", "left"],
	"level-inner-corner": ["frontleft"],
	"level-inner-corner-diag": ["frontleft", "backright"],
	"level-inner-corner-side": ["frontleft", "backleft"],
	"level-inner-corner-edge1": ["frontleft", "back"],
	"level-inner-corner-edge2": ["frontleft", "right"],
	"level-inner-corner-edge-both": ["frontleft", "back", "right"],
	"level-inner-corner-side-edge": ["frontleft", "backleft", "right"],
	"level-inner-corner-three": ["frontleft", "backleft", "backright"],
	"level-inner-corner-all": ["frontright", "backright", "backleft", "frontleft"]
}
const INNER_CORNER_CARDINALS_BY_DIAGONAL: Dictionary[String, Array] = {
	"frontleft": ["front", "left"],
	"frontright": ["front", "right"],
	"backright": ["back", "right"],
	"backleft": ["back", "left"]
}
const LEVEL_TAG_ORDER: Array[String] = [
	"level-center",
	"level-side",
	"level-line",
	"level-corner",
	"level-peninsula",
	"level-island",
	"level-inner-corner",
	"level-inner-corner-diag",
	"level-inner-corner-side",
	"level-inner-corner-edge1",
	"level-inner-corner-edge2",
	"level-inner-corner-edge-both",
	"level-inner-corner-side-edge",
	"level-inner-corner-three",
	"level-inner-corner-all"
]
static var module_by_level_tag: Dictionary = {}

func matches(context: Dictionary) -> bool:
	if not context.has("chosen_piece"):
		return false
	var chosen_piece: TerrainModuleInstance = context["chosen_piece"]
	if chosen_piece == null:
		return false
	return chosen_piece.def.tags.has("level")


func apply(context: Dictionary) -> Dictionary:
	if (
		not context.has("chosen_piece")
		or not context.has("socket_index")
		or not context.has("terrain_index")
	):
		return {"chosen_piece": context.get("chosen_piece", null), "piece_updates": {}}

	var chosen_piece: TerrainModuleInstance = context["chosen_piece"]
	var socket_index: PositionIndex = context["socket_index"]
	var terrain_index: TerrainIndex = context["terrain_index"]
	var piece_updates: Dictionary = {}
	var affected: Array[TerrainModuleInstance] = []
	var seen: Dictionary = {}
	_add_unique_piece(affected, seen, chosen_piece)
	var direct_neighbors: Array[TerrainModuleInstance] = _get_level_neighbors(
		chosen_piece,
		socket_index,
		terrain_index
	)
	for neighbor_piece in direct_neighbors:
		_add_unique_piece(affected, seen, neighbor_piece)
	for neighbor_piece in direct_neighbors:
		var neighbor_neighbors: Array[TerrainModuleInstance] = _get_level_neighbors(
			neighbor_piece,
			socket_index,
			terrain_index
		)
		for indirect_neighbor in neighbor_neighbors:
			_add_unique_piece(affected, seen, indirect_neighbor)
	var chosen_replacement: TerrainModuleInstance = chosen_piece
	var sockets_for_queue: Array[TerrainModuleSocket] = []
	for affected_piece in affected:
		var had_topcenter_override: bool = affected_piece.socket_fill_prob_override.has("topcenter")
		var missing: Array[String] = _missing_sockets_for_piece(
			affected_piece,
			socket_index,
			terrain_index
		)
		var target_tag: String = _tag_for_missing_sockets(missing)
		var stacked: TerrainModuleInstance = _get_stacked_piece(affected_piece, socket_index)
		if stacked != null and not _can_support_stacked_piece(affected_piece, socket_index):
			piece_updates[stacked] = null
		var steps_to_align: int = _rotation_steps_to_align_canonical(target_tag, missing)
		var replacement: TerrainModuleInstance = _create_replacement_for_target(
			affected_piece,
			target_tag,
			steps_to_align
		)
		if affected_piece == chosen_piece:
			chosen_replacement = replacement
		else:
			piece_updates[affected_piece] = replacement
		if (
			replacement == affected_piece
			and not had_topcenter_override
			and affected_piece.socket_fill_prob_override.has("topcenter")
			and affected_piece.sockets.has("topcenter")
		):
			sockets_for_queue.append(TerrainModuleSocket.new(affected_piece, "topcenter"))
	return {"chosen_piece": chosen_replacement, "piece_updates": piece_updates, "sockets_for_queue": sockets_for_queue}


func _is_stacked_support(piece: TerrainModuleInstance, socket_index: PositionIndex) -> bool:
	if piece == null:
		return false
	return _has_level_connection(piece, "topcenter", socket_index)


func _can_support_stacked_piece(piece: TerrainModuleInstance, socket_index: PositionIndex) -> bool:
	if piece == null:
		return false
	return _get_stacked_piece(piece, socket_index) != null and _has_all_cardinal_level_neighbors(piece, socket_index)


func _has_all_cardinal_level_neighbors(
	piece: TerrainModuleInstance,
	socket_index: PositionIndex
) -> bool:
	for socket_name in CARDINAL_SOCKETS:
		if not _has_level_connection(piece, socket_name, socket_index):
			return false
	return true


func _get_stacked_piece(
	piece: TerrainModuleInstance, socket_index: PositionIndex
) -> TerrainModuleInstance:
	if piece == null or not piece.sockets.has("topcenter"):
		return null
	var piece_socket: TerrainModuleSocket = TerrainModuleSocket.new(piece, "topcenter")
	var other: TerrainModuleSocket = socket_index.query_other(
		piece_socket.get_socket_position(),
		piece
	)
	if other == null or other.piece == null:
		return null
	if not other.piece.def.tags.has("level"):
		return null
	if not _is_same_height(other.piece.transform.origin.y, piece.transform.origin.y + 1.0):
		return null
	return other.piece


func _current_level_tag(module_def: TerrainModule) -> String:
	if module_def == null:
		return ""
	for level_tag in LEVEL_TAG_ORDER:
		if module_def.tags.has(level_tag):
			return level_tag
	return ""


func _add_unique_piece(
	pieces: Array[TerrainModuleInstance],
	seen: Dictionary,
	piece: TerrainModuleInstance
) -> void:
	if piece == null:
		return
	if seen.has(piece):
		return
	seen[piece] = true
	pieces.append(piece)


func _missing_sockets_for_piece(
	piece: TerrainModuleInstance,
	socket_index: PositionIndex,
	terrain_index: TerrainIndex
) -> Array[String]:
	var missing_cardinals: Array[String] = []
	var connected_cardinals: Dictionary[String, bool] = {}
	for socket_name in CARDINAL_SOCKETS:
		var connected: bool = _has_level_connection(piece, socket_name, socket_index)
		connected_cardinals[socket_name] = connected
		if not connected:
			missing_cardinals.append(socket_name)
	var missing_inner_diagonals: Array[String] = []
	for socket_name in DIAGONAL_SOCKETS:
		var required_cardinals: Array = INNER_CORNER_CARDINALS_BY_DIAGONAL.get(socket_name, [])
		if required_cardinals.size() != 2:
			continue
		var first_cardinal: String = required_cardinals[0]
		var second_cardinal: String = required_cardinals[1]
		if not connected_cardinals.get(first_cardinal, false):
			continue
		if not connected_cardinals.get(second_cardinal, false):
			continue
		if _has_diagonal_level_neighbor(piece, socket_name, terrain_index):
			continue
		missing_inner_diagonals.append(socket_name)
	return missing_cardinals + missing_inner_diagonals


func _has_level_connection(
	piece: TerrainModuleInstance,
	socket_name: String,
	socket_index: PositionIndex
) -> bool:
	if not piece.sockets.has(socket_name):
		return false
	var piece_socket: TerrainModuleSocket = TerrainModuleSocket.new(piece, socket_name)
	var other: TerrainModuleSocket = socket_index.query_other(
		piece_socket.get_socket_position(),
		piece
	)
	return (
		other != null
		and other.piece != null
		and other.piece.def.tags.has("level")
	)


func _get_level_neighbors(
	piece: TerrainModuleInstance,
	socket_index: PositionIndex,
	terrain_index: TerrainIndex
) -> Array[TerrainModuleInstance]:
	var neighbors: Array[TerrainModuleInstance] = []
	var seen: Dictionary = {}
	for socket_name in CARDINAL_SOCKETS:
		if not piece.sockets.has(socket_name):
			continue
		var piece_socket: TerrainModuleSocket = TerrainModuleSocket.new(piece, socket_name)
		var other: TerrainModuleSocket = socket_index.query_other(
			piece_socket.get_socket_position(),
			piece
		)
		if other == null or other.piece == null:
			continue
		if not other.piece.def.tags.has("level"):
			continue
		if seen.has(other.piece):
			continue
		seen[other.piece] = true
		neighbors.append(other.piece)
	for socket_name in DIAGONAL_SOCKETS:
		var diagonal_neighbor: TerrainModuleInstance = _get_diagonal_level_neighbor_piece(
			piece,
			socket_name,
			terrain_index
		)
		if diagonal_neighbor == null:
			continue
		if seen.has(diagonal_neighbor):
			continue
		seen[diagonal_neighbor] = true
		neighbors.append(diagonal_neighbor)
	return neighbors


func _has_diagonal_level_neighbor(
	piece: TerrainModuleInstance,
	diagonal_socket_name: String,
	terrain_index: TerrainIndex
) -> bool:
	return _get_diagonal_level_neighbor_piece(piece, diagonal_socket_name, terrain_index) != null


func _get_diagonal_level_neighbor_piece(
	piece: TerrainModuleInstance,
	diagonal_socket_name: String,
	terrain_index: TerrainIndex
) -> TerrainModuleInstance:
	var diagonal_target: Variant = _diagonal_target_center(piece, diagonal_socket_name)
	if not (diagonal_target is Vector3):
		return null
	var target_pos: Vector3 = diagonal_target
	var query_box: AABB = AABB(target_pos + Vector3(-0.6, -2.0, -0.6), Vector3(1.2, 4.0, 1.2))
	var hits: Array = terrain_index.query_box(query_box)
	for hit in hits:
		if not (hit is TerrainModuleInstance):
			continue
		var other: TerrainModuleInstance = hit
		if other == piece:
			continue
		if not other.def.tags.has("level"):
			continue
		if not _is_same_height(piece.transform.origin.y, other.transform.origin.y):
			continue
		var delta: Vector3 = other.transform.origin - target_pos
		if abs(delta.x) <= 0.6 and abs(delta.z) <= 0.6:
			return other
	return null


func _is_same_height(a: float, b: float) -> bool:
	return abs(a - b) <= SAME_LEVEL_EPS


func _diagonal_target_center(piece: TerrainModuleInstance, diagonal_socket_name: String) -> Variant:
	var required_cardinals: Array = INNER_CORNER_CARDINALS_BY_DIAGONAL.get(diagonal_socket_name, [])
	if required_cardinals.size() != 2:
		return null
	var first_cardinal: String = required_cardinals[0]
	var second_cardinal: String = required_cardinals[1]
	if not piece.sockets.has(first_cardinal) or not piece.sockets.has(second_cardinal):
		return null
	var center: Vector3 = piece.transform.origin
	var first_pos: Vector3 = TerrainModuleSocket.new(piece, first_cardinal).get_socket_position()
	var second_pos: Vector3 = TerrainModuleSocket.new(piece, second_cardinal).get_socket_position()
	var first_offset: Vector3 = first_pos - center
	var second_offset: Vector3 = second_pos - center
	return center + (first_offset + second_offset) * 2.0


## Replace piece with the correct level variant (center/side/corner/...) and rotate so its
## canonical "missing" edges align with this piece's actual missing sockets.
func _create_replacement_for_target(
	source_piece: TerrainModuleInstance,
	target_tag: String,
	steps_to_align: int
) -> TerrainModuleInstance:
	var existing_tag: String = _current_level_tag(source_piece.def)
	if existing_tag == target_tag and steps_to_align == 0:
		_apply_topcenter_override(source_piece, target_tag)
		return source_piece
	var module_template: TerrainModule = _get_module_for_level_tag(
		target_tag,
		_level_tier_tag(source_piece.def)
	)
	if module_template == null:
		return source_piece
	if module_template == source_piece.def and steps_to_align == 0:
		_apply_topcenter_override(source_piece, target_tag)
		return source_piece
	var replacement: TerrainModuleInstance = module_template.spawn()
	replacement.set_transform(source_piece.transform)
	replacement.create()

	if steps_to_align >= 0:
		var yaw: float = PI * 0.5 * float((4 - steps_to_align) % 4)
		var rotated_basis: Basis = Basis(Vector3.UP, yaw) * replacement.transform.basis
		replacement.set_basis(rotated_basis)
	_apply_topcenter_override(replacement, target_tag)
	return replacement


func _apply_topcenter_override(piece: TerrainModuleInstance, level_tag: String) -> void:
	if level_tag == "level-center" and piece.sockets.has("topcenter"):
		piece.socket_fill_prob_override["topcenter"] = TOPCENTER_FILL_PROB


## Returns 0..3: rotations of canonical missing set until it equals desired_missing; -1 if no match.
func _rotation_steps_to_align_canonical(target_tag: String, desired_missing: Array[String]) -> int:
	var canonical: Array = CANONICAL_MISSING_BY_TAG.get(target_tag, []).duplicate()
	for step in range(4):
		if _same_socket_set(canonical, desired_missing):
			return step
		canonical = _rotate_socket_names_once(canonical)
	return -1


func _rotate_socket_names_once(socket_names: Array) -> Array:
	var out: Array = []
	for socket_name in socket_names:
		out.append(Helper.rotate_socket_name(socket_name))
	return out


func _same_socket_set(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for socket_name in a:
		if not b.has(socket_name):
			return false
	return true


func _tag_for_missing_sockets(missing_sockets: Array[String]) -> String:
	for level_tag in LEVEL_TAG_ORDER:
		if _rotation_steps_to_align_canonical(level_tag, missing_sockets) >= 0:
			return level_tag
	return "level-center"


func _level_tier_tag(module_def: TerrainModule) -> String:
	if module_def != null and module_def.tags.has("level-stack"):
		return "level-stack"
	return "level-ground"


func _get_module_for_level_tag(level_tag: String, level_tier: String) -> TerrainModule:
	if module_by_level_tag.is_empty():
		module_by_level_tag = {
			"level-ground:level-center": TerrainModuleDefinitions.load_level_middle_tile(),
			"level-ground:level-side": TerrainModuleDefinitions.load_level_side_tile(),
			"level-ground:level-corner": TerrainModuleDefinitions.load_level_corner_tile(),
			"level-ground:level-line": TerrainModuleDefinitions.load_level_line_tile(),
			"level-ground:level-peninsula": TerrainModuleDefinitions.load_level_peninsula_tile(),
			"level-ground:level-island": TerrainModuleDefinitions.load_level_island_tile(),
			"level-ground:level-inner-corner": TerrainModuleDefinitions.load_level_inner_corner_tile(),
			"level-ground:level-inner-corner-diag":
				TerrainModuleDefinitions.load_level_inner_corner_diag_tile(),
			"level-ground:level-inner-corner-side":
				TerrainModuleDefinitions.load_level_inner_corner_side_tile(),
			"level-ground:level-inner-corner-edge1":
				TerrainModuleDefinitions.load_level_inner_corner_edge1_tile(),
			"level-ground:level-inner-corner-edge2":
				TerrainModuleDefinitions.load_level_inner_corner_edge2_tile(),
			"level-ground:level-inner-corner-edge-both":
				TerrainModuleDefinitions.load_level_inner_corner_edge_both_tile(),
			"level-ground:level-inner-corner-side-edge":
				TerrainModuleDefinitions.load_level_inner_corner_side_edge_tile(),
			"level-ground:level-inner-corner-three":
				TerrainModuleDefinitions.load_level_inner_corner_three_tile(),
			"level-ground:level-inner-corner-all":
				TerrainModuleDefinitions.load_level_inner_corner_all_tile(),
			"level-stack:level-center": TerrainModuleDefinitions.load_level_stack_middle_tile(),
			"level-stack:level-side": TerrainModuleDefinitions.load_level_stack_side_tile(),
			"level-stack:level-corner": TerrainModuleDefinitions.load_level_stack_corner_tile(),
			"level-stack:level-line": TerrainModuleDefinitions.load_level_stack_line_tile(),
			"level-stack:level-peninsula": TerrainModuleDefinitions.load_level_stack_peninsula_tile(),
			"level-stack:level-island": TerrainModuleDefinitions.load_level_stack_island_tile(),
			"level-stack:level-inner-corner": TerrainModuleDefinitions.load_level_stack_inner_corner_tile(),
			"level-stack:level-inner-corner-diag":
				TerrainModuleDefinitions.load_level_stack_inner_corner_diag_tile(),
			"level-stack:level-inner-corner-side":
				TerrainModuleDefinitions.load_level_stack_inner_corner_side_tile(),
			"level-stack:level-inner-corner-edge1":
				TerrainModuleDefinitions.load_level_stack_inner_corner_edge1_tile(),
			"level-stack:level-inner-corner-edge2":
				TerrainModuleDefinitions.load_level_stack_inner_corner_edge2_tile(),
			"level-stack:level-inner-corner-edge-both":
				TerrainModuleDefinitions.load_level_stack_inner_corner_edge_both_tile(),
			"level-stack:level-inner-corner-side-edge":
				TerrainModuleDefinitions.load_level_stack_inner_corner_side_edge_tile(),
			"level-stack:level-inner-corner-three":
				TerrainModuleDefinitions.load_level_stack_inner_corner_three_tile(),
			"level-stack:level-inner-corner-all":
				TerrainModuleDefinitions.load_level_stack_inner_corner_all_tile()
		}
	return module_by_level_tag.get("%s:%s" % [level_tier, level_tag], null)
