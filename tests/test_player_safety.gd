extends GutTest

## Structures must never spawn overlapping the player (a hill spawning on the
## player traps them inside its collision mesh).

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
	g.queue = PriorityQueue.new()
	return g


func _spawn_ground(gen: Variant, pos: Vector3) -> TerrainModuleInstance:
	var modules: TerrainModuleList = gen.library.get_by_tags(TagList.new(["ground-plain"]))
	var piece: TerrainModuleInstance = modules.library[0].spawn()
	piece.set_transform(Transform3D(Basis.IDENTITY, pos))
	piece.create()
	_pieces_to_destroy.append(piece)
	gen.terrain_parent.add_child(piece.root)
	gen.register_piece(piece, "")
	return piece


## A hill placed via a ground foliage socket where the player stands must be
## rejected. Hill origins sit at ground height, so an origin-height exemption
## in the overlap check lets them spawn on (and trap) the player.
func test_hill_cannot_spawn_on_player() -> void:
	var gen: Variant = _new_generator()
	var ground: TerrainModuleInstance = _spawn_ground(gen, Vector3.ZERO)
	# Player stands at the corner foliage socket position.
	gen.player.global_position = Vector3(6, 0.5, 6)

	var hill: TerrainModuleInstance = TerrainModuleDefinitions.load_12x12x2_tile().spawn()
	hill.create()
	_pieces_to_destroy.append(hill)
	var new_ps: TerrainModuleSocket = TerrainModuleSocket.new(hill, "bottom")
	var orig_ps: TerrainModuleSocket = TerrainModuleSocket.new(ground, "topfrontright")
	assert_false(
		gen.add_piece(new_ps, orig_ps),
		"a hill overlapping the player must be rejected"
	)


## The same protection must hold on elevated terrain: the player footprint
## follows the player's height, it is not pinned to the ground plane.
func test_hill_cannot_spawn_on_player_on_plateau() -> void:
	var gen: Variant = _new_generator()
	# A cliff-interior plateau tile at storey height with the player on top.
	var interior_def: TerrainModule = null
	for def in TerrainModuleDefinitions.load_cliff_variants():
		if def.tags.has("cliff-interior") and def.tags.has("cliff-base"):
			interior_def = def
			break
	var plateau: TerrainModuleInstance = interior_def.spawn()
	plateau.set_transform(Transform3D(Basis.IDENTITY, Vector3(0, 4, 0)))
	plateau.create()
	_pieces_to_destroy.append(plateau)
	gen.terrain_parent.add_child(plateau.root)
	gen.register_piece(plateau, "")
	gen.player.global_position = Vector3(6, 4.5, 6)

	var hill: TerrainModuleInstance = TerrainModuleDefinitions.load_12x12x2_tile().spawn()
	hill.create()
	_pieces_to_destroy.append(hill)
	var new_ps: TerrainModuleSocket = TerrainModuleSocket.new(hill, "bottom")
	var orig_ps: TerrainModuleSocket = TerrainModuleSocket.new(plateau, "topfrontright")
	assert_false(
		gen.add_piece(new_ps, orig_ps),
		"a hill overlapping the player on a plateau must be rejected"
	)
