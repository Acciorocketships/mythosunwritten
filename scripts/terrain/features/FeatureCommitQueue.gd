class_name FeatureCommitQueue
extends RefCounted

## Main-thread staged commit for structural world features. A block becomes
## ready only after its demand-loaded collision is complete; visuals continue
## independently under the ordinary batch budget.
enum State {
	WAITING_ASSETS,
	COLLISION,
}

var _render_cache: EnvironmentRenderCache
var _visuals: EnvironmentCommitQueue
var _jobs: Array[Dictionary] = []
var _mesh_visual_jobs: Array[Dictionary] = []
var _current_generation: Dictionary = {}
var _ready_events: Array[Dictionary] = []

## One lit material shared by every generated walk-surface mesh, tuned to the
## reviewed SFV plank palette so streamed stairs read as the same timber as the
## plank modules beside them.
static var _surface_mesh_material: StandardMaterial3D

func _init(render_cache: EnvironmentRenderCache) -> void:
	assert(render_cache != null)
	_render_cache = render_cache
	_visuals = EnvironmentCommitQueue.new(render_cache, &"Visuals")

func enqueue(chunk: Vector2i, generation: int, parent: Node3D,
		payload: EnvironmentInstancePayload) -> void:
	assert(OS.get_thread_caller_id() == OS.get_main_thread_id())
	assert(parent != null and payload != null and payload.validate())
	assert(not has_chunk(chunk), "one feature generation may be queued only once")
	_current_generation[chunk] = generation
	if payload.instance_count == 0 and payload.surface_meshes.is_empty():
		_ready_events.append({
			"chunk": chunk, "generation": generation, "node": null,
		})
		return
	var block := Node3D.new()
	block.name = "FeatureBlock_%d_%d" % [chunk.x, chunk.y]
	_jobs.append({
		"chunk": chunk,
		"generation": generation,
		"parent": weakref(parent),
		"block": block,
		"payload": payload,
		"asset_ids": payload.asset_ids(),
		"asset_index": 0,
		"state": State.WAITING_ASSETS,
		"collision_items": [],
		"collision_index": 0,
		"body": null,
	})

func drain(max_asset_loads: int, max_collision_shapes: int,
		max_visual_batches: int, max_usec: int = 0) -> Array[Dictionary]:
	assert(OS.get_thread_caller_id() == OS.get_main_thread_id())
	assert(max_asset_loads >= 0 and max_collision_shapes >= 0 \
		and max_visual_batches >= 0 and max_usec >= 0)
	var started := Time.get_ticks_usec()
	_discard_stale_jobs()
	var loaded := 0
	for job: Dictionary in _jobs:
		if loaded >= max_asset_loads or _time_exhausted(started, max_usec):
			break
		if int(job.state) != State.WAITING_ASSETS:
			continue
		var ids: Array = job.asset_ids
		if int(job.asset_index) < ids.size():
			var asset_id: StringName = ids[int(job.asset_index)]
			assert(_render_cache.visual(asset_id) != null)
			job.asset_index = int(job.asset_index) + 1
			loaded += 1
		if int(job.asset_index) == ids.size():
			job.collision_items = _collision_items(job.payload)
			job.state = State.COLLISION
	var committed := 0
	for job: Dictionary in _jobs:
		if committed >= max_collision_shapes \
				or _time_exhausted(started, max_usec):
			break
		if int(job.state) != State.COLLISION:
			continue
		var items: Array = job.collision_items
		while int(job.collision_index) < items.size() \
				and committed < max_collision_shapes \
				and not _time_exhausted(started, max_usec):
			_commit_collision(job, items[int(job.collision_index)])
			job.collision_index = int(job.collision_index) + 1
			committed += 1
	_finalize_collision_complete()
	var remaining_usec := 0
	if max_usec > 0:
		remaining_usec = maxi(0, max_usec - (Time.get_ticks_usec() - started))
	if max_usec <= 0 or remaining_usec > 0:
		var mesh_batches := _drain_mesh_visuals(max_visual_batches, started,
			max_usec)
		if max_usec > 0:
			remaining_usec = maxi(0,
				max_usec - (Time.get_ticks_usec() - started))
		if max_usec <= 0 or remaining_usec > 0:
			_visuals.drain(maxi(0, max_visual_batches - mesh_batches),
				remaining_usec)
	var events := _ready_events.duplicate()
	_ready_events.clear()
	return events

func has_chunk(chunk: Vector2i) -> bool:
	if _current_generation.has(chunk):
		return true
	for event: Dictionary in _ready_events:
		if event.chunk == chunk:
			return true
	return false

func invalidate_chunk(chunk: Vector2i) -> void:
	_current_generation.erase(chunk)
	_visuals.invalidate_chunk(chunk)
	for index in range(_jobs.size() - 1, -1, -1):
		if _jobs[index].chunk == chunk:
			_free_pending_block(_jobs[index].block)
			_jobs.remove_at(index)
	for index in range(_mesh_visual_jobs.size() - 1, -1, -1):
		if _mesh_visual_jobs[index].chunk == chunk:
			_mesh_visual_jobs.remove_at(index)
	for index in range(_ready_events.size() - 1, -1, -1):
		if _ready_events[index].chunk == chunk:
			_ready_events.remove_at(index)

func pending_count() -> int:
	return _jobs.size() + _mesh_visual_jobs.size() + _visuals.pending_count()

func pending_chunks() -> Array[Vector2i]:
	var unique: Dictionary = {}
	for job: Dictionary in _jobs:
		unique[job.chunk] = true
	for event: Dictionary in _ready_events:
		unique[event.chunk] = true
	var out: Array[Vector2i] = []
	out.assign(unique.keys())
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.x < b.x or (a.x == b.x and a.y < b.y))
	return out

func clear() -> void:
	for job: Dictionary in _jobs:
		_free_pending_block(job.block)
	_jobs.clear()
	_mesh_visual_jobs.clear()
	_ready_events.clear()
	_current_generation.clear()
	_visuals.clear()

func _finalize_collision_complete() -> void:
	for index in range(_jobs.size() - 1, -1, -1):
		var job: Dictionary = _jobs[index]
		if int(job.state) != State.COLLISION \
				or int(job.collision_index) < (job.collision_items as Array).size():
			continue
		if not _is_current(job):
			_free_pending_block(job.block)
			_jobs.remove_at(index)
			continue
		var parent := (job.parent as WeakRef).get_ref() as Node3D
		if parent == null or not is_instance_valid(parent):
			_free_pending_block(job.block)
			_jobs.remove_at(index)
			continue
		var block := job.block as Node3D
		parent.add_child(block)
		_visuals.register_chunk(job.chunk, int(job.generation))
		_visuals.enqueue(job.chunk, int(job.generation), block, job.payload)
		var meshes := (job.payload as EnvironmentInstancePayload).surface_meshes
		if not meshes.is_empty():
			_mesh_visual_jobs.append({
				"chunk": job.chunk,
				"generation": job.generation,
				"block": weakref(block),
				"meshes": meshes,
				"mesh_index": 0,
			})
		_ready_events.append({
			"chunk": job.chunk,
			"generation": job.generation,
			"node": block,
		})
		_jobs.remove_at(index)

func _collision_items(payload: EnvironmentInstancePayload) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for asset_id: StringName in payload.asset_ids():
		var visual := _render_cache.visual(asset_id)
		var placements: Array = payload.batches[asset_id].transforms
		for placement_index in placements.size():
			for piece_index in visual.collisions.size():
				out.append({
					"asset_id": asset_id,
					"placement": placements[placement_index],
					"piece": visual.collisions[piece_index],
				})
	for mesh: Dictionary in payload.surface_meshes:
		if not bool(mesh.get("visual_only", false)):
			out.append({"surface_mesh": mesh})
	return out

func _commit_collision(job: Dictionary, item: Dictionary) -> void:
	var body := job.body as StaticBody3D
	if body == null:
		body = StaticBody3D.new()
		body.name = &"FeatureCollision"
		(job.block as Node3D).add_child(body)
		job.body = body
	var shape_node := CollisionShape3D.new()
	if item.has("surface_mesh"):
		var mesh := item.surface_mesh as Dictionary
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(mesh.collision_faces as PackedVector3Array)
		shape_node.name = "%s_%04d" % [String(StringName(
			mesh.stable_id)).replace(".", "_").replace("/", "_"),
			int(job.collision_index)]
		shape_node.shape = shape
	else:
		var collision := item.piece as EnvironmentCollisionPiece
		shape_node.name = "%s_%04d" % [String(item.asset_id).replace(".", "_"),
			int(job.collision_index)]
		shape_node.shape = collision.shape
		shape_node.transform = (item.placement as Transform3D) \
			* collision.local_transform
	body.add_child(shape_node)

func _drain_mesh_visuals(max_batches: int, started: int, max_usec: int) -> int:
	var built := 0
	for index in range(_mesh_visual_jobs.size() - 1, -1, -1):
		var job: Dictionary = _mesh_visual_jobs[index]
		var block := (job.block as WeakRef).get_ref() as Node3D
		if not _is_current(job) or block == null \
				or not is_instance_valid(block):
			_mesh_visual_jobs.remove_at(index)
			continue
		var meshes: Array = job.meshes
		while int(job.mesh_index) < meshes.size() and built < max_batches \
				and not _time_exhausted(started, max_usec):
			_commit_mesh_visual(block, meshes[int(job.mesh_index)] as Dictionary)
			job.mesh_index = int(job.mesh_index) + 1
			built += 1
		if int(job.mesh_index) >= meshes.size():
			_mesh_visual_jobs.remove_at(index)
	return built

func _commit_mesh_visual(block: Node3D, mesh: Dictionary) -> void:
	var container := block.get_node_or_null("Visuals") as Node3D
	if container == null:
		container = Node3D.new()
		container.name = &"Visuals"
		block.add_child(container)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = mesh.vertices as PackedVector3Array
	arrays[Mesh.ARRAY_NORMAL] = mesh.normals as PackedVector3Array
	var uvs := mesh.uvs as PackedVector2Array
	if bool(mesh.get("terrain_ground", false)):
		uvs = PackedVector2Array()
		uvs.resize((mesh.vertices as PackedVector3Array).size())
		uvs.fill(SlopeAtlas.cliff_uv() \
			if bool(mesh.get("terrain_rock", false)) \
			else SlopeAtlas.path_uv() \
			if bool(mesh.get("terrain_path", false)) \
			else CliffDressing.ground_uv())
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	if mesh.has("colors"):
		arrays[Mesh.ARRAY_COLOR] = mesh.colors as PackedColorArray
	arrays[Mesh.ARRAY_INDEX] = mesh.indices as PackedInt32Array
	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	array_mesh.surface_set_material(0, CliffDressing.shared_material() \
		if bool(mesh.get("terrain_ground", false)) \
		else _shared_surface_mesh_material())
	var instance := MeshInstance3D.new()
	instance.name = String(StringName(mesh.stable_id)).replace("/", "_")
	instance.mesh = array_mesh
	container.add_child(instance)

static func _shared_surface_mesh_material() -> StandardMaterial3D:
	if _surface_mesh_material == null:
		_surface_mesh_material = StandardMaterial3D.new()
		# Mid-tone of the two SFV plank atlas swatches (#b78c5c / #a57e53) so
		# generated treads sit in the same lit timber family as plank modules.
		_surface_mesh_material.albedo_color = Color(0.68, 0.52, 0.34)
		_surface_mesh_material.roughness = 1.0
	return _surface_mesh_material

func _discard_stale_jobs() -> void:
	for index in range(_jobs.size() - 1, -1, -1):
		if not _is_current(_jobs[index]):
			_free_pending_block(_jobs[index].block)
			_jobs.remove_at(index)

func _is_current(job: Dictionary) -> bool:
	return int(_current_generation.get(job.chunk, -1)) == int(job.generation)

static func _time_exhausted(started: int, max_usec: int) -> bool:
	return max_usec > 0 and Time.get_ticks_usec() - started >= max_usec

static func _free_pending_block(block: Node3D) -> void:
	if block == null or not is_instance_valid(block):
		return
	if block.is_inside_tree():
		block.queue_free()
	else:
		block.free()
