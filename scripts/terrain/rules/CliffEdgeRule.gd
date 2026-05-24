class_name CliffEdgeRule
extends TerrainGenerationRule

const CARDINAL_SOCKETS: Array[String] = ["front", "right", "back", "left"]
const DIAGONAL_SOCKETS: Array[String] = ["frontright", "backright", "backleft", "frontleft"]
const SAME_LEVEL_EPS: float = 0.1
# Cap the recursive spawn loop. A 1x1 seed needs ~3 actual spawns (and ~7
# iterations including re-checks) to grow into a 2x2 plateau. Each spawn
# attaches a new cliff via the generator, so this also bounds the number of
# new pieces a single rule invocation can create.
const MAX_SPAWN_ITERATIONS: int = 20
# Which empty cardinal each connected cardinal is "adjacent" to. Preferring an
# empty cardinal adjacent to a connected one biases growth toward outer-corner
# (2 adjacent connections) instead of line (2 opposite connections).
const ADJACENT_CARDINALS: Dictionary[String, Array] = {
	"front": ["left", "right"],
	"back": ["left", "right"],
	"left": ["front", "back"],
	"right": ["front", "back"],
}

# Canonical missing-socket patterns for each cliff variant. Drop faces in the
# authored scenes sit on -Z ("front") and -X ("left"), matching the level-tile
# convention — getting these wrong rotates every retiled piece 180° off its
# intended orientation.
const CANONICAL_MISSING_BY_TAG: Dictionary[String, Array] = {
	"cliff-side":                   ["front"],
	"cliff-corner":                 ["front", "left"],
	"cliff-line":                   ["front", "back"],
	"cliff-peninsula":              ["front", "back", "left"],
	"cliff-island":                 ["front", "back", "left", "right"],
	"cliff-inner-corner":           ["frontleft"],
	"cliff-inner-corner-diag":      ["frontleft", "backright"],
	"cliff-inner-corner-side":      ["frontleft", "backleft"],
	"cliff-inner-corner-three":     ["frontleft", "backleft", "backright"],
	"cliff-inner-corner-all":       ["frontleft", "frontright", "backleft", "backright"],
	"cliff-inner-corner-edge1":     ["back", "frontleft"],
	"cliff-inner-corner-edge2":     ["right", "frontleft"],
	"cliff-inner-corner-edge-both": ["back", "right", "frontleft"],
	"cliff-inner-corner-side-edge": ["right", "frontleft", "backleft"],
}
# Order checked: most-constrained first. Variants with more missing sockets
# are matched before variants with fewer; within a missing-count, hybrid
# (cardinal + diagonal) patterns are matched before pure-cardinal or
# pure-diagonal patterns of the same count.
const CLIFF_TAG_ORDER: Array[String] = [
	"cliff-island",
	"cliff-inner-corner-all",
	"cliff-inner-corner-edge-both",
	"cliff-inner-corner-side-edge",
	"cliff-inner-corner-three",
	"cliff-peninsula",
	"cliff-inner-corner-edge1",
	"cliff-inner-corner-edge2",
	"cliff-inner-corner-diag",
	"cliff-inner-corner-side",
	"cliff-line",
	"cliff-corner",
	"cliff-inner-corner",
	"cliff-side",
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
	if (
		not context.has("chosen_piece")
		or not context.has("socket_index")
		or not context.has("terrain_index")
	):
		return {"chosen_piece": context.get("chosen_piece", null), "piece_updates": {}}

	var chosen_piece: TerrainModuleInstance = context["chosen_piece"]
	var socket_index: PositionIndex = context["socket_index"]
	var terrain_index: TerrainIndex = context["terrain_index"]
	var generator: Variant = context.get("generator", null)
	var piece_updates: Dictionary = {}

	# Step 1: recursively spawn cliffs so every invalid cliff piece reaches a
	# valid 5-variant config (interior / inner-corner / inner-corner-diag /
	# edge / outer-corner). Cliffs have no line/peninsula/island variants, so
	# we must grow neighbours instead of accepting those shapes.
	_recursively_validate_via_spawning(
		chosen_piece, socket_index, terrain_index, generator
	)

	# Step 2: collect everything still in scope of `chosen_piece` (which now
	# includes whatever we spawned) and assign each its correct variant.
	var affected: Array[TerrainModuleInstance] = []
	var seen: Dictionary = {}
	_collect_affected(chosen_piece, affected, seen, socket_index, terrain_index)

	var chosen_replacement: TerrainModuleInstance = chosen_piece
	for affected_piece in affected:
		if not is_instance_valid(affected_piece):
			continue
		if not affected_piece.def.tags.has("cliff"):
			continue
		var missing: Array[String] = _missing_sockets_for_piece(
			affected_piece, socket_index, terrain_index
		)
		var target_tag: String = _tag_for_missing_sockets(missing)
		if target_tag == "":
			# Spawning capped out without reaching a valid variant. Leave the
			# piece untouched rather than deleting (avoids ripping holes in
			# the indices that other rules depend on).
			continue
		var steps_to_align: int = _rotation_steps_to_align_canonical(target_tag, missing)
		var replacement: TerrainModuleInstance = _create_replacement_for_target(
			affected_piece, target_tag, steps_to_align
		)
		if affected_piece == chosen_piece:
			chosen_replacement = replacement
		elif replacement != affected_piece:
			piece_updates[affected_piece] = replacement
	return {"chosen_piece": chosen_replacement, "piece_updates": piece_updates}


func _collect_affected(
	chosen_piece: TerrainModuleInstance,
	affected: Array[TerrainModuleInstance],
	seen: Dictionary,
	socket_index: PositionIndex,
	terrain_index: TerrainIndex
) -> void:
	# BFS up to 2 hops (matches the old direct + indirect neighbour walk).
	_add_unique_piece(affected, seen, chosen_piece)
	var direct: Array[TerrainModuleInstance] = _get_cliff_neighbors(
		chosen_piece, socket_index, terrain_index
	)
	for n in direct:
		_add_unique_piece(affected, seen, n)
	for n in direct:
		var indirect: Array[TerrainModuleInstance] = _get_cliff_neighbors(
			n, socket_index, terrain_index
		)
		for nn in indirect:
			_add_unique_piece(affected, seen, nn)


func _recursively_validate_via_spawning(
	chosen_piece: TerrainModuleInstance,
	socket_index: PositionIndex,
	terrain_index: TerrainIndex,
	generator: Variant
) -> void:
	if generator == null:
		return
	var worklist: Array[TerrainModuleInstance] = [chosen_piece]
	var iter: int = 0
	while not worklist.is_empty() and iter < MAX_SPAWN_ITERATIONS:
		iter += 1
		var piece: TerrainModuleInstance = worklist.pop_back()
		if not is_instance_valid(piece):
			continue
		if not piece.def.tags.has("cliff"):
			continue
		var missing: Array[String] = _missing_sockets_for_piece(
			piece, socket_index, terrain_index
		)
		var target_tag: String = _tag_for_missing_sockets(missing)
		if target_tag != "":
			continue  # already valid, nothing to spawn
		var spawned: TerrainModuleInstance = _spawn_one_cliff_neighbour(
			piece, socket_index, generator
		)
		if spawned == null:
			continue  # no empty cardinal slot or attach failed
		worklist.push_back(spawned)
		worklist.push_back(piece)  # re-evaluate this piece next iteration


func _spawn_one_cliff_neighbour(
	piece: TerrainModuleInstance,
	socket_index: PositionIndex,
	generator: Variant
) -> TerrainModuleInstance:
	var socket_name: String = _select_cardinal_to_spawn(piece, socket_index)
	if socket_name == "":
		return null
	var marker: Marker3D = piece.sockets.get(socket_name, null)
	if marker == null:
		return null
	# Neighbour centre = 2 × socket world position − piece centre.
	# (Socket sits at the tile edge halfway between the two centres.)
	var socket_world: Vector3 = piece.transform.origin + piece.transform.basis * marker.position
	var neighbour_centre: Vector3 = socket_world * 2.0 - piece.transform.origin
	var module: TerrainModule = TerrainModuleDefinitions.load_cliff_side_tile()
	var inst: TerrainModuleInstance = module.spawn()
	inst.create()
	_suppress_lateral_expansion(inst)
	var xform: Transform3D = inst.transform
	xform.origin = Helper.snap_vec3(neighbour_centre)
	inst.set_transform(xform)
	if generator.attach_piece(inst):
		return inst
	inst.destroy()
	return null


# Override cardinal fill_prob to 0 so the queue does not try to expand this
# piece laterally. The rule drives all cliff growth; allowing the queue to also
# expand promoted/spawned cliffs cascades into runaway plateau merging.
func _suppress_lateral_expansion(piece: TerrainModuleInstance) -> void:
	for socket_name in CARDINAL_SOCKETS:
		piece.socket_fill_prob_override[socket_name] = 0.0


func _select_cardinal_to_spawn(
	piece: TerrainModuleInstance,
	socket_index: PositionIndex
) -> String:
	var connected: Dictionary[String, bool] = {}
	var empty_cardinals: Array[String] = []
	for socket_name in CARDINAL_SOCKETS:
		var has_neighbour: bool = _has_cliff_connection(piece, socket_name, socket_index)
		connected[socket_name] = has_neighbour
		if not has_neighbour:
			empty_cardinals.append(socket_name)
	if empty_cardinals.is_empty():
		return ""
	# Prefer an empty cardinal adjacent to a connected one (forms outer-corner
	# instead of line, which has no valid variant).
	for empty in empty_cardinals:
		for adj in ADJACENT_CARDINALS.get(empty, []):
			if connected.get(adj, false):
				return empty
	# Fully isolated piece: any cardinal works as the first growth step.
	return empty_cardinals[0]


func _count_cardinal_cliff_connections(
	piece: TerrainModuleInstance,
	socket_index: PositionIndex
) -> int:
	var n: int = 0
	for socket_name in CARDINAL_SOCKETS:
		if _has_cliff_connection(piece, socket_name, socket_index):
			n += 1
	return n


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


func _has_diagonal_cliff_neighbor(
	piece: TerrainModuleInstance,
	diagonal_socket_name: String,
	terrain_index: TerrainIndex
) -> bool:
	return _get_diagonal_cliff_neighbor_piece(piece, diagonal_socket_name, terrain_index) != null


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
			piece, socket_name, terrain_index
		)
		if diagonal_neighbor == null:
			continue
		if seen.has(diagonal_neighbor):
			continue
		seen[diagonal_neighbor] = true
		neighbors.append(diagonal_neighbor)
	return neighbors


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


func _rotation_steps_to_align_canonical(target_tag: String, desired_missing: Array[String]) -> int:
	var canonical: Array = CANONICAL_MISSING_BY_TAG.get(target_tag, []).duplicate()
	for step in range(4):
		if _same_socket_set(canonical, desired_missing):
			return step
		canonical = _rotate_socket_names_once(canonical)
	return -1


func _tag_for_missing_sockets(missing_sockets: Array[String]) -> String:
	# Empty -> swap to interior (signaled by special tag).
	if missing_sockets.is_empty():
		return "cliff-interior"
	for cliff_tag in CLIFF_TAG_ORDER:
		if _rotation_steps_to_align_canonical(cliff_tag, missing_sockets) >= 0:
			return cliff_tag
	# No match: signal "keep piece as-is" via empty string.
	return ""


func _current_cliff_tag(module_def: TerrainModule) -> String:
	if module_def == null:
		return ""
	for cliff_tag in CLIFF_TAG_ORDER:
		if module_def.tags.has(cliff_tag):
			return cliff_tag
	if module_def.tags.has("cliff-interior"):
		return "cliff-interior"
	return ""


func _get_module_for_cliff_tag(cliff_tag: String) -> TerrainModule:
	if module_by_cliff_tag.is_empty():
		module_by_cliff_tag = {
			"cliff-side":                   TerrainModuleDefinitions.load_cliff_side_tile(),
			"cliff-corner":                 TerrainModuleDefinitions.load_cliff_corner_tile(),
			"cliff-line":                   TerrainModuleDefinitions.load_cliff_line_tile(),
			"cliff-peninsula":              TerrainModuleDefinitions.load_cliff_peninsula_tile(),
			"cliff-island":                 TerrainModuleDefinitions.load_cliff_island_tile(),
			"cliff-inner-corner":           TerrainModuleDefinitions.load_cliff_inner_corner_tile(),
			"cliff-inner-corner-diag":      TerrainModuleDefinitions.load_cliff_inner_corner_diag_tile(),
			"cliff-inner-corner-side":      TerrainModuleDefinitions.load_cliff_inner_corner_side_tile(),
			"cliff-inner-corner-three":     TerrainModuleDefinitions.load_cliff_inner_corner_three_tile(),
			"cliff-inner-corner-all":       TerrainModuleDefinitions.load_cliff_inner_corner_all_tile(),
			"cliff-inner-corner-edge1":     TerrainModuleDefinitions.load_cliff_inner_corner_edge1_tile(),
			"cliff-inner-corner-edge2":     TerrainModuleDefinitions.load_cliff_inner_corner_edge2_tile(),
			"cliff-inner-corner-edge-both":
					TerrainModuleDefinitions.load_cliff_inner_corner_edge_both_tile(),
			"cliff-inner-corner-side-edge":
					TerrainModuleDefinitions.load_cliff_inner_corner_side_edge_tile(),
			"cliff-interior":               TerrainModuleDefinitions.load_cliff_interior_tile(),
		}
	return module_by_cliff_tag.get(cliff_tag, null)


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
	_suppress_lateral_expansion(replacement)

	if steps_to_align > 0:
		var yaw: float = PI * 0.5 * float((4 - steps_to_align) % 4)
		var rotated_basis: Basis = Basis(Vector3.UP, yaw) * replacement.transform.basis
		replacement.set_basis(rotated_basis)
	return replacement
