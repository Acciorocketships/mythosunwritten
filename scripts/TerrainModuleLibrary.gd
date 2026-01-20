class_name TerrainModuleLibrary
extends Node


var terrain_modules: TerrainModuleList = TerrainModuleList.new()
var modules_by_tag: Dictionary[String, TerrainModuleList] = {}


func init() -> void:
	load_terrain_modules()
	sort_terrain_modules()


func load_terrain_modules() -> void:
	terrain_modules.append(load_ground_tile())
	terrain_modules.append(load_grass_tile())
	terrain_modules.append(load_bush_tile())
	terrain_modules.append(load_rock_tile())
	terrain_modules.append(load_tree_tile())
	terrain_modules.append(load_8x2x8_tile())


### Individual Terrain Modules ###


func load_ground_tile() -> TerrainModule:
	var top_fill_prob: float = 0.05
	var scene = load("res://terrain/scenes/GroundTile.tscn")
	var tags: TagList = TagList.new(["ground", "24x24"])
	var tags_per_socket: Dictionary[String, TagList] = {}
	var bb: AABB = Helper.compute_scene_mesh_aabb(scene)

	var socket_size: Dictionary[String, Distribution] = {
		"main": Distribution.new({"24x24": 1.0}),
		"back": Distribution.new({"24x24": 1.0}),
		"right": Distribution.new({"24x24": 1.0}),
		"left": Distribution.new({"24x24": 1.0}),
	}
	var socket_required: Dictionary[String, TagList] = {
		"main": TagList.new(["ground"]),
		"back": TagList.new(["ground"]),
		"right": TagList.new(["ground"]),
		"left": TagList.new(["ground"]),
	}
	var socket_fill_prob: Dictionary[String, float] = {
		"main": 1.0,
		"back": 1.0,
		"right": 1.0,
		"left": 1.0,
		"topfront": top_fill_prob,
		"topback": top_fill_prob,
		"topleft": top_fill_prob,
		"topright": top_fill_prob,
		"topfrontright": top_fill_prob,
		"topfrontleft": top_fill_prob,
		"topbackright": top_fill_prob,
		"topbackleft": top_fill_prob,
		"topcenter": top_fill_prob,
	}
	var dist1: Distribution = Distribution.new({"ground": 1.0})
	var dist2: Distribution = Distribution.new({"grass": 0.15, "rock": 0.1, "bush": 0.15,  "tree": 0.2, "hill": 0.4})
	var socket_tag_prob: Dictionary[String, Distribution] = {
		"main": dist1,
		"back": dist1,
		"right": dist1,
		"left": dist1,
		"topfront": dist2,
		"topback": dist2,
		"topleft": dist2,
		"topright": dist2,
		"topfrontright": dist2,
		"topfrontleft": dist2,
		"topbackright": dist2,
		"topbackleft": dist2,
		"topcenter": dist2,
	}

	return TerrainModule.new(
		scene,
		bb,
		tags,
		tags_per_socket,
		[],
		socket_size,
		socket_required,
		socket_fill_prob,
		socket_tag_prob
	)

func load_grass_tile() -> TerrainModule:
	var scene = load("res://terrain/scenes/Grass1.tscn")
	var tags: TagList = TagList.new(["grass", "rotate"])
	# Compute bounds from the mesh instead of manually authoring.
	var bb: AABB = Helper.compute_scene_mesh_aabb(scene)
	var visual_variants: Array[PackedScene] = [load("res://terrain/scenes/Grass2.tscn")]

	return TerrainModule.new(
		scene,
		bb,
		tags,
		{},
		visual_variants
	)
	
func load_bush_tile() -> TerrainModule:
	var scene = load("res://terrain/scenes/Bush1.tscn")
	var tags: TagList = TagList.new(["bush", "rotate"])
	# Compute bounds from the mesh instead of manually authoring.
	var bb: AABB = Helper.compute_scene_mesh_aabb(scene)
	var visual_variants: Array[PackedScene] = []

	return TerrainModule.new(
		scene,
		bb,
		tags,
		{},
		visual_variants
	)
	
func load_rock_tile() -> TerrainModule:
	var scene = load("res://terrain/scenes/Rock1.tscn")
	var tags: TagList = TagList.new(["rock", "rotate"])
	var bb: AABB = Helper.compute_scene_mesh_aabb(scene)
	var visual_variants: Array[PackedScene] = []

	return TerrainModule.new(
		scene,
		bb,
		tags,
		{},
		visual_variants
	)
	
func load_tree_tile() -> TerrainModule:
	var scene = load("res://terrain/scenes/Tree1.tscn")
	var tags: TagList = TagList.new(["tree", "rotate"])
	var bb: AABB = Helper.compute_scene_mesh_aabb(scene)
	var visual_variants: Array[PackedScene] = []

	return TerrainModule.new(
		scene,
		bb,
		tags,
		{},
		visual_variants
	)

func load_8x2x8_tile() -> TerrainModule:
	var scene = load("res://terrain/scenes/Hill_8x2x8.tscn")
	var tags: TagList = TagList.new(["hill", "8x8"])
	var tags_per_socket: Dictionary[String, TagList] = {}
	var bb: AABB = Helper.compute_scene_mesh_aabb(scene)

	var socket_size: Dictionary[String, Distribution] = {
		"topcenter": Distribution.new({"point": 1.0}),
	}
	var socket_required: Dictionary[String, TagList] = {}
	var socket_fill_prob: Dictionary[String, float] = {
		"topcenter": 0.5,
	}
	var socket_tag_prob: Dictionary[String, Distribution] = {
		"topcenter": Distribution.new({"grass": 1.0}),
	}

	return TerrainModule.new(
		scene,
		bb,
		tags,
		tags_per_socket,
		[],
		socket_size,
		socket_required,
		socket_fill_prob,
		socket_tag_prob
	)


## Class Functions ##


func sort_terrain_modules() -> void:
	modules_by_tag.clear()
	for module: TerrainModule in terrain_modules:
		for tag: String in module.tags:
			if not modules_by_tag.has(tag):
				modules_by_tag[tag] = TerrainModuleList.new()
			modules_by_tag[tag].library.append(module)
		for socket_name: String in module.tags_per_socket:
			for tag: String in module.tags_per_socket[socket_name]:
				var tag_combined : String = combined_tag_socket_name(tag, socket_name)
				if not modules_by_tag.has(tag_combined):
					modules_by_tag[tag_combined] = TerrainModuleList.new()
				modules_by_tag[tag_combined].library.append(module)


func get_required_tags(adjacent: Dictionary[String, TerrainModuleSocket]) -> TagList:
	var out: TagList = TagList.new()
	for socket_name: String in adjacent.keys():
		var piece_socket: TerrainModuleSocket = adjacent[socket_name]
		var adjacent_piece: TerrainModuleInstance = piece_socket.piece
		var adjacent_socket_name: String = piece_socket.socket_name
		# Safe lookup: some modules may not define tag requirements for every possible socket name.
		var has_key: bool = adjacent_piece.def.socket_required.has(adjacent_socket_name)
		if not has_key:
			continue
		var adjacent_required_tags: TagList = adjacent_piece.def.socket_required.get(
			adjacent_socket_name,
			TagList.new()
		)
		var tag_list = convert_tag_list(adjacent_required_tags, socket_name)
		out = out.union(tag_list)
	return out


func get_combined_distribution(adjacent: Dictionary[String, TerrainModuleSocket]) -> Distribution:
	var dist_set: Array[Distribution] = []
	for socket_name: String in adjacent.keys():
		var piece_socket: TerrainModuleSocket = adjacent[socket_name]
		var adjacent_piece: TerrainModuleInstance = piece_socket.piece
		var adjacent_socket_name: String = piece_socket.socket_name
		# Safe lookup for socket distributions
		if not adjacent_piece.def.socket_tag_prob.has(adjacent_socket_name):
			print(
				"[TerrainModuleLibrary.get_combined_distribution] missing key '",
				adjacent_socket_name,
				"' in socket_tag_prob; available=",
				adjacent_piece.def.socket_tag_prob.keys()
			)
			continue
		var disti: Distribution = adjacent_piece.def.socket_tag_prob.get(
			adjacent_socket_name,
			Distribution.new()
		)
		dist_set.append(disti)
	assert(dist_set.size() > 0)
	if dist_set.size() == 1:
		return dist_set[0]
	var out_dist: Distribution = Distribution.new()
	for disti: Distribution in dist_set:
		var new_dist = Distribution.new(out_dist.dist)
		new_dist.dist.merge(disti.dist)
		for tag: String in new_dist:
			var disti_tag_prob: float = disti.prob(tag)
			var orig_tag_prob: float = out_dist.prob(tag)
			var new_prob: float = disti_tag_prob * orig_tag_prob
			new_dist.set_prob(tag, new_prob)
		new_dist.normalise()
		out_dist = new_dist
	return out_dist


func sample_from_modules(modules: TerrainModuleList, dist: Distribution) -> TerrainModule:
	var sampled_tag: String = dist.sample()
	var filtered_modules: TerrainModuleList = filter_module_list(modules, sampled_tag)
	assert(!filtered_modules.is_empty())
	var chosen_module = get_random(filtered_modules)
	return chosen_module


func get_by_tags(tags: TagList) -> TerrainModuleList:
	if tags.is_empty():
		return terrain_modules.copy()
	var sets: Array[TerrainModuleList] = []
	for tag in tags:
		if not modules_by_tag.has(tag):
			return TerrainModuleList.new()
		sets.append(modules_by_tag[tag])
	return _intersection(sets)


func get_random(modules: TerrainModuleList, first: bool = false) -> TerrainModule:
	if modules.is_empty():
		return null
	var idx : int = 0
	if not first:
		idx = randi_range(0, modules.size() - 1)
	var module: TerrainModule = modules.library[idx]
	return module


func filter_module_list(modules: TerrainModuleList, tag: String) -> TerrainModuleList:
	if not modules_by_tag.has(tag):
		return TerrainModuleList.new()
	return _intersection([modules, modules_by_tag[tag]])


func _intersection(sets: Array[TerrainModuleList]) -> TerrainModuleList:
	sets = sets.duplicate()
	if sets.is_empty():
		return TerrainModuleList.new()
	# pick smallest set
	var min_i := 0
	var min_size := INF
	for i in range(sets.size()):
		var s: TerrainModuleList = sets[i]
		if s.size() < min_size:
			min_size = s.size()
			min_i = i
	# populate out with smallest set
	var out: Dictionary[TerrainModule, Variant] = {}
	for element: TerrainModule in sets[min_i].library:
		out[element] = true
	sets.remove_at(min_i)
	# for every other set, make sure every element in out is in those sets
	for s : TerrainModuleList in sets:
		for element in out.keys():
			if element not in s.library:
				out.erase(element)
	# return intersection as a TerrainModuleList
	var out_list: TerrainModuleList = TerrainModuleList.new(out.keys())
	return out_list


func convert_tag_list(tag_list: TagList, socket_name: String) -> TagList:
	for i: int in range(tag_list.size()):
		var tag: String = tag_list.tags[i]
		if tag[0] == "!":
			tag_list.tags[i] = combined_tag_socket_name(tag.substr(1), socket_name)
	return tag_list


func combined_tag_socket_name(tag: String, socket_name: String) -> String:
	return "[%s]%s" % [socket_name, tag]
