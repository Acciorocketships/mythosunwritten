class_name GrassStreamer
extends RefCounted

const FULL_RADIUS := 60.0
const GRASS_RADIUS := 84.0
const KEEP_RADIUS := GRASS_RADIUS + GrassField.TILE_WORLD
const COMMIT_BUDGET_USEC := 500
const MAX_DEFORMATION_RATIO := 1.65
const WIND_DIRECTION := Vector2(0.94, 0.34)
const WIND_IDLE_BEND := 0.055
const WIND_GUST_SCALE := 110.0
const WIND_GUST_SPEED := 4.2
const WIND_GUST_BEND := 0.27

var _program: GrassProgram
var _render_cache: EnvironmentRenderCache
var _shader: Shader
var _ground_palette_texture: Texture2D
var _ground_palette_uv := Vector2.ZERO
var _materials: Dictionary = {}
var _meshes: Dictionary = {}
var _built: Dictionary = {}
var _requested: Dictionary = {}
var _pending_tiles: Dictionary = {}
var _pending: Array[Dictionary] = []
var _generations: Dictionary = {}
var _lod_origin := Vector2.ZERO
var _has_lod_origin := false
var _wind_texture: NoiseTexture2D
var _worker_total_usec := 0
var _worker_max_usec := 0
var _worker_result_count := 0
var _commit_max_usec := 0
var _lod_update_max_usec := 0

func _init(program: GrassProgram, render_cache: EnvironmentRenderCache) -> void:
	assert(OS.get_thread_caller_id() == OS.get_main_thread_id())
	assert(program != null and render_cache != null)
	_program = program
	_render_cache = render_cache
	_shader = load("res://terrain/grass/grass.gdshader") as Shader
	assert(_shader != null)
	_ground_palette_texture = CliffDressing.ground_texture()
	_ground_palette_uv = CliffDressing.ground_uv()
	for asset_id: StringName in _program.referenced_asset_ids:
		_prepare_asset(asset_id)
	_prepare_wind()

static func distance_to_tile(origin: Vector2, tile: Vector2i) -> float:
	var rect := Rect2(Vector2(tile) * GrassField.TILE_WORLD,
		Vector2.ONE * GrassField.TILE_WORLD)
	var dx := maxf(maxf(rect.position.x - origin.x, 0.0), origin.x - rect.end.x)
	var dz := maxf(maxf(rect.position.y - origin.y, 0.0), origin.y - rect.end.y)
	return Vector2(dx, dz).length()

static func density(distance: float) -> float:
	return 1.0 - smoothstep(FULL_RADIUS, GRASS_RADIUS, distance)

static func desired_tiles(origin: Vector2) -> Array[Vector2i]:
	var centre := GrassField.tile_of(origin)
	var reach := int(ceil(GRASS_RADIUS / GrassField.TILE_WORLD)) + 1
	var out: Array[Vector2i] = []
	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var tile := centre + Vector2i(dx, dz)
			if distance_to_tile(origin, tile) < GRASS_RADIUS:
				out.append(tile)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := distance_to_tile(origin, a)
		var db := distance_to_tile(origin, b)
		return da < db or (is_equal_approx(da, db) and _key_less(a, b)))
	return out

func begin_frame(origin: Vector2) -> Array[Node3D]:
	var origin_changed := not _has_lod_origin or origin != _lod_origin
	_lod_origin = origin
	_has_lod_origin = true
	RenderingServer.global_shader_parameter_set(&"grass_lod_origin", origin)
	var started := Time.get_ticks_usec()
	if origin_changed:
		_update_visible_counts()
	_lod_update_max_usec = maxi(_lod_update_max_usec,
		Time.get_ticks_usec() - started)
	return _evict_far()

func needs_request(tile: Vector2i) -> bool:
	return not _built.has(tile) and not _requested.has(tile) \
		and not _pending_tiles.has(tile)

func mark_requested(tile: Vector2i) -> int:
	assert(needs_request(tile))
	var generation := int(_generations.get(tile, 1))
	_generations[tile] = generation
	_requested[tile] = generation
	return generation

func generation(tile: Vector2i) -> int:
	return int(_generations.get(tile, 1))

func accept_result(tile: Vector2i, generation_value: int,
		payload: GrassPayload, compute_usec: int = 0) -> bool:
	assert(OS.get_thread_caller_id() == OS.get_main_thread_id())
	if compute_usec > 0:
		_worker_total_usec += compute_usec
		_worker_max_usec = maxi(_worker_max_usec, compute_usec)
		_worker_result_count += 1
	# A late result must not clear a newer request for the same tile.
	if int(_requested.get(tile, -1)) == generation_value:
		_requested.erase(tile)
	if generation(tile) != generation_value \
			or distance_to_tile(_lod_origin, tile) >= GRASS_RADIUS \
			or payload == null or not payload.validate() or payload.tile != tile:
		return false
	_pending_tiles[tile] = generation_value
	_pending.append({"tile": tile, "generation": generation_value,
		"payload": payload, "node": null, "next_batch": 0})
	return true

## Builds resources under an elapsed-time budget and returns unattached nodes.
## FieldTerrainStreamer remains the only scene-tree attachment owner.
func drain_commits() -> Array[Dictionary]:
	assert(OS.get_thread_caller_id() == OS.get_main_thread_id())
	_pending.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var da := distance_to_tile(_lod_origin, a.tile)
		var db := distance_to_tile(_lod_origin, b.tile)
		return da < db or (is_equal_approx(da, db) and _key_less(a.tile, b.tile)))
	var attached: Array[Dictionary] = []
	var started := Time.get_ticks_usec()
	while not _pending.is_empty():
		if Time.get_ticks_usec() - started >= COMMIT_BUDGET_USEC:
			break
		var item: Dictionary = _pending.pop_front()
		var tile: Vector2i = item.tile
		if generation(tile) != int(item.generation) \
				or distance_to_tile(_lod_origin, tile) >= GRASS_RADIUS:
			_pending_tiles.erase(tile)
			_free_partial(item)
			continue
		var payload := item.payload as GrassPayload
		var asset_ids := payload.asset_ids()
		var next_batch := int(item.next_batch)
		var node := item.node as Node3D
		if node == null and not asset_ids.is_empty():
			node = _new_tile_node(payload.tile)
		if next_batch < asset_ids.size():
			_add_batch(node, asset_ids[next_batch],
				payload.batches[asset_ids[next_batch]])
			next_batch += 1
		if next_batch < asset_ids.size():
			item.node = node
			item.next_batch = next_batch
			_pending.push_front(item)
			# One buffer upload per frame is a hard ceiling: the upload cost
			# cannot be predicted accurately enough to start a second safely.
			break
		_pending_tiles.erase(tile)
		_built[tile] = {"node": node, "batches": _batch_records(node),
			"generation": int(item.generation)}
		_update_tile_visible(tile)
		if node != null:
			attached.append({"tile": tile, "node": node})
		# Even a completed one-batch tile has performed this frame's upload.
		if not asset_ids.is_empty():
			break
	_commit_max_usec = maxi(_commit_max_usec, Time.get_ticks_usec() - started)
	return attached

func built_count() -> int:
	return _built.size()

func pending_count() -> int:
	return _pending.size()

func stats() -> Dictionary:
	var batch_count := 0
	var committed_instances := 0
	var visible_instances := 0
	for tile: Vector2i in _built:
		for batch: Dictionary in _built[tile].batches:
			var count: int = batch.count
			batch_count += 1
			committed_instances += count
			visible_instances += int(batch.visible)
	return {
		"tiles": _built.size(),
		"batches": batch_count,
		"committed_instances": committed_instances,
		"visible_instances": visible_instances,
		"buffer_bytes": committed_instances * GrassPayload.FLOATS_PER_INSTANCE * 4,
		"worker_average_usec": float(_worker_total_usec) \
			/ float(_worker_result_count) if _worker_result_count > 0 else 0.0,
		"worker_max_usec": _worker_max_usec,
		"commit_max_usec": _commit_max_usec,
		"lod_update_max_usec": _lod_update_max_usec,
		"worker_results": _worker_result_count,
	}

func _prepare_asset(asset_id: StringName) -> void:
	var visual := _render_cache.visual(asset_id)
	assert(visual != null and visual.pieces.size() == 1)
	var piece: EnvironmentVisualPiece = visual.pieces[0]
	var metadata: Dictionary = _program.assets[asset_id]
	var material := ShaderMaterial.new()
	material.shader = _shader
	var source := piece.mesh.surface_get_material(0) as StandardMaterial3D
	assert(source != null)
	var has_texture := source.albedo_texture != null
	if has_texture:
		material.set_shader_parameter(&"albedo_texture", source.albedo_texture)
	material.set_shader_parameter(&"source_has_texture", has_texture)
	material.set_shader_parameter(&"ground_palette_texture", _ground_palette_texture)
	material.set_shader_parameter(&"ground_palette_uv", _ground_palette_uv)
	material.set_shader_parameter(&"local_base_y", float(metadata.local_base_y))
	material.set_shader_parameter(&"local_height", float(metadata.local_height))
	_materials[asset_id] = material
	_meshes[asset_id] = piece.mesh

func _prepare_wind() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 17321
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.018
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	_wind_texture = NoiseTexture2D.new()
	_wind_texture.width = 256
	_wind_texture.height = 256
	_wind_texture.seamless = true
	_wind_texture.noise = noise
	RenderingServer.global_shader_parameter_set(&"wind_direction", WIND_DIRECTION.normalized())
	RenderingServer.global_shader_parameter_set(&"wind_idle_bend", WIND_IDLE_BEND)
	RenderingServer.global_shader_parameter_set(&"wind_gust_texture", _wind_texture)
	RenderingServer.global_shader_parameter_set(&"wind_gust_scale", WIND_GUST_SCALE)
	RenderingServer.global_shader_parameter_set(&"wind_gust_speed", WIND_GUST_SPEED)
	RenderingServer.global_shader_parameter_set(&"wind_gust_bend", WIND_GUST_BEND)

func _new_tile_node(tile: Vector2i) -> Node3D:
	var root := Node3D.new()
	root.name = "GrassTile_%d_%d" % [tile.x, tile.y]
	return root

func _add_batch(root: Node3D, asset_id: StringName, batch: Dictionary) -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = _meshes[asset_id]
	multimesh.instance_count = int(batch.count)
	multimesh.set_buffer(batch.buffer)
	var inflation := float(batch.max_height) * MAX_DEFORMATION_RATIO + 0.05
	multimesh.custom_aabb = (batch.aabb as AABB).grow(inflation)
	var instance := MultiMeshInstance3D.new()
	instance.name = String(asset_id).replace(".", "_")
	instance.multimesh = multimesh
	instance.material_override = _materials[asset_id]
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.set_meta(&"grass_count", int(batch.count))
	instance.set_meta(&"grass_asset_id", asset_id)
	root.add_child(instance)

func _batch_records(node: Node3D) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if node == null:
		return out
	for child: Node in node.get_children():
		var instance := child as MultiMeshInstance3D
		if instance != null:
			out.append({"multimesh": instance.multimesh,
				"count": int(instance.get_meta(&"grass_count", 0)),
				"visible": -1})
	return out

func _update_visible_counts() -> void:
	for tile: Vector2i in _built:
		_update_tile_visible(tile)

func _update_tile_visible(tile: Vector2i) -> void:
	var tile_density := density(distance_to_tile(_lod_origin, tile))
	for batch: Dictionary in _built[tile].batches:
		var count: int = batch.count
		var multimesh: MultiMesh = batch.multimesh
		var visible := mini(count, int(ceil(float(count) * tile_density)))
		# The cap is still derived from this frame's player origin; only the
		# redundant server write is skipped when the integer is unchanged.
		if visible != int(batch.visible):
			multimesh.visible_instance_count = visible
			batch.visible = visible

func _evict_far() -> Array[Node3D]:
	var removed: Array[Node3D] = []
	var candidates: Dictionary = {}
	for tile: Vector2i in _built:
		candidates[tile] = true
	for tile: Vector2i in _requested:
		candidates[tile] = true
	for tile: Vector2i in _pending_tiles:
		candidates[tile] = true
	for tile: Vector2i in candidates:
		if distance_to_tile(_lod_origin, tile) <= KEEP_RADIUS:
			continue
		_generations[tile] = generation(tile) + 1
		_requested.erase(tile)
		_pending_tiles.erase(tile)
		if _built.has(tile):
			var node := _built[tile].node as Node3D
			if node != null:
				removed.append(node)
			_built.erase(tile)
	var retained: Array[Dictionary] = []
	for item: Dictionary in _pending:
		if _pending_tiles.has(item.tile):
			retained.append(item)
		else:
			_free_partial(item)
	_pending = retained
	return removed

static func _free_partial(item: Dictionary) -> void:
	var node := item.get("node") as Node3D
	if node != null:
		node.free()

static func _key_less(a: Vector2i, b: Vector2i) -> bool:
	return a.x < b.x or (a.x == b.x and a.y < b.y)
