class_name TerrainStreamingTelemetry
extends RefCounted

## Opt-in CPU-only instrumentation. Own lock; never reads live field caches
## from the main thread. Bounded samples preserve long-session memory limits.
const SAMPLE_CAP := 4096
const EVENT_CAP := 256
var enabled := false
var _lock := Mutex.new()
var _counts: Dictionary = {}
var _times: Dictionary = {}
var _events: Array[Dictionary] = []
var _started: Dictionary = {}
var _cache: Dictionary = {}
var _lifecycle: Array[Dictionary] = []
var _event_serial := 0
var _job_serial := 0

func count(key: StringName, amount := 1) -> void:
	if not enabled: return
	_lock.lock()
	_counts[key] = int(_counts.get(key, 0)) + amount
	_lock.unlock()

func timing(key: StringName, usec: int) -> void:
	if not enabled: return
	_lock.lock()
	var row: Dictionary = _times.get(key, {"count": 0, "total_usec": 0, "max_usec": 0, "samples": []})
	row.count += 1
	row.total_usec += usec
	row.max_usec = maxi(row.max_usec, usec)
	if row.samples.size() < SAMPLE_CAP: row.samples.append(usec)
	_times[key] = row
	_lock.unlock()

func job_queued(job: Dictionary) -> void:
	if not enabled: return
	_lock.lock()
	_job_serial += 1
	job["profile_id"] = _job_serial
	job["queued_msec"] = Time.get_ticks_msec()
	_lock.unlock()
	job_event(&"queued", job)

func job_event(event: StringName, job: Dictionary, details: Dictionary = {}) -> void:
	if not enabled: return
	_lock.lock()
	_event_serial += 1
	var row := job.duplicate(true)
	row.merge(details, true)
	row["event"] = event
	row["serial"] = _event_serial
	row["msec"] = Time.get_ticks_msec()
	_lifecycle.append(row)
	if _lifecycle.size() > EVENT_CAP: _lifecycle.pop_front()
	_lock.unlock()

func job_started(job: Dictionary, centre: Vector2i) -> void:
	if not enabled: return
	job_event(&"start", job, {"centre": centre,
		"queue_wait_msec": Time.get_ticks_msec() - int(job.get("queued_msec", Time.get_ticks_msec()))})
	var kind := StringName(job.get("kind", &"chunk"))
	var key := "%s/%s/%s/%s/%s/%s/%s/%s" % [kind, job.get("tile", job.chunk),
		job.get("generation", 0), job.get("terrain_generation", 0), job.get("feature_generation", 0),
		job.get("build_terrain", false), job.get("build_features", false), job.get("resume_count", 0)]
	_lock.lock()
	if _started.has(key): _counts[&"duplicate_job_starts"] = int(_counts.get(&"duplicate_job_starts", 0)) + 1
	if _started.size() < 16384: _started[key] = true
	var event := job.duplicate()
	event["event"] = "start"
	event["msec"] = Time.get_ticks_msec()
	event["centre"] = centre
	event["distance_now"] = maxi(absi(job.chunk.x - centre.x), absi(job.chunk.y - centre.y))
	_events.append(event)
	if _events.size() > EVENT_CAP: _events.pop_front()
	_lock.unlock()
	count(StringName("started/" + String(kind)))

func cache_stats(value: Dictionary) -> void:
	if not enabled: return
	_lock.lock()
	_cache = value.duplicate(true)
	_lock.unlock()

func snapshot() -> Dictionary:
	_lock.lock()
	var result := {"counts": _counts.duplicate(true), "times": _times.duplicate(true),
		"recent_starts": _events.duplicate(true), "field_cache": _cache.duplicate(true),
		"recent_events": _lifecycle.duplicate(true)}
	_lock.unlock()
	return result
