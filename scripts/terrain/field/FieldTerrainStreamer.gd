# scripts/terrain/field/FieldTerrainStreamer.gd
# Slim per-chunk streaming driver: builds field chunks within a radius of the
# player on ONE background thread (the whole pipeline is scene-free RefCounted,
# so build_chunk runs off-thread as-is and returns a detached Node3D), then
# integrates finished chunks on the main thread, budgeted per frame. Evicts
# beyond a keep radius. The player's own chunk is still built synchronously
# when missing, so the player can never fall through unbuilt space.
class_name FieldTerrainStreamer
extends Node3D

const CHUNK_WORLD := 192.0   # TerrainChunkMesher.CHUNK_WORLD

@export var player: Node3D
@export var terrain_parent: Node
@export var CHUNK_RADIUS: int = 3
@export var KEEP_RADIUS: int = 4
## Finished background chunks INTEGRATED (added to the tree) per frame.
@export var MAX_BUILD_PER_FRAME: int = 1
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
# Main-thread pipeline instances for the synchronous player-chunk guarantee.
# Separate objects with separate caches; same seed => identical output (the
# pipeline is a pure function of (seed, cell)).
var _plan_sync: HeightfieldPlan
var _water_sync: WaterPlan
var _mesher_sync: TerrainChunkMesher
var _water_builder_sync := WaterSurfaceBuilder.new()

var _built: Dictionary = {}        # Vector2i -> Node3D          (main thread only)
var _queued: Dictionary = {}       # Vector2i -> true, in-flight  (main thread only)
var world_seed: int = 0

var _thread := Thread.new()
var _sem := Semaphore.new()
var _mutex := Mutex.new()          # guards _jobs, _done, _exit
var _jobs: Array = []              # Vector2i, nearest-first at enqueue time
var _done: Array = []              # [Vector2i, Node3D] finished builds
var _exit := false

static func chunk_of(pos: Vector3) -> Vector2i:
	return Vector2i(int(floor(pos.x / CHUNK_WORLD)), int(floor(pos.z / CHUNK_WORLD)))

func desired_chunks(centre: Vector2i, radius: int) -> Array:
	var out: Array = []
	for dz in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			out.append(centre + Vector2i(dx, dz))
	return out

func _ready() -> void:
	if terrain_parent == null:
		return   # bare instance (unit test)
	world_seed = SEED_OVERRIDE if SEED_OVERRIDE != 0 else randi()
	_plan = HeightfieldPlan.new(world_seed, HEIGHTFIELD_AMPLITUDE, HEIGHTFIELD_MAX_STOREYS, "mean", MAX_CLIFF_STEP)
	_water = WaterPlan.new(world_seed, HEIGHTFIELD_AMPLITUDE, HEIGHTFIELD_MAX_STOREYS)
	_plan.set_water_plan(_water)
	_mesher = TerrainChunkMesher.new()
	_mesher.set_seed(world_seed)
	_plan_sync = HeightfieldPlan.new(world_seed, HEIGHTFIELD_AMPLITUDE, HEIGHTFIELD_MAX_STOREYS, "mean", MAX_CLIFF_STEP)
	_water_sync = WaterPlan.new(world_seed, HEIGHTFIELD_AMPLITUDE, HEIGHTFIELD_MAX_STOREYS)
	_plan_sync.set_water_plan(_water_sync)
	_mesher_sync = TerrainChunkMesher.new()
	_mesher_sync.set_seed(world_seed)
	# Warm every shared static resource on the main thread before the worker
	# starts (loading is thread-safe; warming here just keeps the first
	# background build fast and shader compiles on the main thread).
	CliffDressing._ensure_loaded()
	CliffDressing.shared_material()
	WaterSurfaceBuilder.sheet_material()
	_mesher._ensure_skirt_style()
	_mesher_sync._ensure_skirt_style()
	for tag in TerrainChunkMesher.FOLIAGE_SCENES:
		for path: String in TerrainChunkMesher.FOLIAGE_SCENES[tag]:
			load(path)
	# Build the chunk under the spawn point before the first physics frame, so
	# the player lands on real collision instead of falling through.
	if player != null:
		_build_now(chunk_of(player.global_position))
	_thread.start(_worker)

# Synchronous build on the MAIN thread (spawn + the rare case of the player
# outrunning the streamer). Uses the _sync pipeline instances exclusively.
func _build_now(c: Vector2i) -> void:
	if _built.has(c):
		return
	var node := _mesher_sync.build_chunk(_plan_sync, c)
	var wnode := _water_builder_sync.build_chunk(_water_sync, c)
	if wnode != null:
		node.add_child(wnode)
	terrain_parent.add_child(node)
	_built[c] = node

func _worker() -> void:
	while true:
		_sem.wait()
		_mutex.lock()
		if _exit:
			_mutex.unlock()
			return
		var c: Vector2i = _jobs.pop_front() if not _jobs.is_empty() else Vector2i.MAX
		_mutex.unlock()
		if c == Vector2i.MAX:
			continue
		var node := _mesher.build_chunk(_plan, c)
		var wnode := _water_builder.build_chunk(_water, c)
		if wnode != null:
			node.add_child(wnode)
		_mutex.lock()
		_done.append([c, node])
		_mutex.unlock()

func _process(_delta: float) -> void:
	if _plan == null or player == null:
		return
	var centre := chunk_of(player.global_position)
	# The player's own chunk never waits on the worker.
	_build_now(centre)
	# Integrate finished background builds (budgeted).
	var integrated := 0
	while integrated < MAX_BUILD_PER_FRAME:
		_mutex.lock()
		var pair: Array = _done.pop_front() if not _done.is_empty() else []
		_mutex.unlock()
		if pair.is_empty():
			break
		var c: Vector2i = pair[0]
		_queued.erase(c)
		if _built.has(c) or maxi(absi(c.x - centre.x), absi(c.y - centre.y)) > KEEP_RADIUS:
			pair[1].free()   # lost the race to _build_now, or stale — discard
			continue
		terrain_parent.add_child(pair[1])
		_built[c] = pair[1]
		integrated += 1
	# Queue missing chunks nearest-first, so terrain grows outward from the player.
	var want: Array = []
	for c: Vector2i in desired_chunks(centre, CHUNK_RADIUS):
		if not _built.has(c) and not _queued.has(c):
			want.append(c)
	if not want.is_empty():
		want.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return maxi(absi(a.x - centre.x), absi(a.y - centre.y)) \
				< maxi(absi(b.x - centre.x), absi(b.y - centre.y)))
		_mutex.lock()
		for c: Vector2i in want:
			_queued[c] = true
			_jobs.append(c)
		_mutex.unlock()
		for i in want.size():
			_sem.post()
	# Evict chunks beyond keep radius (Chebyshev).
	for c: Vector2i in _built.keys():
		if maxi(absi(c.x - centre.x), absi(c.y - centre.y)) > KEEP_RADIUS:
			_built[c].queue_free()
			_built.erase(c)

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
	for pair in _done:
		# is_instance_valid guards the "freed exactly once" invariant: these nodes
		# never entered the tree, so freeing them here is correct — the guard just
		# keeps it robust if a future edit ever lets one also reach _built.
		if is_instance_valid(pair[1]):
			pair[1].free()
	_done.clear()
