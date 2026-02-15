class_name LevelEdgeRule
extends TerrainGenerationRule

const CARDINAL_SOCKETS: Array[String] = ["front", "right", "back", "left"]
const CANONICAL_MISSING_BY_TAG: Dictionary[String, Array] = {
	"level-center": [],
	"level-side": ["front"],
	"level-line": ["front", "back"],
	"level-corner": ["front", "left"],
	"level-peninsula": ["front", "left", "right"],
	"level-island": ["front", "right", "back", "left"]
}
static var module_by_level_tag: Dictionary = {}

func matches(context: Dictionary) -> bool:
	if not context.has("chosen_piece"):
		return false
	var chosen_piece: TerrainModuleInstance = context["chosen_piece"]
	if chosen_piece == null:
		return false
	return chosen_piece.def.tags.has("level")


func apply(context: Dictionary) -> Dictionary:
	if not context.has("chosen_piece") or not context.has("socket_index"):
		return {"chosen_piece": context.get("chosen_piece", null), "piece_updates": {}}

	var chosen_piece: TerrainModuleInstance = context["chosen_piece"]
	var socket_index: PositionIndex = context["socket_index"]
	var piece_updates: Dictionary = {}

	var chosen_missing: Array[String] = _missing_sockets_for_piece(chosen_piece, socket_index)
	var chosen_replacement: TerrainModuleInstance = _create_replacement(chosen_piece, chosen_missing)

	var neighbors: Array[TerrainModuleInstance] = _get_level_neighbors(chosen_piece, socket_index)
	for neighbor_piece in neighbors:
		var neighbor_missing: Array[String] = _missing_sockets_for_piece(neighbor_piece, socket_index)
		var neighbor_replacement: TerrainModuleInstance = _create_replacement(
			neighbor_piece,
			neighbor_missing
		)
		piece_updates[neighbor_piece] = neighbor_replacement

	return {"chosen_piece": chosen_replacement, "piece_updates": piece_updates}


func _missing_sockets_for_piece(
	piece: TerrainModuleInstance,
	socket_index: PositionIndex
) -> Array[String]:
	var missing: Array[String] = []
	for socket_name in CARDINAL_SOCKETS:
		if not piece.sockets.has(socket_name):
			continue
		var piece_socket: TerrainModuleSocket = TerrainModuleSocket.new(piece, socket_name)
		var other: TerrainModuleSocket = socket_index.query_other(
			piece_socket.get_socket_position(),
			piece
		)
		var has_level_connection: bool = (
			other != null
			and other.piece != null
			and other.piece.def.tags.has("level")
		)
		if not has_level_connection:
			missing.append(socket_name)
	return missing


func _get_level_neighbors(
	piece: TerrainModuleInstance,
	socket_index: PositionIndex
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
	return neighbors


## Replace piece with the correct level variant (center/side/corner/...) and rotate so its
## canonical "missing" edges align with this piece's actual missing sockets.
func _create_replacement(
	source_piece: TerrainModuleInstance,
	missing_sockets: Array[String]
) -> TerrainModuleInstance:
	var target_tag: String = _tag_for_missing_sockets(missing_sockets)
	var module_template: TerrainModule = _get_module_for_level_tag(target_tag)
	if module_template == null:
		return source_piece
	var replacement: TerrainModuleInstance = module_template.spawn()
	replacement.set_transform(source_piece.transform)
	replacement.create()

	# Variant has canonical edge socket names (e.g. level-side has ["front"]). Find how many
	# 90° rotations of that set match missing_sockets; then rotate piece by (4 - steps).
	var steps: int = _rotation_steps_to_align_canonical(target_tag, missing_sockets)
	if steps >= 0:
		var yaw: float = PI * 0.5 * float((4 - steps) % 4)
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
	var count: int = missing_sockets.size()
	var tag: String = "level-center"
	match count:
		0:
			tag = "level-center"
		1:
			tag = "level-side"
		2:
			var opp: bool = (
				(missing_sockets.has("front") and missing_sockets.has("back"))
				or (missing_sockets.has("left") and missing_sockets.has("right"))
			)
			tag = "level-line" if opp else "level-corner"
		3:
			tag = "level-peninsula"
		4:
			tag = "level-island"
	return tag


func _get_module_for_level_tag(level_tag: String) -> TerrainModule:
	if module_by_level_tag.is_empty():
		module_by_level_tag = {
			"level-center": TerrainModuleDefinitions.load_level_middle_tile(),
			"level-side": TerrainModuleDefinitions.load_level_side_tile(),
			"level-corner": TerrainModuleDefinitions.load_level_corner_tile(),
			"level-line": TerrainModuleDefinitions.load_level_line_tile(),
			"level-peninsula": TerrainModuleDefinitions.load_level_peninsula_tile(),
			"level-island": TerrainModuleDefinitions.load_level_island_tile()
		}
	return module_by_level_tag.get(level_tag, null)
