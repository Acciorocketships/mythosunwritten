extends Object
class_name TerrainIndexSimple

# Just a flat list of modules + their AABBs
var modules: Array = []                  # [TerrainModule]
var aabb_by_module: Dictionary = {}      # {TerrainModule: AABB}


func insert(module: TerrainModule) -> void:
	if module in modules:
		remove(module)

	modules.append(module)
	aabb_by_module[module] = module.aabb
	#_debug("insert: " + module.debug_string())


func remove(module: TerrainModule) -> void:
	var idx: int = modules.find(module)
	if idx != -1:
		modules.remove_at(idx)
	#_debug("remove: " + module.debug_string())

	aabb_by_module.erase(module)


func update(module: TerrainModule) -> void:
	# Call after module.aabb is changed
	#_debug("update: " + module.debug_string())
	remove(module)
	insert(module)


func query_box(box: AABB) -> Array:
	var out: Array = []
	for m in modules:
		var aabb: AABB = aabb_by_module.get(m, null)
		if aabb == null:
			continue
		if aabb.intersects(box):
			out.append(m)
	return out


func query_outside(box: AABB) -> Array:
	var inside = query_box(box)
	if inside.is_empty():
		return modules.duplicate()

	var inside_set: Dictionary = {}
	for m in inside:
		inside_set[m] = true

	var out: Array = []
	for m in modules:
		if not inside_set.has(m):
			out.append(m)

	return out
