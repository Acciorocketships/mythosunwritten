# scripts/terrain/field/FieldTerrainStreamer.gd
# Slim per-chunk streaming driver: builds field chunks within a radius of the
# player on ONE background thread. The worker returns CPU-side mesh arrays,
# collision faces, transforms, and sampler data only; the main thread commits
# those payloads into render/physics resources and nodes, budgeted per frame. Evicts
# beyond a keep radius. At startup the player is held until every chunk within
# one terrain chunk of spawn exists, providing the first travel buffer;
# discontinuous relocations prepare the same buffer. During ordinary travel,
# the current chunk gates movement while forward deadlines prepare crossings.
class_name FieldTerrainStreamer
extends Node3D

const CHUNK_WORLD := TerrainChunkMesher.CHUNK_WORLD   # 192 m, 16 x 16 lattice points
## A camera-sized loading boundary can release the runner seconds before an
## unbuilt seam. The surrounding ring supplies at least 192 m of initial
## travel in every direction while the worker prepares the next crossings.
## These chunks already belong to the ordinary streaming footprint.
const STARTUP_SUPPORT_HALF_EXTENT := CHUNK_WORLD
const TERRAIN_PREFETCH_RADIUS := CHUNK_WORLD * 0.5
const PREFETCH_SECONDS := 30.0
const PRIORITY_FOCUS_STEP := 8.0
## Keep the production spawn just inside one chunk instead of exactly on the
## four-way world-origin seam so the player capsule has one collision owner.
## The startup environment gate still includes all nearby visible quadrants.
const DEFAULT_SPAWN_POSITION := Vector3(0.5, 0.0, 0.5)
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
## Structural features demand-load and build collision before readiness. Each
## cap bounds one main-thread stage; the elapsed budget bounds their sum.
@export var MAX_FEATURE_ASSET_LOADS_PER_FRAME: int = 1
@export var MAX_FEATURE_COLLISION_SHAPES_PER_FRAME: int = 24
@export var MAX_FEATURE_COMMIT_USEC: int = 2500
## Dense grass is visual-only and is skipped by headless terrain/test runs.
## Its field and renderer have direct headless tests; production enables it.
@export var GRASS_ENABLED: bool = true
## 0 = random each run. Set non-zero to pin the world for debugging (pairs
## with the F3 coord overlay screenshot workflow).
@export var SEED_OVERRIDE: int = 0
## Cliff rock art direction (`CliffRockStyle.apply` name) for this world;
## empty keeps the style's defaults.
@export var CLIFF_STYLE: String = ""
## Opt-in travel diagnostics; no per-frame logging or field changes.
@export var PROFILE_STREAMING := false
var _telemetry := TerrainStreamingTelemetry.new()
var _queue_focus := Vector2i(2147483647, 2147483647)
var _profile_player_chunk := Vector2i.ZERO
var _queue_lod_origin := Vector2.ZERO
var _queue_travel_offset := Vector2.ZERO
var _queue_heading := Vector2i.ZERO
var _requested_centre := Vector2i(2147483647, 2147483647)
var _requested_startup := true

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
var _feature_program: FeatureProgram
var _settlements: SettlementPlan
var _fields: WorldFieldBlockCache
var _features: WorldFeaturePlan
var _feature_queue: FeatureCommitQueue
var _features_root: Node3D
var _grass_program: GrassProgram
var _grass_work: GrassWorkQueue
var _grass_streamer: GrassStreamer
var _grass_root: Node3D
var _trample_field: TrampleField
var _grass_runtime_enabled := false
var _dressing_trample_by_chunk: Dictionary = {} # Vector2i -> Array[Dictionary]
var _static_trample_dirty := false
var _built: Dictionary = {}        # Vector2i -> Node3D          (main thread only)
var _storey_snapshots: Dictionary = {} # Vector2i -> PackedInt32Array per lattice point (main thread only)
var _point_snapshots: Dictionary = {} # Vector2i -> PackedFloat32Array (height, graded) per lattice point (main thread only)
var _feature_ready: Dictionary = {} # Vector2i -> generation, including empty blocks
var _feature_nodes: Dictionary = {} # Vector2i -> non-empty Node3D
var _terrain_generation: Dictionary = {}
var _feature_generation: Dictionary = {}
var _queued: Dictionary = {}       # Vector2i -> job Dictionary
var _active_job: Dictionary = {}
var _followups: Dictionary = {}
var _pending_terrain: Array[Dictionary] = []
# Guarded by _mutex. Terrain requests retain dependency ownership before the
# worker starts, so activation work cannot arrive behind its next long mesh.
var _terrain_feature_parents: Dictionary = {}
var _startup_support_chunks: Array[Vector2i] = []
var _arrival_support_chunks: Array[Vector2i] = []
var _last_stream_position := Vector3(INF, INF, INF)
var _startup_feature_keys: Array[Vector2i] = []
## Worker-owned phase fractions mirrored through _mutex. Support chunks record
## the whole terrain pipeline; every required feature key records FeatureContext.
var _startup_worker_progress: Dictionary = {}
var _startup_feature_progress: Dictionary = {}
var _startup_cold_plan_progress := 0.0
var _startup_ready_count: int = -1
var _startup_emitted_progress: float = -1.0
var _startup_completion_emitted: bool = false
var _startup_previous_max_fps := -1
## Worker state mirrored through _mutex for the main-thread diagnostic heartbeat.
## These values are observability only and never participate in build output.
var _worker_phase: StringName = &"idle"
var _active_job_yield_requested := false
var _worker_phase_chunk := Vector2i.ZERO
var _worker_phase_started_msec: int = 0
var _worker_job_started_msec: int = 0
var _worker_job_kind: StringName = &"chunk"
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
	var extent:=Vector3(STARTUP_SUPPORT_HALF_EXTENT,0,STARTUP_SUPPORT_HALF_EXTENT)
	var lo:=chunk_of(pos-extent)
	var hi:=chunk_of(pos+extent)
	var chunks: Array[Vector2i] = []
	for x in range(lo.x,hi.x+1):
		for z in range(lo.y,hi.y+1):
			chunks.append(Vector2i(x,z))
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
	# The loading overlay does not need hundreds of redraws per second while
	# generation owns the CPU. Restore the caller's limit before gameplay.
	if not Helper.is_headless() and (Engine.max_fps == 0 or Engine.max_fps > 30):
		_startup_previous_max_fps = Engine.max_fps
		Engine.max_fps = 30
	_telemetry.enabled = PROFILE_STREAMING
	_startup_support_chunks = support_chunks_at(player.global_position)
	world_seed = SEED_OVERRIDE if SEED_OVERRIDE != 0 else randi()
	if not CLIFF_STYLE.is_empty():
		preload("res://scripts/terrain/field/CliffRockStyle.gd").apply(CLIFF_STYLE)
	_diagnostic_started_msec = Time.get_ticks_msec()
	_last_diagnostic_msec = _diagnostic_started_msec
	print("[terrain-streamer] startup_begin seed=%d support_chunks=%s" % [
		world_seed, str(_startup_support_chunks)])
	# The canonical tuning keeps the streamed world and offline harnesses from
	# silently constructing different terrain fields.
	_water = TerrainWorldTuning.make_water(world_seed)
	_settlements = SettlementPlan.new(world_seed, _water)
	_plan = TerrainWorldTuning.make_heightfield(world_seed, _water)
	_mesher = TerrainChunkMesher.new()
	_mesher.profile_enabled = PROFILE_STREAMING
	_mesher.set_seed(world_seed)
	_environment_catalog = EnvironmentCatalog.load_default()
	assert(_environment_catalog != null)
	_environment_cache = EnvironmentRenderCache.new(_environment_catalog)
	var dressing_index := load("res://terrain/dressing/index.tres") as DressingCatalogIndex
	assert(dressing_index != null)
	_dressing_program = DressingCompiler.compile(dressing_index, _environment_catalog)
	assert(_dressing_program != null)
	_feature_program = FeatureProgram.compile(_environment_catalog)
	assert(_feature_program != null)
	if GRASS_ENABLED:
		var grass_settings := load("res://terrain/grass/settings.tres") as GrassSettings
		_grass_program = GrassProgram.compile(grass_settings, _environment_catalog,
			_environment_cache)
		assert(_grass_program != null)
	assert(_dressing_program.maximum_feature_clearance \
		<= _feature_program.maximum_clearance,
		"FeatureProgram clearance coverage must contain every dressing margin")
	var combined_query_margin := maxf(_dressing_program.query_margin,
		_feature_program.query_margin)
	# Road verges (HeightfieldRegion.with_road_verges) grade a point from the
	# roads within one point of it: every point the cliff slope reads beyond
	# its chunk (CliffSlopeField.GROUND_REACH) needs the same roads its own
	# chunk sees, or neighbouring chunks dress one cliff differently.
	var feature_context_margin := maxf(maxf(_feature_program.query_margin,
		_dressing_program.feature_query_margin),
		preload("res://scripts/terrain/field/CliffSlopeField.gd").GROUND_REACH + HeightfieldPlan.POINT)
	var combined_shore_limit := maxf(_dressing_program.shore_distance_limit,
		_feature_program.shore_distance_limit)
	if _grass_program != null:
		combined_query_margin = maxf(combined_query_margin,
			_grass_program.query_margin)
		combined_shore_limit = maxf(combined_shore_limit,
			_grass_program.shore_distance_limit)
	assert(combined_query_margin + combined_shore_limit \
		<= WaterField.FILL_MARGIN * WaterField.FILL_STEP - WaterContour.MARGIN)
	_fields = WorldFieldBlockCache.new(_plan, _water, combined_query_margin,
		combined_shore_limit, _feature_program.field_cache_cap)
	_features = WorldFeaturePlan.new(world_seed, _water, _fields,
		_feature_program, _settlements, feature_context_margin)
	# Miss/stage observers are cheap and keep slow-operation logs useful in
	# ordinary play. Detailed bounded event samples remain explicitly opt-in.
	_features.profile_stage_callback = Callable(self, "_begin_worker_phase")
	_fields.profile_callback = Callable(self, "_profile_field_operation")
	# The cliff slope samples neighbouring blocks' water from the same cache.
	_mesher.water_blocks = _fields
	_mesher.phase_callback = Callable(self, "_begin_worker_phase")
	_features.set_progress_callback(Callable(self, "_on_feature_context_progress"))
	_features.set_planning_progress_callback(
		Callable(self, "_on_cold_planning_progress"))
	_startup_feature_keys = _startup_required_feature_keys()
	print("[terrain-streamer] startup_plan seed=%d feature_keys=%d" % [
		world_seed, _startup_feature_keys.size()])
	var active_set: Dictionary = {}
	for asset_id: StringName in _dressing_program.referenced_asset_ids:
		active_set[asset_id] = true
	# Man-made features are demand-warmed by FeatureCommitQueue. Keeping them
	# out of startup preparation makes village catalogue growth load-proportional.
	if _grass_program != null:
		for asset_id: StringName in _grass_program.referenced_asset_ids:
			active_set[asset_id] = true
	for asset_id: StringName in CliffDressing.ASSETS.values():
		active_set[asset_id] = true
	var active_visuals: Array[StringName] = []
	active_visuals.assign(active_set.keys())
	active_visuals.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	assert(_environment_cache.prepare(active_visuals))
	_dressing_queue = EnvironmentCommitQueue.new(_environment_cache, &"Dressing")
	_feature_queue = FeatureCommitQueue.new(_environment_cache)
	_features_root = Node3D.new()
	_features_root.name = &"ManmadeFeatures"
	add_child(_features_root)
	# Warm the one shared terrain palette before constructing grass materials;
	# grass binds its live texture/UV instead of copying a sampled colour.
	CliffDressing.prepare(_environment_cache)
	CliffDressing.shared_material()
	WaterSurfaceBuilder.sheet_material()
	_mesher.prepare_resources()
	_grass_runtime_enabled = GRASS_ENABLED and not _headless
	if _grass_runtime_enabled:
		_grass_streamer = GrassStreamer.new(_grass_program, _environment_cache)
		_grass_work = GrassWorkQueue.new(_grass_program, world_seed)
		_grass_root = Node3D.new()
		_grass_root.name = &"Grass"
		add_child(_grass_root)
		_trample_field = TrampleField.new()
		_trample_field.name = &"TrampleField"
		_trample_field.player = player
		# Observe the character after ordinary gameplay _process callbacks.
		_trample_field.process_priority = 100
		add_child(_trample_field)
	# Warm render resources and caches on the main thread before the worker
	# starts. The worker never touches them; this also keeps the first payload
	# commit from paying a visible resource-load hitch.
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
	var feature_progress_by_key: Dictionary
	var cold_plan_progress: float
	_mutex.lock()
	worker_progress = _startup_worker_progress.duplicate()
	feature_progress_by_key = _startup_feature_progress.duplicate()
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
			feature_sum += float(feature_progress_by_key.get(key, 0.0))
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
		_restore_startup_render_limit()
		print("[terrain-streamer] startup_complete seed=%d elapsed_ms=%d chunks=%d" % [
			world_seed, Time.get_ticks_msec() - _diagnostic_started_msec, total])
		startup_loading_completed.emit()

func _restore_startup_render_limit() -> void:
	if _startup_previous_max_fps < 0: return
	# A later explicit setting takes precedence over the temporary limit.
	if Engine.max_fps == 30: Engine.max_fps = _startup_previous_max_fps
	_startup_previous_max_fps = -1

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

## Called on the worker thread by WorldFeaturePlan. It touches only mutex-protected
## numeric progress records; the main thread owns all signal and UI emission.
func _on_feature_context_progress(chunk: Vector2i, progress: float) -> void:
	if not _startup_feature_keys.has(chunk) and not _startup_support_chunks.has(chunk):
		return
	_mutex.lock()
	_startup_feature_progress[chunk] = maxf(
		float(_startup_feature_progress.get(chunk, 0.0)), progress)
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

## A near chunk may need only a distant block's feature geometry. Publish that
## dependency before spending seconds meshing the distant block's terrain.
## The terrain component keeps its own current distance in a normal follow-up.
func _take_job_locked() -> Dictionary:
	if _jobs.is_empty(): return {}
	var job: Dictionary = _jobs.pop_front()
	if StringName(job.get("kind", &"chunk")) == &"chunk" \
			and bool(job.build_terrain) and bool(job.build_features):
		var distance := maxi(absi(job.chunk.x - _profile_player_chunk.x), absi(job.chunk.y - _profile_player_chunk.y))
		var tier := _terrain_priority_tier(job.chunk, _profile_player_chunk, _queue_lod_origin)
		var dependency_first := int(job.priority_tier) < tier \
			or (int(job.priority_tier) == tier and int(job.priority_distance) < distance) \
			or _job_ground_distance(job) < _ground_distance(job.chunk) - 0.000001
		# Startup support terrain is explicitly urgent in its own right.
		if dependency_first and startup_loading_complete():
			_followups[job.chunk] = _new_job(job.chunk, true, false, distance, tier)
			job = job.duplicate()
			job.build_terrain = false
			_telemetry.count(&"feature_dependency_splits")
	return job


func _worker() -> void:
	while true:
		_sem.wait()
		_mutex.lock()
		if _exit:
			_mutex.unlock()
			return
		var job := _take_job_locked()
		if not job.is_empty():
			_queued.erase(job.chunk)
			_active_job = job
			_telemetry.job_started(job, _profile_player_chunk)
		_mutex.unlock()
		if job.is_empty():
			continue
		var c: Vector2i = job.chunk
		_begin_worker_job(c, job)
		var result: Dictionary
		_begin_worker_phase(c, &"feature_context")
		var features := _features.context_for(c, Callable(self, "_worker_should_cancel"))
		if features == null or _worker_should_cancel():
			_publish_worker_result({}, job)
			continue
		_set_startup_worker_progress(c, 0.55)
		result = {
			"kind": &"chunk",
			"chunk": c,
			"build_terrain": bool(job.build_terrain),
			"terrain_generation": int(job.terrain_generation),
			"build_features": bool(job.build_features),
			"feature_generation": int(job.feature_generation),
		}
		if job.build_features:
			_begin_worker_phase(c, &"feature_placements")
			result["features"] = features.placements()
			_set_startup_worker_progress(c, 0.58)
		if job.build_terrain:
			_begin_worker_phase(c, &"heightfield_region")
			var region := features.graded_region(_fields.region(c))
			_set_startup_worker_progress(c, 0.62)
			_begin_worker_phase(c, &"water_context")
			var water_context := _fields.water(c)
			if _worker_should_cancel():
				_publish_worker_result({}, job)
				continue
			_set_startup_worker_progress(c, 0.67)
			var core := Rect2(Vector2(c) * CHUNK_WORLD, Vector2.ONE * CHUNK_WORLD)
			result["storeys"] = _storey_snapshot(c, region)
			result["points"] = _point_snapshot(c, region)
			_begin_worker_phase(c, &"terrain_mesh")
			result["terrain"] = _mesher.compute_chunk(c, region, water_context,
				features)
			if _worker_should_cancel():
				_publish_worker_result({}, job)
				continue
			if PROFILE_STREAMING:
				for phase: String in result.terrain.profile:
					_telemetry.timing(StringName("mesh/" + phase), result.terrain.profile[phase])
				for metric: String in result.terrain.profile_counts:
					_telemetry.count(StringName("mesh/" + metric), int(result.terrain.profile_counts[metric]))
			_set_startup_worker_progress(c, 0.82)
			_begin_worker_phase(c, &"water_mesh")
			result["water"] = _water_builder.compute_chunk(_water, c, region,
				water_context)
			if _worker_should_cancel():
				_publish_worker_result({}, job)
				continue
			_set_startup_worker_progress(c, 0.88)
			_begin_worker_phase(c, &"dressing")
			var structure_clearance: Array[FeatureGroundShape] = result.terrain.structure_clearance
			if not structure_clearance.is_empty():
				features = features.extended([],structure_clearance,
					EnvironmentInstancePayload.new(),Rect2())
			result["dressing"] = DressingField.compute(_dressing_program, world_seed,
				core, region, water_context, features,result.terrain.cliff_terraces.ground_reservations)
			if _grass_runtime_enabled:
				_begin_worker_phase(c, &"grass_sampling")
				# Embedded rocks' ground skirts carry their own grass support.
				var grass_supports: Array = result.terrain.cliff_terraces.grass_supports.duplicate()
				# (A neighbouring chunk's skirt reaching across the border is
				# not included: its blades there root in the terrain beneath.)
				for skirt: Dictionary in result.dressing.ground_skirts:
					grass_supports.append(skirt.grass_support)
				result["grass_sampling"] = GrassSamplingContext.detached(
					region, water_context, features, grass_supports)
			_set_startup_worker_progress(c, 0.97)
			# FX data stays worker-side; nodes are built during integration.
			_begin_worker_phase(c, &"biome_fx")
			result["fx"] = _biome_fx_data(c, region, water_context)
			_set_startup_worker_progress(c, 1.0)
		_publish_worker_result(result, job)


func _publish_worker_result(result: Dictionary, job: Dictionary) -> void:
	var c: Vector2i = job.chunk
	var kind: StringName = job.get("kind", &"chunk")
	if PROFILE_STREAMING:
		var field_counts := _fields.stats()
		field_counts.merge(WaterField.cache_counts())
		field_counts["height_samples"] = _plan._samples.size()
		field_counts["water_regions"] = _water._region_cache.size()
		field_counts["water_traces"] = _water._trace_cache.size()
		field_counts["features"] = _features.stats()
		_telemetry.cache_stats(field_counts)
	_finish_worker_job(c)
	_mutex.lock()
	if result.is_empty() and _active_job_yield_requested:
		# Complete field/route caches survive the interrupted context. Resume
		# its exact components later, merging any independently requested work.
		var resume := job.duplicate()
		resume["resume_count"] = int(job.get("resume_count", 0)) + 1
		if _followups.has(c):
			resume.build_terrain = bool(resume.build_terrain) or bool(_followups[c].build_terrain)
			resume.build_features = bool(resume.build_features) or bool(_followups[c].build_features)
		_followups[c] = resume
		_telemetry.count(&"priority_yields")
		_telemetry.job_event(&"yield", job, {"reason": "more_urgent_ground"})
	elif result.is_empty():
		_telemetry.count(&"obsolete_active_cancels")
		_telemetry.job_event(&"cancel", _active_job, {"reason": "obsolete_active"})
		_done.append({"kind": &"cancelled", "chunk": c})
	else:
		_done.append(result)
	_active_job = {}
	_active_job_yield_requested = false
	if kind == &"chunk" and _followups.has(c):
		var followup: Dictionary = _followups[c]
		_followups.erase(c)
		_queued[c] = followup
		_telemetry.job_queued(followup)
		_jobs.append(followup)
		# The completed feature may have inherited a nearby parent's urgency.
		# Its remaining terrain owns only its own position. Rebase before the
		# worker can take it again, including while the player is stationary.
		_refresh_job_priorities_locked(_profile_player_chunk, _queue_lod_origin)
		_sem.post()
	_mutex.unlock()

## Worker-thread phase markers. Startup jobs log their boundaries; later jobs
## stay quiet unless a completed phase exceeded the slow-phase threshold.
func _profile_field_operation(event: StringName, operation: StringName,
		field_chunk: Vector2i, elapsed_usec: int) -> void:
	_telemetry.job_event(&"field", _active_job, {"stage": event,
		"operation": operation, "field_chunk": field_chunk, "elapsed_usec": elapsed_usec})
	if event == &"end":
		_telemetry.timing(StringName("field/" + String(operation)), elapsed_usec)
		if elapsed_usec >= SLOW_WORKER_PHASE_MSEC * 1000:
			print("[terrain-streamer] slow_field operation=%s field_chunk=%s job_chunk=%s elapsed_ms=%.1f" % [
				operation, field_chunk, _active_job.chunk, elapsed_usec / 1000.0])


func _begin_worker_job(chunk: Vector2i, job: Dictionary) -> void:
	var now := Time.get_ticks_msec()
	_mutex.lock()
	_worker_phase_chunk = chunk
	_worker_phase = &"starting"
	_worker_phase_started_msec = now
	_worker_job_started_msec = now
	_worker_job_kind = job.get("kind", &"chunk")
	_mutex.unlock()
	if _worker_job_kind == &"chunk" and _is_startup_diagnostic_chunk(chunk):
		print("[terrain-streamer] worker_job_begin seed=%d chunk=%d,%d terrain=%s features=%s" % [
			world_seed, chunk.x, chunk.y, str(bool(job.get("build_terrain", false))),
			str(bool(job.get("build_features", false)))])


func _begin_worker_phase(chunk: Vector2i, phase: StringName) -> void:
	var now := Time.get_ticks_msec()
	var previous: StringName
	var previous_elapsed: int
	var job_elapsed: int
	var kind: StringName
	_mutex.lock()
	previous = _worker_phase
	_telemetry.job_event(&"phase", _active_job, {"phase": phase, "previous": previous,
		"previous_msec": now - _worker_phase_started_msec})
	previous_elapsed = now - _worker_phase_started_msec
	_telemetry.timing(StringName("worker/" + String(previous)), previous_elapsed * 1000)
	job_elapsed = now - _worker_job_started_msec
	kind = _worker_job_kind
	_worker_phase_chunk = chunk
	_worker_phase = phase
	_worker_phase_started_msec = now
	_mutex.unlock()
	if (kind == &"chunk" and _is_startup_diagnostic_chunk(chunk)) \
			or previous_elapsed >= SLOW_WORKER_PHASE_MSEC:
		print("[terrain-streamer] worker_phase seed=%d chunk=%d,%d phase=%s previous=%s previous_ms=%d job_ms=%d" % [
			world_seed, chunk.x, chunk.y, String(phase), String(previous),
			previous_elapsed, job_elapsed])


func _finish_worker_job(chunk: Vector2i) -> void:
	var now := Time.get_ticks_msec()
	var phase: StringName
	var phase_elapsed: int
	var job_elapsed: int
	var kind: StringName
	_mutex.lock()
	phase = _worker_phase
	_telemetry.job_event(&"complete", _active_job, {"job_msec": now - _worker_job_started_msec})
	phase_elapsed = now - _worker_phase_started_msec
	_telemetry.timing(StringName("worker/" + String(phase)), phase_elapsed * 1000)
	job_elapsed = now - _worker_job_started_msec
	_telemetry.timing(&"worker/job", job_elapsed * 1000)
	kind = _worker_job_kind
	_worker_phase = &"idle"
	_worker_phase_started_msec = now
	_worker_job_started_msec = 0
	_mutex.unlock()
	if (kind == &"chunk" and _is_startup_diagnostic_chunk(chunk)) \
			or phase_elapsed >= SLOW_WORKER_PHASE_MSEC:
		print("[terrain-streamer] worker_job_complete seed=%d chunk=%d,%d final_phase=%s phase_ms=%d job_ms=%d" % [
			world_seed, chunk.x, chunk.y, String(phase), phase_elapsed, job_elapsed])


## Main-thread verification harnesses use this immutable snapshot to
## distinguish a genuinely stalled teleport from a complex village whose
## relevant worker job is still active. Keeping the mutex here avoids making
## test code reach into live worker-owned diagnostics unsafely.
func worker_progress_snapshot() -> Dictionary:
	var now := Time.get_ticks_msec()
	var phase: StringName
	var chunk: Vector2i
	var phase_started: int
	var job_started: int
	var active: bool
	_mutex.lock()
	phase = _worker_phase
	chunk = _worker_phase_chunk
	phase_started = _worker_phase_started_msec
	job_started = _worker_job_started_msec
	active = not _active_job.is_empty()
	_mutex.unlock()
	return {
		"active": active,
		"phase": phase,
		"chunk": chunk,
		"phase_elapsed_msec": now - phase_started if phase_started > 0 else 0,
		"job_elapsed_msec": now - job_started if job_started > 0 else 0,
	}


func _is_startup_diagnostic_chunk(chunk: Vector2i) -> bool:
	return _startup_support_chunks.has(chunk) or _startup_feature_keys.has(chunk)

# Worker-side atmosphere sampling contains only CPU arrays and world coordinates.
func _biome_fx_data(c: Vector2i, region, water: WaterFieldContext = null) -> Dictionary:
	if _headless:
		return {}
	return BiomeAtmosphereField.compute(c, region, world_seed, water)

func _build_fx(node: Node3D, fx_data: Dictionary) -> void:
	if fx_data.is_empty():
		return
	var fx := BiomeChunkFx.build_field(fx_data)
	fx.position = fx_data.origin
	node.add_child(fx)


func _process(_delta: float) -> void:
	var profile_started := Time.get_ticks_usec() if PROFILE_STREAMING else 0
	if _plan == null or player == null:
		return
	var centre := chunk_of(player.global_position)
	_mutex.lock()
	_observe_stream_position(player.global_position)
	_profile_player_chunk = centre
	_queue_lod_origin = Vector2(player.global_position.x, player.global_position.z)
	_queue_travel_offset = Vector2.ZERO
	if player is CharacterBody3D:
		var travel:Vector3 = player.streaming_velocity() if player.has_method("streaming_velocity") else player.velocity
		_queue_travel_offset = (Vector2(travel.x, travel.z)
			* PREFETCH_SECONDS).limit_length(CHUNK_WORLD * mini(CHUNK_RADIUS,KEEP_RADIUS))
	var heading := Vector2i((_queue_travel_offset / PRIORITY_FOCUS_STEP).round())
	_mutex.unlock()
	var lod_origin := Vector2(player.global_position.x, player.global_position.z)
	if _grass_runtime_enabled:
		for node: Node3D in _grass_streamer.begin_frame(lod_origin):
			if node != null:
				node.queue_free()
		_grass_work.update_origin(lod_origin)
		for result: Dictionary in _grass_work.drain_results():
			_grass_streamer.accept_result(result.tile,int(result.generation),
				result.grass,int(result.compute_usec))
	var commit_started := Time.get_ticks_usec() if PROFILE_STREAMING else 0
	_dressing_queue.drain(MAX_DRESSING_BATCHES_PER_FRAME)
	for event: Dictionary in _feature_queue.drain(
			MAX_FEATURE_ASSET_LOADS_PER_FRAME,
			MAX_FEATURE_COLLISION_SHAPES_PER_FRAME,
			MAX_DRESSING_BATCHES_PER_FRAME, MAX_FEATURE_COMMIT_USEC):
		_accept_feature_ready(event)
	_drain_results(centre)
	_integrate_pending_terrain(centre)
	if _grass_runtime_enabled:
		for item: Dictionary in _grass_streamer.drain_commits():
			_grass_root.add_child(item.node)
	_telemetry.timing(&"main/commits", Time.get_ticks_usec() - commit_started)
	_emit_startup_loading_progress()
	_log_worker_diagnostics()
	var focus := Vector2i((lod_origin / PRIORITY_FOCUS_STEP).floor())
	if focus != _queue_focus or heading != _queue_heading:
		_queue_focus = focus
		_queue_heading = heading
		_mutex.lock()
		_refresh_job_priorities_locked(centre, lod_origin)
		_mutex.unlock()
	var current_chunk_ready := _built.has(centre) and _feature_square_ready(centre)
	var arrival_ready := _arrival_support_ready()
	_freeze_player(not current_chunk_ready or not startup_loading_complete() or not arrival_ready)
	var startup_pending := not startup_loading_complete()
	_request_neighborhood(centre, lod_origin, startup_pending)
	if _grass_runtime_enabled:
		_queue_grass_jobs(lod_origin)
	# Evict chunks beyond keep radius (Chebyshev).
	for c: Vector2i in _built.keys():
		if maxi(absi(c.x - centre.x), absi(c.y - centre.y)) > KEEP_RADIUS:
			_dressing_queue.invalidate_chunk(c)
			_telemetry.count(&"terrain_evictions")
			_built[c].queue_free()
			_built.erase(c)
			_storey_snapshots.erase(c)
			_point_snapshots.erase(c)
			if _dressing_trample_by_chunk.erase(c):
				_static_trample_dirty = true
			_terrain_generation[c] = int(_terrain_generation.get(c, 0)) + 1
	var feature_keep := KEEP_RADIUS + _feature_program.geometry_halo
	for c: Vector2i in _feature_ready.keys():
		if maxi(absi(c.x - centre.x), absi(c.y - centre.y)) > feature_keep:
			_feature_queue.invalidate_chunk(c)
			if _feature_nodes.has(c):
				_feature_nodes[c].queue_free()
				_feature_nodes.erase(c)
			_feature_ready.erase(c)
			_feature_generation[c] = int(_feature_generation.get(c, 0)) + 1
	for c: Vector2i in _feature_queue.pending_chunks():
		if maxi(absi(c.x - centre.x), absi(c.y - centre.y)) > feature_keep:
			_feature_queue.invalidate_chunk(c)
			_feature_generation[c] = int(_feature_generation.get(c, 0)) + 1
	if _grass_runtime_enabled and _static_trample_dirty:
		var static_started := Time.get_ticks_usec()
		_refresh_static_dressing()
		_telemetry.timing(&"main/static_dressing", Time.get_ticks_usec() - static_started)
	_telemetry.timing(&"main/streamer", Time.get_ticks_usec() - profile_started)


## Review harnesses only: discard these committed terrain chunks and their
## grass so the ordinary pipeline rebuilds them with the current scripts.
## Worker caches (regions, features, water) and feature blocks are kept.
func rebuild_terrain(chunks: Array) -> void:
	for c: Vector2i in chunks:
		if not _built.has(c):
			continue
		_dressing_queue.invalidate_chunk(c)
		_built[c].queue_free()
		_built.erase(c)
		_storey_snapshots.erase(c)
		_point_snapshots.erase(c)
		_dressing_trample_by_chunk.erase(c)
		_static_trample_dirty = true
		_terrain_generation[c] = int(_terrain_generation.get(c, 0)) + 1
		if _grass_runtime_enabled:
			for node: Node3D in _grass_streamer.discard_parent(c):
				node.queue_free()
	_requested_centre = Vector2i(1 << 30, 1 << 30)


func _request_neighborhood(centre: Vector2i, lod_origin: Vector2,
		startup_pending: bool) -> void:
	# Requests retain ownership through queued, active, handoff and pending
	# states. Only a new desired footprint needs new requests; position and
	# velocity changes within it already rebase the existing queue above.
	if centre == _requested_centre and startup_pending == _requested_startup:
		return
	_requested_centre = centre
	_requested_startup = startup_pending
	# Queue the spawn environment boundary ahead of the normal radius so the
	# loading screen cannot clear while the camera can still see missing ground.
	if startup_pending:
		var startup_wakes := 0
		_mutex.lock()
		for chunk: Vector2i in _startup_support_chunks:
			if _built.has(chunk) or _has_pending_terrain(chunk):
				continue
			var priority := maxi(absi(chunk.x - centre.x), absi(chunk.y - centre.y))
			if _request_job_locked(chunk, true, true, priority, 0):
				startup_wakes += 1
		_mutex.unlock()
		for _i in startup_wakes:
			_sem.post()
	else:
		# Do not let ordinary radius work merge terrain into feature-only startup
		# dependencies. Such merging used to make the overlay wait while unrelated
		# chunks were meshed. Once startup is complete, resume nearest-first
		# streaming normally.
		if not _built.has(centre) and not _has_pending_terrain(centre):
			_mutex.lock()
			var wake := _request_job_locked(centre, true, true, 0, 0)
			_mutex.unlock()
			if wake:
				_sem.post()
		var requested := 0
		for c: Vector2i in desired_chunks(centre, CHUNK_RADIUS):
			if _built.has(c) or _has_pending_terrain(c):
				continue
			_mutex.lock()
			requested += _request_terrain_dependencies_locked(c,
				maxi(absi(c.x - centre.x), absi(c.y - centre.y)),
				_terrain_priority_tier(c, centre, lod_origin))
			_mutex.unlock()
		for _i in requested:
			_sem.post()


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
	if not startup_pending and _pending_terrain.is_empty() and (active_job.is_empty() \
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
	var frontier := loading_boundary_snapshot()
	print("[terrain-streamer] ground_frontier ", JSON.stringify(frontier))

func loading_boundary_snapshot() -> Dictionary:
	var waiting: Array[Dictionary] = []
	for result: Dictionary in _pending_terrain:
		var missing: Array[Vector2i] = []
		for key: Vector2i in _feature_halo_keys(result.chunk):
			if int(_feature_ready.get(key,-1)) != int(_feature_generation.get(key,0)):
				missing.append(key)
		waiting.append({"chunk":result.chunk,"missing_features":missing})
	return {"loaded_ground":_built.keys(),"waiting_ground":waiting,
		"position":player.global_position if is_instance_valid(player) else Vector3.ZERO,
		"frozen":_player_frozen}

func _drain_results(centre: Vector2i) -> void:
	var results: Array[Dictionary] = []
	_mutex.lock()
	results.assign(_done)
	_done.clear()
	_mutex.unlock()
	for result: Dictionary in results:
		if StringName(result.get("kind", &"chunk")) == &"cancelled":
			# A second teleport can return while an obsolete worker unwinds.
			# Recheck request ownership once on the main thread, even if this
			# frame's desired footprint was already announced to that owner.
			_requested_centre = Vector2i(2147483647, 2147483647)
	# Features first: a result may make several completed terrain payloads ready.
	for result: Dictionary in results:
		if StringName(result.get("kind", &"chunk")) == &"chunk" \
				and bool(result.get("build_features", false)):
			_commit_feature_result(result, centre)
	for result: Dictionary in results:
		if StringName(result.get("kind", &"chunk")) != &"chunk" \
				or not bool(result.get("build_terrain", false)):
			continue
		var c: Vector2i = result.chunk
		if int(_terrain_generation.get(c, 0)) != int(result.terrain_generation) \
			or _built.has(c) \
			or maxi(absi(c.x - centre.x), absi(c.y - centre.y)) > KEEP_RADIUS:
			continue
		_telemetry.count(&"terrain_results")
		_pending_terrain.append(result)
		var requested := 0
		_mutex.lock()
		for key: Vector2i in _feature_halo_keys(c):
			if not _feature_ready.has(key) \
				and _request_job_locked(key, false, true,
					maxi(absi(c.x - centre.x), absi(c.y - centre.y)),
					_terrain_priority_tier(c, centre,
						Vector2(player.global_position.x, player.global_position.z))):
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
	var payload: EnvironmentInstancePayload = result.features
	# Empty blocks have no resource or collision stage. Publish their explicit
	# readiness directly, which also keeps this pure fast path unit-testable
	# without constructing main-thread render services.
	if payload.instance_count == 0 and payload.collision_boxes.is_empty() \
			and payload.surface_meshes.is_empty():
		if int(_feature_generation.get(c, 0)) == generation \
				and not _feature_ready.has(c) \
				and maxi(absi(c.x - centre.x), absi(c.y - centre.y)) \
				<= KEEP_RADIUS + _feature_program.geometry_halo:
			_feature_ready[c] = generation
		return
	if int(_feature_generation.get(c, 0)) != generation \
		or _feature_ready.has(c) \
		or _feature_queue.has_chunk(c) \
		or maxi(absi(c.x - centre.x), absi(c.y - centre.y)) \
		> KEEP_RADIUS + _feature_program.geometry_halo:
		return
	_feature_queue.enqueue(c, generation, _features_root, payload)

func _accept_feature_ready(event: Dictionary) -> void:
	var c: Vector2i = event.chunk
	var generation := int(event.generation)
	if int(_feature_generation.get(c, 0)) != generation:
		var stale := event.node as Node3D
		if stale != null and is_instance_valid(stale):
			stale.queue_free()
		return
	var block := event.node as Node3D
	if block != null:
		_feature_nodes[c] = block
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
		var integrate_started := Time.get_ticks_usec()
		var node: Node3D = _mesher.commit_chunk(result.terrain)
		var terrain_finished := Time.get_ticks_usec()
		var water_node: Node3D = _water_builder.commit_chunk(result.water)
		if water_node != null:
			node.add_child(water_node)
		var water_finished := Time.get_ticks_usec()
		EnvironmentCollisionBuilder.commit(node, result.dressing, _environment_cache,
			&"DressingCollision")
		# Embedded rocks' ground skirts are ground: they commit with it.
		RockSkirt.commit(node, result.dressing.ground_skirts)
		var collision_finished := Time.get_ticks_usec()
		terrain_parent.add_child(node)
		_build_fx(node, result.fx)
		var publish_finished := Time.get_ticks_usec()
		if publish_finished-integrate_started>=50000:
			print("[terrain-streamer] slow_commit seed=%d chunk=%s terrain_ms=%.2f water_ms=%.2f dressing_collision_ms=%.2f publish_fx_ms=%.2f" % [
				world_seed,c,(terrain_finished-integrate_started)/1000.0,
				(water_finished-terrain_finished)/1000.0,
				(collision_finished-water_finished)/1000.0,
				(publish_finished-collision_finished)/1000.0])
		if _grass_runtime_enabled:
			node.set_meta(&"grass_sampling", result.grass_sampling)
		_built[c] = node
		_storey_snapshots[c] = result.storeys
		_point_snapshots[c] = result.get("points", PackedFloat32Array())
		_dressing_trample_by_chunk[c] = _dressing_trample_stamps(result.dressing)
		_static_trample_dirty = true
		var generation: int = result.terrain_generation
		_dressing_queue.register_chunk(c, generation)
		_dressing_queue.enqueue(c, generation, node, result.dressing)
		_telemetry.count(&"terrain_commits")
		_telemetry.timing(&"main/terrain_commit", Time.get_ticks_usec() - integrate_started)
		integrated += 1
	_pending_terrain = remaining

## Publish loaded structural dressing as a persistent layer, separate from the
## recovering player trail. Rebuilding only when chunks change avoids the old
## two-second overwrite that snapped walked grass back to a fixed direction.
func _refresh_static_dressing() -> void:
	if _trample_field == null:
		return
	var chunk_keys: Array[Vector2i] = []
	chunk_keys.assign(_dressing_trample_by_chunk.keys())
	chunk_keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.x < b.x or (a.x == b.x and a.y < b.y))
	var all_stamps: Array[Dictionary] = []
	for chunk: Vector2i in chunk_keys:
		for stamp: Dictionary in _dressing_trample_by_chunk[chunk]:
			all_stamps.append(stamp)
	_trample_field.set_static_stamps(all_stamps)
	_static_trample_dirty = false

func _dressing_trample_stamps(payload: EnvironmentInstancePayload) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if payload == null or _dressing_program == null:
		return out
	for asset_id: StringName in payload.asset_ids():
		var local_points: PackedVector2Array = \
			_dressing_program.ground_stencil_by_asset.get(asset_id, PackedVector2Array())
		if local_points.size() < 3:
			continue
		for placement: Transform3D in payload.batches[asset_id].transforms:
			var world_points := PackedVector2Array()
			var centre := Vector2(placement.origin.x, placement.origin.z)
			var radius := 0.0
			for local_point: Vector2 in local_points:
				var world_point := placement * Vector3(local_point.x, 0.0, local_point.y)
				var world_xz := Vector2(world_point.x, world_point.z)
				world_points.append(world_xz)
				radius = maxf(radius, world_xz.distance_to(centre))
			out.append({
				"position": placement.origin,
				"points": world_points,
				"radius": radius,
			})
	return out

## Main-thread debug queries over immutable data delivered with each committed
## chunk, keyed by 12 m lattice point (chunk k owns points 16 k .. 16 k + 15).
## They deliberately never reach into the worker-owned plan or its mutable
## terrain/water caches.
func loaded_storey_at(point: Vector2i) -> Variant:
	var side := TerrainChunkMesher.POINTS_PER_CHUNK
	var chunk := Vector2i(floori(float(point.x) / side), floori(float(point.y) / side))
	var values: PackedInt32Array = _storey_snapshots.get(chunk, PackedInt32Array())
	if values.size() != side * side:
		return null
	var local := point - chunk * side
	return values[local.y * side + local.x]

## Surface height and graded flag of a loaded lattice point (the terrain
## category overlay's input), or null. Same immutable-snapshot contract.
func loaded_point_at(point: Vector2i) -> Variant:
	var side := TerrainChunkMesher.POINTS_PER_CHUNK
	var chunk := Vector2i(floori(float(point.x) / side), floori(float(point.y) / side))
	var values: PackedFloat32Array = _point_snapshots.get(chunk, PackedFloat32Array())
	if values.size() != side * side * 2:
		return null
	var local := point - chunk * side
	var i := (local.y * side + local.x) * 2
	return Vector2(values[i], values[i + 1])

static func _point_snapshot(chunk: Vector2i, region: HeightfieldRegion) -> PackedFloat32Array:
	var side := TerrainChunkMesher.POINTS_PER_CHUNK
	var values := PackedFloat32Array()
	values.resize(side * side * 2)
	var first := chunk * side
	for z in side:
		for x in side:
			var point := first + Vector2i(x, z)
			values[(z * side + x) * 2] = region.surface_height(point.x, point.y)
			# A town grade reaches the terrain only as per-point native controls.
			values[(z * side + x) * 2 + 1] = 1.0 if region.native_control_heights.has(point) else 0.0
	return values

static func _storey_snapshot(chunk: Vector2i, region: HeightfieldRegion) -> PackedInt32Array:
	var side := TerrainChunkMesher.POINTS_PER_CHUNK
	var values := PackedInt32Array()
	values.resize(side * side)
	var first := chunk * side
	for z in side:
		for x in side:
			values[z * side + x] = region.storey_at(first.x + x, first.y + z)
	return values

func _feature_halo_keys(chunk: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dz in range(-_feature_program.geometry_halo,
			_feature_program.geometry_halo + 1):
		for dx in range(-_feature_program.geometry_halo,
				_feature_program.geometry_halo + 1):
			out.append(chunk + Vector2i(dx, dz))
	out.sort_custom(_key_less)
	return out

func _feature_square_ready(chunk: Vector2i) -> bool:
	if _feature_program == null:
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

static func distance_to_chunk(origin: Vector2, chunk: Vector2i) -> float:
	var rect := Rect2(Vector2(chunk) * CHUNK_WORLD, Vector2.ONE * CHUNK_WORLD)
	var dx := maxf(maxf(rect.position.x - origin.x, 0.0), origin.x - rect.end.x)
	var dz := maxf(maxf(rect.position.y - origin.y, 0.0), origin.y - rect.end.y)
	return Vector2(dx, dz).length()

func _terrain_priority_tier(chunk: Vector2i, centre: Vector2i,
		lod_origin: Vector2) -> int:
	if chunk == centre or chunk in _arrival_support_chunks:
		return 0
	if is_finite(_travel_entry_distance(chunk,lod_origin)):
		return 1
	if distance_to_chunk(lod_origin, chunk) < TERRAIN_PREFETCH_RADIUS:
		# Upcoming crossings precede lateral scenery while moving. Giving both
		# the same tier lets a cold lateral dependency monopolize the worker
		# until the crossing has already become missing current ground.
		return 2 if _queue_travel_offset.length_squared() > 0.000001 else 1
	return 3


## First entry into a chunk along the bounded travel segment.
## Testing the entire segment preserves intervening ground when preparation
## takes longer than one chunk crossing; an endpoint-only probe skips it.
func _travel_entry_distance(chunk:Vector2i,origin:Vector2)->float:
	var length := _queue_travel_offset.length()
	if length<0.001: return INF
	var low := Vector2(chunk)*CHUNK_WORLD
	var high := low+Vector2.ONE*CHUNK_WORLD
	var enter := 0.0
	var leave := 1.0
	for axis in 2:
		var motion := _queue_travel_offset[axis]
		if absf(motion)<0.000001:
			if origin[axis]<low[axis] or origin[axis]>high[axis]: return INF
			continue
		var first := (low[axis]-origin[axis])/motion
		var last := (high[axis]-origin[axis])/motion
		enter=maxf(enter,minf(first,last))
		leave=minf(leave,maxf(first,last))
		if enter>leave: return INF
	return enter*length

## Only committed ground supplies grass sampling data. The visual worker
## consumes private copies while terrain continues planning independently.
func _queue_grass_jobs(lod_origin: Vector2) -> void:
	for tile: Vector2i in GrassStreamer.desired_tiles(lod_origin):
		if not _grass_streamer.needs_request(tile):
			continue
		var parent := GrassField.parent_chunk(tile)
		if not _built.has(parent):
			continue
		var sampling: GrassSamplingContext = (_built[parent] as Node3D).get_meta(&"grass_sampling", null)
		if sampling == null:
			continue
		if _grass_work.request(tile,_grass_streamer.generation(tile),sampling):
			_grass_streamer.mark_requested(tile)

## Schedule the complete activation dependency set before waking the worker.
## Collision readiness still gates terrain integration; it no longer discovers
## its neighbour work only after the terrain mesh has already completed.
func _request_terrain_dependencies_locked(chunk: Vector2i, distance: int, tier: int) -> int:
	var wakes := 1 if _request_job_locked(chunk,true,true,distance,tier) else 0
	for key: Vector2i in _feature_halo_keys(chunk):
		if _request_job_locked(key,false,true,distance,tier): wakes += 1
	return wakes

## Caller holds _mutex. Returns true only when a new semaphore wake is needed.
func _request_job_locked(chunk: Vector2i, build_terrain: bool,
		build_features: bool, priority_distance: int,
		priority_tier: int = 3) -> bool:
	_telemetry.count(&"chunk_requests")
	if build_terrain and (_built.has(chunk) or _has_pending_terrain(chunk)):
		build_terrain = false
	if build_features and (_feature_ready.has(chunk) or (_feature_queue != null and _feature_queue.has_chunk(chunk))):
		build_features = false
	# Completion can land after this frame drained results but before requests.
	# The hand-off still owns its components until the main thread accepts it.
	for result: Dictionary in _done:
		if StringName(result.get("kind", &"chunk")) == &"chunk" and result.chunk == chunk:
			if int(result.terrain_generation) == int(_terrain_generation.get(chunk, 1)):
				build_terrain = build_terrain and not bool(result.build_terrain)
			if int(result.feature_generation) == int(_feature_generation.get(chunk, 1)):
				build_features = build_features and not bool(result.build_features)
	if not build_terrain and not build_features:
		return false
	if build_terrain: _terrain_feature_parents[chunk] = true
	if not _terrain_generation.has(chunk):
		_terrain_generation[chunk] = 1
	if not _feature_generation.has(chunk):
		_feature_generation[chunk] = 1
	if _queued.has(chunk):
		var queued: Dictionary = _queued[chunk]
		var terrain := bool(queued.build_terrain) or build_terrain
		var features := bool(queued.build_features) or build_features
		var distance := mini(int(queued.priority_distance), priority_distance)
		var tier := mini(int(queued.priority_tier), priority_tier)
		if terrain == bool(queued.build_terrain) and features == bool(queued.build_features) \
				and distance == int(queued.priority_distance) and tier == int(queued.priority_tier):
			_telemetry.count(&"queued_chunk_noops")
			return false
		_telemetry.count(&"queued_chunk_updates")
		# Dictionaries are shared with the queue; no linear replacement search.
		queued.build_terrain = terrain
		queued.build_features = features
		queued.priority_distance = distance
		queued.priority_tier = tier
		_sort_jobs_locked()
		return false
	if not _active_job.is_empty() \
			and StringName(_active_job.get("kind", &"chunk")) == &"chunk" \
			and _active_job.chunk == chunk:
		_telemetry.count(&"active_chunk_requests")
		var followup: Dictionary = _followups.get(chunk, _new_job(chunk, false, false,
			priority_distance, priority_tier))
		followup.build_terrain = bool(followup.build_terrain) \
			or (build_terrain and not bool(_active_job.build_terrain))
		followup.build_features = bool(followup.build_features) \
			or (build_features and not bool(_active_job.build_features))
		followup.priority_distance = mini(int(followup.priority_distance), priority_distance)
		followup.priority_tier = mini(int(followup.priority_tier), priority_tier)
		if followup.build_terrain or followup.build_features:
			_followups[chunk] = followup
		return false
	_telemetry.count(&"chunk_enqueues")
	var job := _new_job(chunk, build_terrain, build_features, priority_distance,
		priority_tier)
	_queued[chunk] = job
	_telemetry.job_queued(job)
	_jobs.append(job)
	_sort_jobs_locked()
	return true

func _new_job(chunk: Vector2i, build_terrain: bool,
		build_features: bool, priority_distance: int,
		priority_tier: int = 3) -> Dictionary:
	return {"kind": &"chunk", "chunk": chunk, "build_terrain": build_terrain,
		"terrain_generation": int(_terrain_generation.get(chunk, 1)),
		"build_features": build_features,
		"feature_generation": int(_feature_generation.get(chunk, 1)),
		"priority_tier": priority_tier,
		"priority_distance": priority_distance}

## Rebase queued work on the current location, including the dependencies of
## completed terrain. Old near priorities must become far priorities after travel.
## Re-evaluate on 8m scheduling cells and changes in travel direction or speed.
func _refresh_job_priorities_locked(centre: Vector2i, lod_origin: Vector2) -> void:
	_queue_lod_origin = lod_origin
	var halo := _feature_program.geometry_halo if _feature_program != null else 0
	for parent: Vector2i in _terrain_feature_parents.keys():
		if _built.has(parent) or maxi(absi(parent.x-centre.x),absi(parent.y-centre.y)) > KEEP_RADIUS:
			_terrain_feature_parents.erase(parent)
	# A component waiting behind an active job is queued work too. Rebase it
	# now so worker completion cannot restore an abandoned near priority.
	for chunk: Vector2i in _followups.keys():
		var followup: Dictionary = _followups[chunk]
		var distance := maxi(absi(chunk.x - centre.x), absi(chunk.y - centre.y))
		if distance > KEEP_RADIUS: followup.build_terrain = false
		if distance > KEEP_RADIUS + halo or (not bool(followup.build_terrain) and not bool(followup.build_features)):
			_followups.erase(chunk)
			_telemetry.count(&"followup_cancels")
			continue
		followup.priority_distance = distance
		followup.priority_tier = _terrain_priority_tier(chunk, centre, lod_origin)
	for index in range(_jobs.size() - 1, -1, -1):
		var job: Dictionary = _jobs[index]
		var distance := maxi(absi(job.chunk.x - centre.x), absi(job.chunk.y - centre.y))
		if distance > KEEP_RADIUS:
			job.build_terrain = false
		if distance > KEEP_RADIUS + halo or (not bool(job.build_terrain) and not bool(job.build_features)):
			_telemetry.job_event(&"cancel", job, {"reason": "outside_terrain_keep"})
			_queued.erase(job.chunk)
			_jobs.remove_at(index)
			_telemetry.count(&"terrain_queue_cancels")
			continue
		job.priority_distance = distance
		job.priority_tier = _terrain_priority_tier(job.chunk, centre, lod_origin)
		if not startup_loading_complete() and job.chunk in _startup_feature_keys:
			job.priority_tier = 0
		for parent: Vector2i in _terrain_feature_parents:
			if not bool(job.build_features): break
			var parent_distance := maxi(absi(parent.x - centre.x), absi(parent.y - centre.y))
			if parent_distance <= KEEP_RADIUS and maxi(absi(job.chunk.x-parent.x),absi(job.chunk.y-parent.y)) <= halo:
				job.priority_tier = mini(int(job.priority_tier), _terrain_priority_tier(parent, centre, lod_origin))
				job.priority_distance = mini(int(job.priority_distance), parent_distance)
	_sort_jobs_locked()


func _ground_distance(chunk: Vector2i) -> float:
	return minf(distance_to_chunk(_queue_lod_origin,chunk),
		distance_to_chunk(_queue_lod_origin+_queue_travel_offset,chunk))

func _job_ground_distance(job: Dictionary) -> float:
	var distance := _ground_distance(job.chunk)
	if not bool(job.get("build_features",false)): return distance
	var halo := _feature_program.geometry_halo if _feature_program != null else 0
	for z in range(-halo,halo+1):
		for x in range(-halo,halo+1):
			var parent: Vector2i = job.chunk+Vector2i(x,z)
			if _terrain_feature_parents.has(parent):
				distance = minf(distance,_ground_distance(parent))
	return distance

func _job_travel_distance(job:Dictionary)->float:
	var distance := _travel_entry_distance(job.chunk,_queue_lod_origin)
	if not bool(job.get("build_features",false)): return distance
	var halo := _feature_program.geometry_halo if _feature_program != null else 0
	for z in range(-halo,halo+1):
		for x in range(-halo,halo+1):
			var parent:Vector2i=job.chunk+Vector2i(x,z)
			if _terrain_feature_parents.has(parent):
				distance=minf(distance,_travel_entry_distance(parent,_queue_lod_origin))
	return distance

func _sort_jobs_locked() -> void:
	var started := Time.get_ticks_usec() if PROFILE_STREAMING else 0
	# Queue geometry is unchanged throughout a sort. Compute its two metrics
	# once per job instead of rescanning feature parents in every comparison.
	for job:Dictionary in _jobs:
		if job.get("kind",&"chunk")==&"chunk":
			job._sort_ground=_job_ground_distance(job)
			job._sort_travel=_job_travel_distance(job)
	_jobs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.priority_tier) != int(b.priority_tier):
			return int(a.priority_tier) < int(b.priority_tier)
		if a.get("kind",&"chunk")==&"chunk" and b.get("kind",&"chunk")==&"chunk":
			# While moving, prepare upcoming crossings before surrounding
			# background terrain. Feature owners inherit the same deadline.
			if a._sort_travel!=b._sort_travel: return a._sort_travel<b._sort_travel
		if int(a.priority_distance) != int(b.priority_distance):
			return int(a.priority_distance) < int(b.priority_distance)
		# Equal Chebyshev rings may be a few metres ahead or almost a full
		# chunk behind. Resolve their tie using the distance to actual ground.
		if a.get("kind", &"chunk") == &"chunk" and b.get("kind", &"chunk") == &"chunk":
			var ad:float = a._sort_ground
			var bd:float = b._sort_ground
			if ad != bd: return ad < bd
		if bool(a.get("build_features", false)) \
				!= bool(b.get("build_features", false)):
			return bool(a.get("build_features", false))
		return _key_less(_job_key(a), _job_key(b)))
	# Jobs and queue snapshots contain persistent facts only. In particular,
	# an absent travel intersection is INF, which is not a JSON number.
	for job:Dictionary in _jobs:
		job.erase("_sort_ground")
		job.erase("_sort_travel")
	_telemetry.timing(&"queue/sort", Time.get_ticks_usec() - started)

static func _job_key(job: Dictionary) -> Vector2i:
	return job.chunk

static func _key_less(a: Vector2i, b: Vector2i) -> bool:
	return a.x < b.x or (a.x == b.x and a.y < b.y)

func _exit_tree() -> void:
	_restore_startup_render_limit()
	# The cliff style is process-wide: leave the default (`chosen`) behind.
	if not CLIFF_STYLE.is_empty():
		var style := preload("res://scripts/terrain/field/CliffRockStyle.gd")
		style.apply(style.PRODUCTION)
	if _grass_work != null: _grass_work.stop()
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


## Immutable, bounded observation for integration harnesses. No live worker
## caches or server objects cross this API.
func streaming_profile_snapshot() -> Dictionary:
	var result := _telemetry.snapshot()
	_mutex.lock()
	result["queued"] = _jobs.size()
	result["done"] = _done.size()
	result["active_job"] = _active_job.duplicate(true)
	result["arrival_support"] = _arrival_support_chunks.duplicate()
	result["queue_head"] = _jobs.slice(0, mini(8, _jobs.size())).duplicate(true)
	result["followups"] = _followups.size()
	_mutex.unlock()
	result["pending_terrain"] = _pending_terrain.size()
	result["built"] = _built.size()
	result["player_frozen"] = _player_frozen
	result["feature_pending"] = _feature_queue.pending_chunks().size() if _feature_queue != null else 0
	result["ground_frontier"] = loading_boundary_snapshot()
	return result


## Called only between complete, cached planning operations. A teleport may
## abandon an active road context, but never publishes a partial feature plan.
func _worker_should_cancel() -> bool:
	_mutex.lock()
	var cancelled := _exit
	if not cancelled and not _active_job.is_empty():
		var chunk: Vector2i = _active_job.chunk
		var distance := maxi(absi(chunk.x - _profile_player_chunk.x),
			absi(chunk.y - _profile_player_chunk.y))
		var halo := _feature_program.geometry_halo if _feature_program != null else 0
		cancelled = distance > KEEP_RADIUS + halo
	if cancelled:
		_active_job_yield_requested = false
	elif not _active_job.is_empty() and startup_loading_complete() and not _jobs.is_empty():
		# Only a strictly more urgent tier can interrupt work. Equal-priority
		# neighbors run to completion rather than repeatedly yielding to one
		# another. Feature dependencies inherit their terrain parent's urgency.
		var tier := _terrain_priority_tier(_active_job.chunk, _profile_player_chunk, _queue_lod_origin)
		if bool(_active_job.build_features):
			var halo := _feature_program.geometry_halo if _feature_program != null else 0
			for parent: Vector2i in _terrain_feature_parents:
				if maxi(absi(parent.x-_profile_player_chunk.x),absi(parent.y-_profile_player_chunk.y)) <= KEEP_RADIUS \
						and maxi(absi(parent.x-_active_job.chunk.x),absi(parent.y-_active_job.chunk.y)) <= halo:
					tier = mini(tier,_terrain_priority_tier(parent,_profile_player_chunk,_queue_lod_origin))
		if int(_jobs[0].priority_tier) < tier:
			_active_job_yield_requested = true
	cancelled = cancelled or _active_job_yield_requested
	_mutex.unlock()
	return cancelled


## Caller holds _mutex. Ordinary motion never restarts this gate. A
## discontinuous relocation needs the same existing travel buffer as spawn;
## otherwise a position 5 m from a seam is released straight into unloaded air.
func _observe_stream_position(position: Vector3) -> void:
	if _last_stream_position.is_finite() and Vector2(position.x, position.z).distance_to(
			Vector2(_last_stream_position.x, _last_stream_position.z)) > CHUNK_WORLD * 0.5:
		_arrival_support_chunks = support_chunks_at(position)
		_telemetry.count(&"arrival_gates")
	_last_stream_position = position

## Main-thread status for review UI: whether the player is held, and how many
## of the chunks a teleport (or spawn) waits for are ready.
func arrival_status() -> Dictionary:
	var ready := 0
	for chunk: Vector2i in _arrival_support_chunks:
		if _built.has(chunk) and _feature_square_ready(chunk): ready += 1
	return {"frozen": _player_frozen, "ready": ready, "total": _arrival_support_chunks.size()}

func _arrival_support_ready() -> bool:
	if _arrival_support_chunks.is_empty(): return true
	for chunk: Vector2i in _arrival_support_chunks:
		if not _built.has(chunk) or not _feature_square_ready(chunk): return false
	_mutex.lock()
	_arrival_support_chunks.clear()
	_refresh_job_priorities_locked(_profile_player_chunk, _queue_lod_origin)
	_mutex.unlock()
	_telemetry.count(&"arrival_ready")
	return true
