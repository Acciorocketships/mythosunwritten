extends RefCounted

## C# version of TerrainTileField's tile evaluation over a dense window of
## corner data (sample_owned, sample_grid, sample_grid32). Used only once verified bit-identical to the
## GDScript reference, and never under the standard editor.
## No class_name: preload it. TerrainTileField dispatches with
##   if NATIVE_TILE.on(): return NATIVE_TILE.sample_owned(...)
##
## setup() (FieldTerrainStreamer._ready) loads the C# class; it also runs the
## 60-case parity gate at once unless NativeGates.deferred (the game), where
## the gate runs on the first on() from a non-main thread that wins the
## try_lock and every other caller uses GDScript meanwhile. A C# call that
## throws turns the port off and that call returns the GDScript result.

const _CS_PATH := "res://scripts/native/NativeTileKernel.cs"
const TILE := preload("res://scripts/terrain/field/TerrainTileField.gd")
const _GATES := preload("res://scripts/native/NativeGates.gd")

static var enabled := false
static var _native: Object = null
static var _load_attempted := false
static var _gated := false
static var _mutex := Mutex.new()


## Any thread. Runs a deferred gate on a worker that wins the lock.
static func on() -> bool:
	if not _gated and _native != null and _GATES.may_gate_here() and _mutex.try_lock():
		_gate()
		_mutex.unlock()
	return enabled


static func sample_owned(window: Dictionary, xs: PackedFloat64Array, zs: PackedFloat64Array,
		owner_i: PackedInt32Array, owner_j: PackedInt32Array) -> PackedFloat64Array:
	var lo: Vector2i = window.lo
	var out = _native.SampleOwned(window.heights, window.storeys, window.w, window.h, lo.x, lo.y,
		window.spacing, xs, zs, owner_i, owner_j, TILE.cliff_end)
	if _fault(out):
		return TILE._sample_window_gd(window, xs, zs, owner_i, owner_j)
	return out


static func sample_grid(window: Dictionary, xs: PackedFloat64Array, zs: PackedFloat64Array,
		owner_xs: PackedInt32Array, owner_zs: PackedInt32Array) -> PackedFloat64Array:
	var lo: Vector2i = window.lo
	var out = _native.SampleGrid(window.heights, window.storeys, window.w, window.h, lo.x, lo.y,
		window.spacing, xs, zs, owner_xs, owner_zs, TILE.cliff_end)
	if _fault(out):
		return TILE._sample_grid_gd(window, xs, zs, owner_xs, owner_zs)
	return out


static func sample_grid32(window: Dictionary, xs: PackedFloat64Array, zs: PackedFloat64Array,
		owner_xs: PackedInt32Array, owner_zs: PackedInt32Array) -> PackedFloat32Array:
	var lo: Vector2i = window.lo
	var out = _native.SampleGrid32(window.heights, window.storeys, window.w, window.h, lo.x, lo.y,
		window.spacing, xs, zs, owner_xs, owner_zs, TILE.cliff_end)
	if _fault(out):
		return TILE._to_float32(TILE._sample_grid_gd(window, xs, zs, owner_xs, owner_zs))
	return out


## True (and the port off) when the C# call behind `result` threw.
static func _fault(result) -> bool:
	var err := _GATES.faulted(_native, result)
	if err.is_empty():
		return false
	enabled = false
	push_warning("NativeTileKernel disabled: the C# call failed (%s); using the GDScript tile kernel." % err)
	return true


## Test hook: the next C# call (any port) throws once.
static func arm_fault() -> void:
	setup()
	if _native != null:
		_native.ArmFault()


## Load the C# class; gate now unless NativeGates.deferred. Harmless to repeat.
static func setup() -> void:
	_mutex.lock()
	_load()
	if not _GATES.deferred:
		_gate()
	_mutex.unlock()


## Forget the gate (tests): the next setup()/on() gates again.
static func reset() -> void:
	_mutex.lock()
	_gated = false
	enabled = false
	_mutex.unlock()


## Load and gate now, deferred or not (tests).
static func setup_now() -> void:
	_mutex.lock()
	_load()
	_gate()
	_mutex.unlock()


## Under _mutex.
static func _load() -> void:
	if _load_attempted:
		return
	_load_attempted = true
	if not ClassDB.class_exists(&"CSharpScript"):
		return
	var script = load(_CS_PATH)
	if script == null or not script.can_instantiate():
		push_warning("NativeTileKernel: %s is not built (dotnet build Story.csproj); using GDScript." % _CS_PATH)
		return
	_native = script.new()


## Under _mutex. _gated is set before the parity runs.
static func _gate() -> void:
	if _gated or _native == null:
		return
	_gated = true
	var mismatch := _parity()
	if mismatch.is_empty():
		enabled = true
	else:
		push_warning("NativeTileKernel disabled: %s. Re-sync scripts/native/NativeTileKernel.cs with " % mismatch
			+ "scripts/terrain/field/TerrainTileField.gd (eval_params/_layer/_corner_profile/_profile).")


static func _parity() -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261007
	var result := ""
	for case_index in 60:
		var n := rng.randi_range(4, 14)
		var heights := PackedFloat32Array(); heights.resize(n * n)
		var storeys := PackedInt32Array(); storeys.resize(n * n)
		for k in n * n:
			var st := rng.randi_range(0, 6)
			var h := float(st * 4 + rng.randi_range(0, 3))
			if rng.randf() < 0.1:
				h += 0.5
			elif rng.randf() < 0.15:
				h += rng.randf_range(0.0, 3.999)   # float32-rounded off-grid heights
			heights[k] = h
			storeys[k] = st
		var window := {"lo": Vector2i.ZERO, "w": n, "h": n, "heights": heights, "storeys": storeys, "spacing": 12.0}
		var xs := PackedFloat64Array(); var zs := PackedFloat64Array()
		var oi := PackedInt32Array(); var oj := PackedInt32Array()
		var span := float(n - 3) * 12.0
		for k in 300:
			var x := rng.randf_range(12.0, 12.0 + span)
			var z := rng.randf_range(12.0, 12.0 + span)
			if k % 5 == 0:
				x = 12.0 * rng.randi_range(1, n - 3) + 6.0
			if k % 7 == 0:
				z = 12.0 * rng.randi_range(1, n - 3)
			if k % 11 == 0:
				x = 12.0 * rng.randi_range(1, n - 3)
			if k % 13 == 0:
				z = 12.0 * rng.randi_range(1, n - 3) + 6.0
			xs.append(x); zs.append(z)
			var o := Vector2i(TILE.point_of(x), TILE.point_of(z))
			if k % 3 == 0:
				# Non-point_of owners (the mesher passes a quad's centre owner for
				# its corners): clamp into a neighbour's cell, side -1 at u == 0.5.
				o.x = clampi(o.x + rng.randi_range(-1, 1), 1, n - 2)
				o.y = clampi(o.y + rng.randi_range(-1, 1), 1, n - 2)
			oi.append(o.x); oj.append(o.y)
		if not TILE._owners_inside(window, oi, oj):
			result = "parity case %d: an owner's tiles leave the window" % case_index
			break
		# Grid samples: the first 17 x positions as columns, z positions as rows,
		# each with its (possibly non-point_of) owner.
		var gx := xs.slice(0, 17); var gz := zs.slice(0, 13)
		var gox := oi.slice(0, 17); var goz := oj.slice(0, 13)
		for mode in TILE.CliffEnd.size():
			var grid_expected: PackedFloat64Array = TILE._sample_grid_gd(window, gx, gz, gox, goz, mode)
			var grid_actual: PackedFloat64Array = _native.SampleGrid(heights, storeys, n, n, 0, 0, 12.0,
				gx, gz, gox, goz, mode)
			if grid_expected != grid_actual:
				result = "sample_grid differs (case %d mode %d)" % [case_index, mode]
				break
			var grid32: PackedFloat32Array = _native.SampleGrid32(heights, storeys, n, n, 0, 0, 12.0,
				gx, gz, gox, goz, mode)
			if TILE._to_float32(grid_expected) != grid32:
				result = "sample_grid32 differs (case %d mode %d)" % [case_index, mode]
				break
			var expected: PackedFloat64Array = TILE._sample_window_gd(window, xs, zs, oi, oj, mode)
			var actual: PackedFloat64Array = _native.SampleOwned(heights, storeys, n, n, 0, 0, 12.0,
				xs, zs, oi, oj, mode)
			if expected != actual:
				for k in xs.size():
					if expected[k] != actual[k]:
						result = "sample_owned differs (case %d mode %d sample %d: %s vs %s)" % [
							case_index, mode, k, expected[k], actual[k]]
						break
				break
		if not result.is_empty():
			break
	return result
