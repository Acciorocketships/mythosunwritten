extends RefCounted

## C# versions of CliffSlopeEnvelope's pure grid kernels (_envelope_axis,
## _blur): about half of the cliff sheet's build time in GDScript. Used only
## once verified bit-identical to the GDScript on random grids (setup()), and
## never under the standard editor. No class_name: preload it.
##
## CliffSlopeEnvelope dispatches with
##   if NativeGridKernels.enabled: return NativeGridKernels.<kernel>(...)
## The GDScript kernels stay the reference: change them freely; a mismatch
## keeps the native path off and names the file to re-sync.

const _CS_PATH := "res://scripts/native/NativeGridKernels.cs"
const _ENVELOPE := preload("res://scripts/terrain/field/CliffSlopeEnvelope.gd")
const _GATES := preload("res://scripts/native/NativeGates.gd")

static var enabled := false
static var _native: Object = null
static var _attempted := false
static var _mutex := Mutex.new()


## A C# call that throws turns the port off and that call re-dispatches to
## the (now GDScript) CliffSlopeEnvelope kernel.
static func envelope_axis(f: PackedFloat64Array, w: int, h: int, a: float,
		columns: bool, only := PackedByteArray()) -> PackedFloat64Array:
	var out = _native.EnvelopeAxis(f, w, h, a, columns, only)
	if _fault(out):
		return _ENVELOPE._envelope_axis(f, w, h, a, columns, only)
	return out


static func window(g: PackedFloat64Array, w: int, h: int, reach: float,
		highest: bool) -> PackedFloat64Array:
	var out = _native.Window(g, w, h, ceili(reach / _ENVELOPE.H), highest)
	if _fault(out):
		return _ENVELOPE._window(g, w, h, reach, highest)
	return out


static func blur(f: PackedFloat64Array, w: int, h: int, r: int) -> PackedFloat64Array:
	var out = _native.Blur(f, w, h, r)
	if _fault(out):
		return _ENVELOPE._blur(f, w, h, r)
	return out


static func bank_bound(surface:PackedFloat64Array,w:int,h:int,original:PackedFloat64Array,
		size:Vector2i,xs:PackedInt32Array,zs:PackedInt32Array,intervals:int)->PackedFloat64Array:
	var out=_native.BankBound(surface,w,h,original,size.x,size.y,xs,zs,intervals)
	if _fault(out):
		return load("res://scripts/terrain/water/WaterBankBound.gd").reference_bound(surface,w,h,original,size,xs,zs,intervals)
	return out


## True (and the port off) when the C# call behind `result` threw.
static func _fault(result) -> bool:
	var err := _GATES.faulted(_native, result)
	if err.is_empty():
		return false
	enabled = false
	push_warning("NativeGridKernels disabled: the C# call failed (%s); using the GDScript kernels." % err)
	return true


## Test hook: the next C# call (any port) throws once.
static func arm_fault() -> void:
	setup()
	if _native != null:
		_native.ArmFault()


## Main thread, once (FieldTerrainStreamer._ready; harmless to repeat).
static func setup() -> void:
	_mutex.lock()
	if _attempted:
		_mutex.unlock()
		return
	_attempted = true
	if not ClassDB.class_exists(&"CSharpScript"):
		_mutex.unlock()
		return
	var script = load(_CS_PATH)
	if script == null or not script.can_instantiate():
		push_warning("NativeGridKernels: %s is not built (dotnet build Story.csproj); using GDScript." % _CS_PATH)
		_mutex.unlock()
		return
	_native = script.new()
	var mismatch := _parity()
	if mismatch.is_empty():
		enabled = true
	else:
		push_warning("NativeGridKernels disabled: %s. Re-sync scripts/native/NativeGridKernels.cs with " % mismatch
			+ "scripts/terrain/field/CliffSlopeEnvelope.gd (_envelope_axis/_envelope1/_blur); "
			+ "the cliff sheet uses the GDScript kernels until then.")
	_mutex.unlock()


## Random grids (with unreached INF nodes, as the envelope's inputs have),
## odd and even sizes, rows and columns, partial `only` masks.
static func _parity() -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261005
	for case_index in 80:
		var w := rng.randi_range(1, 90)
		var h := rng.randi_range(1, 90)
		var f := PackedFloat64Array()
		f.resize(w * h)
		for i in f.size():
			f[i] = INF if rng.randf() < 0.3 else rng.randf_range(-50.0, 50.0)
		var a := rng.randf_range(0.01, 3.0)
		var columns := rng.randf() < 0.5
		var only := PackedByteArray()
		if rng.randf() < 0.5:
			only.resize(w if columns else h)
			for i in only.size():
				only[i] = 1 if rng.randf() < 0.6 else 0
		var expected: PackedFloat64Array = _ENVELOPE._envelope_axis(f, w, h, a, columns, only)
		var actual: PackedFloat64Array = _native.EnvelopeAxis(f, w, h, a, columns, only)
		if expected != actual:
			return "envelope_axis differs (case %d, %dx%d)" % [case_index, w, h]
		var finite := f.duplicate()
		for i in finite.size():
			if finite[i] == INF:
				finite[i] = rng.randf_range(-5.0, 5.0)
		# Radius 0 and windows wider than the grid included.
		var r := rng.randi_range(0, 4) if case_index % 4 != 0 else rng.randi_range(0, 120)
		if _ENVELOPE._blur(finite, w, h, r) != _native.Blur(finite, w, h, r):
			return "blur differs (case %d, %dx%d r=%d)" % [case_index, w, h, r]
		var reach := 0.0 if case_index % 5 == 0 else rng.randf_range(0.0, 60.0)
		var highest := rng.randf() < 0.5
		if _ENVELOPE._window(finite, w, h, reach, highest) \
				!= _native.Window(finite, w, h, ceili(reach / _ENVELOPE.H), highest):
			return "window differs (case %d, %dx%d reach=%.3f)" % [case_index, w, h, reach]
		var bank=load("res://scripts/terrain/water/WaterBankBound.gd")
		var intervals:=6 if case_index%2==0 else 12
		var xs:=PackedInt32Array([-3,intervals-3,intervals*2-3])
		var zs:=PackedInt32Array([-2,intervals-2,intervals*2-2])
		var originals:=PackedFloat64Array()
		for z in 3:
			for x in 3:originals.append(finite[clampi(zs[z],0,h-1)*w+clampi(xs[x],0,w-1)])
		if bank.reference_bound(finite,w,h,originals,Vector2i(3,3),xs,zs,intervals) != _native.BankBound(finite,w,h,originals,3,3,xs,zs,intervals):
			return "bank_bound differs (case %d)" % case_index
	return ""
