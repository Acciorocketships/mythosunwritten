extends RefCounted

## C# versions of WaterField's hydraulic fill kernels (_relax_fill,
## _reconcile_connected_surface, _smooth_fill_surface,
## _retain_source_connected_fill, _cap_hydrostatic_fill with its SpillSearch) and of PriorityQueue.gd
## (scripts/native/NativeWaterFill.cs, GdPriorityQueue.cs). Used only once
## verified bit-identical to the GDScript on random lattices (setup()), and
## never under the standard editor. No class_name: preload it.
##
## WaterField dispatches with
##   if NativeWaterFill.on(): return NativeWaterFill.<kernel>(...)
## FieldTerrainStreamer._ready only loads the C# class (prepare()); the parity
## gate (about 0.3-0.4 s of GDScript reference runs) then happens lazily in the
## first on() call, on the worker that first solves water, never on the main
## thread. Tests and harnesses call setup() to load and gate at once.
## Relax, smooth and cap read ground only from their dense array, so WaterField uses
## them only when that array is complete (no INF, the "not sampled yet"
## sentinel of _ground_at); otherwise the GDScript runs.
## The GDScript kernels stay the reference: change them freely; a mismatch
## keeps the native path off and names the files to re-sync.

const _CS_PATH := "res://scripts/native/NativeWaterFill.cs"

## Tests: force the GDScript reference.
static var force_off := false
static var enabled := false
static var _native: Object = null
static var _load_attempted := false
static var _gated := false
static var _mutex := Mutex.new()


## Any thread. The first call runs the parity gate (unless setup() already
## did); a thread that finds the gate running elsewhere just uses GDScript.
static func on() -> bool:
	if not _gated and _mutex.try_lock():
		_gate()
		_mutex.unlock()
	return enabled and not force_off


## Test hook: -1 pops, any other value pushes (item = push count). Returns the
## final drain's items.
static func queue_replay(pushes: PackedFloat64Array) -> PackedInt64Array:
	setup()
	if _native == null:
		return PackedInt64Array()
	return PackedInt64Array(_native.QueueReplay(pushes))


static func relax(m1: int, levels: PackedFloat32Array, gnd: PackedFloat32Array,
		river_levels: PackedFloat32Array, pq: PriorityQueue) -> void:
	var n: int = pq.heap.size()
	var index := PackedInt32Array(); index.resize(n)
	var level := PackedFloat64Array(); level.resize(n)
	var priority := PackedFloat64Array(); priority.resize(n)
	for k in n:
		var entry: Dictionary = pq.heap[k]
		index[k] = entry.item[0]
		level[k] = entry.item[1]
		priority[k] = entry.priority
	pq.heap.clear()
	_store(levels, _native.Relax(m1, levels, gnd, river_levels, index, level, priority))


static func reconcile(levels: PackedFloat32Array, ground: PackedFloat32Array,
		columns: int, step: float) -> int:
	var result: Array = _native.Reconcile(levels, ground, columns, step)
	_store(levels, result[0])
	return result[1]


static func smooth(m1: int, levels: PackedFloat32Array, gnd: PackedFloat32Array,
		river_levels: PackedFloat32Array, physical_ceilings: PackedFloat32Array,
		passes: int) -> void:
	_store(levels, _native.Smooth(m1, levels, gnd, river_levels, physical_ceilings, passes))


static func retain(levels: PackedFloat32Array, side: int,
		source_indices: PackedInt32Array) -> int:
	var result: Array = _native.Retain(levels, side, source_indices)
	_store(levels, result[0])
	return result[1]


## WaterField._cap_hydrostatic_fill (with its SpillSearch) over a dense
## `ground`; `natural_ground` is the dense uncarved lattice or empty (none).
## Caps `levels` in place and returns the ceilings.
static func cap(side: int, levels: PackedFloat32Array, ground: PackedFloat32Array,
		anchors: PackedFloat32Array, natural_ground: PackedFloat32Array,
		flow_ceilings: PackedFloat32Array) -> PackedFloat32Array:
	var result: Array = _native.CapHydrostatic(side, levels, ground, anchors,
		not natural_ground.is_empty(), natural_ground, flow_ceilings)
	_store(levels, result[0])
	return result[1]


## The kernels mutate their caller's array (packed arrays are shared by
## reference); C# works on a copy, so write it back in place.
static func _store(target: PackedFloat32Array, values: PackedFloat32Array) -> void:
	target.clear()
	target.append_array(values)


## Main thread: load the C# class only (FieldTerrainStreamer._ready); the gate
## then runs on the first worker call. Harmless to repeat.
static func prepare() -> void:
	_mutex.lock()
	_load()
	_mutex.unlock()


## Load and gate now (tests, harnesses). Harmless to repeat.
static func setup() -> void:
	_mutex.lock()
	_gate()
	_mutex.unlock()


## Under _mutex. _gated is set before the parity runs, so the reference
## kernels it calls (whose on() re-enters this recursive mutex) stay GDScript.
static func _gate() -> void:
	if _gated:
		return
	_gated = true
	_load()
	if _native == null:
		return
	var mismatch := _parity()
	if mismatch.is_empty():
		enabled = true
	else:
		push_warning("NativeWaterFill disabled: %s. Re-sync scripts/native/NativeWaterFill.cs " % mismatch
			+ "(and GdPriorityQueue.cs) with scripts/terrain/water/WaterField.gd (_relax_fill, "
			+ "_reconcile_connected_surface, _smooth_fill_surface, _retain_source_connected_fill, "
			+ "_cap_hydrostatic_fill, SpillSearch) "
			+ "and scripts/core/PriorityQueue.gd; the water fill uses GDScript until then.")


## Under _mutex.
static func _load() -> void:
	if _load_attempted:
		return
	_load_attempted = true
	if not ClassDB.class_exists(&"CSharpScript"):
		return
	var script = load(_CS_PATH)
	if script == null or not script.can_instantiate():
		push_warning("NativeWaterFill: %s is not built (dotnet build Story.csproj); using GDScript." % _CS_PATH)
		return
	_native = script.new()


## Random lattices: ground terraced in 1 m steps (many level ties), about 10%
## river seeds, a few ponds, odd and even sides, square and not. Each kernel is
## compared with the GDScript reference (enabled is still false here, so the
## WaterField functions run their GDScript bodies).
static func _parity() -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261007
	# Heap order with heavy ties, pushes interleaved with pops.
	for case_index in 4:
		var pushes := PackedFloat64Array()
		var gd := PriorityQueue.new()
		for i in 300:
			var p := float(rng.randi_range(0, 6)) + (0.5 if rng.randf() < 0.1 else 0.0)
			pushes.append(p)
			gd.push(i, p)
			if rng.randf() < 0.3:
				pushes.append(-1.0)
				gd.pop()
		var order := PackedInt64Array()
		while not gd.is_empty():
			order.append(gd.pop())
		gd.free()
		if PackedInt64Array(_native.QueueReplay(pushes)) != order:
			return "priority queue order differs (case %d)" % case_index
	for case_index in 12:
		var m1 := rng.randi_range(20, 60)
		var rows := m1 if case_index % 3 == 0 else rng.randi_range(20, 60)
		var n := m1 * rows
		var ground := PackedFloat32Array(); ground.resize(n)
		var shift := 0.0 if case_index % 4 == 0 else rng.randf_range(-50.0, 50.0)
		var bowl := Vector2(rng.randf_range(0.3, 0.7) * m1, rng.randf_range(0.3, 0.7) * rows)
		for j in rows:
			for i in m1:
				var d := Vector2(i, j).distance_to(bowl) * rng.randf_range(0.3, 0.6)
				ground[j * m1 + i] = floorf(d + rng.randf_range(-1.0, 1.0)) + shift # 1 m terraces
		var rivers := PackedFloat32Array(); rivers.resize(n); rivers.fill(-INF)
		var levels := PackedFloat32Array(); levels.resize(n); levels.fill(-INF)
		var pq := PriorityQueue.new()
		for idx in n:
			if rng.randf() < 0.1:
				# Whole and half metres: river heads tie with pond levels.
				rivers[idx] = ground[idx] + float(rng.randi_range(-1, 4)) * 0.5 \
					+ (WaterField.EPS if rng.randf() < 0.3 else 0.0)
				pq.push([idx, float(rivers[idx])], rivers[idx])
		# Ponds offer a whole disc at one double level (not a float32 value),
		# like WaterField._seed_ponds; some sit exactly on a terrace step or
		# EPS above one (the ground < level - EPS boundary).
		for _pond in rng.randi_range(1, 4):
			var centre := Vector2i(rng.randi_range(0, m1 - 1), rng.randi_range(0, rows - 1))
			var radius := rng.randi_range(1, 5)
			var roll := rng.randf()
			var lvl: float = ground[centre.y * m1 + centre.x] + (float(rng.randi_range(1, 4))
				if roll < 0.3 else float(rng.randi_range(1, 4)) + WaterField.EPS if roll < 0.6
				else rng.randf_range(0.5, 6.0))
			for j in range(maxi(0, centre.y - radius), mini(rows, centre.y + radius + 1)):
				for i in range(maxi(0, centre.x - radius), mini(m1, centre.x + radius + 1)):
					if Vector2i(i, j).distance_to(centre) <= radius and ground[j * m1 + i] < lvl - WaterField.EPS:
						pq.push([j * m1 + i, lvl], lvl)
		var expected := levels.duplicate()
		var actual := levels.duplicate()
		var pq_native := PriorityQueue.new()
		pq_native.heap = pq.heap.duplicate(true)
		WaterField._relax_fill(null, Vector2.ZERO, m1, expected, ground, rivers, pq)
		relax(m1, actual, ground, rivers, pq_native)
		pq.free()
		pq_native.free()
		if expected != actual:
			return "relax differs (case %d, %dx%d)" % [case_index, m1, rows]
		# Hydrostatic cap (SpillSearch): the relaxed flood plus a uniform
		# high head on dry nodes (wet boundaries, many tied spill heights),
		# river anchors, a dense uncarved ground and mixed flow ceilings.
		var cap_levels := expected.duplicate()
		var head := float(rng.randi_range(2, 8)) + shift
		var natural := PackedFloat32Array(); natural.resize(n)
		var flow := PackedFloat32Array(); flow.resize(n)
		for idx in n:
			if not is_finite(cap_levels[idx]) and rng.randf() < 0.6: cap_levels[idx] = head
			natural[idx] = ground[idx] + (float(rng.randi_range(0, 6)) * 0.5 if rng.randf() < 0.5 else 0.0)
			var roll := rng.randf()
			flow[idx] = INF if roll < 0.1 else -INF if roll < 0.2 else ground[idx] + rng.randf_range(0.0, 4.0)
		var cap_natural := case_index % 3 != 0
		var capped_expected := cap_levels.duplicate()
		var capped_actual := cap_levels.duplicate()
		var cap_ceilings := WaterField._cap_hydrostatic_fill(null, Vector2.ZERO, m1, capped_expected,
			ground, rivers, WaterField.FILL_STEP, null, natural if cap_natural else null, flow)
		if cap(m1, capped_actual, ground, rivers, natural if cap_natural else PackedFloat32Array(),
				flow) != cap_ceilings or capped_actual != capped_expected:
			return "hydrostatic cap differs (case %d, %dx%d)" % [case_index, m1, rows]
		# Source retention from a few of the filled seeds (and a dry one).
		var sources := PackedInt32Array()
		for _s in rng.randi_range(0, 5):
			sources.append(rng.randi_range(0, n - 1))
		var kept_expected := expected.duplicate()
		var kept_actual := expected.duplicate()
		var removed_expected := WaterField._retain_source_connected_fill(kept_expected, m1, sources)
		if retain(kept_actual, m1, sources) != removed_expected or kept_actual != kept_expected:
			return "retain differs (case %d, %dx%d)" % [case_index, m1, rows]
		var ceilings := PackedFloat32Array()
		if case_index % 2 == 1:
			ceilings = expected.duplicate()
			for idx in n:
				if rng.randf() < 0.2:
					ceilings[idx] = ground[idx] + rng.randf_range(0.0, 3.0)
				elif rng.randf() < 0.1:
					ceilings[idx] = INF
		# Shallow nodes, so the ground + EPS + 0.01 floor binds too.
		var shallow := expected.duplicate()
		for idx in n:
			if is_finite(shallow[idx]) and rng.randf() < 0.3:
				shallow[idx] = ground[idx] + rng.randf_range(0.0, 0.1)
		var smooth_expected := shallow.duplicate()
		var smooth_actual := shallow.duplicate()
		WaterField._smooth_fill_surface(null, Vector2.ZERO, m1, smooth_expected, ground, rivers, ceilings)
		smooth(m1, smooth_actual, ground, rivers, ceilings, WaterField.FILL_SURFACE_PASSES)
		if smooth_expected != smooth_actual:
			return "smooth differs (case %d, %dx%d)" % [case_index, m1, rows]
		# Reconcile sees unsampled (INF) ground too and both lattice steps.
		var reconcile_ground := ground.duplicate()
		for idx in n:
			if rng.randf() < 0.05:
				reconcile_ground[idx] = INF
		var step := WaterField.FILL_STEP if case_index % 2 == 0 else WaterField.FILL_SUB_STEP
		# Unsmoothed relax output keeps the steep joins reconcile lowers.
		var surface := expected if case_index % 2 == 0 else smooth_expected
		var reconciled_expected := surface.duplicate()
		var reconciled_actual := surface.duplicate()
		var offers_expected := WaterField._reconcile_connected_surface(
			reconciled_expected, reconcile_ground, m1, step)
		if reconcile(reconciled_actual, reconcile_ground, m1, step) != offers_expected \
				or reconciled_actual != reconciled_expected:
			return "reconcile differs (case %d, %dx%d)" % [case_index, m1, rows]
	return ""
