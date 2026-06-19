class_name WaterRule
extends TerrainGenerationRule

## Carves rivers and lakes out of the ground plane.
##
## The water field (Helper.is_water) deterministically marks tile positions as
## water. When a plain ground tile is placed on a water position, this rule
## swaps it for a water tile. Land tiles adjacent to water are retiled to bank
## variants — the cliff scenes placed at ground depth, rotated so the rock
## wall faces the water — and back to plain ground when the water disappears
## from their neighbourhood. Islands and river bends fall out of the field
## shape; the canonical-rotation machinery mirrors CliffEdgeRule.

const CARDINAL_SOCKETS: Array[String] = ["front", "right", "back", "left"]
const DIAGONAL_SOCKETS: Array[String] = ["frontright", "backright", "backleft", "frontleft"]
const SAME_LEVEL_EPS: float = 0.1

# Canonical water-facing sides per variant ("missing" = water side).
const CANONICAL_MISSING_BY_TAG: Dictionary[String, Array] = {
	"ground-plain": [],
	"bank-side": ["front"],
	"bank-line": ["front", "back"],
	"bank-corner": ["front", "left"],
	"bank-peninsula": ["front", "back", "left"],
	"bank-island": ["front", "right", "back", "left"],
	"bank-inner-corner": ["frontleft"],
	"bank-inner-corner-diag": ["frontleft", "backright"],
	"bank-inner-corner-side": ["frontleft", "backleft"],
	"bank-inner-corner-edge1": ["frontleft", "back"],
	"bank-inner-corner-edge2": ["frontleft", "right"],
	"bank-inner-corner-edge-both": ["frontleft", "back", "right"],
	"bank-inner-corner-side-edge": ["frontleft", "backleft", "right"],
	"bank-inner-corner-three": ["frontleft", "backleft", "backright"],
	"bank-inner-corner-all": ["frontright", "backright", "backleft", "frontleft"]
}
const INNER_CORNER_CARDINALS_BY_DIAGONAL: Dictionary[String, Array] = {
	"frontleft": ["front", "left"],
	"frontright": ["front", "right"],
	"backright": ["back", "right"],
	"backleft": ["back", "left"]
}
const BANK_TAG_ORDER: Array[String] = [
	"ground-plain",
	"bank-side",
	"bank-line",
	"bank-corner",
	"bank-peninsula",
	"bank-island",
	"bank-inner-corner",
	"bank-inner-corner-diag",
	"bank-inner-corner-side",
	"bank-inner-corner-edge1",
	"bank-inner-corner-edge2",
	"bank-inner-corner-edge-both",
	"bank-inner-corner-side-edge",
	"bank-inner-corner-three",
	"bank-inner-corner-all"
]


func matches(context: Dictionary) -> bool:
	var chosen_piece: TerrainModuleInstance = context.get("chosen_piece", null)
	if chosen_piece == null:
		return false
	# Base-plane tiles only: plain ground, banks, and water carry the bare
	# "ground" or "water" tag; cliffs and levels do not.
	return chosen_piece.def.tags.has("ground") or chosen_piece.def.tags.has("water")


func apply(context: Dictionary) -> Dictionary:
	var chosen_piece: TerrainModuleInstance = context["chosen_piece"]
	var socket_index: PositionIndex = context.get("socket_index", null)
	var terrain_index: TerrainIndex = context.get("terrain_index", null)
	var library: TerrainModuleLibrary = context.get("library", null)
	var world_seed: int = int(context.get("world_seed", 0))
	var piece_updates: Dictionary = {}
	if socket_index == null or terrain_index == null or library == null:
		return {"chosen_piece": chosen_piece, "piece_updates": piece_updates}

	var chosen_replacement: TerrainModuleInstance = chosen_piece
	# Swap a plain ground tile on a water-field position for a water tile.
	if (
		chosen_piece.def.tags.has("ground-plain")
		and Helper.is_water(chosen_piece.transform.origin, world_seed)
	):
		chosen_replacement = _create_water_replacement(chosen_piece, library)

	# Cheap exit for the overwhelmingly common case: nothing watery nearby —
	# neither placed water pieces nor ungenerated field-water positions (banks
	# are pre-tiled toward those so the wall is already there when the water
	# tile arrives).
	var chosen_is_water: bool = chosen_replacement.def.tags.has("water")
	if (
		not chosen_is_water
		and not _has_any_water_neighbor(chosen_piece, socket_index, terrain_index, world_seed)
		and not _field_water_near(chosen_piece, world_seed)
	):
		return {"chosen_piece": chosen_replacement, "piece_updates": piece_updates}

	# Reclassify the neighbourhood: the chosen tile plus two rings of
	# base-plane neighbours (their water adjacency may have changed).
	var affected: Array[TerrainModuleInstance] = []
	var seen: Dictionary = {}
	_add_unique_piece(affected, seen, chosen_replacement)
	var direct_neighbors: Array[TerrainModuleInstance] = _get_base_neighbors(
		chosen_piece, socket_index, terrain_index
	)
	for neighbor_piece in direct_neighbors:
		_add_unique_piece(affected, seen, neighbor_piece)
	for neighbor_piece in direct_neighbors:
		for indirect in _get_base_neighbors(neighbor_piece, socket_index, terrain_index):
			_add_unique_piece(affected, seen, indirect)

	for affected_piece in affected:
		if affected_piece.def.tags.has("water"):
			continue
		# The swapped-in water tile replaces chosen_piece via chosen_replacement;
		# classify everything else by its water-facing sides.
		if affected_piece == chosen_replacement and chosen_is_water:
			continue
		# A neighbour that is itself ground-plain on a water-field position must
		# become a water tile too, not a bank — regardless of processing order.
		# (When the heightfield places all ground tiles at once and then runs rules,
		# a border tile may be processed before the water-cell tile and classify it
		# as a bank via piece_updates; this guard ensures it becomes water instead.)
		if (
			affected_piece.def.tags.has("ground-plain")
			and Helper.is_water(affected_piece.transform.origin, world_seed)
		):
			var water_replacement: TerrainModuleInstance = _create_water_replacement(
				affected_piece, library
			)
			if affected_piece == chosen_replacement:
				chosen_replacement = water_replacement
			elif water_replacement != affected_piece:
				piece_updates[affected_piece] = water_replacement
			continue
		var missing: Array[String] = _water_sides_for_piece(
			affected_piece, socket_index, terrain_index, world_seed
		)
		var target_tag: String = _tag_for_missing_sockets(missing)
		var steps_to_align: int = _rotation_steps_to_align_canonical(target_tag, missing)
		var replacement: TerrainModuleInstance = _create_replacement_for_target(
			affected_piece, target_tag, steps_to_align, library
		)
		# Nothing may sit on a bank (its topcenter is blocking going forward,
		# but a level or hill may have grown onto the tile before the water
		# arrived).
		if target_tag != "ground-plain":
			for stacked in _structures_above(affected_piece, terrain_index):
				piece_updates[stacked] = null
		if affected_piece == chosen_replacement:
			chosen_replacement = replacement
		elif replacement != affected_piece:
			piece_updates[affected_piece] = replacement
	return {"chosen_piece": chosen_replacement, "piece_updates": piece_updates}


## Structures (level or hill tiles) on top of this base tile, plus anything
## riding them. Queried over the full 24x24 footprint, not just the tile
## center: levels are co-located with the base tile origin, but hills spawn
## from edge foliage sockets and sit at offsets — a 1x1 center box misses
## them entirely. The column reaches the full hill-stack height (hills stack
## on hills), and elevated displaceable decorations (grass on a doomed hill)
## are included too or they'd be left floating; deco at the bank's own top
## (dy < 1.5) is legitimate shore vegetation and stays.
func _structures_above(
	piece: TerrainModuleInstance, terrain_index: TerrainIndex
) -> Array[TerrainModuleInstance]:
	var out: Array[TerrainModuleInstance] = []
	var o: Vector3 = piece.transform.origin
	var query_box: AABB = AABB(o + Vector3(-11.5, -0.2, -11.5), Vector3(23.0, 12.0, 23.0))
	for hit in terrain_index.query_box(query_box):
		if not (hit is TerrainModuleInstance) or hit == piece:
			continue
		var delta: Vector3 = hit.transform.origin - o
		if absf(delta.x) > 11.9 or absf(delta.z) > 11.9 or delta.y < -0.2 or delta.y > 11.0:
			continue
		if hit.def.tags.has("level") or hit.def.tags.has("hill"):
			out.append(hit)
		elif hit.def.displaceable and delta.y > 1.5:
			out.append(hit)
	return out


func _create_water_replacement(
	source_piece: TerrainModuleInstance, library: TerrainModuleLibrary
) -> TerrainModuleInstance:
	var water_modules: TerrainModuleList = library.get_by_tags(TagList.new(["water"]))
	if water_modules.is_empty():
		return source_piece
	var replacement: TerrainModuleInstance = water_modules.library[0].spawn()
	replacement.set_transform(source_piece.transform)
	replacement.create()
	return replacement


func _has_any_water_neighbor(
	piece: TerrainModuleInstance,
	socket_index: PositionIndex,
	terrain_index: TerrainIndex,
	world_seed: int
) -> bool:
	for socket_name in CARDINAL_SOCKETS:
		if _water_at_cardinal(piece, socket_name, socket_index, world_seed):
			return true
	for socket_name in DIAGONAL_SOCKETS:
		if _get_diagonal_water_piece(piece, socket_name, terrain_index, world_seed) != null:
			return true
	return false


## Field lookahead for the cheap exit: any of the 8 neighbouring tile centers
## on a water-field position means classification must run even when no water
## piece has been generated there yet.
func _field_water_near(piece: TerrainModuleInstance, world_seed: int) -> bool:
	for socket_name in CARDINAL_SOCKETS:
		if not piece.sockets.has(socket_name):
			continue
		if Helper.is_water(_adjacent_center(piece, socket_name), world_seed):
			return true
	for socket_name in DIAGONAL_SOCKETS:
		var target: Variant = _diagonal_target_center(piece, socket_name)
		if target is Vector3 and Helper.is_water(target, world_seed):
			return true
	return false


## A piece counts as water if it is a water tile, or a plain ground tile
## sitting on a field-water position. The rule always swaps the latter at
## placement time, but while THIS apply() runs for it, the registered piece
## in the indices is still the plain ground instance — neighbours classified
## in the same pass must already see it as water, or they keep (or get
## downgraded to) wall-less variants beside the new water tile.
func _piece_counts_as_water(piece: TerrainModuleInstance, world_seed: int) -> bool:
	if piece == null or piece.def == null:
		return false
	if piece.def.tags.has("water"):
		return true
	return (
		piece.def.tags.has("ground-plain")
		and Helper.is_water(piece.transform.origin, world_seed)
	)


## The chosen piece's water-facing sides: cardinals adjacent to a water tile,
## plus inner-corner diagonals (diagonal is water while both touching
## cardinals are land). Positions the field marks as water but that are not
## yet generated also count — the bank must face them when they arrive.
func _water_sides_for_piece(
	piece: TerrainModuleInstance,
	socket_index: PositionIndex,
	terrain_index: TerrainIndex,
	world_seed: int
) -> Array[String]:
	var water_cardinals: Array[String] = []
	var cardinal_is_water: Dictionary[String, bool] = {}
	for socket_name in CARDINAL_SOCKETS:
		var is_water_side: bool = _water_at_cardinal(piece, socket_name, socket_index, world_seed)
		if not is_water_side and not _cardinal_occupied(piece, socket_name, socket_index):
			is_water_side = Helper.is_water(_adjacent_center(piece, socket_name), world_seed)
		cardinal_is_water[socket_name] = is_water_side
		if is_water_side:
			water_cardinals.append(socket_name)
	var water_inner_diagonals: Array[String] = []
	for socket_name in DIAGONAL_SOCKETS:
		var required_cardinals: Array = INNER_CORNER_CARDINALS_BY_DIAGONAL.get(socket_name, [])
		if required_cardinals.size() != 2:
			continue
		if cardinal_is_water.get(required_cardinals[0], false):
			continue
		if cardinal_is_water.get(required_cardinals[1], false):
			continue
		var diagonal_water: bool = (
			_get_diagonal_water_piece(piece, socket_name, terrain_index, world_seed) != null
		)
		if not diagonal_water:
			var target: Variant = _diagonal_target_center(piece, socket_name)
			if target is Vector3 and not _position_occupied(target, terrain_index):
				diagonal_water = Helper.is_water(target, world_seed)
		if diagonal_water:
			water_inner_diagonals.append(socket_name)
	return water_cardinals + water_inner_diagonals


func _water_at_cardinal(
	piece: TerrainModuleInstance,
	socket_name: String,
	socket_index: PositionIndex,
	world_seed: int
) -> bool:
	if not piece.sockets.has(socket_name):
		return false
	var piece_socket: TerrainModuleSocket = TerrainModuleSocket.new(piece, socket_name)
	var other: TerrainModuleSocket = socket_index.query_other(
		piece_socket.get_socket_position(), piece
	)
	return other != null and _piece_counts_as_water(other.piece, world_seed)


func _cardinal_occupied(
	piece: TerrainModuleInstance, socket_name: String, socket_index: PositionIndex
) -> bool:
	if not piece.sockets.has(socket_name):
		return false
	var piece_socket: TerrainModuleSocket = TerrainModuleSocket.new(piece, socket_name)
	return socket_index.query_other(piece_socket.get_socket_position(), piece) != null


## Center of the tile adjacent to `piece` across `socket_name`.
func _adjacent_center(piece: TerrainModuleInstance, socket_name: String) -> Vector3:
	var center: Vector3 = piece.transform.origin
	var socket_pos: Vector3 = TerrainModuleSocket.new(piece, socket_name).get_socket_position()
	var offset: Vector3 = socket_pos - center
	offset.y = 0.0
	return center + offset * 2.0


func _position_occupied(center: Vector3, terrain_index: TerrainIndex) -> bool:
	var query_box: AABB = AABB(center + Vector3(-0.6, -0.5, -0.6), Vector3(1.2, 1.0, 1.2))
	for hit in terrain_index.query_box(query_box):
		if hit is TerrainModuleInstance:
			return true
	return false


func _get_base_neighbors(
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
			piece_socket.get_socket_position(), piece
		)
		if other == null or other.piece == null:
			continue
		if not _is_base_piece(other.piece):
			continue
		if seen.has(other.piece):
			continue
		seen[other.piece] = true
		neighbors.append(other.piece)
	for socket_name in DIAGONAL_SOCKETS:
		var diagonal_piece: TerrainModuleInstance = _get_diagonal_base_piece(
			piece, socket_name, terrain_index
		)
		if diagonal_piece == null or seen.has(diagonal_piece):
			continue
		seen[diagonal_piece] = true
		neighbors.append(diagonal_piece)
	return neighbors


func _is_base_piece(piece: TerrainModuleInstance) -> bool:
	return piece.def.tags.has("ground") or piece.def.tags.has("water")


func _get_diagonal_water_piece(
	piece: TerrainModuleInstance,
	diagonal_socket_name: String,
	terrain_index: TerrainIndex,
	world_seed: int
) -> TerrainModuleInstance:
	var diagonal_piece: TerrainModuleInstance = _get_diagonal_base_piece(
		piece, diagonal_socket_name, terrain_index
	)
	if diagonal_piece != null and _piece_counts_as_water(diagonal_piece, world_seed):
		return diagonal_piece
	return null


func _get_diagonal_base_piece(
	piece: TerrainModuleInstance, diagonal_socket_name: String, terrain_index: TerrainIndex
) -> TerrainModuleInstance:
	var diagonal_target: Variant = _diagonal_target_center(piece, diagonal_socket_name)
	if not (diagonal_target is Vector3):
		return null
	var target_pos: Vector3 = diagonal_target
	var query_box: AABB = AABB(target_pos + Vector3(-0.6, -0.5, -0.6), Vector3(1.2, 1.0, 1.2))
	for hit in terrain_index.query_box(query_box):
		if not (hit is TerrainModuleInstance):
			continue
		var other: TerrainModuleInstance = hit
		if other == piece or not _is_base_piece(other):
			continue
		if absf(other.transform.origin.y - piece.transform.origin.y) > SAME_LEVEL_EPS:
			continue
		var delta: Vector3 = other.transform.origin - target_pos
		if absf(delta.x) <= 0.6 and absf(delta.z) <= 0.6:
			return other
	return null


## Diagonal tile-center derived from two cardinal sockets (cliff scenes lack
## some diagonal markers on certain variants; this works for all of them).
func _diagonal_target_center(piece: TerrainModuleInstance, diagonal_socket_name: String) -> Variant:
	var required_cardinals: Array = INNER_CORNER_CARDINALS_BY_DIAGONAL.get(diagonal_socket_name, [])
	if required_cardinals.size() != 2:
		return null
	if not piece.sockets.has(required_cardinals[0]) or not piece.sockets.has(required_cardinals[1]):
		return null
	var center: Vector3 = piece.transform.origin
	var first_pos: Vector3 = TerrainModuleSocket.new(piece, required_cardinals[0]).get_socket_position()
	var second_pos: Vector3 = TerrainModuleSocket.new(piece, required_cardinals[1]).get_socket_position()
	return center + ((first_pos - center) + (second_pos - center)) * 2.0


func _create_replacement_for_target(
	source_piece: TerrainModuleInstance,
	target_tag: String,
	steps_to_align: int,
	library: TerrainModuleLibrary
) -> TerrainModuleInstance:
	var existing_tag: String = _current_bank_tag(source_piece.def)
	if existing_tag == target_tag and steps_to_align == 0:
		return source_piece
	var matches_list: TerrainModuleList = library.get_by_tags(TagList.new([target_tag]))
	if matches_list.is_empty():
		return source_piece
	var module_template: TerrainModule = matches_list.library[0]
	if module_template == source_piece.def and steps_to_align == 0:
		return source_piece
	var replacement: TerrainModuleInstance = module_template.spawn()
	replacement.set_transform(source_piece.transform)
	replacement.create()
	if steps_to_align >= 0:
		# The water-side set was computed in the source's local frame, so the
		# canonical alignment yaw composes with the source's basis.
		var yaw: float = PI * 0.5 * float((4 - steps_to_align) % 4)
		replacement.set_basis(Basis(Vector3.UP, yaw) * replacement.transform.basis)
	return replacement


func _current_bank_tag(module_def: TerrainModule) -> String:
	if module_def == null:
		return ""
	for bank_tag in BANK_TAG_ORDER:
		if module_def.tags.has(bank_tag):
			return bank_tag
	return ""


func _tag_for_missing_sockets(missing_sockets: Array[String]) -> String:
	for bank_tag in BANK_TAG_ORDER:
		if _rotation_steps_to_align_canonical(bank_tag, missing_sockets) >= 0:
			return bank_tag
	return "ground-plain"


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


func _add_unique_piece(
	pieces: Array[TerrainModuleInstance],
	seen: Dictionary,
	piece: TerrainModuleInstance
) -> void:
	if piece == null or seen.has(piece):
		return
	seen[piece] = true
	pieces.append(piece)
