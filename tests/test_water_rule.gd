extends GutTest

## WaterRule regression tests.
##
## The critical ordering case: when a water-field position is generated, the
## chosen piece is a plain ground tile that is ALREADY registered in the
## indices while the rule classifies its neighbours — the swap to a water tile
## happens after apply() returns. Neighbour classification must treat that
## transient ground-plain-on-a-water-position as water, or existing land tiles
## beside it keep (or get downgraded to) wall-less variants, leaving a hole
## down to the water along the shore.

var _pieces_to_destroy: Array[TerrainModuleInstance] = []
var _nodes_to_free: Array[Node] = []


func before_each() -> void:
	_pieces_to_destroy.clear()
	_nodes_to_free.clear()


func after_each() -> void:
	for p: TerrainModuleInstance in _pieces_to_destroy:
		if p != null and p.root != null and is_instance_valid(p.root):
			if p.root.get_parent() != null:
				p.root.get_parent().remove_child(p.root)
			p.root.free()
	_pieces_to_destroy.clear()
	for n: Node in _nodes_to_free:
		if is_instance_valid(n):
			if n.get_parent() != null:
				n.get_parent().remove_child(n)
			n.free()
	_nodes_to_free.clear()


func _new_generator() -> Variant:
	var Generator: Script = load("res://scripts/terrain/TerrainGenerator.gd")
	var g: Variant = Generator.new()
	_nodes_to_free.append(g)
	g.player = Node3D.new()
	g.terrain_parent = Node3D.new()
	g.library = TerrainModuleLibrary.new()
	g.library.init()
	g.socket_index = PositionIndex.new()
	add_child(g.player)
	add_child(g.terrain_parent)
	_nodes_to_free.append(g.player)
	_nodes_to_free.append(g.terrain_parent)
	_nodes_to_free.append(g.library)
	_nodes_to_free.append(g.socket_index)
	g.terrain_index = TerrainIndex.new()
	return g


## Find a deterministic field configuration for `world_seed`: a water position
## W whose +X neighbour P is land with W as its ONLY water-field contact
## (cardinals and diagonals), so P's expected variant is exactly bank-side.
func _find_side_config(world_seed: int) -> Dictionary:
	for ring in range(10, 200):
		for axis_positions in [
			Vector3(ring * 24, 0, 0), Vector3(-ring * 24, 0, 0),
			Vector3(0, 0, ring * 24), Vector3(0, 0, -ring * 24),
			Vector3(ring * 24, 0, ring * 12), Vector3(ring * 12, 0, -ring * 24),
		]:
			var w: Vector3 = axis_positions
			if not Helper.is_water(w, world_seed):
				continue
			var p: Vector3 = w + Vector3(24, 0, 0)
			if Helper.is_water(p, world_seed):
				continue
			var clean: bool = true
			for offset in [
				Vector3(24, 0, 0), Vector3(0, 0, 24), Vector3(0, 0, -24),
				Vector3(24, 0, 24), Vector3(24, 0, -24),
				Vector3(-24, 0, 24), Vector3(-24, 0, -24),
			]:
				if Helper.is_water(p + offset, world_seed):
					clean = false
					break
			if clean:
				return {"water": w, "land": p}
	return {}


func _spawn_ground_plain(gen: Variant, pos: Vector3) -> TerrainModuleInstance:
	var modules: TerrainModuleList = gen.library.get_by_tags(TagList.new(["ground-plain"]))
	assert_false(modules.is_empty(), "library must contain a ground-plain module")
	var piece: TerrainModuleInstance = modules.library[0].spawn()
	piece.set_transform(Transform3D(Basis.IDENTITY, pos))
	piece.create()
	_pieces_to_destroy.append(piece)
	gen.terrain_parent.add_child(piece.root)
	gen.register_piece(piece, "")
	return piece


func _spawn_bank_side_facing(gen: Variant, pos: Vector3, water_dir_socket: String) -> TerrainModuleInstance:
	var modules: TerrainModuleList = gen.library.get_by_tags(TagList.new(["bank-side"]))
	assert_false(modules.is_empty(), "library must contain a bank-side module")
	var piece: TerrainModuleInstance = modules.library[0].spawn()
	# Canonical bank-side faces "front" (+X). Rotate so it faces the water.
	var yaw: float = 0.0
	match water_dir_socket:
		"front": yaw = 0.0
		"right": yaw = -PI * 0.5
		"back": yaw = PI
		"left": yaw = PI * 0.5
	piece.set_transform(Transform3D(Basis(Vector3.UP, yaw), pos))
	piece.create()
	_pieces_to_destroy.append(piece)
	gen.terrain_parent.add_child(piece.root)
	gen.register_piece(piece, "")
	return piece


func _apply_water_rule(gen: Variant, chosen: TerrainModuleInstance, world_seed: int) -> Dictionary:
	var rule: WaterRule = WaterRule.new()
	var context: Dictionary = {
		"chosen_piece": chosen,
		"socket_index": gen.socket_index,
		"terrain_index": gen.terrain_index,
		"library": gen.library,
		"world_seed": world_seed,
	}
	assert_true(rule.matches(context), "WaterRule must match a ground-plain placement")
	var result: Dictionary = rule.apply(context)
	# Replacement instances are detached; track them for cleanup.
	var chosen_replacement: Variant = result.get("chosen_piece", null)
	if chosen_replacement is TerrainModuleInstance and chosen_replacement != chosen:
		_pieces_to_destroy.append(chosen_replacement)
	for value in result.get("piece_updates", {}).values():
		if value is TerrainModuleInstance:
			_pieces_to_destroy.append(value)
	return result


func test_water_field_config_exists_for_seed() -> void:
	var config: Dictionary = _find_side_config(12345)
	assert_false(config.is_empty(), "seed 12345 must yield a bank-side field configuration")


## Land tile exists first; the adjacent water-field position is generated
## afterwards. While the rule runs, the chosen piece at the water position is
## still the registered ground-plain instance. The existing neighbour must be
## retiled to a bank facing the new water — this is the shore-hole regression.
func test_existing_neighbor_retiled_when_water_position_generated() -> void:
	var world_seed: int = 12345
	var config: Dictionary = _find_side_config(world_seed)
	assert_false(config.is_empty(), "field configuration required")
	var gen: Variant = _new_generator()

	var land: TerrainModuleInstance = _spawn_ground_plain(gen, config["land"])
	# The chosen piece: a plain ground tile placed on the water position,
	# registered in the indices exactly as add_piece leaves it before rules run.
	var chosen: TerrainModuleInstance = _spawn_ground_plain(gen, config["water"])

	var result: Dictionary = _apply_water_rule(gen, chosen, world_seed)

	var swapped: TerrainModuleInstance = result.get("chosen_piece", null)
	assert_not_null(swapped, "rule must return a chosen piece")
	assert_true(swapped.def.tags.has("water"), "chosen piece on a water position must become water")

	var updates: Dictionary = result.get("piece_updates", {})
	assert_true(
		updates.has(land),
		"the existing land neighbour must be retiled when the water tile arrives"
	)
	var replacement: Variant = updates.get(land, null)
	assert_true(replacement is TerrainModuleInstance, "neighbour update must be a replacement piece")
	if replacement is TerrainModuleInstance:
		assert_true(
			replacement.def.tags.has("bank-side"),
			"neighbour beside a single water side must become bank-side, got: "
			+ str(replacement.def.tags.tags)
		)


## A hill that grew on the shore tile before the water arrived must be removed
## when the tile converts to a bank — hills sit at edge-socket offsets, so the
## cleanup must search the full tile footprint, not just the tile center.
func test_hill_on_converting_bank_is_removed() -> void:
	var world_seed: int = 12345
	var config: Dictionary = _find_side_config(world_seed)
	assert_false(config.is_empty(), "field configuration required")
	var gen: Variant = _new_generator()

	var land_pos: Vector3 = config["land"]
	_spawn_ground_plain(gen, land_pos)
	# A hill on the land tile, offset toward a corner like an edge-socket
	# spawn would place it.
	var hill: TerrainModuleInstance = TerrainModuleDefinitions.load_8x8x2_tile().spawn()
	hill.set_transform(Transform3D(Basis.IDENTITY, land_pos + Vector3(6, 0, 6)))
	hill.create()
	_pieces_to_destroy.append(hill)
	gen.terrain_parent.add_child(hill.root)
	gen.register_piece(hill, "")

	var chosen: TerrainModuleInstance = _spawn_ground_plain(gen, config["water"])
	var result: Dictionary = _apply_water_rule(gen, chosen, world_seed)

	var updates: Dictionary = result.get("piece_updates", {})
	assert_true(
		updates.has(hill) and updates.get(hill, "x") == null,
		"a hill on a tile converting to bank must be scheduled for removal"
	)


## A neighbour that is ALREADY the correct bank (placed earlier via field
## lookahead) must not be downgraded to plain ground while the water tile at
## the position it faces is mid-swap.
func test_existing_bank_not_downgraded_when_water_position_generated() -> void:
	var world_seed: int = 12345
	var config: Dictionary = _find_side_config(world_seed)
	assert_false(config.is_empty(), "field configuration required")
	var gen: Variant = _new_generator()

	# Water lies at -X of the land tile; in canonical socket space that is the
	# "back" side (front = +X), so rotate the bank to face back.
	var bank: TerrainModuleInstance = _spawn_bank_side_facing(gen, config["land"], "back")
	var chosen: TerrainModuleInstance = _spawn_ground_plain(gen, config["water"])

	var result: Dictionary = _apply_water_rule(gen, chosen, world_seed)

	var updates: Dictionary = result.get("piece_updates", {})
	if updates.has(bank):
		var replacement: Variant = updates.get(bank, null)
		if replacement is TerrainModuleInstance:
			assert_true(
				replacement.def.tags.has("bank-side"),
				"an already-correct bank must not be downgraded, got: "
				+ str(replacement.def.tags.tags)
			)
