# tests/harness/profile_startup_threaded.gd
# Startup + ring-sweep profiler whose generation runs on a worker thread while
# the SceneTree keeps ticking frames, exactly like FieldTerrainStreamer. That
# makes it usable under the remote-debugger script profiler (which reports
# per frame) and lets the main thread commit payloads as production does.
#
#   Godot --headless --path . -s res://tests/harness/profile_startup_threaded.gd \
#     [--remote-debug tcp://127.0.0.1:PORT] -- [--seed=N] [--radius=N] [--ready-only]
#
# Prints one `[stprof]` line per stage; `--radius` sweeps the (2r+1)^2 ring
# after the nine startup support chunks.
extends SceneTree

const DEFAULT_SEED := 2697992464
const CHUNK_WORLD := 192.0

var _t0 := 0
var _seed := DEFAULT_SEED
var _radius := 1
var _ready_only := false
var _thread: Thread
var _mutex := Mutex.new()
var _commit_queue: Array[Dictionary] = []
var _worker_done := false
var _commit_usec := 0
var _commits := 0

var plan: HeightfieldPlan
var water: WaterPlan
var mesher: TerrainChunkMesher
var water_builder: WaterSurfaceBuilder
var dressing_program: DressingProgram
var feature_program: FeatureProgram
var fields: WorldFieldBlockCache
var features: WorldFeaturePlan
var render_cache: EnvironmentRenderCache

static func _ms(usec: int) -> String:
	return "%.1f" % (float(usec) / 1000.0)

func _mark(label: String, started_usec: int) -> int:
	var now := Time.get_ticks_usec()
	print("[stprof] %s ms=%s total_ms=%s" % [label, _ms(now - started_usec), _ms(now - _t0)])
	return now

func _init() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="): _seed = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--radius="): _radius = int(arg.trim_prefix("--radius="))
		elif arg == "--ready-only": _ready_only = true
	_t0 = Time.get_ticks_usec()
	var t := _t0
	water = TerrainWorldTuning.make_water(_seed)
	var settlements := SettlementPlan.new(_seed, water)
	plan = TerrainWorldTuning.make_heightfield(_seed, water)
	mesher = TerrainChunkMesher.new()
	mesher.set_seed(_seed)
	water_builder = WaterSurfaceBuilder.new()
	var catalog := EnvironmentCatalog.load_default()
	t = _mark("ready.environment_catalog", t)
	render_cache = EnvironmentRenderCache.new(catalog)
	var dressing_index := load("res://terrain/dressing/index.tres") as DressingCatalogIndex
	if not OS.get_cmdline_user_args().has("--no-prefetch"):
		# Mirrors FieldTerrainStreamer._ready.
		var startup_visuals: Array[StringName] = DressingCompiler.authored_asset_ids(dressing_index)
		for asset_id: StringName in CliffDressing.ASSETS.values():
			if not startup_visuals.has(asset_id): startup_visuals.append(asset_id)
		render_cache.prefetch(startup_visuals)
		preload("res://scripts/terrain/field/CliffSlopeRocks.gd").prefetch()
		render_cache.prepare(startup_visuals)
		preload("res://scripts/core/ResourcePrefetch.gd").wait_all()
		t = _mark("ready.prefetch_prepare", t)
	dressing_program = DressingCompiler.compile(dressing_index, catalog)
	t = _mark("ready.dressing_compile", t)
	feature_program = FeatureProgram.compile(catalog)
	t = _mark("ready.feature_compile", t)
	var grass_settings := load("res://terrain/grass/settings.tres") as GrassSettings
	var grass_program := GrassProgram.compile(grass_settings, catalog, render_cache)
	t = _mark("ready.grass_compile", t)
	var query_margin := maxf(maxf(dressing_program.query_margin, feature_program.query_margin),
		grass_program.query_margin)
	var context_margin := maxf(maxf(feature_program.query_margin,
		dressing_program.feature_query_margin),
		preload("res://scripts/terrain/field/CliffSlopeField.gd").GROUND_REACH + HeightfieldPlan.POINT)
	var shore := maxf(maxf(dressing_program.shore_distance_limit,
		feature_program.shore_distance_limit), grass_program.shore_distance_limit)
	fields = WorldFieldBlockCache.new(plan, water, query_margin, shore,
		feature_program.field_cache_cap)
	features = WorldFeaturePlan.new(_seed, water, fields, feature_program, settlements,
		context_margin)
	features.profile_stage_callback = Callable(self, "_stage")
	fields.profile_callback = Callable(self, "_field_op")
	mesher.water_blocks = fields
	var active_set: Dictionary = {}
	for id: StringName in dressing_program.referenced_asset_ids: active_set[id] = true
	for id: StringName in grass_program.referenced_asset_ids: active_set[id] = true
	for id: StringName in CliffDressing.ASSETS.values(): active_set[id] = true
	var active: Array[StringName] = []
	active.assign(active_set.keys())
	active.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	render_cache.prepare(active)
	t = _mark("ready.render_cache_prepare(%d)" % active.size(), t)
	CliffDressing.prepare(render_cache)
	CliffDressing.shared_material()
	t = _mark("ready.cliff_dressing_material", t)
	WaterSurfaceBuilder.sheet_material()
	t = _mark("ready.water_material", t)
	mesher.prepare_resources()
	t = _mark("ready.mesher_resources", t)
	BiomeRegistry.profile(&"meadow")
	_mark("READY_TOTAL", _t0)
	if _ready_only:
		_worker_done = true
		return
	_thread = Thread.new()
	_thread.start(_work)

var _stage_started := {}
func _stage(chunk: Vector2i, stage: StringName) -> void:
	var now := Time.get_ticks_usec()
	print("[stprof] stage chunk=%d,%d %s at_ms=%s" % [chunk.x, chunk.y, stage, _ms(now - _t0)])

func _field_op(event: StringName, operation: StringName, field_chunk: Vector2i, elapsed: int) -> void:
	if event == &"end" and elapsed > 200000:
		print("[stprof] field %s %d,%d ms=%s" % [operation, field_chunk.x, field_chunk.y, _ms(elapsed)])

func _work() -> void:
	var started := Time.get_ticks_usec()
	var supports := FieldTerrainStreamer.support_chunks_at(FieldTerrainStreamer.DEFAULT_SPAWN_POSITION)
	var halo := feature_program.geometry_halo
	var key_set: Dictionary = {}
	for chunk: Vector2i in supports:
		for dz in range(-halo, halo + 1):
			for dx in range(-halo, halo + 1):
				key_set[chunk + Vector2i(dx, dz)] = true
	var keys: Array[Vector2i] = []
	keys.assign(key_set.keys())
	# Production order: the spawn chunk first, then outward.
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := maxi(absi(a.x), absi(a.y))
		var db := maxi(absi(b.x), absi(b.y))
		return da < db or (da == db and (a.x < b.x or (a.x == b.x and a.y < b.y))))
	for key: Vector2i in keys:
		var t := Time.get_ticks_usec()
		features.context_for(key)
		print("[stprof] context key=%d,%d ms=%s" % [key.x, key.y, _ms(Time.get_ticks_usec() - t)])
	print("[stprof] CONTEXTS_TOTAL ms=%s" % _ms(Time.get_ticks_usec() - started))
	var chunks: Array[Vector2i] = []
	chunks.assign(supports)
	for dz in range(-_radius, _radius + 1):
		for dx in range(-_radius, _radius + 1):
			if not chunks.has(Vector2i(dx, dz)): chunks.append(Vector2i(dx, dz))
	var totals: Dictionary = {}
	var phase_started := Time.get_ticks_usec()
	for chunk: Vector2i in chunks:
		var report := _build(chunk)
		var line := "[stprof] chunk=%d,%d" % [chunk.x, chunk.y]
		for key: String in report:
			if key.ends_with("_usec"):
				totals[key] = int(totals.get(key, 0)) + int(report[key])
				line += " %s=%s" % [key.trim_suffix("_usec"), _ms(report[key])]
		print(line)
	print("[stprof] CHUNKS_TOTAL n=%d ms=%s" % [chunks.size(), _ms(Time.get_ticks_usec() - phase_started)])
	for key: String in totals:
		print("[stprof] chunk_phase %s total_ms=%s avg_ms=%s" % [key.trim_suffix("_usec"),
			_ms(totals[key]), _ms(int(totals[key]) / chunks.size())])
	_mutex.lock()
	_worker_done = true
	_mutex.unlock()

func _build(chunk: Vector2i) -> Dictionary:
	var r := {}
	var job_started := Time.get_ticks_usec()
	var t := job_started
	var ctx := features.context_for(chunk)
	r["context_usec"] = Time.get_ticks_usec() - t
	t = Time.get_ticks_usec()
	var region := ctx.graded_region(fields.region(chunk))
	r["region_usec"] = Time.get_ticks_usec() - t
	t = Time.get_ticks_usec()
	var water_ctx := fields.water(chunk)
	r["water_ctx_usec"] = Time.get_ticks_usec() - t
	t = Time.get_ticks_usec()
	var terrain := mesher.compute_chunk(chunk, region, water_ctx, ctx)
	r["mesh_usec"] = Time.get_ticks_usec() - t
	t = Time.get_ticks_usec()
	var water_payload := water_builder.compute_chunk(water, chunk, region, water_ctx)
	r["water_mesh_usec"] = Time.get_ticks_usec() - t
	t = Time.get_ticks_usec()
	var core := Rect2(Vector2(chunk) * CHUNK_WORLD, Vector2.ONE * CHUNK_WORLD)
	var fctx := ctx
	var structure_clearance: Array[FeatureGroundShape] = terrain.structure_clearance
	if not structure_clearance.is_empty():
		fctx = ctx.extended([], structure_clearance, EnvironmentInstancePayload.new(), Rect2())
	var dressing := DressingField.compute(dressing_program, _seed, core, region, water_ctx,
		fctx, terrain.cliff_terraces.ground_reservations)
	r["dressing_usec"] = Time.get_ticks_usec() - t
	t = Time.get_ticks_usec()
	var grass_supports: Array = terrain.cliff_terraces.grass_supports.duplicate()
	for skirt: Dictionary in dressing.ground_skirts:
		grass_supports.append(skirt.grass_support)
	GrassSamplingContext.detached(region, water_ctx, fctx, grass_supports)
	r["grass_sampling_usec"] = Time.get_ticks_usec() - t
	t = Time.get_ticks_usec()
	BiomeAtmosphereField.compute(chunk, region, _seed, water_ctx)
	r["fx_usec"] = Time.get_ticks_usec() - t
	r["job_usec"] = Time.get_ticks_usec() - job_started
	_mutex.lock()
	_commit_queue.append({"chunk": chunk, "terrain": terrain, "water": water_payload,
		"dressing": dressing})
	_mutex.unlock()
	return r

func _process(_delta: float) -> bool:
	var items: Array[Dictionary] = []
	_mutex.lock()
	items.assign(_commit_queue)
	_commit_queue.clear()
	var done := _worker_done
	_mutex.unlock()
	for item: Dictionary in items:
		var t := Time.get_ticks_usec()
		var node := mesher.commit_chunk(item.terrain)
		var t_terrain := Time.get_ticks_usec()
		var water_node := water_builder.commit_chunk(item.water)
		if water_node != null: node.add_child(water_node)
		var t_water := Time.get_ticks_usec()
		EnvironmentCollisionBuilder.commit(node, item.dressing, render_cache, &"DressingCollision")
		RockSkirt.commit(node, item.dressing.ground_skirts)
		var t_coll := Time.get_ticks_usec()
		var queue := EnvironmentCommitQueue.new(render_cache, &"Dressing")
		queue.register_chunk(item.chunk, 1)
		queue.enqueue(item.chunk, 1, node, item.dressing)
		queue.drain(1000000)
		var t_end := Time.get_ticks_usec()
		print("[stprof] commit chunk=%d,%d terrain_ms=%s water_ms=%s collision_ms=%s dressing_vis_ms=%s" % [
			item.chunk.x, item.chunk.y, _ms(t_terrain - t), _ms(t_water - t_terrain),
			_ms(t_coll - t_water), _ms(t_end - t_coll)])
		node.free()
	if done and items.is_empty():
		if _thread != null: _thread.wait_to_finish()
		print("[stprof] DONE total_ms=%s" % _ms(Time.get_ticks_usec() - _t0))
		return true
	return false
