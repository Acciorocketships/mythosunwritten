extends RefCounted

## C# version of WaterPlan's river/pond carve (scripts/native/NativeCarve.cs),
## used by HeightfieldPlan._prefetch_samples to fill a whole window's samples
## ([h - carve, carve, h]) in one call per pool task, only where verified
## bit-identical to the GDScript reference. No class_name: preload it.
##
## setup(seed) (WaterPlan._init) only loads C# and hands it the constants.
## region_for(plan, rc, region) builds a carve region's C# copy lazily, the
## first time the batched prefetch needs it, and keeps it in the plan's
## _native_regions cache (under the plan's lock; the published region
## dictionary is never mutated; two threads building the same copy is
## harmless, the first stored wins). The parity gate runs as copies are built:
## the C# region carves probe points (on segment cells, round ponds, at random
## in the region) and must equal WaterPlan._carve_region exactly (!=). The
## first GATE_REGIONS copies of a seed take GATE_POINTS probes, the next
## SPOT_REGIONS take SPOT_POINTS, later ones none. A mismatch turns the seed
## off for good (a warning names the files to re-sync) and the window falls
## back to the GDScript prefetch. Probe ground comes straight from
## HeightfieldPlan.natural01, so WaterPlan's field memo is untouched.
## Lifetime: each region is its own NativeCarve object held by the cache, so
## eviction needs no release and an in-flight batch keeps its regions alive.

const _CS_PATH := "res://scripts/native/NativeCarve.cs"
const NATIVE_HEIGHT := preload("res://scripts/native/NativeHeightField.gd")
const GATE_REGIONS := 3
const GATE_POINTS := 2000
const SPOT_REGIONS := 8
const SPOT_POINTS := 32

## Tests: force the GDScript reference.
static var force_off := false
static var enabled := false
## Seeds whose regions may be built natively (replaced, never mutated).
static var seeds: Dictionary = {}
## Seeds that failed a region check (replaced, never mutated).
static var failed: Dictionary = {}
## Regions verified per seed (tests, gate sizing).
static var regions_checked: Dictionary = {}
## Native copies built, all seeds (tests, QA).
static var regions_served := 0
## Samples the batched prefetch filled natively, all plans (tests, QA).
static var samples_filled := 0
static var _native: Object = null
static var _script: Script = null
static var _native_failed := false
static var _mutex := Mutex.new()


static func ready_for(seed: int) -> bool:
	if not enabled or force_off or HeightfieldPlan.LOWPASS_M > 0.0 or not NATIVE_HEIGHT.ready_for(seed):
		return false
	_mutex.lock()
	var ok := seeds.has(seed) and not failed.has(seed)
	_mutex.unlock()
	return ok


static func count_filled(n: int) -> void:
	_mutex.lock()
	samples_filled += n
	_mutex.unlock()


static func setup(seed: int) -> void:
	_mutex.lock()
	if _native == null and not _native_failed and not _load_native():
		_native_failed = true
	if _native != null and not seeds.has(seed):
		var next := seeds.duplicate()
		next[seed] = true
		seeds = next
		enabled = true
	_mutex.unlock()


## Drop every verified seed (tests).
static func reset() -> void:
	_mutex.lock()
	seeds = {}
	failed = {}
	regions_checked = {}
	regions_served = 0
	enabled = false
	_mutex.unlock()


## The verified C# copy of carve region `region` (super-cell rc), built on
## first use; null when the seed is off or the copy failed its check.
static func region_for(plan: WaterPlan, rc: Vector2i, region: Dictionary) -> Object:
	var seed := plan.world_seed
	if not ready_for(seed):
		return null
	plan._lock.lock()
	var entry = plan._native_regions.get(rc)
	plan._lock.unlock()
	if entry != null and is_same(entry[0], region):
		return entry[1]
	var obj: Object = _script.new()
	var err: String = obj.Build(_flatten(plan, rc, region))
	var mismatch := "C# build failed: " + err if err != "" else ""
	if mismatch == "":
		_mutex.lock()
		var done: int = regions_checked.get(seed, 0)
		_mutex.unlock()
		var probes := GATE_POINTS if done < GATE_REGIONS \
			else (SPOT_POINTS if done < GATE_REGIONS + SPOT_REGIONS else 0)
		if probes > 0:
			mismatch = _parity(plan, rc, region, obj, probes)
	_mutex.lock()
	if mismatch != "":
		var next := failed.duplicate()
		next[seed] = true
		failed = next
		_mutex.unlock()
		push_warning("NativeCarve disabled for seed %d: region %s %s. Re-sync scripts/native/NativeCarve.cs " % [seed, rc, mismatch]
			+ "with WaterPlan._carve_region / PondStamp / RiverTrace.retained_ground_weight. Using the GDScript carve.")
		return null
	var counts := regions_checked.duplicate()
	counts[seed] = int(counts.get(seed, 0)) + 1
	regions_checked = counts
	regions_served += 1
	_mutex.unlock()
	plan._lock.lock()
	entry = plan._native_regions.get(rc)
	if entry != null and is_same(entry[0], region):
		obj = entry[1]   # another thread stored the same region's copy first
	else:
		WaterPlan._memo_insert(plan._native_regions, rc, [region, obj], WaterPlan.CARVE_REGION_CACHE_LIMIT)
	plan._lock.unlock()
	return obj


## [h - carve, carve, h] for lattice points lo + (index % width, index / width),
## flattened. Every owner super-cell's region must carry "native".
static func sample_batch(plan: HeightfieldPlan, lo: Vector2i, width: int, indices: PackedInt32Array,
		regions: Array, keys: PackedInt32Array) -> PackedFloat64Array:
	var water: WaterPlan = plan._water_plan
	return _native.SampleBatch(plan.world_seed, lo.x, lo.y, width, indices, regions, keys,
		HeightfieldPlan.POINT, plan.height_amplitude, water.amplitude,
		TerrainField.spawn_level_m(plan.world_seed), TerrainField.REF_AMPLITUDE)


static func _load_native() -> bool:
	if not ClassDB.class_exists(&"CSharpScript"):
		return false
	var script = load(_CS_PATH)
	if script == null or not script.can_instantiate():
		push_warning("NativeCarve: %s is not built (dotnet build Story.csproj); using GDScript." % _CS_PATH)
		return false
	var native: Object = script.new()
	var err: String = native.Configure(_consts())
	if err != "":
		push_warning("NativeCarve: C# constants rejected (%s); using GDScript." % err)
		return false
	_script = script
	_native = native
	return true


static func _consts() -> Dictionary:
	var out := {}
	for k: String in ["TILE", "SUPER", "SPAWN_WATER_RADIUS", "BANK_FEATHER", "CARVE_FEATHER",
			"CARVE_BED_EXTRA", "CARVE_EXTRA_MAX_GRADE", "BED_MIN", "STOREY"]:
		out[k] = float((WaterPlan as Script).get_script_constant_map()[k])
	out["SURFACE_RIDE"] = float(WaterField.SURFACE_RIDE)
	out["POND_STOREY"] = float(PondStamp.STOREY)
	out["WOBBLE"] = float(PondStamp.WOBBLE)
	out["SURFACE_DROP"] = float(PondStamp.SURFACE_DROP)
	out["RIM_FEATHER"] = float(PondStamp.RIM_FEATHER)
	return out


## A carve region as flat arrays (NativeCarve.cs Build).
static func _flatten(plan: WaterPlan, rc: Vector2i, region: Dictionary) -> Dictionary:
	var pond_vec := PackedVector2Array()
	var pond_num := PackedFloat64Array()
	var pond_int := PackedInt64Array()
	var pond_index := {}
	for pond: PondStamp in region.ponds:
		pond_index[pond.get_instance_id()] = pond_index.size()
		pond_vec.append(pond.center)
		pond_vec.append(pond.island_offset)
		pond_num.append_array([pond.radius, pond.surface_ceiling, pond.depth, pond.island_radius, pond.aspect_ratio])
		pond_int.append_array([pond.shape_seed, pond.level, 1 if pond.peninsula else 0])
	var trace_index := {}
	var points := []
	var beds := []
	var widths := []
	var bank := []
	var bar_vec := []
	var bar_num := []
	var trace_pond := PackedInt32Array()
	for t: RiverTrace in region.rivers:
		trace_index[t.get_instance_id()] = trace_index.size()
		points.append(t.points)
		beds.append(t.beds)
		widths.append(t.widths)
		bank.append(plan.bank_strengths(t))
		var bv := PackedVector2Array()
		var bn := PackedFloat64Array()
		for bar: Dictionary in t.land_bars:
			bv.append(bar.center)
			bv.append(bar.axis)
			bn.append(float(bar.half_length))
			bn.append(float(bar.half_width))
		bar_vec.append(bv)
		bar_num.append(bn)
		trace_pond.append(pond_index.get(t.pond.get_instance_id(), -1) if t.pond != null else -1)
	var side := int(WaterPlan.SUPER / WaterPlan.TILE)
	var first := rc * side
	var cell_start := PackedInt32Array()
	cell_start.resize(side * side + 1)
	var seg := PackedInt32Array()
	var segments: Dictionary = region.segments
	for lz in side:
		for lx in side:
			cell_start[lz * side + lx] = seg.size() / 2
			var flat: Array = segments.get(first + Vector2i(lx, lz), [])
			for n in range(0, flat.size(), 2):
				seg.append(trace_index[flat[n].get_instance_id()])
				seg.append(flat[n + 1])
	cell_start[side * side] = seg.size() / 2
	return {"pond_vec": pond_vec, "pond_num": pond_num, "pond_int": pond_int,
		"trace_points": points, "trace_beds": beds, "trace_widths": widths, "trace_bank": bank,
		"bar_vec": bar_vec, "bar_num": bar_num, "trace_pond": trace_pond,
		"first_cell": first, "side": side, "cell_start": cell_start, "seg": seg}


# ---------------------------------------------------------------- parity

## "" when the C# region carves `count` probe points of super-cell rc exactly
## as WaterPlan._carve_region, else the first mismatch. Probes lie on segment
## cells (12 m lattice and quarter-metre points), round ponds and at random,
## all in cells this region owns.
static func _parity(plan: WaterPlan, rc: Vector2i, region: Dictionary, obj: Object, count: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([plan.world_seed, rc, "native-carve-parity"])
	var side := int(WaterPlan.SUPER / WaterPlan.TILE)
	var first := rc * side
	var cells: Array = region.segments.keys()
	var xs := PackedFloat64Array()
	var zs := PackedFloat64Array()
	for k in count:
		var p: Vector2
		var roll := k % 4
		if roll < 2 and not cells.is_empty():
			var c: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
			if roll == 0:   # a 12 m lattice point owned by the cell
				p = Vector2(float(2 * c.x - rng.randi_range(0, 1)), float(2 * c.y - rng.randi_range(0, 1))) * HeightfieldPlan.POINT
			else:
				p = Vector2(c) * WaterPlan.TILE + Vector2(rng.randf_range(-12.0, 11.75), rng.randf_range(-12.0, 11.75))
				p = (p * 4.0).floor() / 4.0
		elif roll == 2 and not region.ponds.is_empty():
			var pond: PondStamp = region.ponds[rng.randi_range(0, region.ponds.size() - 1)]
			p = pond.center + Vector2.from_angle(rng.randf() * TAU) * rng.randf() * pond.bound_radius() * 1.1
		else:
			p = Vector2(first) * WaterPlan.TILE + Vector2(rng.randf(), rng.randf()) * WaterPlan.SUPER \
				- Vector2.ONE * (WaterPlan.TILE * 0.5)
		# Keep only points this region owns (a pond probe may fall outside).
		var cx := floori(float(p.x) / WaterPlan.TILE + 0.5)
		var cz := floori(float(p.y) / WaterPlan.TILE + 0.5)
		if cx < first.x or cz < first.y or cx >= first.x + side or cz >= first.y + side:
			continue
		xs.append(p.x)
		zs.append(p.y)
	# noise_h without its memo: the same natural01 at the same float32 point.
	var grounds := PackedFloat64Array()
	for k in xs.size():
		grounds.append(HeightfieldPlan.natural01(Vector3(xs[k], 0.0, zs[k]), plan.world_seed) * plan.amplitude)
	var cs: PackedFloat64Array = obj.CarveBatch(xs, zs, grounds)
	for k in xs.size():
		var gd := plan._carve_region(region, xs[k], zs[k], grounds[k])
		if cs[k] != gd:
			return "at (%s, %s): gd %s, cs %s" % [xs[k], zs[k], var_to_str(gd), var_to_str(cs[k])]
	return ""
