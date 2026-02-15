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
	var rotation_steps: int = _rotation_steps_from_world_directions(
		source_piece,
		replacement,
		target_tag,
		missing_sockets
	)
	if rotation_steps != 0:
		# Step count K from _rotation_steps_from_world_directions rotates canonical world
		# cardinals to match desired; the piece must be rotated by (4 - K) steps so that
		# its canonical edges end up pointing at those world directions.
		var steps_to_apply: int = (4 - rotation_steps) % 4
		var yaw: float = PI * 0.5 * float(steps_to_apply)
		var rotated_basis: Basis = Basis(Vector3.UP, yaw) * replacement.transform.basis
		replacement.set_basis(rotated_basis)
	return replacement


func _tag_for_missing_sockets(missing_sockets: Array[String]) -> String:
	var count: int = missing_sockets.size()
	var target_tag: String = "level-center"
	match count:
		0:
			target_tag = "level-center"
		1:
			target_tag = "level-side"
		2:
			var has_front: bool = missing_sockets.has("front")
			var has_back: bool = missing_sockets.has("back")
			var has_left: bool = missing_sockets.has("left")
			var has_right: bool = missing_sockets.has("right")
			if (has_front and has_back) or (has_left and has_right):
				target_tag = "level-line"
			else:
				target_tag = "level-corner"
		3:
			target_tag = "level-peninsula"
		4:
			target_tag = "level-island"
		_:
			target_tag = "level-center"
	return target_tag


func _rotation_steps_for_missing(target_tag: String, desired_missing: Array[String]) -> int:
	var canonical_missing: Array = CANONICAL_MISSING_BY_TAG.get(target_tag, []).duplicate()
	for step in range(4):
		if _same_socket_set(canonical_missing, desired_missing):
			return step
		canonical_missing = _rotate_socket_array(canonical_missing)
	return 0


## World cardinal from direction (Godot: front=-Z, back=+Z, right=+X, left=-X). Must match test _world_cardinal_from_direction.
static func _world_cardinal_from_direction(v: Vector3) -> String:
	var vxz: Vector3 = Vector3(v.x, 0, v.z)
	if vxz.length_squared() < 0.01:
		return "front"
	vxz = vxz.normalized()
	if abs(vxz.x) >= abs(vxz.z):
		return "right" if vxz.x > 0 else "left"
	else:
		return "back" if vxz.z > 0 else "front"


## Set of world cardinal names for the given socket names on the piece (by direction from piece origin to socket).
static func _piece_world_cardinals_for_sockets(piece: TerrainModuleInstance, socket_names: Array) -> Array:
	var center: Vector3 = piece.transform.origin
	var cardinals: Array = []
	var seen: Dictionary = {}
	for socket_name in socket_names:
		if not piece.sockets.has(socket_name):
			continue
		var ps: TerrainModuleSocket = TerrainModuleSocket.new(piece, socket_name)
		var pos: Vector3 = ps.get_socket_position()
		var dir: Vector3 = pos - center
		if dir.length_squared() < 0.01:
			continue
		var c: String = _world_cardinal_from_direction(dir)
		if not seen.get(c, false):
			seen[c] = true
			cardinals.append(c)
	return cardinals


## World cardinals that the replacement's canonical edge sockets point to (using replacement's current transform).
static func _replacement_canonical_world_cardinals(replacement: TerrainModuleInstance, target_tag: String) -> Array:
	var canonical_missing: Array = CANONICAL_MISSING_BY_TAG.get(target_tag, [])
	if replacement.root == null or replacement.socket_node == null:
		return []
	var cardinals: Array = []
	var seen: Dictionary = {}
	for socket_name in canonical_missing:
		if not replacement.sockets.has(socket_name):
			continue
		var sock: Node3D = replacement.sockets[socket_name]
		var local_tf: Transform3D = Helper.to_root_tf(sock, replacement.root)
		var local_pos: Vector3 = local_tf.origin
		if local_pos.length_squared() < 0.01:
			continue
		var world_dir: Vector3 = (replacement.transform.basis * local_pos).normalized()
		var c: String = _world_cardinal_from_direction(world_dir)
		if not seen.get(c, false):
			seen[c] = true
			cardinals.append(c)
	return cardinals


## Find rotation steps so replacement's canonical edges (after rotation) point to the same world directions as source's missing sockets.
func _rotation_steps_from_world_directions(
	source_piece: TerrainModuleInstance,
	replacement: TerrainModuleInstance,
	target_tag: String,
	missing_sockets: Array[String]
) -> int:
	var desired_world_cardinals: Array = _piece_world_cardinals_for_sockets(source_piece, missing_sockets)
	var canonical_world_cardinals: Array = _replacement_canonical_world_cardinals(replacement, target_tag)
	if desired_world_cardinals.size() != canonical_world_cardinals.size():
		return _rotation_steps_for_missing(target_tag, missing_sockets)
	for step in range(4):
		if _same_socket_set(canonical_world_cardinals, desired_world_cardinals):
			return step
		canonical_world_cardinals = _rotate_socket_array(canonical_world_cardinals)
	return 0


func _rotate_socket_array(sockets: Array) -> Array:
	var out: Array = []
	for socket_name in sockets:
		out.append(Helper.rotate_socket_name(socket_name))
	return out


func _same_socket_set(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for socket_name in a:
		if not b.has(socket_name):
			return false
	return true


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
