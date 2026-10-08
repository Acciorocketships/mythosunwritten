extends RefCounted

## C# implementation of TerrainField.height_m (scripts/native/*.cs), used only
## where it is verified bit-identical to the GDScript reference.
##
## No class_name on purpose: reference it with preload (a new global class
## would force a class-cache rebuild in every checkout).
##
## setup(seed) (called by HeightfieldPlan._init) does nothing under the
## standard editor (no CSharpScript class). Under the .NET editor it hands the
## live tuning tables to C#; the parity gate compares C# and GDScript heights
## bit for bit on a fixed deterministic point set for that seed (~4000
## points, with and without detail, ~2.2 s). Tests and harnesses gate at once
## in setup(); the game (NativeGates.deferred) only registers the seed, and the
## gate runs in the first ready_for(seed) on a non-main thread that wins the
## try_lock (a worker); every other caller, the main thread always, uses the
## GDScript field meanwhile (identical heights). Only a seed that passes is
## served natively; otherwise the game keeps the (slower) GDScript field and a
## warning names the files to re-sync. A C# call that throws turns the port
## off and that call returns the GDScript height.
## The GDScript field stays the reference: change it freely, the parity check
## turns the native path off until the C# mirror catches up.

const _CS_PATH := "res://scripts/native/NativeTerrainHeight.cs"
const _SCRIPTS := {
	"TerrainField": preload("res://scripts/terrain/heightfield/TerrainField.gd"),
	"TerrainRegimeField": preload("res://scripts/terrain/heightfield/TerrainRegimeField.gd"),
	"TerrainRegimeCatalog": preload("res://scripts/terrain/heightfield/TerrainRegimeCatalog.gd"),
	"LandformSetpieces": preload("res://scripts/terrain/heightfield/LandformSetpieces.gd"),
	"LandformFeatures": preload("res://scripts/terrain/heightfield/LandformFeatures.gd"),
	"ReliefPrimitives": preload("res://scripts/terrain/heightfield/ReliefPrimitives.gd"),
	"Helper": preload("res://scripts/core/Helper.gd"),
}
const CLUSTERS := 48   # parity clusters of 48 points (see parity_points)
const _GATES := preload("res://scripts/native/NativeGates.gd")

## True once the C# side is loaded and at least one seed passed its check.
static var enabled := false
## Seeds served natively (replaced, never mutated, so readers on other threads
## always see a complete dictionary).
static var seeds: Dictionary = {}
## Seeds registered by a deferred setup() whose gate has not run yet
## (replaced, never mutated).
static var _pending: Dictionary = {}
static var _attempted: Dictionary = {}
static var _native: Object = null
static var _native_failed := false
static var _mutex := Mutex.new()


## True when height_m(…, seed, …) is served by verified C#. A forced archetype
## (tests, gallery) is GDScript-only state the C# side does not mirror. Runs a
## deferred gate on a worker that wins the lock.
static func ready_for(seed: int) -> bool:
	if enabled and seeds.has(seed):
		return TerrainRegimeField._force == &""
	if _pending.has(seed) and _GATES.may_gate_here() and _mutex.try_lock():
		_gate(seed)
		_mutex.unlock()
		return enabled and seeds.has(seed) and TerrainRegimeField._force == &""
	return false


static func height_m(p: Vector2, seed: int, include_detail: bool) -> float:
	var h: float = _native.HeightM(p, seed, include_detail)
	if is_nan(h) and _fault(h):
		return TerrainField.height_m(p, seed, include_detail)
	return h


## Heights for many points in one call (PackedVector2Array -> PackedFloat64Array).
static func height_batch(points: PackedVector2Array, seed: int, include_detail: bool) -> PackedFloat64Array:
	var out = _native.HeightBatch(points, seed, include_detail)
	if _fault(out):
		out = PackedFloat64Array()
		out.resize(points.size())
		for k in points.size():
			out[k] = TerrainField.height_m(points[k], seed, include_detail)
	return out


## True (and the port off) when the C# call behind `result` threw.
static func _fault(result) -> bool:
	var err := _GATES.faulted(_native, result)
	if err.is_empty():
		return false
	enabled = false
	push_warning("NativeHeightField disabled: the C# call failed (%s); using GDScript heights." % err)
	return true


## Test hook: the next C# call (any port) throws once.
static func arm_fault() -> void:
	if _native != null:
		_native.ArmFault()


## Load C# and register the seed; gate now unless NativeGates.deferred.
static func setup(seed: int) -> void:
	_mutex.lock()
	if _GATES.deferred:
		if _native == null and not _native_failed and not _load_native():
			_native_failed = true
		if _native != null and not _attempted.has(seed) and not _pending.has(seed):
			var next := _pending.duplicate()
			next[seed] = true
			_pending = next
	else:
		_gate(seed)
	_mutex.unlock()


## Load and gate now, deferred or not (tests, the river walk's gate).
static func setup_now(seed: int) -> void:
	_mutex.lock()
	_gate(seed)
	_mutex.unlock()


## Under _mutex. Harmless to repeat.
static func _gate(seed: int) -> void:
	if _attempted.has(seed) or _native_failed:
		return
	_attempted[seed] = true
	if _pending.has(seed):
		var next := _pending.duplicate()
		next.erase(seed)
		_pending = next
	if _native == null and not _load_native():
		_native_failed = true
		return
	var err: String = _native.Prepare(seed)
	var mismatch := "" if err == "" else "C# setup failed: " + err
	if mismatch == "":
		mismatch = _parity(seed)
	if mismatch == "":
		var next := seeds.duplicate()
		next[seed] = true
		seeds = next
		enabled = true
	else:
		push_warning("NativeHeightField disabled for seed %d: %s. Re-sync scripts/native/*.cs with " % [seed, mismatch]
			+ "scripts/terrain/heightfield/{TerrainField,LandformFeatures,TerrainRegime*,LandformSetpieces,"
			+ "RegimeRelief,ReliefPrimitives}.gd / Helper.gd noise. The game uses the (slower) GDScript "
			+ "height field until then.")


## Drop every verified seed (tests): the next setup() re-checks parity.
static func reset() -> void:
	_mutex.lock()
	seeds = {}
	_pending = {}
	_attempted.clear()
	enabled = false
	_mutex.unlock()


static func _load_native() -> bool:
	# The standard editor has no C# support at all: stay silent.
	if not ClassDB.class_exists(&"CSharpScript"):
		return false
	var script = load(_CS_PATH)
	if script == null or not script.can_instantiate():
		push_warning("NativeHeightField: %s is not built (dotnet build Story.csproj); using GDScript heights." % _CS_PATH)
		return false
	_native = script.new()
	var err: String = _native.Configure(_tables())
	if err != "":
		push_warning("NativeHeightField: C# tables rejected (%s); using GDScript heights." % err)
		_native = null
		return false
	return true


# ---------------------------------------------------------------- tables

## The live constants and tables, flattened for C#. Dictionary iteration order
## is preserved as arrays wherever it changes a result.
static func _tables() -> Dictionary:
	var consts := {}
	for script_name: String in _SCRIPTS:
		var map: Dictionary = (_SCRIPTS[script_name] as Script).get_script_constant_map()
		for k: String in map:
			var v = map[k]
			if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
				consts[script_name + "." + k] = float(v)
	var archetypes := PackedStringArray()
	for a: StringName in TerrainRegimeCatalog.ARCHETYPES:
		archetypes.append(String(a))
	var biomes := PackedStringArray()
	for b: StringName in Helper.biome_weights5(Vector3(1000.0, 0.0, 1000.0), 1):
		biomes.append(String(b))
	var affinity := []
	var bias := PackedFloat64Array()
	var params := {}
	var sp_density := {}
	var features := {}
	for a: StringName in TerrainRegimeCatalog.ARCHETYPES:
		var row := PackedFloat64Array()
		for b: String in biomes:
			row.append(float((TerrainRegimeCatalog.AFFINITY.get(StringName(b), {}) as Dictionary).get(a, 0.0)))
		affinity.append(row)
		bias.append(float(TerrainRegimeCatalog.ALTITUDE_BIAS.get(a, 0.0)))
		params[String(a)] = _spec(TerrainRegimeCatalog.PARAMS[a])
		var dens := []
		for k: StringName in TerrainRegimeCatalog.SETPIECE_DENSITY[a]:
			dens.append([String(k), float(TerrainRegimeCatalog.SETPIECE_DENSITY[a][k])])
		sp_density[String(a)] = dens
		var table: Dictionary = TerrainRegimeCatalog.FEATURES[a]
		var kinds := []
		for k: StringName in table.kinds:
			kinds.append([String(k), float(table.kinds[k])])
		features[String(a)] = {"density": float(table.density), "kinds": kinds,
			"height_scale": [float(table.height_scale[0]), float(table.height_scale[1])]}
	var sp_params := {}
	for k: StringName in TerrainRegimeCatalog.SETPIECE_PARAMS:
		sp_params[String(k)] = _spec(TerrainRegimeCatalog.SETPIECE_PARAMS[k])
	var f_params := {}
	for k: StringName in TerrainRegimeCatalog.FEATURE_PARAMS:
		f_params[String(k)] = _spec(TerrainRegimeCatalog.FEATURE_PARAMS[k])
	return {"consts": consts, "archetypes": archetypes, "biomes": biomes, "affinity": affinity,
		"altitude_bias": bias, "params": params, "setpiece_density": sp_density,
		"setpiece_params": sp_params, "features": features, "feature_params": f_params,
		"raised": _names(LandformFeatures._RAISED), "hollow": _names(LandformFeatures._HOLLOW), "benched": _names(LandformFeatures._BENCHED)}


## [name, lo, hi, draw-group hash] per parameter, as TerrainRegimeCatalog.draw reads them.
static func _spec(spec: Dictionary) -> Array:
	var out := []
	for name: String in spec:
		var r: Array = spec[name]
		var group: String = String(r[2]) if r.size() > 2 else name
		out.append([name, float(r[0]), float(r[1]), group.hash() & 0xFFFF])
	return out


static func _names(list: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for n in list:
		out.append(String(n))
	return out


# ---------------------------------------------------------------- parity

## "" when C# equals GDScript bit for bit on every probe, else a description of
## the first mismatch.
static func _parity(seed: int) -> String:
	for p: Vector2 in parity_points(seed):
		for detail: bool in [true, false]:
			var gd := TerrainField.height_m(p, seed, detail)
			var cs: float = _native.HeightM(p, seed, detail)
			if gd != cs:
				return "C# height differs from GDScript at (%s, %s) detail=%s (gd=%s, cs=%s)" % [
					p.x, p.y, detail, var_to_str(gd), var_to_str(cs)]
	return ""


## The fixed probe set of a seed: random and 12 m lattice points round spawn
## (the clearing, 0..240 m); clusters of random, lattice and quarter-metre
## points a few km out and tens of km out (both signs); points inside
## set-piece and feature footprints and along feature links; points on regime
## borders. Clustered so the GDScript reference stays warm (setup cost).
static func parity_points(seed: int) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed, "native-height-parity"])
	var out := PackedVector2Array()
	for i in 240:   # spawn clearing
		out.append(Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, 240.0))
	for i in 80:    # spawn lattice
		out.append(Vector2(rng.randi_range(-20, 20), rng.randi_range(-20, 20)) * 12.0)
	for c in CLUSTERS:
		var reach := 6000.0 if c < CLUSTERS / 2 else 60000.0
		var centre := Vector2(rng.randf_range(-reach, reach), rng.randf_range(-reach, reach))
		for i in 48:
			var p := centre + Vector2(rng.randf_range(-400.0, 400.0), rng.randf_range(-400.0, 400.0))
			match i % 3:
				1:
					p = (p / 12.0).round() * 12.0
				2:
					p = (p * 4.0).round() / 4.0
			out.append(p)
	var area := Rect2(-3000.0, -3000.0, 6000.0, 6000.0)
	# Regime borders: points whose blend holds more than one region.
	var borders := 0
	while borders < 320:
		var p := Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y))
		if TerrainRegimeField.sample(seed, p).size() > 1:
			out.append(p)
			borders += 1
	# Set pieces (8 points each, within the footprint).
	var pieces := LandformSetpieces.setpieces_in_rect(seed, Rect2(-8000.0, -8000.0, 16000.0, 16000.0))
	for a: Dictionary in pieces.slice(0, 48):
		for i in 8:
			out.append(a.pos + Vector2.from_angle(rng.randf() * TAU) * rng.randf() * float(a.radius))
	# Features and their links.
	var feats := LandformFeatures.features_in_rect(seed, area)
	for f: Dictionary in feats.slice(0, 100):
		for i in 4:
			out.append(f.pos + Vector2.from_angle(rng.randf() * TAU) * rng.randf() * float(f.radius))
	var links := 0
	for f: Dictionary in feats:
		if links >= 100:
			break
		for link: Dictionary in LandformFeatures._links_owned(seed, f.cell):
			for i in 4:
				var t := rng.randf()
				var along: Vector2 = link.a.lerp(link.b, t)
				out.append(along + Vector2.from_angle(rng.randf() * TAU) * rng.randf() * float(link.wa))
			links += 1
	return out
