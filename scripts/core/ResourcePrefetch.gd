extends RefCounted

## Main-thread startup helper: start several resource loads on Godot's
## threaded loader at once, then `take` each one where it is used. Large
## textures (the 4K Meadow rocks) decode in parallel instead of one after
## another, and `take` of a path never requested is an ordinary `load`, so
## callers stay correct with or without a prefetch. Output is identical: the
## same resources load from the same files.
static var _requested: Dictionary = {}

static func request(paths: Array) -> void:
	for path: String in paths:
		if path.is_empty() or _requested.has(path) or ResourceLoader.has_cached(path):
			continue
		if ResourceLoader.load_threaded_request(path, "", true) == OK:
			_requested[path] = true

static func take(path: String) -> Resource:
	if _requested.erase(path):
		return ResourceLoader.load_threaded_get(path)
	return load(path)
