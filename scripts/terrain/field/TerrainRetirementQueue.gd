class_name TerrainRetirementQueue
extends RefCounted

## Remove a chunk from rendering/physics immediately, then destroy its detached
## tree in bounded main-thread slices. Render and physics resources never move
## to a worker. Callers separately release large plain-data metadata off-thread.
var _roots: Array[Node] = []
var _walk: Array[Node] = []

func enqueue(node: Node) -> void:
	assert(OS.get_thread_caller_id() == OS.get_main_thread_id())
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	_roots.append(node)

func drain(budget_usec := 1000, max_nodes := 32) -> int:
	assert(OS.get_thread_caller_id() == OS.get_main_thread_id())
	var started := Time.get_ticks_usec()
	var freed := 0
	while freed < max_nodes:
		if _walk.is_empty():
			if _roots.is_empty(): break
			_walk.append(_roots.pop_front())
		var node: Node = _walk.back()
		if node.get_child_count() > 0:
			_walk.append(node.get_child(node.get_child_count() - 1))
		else:
			_walk.pop_back()
			node.free()
			freed += 1
		if Time.get_ticks_usec() - started >= budget_usec: break
	return freed

func pending() -> bool:
	return not _roots.is_empty() or not _walk.is_empty()

func clear() -> void:
	# Shutdown is synchronous; every detached node still has an owner here.
	if not _walk.is_empty():
		_walk[0].free()
		_walk.clear()
	for node: Node in _roots: node.free()
	_roots.clear()
