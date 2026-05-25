class_name LevelEdgeRule
extends TerrainGenerationRule

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
	# If chosen is a stacked tile, walk down so the support's stacking check
	# runs in this rule call. Without this, an unsupported stack placed by the
	# queue persists until something happens to its support's neighbours —
	# which can take forever, letting towers grow upward unchecked.
	if chosen_piece.def.tags.has("level-stack"):
		# Proactive support check: a stacked level is only allowed when its
		# support tile below has all 4 cardinal level neighbours. Without this,
		# the queue's deterministic topcenter expansion (fill_prob 1.0) lets
		# unsupported towers grow upward indefinitely until something happens
		# to perturb the support's neighbourhood — which often never happens.
		var support: TerrainModuleInstance = _get_support_piece_below(
			chosen_piece, terrain_index
		)
		if support == null or not _has_all_cardinal_level_neighbors(support, socket_index):
			return {"chosen_piece": null, "piece_updates": piece_updates}
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
	for affected_piece in affected:
		var missing: Array[String] = _missing_sockets_for_piece(
			affected_piece,
			socket_index,
			terrain_index
		)
		var target_tag: String = _tag_for_missing_sockets(missing)
		var stacked: TerrainModuleInstance = _get_stacked_piece(affected_piece, socket_index)
		if stacked != null and not _can_support_stacked_piece(affected_piece, socket_index):
			piece_updates[stacked] = null
		# Wider-range check: catches stacks at 0.5-offset that _get_stacked_piece
		# misses (its +1.0 height check is too strict for some scenes). When the
		# support level lacks full cardinals, delete those stacks too.
		var wide_stacks: Array[TerrainModuleInstance] = _get_stacks_above(
			affected_piece, terrain_index
		)
		if not wide_stacks.is_empty() and not _has_all_cardinal_level_neighbors(
			affected_piece, socket_index
		):
			for s in wide_stacks:
				piece_updates[s] = null
		var steps_to_align: int = _rotation_steps_to_align_canonical(target_tag, missing)
		var replacement: TerrainModuleInstance = _create_replacement_for_target(
			affected_piece,
			target_tag,
			steps_to_align
		)
		# If this affected piece is a stacked level and its support below has
		# lost all-4-cardinal coverage, delete it rather than retiling it to a
		# stack variant. Without this check, the wide_stacks cleanup above
		# (piece_updates[stack] = null) is overwritten by
		# piece_updates[stack] = replacement when the loop reaches the stack
		# as its own affected_piece, leaving an unsupported stack-island.
		if affected_piece.def.tags.has("level-stack"):
			var support: TerrainModuleInstance = _get_support_piece_below(
				affected_piece, terrain_index
			)
			var support_ok: bool = (
				support != null
				and _has_all_cardinal_level_neighbors(support, socket_index)
			)
			if not support_ok:
				replacement = null
		if affected_piece == chosen_piece:
			chosen_replacement = replacement
		else:
			piece_updates[affected_piece] = replacement
	# Second pass: any level-stack tile near the affected region whose support
	# now lacks all-4-cardinal coverage must be deleted. The main loop only
	# covers stacks directly above affected pieces; this pass catches stacks
	# whose base slid out of the affected set (> 2 hops from chosen_piece)
	# but whose support was invalidated by the current round of retiling.
	_sweep_orphaned_stacks(affected, terrain_index, socket_index, piece_updates)
	return {"chosen_piece": chosen_replacement, "piece_updates": piece_updates}


## Delete any level-stack tile whose support tile lacks all 4 cardinal level
## neighbours. Searches within a neighbourhood of the currently-affected pieces
## so the cost is bounded (small constant multiple of affected.size()).
func _sweep_orphaned_stacks(
	affected: Array[TerrainModuleInstance],
	terrain_index: TerrainIndex,
	socket_index: PositionIndex,
	piece_updates: Dictionary
) -> void:
	# Build a search box that covers all affected pieces + 3 tile widths (72u).
	const SWEEP_PAD: float = 72.0
	if affected.is_empty():
		return
	var lo: Vector3 = affected[0].transform.origin
	var hi: Vector3 = lo
	for p in affected:
		var o: Vector3 = p.transform.origin
		lo.x = min(lo.x, o.x)
		lo.y = min(lo.y, o.y)
		lo.z = min(lo.z, o.z)
		hi.x = max(hi.x, o.x)
		hi.y = max(hi.y, o.y)
		hi.z = max(hi.z, o.z)
	var search_box: AABB = AABB(
		lo - Vector3(SWEEP_PAD, 2.0, SWEEP_PAD),
		hi - lo + Vector3(SWEEP_PAD * 2.0, 6.0, SWEEP_PAD * 2.0)
	)
	var candidates: Array = terrain_index.query_box(search_box)
	for m in candidates:
		if not (m is TerrainModuleInstance):
			continue
		var stack: TerrainModuleInstance = m
		if not stack.def.tags.has("level-stack"):
			continue
		if piece_updates.has(stack):
			continue  # already scheduled
		var support: TerrainModuleInstance = _get_support_piece_below(stack, terrain_index)
		var ok: bool = (
			support != null
			and _has_all_cardinal_level_neighbors(support, socket_index)
		)
		if not ok:
			piece_updates[stack] = null


func _is_stacked_support(piece: TerrainModuleInstance, socket_index: PositionIndex) -> bool:
	if piece == null:
		return false
	return _has_level_connection(piece, "topcenter", socket_index)


func _can_support_stacked_piece(piece: TerrainModuleInstance, socket_index: PositionIndex) -> bool:
	if piece == null:
		return false
	return (
		_get_stacked_piece(piece, socket_index) != null
		and _has_all_cardinal_level_neighbors(piece, socket_index)
	)


func _has_all_cardinal_level_neighbors(
	piece: TerrainModuleInstance,
	socket_index: PositionIndex
) -> bool:
	for socket_name in CARDINAL_SOCKETS:
		if not _has_level_connection(piece, socket_name, socket_index):
			return false
	return true


## Find all level-stack tiles directly above this piece (within 1.5 units up).
## Mirrors _get_support_piece_below: catches stacks at any vertical offset
## that the strict _is_same_height(+1.0) check in _get_stacked_piece would
## miss. Used to clean up stacks when their support's neighbourhood changes.
func _get_stacks_above(
	piece: TerrainModuleInstance, terrain_index: TerrainIndex
) -> Array[TerrainModuleInstance]:
	var out: Array[TerrainModuleInstance] = []
	if piece == null:
		return out
	var piece_y: float = piece.transform.origin.y
	var query_box: AABB = AABB(
		Vector3(piece.transform.origin.x - 0.5, piece_y, piece.transform.origin.z - 0.5),
		Vector3(1.0, 1.5, 1.0)
	)
	var hits: Array = terrain_index.query_box(query_box)
	for hit in hits:
		if not (hit is TerrainModuleInstance):
			continue
		var other: TerrainModuleInstance = hit
		if other == piece:
			continue
		if not other.def.tags.has("level-stack"):
			continue
		if other.transform.origin.y - piece_y <= SAME_LEVEL_EPS:
			continue  # not above
		out.append(other)
	return out


## Find the nearest level tile directly under this stacked tile (within 1.5
## units down). Used by apply() so the rule can validate stacking support
## proactively when a new stack tile is placed, rather than waiting for the
## support's own neighbours to change.
func _get_support_piece_below(
	piece: TerrainModuleInstance, terrain_index: TerrainIndex
) -> TerrainModuleInstance:
	if piece == null:
		return null
	var piece_y: float = piece.transform.origin.y
	var query_box: AABB = AABB(
		Vector3(piece.transform.origin.x - 0.5, piece_y - 1.5, piece.transform.origin.z - 0.5),
		Vector3(1.0, 1.4, 1.0)
	)
	var hits: Array = terrain_index.query_box(query_box)
	var best_support: TerrainModuleInstance = null
	var best_dy: float = INF
	for hit in hits:
		if not (hit is TerrainModuleInstance):
			continue
		var other: TerrainModuleInstance = hit
		if other == piece:
			continue
		if not other.def.tags.has("level"):
			continue
		var dy: float = piece_y - other.transform.origin.y
		if dy <= SAME_LEVEL_EPS:
			continue  # same height or above
		if dy < best_dy:
			best_dy = dy
			best_support = other
	return best_support


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
		return source_piece
	var module_template: TerrainModule = _get_module_for_level_tag(
		target_tag,
		_level_tier_tag(source_piece.def)
	)
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
		# Special-tag center tiles (carry ground-type / level-stack-center beyond the
		# generic variant tag set) — built by dedicated loaders.
		module_by_level_tag["level-ground:level-center"] = (
			TerrainModuleDefinitions.load_level_middle_tile()
		)
		module_by_level_tag["level-stack:level-center"] = (
			TerrainModuleDefinitions.load_level_stack_middle_tile()
		)
		for entry in TerrainModuleDefinitions.LEVEL_VARIANT_TABLE:
			var scene_name: String = entry[0]
			var variant_tag: String = entry[1]
			module_by_level_tag["level-ground:%s" % variant_tag] = (
				TerrainModuleDefinitions.load_level_variant(scene_name, "level-ground", variant_tag)
			)
			module_by_level_tag["level-stack:%s" % variant_tag] = (
				TerrainModuleDefinitions.load_level_variant(scene_name, "level-stack", variant_tag)
			)
	return module_by_level_tag.get("%s:%s" % [level_tier, level_tag], null)
