# scripts/terrain/field/FieldTerrainStreamer.gd
# Slim per-chunk streaming driver: builds field chunks within a radius of the
# player on ONE background thread. The worker returns CPU-side mesh arrays,
# collision faces, transforms, and sampler data only; the main thread commits
# those payloads into render/physics resources and nodes, budgeted per frame. Evicts
# beyond a keep radius. At startup the player is held until every chunk under
# their footprint exists; later, their current chunk alone gates movement.
class_name FieldTerrainStreamer
extends Node3D

const CHUNK_WORLD := 192.0   # TerrainChunkMesher.CHUNK_WORLD
## Half-extent used to identify every chunk beneath the player's spawn
## footprint. Spawn is intentionally on a chunk corner, so these four probes
## resolve to four support quadrants instead of only floor(pos / CHUNK_WORLD).
const STARTUP_SUPPORT_HALF_EXTENT := 0.5
## Calibrated from the cold 49-chunk phase profile. The first shared water
## trace/network region dominates startup and is tracked separately; treating
## it as one sixteenth of a feature block was why the old bar appeared frozen.
const STARTUP_COLD_PLAN_WEIGHT := 0.52
const STARTUP_COMPUTE_WEIGHT := 0.30
const STARTUP_FEATURE_WEIGHT := 0.10
const STARTUP_COMMIT_WEIGHT := 0.08
## Startup diagnostics are intentionally periodic rather than per-progress-tick:
## cold water planning emits thousands of updates, while one durable heartbeat
## every few seconds is enough to distinguish slow progress from a dead worker.
const DIAGNOSTIC_INTERVAL_MSEC := 5000
const SLOW_WORKER_PHASE_MSEC := 15000

signal startup_loading_progress_changed(progress: float, ready_chunks: int,
	total_chunks: int)
signal startup_loading_completed

@export var player: Node3D
@export var terrain_parent: Node
@export var CHUNK_RADIUS: int = 3
@export var KEEP_RADIUS: int = 4
## Finished background chunks INTEGRATED (added to the tree) per frame.
@export var MAX_BUILD_PER_FRAME: int = 1
## Render-only dressing batches committed per frame. Terrain/water readiness
## never waits for this queue.
@export var MAX_DRESSING_BATCHES_PER_FRAME: int = 2
@export var HEIGHTFIELD_AMPLITUDE: float = 22.0
@export var HEIGHTFIELD_MAX_STOREYS: int = 8
## Max storey difference between adjacent cells. 1 = all walkable slopes (SP1);
## 3 = cliffs up to 3 storeys (12m) form where the field steps down steeply.
@export var MAX_CLIFF_STEP: int = 3
## 0 = random each run. Set non-zero to pin the world for debugging (pairs
## with the F3 coord overlay screenshot workflow).
@export var SEED_OVERRIDE: int = 0

# Worker-thread pipeline instances. Their internal caches (plan sample memo,
# water trace/region caches) are touched ONLY by the worker thread — that
# confinement is the whole thread-safety story; no locks on the pipeline.
var _plan: HeightfieldPlan
var _water: WaterPlan
var _mesher: TerrainChunkMesher
var _water_builder := WaterSurfaceBuilder.new()
var _environment_catalog: EnvironmentCatalog
var _environment_cache: EnvironmentRenderCache
var _dressing_program: DressingProgram
var _dressing_queue: EnvironmentCommitQueue
var _path_program: PathProgram
var _settlements: SettlementPlan
var _fields: WorldFieldBlockCache
var _paths: PathPlan
var _feature_queue: EnvironmentCommitQueue
var _features_root: Node3D
var _built: Dictionary = {}        # Vector2i -> Node3D          (main thread only)
var _storey_snapshots: Dictionary = {} # Vector2i -> PackedInt32Array (main thread only)
var _feature_ready: Dictionary = {} # Vector2i -> generation, including empty blocks
var _feature_nodes: Dictionary = {} # Vector2i -> non-empty Node3D
var _terrain_generation: Dictionary = {}
var _feature_generation: Dictionary = {}
var _queued: Dictionary = {}       # Vector2i -> job Dictionary
var _active_job: Dictionary = {}
var _followups: Dictionary = {}
var _pending_terrain: Array[Dictionary] = []
var _startup_support_chunks: Array[Vector2i] = []
var _startup_feature_keys: Array[Vector2i] = []
## Worker-owned phase fractions mirrored through _mutex. Support chunks record
## the whole terrain pipeline; every required feature key records PathContext.
var _startup_worker_progress: Dictionary = {}
var _startup_path_progress: Dictionary = {}
var _startup_cold_plan_progress := 0.0
var _startup_ready_count: int = -1
var _startup_emitted_progress: float = -1.0
var _startup_completion_emitted: bool = false
## Worker state mirrored through _mutex for the main-thread diagnostic heartbeat.
## These values are observability only and never participate in build output.
var _worker_phase: StringName = &"idle"
var _worker_phase_chunk := Vector2i.ZERO
var _worker_phase_started_msec: int = 0
var _worker_job_started_msec: int = 0
var _diagnostic_started_msec: int = 0
var _last_diagnostic_msec: int = 0
var world_seed: int = 0
var _headless: bool = Helper.is_headless()

var _thread := Thread.new()
var _sem := Semaphore.new()
var _mutex := Mutex.new()          # guards _jobs, _done, _exit
var _jobs: Array[Dictionary] = []
var _done: Array[Dictionary] = []
var _exit := false

static func chunk_of(pos: Vector3) -> Vector2i:
	return Vector2i(int(floor(pos.x / CHUNK_WORLD)), int(floor(pos.z / CHUNK_WORLD)))

static func support_chunks_at(pos: Vector3) -> Array[Vector2i]:
	var unique: Dictionary = {}
	for dz: float in [-STARTUP_SUPPORT_HALF_EXTENT, STARTUP_SUPPORT_HALF_EXTENT]:
		for dx: float in [-STARTUP_SUPPORT_HALF_EXTENT, STARTUP_SUPPORT_HALF_EXTENT]:
			unique[chunk_of(pos + Vector3(dx, 0.0, dz))] = true
	var chunks: Array[Vector2i] = []
	chunks.assign(unique.keys())
	chunks.sort_custom(_key_less)
	return chunks

func desired_chunks(centre: Vector2i, radius: int) -> Array:
	var out: Array = []
	for dz in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			out.append(centre + Vector2i(dx, dz))
	return out

func _ready() -> void:
	if terrain_parent == null:
		return   # bare instance (unit test)
	_startup_support_chunks = support_chunks_at(player.global_position)
	world_seed = SEED_OVERRIDE if SEED_OVERRIDE != 0 else randi()
	_diagnostic_started_msec = Time.get_ticks_msec()
	_last_diagnostic_msec = _diagnostic_started_msec
	print("[terrain-streamer] startup_begin seed=%d support_chunks=%s" % [
		world_seed, str(_startup_support_chunks)])
	_water = WaterPlan.new(world_seed, HEIGHTFIELD_AMPLITUDE, HEIGHTFIELD_MAX_STOREYS)
	_settlements = SettlementPlan.new(world_seed, _water)
	_plan = HeightfieldPlan.new(world_seed, HEIGHTFIELD_AMPLITUDE,
		HEIGHTFIELD_MAX_STOREYS, "mean", MAX_CLIFF_STEP)
	_plan.set_water_plan(_water)
	_mesher = TerrainChunkMesher.new()
	_mesher.set_seed(world_seed)
	_environment_catalog = EnvironmentCatalog.load_default()
	assert(_environment_catalog != null)
	var dressing_index := load("res://terrain/dressing/index.tres") as DressingCatalogIndex
	assert(dressing_index != null)
	_dressing_program = DressingCompiler.compile(dressing_index, _environment_catalog)
	assert(_dressing_program != null)
	_path_program = PathProgram.compile(_environment_catalog)
	assert(_path_program != null)
	assert(_dressing_program.maximum_feature_clearance \
		<= _path_program.maximum_clearance,
		"PathProgram clearance coverage must contain every dressing margin")
	var combined_query_margin := maxf(_dressing_program.query_margin,
		_path_program.query_margin)
	var combined_shore_limit := maxf(_dressing_program.shore_distance_limit,
		_path_program.shore_distance_limit)
	assert(combined_query_margin + combined_shore_limit \
		<= WaterField.FILL_MARGIN * WaterField.FILL_STEP - WaterContour.MARGIN)
	_fields = WorldFieldBlockCache.new(_plan, _water, combined_query_margin,
		combined_shore_limit, _path_program.FIELD_CACHE_CAP)
	_paths = PathPlan.new(world_seed, _water, _fields, _path_program,
		combined_query_margin, _settlements)
	_paths.set_progress_callback(Callable(self, "_on_path_context_progress"))
	_paths.set_planning_progress_callback(
		Callable(self, "_on_cold_planning_progress"))
	_startup_feature_keys = _startup_required_feature_keys()
	print("[terrain-streamer] startup_plan seed=%d feature_keys=%d" % [
		world_seed, _startup_feature_keys.size()])
	_environment_cache = EnvironmentRenderCache.new(_environment_catalog)
	var active_set: Dictionary = {}
	for asset_id: StringName in _dressing_program.referenced_asset_ids:
		active_set[asset_id] = true
	for asset_id: StringName in _path_program.referenced_asset_ids:
		active_set[asset_id] = true
	for asset_id: StringName in CliffDressing.ASSETS.values():
		active_set[asset_id] = true
	var active_visuals: Array[StringName] = []
	active_visuals.assign(active_set.keys())
	active_visuals.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	assert(_environment_cache.prepare(active_visuals))
	_dressing_queue = EnvironmentCommitQueue.new(_environment_cache, &"Dressing")
	_feature_queue = EnvironmentCommitQueue.new(_environment_cache, &"Visuals")
	_features_root = Node3D.new()
	_features_root.name = &"ManmadeFeatures"
	add_child(_features_root)
	# Warm render resources and caches on the main thread before the worker
	# starts. The worker never touches them; this also keeps the first payload
	# commit from paying a visible resource-load hitch.
	CliffDressing.prepare(_environment_cache)
	CliffDressing.shared_material()
	WaterSurfaceBuilder.sheet_material()
	_mesher.prepare_resources()
	# Warm the biome tint materials + profiles on the main thread too, so the
	# worker only ever READS them (same no-locks confinement as above).
	BiomeRegistry.profile(&"meadow")
	# The spawn chunk is NOT built synchronously: the first build pays the
	# whole cold water-trace cache (~10s) and blocking _ready held a blank
	# grey window that long (owner). The worker builds it front-of-queue
	# while the player is HELD (see _process), and the window renders.
	_freeze_player(true)
	_thread.start(_worker)
	_emit_startup_loading_progress()


func startup_support_chunks() -> Array[Vector2i]:
	return _startup_support_chunks.duplicate()


func startup_loading_progress() -> float:
	# Startup is a one-way gate. Its original support chunks may be evicted once
	# the player travels beyond KEEP_RADIUS, but that must not make the public
	# loading state regress or restart the spawn build loop.
	if _startup_completion_emitted:
		return 1.0
	if _startup_support_chunks.is_empty():
		return 0.0
	var worker_progress: Dictionary
	var path_progress: Dictionary
	var cold_plan_progress: float
	_mutex.lock()
	worker_progress = _startup_worker_progress.duplicate()
	path_progress = _startup_path_progress.duplicate()
	cold_plan_progress = _startup_cold_plan_progress
	_mutex.unlock()
	var compute_sum := 0.0
	var commit_sum := 0.0
	for chunk: Vector2i in _startup_support_chunks:
		if _built.has(chunk):
			compute_sum += 1.0
			commit_sum += 1.0
		else:
			compute_sum += float(worker_progress.get(chunk, 0.0))
	var support_total := float(_startup_support_chunks.size())
	var compute_progress := compute_sum / support_total
	var commit_progress := commit_sum / support_total
	var feature_sum := 0.0
	for key: Vector2i in _startup_feature_keys:
		if int(_feature_ready.get(key, -1)) == int(_feature_generation.get(key, 0)):
			feature_sum += 1.0
		else:
			feature_sum += float(path_progress.get(key, 0.0))
	var feature_progress := feature_sum / float(_startup_feature_keys.size()) \
		if not _startup_feature_keys.is_empty() else compute_progress
	# Bare test instances have no feature set and preserve the intuitive support
	# fraction. Production has a separately measured shared cold-plan phase.
	if _startup_feature_keys.is_empty():
		cold_plan_progress = compute_progress
	return clampf(cold_plan_progress * STARTUP_COLD_PLAN_WEIGHT
		+ compute_progress * STARTUP_COMPUTE_WEIGHT
		+ feature_progress * STARTUP_FEATURE_WEIGHT
		+ commit_progress * STARTUP_COMMIT_WEIGHT, 0.0, 1.0)


func startup_loading_complete() -> bool:
	return _startup_completion_emitted or (
		not _startup_support_chunks.is_empty()
		and _startup_ready_chunks_count() == _startup_support_chunks.size())


func _emit_startup_loading_progress() -> void:
	if _startup_completion_emitted or _startup_support_chunks.is_empty():
		return
	var ready := _startup_ready_chunks_count()
	var progress := startup_loading_progress()
	if ready == _startup_ready_count \
			and absf(progress - _startup_emitted_progress) < 0.0005:
		return
	_startup_ready_count = ready
	_startup_emitted_progress = progress
	var total := _startup_support_chunks.size()
	startup_loading_progress_changed.emit(progress, ready, total)
	if ready == total and not _startup_completion_emitted:
		_startup_completion_emitted = true
		print("[terrain-streamer] startup_complete seed=%d elapsed_ms=%d chunks=%d" % [
			world_seed, Time.get_ticks_msec() - _diagnostic_started_msec, total])
		startup_loading_completed.emit()

func _startup_ready_chunks_count() -> int:
	var ready := 0
	for chunk: Vector2i in _startup_support_chunks:
		if _built.has(chunk):
			ready += 1
	return ready

func _startup_required_feature_keys() -> Array[Vector2i]:
	var unique: Dictionary = {}
	for chunk: Vector2i in _startup_support_chunks:
		for key: Vector2i in _feature_halo_keys(chunk):
			unique[key] = true
	var keys: Array[Vector2i] = []
	keys.assign(unique.keys())
	keys.sort_custom(_key_less)
	return keys

## Called on the worker thread by PathPlan. It touches only mutex-protected
## numeric progress records; the main thread owns all signal and UI emission.
func _on_path_context_progress(chunk: Vector2i, progress: float) -> void:
	if not _startup_feature_keys.has(chunk) and not _startup_support_chunks.has(chunk):
		return
	_mutex.lock()
	_startup_path_progress[chunk] = maxf(
		float(_startup_path_progress.get(chunk, 0.0)), progress)
	if _startup_support_chunks.has(chunk):
		_startup_worker_progress[chunk] = maxf(
			float(_startup_worker_progress.get(chunk, 0.0)), progress * 0.55)
	_mutex.unlock()

## The first cold WaterPlan region is shared by every subsequent support and
## feature context, so it is a global startup phase rather than 1/N of a chunk.
func _on_cold_planning_progress(progress: float) -> void:
	_mutex.lock()
	_startup_cold_plan_progress = maxf(_startup_cold_plan_progress,
		clampf(progress, 0.0, 1.0))
	_mutex.unlock()

## Called on the worker thread at completed pure-compute boundaries.
func _set_startup_worker_progress(chunk: Vector2i, progress: float) -> void:
	if not _startup_support_chunks.has(chunk):
		return
	_mutex.lock()
	_startup_worker_progress[chunk] = maxf(
		float(_startup_worker_progress.get(chunk, 0.0)), progress)
	_mutex.unlock()

# The player is HELD (physics + input off) until the startup support set is
# complete, and whenever their current chunk later has no terrain — teleports or
# outrunning the streamer — so they never fall through unbuilt ground.
var _player_frozen := false

func _freeze_player(on: bool) -> void:
	if player == null or _player_frozen == on:
		return
	_player_frozen = on
	player.process_mode = Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT

func _worker() -> void:
	while true:
		_sem.wait()
		_mutex.lock()
		if _exit:
			_mutex.unlock()
			return
		var job: Dictionary = _jobs.pop_front() if not _jobs.is_empty() else {}
		if not job.is_empty():
			_queued.erase(job.chunk)
			_active_job = job
		_mutex.unlock()
		if job.is_empty():
			continue
		var c: Vector2i = job.chunk
		_begin_worker_job(c, job)
		_begin_worker_phase(c, &"path_context")
		var paths := _paths.context_for(c)
		_set_startup_worker_progress(c, 0.55)
		var result := {
			"chunk": c,
			"build_terrain": bool(job.build_terrain),
			"terrain_generation": int(job.terrain_generation),
			"build_features": bool(job.build_features),
			"feature_generation": int(job.feature_generation),
		}
		if job.build_features:
			_begin_worker_phase(c, &"feature_placements")
			result["features"] = paths.placements()
			_set_startup_worker_progress(c, 0.58)
		if job.build_terrain:
			_begin_worker_phase(c, &"heightfield_region")
			var region := _fields.region(c)
			_set_startup_worker_progress(c, 0.62)
			_begin_worker_phase(c, &"water_context")
			var water_context := _fields.water(c)
			_set_startup_worker_progress(c, 0.67)
			var core := Rect2(Vector2(c) * CHUNK_WORLD, Vector2.ONE * CHUNK_WORLD)
			result["storeys"] = _storey_snapshot(c, region)
			_begin_worker_phase(c, &"terrain_mesh")
			result["terrain"] = _mesher.compute_chunk(c, region, water_context, paths)
			_set_startup_worker_progress(c, 0.82)
			_begin_worker_phase(c, &"water_mesh")
			result["water"] = _water_builder.compute_chunk(_water, c, region, water_context)
			_set_startup_worker_progress(c, 0.88)
			_begin_worker_phase(c, &"dressing")
			result["dressing"] = DressingField.compute(_dressing_program, world_seed,
				core, region, water_context, paths)
			_set_startup_worker_progress(c, 0.97)
			# FX data stays worker-side; nodes are built during integration.
			_begin_worker_phase(c, &"biome_fx")
			result["fx"] = _biome_fx_data(c, region)
			_set_startup_worker_progress(c, 1.0)
		_finish_worker_job(c)
		_mutex.lock()
		_done.append(result)
		_active_job = {}
		if _followups.has(c):
			var followup: Dictionary = _followups[c]
			_followups.erase(c)
			_queued[c] = followup
			_jobs.append(followup)
			_sort_jobs_locked()
			_sem.post()
		_mutex.unlock()


## Worker-thread phase markers. Startup jobs log their boundaries; later jobs
## stay quiet unless a completed phase exceeded the slow-phase threshold.
func _begin_worker_job(chunk: Vector2i, job: Dictionary) -> void:
	var now := Time.get_ticks_msec()
	_mutex.lock()
	_worker_phase_chunk = chunk
	_worker_phase = &"starting"
	_worker_phase_started_msec = now
	_worker_job_started_msec = now
	_mutex.unlock()
	if _is_startup_diagnostic_chunk(chunk):
		print("[terrain-streamer] worker_job_begin seed=%d chunk=%d,%d terrain=%s features=%s" % [
			world_seed, chunk.x, chunk.y, str(bool(job.build_terrain)),
			str(bool(job.build_features))])


func _begin_worker_phase(chunk: Vector2i, phase: StringName) -> void:
	var now := Time.get_ticks_msec()
	var previous: StringName
	var previous_elapsed: int
	var job_elapsed: int
	_mutex.lock()
	previous = _worker_phase
	previous_elapsed = now - _worker_phase_started_msec
	job_elapsed = now - _worker_job_started_msec
	_worker_phase_chunk = chunk
	_worker_phase = phase
	_worker_phase_started_msec = now
	_mutex.unlock()
	if _is_startup_diagnostic_chunk(chunk) or previous_elapsed >= SLOW_WORKER_PHASE_MSEC:
		print("[terrain-streamer] worker_phase seed=%d chunk=%d,%d phase=%s previous=%s previous_ms=%d job_ms=%d" % [
			world_seed, chunk.x, chunk.y, String(phase), String(previous),
			previous_elapsed, job_elapsed])


func _finish_worker_job(chunk: Vector2i) -> void:
	var now := Time.get_ticks_msec()
	var phase: StringName
	var phase_elapsed: int
	var job_elapsed: int
	_mutex.lock()
	phase = _worker_phase
	phase_elapsed = now - _worker_phase_started_msec
	job_elapsed = now - _worker_job_started_msec
	_worker_phase = &"idle"
	_worker_phase_started_msec = now
	_worker_job_started_msec = 0
	_mutex.unlock()
	if _is_startup_diagnostic_chunk(chunk) or phase_elapsed >= SLOW_WORKER_PHASE_MSEC:
		print("[terrain-streamer] worker_job_complete seed=%d chunk=%d,%d final_phase=%s phase_ms=%d job_ms=%d" % [
			world_seed, chunk.x, chunk.y, String(phase), phase_elapsed, job_elapsed])


func _is_startup_diagnostic_chunk(chunk: Vector2i) -> bool:
	return _startup_support_chunks.has(chunk) or _startup_feature_keys.has(chunk)

# Worker-thread: pure data for the chunk's biome FX (dominant profile + ground-
# anchored light points). No node/renderer calls — those happen on the main
# thread in _build_fx. Empty when headless (FX is render-only).
func _biome_fx_data(c: Vector2i, region) -> Dictionary:
	if _headless:
		return {}
	var origin := Vector3(float(c.x) * CHUNK_WORLD, 0.0, float(c.y) * CHUNK_WORLD)
	var centre := origin + Vector3(CHUNK_WORLD * 0.5, 0.0, CHUNK_WORLD * 0.5)
	var prof := BiomeRegistry.profile(Helper.biome_at(centre, world_seed))
	var light_points: Array = []
	if BiomeChunkFx.wants_light_points(prof):
		for i in 3:
			var hx := Helper._cell_hash01(world_seed + 7000 + i, c.x, c.y)
			var hz := Helper._cell_hash01(world_seed + 8000 + i, c.x, c.y)
			var lx := origin.x + hx * CHUNK_WORLD
			var lz := origin.z + hz * CHUNK_WORLD
			var ly := TerrainSurfaceField.surface_y(region, lx, lz) + 2.5
			light_points.append(Vector3(lx - origin.x, ly, lz - origin.z))
	# The chunk's surface height band — particle emission + pocket fog hug the
	# actual ground instead of a fixed 0..12 band (orbs on a storey-5 plateau
	# floated inside the terrain / far underfoot before).
	var surf_lo := INF
	var surf_hi := -INF
	var lo_cx := c.x * TerrainChunkMesher.CELLS_PER_CHUNK
	var lo_cz := c.y * TerrainChunkMesher.CELLS_PER_CHUNK
	for dz in TerrainChunkMesher.CELLS_PER_CHUNK:
		for dx in TerrainChunkMesher.CELLS_PER_CHUNK:
			var h: float = region.surface_height(lo_cx + dx, lo_cz + dz)
			surf_lo = minf(surf_lo, h)
			surf_hi = maxf(surf_hi, h)
	return {"profile": prof, "lights": light_points, "origin": origin,
			"surf_lo": surf_lo, "surf_hi": surf_hi}

# Main-thread: build the FX nodes from the worker's data and parent them under
# the (now in-tree) chunk node.
func _build_fx(node: Node3D, fx_data: Dictionary) -> void:
	if fx_data.is_empty():
		return
	var fx := BiomeChunkFx.build(fx_data["profile"], fx_data["lights"],
			fx_data["surf_lo"], fx_data["surf_hi"])
	fx.position = fx_data["origin"]
	node.add_child(fx)


func _process(_delta: float) -> void:
	if _plan == null or player == null:
		return
	var centre := chunk_of(player.global_position)
	_dressing_queue.drain(MAX_DRESSING_BATCHES_PER_FRAME)
	_feature_queue.drain(MAX_DRESSING_BATCHES_PER_FRAME)
	_drain_results(centre)
	_integrate_pending_terrain(centre)
	_emit_startup_loading_progress()
	_log_worker_diagnostics()
	var current_chunk_ready := _built.has(centre) and _feature_square_ready(centre)
	_freeze_player(not current_chunk_ready or not startup_loading_complete())
	# Startup is the one time the player deliberately straddles a four-chunk
	# corner. Queue those four terrain+feature jobs ahead of the normal radius so
	# the loading screen tracks the exact support set it is waiting for.
	if not startup_loading_complete():
		var startup_wakes := 0
		_mutex.lock()
		for chunk: Vector2i in _startup_support_chunks:
			if _built.has(chunk) or _has_pending_terrain(chunk):
				continue
			var priority := -2 if chunk == centre else -1
			if _request_job_locked(chunk, true, true, priority):
				startup_wakes += 1
		_mutex.unlock()
		for _i in startup_wakes:
			_sem.post()
	# The player's terrain request receives distance zero. It stays asynchronous.
	if not _built.has(centre) and not _has_pending_terrain(centre):
		_mutex.lock()
		var wake := _request_job_locked(centre, true, true, 0)
		_mutex.unlock()
		if wake:
			_sem.post()
	# Queue missing chunks nearest-first, so terrain grows outward from the player.
	var requested := 0
	for c: Vector2i in desired_chunks(centre, CHUNK_RADIUS):
		if _built.has(c) or _has_pending_terrain(c):
			continue
		_mutex.lock()
		if _request_job_locked(c, true, true,
				maxi(absi(c.x - centre.x), absi(c.y - centre.y))):
			requested += 1
		_mutex.unlock()
	for _i in requested:
		_sem.post()
	# Evict chunks beyond keep radius (Chebyshev).
	for c: Vector2i in _built.keys():
		if maxi(absi(c.x - centre.x), absi(c.y - centre.y)) > KEEP_RADIUS:
			_dressing_queue.invalidate_chunk(c)
			_built[c].queue_free()
			_built.erase(c)
			_storey_snapshots.erase(c)
			_terrain_generation[c] = int(_terrain_generation.get(c, 0)) + 1
	var feature_keep := KEEP_RADIUS + _path_program.feature_halo
	for c: Vector2i in _feature_ready.keys():
		if maxi(absi(c.x - centre.x), absi(c.y - centre.y)) > feature_keep:
			_feature_queue.invalidate_chunk(c)
			if _feature_nodes.has(c):
				_feature_nodes[c].queue_free()
				_feature_nodes.erase(c)
			_feature_ready.erase(c)
			_feature_generation[c] = int(_feature_generation.get(c, 0)) + 1


## Main-thread durable heartbeat. During startup it proves that the window is
## alive and records the exact long-running phase; after startup it emits only
## for a phase that has crossed the slow threshold.
func _log_worker_diagnostics() -> void:
	var now := Time.get_ticks_msec()
	var startup_pending := not startup_loading_complete()
	var active_job: Dictionary
	var phase: StringName
	var phase_chunk: Vector2i
	var phase_started: int
	var job_started: int
	var cold_plan_progress: float
	var queued_count: int
	var done_count: int
	_mutex.lock()
	active_job = _active_job.duplicate()
	phase = _worker_phase
	phase_chunk = _worker_phase_chunk
	phase_started = _worker_phase_started_msec
	job_started = _worker_job_started_msec
	cold_plan_progress = _startup_cold_plan_progress
	queued_count = _jobs.size()
	done_count = _done.size()
	_mutex.unlock()
	var phase_elapsed := now - phase_started if phase_started > 0 else 0
	if not startup_pending and (active_job.is_empty() \
			or phase_elapsed < SLOW_WORKER_PHASE_MSEC):
		return
	var interval := DIAGNOSTIC_INTERVAL_MSEC if startup_pending \
		else SLOW_WORKER_PHASE_MSEC
	if now - _last_diagnostic_msec < interval:
		return
	_last_diagnostic_msec = now
	var ready := _startup_ready_chunks_count()
	var progress := startup_loading_progress()
	var job_elapsed := now - job_started if job_started > 0 else 0
	var prefix := "startup_heartbeat" if startup_pending else "slow_worker"
	print("[terrain-streamer] %s seed=%d elapsed_ms=%d progress=%.4f ready=%d/%d cold_plan=%.4f chunk=%d,%d phase=%s phase_ms=%d job_ms=%d queued=%d done=%d pending=%d built=%d feature_ready=%d" % [
		prefix, world_seed, now - _diagnostic_started_msec, progress, ready,
		_startup_support_chunks.size(), cold_plan_progress, phase_chunk.x,
		phase_chunk.y, String(phase), phase_elapsed, job_elapsed, queued_count,
		done_count, _pending_terrain.size(), _built.size(), _feature_ready.size()])

func _drain_results(centre: Vector2i) -> void:
	var results: Array[Dictionary] = []
	_mutex.lock()
	results.assign(_done)
	_done.clear()
	_mutex.unlock()
	# Features first: a result may make several completed terrain payloads ready.
	for result: Dictionary in results:
		if result.build_features:
			_commit_feature_result(result, centre)
	for result: Dictionary in results:
		if not result.build_terrain:
			continue
		var c: Vector2i = result.chunk
		if int(_terrain_generation.get(c, 0)) != int(result.terrain_generation) \
			or _built.has(c) \
			or maxi(absi(c.x - centre.x), absi(c.y - centre.y)) > KEEP_RADIUS:
			continue
		_pending_terrain.append(result)
		var requested := 0
		_mutex.lock()
		for key: Vector2i in _feature_halo_keys(c):
			if not _feature_ready.has(key) \
				and _request_job_locked(key, false, true,
					maxi(absi(c.x - centre.x), absi(c.y - centre.y))):
				requested += 1
		_mutex.unlock()
		for _i in requested:
			_sem.post()
	_pending_terrain.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var da := maxi(absi(a.chunk.x - centre.x), absi(a.chunk.y - centre.y))
		var db := maxi(absi(b.chunk.x - centre.x), absi(b.chunk.y - centre.y))
		return da < db or (da == db and _key_less(a.chunk, b.chunk)))

func _commit_feature_result(result: Dictionary, centre: Vector2i) -> void:
	var c: Vector2i = result.chunk
	var generation: int = result.feature_generation
	if int(_feature_generation.get(c, 0)) != generation \
		or _feature_ready.has(c) \
		or maxi(absi(c.x - centre.x), absi(c.y - centre.y)) \
		> KEEP_RADIUS + _path_program.feature_halo:
		return
	var payload: EnvironmentInstancePayload = result.features
	if payload.instance_count > 0:
		var block := Node3D.new()
		block.name = "FeatureBlock_%d_%d" % [c.x, c.y]
		EnvironmentCollisionBuilder.commit(block, payload, _environment_cache,
			&"FeatureCollision")
		_features_root.add_child(block)
		_feature_nodes[c] = block
		_feature_queue.register_chunk(c, generation)
		_feature_queue.enqueue(c, generation, block, payload)
	_feature_ready[c] = generation

func _integrate_pending_terrain(centre: Vector2i) -> void:
	var integrated := 0
	var remaining: Array[Dictionary] = []
	for result: Dictionary in _pending_terrain:
		var c: Vector2i = result.chunk
		if int(_terrain_generation.get(c, 0)) != int(result.terrain_generation) \
			or _built.has(c) \
			or maxi(absi(c.x - centre.x), absi(c.y - centre.y)) > KEEP_RADIUS:
			continue
		if integrated >= MAX_BUILD_PER_FRAME or not _feature_square_ready(c):
			remaining.append(result)
			continue
		var node: Node3D = _mesher.commit_chunk(result.terrain)
		var water_node: Node3D = _water_builder.commit_chunk(result.water)
		if water_node != null:
			node.add_child(water_node)
		EnvironmentCollisionBuilder.commit(node, result.dressing, _environment_cache,
			&"DressingCollision")
		terrain_parent.add_child(node)
		_build_fx(node, result.fx)
		_built[c] = node
		_storey_snapshots[c] = result.storeys
		var generation: int = result.terrain_generation
		_dressing_queue.register_chunk(c, generation)
		_dressing_queue.enqueue(c, generation, node, result.dressing)
		integrated += 1
	_pending_terrain = remaining

## Main-thread debug query over immutable data delivered with each committed
## chunk. This deliberately never reaches into the worker-owned plan or its
## mutable terrain/water caches.
func loaded_storey_at(cell: Vector2i) -> Variant:
	var side := TerrainChunkMesher.CELLS_PER_CHUNK
	var chunk := Vector2i(floori(float(cell.x) / side), floori(float(cell.y) / side))
	var values: PackedInt32Array = _storey_snapshots.get(chunk, PackedInt32Array())
	if values.size() != side * side:
		return null
	var local := cell - chunk * side
	return values[local.y * side + local.x]

static func _storey_snapshot(chunk: Vector2i, region: HeightfieldRegion) -> PackedInt32Array:
	var side := TerrainChunkMesher.CELLS_PER_CHUNK
	var values := PackedInt32Array()
	values.resize(side * side)
	var first := chunk * side
	for z in side:
		for x in side:
			values[z * side + x] = region.storey_at(first.x + x, first.y + z)
	return values

func _feature_halo_keys(chunk: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dz in range(-_path_program.feature_halo, _path_program.feature_halo + 1):
		for dx in range(-_path_program.feature_halo, _path_program.feature_halo + 1):
			out.append(chunk + Vector2i(dx, dz))
	out.sort_custom(_key_less)
	return out

func _feature_square_ready(chunk: Vector2i) -> bool:
	if _path_program == null:
		return false
	for key: Vector2i in _feature_halo_keys(chunk):
		if int(_feature_ready.get(key, -1)) != int(_feature_generation.get(key, 0)):
			return false
	return true

func _has_pending_terrain(chunk: Vector2i) -> bool:
	for result: Dictionary in _pending_terrain:
		if result.chunk == chunk:
			return true
	return false

## Caller holds _mutex. Returns true only when a new semaphore wake is needed.
func _request_job_locked(chunk: Vector2i, build_terrain: bool,
		build_features: bool, priority_distance: int) -> bool:
	if build_terrain and _built.has(chunk):
		build_terrain = false
	if build_features and _feature_ready.has(chunk):
		build_features = false
	if not build_terrain and not build_features:
		return false
	if not _terrain_generation.has(chunk):
		_terrain_generation[chunk] = 1
	if not _feature_generation.has(chunk):
		_feature_generation[chunk] = 1
	if _queued.has(chunk):
		var queued: Dictionary = _queued[chunk]
		queued.build_terrain = bool(queued.build_terrain) or build_terrain
		queued.build_features = bool(queued.build_features) or build_features
		queued.priority_distance = mini(int(queued.priority_distance), priority_distance)
		_queued[chunk] = queued
		for i in _jobs.size():
			if _jobs[i].chunk == chunk:
				_jobs[i] = queued
				break
		_sort_jobs_locked()
		return false
	if not _active_job.is_empty() and _active_job.chunk == chunk:
		var followup: Dictionary = _followups.get(chunk, _new_job(chunk, false, false,
			priority_distance))
		followup.build_terrain = bool(followup.build_terrain) \
			or (build_terrain and not bool(_active_job.build_terrain))
		followup.build_features = bool(followup.build_features) \
			or (build_features and not bool(_active_job.build_features))
		followup.priority_distance = mini(int(followup.priority_distance), priority_distance)
		if followup.build_terrain or followup.build_features:
			_followups[chunk] = followup
		return false
	var job := _new_job(chunk, build_terrain, build_features, priority_distance)
	_queued[chunk] = job
	_jobs.append(job)
	_sort_jobs_locked()
	return true

func _new_job(chunk: Vector2i, build_terrain: bool,
		build_features: bool, priority_distance: int) -> Dictionary:
	return {"chunk": chunk, "build_terrain": build_terrain,
		"terrain_generation": int(_terrain_generation.get(chunk, 1)),
		"build_features": build_features,
		"feature_generation": int(_feature_generation.get(chunk, 1)),
		"priority_distance": priority_distance}

func _sort_jobs_locked() -> void:
	_jobs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.priority_distance) != int(b.priority_distance):
			return int(a.priority_distance) < int(b.priority_distance)
		if bool(a.build_features) != bool(b.build_features):
			return bool(a.build_features)
		return _key_less(a.chunk, b.chunk))

static func _key_less(a: Vector2i, b: Vector2i) -> bool:
	return a.x < b.x or (a.x == b.x and a.y < b.y)

func _exit_tree() -> void:
	if not _thread.is_started():
		return
	# Stop queuing work at a dead worker: after this point _process must not run.
	set_process(false)
	_mutex.lock()
	_exit = true
	_mutex.unlock()
	_sem.post()
	_thread.wait_to_finish()
	# Pending entries are CPU-side payloads only; releasing the arrays and
	# RefCounted samplers is sufficient and safe on the main thread.
	_done.clear()
	if _dressing_queue != null:
		_dressing_queue.clear()
	if _feature_queue != null:
		_feature_queue.clear()
