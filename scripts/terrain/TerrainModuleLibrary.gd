class_name TerrainModuleLibrary
extends Node


var terrain_modules: TerrainModuleList = TerrainModuleList.new()
var modules_by_tag: Dictionary[String, TerrainModuleList] = {}


func init() -> void:
	load_terrain_modules()
	sort_terrain_modules()


func init_test_pieces() -> void:
	load_test_pieces()
	sort_terrain_modules()


func load_terrain_modules() -> void:
	terrain_modules.append(TerrainModuleDefinitions.load_ground_tile())
	terrain_modules.append(TerrainModuleDefinitions.load_grass_tile())
	terrain_modules.append(TerrainModuleDefinitions.load_bush_tile())
	terrain_modules.append(TerrainModuleDefinitions.load_rock_tile())
	terrain_modules.append(TerrainModuleDefinitions.load_tree_tile())
	terrain_modules.append(TerrainModuleDefinitions.load_8x8x2_tile())
	terrain_modules.append(TerrainModuleDefinitions.load_12x12x2_tile())
	terrain_modules.append(TerrainModuleDefinitions.load_level_middle_tile())


func load_test_pieces() -> void:
	terrain_modules.append(TerrainModuleDefinitions.create_8x8_test_piece())
	terrain_modules.append(TerrainModuleDefinitions.create_12x12_test_piece())
	terrain_modules.append(TerrainModuleDefinitions.create_24x24_test_piece())


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


func get_required_tags(
	adjacent: Dictionary[String, TerrainModuleSocket],
	_attachment_socket_name: String = ""
) -> TagList:
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
		var tag_list: TagList = convert_tag_list(adjacent_required_tags, socket_name)
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

	var result: Distribution = Distribution.new(_multiply_distributions(dist_set))
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
	var min_i: int = _index_of_smallest(sets)
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
	var out: TagList = TagList.new()
	for i: int in range(tag_list.size()):
		var tag: String = tag_list.tags[i]
		# "!tag" is reserved for self-placement socket requirements and should not
		# be injected into adjacency-driven required tags.
		if tag.begins_with("!"):
			continue
		out.append(combined_tag_socket_name(tag, socket_name))
	return out


func combined_tag_socket_name(tag: String, socket_name: String) -> String:
	if tag.begins_with("[socket]"):
		var processed_tag: String = tag.substr(8)
		return "[%s]%s" % [socket_name, processed_tag]
	return tag


func filter_by_socket_requirements(
	modules: TerrainModuleList,
	adjacent: Dictionary[String, TerrainModuleSocket]
) -> TerrainModuleList:
	var out: TerrainModuleList = TerrainModuleList.new()
	for module_def: TerrainModule in modules.library:
		if _module_matches_socket_requirements(module_def, adjacent):
			out.append(module_def)
	return out


func _module_matches_socket_requirements(
	module_def: TerrainModule,
	adjacent: Dictionary[String, TerrainModuleSocket]
) -> bool:
	if module_def == null:
		return false
	for socket_name: String in module_def.socket_required.keys():
		var required: TagList = module_def.socket_required[socket_name]
		for required_tag: String in required:
			if not required_tag.begins_with("!"):
				continue
			var tag_name: String = required_tag.substr(1)
			var adjacent_socket: TerrainModuleSocket = adjacent.get(socket_name, null)
			if adjacent_socket == null or adjacent_socket.piece == null:
				return false
			if not adjacent_socket.piece.def.tags.has(tag_name):
				return false
	return true


func _multiply_distributions(dists: Array[Distribution]) -> Dictionary[String, float]:
	var combined: Dictionary[String, float] = {}
	for disti: Distribution in dists:
		for tag: String in disti.dist.keys():
			var p: float = disti.prob(tag)
			if combined.has(tag):
				combined[tag] *= p
			else:
				combined[tag] = p
	return combined


func _index_of_smallest(sets: Array[TerrainModuleList]) -> int:
	var min_i: int = 0
	var min_size: int = sets[0].size()
	for i in range(1, sets.size()):
		var set_size: int = sets[i].size()
		if set_size < min_size:
			min_size = set_size
			min_i = i
	return min_i
