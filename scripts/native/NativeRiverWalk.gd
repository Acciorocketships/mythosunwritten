extends RefCounted

## C# version of WaterPlan's source search (summit climb and its gates) and raw
## contour walk (scripts/native/NativeRiverWalk.cs), used only where verified
## bit-identical to the GDScript reference. No class_name: preload it.
##
## setup(seed) (called by WaterPlan._init, so on the main thread before the
## streamer's worker starts) does nothing under the standard editor. Under the
## .NET editor it hands WaterPlan's live constants to C# and compares C# with
## the GDScript functions on 40 fixed super-cells of that seed (source gate,
## source position, has_source and the whole raw walk, field by field with !=).
## Only a seed that passes is served natively. The native path also needs the
## native height field for the seed and an unfiltered natural field
## (HeightfieldPlan.LOWPASS_M == 0; the tent filter stays GDScript).

const _CS_PATH := "res://scripts/native/NativeRiverWalk.cs"
const NATIVE_HEIGHT := preload("res://scripts/native/NativeHeightField.gd")
const PARITY_CELLS := 40

## Tests and the parity gate: force the GDScript reference.
static var force_off := false
static var enabled := false
## Seeds served natively (replaced, never mutated, so readers on other threads
## always see a complete dictionary).
static var seeds: Dictionary = {}
static var _attempted: Dictionary = {}
static var _native: Object = null
static var _native_failed := false
static var _mutex := Mutex.new()


static func ready_for(seed: int) -> bool:
	return enabled and not force_off and seeds.has(seed) \
		and HeightfieldPlan.LOWPASS_M <= 0.0 and NATIVE_HEIGHT.ready_for(seed)


static func source_gate(plan: WaterPlan, sc: Vector2i) -> Dictionary:
	return _native.SourceGate(plan.world_seed, sc.x, sc.y, plan.amplitude,
		TerrainField.spawn_level_m(plan.world_seed), TerrainField.REF_AMPLITUDE)


static func source_pos(plan: WaterPlan, sc: Vector2i) -> Vector2:
	return _native.SourcePos(plan.world_seed, sc.x, sc.y, plan.amplitude,
		TerrainField.spawn_level_m(plan.world_seed), TerrainField.REF_AMPLITUDE)


static func pond_level(plan: WaterPlan, center: Vector2, radius: float) -> int:
	return _native.PondLevel(plan.world_seed, center, radius, plan.amplitude,
		TerrainField.spawn_level_m(plan.world_seed), TerrainField.REF_AMPLITUDE, plan.max_storeys)


static func walk(plan: WaterPlan, sc: Vector2i) -> Dictionary:
	return _native.Walk(plan.world_seed, sc.x, sc.y, plan.amplitude,
		TerrainField.spawn_level_m(plan.world_seed), TerrainField.REF_AMPLITUDE, plan.max_storeys)


static func setup(seed: int) -> void:
	_mutex.lock()
	if _attempted.has(seed) or _native_failed:
		_mutex.unlock()
		return
	_attempted[seed] = true
	if _native == null and not _load_native():
		_native_failed = true
		_mutex.unlock()
		return
	NATIVE_HEIGHT.setup(seed)
	var mismatch := ""
	if not NATIVE_HEIGHT.ready_for(seed):
		mismatch = "the native height field is off for this seed"
	elif HeightfieldPlan.LOWPASS_M > 0.0:
		mismatch = "HeightfieldPlan.LOWPASS_M is set"
	else:
		mismatch = _parity(seed)
	if mismatch == "":
		var next := seeds.duplicate()
		next[seed] = true
		seeds = next
		enabled = true
	elif ClassDB.class_exists(&"CSharpScript"):
		push_warning("NativeRiverWalk disabled for seed %d: %s. Re-sync scripts/native/NativeRiverWalk.cs " % [seed, mismatch]
			+ "with scripts/terrain/water/WaterPlan.gd (_jitter_pos/_ascend/_has_source_uncached/_walk/"
			+ "_contour_step/_contained_bed/_pond_level). Using the GDScript river walk.")
	_mutex.unlock()


## Drop every verified seed (tests): the next setup() re-checks parity.
static func reset() -> void:
	_mutex.lock()
	seeds = {}
	_attempted.clear()
	enabled = false
	_mutex.unlock()


static func _load_native() -> bool:
	if not ClassDB.class_exists(&"CSharpScript"):
		return false
	var script = load(_CS_PATH)
	if script == null or not script.can_instantiate():
		push_warning("NativeRiverWalk: %s is not built (dotnet build Story.csproj); using GDScript." % _CS_PATH)
		return false
	_native = script.new()
	var err: String = _native.Configure(_consts())
	if err != "":
		push_warning("NativeRiverWalk: C# constants rejected (%s); using GDScript." % err)
		_native = null
		return false
	return true


## WaterPlan's live constants for C#.
static func _consts() -> Dictionary:
	var out := {}
	var map: Dictionary = (WaterPlan as Script).get_script_constant_map()
	for k: String in map:
		var v = map[k]
		if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
			out[k] = v
	var steep: Vector2 = WaterPlan.SUMMIT_STEEP
	out["SUMMIT_STEEP_X"] = float(steep.x)
	out["SUMMIT_STEEP_Y"] = float(steep.y)
	out["WOBBLE"] = float(PondStamp.WOBBLE)
	out["POINT"] = float(HeightfieldPlan.POINT)
	return out


# ---------------------------------------------------------------- parity

## "" when C# equals GDScript on every probe, else the first mismatch. Two
## plans of the seed: `gd` forced to the reference, `cs` calling C# directly.
static func _parity(seed: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed, "river-walk-parity"])
	var gd := TerrainWorldTuning.make_water(seed)
	var saved := force_off
	var result := ""
	for n in PARITY_CELLS:
		var sc := Vector2i(rng.randi_range(-12, 12), rng.randi_range(-12, 12))
		force_off = true
		var gate: Dictionary = source_gate(gd, sc)
		var pos := gd.source_pos(sc)
		var has := gd.has_source(sc)
		var native_pos := source_pos(gd, sc)
		if native_pos != pos:
			result = "source_pos %s: gd %s cs %s" % [sc, pos, native_pos]
			break
		if gate.has_source_pos and gate.source_pos != pos:
			result = "source gate position %s: gd %s cs %s" % [sc, pos, gate.source_pos]
			break
		var gd_walk: RiverTrace = gd._walk(sc) if gate.passes_gates else null
		var gd_has: bool = gate.passes_gates \
			and gd_walk.points[-1].distance_to(gd_walk.points[0]) > WaterPlan.SUMMIT_REACH
		if gd_has != has:
			result = "source gates %s: gd has_source %s, cs gates %s" % [sc, has, gate.passes_gates]
			break
		if gate.passes_gates:
			var w: Dictionary = walk(gd, sc)
			var diff := _walk_diff(gd, sc, gd_walk, w)
			if diff != "":
				result = "walk %s: %s" % [sc, diff]
				break
	force_off = saved
	return result


static func _walk_diff(plan: WaterPlan, sc: Vector2i, t: RiverTrace, w: Dictionary) -> String:
	var points: PackedVector2Array = w.points
	var beds: PackedFloat32Array = w.beds
	var widths: PackedFloat32Array = w.widths
	if w.source != t.points[0]:
		return "source %s vs %s" % [t.points[0], w.source]
	if int(w.priority) != t.priority:
		return "priority"
	if int(w.pool_level) != t.source_pool.level:
		return "pool level %d vs %d" % [t.source_pool.level, w.pool_level]
	if points.size() != t.points.size():
		return "%d vs %d points" % [t.points.size(), points.size()]
	for i in points.size():
		if points[i] != t.points[i]:
			return "point %d: %s vs %s" % [i, t.points[i], points[i]]
		if beds[i] != t.beds[i]:
			return "bed %d: %s vs %s" % [i, t.beds[i], beds[i]]
	# The alluvial shaping may widen the tail; compare the trace the walk built.
	var built := plan._trace_from_native(sc, w)
	if built.widths != t.widths:
		return "widths"
	if built.pond.center != t.pond.center or built.pond.radius != t.pond.radius \
		or built.pond.level != t.pond.level or built.pond.surface_ceiling != t.pond.surface_ceiling \
		or built.pond.island_offset != t.pond.island_offset or built.pond.island_radius != t.pond.island_radius:
		return "terminal pond"
	if built.land_bars != t.land_bars:
		return "land bars"
	if pond_level(plan, t.pond.center, t.pond.radius) != t.pond.level:
		return "terminal pond level"
	return ""
