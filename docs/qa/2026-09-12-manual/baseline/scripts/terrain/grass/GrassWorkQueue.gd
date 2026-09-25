class_name GrassWorkQueue
extends RefCounted

## One visual worker consumes detached sampling data only. It never enters the
## canonical terrain, road or water planners and never creates render resources.
var _program: GrassProgram
var _seed: int
var _thread := Thread.new()
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
	assert(_thread.start(_work) == OK)

func update_origin(origin: Vector2) -> void:
	_mutex.lock()
	if _origin == origin:
		_mutex.unlock()
		return
	_origin = origin
	for index in range(_jobs.size()-1,-1,-1):
		var job: Dictionary = _jobs[index]
		if GrassStreamer.distance_to_tile(origin,job.tile) > GrassStreamer.KEEP_RADIUS:
			_queued.erase(job.tile)
			_jobs.remove_at(index)
			_cancelled += 1
	_sort_locked()
	_mutex.unlock()

func request(tile: Vector2i, generation: int, sampling: GrassSamplingContext) -> bool:
	_mutex.lock()
	if _exit or GrassStreamer.distance_to_tile(_origin,tile) >= GrassStreamer.GRASS_RADIUS \
		or (not _active.is_empty() and _active.tile == tile):
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
		"active_tile":str(_active.tile) if not _active.is_empty() else "",
		"completed_waiting":_done.size()}
	_mutex.unlock()
	return result

func stop() -> void:
	_mutex.lock()
	_exit = true
	_jobs.clear()
	_queued.clear()
	_mutex.unlock()
	_sem.post()
	if _thread.is_started(): _thread.wait_to_finish()
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
		_active = job
		_started += 1
		_mutex.unlock()
		var started := Time.get_ticks_usec()
		var sampling: GrassSamplingContext = job.sampling
		var payload := GrassField.compute(_program,_seed,job.tile,
			sampling.region,sampling.water,sampling.features)
		var result := {"tile":job.tile,"generation":job.generation,"grass":payload,
			"compute_usec":Time.get_ticks_usec()-started}
		# GDScript locals survive the next semaphore wait. Release the input
		# before publishing completion so an idle worker cannot retain old ground.
		sampling = null
		job = {}
		_mutex.lock()
		_active = {}
		if not _exit: _done.append(result)
		_mutex.unlock()
