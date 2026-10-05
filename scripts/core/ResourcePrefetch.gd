extends RefCounted

## Main-thread startup helper: start several resource loads on Godot's
## threaded loader at once, then `take` each one where it is used. Large
## textures (the 4K Meadow rocks) decode in parallel instead of one after
## another, and `take` of a path never requested is an ordinary `load`, so
## callers stay correct with or without a prefetch. Output is identical: the
## same resources load from the same files.
static var _requested: Dictionary = {}
static var _finished: Dictionary = {}

static func request(paths: Array) -> void:
	# The headless dummy renderer's resource IDs are not thread-safe (parallel
	# loads there intermittently corrupt RID allocation); load serially there.
	if Helper.is_headless():
		return
	for path: String in paths:
		if path.is_empty() or _requested.has(path) or ResourceLoader.has_cached(path):
			continue
		if ResourceLoader.load_threaded_request(path, "", true) == OK:
			_requested[path] = true

static func take(path: String) -> Resource:
	if _finished.has(path):
		var resource: Resource = _finished[path]
		_finished.erase(path)
		return resource
	if _requested.erase(path):
		return ResourceLoader.load_threaded_get(path)
	return load(path)

## Finish every outstanding request now, keeping the results until taken.
## Call before main-thread work that creates render resources: loader threads
## still running beside it raced the renderer's resource allocation.
static func wait_all() -> void:
	for path: String in _requested.keys():
		_finished[path] = ResourceLoader.load_threaded_get(path)
	_requested.clear()
