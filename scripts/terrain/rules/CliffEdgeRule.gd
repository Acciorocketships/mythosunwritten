class_name CliffEdgeRule
extends TerrainGenerationRule

const CARDINAL_SOCKETS: Array[String] = ["front", "right", "back", "left"]
const DIAGONAL_SOCKETS: Array[String] = ["frontright", "backright", "backleft", "frontleft"]
const SAME_LEVEL_EPS: float = 0.1

const CANONICAL_MISSING_BY_TAG: Dictionary[String, Array] = {
	"cliff-interior": [],
	"cliff-side": ["front"],
	"cliff-line": ["front", "back"],
	"cliff-corner": ["front", "left"],
	"cliff-peninsula": ["front", "back", "left"],
	"cliff-island": ["front", "right", "back", "left"],
	"cliff-inner-corner": ["frontleft"],
	"cliff-inner-corner-diag": ["frontleft", "backright"],
	"cliff-inner-corner-side": ["frontleft", "backleft"],
	"cliff-inner-corner-edge1": ["frontleft", "back"],
	"cliff-inner-corner-edge2": ["frontleft", "right"],
	"cliff-inner-corner-edge-both": ["frontleft", "back", "right"],
	"cliff-inner-corner-side-edge": ["frontleft", "backleft", "right"],
	"cliff-inner-corner-three": ["frontleft", "backleft", "backright"],
	"cliff-inner-corner-all": ["frontright", "backright", "backleft", "frontleft"]
}
const INNER_CORNER_CARDINALS_BY_DIAGONAL: Dictionary[String, Array] = {
	"frontleft": ["front", "left"],
	"frontright": ["front", "right"],
	"backright": ["back", "right"],
	"backleft": ["back", "left"]
}
const CLIFF_TAG_ORDER: Array[String] = [
	"cliff-interior",
	"cliff-side",
	"cliff-line",
	"cliff-corner",
	"cliff-peninsula",
	"cliff-island",
	"cliff-inner-corner",
	"cliff-inner-corner-diag",
	"cliff-inner-corner-side",
	"cliff-inner-corner-edge1",
	"cliff-inner-corner-edge2",
	"cliff-inner-corner-edge-both",
	"cliff-inner-corner-side-edge",
	"cliff-inner-corner-three",
	"cliff-inner-corner-all"
]
static var module_by_cliff_tag: Dictionary = {}

func matches(context: Dictionary) -> bool:
	if not context.has("chosen_piece"):
		return false
	var chosen_piece: TerrainModuleInstance = context["chosen_piece"]
	if chosen_piece == null:
		return false
	return chosen_piece.def.tags.has("cliff")


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
	var direct_neighbors: Array[TerrainModuleInstance] = _get_cliff_neighbors(
		chosen_piece,
		socket_index,
		terrain_index
	)
	for neighbor_piece in direct_neighbors:
		_add_unique_piece(affected, seen, neighbor_piece)
	for neighbor_piece in direct_neighbors:
		var neighbor_neighbors: Array[TerrainModuleInstance] = _get_cliff_neighbors(
			neighbor_piece,
			socket_index,
			terrain_index
		)
		for indirect_neighbor in neighbor_neighbors:
			_add_unique_piece(affected, seen, indirect_neighbor)
	var chosen_replacement: TerrainModuleInstance = chosen_piece
	for affected_piece in affected:
		var missing: Array[String] = _missing_sockets_for_piece(
			affected_piece,
			socket_index,
			terrain_index
		)
		var target_tag: String = _tag_for_missing_sockets(missing)
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
	return {"chosen_piece": chosen_replacement, "piece_updates": piece_updates}


func _current_cliff_tag(module_def: TerrainModule) -> String:
	if module_def == null:
		return ""
	for cliff_tag in CLIFF_TAG_ORDER:
		if module_def.tags.has(cliff_tag):
			return cliff_tag
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
		var connected: bool = _has_cliff_connection(piece, socket_name, socket_index)
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
		if _has_diagonal_cliff_neighbor(piece, socket_name, terrain_index):
			continue
		missing_inner_diagonals.append(socket_name)
	return missing_cardinals + missing_inner_diagonals


func _has_cliff_connection(
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
		and other.piece.def.tags.has("cliff")
	)


func _get_cliff_neighbors(
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
		if not other.piece.def.tags.has("cliff"):
			continue
		if seen.has(other.piece):
			continue
		seen[other.piece] = true
		neighbors.append(other.piece)
	for socket_name in DIAGONAL_SOCKETS:
		var diagonal_neighbor: TerrainModuleInstance = _get_diagonal_cliff_neighbor_piece(
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


func _has_diagonal_cliff_neighbor(
	piece: TerrainModuleInstance,
	diagonal_socket_name: String,
	terrain_index: TerrainIndex
) -> bool:
	return _get_diagonal_cliff_neighbor_piece(piece, diagonal_socket_name, terrain_index) != null


func _get_diagonal_cliff_neighbor_piece(
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
		if not other.def.tags.has("cliff"):
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


## Replace piece with the correct cliff variant (interior/side/corner/...) and rotate so its
## canonical "missing" edges align with this piece's actual missing sockets.
func _create_replacement_for_target(
	source_piece: TerrainModuleInstance,
	target_tag: String,
	steps_to_align: int
) -> TerrainModuleInstance:
	var existing_tag: String = _current_cliff_tag(source_piece.def)
	if existing_tag == target_tag and steps_to_align == 0:
		return source_piece
	var module_template: TerrainModule = _get_module_for_cliff_tag(target_tag)
	if module_template == null:
		return source_piece
	if module_template == source_piece.def and steps_to_align == 0:
		return source_piece
	var replacement: TerrainModuleInstance = module_template.spawn()
	replacement.set_transform(source_piece.transform)
	replacement.create()

	if steps_to_align >= 0:
		var yaw: float = PI * 0.5 * float((4 - steps_to_align) % 4)
		var rotated_basis: Basis = Basis(Vector3.UP, yaw) * replacement.transform.basis
		replacement.set_basis(rotated_basis)
	return replacement


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
	for cliff_tag in CLIFF_TAG_ORDER:
		if _rotation_steps_to_align_canonical(cliff_tag, missing_sockets) >= 0:
			return cliff_tag
	return "cliff-interior"


func _get_module_for_cliff_tag(cliff_tag: String) -> TerrainModule:
	if module_by_cliff_tag.is_empty():
		module_by_cliff_tag["cliff-interior"] = (
			TerrainModuleDefinitions.load_cliff_interior_tile()
		)
		for entry in TerrainModuleDefinitions.CLIFF_VARIANT_TABLE:
			var scene_name: String = entry[0]
			var variant_tag: String = entry[1]
			module_by_cliff_tag[variant_tag] = (
				TerrainModuleDefinitions.load_cliff_variant(scene_name, variant_tag)
			)
	return module_by_cliff_tag.get(cliff_tag, null)
