extends Node3D

## Player feet rest at y=0.5 (top of ground tile). Tiles whose top exceeds
## feet_y + max_step are unclimbable and must not spawn at the player origin.
const PLAYER_FEET_Y: float = 0.5
const PLAYER_MAX_STEP_HEIGHT: float = 0.5

@export var RENDER_RANGE: int = 250
@export var MAX_LOAD_PER_STEP: int = 8

@export var player: Node3D
@export var terrain_parent: Node

var generation_rules: TerrainGenerationRuleLibrary
var library: TerrainModuleLibrary
var test_pieces_library: TerrainModuleLibrary
var terrain_index: TerrainIndex
var socket_index: PositionIndex
var queue: PriorityQueue
var queued_socket_keys: Dictionary = {}
var _tracked_queue_ref: PriorityQueue = null
var _deferred_sockets: Array = []
var _deferred_socket_keys: Dictionary = {}
var _last_player_pos: Vector3 = Vector3(INF, INF, INF)


func _ready() -> void:
	library = TerrainModuleLibrary.new()
	library.init()

	test_pieces_library = TerrainModuleLibrary.new()
	test_pieces_library.init_test_pieces()

	socket_index = PositionIndex.new()
	terrain_index = TerrainIndex.new()
	generation_rules = TerrainGenerationRuleLibrary.new()

	var start_tile := load_start_tile()
	queue = PriorityQueue.new()
	queued_socket_keys.clear()
	_tracked_queue_ref = queue
	# Register the start tile in indices so collision checks work and adjacency can be detected
	# Sockets are indexed so they can act as adjacency barriers.
	register_piece(start_tile, "")
	for socket_name in start_tile.sockets.keys():
		var piece_socket: TerrainModuleSocket = TerrainModuleSocket.new(start_tile, socket_name)
		if not _is_socket_expandable(piece_socket):
			continue
		var dist := get_dist_from_player(piece_socket.piece, piece_socket.socket_name)
		_enqueue_socket(piece_socket, dist)

func _process(_delta: float) -> void:
	load_terrain()

func load_terrain() -> void:
	_ensure_queue_tracking_current()
	# When the player hasn't moved since last frame, all queue priorities still reflect
	# the current player position, so the heap top is the actual nearest socket. If even
	# that is out of range, every queued socket is out of range too — skip the frame to
	# avoid the pop/defer/re-enqueue churn that would otherwise burn the per-frame budget.
	var current_player_pos: Vector3 = player.global_position if player != null else Vector3.ZERO
	if current_player_pos == _last_player_pos and not queue.is_empty():
		var top_item: Variant = queue.peek()
		if top_item is TerrainModuleSocket:
			var top_socket: TerrainModuleSocket = top_item
			if get_dist_from_player(top_socket.piece, top_socket.socket_name) > RENDER_RANGE:
				return
	_last_player_pos = current_player_pos
	var num_added: int = 0
	var num_processed: int = 0
	_deferred_sockets.clear()
	_deferred_socket_keys.clear()

	while num_added < MAX_LOAD_PER_STEP and num_processed < MAX_LOAD_PER_STEP * 2 and !queue.is_empty():
		var piece_socket = queue.pop()
		if piece_socket == null:
			break
		_mark_socket_dequeued(piece_socket)
		var piece: TerrainModuleInstance = piece_socket.piece
		var socket_name: String = piece_socket.socket_name
		var distance := get_dist_from_player(piece, socket_name)

		num_processed += 1

		var added: bool = _process_socket(piece_socket, distance)
		if added:
			num_added += 1
	_flush_deferred_sockets()
	_purge_orphaned_level_stacks()


## Delete any level-stack tile whose support tile (directly below) no longer
## has all 4 cardinal level neighbours. Runs once per load_terrain() call so
## stacks whose support lost cardinals between rule evaluations are cleaned up
## even when no LevelEdgeRule trigger fires near that support tile.
func _purge_orphaned_level_stacks() -> void:
	var to_remove: Array[TerrainModuleInstance] = []
	for module in terrain_index.all_modules.keys():
		if not (module is TerrainModuleInstance):
			continue
		var piece: TerrainModuleInstance = module
		if not piece.def.tags.has("level-stack"):
			continue
		# Find support tile (level tile directly below, within 1.5 units).
		var piece_y: float = piece.transform.origin.y
		var query_box: AABB = AABB(
			Vector3(piece.transform.origin.x - 0.5, piece_y - 1.5, piece.transform.origin.z - 0.5),
			Vector3(1.0, 1.4, 1.0)
		)
		var candidates: Array = terrain_index.query_box(query_box)
		var support: TerrainModuleInstance = null
		var best_dy: float = INF
		for c in candidates:
			if not (c is TerrainModuleInstance):
				continue
			var other: TerrainModuleInstance = c
			if other == piece:
				continue
			if not other.def.tags.has("level"):
				continue
			var dy: float = piece_y - other.transform.origin.y
			if dy <= 0.1:
				continue
			if dy < best_dy:
				best_dy = dy
				support = other
		if support == null:
			to_remove.append(piece)
			continue
		# Support found — verify it still has all 4 cardinal level neighbours.
		var all_cardinals: bool = true
		for socket_name in ["front", "right", "back", "left"]:
			if not support.sockets.has(socket_name):
				all_cardinals = false
				break
			var s: TerrainModuleSocket = TerrainModuleSocket.new(support, socket_name)
			var other_socket: TerrainModuleSocket = socket_index.query_other(
				s.get_socket_position(), support
			)
			if other_socket == null or other_socket.piece == null:
				all_cardinals = false
				break
			if not other_socket.piece.def.tags.has("level"):
				all_cardinals = false
				break
		if not all_cardinals:
			to_remove.append(piece)
	for piece in to_remove:
		remove_piece(piece)


func _process_socket(piece_socket: TerrainModuleSocket, distance: float) -> bool:
	if piece_socket.piece.root == null or piece_socket.piece.sockets.is_empty():
		return false
	if _is_socket_connected(piece_socket):
		return false
	if _defer_if_out_of_range(piece_socket, distance):
		return false
	if not _passes_fill_prob_roll(piece_socket):
		return false

	var size: String = _sample_socket_size(piece_socket.piece, piece_socket.socket_name)
	var placement_context: Dictionary = _resolve_placement_context(piece_socket, size)
	return _try_place_with_rules(piece_socket, placement_context)


func _is_socket_connected(piece_socket: TerrainModuleSocket) -> bool:
	var existing_sockets: Array[TerrainModuleSocket] = socket_index.query_others(
		piece_socket.get_socket_position(),
		piece_socket.piece
	)
	for existing_socket in existing_sockets:
		if _is_socket_expandable(existing_socket):
			return true
	return false


func _defer_if_out_of_range(piece_socket: TerrainModuleSocket, distance: float) -> bool:
	if distance <= RENDER_RANGE:
		return false
	_stage_deferred_socket(piece_socket, distance)
	return true


func _sample_socket_size(piece: TerrainModuleInstance, socket_name: String) -> String:
	if not piece.def.socket_size.has(socket_name):
		return "point"
	var size_prob_dist: Distribution = piece.def.socket_size[socket_name]
	return size_prob_dist.sample()


func _get_socket_fill_prob(piece: TerrainModuleInstance, socket_name: String) -> float:
	if piece.socket_fill_prob_override.has(socket_name):
		var ov: Variant = piece.socket_fill_prob_override[socket_name]
		if ov is float:
			return ov
		if ov is int:
			return float(ov)
	if not piece.def.socket_fill_prob.has(socket_name):
		return 0.0
	var fill_prob: Variant = piece.def.socket_fill_prob[socket_name]
	if fill_prob == null:
		return 0.0
	if fill_prob is float:
		return fill_prob
	if fill_prob is int:
		return fill_prob
	return 0.0


func _is_socket_expandable(piece_socket: TerrainModuleSocket) -> bool:
	return _get_socket_fill_prob(piece_socket.piece, piece_socket.socket_name) > 0.0


func _is_socket_blocking(piece_socket: TerrainModuleSocket) -> bool:
	if piece_socket == null or piece_socket.piece == null or piece_socket.piece.def == null:
		return false
	var socket_name: String = piece_socket.socket_name
	var fill_probs: Dictionary = piece_socket.piece.def.socket_fill_prob
	if not fill_probs.has(socket_name):
		return false
	var fill_prob: Variant = fill_probs[socket_name]
	if fill_prob == null:
		return false
	return _get_socket_fill_prob(piece_socket.piece, socket_name) <= 0.0


func _passes_fill_prob_roll(piece_socket: TerrainModuleSocket) -> bool:
	var fill_prob: float = _get_socket_fill_prob(piece_socket.piece, piece_socket.socket_name)
	return fill_prob > 0.0 and randf() <= fill_prob


func _resolve_placement_context(piece_socket: TerrainModuleSocket, size: String) -> Dictionary:
	var socket_name: String = piece_socket.socket_name
	var adjacent: Dictionary[String, TerrainModuleSocket] = get_adjacent_from_size(piece_socket, size)
	var attachment_socket_name: String = Helper.get_attachment_socket_name(socket_name)
	var origin_world: Vector3 = piece_socket.get_socket_position()

	if _has_forbidden_adjacency(adjacent):
		return _empty_placement_context(size, adjacent, attachment_socket_name, origin_world)

	var rotated_adjacent: Dictionary = adjacent.duplicate()
	var rotated_attachment_socket: String = attachment_socket_name
	for _rotation_attempt in range(4):
		var required_tags: TagList = library.get_required_tags(rotated_adjacent, rotated_attachment_socket)
		required_tags.append(size)
		var filtered: TerrainModuleList = library.get_by_tags(required_tags)
		if not filtered.is_empty():
			return {
				"size": size,
				"adjacent": rotated_adjacent,
				"attachment_socket_name": rotated_attachment_socket,
				"required_tags": required_tags,
				"filtered": filtered,
				"dist": library.get_combined_distribution(rotated_adjacent).copy(),
				"origin_world": origin_world
			}
		rotated_adjacent = Helper.rotate_adjacency(rotated_adjacent)
		rotated_attachment_socket = Helper.rotate_socket_name(rotated_attachment_socket)

	return _empty_placement_context(size, adjacent, attachment_socket_name, origin_world)


func _empty_placement_context(
	size: String,
	adjacent: Dictionary[String, TerrainModuleSocket],
	attachment_socket_name: String,
	origin_world: Vector3
) -> Dictionary:
	return {
		"size": size,
		"adjacent": adjacent,
		"attachment_socket_name": attachment_socket_name,
		"required_tags": TagList.new(),
		"filtered": TerrainModuleList.new(),
		"dist": Distribution.new(),
		"origin_world": origin_world
	}


func _has_forbidden_adjacency(adjacent: Dictionary[String, TerrainModuleSocket]) -> bool:
	for hit in adjacent.values():
		if hit == null:
			continue
		if _is_socket_blocking(hit):
			return true
	return false


func _try_place_with_rules(orig_piece_socket: TerrainModuleSocket, placement_context: Dictionary) -> bool:
	var filtered: TerrainModuleList = placement_context.get("filtered", TerrainModuleList.new())
	var dist: Distribution = placement_context.get("dist", Distribution.new())
	var attachment_socket_name: String = placement_context.get("attachment_socket_name", "bottom")
	if filtered.is_empty():
		return false
	var chosen_template: TerrainModule = library.sample_from_modules(filtered, dist)
	var chosen: TerrainModuleInstance = chosen_template.spawn()
	chosen.create()
	var new_piece_socket: TerrainModuleSocket = TerrainModuleSocket.new(chosen, attachment_socket_name)
	if add_piece(new_piece_socket, orig_piece_socket):
		_apply_rules_after_placement(chosen, orig_piece_socket, placement_context, filtered)
		return true
	chosen.destroy()
	return false


func _build_rule_context(
	orig_piece_socket: TerrainModuleSocket,
	placement_context: Dictionary,
	chosen_piece: TerrainModuleInstance,
	filtered: TerrainModuleList
) -> Dictionary:
	return {
		"size": placement_context.get("size", "point"),
		"required_tags": placement_context.get("required_tags", TagList.new()),
		"socket_name": orig_piece_socket.socket_name,
		"adjacent": placement_context.get("adjacent", {}),
		"chosen_piece": chosen_piece,
		"filtered": filtered,
		"origin_world": placement_context.get("origin_world", orig_piece_socket.get_socket_position()),
		"terrain_index": terrain_index,
		"socket_index": socket_index,
		"queue": queue,
		"library": library,
		"rules_instance": generation_rules
	}


func _apply_rules_after_placement(
	placed_piece: TerrainModuleInstance,
	orig_piece_socket: TerrainModuleSocket,
	placement_context: Dictionary,
	filtered: TerrainModuleList
) -> void:
	var current_piece: TerrainModuleInstance = placed_piece
	var context: Dictionary = _build_rule_context(orig_piece_socket, placement_context, current_piece, filtered)
	context["adjacent"] = get_adjacent(current_piece)
	for rule in generation_rules.rules:
		context["chosen_piece"] = current_piece
		if not rule.matches(context):
			continue
		var step_result: Dictionary = rule.apply(context)
		if step_result.get("skip", false):
			return
		var updated_piece: Variant = step_result.get("chosen_piece", current_piece)
		var step_updates: Dictionary = step_result.get("piece_updates", {})
		if updated_piece == null:
			# Rule decided the placement is invalid (e.g. an unsupported level
			# stack, or a stuck cliff). Apply any sibling updates, remove the
			# piece, and stop running further rules for this placement.
			_apply_piece_updates_after_placement(step_updates, null)
			remove_piece(current_piece)
			return
		if updated_piece is TerrainModuleInstance and updated_piece != current_piece:
			# Preserve topcenter when retiling a piece placed by lateral expansion so that position gets one stacked tile.
			# Do not preserve when this piece was placed by stacking (topcenter), or we'd enqueue its topcenter and build infinite towers.
			var preserve_topcenter: bool = orig_piece_socket.socket_name != "topcenter"
			_replace_piece(current_piece, updated_piece, preserve_topcenter)
			current_piece = updated_piece
			context["adjacent"] = get_adjacent(current_piece)
		_apply_piece_updates_after_placement(step_updates, current_piece)
		for socket_to_queue in step_result.get("sockets_for_queue", []):
			queue.push(socket_to_queue, 0)


func _apply_piece_updates_after_placement(piece_updates: Dictionary, placed_piece: TerrainModuleInstance) -> void:
	for from_piece in piece_updates.keys():
		var to_piece: Variant = piece_updates[from_piece]
		if from_piece == placed_piece:
			continue
		if not (from_piece is TerrainModuleInstance):
			continue
		var existing_piece: TerrainModuleInstance = from_piece
		var is_registered_piece: bool = existing_piece.root != null and existing_piece.root.get_parent() == terrain_parent
		if not is_registered_piece:
			continue
		if to_piece == from_piece:
			continue
		if to_piece == null:
			remove_piece(existing_piece)
			continue
		if not (to_piece is TerrainModuleInstance):
			continue
		_replace_piece(existing_piece, to_piece, true)


func _replace_piece(old_piece: TerrainModuleInstance, new_piece: TerrainModuleInstance, preserve_topcenter: bool = false) -> void:
	if old_piece == null or new_piece == null:
		return
	# Only preserve topcenter when retiling an existing piece (neighbor update) or when the placed piece was placed by lateral expansion. Do not preserve when
	# retiling the piece we just placed, or we would enqueue that edge's topcenter and build infinite towers.
	if preserve_topcenter and (
		old_piece.def != null and old_piece.def.tags.has("level-stack-center")
		and new_piece.def != null and new_piece.def.tags.has("level-stack")
		and not new_piece.def.tags.has("level-stack-center")
		and new_piece.sockets.has("topcenter")
	):
		var fp: Variant = old_piece.def.socket_fill_prob.get("topcenter")
		if fp != null and (fp is float or fp is int):
			new_piece.socket_fill_prob_override["topcenter"] = float(fp)
	remove_piece(old_piece)
	terrain_parent.add_child(new_piece.root)
	register_piece(new_piece, "")
	add_piece_to_queue(new_piece)


func get_dist_from_player(piece: TerrainModuleInstance, socket_name: String) -> float:
	var socket: Marker3D = piece.sockets.get(socket_name, null)
	if socket == null or piece.root == null:
		return INF
	var socket_world_pos := Helper.socket_world_pos(piece.transform, socket, piece.root)
	var player_pos := player.global_position
	player_pos[1] = -1.0
	return (socket_world_pos - player_pos).length()


func add_piece_to_queue(piece: TerrainModuleInstance) -> void:
	_ensure_queue_tracking_current()
	for socket_name: String in piece.sockets.keys():
		var current_socket: TerrainModuleSocket = TerrainModuleSocket.new(piece, socket_name)
		if not _is_socket_expandable(current_socket):
			continue
		var socket: Marker3D = piece.sockets[socket_name]
		var pos := Helper.socket_world_pos(piece.transform, socket, piece.root)
		var existing_socket: TerrainModuleSocket = socket_index.query_other(pos, piece)
		if existing_socket != null and _is_socket_expandable(existing_socket):
			continue
		var dist := get_dist_from_player(piece, socket_name)
		_enqueue_socket(current_socket, dist)


func register_piece(piece: TerrainModuleInstance, _attachment_socket_name: String) -> void:
	# Index every socket. The attachment socket must be indexed too — otherwise a query
	# from the parent piece's matching socket position finds only its own socket and
	# falsely concludes the side has no neighbor, which causes LevelEdgeRule to choose
	# the wrong variant for the parent (treating an attached neighbor as missing).
	for socket_name: String in piece.sockets.keys():
		var piece_other_socket: TerrainModuleSocket = TerrainModuleSocket.new(piece, socket_name)
		socket_index.insert(piece_other_socket)
	terrain_index.insert(piece)


func can_place(new_piece: TerrainModuleInstance, parent_piece: TerrainModuleInstance) -> bool:
	assert(new_piece.def != null)
	if new_piece.def.tags.has("ground"):
		return true
	if new_piece.def.replace_existing:
		return true
	var other_pieces: Array = terrain_index.query_box(new_piece.aabb)
	if parent_piece != null:
		other_pieces.erase(parent_piece)

	other_pieces = other_pieces.filter(func(p): return not p.def.tags.has("ground"))

	if new_piece.def.tags.has("level") and parent_piece != null and parent_piece.def.tags.has("level"):
		var parent_y: float = parent_piece.transform.origin.y
		other_pieces = other_pieces.filter(func(p):
			return not (p.def.tags.has("level") and p.transform.origin.y <= parent_y)
		)

	return other_pieces.is_empty()


## Collect all pieces stacked above `piece` via topcenter socket-links, recursively.
## A piece P is "on top of" Q when P has a socket at Q's topcenter world position
## AND P's origin.y is strictly above Q's origin.y. Populates `out_set` (keyed by
## instance_id) and returns `out_list` in bottom-up removal order.
func _collect_stacked_above(
	piece: TerrainModuleInstance,
	out_set: Dictionary,
	out_list: Array
) -> void:
	if not piece.sockets.has("topcenter"):
		return
	var topcenter_socket: TerrainModuleSocket = TerrainModuleSocket.new(piece, "topcenter")
	var topcenter_pos: Vector3 = topcenter_socket.get_socket_position()
	var piece_y: float = piece.transform.origin.y
	var candidates: Array[TerrainModuleSocket] = socket_index.query_others(topcenter_pos, piece)
	for candidate_socket in candidates:
		if candidate_socket == null or candidate_socket.piece == null:
			continue
		var stacked: TerrainModuleInstance = candidate_socket.piece
		# Only remove pieces strictly above (structural dependency, not coincidental same-level).
		if stacked.transform.origin.y <= piece_y:
			continue
		var stacked_id: int = stacked.get_instance_id()
		if out_set.has(stacked_id):
			continue
		out_set[stacked_id] = true
		# Recurse depth-first so the deepest dependent is queued for removal first.
		_collect_stacked_above(stacked, out_set, out_list)
		out_list.append(stacked)


func remove_piece(piece: TerrainModuleInstance) -> void:
	_ensure_queue_tracking_current()
	var piece_deferred_keys: Dictionary = {}
	for socket_name in piece.sockets.keys():
		var deferred_key: String = _socket_queue_key_from_parts(piece, socket_name)
		piece_deferred_keys[deferred_key] = true
	var kept_deferred: Array = []
	for entry in _deferred_sockets:
		var deferred_socket: TerrainModuleSocket = entry.get("socket", null)
		var deferred_key: String = _socket_queue_key(deferred_socket)
		if piece_deferred_keys.has(deferred_key):
			continue
		kept_deferred.append(entry)
	_deferred_sockets = kept_deferred
	for deferred_key in piece_deferred_keys.keys():
		if _deferred_socket_keys.has(deferred_key):
			_deferred_socket_keys.erase(deferred_key)
	terrain_index.remove(piece)
	socket_index.remove_piece(piece)
	queue.remove_where(func(item): return item is TerrainModuleSocket and item.piece == piece)
	for socket_name in piece.sockets.keys():
		var queued_key: String = _socket_queue_key_from_parts(piece, socket_name)
		if queued_socket_keys.has(queued_key):
			queued_socket_keys.erase(queued_key)
	if piece.root and piece.root.get_parent() == terrain_parent:
		terrain_parent.remove_child(piece.root)
		piece.root.queue_free()


func get_adjacent(piece: TerrainModuleInstance) -> Dictionary[String, TerrainModuleSocket]:
	if piece.root == null:
		return {}

	var out: Dictionary[String, TerrainModuleSocket] = {}
	for socket_name: String in piece.sockets.keys():
		var s: Marker3D = piece.sockets[socket_name]
		var pos := Helper.socket_world_pos(piece.transform, s, piece.root)

		var hit := socket_index.query_other(pos, piece)
		if hit != null:
			out[socket_name] = hit
	return out


func get_adjacent_from_size(
	orig_piece_socket: TerrainModuleSocket,
	size: String
) -> Dictionary[String, TerrainModuleSocket]:
	if size == "point":
		return {"bottom": orig_piece_socket}

	var orig_piece: TerrainModuleInstance = orig_piece_socket.piece
	var orig_sock: Marker3D = orig_piece_socket.socket
	assert(orig_piece.root != null)
	assert(orig_sock != null)

	# Get test piece for this size
	var test_pieces: TerrainModuleList = test_pieces_library.get_by_tags(TagList.new([size]))
	if test_pieces.is_empty():
		push_error("No test piece found for size: " + size)
		return {}

	var test_piece_template: TerrainModule = test_pieces_library.get_random(test_pieces, true)
	var test_piece: TerrainModuleInstance = test_piece_template.spawn()
	assert(test_piece != null)
	test_piece.create()

	# Determine which socket on the test piece should attach
	var attachment_socket_name: String = Helper.get_attachment_socket_name(orig_piece_socket.socket_name)
	var attachment_socket: Marker3D = test_piece.sockets.get(attachment_socket_name, null)
	if attachment_socket == null:
		push_error("Test piece does not have attachment socket: " + attachment_socket_name)
		test_piece.destroy()
		return {}

	# Position the test piece so the attachment socket aligns with the expansion socket
	var orig_socket_pos: Vector3 = orig_piece_socket.get_socket_position()
	var attachment_local: Transform3D = Helper.to_root_tf(attachment_socket, test_piece.root)
	test_piece.set_position(orig_socket_pos - attachment_local.origin)

	# Get initial adjacency
	var adjacency: Dictionary[String, TerrainModuleSocket] = {attachment_socket_name: orig_piece_socket}

	for socket_name: String in test_piece.sockets.keys():
		if socket_name == attachment_socket_name:
			continue

		var s: Marker3D = test_piece.sockets[socket_name]
		var pos := Helper.socket_world_pos(test_piece.transform, s, test_piece.root)
		var hit := socket_index.query_other(pos, test_piece)
		if hit != null:
			var is_hit_ground = hit.piece.def.tags.has("ground")
			if orig_piece.def.tags.has("ground") and not is_hit_ground:
				var from_top_socket: bool = orig_piece_socket.socket_name.begins_with("top")
				# Ground top sockets may spawn elevated pieces that should connect to existing non-ground tiles.
				# Keep legacy behavior for non-top ground sockets.
				if not from_top_socket:
					continue

			adjacency[socket_name] = hit

	test_piece.destroy()
	return adjacency


func transform_to_socket(new_ps: TerrainModuleSocket, orig_ps: TerrainModuleSocket) -> void:
	var orig_socket_pos: Vector3 = orig_ps.get_socket_position()
	var new_socket_pos: Vector3 = new_ps.get_socket_position()
	var orig_piece_pos: Vector3 = orig_ps.get_piece_position()
	var new_piece_pos: Vector3 = new_ps.get_piece_position()

	var new_piece: TerrainModuleInstance = new_ps.piece

	# Align in XZ only (prevent tilting) by using the actual socket direction:
	# d = (piece_center -> socket_pos) projected to XZ.
	#
	# This is more robust than choosing a face normal from an AABB, especially when sockets sit
	# on edges/corners (e.g. y=0 plane), where "nearest face" is ambiguous.
	var target2 := Vector2(orig_socket_pos.x - orig_piece_pos.x, orig_socket_pos.z - orig_piece_pos.z)
	var current2 := Vector2(new_socket_pos.x - new_piece_pos.x, new_socket_pos.z - new_piece_pos.z)

	if target2.length() > 1e-6 and current2.length() > 1e-6:
		# We want the new socket to be on the opposite side of the shared point, so the two pieces
		# sit adjacent rather than overlapping.
		var desired2 := (-target2).normalized()
		current2 = current2.normalized()
		var ang_desired := atan2(desired2.y, desired2.x)
		var ang_current := atan2(current2.y, current2.x)
		# Godot's yaw sign in XZ is opposite our atan2 convention here.
		# Flipping the sign makes +X rotate toward the intended XZ direction.
		var yaw := ang_current - ang_desired
		var rot_y := Basis(Vector3.UP, yaw)
		new_piece.set_basis(rot_y * new_piece.transform.basis)

	# Recompute socket pos after rotation
	var rotated_socket_pos := new_ps.get_socket_position()

	# Translate so sockets coincide
	var new_position: Vector3 = new_piece_pos + (orig_socket_pos - rotated_socket_pos)

	new_piece.set_position(Helper.snap_vec3(new_position))

func add_piece(
	new_piece_socket: TerrainModuleSocket,
	orig_piece_socket: TerrainModuleSocket
) -> bool:
	transform_to_socket(new_piece_socket, orig_piece_socket)

	var new_piece: TerrainModuleInstance = new_piece_socket.piece
	# Block level-stack tiles whose top exceeds the player's step-height limit
	# from being placed anywhere that overlaps the player's body footprint.
	# level-stack tiles sit at y=1.0 (top y=1.5), which traps a player standing
	# on the ground tile at y=0..0.5. This check runs before replace_existing
	# removal because can_place() always returns true for replace_existing tiles.
	if new_piece.def.tags.has("level-stack") and player != null:
		# level-stack tiles are placed at y=1.0 (their surface starts at ~y=1.0
		# and extends up to ~y=1.5). Any stack whose origin is above
		# PLAYER_FEET_Y (0.5) + PLAYER_MAX_STEP_HEIGHT (0.5) = 1.0 is
		# unreachable. We use the transform origin directly because the mesh AABB
		# top may be at y=0 locally (top face flush with origin), making the
		# world-space AABB top equal to origin.y — not origin.y + thickness.
		if new_piece.transform.origin.y > PLAYER_FEET_Y + 0.01:
			var player_footprint: AABB = AABB(
				Vector3(player.global_position.x - 0.5, 0.0, player.global_position.z - 0.5),
				Vector3(1.0, 3.0, 1.0)
			)
			if new_piece.aabb.intersects(player_footprint):
				return false
	if new_piece.def.replace_existing:
		# Expand the query box slightly downward so that tiles whose top surface
		# exactly meets this piece's bottom (e.g. a level tile at y=0..0.5 vs a
		# cliff whose AABB starts at y=0.5) are found. Godot's AABB.intersects
		# is exclusive at boundaries, so without this expansion a touching tile
		# is missed and never removed.
		var replace_query_aabb := new_piece.aabb
		replace_query_aabb.position.y -= 0.1
		replace_query_aabb.size.y += 0.1
		var overlapping_pieces: Array = terrain_index.query_box(replace_query_aabb)
		if orig_piece_socket.piece != null:
			overlapping_pieces.erase(orig_piece_socket.piece)
		overlapping_pieces = overlapping_pieces.filter(func(p): return not p.def.tags.has("ground"))
		# Collect pieces stacked above each overlapping piece (e.g. a hill or grass on a
		# ground tile's topcenter that sits above the new piece's AABB and would be missed
		# by the query_box call). Gathered before any removal so the socket index is intact.
		var stacked_set: Dictionary = {}
		var stacked_to_remove: Array = []
		for piece in overlapping_pieces:
			stacked_set[piece.get_instance_id()] = true
		for piece in overlapping_pieces:
			_collect_stacked_above(piece, stacked_set, stacked_to_remove)
		for piece in overlapping_pieces:
			remove_piece(piece)
		for piece in stacked_to_remove:
			remove_piece(piece)

	var can_place_result := can_place(new_piece, orig_piece_socket.piece)

	if not can_place_result:
		return false

	terrain_parent.add_child(new_piece.root)

	register_piece(new_piece, new_piece_socket.socket_name)
	add_piece_to_queue(new_piece)

	# Remove sockets that are now linked into from the queue
	remove_linked_sockets_from_queue(new_piece_socket)

	return true



# Removed ensure_ground_coverage_around_piece - using prioritized ground expansion instead


func remove_linked_sockets_from_queue(new_piece_socket: TerrainModuleSocket) -> void:
	_ensure_queue_tracking_current()
	# Remove sockets that were linked into by the new piece from the queue
	# These are the sockets that the new piece connected to

	var new_piece: TerrainModuleInstance = new_piece_socket.piece
	var linked_sockets: Array[TerrainModuleSocket] = []
	var linked_socket_keys: Dictionary = {}

	# Find all sockets on other pieces that are at the same positions as our new piece's sockets
	for socket_name in new_piece.sockets.keys():
		var socket: Marker3D = new_piece.sockets[socket_name]
		var socket_pos := Helper.socket_world_pos(new_piece.transform, socket, new_piece.root)

		# Find any existing socket at this position (not belonging to our new piece)
		var existing_socket := socket_index.query_other(socket_pos, new_piece)
		if existing_socket != null:
			if _is_socket_expandable(existing_socket):
				linked_sockets.append(existing_socket)
				linked_socket_keys[_socket_queue_key(existing_socket)] = true

	# Remove these linked sockets from the queue
	if linked_sockets.is_empty():
		return
	queue.remove_where(
		func(item):
			if not (item is TerrainModuleSocket):
				return false
			var item_socket: TerrainModuleSocket = item
			return linked_socket_keys.has(_socket_queue_key(item_socket))
	)
	for linked_socket_key in linked_socket_keys.keys():
		if queued_socket_keys.has(linked_socket_key):
			queued_socket_keys.erase(linked_socket_key)


func load_start_tile() -> TerrainModuleInstance:
	var def : TerrainModule = TerrainModuleDefinitions.load_ground_tile()
	var initial_tile := def.spawn()
	initial_tile.set_transform(Transform3D.IDENTITY)
	var root := initial_tile.create()
	terrain_parent.add_child(root)
	return initial_tile


func _socket_queue_key(piece_socket: TerrainModuleSocket) -> String:
	if piece_socket == null:
		return ""
	return _socket_queue_key_from_parts(piece_socket.piece, piece_socket.socket_name)


func _socket_queue_key_from_parts(piece: TerrainModuleInstance, socket_name: String) -> String:
	if piece == null:
		return ""
	return str(piece.get_instance_id()) + ":" + socket_name


func _ensure_queue_tracking_current() -> void:
	if queue == null:
		queued_socket_keys.clear()
		_tracked_queue_ref = null
		return
	if queue == _tracked_queue_ref:
		return
	queued_socket_keys.clear()
	for entry in queue.heap:
		if not (entry is Dictionary):
			continue
		if not entry.has("item"):
			continue
		var item: Variant = entry["item"]
		if not (item is TerrainModuleSocket):
			continue
		var key: String = _socket_queue_key(item)
		if key == "":
			continue
		queued_socket_keys[key] = true
	_tracked_queue_ref = queue


func _mark_socket_dequeued(piece_socket: TerrainModuleSocket) -> void:
	var queue_key: String = _socket_queue_key(piece_socket)
	if queue_key == "":
		return
	if queued_socket_keys.has(queue_key):
		queued_socket_keys.erase(queue_key)


func _enqueue_socket(piece_socket: TerrainModuleSocket, priority: float) -> bool:
	_ensure_queue_tracking_current()
	var queue_key: String = _socket_queue_key(piece_socket)
	if queue_key == "":
		return false
	if queued_socket_keys.has(queue_key):
		return false
	queue.push(piece_socket, priority)
	queued_socket_keys[queue_key] = true
	return true


func _stage_deferred_socket(piece_socket: TerrainModuleSocket, distance: float) -> void:
	var queue_key: String = _socket_queue_key(piece_socket)
	if queue_key == "":
		return
	if _deferred_socket_keys.has(queue_key):
		return
	_deferred_socket_keys[queue_key] = true
	_deferred_sockets.append({"socket": piece_socket, "distance": distance})


func _flush_deferred_sockets() -> void:
	for entry in _deferred_sockets:
		var piece_socket: TerrainModuleSocket = entry.get("socket", null)
		var distance: float = float(entry.get("distance", 0.0))
		_enqueue_socket(piece_socket, distance)
	_deferred_sockets.clear()
	_deferred_socket_keys.clear()
