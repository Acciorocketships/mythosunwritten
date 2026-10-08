extends RefCounted

## C# version of CliffSlopeField's bedrock surface net
## (scripts/native/NativeCliffSolid.cs): _columns (with _window_max), solid's
## column evaluation (_solid_top over the 2 m quad corners, presampled here in
## one batched TerrainTileField window sample), the meshing, _drop_fragments
## and the per-vertex normals / exposure / moss grade. Only the production
## bedrock sheet (CliffRockStyle.sheet_study == "bedrock", no rock swells).
## Used only once verified bit-identical to the GDScript (the lazy parity gate
## in on()), and never under the standard editor. No class_name: preload it.
##
## CliffSlopeField.solid / grass_support dispatch with on().
## FieldTerrainStreamer._ready only loads the C# class (prepare()); the gate
## (a few small GDScript reference solids) runs in the first on() call, on the
## chunk tail that first builds a solid; a thread that finds it running
## elsewhere uses GDScript meanwhile. Tests call setup(). The GDScript stays
## the reference: change it freely; a mismatch keeps the native path off and
## names the file to re-sync.

const _CS_PATH := "res://scripts/native/NativeCliffSolid.cs"
const _FIELD := preload("res://scripts/terrain/field/CliffSlopeField.gd")
const _STYLE := preload("res://scripts/terrain/field/CliffRockStyle.gd")

## Tests: force the GDScript reference.
static var force_off := false
static var enabled := false
static var _native: Object = null
static var _load_attempted := false
static var _gated := false
static var _mutex := Mutex.new()


## The solid's columns as a row-major mask over [lo, lo + dims): what
## CliffSlopeField._columns' Dictionary holds, with the same has() /
## is_empty() for its readers (grass support, replacement_columns).
class ColumnMask:
	extends RefCounted
	var lo := Vector2i.ZERO
	var dims := Vector2i.ZERO
	var mask := PackedByteArray()
	var count := 0

	func has(key: Vector2i) -> bool:
		var i := key.x - lo.x
		var k := key.y - lo.y
		return i >= 0 and k >= 0 and i < dims.x and k < dims.y and mask[k * dims.x + i] != 0

	func is_empty() -> bool:
		return count == 0

	## The keys in the GDScript Dictionary's insertion order (gate, tests).
	func keys() -> Array[Vector2i]:
		var out: Array[Vector2i] = []
		for k in dims.y:
			for i in dims.x:
				if mask[k * dims.x + i] != 0:
					out.append(lo + Vector2i(i, k))
		return out


## Any thread. Only the bedrock sheet is native. The first call runs the
## parity gate (unless setup() already did); a thread that finds the gate
## running elsewhere just uses GDScript.
static func on() -> bool:
	if force_off or _STYLE.sheet_study != "bedrock":
		return false
	if not _gated and _mutex.try_lock():
		_gate()
		_mutex.unlock()
	return enabled


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


## CliffSlopeField._columns(rect) of `env`.
static func columns(env, rect: Rect2) -> ColumnMask:
	var r: Array = _native.Columns(env.origin, env.w, env.h, env.surface, env.ground, rect, true)
	var m := ColumnMask.new()
	m.lo = r[0]
	m.dims = r[1]
	m.mask = r[2]
	m.count = r[3]
	return m


## CliffSlopeField.solid's bedrock branch over the columns `cols`: the same
## placement list. Sets field._support_faces / _support_owned.
static func solid(field, env, owned: Rect2, cols: ColumnMask, region) -> Array[Dictionary]:
	if cols.count == 0:
		field._support_faces = PackedVector3Array()
		field._support_owned = owned
		return []
	var qlo := Vector2i.ZERO
	var qsize := Vector2i.ZERO
	var corners := PackedFloat64Array()
	if region != null:
		var step: float = TerrainChunkMesher.STEP
		var grid: float = _FIELD.GRID
		qlo = Vector2i(floori(float(cols.lo.x) * grid / step), floori(float(cols.lo.y) * grid / step))
		var qhi := Vector2i(floori(float(cols.lo.x + cols.dims.x - 1) * grid / step),
			floori(float(cols.lo.y + cols.dims.y - 1) * grid / step))
		qsize = qhi - qlo + Vector2i.ONE
		# Two samples per quad and axis (its low and high corner), each owned
		# by the lattice point of the quad's centre, as _mesh_height bakes it.
		var xs := PackedFloat64Array(); xs.resize(2 * qsize.x)
		var oxs := PackedInt32Array(); oxs.resize(2 * qsize.x)
		var zs := PackedFloat64Array(); zs.resize(2 * qsize.y)
		var ozs := PackedInt32Array(); ozs.resize(2 * qsize.y)
		for a in qsize.x:
			var x0 := float(qlo.x + a) * step
			xs[2 * a] = x0; xs[2 * a + 1] = x0 + step
			oxs[2 * a] = TerrainTileField.point_of(x0 + step * .5, region); oxs[2 * a + 1] = oxs[2 * a]
		for b in qsize.y:
			var z0 := float(qlo.y + b) * step
			zs[2 * b] = z0; zs[2 * b + 1] = z0 + step
			ozs[2 * b] = TerrainTileField.point_of(z0 + step * .5, region); ozs[2 * b + 1] = ozs[2 * b]
		var plo := Vector2i(oxs[0], ozs[0])
		var phi := Vector2i(oxs[oxs.size() - 1], ozs[ozs.size() - 1])
		var window := TerrainTileField.dense_window(region, plo - Vector2i.ONE, phi - plo + Vector2i(3, 3))
		corners = TerrainTileField.sample_grid_window(window, xs, zs, oxs, ozs)
		if TerrainTileField.grades(region):
			# Graded ground: only the quads _solid_top reads take the grade
			# (sample_baked grades every corner it returns).
			var needed: PackedByteArray = _native.NeededQuads(env.origin, env.w, env.h, env.surface, env.ground,
				cols.lo, cols.dims, cols.mask, qlo, qsize)
			var w2 := 2 * qsize.x
			for b in qsize.y:
				for a in qsize.x:
					if needed[b * qsize.x + a] == 0:
						continue
					for c in 4:
						var n := (2 * b + (c >> 1)) * w2 + 2 * a + (c & 1)
						corners[n] = TerrainTileField._apply_grade(region, xs[2 * a + (c & 1)], zs[2 * b + (c >> 1)], corners[n])
	var r: Array = _native.Solid(env.origin, env.w, env.h, env.surface, env.ground, env.excluded, env.rock,
		env.moss_grade, owned, cols.lo, cols.dims, cols.mask, region != null, qlo, qsize, corners)
	var faces: PackedVector3Array = r[0]
	field._support_faces = faces
	field._support_owned = owned
	if faces.is_empty():
		return []
	var points: PackedVector3Array = r[1]
	var normals: PackedVector3Array = r[2]
	var exposure: PackedFloat64Array = r[3]
	var grade: PackedFloat64Array = r[4]
	var roots := {}
	for n in points.size():
		roots[points[n]] = [normals[n], exposure[n], grade[n]]
	var bounds := AABB(r[5], r[6])
	return [{"faces": faces, "green": PackedVector3Array(), "native_roots": roots, "transform": Transform3D.IDENTITY,
		"bounds": bounds, "anchor": bounds.get_center(), "top": bounds.end.y, "base": bounds.position.y,
		"id": "slope_solid/%s" % owned.position, "asset": &"cliff.native_crag", "kind": "rock", "native_crag": true,
		"slope_sheet": true}]


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
		push_warning("NativeCliffSolid disabled: %s. Re-sync scripts/native/NativeCliffSolid.cs " % mismatch
			+ "with scripts/terrain/field/CliffSlopeField.gd (_columns, _window_max, _solid_top_over, "
			+ "_mesh_height, solid, _drop_fragments); the cliff sheet uses GDScript until then.")


## Under _mutex.
static func _load() -> void:
	if _load_attempted:
		return
	_load_attempted = true
	if not ClassDB.class_exists(&"CSharpScript"):
		return
	# Debug knob: compare against the GDScript solid in the same binary.
	if OS.has_environment("NATIVE_CLIFF_SOLID_OFF"):
		return
	var script = load(_CS_PATH)
	if script == null or not script.can_instantiate():
		push_warning("NativeCliffSolid: %s is not built (dotnet build Story.csproj); using GDScript." % _CS_PATH)
		return
	_native = script.new()


## The GDScript constants the C# mirrors, in its Constants() order.
static func constants() -> PackedFloat64Array:
	var F := _FIELD
	return PackedFloat64Array([F.GRID, F.SINK, F.RAISED, F.MARGIN, F.EMERGE, F.COVER,
		TerrainChunkMesher.STEP, F.MIN_PIECE])


static func _parity() -> String:
	if PackedFloat64Array(_native.Constants()) != constants():
		return "constants differ"
	var cases := parity_cases()
	for case_index in cases.size():
		var mismatch := compare(cases[case_index])
		if not mismatch.is_empty():
			return "case %d: %s" % [case_index, mismatch]
	return ""


## Small dual-grid sites (lattice storeys over a 13 x 13 point square): a
## stepped massif with convex and inner corners, a cliff ending in a slope
## with a keep-out stripe across its foot, and a cliff beside a gentle slope
## where the solid lies on the terrain's chords. Owned rects are 24 or 12 m deep.
static func parity_cases() -> Array:
	var massif := func(i: int, j: int) -> int: return clampi(4 - maxi(absi(i), absi(j - 1)), 0, 3) * 2
	var ending := func(i: int, j: int) -> int: return 5 if j <= 0 else (3 if i <= 0 else 4)
	var gentle := func(i: int, j: int) -> int: return (3 if i <= 0 else 1) + clampi(j, -1, 1)
	return [
		{"storeys": massif, "owned": Rect2(-6, -6, 24, 24), "seed": 7, "exclude": Rect2()},
		{"storeys": ending, "owned": Rect2(-6, 0, 24, 12), "seed": 11, "exclude": Rect2(-4, 7, 20, 3)},
		{"storeys": gentle, "owned": Rect2(-18, -6, 24, 24), "seed": 2697992464, "exclude": Rect2()},
	]


static func region_of(storeys: Callable) -> HeightfieldRegion:
	var s := {}
	var levels := {}
	for j in range(-12, 13):
		for i in range(-12, 13):
			s[Vector2i(i, j)] = int(storeys.call(i, j))
			levels[Vector2i(i, j)] = 0
	return HeightfieldRegion.new(s, levels)


## GDScript against C# on one case ({storeys, owned, seed, exclude}); ""
## when identical, else what differs. The field has no walls (no rocks: the
## bedrock solid ignores them) and an envelope over just the owned rect
## grown by 8 m (the build grows its rect by PAD), which is all the solid
## reads.
static func compare(c: Dictionary) -> String:
	var region := region_of(c.storeys)
	var owned: Rect2 = c.owned
	var field = _FIELD.new([], c.seed, region, owned)
	var E = _FIELD.ENVELOPE
	var grid := func(origin: Vector2, w: int, h: int) -> PackedFloat64Array:
		var xs := PackedFloat64Array(); xs.resize(w)
		for i in w: xs[i] = (origin + Vector2(i, 0) * E.H).x
		var zs := PackedFloat64Array(); zs.resize(h)
		for k in h: zs[k] = (origin + Vector2(0, k) * E.H).y
		return TerrainTileField.sample_grid(region, xs, zs)
	var points := func(xs: PackedFloat64Array, zs: PackedFloat64Array) -> PackedFloat64Array:
		return TerrainTileField.sample_grid(region, xs, zs)
	var ground := func(q: Vector2) -> float: return TerrainTileField.surface_y(region, q.x, q.y)
	var exclude: Rect2 = c.exclude
	var excluded := Callable()
	if exclude.has_area():
		excluded = func(q: Vector2) -> bool: return exclude.has_point(q)
	field._env = E.build(owned.grow(8.0 - E.PAD), ground, excluded, c.seed, Callable(), grid, points)
	return compare_field(field, owned)


## Both solids of one CliffSlopeField over `owned` (and its columns).
static func compare_field(field, owned: Rect2) -> String:
	var env = field.envelope()
	var gd: Array = field.solid(owned, 1)
	var gd_faces: PackedVector3Array = field._support_faces
	var gd_columns: Dictionary = field._columns(owned)
	var gd_replacement: Dictionary = field._columns(owned.grow(4.0))
	var cs: Array = field.solid(owned, 2)
	var cs_faces: PackedVector3Array = field._support_faces
	if Array(columns(env, owned).keys()) != gd_columns.keys():
		return "columns differ"
	if Array(columns(env, owned.grow(4.0)).keys()) != gd_replacement.keys():
		return "replacement columns differ"
	if cs_faces != gd_faces:
		return "faces differ (%d vs %d)" % [cs_faces.size(), gd_faces.size()]
	if gd.size() != cs.size():
		return "placement count differs"
	if gd.is_empty():
		return ""
	var a: Dictionary = gd[0]
	var b: Dictionary = cs[0]
	if a.keys() != b.keys():
		return "placement keys differ"
	for key in a:
		if key == "native_roots":
			continue
		if a[key] != b[key]:
			return "%s differs" % key
	var ra: Dictionary = a.native_roots
	var rb: Dictionary = b.native_roots
	if ra.keys() != rb.keys():
		return "native_roots keys differ"
	for key in ra:
		if ra[key] != rb[key]:
			return "native_roots value differs at %s" % key
	return ""
