class_name GrassWorkQueue
extends RefCounted

## WORKERS visual workers consume detached sampling data only. They never enter
## the canonical terrain, road or water planners and never create render
## resources. Every static/lazy cache GrassField.compute reaches is either
## pre-initialized in _init (BiomeRegistry) or locked (Helper noise corners,
## HeightfieldRegion/WaterFieldContext memos); the rest is per-call.
const WORKERS := 2
var _program: GrassProgram
var _seed: int
var _threads: Array[Thread] = []
var _mutex := Mutex.new()
var _sem := Semaphore.new()
var _exit := false
var _origin := Vector2.ZERO
var _jobs: Array[Dictionary] = []
var _queued: Dictionary = {}
var _active: Dictionary = {}
var _done: Array[Dictionary] = []
var _started := 0
var _cancelled := 0

func _init(program: GrassProgram, seed_value: int) -> void:
	_program = program
	_seed = seed_value
	# All shared biome metadata is initialized before either worker reads it.
	BiomeRegistry.max_foliage_density()
	for index in WORKERS:
		var thread := Thread.new()
		assert(thread.start(_work) == OK)
		_threads.append(thread)

func update_origin(origin: Vector2) -> void:
	_mutex.lock()
	if _origin == origin:
		_mutex.unlock()
		return
	_origin = origin
	for index in range(_jobs.size()-1,-1,-1):
		var job: Dictionary = _jobs[index]
		if GrassStreamer.distance_to_tile(origin,job.tile) > GrassStreamer.keep_radius():
			_queued.erase(job.tile)
			_jobs.remove_at(index)
			_cancelled += 1
	_sort_locked()
	_mutex.unlock()

func request(tile: Vector2i, generation: int, sampling: GrassSamplingContext) -> bool:
	_mutex.lock()
	if _exit or GrassStreamer.distance_to_tile(_origin,tile) >= GrassStreamer.GRASS_RADIUS \
		or _active.has(tile):
		_mutex.unlock()
		return false
	if _queued.has(tile):
		_queued[tile].generation = generation
		_queued[tile].sampling = sampling
		_mutex.unlock()
		return true
	var job := {"tile":tile,"generation":generation,"sampling":sampling}
	_jobs.append(job)
	_queued[tile] = job
	_sort_locked()
	_mutex.unlock()
	_sem.post()
	return true

func drain_results() -> Array[Dictionary]:
	_mutex.lock()
	var results: Array[Dictionary] = _done
	_done = []
	_mutex.unlock()
	return results

func stats() -> Dictionary:
	_mutex.lock()
	var result := {"queued":_jobs.size(),"started":_started,"cancelled":_cancelled,
		"active_tile":",".join(_active.keys().map(func(t:Vector2i)->String:return str(t))),
		"active":_active.size(),
		"completed_waiting":_done.size()}
	_mutex.unlock()
	return result

func active_count() -> int:
	_mutex.lock()
	var count := _active.size()
	_mutex.unlock()
	return count

func stop() -> void:
	_mutex.lock()
	_exit = true
	_jobs.clear()
	_queued.clear()
	_mutex.unlock()
	for index in WORKERS: _sem.post()
	for thread: Thread in _threads:
		if thread.is_started(): thread.wait_to_finish()
	_done.clear()
	_active.clear()

func _sort_locked() -> void:
	_jobs.sort_custom(func(a:Dictionary,b:Dictionary)->bool:
		var da := GrassStreamer.distance_to_tile(_origin,a.tile)
		var db := GrassStreamer.distance_to_tile(_origin,b.tile)
		return da < db or (is_equal_approx(da,db) and
			(a.tile.x < b.tile.x or (a.tile.x == b.tile.x and a.tile.y < b.tile.y))))

func _work() -> void:
	while true:
		_sem.wait()
		_mutex.lock()
		if _exit:
			_mutex.unlock()
			return
		if _jobs.is_empty():
			_mutex.unlock()
			continue
		var job: Dictionary = _jobs.pop_front()
		_queued.erase(job.tile)
		_active[job.tile] = true
		_started += 1
		_mutex.unlock()
		var started := Time.get_ticks_usec()
		var sampling: GrassSamplingContext = job.sampling
		var payload := GrassField.compute(_program,_seed,job.tile,
			sampling.region,sampling.water,sampling.features,sampling.supports)
		var result := {"tile":job.tile,"generation":job.generation,"grass":payload,
			"compute_usec":Time.get_ticks_usec()-started}
		# GDScript locals survive the next semaphore wait. Release the input
		# before publishing completion so an idle worker cannot retain old ground.
		var tile: Vector2i = job.tile
		sampling = null
		job = {}
		_mutex.lock()
		_active.erase(tile)
		if not _exit: _done.append(result)
		_mutex.unlock()
