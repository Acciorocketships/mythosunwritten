extends GutTest

## Regression: decorations spawning inside a cliff plateau's volume.
##
## Cliff INTERIOR tiles (the retile target once a plateau tile is fully
## surrounded) must author the same full-storey logical bounds as the edge
## variants. With the historical thin slab-at-the-top bounds, the storey
## volume below the walkable top was unindexed, so a ground tile's deferred
## foliage sockets (still queued from before the mountain grew over the tile)
## passed can_place and planted trees inside the mesa, poking out of the
## plateau top.

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
	g.socket_index = PositionIndex.new()
	add_child(g.player)
	add_child(g.terrain_parent)
	_nodes_to_free.append(g.player)
	_nodes_to_free.append(g.terrain_parent)
	_nodes_to_free.append(g.socket_index)
	g.terrain_index = TerrainIndex.new()
	# Keep the player far away so the player-overlap rejection never triggers.
	g.player.global_position = Vector3(10000, 0, 10000)
	return g


func _spawn_registered(gen: Variant, def: TerrainModule, pos: Vector3) -> TerrainModuleInstance:
	var piece: TerrainModuleInstance = def.spawn()
	piece.set_transform(Transform3D(Basis.IDENTITY, pos))
	piece.create()
	_pieces_to_destroy.append(piece)
	gen.terrain_parent.add_child(piece.root)
	gen.register_piece(piece, "")
	return piece


func test_cliff_interior_bounds_cover_the_full_storey() -> void:
	for def in TerrainModuleDefinitions.load_cliff_variants():
		if not def.tags.has("cliff-interior"):
			continue
		assert_almost_eq(
			def.size.position.y, -4.0, 0.001,
			"%s bounds must reach the storey bottom" % str(def.tags.tags)
		)
		assert_almost_eq(
			def.size.size.y, 4.0, 0.001,
			"%s bounds must cover the full 4u storey volume" % str(def.tags.tags)
		)


func test_deco_cannot_be_placed_inside_a_cliff_interior_volume() -> void:
	var gen: Variant = _new_generator()
	# Ground tile at origin with a cliff-interior tile one storey above it —
	# the state after a mountain grows over a ground tile and the plateau tile
	# retiles to interior (retiles keep the transform: base tier origin y=4).
	var ground: TerrainModuleInstance = _spawn_registered(
		gen, TerrainModuleDefinitions.load_ground_tile(), Vector3.ZERO
	)
	var interior_def: TerrainModule = null
	for def in TerrainModuleDefinitions.load_cliff_variants():
		if def.tags.has("cliff-interior") and def.tags.has("cliff-base"):
			interior_def = def
			break
	assert_not_null(interior_def, "library must contain the base cliff interior tile")
	_spawn_registered(gen, interior_def, Vector3(0, 4, 0))

	# A tree on one of the buried ground tile's foliage socket positions.
	var tree: TerrainModuleInstance = TerrainModuleDefinitions.load_tree_tile().spawn()
	tree.set_transform(Transform3D(Basis.IDENTITY, Vector3(6, 0, 6)))
	tree.create()
	_pieces_to_destroy.append(tree)
	assert_false(
		gen.can_place(tree, ground),
		"a decoration must not be placeable inside the plateau volume"
	)
