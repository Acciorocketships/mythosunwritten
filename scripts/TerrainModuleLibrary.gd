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
	terrain_modules.append(load_8x8x2_tile())
	terrain_modules.append(load_12x12x2_tile())
	terrain_modules.append(load_level_side_tile())


### Individual Terrain Modules ###


func load_ground_tile() -> TerrainModule:
	var scene = load("res://terrain/scenes/GroundTile.tscn")
	var tags: TagList = TagList.new(["ground", "24x24"])
	var tags_per_socket: Dictionary[String, TagList] = {}
	var bb: AABB = Helper.compute_scene_mesh_aabb(scene)

	var top_size_dist_corners: Distribution = Distribution.new({"point": 0.9, "12x12": 0.1})
	var top_fill_prob_corners: float = 0.05
	var top_size_dist_cardinal: Distribution = Distribution.new({"point": 0.9, "8x8": 0.1})
	var top_fill_prob_cardinal: float = 0.05
	var top_size_dist_center: Distribution = Distribution.new({"point": 1.0})
	var top_fill_prob_center: float = 0.05
	var adjacent_tag_prob: Distribution = Distribution.new({"ground": 1.0})
	var top_tag_prob_corners: Distribution = Distribution.new({"grass": 0.3, "rock": 0.2, "bush": 0.2, "tree": 0.2, "hill": 0.1})
	var top_tag_prob_cardinal: Distribution = Distribution.new({"grass": 0.3, "rock": 0.2, "bush": 0.2, "tree": 0.2, "hill": 0.1})
	var top_tag_prob_center: Distribution = Distribution.new({"grass": 0.3, "rock": 0.2, "bush": 0.2, "tree": 0.2, "level": 0.1})

	var socket_size: Dictionary[String, Distribution] = {
		"main": Distribution.new({"24x24": 1.0}),
		"back": Distribution.new({"24x24": 1.0}),
		"right": Distribution.new({"24x24": 1.0}),
		"left": Distribution.new({"24x24": 1.0}),
		"topfront": top_size_dist_cardinal,
		"topback": top_size_dist_cardinal,
		"topleft": top_size_dist_cardinal,
		"topright": top_size_dist_cardinal,
		"topcenter": top_size_dist_center,
		"topfrontright": top_size_dist_corners,
		"topfrontleft": top_size_dist_corners,
		"topbackright": top_size_dist_corners,
		"topbackleft": top_size_dist_corners,
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
		"topfront": top_fill_prob_cardinal,
		"topback": top_fill_prob_cardinal,
		"topleft": top_fill_prob_cardinal,
		"topright": top_fill_prob_cardinal,
		"topfrontright": top_fill_prob_corners,
		"topfrontleft": top_fill_prob_corners,
		"topbackright": top_fill_prob_corners,
		"topbackleft": top_fill_prob_corners,
		"topcenter": top_fill_prob_center,
	}

	var socket_tag_prob: Dictionary[String, Distribution] = {
		"main": adjacent_tag_prob,
		"back": adjacent_tag_prob,
		"right": adjacent_tag_prob,
		"left": adjacent_tag_prob,
		"topfront": top_tag_prob_cardinal,
		"topback": top_tag_prob_cardinal,
		"topleft": top_tag_prob_cardinal,
		"topright": top_tag_prob_cardinal,
		"topfrontright": top_tag_prob_corners,
		"topfrontleft": top_tag_prob_corners,
		"topbackright": top_tag_prob_corners,
		"topbackleft": top_tag_prob_corners,
		"topcenter": top_tag_prob_center,
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
	var tags: TagList = TagList.new(["grass", "rotate", "point"])
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
	var tags: TagList = TagList.new(["bush", "rotate", "point"])
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
	var tags: TagList = TagList.new(["rock", "rotate", "point"])
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
	var tags: TagList = TagList.new(["tree", "rotate", "point"])
	var bb: AABB = Helper.compute_scene_mesh_aabb(scene)
	var visual_variants: Array[PackedScene] = []

	return TerrainModule.new(
		scene,
		bb,
		tags,
		{},
		visual_variants
	)

func load_8x8x2_tile() -> TerrainModule:
	var scene = load("res://terrain/scenes/Hill_8x8x2.tscn")
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
	var socket_tag_prob: Dictionary[String, Distribution] = {"topcenter": Distribution.new({"grass": 1.0})}

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


func load_12x12x2_tile() -> TerrainModule:
	var scene = load("res://terrain/scenes/Hill_12x12x2.tscn")
	var tags: TagList = TagList.new(["hill", "12x12"])
	var tags_per_socket: Dictionary[String, TagList] = {}
	var bb: AABB = Helper.compute_scene_mesh_aabb(scene)

	var socket_size: Dictionary[String, Distribution] = {
		"topcenter": Distribution.new({"8x8": 1.0}),
	}
	var socket_required: Dictionary[String, TagList] = {}
	var socket_fill_prob: Dictionary[String, float] = {
		"topcenter": 0.3,
	}
	var socket_tag_prob: Dictionary[String, Distribution] = {
		"topcenter": Distribution.new({"hill": 1.0}),
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
		
func load_level_side_tile() -> TerrainModule:
	var scene = load("res://terrain/scenes/LevelSide.tscn")
	var tags: TagList = TagList.new(["level", "24x24"])
	var tags_per_socket: Dictionary[String, TagList] = {}
	var bb: AABB = Helper.compute_scene_mesh_aabb(scene)

	var socket_size: Dictionary[String, Distribution] = {}
	var socket_required: Dictionary[String, TagList] = {}
	var socket_fill_prob: Dictionary[String, float] = {}
	var socket_tag_prob: Dictionary[String, Distribution] = {}

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
		if disti == null:
			# Null distributions are treated as uniform (no influence)
			continue
		dist_set.append(disti)
	if dist_set.is_empty():
		return Distribution.new()  # No adjacent influences, return empty distribution
	if dist_set.size() == 1:
		return dist_set[0]

	# Combine distributions by multiplying probabilities for overlapping tags
	var combined: Dictionary[String, float] = {}
	for disti: Distribution in dist_set:
		for tag: String in disti.dist.keys():
			var p: float = disti.prob(tag)
			if combined.has(tag):
				# Tag exists in multiple distributions, multiply probabilities
				combined[tag] *= p
			else:
				# First time seeing this tag, set its probability
				combined[tag] = p

	var result: Distribution = Distribution.new(combined)
	result.normalise()
	return result


func sample_from_modules(modules: TerrainModuleList, dist: Distribution) -> TerrainModule:
	var filtered_modules: TerrainModuleList = modules
	var working_dist: Distribution = dist.copy()

	while !working_dist.is_empty():
		var sampled_tag: String = working_dist.sample()
		filtered_modules = filter_module_list(modules, sampled_tag)
		if !filtered_modules.is_empty():
			# Found modules for this tag
			break
		else:
			# No modules for this tag, remove it and continue
			working_dist.remove(sampled_tag)
			if !working_dist.is_empty():
				working_dist.normalise()

	# If no tags had any modules, return original modules
	if filtered_modules.is_empty():
		print("warning: no matching tags in module list")
		filtered_modules = modules

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
	return intersection(sets)


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
	return intersection([modules, modules_by_tag[tag]])


func intersection(sets: Array[TerrainModuleList]) -> TerrainModuleList:
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
