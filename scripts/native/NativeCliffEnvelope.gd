extends RefCounted

## C# version of CliffSlopeEnvelope.build's numeric pipeline: everything after
## its presampled inputs (the ground grid, the keep-out mask, the water levels
## and the ground on both sides of every 12 m wall line), i.e. _walls,
## _close_walls, _channel_scale, _lips, _ridges, the closings, _distance, the
## blend, fillet and caps, _bedrock, _bench, _level_outward and _moss_grade
## (scripts/native/NativeCliffEnvelope.cs). Used only once verified
## bit-identical to the GDScript (the lazy parity gate in on()), and never
## under the standard editor. No class_name: preload it.
##
## CliffSlopeEnvelope._build dispatches with NativeCliffEnvelope.on().
## FieldTerrainStreamer._ready only loads the C# class (prepare()); the parity
## gate (a few small GDScript reference builds) runs in the first on() call,
## on the chunk tail that first builds an envelope; a thread that finds the
## gate running elsewhere uses GDScript meanwhile. Tests call setup().
## The GDScript stays the reference: change it freely; a mismatch keeps the
## native path off and names the file to re-sync.

const _CS_PATH := "res://scripts/native/NativeCliffEnvelope.cs"
const _ENVELOPE := preload("res://scripts/terrain/field/CliffSlopeEnvelope.gd")

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


## Main thread, cheap: load the C# class (FieldTerrainStreamer._ready).
static func prepare() -> void:
	_mutex.lock()
	_load()
	_mutex.unlock()


## Load and gate now (tests, harnesses). Harmless to repeat.
static func setup() -> void:
	_mutex.lock()
	_gate()
	_mutex.unlock()


## The native build over env's presampled inputs; assigns env's surface,
## rock and moss_grade exactly as the GDScript build does. With `stages`,
## CliffSlopeEnvelope.stages receives the C# stage arrays.
static func build_rest(env, wet_level: PackedFloat64Array, lines: Array, seed_value: int,
		bedrock: bool, stages: bool) -> void:
	var result: Array = _native.Build(env.origin, env.w, env.h, env.ground, env.excluded, wet_level,
		lines[0], lines[1], lines[2], lines[3], lines[4], lines[5], seed_value, bedrock, stages)
	env.surface = result[0]
	env.rock = result[1]
	env.moss_grade = result[2]
	if stages:
		_ENVELOPE.stages = result[3]


## Under _mutex. _gated is set before the parity runs.
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
		push_warning("NativeCliffEnvelope disabled: %s. Re-sync scripts/native/NativeCliffEnvelope.cs " % mismatch
			+ "with scripts/terrain/field/CliffSlopeEnvelope.gd (build after its inputs: _walls, "
			+ "_close_walls, _channel_scale, _lips, _ridges, _bedrock, _bench, _bench_profile, "
			+ "_level_outward, _moss_grade); the cliff sheet uses GDScript until then.")


## Under _mutex.
static func _load() -> void:
	if _load_attempted:
		return
	_load_attempted = true
	if not ClassDB.class_exists(&"CSharpScript"):
		return
	# Debug knob: compare against the GDScript build in the same binary.
	if OS.has_environment("NATIVE_CLIFF_ENVELOPE_OFF"):
		return
	var script = load(_CS_PATH)
	if script == null or not script.can_instantiate():
		push_warning("NativeCliffEnvelope: %s is not built (dotnet build Story.csproj); using GDScript." % _CS_PATH)
		return
	_native = script.new()


## The GDScript constants the C# mirrors, in its Constants() order.
static func constants() -> PackedFloat64Array:
	var E := _ENVELOPE
	return PackedFloat64Array([E.H, E.SHOULDER.x, E.SHOULDER.y, E.FOOT, E.TIGHT.x, E.TIGHT.y,
		E.RELIEF.x, E.RELIEF.y, E.RELIEF_SPREAD, E.CELL, E.LOW, E.WIDEN, E.JUMP, E.CLIFF_DROP,
		E.VARIED.x, E.VARIED.y, E.PLAIN, E.CUT_SLOPE, E.CUT_MARGIN, E.CHANNEL_CORE, E.WATER_SINK,
		E.BEDROCK_RECESS, E.BLOCK, E.PATCH, E.STRETCH, E.TREAD, E.RISER, E.CORNER, E.BLOCK_BLEND,
		E.FILTER])


## Small synthetic sites covering every stage: storeyed walls on the 12 m
## wall lines (convex and inner corners, a wall ending in a slope), a jump off
## the wall lines, a road, a channel fitted between two walls, the plain
## sheet, and ground without walls. Each grid is a 28 m square or less (the rect is
## the window shrunk by the build's PAD, so its size is negative): the whole
## gate takes a few hundred milliseconds of GDScript.
static func _parity() -> String:
	if PackedFloat64Array(_native.Constants()) != constants():
		return "constants differ"
	var cases := parity_cases()
	for case_index in cases.size():
		var mismatch := compare(cases[case_index])
		if not mismatch.is_empty():
			return "case %d: %s" % [case_index, mismatch]
	return ""


## The build rect whose grid is the square of half-size `half` round `centre`.
static func window(centre: Vector2, half: float) -> Rect2:
	var inset := half - _ENVELOPE.PAD
	return Rect2(centre - Vector2.ONE * inset, Vector2.ONE * 2.0 * inset)


static func parity_cases() -> Array:
	var walls := func(q: Vector2) -> float:
		var x := floorf((q.x + 6.0) / 12.0)
		var z := floorf((q.y + 6.0) / 12.0)
		var h := 4.0 * clampf(x, -1.0, 2.0) + (8.0 if z <= -1.0 and x >= 0.0 else 0.0)
		# A wall that ends in a slope, and a jump off the wall lines.
		if z >= 1.0:
			h = minf(h, 2.0 + q.x * 0.15)
		if q.x > 9.0 and q.y < -14.3:
			h += 2.5
		return h
	var road := func(q: Vector2) -> bool: return q.y > 1.0 and q.y < 5.0 and q.x < 4.0
	var channel_walls := func(q: Vector2) -> float:
		if absf(q.x) < 6.0:
			return 0.2 * sin(q.y * 0.4)
		return 12.0 + 4.0 * floorf((q.y + 6.0) / 12.0) * signf(q.x)
	var channel := func(q: Vector2) -> float: return 2.0 + 0.3 * sin(q.y * 0.2) if absf(q.x) < 8.0 else NAN
	var rolling := func(q: Vector2) -> float: return 3.0 * sin(q.x * 0.11) + 2.0 * cos(q.y * 0.07)
	return [
		{"rect": window(Vector2(0.0, -6.0), 14.0), "ground": walls, "excluded": road, "water": Callable(), "seed": 7, "bedrock": true},
		{"rect": window(Vector2.ZERO, 14.0), "ground": channel_walls, "excluded": Callable(), "water": channel, "seed": 2697992464, "bedrock": true},
		{"rect": window(Vector2(0.0, 6.0), 14.0), "ground": walls, "excluded": road, "water": channel, "seed": 3, "bedrock": false},
		{"rect": window(Vector2.ZERO, 8.0), "ground": rolling, "excluded": road, "water": Callable(), "seed": 5, "bedrock": true},
	]


## GDScript against C# on one case ({rect, ground, excluded, water, seed,
## bedrock}, optional ground_grid/ground_points); "" when identical, else the
## first differing array (stages too when `with_stages`).
static func compare(c: Dictionary, with_stages := false) -> String:
	var grid: Callable = c.get("ground_grid", Callable())
	var points: Callable = c.get("ground_points", Callable())
	var arrays: Array = []
	var stage_sets: Array = []
	for mode in [1, 2]:
		_ENVELOPE.capture_stages = with_stages
		_ENVELOPE.stages = {}
		var env = _ENVELOPE._build(c.rect, c.ground, c.excluded, c.seed, c.water, grid, points, c.bedrock, mode)
		_ENVELOPE.capture_stages = false
		arrays.append([env.surface, env.rock, env.moss_grade, env.excluded, env.ground])
		stage_sets.append(_ENVELOPE.stages)
	_ENVELOPE.stages = {}
	if with_stages:
		var gd: Dictionary = stage_sets[0]
		var cs: Dictionary = stage_sets[1]
		for key in gd:
			if not cs.has(key):
				return "stage %s missing" % key
			if cs[key] != gd[key]:
				return "stage %s differs" % key
	var names := ["surface", "rock", "moss_grade", "excluded", "ground"]
	for k in names.size():
		if arrays[0][k] != arrays[1][k]:
			return "%s differs" % names[k]
	return ""
