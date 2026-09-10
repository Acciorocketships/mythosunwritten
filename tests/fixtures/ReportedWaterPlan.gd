extends WaterPlan
## Frozen pre-generation-change traces keep historical screenshot regressions
## meaningful. The historical natural-height input belongs to the same fixture;
## live clamp, terrain reconstruction, carving, contour and skin still run.
## Natural-height input is pinned to the pre-rebuild 01a6e1b4 field.
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


## Frozen traces must be paired with the ground on which they were reported.
## Otherwise a new world generator moves the banks away from the pinned river.
func make_heightfield() -> HeightfieldPlan:
	var plan := HeightfieldPlan.new(world_seed, amplitude, max_storeys, "mean", 3)
	plan.set_raw_height_override(func(cx: int, cz: int) -> float:
		return noise_h(Vector2(cx * TILE, cz * TILE)))
	plan.set_water_plan(self)
	return plan

func smooth01(p: Vector2) -> float:
	return _reported_height01(p, false)

func noise_h(p: Vector2) -> float:
	return _reported_height01(p, true) * amplitude

func _reported_height01(p: Vector2, detail_enabled: bool) -> float:
	var pos := Vector3(p.x, 0.0, p.y)
	var base := Helper._value_noise01(pos, world_seed, 320.0)
	var hills := Helper._value_noise01(pos, world_seed + 5, 120.0)
	var h := (base + hills * 0.5) / 1.5
	if detail_enabled:
		var detail := Helper._value_noise01(pos, world_seed + 9, 46.0)
		h = (base + hills * 0.5 + detail * 0.25) / 1.75
	var rocky := smoothstep(0.5, 0.8,
		Helper._value_noise01(pos, world_seed + 37, 150.0))
	h *= 0.35 + 1.5 * rocky
	if rocky > 0.5:
		var n := Helper._value_noise01(pos, world_seed + 17, 190.0)
		var ridge := 1.0 - absf(2.0 * n - 1.0)
		h += ridge * ridge * (rocky - 0.5) * 0.9
	return clampf(h * clampf((p.length() - 60.0) / 120.0, 0.0, 1.0), 0.0, 1.0)
