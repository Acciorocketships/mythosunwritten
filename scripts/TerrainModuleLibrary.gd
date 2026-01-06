extends Node
class_name TerrainModuleLibrary

var TERRAIN_MODULES: TerrainModuleList = TerrainModuleList.new()
var MODULES_BY_TAG: Dictionary[String, TerrainModuleList] = {} # String -> Array[TerrainModule]

func init() -> void:
	load_terrain_modules()
	sort_terrain_modules()

func load_terrain_modules() -> void:
	TERRAIN_MODULES.append(load_ground_tile())

func sort_terrain_modules() -> void:
	MODULES_BY_TAG.clear()
	for module: TerrainModule in TERRAIN_MODULES.library:
		for tag: String in module.tags:
			if not MODULES_BY_TAG.has(tag):
				MODULES_BY_TAG[tag] = TerrainModuleList.new()
			MODULES_BY_TAG[tag].library.append(module)

func get_by_tags(tags: Array[String]) -> TerrainModuleList:
	if tags.is_empty():
		return TERRAIN_MODULES.duplicate()

	var sets: Array[TerrainModuleList] = []
	for tag in tags:
		if not MODULES_BY_TAG.has(tag):
			return TerrainModuleList.new()
		sets.append(MODULES_BY_TAG[tag])
	return _intersection_defs(sets)

func create_by_tags(tags: Array[String]) -> TerrainModuleInstance:
	var defs := get_by_tags(tags)
	if defs.is_empty():
		return null
	var def: TerrainModule = defs.library[randi_range(0, defs.size() - 1)]
	return def.spawn()

func filter_module_list(modules: TerrainModuleList, tag: String) -> TerrainModuleList:
	if tag == "other":
		return modules
	if not MODULES_BY_TAG.has(tag):
		return TerrainModuleList.new()
	return _intersection_defs([modules, MODULES_BY_TAG[tag]])

func _intersection_defs(sets: Array[TerrainModuleList]) -> TerrainModuleList:
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

	var out: Dictionary[TerrainModule, Variant] = {}
	for element: TerrainModule in sets[min_i].library:
		out[element] = true
	sets.remove_at(min_i)

	for s : TerrainModuleList in sets:
		for element in out.keys():
			if element not in s.library:
				out.erase(element)

	var out_list: TerrainModuleList = TerrainModuleList.new(out.keys())
	return out_list

### Individual Terrain Modules ###

func load_ground_tile() -> TerrainModule:
	var scene = load("res://terrain/scenes/GroundTile.tscn")
	var tags: Array[String] = ["ground", "24x24"]
	var bb: AABB = AABB(Vector3.ZERO, Vector3(24.0, 2.0, 24.0))

	var socket_size: Dictionary = {
		"main": Distribution.new({"24x24": 1.0}),
		"back": Distribution.new({"24x24": 1.0}),
		"right": Distribution.new({"24x24": 1.0}),
		"left": Distribution.new({"24x24": 1.0}),
	}
	var socket_required: Dictionary = {
		"main": ["ground"],
		"back": ["ground"],
		"right": ["ground"],
		"left": ["ground"],
	}
	var socket_fill_prob: Distribution = Distribution.new({
		"main": 1.0,
		"back": 1.0,
		"right": 1.0,
		"left": 1.0
	})
	var socket_tag_prob: Dictionary = {
		"main": Distribution.new({"ground": 1.0}),
		"back": Distribution.new({"ground": 1.0}),
		"right": Distribution.new({"ground": 1.0}),
		"left": Distribution.new({"ground": 1.0}),
	}

	return TerrainModule.new(
		scene,
		bb,
		tags,
		socket_size,
		socket_required,
		socket_fill_prob,
		socket_tag_prob
	)
