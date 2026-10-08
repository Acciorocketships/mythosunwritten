extends RefCounted

## C# versions of WaterField's hydraulic fill kernels (_relax_fill,
## _reconcile_connected_surface, _smooth_fill_surface,
## _retain_source_connected_fill, _cap_hydrostatic_fill with its SpillSearch),
## of its source seeding (_claim_rivers, _contain_rivers, _seed_ponds;
## NativeWaterSeed.cs, GdPond.cs), of profile()'s terrain-shaped branch with
## the trace's natural terrain corridor (NativeWaterProfile.cs: the corridor
## is compute_rect_region's certified values on just the lattice points a
## profile reads, so no trace region is built) and of PriorityQueue.gd
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
const _CARVE := preload("res://scripts/native/NativeCarve.gd")

## Tests: force the GDScript reference.
static var force_off := false
static var enabled := false
static var _native: Object = null
static var _load_attempted := false
static var _gated := false
static var _mutex := Mutex.new()
## Profiles the C# shaped (tests).
static var profiles_served := 0


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


## The GDScript heap's entries as three arrays (seed_sources), relaxed.
static func relax_heap(m1: int, levels: PackedFloat32Array, gnd: PackedFloat32Array,
		river_levels: PackedFloat32Array, heap: Dictionary) -> void:
	_store(levels, _native.Relax(m1, levels, gnd, river_levels, heap.index, heap.level, heap.priority))


## WaterField._claim_rivers + _contain_rivers + _seed_ponds over a complete
## `gnd` (claims: WaterField._river_claims). Updates river_levels in place and
## returns the queue the GDScript would have built, as {"index", "level",
## "priority"} in heap order, plus "margins" and the C# phase times
## ("claim_usec", "contain_usec"). {} when the C# call failed (nothing changed).
static func seed_sources(claims: Array, ponds: Array, base: Vector2, m1: int,
		levels: PackedFloat32Array, gnd: PackedFloat32Array,
		river_levels: PackedFloat32Array) -> Dictionary:
	var all_ponds := ponds.duplicate()
	var position := {}
	for k in ponds.size():
		if not position.has(ponds[k].get_instance_id()): position[ponds[k].get_instance_id()] = k
	var t_points := []
	var t_widths := []
	var t_levels := []
	var t_bank := []
	var t_terminal := PackedInt32Array()
	var d_start := PackedInt32Array()
	var d_lo := PackedInt32Array()
	var d_hi := PackedInt32Array()
	var d_pos := []
	var d_w := []
	var d_lvl := []
	for claim: Array in claims:
		var tr: RiverTrace = claim[0]
		var prof: Dictionary = claim[2]
		t_points.append(tr.points)
		t_widths.append(tr.widths)
		t_levels.append(prof.levels)
		t_bank.append(claim[1])
		var terminal := -1
		if tr.pond != null:
			var id := tr.pond.get_instance_id()
			if not position.has(id):
				position[id] = all_ponds.size()
				all_ponds.append(tr.pond)
			terminal = position[id]
		t_terminal.append(terminal)
		d_start.append(d_lo.size())
		for d: Dictionary in prof.get("descents", []):
			d_lo.append(int(d.lo))
			d_hi.append(int(d.hi))
			d_pos.append(d.pos)
			d_w.append(d.w)
			d_lvl.append(d.lvl)
	d_start.append(d_lo.size())
	var flat_ponds := _CARVE.flatten_ponds(all_ponds)
	var flat := {"pond_vec": flat_ponds.pond_vec, "pond_num": flat_ponds.pond_num,
		"pond_int": flat_ponds.pond_int, "seed_ponds": ponds.size(),
		"t_points": t_points, "t_widths": t_widths, "t_levels": t_levels, "t_bank": t_bank,
		"t_terminal": t_terminal, "d_start": d_start, "d_lo": d_lo, "d_hi": d_hi,
		"d_pos": d_pos, "d_w": d_w, "d_lvl": d_lvl}
	var consts := PackedFloat64Array([WaterField.FILL_STEP, WaterPlan.BANK_FEATHER,
		PondStamp.WOBBLE, PondStamp.STOREY, PondStamp.SURFACE_DROP])
	var result = _native.SeedSources(flat, consts, base.x, base.y, m1, levels, gnd, river_levels)
	if not result is Array or (result as Array).size() != 7:
		return {}
	_store(river_levels, result[0])
	return {"index": PackedInt32Array(result[2]), "level": PackedFloat64Array(result[3]),
		"priority": PackedFloat64Array(result[4]), "margins": PackedFloat32Array(result[1]),
		"claim_usec": int(result[5]), "contain_usec": int(result[6])}


## WaterField._profile_compute's terrain-shaped branch for `trace` (level0 =
## levels[0]). Corner heights come from `source` (a region the GDScript would
## read) or, when null, from plan's natural corridor (corridor_terrain).
## Returns {"levels", "descents"} as the GDScript builds them, {} on failure.
static func profile(trace: RiverTrace, level0: float, source, plan: HeightfieldPlan) -> Dictionary:
	_mutex.lock()
	profiles_served += 1
	_mutex.unlock()
	var consts := _profile_consts()
	var lattice = _native.ProfileLattice(trace.points, trace.beds, level0, consts)
	if not lattice is PackedInt32Array or (lattice as PackedInt32Array).is_empty():
		return {}
	var heights := PackedFloat32Array()
	var storeys := PackedInt32Array()
	if source != null:
		var count: int = lattice.size() / 2
		heights.resize(count)
		storeys.resize(count)
		for k in count:
			heights[k] = source.surface_height(lattice[2 * k], lattice[2 * k + 1])
			storeys[k] = source.storey_at(lattice[2 * k], lattice[2 * k + 1])
	else:
		var terrain := corridor_terrain(plan, lattice)
		if terrain.is_empty():
			return {}
		heights = terrain.heights
		storeys = terrain.storeys
	var has_pond := trace.pond != null
	var r = _native.Profile(trace.points, trace.beds, trace.widths, level0, has_pond,
		trace.pond.surface_y() if has_pond else 0.0, lattice, heights, storeys, consts)
	if not r is Array or (r as Array).size() != 7:
		return {}
	var lo := PackedInt32Array(r[1])
	var hi := PackedInt32Array(r[2])
	var sizes := PackedInt32Array(r[3])
	var pos := PackedVector2Array(r[4])
	var w := PackedFloat32Array(r[5])
	var lvl := PackedFloat32Array(r[6])
	var descents: Array = []
	var at := 0
	for d in lo.size():
		descents.append({"lo": lo[d], "hi": hi[d], "pos": pos.slice(at, at + sizes[d]),
			"w": w.slice(at, at + sizes[d]), "lvl": lvl.slice(at, at + sizes[d])})
		at += sizes[d]
	return {"levels": PackedFloat32Array(r[0]), "descents": descents}


## Certified natural surface heights (float32) and storeys of the lattice
## points `lattice` (interleaved i, j): what plan.compute_rect_region over
## any certifying interior holds there, from the plan's samples near them
## only. {"heights", "storeys"}, {} on failure.
static func corridor_terrain(plan: HeightfieldPlan, lattice: PackedInt32Array) -> Dictionary:
	var terrain := _terrain_consts()
	var agg := _aggregation(plan.aggregation)
	var s = _native.CorridorPoints(lattice, terrain)
	if not s is PackedInt32Array:
		return {}
	var hs := plan.sample_heights(s)
	var d = _native.CorridorDisks(s, hs, agg, plan.max_storeys, plan.max_step, terrain)
	if not d is PackedInt32Array:
		return {}
	var hd := plan.sample_heights(d)
	var r = _native.CorridorTerrain(lattice, s, hs, d, hd, agg, plan.max_storeys, plan.max_step, terrain)
	if not r is Array or (r as Array).size() != 2:
		return {}
	return {"heights": PackedFloat32Array(r[0]), "storeys": PackedInt32Array(r[1])}


static func _aggregation(name: String) -> int:
	return 0 if name == "min" else (2 if name == "max" else 1)


static func _profile_consts() -> PackedFloat64Array:
	return PackedFloat64Array([WaterField.SURFACE_RIDE, WaterField.FILM, WaterField._EASE_BAND,
		WaterField._DESCENT_STEP, WaterField.DESCENT_CLAMP, WaterField.EPS,
		WaterField.DESCENT_POOL_GAP, WaterField.FALL_DROP_MIN, HeightfieldPlan.POINT,
		float(TerrainTileField.cliff_end)])


static func _terrain_consts() -> PackedFloat64Array:
	return PackedFloat64Array([HeightfieldPlan.STOREY_HEIGHT, HeightfieldPlan.LEVEL_HEIGHT,
		HeightfieldPlan.LEVELS_PER_STOREY, HeightfieldPlan._CLIFF_SEARCH_MAX,
		1.0 if HeightfieldPlan.RENDER_LEVELS else 0.0, HeightfieldPlan._NO_CLIFF])


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
			+ "_cap_hydrostatic_fill, SpillSearch, _claim_river_segment, _claim_rivers, "
			+ "_contain_rivers, _seed_ponds; NativeWaterSeed.cs, GdPond.cs with PondStamp; "
			+ "NativeWaterProfile.cs with profile()'s _descend_segment, _shape_descent_span, "
			+ "_dense_span_curve, _find_descent_knots, _eval_descent_knots, _descent_knot_tangents, "
			+ "_dense_span_points and HeightfieldPlan.region_kernel) "
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
	for case_index in 9:
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
	var seeded := _seed_parity(rng)
	if not seeded.is_empty():
		return seeded
	return _profile_parity(rng)


## Random traces (12 m-ish steps, zero and near-zero segments, storey drops,
## pools under DESCENT_POOL_GAP, near-EPS ties, source pools, terminal ponds
## above and below the end) over random natural regions with cliffs and level
## steps: the C# profile must equal WaterField._profile_compute (levels and
## every descent array). Then corridor_parity.
static func _profile_parity(rng: RandomNumberGenerator) -> String:
	for case_index in 15:
		var trace := RiverTrace.new()
		var n := rng.randi_range(1, 30)
		var p := Vector2(rng.randf_range(-40.0, 40.0), rng.randf_range(-40.0, 40.0))
		var dir := Vector2.from_angle(rng.randf() * TAU)
		var bed := rng.randf_range(24.0, 44.0)
		for i in n:
			trace.points.append(p)
			trace.beds.append(bed)
			trace.widths.append(rng.randf_range(4.0, 20.0))
			var roll := rng.randf()
			var step := 0.0 if roll < 0.05 else (0.0004 if roll < 0.08 else rng.randf_range(5.0, 14.0))
			dir = dir.rotated(rng.randf_range(-0.7, 0.7))
			p += dir * step
			roll = rng.randf()
			if roll < 0.35:
				bed -= 4.0 * rng.randi_range(1, 2)
			elif roll < 0.5:
				var ties := [0.05, 0.04999, 0.05001, 0.0]
				bed -= ties[rng.randi_range(0, 3)] if rng.randf() < 0.5 else rng.randf_range(0.0, 1.5)
		if rng.randf() < 0.3:
			trace.source_pool = PondStamp.new(p, 20.0, rng.randi(), 30, 4.0)
			trace.source_pool.surface_ceiling = trace.beds[0] + rng.randf_range(-3.0, 4.0)
		if rng.randf() < 0.6:
			trace.pond = PondStamp.new(p, 20.0, rng.randi(), 30, 4.0)
			trace.pond.surface_ceiling = bed + (rng.randf_range(-12.0, -5.0) if rng.randf() < 0.4
				else rng.randf_range(0.0, 6.0))
		# Natural region round the trace: terraced storeys near the beds,
		# cliffs (two-storey jumps) and random level steps.
		var lo := Vector2i(floori(trace.points[0].x / 12.0), floori(trace.points[0].y / 12.0)) - Vector2i(4, 4)
		var hi := lo + Vector2i(8, 8)
		for q: Vector2 in trace.points:
			lo = Vector2i(mini(lo.x, floori(q.x / 12.0) - 4), mini(lo.y, floori(q.y / 12.0) - 4))
			hi = Vector2i(maxi(hi.x, floori(q.x / 12.0) + 4), maxi(hi.y, floori(q.y / 12.0) + 4))
		var storeys := {}
		var levels := {}
		for j in range(lo.y, hi.y + 1):
			for i in range(lo.x, hi.x + 1):
				var near := 0
				for k in n:
					if trace.points[k].distance_squared_to(Vector2(i, j) * 12.0) \
							< trace.points[near].distance_squared_to(Vector2(i, j) * 12.0):
						near = k
				# By case: the local bed (ordinary reaches), the source's
				# height (sills, knots) or low ground (curves under a pond).
				var st := floori(trace.beds[near if case_index % 3 == 0 else 0] / 4.0) - rng.randi_range(-1, 3)
				if case_index % 3 == 2:
					st = rng.randi_range(0, 1)
				if rng.randf() < 0.15:
					st += rng.randi_range(2, 3)
				storeys[Vector2i(i, j)] = maxi(st, 0)
				levels[Vector2i(i, j)] = rng.randi_range(0, 3)
		var region := HeightfieldRegion.new(storeys, levels)
		var expected := WaterField._profile_compute(trace, region, false, false)
		var level0 := trace.beds[0] + WaterField.SURFACE_RIDE
		if trace.source_pool != null:
			level0 = minf(level0, trace.source_pool.surface_y())
		var actual := profile(trace, PackedFloat32Array([level0])[0], region, null)
		if actual.is_empty():
			return "profile failed (case %d)" % case_index
		if actual.levels != expected.levels or var_to_bytes(actual.descents) != var_to_bytes(expected.descents):
			return "profile differs (case %d, %d points)" % [case_index, n]
	return _corridor_parity(rng)


## Random samples (pits, spikes, x.5 roundings) under every aggregation and
## max_step: corridor terrain on an interior equals HeightfieldPlan's region
## kernel there (surface heights and storeys).
static func _corridor_parity(rng: RandomNumberGenerator) -> String:
	var terrain := _terrain_consts()
	var aggregations := ["min", "mean", "max"]
	for case_index in 9:
		var max_step: int = 1 + case_index % 3
		var max_storeys: int = 5 + rng.randi_range(0, 4)
		var agg: String = aggregations[(case_index / 3) % 3]
		var inset: int = HeightfieldPlan._CLIFF_SEARCH_MAX + ceili(float(max_storeys) / max_step)
		var grow: int = 1 + HeightfieldPlan.LEVELS_PER_STOREY + inset
		var interior := Vector2i(rng.randi_range(5, 10), rng.randi_range(5, 10))
		var width := interior.x + 2 * grow
		var rows := interior.y + 2 * grow
		var origin := Vector2i(rng.randi_range(-40, 40), rng.randi_range(-40, 40))
		# Terraces of nearly equal storeys (so diagonal-only cliffs, cliff
		# distances and level relaxation all occur) high enough for a rare pit
		# to clamp them from afar; x.5 levels and storeys exercise the rounding.
		var heights := PackedFloat64Array()
		heights.resize(width * rows)
		var top := float(max_storeys * 4 + 6)
		var block := rng.randi_range(3, 7)
		var base := rng.randi_range(maxi(0, max_storeys - 3), max_storeys)
		var block_storeys := {}
		for z in rows:
			for x in width:
				var cell := Vector2i(x / block, z / block)
				if not block_storeys.has(cell):
					block_storeys[cell] = maxi(0, base - rng.randi_range(0, 1))
				# Residuals the aggregation keeps on the block's own storey.
				var low := 0.0 if agg == "min" else (-1.99 if agg == "mean" else -3.99)
				var residual := rng.randf_range(low, low + 3.98)
				var roll := rng.randf()
				if roll < 0.2:
					residual = float(rng.randi_range(0, 3)) + 0.5 + floorf(low)
				elif roll < 0.3:
					residual = 2.0
				var h := float(block_storeys[cell]) * 4.0 + residual
				roll = rng.randf()
				if roll < (0.04 if case_index % 2 == 1 else 0.002):
					h = 0.0
				elif roll < 0.02:
					h = top
				heights[z * width + x] = h
		var kernel := HeightfieldPlan.region_kernel(heights, width, rows, inset, max_step, max_storeys, agg)
		var lattice := PackedInt32Array()
		var expected_h := PackedFloat32Array()
		var expected_s := PackedInt32Array()
		for z in interior.y:
			for x in interior.x:
				var idx := (z + grow) * width + x + grow
				lattice.append_array([origin.x + x + grow, origin.y + z + grow])
				var st: int = kernel[0][idx]
				var h := float(st) * HeightfieldPlan.STOREY_HEIGHT
				if HeightfieldPlan.RENDER_LEVELS:
					h += float(kernel[1][idx]) * HeightfieldPlan.LEVEL_HEIGHT
				expected_h.append(h)
				expected_s.append(st)
		var agg_id := _aggregation(agg)
		var s: PackedInt32Array = _native.CorridorPoints(lattice, terrain)
		var hs := _lookup(heights, width, rows, origin, s)
		if hs.size() != s.size() / 2:
			return "corridor points leave the sample rectangle (case %d)" % case_index
		var d: PackedInt32Array = _native.CorridorDisks(s, hs, agg_id, max_storeys, max_step, terrain)
		var hd := _lookup(heights, width, rows, origin, d)
		if hd.size() != d.size() / 2:
			return "corridor disks leave the sample rectangle (case %d)" % case_index
		var r = _native.CorridorTerrain(lattice, s, hs, d, hd, agg_id, max_storeys, max_step, terrain)
		if not r is Array or PackedFloat32Array(r[0]) != expected_h or PackedInt32Array(r[1]) != expected_s:
			return "corridor terrain differs (case %d, %s, step %d)" % [case_index, agg, max_step]
	return ""


static func _lookup(heights: PackedFloat64Array, width: int, rows: int, origin: Vector2i,
		points: PackedInt32Array) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for k in points.size() / 2:
		var x := points[2 * k] - origin.x
		var z := points[2 * k + 1] - origin.y
		if x < 0 or z < 0 or x >= width or z >= rows:
			break
		out.append(heights[z * width + x])
	return out


## Random rivers over terraced lattices: claim ties (equal levels, equal
## margins), descent spans, degenerate and single-point traces, terminal ponds
## inside and outside the pond list, bank widths from zero to wide. The C#
## seeding must equal _claim_rivers + _contain_rivers + _seed_ponds: river
## levels, margins and the queue heap (index, level and priority, in order).
static func _seed_parity(rng: RandomNumberGenerator) -> String:
	for case_index in 16:
		var m1 := rng.randi_range(24, 44)
		var rows := m1 if case_index % 3 == 0 else rng.randi_range(24, 44)
		var n := m1 * rows
		var base := Vector2(rng.randi_range(-40, 40), rng.randi_range(-40, 40)) * WaterField.FILL_STEP \
			+ Vector2.ONE * WaterField.FILL_OFFSET
		var extent := Vector2(m1 - 1, rows - 1) * WaterField.FILL_STEP
		var ground := PackedFloat32Array(); ground.resize(n)
		var slope := Vector2(rng.randf_range(-0.05, 0.05), rng.randf_range(-0.05, 0.05))
		for j in rows:
			for i in m1:
				ground[j * m1 + i] = floorf(12.0 + slope.dot(Vector2(i, j) * WaterField.FILL_STEP)
					+ rng.randf_range(-1.0, 1.0))
		var ponds: Array = []
		var extra_ponds: Array = []
		for k in rng.randi_range(0, 3):
			var pond := PondStamp.new(base + Vector2(rng.randf(), rng.randf()) * extent,
				rng.randf_range(8.0, 40.0), rng.randi(), rng.randi_range(2, 5), rng.randf_range(1.0, 4.0))
			pond.aspect_ratio = rng.randf_range(0.4, 1.0)
			if rng.randf() < 0.4: pond.surface_ceiling = float(rng.randi_range(8, 18))
			ponds.append(pond)
		if rng.randf() < 0.5:
			extra_ponds.append(PondStamp.new(base + Vector2(rng.randf(), rng.randf()) * extent,
				rng.randf_range(8.0, 30.0), rng.randi(), rng.randi_range(2, 5), 2.0))
		var claims: Array = []
		for t in rng.randi_range(1, 6):
			var tr := RiverTrace.new()
			var count := 1 if rng.randf() < 0.15 else rng.randi_range(2, 7)
			var p := base + Vector2(rng.randf(), rng.randf()) * extent
			var heading := rng.randf() * TAU
			var levels := PackedFloat32Array()
			var points := PackedVector2Array()
			var widths := PackedFloat32Array()
			var level := float(rng.randi_range(9, 16))
			for k in count:
				points.append(p)
				widths.append(rng.randf_range(2.0, 22.0) if rng.randf() < 0.8 else 10.0)
				levels.append(level)
				if rng.randf() < 0.1: continue   # a repeated point (zero-length segment)
				heading += rng.randf_range(-0.8, 0.8)
				p += Vector2.from_angle(heading) * rng.randf_range(6.0, 30.0)
				level -= float(rng.randi_range(0, 2)) * 0.5   # ties on whole and half metres
			tr.points = points
			tr.widths = widths
			var bank := PackedFloat64Array()
			for k in count:
				var roll := rng.randf()
				bank.append(0.0 if roll < 0.3 else 1.0 if roll < 0.4 else rng.randf_range(0.0, 0.3))
			var descents := []
			if count >= 3 and rng.randf() < 0.6:
				var lo := rng.randi_range(0, count - 3)
				var hi := rng.randi_range(lo + 1, count - 1)
				var pos := PackedVector2Array()
				var w := PackedFloat32Array()
				var lvl := PackedFloat32Array()
				var steps := (hi - lo) * 3
				for k in steps + 1:
					var u := float(k) / float(steps) * float(hi - lo)
					var si := mini(lo + int(u), hi - 1)
					var f := u - float(si - lo)
					pos.append(tr.points[si].lerp(tr.points[si + 1], f))
					w.append(lerpf(tr.widths[si], tr.widths[si + 1], f))
					lvl.append(lerpf(levels[si], levels[si + 1], f))
				descents.append({"lo": lo, "hi": hi, "pos": pos, "w": w, "lvl": lvl})
			var pond_roll := rng.randf()
			if pond_roll < 0.3 and not ponds.is_empty():
				tr.pond = ponds[rng.randi_range(0, ponds.size() - 1)]
			elif pond_roll < 0.5 and not extra_ponds.is_empty():
				tr.pond = extra_ponds[0]
			claims.append([tr, bank, {"levels": levels, "descents": descents}])
		# A twin of one river, its widths a hair wider (margins within and just
		# beyond the 0.0001 tie band) and its levels shifted: the tie rule.
		if not claims.is_empty():
			var source: Array = claims[rng.randi_range(0, claims.size() - 1)]
			var twin := RiverTrace.new()
			twin.points = source[0].points
			var twin_widths := PackedFloat32Array()
			for width in source[0].widths:
				twin_widths.append(width + rng.randf_range(0.0, 0.0003))
			twin.widths = twin_widths
			var twin_levels := PackedFloat32Array()
			for value in source[2].levels:
				twin_levels.append(value + float(rng.randi_range(-1, 1)) * 0.5)
			claims.append([twin, source[1], {"levels": twin_levels, "descents": []}])
		var dry := PackedFloat32Array(); dry.resize(n); dry.fill(-INF)
		var expected := dry.duplicate()
		var actual := dry.duplicate()
		var margins := WaterField._claim_rivers(claims, base, m1, expected)
		var pq := PriorityQueue.new()
		WaterField._contain_rivers(ponds, null, base, m1, dry, ground, expected, margins, pq)
		WaterField._seed_ponds({"ponds": ponds}, null, base, m1, dry, ground, pq)
		var heap := seed_sources(claims, ponds, base, m1, dry, ground, actual)
		var heap_index := PackedInt32Array()
		var heap_level := PackedFloat64Array()
		var heap_priority := PackedFloat64Array()
		for entry: Dictionary in pq.heap:
			heap_index.append(entry.item[0])
			heap_level.append(entry.item[1])
			heap_priority.append(entry.priority)
		pq.free()
		if heap.is_empty():
			return "seeding failed in C# (case %d)" % case_index
		if actual != expected or heap.index != heap_index or heap.level != heap_level or heap.priority != heap_priority:
			return "river seeding differs (case %d, %dx%d)" % [case_index, m1, rows]
		if heap.margins != margins:
			return "river claim margins differ (case %d)" % case_index
	return ""
