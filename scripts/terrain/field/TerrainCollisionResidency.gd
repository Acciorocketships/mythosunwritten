extends RefCounted

## Main-thread coordinator. Callers supply every active actor's position and
## predicted position, and must hold arrivals until is_ready() becomes true.
## Rendering and shared/imported collision resources are unchanged.
const ARCHIVE := preload("res://scripts/terrain/field/TerrainCollisionArchive.gd")
const CHUNK_SIZE := 192.0
# Actor interests already include up to 192 m of travel prediction. Keep the
# full collision near those interests, rather than another two chunks beyond
# them; distant scenery retains exact compressed faces for restoration.
const RESTORE_RADIUS := 96.0
const SUSPEND_RADIUS := 160.0
var _entries: Dictionary = {}

func register_chunk(chunk: Vector2i, root: Node) -> void:
	assert(not _entries.has(chunk))
	var nodes: Array[WeakRef] = []
	for node: Node in root.find_children("*","CollisionShape3D",true,false):
		nodes.append(weakref(node))
	_entries[chunk] = {"root":weakref(root),"nodes":nodes,"cursor":0,
		"archive":ARCHIVE.new(),"near":true,"distance":0.0,
		"ready_frame":Engine.get_physics_frames()+1}

func unregister_chunk(chunk: Vector2i) -> Dictionary:
	var entry: Dictionary = _entries.get(chunk,{})
	_entries.erase(chunk)
	return entry

func update_interests(points: PackedVector3Array) -> void:
	assert(OS.get_thread_caller_id() == OS.get_main_thread_id())
	for chunk: Vector2i in _entries:
		var entry: Dictionary = _entries[chunk]
		# An incomplete actor inventory must never turn off all collision.
		var distance := 0.0 if points.is_empty() else INF
		for point: Vector3 in points:
			distance = minf(distance,distance_to_chunk(point,chunk))
		entry.distance = distance
		if entry.near:
			if distance > SUSPEND_RADIUS: entry.near = false
		elif distance < RESTORE_RADIUS:
			entry.near = true
			entry.cursor = 0

func drain(budget_usec := 1000, max_steps := 32) -> int:
	assert(OS.get_thread_caller_id() == OS.get_main_thread_id())
	var started := Time.get_ticks_usec()
	var steps := 0
	var keys: Array = _entries.keys()
	# Restore nearest actors first, before spending time suspending scenery.
	keys.sort_custom(func(a: Vector2i,b: Vector2i)->bool:
		if bool(_entries[a].near) != bool(_entries[b].near): return bool(_entries[a].near)
		return float(_entries[a].distance) < float(_entries[b].distance))
	for chunk: Vector2i in keys:
		var entry: Dictionary = _entries[chunk]
		if entry.root.get_ref() == null: continue
		if entry.near:
			while entry.archive.pending() > 0:
				if not entry.archive.restore_one(): return steps
				entry.ready_frame = Engine.get_physics_frames()+1
				steps += 1
				if steps >= max_steps or Time.get_ticks_usec()-started >= budget_usec: return steps
		else:
			while entry.cursor < entry.nodes.size():
				var node := (entry.nodes[entry.cursor] as WeakRef).get_ref() as CollisionShape3D
				entry.cursor += 1
				if node != null: entry.archive.suspend(node)
				steps += 1
				if steps >= max_steps or Time.get_ticks_usec()-started >= budget_usec: return steps
	return steps

func is_ready(chunk: Vector2i) -> bool:
	if not _entries.has(chunk): return false
	var entry: Dictionary = _entries[chunk]
	return entry.root.get_ref() != null and entry.archive.pending() == 0 \
		and Engine.get_physics_frames() >= int(entry.ready_frame)

static func distance_to_chunk(point: Vector3, chunk: Vector2i) -> float:
	var lo := Vector2(chunk)*CHUNK_SIZE
	var hi := lo+Vector2.ONE*CHUNK_SIZE
	var p := Vector2(point.x,point.z)
	return p.distance_to(p.clamp(lo,hi))

func stats() -> Dictionary:
	var shapes := 0
	var bytes := 0
	var chunks := 0
	for entry: Dictionary in _entries.values():
		shapes += entry.archive.pending()
		bytes += entry.archive.compressed_bytes
		if entry.archive.pending() > 0: chunks += 1
	return {"registered_chunks":_entries.size(),"archived_chunks":chunks,
		"archived_shapes":shapes,"compressed_bytes":bytes}
