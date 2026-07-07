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
var _built: Dictionary = {}        # Vector2i -> Node3D          (main thread only)
var _queued: Dictionary = {}       # Vector2i -> true, in-flight  (main thread only)
var world_seed: int = 0
var _headless: bool = Helper.is_headless()

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
	# Warm every shared STATIC on the main thread before the worker starts —
	# after this point the statics are read-only, which is what makes the
	# no-locks pipeline safe. `load(path)` alone did NOT fill the mesher's
	# static _foliage_piece_cache: the worker and the main thread then raced
	# their first `_foliage_piece_cache[path] = ...` insert — a String-keyed
	# Dictionary corrupted across threads (SIGSEGV in
	# StringLikeVariantComparator).
	CliffDressing._ensure_loaded()
	CliffDressing.shared_material()
	WaterSurfaceBuilder.sheet_material()
	WaterSurfaceBuilder.waterfall_material()
	WaterSurfaceBuilder.mist_resources()
	_mesher._ensure_skirt_style()
	for tag in TerrainChunkMesher.FOLIAGE_SCENES:
		for path: String in TerrainChunkMesher.FOLIAGE_SCENES[tag]:
			TerrainChunkMesher._foliage_pieces(path)
	# Warm the biome tint materials + profiles on the main thread too, so the
	# worker only ever READS them (same no-locks confinement as above).
	_mesher._ground_tinted_mat()
	_mesher._foliage_material()
	BiomeRegistry.profile(&"meadow")
	# The spawn chunk is NOT built synchronously: the first build pays the
	# whole cold water-trace cache (~10s) and blocking _ready held a blank
	# grey window that long (owner). The worker builds it front-of-queue
	# while the player is HELD (see _process), and the window renders.
	_freeze_player(true)
	_thread.start(_worker)

# The player is HELD (physics + input off) whenever their chunk has no
# terrain yet — spawn, teleports, or outrunning the streamer — so they never
# fall through unbuilt ground while the worker catches up.
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
		var c: Vector2i = _jobs.pop_front() if not _jobs.is_empty() else Vector2i.MAX
		_mutex.unlock()
		if c == Vector2i.MAX:
			continue
		var region = _mesher.chunk_region(_plan, c)
		var node := _mesher.build_chunk(_plan, c, region)
		var wnode := _water_builder.build_chunk(_water, c, region)
		if wnode != null:
			node.add_child(wnode)
		# FX *data* is computed here (needs the worker-confined _plan region for
		# ground heights), but the FX *nodes* (particles/fog/lights touch the
		# renderer) are built on the main thread at integration — see _build_fx.
		var fx_data := _biome_fx_data(c, region)
		_mutex.lock()
		_done.append([c, node, fx_data])
		_mutex.unlock()

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
	# The player's chunk jumps the queue but never blocks the frame; the
	# player stays held until it lands.
	if _built.has(centre):
		_freeze_player(false)
	else:
		_freeze_player(true)
		_mutex.lock()
		var qi := _jobs.find(centre)
		if qi > 0:
			_jobs.remove_at(qi)
			_jobs.push_front(centre)
		elif qi < 0 and not _queued.has(centre):
			_queued[centre] = true
			_jobs.push_front(centre)
			_sem.post()
		_mutex.unlock()
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
			pair[1].free()   # duplicate or stale (player moved on) — discard
			continue
		terrain_parent.add_child(pair[1])
		_build_fx(pair[1], pair[2])   # main thread: particles/fog/lights
		WaterSurfaceBuilder.build_mist(pair[1])   # main thread: plunge mist
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
