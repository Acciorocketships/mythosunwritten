extends WaterPlan
## Frozen pre-generation-change traces keep historical screenshot regressions
## meaningful. Runtime fields, terrain, carving, contour and skin stay live.
func _init(seed_v: int, amp := 22.0, cap := 8) -> void:
	super(seed_v, amp, cap)
	var file := FileAccess.open("res://tests/fixtures/water_%d.var" % seed_v, FileAccess.READ)
	var records: Dictionary = file.get_var()
	for sc: Vector2i in records:
		var r: Dictionary = records[sc]
		var t := RiverTrace.new()
		t.source_cell = sc
		t.priority = r.priority
		t.points = r.points
		t.beds = r.beds
		t.widths = r.widths
		t.joined = r.joined
		t.source_pool = _pond(r.pool)
		t.pond = _pond(r.pond)
		_trace_cache[Vector3i(sc.x, sc.y, JOIN_DEPTH)] = t
func river_for(sc: Vector2i, depth: int = JOIN_DEPTH,
		_progress_start := -1.0, _progress_end := -1.0) -> RiverTrace:
	return _trace_cache.get(Vector3i(sc.x, sc.y, JOIN_DEPTH)) as RiverTrace
static func _pond(data: Array) -> PondStamp:
	return null if data.is_empty() else PondStamp.new(data[0], data[1], data[2], data[3], data[4])
