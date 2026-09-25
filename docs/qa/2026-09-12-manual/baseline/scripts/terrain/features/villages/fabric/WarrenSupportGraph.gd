class_name WarrenSupportGraph
extends RefCounted

## Resource-free bearing DAG for rooms, buildings, and composed features.  A
## terrain root is explicit; an unowned allocation cell or decorative asset can
## never become support merely because it happens to lie below a volume.
var last_rejection := ""
var _parents_by_node: Dictionary = {}
var _terrain_roots: Dictionary = {}
var _sealed := false


func add_node(stable_id: StringName) -> bool:
	if _sealed or stable_id.is_empty() or _parents_by_node.has(stable_id):
		return false
	_parents_by_node[stable_id] = [] as Array[StringName]
	return true


func add_edge(child_id: StringName, parent_id: StringName) -> bool:
	if _sealed or child_id == parent_id or not _parents_by_node.has(child_id) \
			or not _parents_by_node.has(parent_id):
		return false
	var parents := _parents_by_node[child_id] as Array[StringName]
	if parents.has(parent_id):
		return false
	parents.append(parent_id)
	return true


func mark_terrain_root(stable_id: StringName) -> bool:
	if _sealed or not _parents_by_node.has(stable_id):
		return false
	_terrain_roots[stable_id] = true
	return true


func seal(required_ids: Array[StringName]) -> bool:
	last_rejection = ""
	if _sealed or required_ids.is_empty():
		return _reject("missing required support nodes")
	for stable_id: StringName in required_ids:
		if not _parents_by_node.has(stable_id):
			return _reject("missing support node %s" % stable_id)
		var visiting: Dictionary = {}
		var memo: Dictionary = {}
		if not _reaches_terrain(stable_id, visiting, memo):
			return _reject("support node does not reach terrain: %s" % stable_id)
	_sealed = true
	return true


func is_sealed() -> bool:
	return _sealed


func reaches_terrain(stable_id: StringName) -> bool:
	if not _sealed or not _parents_by_node.has(stable_id):
		return false
	return _reaches_terrain(stable_id, {}, {})


func deterministic_signature() -> String:
	var nodes := PackedStringArray()
	for node_value: Variant in _parents_by_node.keys():
		var node := StringName(node_value)
		var parents := PackedStringArray()
		for parent: StringName in _parents_by_node[node] as Array[StringName]:
			parents.append(String(parent))
		parents.sort()
		nodes.append("%s>%s/t%d" % [String(node), ",".join(parents),
			int(_terrain_roots.has(node))])
	nodes.sort()
	return "|".join(nodes)


func _reaches_terrain(stable_id: StringName, visiting: Dictionary,
		memo: Dictionary) -> bool:
	if memo.has(stable_id):
		return bool(memo[stable_id])
	if visiting.has(stable_id):
		memo[stable_id] = false
		return false
	if _terrain_roots.has(stable_id):
		memo[stable_id] = true
		return true
	visiting[stable_id] = true
	for parent: StringName in _parents_by_node[stable_id] as Array[StringName]:
		if _reaches_terrain(parent, visiting, memo):
			visiting.erase(stable_id)
			memo[stable_id] = true
			return true
	visiting.erase(stable_id)
	memo[stable_id] = false
	return false


func _reject(reason: String) -> bool:
	last_rejection = reason
	return false
