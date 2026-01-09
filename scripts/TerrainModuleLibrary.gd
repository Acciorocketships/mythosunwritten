extends Node
class_name TerrainModuleLibrary


var TERRAIN_MODULES: TerrainModuleList = TerrainModuleList.new()
var MODULES_BY_TAG: Dictionary[String, TerrainModuleList] = {}


func init() -> void:
	load_terrain_modules()
	sort_terrain_modules()


func load_terrain_modules() -> void:
	TERRAIN_MODULES.append(load_ground_tile())


func sort_terrain_modules() -> void:
	MODULES_BY_TAG.clear()
	for module: TerrainModule in TERRAIN_MODULES:
		for tag: String in module.tags:
			if not MODULES_BY_TAG.has(tag):
				MODULES_BY_TAG[tag] = TerrainModuleList.new()
			MODULES_BY_TAG[tag].library.append(module)
		for socket_name: String in module.tags_per_socket:
			for tag: String in module.tags_per_socket[socket_name]:
				var tag_combined : String = combined_tag_socket_name(tag, socket_name)
				if not MODULES_BY_TAG.has(tag_combined):
					MODULES_BY_TAG[tag_combined] = TerrainModuleList.new()
				MODULES_BY_TAG[tag_combined].library.append(module)
			
			
func get_required_tags(adjacent: Dictionary[String, TerrainModuleSocket]) -> TagList:
	var out: TagList = TagList.new()
	for socket_name: String in adjacent.keys():
		var piece_socket: TerrainModuleSocket = adjacent[socket_name]
		var adjacent_piece: TerrainModuleInstance = piece_socket.piece
		var adjacent_socket_name: String = piece_socket.socket_name
		var adjacent_required_tags = adjacent_piece.def.socket_required[adjacent_socket_name]
		var tag_list = convert_tag_list(adjacent_required_tags, socket_name)
		out = out.union(tag_list)
	return out


func get_combined_distribution(adjacent: Dictionary[String, TerrainModuleSocket]) -> Distribution:
	var dist_set: Array[Distribution] = []
	for socket_name: String in adjacent.keys():
		var piece_socket: TerrainModuleSocket = adjacent[socket_name]
		var adjacent_piece: TerrainModuleInstance = piece_socket.piece
		var adjacent_socket_name: String = piece_socket.socket_name
		var disti: Distribution = adjacent_piece.def.socket_tag_prob[adjacent_socket_name]
		dist_set.append(disti)
	assert(dist_set.size() > 0)
	if dist_set.size() == 1:
		return dist_set[0]
	var out_dist: Distribution = Distribution.new()
	for disti: Distribution in dist_set:
		var new_dist = Distribution.new(out_dist.dist)
		new_dist.dist.merge(disti)
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
		return TERRAIN_MODULES.duplicate()
	var sets: Array[TerrainModuleList] = []
	for tag in tags:
		if not MODULES_BY_TAG.has(tag):
			return TerrainModuleList.new()
		sets.append(MODULES_BY_TAG[tag])
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
	if not MODULES_BY_TAG.has(tag):
		return TerrainModuleList.new()
	return _intersection([modules, MODULES_BY_TAG[tag]])


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
			tag_list.tags[i] = combined_tag_socket_name(tag, socket_name)
	return tag_list
			
	
func combined_tag_socket_name(tag: String, socket_name: String) -> String:
	return "[%s]%s" % [socket_name, tag]


### Individual Terrain Modules ###


func load_ground_tile() -> TerrainModule:
	var scene = load("res://terrain/scenes/GroundTile.tscn")
	var tags: TagList = TagList.new(["ground", "24x24"])
	var tags_by_socket: Dictionary[String, TagList] = {}
	var bb: AABB = AABB(Vector3.ZERO, Vector3(24.0, 2.0, 24.0))

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
	var socket_fill_prob: Distribution = Distribution.new({
		"main": 1.0,
		"back": 1.0,
		"right": 1.0,
		"left": 1.0
	})
	var socket_tag_prob: Dictionary[String, Distribution] = {
		"main": Distribution.new({"ground": 1.0}),
		"back": Distribution.new({"ground": 1.0}),
		"right": Distribution.new({"ground": 1.0}),
		"left": Distribution.new({"ground": 1.0}),
	}

	return TerrainModule.new(
		scene,
		bb,
		tags,
		tags_by_socket,
		socket_size,
		socket_required,
		socket_fill_prob,
		socket_tag_prob
	)
